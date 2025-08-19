# Crear el archivo ZIP de la función Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.root}/lambda_function.zip"
  
  source {
    content = file("${path.root}/scripts/lambda_function.py")
    filename = "lambda_function.py"
  }
  
  source {
    content = file("${path.root}/scripts/requirements.txt")
    filename = "requirements.txt"
  }
}

# Función Lambda
resource "aws_lambda_function" "anomaly_processor" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = var.lambda_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 300
  memory_size   = 1024

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ATHENA_DATABASE       = "${local.project_name}_flow_logs_db"
      ATHENA_TABLE          = "vpc_flow_logs"
      ATHENA_RESULTS_BUCKET = "${var.bucket_name}-athena-results"
      SNS_TOPIC_ARN         = aws_sns_topic.anomaly_alerts.arn
      BEDROCK_MODEL_ID      = "anthropic.claude-3-5-sonnet-20241022-v2:0"
    }
  }

  tags = local.common_tags
}


resource "aws_lambda_function" "anomaly_detection_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.lambda_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.11"
  timeout         = 600  # 10 minutos
  memory_size     = 1024 # 1GB
  
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  # Variables de entorno
  environment {
    variables = {
      DATABASE_NAME     = aws_glue_catalog_database.vpc_flow_logs.name
      TABLE_NAME        = aws_glue_catalog_table.vpc_flow_logs.name
      RESULTS_BUCKET    = data.aws_s3_bucket.anomaly-detection-athena-results.bucket
      SNS_TOPIC_ARN     = aws_sns_topic.anomaly_alerts.name
      BEDROCK_MODEL_ID  = var.bedrock_model_id      
    }
  }
  
  # Tags
  tags = merge(local.common_tags, {
    Name        = "anomaly-detection-processor"
    Purpose     = "SecurityAnomalyDetection"   
  })
}


# CloudWatch Log Group para Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 7

  tags = local.common_tags
}

