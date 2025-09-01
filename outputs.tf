# =========================================================================
# OUTPUTS CRÍTICOS PARA DEMO.SH
# =========================================================================

# Output principal que usa demo.sh para obtener IPs de instancias
output "demo_instances" {
  description = "Información de las instancias para la demo"
  value = {
    attack_simulator_public_ip  = aws_instance.attack_simulator.public_ip
    attack_simulator_private_ip = aws_instance.attack_simulator.private_ip
    web_server_public_ip        = aws_instance.web_server.public_ip
    web_server_private_ip       = aws_instance.web_server.private_ip
  }
  sensitive = false
}

# =========================================================================
# OUTPUT PARA DEPLOY.SH
# =========================================================================

# Summary de la arquitectura que muestra deploy.sh
output "architecture_summary" {
  description = "Resumen completo de la arquitectura desplegada"
  value = {
    # Información de red
    vpc_id             = aws_vpc.main.id
    vpc_cidr           = aws_vpc.main.cidr_block
    public_subnet_ids  = aws_subnet.public[*].id
    private_subnet_ids = aws_subnet.private[*].id

    # Instancias EC2
    attack_simulator = {
      instance_id = aws_instance.attack_simulator.id
      public_ip   = aws_instance.attack_simulator.public_ip
      private_ip  = aws_instance.attack_simulator.private_ip
      state       = aws_instance.attack_simulator.instance_state
    }

    web_server = {
      instance_id = aws_instance.web_server.id
      public_ip   = aws_instance.web_server.public_ip
      private_ip  = aws_instance.web_server.private_ip
      state       = aws_instance.web_server.instance_state
    }

    # Recursos de almacenamiento
    s3_bucket = {
      name   = data.aws_s3_bucket.anomaly-detection-flow-logs.id
      arn    = data.aws_s3_bucket.anomaly-detection-flow-logs.arn
      region = data.aws_s3_bucket.anomaly-detection-flow-logs.region
    }

    # Funciones Lambda
    lambda_functions = {
      anomaly_processor = {
        function_name = aws_lambda_function.anomaly_detection_processor.function_name
        arn           = aws_lambda_function.anomaly_detection_processor.arn
        runtime       = aws_lambda_function.anomaly_detection_processor.runtime
      }
    }

    # SNS y alertas
    sns_topic = {
      name = aws_sns_topic.anomaly_alerts.name
      arn  = aws_sns_topic.anomaly_alerts.arn
    }

    # CloudWatch
    cloudwatch = {
      log_group_name = aws_cloudwatch_log_group.lambda_logs.name
    }

    # Flow Logs
    flow_logs = {
      vpc_flow_log_id = aws_flow_log.main.id
      s3_prefix       = "AWSLogs/${data.aws_caller_identity.current.account_id}/vpcflowlogs/${data.aws_region.current.id}/"
    }

    # Información de acceso
    access_info = {
      ssh_command = "ssh -i ~/.ssh/aws-demo.pem ec2-user@${aws_instance.attack_simulator.public_ip}"
      region      = data.aws_region.current.id
      account_id  = data.aws_caller_identity.current.account_id
    }
  }
}

# =========================================================================
# OUTPUTS PARA INTEGRACIÓN CON BEDROCK/AI
# =========================================================================

output "ai_integration_info" {
  description = "Información para integración con servicios de AI"
  value = {
    bedrock_region   = data.aws_region.current.id
    s3_data_location = "s3://${data.aws_s3_bucket.anomaly-detection-flow-logs.id}/AWSLogs/${data.aws_caller_identity.current.account_id}/"
    athena_database  = aws_glue_catalog_database.vpc_flow_logs.name
    athena_table     = aws_glue_catalog_table.vpc_flow_logs.name
  }
}
