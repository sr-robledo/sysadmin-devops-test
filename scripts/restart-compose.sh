#!/bin/bash
set -e
sudo systemctl start docker
sleep 3
cd /mnt/h/Prueba\ cibervoluntarios/compose
sudo docker compose up -d 2>&1 | tail -5
sleep 8
echo "=== compose ps ==="
sudo docker compose ps
echo ""
echo "=== curl ==="
curl -sS -w "\nHTTP %{http_code}\n" http://127.0.0.1/health
curl -sS -w "\nHTTP %{http_code}\n" http://127.0.0.1/ready
