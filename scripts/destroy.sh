#!/bin/bash

# Script de destrucción para Arquitectura de Detección de Anomalías
# Versión mejorada con validaciones y manejo de errores

set -euo pipefail

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

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

# Función de limpieza en caso de error
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Destrucción falló con código: $exit_code"
        log_warning "Algunos recursos pueden no haberse eliminado correctamente"
        log_info "Revisa manualmente la consola de AWS para verificar"
    fi
}

# Configurar trap para limpieza
trap cleanup EXIT

# Verificar estructura del proyecto y cambiar al directorio raíz
check_and_setup_working_directory() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Cambiar al directorio padre (donde están los archivos .tf)
    cd "$script_dir/.." || {
        log_error "No se pudo acceder al directorio padre"
        exit 1
    }

    # Verificar que estamos en el directorio correcto
    if ! ls *.tf &> /dev/null; then
        log_error "No se encontraron archivos .tf en el directorio: $(pwd)"
        log_info "Estructura esperada:"
        log_info "  proyecto/"
        log_info "  ├── *.tf (archivos terraform)"
        log_info "  └── scripts/"
        log_info "      └── destroy.sh (este script)"
        exit 1
    fi

    log_success "Directorio de trabajo: $(pwd)"
}

# Verificar prerrequisitos básicos
check_prerequisites() {
    log_info "Verificando prerrequisitos..."

    # Verificar Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform no está instalado"
        exit 1
    fi

    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI no está instalado"
        exit 1
    fi

    log_success "Herramientas necesarias encontradas"
}

# Verificar que Terraform esté inicializado y haya estado
check_terraform_state() {
    log_info "Verificando estado de Terraform..."

    # Verificar que Terraform esté inicializado
    if [[ ! -d ".terraform" ]]; then
        log_error "Terraform no está inicializado en este directorio"
        log_info "Ejecuta primero './scripts/deploy.sh' o 'terraform init'"
        exit 1
    fi

    # Verificar que exista estado
    if ! terraform state list &> /dev/null; then
        log_warning "No se encontró estado de Terraform o está vacío"
        log_info "Puede que no haya recursos para destruir"

        # Preguntar si continuar
        local response
        while true; do
            read -p "¿Continuar de todos modos? [y/N]: " -n 1 -r response
            echo
            case $response in
                [Yy]* )
                    log_info "Continuando..."
                    return 0
                    ;;
                [Nn]* | "" )
                    log_info "Operación cancelada"
                    exit 0
                    ;;
                * )
                    echo "Por favor responde 'y' para sí o 'n' para no."
                    ;;
            esac
        done
    fi

    # Mostrar recursos que serán destruidos
    local resource_count
    resource_count=$(terraform state list | wc -l)
    log_info "Se encontraron $resource_count recursos para destruir"
}

# Verificar credenciales AWS
check_aws_credentials() {
    log_info "Verificando credenciales AWS..."

    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "Credenciales AWS no configuradas o inválidas"
        log_info "Configura tus credenciales con: aws configure"
        exit 1
    fi

    local aws_account
    aws_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    log_success "Conectado a cuenta AWS: $aws_account"
}

# Mostrar advertencia detallada
show_destruction_warning() {
    echo
    log_error "🗑️  DESTRUYENDO RECURSOS DE DEMO"
    echo "================================="
    echo
    log_warning "ADVERTENCIA: Esta operación es IRREVERSIBLE"
    echo
    log_info "Los siguientes recursos serán ELIMINADOS PERMANENTEMENTE:"
    echo "   💾 VPC y subnets"
    echo "   🖥️  Instancias EC2"
    echo "   📦 Buckets S3 y TODO su contenido"
    echo "   ⚡ Funciones Lambda"
    echo "   📧 Topics SNS y suscripciones"
    echo "   📊 Grupos de logs de CloudWatch"
    echo "   🌊 Todos los datos de Flow Logs"
    echo "   🔒 Roles y políticas IAM"
    echo "   🚨 Alarmas de CloudWatch"
    echo
    log_warning "💰 Esto detendrá todos los costos asociados con estos recursos"
    echo
}

# Confirmación múltiple para seguridad
confirm_destruction() {
    local response

    # Primera confirmación
    while true; do
        read -p "¿Estás completamente seguro de ELIMINAR todos estos recursos? [y/N]: " -n 1 -r response
        echo
        case $response in
            [Yy]* )
                break
                ;;
            [Nn]* | "" )
                log_info "Operación cancelada por el usuario"
                exit 0
                ;;
            * )
                echo "Por favor responde 'y' para sí o 'n' para no."
                ;;
        esac
    done

    # Segunda confirmación para mayor seguridad
    echo
    log_warning "Última oportunidad para cancelar..."
    while true; do
        read -p "Escribe 'DESTROY' en mayúsculas para confirmar: " response
        case $response in
            "DESTROY" )
                log_info "Confirmación recibida. Iniciando destrucción..."
                return 0
                ;;
            "" )
                log_info "Operación cancelada"
                exit 0
                ;;
            * )
                echo "Debes escribir exactamente 'DESTROY' para continuar"
                ;;
        esac
    done
}

# Mostrar plan de destrucción
show_destroy_plan() {
    log_info "Generando plan de destrucción..."
    echo "=================================="

    if ! terraform plan -destroy -input=false; then
        log_error "Error al generar el plan de destrucción"
        exit 1
    fi

    echo
    log_info "Revisa cuidadosamente el plan anterior"
    echo
}

# Ejecutar destrucción con Terraform
execute_destruction() {
    log_info "🧹 Iniciando eliminación de recursos..."
    echo "====================================="

    local start_time
    start_time=$(date +%s)

    if ! terraform destroy -auto-approve -input=false; then
        log_error "Error durante la destrucción de recursos"
        log_warning "Algunos recursos pueden no haberse eliminado"
        log_info "Revisa manualmente en la consola de AWS"
        exit 1
    fi

    local end_time
    local duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log_success "Recursos eliminados exitosamente en ${duration}s"
}

# Verificación post-destrucción
post_destruction_verification() {
    log_info "Realizando verificaciones post-destrucción..."

    # Verificar que el estado esté vacío
    local remaining_resources
    remaining_resources=$(terraform state list 2>/dev/null | wc -l)

    if [[ $remaining_resources -eq 0 ]]; then
        log_success "Estado de Terraform limpio - todos los recursos eliminados"
    else
        log_warning "Quedan $remaining_resources recursos en el estado"
        log_info "Recursos restantes:"
        terraform state list 2>/dev/null || true
    fi
}

# Información post-destrucción
show_post_destruction_info() {
    echo
    log_success "✅ Proceso de destrucción completado"
    echo "===================================="
    echo
    log_info "📋 Tareas de verificación recomendadas:"
    echo "   1. Revisa la consola de AWS para confirmar que todos los recursos fueron eliminados"
    echo "   2. Verifica que no hay buckets S3 huérfanos"
    echo "   3. Confirma que las alarmas de CloudWatch fueron eliminadas"
    echo "   4. Revisa que los logs de CloudWatch se estén eliminando (puede tomar tiempo)"
    echo
    log_info "🔗 Enlaces útiles:"
    echo "   • EC2: https://console.aws.amazon.com/ec2/"
    echo "   • S3: https://console.aws.amazon.com/s3/"
    echo "   • Lambda: https://console.aws.amazon.com/lambda/"
    echo "   • CloudWatch: https://console.aws.amazon.com/cloudwatch/"
    echo
    log_warning "⏱️  Nota: Los logs de CloudWatch pueden tardar hasta 24h en eliminarse completamente"
    log_success "💰 Los costos asociados con estos recursos han cesado"
    echo
    log_info "🚀 Para volver a desplegar: './scripts/deploy.sh'"
}

# Función principal
main() {
    check_and_setup_working_directory
    check_prerequisites
    check_terraform_state
    check_aws_credentials
    show_destruction_warning
    show_destroy_plan
    confirm_destruction
    execute_destruction
    post_destruction_verification
    show_post_destruction_info
}

# Ejecutar función principal
main "$@"
