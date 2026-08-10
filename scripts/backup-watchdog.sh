#!/usr/bin/env bash
# shellcheck shell=bash
#
# backup-watchdog.sh
# Se ejecuta cada 30 min (inventario-backup-watchdog.timer) y comprueba
# que el último backup de inventario existe, no está vacío y es reciente.
#
# Si algo va mal, escribe en el journal y (si hay `mail` configurado) envía
# un correo al root con el detalle. Exit 0 = OK, exit 1 = problema.
#
# Proporcional para una organización pequeña: nada de stacks de
# monitorización completos. Lo que pide el enunciado A.5: "que si el
# backup falla, alguien lo sepa".

set -euo pipefail
IFS=$'\n\t'

BACKUP_DIR="${BACKUP_DIR:-/var/backups/inventario}"
MAX_AGE_HOURS="${MAX_AGE_HOURS:-26}"   # el backup diario debe existir; 26h da margen
MIN_SIZE_BYTES="${MIN_SIZE_BYTES:-1024}"  # un .sql.gz de BD vacía ≈ unos pocos KB

ADMIN_TO="${ADMIN_TO:-root}"  # se redirige a sistemas@ en el alias de root

log_err() { echo "[$(date -Iseconds)] WATCHDOG ERROR: $*" >&2; }
log_ok()  { echo "[$(date -Iseconds)] WATCHDOG OK: $*"; }

# Último backup = el inventario-*.sql.gz más reciente (por nombre ISO)
last_file="$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name 'inventario-*.sql.gz' -print0 2>/dev/null \
              | sort -z | tail -z -n 1 | tr -d '\0' || true)"

if [[ -z "${last_file}" ]]; then
  log_err "No existe ningún backup en ${BACKUP_DIR}"
  echo "No hay ningún backup de inventario en ${BACKUP_DIR}. Revisar el servicio inventario-backup.service y los logs." \
    | mail -s "[inventario][ALERTA] No hay backups" "${ADMIN_TO}" 2>/dev/null || true
  exit 1
fi

# Comprobar tamaño
size=$(stat -c%s "${last_file}")
if (( size < MIN_SIZE_BYTES )); then
  log_err "Backup ${last_file} demasiado pequeño (${size} bytes)"
  echo "El último backup (${last_file}) tiene ${size} bytes, parece corrupto o vacío." \
    | mail -s "[inventario][ALERTA] Backup vacío/corrupto" "${ADMIN_TO}" 2>/dev/null || true
  exit 1
fi

# Comprobar antigüedad
age_min=$(( ( $(date +%s) - $(stat -c%Y "${last_file}") ) / 60 ))
max_age_min=$(( MAX_AGE_HOURS * 60 ))
if (( age_min > max_age_min )); then
  log_err "Último backup ${last_file} tiene ${age_min} min (> ${max_age_min})"
  echo "El último backup (${last_file}) tiene $((age_min/60))h. Debería ser < ${MAX_AGE_HOURS}h." \
    | mail -s "[inventario][ALERTA] Backup antiguo" "${ADMIN_TO}" 2>/dev/null || true
  exit 1
fi

# Verificar integridad gzip
if ! gzip -t "${last_file}" 2>/dev/null; then
  log_err "Backup ${last_file} no pasa gzip -t"
  echo "El último backup (${last_file}) no es un gzip válido." \
    | mail -s "[inventario][ALERTA] Backup corrupto" "${ADMIN_TO}" 2>/dev/null || true
  exit 1
fi

log_ok "Último backup ${last_file} OK (${size} bytes, antigüedad $((age_min/60))h$((age_min%60))m)"
exit 0
