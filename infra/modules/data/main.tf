variable "name_prefix" {
  type = string
}

variable "deletion_protection" {
  type    = bool
  default = false
}

# One item per image: imageId, status (PENDING|PROCESSING|COMPLETED|FAILED),
# uploadedAt, dimensions, format, output keys.
resource "aws_dynamodb_table" "images" {
  name                        = "${var.name_prefix}-images"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "imageId"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "imageId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "uploadedAt"
    type = "S"
  }

  # List jobs by status, newest first.
  global_secondary_index {
    name            = "status-uploadedAt"
    projection_type = "ALL"

    key_schema {
      attribute_name = "status"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "uploadedAt"
      key_type       = "RANGE"
    }
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}

output "table_name" {
  value = aws_dynamodb_table.images.name
}

output "table_arn" {
  value = aws_dynamodb_table.images.arn
}
