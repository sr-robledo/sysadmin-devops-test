#!/bin/bash
cd /mnt/h/Prueba\ cibervoluntarios
echo "=== hadolint ==="
hadolint app/Dockerfile
echo "exit: $?"
echo ""
echo "=== docker build (primera vez) ==="
cd app
docker build -t inventario-api:new .
echo "exit: $?"
echo ""
echo "=== docker images ==="
docker images | head -10
