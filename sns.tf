# SNS Topic para alertas de anomalías
resource "aws_sns_topic" "anomaly_alerts" {
  name         = "${local.project_name}-anomaly-alerts"
  display_name = "Anomaly Detection Alerts"

  tags = merge({ Name = "${local.prefix}-sns-topic" }, local.common_tags)
}

# Suscripción de email principal
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.anomaly_alerts.arn
  protocol  = "email"
  endpoint  = var.email

  depends_on = [aws_sns_topic.anomaly_alerts]
}

# Topic policy para permitir publicación desde Lambda
resource "aws_sns_topic_policy" "anomaly_alerts_policy" {
  arn = aws_sns_topic.anomaly_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaPublishSNS"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "SNS:Publish",
          "SNS:GetTopicAttributes"
        ]
        Resource = aws_sns_topic.anomaly_alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowCloudWatchAlarmsPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "SNS:Publish",
          "SNS:GetTopicAttributes"
        ]
        Resource = aws_sns_topic.anomaly_alerts.arn
      }
    ]
  })
}
