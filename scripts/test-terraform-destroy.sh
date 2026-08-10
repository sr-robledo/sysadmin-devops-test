#!/bin/bash
set -e
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/terraform"

export TF_VAR_db_password="test_terraform_pass_123"
export TF_VAR_db_name="inventario"
export TF_VAR_db_user="inventario"
export TF_VAR_db_image="postgres:16-alpine"

# Crear datos en la BD
sudo docker exec inventario-db-tf psql -U inventario -d inventario \
  -c "CREATE TABLE IF NOT EXISTS t (id int); INSERT INTO t VALUES (1),(2),(3),(4),(5);" >/dev/null 2>&1 || true
echo "Filas en BD antes del destroy: $(sudo docker exec inventario-db-tf psql -U inventario -d inventario -t -c 'SELECT count(*) FROM t;' | xargs)"

echo ""
echo "=== terraform destroy (target = contenedor y red, NO el volumen) ==="
terraform destroy \
  -target=docker_container.db \
  -target=docker_network.backend \
  -auto-approve -no-color -input=false

echo ""
echo "=== Después del destroy ==="
echo "-- containers (debe estar vacío):"
sudo docker ps -a | grep inventario-db-tf && echo "ERROR" || echo "  (ninguno, correcto)"
echo "-- volumes (DEBE seguir existiendo):"
sudo docker volume ls | grep inventario-db-tf-data && echo "  OK: el volumen persiste"
echo ""
echo "=== Recreo contenedor y confirmo que los datos siguen ==="
export TF_VAR_container_name="inventario-db-tf-restore"
terraform apply -auto-approve -no-color -input=false 2>&1 | tail -5
echo "Filas tras restaurar: $(sudo docker exec inventario-db-tf-restore psql -U inventario -d inventario -t -c 'SELECT count(*) FROM t;' | xargs 2>/dev/null || echo 'no accesible todavía')"

echo ""
echo "=== Limpio todo ==="
terraform destroy -auto-approve -no-color -input=false
sudo docker volume rm inventario-db-tf-data 2>&1
