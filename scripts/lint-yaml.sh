#!/bin/bash
set -e
cd /mnt/h/Prueba\ cibervoluntarios
echo "=== yamllint workflows + compose ==="
yamllint -d '{extends: default, rules: {line-length: disable, document-start: disable, truthy: {check-keys: false}}}' .github/workflows
echo "---"
yamllint -d '{extends: default, rules: {line-length: disable, document-start: disable, truthy: {check-keys: false}}}' compose/docker-compose.yml
echo "OK"
