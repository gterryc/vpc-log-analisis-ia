# VPC y Networking
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = data.aws_availability_zones.available.names[0]
  
  bucket_arn = module.storage.bucket_arn
  
  tags = local.common_tags
}


