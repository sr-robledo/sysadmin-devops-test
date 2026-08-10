#!/bin/bash
# Sube todas las ramas al fork
set -e
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

for b in feat/bloque-a-server feat/bloque-b-docker feat/bloque-c-ci feat/bloque-d-terraform feat/bloque-f-incidencia docs/entrega chore/setup-scripts ; do
  echo "--- push $b ---"
  git push -u origin "$b" 2>&1 | tail -2
done
