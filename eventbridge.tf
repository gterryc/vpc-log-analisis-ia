# # EventBridge Rule para ejecutar análisis periódico
# resource "aws_cloudwatch_event_rule" "anomaly_detection_schedule" {
#   name                = "${local.project_name}-anomaly-detection-schedule"
#   description         = "Trigger anomaly detection analysis every ${var.schedule_frequency_minutes} minutes"
#   schedule_expression = "rate(${var.schedule_frequency_minutes} minutes)"
#   state               = var.enable_scheduled_analysis ? "ENABLED" : "DISABLED"

#   tags = merge(local.common_tags, {
#     Name    = "${local.project_name}-anomaly-detection-schedule"
#     Purpose = "AutomatedAnalysis"
#   })
# }

# # Target para la función Lambda
# resource "aws_cloudwatch_event_target" "lambda_target" {
#   rule      = aws_cloudwatch_event_rule.anomaly_detection_schedule.name
#   target_id = "AnomalyDetectionLambdaTarget"
#   arn       = aws_lambda_function.anomaly_processor.arn

#   # # Input transformer para pasar información útil a Lambda
#   # input_transformer {
#   #   input_paths = {
#   #     timestamp = "$.time"
#   #     source    = "$.source"
#   #   }
#   #   input_template = jsonencode({
#   #     "trigger_type"            = "scheduled"
#   #     "timestamp"               = "<timestamp>"
#   #     "source"                  = "<source>"
#   #     "analysis_window_minutes" = var.analysis_window_minutes
#   #   })
#   # }

#   # retry_policy {
#   #   maximum_retry_attempts       = 3
#   #   maximum_event_age_in_seconds = 3600
#   # }

#   # dead_letter_config {
#   #   arn = var.enable_dead_letter_queue ? aws_sqs_queue.dlq[0].arn : null
#   # }
# }

# # Permiso para que EventBridge invoque Lambda
# resource "aws_lambda_permission" "allow_eventbridge" {
#   statement_id  = "AllowExecutionFromEventBridge"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.anomaly_processor.arn
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.anomaly_detection_schedule.arn
# }

# # # EventBridge Rule para monitoreo de fallos de Lambda
# # resource "aws_cloudwatch_event_rule" "lambda_failure_monitoring" {
# #   count       = var.enable_failure_monitoring ? 1 : 0
# #   name        = "${local.project_name}-lambda-failure-monitoring"
# #   description = "Monitor Lambda function failures"

# #   event_pattern = jsonencode({
# #     source      = ["aws.lambda"]
# #     detail-type = ["Lambda Function Invocation Result - Failure"]
# #     detail = {
# #       functionName = ["${aws_lambda_function.anomaly_processor.id}"]
# #     }
# #   })

# #   tags = merge(local.common_tags, {
# #     Name    = "${local.project_name}-lambda-failure-monitoring"
# #     Purpose = "FailureMonitoring"
# #   })
# # }

# # # Target para notificar fallos de Lambda
# # resource "aws_cloudwatch_event_target" "lambda_failure_notification" {
# #   count     = var.enable_failure_monitoring ? 1 : 0
# #   rule      = aws_cloudwatch_event_rule.lambda_failure_monitoring[0].name
# #   target_id = "LambdaFailureNotification"
# #   arn       = aws_sns_topic.anomaly_alerts.arn

# #   input_transformer {
# #     input_paths = {
# #       function_name = "$.detail.functionName"
# #       error_message = "$.detail.errorMessage"
# #       timestamp     = "$.time"
# #     }
# #     input_template = jsonencode({
# #       "alert_type"    = "lambda_failure"
# #       "function_name" = "<function_name>"
# #       "error_message" = "<error_message>"
# #       "timestamp"     = "<timestamp>"
# #       "severity"      = "HIGH"
# #     })
# #   }
# # }

