# # Crear el archivo ZIP de la función Lambda
# data "archive_file" "lambda_zip" {
#   type        = "zip"
#   output_path = "${path.module}/lambda_function.zip"

#   source {
#     content = templatefile("${path.root}/scripts/lambda_function.py", {
#       athena_database       = "${local.project_name}_flow_logs_db"
#       athena_table          = "vpc_flow_logs"
#       athena_results_bucket = "${var.bucket_name}-athena-results"
#       sns_topic_arn         = "${aws_sns_topic.anomaly_alerts.arn}"
#     })
#     filename = "lambda_function.py"
#   }

#   source {
#     content  = file("${path.root}/scripts/requirements.txt")
#     filename = "requirements.txt"
#   }
# }

# # IAM Role para Lambda
# resource "aws_iam_role" "lambda_role" {
#   name_prefix = "anomaly-detection-lambda-"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       }
#     ]
#   })

#   tags = local.common_tags
# }

# # IAM Policy para Lambda
# resource "aws_iam_role_policy" "lambda_policy" {
#   name_prefix = "anomaly-detection-lambda-"
#   role        = aws_iam_role.lambda_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ]
#         Resource = "arn:aws:logs:*:*:*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "athena:StartQueryExecution",
#           "athena:GetQueryExecution",
#           "athena:GetQueryResults",
#           "athena:StopQueryExecution"
#         ]
#         Resource = "*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject",
#           "s3:ListBucket"
#         ]
#         Resource = [
#           "arn:aws:s3:::${aws_s3_bucket.flow_logs.arn}",
#           "arn:aws:s3:::${aws_s3_bucket.flow_logs.arn}/*",
#           "arn:aws:s3:::${aws_s3_bucket.athena_results.arn}",
#           "arn:aws:s3:::${aws_s3_bucket.athena_results.arn}/*"
#         ]
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "glue:GetDatabase",
#           "glue:GetTable",
#           "glue:GetPartitions"
#         ]
#         Resource = "*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "bedrock:InvokeModel",
#           "bedrock:InvokeModelWithResponseStream"
#         ]
#         Resource = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "sns:Publish"
#         ]
#         Resource = "${aws_sns_topic.anomaly_alerts.arn}"
#       }
#     ]
#   })
# }

# # Adjuntar la política básica de ejecución de Lambda
# resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
#   role       = aws_iam_role.lambda_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }

# # Función Lambda
# resource "aws_lambda_function" "anomaly_processor" {
#   filename      = data.archive_file.lambda_zip.output_path
#   function_name = "anomaly-detection-processor"
#   role          = aws_iam_role.lambda_role.arn
#   handler       = "lambda_function.lambda_handler"
#   runtime       = "python3.11"
#   timeout       = 300
#   memory_size   = 1024

#   source_code_hash = data.archive_file.lambda_zip.output_base64sha256

#   environment {
#     variables = {
#       ATHENA_DATABASE       = "${local.project_name}_flow_logs_db"
#       ATHENA_TABLE          = "vpc_flow_logs"
#       ATHENA_RESULTS_BUCKET = "${var.bucket_name}-athena-results"
#       SNS_TOPIC_ARN         = aws_sns_topic.anomaly_alerts.arn
#       BEDROCK_MODEL_ID      = "anthropic.claude-3-5-sonnet-20241022-v2:0"
#     }
#   }

#   tags = local.common_tags
# }

# # CloudWatch Log Group para Lambda
# resource "aws_cloudwatch_log_group" "lambda_logs" {
#   name              = "/aws/lambda/${aws_lambda_function.anomaly_processor.function_name}"
#   retention_in_days = 14

#   tags = local.common_tags
# }
