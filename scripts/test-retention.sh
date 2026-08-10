#!/bin/bash
# Test de retención: simula backups antiguos y verifica que se borran
set -e
BACKUP_DIR=/var/backups/inventario

# 3 backups de prueba: 30d, 10d, 1d
sudo touch -d "30 days ago" "${BACKUP_DIR}/inventario-2025-07-10.sql.gz"
sudo touch -d "10 days ago" "${BACKUP_DIR}/inventario-2025-07-30.sql.gz"
sudo touch -d "1 day ago"  "${BACKUP_DIR}/inventario-2025-08-09.sql.gz"
echo "Antes de la retención:"
ls -la "${BACKUP_DIR}/"

echo "--- Ejecutando backup ---"
sudo ENV_FILE=/etc/inventario/backup.env /mnt/h/Prueba\ cibervoluntarios/scripts/backup-db.sh 2>&1 | tail -8

echo "--- Tras la retención ---"
ls -la "${BACKUP_DIR}/"
