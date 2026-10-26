# Partial configuration: bucket, key and region come from backend.hcl
# (copy backend.hcl.example), passed with `terraform init -backend-config=backend.hcl`.
terraform {
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}
