variable "vpc_cidr" {
  description = "CIDR block para VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block para subnet pública"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block para subnet privada"
  type        = string
}

variable "availability_zone" {
  description = "Zona de disponibilidad"
  type        = string
}

variable "bucket_arn" {
  description = "ARN del bucket S3 para Flow Logs"
  type        = string
}

variable "tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}