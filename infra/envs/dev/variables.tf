variable "aws_region" {
  description = "Project Region (AWS Settings > View all projects > Overview > Additional Info > Region)."
  type        = string
}

variable "expected_account_id" {
  description = "12-digit ID of the target project account. Terraform refuses to run against any other account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be a 12-digit AWS account ID."
  }
}

variable "project_name" {
  description = "Short name used as a prefix for resource names."
  type        = string
  default     = "image-pipeline"
}

variable "env" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "notification_email" {
  description = "Email subscribed to the job/alarm SNS topic. Leave empty to skip the subscription."
  type        = string
  default     = ""
}

variable "max_upload_bytes" {
  description = "Maximum upload size enforced by the pre-signed POST policy."
  type        = number
  default     = 10485760
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for all log groups."
  type        = number
  default     = 14
}

variable "cors_allowed_origins" {
  description = "Origins allowed to call the API and POST to the source bucket."
  type        = list(string)
  default     = ["*"]
}

variable "api_throttle_rate" {
  description = "Steady-state requests per second for the HTTP API stage."
  type        = number
  default     = 10
}

variable "api_throttle_burst" {
  description = "Burst limit for the HTTP API stage."
  type        = number
  default     = 20
}

variable "dispatcher_max_concurrency" {
  description = "Maximum concurrent dispatcher invocations from SQS (minimum 2)."
  type        = number
  default     = 5
}

variable "sfn_log_level" {
  description = "Step Functions log level: ALL, ERROR, FATAL or OFF."
  type        = string
  default     = "ERROR"
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to delete non-empty buckets. Keep true only for dev."
  type        = bool
  default     = true
}
