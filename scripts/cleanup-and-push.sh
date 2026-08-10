#!/bin/bash
# Commit de limpieza: gitignore completo, scripts saneados, tfstate fuera.
set -e
cd /mnt/h/Prueba\ cibervoluntarios

# 1. Reescribe el .gitignore con exclusiones de terraform
cat > .gitignore <<'EOF'
# Punto de partida. Amplíalo con lo que haga falta según lo que uses.
# Revisar qué debe ir aquí es parte de la prueba: hay cosas que generan
# Terraform, Docker o tu editor que no deberían acabar en el repositorio.

# Secretos y entorno
.env
*.env
!.env.example
etc/inventario/backup.env
!etc/inventario/backup.env.example
*.pem
*.key
id_rsa*
id_ed25519*

# Sistema operativo y editores
.DS_Store
Thumbs.db
.idea/
.vscode/
*.swp
*~

# Python
__pycache__/
*.pyc
.pytest_cache/
.ruff_cache/
.mypy_cache/
.coverage
htmlcov/
.venv/
venv/

# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfstate.backup
.terraform.lock.hcl
tfplan
tfplan.json
crash.log
crash.*.log

# Docker
docker-compose.override.yml
compose/.env
EOF

# 2. Quita del index (sin tocar el disco) los archivos sensibles
git rm --cached -r terraform/.terraform 2>/dev/null || true
git rm --cached terraform/.terraform.lock.hcl 2>/dev/null || true
git rm --cached terraform/terraform.tfstate 2>/dev/null || true
git rm --cached terraform/terraform.tfstate.backup 2>/dev/null || true

# 3. Stage todo lo demás (scripts saneados, .gitignore, etc.)
git add .gitignore scripts/

# 4. Ver qué se va a commitear
echo "=== Cambios a commitear ==="
git status --short

echo ""
echo "=== Commit ==="
git commit -m "fix(security): gitignore completo + scripts saneados + tfstate fuera del repo

- .gitignore: añade exclusiones de Terraform y Docker (estaban ausentes
  en el .gitignore inicial, lo que permitió que se subiera el tfstate
  con la contraseña de la BD de prueba en claro).
- scripts/*: rutas absolutas /mnt/h/... reemplazadas por REPO_ROOT
  calculado desde la ubicación del script. Los scripts ahora son
  portables y no exponen el path del entorno de desarrollo.
- terraform/.terraform, terraform.tfstate*, .terraform.lock.hcl:
  eliminados del repo (los archivos generados no deben versionarse).
- setup-commits.sh: email del autor del commit se toma de la config
  global de git en lugar de un valor hardcodeado."

echo ""
echo "=== Push a integration ==="
git push origin integration
echo ""
echo "=== Estado ==="
git status
