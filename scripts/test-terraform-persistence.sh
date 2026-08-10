#!/bin/bash
set -e
cd /mnt/h/Prueba\ cibervoluntarios/terraform

export TF_VAR_db_password="test_terraform_pass_123"
export TF_VAR_db_name="inventario"
export TF_VAR_db_user="inventario"
export TF_VAR_db_image="postgres:16-alpine"
unset TF_VAR_container_name

# Recrear el contenedor
echo "=== apply (contenedor) ==="
terraform apply -target=docker_container.db -target=docker_network.backend \
  -auto-approve -no-color -input=false 2>&1 | tail -3
sleep 5

echo ""
echo "=== Comprobar que los datos siguen ahí ==="
echo "Filas tras restaurar: $(sudo docker exec inventario-db-tf psql -U inventario -d inventario -t -c 'SELECT count(*) FROM t;' 2>/dev/null | xargs)"

echo ""
echo "=== terraform output ==="
terraform output -no-color

echo ""
echo "=== Limpiar todo ==="
terraform destroy -target=docker_container.db -target=docker_network.backend \
  -auto-approve -no-color -input=false 2>&1 | tail -2
sudo docker volume rm inventario-db-tf-data
