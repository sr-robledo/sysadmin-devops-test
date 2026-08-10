#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source=/etc/inventario/backup.env
#
# backup-db.sh — Backup diario de la base de datos PostgreSQL de inventario.
#
# Diseñado para correr como servicio systemd (oneshot). El timer asociado
# está en systemd/inventario-backup.timer.
#
# Cambios principales respecto al original:
#   • set -euo pipefail + trap para que cualquier error aborte limpiamente
#   • Credenciales leídas de /etc/inventario/backup.env (no en el repo)
#   • mkdir -p (idempotente) en vez de mkdir a secas
#   • Patrones de find entre comillas: el original NUNCA borraba los
#     backups antiguos porque el shell expandía *.sql.gz antes de
#     pasárselo a find. Esa línea es la causa raíz de la incidencia
#     del Bloque F (231 backups en /var/backups/inventario).
#   • rm -rf $BACKUP_DIR/tmp/* eliminado: si un día ese directorio es
#     un symlink, te cargas el destino. La limpieza de temporales se
#     hace con trap y mktemp -d.
#   • Lock con flock para evitar solapes si dos ejecuciones coinciden.
#   • Validación post-pg_dump: si falla, el .sql incompleto se borra
#     y el gzip no se hace sobre un fichero corrupto.
#   • Fichero de salida con fecha ISO (YYYY-MM-DD), ordenable.
#   • Logging a /var/log/inventario/backup.log (rotación por logrotate).
#
# Variables de entorno esperadas (definidas en /etc/inventario/backup.env):
#   BACKUP_DIR, DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, RETENTION_DAYS

set -euo pipefail
IFS=$'\n\t'

# ─── Configuración por defecto ──────────────────────────────────────────
BACKUP_DIR="${BACKUP_DIR:-/var/backups/inventario}"
LOG_DIR="${LOG_DIR:-/var/log/inventario}"
LOG_FILE="${LOG_DIR}/backup.log"
LOCK_FILE="${BACKUP_DIR}/.backup.lock"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
ENV_FILE="${ENV_FILE:-/etc/inventario/backup.env}"

# ─── Cargar credenciales desde fichero externo ──────────────────────────
if [[ -r "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a; source "${ENV_FILE}"; set +a
else
  echo "[$(date -Iseconds)] ERROR: no se puede leer ${ENV_FILE}" >&2
  exit 1
fi

# ─── Logging ────────────────────────────────────────────────────────────
mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

log() { echo "[$(date -Iseconds)] $*"; }

# ─── Manejo de errores y limpieza segura de temporales ─────────────────
TMPDIR_WORK=""
# cleanup() se invoca desde `trap`; shellcheck no lo ve y marca SC2317.
# Marcamos la función entera con disable y al final del script
# restablecemos con disable= para no contaminar el resto.
# shellcheck disable=SC2317
cleanup() {
  local rc=$?
  [[ -n "${TMPDIR_WORK}" && -d "${TMPDIR_WORK}" ]] && rm -rf -- "${TMPDIR_WORK}"
  [[ -e "${LOCK_FILE}" ]] && rm -f -- "${LOCK_FILE}"
  if [[ ${rc} -ne 0 ]]; then
    log "ERROR: backup terminado con código ${rc}"
  fi
  exit "${rc}"
}
# shellcheck disable=SC2317
trap cleanup EXIT INT TERM

# ─── Lock (evitar dos backups simultáneos) ──────────────────────────────
mkdir -p "${BACKUP_DIR}"
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  log "Otro backup en curso (lock activo). Saliendo."
  exit 0
fi

# ─── Pre-flight ─────────────────────────────────────────────────────────
log "=== Iniciando backup ==="
log "Destino: ${BACKUP_DIR}"
log "BD: ${DB_NAME}@${DB_HOST}:${DB_PORT:-5432} como ${DB_USER}"
log "Retención: ${RETENTION_DAYS} días"

# Validar herramientas necesarias
for cmd in pg_dump gzip find flock; do
  command -v "${cmd}" >/dev/null 2>&1 || { log "Falta ${cmd}"; exit 1; }
done

# Directorio de trabajo temporal seguro (no en BACKUP_DIR, para evitar
# el patrón "rm -rf $BACKUP_DIR/tmp/* con symlink" del script original)
TMPDIR_WORK="$(mktemp -d -t inventario-backup-XXXXXX)"
log "Temporal: ${TMPDIR_WORK}"

# Fichero de salida con fecha ISO (ordenable) y nombre de BD
FECHA="$(date +%F)"   # YYYY-MM-DD
SQL_TMP="${TMPDIR_WORK}/inventario-${FECHA}.sql"
GZ_OUT="${BACKUP_DIR}/inventario-${FECHA}.sql.gz"

# No machacar el backup del día si ya existe
if [[ -e "${GZ_OUT}" ]]; then
  log "Ya existe ${GZ_OUT}, no se sobreescribe"
  exit 0
fi

# ─── pg_dump ────────────────────────────────────────────────────────────
export PGPASSWORD="${DB_PASSWORD}"
if ! pg_dump \
      --host="${DB_HOST}" \
      --port="${DB_PORT:-5432}" \
      --username="${DB_USER}" \
      --dbname="${DB_NAME}" \
      --no-owner \
      --no-privileges \
      --format=plain \
      --file="${SQL_TMP}"; then
  log "pg_dump falló — el backup no se completa"
  exit 1
fi

# Verificar que el dump no está vacío
if [[ ! -s "${SQL_TMP}" ]]; then
  log "pg_dump generó un fichero vacío — algo va mal"
  exit 1
fi

# ─── Comprimir (en destino) ────────────────────────────────────────────
if ! gzip -9 -c "${SQL_TMP}" > "${GZ_OUT}"; then
  log "gzip falló"
  rm -f -- "${GZ_OUT}"
  exit 1
fi

chmod 0640 "${GZ_OUT}"
log "Backup escrito: ${GZ_OUT} ($(du -h "${GZ_OUT}" | cut -f1))"

# ─── Limpieza de backups antiguos ─────────────────────────────────────
# OJO: el patrón va entre comillas para que find lo reciba literal y
# NO lo expanda el shell (eso era el fallo silencioso del original).
deleted=$(find "${BACKUP_DIR}" -maxdepth 1 -type f \
            -name 'inventario-*.sql.gz' -mtime "+${RETENTION_DAYS}" \
            -print -delete | wc -l)
log "Retención: ${deleted} backup(s) antiguo(s) borrado(s) (mtime > ${RETENTION_DAYS}d)"

# ─── Resumen ───────────────────────────────────────────────────────────
total=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name 'inventario-*.sql.gz' | wc -l)
log "Backups retenidos: ${total}"
log "=== Backup completado OK ==="
exit 0
