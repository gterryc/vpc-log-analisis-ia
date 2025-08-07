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