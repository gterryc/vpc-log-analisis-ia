#!/bin/bash

echo "🗑️  Destruyendo Recursos de Demo"
echo "==============================="

echo "⚠️  ADVERTENCIA: Esto eliminará TODOS los recursos creados"
echo "   - VPC y subnets"
echo "   - Instancias EC2"
echo "   - Buckets S3 y contenido"
echo "   - Funciones Lambda"
echo "   - Topics SNS"
echo "   - Todos los datos de Flow Logs"
echo ""

read -p "¿Estás seguro de que quieres continuar? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Operación cancelada"
    exit 1
fi

echo "🧹 Limpiando recursos..."

# Eliminar recursos con Terraform
terraform destroy -auto-approve

echo "✅ Recursos eliminados exitosamente"
echo ""
echo "💡 Recuerda:"
echo "   - Los logs de CloudWatch pueden tardar en eliminarse"
echo "   - Verifica que no queden recursos huérfanos en la consola"
echo "   - Los buckets S3 se eliminaron con todo su contenido"