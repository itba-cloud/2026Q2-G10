# Bucket del state remoto de organization. Va en un bootstrap aparte con state
# local porque el backend remoto no puede crear el bucket que todavia no existe

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 6.0" }
    awscc = { source = "hashicorp/awscc", version = "~> 1.0" }
  }
}

provider "aws" {
  region = var.region
}

provider "awscc" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "barriofix"
}

data "aws_caller_identity" "this" {}

locals {
  # Lleva el account id porque el nombre de bucket es unico en todo AWS
  bucket_name = format("%s-tfstate-%s", var.project, data.aws_caller_identity.this.account_id)
}

resource "awscc_s3_bucket" "state" {
  bucket_name = local.bucket_name

  # Permite recuperar un state corrupto o pisado
  versioning_configuration = {
    status = "Enabled"
  }

  bucket_encryption = {
    server_side_encryption_configuration = [{
      server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }]
  }

  public_access_block_configuration = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}

output "state_bucket" {
  value = awscc_s3_bucket.state.bucket_name
}
