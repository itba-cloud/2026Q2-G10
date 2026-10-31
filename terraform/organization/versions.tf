terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # aws_s3_bucket no funciona en el Learner Lab porque una SCP deniega
    # s3:GetBucketObjectLockConfiguration, por eso los buckets usan awscc
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}
