#!/bin/bash
# Instala y activa el watchdog del backup
set -e

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mailutils >/dev/null

sudo install -m 0755 -o root -g root "$(cd "$(dirname "$0")/.." && pwd)"/scripts/backup-watchdog.sh /usr/local/bin/backup-watchdog.sh
sudo install -m 0644 -o root -g root "$(cd "$(dirname "$0")/.." && pwd)"/systemd/inventario-backup-watchdog.service /etc/systemd/system/
sudo install -m 0644 -o root -g root "$(cd "$(dirname "$0")/.." && pwd)"/systemd/inventario-backup-watchdog.timer    /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now inventario-backup-watchdog.timer

echo "=== shellcheck ==="
shellcheck -x /usr/local/bin/backup-watchdog.sh && echo "shellcheck OK"

echo "=== timer ==="
sudo systemctl list-timers inventario-backup-watchdog.timer --no-pager

echo "=== test manual ==="
sudo systemctl start inventario-backup-watchdog.service
sudo systemctl status inventario-backup-watchdog.service --no-pager | head -10
echo "=== journalctl -n 8 ==="
sudo journalctl -u inventario-backup-watchdog.service -n 8 --no-pager
