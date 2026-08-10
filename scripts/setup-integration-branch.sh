#!/bin/bash
# Crea la rama de integración desde el commit original del fork y
# le mergea todas las features en orden. Luego pushea la rama.
set -e
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# SHA del commit base (justo antes de cualquier trabajo nuestro)
BASE=$(git log --oneline | grep "chore: añade .gitignore inicial" | head -1 | awk '{print $1}')
echo "Base SHA: $BASE"

# Crear la rama de integración desde ese commit
git checkout -b integration "$BASE"

# Mergear en orden
for b in feat/bloque-a-server feat/bloque-b-docker feat/bloque-c-ci \
         feat/bloque-d-terraform feat/bloque-f-incidencia docs/entrega \
         chore/setup-scripts ; do
  echo "--- merge $b ---"
  git merge --no-ff "$b" -m "Merge $b en rama de integración"
done

# Volver a main y pushear la rama
git checkout main
git push -u origin integration
echo ""
echo "=== commits de la rama integration ==="
git log --oneline integration | head -25
