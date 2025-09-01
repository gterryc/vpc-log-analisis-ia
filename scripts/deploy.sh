#!/bin/bash

# Script de despliegue para Arquitectura de Detección de Anomalías
# Versión mejorada con manejo de errores y validaciones adicionales

set -euo pipefail  # Mejorado: -u para variables no definidas, -o pipefail para errores en pipes

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
        log_error "Despliegue falló con código: $exit_code"
        if [[ -f "tfplan" ]]; then
            log_info "Limpiando archivo de plan temporal..."
            rm -f tfplan
        fi
        log_warning "Revisa los logs anteriores para identificar el problema"
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
        log_info "  ├── terraform.tfvars"
        log_info "  └── scripts/"
        log_info "      └── deploy.sh (este script)"
        exit 1
    fi

    log_success "Directorio de trabajo: $(pwd)"
}

# Verificar prerrequisitos mejorado
check_prerequisites() {
    log_info "Verificando prerrequisitos..."

    local missing_tools=()

    # Verificar Terraform
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    else
        local tf_version
        tf_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | cut -d' ' -f2 | tr -d 'v')
        log_success "Terraform encontrado: v$tf_version"
    fi

    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws-cli")
    else
        local aws_version
        aws_version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
        log_success "AWS CLI encontrado: $aws_version"
    fi

    # Verificar jq (útil para procesar JSON)
    if ! command -v jq &> /dev/null; then
        log_warning "jq no está instalado (recomendado para procesamiento JSON)"
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Herramientas faltantes: ${missing_tools[*]}"
        log_info "Instala las herramientas faltantes antes de continuar"
        exit 1
    fi
}

# Verificar credenciales AWS mejorado
check_aws_credentials() {
    log_info "Verificando credenciales AWS..."

    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "Credenciales AWS no configuradas o inválidas"
        log_info "Configura tus credenciales con: aws configure"
        exit 1
    fi

    local aws_account
    local aws_region
    aws_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    aws_region=$(aws configure get region 2>/dev/null || echo "no configurada")

    log_success "Conectado a cuenta AWS: $aws_account"
    log_success "Región configurada: $aws_region"

    # Advertir si no hay región configurada
    if [[ "$aws_region" == "no configurada" ]]; then
        log_warning "No hay región AWS configurada. Terraform usará la región por defecto del provider"
    fi
}

# Verificar archivos de configuración
check_config_files() {
    log_info "Verificando archivos de configuración..."

    # Verificar terraform.tfvars
    if [[ ! -f "terraform.tfvars" ]]; then
        if [[ -f "terraform.tfvars.example" ]]; then
            log_error "Archivo terraform.tfvars no encontrado"
            log_info "Copia terraform.tfvars.example y configura tus valores:"
            log_info "cp terraform.tfvars.example terraform.tfvars"
        else
            log_error "No se encontró terraform.tfvars ni terraform.tfvars.example"
        fi
        exit 1
    fi

    # Verificar que el archivo no esté vacío
    if [[ ! -s "terraform.tfvars" ]]; then
        log_error "El archivo terraform.tfvars está vacío"
        exit 1
    fi

    log_success "Archivo terraform.tfvars encontrado"
}

# Inicializar Terraform con manejo de errores
terraform_init() {
    log_info "Inicializando Terraform..."

    if ! terraform init -input=false; then
        log_error "Falló la inicialización de Terraform"
        exit 1
    fi

    log_success "Terraform inicializado correctamente"
}

# Validar configuración de Terraform
terraform_validate() {
    log_info "Validando configuración de Terraform..."

    if ! terraform validate; then
        log_error "Configuración de Terraform no válida"
        exit 1
    fi

    log_success "Configuración validada correctamente"
}

# Generar y mostrar plan
terraform_plan() {
    log_info "Generando plan de ejecución..."

    if ! terraform plan -input=false -out=tfplan; then
        log_error "Falló la generación del plan"
        exit 1
    fi

    log_success "Plan generado correctamente"
}

# Confirmar despliegue con opciones mejoradas
confirm_deployment() {
    echo
    log_warning "¿Estás seguro de que quieres continuar con el despliegue?"
    log_info "Esta operación creará recursos en AWS que pueden generar costos"
    echo

    local response
    while true; do
        read -p "Continuar con el despliegue? [y/N]: " -n 1 -r response
        echo
        case $response in
            [Yy]* )
                log_info "Continuando con el despliegue..."
                return 0
                ;;
            [Nn]* | "" )
                log_info "Despliegue cancelado por el usuario"
                rm -f tfplan
                exit 0
                ;;
            * )
                echo "Por favor responde 'y' para sí o 'n' para no."
                ;;
        esac
    done
}

# Aplicar cambios de Terraform
terraform_apply() {
    log_info "Desplegando recursos en AWS..."
    echo "=============================================="

    if ! terraform apply -input=false tfplan; then
        log_error "Falló el despliegue de recursos"
        exit 1
    fi

    # Limpiar archivo de plan
    rm -f tfplan

    log_success "¡Recursos desplegados exitosamente!"
}

# Mostrar información post-despliegue
show_post_deployment_info() {
    echo
    log_success "¡Despliegue completado!"
    echo "========================"

    # Mostrar outputs si existen
    if terraform output architecture_summary &> /dev/null; then
        terraform output architecture_summary
    else
        log_warning "No se encontró el output 'architecture_summary'"
        log_info "Outputs disponibles:"
        terraform output 2>/dev/null || log_info "No hay outputs definidos"
    fi

    echo
    log_info "🎯 Próximos pasos:"
    echo "1. Espera 2-3 minutos para que Flow Logs se activen"
    echo "2. Usa './scripts/demo.sh' para ejecutar la demo"
    echo "3. Revisa tu email para las alertas"
    echo
    log_warning "💰 Recuerda: Esta demo tiene costos asociados"
    log_info "🗑️  Usa './scripts/destroy.sh' para limpiar recursos cuando termines"
    echo
    log_info "📊 Para monitorear recursos: https://console.aws.amazon.com/"
}

# Función principal
main() {
    echo "🚀 Desplegando Arquitectura de Detección de Anomalías"
    echo "=================================================="
    echo

    check_and_setup_working_directory
    check_prerequisites
    check_aws_credentials
    check_config_files
    terraform_init
    terraform_validate
    terraform_plan
    confirm_deployment
    terraform_apply
    show_post_deployment_info
}

# Ejecutar función principal
main "$@"
