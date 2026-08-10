#!/bin/bash
set -e
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/terraform"

# Asegurar que docker está arriba (lo paramos en algún test)
sudo systemctl start docker 2>/dev/null || true
sleep 2

# Limpiar contenedores previos que pueden chocar
sudo docker rm -f inventario-db-tf 2>/dev/null || true

# Usar una contraseña dummy pero suficiente para postgres
export TF_VAR_db_password="test_terraform_pass_123"
export TF_VAR_db_name="inventario"
export TF_VAR_db_user="inventario"
export TF_VAR_db_image="postgres:16-alpine"

echo "=== terraform fmt ==="
terraform fmt -recursive -check
echo "OK"
echo ""
echo "=== terraform init ==="
terraform init -input=false
echo ""
echo "=== terraform validate ==="
terraform validate
echo ""
echo "=== terraform plan (sin aplicar) ==="
terraform plan -no-color -input=false
echo ""
echo "=== terraform apply ==="
terraform apply -auto-approve -no-color -input=false
echo ""
echo "=== docker ps ==="
sudo docker ps | grep -E 'inventario|NAMES' || true
echo ""
echo "=== segundo plan (debe decir no changes) ==="
terraform plan -no-color -input=false
