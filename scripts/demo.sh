#!/bin/bash

# Script de demostración para Arquitectura de Detección de Anomalías
# Versión completa con funcionalidad interactiva y manejo correcto de directorios

set -euo pipefail

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Variables globales
ATTACK_IP=""
WEB_IP=""
SSH_KEY=""
AWS_REGION=""

# Funciones de logging
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_demo() {
    echo -e "${PURPLE}🎬 $1${NC}"
}

log_command() {
    echo -e "${CYAN}🔧 $1${NC}"
}

# Función de limpieza en caso de error
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Demo terminó con error (código: $exit_code)"
        log_info "Revisa los logs anteriores para más información"
    fi
}

# Configurar trap para limpieza
trap cleanup EXIT

# Configurar directorio de trabajo correcto
setup_working_directory() {
    # Obtener el directorio donde está el script
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    log_info "Script ejecutándose desde: $script_dir"

    # Cambiar al directorio padre (donde están los archivos .tf)
    if ! cd "$script_dir/.."; then
        log_error "No se pudo cambiar al directorio padre"
        exit 1
    fi

    log_info "Directorio de trabajo: $(pwd)"

    # Verificar que estamos en el lugar correcto
    if ! ls *.tf &> /dev/null; then
        log_error "No se encontraron archivos .tf en: $(pwd)"
        log_info "Estructura esperada:"
        log_info "  proyecto/"
        log_info "  ├── *.tf"
        log_info "  └── scripts/demo.sh"
        exit 1
    fi

    # Verificar que Terraform está inicializado
    if [[ ! -d ".terraform" ]]; then
        log_error "Terraform no está inicializado en: $(pwd)"
        log_info "Ejecuta primero: ./scripts/deploy.sh"
        exit 1
    fi

    log_success "Directorio correcto y Terraform inicializado"
}

# Verificar prerrequisitos
check_prerequisites() {
    log_info "Verificando prerrequisitos..."

    local missing_tools=()

    # Verificar herramientas necesarias
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi

    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi

    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    fi

    if ! command -v ssh &> /dev/null; then
        missing_tools+=("ssh")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Herramientas faltantes: ${missing_tools[*]}"
        log_info "Instala las herramientas faltantes y vuelve a intentar"
        exit 1
    fi

    # Obtener región AWS
    AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")

    log_success "Prerrequisitos verificados (región: $AWS_REGION)"
}

# Obtener información de las instancias
get_instance_info() {
    log_info "Obteniendo información de las instancias..."

    # Verificar que el output exists
    if ! terraform output demo_instances &> /dev/null; then
        log_error "No se encontró el output 'demo_instances'"
        log_info "Outputs disponibles:"
        terraform output 2>/dev/null || log_info "No hay outputs disponibles"
        log_info "Asegúrate de que los recursos estén desplegados correctamente"
        exit 1
    fi

    # Obtener IPs
    ATTACK_IP=$(terraform output -json demo_instances | jq -r '.attack_simulator_public_ip')
    WEB_IP=$(terraform output -json demo_instances | jq -r '.web_server_private_ip')

    if [[ -z "$ATTACK_IP" || "$ATTACK_IP" == "null" ]]; then
        log_error "No se puede obtener la IP del simulador de ataques"
        log_info "Verifica que las instancias estén desplegadas correctamente"
        exit 1
    fi

    if [[ -z "$WEB_IP" || "$WEB_IP" == "null" ]]; then
        log_warning "No se puede obtener la IP del servidor web"
        WEB_IP="N/A"
    fi

    log_success "Información de instancias obtenida"
}

# Buscar clave SSH
find_ssh_key() {
    log_info "Buscando clave SSH..."

    # Buscar claves SSH comunes
    local key_paths=(
        "$HOME/.ssh/aws-demo.pem"
        "$HOME/.ssh/anomaly-detection-key.pem"
        "$HOME/.ssh/demo-key.pem"
        "$HOME/.ssh/id_rsa"
        "$HOME/.ssh/id_ed25519"
        "./keys/aws-demo.pem"
        "./keys/demo-key.pem"
    )

    SSH_KEY=""
    for key_path in "${key_paths[@]}"; do
        if [[ -f "$key_path" ]]; then
            SSH_KEY="$key_path"
            break
        fi
    done

    if [[ -z "$SSH_KEY" ]]; then
        log_warning "No se encontró clave SSH automáticamente"
        log_info "Especifica la ruta de tu clave SSH:"
        read -p "Ruta de la clave SSH: " SSH_KEY

        if [[ ! -f "$SSH_KEY" ]]; then
            log_error "Archivo de clave no encontrado: $SSH_KEY"
            return 1
        fi
    fi

    # Verificar y corregir permisos
    local key_perms
    key_perms=$(stat -c %a "$SSH_KEY" 2>/dev/null || stat -f %A "$SSH_KEY" 2>/dev/null)

    if [[ "$key_perms" != "600" ]]; then
        log_warning "Corrigiendo permisos de la clave SSH"
        chmod 600 "$SSH_KEY"
    fi

    log_success "Clave SSH encontrada: $SSH_KEY"
    return 0
}

# Verificar conectividad SSH
test_ssh_connectivity() {
    log_info "Probando conectividad SSH..."

    if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@"$ATTACK_IP" "echo 'SSH_OK'" &> /dev/null; then
        log_success "Conectividad SSH verificada"
        return 0
    else
        log_error "No se puede conectar por SSH"
        log_info "Verifica:"
        log_info "1. La clave SSH es correcta: $SSH_KEY"
        log_info "2. La instancia está ejecutándose"
        log_info "3. Los security groups permiten SSH (puerto 22)"
        log_info "4. La IP es correcta: $ATTACK_IP"
        return 1
    fi
}

# Ejecutar comando SSH
execute_ssh_command() {
    local command=$1
    local description=$2

    log_demo "Ejecutando: $description"
    log_command "Comando: $command"

    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@"$ATTACK_IP" "$command"; then
        log_success "Comando ejecutado exitosamente"
        return 0
    else
        log_error "Error al ejecutar comando"
        return 1
    fi
}

# Mostrar información básica
show_instance_info() {
    echo
    log_demo "🎯 Instancias Configuradas"
    echo "=========================="
    echo "   • Simulador de ataques: $ATTACK_IP"
    echo "   • Servidor web objetivo: $WEB_IP"
    echo "   • Clave SSH: $SSH_KEY"
    echo "   • Región AWS: $AWS_REGION"
    echo
}

# Mostrar información de monitoreo
show_monitoring_info() {
    echo
    log_info "📊 Enlaces de Monitoreo"
    echo "======================="
    echo "🔗 CloudWatch Logs:"
    echo "   https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#logsV2:log-groups/log-group/%2Faws%2Flambda%2Fanomaly-detection-function"
    echo
    echo "🔗 S3 Flow Logs:"
    echo "   https://s3.console.aws.amazon.com/s3/buckets/anomaly-detection-flow-logs-12051980?region=$AWS_REGION"
    echo
    echo "🔗 Athena Queries:"
    echo "   https://console.aws.amazon.com/athena/home?region=$AWS_REGION"
    echo
    echo "🔗 Lambda Function:"
    echo "   https://console.aws.amazon.com/lambda/home?region=$AWS_REGION#/functions/anomaly-detection-function"
    echo
    echo "🔗 EC2 Instances:"
    echo "   https://console.aws.amazon.com/ec2/home?region=$AWS_REGION#Instances:"
    echo
}

# Mostrar cronología de demo
show_demo_timeline() {
    echo
    log_info "⏱️  Cronología Sugerida para la Demo"
    echo "===================================="
    echo "1. 📊 Mostrar tráfico normal en CloudWatch"
    echo "2. 🔍 Ejecutar Port Scan (2 min)"
    echo "3. ⏰ Esperar alertas (~3-5 min)"
    echo "4. 🤖 Mostrar análisis de Bedrock/AI"
    echo "5. 💥 Ejecutar DDoS (2 min)"
    echo "6. 📧 Verificar nuevas alertas por email"
    echo "7. 💰 Discutir costos y escalabilidad"
    echo
}

# Ejecutar ataque específico
run_attack() {
    local attack_type=$1
    local description=$2

    echo
    log_demo "🔥 Iniciando: $description"
    echo "============================================"

    # Verificar que el script de ataque existe
    if ! execute_ssh_command "ls attack_controller.sh" "Verificando script de ataques"; then
        log_error "Script attack_controller.sh no encontrado en la instancia"
        log_info "Verifica que la instancia esté configurada correctamente"
        return 1
    fi

    # Ejecutar ataque
    local start_time
    start_time=$(date +%s)

    if execute_ssh_command "./attack_controller.sh $attack_type" "$description"; then
        local end_time
        local duration
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        log_success "Ataque completado en ${duration}s"

        echo
        log_info "⏱️  Próximos pasos:"
        echo "   • Las alertas aparecerán en 3-5 minutos"
        echo "   • Revisa tu email para notificaciones"
        echo "   • Los logs están siendo procesados por Lambda"
        echo "   • Ve a CloudWatch para monitorear en tiempo real"
        return 0
    else
        log_error "Error durante la ejecución del ataque"
        return 1
    fi
}

# Ver logs en tiempo real
show_real_time_logs() {
    log_info "Mostrando logs de Lambda en tiempo real..."
    log_warning "Presiona Ctrl+C para salir del modo de monitoreo"
    echo

    if command -v aws &> /dev/null; then
        aws logs tail /aws/lambda/anomaly-detection-function --follow --format short
    else
        log_error "AWS CLI no está disponible para mostrar logs"
        log_info "Ve a: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION"
    fi
}

# Mostrar menú principal
show_main_menu() {
    echo
    log_demo "🎭 DEMO: Detección de Anomalías en AWS"
    echo "======================================"
    show_instance_info

    log_info "🎬 Opciones disponibles:"
    echo "   1) 🔍 Port Scanning Attack (2 min)"
    echo "   2) 💥 DDoS Attack Simulation (2 min)"
    echo "   3) 📤 Data Exfiltration Simulation (2 min)"
    echo "   4) 🔄 Ejecutar todos los ataques secuencialmente"
    echo "   5) 📊 Mostrar información de monitoreo"
    echo "   6) 📋 Ver cronología de demo sugerida"
    echo "   7) 📝 Mostrar logs en tiempo real"
    echo "   8) 🛑 Detener todos los ataques"
    echo "   9) 🔧 Mostrar comandos manuales"
    echo "   0) 🚪 Salir"
    echo
}

# Mostrar comandos manuales
show_manual_commands() {
    echo
    log_info "🔧 Comandos Manuales"
    echo "===================="
    echo "📝 Conectar por SSH:"
    echo "   ssh -i $SSH_KEY ec2-user@$ATTACK_IP"
    echo
    echo "🔍 Ejecutar ataques:"
    echo "   ./attack_controller.sh port    # Port scanning"
    echo "   ./attack_controller.sh ddos    # DDoS attack"
    echo "   ./attack_controller.sh exfil   # Data exfiltration"
    echo "   ./attack_controller.sh all     # Todos los ataques"
    echo "   ./attack_controller.sh stop    # Detener ataques"
    echo
    echo "📊 Monitorear:"
    echo "   ./attack_controller.sh status  # Estado actual"
    echo
}

# Función principal del menú interactivo
run_interactive_demo() {
    while true; do
        show_main_menu

        local choice
        read -p "Selecciona una opción [0-9]: " choice

        case $choice in
            1)
                run_attack "port" "Port Scanning Attack"
                ;;
            2)
                run_attack "ddos" "DDoS Attack Simulation"
                ;;
            3)
                run_attack "exfil" "Data Exfiltration Simulation"
                ;;
            4)
                log_demo "Ejecutando demo completa..."
                run_attack "port" "Port Scanning Attack" && sleep 30
                run_attack "ddos" "DDoS Attack Simulation" && sleep 30
                run_attack "exfil" "Data Exfiltration Simulation"
                ;;
            5)
                show_monitoring_info
                ;;
            6)
                show_demo_timeline
                ;;
            7)
                show_real_time_logs
                ;;
            8)
                execute_ssh_command "./attack_controller.sh stop" "Deteniendo todos los ataques"
                ;;
            9)
                show_manual_commands
                ;;
            0)
                log_info "Saliendo de la demo..."
                echo
                log_success "¡Gracias por usar la demo!"
                log_info "Recuerda ejecutar './scripts/destroy.sh' cuando termines"
                exit 0
                ;;
            *)
                log_warning "Opción inválida. Selecciona 0-9."
                ;;
        esac

        echo
        read -p "Presiona Enter para continuar..."
    done
}

# Función principal
main() {
    echo
    log_demo "🎬 Ejecutando Demo de Detección de Anomalías"
    echo "============================================="
    echo

    # Configuración inicial
    setup_working_directory
    check_prerequisites
    get_instance_info

    # Buscar clave SSH
    if find_ssh_key; then
        # Si tenemos clave SSH, verificar conectividad
        if test_ssh_connectivity; then
            log_success "¡Todo configurado correctamente!"
            log_info "Iniciando modo interactivo..."
            sleep 2
            run_interactive_demo
        else
            log_warning "Problema con SSH, pero puedes usar comandos manuales"
            show_instance_info
            show_manual_commands
        fi
    else
        log_warning "No se pudo configurar SSH automáticamente"
        show_instance_info
        show_manual_commands
    fi
}

# Verificar si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
