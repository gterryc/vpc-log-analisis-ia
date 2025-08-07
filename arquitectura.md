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

## 📋 Paso a Paso de Implementación

### **Fase 1: Configuración Base de Red (15 min)**

#### 1.1 Crear VPC y Subnets
```hcl
# Variables principales
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
```

#### 1.2 Habilitar VPC Flow Logs
- Destino: S3 bucket
- Formato: Personalizado para optimizar análisis
- Frecuencia: 1 minuto (para demo rápida)

#### 1.3 Desplegar instancias EC2
- **App Server**: Genera tráfico normal (nginx + script)
- **Attack Simulator**: Simula diferentes tipos de ataques

### **Fase 2: Configuración de Almacenamiento (10 min)**

#### 2.1 Crear S3 Bucket
```bash
# Estructura del bucket
anomaly-detection-flowlogs-{random}/
├── year=2024/
│   ├── month=01/
│   │   ├── day=15/
│   │   │   └── hour=14/
│   │   └── └── flow-logs-*.gz
```

#### 2.2 Configurar Lifecycle Policies
- Transición a IA después de 30 días
- Eliminación después de 90 días

### **Fase 3: Configuración de Análisis (20 min)**

#### 3.1 Crear tabla en Athena
```sql
CREATE EXTERNAL TABLE vpc_flow_logs (
  version int,
  account_id string,
  interface_id string,
  srcaddr string,
  dstaddr string,
  srcport int,
  dstport int,
  protocol int,
  packets bigint,
  bytes bigint,
  windowstart bigint,
  windowend bigint,
  action string
)
PARTITIONED BY (
  year string,
  month string,
  day string,
  hour string
)
STORED AS PARQUET
LOCATION 's3://your-bucket/partitioned-flow-logs/'
```

#### 3.2 Queries de Detección de Anomalías
```sql
-- 1. Port Scanning Detection
SELECT srcaddr, COUNT(DISTINCT dstport) as unique_ports
FROM vpc_flow_logs 
WHERE action = 'REJECT'
GROUP BY srcaddr
HAVING unique_ports > 100;

-- 2. DDoS Detection  
SELECT dstaddr, SUM(packets) as total_packets
FROM vpc_flow_logs
WHERE windowstart > unix_timestamp() - 300
GROUP BY dstaddr
HAVING total_packets > 100000;

-- 3. Data Exfiltration
SELECT srcaddr, SUM(bytes) as total_bytes
FROM vpc_flow_logs 
WHERE action = 'ACCEPT' AND srcport IN (80,443)
GROUP BY srcaddr
HAVING total_bytes > 1000000000;
```

### **Fase 4: Función Lambda de Procesamiento (25 min)**

#### 4.1 Lambda para Análisis de Anomalías
```python
import boto3
import json
from datetime import datetime, timedelta

def lambda_handler(event, context):
    # 1. Ejecutar queries de Athena
    # 2. Procesar resultados
    # 3. Invocar Bedrock si hay anomalías
    # 4. Enviar alertas via SNS
    pass
```

#### 4.2 Integración con Bedrock
```python
def analyze_with_bedrock(anomaly_data):
    prompt = f"""
    Analiza el siguiente tráfico de red anómalo y proporciona:
    1. Explicación clara del problema
    2. Nivel de severidad (1-10)
    3. Acciones recomendadas
    4. Posible tipo de ataque
    
    Datos: {anomaly_data}
    """
    # Invocar modelo Claude en Bedrock
```

### **Fase 5: Sistema de Alertas (15 min)**

#### 5.1 Configurar SNS Topic
- Email notifications
- Formato estructurado de alertas
- Integración con Slack (opcional)

#### 5.2 Template de Alerta
```json
{
  "timestamp": "2024-01-15T14:30:00Z",
  "severity": "HIGH",
  "anomaly_type": "Port Scanning",
  "source_ip": "203.0.113.5",
  "ai_analysis": "Detectado escaneo masivo de puertos...",
  "recommended_actions": ["Bloquear IP", "Revisar logs", "Verificar firewall"]
}
```

### **Fase 6: Automatización y Monitoreo (10 min)**

#### 6.1 EventBridge Rules
- Ejecución cada 5 minutos
- Triggers basados en métricas
- Recuperación automática

#### 6.2 CloudWatch Dashboards
- Métricas de tráfico en tiempo real
- Estado de componentes
- Costos del sistema

## 💻 Scripts de Simulación para la Demo

### Simulador de Tráfico Normal
```bash
#!/bin/bash
# normal_traffic.sh
while true; do
  curl -s http://internal-app:80 > /dev/null
  sleep $((RANDOM % 10 + 1))
done
```

### Simulador de Port Scanning
```python
# port_scanner.py
import socket
import threading

def scan_port(target, port):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.1)
        result = sock.connect_ex((target, port))
        sock.close()
    except:
        pass

target = "10.0.1.100"
for port in range(1, 65535):
    threading.Thread(target=scan_port, args=(target, port)).start()
```

### Simulador de DDoS
```bash
#!/bin/bash
# ddos_simulator.sh
target="10.0.1.100"
for i in {1..1000}; do
  (while true; do
    curl -s http://$target > /dev/null 2>&1
  done) &
done
```

## 📊 Métricas y KPIs para la Demo

### Métricas Técnicas
- **Latencia de detección**: < 5 minutos
- **Precisión de alertas**: > 95%
- **Costo por análisis**: < $0.01 USD
- **Throughput**: 1M+ registros/hora

### Métricas de Negocio  
- **MTTR** (Mean Time To Response): < 2 minutos
- **Falsos positivos**: < 5%
- **Cobertura de amenazas**: 8 tipos diferentes

## 🎯 Puntos Clave para la Presentación

### **Demo Flow (20 minutos)**
1. **Mostrar tráfico normal** (2 min)
2. **Activar simulador de ataques** (3 min)
3. **Visualizar detección en CloudWatch** (5 min)
4. **Mostrar análisis de Bedrock** (5 min)  
5. **Recibir alerta y explicación** (3 min)
6. **Discutir costos y escalabilidad** (2 min)

### **Ventajas Competitivas**
- ✅ **Sin ML expertise requerida**
- ✅ **Costo ultra bajo** (~$5-10/mes)
- ✅ **Explicaciones humanas** via IA
- ✅ **Escalamiento automático**
- ✅ **Implementación en < 2 horas**

### **Casos de Uso Reales**
- Detección de intrusiones
- Compliance y auditoría
- Análisis forense de incidentes
- Optimización de costos de red
- Monitoreo de aplicaciones críticas

## 💡 Tips para la Implementación

1. **Usar regiones con Bedrock disponible** (us-east-1, us-west-2)
2. **Configurar límites de costo** en AWS Budgets
3. **Probar con datos sintéticos** primero
4. **Documentar todos los queries** de Athena
5. **Preparar rollback plan** para la demo

## 🔄 Próximos Pasos Post-Demo

1. **Integración con SIEM** existente
2. **ML customizado** para patrones específicos  
3. **Respuesta automática** (bloqueo de IPs)
4. **Dashboard ejecutivo** con métricas
5. **Multi-account** deployment

---

**Tiempo total estimado de implementación: 95 minutos**  
**Costo mensual estimado: $8-15 USD**  
**Nivel de dificultad: Intermedio**