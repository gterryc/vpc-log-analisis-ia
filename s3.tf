# Bucket S3 para almacenar los logs y resultados de Athena
# Los Buckets se crearon a mano para poder guardar logs con anterioridad

data "aws_s3_bucket" "anomaly-detection-flow-logs" {
  bucket = "anomaly-detection-flow-logs-12051980"
}

data "aws_s3_bucket" "anomaly-detection-athena-results" {
  bucket = "anomaly-detection-athena-results-12051980"
}