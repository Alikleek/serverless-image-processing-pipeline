variable "name_prefix" {
  type = string
}

variable "account_id" {
  type = string
}

variable "source_bucket_arn" {
  description = "Only this bucket may send messages to the queue."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Should be at least 6x the consumer Lambda timeout."
  type        = number
}

variable "max_receive_count" {
  description = "Receives before a message is moved to the DLQ."
  type        = number
  default     = 3
}
