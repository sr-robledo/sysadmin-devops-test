#!/bin/bash
# Recopila evidencias para ENTREGA.md (Bloque A y B)
set +e
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

echo "================ EVIDENCIA: ufw status ================"
sudo ufw status verbose

echo
echo "================ EVIDENCIA: fail2ban ================"
sudo fail2ban-client status sshd

echo
echo "================ EVIDENCIA: timers systemd ================"
sudo systemctl list-timers 'inventario*' --all --no-pager

echo
echo "================ EVIDENCIA: backup-db.service status ================"
sudo systemctl status inventario-backup.service --no-pager

echo
echo "================ EVIDENCIA: journalctl backup.service ================"
sudo journalctl -u inventario-backup.service -n 10 --no-pager

echo
echo "================ EVIDENCIA: directorio de backups ================"
sudo ls -la /var/backups/inventario/

echo
echo "================ EVIDENCIA: docker compose ps ================"
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/compose"
sudo docker compose ps

echo
echo "================ EVIDENCIA: puertos del host ================"
sudo ss -tlnp | grep -E ':(80|443|5432|8080) ' || echo "(solo 80 debe estar)"

echo
echo "================ EVIDENCIA: curl health y ready ================"
curl -sS -w "\nHTTP %{http_code}\n" http://127.0.0.1/health
curl -sS -w "\nHTTP %{http_code}\n" http://127.0.0.1/ready

echo
echo "================ EVIDENCIA: docker images (tamaños) ================"
sudo docker images | grep -E 'inventario|postgres'

echo
echo "================ EVIDENCIA: shellcheck backup-db.sh ================"
shellcheck -x /usr/local/bin/backup-db.sh && echo "shellcheck OK"

echo
echo "================ EVIDENCIA: hadolint ================"
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
hadolint app/Dockerfile
echo "hadolint exit: $?"

echo
echo "================ EVIDENCIA: terraform fmt + validate ================"
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/terraform"
terraform fmt -check -recursive && echo "fmt OK"
terraform validate
