# Sistema de alertas (SNS)
module "alerting" {
  source = "./modules/alerting"
  
  project_name = local.project_name
  email        = var.notification_email
  
  tags = local.common_tags
}