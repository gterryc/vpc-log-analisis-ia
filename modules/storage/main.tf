# modules/storage/main.tf

# S3 Bucket para Flow Logs
resource "aws_s3_bucket" "flow_logs" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.tags.Project}-flow-logs-bucket"
    Purpose = "VPCFlowLogs"
  })
}

# Configuración de versioning
resource "aws_s3_bucket_versioning" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptación del bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueo de acceso público
resource "aws_s3_bucket_public_access_block" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy para optimizar costos
resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    id     = "flow_logs_lifecycle"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

# Bucket policy para VPC Flow Logs
resource "aws_s3_bucket_policy" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.flow_logs.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.flow_logs.arn
      }
    ]
  })
}

# S3 Bucket para resultados de Athena
resource "aws_s3_bucket" "athena_results" {
  bucket        = "${var.bucket_name}-athena-results"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.tags.Project}-athena-results-bucket"
    Purpose = "AthenaQueryResults"
  })
}

# Configuración de versioning para Athena results
resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptación para Athena results
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueo de acceso público para Athena results
resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle para resultados de Athena
resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "athena_results_lifecycle"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}