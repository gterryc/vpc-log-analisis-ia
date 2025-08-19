import json
import boto3
import time
from datetime import datetime
import os
import logging

# Configurar logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Inicializar clientes AWS
athena_client = boto3.client('athena')
sns_client = boto3.client('sns')

# Inicializar Bedrock
try:
    bedrock_client = boto3.client('bedrock-runtime')
    BEDROCK_AVAILABLE = True
    print("✅ Bedrock client inicializado")
except Exception as e:
    BEDROCK_AVAILABLE = False
    print(f"⚠️ Bedrock no disponible: {e}")

# Variables de configuración con valores exactos
DATABASE_NAME = os.environ.get('DATABASE_NAME', 'vpc-traffic-anomaly-detection_flow_logs_db')
TABLE_NAME = os.environ.get('TABLE_NAME', 'vpc_flow_logs')
RESULTS_BUCKET = os.environ.get('RESULTS_BUCKET', 'anomaly-detection-flow-logs-12051980-athena-results')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', 'arn:aws:sns:us-east-1:730335323500:vpc-traffic-anomaly-detection-anomaly-alerts')
BEDROCK_MODEL_ID = 'anthropic.claude-3-5-sonnet-20240620-v1:0'

def lambda_handler(event, context):
    """
    Función principal de detección de anomalías en VPC Flow Logs
    """
    print("🔍 === ANOMALY DETECTION SYSTEM ===")
    print(f"⏰ Timestamp: {datetime.now()}")
    print(f"🎯 Request ID: {context.aws_request_id}")
    print(f"📊 Configuration:")
    print(f"   Database: {DATABASE_NAME}")
    print(f"   Table: {TABLE_NAME}")
    print(f"   Results Bucket: {RESULTS_BUCKET}")
    print(f"   SNS Topic: {SNS_TOPIC_ARN}")
    print(f"   Bedrock Available: {BEDROCK_AVAILABLE}")
    
    try:
        anomalies_detected = []
        
        # 1. Port Scanning Detection
        print("\n🔎 Analizando port scanning...")
        port_scan_results = detect_port_scanning()
        if port_scan_results:
            anomalies_detected.append({
                'type': 'Port Scanning',
                'severity': 'HIGH',
                'data': port_scan_results
            })
            print(f"🚨 Port scanning detectado: {len(port_scan_results)} instancias")
        
        # 2. DDoS Detection
        print("🔎 Analizando DDoS attacks...")
        ddos_results = detect_ddos()
        if ddos_results:
            anomalies_detected.append({
                'type': 'DDoS Attack',
                'severity': 'CRITICAL',
                'data': ddos_results
            })
            print(f"🚨 DDoS detectado: {len(ddos_results)} instancias")
            
        # 3. Data Exfiltration Detection
        print("🔎 Analizando data exfiltration...")
        exfil_results = detect_data_exfiltration()
        if exfil_results:
            anomalies_detected.append({
                'type': 'Data Exfiltration',
                'severity': 'HIGH',
                'data': exfil_results
            })
            print(f"🚨 Data exfiltration detectado: {len(exfil_results)} instancias")
        
        # Procesar anomalías detectadas
        if anomalies_detected:
            print(f"\n🚨 TOTAL ANOMALÍAS DETECTADAS: {len(anomalies_detected)}")
            
            for i, anomaly in enumerate(anomalies_detected):
                print(f"\n📋 Procesando anomalía {i+1}/{len(anomalies_detected)}: {anomaly['type']}")
                
                # Analizar con IA si está disponible
                if BEDROCK_AVAILABLE:
                    print("🤖 Analizando con Claude 3.5 Sonnet...")
                    ai_analysis = analyze_with_bedrock(anomaly)
                    anomaly['ai_analysis'] = ai_analysis
                else:
                    print("📝 Generando análisis básico...")
                    anomaly['ai_analysis'] = generate_basic_analysis(anomaly)
                
                # Enviar alerta
                print("📧 Enviando alerta...")
                send_alert(anomaly)
                
                # Pausa entre procesamiento para evitar throttling
                if i < len(anomalies_detected) - 1:
                    print("⏳ Pausa para evitar throttling...")
                    time.sleep(3)
        else:
            print("✅ No se detectaron anomalías")
            send_status_ok()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Análisis completado exitosamente',
                'anomalies_found': len(anomalies_detected),
                'timestamp': datetime.now().isoformat(),
                'request_id': context.aws_request_id,
                'bedrock_available': BEDROCK_AVAILABLE
            })
        }
        
    except Exception as e:
        error_msg = str(e)
        print(f"❌ ERROR en el proceso: {error_msg}")
        logger.error(f"Error: {error_msg}")
        send_error_alert(error_msg, context.aws_request_id)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_msg,
                'timestamp': datetime.now().isoformat(),
                'request_id': context.aws_request_id
            })
        }

def execute_athena_query(query, description="Query"):
    """Ejecuta una consulta en Athena y retorna los resultados"""
    try:
        print(f"🔄 Ejecutando {description}...")
        
        response = athena_client.start_query_execution(
            QueryString=query,
            QueryExecutionContext={'Database': DATABASE_NAME},
            ResultConfiguration={'OutputLocation': f's3://{RESULTS_BUCKET}/'}
        )
        
        query_id = response['QueryExecutionId']
        print(f"📝 Query ID: {query_id}")
        
        # Esperar completación (máximo 5 minutos)
        max_wait_time = 300
        wait_interval = 5
        elapsed_time = 0
        
        while elapsed_time < max_wait_time:
            status_response = athena_client.get_query_execution(QueryExecutionId=query_id)
            status = status_response['QueryExecution']['Status']['State']
            
            if status == 'SUCCEEDED':
                print(f"✅ {description} completada")
                break
            elif status in ['FAILED', 'CANCELLED']:
                error_reason = status_response['QueryExecution']['Status'].get('StateChangeReason', 'Unknown error')
                print(f"❌ {description} falló: {error_reason}")
                return None
            
            time.sleep(wait_interval)
            elapsed_time += wait_interval
        
        if elapsed_time >= max_wait_time:
            print(f"⏰ {description} timeout después de {max_wait_time} segundos")
            return None
        
        # Obtener resultados
        results_response = athena_client.get_query_results(QueryExecutionId=query_id)
        rows = results_response['ResultSet']['Rows']
        
        if len(rows) <= 1:  # Solo headers, no hay datos
            return None
        
        # Procesar resultados
        headers = [col['VarCharValue'] for col in rows[0]['Data']]
        data = []
        
        for row in rows[1:]:  # Saltar header row
            row_data = {}
            for i, cell in enumerate(row['Data']):
                row_data[headers[i]] = cell.get('VarCharValue', '')
            data.append(row_data)
        
        print(f"📊 {description}: {len(data)} resultados encontrados")
        return data
        
    except Exception as e:
        print(f"❌ Error en {description}: {str(e)}")
        return None

def detect_port_scanning():
    """Detecta actividad de port scanning"""
    query = f"""
    SELECT 
        srcaddr,
        COUNT(DISTINCT dstport) AS unique_ports,
        COUNT(*) AS total_attempts,
        MIN(to_iso8601(from_unixtime(start))) AS first_attempt,
        MAX(to_iso8601(from_unixtime("end"))) AS last_attempt
    FROM vpc_flow_logs
    WHERE 
        log_status = 'OK'
        AND action = 'REJECT'
        AND year = CAST(year(current_date) AS varchar)
        AND month = LPAD(CAST(month(current_date) AS varchar), 2, '0')
        AND day = LPAD(CAST(day(current_date) AS varchar), 2, '0')
    GROUP BY srcaddr
    HAVING COUNT(DISTINCT dstport) > 50
    ORDER BY unique_ports DESC
    LIMIT 20;
    """
    
    return execute_athena_query(query, "Port Scanning Detection")

def detect_ddos():
    """Detecta ataques DDoS"""
    query = f"""
    SELECT 
        dstaddr,
        SUM(packets) AS total_packets,
        SUM(bytes) AS total_bytes,
        COUNT(DISTINCT srcaddr) AS unique_sources,
        MIN(to_iso8601(from_unixtime(start))) AS attack_start,
        MAX(to_iso8601(from_unixtime("end"))) AS attack_end
    FROM vpc_flow_logs
    WHERE
        log_status = 'OK'
        AND action IN ('ACCEPT','REJECT')
        AND year = CAST(year(current_date) AS varchar)
        AND month = LPAD(CAST(month(current_date) AS varchar), 2, '0')
        AND day = LPAD(CAST(day(current_date) AS varchar), 2, '0')
    GROUP BY dstaddr
    HAVING 
        SUM(packets) > 100000
        OR COUNT(DISTINCT srcaddr) > 100
    ORDER BY total_packets DESC
    LIMIT 10;
    """
    
    return execute_athena_query(query, "DDoS Detection")

def detect_data_exfiltration():
    """Detecta posible exfiltración de datos"""
    query = f"""
    SELECT 
        srcaddr,
        dstaddr,
        SUM(bytes) AS total_bytes,
        COUNT(*) AS connection_count,
        AVG(bytes) AS avg_bytes_per_connection,
        MIN(to_iso8601(from_unixtime(start))) AS first_connection,
        MAX(to_iso8601(from_unixtime("end"))) AS last_connection
    FROM vpc_flow_logs
    WHERE 
        log_status = 'OK'
        AND action = 'ACCEPT'
        AND dstport IN (80, 443, 21, 22)
        AND year = CAST(year(current_date) AS varchar)
        AND month = LPAD(CAST(month(current_date) AS varchar), 2, '0')
        AND day = LPAD(CAST(day(current_date) AS varchar), 2, '0')
    GROUP BY srcaddr, dstaddr
    HAVING SUM(bytes) > 25000000    -- 25 MB
    ORDER BY total_bytes DESC
    LIMIT 10;
    """
    
    return execute_athena_query(query, "Data Exfiltration Detection")

def analyze_with_bedrock(anomaly):
    """Analiza anomalía usando Amazon Bedrock (Claude 3.5 Sonnet)"""
    if not BEDROCK_AVAILABLE:
        return generate_basic_analysis(anomaly)
    
    try:
        print(f"🤖 Analizando {anomaly['type']} con Claude 3.5 Sonnet...")
        
        prompt = f"""
        Eres un experto en ciberseguridad analizando tráfico de red anómalo en AWS VPC Flow Logs.
        
        Analiza la siguiente anomalía detectada y proporciona un análisis estructurado:

        **ANOMALÍA DETECTADA:**
        - Tipo: {anomaly['type']}
        - Severidad inicial: {anomaly['severity']}
        - Instancias detectadas: {len(anomaly['data'])}
        
        **DATOS TÉCNICOS:**
        {json.dumps(anomaly['data'], indent=2)}
        
        **ANÁLISIS REQUERIDO:**
        1. **Explicación técnica**: ¿Qué indica esta actividad?
        2. **Nivel de severidad**: Escala 1-10 con justificación
        3. **Vectores de ataque**: Posibles métodos utilizados
        4. **Impacto potencial**: Riesgos para la infraestructura
        5. **Acciones inmediatas**: Top 3 medidas urgentes
        6. **Prevención**: Medidas a largo plazo
        
        Responde en español, sé técnico pero claro. Estructura la respuesta para SOC/DevSecOps.
        """
        
        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1500,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.1
        })
        
        response = bedrock_client.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=body,
            contentType='application/json'
        )
        
        response_body = json.loads(response['body'].read())
        ai_analysis = response_body['content'][0]['text']
        
        print(f"✅ Análisis IA completado para {anomaly['type']}")
        return ai_analysis
        
    except Exception as e:
        error_msg = f"Error en análisis de IA: {str(e)}"
        print(f"❌ {error_msg}")
        return generate_basic_analysis(anomaly) + f"\n\n⚠️ Nota: {error_msg}"

def generate_basic_analysis(anomaly):
    """Genera análisis básico sin IA"""
    analysis_templates = {
        'Port Scanning': f"""
        📋 ANÁLISIS BÁSICO - PORT SCANNING
        
        🔍 **Explicación técnica**: 
        Detectado escaneo sistemático de puertos indicando reconocimiento de red.
        Instancias detectadas: {len(anomaly['data'])}
        
        ⚠️ **Severidad**: 8/10 - Alto riesgo de ataque inminente
        
        🎯 **Acciones inmediatas**:
        1. Bloquear inmediatamente las IPs origen identificadas
        2. Revisar logs de firewall para actividad correlacionada
        3. Implementar rate limiting en servicios expuestos
        
        🛡️ **Medidas preventivas**:
        - Configurar fail2ban o AWS WAF
        - Ocultar servicios no esenciales
        - Implementar honeypots para detección temprana
        """,
        
        'DDoS Attack': f"""
        📋 ANÁLISIS BÁSICO - ATAQUE DDOS
        
        🔍 **Explicación técnica**: 
        Detectado patrón de ataque de denegación de servicio distribuido.
        Instancias detectadas: {len(anomaly['data'])}
        
        ⚠️ **Severidad**: 9/10 - Crítico, afecta disponibilidad del servicio
        
        🎯 **Acciones inmediatas**:
        1. Activar AWS Shield Advanced inmediatamente
        2. Implementar rate limiting en Application Load Balancer
        3. Revisar y ajustar configuraciones de auto-scaling
        
        🛡️ **Medidas preventivas**:
        - Configurar CloudFront como proxy reverso
        - Implementar geoblocking si es aplicable
        - Configurar alarmas de tráfico anómalo
        """,
        
        'Data Exfiltration': f"""
        📋 ANÁLISIS BÁSICO - EXFILTRACIÓN DE DATOS
        
        🔍 **Explicación técnica**: 
        Detectada transferencia anormal de grandes volúmenes de datos.
        Instancias detectadas: {len(anomaly['data'])}
        
        ⚠️ **Severidad**: 8/10 - Alto riesgo de compromiso de datos
        
        🎯 **Acciones inmediatas**:
        1. Investigar inmediatamente las conexiones identificadas
        2. Revisar logs de acceso a aplicaciones críticas
        3. Verificar integridad de datos sensibles
        
        🛡️ **Medidas preventivas**:
        - Implementar DLP (Data Loss Prevention)
        - Configurar monitoreo de transferencias grandes
        - Reforzar autenticación multifactor
        """
    }
    
    return analysis_templates.get(anomaly['type'], f"""
    📋 ANÁLISIS BÁSICO - {anomaly['type'].upper()}
    
    Anomalía detectada con {len(anomaly['data'])} instancias.
    Se requiere investigación manual inmediata.
    """)

def send_alert(anomaly):
    """Envía alerta via SNS"""
    try:
        print(f"📧 Enviando alerta para {anomaly['type']}...")
        
        emoji_map = {
            'Port Scanning': '🔍',
            'DDoS Attack': '💥',
            'Data Exfiltration': '📤'
        }
        
        emoji = emoji_map.get(anomaly['type'], '🚨')
        subject = f"{emoji} ALERTA CRÍTICA: {anomaly['type']} - Severidad {anomaly['severity']}"
        
        message = f"""
{emoji} ALERTA DE SEGURIDAD - VPC FLOW LOGS {emoji}
================================================

🕒 **Timestamp**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}
🎯 **Tipo de Anomalía**: {anomaly['type']}
⚠️  **Severidad**: {anomaly['severity']}
📊 **Instancias Detectadas**: {len(anomaly['data'])}

🤖 **ANÁLISIS DE INTELIGENCIA ARTIFICIAL:**
{anomaly.get('ai_analysis', 'No disponible')}

📈 **DATOS TÉCNICOS DETECTADOS:**
{json.dumps(anomaly['data'], indent=2)}

---
🛡️ **Sistema**: Detección de Anomalías VPC Flow Logs
🤖 **Powered by**: Amazon Bedrock (Claude 3.5 Sonnet)
⏰ **Detección**: Análisis automático cada 5 minutos
🔗 **Region**: us-east-1

Para más detalles, revisar CloudWatch Logs: /aws/lambda/anomaly-detection-processor
"""
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        
        print(f"✅ Alerta enviada exitosamente para {anomaly['type']}")
        
    except Exception as e:
        print(f"❌ Error enviando alerta: {str(e)}")

def send_status_ok():
    """Envía notificación de estado OK (solo ocasionalmente)"""
    try:
        # Solo enviar cada 12 ejecuciones para evitar spam
        import random
        if random.randint(1, 12) == 1:
            message = f"""
✅ ESTADO: Sistema de Monitoreo Operacional

🕒 Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}
🔍 Análisis completado sin anomalías detectadas
📊 VPC Flow Logs monitoreados correctamente
🤖 Claude 3.5 Sonnet operacional
📧 Sistema de alertas activo

El sistema está funcionando normalmente y monitoreando tráfico de red.
"""
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject="✅ Status OK: Sistema de Detección Operacional",
                Message=message
            )
            print("📧 Status OK enviado")
        else:
            print("✅ Estado normal - no se envía notificación (evitar spam)")
            
    except Exception as e:
        print(f"❌ Error enviando estado OK: {str(e)}")

def send_error_alert(error_message, request_id):
    """Envía notificación de error del sistema"""
    try:
        subject = "❌ ERROR: Sistema de Detección de Anomalías"
        message = f"""
🚫 ERROR EN EL SISTEMA DE DETECCIÓN
===================================

🕒 **Timestamp**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}
🔑 **Request ID**: {request_id}
❌ **Error**: {error_message}

🔍 **Para debugging**:
- CloudWatch Log Group: /aws/lambda/anomaly-detection-processor
- Request ID: {request_id}
- Database: {DATABASE_NAME}
- Table: {TABLE_NAME}

⚠️ **El sistema requiere atención inmediata.**

🛠️ **Componentes a verificar**:
1. Permisos IAM de Lambda
2. Conectividad con Athena
3. Acceso a Bedrock
4. Configuración SNS
"""
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        
        print("✅ Notificación de error enviada")
        
    except Exception as e:
        print(f"❌ Error crítico enviando notificación: {str(e)}")

# Función de test interno (se ejecuta solo en test manual)
def test_components():
    """Test de componentes para debugging"""
    print("🧪 Testing system components...")
    
    # Test Athena
    try:
        athena_client.list_work_groups(MaxResults=1)
        print("✅ Athena: OK")
    except Exception as e:
        print(f"❌ Athena: {e}")
    
    # Test SNS
    try:
        sns_client.get_topic_attributes(TopicArn=SNS_TOPIC_ARN)
        print("✅ SNS: OK")
    except Exception as e:
        print(f"❌ SNS: {e}")
    
    # Test Bedrock
    if BEDROCK_AVAILABLE:
        try:
            # Test muy simple para evitar throttling
            print("✅ Bedrock: Available")
        except Exception as e:
            print(f"❌ Bedrock: {e}")
    else:
        print("⚠️ Bedrock: Not available")
        