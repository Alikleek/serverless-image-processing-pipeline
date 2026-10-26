# Source (uploads) and destination (processed) buckets. Keeping them separate
# means processed output can never re-trigger the pipeline.
#
# The destination bucket's policy is owned by the cdn module, because it must
# reference the CloudFront distribution ARN (a bucket has exactly one policy).

locals {
  buckets = {
    source = "${var.name_prefix}-source-${var.account_id}-${var.aws_region}"
    dest   = "${var.name_prefix}-dest-${var.account_id}-${var.aws_region}"
  }
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket        = each.value
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Source bucket ---------------------------------------------------------

data "aws_iam_policy_document" "source" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this["source"].arn,
      "${aws_s3_bucket.this["source"].arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "source" {
  bucket = aws_s3_bucket.this["source"].id
  policy = data.aws_iam_policy_document.source.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# Browsers upload straight to S3 with a pre-signed POST.
resource "aws_s3_bucket_cors_configuration" "source" {
  bucket = aws_s3_bucket.this["source"].id

  cors_rule {
    allowed_methods = ["POST"]
    allowed_origins = var.cors_allowed_origins
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "source" {
  bucket = aws_s3_bucket.this["source"].id

  # Originals are rarely read after processing: tier down, then expire.
  # STANDARD_IA bills a 128 KB minimum per object and 30 days minimum storage.
  rule {
    id     = "originals-tiering"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- Destination bucket ----------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "dest" {
  bucket = aws_s3_bucket.this["dest"].id

  # Access patterns of served images are unpredictable: let S3 decide.
  rule {
    id     = "intelligent-tiering"
    status = "Enabled"

    filter {}

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
