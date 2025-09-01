#!/usr/bin/env python3
# Test standalone de Claude 3.5 Sonnet
import boto3
import json
from datetime import datetime

def test_claude_35_sonnet():
    """Test completo de Claude 3.5 Sonnet"""
    print("🧪 Testing Claude 3.5 Sonnet...")

    try:
        bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
        model_id = 'anthropic.claude-3-5-sonnet-20240620-v1:0'

        # Test 1: Respuesta básica
        print("\n📝 Test 1: Respuesta básica")
        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 100,
            "messages": [
                {
                    "role": "user",
                    "content": "Responde exactamente: 'CLAUDE 3.5 SONNET FUNCIONANDO - ' seguido de la fecha y hora actual."
                }
            ],
            "temperature": 0.1
        })

        response = bedrock.invoke_model(
            modelId=model_id,
            body=body,
            contentType='application/json'
        )

        result = json.loads(response['body'].read())
        answer = result['content'][0]['text']
        print(f"✅ Respuesta: {answer}")

        # Test 2: Análisis de seguridad (simulado)
        print("\n🔒 Test 2: Análisis de seguridad")
        security_body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 200,
            "messages": [
                {
                    "role": "user",
                    "content": """Analiza esta anomalía de red simulada:

Tipo: Port Scanning
IP origen: 203.0.113.5
Puertos escaneados: 150 puertos únicos
Conexiones rechazadas: 890

Proporciona un análisis breve de severidad y 2 acciones recomendadas."""
                }
            ],
            "temperature": 0.1
        })

        response = bedrock.invoke_model(
            modelId=model_id,
            body=security_body,
            contentType='application/json'
        )

        result = json.loads(response['body'].read())
        security_analysis = result['content'][0]['text']
        print(f"✅ Análisis de seguridad:")
        print(f"   {security_analysis}")

        print(f"\n🎉 Claude 3.5 Sonnet está funcionando perfectamente!")
        return True

    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_sns():
    """Test rápido de SNS"""
    print("\n📧 Testing SNS...")

    try:
        sns = boto3.client('sns', region_name='us-east-1')
        topic_arn = 'arn:aws:sns:us-east-1:730335323500:vpc-traffic-anomaly-detection-anomaly-alerts'

        response = sns.publish(
            TopicArn=topic_arn,
            Subject='🧪 TEST: Claude 3.5 Sonnet Integrado',
            Message=f'''🧪 MENSAJE DE PRUEBA

Claude 3.5 Sonnet está funcionando correctamente y listo para análisis de anomalías.

Timestamp: {datetime.now()}
Status: ✅ OPERACIONAL

Este es un test de integración del sistema completo.
'''
        )

        print(f"✅ SNS Message sent: {response['MessageId']}")
        print("📬 Revisa tu email para confirmar que SNS funciona")
        return True

    except Exception as e:
        print(f"❌ SNS Error: {e}")
        return False

if __name__ == "__main__":
    print("🔬 === SYSTEM INTEGRATION TEST ===")
    print(f"🕐 Timestamp: {datetime.now()}")
    print("=" * 50)

    # Test Claude 3.5 Sonnet
    bedrock_ok = test_claude_35_sonnet()

    # Test SNS
    sns_ok = test_sns()

    print("\n" + "=" * 50)
    print("📊 RESUMEN DE TESTS:")
    print(f"   🤖 Claude 3.5 Sonnet: {'✅ OK' if bedrock_ok else '❌ FAIL'}")
    print(f"   📧 SNS: {'✅ OK' if sns_ok else '❌ FAIL'}")

    if bedrock_ok and sns_ok:
        print("\n🎉 ¡Sistema listo para integración completa!")
        print("\n📋 Próximos pasos:")
        print("   1. Actualizar código Lambda con Claude 3.5")
        print("   2. Configurar EventBridge")
        print("   3. Test end-to-end con ataques simulados")
    else:
        print("\n⚠️  Revisar componentes fallidos antes de continuar")
