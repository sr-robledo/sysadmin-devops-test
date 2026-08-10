#!/bin/bash
set -e
cd "${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
echo "=== yamllint workflows + compose ==="
yamllint -d '{extends: default, rules: {line-length: disable, document-start: disable, truthy: {check-keys: false}}}' .github/workflows
echo "---"
yamllint -d '{extends: default, rules: {line-length: disable, document-start: disable, truthy: {check-keys: false}}}' compose/docker-compose.yml
echo "OK"
