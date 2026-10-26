variable "name" {
  type = string
}

variable "definition_file" {
  description = "Path to the ASL template (rendered with templatefile)."
  type        = string
}

variable "function_arns" {
  type = map(string)
}

variable "table_name" {
  type = string
}

variable "table_arn" {
  type = string
}

variable "topic_arn" {
  type = string
}

variable "log_level" {
  type = string
}

variable "log_retention_days" {
  type = number
}

locals {
  step_functions = ["validate", "thumbnail", "watermark", "metadata"]
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn" {
  name               = "${var.name}-sfn"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "sfn" {
  statement {
    sid       = "InvokeSteps"
    actions   = ["lambda:InvokeFunction"]
    resources = [for f in local.step_functions : var.function_arns[f]]
  }

  statement {
    sid       = "UpdateImageRecord"
    actions   = ["dynamodb:UpdateItem"]
    resources = [var.table_arn]
  }

  statement {
    sid       = "Notify"
    actions   = ["sns:Publish"]
    resources = [var.topic_arn]
  }

  # Step Functions log delivery requires these on "*".
  statement {
    sid = "LogDelivery"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "XRay"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords", "xray:GetSamplingRules", "xray:GetSamplingTargets"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "sfn" {
  name   = "pipeline"
  role   = aws_iam_role.sfn.id
  policy = data.aws_iam_policy_document.sfn.json
}

# /aws/vendedlogs/ prefix avoids hitting the CloudWatch Logs resource-policy size limit.
resource "aws_cloudwatch_log_group" "sfn" {
  name              = "/aws/vendedlogs/states/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_sfn_state_machine" "pipeline" {
  name     = var.name
  type     = "STANDARD"
  role_arn = aws_iam_role.sfn.arn

  definition = templatefile(var.definition_file, {
    validate_arn  = var.function_arns["validate"]
    thumbnail_arn = var.function_arns["thumbnail"]
    watermark_arn = var.function_arns["watermark"]
    metadata_arn  = var.function_arns["metadata"]
    table_name    = var.table_name
    topic_arn     = var.topic_arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
    include_execution_data = true
    level                  = var.log_level
  }

  tracing_configuration {
    enabled = true
  }

  depends_on = [aws_iam_role_policy.sfn]
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.pipeline.arn
}
