#!/bin/bash
set -e
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
for b in feat/bloque-a-server feat/bloque-b-docker feat/bloque-c-ci \
         feat/bloque-d-terraform feat/bloque-f-incidencia docs/entrega \
         chore/setup-scripts ; do
  echo "--- merge $b ---"
  git merge --no-ff "$b" -m "Merge $b en rama de integración" 2>&1 | tail -2
done
echo ""
echo "--- log ---"
git log --oneline | head -25
