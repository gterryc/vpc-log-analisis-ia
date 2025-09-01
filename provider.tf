terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "2.7.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
