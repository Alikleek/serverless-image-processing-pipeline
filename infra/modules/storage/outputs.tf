output "source_bucket_id" {
  value = aws_s3_bucket.this["source"].id
}

output "source_bucket_arn" {
  value = aws_s3_bucket.this["source"].arn
}

output "dest_bucket_id" {
  value = aws_s3_bucket.this["dest"].id
}

output "dest_bucket_arn" {
  value = aws_s3_bucket.this["dest"].arn
}

output "dest_bucket_regional_domain_name" {
  value = aws_s3_bucket.this["dest"].bucket_regional_domain_name
}
