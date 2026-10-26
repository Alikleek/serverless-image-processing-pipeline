output "api_url" {
  description = "Base URL of the HTTP API (POST /uploads, GET /images/{imageId})."
  value       = module.api.api_url
}

output "cdn_domain" {
  description = "CloudFront domain serving processed images."
  value       = module.cdn.domain_name
}

output "source_bucket" {
  value = module.storage.source_bucket_id
}

output "dest_bucket" {
  value = module.storage.dest_bucket_id
}

output "queue_url" {
  value = module.queue.queue_url
}

output "dlq_url" {
  value = module.queue.dlq_url
}

output "state_machine_arn" {
  value = module.workflow.state_machine_arn
}

output "topic_arn" {
  value = module.notify.topic_arn
}
