locals {
  project_name = "vpc-traffic-anomaly-detection"
  environment  = "demo"
  prefix       = "aws-demo"
  common_tags = {
    Owner       = "George Terry"
    Environment = local.environment
    Project     = local.project_name
    Deployment  = "Terraform"
    Domain      = "georgeterry.cloud"
  }
  #bucket_name = "${local.project_name}-flowlogs-${random_string.suffix.result}"
}
