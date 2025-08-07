# Almacenamiento (S3)
module "storage" {
  source = "./modules/storage"
  
  bucket_name = local.bucket_name
  
  tags = local.common_tags
}