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