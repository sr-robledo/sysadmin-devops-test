#!/bin/bash
#
# provision-server.sh
# Aprovisionamiento idempotente del servidor de inventario.
# Pensado para ejecutarse sobre un Ubuntu 24.04 recién instalado.
# Se puede correr dos veces seguidas sin romper nada.
#
# Cubre: usuario admin, SSH hardened, ufw, actualizaciones
# automáticas y fail2ban. Todo lo que hace se imprime en pantalla
# para que sea fácil de auditar.
#
# Uso:
#   sudo ./provision-server.sh [PUERTO_SSH]
#
# Antes de ejecutarlo:
#   1. Copia tu clave pública a /tmp/authorized_keys
#      (o pásala como variable AUTHORIZED_KEY)
#   2. Asegúrate de que el puerto SSH (22 por defecto) es accesible

set -euo pipefail

# ─── Configuración ──────────────────────────────────────────────────────
ADMIN_USER="${ADMIN_USER:-sysadmin}"
SSH_PORT="${1:-${SSH_PORT:-22}}"
AUTHORIZED_KEY_FILE="${AUTHORIZED_KEY_FILE:-/tmp/authorized_keys}"
LOG_PREFIX="[provision]"

log()  { echo "${LOG_PREFIX} $*"; }
fail() { echo "${LOG_PREFIX} ERROR: $*" >&2; exit 1; }

# ─── Comprobaciones previas ─────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || fail "Este script necesita ejecutarse como root (sudo)."

if [ ! -f "${AUTHORIZED_KEY_FILE}" ]; then
  fail "No encuentro ${AUTHORIZED_KEY_FILE}. Copia ahí tu clave pública antes de continuar."
fi

. /etc/os-release
[ "${VERSION_CODENAME:-}" = "noble" ] || log "Aviso: este script está probado en Ubuntu 24.04 (noble). Versión detectada: ${VERSION_CODENAME:-desconocida}."

# ─── 1. Usuario sysadmin con sudo ───────────────────────────────────────
if ! id -u "${ADMIN_USER}" >/dev/null 2>&1; then
  log "Creando usuario ${ADMIN_USER}"
  adduser --disabled-password --gecos "Sysadmin Fundación" "${ADMIN_USER}"
  echo "${ADMIN_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"${ADMIN_USER}"
  chmod 0440 /etc/sudoers.d/"${ADMIN_USER}"
else
  log "Usuario ${ADMIN_USER} ya existe"
fi

# Asegurar sudo sin contraseña (idempotente)
echo "${ADMIN_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"${ADMIN_USER}"
chmod 0440 /etc/sudoers.d/"${ADMIN_USER}"

# ─── 2. Clave pública SSH ──────────────────────────────────────────────
install -d -m 0700 -o "${ADMIN_USER}" -g "${ADMIN_USER}" "/home/${ADMIN_USER}/.ssh"
install -m 0600 -o "${ADMIN_USER}" -g "${ADMIN_USER}" "${AUTHORIZED_KEY_FILE}" "/home/${ADMIN_USER}/.ssh/authorized_keys"
log "Clave pública instalada para ${ADMIN_USER}"

# ─── 3. Hardening de sshd_config ────────────────────────────────────────
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_CONFIG_DROPIN="/etc/ssh/sshd_config.d/00-hardening.conf"

install -d -m 0755 /etc/ssh/sshd_config.d
cat > "${SSHD_CONFIG_DROPIN}" <<EOF
# Hardening Fundación Cibervoluntarios
# Generado por provision-server.sh — sobreescrito en cada ejecución
Port ${SSH_PORT}
Protocol 2
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
UsePAM yes
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers ${ADMIN_USER}
EOF
chmod 0644 "${SSHD_CONFIG_DROPIN}"

# Asegurarse de que Include sshd_config.d/*.conf está activo (Ubuntu 24.04 ya lo trae)
if ! grep -qE '^Include /etc/ssh/sshd_config.d/\*\.conf' "${SSHD_CONFIG}"; then
  log "Aviso: ${SSHD_CONFIG} no incluye sshd_config.d/*.conf. Revísalo."
fi

# Validar configuración antes de recargar
sshd -t || fail "La configuración de sshd no pasa sshd -t. Abortando antes de recargar."
log "sshd -t OK. Recargando SSH en puerto ${SSH_PORT}"
systemctl reload ssh || systemctl restart ssh
log "SSH recargado"

# ─── 4. Firewall (ufw) ──────────────────────────────────────────────────
if ! command -v ufw >/dev/null 2>&1; then
  apt-get install -y -qq ufw >/dev/null
fi
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
# Permitir SSH en el puerto configurado
ufw allow "${SSH_PORT}"/tcp comment "SSH"
# Permitir HTTP/HTTPS para el proxy de la app
ufw allow 80/tcp  comment "HTTP nginx proxy"
ufw allow 443/tcp comment "HTTPS nginx proxy"
# (Intencionadamente NO se abre 5432 ni 8080: la DB y la API no son públicas.)
ufw --force enable
ufw status verbose | sed "s/^/${LOG_PREFIX} /"

# ─── 5. Actualizaciones automáticas ────────────────────────────────────
if ! dpkg -s unattended-upgrades >/dev/null 2>&1; then
  apt-get install -y -qq unattended-upgrades >/dev/null
fi
install -d /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# Origen: security + updates (noble)
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}:\${distro_codename}-updates";
};
Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailOnlyOnError "true";
EOF
log "Actualizaciones automáticas configuradas (security + updates, sin reboot)"

# ─── 6. fail2ban ────────────────────────────────────────────────────────
if ! dpkg -s fail2ban >/dev/null 2>&1; then
  apt-get install -y -qq fail2ban >/dev/null
fi
cat > /etc/fail2ban/jail.d/sshd.conf <<'EOF'
[DEFAULT]
backend = systemd
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh
mode    = aggressive
EOF
systemctl enable --now fail2ban >/dev/null
fail2ban-client status sshd 2>/dev/null | sed "s/^/${LOG_PREFIX} /" || log "fail2ban reiniciando…"

# ─── 7. Resumen final ──────────────────────────────────────────────────
cat <<EOF

${LOG_PREFIX} ────────────────────────────────────────────────────────────
${LOG_PREFIX} Aprovisionamiento completado
${LOG_PREFIX}   • Usuario:    ${ADMIN_USER} (sudo NOPASSWD, clave SSH)
${LOG_PREFIX}   • SSH:        puerto ${SSH_PORT}, sin root, sin password
${LOG_PREFIX}   • Firewall:   ufw activo (deny incoming, 22/80/443)
${LOG_PREFIX}   • Updates:    unattended-upgrades (security + updates)
${LOG_PREFIX}   • fail2ban:   sshd jail activo
${LOG_PREFIX}
${LOG_PREFIX} Para conectarte:
${LOG_PREFIX}   ssh -p ${SSH_PORT} ${ADMIN_USER}@<IP>
${LOG_PREFIX} ────────────────────────────────────────────────────────────
EOF
