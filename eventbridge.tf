# Automatización (EventBridge)
module "automation" {
  source = "./modules/automation"
  
  lambda_function_arn = module.processing.lambda_function_arn
  lambda_function_name = module.processing.lambda_function_name
  
  depends_on = [module.processing]
  tags       = local.common_tags
}