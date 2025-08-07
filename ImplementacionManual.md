# 🛠️ Guía Manual: Detección de Anomalías en AWS Console

## ⏱️ Tiempo Total Estimado: 60-90 minutos

---

## 📋 **FASE 1: PREPARACIÓN (5 minutos)**

### 1.1 Verificar Prerrequisitos
- ✅ Cuenta AWS con permisos administrativos
- ✅ Región con Bedrock disponible (us-east-1, us-west-2, eu-west-1)
- ✅ Email válido para notificaciones
- ✅ Key Pair EC2 creado en la región

### 1.2 Activar Amazon Bedrock (CRÍTICO)
1. Ve a **Amazon Bedrock** en la consola
2. Clic en **Model access** (lado izquierdo)
3. Clic **Enable specific models**
4. Buscar y habilitar: **Anthropic Claude 3 Sonnet**
5. **Submit** y esperar aprobación (~2-5 minutos)

### 1.2.1 Acceder a Bedrock Console
1. Ve a **Amazon Bedrock** en la consola AWS
2. **IMPORTANTE**: Asegúrate de estar en una región compatible:
   - ✅ `us-east-1` (Virginia del Norte) 
   - ✅ `us-west-2` (Oregón)
   - ✅ `eu-west-1` (Irlanda)

### 1.2.2 Solicitar Acceso a Modelos
1. En Bedrock Console → **Model access** (menú izquierdo)
2. Clic **Manage model access**
3. Buscar **Anthropic** → Expandir
4. ✅ Marcar **Claude 3 Sonnet**
5. **Next** → **Submit**
6. **⏳ ESPERAR**: La aprobación puede tomar 2-10 minutos

### 1.2.3 Verificar Acceso (IMPORTANTE)
1. Una vez aprobado, verás **Access granted** ✅
2. Anotar el **Model ID**: `anthropic.claude-3-sonnet-20240229-v1:0`
3. **Probar invocación**:
   - En Bedrock Console → **Playgrounds** → **Chat**
   - Seleccionar Claude 3 Sonnet
   - Escribir: "Hola, ¿funcionas?"
   - Si responde → ✅ Listo para usar

---

## 🌐 **FASE 2: CREAR INFRAESTRUCTURA DE RED (15 minutos)**

### 2.1 Crear VPC
1. **VPC Console** → **Create VPC**
2. Configuración:
   ```
   Name: anomaly-detection-vpc
   IPv4 CIDR: 10.0.0.0/16
   IPv6 CIDR: No IPv6 CIDR block
   Tenancy: Default
   ```
3. **Create VPC**

### 2.2 Crear Subnets
**Subnet Pública:**
1. **Subnets** → **Create subnet**
2. Configuración:
   ```
   VPC: anomaly-detection-vpc
   Name: public-subnet
   AZ: us-east-1a (o primera disponible)
   IPv4 CIDR: 10.0.1.0/24
   ```

**Subnet Privada:**
1. **Create subnet** (otra vez)
2. Configuración:
   ```
   VPC: anomaly-detection-vpc
   Name: private-subnet
   AZ: us-east-1a (misma que pública)
   IPv4 CIDR: 10.0.2.0/24
   ```

### 2.3 Crear Internet Gateway
1. **Internet Gateways** → **Create internet gateway**
2. Name: `anomaly-detection-igw`
3. **Create** → **Attach to VPC** → Seleccionar tu VPC

### 2.4 Crear NAT Gateway
1. **NAT Gateways** → **Create NAT gateway**
2. Configuración:
   ```
   Name: anomaly-detection-nat
   Subnet: public-subnet
   Connectivity: Public
   Elastic IP: Allocate Elastic IP
   ```

### 2.5 Configurar Route Tables
**Route Table Pública:**
1. **Route Tables** → Encontrar RT de subnet pública
2. **Routes** → **Edit routes** → **Add route**
   ```
   Destination: 0.0.0.0/0
   Target: Internet Gateway (tu IGW)
   ```
3. **Save changes**

**Route Table Privada:**
1. **Route Tables** → Encontrar RT de subnet privada
2. **Routes** → **Edit routes** → **Add route**
   ```
   Destination: 0.0.0.0/0
   Target: NAT Gateway (tu NAT)
   ```

### 2.6 Crear Security Groups
**Web Server Security Group:**
1. **Security Groups** → **Create security group**
2. Configuración:
   ```
   Name: web-server-sg
   Description: Security group for web server
   VPC: anomaly-detection-vpc
   
   Inbound Rules:
   - Type: HTTP, Port: 80, Source: 10.0.0.0/16
   - Type: HTTPS, Port: 443, Source: 10.0.0.0/16
   - Type: SSH, Port: 22, Source: 10.0.0.0/16
   - Type: All TCP, Port: 1-65535, Source: 10.0.0.0/16 (para demo)
   
   Outbound Rules: 
   - Type: All traffic, Destination: 0.0.0.0/0
   ```

**Attack Simulator Security Group:**
1. **Create security group**
2. Configuración:
   ```
   Name: attack-simulator-sg
   Description: Security group for attack simulator
   VPC: anomaly-detection-vpc
   
   Inbound Rules:
   - Type: SSH, Port: 22, Source: 0.0.0.0/0
   
   Outbound Rules:
   - Type: All traffic, Destination: 0.0.0.0/0
   ```

---

## 📦 **FASE 3: CONFIGURAR ALMACENAMIENTO S3 (10 minutos)**

### 3.1 Crear Bucket para Flow Logs
1. **S3 Console** → **Create bucket**
2. Configuración:
   ```
   Bucket name: anomaly-detection-flowlogs-[RANDOM] 
   (usar timestamp: anomaly-detection-flowlogs-20241201)
   Region: us-east-1 (misma que VPC)
   Block all public access: ✅ (habilitado)
   Bucket versioning: Enable
   Default encryption: Enable (SSE-S3)
   ```
3. **Create bucket**

### 3.2 Crear Bucket para Resultados de Athena
1. **Create bucket**
2. Configuración:
   ```
   Bucket name: anomaly-detection-athena-results-[RANDOM]
   Region: us-east-1
   Block all public access: ✅
   Bucket versioning: Enable
   Default encryption: Enable (SSE-S3)
   ```

### 3.3 Configurar Lifecycle Policies
**Para Flow Logs Bucket:**
1. Seleccionar bucket → **Management** → **Create lifecycle rule**
2. Configuración:
   ```
   Rule name: flow-logs-lifecycle
   Apply to all objects: ✅
   
   Lifecycle rule actions:
   - Transition current versions: 30 days → Standard-IA
   - Transition current versions: 60 days → Glacier
   - Delete current versions: 90 days
   - Delete noncurrent versions: 30 days
   ```

---

## 🔄 **FASE 4: HABILITAR VPC FLOW LOGS (5 minutos)**

### 4.1 Crear IAM Role para Flow Logs
1. **IAM Console** → **Roles** → **Create role**
2. **AWS Service** → **VPC - Flow Logs**
3. Role name: `flowlogsRole`
4. **Create role**

### 4.2 Habilitar Flow Logs
1. **VPC Console** → **Your VPCs**
2. Seleccionar tu VPC → **Flow logs** → **Create flow log**
3. Configuración:
   ```
   Filter: All
   Destination: Send to S3 bucket
   S3 bucket ARN: arn:aws:s3:::tu-bucket-flowlogs
   Log record format: Custom format
   Format: ${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${windowstart} ${windowend} ${action} ${flow-log-status}
   ```
4. **Create flow log**

---

## 📊 **FASE 5: CONFIGURAR ATHENA Y GLUE (15 minutos)**

### 5.1 Crear Database en Glue
1. **AWS Glue Console** → **Databases** → **Add database**
2. Database name: `vpc_flow_logs_db`
3. **Create**

### 5.2 Configurar Athena Workgroup
1. **Athena Console** → **Workgroups** → **Create workgroup**
2. Configuración:
   ```
   Name: anomaly-detection-workgroup
   Query result location: s3://tu-bucket-athena-results/
   Encrypt query results: ✅
   ```

### 5.3 Crear Tabla en Athena
1. **Athena Console** → **Query editor**
2. Seleccionar workgroup creado
3. Ejecutar esta query (reemplazar BUCKET_NAME):

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
  action string,
  flow_log_status string
)
PARTITIONED BY (
  year string,
  month string,
  day string,
  hour string
)
STORED AS PARQUET
LOCATION 's3://TU-BUCKET-FLOWLOGS/AWSLogs/'
TBLPROPERTIES (
  "projection.enabled"="true",
  "projection.year.type"="integer",
  "projection.year.range"="2020,2030",
  "projection.month.type"="integer",
  "projection.month.range"="1,12",
  "projection.month.digits"="2",
  "projection.day.type"="integer", 
  "projection.day.range"="1,31",
  "projection.day.digits"="2",
  "projection.hour.type"="integer",
  "projection.hour.range"="0,23",
  "projection.hour.digits"="2",
  "storage.location.template"="s3://TU-BUCKET-FLOWLOGS/AWSLogs/ACCOUNT-ID/vpcflowlogs/us-east-1/${year}/${month}/${day}/"
)
```

---

## 📧 **FASE 6: CONFIGURAR SISTEMA DE ALERTAS SNS (5 minutos)**

### 6.1 Crear SNS Topic
1. **SNS Console** → **Topics** → **Create topic**
2. Configuración:
   ```
   Type: Standard
   Name: anomaly-detection-alerts
   Display name: Anomaly Detection Alerts
   ```

### 6.2 Crear Subscription
1. En el topic creado → **Create subscription**
2. Configuración:
   ```
   Protocol: Email
   Endpoint: tu-email@ejemplo.com
   ```
3. **Confirmar suscripción** en tu email

---

## 🤖 **FASE 7: CREAR FUNCIÓN LAMBDA (20 minutos)**

### 7.1 Crear IAM Role para Lambda
1. **IAM Console** → **Roles** → **Create role**
2. **AWS Service** → **Lambda**
3. Adjuntar políticas:
   - `AWSLambdaBasicExecutionRole`
   - Crear política personalizada:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "athena:StartQueryExecution",
                "athena:GetQueryExecution", 
                "athena:GetQueryResults",
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket",
                "glue:GetDatabase",
                "glue:GetTable",
                "bedrock:InvokeModel",
                "sns:Publish"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream"
            ],
            "Resource": [
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:ListFoundationModels",
                "bedrock:GetFoundationModel"
            ],
            "Resource": "*"
        }   
    ]
}
```

4. Role name: `anomaly-detection-lambda-role`

### 7.2 Crear Función Lambda
1. **Lambda Console** → **Create function**
2. Configuración:
   ```
   Function name: anomaly-detection-processor
   Runtime: Python 3.11
   Role: anomaly-detection-lambda-role
   Timeout: 5 minutes
   Memory: 512 MB
   ```

### 7.3 Código Lambda
Copiar este código en el editor:

```python
import json
import boto3
import time
from datetime import datetime

# Clients
athena_client = boto3.client('athena')
bedrock_client = boto3.client('bedrock-runtime')
sns_client = boto3.client('sns')

# Configuration (CAMBIAR ESTOS VALORES)
DATABASE_NAME = 'vpc_flow_logs_db'
TABLE_NAME = 'vpc_flow_logs'
RESULTS_BUCKET = 'TU-BUCKET-ATHENA-RESULTS'
SNS_TOPIC_ARN = 'arn:aws:sns:us-east-1:ACCOUNT:anomaly-detection-alerts'
BEDROCK_MODEL_ID = 'anthropic.claude-3-sonnet-20240229-v1:0'

def lambda_handler(event, context):
    print("🔍 Iniciando detección de anomalías con IA...")
    
    try:
        anomalies_detected = []
        
        # 1. Port Scanning Detection
        print("🔎 Analizando port scanning...")
        port_scan_query = f"""
        SELECT srcaddr, COUNT(DISTINCT dstport) as unique_ports, 
               COUNT(*) as total_attempts,
               MIN(from_unixtime(windowstart)) as first_attempt,
               MAX(from_unixtime(windowend)) as last_attempt
        FROM {TABLE_NAME}
        WHERE action = 'REJECT' 
        AND windowstart > to_unixtime(current_timestamp - interval '1' hour)
        GROUP BY srcaddr
        HAVING COUNT(DISTINCT dstport) > 20
        ORDER BY unique_ports DESC
        LIMIT 5;
        """
        
        port_results = execute_athena_query(port_scan_query)
        if port_results:
            anomalies_detected.append({
                'type': 'Port Scanning',
                'severity': 'HIGH',
                'data': port_results
            })
        
        # 2. DDoS Detection
        print("🔎 Analizando DDoS attacks...")
        ddos_query = f"""
        SELECT dstaddr, SUM(packets) as total_packets, 
               COUNT(DISTINCT srcaddr) as unique_sources,
               SUM(bytes) as total_bytes,
               MIN(from_unixtime(windowstart)) as attack_start,
               MAX(from_unixtime(windowend)) as attack_end
        FROM {TABLE_NAME}
        WHERE action = 'ACCEPT'
        AND windowstart > to_unixtime(current_timestamp - interval '1' hour)
        GROUP BY dstaddr
        HAVING SUM(packets) > 50000 OR COUNT(DISTINCT srcaddr) > 50
        ORDER BY total_packets DESC
        LIMIT 5;
        """
        
        ddos_results = execute_athena_query(ddos_query)
        if ddos_results:
            anomalies_detected.append({
                'type': 'DDoS Attack',
                'severity': 'CRITICAL',
                'data': ddos_results
            })
            
        # 3. Data Exfiltration Detection
        print("🔎 Analizando data exfiltration...")
        exfil_query = f"""
        SELECT srcaddr, dstaddr, SUM(bytes) as total_bytes,
               COUNT(*) as connection_count,
               AVG(bytes) as avg_bytes_per_connection,
               MIN(from_unixtime(windowstart)) as first_connection,
               MAX(from_unixtime(windowend)) as last_connection
        FROM {TABLE_NAME}
        WHERE action = 'ACCEPT'
        AND dstport IN (80, 443, 21, 22)
        AND windowstart > to_unixtime(current_timestamp - interval '1' hour)
        GROUP BY srcaddr, dstaddr
        HAVING SUM(bytes) > 100000000  -- 100MB threshold
        ORDER BY total_bytes DESC
        LIMIT 5;
        """
        
        exfil_results = execute_athena_query(exfil_query)
        if exfil_results:
            anomalies_detected.append({
                'type': 'Data Exfiltration',
                'severity': 'HIGH',
                'data': exfil_results
            })
        
        # Procesar anomalías con Bedrock
        if anomalies_detected:
            print(f"🚨 Detectadas {len(anomalies_detected)} anomalías. Analizando con IA...")
            
            for anomaly in anomalies_detected:
                # AQUÍ ES DONDE ENTRA BEDROCK
                ai_analysis = analyze_with_bedrock(anomaly)
                anomaly['ai_analysis'] = ai_analysis
                
                # Enviar alerta con análisis de IA
                send_alert_with_ai(anomaly)
        else:
            print("✅ No se detectaron anomalías")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Análisis completado exitosamente',
                'anomalies_found': len(anomalies_detected),
                'timestamp': datetime.now().isoformat()
            })
        }
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        send_error_alert(str(e))
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def execute_athena_query(query):
    """Ejecuta query en Athena y retorna resultados"""
    try:
        response = athena_client.start_query_execution(
            QueryString=query,
            QueryExecutionContext={'Database': DATABASE_NAME},
            ResultConfiguration={'OutputLocation': f's3://{RESULTS_BUCKET}/'}
        )
        
        query_id = response['QueryExecutionId']
        print(f"🔄 Ejecutando query: {query_id}")
        
        # Wait for completion
        for i in range(60):  # 5 minutes max
            status = athena_client.get_query_execution(QueryExecutionId=query_id)
            state = status['QueryExecution']['Status']['State']
            
            if state == 'SUCCEEDED':
                print(f"✅ Query completada: {query_id}")
                break
            elif state in ['FAILED', 'CANCELLED']:
                error_reason = status['QueryExecution']['Status'].get('StateChangeReason', 'Unknown')
                print(f"❌ Query falló: {error_reason}")
                return None
            
            time.sleep(5)
        
        # Get results
        results = athena_client.get_query_results(QueryExecutionId=query_id)
        rows = results['ResultSet']['Rows']
        
        if len(rows) <= 1:
            return None
            
        # Parse results
        headers = [col['VarCharValue'] for col in rows[0]['Data']]
        data = []
        for row in rows[1:]:
            row_data = {}
            for i, cell in enumerate(row['Data']):
                row_data[headers[i]] = cell.get('VarCharValue', '')
            data.append(row_data)
        
        return data
        
    except Exception as e:
        print(f"❌ Error en query: {str(e)}")
        return None

def analyze_with_bedrock(anomaly):
    """
    🤖 AQUÍ ES DONDE BEDROCK ANALIZA LAS ANOMALÍAS
    Esta es la función clave que usa IA generativa
    """
    try:
        print(f"🤖 Analizando {anomaly['type']} con Bedrock...")
        
        # Crear prompt estructurado para Claude
        prompt = f"""
        Eres un experto en ciberseguridad analizando tráfico de red anómalo. 
        
        Analiza la siguiente anomalía detectada y proporciona:

        1. **Explicación técnica clara** del problema detectado
        2. **Nivel de severidad justificado** (1-10) con razones
        3. **Tipo de ataque probable** y vectores utilizados
        4. **Acciones inmediatas recomendadas** (top 3)
        5. **Medidas preventivas** a largo plazo
        6. **Indicadores adicionales** a monitorear

        **DATOS DE LA ANOMALÍA:**
        - Tipo: {anomaly['type']}
        - Severidad inicial: {anomaly['severity']}
        - Datos detectados: {json.dumps(anomaly['data'], indent=2)}

        Responde en español, sé conciso pero completo. Usa formato estructurado para facilitar la lectura.
        """
        
        # Preparar el request para Bedrock
        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1500,
            "messages": [
                {
                    "role": "user", 
                    "content": prompt
                }
            ],
            "temperature": 0.1,  # Baja temperatura para respuestas más consistentes
            "top_p": 0.9
        })
        
        # Invocar Bedrock
        response = bedrock_client.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=body,
            contentType='application/json',
            accept='application/json'
        )
        
        # Procesar respuesta
        response_body = json.loads(response['body'].read())
        ai_analysis = response_body['content'][0]['text']
        
        print(f"✅ Análisis IA completado para {anomaly['type']}")
        return ai_analysis
        
    except Exception as e:
        error_msg = f"Error en análisis de IA: {str(e)}"
        print(f"❌ {error_msg}")
        
        # Fallback: análisis básico sin IA
        fallback_analysis = f"""
        ⚠️ Análisis básico (IA no disponible):
        
        Tipo de anomalía: {anomaly['type']}
        Severidad: {anomaly['severity']}
        Instancias detectadas: {len(anomaly['data'])}
        
        Se recomienda investigación manual inmediata.
        Error de IA: {str(e)}
        """
        return fallback_analysis

def send_alert_with_ai(anomaly):
    """Envía alerta enriquecida con análisis de IA"""
    try:
        print(f"📧 Enviando alerta para {anomaly['type']}...")
        
        # Determinar emoji y urgencia según tipo
        emoji_map = {
            'Port Scanning': '🔍',
            'DDoS Attack': '💥',  
            'Data Exfiltration': '📤',
            'Unusual Protocol': '🔧'
        }
        
        emoji = emoji_map.get(anomaly['type'], '🚨')
        
        subject = f"{emoji} ALERTA CRÍTICA: {anomaly['type']} - Severidad {anomaly['severity']}"
        
        message = f"""
{emoji} ALERTA DE SEGURIDAD - ANÁLISIS CON IA {emoji}
===============================================

🕒 Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}
🎯 Tipo de Anomalía: {anomaly['type']}
⚠️  Severidad: {anomaly['severity']}
📊 Instancias detectadas: {len(anomaly['data'])}

🤖 ANÁLISIS DE INTELIGENCIA ARTIFICIAL:
{anomaly.get('ai_analysis', 'No disponible')}

📈 DATOS TÉCNICOS DETECTADOS:
{json.dumps(anomaly['data'], indent=2)}

---
🛡️ Este es un mensaje automático del Sistema de Detección de Anomalías
🤖 Análisis generado por Amazon Bedrock (Claude 3 Sonnet)
⏰ Tiempo de detección: < 5 minutos desde el evento

Para más detalles, revisar CloudWatch Logs del sistema.
"""
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        
        print(f"✅ Alerta enviada exitosamente para {anomaly['type']}")
        
    except Exception as e:
        print(f"❌ Error enviando alerta: {str(e)}")

def send_error_alert(error_message):
    """Envía notificación de error del sistema"""
    try:
        subject = "❌ Error en Sistema de Detección de Anomalías"
        message = f"""
🚫 ERROR EN EL SISTEMA 🚫
========================

🕒 Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}
❌ Error: {error_message}

🔍 Acciones recomendadas:
1. Revisar logs de CloudWatch
2. Verificar permisos de Bedrock
3. Comprobar conectividad de Athena
4. Validar configuración SNS

📍 Función Lambda: anomaly-detection-processor
🔗 CloudWatch Log Group: /aws/lambda/anomaly-detection-processor

Este sistema requiere atención inmediata.
"""
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        
    except Exception as e:
        print(f"❌ Error crítico enviando notificación de error: {str(e)}")

# Función de testing (opcional)
def test_bedrock_connection():
    """Prueba la conexión con Bedrock"""
    try:
        test_prompt = "Responde solo con 'OK' si puedes procesarme."
        
        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31", 
            "max_tokens": 10,
            "messages": [{"role": "user", "content": test_prompt}]
        })
        
        response = bedrock_client.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=body,
            contentType='application/json'
        )
        
        response_body = json.loads(response['body'].read())
        result = response_body['content'][0]['text']
        
        print(f"✅ Bedrock test: {result}")
        return True
        
    except Exception as e:
        print(f"❌ Bedrock test failed: {str(e)}")
        return False
```

### 7.4 Configurar Variables de Entorno
En la función Lambda → **Configuration** → **Environment variables**:
```
DATABASE_NAME = vpc_flow_logs_db
TABLE_NAME = vpc_flow_logs
RESULTS_BUCKET = tu-bucket-athena-results
SNS_TOPIC_ARN = arn:aws:sns:us-east-1:ACCOUNT:anomaly-detection-alerts
BEDROCK_MODEL_ID = anthropic.claude-3-sonnet-20240229-v1:0
AWS_REGION = us-east-1
```
### 7.5  Configuración de Lambda Actualizada
- **Timeout**: ⚠️ **Cambiar a 10 minutos** (600 segundos)
- **Memory**: ⚠️ **Cambiar a 1024 MB** (Bedrock necesita más memoria)

### 7.5.1 Test de Conexión Bedrock
1. En Lambda Console → **Test**
2. Crear evento de prueba:
```json
{
  "test": "bedrock_connection"
}
```
3. **Test** y revisar logs
4. ✅ Debe aparecer: "Bedrock test: OK"

### 7.5.2 Test de Análisis Completo
1. Evento de prueba:
```json
{
  "test": "full_analysis"
}
```
2. **Test** → Revisar CloudWatch Logs
3. ✅ Debe mostrar: "🤖 Analizando con Bedrock..."

---

## 🖥️ **FASE 8: CREAR INSTANCIAS EC2 PARA DEMO (15 minutos)**

### 8.1 Crear Instancia Web Server (Target)
1. **EC2 Console** → **Launch Instance**
2. Configuración:
   ```
   Name: demo-web-server
   AMI: Amazon Linux 2
   Instance type: t3.micro
   Key pair: tu-keypair
   VPC: anomaly-detection-vpc
   Subnet: private-subnet
   Security group: web-server-sg
   ```

3. **User Data** (en Advanced Details):
```bash
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

echo "<h1>Demo Web Server</h1><p>Timestamp: $(date)</p>" > /var/www/html/index.html

# Script para tráfico normal
cat > /home/ec2-user/normal_traffic.sh << 'EOF'
#!/bin/bash
while true; do
    curl -s http://localhost/ > /dev/null
    sleep $((RANDOM % 10 + 5))
done
EOF

chmod +x /home/ec2-user/normal_traffic.sh
nohup /home/ec2-user/normal_traffic.sh &
```

### 8.2 Crear Instancia Attack Simulator
1. **Launch Instance**
2. Configuración:
   ```
   Name: demo-attack-simulator
   AMI: Amazon Linux 2
   Instance type: t3.micro
   Key pair: tu-keypair
   VPC: anomaly-detection-vpc
   Subnet: public-subnet
   Security group: attack-simulator-sg
   Auto-assign public IP: Enable
   ```

3. **User Data**:
```bash
#!/bin/bash
yum update -y
yum install -y python3 nmap

# Port Scanner
cat > /home/ec2-user/port_scan.py << 'EOF'
import socket
import threading
import time
import sys

def scan_port(target, port):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.1)
        result = sock.connect_ex((target, port))
        sock.close()
    except:
        pass

def port_scan_attack(target, duration=300):
    print(f"Port scanning {target} for {duration} seconds")
    end_time = time.time() + duration
    
    while time.time() < end_time:
        for port in range(1, 1000):
            threading.Thread(target=scan_port, args=(target, port)).start()
            time.sleep(0.01)

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "10.0.2.100"
    port_scan_attack(target)
EOF

# DDoS Simulator
cat > /home/ec2-user/ddos_sim.py << 'EOF'
import threading
import socket
import time
import sys

def ddos_thread(target, port, duration):
    end_time = time.time() + duration
    while time.time() < end_time:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect((target, port))
            sock.send(b"GET / HTTP/1.1\r\nHost: " + target.encode() + b"\r\n\r\n")
            sock.close()
        except:
            pass
        time.sleep(0.001)

def ddos_attack(target, threads=50, duration=300):
    print(f"DDoS attack on {target} with {threads} threads for {duration} seconds")
    
    for i in range(threads):
        thread = threading.Thread(target=ddos_thread, args=(target, 80, duration))
        thread.daemon = True
        thread.start()
    
    time.sleep(duration)

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "10.0.2.100"
    ddos_attack(target)
EOF

chmod +x /home/ec2-user/*.py
chown ec2-user:ec2-user /home/ec2-user/*.py
```

---

## ⏰ **FASE 9: CONFIGURAR AUTOMATIZACIÓN EVENTBRIDGE (5 minutos)**

### 9.1 Crear EventBridge Rule
1. **EventBridge Console** → **Rules** → **Create rule**
2. Configuración:
   ```
   Name: anomaly-detection-scheduler
   Description: Ejecutar análisis cada 5 minutos
   Event bus: default
   Rule type: Schedule
   Schedule pattern: Rate expression
   Rate: rate(5 minutes)
   ```

### 9.2 Agregar Target
1. **Target type**: AWS service
2. **Service**: Lambda function
3. **Function**: anomaly-detection-processor

---

## 🧪 **FASE 10: TESTING Y VALIDACIÓN (15 minutos)**

### 10.1 Verificar Flow Logs
1. **S3 Console** → Tu bucket de Flow Logs
2. Verificar que aparezcan archivos en: `AWSLogs/ACCOUNT-ID/vpcflowlogs/us-east-1/YYYY/MM/DD/`
3. **Esperar 5-10 minutos** para que aparezcan datos

### 10.2 Probar Query en Athena
```sql
SELECT * FROM vpc_flow_logs 
WHERE year = '2024' AND month = '12' AND day = '01'
LIMIT 10;
```

### 10.3 Ejecutar Test de Lambda
1. **Lambda Console** → Tu función
2. **Test** → **Create test event**
3. Usar template: `hello-world`
4. **Test** y verificar logs

### 10.4 Generar Tráfico Anómalo
1. **SSH al attack simulator**:
   ```bash
   ssh -i tu-key.pem ec2-user@PUBLIC-IP-SIMULATOR
   ```

2. **Port Scan Attack**:
   ```bash
   python3 port_scan.py 10.0.2.X  # IP del web server
   ```

3. **DDoS Attack**:
   ```bash
   python3 ddos_sim.py 10.0.2.X
   ```

### 10.5 Verificar Alertas
1. **Esperar 5-10 minutos**
2. **Revisar tu email** para alertas
3. **CloudWatch Logs** → Revisar logs de Lambda

---

## **FLUJO COMPLETO CON BEDROCK:**

```
🔄 FLUJO DE DATOS CON IA:

1. EC2 genera tráfico anómalo
   ↓
2. VPC Flow Logs captura en S3
   ↓  
3. EventBridge trigger cada 5 min
   ↓
4. Lambda ejecuta queries Athena
   ↓
5. Si hay anomalías → 🤖 BEDROCK ANALIZA
   ↓
6. Claude 3 Sonnet genera explicación
   ↓
7. SNS envía alerta ENRIQUECIDA con IA
   ↓
8. 📧 Recibes email con análisis inteligente
```

---

## **TESTING CON BEDROCK HABILITADO:**

### Scenario 1: Port Scan Attack
1. **SSH al attack simulator**
2. **Ejecutar**: `python3 port_scan.py TARGET_IP`
3. **Esperar 5-8 minutos**
4. **Email recibido contendrá**:
   ```
   🤖 ANÁLISIS DE INTELIGENCIA ARTIFICIAL:
   
   **Explicación técnica:** Se detectó un escaneo masivo de puertos...
   **Severidad:** 8/10 - Alto riesgo de reconocimiento previo a ataque
   **Tipo de ataque:** Network reconnaissance con intención maliciosa
   **Acciones inmediatas:** 
   1. Bloquear IP origen inmediatamente
   2. Revisar logs de firewall 
   3. Implementar rate limiting
   ```

### Scenario 2: DDoS Attack  
1. **Ejecutar**: `python3 ddos_sim.py TARGET_IP`
2. **Email con análisis IA**:
   ```
   🤖 ANÁLISIS DE INTELIGENCIA ARTIFICIAL:
   
   **Explicación técnica:** Detectado ataque de denegación de servicio...
   **Severidad:** 9/10 - Crítico, afecta disponibilidad del servicio
   **Vectores:** Flood de conexiones TCP desde múltiples fuentes
   **Acciones inmediatas:**
   1. Activar AWS Shield Advanced
   2. Implementar rate limiting en ALB
   3. Revisar CloudFront cache
   ```

---

## **DIFERENCIAS CLAVE CON/SIN BEDROCK:**

### ❌ **Sin Bedrock (versión simple)**:
```
Alerta: "Detectado Port Scanning: 1 instancias"
Datos técnicos: [JSON crudo]
```

### ✅ **Con Bedrock (versión inteligente)**:
```
🤖 ANÁLISIS DE IA:
- Explicación clara en español
- Nivel de severidad justificado  
- Tipo de ataque identificado
- 3 acciones específicas recomendadas
- Medidas preventivas
- Indicadores adicionales a monitorear
```

---

## **COSTOS CON BEDROCK:**

### Estimación Mensual:
- **Bedrock (Claude 3 Sonnet)**: $2-5 USD
  - ~100 invocaciones/mes
  - ~1000 tokens por análisis  
- **Resto de servicios**: $8-10 USD
- **TOTAL**: ~$10-15 USD/mes

### Optimización:
- ✅ Solo analizar anomalías (no todo el tráfico)
- ✅ Usar temperatura baja (0.1) para consistencia
- ✅ Limitar tokens de respuesta (1500 max)

---

## **TROUBLESHOOTING BEDROCK:**

### Error: "AccessDeniedException"
- ✅ Verificar que Bedrock está habilitado en la región
- ✅ Confirmar acceso al modelo Claude 3 Sonnet
- ✅ Revisar permisos IAM del Lambda role

### Error: "ModelNotFound"
- ✅ Verificar Model ID exacto
- ✅ Confirmar región correcta
- ✅ Esperar aprobación completa de acceso

### Error: "ThrottlingException"  
- ✅ Reducir frecuencia de invocaciones
- ✅ Implementar retry logic
- ✅ Considerar rate limiting

### Respuestas de IA inconsistentes
- ✅ Ajustar temperatura a 0.1
- ✅ Mejorar prompt con ejemplos
- ✅ Limitar max_tokens

---

## **DEMO SCRIPT ACTUALIZADO CON IA:**

### Minutos 7-12: Port Scanning Attack CON IA
- SSH al simulator  
- Ejecutar port scan
- Mostrar logs: "🤖 Analizando con Bedrock..."
- **HIGHLIGHT**: Mostrar email CON análisis inteligente
- **Comparar**: Explicar diferencia vs alertas tradicionales

### Minutos 13-18: DDoS Attack CON IA
- Ejecutar DDoS simulator
- **MOSTRAR**: Análisis IA diferente para diferente ataque
- **DESTACAR**: Claude identifica tipo específico de ataque
- **ENFATIZAR**: Recomendaciones accionables específicas

---

## 🎯 **TESTING DE LA DEMO (10 minutos)**

### Escenario 1: Tráfico Normal
1. **Athena** → Ejecutar query básica
2. **Verificar**: No hay alertas
3. **Mostrar**: Flow Logs llegando normalmente

### Escenario 2: Port Scanning
1. **SSH al simulator**
2. **Ejecutar**: `python3 port_scan.py TARGET_IP`
3. **Esperar**: 5-7 minutos
4. **Verificar**: Alerta por email + logs Lambda

### Escenario 3: DDoS Attack
1. **Ejecutar**: `python3 ddos_sim.py TARGET_IP`
2. **Esperar**: 5-7 minutos  
3. **Verificar**: Nueva alerta diferente

---

## 🧹 **DESTRUCCIÓN Y LIMPIEZA**

### Orden de Eliminación (IMPORTANTE):

#### 1. Detener Generación de Datos
- **EventBridge**: Deshabilitar rule
- **EC2**: Terminar instancias
- **VPC Flow Logs**: Eliminar

#### 2. Limpiar Servicios
- **Lambda**: Eliminar función
- **SNS**: Eliminar topic y subscriptions
- **Athena**: Eliminar workgroup

#### 3. Limpiar Datos
- **S3**: Vaciar y eliminar buckets
- **Glue**: Eliminar database y tablas

#### 4. Limpiar Networking
- **NAT Gateway**: Eliminar (libera Elastic IP)
- **Internet Gateway**: Detach y eliminar
- **Subnets**: Eliminar
- **Security Groups**: Eliminar
- **VPC**: Eliminar

#### 5. Limpiar IAM
- **Roles**: Eliminar roles creados
- **Policies**: Eliminar políticas custom

---

## 💡 **TROUBLESHOOTING COMÚN**

### Flow Logs no aparecen
- ✅ Verificar permisos IAM role
- ✅ Revisar formato del bucket ARN
- ✅ Esperar hasta 10 minutos

### Athena queries fallan
- ✅ Verificar bucket de resultados
- ✅ Comprobar permisos S3
- ✅ Revisar formato de tabla

### Lambda timeout
- ✅ Aumentar timeout a 5 minutos
- ✅ Verificar permisos Bedrock
- ✅ Simplificar queries Athena

### No llegan alertas
- ✅ Confirmar suscripción email
- ✅ Revisar carpeta spam
- ✅ Verificar permisos SNS en Lambda

---

## 🎬 **DEMO SCRIPT (20 minutos)**

### Minutos 1-3: Introducción
- Mostrar arquitectura implementada
- Explicar flujo de datos
- Mostrar consola AWS con recursos

### Minutos 4-6: Tráfico Normal
- Ejecutar query básica en Athena
- Mostrar Flow Logs en S3
- Demostrar que no hay alertas

### Minutos 7-12: Port Scanning Attack
- SSH al simulator
- Ejecutar port scan
- Mostrar logs en CloudWatch
- Esperar y mostrar alerta

### Minutos 13-18: DDoS Attack
- Ejecutar DDoS simulator
- Mostrar diferente patrón
- Nueva alerta con análisis

### Minutos 19-20: Wrap-up
- Costos (~$10/mes)
- Escalabilidad 
- Q&A

---

## 📊 **MÉTRICAS DE ÉXITO**

- ✅ Flow Logs generándose < 5 minutos
- ✅ Queries Athena ejecutando < 30 segundos  
- ✅ Lambda procesando sin errores
- ✅ Alertas llegando < 8 minutos total
- ✅ Demo fluida sin interrupciones

**🎯 ¡Tu implementación manual está lista!**

Esta guía te permitirá entender cada componente antes de automatizar con Terraform.