#!/bin/bash
# Compara tamaños de imagen
set +e
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
echo "=== Construir imagen original (para comparar) ==="
sudo docker build -f app/Dockerfile.original -t inventario-api:original app/ 2>&1 | tail -3
echo ""
echo "=== Construir imagen nueva ==="
sudo docker build -f app/Dockerfile -t inventario-api:new app/ 2>&1 | tail -3
echo ""
echo "=== Tamaños ==="
sudo docker images | grep inventario-api
