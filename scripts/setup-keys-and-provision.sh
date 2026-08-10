#!/bin/bash
# Genera clave, copia authorized_keys a sitio persistente y aprovisiona.
set -e

PERSIST="/var/tmp/cibervol"
sudo mkdir -p "$PERSIST"
sudo chown "$(id -u):$(id -g)" "$PERSIST"

# Generar clave si no existe
[ -f "$PERSIST/id_ed25519" ] || ssh-keygen -t ed25519 -N '' -f "$PERSIST/id_ed25519" -C 'sysadmin@inventario' >/dev/null
cp "$PERSIST/id_ed25519.pub" "$PERSIST/authorized_keys"
chmod 0600 "$PERSIST/id_ed25519"
chmod 0644 "$PERSIST/authorized_keys"
echo "Clave persistente en $PERSIST"

# Aprovisionar
sudo AUTHORIZED_KEY_FILE="$PERSIST/authorized_keys" \
     /mnt/h/Prueba\ cibervoluntarios/scripts/provision-server.sh 2222
