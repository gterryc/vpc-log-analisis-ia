# Análisis de datos (Athena + Glue)
module "analytics" {
  source = "./modules/analytics"
  
  bucket_name  = local.bucket_name
  bucket_arn   = module.storage.bucket_arn
  project_name = local.project_name
  
  depends_on = [module.storage]
  tags       = local.common_tags
}