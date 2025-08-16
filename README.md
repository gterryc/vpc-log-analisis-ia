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
| <a name="requirement_aws"></a> [aws](#requirement_aws) | >=5.0.0 |

#### Providers

No providers.

#### Resources

No resources.

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws_region](#input_aws_region) | AWS region | `string` | `"us-east-1"` | no |

#### Outputs

No outputs.
<!-- END_TF_DOCS -->