#!/bin/bash
# Crea las ramas por bloque y hace los commits limpios.
# El fork aún no existe: este script solo deja el repo preparado
# para `git push -u <origin> <rama>` cuando el usuario haga el fork.
set -e
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Asegurarse de partir de main limpio
git checkout main >/dev/null 2>&1
# git user: usa la config global si existe, si no pone algo neutro
git config user.email "$(git config --global user.email 2>/dev/null || echo noreply@inventario.local)"
git config user.name  "$(git config --global user.name 2>/dev/null || echo 'Alejandro Nomengongloro')"

# ─── Bloque A ────────────────────────────────────────────────────────
git checkout -b feat/bloque-a-server
git add scripts/provision-server.sh \
        scripts/setup-keys-and-provision.sh \
        scripts/install-systemd.sh \
        scripts/backup-db.sh \
        scripts/backup-watchdog.sh \
        scripts/install-watchdog.sh \
        systemd/inventario-backup.service \
        systemd/inventario-backup.timer \
        systemd/inventario-backup-watchdog.service \
        systemd/inventario-backup-watchdog.timer \
        etc/inventario/backup.env.example
git commit -m "Bloque A: hardening, script de backup arreglado y unidades systemd

- scripts/provision-server.sh: aprovisionamiento idempotente
  (usuario sysadmin, ssh hardened, ufw, unattended-upgrades, fail2ban).
- scripts/backup-db.sh: arregla el find sin comillas que no borraba
  los backups (causa raíz de la incidencia del Bloque F) y el
  rm -rf \$BACKUP_DIR/tmp/* destructivo. Pasa shellcheck.
- systemd/inventario-backup.{service,timer}: backup diario a las
  03:00 con Persistent=true para no perder la tarea si la máquina
  estaba apagada. Endurecido con ProtectSystem, PrivateTmp,
  SystemCallFilter, etc.
- scripts/backup-watchdog.sh + systemd/inventario-backup-watchdog:
  vigila que el último backup existe, gzip válido, tamaño y
  antigüedad correctas. Alerta por mail al root.
- etc/inventario/backup.env.example: plantilla de credenciales
  fuera del repo (0600 root:root)."

git checkout main >/dev/null 2>&1
git merge --no-ff feat/bloque-a-server -m "Merge bloque A"

# ─── Bloque B ────────────────────────────────────────────────────────
git checkout -b feat/bloque-b-docker
git add app/Dockerfile app/.dockerignore \
        compose/docker-compose.yml compose/nginx.conf \
        compose/.env.example
git commit -m "Bloque B: Dockerfile, compose y nginx endurecidos

- app/Dockerfile: multi-stage con python:3.12-slim-bookworm,
  USER no-root (uid 10001), gunicorn como servidor, tini como
  PID 1, HEALTHCHECK contra /ready, base fijada por digest.
  Reducción de tamaño de 1.79 GB a 217 MB.
- app/.dockerignore: evita que .git, __pycache__ y .venv entren
  en el contexto de build.
- compose/docker-compose.yml: secret management con .env,
  restart: unless-stopped, healthchecks en los 3 servicios,
  depends_on con condition: service_healthy. Eliminada la
  exposición de 5432 y 8080 al host. Quitados /var/run/docker.sock
  y privileged: true del proxy (era dar root al host).
- compose/nginx.conf: timeouts razonables, server_tokens off,
  cabeceras X-Real-IP y X-Forwarded-{For,Proto}.
- compose/.env.example: plantilla de credenciales, fuera del repo."

git checkout main >/dev/null 2>&1
git merge --no-ff feat/bloque-b-docker -m "Merge bloque B"

# ─── Bloque C ────────────────────────────────────────────────────────
git checkout -b feat/bloque-c-ci
git add .github/workflows/ .hadolint.yaml
git commit -m "Bloque C: CI con GitHub Actions (lint + build)

- .github/workflows/lint.yml: shellcheck, hadolint, compose
  validate, yamllint. Corre en push y pull_request. Acciones
  fijadas por SHA completo.
- .github/workflows/build.yml: build + push a GHCR. Diferencia
  entre push (push a GHCR con tags sha-/semver/latest) y
  pull_request (solo build, no push). Cache de capas con GHA.
- .hadolint.yaml: configuración de hadolint con los ignores
  documentados."

git checkout main >/dev/null 2>&1
git merge --no-ff feat/bloque-c-ci -m "Merge bloque C"

# ─── Bloque D ────────────────────────────────────────────────────────
git checkout -b feat/bloque-d-terraform
git add terraform/
git commit -m "Bloque D: Terraform para la base de datos

- terraform/versions.tf: required_version y required_providers
  con kreuzwerker/docker ~> 3.0.2.
- terraform/variables.tf: variables con tipo, descripción y
  default. db_password sensitive=true.
- terraform/main.tf: red bridge, volumen con prevent_destroy
  para no perder datos, contenedor PostgreSQL con healthcheck.
- terraform/outputs.tf: red, contenedor, volumen, host (sin
  la contraseña).
- terraform/terraform.tfvars.example: plantilla sin secretos.
- terraform/README.md: cómo se usa, tratamiento del state."

git checkout main >/dev/null 2>&1
git merge --no-ff feat/bloque-d-terraform -m "Merge bloque D"

# ─── Bloque F ────────────────────────────────────────────────────────
git checkout -b feat/bloque-f-incidencia
git add docs/incidencia.md
git commit -m "Bloque F: análisis de la incidencia del 02-08-2026

Causa raíz: la línea
    find \$BACKUP_DIR -name *.sql.gz -mtime +\$RETENTION_DAYS -exec rm {} \;
no borraba nada porque el shell expandía el *.sql.gz antes de
pasárselo a find. Ocho meses de backups acumulándose. Disco lleno.
PostgreSQL cae por falta de espacio para WAL. La API no resuelve
db. Nginx devuelve 502.

El documento incluye: cadena causal, dos pistas falsas analizadas
(el docker compose up -d del compañero y el load average),
mecanismo exacto del find, resolución inmediata con los pasos
peligrosos marcados, resolución de fondo ordenada por
coste/beneficio, y los dos fallos de la monitorización."

git checkout main >/dev/null 2>&1
git merge --no-ff feat/bloque-f-incidencia -m "Merge bloque F"

# ─── ENTREGA.md ─────────────────────────────────────────────────────
git checkout -b docs/entrega
git add ENTREGA.md
git commit -m "ENTREGA.md: documento principal de la prueba

Resumen, suposiciones, entorno, decisiones por bloque, evidencias,
y respuestas a las preguntas obligatorias de D y E."

git checkout main >/dev/null 2>&1
git merge --no-ff docs/entrega -m "Merge ENTREGA.md"

# ─── Chore: setup y herramientas ────────────────────────────────────
git checkout -b chore/setup-scripts
git add scripts/install-docker.sh \
        scripts/install-tools.sh \
        scripts/install-systemd.sh \
        scripts/install-watchdog.sh \
        scripts/check-dockerfile.sh \
        scripts/compare-image-sizes.sh \
        scripts/collect-evidence.sh \
        scripts/lint-hadolint.sh \
        scripts/lint-yaml.sh \
        scripts/restart-compose.sh \
        scripts/smoke-test.sh \
        scripts/test-retention.sh \
        scripts/test-terraform.sh \
        scripts/test-terraform-destroy.sh \
        scripts/test-terraform-persistence.sh \
        scripts/test-watchdog.sh
git commit -m "Chore: scripts de setup, test y validación

Scripts auxiliares usados durante la prueba para:
- Instalar el entorno (Docker, terraform, shellcheck, hadolint, gh).
- Probar el script de backup (test-retention, test-watchdog).
- Probar el compose (smoke-test, restart-compose).
- Probar Terraform (init/apply/destroy + persistencia del volumen).
- Recopilar evidencias y validar lints (lint-yaml, lint-hadolint,
  collect-evidence, compare-image-sizes).
- Instalar el script de backup y el watchdog como unidades systemd.

No son parte de la entrega en producción, pero quedan en el
repo como muestra del proceso de trabajo y para reproducibilidad."

git checkout main >/dev/null 2>&1
git merge --no-ff chore/setup-scripts -m "Merge scripts de setup"

# ─── Final ──────────────────────────────────────────────────────────
git checkout main
echo ""
echo "=== Historial final ==="
git log --oneline --graph --all | head -40
echo ""
echo "=== Estado ==="
git status --short
