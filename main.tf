# Random suffix para recursos únicos
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
