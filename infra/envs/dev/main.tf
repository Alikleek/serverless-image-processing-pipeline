data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.env}"
  account_id  = data.aws_caller_identity.current.account_id
  repo_root   = "${path.root}/../../.."

  # Built from its parts (not taken from the workflow module) so the
  # dispatcher Lambda can reference it without a functions <-> workflow cycle.
  state_machine_name = "${local.name_prefix}-pipeline"
  state_machine_arn  = "arn:aws:states:${var.aws_region}:${local.account_id}:stateMachine:${local.state_machine_name}"
}

module "storage" {
  source = "../../modules/storage"

  name_prefix          = local.name_prefix
  account_id           = local.account_id
  aws_region           = var.aws_region
  cors_allowed_origins = var.cors_allowed_origins
  force_destroy        = var.force_destroy
}

module "queue" {
  source = "../../modules/queue"

  name_prefix                = local.name_prefix
  account_id                 = local.account_id
  source_bucket_arn          = module.storage.source_bucket_arn
  visibility_timeout_seconds = 180 # >= 6x the dispatcher timeout (30s)
}

# S3 -> SQS. Lives here because it needs both the bucket and the queue policy.
resource "aws_s3_bucket_notification" "uploads" {
  bucket = module.storage.source_bucket_id

  queue {
    queue_arn     = module.queue.queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }

  depends_on = [module.queue]
}

module "data" {
  source = "../../modules/data"

  name_prefix = local.name_prefix
}

module "notify" {
  source = "../../modules/notify"

  name_prefix        = local.name_prefix
  notification_email = var.notification_email
}

module "cdn" {
  source = "../../modules/cdn"

  name_prefix                 = local.name_prefix
  dest_bucket_id              = module.storage.dest_bucket_id
  dest_bucket_arn             = module.storage.dest_bucket_arn
  dest_bucket_regional_domain = module.storage.dest_bucket_regional_domain_name
}

module "functions" {
  source = "../../modules/functions"

  name_prefix                = local.name_prefix
  src_dir                    = "${local.repo_root}/src"
  build_dir                  = "${local.repo_root}/build"
  pillow_layer_zip           = "${local.repo_root}/build/pillow-layer.zip"
  log_retention_days         = var.log_retention_days
  source_bucket_name         = module.storage.source_bucket_id
  source_bucket_arn          = module.storage.source_bucket_arn
  dest_bucket_name           = module.storage.dest_bucket_id
  dest_bucket_arn            = module.storage.dest_bucket_arn
  table_name                 = module.data.table_name
  table_arn                  = module.data.table_arn
  queue_arn                  = module.queue.queue_arn
  state_machine_arn          = local.state_machine_arn
  cdn_domain                 = module.cdn.domain_name
  max_upload_bytes           = var.max_upload_bytes
  dispatcher_max_concurrency = var.dispatcher_max_concurrency
}

module "workflow" {
  source = "../../modules/workflow"

  name               = local.state_machine_name
  definition_file    = "${local.repo_root}/statemachine/pipeline.asl.json.tftpl"
  function_arns      = module.functions.function_arns
  table_name         = module.data.table_name
  table_arn          = module.data.table_arn
  topic_arn          = module.notify.topic_arn
  log_level          = var.sfn_log_level
  log_retention_days = var.log_retention_days
}

module "api" {
  source = "../../modules/api"

  name_prefix          = local.name_prefix
  presign_invoke_arn   = module.functions.invoke_arns["presign"]
  presign_function     = module.functions.function_names["presign"]
  status_invoke_arn    = module.functions.invoke_arns["status"]
  status_function      = module.functions.function_names["status"]
  cors_allowed_origins = var.cors_allowed_origins
  throttle_rate        = var.api_throttle_rate
  throttle_burst       = var.api_throttle_burst
  log_retention_days   = var.log_retention_days
}

module "alarms" {
  source = "../../modules/alarms"

  name_prefix       = local.name_prefix
  topic_arn         = module.notify.topic_arn
  dlq_name          = module.queue.dlq_name
  state_machine_arn = module.workflow.state_machine_arn
  function_names    = module.functions.function_names
  api_id            = module.api.api_id
}
