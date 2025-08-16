import json
import boto3
import time
import os
from datetime import datetime, timedelta
import logging

# Configurar logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Inicializar clientes AWS
athena_client = boto3.client('athena')
bedrock_client = boto3.client('bedrock-runtime')
sns_client = boto3.client('sns')

# Variables de entorno
ATHENA_DATABASE = os.environ['ATHENA_DATABASE']
ATHENA_TABLE = os.environ['ATHENA_TABLE']
ATHENA_RESULTS_BUCKET = os.environ['ATHENA_RESULTS_BUCKET']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
BEDROCK_MODEL_ID = os.environ['BEDROCK_MODEL_ID']

def lambda_handler(event, context):
    """
    Función principal que ejecuta la detección de anomalías
    """
    logger.info("Iniciando proceso de detección de anomalías")
    
    try:
        # Ejecutar todas las consultas de detección
        anomalies_detected = []
        
        # 1. Detección de Port Scanning
        port_scan_results = execute_athena_query("port_scanning_detection")
        if port_scan_results:
            anomalies_detected.append({
                'type': 'Port Scanning',
                'severity': 'HIGH',
                'data': port_scan_results
            })
        
        # 2. Detección de DDoS
        ddos_results = execute_athena_query("ddos_detection") 
        if ddos_results:
            anomalies_detected.append({
                'type': 'DDoS Attack',
                'severity': 'CRITICAL',
                'data': ddos_results
            })
        
        # 3. Detección de Data Exfiltration
        exfiltration_results = execute_athena_query("data_exfiltration_detection")
        if exfiltration_results:
            anomalies_detected.append({
                'type': 'Data Exfiltration',
                'severity': 'HIGH', 
                'data': exfiltration_results
            })
        
        # 4. Detección de Protocolos Inusuales
        protocol_results = execute_athena_query("unusual_protocol_detection")
        if protocol_results:
            anomalies_detected.append({
                'type': 'Unusual Protocol',
                'severity': 'MEDIUM',
                'data': protocol_results
            })
        
        # Procesar anomalías detectadas
        if anomalies_detected:
            logger.info(f"Detectadas {len(anomalies_detected)} anomalías")
            
            for anomaly in anomalies_detected:
                # Analizar con Bedrock
                ai_analysis = analyze_with_bedrock(anomaly)
                anomaly['ai_analysis'] = ai_analysis
                
                # Enviar alerta
                send_alert(anomaly)
        else:
            logger.info("No se detectaron anomalías")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Análisis completado exitosamente',
                'anomalies_found': len(anomalies_detected),
                'timestamp': datetime.now().isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"Error en el proceso: {str(e)}")
        send_error_notification(str(e))
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            })
        }

def execute_athena_query(query_name):
    """
    Ejecuta una consulta nombrada de Athena y retorna los resultados
    """
    logger.info(f"Ejecutando consulta: {query_name}")
    
    try:
        # Obtener la consulta nombrada
        queries = {
            'port_scanning_detection': get_port_scanning_query(),
            'ddos_detection': get_ddos_query(),
            'data_exfiltration_detection': get_exfiltration_query(),
            'unusual_protocol_detection': get_protocol_query()
        }
        
        query_sql = queries.get(query_name)
        if not query_sql:
            raise ValueError(f"Consulta no encontrada: {query_name}")
        
        # Ejecutar consulta
        response = athena_client.start_query_execution(
            QueryString=query_sql,
            QueryExecutionContext={
                'Database': ATHENA_DATABASE
            },
            ResultConfiguration={
                'OutputLocation': f's3://{ATHENA_RESULTS_BUCKET}/'
            }
        )
        
        query_execution_id = response['QueryExecutionId']
        
        # Esperar a que termine la consulta
        wait_for_query_completion(query_execution_id)
        
        # Obtener resultados
        results = get_query_results(query_execution_id)
        
        return results if results else None
        
    except Exception as e:
        logger.error(f"Error ejecutando consulta {query_name}: {str(e)}")
        return None

def wait_for_query_completion(query_execution_id, max_wait_time=300):
    """
    Espera a que se complete la consulta de Athena
    """
    start_time = time.time()
    
    while time.time() - start_time < max_wait_time:
        response = athena_client.get_query_execution(
            QueryExecutionId=query_execution_id
        )
        
        status = response['QueryExecution']['Status']['State']
        
        if status == 'SUCCEEDED':
            return True
        elif status in ['FAILED', 'CANCELLED']:
            error_reason = response['QueryExecution']['Status'].get('StateChangeReason', 'Unknown error')
            raise Exception(f"Query failed: {error_reason}")
        
        time.sleep(5)
    
    raise TimeoutError(f"Query timed out after {max_wait_time} seconds")

def get_query_results(query_execution_id):
    """
    Obtiene los resultados de una consulta de Athena
    """
    try:
        response = athena_client.get_query_results(
            QueryExecutionId=query_execution_id
        )
        
        rows = response['ResultSet']['Rows']
        
        if len(rows) <= 1:  # Solo headers, no hay datos
            return None
        
        # Extraer headers
        headers = [col['VarCharValue'] for col in rows[0]['Data']]
        
        # Extraer datos
        data = []
        for row in rows[1:]:  # Saltar header row
            row_data = {}
            for i, cell in enumerate(row['Data']):
                row_data[headers[i]] = cell.get('VarCharValue', '')
            data.append(row_data)
        
        return data
        
    except Exception as e:
        logger.error(f"Error obteniendo resultados: {str(e)}")
        return None

def analyze_with_bedrock(anomaly):
    """
    Analiza la anomalía usando Amazon Bedrock (Claude)
    """
    try:
        prompt = f"""
        Analiza la siguiente anomalía de tráfico de red y proporciona:

        1. Explicación clara y técnica del problema detectado
        2. Nivel de severidad justificado (1-10)
        3. Posibles vectores de ataque o causas
        4. Acciones recomendadas inmediatas
        5. Acciones preventivas a largo plazo

        Tipo de anomalía: {anomaly['type']}
        Severidad inicial: {anomaly['severity']}
        Datos detectados: {json.dumps(anomaly['data'], indent=2)}

        Responde en español y de forma concisa pero completa.
        """
        
        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        })
        
        response = bedrock_client.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=body,
            contentType='application/json'
        )
        
        response_body = json.loads(response['body'].read())
        return response_body['content'][0]['text']
        
    except Exception as e:
        logger.error(f"Error analizando con Bedrock: {str(e)}")
        return f"Error en análisis de IA: {str(e)}"

def send_alert(anomaly):
    """
    Envía una alerta via SNS
    """
    try:
        subject = f"🚨 ALERTA: {anomaly['type']} detectado - Severidad: {anomaly['severity']}"
        
        message = f"""
ALERTA DE SEGURIDAD - TRÁFICO ANÓMALO DETECTADO
===============================================

Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}
Tipo de Anomalía: {anomaly['type']}
Severidad: {anomaly['severity']}

ANÁLISIS DE IA:
{anomaly.get('ai_analysis', 'No disponible')}

DATOS TÉCNICOS:
{json.dumps(anomaly['data'], indent=2)}

---
Este es un mensaje automático del sistema de detección de anomalías de red.
"""
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        
        logger.info(f"Alerta enviada para {anomaly['type']}")
        
    except Exception as e:
        logger.error(f"Error enviando alerta: {str(e)}")

def send_error_notification(error_message):
    """
    Envía notificación de error del sistema
    """
    try:
        subject = "❌ Error en Sistema de Detección de Anomalías"
        message = f"""
Error en el sistema de detección de anomalías:

Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}
Error: {error_message}

Por favor revisar los logs de CloudWatch para más detalles.
"""
        
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        
    except Exception as e:
        logger.error(f"Error enviando notificación de error: {str(e)}")

# Consultas SQL (simplificadas para demo)
def get_port_scanning_query():
    return f"""
    SELECT 
        srcaddr,
        COUNT(DISTINCT dstport) as unique_ports,
        COUNT(*) as total_attempts,
        MIN(from_unixtime(windowstart)) as first_attempt,
        MAX(from_unixtime(windowend)) as last_attempt
    FROM {ATHENA_TABLE}
    WHERE 
        action = 'REJECT'
        AND windowstart > to_unixtime(current_timestamp - interval '1' hour)
    GROUP BY srcaddr
    HAVING COUNT(DISTINCT dstport) > 50
    ORDER BY unique_ports DESC
    LIMIT 10;
    """

def get_ddos_query():
    return f"""
    SELECT 
        dstaddr,
        SUM(packets) as total_packets,
        SUM(bytes) as total_bytes,
        COUNT(DISTINCT srcaddr) as unique_sources,
        MIN(from_unixtime(windowstart)) as attack_start,
        MAX(from_unixtime(windowend)) as attack_end
    FROM {ATHENA_TABLE}
    WHERE 
        action = 'ACCEPT'
        AND windowstart > to_unixtime(current_timestamp - interval '1' hour)
    GROUP BY dstaddr
    HAVING 
        SUM(packets) > 100000
        OR COUNT(DISTINCT srcaddr) > 100
    ORDER BY total_packets DESC
    LIMIT 10;
    """

def get_exfiltration_query():
    return f"""
    SELECT 
        srcaddr,
        dstaddr,
        SUM(bytes) as total_bytes,
        COUNT(*) as connection_count,
        AVG(bytes) as avg_bytes_per_connection,
        MIN(from_unixtime(windowstart)) as first_connection,
        MAX(from_unixtime(windowend)) as last_connection
    FROM {ATHENA_TABLE}
    WHERE 
        action = 'ACCEPT'
        AND dstport IN (80, 443, 21, 22)
        AND windowstart > to_unixtime(current_timestamp - interval '1' hour)
    GROUP BY srcaddr, dstaddr
    HAVING SUM(bytes) > 100000000
    ORDER BY total_bytes DESC
    LIMIT 10;
    """

def get_protocol_query():
    return f"""
    SELECT 
        protocol,
        COUNT(*) as connection_count,
        COUNT(DISTINCT srcaddr) as unique_sources,
        COUNT(DISTINCT dstaddr) as unique_destinations,
        SUM(bytes) as total_bytes
    FROM {ATHENA_TABLE}
    WHERE 
        protocol NOT IN (6, 17, 1)
        AND action = 'ACCEPT'
        AND windowstart > to_unixtime(current_timestamp - interval '1' hour)
    GROUP BY protocol
    ORDER BY connection_count DESC;
    """