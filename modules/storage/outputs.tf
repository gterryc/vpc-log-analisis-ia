output "bucket_arn" {
  description = "S3 Bucket ARN"
  value = aws_s3_bucket.flow_logs.arn
}