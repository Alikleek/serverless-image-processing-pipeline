variable "name_prefix" {
  type = string
}

variable "dest_bucket_id" {
  type = string
}

variable "dest_bucket_arn" {
  type = string
}

variable "dest_bucket_regional_domain" {
  type = string
}

variable "price_class" {
  description = "PriceClass_100 = North America + Europe edges (cheapest)."
  type        = string
  default     = "PriceClass_100"
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_response_headers_policy" "security" {
  name = "Managed-SecurityHeadersPolicy"
}

# CloudFront signs its requests to S3; the bucket stays private.
resource "aws_cloudfront_origin_access_control" "dest" {
  name                              = "${var.name_prefix}-dest-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "images" {
  enabled         = true
  comment         = "${var.name_prefix} processed images"
  price_class     = var.price_class
  http_version    = "http2and3"
  is_ipv6_enabled = true

  origin {
    origin_id                = "dest-bucket"
    domain_name              = var.dest_bucket_regional_domain
    origin_access_control_id = aws_cloudfront_origin_access_control.dest.id
  }

  # Output keys contain the imageId and never change, so long TTLs are safe
  # and no invalidations are needed.
  default_cache_behavior {
    target_origin_id           = "dest-bucket"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Default *.cloudfront.net certificate. A custom domain would need an ACM
  # certificate in us-east-1 plus DNS records.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# The destination bucket's only policy: CloudFront (this distribution) can read,
# and plain-HTTP access is denied.
data "aws_iam_policy_document" "dest" {
  statement {
    sid       = "AllowCloudFrontRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.dest_bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.images.arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      var.dest_bucket_arn,
      "${var.dest_bucket_arn}/*",
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

resource "aws_s3_bucket_policy" "dest" {
  bucket = var.dest_bucket_id
  policy = data.aws_iam_policy_document.dest.json
}

output "domain_name" {
  value = aws_cloudfront_distribution.images.domain_name
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.images.arn
}
