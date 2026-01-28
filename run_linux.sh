#!/bin/bash

# Script de inicio para Suray POS OFICINA en Linux

echo "🚀 Iniciando Suray POS OFICINA..."
echo ""

# Verificar si Flutter está instalado
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter no está instalado o no está en el PATH"
    echo "   Instale Flutter desde: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Verificar si estamos en el directorio correcto
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Este script debe ejecutarse desde el directorio raíz del proyecto"
    exit 1
fi

# Obtener dependencias si es necesario
if [ ! -d ".dart_tool" ]; then
    echo "📦 Obteniendo dependencias..."
    flutter pub get
fi

# Ejecutar la aplicación
echo "▶️  Ejecutando aplicación en Linux..."
flutter run -d linux

