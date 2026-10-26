locals {
  # One entry per Lambda. `image` functions get the Pillow layer.
  functions = {
    presign    = { timeout = 10, memory = 256, image = false }
    status     = { timeout = 10, memory = 256, image = false }
    dispatcher = { timeout = 30, memory = 256, image = false }
    validate   = { timeout = 30, memory = 512, image = true }
    thumbnail  = { timeout = 60, memory = 1024, image = true }
    watermark  = { timeout = 60, memory = 1536, image = true }
    metadata   = { timeout = 30, memory = 512, image = true }
  }

  environment = {
    SOURCE_BUCKET           = var.source_bucket_name
    DEST_BUCKET             = var.dest_bucket_name
    TABLE_NAME              = var.table_name
    STATE_MACHINE_ARN       = var.state_machine_arn
    CDN_DOMAIN              = var.cdn_domain
    MAX_UPLOAD_BYTES        = tostring(var.max_upload_bytes)
    POWERTOOLS_SERVICE_NAME = var.name_prefix
  }
}

# --- Code and layer --------------------------------------------------------

data "archive_file" "code" {
  type        = "zip"
  source_dir  = var.src_dir
  output_path = "${var.build_dir}/lambda-src.zip"
  excludes    = ["**/__pycache__/**", "**/*.pyc"]
}

resource "aws_lambda_layer_version" "pillow" {
  layer_name               = "${var.name_prefix}-pillow"
  filename                 = var.pillow_layer_zip
  source_code_hash         = fileexists(var.pillow_layer_zip) ? filebase64sha256(var.pillow_layer_zip) : null
  compatible_runtimes      = [var.runtime]
  compatible_architectures = [var.architecture]

  lifecycle {
    precondition {
      condition     = fileexists(var.pillow_layer_zip)
      error_message = "Pillow layer zip not found. Run `make layer` first."
    }
  }
}

# --- IAM: one role per function --------------------------------------------

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = local.functions

  name               = "${var.name_prefix}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Logs to its own log group, plus X-Ray. Shared by all functions.
data "aws_iam_policy_document" "base" {
  for_each = local.functions

  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this[each.key].arn}:*"]
  }

  statement {
    sid       = "XRay"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "base" {
  for_each = local.functions

  name   = "base"
  role   = aws_iam_role.this[each.key].id
  policy = data.aws_iam_policy_document.base[each.key].json
}

# Function-specific permissions.
data "aws_iam_policy_document" "presign" {
  # A pre-signed POST is signed with this role's credentials, so the role
  # itself needs PutObject on the upload prefix.
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${var.source_bucket_arn}/uploads/*"]
  }

  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [var.table_arn]
  }
}

data "aws_iam_policy_document" "status" {
  statement {
    actions   = ["dynamodb:GetItem"]
    resources = [var.table_arn]
  }
}

data "aws_iam_policy_document" "dispatcher" {
  statement {
    actions   = ["states:StartExecution"]
    resources = [var.state_machine_arn]
  }

  statement {
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [var.queue_arn]
  }
}

data "aws_iam_policy_document" "read_source" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${var.source_bucket_arn}/uploads/*"]
  }
}

data "aws_iam_policy_document" "read_source_write_dest" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${var.source_bucket_arn}/uploads/*"]
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = ["${var.dest_bucket_arn}/*"]
  }
}

locals {
  function_policies = {
    presign    = data.aws_iam_policy_document.presign.json
    status     = data.aws_iam_policy_document.status.json
    dispatcher = data.aws_iam_policy_document.dispatcher.json
    validate   = data.aws_iam_policy_document.read_source.json
    thumbnail  = data.aws_iam_policy_document.read_source_write_dest.json
    watermark  = data.aws_iam_policy_document.read_source_write_dest.json
    metadata   = data.aws_iam_policy_document.read_source.json
  }
}

resource "aws_iam_role_policy" "function" {
  for_each = local.functions

  name   = each.key
  role   = aws_iam_role.this[each.key].id
  policy = local.function_policies[each.key]
}

# --- Functions -------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  for_each = local.functions

  name              = "/aws/lambda/${var.name_prefix}-${each.key}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  for_each = local.functions

  function_name    = "${var.name_prefix}-${each.key}"
  role             = aws_iam_role.this[each.key].arn
  runtime          = var.runtime
  architectures    = [var.architecture]
  handler          = "handlers.${each.key}.handler"
  filename         = data.archive_file.code.output_path
  source_code_hash = data.archive_file.code.output_base64sha256
  timeout          = each.value.timeout
  memory_size      = each.value.memory

  layers = each.value.image ? concat([aws_lambda_layer_version.pillow.arn], var.extra_layer_arns) : var.extra_layer_arns

  environment {
    variables = local.environment
  }

  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.this[each.key].name
  }

  depends_on = [
    aws_iam_role_policy.base,
    aws_iam_role_policy.function,
  ]
}

# --- SQS -> dispatcher -----------------------------------------------------

resource "aws_lambda_event_source_mapping" "dispatcher" {
  event_source_arn                   = var.queue_arn
  function_name                      = aws_lambda_function.this["dispatcher"].arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  function_response_types            = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = var.dispatcher_max_concurrency
  }
}
