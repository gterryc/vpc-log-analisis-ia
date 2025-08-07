variable "instance_type" {
  description = "EC2 Instance type para la demo"
  type = string
}

variable "key_pair_name" {
  description = "Key pair name"
  type = string
}

variable "private_subnet_id" {
  description = "Subnet para la EC2 de la demo"
  type = string
}

variable "public_subnet_id" {
  description = "Subnet para la EC2 de la demo"
  type = string
}

variable "vpc_id" {
  description = "VPC ID para la EC2 de la demo"
  type = string
}

variable "tags" {
  description = "Tags para los recursos de VPC"
  type        = map(string)
  default     = {}
}