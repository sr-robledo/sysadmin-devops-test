#!/bin/bash
cd /mnt/h/Prueba\ cibervoluntarios
hadolint --config .hadolint.yaml app/Dockerfile
echo "hadolint exit: $?"
