# Estructura Completa de Archivos Terraform

## 📁 Estructura de Directorios

```
anomaly-detection-terraform/
├── main.tf                           # Configuración principal
├── variables.tf                      # Variables de entrada
├── terraform.tfvars.example          # Ejemplo de variables
├── outputs.tf                        # Outputs del proyecto
├── README.md                         # Documentación del proyecto
├── scripts/
│   ├── deploy.sh                     # Script de despliegue
│   ├── destroy.sh                    # Script de destrucción
│   └── demo.sh                       # Script para ejecutar demo
└── modules/
    ├── vpc/
    │   ├── main.tf                   # Recursos VPC y networking
    │   ├── variables.tf              # Variables del módulo
    │   └── outputs.tf                # Outputs del módulo
    ├── storage/
    │   ├── main.tf                   # S3 buckets y configuración
    │   ├── variables.tf              # Variables del módulo
    │   └── outputs.tf                # Outputs del módulo
    ├── analytics/
    │   ├── main.tf                   # Athena, Glue, queries
    │   ├── variables.tf              # Variables del módulo
    │   └── outputs.tf                # Outputs del módulo
    ├── processing/
    │   ├── main.tf                   # Lambda function y IAM
    │   ├── lambda_function.py        # Código de la función Lambda
    │   ├── requirements.txt          # Dependencias Python
    │   ├── variables.tf              # Variables del módulo
    │   └── outputs.tf                # Outputs del módulo
    ├── alerting/
    │   ├── main.tf                   # SNS topics y subscriptions
    │   ├── variables.tf              # Variables del módulo
    │   └── outputs.tf                # Outputs del módulo
    ├── demo/
    │   ├── main.tf                   # Instancias EC2 para demo
    │   ├── variables.tf              # Variables del módulo
    │   └── outputs.tf                # Outputs del módulo
    └── automation/
        ├── main.tf                   # EventBridge rules y triggers
        ├── variables.tf              # Variables del módulo
        └── outputs.tf                # Outputs del módulo
```

## 📋 Archivos Restantes Necesarios

### `terraform.tfvars.example`
```hcl
# Copia este archivo como terraform.tfvars y ajusta los valores

# Configuración básica
aws_region = "us-east-1"
notification_email = "tu-email@ejemplo.com"
key_pair_name = "tu-keypair"

# Configuración de red
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"

# Configuración de instancias
instance_type = "t3.micro"

# Configuración de análisis
analysis_frequency_minutes = 5
flow_logs_retention_days = 30
```

### `outputs.tf`
```hcl
# outputs.tf
output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.vpc.vpc_id
}

output "flow_logs_bucket" {
  description = "Nombre del bucket de Flow Logs"
  value       = module.storage.bucket_name
}

output "athena_database" {
  description = "Base de datos de Athena"
  value       = module.analytics.database_name
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = module.processing.lambda_function_name
}

output "sns_topic_arn" {
  description = "ARN del topic de SNS"
  value       = module.alerting.topic_arn
}

output "demo_instances" {
  description = "Información de las instancias de demo"
  value       = module.demo_instances.demo_info
  sensitive   = true
}

output "architecture_summary" {
  description = "Resumen de la arquitectura desplegada"
  value = {
    region = var.aws_region
    vpc_cidr = var.vpc_cidr
    components_deployed = [
      "VPC with Flow Logs",
      "S3 Storage",
      "Athena Analytics", 
      "Lambda Processing",
      "SNS Alerting",
      "Demo Instances",
      "EventBridge Automation"
    ]
    estimated_monthly_cost = "$8-15 USD"
    demo_ready = true
  }
}
```

### Variables para Módulos

#### `modules/vpc/variables.tf`
```hcl
variable "vpc_cidr" {
  description = "CIDR block para VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block para subnet pública"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block para subnet privada"
  type        = string
}

variable "availability_zone" {
  description = "Zona de disponibilidad"
  type        = string
}

variable "bucket_arn" {
  description = "ARN del bucket S3 para Flow Logs"
  type        = string
}

variable "tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}
```

#### `modules/vpc/outputs.tf`
```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "web_security_group_id" {
  value = aws_security_group.web.id
}

output "attack_security_group_id" {
  value = aws_security_group.attack_simulator.id
}
```

### Scripts de Automatización

#### `scripts/deploy.sh`
```bash
#!/bin/bash

set -e

echo "🚀 Desplegando Arquitectura de Detección de Anomalías"
echo "=================================================="

# Verificar prerrequisitos
echo "✅ Verificando prerrequisitos..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform no está instalado"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado"
    exit 1
fi

# Verificar credenciales AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciales AWS no configuradas"
    exit 1
fi

# Verificar archivo de variables
if [[ ! -f "terraform.tfvars" ]]; then
    echo "❌ Archivo terraform.tfvars no encontrado"
    echo "💡 Copia terraform.tfvars.example y configura tus valores"
    exit 1
fi

# Inicializar Terraform
echo "🔧 Inicializando Terraform..."
terraform init

# Validar configuración
echo "🔍 Validando configuración..."
terraform validate

# Mostrar plan
echo "📋 Generando plan de ejecución..."
terraform plan -out=tfplan

# Confirmar despliegue
read -p "¿Continuar con el despliegue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Despliegue cancelado"
    exit 1
fi

# Aplicar cambios
echo "🚀 Desplegando recursos..."
terraform apply tfplan

# Mostrar outputs importantes
echo "✅ ¡Despliegue completado!"
echo "========================"
terraform output architecture_summary

echo ""
echo "🎯 Próximos pasos:"
echo "1. Espera 2-3 minutos para que Flow Logs se activen"
echo "2. Usa 'bash scripts/demo.sh' para ejecutar la demo"
echo "3. Revisa tu email para las alertas"

echo ""
echo "💰 Recuerda: Esta demo tiene costos asociados"
echo "🗑️  Usa 'bash scripts/destroy.sh' para limpiar recursos"
```

#### `scripts/demo.sh`
```bash
#!/bin/bash

echo "🎬 Ejecutando Demo de Detección de Anomalías"
echo "==========================================="

# Obtener información de las instancias
ATTACK_IP=$(terraform output -raw demo_instances | jq -r '.attack_simulator_public_ip')
WEB_IP=$(terraform output -raw demo_instances | jq -r '.web_server_private_ip')

if [[ -z "$ATTACK_IP" || "$ATTACK_IP" == "null" ]]; then
    echo "❌ No se puede obtener la IP del simulador de ataques"
    echo "💡 Asegúrate de que los recursos estén desplegados"
    exit 1
fi

echo "🎯 Instancias configuradas:"
echo "   - Simulador de ataques: $ATTACK_IP"
echo "   - Servidor web objetivo: $WEB_IP"
echo ""

# Función para ejecutar comandos SSH
run_attack() {
    local attack_type=$1
    local description=$2
    
    echo "🔥 Ejecutando: $description"
    echo "   Comando: ./attack_controller.sh $attack_type"
    echo "   Duración: ~2 minutos"
    echo ""
    
    # Nota: Requiere que tengas la clave SSH configurada
    echo "📝 Para ejecutar manualmente:"
    echo "   ssh -i tu-clave.pem ec2-user@$ATTACK_IP"
    echo "   ./attack_controller.sh $attack_type"
    echo ""
}

echo "🎭 Escenarios de Demo Disponibles:"
echo "================================"
echo ""

run_attack "port" "Port Scanning Attack"
run_attack "ddos" "DDoS Attack Simulation" 
run_attack "exfil" "Data Exfiltration Simulation"
run_attack "all" "Todos los ataques secuencialmente"

echo "⏱️  Cronología sugerida para la demo:"
echo "1. Mostrar tráfico normal (CloudWatch)"
echo "2. Ejecutar port scan (2 min)"
echo "3. Esperar alertas (~3-5 min)"
echo "4. Mostrar análisis de Bedrock"
echo "5. Ejecutar DDoS (2 min)"
echo "6. Mostrar nuevas alertas"
echo "7. Discutir costos y escalabilidad"
echo ""

echo "📊 Monitoreo:"
echo "- CloudWatch Logs: /aws/lambda/anomaly-detection-processor"
echo "- Flow Logs: S3 bucket con prefijo AWSLogs/"
echo "- Athena Queries: Consola de Athena"
echo "- Alertas: Tu email configurado"
echo ""

echo "🛑 Para detener ataques:"
echo "   ssh -i tu-clave.pem ec2-user@$ATTACK_IP"
echo "   ./attack_controller.sh stop"
```

#### `scripts/destroy.sh`
```bash
#!/bin/bash

echo "🗑️  Destruyendo Recursos de Demo"
echo "==============================="

echo "⚠️  ADVERTENCIA: Esto eliminará TODOS los recursos creados"
echo "   - VPC y subnets"
echo "   - Instancias EC2"
echo "   - Buckets S3 y contenido"
echo "   - Funciones Lambda"
echo "   - Topics SNS"
echo "   - Todos los datos de Flow Logs"
echo ""

read -p "¿Estás seguro de que quieres continuar? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Operación cancelada"
    exit 1
fi

echo "🧹 Limpiando recursos..."

# Eliminar recursos con Terraform
terraform destroy -auto-approve

echo "✅ Recursos eliminados exitosamente"
echo ""
echo "💡 Recuerda:"
echo "   - Los logs de CloudWatch pueden tardar en eliminarse"
echo "   - Verifica que no queden recursos huérfanos en la consola"
echo "   - Los buckets S3 se eliminaron con todo su contenido"
```

### `requirements.txt` para Lambda
```txt
boto3>=1.26.0
botocore>=1.29.0
```

## 🚀 Instrucciones de Despliegue

### 1. Preparación
```bash
# Clonar o crear el directorio del proyecto
mkdir anomaly-detection-terraform
cd anomaly-detection-terraform

# Crear todos los archivos según la estructura
# Configurar variables
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con tus valores
```

### 2. Verificar Prerrequisitos
- ✅ Terraform >= 1.0 instalado
- ✅ AWS CLI configurado con credenciales
- ✅ Key pair EC2 creado en la región de despliegue
- ✅ Región con Amazon Bedrock habilitado (us-east-1, us-west-2, etc.)
- ✅ Email válido para notificaciones

### 3. Despliegue
```bash
# Hacer ejecutables los scripts
chmod +x scripts/*.sh

# Ejecutar despliegue
./scripts/deploy.sh
```

### 4. Ejecutar Demo
```bash
# Esperar 2-3 minutos después del despliegue
./scripts/demo.sh

# Conectarse al simulador de ataques
ssh -i tu-clave.pem ec2-user@<IP_PUBLICA>

# Ejecutar ataques
./attack_controller.sh all
```

### 5. Limpieza
```bash
# Eliminar todos los recursos
./scripts/destroy.sh
```

## 🎯 Checklist de Demo

### Pre-Demo (5 minutos)
- [ ] Recursos desplegados correctamente
- [ ] Flow Logs activos (verificar en VPC console)
- [ ] Email de notificaciones confirmado
- [ ] Conexión SSH al simulador funcionando
- [ ] CloudWatch console abierto
- [ ] Athena console preparado

### Durante la Demo (20 minutos)

#### Fase 1: Mostrar Arquitectura (3 min)
- [ ] Explicar diagrama de arquitectura
- [ ] Mostrar recursos en AWS console
- [ ] Explicar flujo de datos

#### Fase 2: Tráfico Normal (2 min)
- [ ] Mostrar Flow Logs llegando a S3
- [ ] Ejecutar query básica en Athena
- [ ] Mostrar que no hay alertas

#### Fase 3: Port Scanning Attack (5 min)
- [ ] Ejecutar: `./attack_controller.sh port`
- [ ] Mostrar logs en CloudWatch
- [ ] Esperar alerta por email
- [ ] Mostrar análisis de Bedrock

#### Fase 4: DDoS Attack (5 min)
- [ ] Ejecutar: `./attack_controller.sh ddos`
- [ ] Mostrar diferente patrón en logs
- [ ] Nueva alerta con análisis diferente

#### Fase 5: Wrap-up (5 min)
- [ ] Mostrar queries de Athena
- [ ] Explicar costos (~$10/mes)
- [ ] Discutir escalabilidad
- [ ] Q&A

### Post-Demo
- [ ] Detener ataques: `./attack_controller.sh stop`
- [ ] Limpiar recursos si es necesario

## 💡 Tips para la Presentación

### Puntos Clave a Destacar
1. **Sin ML expertise**: Solo SQL y configuración
2. **Bajo costo**: ~$8-15/mes para monitoreo continuo
3. **Serverless**: Escala automáticamente
4. **IA explicativa**: Bedrock hace el análisis comprensible
5. **Tiempo real**: Detección en < 5 minutos

### Posibles Preguntas y Respuestas

**P: ¿Qué pasa con falsos positivos?**
R: Se pueden ajustar los umbrales en las queries y usar ML más avanzado para reducirlos.

**P: ¿Escala para empresas grandes?**
R: Sí, Athena y Lambda escalan automáticamente. Solo pagas por lo que usas.

**P: ¿Se puede integrar con otros sistemas?**
R: Absolutamente. SNS puede enviar a Slack, PagerDuty, SIEM, etc.

**P: ¿Qué otros tipos de ataques detecta?**
R: Se pueden agregar fácilmente nuevas queries para lateral movement, reconnaissance, etc.

### Demos Adicionales (si hay tiempo)
- Mostrar integración con Slack
- Crear dashboard en CloudWatch
- Mostrar respuesta automática (bloquear IP)

## 📊 Métricas de Éxito de la Demo

### Técnicas
- ✅ Flow Logs generándose < 2 minutos
- ✅ Queries de Athena ejecutando < 30 segundos
- ✅ Lambda procesando < 5 minutos
- ✅ Alertas llegando < 7 minutos total

### Engagement
- ✅ Audiencia entiende la arquitectura
- ✅ Preguntas técnicas relevantes
- ✅ Interés en implementación
- ✅ Solicitudes de código/slides

## 🛠️ Troubleshooting Común

### Flow Logs no aparecen
- Verificar IAM role permissions
- Revisar bucket policy
- Esperar hasta 10 minutos para primeros logs

### Athena queries fallan
- Verificar permisos de S3
- Comprobar formato de particiones
- Revisar sintaxis SQL

### Lambda timeout
- Aumentar timeout a 900 segundos
- Verificar permisos de Bedrock
- Revisar logs de CloudWatch

### Bedrock no disponible
- Verificar región (us-east-1, us-west-2)
- Solicitar acceso a modelos
- Usar fallback sin IA

### No llegan alertas
- Verificar suscripción SNS confirmada
- Revisar spam/filtros email
- Comprobar permisos de Lambda para SNS

## 📈 Extensiones Post-Demo

### Mejoras Técnicas
1. **Dashboard tiempo real** con CloudWatch/Grafana
2. **ML customizado** con SageMaker
3. **Respuesta automática** con Lambda + WAF
4. **Multi-account** con Organizations
5. **Compliance reporting** automatizado

### Integraciones Empresariales
1. **SIEM integration** (Splunk, QRadar)
2. **Ticketing** (Jira, ServiceNow) 
3. **Chat ops** (Slack, Teams)
4. **Mobile alerts** (PagerDuty)
5. **Threat intelligence** feeds

---

**🎬 ¡Tu demo está lista para impresionar!**

Esta arquitectura demuestra cómo combinar servicios AWS nativos con IA generativa para crear una solución de seguridad práctica, escalable y de bajo costo. Perfect para community talks donde quieres mostrar el poder de la nube + IA aplicada a problemas reales.