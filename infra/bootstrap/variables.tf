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
