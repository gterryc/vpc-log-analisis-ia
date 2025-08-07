
variable "aws_region" {
  description = "AWS region para desplegar recursos"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block para VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block para subnet pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block para subnet privada"
  type        = string
  default     = "10.0.2.0/24"
}

variable "notification_email" {
  description = "Email para recibir notificaciones de anomalías"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "El email debe tener un formato válido."
  }
}

variable "key_pair_name" {
  description = "Nombre del key pair para instancias EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "enable_flow_logs" {
  description = "Habilitar VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Días de retención para Flow Logs"
  type        = number
  default     = 30
}

variable "analysis_frequency_minutes" {
  description = "Frecuencia de análisis en minutos"
  type        = number
  default     = 5
}

variable "athena_query_timeout" {
  description = "Timeout para queries de Athena en segundos"
  type        = number
  default     = 300
}