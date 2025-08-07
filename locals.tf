locals {
  project_name = "vpc-traffic-anomaly-detection"
  environment  = "demo"
  common_tags = {
    Owner       = "George Terry"
    Environment = local.environment
    Project     = local.project_name
    Deployment  = "Terraform"
    Domain      = ""
  }
  bucket_name = "${local.project_name}-flowlogs-${random_string.suffix.result}"
}
