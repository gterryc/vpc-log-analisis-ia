terraform {
  backend "s3" {
    bucket = "george-sandbox--terraform-us-east-1-state"
    key    = "vpc-anomaly-detection/terraform.tfstate"
    region = "us-east-1"
  }
}
