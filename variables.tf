### Variables Generales

variable "aws_region" {
  description = "AWS region para desplegar recursos"
  type        = string
  default     = "us-east-1"
}

### Variables VPC
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

### Variables de S3 Bucket

variable "bucket_name" {
  description = "S3 Bucket Name"
  type        = string
}

### Variable de SNS

variable "email" {
  description = "Email principal para recibir alertas"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.email))
    error_message = "El email debe tener un formato válido."
  }
}

# Variables Lambda

variable "lambda_name" {
  description = "Nombre de la función Lambda (para construir el nombre del log group)."
  type        = string
  default     = "anomaly-detection-function" 
}

# ### Variables Eventbridge
# variable "schedule_frequency_minutes" {
#   description = "Frecuencia en minutos para ejecutar análisis automático"
#   type        = number
#   default     = 5

#   validation {
#     condition     = var.schedule_frequency_minutes >= 1 && var.schedule_frequency_minutes <= 1440
#     error_message = "La frecuencia debe estar entre 1 minuto y 1440 minutos (24 horas)."
#   }
# }

# variable "enable_scheduled_analysis" {
#   description = "Habilitar análisis automático programado"
#   type        = bool
#   default     = true
# }

# variable "analysis_window_minutes" {
#   description = "Ventana de tiempo en minutos para analizar en cada ejecución"
#   type        = number
#   default     = 60

#   validation {
#     condition     = var.analysis_window_minutes >= 5 && var.analysis_window_minutes <= 1440
#     error_message = "La ventana de análisis debe estar entre 5 minutos y 24 horas."
#   }
# }

# variable "enable_dead_letter_queue" {
#   description = "Habilitar Dead Letter Queue para eventos fallidos"
#   type        = bool
#   default     = true
# }

# variable "enable_failure_monitoring" {
#   description = "Habilitar monitoreo de fallos de Lambda"
#   type        = bool
#   default     = true
# }

### Variables EC2

variable "key_pair_name" {
  description = "Nombre del key pair para instancias EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "ec2_iam_instance_profile" {
  description = "IAM instance profile para agregar SSM Connect"
  type        = string
  default     = "SSM_Manage_Instance" # Este role se creo a mano y existe previamente en la cuenta
}

# Variables Bedrock

variable "bedrock_model_id" {
  description = "ID del modelo de Bedrock"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20240620-v1:0"
}