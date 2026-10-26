variable "name_prefix" {
  type = string
}

variable "account_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cors_allowed_origins" {
  type = list(string)
}

variable "force_destroy" {
  type = bool
}
