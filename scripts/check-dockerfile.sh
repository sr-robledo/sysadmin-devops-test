#!/bin/bash
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
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
