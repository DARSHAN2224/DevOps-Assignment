terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Note: For production, parameters like bucket and dynamodb_table 
    # should be passed dynamically during init based on environment
    bucket         = "YOUR_AWS_S3_TERRAFORM_STATE_BUCKET"
    key            = "aws/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "YOUR_DYNAMODB_LOCK_TABLE"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "DevOps-Assignment"
      Environment = var.environment
    }
  }
}
