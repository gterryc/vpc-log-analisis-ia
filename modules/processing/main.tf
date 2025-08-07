# Crear el archivo ZIP de la función Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  
  source {
    content = templatefile("${path.module}/lambda_function.py", {
      athena_database        = var.athena_database
      athena_table          = var.athena_table
      athena_results_bucket = var.athena_results_bucket
      sns_topic_arn         = var.sns_topic_arn
    })
    filename = "lambda_function.py"
  }
  
  source {
    content  = file("${path.module}/requirements.txt")
    filename = "requirements.txt"
  }
}

# IAM Role para Lambda
resource "aws_iam_role" "lambda_role" {
  name_prefix = "anomaly-detection-lambda-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy para Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name_prefix = "anomaly-detection-lambda-"
  role        = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*",
          "arn:aws:s3:::${var.athena_results_bucket}",
          "arn:aws:s3:::${var.athena_results_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      }
    ]
  })
}

# Adjuntar la política básica de ejecución de Lambda
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Función Lambda
resource "aws_lambda_function" "anomaly_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "anomaly-detection-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512
  
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ATHENA_DATABASE        = var.athena_database
      ATHENA_TABLE          = var.athena_table
      ATHENA_RESULTS_BUCKET = var.athena_results_bucket
      SNS_TOPIC_ARN         = var.sns_topic_arn
      BEDROCK_MODEL_ID      = "anthropic.claude-3-sonnet-20240229-v1:0"
    }
  }

  tags = var.tags
}

# CloudWatch Log Group para Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.anomaly_processor.function_name}"
  retention_in_days = 14

  tags = var.tags
}

# Lambda Layer para dependencias (opcional, para optimizar)
resource "aws_lambda_layer_version" "dependencies" {
  filename         = "${path.module}/layer.zip"
  layer_name       = "anomaly-detection-dependencies"
  compatible_runtimes = ["python3.11"]
  
  # Solo crear si el archivo existe
  count = fileexists("${path.module}/layer.zip") ? 1 : 0
}