output "state_bucket_name" {
  description = "Put this in infra/envs/<env>/backend.hcl as `bucket`."
  value       = aws_s3_bucket.tfstate.bucket
}
