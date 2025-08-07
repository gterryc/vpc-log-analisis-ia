# modules/processing/outputs.tf

output "lambda_function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.anomaly_processor.arn
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.anomaly_processor.function_name
}

output "lambda_function_qualified_arn" {
  description = "ARN cualificado de la función Lambda"
  value       = aws_lambda_function.anomaly_processor.qualified_arn
}

output "lambda_function_version" {
  description = "Versión de la función Lambda"
  value       = aws_lambda_function.anomaly_processor.version
}

output "lambda_role_arn" {
  description = "ARN del rol IAM de Lambda"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_role_name" {
  description = "Nombre del rol IAM de Lambda"
  value       = aws_iam_role.lambda_role.name
}

output "lambda_log_group_name" {
  description = "Nombre del grupo de logs de CloudWatch"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "lambda_log_group_arn" {
  description = "ARN del grupo de logs de CloudWatch"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}

output "lambda_source_code_hash" {
  description = "Hash del código fuente de Lambda"
  value       = aws_lambda_function.anomaly_processor.source_code_hash
}

output "lambda_last_modified" {
  description = "Fecha de última modificación de la función Lambda"
  value       = aws_lambda_function.anomaly_processor.last_modified
}

output "lambda_invoke_arn" {
  description = "ARN para invocar la función Lambda"
  value       = aws_lambda_function.anomaly_processor.invoke_arn
}