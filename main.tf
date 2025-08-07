# Random suffix para recursos únicos
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Datos de la región actual
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
