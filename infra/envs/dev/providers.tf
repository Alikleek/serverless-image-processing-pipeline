provider "aws" {
  region = var.aws_region

  # Hard stop if the active credentials belong to any other account.
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project   = var.project_name
      Env       = var.env
      ManagedBy = "terraform"
    }
  }
}
