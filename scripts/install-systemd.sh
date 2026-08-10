#!/bin/bash
# Raíz del repo (calculada desde la ubicación del script)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Instala y activa el timer de backup. Lo ejecuta todo en una sola sesión
# para que systemctl no pierda el bus entre llamadas.
set -e

SCRIPT_SRC="${REPO_ROOT}/scripts/backup-db.sh"
SERVICE_SRC="${REPO_ROOT}/systemd/inventario-backup.service"
TIMER_SRC="${REPO_ROOT}/systemd/inventario-backup.timer"

echo "=== Instalando script y unidades ==="
sudo install -m 0755 -o root -g root "$SCRIPT_SRC"   /usr/local/bin/backup-db.sh
sudo install -m 0644 -o root -g root "$SERVICE_SRC"  /etc/systemd/system/inventario-backup.service
sudo install -m 0644 -o root -g root "$TIMER_SRC"    /etc/systemd/system/inventario-backup.timer

echo "=== Verificando unidades ==="
sudo systemd-analyze verify /etc/systemd/system/inventario-backup.service || true
sudo systemd-analyze verify /etc/systemd/system/inventario-backup.timer   || true

echo "=== Recargando systemd y activando timer ==="
sudo systemctl daemon-reload
sudo systemctl enable --now inventario-backup.timer

echo "=== Estado del timer ==="
sudo systemctl status inventario-backup.timer --no-pager || true

echo "=== Timers activos ==="
sudo systemctl list-timers --all --no-pager | head -20

echo "=== Probando el service manualmente ==="
sudo systemctl start inventario-backup.service
sudo systemctl status inventario-backup.service --no-pager || true
echo "=== journalctl -n 15 ==="
sudo journalctl -u inventario-backup.service -n 15 --no-pager || true
