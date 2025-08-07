# modules/processing/variables.tf

variable "bucket_name" {
  description = "Nombre del bucket S3 donde se almacenan los Flow Logs"
  type        = string
}

variable "athena_database" {
  description = "Nombre de la base de datos de Athena"
  type        = string
}

variable "athena_table" {
  description = "Nombre de la tabla de Athena para VPC Flow Logs"
  type        = string
}

variable "athena_results_bucket" {
  description = "Nombre del bucket S3 para resultados de consultas Athena"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN del topic SNS para enviar alertas"
  type        = string
}

variable "lambda_timeout" {
  description = "Timeout en segundos para la función Lambda"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Memoria en MB para la función Lambda"
  type        = number
  default     = 512
}

variable "lambda_runtime" {
  description = "Runtime de la función Lambda"
  type        = string
  default     = "python3.11"
}

variable "bedrock_model_id" {
  description = "ID del modelo de Bedrock para análisis de IA"
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}

variable "athena_query_timeout" {
  description = "Timeout en segundos para queries de Athena"
  type        = number
  default     = 300
}

variable "log_retention_days" {
  description = "Días de retención para logs de CloudWatch"
  type        = number
  default     = 14
}

variable "enable_xray_tracing" {
  description = "Habilitar tracing con AWS X-Ray"
  type        = bool
  default     = false
}

variable "environment_variables" {
  description = "Variables de entorno adicionales para Lambda"
  type        = map(string)
  default     = {}
}

variable "lambda_layers" {
  description = "Lista de ARNs de Lambda Layers"
  type        = list(string)
  default     = []
}

variable "vpc_config" {
  description = "Configuración VPC para Lambda (opcional)"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "dead_letter_config" {
  description = "Configuración de Dead Letter Queue"
  type = object({
    target_arn = string
  })
  default = null
}

variable "reserved_concurrent_executions" {
  description = "Número de ejecuciones concurrentes reservadas para Lambda"
  type        = number
  default     = -1
}

variable "tags" {
  description = "Tags comunes para todos los recursos"
  type        = map(string)
  default     = {}
}