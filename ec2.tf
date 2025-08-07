# Instancias EC2 para la demo
module "demo_instances" {
  source = "./modules/demo"
  
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id
  key_pair_name     = var.key_pair_name
  
  tags = local.common_tags
}