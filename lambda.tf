# Procesamiento (Lambda)
module "processing" {
  source = "./modules/processing"
  
  bucket_name            = local.bucket_name
  athena_database        = module.analytics.database_name
  athena_table           = module.analytics.table_name
  athena_results_bucket  = module.analytics.results_bucket_name
  sns_topic_arn          = module.alerting.topic_arn
  
  depends_on = [module.analytics, module.alerting]
  tags       = local.common_tags
}