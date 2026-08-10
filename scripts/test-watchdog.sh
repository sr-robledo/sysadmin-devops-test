#!/bin/bash
# Test integral del flujo backup + watchdog
set -e

echo "=== 1) Llenar BD con datos ==="
sudo docker exec pg-test psql -U inventario -d inventario \
  -c "INSERT INTO t SELECT generate_series(1,5000);" 2>&1 | tail -1
count=$(sudo docker exec pg-test psql -U inventario -d inventario \
  -t -c "SELECT count(*) FROM t;" | xargs)
echo "Filas en BD: $count"

echo ""
echo "=== 2) Ejecutar backup-db.sh ==="
sudo rm -f /var/backups/inventario/inventario-2026-08-10.sql.gz
sudo ENV_FILE=/etc/inventario/backup.env /usr/local/bin/backup-db.sh 2>&1 | tail -8

echo ""
echo "=== 3) Ejecutar watchdog ==="
sudo /usr/local/bin/backup-watchdog.sh
echo "Exit: $?"

echo ""
echo "=== 4) Estado del timer ==="
sudo systemctl list-timers 'inventario*' --all --no-pager

echo ""
echo "=== 5) Listado backups ==="
ls -la /var/backups/inventario/
