# Arquitectura de Detección de Tráfico Anómalo en AWS

## 🏗️ Diagrama de Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    VPC + EC2    │    │   VPC + EC2     │    │   Attack Box    │
│   (Aplicación)  │────│  (Simulación)   │────│   (Simulador)   │
│                 │    │                 │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    VPC Flow Logs                               │
│             (Captura todo el tráfico de red)                   │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Amazon S3                                    │
│           (Almacenamiento de Flow Logs)                        │
│                Particionado por fecha                          │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Amazon Athena                                  │
│        (Análisis y consultas SQL de los logs)                  │
│    • Detección de patrones anómalos                            │
│    • Agregaciones por tiempo/IP/puerto                         │
│    • Queries programadas                                       │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                AWS Lambda                                      │
│           (Procesador de Anomalías)                            │
│    • Ejecuta queries de Athena                                 │
│    • Procesa resultados                                        │
│    • Invoca Bedrock para análisis                              │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                Amazon Bedrock                                  │
│              (IA Generativa)                                   │
│    • Interpreta datos de tráfico                               │
│    • Genera explicaciones claras                               │
│    • Sugiere acciones correctivas                              │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                Amazon SNS                                      │
│            (Sistema de Alertas)                                │
│    • Notificaciones por email                                  │
│    • Integración con Slack/Teams                               │
│    • Alertas estructuradas                                     │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              CloudWatch Events                                │
│            (Automatización)                                    │
│    • Triggers programados                                      │
│    • Monitoreo del sistema                                     │
│    • Métricas de rendimiento                                   │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Componentes Principales

### 1. **Capa de Generación de Datos**
- **VPC con EC2**: Instancias que generan tráfico normal
- **Simulador de Ataques**: Script que genera tráfico anómalo
- **VPC Flow Logs**: Captura automática de metadatos de red

### 2. **Capa de Almacenamiento**
- **S3 Bucket**: Almacena los Flow Logs con particionado por fecha
- **Estructura optimizada**: Para consultas eficientes en Athena

### 3. **Capa de Análisis**
- **Amazon Athena**: Motor de consultas SQL serverless
- **Glue Data Catalog**: Metadatos y esquemas
- **Queries de detección**: Patrones predefinidos de anomalías

### 4. **Capa de Procesamiento**
- **Lambda Functions**: Orquestación y procesamiento
- **EventBridge**: Programación de ejecuciones

### 5. **Capa de IA**
- **Amazon Bedrock**: Interpretación inteligente de resultados
- **Modelos LLM**: Claude/Titan para generar explicaciones

### 6. **Capa de Alertas**
- **Amazon SNS**: Sistema de notificaciones
- **CloudWatch**: Métricas y dashboards

---


<!-- BEGIN_TF_DOCS -->
#### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.10.0 |
| <a name="requirement_archive"></a> [archive](#requirement_archive) | 2.7.1 |
| <a name="requirement_aws"></a> [aws](#requirement_aws) | >=5.0.0 |
| <a name="requirement_random"></a> [random](#requirement_random) | ~> 3.1 |

#### Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider_archive) | 2.7.1 |
| <a name="provider_aws"></a> [aws](#provider_aws) | 6.8.0 |
| <a name="provider_random"></a> [random](#provider_random) | 3.7.2 |

#### Resources

| Name | Type |
|------|------|
| [aws_athena_named_query.data_exfiltration_detection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.ddos_detection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.port_scanning_detection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.unusual_protocol_detection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_workgroup.anomaly_detection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_workgroup) | resource |
| [aws_cloudwatch_log_group.lambda_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eip.attack_simulator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_glue_catalog_database.vpc_flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_database) | resource |
| [aws_glue_catalog_table.vpc_flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_table) | resource |
| [aws_iam_instance_profile.ec2_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ec2_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cw_logs_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.athena_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bedrock_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bedrock_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.glue_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.s3_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sns_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sns_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.attack_simulator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_instance.web_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_lambda_function.anomaly_detection_processor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.attack_simulator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.web_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_sns_topic.anomaly_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.anomaly_alerts_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.email_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.s3_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws_region](#input_aws_region) | AWS region para desplegar recursos | `string` | `"us-east-1"` | no |
| <a name="input_bedrock_model_id"></a> [bedrock_model_id](#input_bedrock_model_id) | ID del modelo de Bedrock | `string` | `"anthropic.claude-3-5-sonnet-20240620-v1:0"` | no |
| <a name="input_bucket_name"></a> [bucket_name](#input_bucket_name) | S3 Bucket Name | `string` | n/a | yes |
| <a name="input_email"></a> [email](#input_email) | Email principal para recibir alertas | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance_type](#input_instance_type) | Tipo de instancia EC2 | `string` | `"t3.micro"` | no |
| <a name="input_key_pair_name"></a> [key_pair_name](#input_key_pair_name) | Nombre del key pair para instancias EC2 | `string` | n/a | yes |
| <a name="input_lambda_name"></a> [lambda_name](#input_lambda_name) | Nombre de la función Lambda (para construir el nombre del log group). | `string` | `"anomaly-detection-function"` | no |
| <a name="input_private_subnet_cidr"></a> [private_subnet_cidr](#input_private_subnet_cidr) | CIDR block para subnet privada | `string` | `"10.0.2.0/24"` | no |
| <a name="input_public_subnet_cidr"></a> [public_subnet_cidr](#input_public_subnet_cidr) | CIDR block para subnet pública | `string` | `"10.0.1.0/24"` | no |
| <a name="input_vpc_cidr"></a> [vpc_cidr](#input_vpc_cidr) | CIDR block para VPC | `string` | `"10.0.0.0/16"` | no |

#### Outputs

| Name | Description |
|------|-------------|
| <a name="output_ai_integration_info"></a> [ai_integration_info](#output_ai_integration_info) | Información para integración con servicios de AI |
| <a name="output_architecture_summary"></a> [architecture_summary](#output_architecture_summary) | Resumen completo de la arquitectura desplegada |
| <a name="output_demo_instances"></a> [demo_instances](#output_demo_instances) | Información de las instancias para la demo |
<!-- END_TF_DOCS -->
