variable "name_prefix" {
  type = string
}

variable "src_dir" {
  description = "Directory packaged as the function code (contains handlers/)."
  type        = string
}

variable "build_dir" {
  description = "Where the code zip is written."
  type        = string
}

variable "pillow_layer_zip" {
  description = "Path to the Pillow layer zip produced by `make layer`."
  type        = string
}

variable "extra_layer_arns" {
  description = "Extra layers for the image functions, e.g. the AWS-managed Powertools layer ARN for your Region."
  type        = list(string)
  default     = []
}

variable "runtime" {
  type    = string
  default = "python3.13"
}

variable "architecture" {
  type    = string
  default = "arm64"
}

variable "log_retention_days" {
  type = number
}

variable "source_bucket_name" {
  type = string
}

variable "source_bucket_arn" {
  type = string
}

variable "dest_bucket_name" {
  type = string
}

variable "dest_bucket_arn" {
  type = string
}

variable "table_name" {
  type = string
}

variable "table_arn" {
  type = string
}

variable "queue_arn" {
  type = string
}

variable "state_machine_arn" {
  type = string
}

variable "cdn_domain" {
  type = string
}

variable "max_upload_bytes" {
  type = number
}

variable "dispatcher_max_concurrency" {
  type = number
}
