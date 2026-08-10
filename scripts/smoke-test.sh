#!/bin/bash
echo "=== POST /equipos ==="
curl -sS -X POST \
     -H "Content-Type: application/json" \
     -d '{"hostname":"srv-test-01","so":"Ubuntu 24.04","ubicacion":"Madrid"}' \
     -w "\nHTTP %{http_code}\n" \
     http://127.0.0.1/equipos

echo
echo "=== POST /equipos (segundo) ==="
curl -sS -X POST \
     -H "Content-Type: application/json" \
     -d '{"hostname":"srv-test-02","so":"Debian 12","ubicacion":"Barcelona"}' \
     -w "\nHTTP %{http_code}\n" \
     http://127.0.0.1/equipos

echo
echo "=== GET /equipos ==="
curl -sS -w "\nHTTP %{http_code}\n" http://127.0.0.1/equipos
