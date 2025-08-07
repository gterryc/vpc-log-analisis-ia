variable "bucket_name" {
  description = "S3 Bucket Name"
  type = string
}

variable "tags" {
  description = "Tags para los recursos de VPC"
  type = any  
}