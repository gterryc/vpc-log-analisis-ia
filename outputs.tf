# outputs.tf
output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.vpc.vpc_id
}

output "flow_logs_bucket" {
  description = "Nombre del bucket de Flow Logs"
  value       = module.storage.bucket_name
}

output "athena_database" {
  description = "Base de datos de Athena"
  value       = module.analytics.database_name
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = module.processing.lambda_function_name
}

output "sns_topic_arn" {
  description = "ARN del topic de SNS"
  value       = module.alerting.topic_arn
}

output "demo_instances" {
  description = "Información de las instancias de demo"
  value       = module.demo_instances.demo_info
  sensitive   = true
}

output "architecture_summary" {
  description = "Resumen de la arquitectura desplegada"
  value = {
    region = var.aws_region
    vpc_cidr = var.vpc_cidr
    components_deployed = [
      "VPC with Flow Logs",
      "S3 Storage",
      "Athena Analytics", 
      "Lambda Processing",
      "SNS Alerting",
      "Demo Instances",
      "EventBridge Automation"
    ]
    estimated_monthly_cost = "$8-15 USD"
    demo_ready = true
  }
}