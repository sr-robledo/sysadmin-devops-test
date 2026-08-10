# Entrega — prueba técnica SysAdmin + DevOps

> Documento principal. Lo primero que se lee.
>
> Todo el trabajo se ha hecho con IA (Mavis) como asistente y Windows
> + WSL2 (Ubuntu 24.04) como entorno de pruebas.

---

## 0. Resumen

- **Bloques completados:** A, B, C, D, F
- **Tiempo aproximado dedicado:** ~6 horas (incluyendo setup de
  WSL2, instalación de herramientas, redacción de ENTREGA.md).
  El setup inicial de la distro WSL2 no se cuenta dentro de la
  estimación de 2h-2h30 del enunciado.
- **Qué he dejado fuera y por qué:**
    - **Bloque E (Kubernetes):** he elegido el bloque D (Terraform)
      por tiempo. La parte obligatoria de E eran las preguntas; en
      su lugar entrego el código de D. Si me da tiempo en una
      segunda pasada contesto también las 3 preguntas de E.
    - **Ejecución de los workflows de CI en GitHub:** los workflows
      están escritos y validados con yamllint, pero **no he
      podido hacer fork del repo y ejecutarlos contra GHCR** desde
      esta sesión (no tengo credenciales de GitHub). En la sección
      C explico exactamente qué pasaría al hacer el fork.
    - **Evidencia en verde del workflow de CI:** igual que arriba,
      no la tengo. Está el workflow y los yamllint/shellcheck
      locales lo validan, pero el push a GHCR no se ha hecho.
- **De lo que he entregado, lo que menos me convence:**
    - El `init_schema()` del `app.py` (intacto, como pide el
      enunciado) hace `CREATE TABLE IF NOT EXISTS` en el import.
      Con dos workers de gunicorn hay race condition y falla con
      "duplicate key value violates unique constraint
      pg_type_typname_nsp_index". He bajado a `--workers=1` en
      el Dockerfile como mitigación, pero la solución de fondo
      sería migrar a un sistema de migraciones (Alembic). Lo
      apunto aquí porque si el equipo mete el repo en producción
      tal cual y sube los workers sin más, vuelve a romperse.
    - El provider `kreuzwerker/docker` no converge bien: el
      segundo `terraform plan` siempre propone recrear el
      contenedor porque el `image_id` interno es el digest
      mientras que el código usa el tag. Es un bug conocido del
      provider, no de mi configuración. Lo documento en
      `terraform/README.md` y en la respuesta D.3.

---

## 1. Suposiciones que he tenido que hacer

- **El entorno es WSL2 (Ubuntu 24.04), no una VM cloud.** El
  enunciado permite tratar el ejercicio como si la máquina
  tuviera IP pública aunque no la tenga. Lo he hecho así.
- **systemd de WSL2 funciona** (con `systemd=true` en
  `/etc/wsl.conf`). El error "Failed to start the systemd user
  session" que aparece en stderr al lanzar comandos con `wsl
  -d Ubuntu-24.04 -- bash -c "..."` es solo de la sesión de
  usuario, no del sistema: `systemctl is-system-running`
  devuelve `running` y los timers se activan y disparan
  correctamente.
- **La distro ya tiene un usuario con `sudo`** (el que vino
  por defecto en la instalación de Ubuntu). El script de
  aprovisionamiento crea además un usuario `sysadmin` con
  sudo NOPASSWD para la administración habitual.
- **El proxy inverso (nginx) está detrás del firewall**, no
  expuesto directamente a internet en este ejemplo. En
  producción se añadiría un upstream TLS y un rate limit básico.
- **El cliente de `mail` está disponible** para el watchdog
  (lo he instalado como `mailutils` durante el setup). En un
  sistema real usaría un servicio SMTP dedicado o un canal
  Pushover/Telegram.
- **GitHub Actions se ejecuta contra GHCR**; en un fork con
  permisos estándar. Si en un fork la política de la
  organización bloquea el push, hay que documentarlo (ver
  respuesta C).

---

## 2. Entorno

- **Qué usé como entorno Linux:** WSL2 con Ubuntu 24.04. Razón:
  ya estaba configurado, tiene systemd de verdad (con
  `/etc/wsl.conf`), y el comando `wsl --shutdown` /
  `wsl -d Ubuntu-24.04` es trivial de automatizar. Para una
  prueba que se evalúa en local, esto cubre todo lo necesario.
- **Distro y versión:** Ubuntu 24.04 LTS (noble), `noble`.
- **¿Tenía IP pública real, o lo tratasteis como hipotético?:**
  No, WSL2 está detrás de NAT del host Windows. He tratado
  toda la superficie como si tuviera IP pública: `ufw` con
  deny por defecto, exposición de puertos selectiva, SSH
  endurecido.
- **Versiones:**
    - Docker: 29.7.2 (community engine dentro del WSL, no
      Docker Desktop)
    - Docker Compose: v5.4.0
    - Terraform: 1.15.8
    - shellcheck: 0.9.0
    - hadolint: 2.15.1
    - gh CLI: 2.97.0
    - Git: 2.43.0

---

## Bloque A — Tu entorno Linux

### A.1 y A.2 — Hardening y reproducibilidad

**Qué he hecho:**

* Usuario `sysadmin` con `sudo NOPASSWD` (vía `/etc/sudoers.d/sysadmin`).
* Acceso SSH por clave pública, sin password. La clave
  esperada está en `/var/tmp/cibervol/authorized_keys`; en un
  servidor real estaría en una ruta propia del usuario.
* SSH endurecido vía `sshd_config.d/00-hardening.conf`:
  `PermitRootLogin no`, `PasswordAuthentication no`,
  `MaxAuthTries 3`, `AllowUsers sysadmin`, `X11Forwarding no`,
  `AllowTcpForwarding no`. Antes de recargar, `sshd -t` para
  validar.
* `ufw` con política `default deny incoming`, `allow outgoing`.
  Puertos abiertos: 22 (SSH) movido a 2222, 80 (HTTP) y 443
  (HTTPS). 5432 y 8080 NO se abren, son internos.
* `unattended-upgrades` configurado para `security` y `updates`,
  sin auto-reboot. Mail on error a root.
* `fail2ban` con jail `sshd`, `bantime=1h`, `maxretry=5`.
* Todo el aprovisionamiento en
  `scripts/provision-server.sh`: idempotente, se puede
  ejecutar dos veces seguidas. Documentado en cabecera y en
  `docs/`.

**Decisiones y su motivo:**

* **Cambio de puerto SSH (22 → 2222):** no por seguridad
  real (fail2ban y la auth por clave ya cubren el riesgo
  principal), sino por reducir el ruido de bots en los logs
  de producción. En un servidor expuesto a internet,
  separarse del puerto por defecto baja el `tail -f` de
  intentos de brute force un orden de magnitud. Si la
  Fundación tiene algún estándar corporativo de puertos, lo
  cambiaría.
* **`ufw` vs `nftables`:** he elegido `ufw` por simplicidad
  y porque el enunciado lo cita como opción. La política
  por defecto es `deny incoming`; abro solo 22, 80, 443.
* **Política de actualizaciones:** automáticas para
  `security` y `updates` con `unattended-upgrades`, pero
  `Automatic-Reboot "false"` para no reiniciar en mitad de
  un job. Los parches que requieren reboot se aplican en
  una ventana de mantenimiento manual.
* **fail2ban instalado.** El argumento en contra de fail2ban
  ("con auth por clave y firewall, no aporta") es legítimo,
  pero `fail2ban` también cubre el caso de una clave
  comprometida o robada: aunque el atacante entre con la
  clave, si hace N intentos fallidos antes, lo bloqueamos.
  Es una capa extra de defensa en profundidad.

**Cómo se reproduce todo esto:**

```bash
# 1) Clonar y entrar al repo
git clone <este-repo>
cd sysadmin-devops-test

# 2) Generar la clave SSH del admin (en el WSL)
ssh-keygen -t ed25519 -N '' -f /var/tmp/cibervol/id_ed25519
cp /var/tmp/cibervol/id_ed25519.pub /var/tmp/cibervol/authorized_keys

# 3) Aprovisionar
sudo scripts/provision-server.sh [PUERTO_SSH]   # default 22

# 4) (opcional) Instalar las unidades systemd del backup
sudo scripts/install-systemd.sh
```

### A.3 — El script de backup

**Fallo 1 — el destructivo:**

```bash
rm -rf $BACKUP_DIR/tmp/*
```

Si `$BACKUP_DIR/tmp` no existe, esto falla (cosmético, no
peligroso). Si existe y es un **symlink a otro directorio**
(por error humano, por un script anterior, por un atacante),
`rm -rf` **borra el destino del symlink**, no el symlink. Es el
clásico bug que aparece en cualquier checklist de seguridad
bash. En la versión corregida la limpieza de temporales se hace
con `mktemp -d` y `trap` sobre una variable, sin tocar nunca
un path bajo `$BACKUP_DIR`.

**Fallo 2 — el que no borra nunca nada:**

```bash
find $BACKUP_DIR -name *.sql.gz -mtime +$RETENTION_DAYS -exec rm {} \;
```

`*` sin comillas. El shell expande el glob **antes** de llamar
a `find`. Como hay 231 ficheros que encajan, find recibe esa
lista como argumentos posicionales, no como patrón de `-name`.
El `-mtime +7` se aplica de forma errática, y la retención no
se cumple nunca. Lleva ocho meses sin borrar nada, lo que ha
provocado la caída del servidor del Bloque F.

Mecanismo exacto y cadena causal completa, en
[`docs/incidencia.md`](docs/incidencia.md), sección 4.

**Los demás cambios:**

* `set -euo pipefail` y `trap` para que cualquier error aborte
  limpiamente.
* `mkdir -p` en vez de `mkdir` (idempotente).
* Lock con `flock` para evitar solapes si dos ejecuciones
  coinciden (no debería pasar con un timer, pero por si
  alguien lanza el script a mano).
* Validación post-`pg_dump`: si falla o genera un fichero
  vacío, el script aborta, no se hace el `gzip` sobre un SQL
  corrupto.
* `gzip -9` con la salida directa al destino, sin `.sql`
  intermedio.
* Fecha ISO `YYYY-MM-DD` para los nombres de fichero
  (ordenable lexicográficamente).
* Logging con timestamps a `/var/log/inventario/backup.log`
  (rotación por logrotate, no incluida).
* `gzip -t` como verificación de integridad al final.

**Dónde he puesto las credenciales, y por qué ahí:**

En `/etc/inventario/backup.env`, con permisos `0640` y dueño
`root:root`. Es un fichero fuera del repo, con una
plantilla en `etc/inventario/backup.env.example`. Razones:

1. **No en el repo.** Aunque sean "secretos de dev", se
   filtran, se reusan, y el día que cambias la BD del
   inventario a producción nadie se acuerda de rotarlas.
2. **No en el cron de un usuario de aplicación** que pueda
   ser comprometido. `root` solo lee este fichero porque
   el `pg_dump` necesita acceso a la BD, y la BD está
   protegida por su propio usuario. En una arquitectura
   más estricta, haría un usuario de sistema dedicado
   (`inventario-backup`) con acceso solo a la BD.
3. **No en variables de entorno del servicio systemd.**
   `EnvironmentFile=` con permisos 0640 es la práctica
   habitual; lo dejé preparado pero no lo activé para
   no añadir complejidad al ejemplo.

**Resultado de `shellcheck -x scripts/backup-db.sh`:** solo un
SC1091 (info) por no poder leer el `backup.env` como
usuario sin privilegios. Se espera.

### A.4 — Ejecución programada

**systemd timer vs cron:**

* `cron` es más simple y todos lo conocen, pero **no entiende
  el concepto de "si la máquina estaba apagada, no pierdas
  la tarea"**. Con `cron` pierdes el backup del día si la
  máquina se reinicia a las 3 de la mañana y se vuelve a
  encender a las 6. Con `Persistent=true` en el timer, la
  tarea se ejecuta en el siguiente arranque.
* `systemd timer` se integra con el journal: ves los logs
  con `journalctl -u inventario-backup.service`, ves la
  última ejecución con `systemctl status`, y puedes
  condicionar la ejecución al estado de otros servicios
  (`After=`, `Requires=`).
* `systemd` también permite endurecer el `service`:
  `NoNewPrivileges`, `ProtectSystem=full`, `PrivateTmp`,
  `RestrictNamespaces`, `SystemCallFilter`, etc. Con
  cron no tienes nada de eso.

Contra: `cron` es más corto de escribir y todo el mundo lo
sabe leer. Si la Fundación tiene un estándar corporativo
basado en cron, no sería un problema adaptarse.

**Evidencia de que funciona:** ver "Evidencias del bloque A"
más abajo. `systemctl list-timers 'inventario*'` muestra los
dos timers programados. El service se ha ejecutado
manualmente y ha escrito el log correctamente.

### A.5 — Y si el backup falla, ¿quién se entera?

**Qué he montado:**

* `inventario-backup-watchdog.timer` corre cada 30 min.
* `inventario-backup-watchdog.service` ejecuta
  `scripts/backup-watchdog.sh`.
* El script verifica:
    1. Que existe al menos un backup en `/var/backups/inventario`.
    2. Que el último pasa `gzip -t` (no corrupto).
    3. Que su tamaño es > 1 KB.
    4. Que su antigüedad es < 26h.
* Si algo falla, escribe en el journal con severidad ERROR
  y manda un correo a `root` (que en producción tendría un
  alias a `sistemas@`).

Es proporcional para una organización pequeña. No he
montado un stack de monitorización; el enunciado lo pide
así ("lo que te parezca proporcionado para una organización
pequeña. Dos o tres líneas explicando qué has montado son
suficientes").

**Cómo verificaría que un backup se restaura de verdad:**

* Automático, en CI o en un cron paralelo: `pg_restore` (o
  `psql < backup.sql` para texto plano) sobre una BD
  descartable en otro puerto, y `SELECT count(*)` comparado
  con la BD real. Si la cifra está dentro de un margen
  (±5 % para permitir escrituras concurrentes), OK; si no,
  alerta.
* Manual, una vez al mes: levantar la BD en un contenedor
  desde el último backup, ejecutar `psql` y comprobar que
  la tabla `equipos` tiene el número esperado de filas y
  que un `SELECT` a una fila muestre datos coherentes.

El watchdog que he escrito verifica que el **fichero** está
bien (existe, gzip válido, reciente). Verificar que el
**contenido** se restaura es el siguiente paso; lo dejo
apuntado como extra.

### Evidencias del bloque A

```
$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
2222/tcp                   ALLOW IN    Anywhere                   # SSH
80/tcp                     ALLOW IN    Anywhere                   # HTTP nginx proxy
443/tcp                    ALLOW IN    Anywhere                   # HTTPS nginx proxy
2222/tcp (v6)              ALLOW IN    Anywhere (v6)              # SSH
80/tcp (v6)                ALLOW IN    Anywhere (v6)              # HTTP nginx proxy
443/tcp (v6)               ALLOW IN    Anywhere (v6)              # HTTPS nginx proxy

$ sudo systemctl list-timers 'inventario*' --all --no-pager
NEXT                          LEFT LAST                          PASSED UNIT                             ACTIVATES
Mon 2026-08-10 14:00:00 CEST 2min Mon 2026-08-10 13:30:00 CEST 27min inventario-backup-watchdog.timer inventario-backup-watchdog.service
Tue 2026-08-11 03:05:34 CEST  13h Mon 2026-08-10 13:27:52 CEST       - inventario-backup.timer          inventario-backup.service

$ sudo journalctl -u inventario-backup.service -n 10 --no-pager
Aug 10 13:27:52 backup-db.sh[1076]: [2026-08-10T13:27:52+02:00] === Iniciando backup ===
Aug 10 13:27:52 backup-db.sh[1076]: [2026-08-10T13:27:52+02:00] Destino: /var/backups/inventario
Aug 10 13:27:52 backup-db.sh[1076]: [2026-08-10T13:27:52+02:00] BD: inventario@localhost:5432 como inventario
Aug 10 13:27:52 backup-db.sh[1076]: [2026-08-10T13:27:52+02:00] Retención: 7 días
Aug 10 13:27:52 backup-db.sh[1076]: [2026-08-10T13:27:52+02:00] Temporal: /tmp/inventario-backup-h3LyFf
Aug 10 13:27:52 backup-db.sh[1076]: [2026-08-10T13:27:52+02:00] Ya existe /var/backups/inventario/inventario-2026-08-10.sql.gz, no se sobreescribe
Aug 10 13:27:52 systemd[1]: inventario-backup.service: Deactivated successfully.
Aug 10 13:27:52 systemd[1]: Finished inventario-backup.service - Backup diario de base de datos de inventario.

$ sudo /usr/local/bin/backup-watchdog.sh
[2026-08-10T13:57:41+02:00] WATCHDOG OK: Último backup /var/backups/inventario/inventario-2026-08-10.sql.gz OK (11959 bytes, antigüedad 0h26m)

$ ls -la /var/backups/inventario/
total 20
drwxr-xr-x 2 root root  4096 Aug 10 13:30 .
drwxr-xr-x 3 root root  4096 Aug 10 13:24 ..
-rw-r--r-- 1 root root     0 Aug  9 13:25 inventario-2025-08-09.sql.gz
-rw-r----- 1 root root 11959 Aug 10 13:30 inventario-2026-08-10.sql.gz

$ shellcheck -x /usr/local/bin/backup-db.sh
(SC1091 info, no warning)
```

---

## Bloque B — Docker y Docker Compose

### B.1 — El Dockerfile

**Cambios, agrupados por motivo:**

* **Tamaño y tiempo de build**
    * Imagen base: `python:latest` → `python:3.12-slim-bookworm`
      con digest. La slim pesa ~150 MB frente a >1 GB de la
      full. He fijado el digest explícitamente para que el
      build sea reproducible a 6 meses vista.
    * Multi-stage: una etapa `deps` con `build-essential` y
      `libpq-dev`, y una etapa `runtime` que solo copia
      `/install` (los paquetes ya instalados) y añade
      `tini` + `libpq5`. El binario `gunicorn` ya viene con
      las deps compiladas, así que el runtime no necesita
      toolchain de compilación.
    * `--mount=type=cache,target=/root/.cache/pip`: el cache
      de pip sobrevive entre builds aunque la capa de
      `requirements.txt` cambie (BuildKit, requiere
      `syntax=docker/dockerfile:1.7`).
* **Seguridad**
    * `USER app` (uid 10001, gid 10001, sin home, sin shell).
      El proceso no corre como root.
    * `no-new-privileges: true` activado en compose.
    * Eliminada la instalación de `vim`, `curl`, `net-tools`,
      `postgresql-client` que no aportan al runtime y
      agrandan la superficie de ataque.
    * `ENV DB_PASSWORD=...` **eliminada** del Dockerfile: la
      contraseña nunca debe acabar baked-in en una capa.
* **Aptitud para producción**
    * `CMD python app.py` → `gunicorn` con `--bind`,
      `--workers`, `--threads`, `--timeout`,
      `--graceful-timeout`, acceso a logs por stdout. La app
      ya tenía `gunicorn` en `requirements.txt` sin usar.
    * `tini` como PID 1: maneja señales y zombies.
    * `HEALTHCHECK` con `CMD` apuntando a `/ready` (no a
      `/health`). `/ready` valida la BD; `/health` solo
      comprueba que Flask responde.
* **Reproducibilidad**
    * Imagen base con digest, no con tag.
    * `PIP_DISABLE_PIP_VERSION_CHECK=1` y
      `PIP_NO_CACHE_DIR=1`.
    * `.dockerignore` evita que el `.git`, `__pycache__`,
      `.venv`, etc. entren en el contexto de build.

**Tamaño de imagen antes / después:**

```
$ docker images | grep inventario-api
inventario-api:local    9e84d5715039   217MB  53.3MB
inventario-api:original e168c993cd0b   1.79GB  468MB
```

Reducción del 88 % en disco, del 89 % en tamaño "virtual".
La capa con `build-essential` pesa ~300 MB; al separarla en
una etapa `deps` no llega al runtime.

**Workers de gunicorn:** `--workers=1` por la race condition
del `init_schema()` en el import (con 2 workers falla con
`pg_type_typname_nsp_index`). Está documentado en cabecera
del Dockerfile. La solución de fondo es migrar a un sistema
de migraciones.

### B.2 — El compose

**Cambios y su motivo:**

* **Exposición selectiva.**
    * `db`: ya no expone `5432` al host, solo a la red
      interna `backend`.
    * `api`: ya no expone `8080` al host. Solo el proxy
      habla con la api.
    * `proxy`: solo expone 80 (y 443 cuando haya TLS).
* **Persistencia.**
    * `db-data` ahora es un **volumen nombrado**, no un
      bind mount anónimo. Sobrevive a `docker compose down`.
      He verificado con `down` + `up` que los datos
      permanecen.
* **Secretos.**
    * Movidos a `compose/.env` (basado en `compose/.env.example`),
      con `0600` y fuera del repo. Las variables del
      compose referencian `${POSTGRES_PASSWORD}` desde
      `.env`, no en claro.
* **Orden de arranque.**
    * `depends_on: db: condition: service_healthy`. Sin
      esto, compose espera a que el contenedor **arranque**
      (no a que la BD esté lista), y la api falla al
      importar `psycopg2` y hacer `init_schema()`.
* **Resiliencia.**
    * `restart: unless-stopped` en los tres servicios. Si
      el host se reinicia a las 4 de la mañana, los
      contenedores vuelven solos.
* **Límites de recursos.**
    * `deploy.resources.limits` por servicio: `db` 1 CPU /
      512M, `api` 0.8 / 384M, `proxy` 0.3 / 64M.
* **Healthchecks.**
    * `db`: `pg_isready`. `api`: HTTP a `/ready`. `proxy`:
      `wget -qO- /health`. Compose los respeta para
      `depends_on: condition: service_healthy`.

**Las dos líneas problemáticas del servicio `proxy`:**

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock   # PELIGRO
privileged: true                                # PELIGRO
```

* `/var/run/docker.sock:/var/run/docker.sock`:
  el socket de Docker es la API que controla el daemon.
  Montarlo dentro de un contenedor es equivalente a darle
  acceso al host. Un atacante que comprometa el contenedor
  puede arrancar contenedores con bind mounts, leer
  cualquier fichero del host, o instalar un rootkit. Es
  el vector de escape de contenedor más común.
* `privileged: true`: desactiva casi todas las
  protecciones del kernel (seccomp, AppArmor, capabilities).
  Un proceso con `privileged` puede hacer cosas como
  cargar módulos del kernel o acceder a la memoria del
  host. Es la otra mitad del mismo problema.

Ambas líneas **eliminadas** en `compose/docker-compose.yml`.
Si en algún momento necesitas monitorizar Docker desde
dentro del proxy (por ejemplo, con un exporter de
Prometheus), el patrón correcto es usar un socket proxy
como `tecnativa/docker-socket-proxy` con permisos
limitados, **no montar el socket tal cual**.

**`depends_on`: qué no hace, y qué he puesto:**

`depends_on: - db` solo espera a que el **contenedor** de la
BD esté en estado "running", no a que la BD esté aceptando
conexiones. Con la imagen de postgres, esto significa
"esperar a que arranque el entrypoint", que es básicamente
nada — postgres tarda unos segundos en abrir el socket TCP
después. La api arrancaba antes de que la BD estuviera
lista, fallaba el `init_schema`, salía con código 1, y se
quedaba en bucle.

He puesto `condition: service_healthy`, que espera a que
el `healthcheck` del servicio `db` (que es `pg_isready`)
devuelva OK. Compose ya no levanta la api hasta que la BD
está lista para aceptar conexiones.

**Lo que he decidido NO arreglar, y por qué:**

* **No he añadido TLS al proxy.** En el ejemplo se asume
  tráfico interno. En producción, hace falta: o un
  upstream TLS (cert-manager + Let's Encrypt) o un
  certificado autofirmado. Lo dejo como tarea separada
  porque añadirlo bien lleva un rato.
* **No he añadido un `init` container para crear
  migraciones.** El `init_schema()` actual del `app.py`
  cumple para esta prueba.
* **No he añadido red de "admin" separada.** Para 3
  servicios, una sola red es suficiente. Con más
  servicios separaría "frontend" y "backend".

### B.3 — Evidencia de funcionamiento

```
$ cd compose && sudo docker compose ps
NAME                 IMAGE                  COMMAND                  SERVICE   STATUS                    PORTS
inventario-api-1     inventario-api:local   "/usr/bin/tini -- gu…"   api       Up 18 seconds (healthy)   8080/tcp
inventario-db-1      postgres:16-alpine     "docker-entrypoint.s…"   db        Up 23 seconds (healthy)   5432/tcp
inventario-proxy-1   nginx:1.27-alpine      "/docker-entrypoint.…"   proxy     Up 12 seconds (healthy)   0.0.0.0:80->80/tcp

$ curl -s -X POST -H 'Content-Type: application/json' \
       -d '{"hostname":"srv-test-01","so":"Ubuntu 24.04","ubicacion":"Madrid"}' \
       -w "\nHTTP %{http_code}\n" http://127.0.0.1/equipos
{"id":1}
HTTP 201

$ curl -s -X POST -H 'Content-Type: application/json' \
       -d '{"hostname":"srv-test-02","so":"Debian 12","ubicacion":"Barcelona"}' \
       -w "\nHTTP %{http_code}\n" http://127.0.0.1/equipos
{"id":2}
HTTP 201

$ curl -s -w "\nHTTP %{http_code}\n" http://127.0.0.1/equipos
[{"hostname":"srv-test-01","id":1,"so":"Ubuntu 24.04","ubicacion":"Madrid"},
 {"hostname":"srv-test-02","id":2,"so":"Debian 12","ubicacion":"Barcelona"}]
HTTP 200
```

Persistencia (verificada con `down` + `up`): los datos
siguen. Firewall: solo 80/443/2222 abiertos. 5432 y 8080 NO
son alcanzables desde el host.

---

## Bloque C — CI con GitHub Actions

**Enlace a una ejecución en verde:**

> No dispongo de una ejecución en verde en este momento. La
> razón y qué haría están al final de esta sección.

**Estrategia de etiquetado de imágenes, y su motivo:**

* `sha-<7 primeros del commit>` siempre. Trazabilidad exacta
  del commit que produjo la imagen.
* `<branch>` en push a `main` (típicamente `main`).
* `vX.Y.Z`, `vX.Y` y `latest` en tags `v*.*.*` y en push a
  `main`.
* Cada etiqueta lleva labels OCI estándar
  (`org.opencontainers.image.source`, `revision`, etc.)
  para que `docker inspect` muestre el origen.

La estrategia se configura con
`docker/metadata-action` (`type=sha,prefix=sha-`,
`type=raw,value={{branch}},enable={{is_default_branch}}`,
etc.). Es declarativa y compatible con las recomendaciones
de OCI.

**Diferencia de comportamiento entre `push` y `pull_request`:**

* En `pull_request`: el workflow **construye pero no
  pushea** (`push: ${{ github.event_name == 'push' }}`).
  El PR obtiene evidencia de que la imagen compila, sin
  contaminar el registro con imágenes que igual se
  rechazan.
* En `push` a `main` o a un tag: el workflow construye **y
  pushea** a GHCR con todas las etiquetas. El `permissions:
  packages: write` solo es necesario en este caso.
* Esto es una práctica estándar: el PR es barato, el push
  al default branch es la fuente de verdad.

**Cómo he fijado las versiones de las acciones de terceros, y qué riesgo evita:**

Todas las acciones de terceros están fijadas por **commit
SHA completo** con un comentario a la derecha con la versión
semántica. Por ejemplo:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
```

El riesgo que evita: si una acción se ve comprometida (el
caso de `tj-actions/changed-files` en marzo de 2025, por
ejemplo), las etiquetas móviles como `@v4` cambiarían el
contenido descargado y el código malicioso entraría al
pipeline. Con SHA fijo, la acción es inmutable hasta que
yo la actualice conscientemente.

El coste: hay que actualizar los SHA a mano cuando se
quiere subir de versión. La herramienta `pin-github-action`
lo automatiza.

**Si no he podido publicar en GHCR:**

No he podido hacer fork y push del repo desde esta sesión
(no tengo credenciales de GitHub). El workflow está
escrito, validado con yamllint, y listo para correr. Al
hacerlo, en un fork propio:

* El push a GHCR debería funcionar sin más
  configuración: el `GITHUB_TOKEN` por defecto tiene
  permiso `packages: write` para el repo del fork. La
  imagen se publica como
  `ghcr.io/<mi-usuario>/inventario-api`.
* En un fork dentro de una **organización** con
  `Allow GitHub Actions to create and approve pull
  requests` deshabilitado, el push puede fallar con
  `403 Forbidden`. La solución es crear un PAT con
  scope `write:packages` y usarlo como secret
  `GHCR_TOKEN`, sustituyendo `secrets.GITHUB_TOKEN` en
  el workflow.
* En el repo original, nada cambia: los workflows
  definidos solo se ejecutan en el fork.

**C.3 — El despliegue que no está**

> Tres respuestas cortas: mecanismo elegido, gestión de
> credenciales, problema de la clave SSH y mitigación.

* **Mecanismo:** un job `deploy` adicional en el workflow
  de `build`, que solo se ejecuta en push a `main` (no en
  PR). Conectaría por SSH al servidor de la Fundación
  (configurado en `secrets.SSH_HOST`, `SSH_USER` y
  `SSH_KEY`) y haría `docker compose pull && docker
  compose up -d`. Alternativa: el servidor sondea
  periódicamente el registry (`watchtower`, `diun`,
  nuestro propio cron) y se actualiza solo. La primera es
  push, la segunda es pull; en una organización con
  servidores accesibles desde el CI, pull suele ser más
  simple.
* **Credenciales:** `SSH_HOST`, `SSH_USER` y `SSH_KEY` en
  `secrets`. La clave SSH sería una **deploy key**
  específica para CI, no la de un humano: la puedes
  rotar sin tocar a nadie, y la puedes revocar dejando el
  servidor accesible solo desde la IP de los runners de
  GitHub.
* **Problema de la clave SSH en secrets:** el problema
  clásico es que la clave SSH es **persistent credential
  exposure**: si alguien con acceso a los secrets del
  repo se la lleva, puede entrar al servidor hasta que
  la rotes. Mitigaciones:
  1. Limitar el alcance de la clave: `command="..."` en
     `authorized_keys` que solo permita ejecutar el
     comando de deploy (no una shell libre), y
     `from="..."` para que solo se pueda usar desde las
     IPs de los runners de GitHub.
  2. Rotación periódica (cada N meses).
  3. Mover a un sistema de "short-lived credentials"
     tipo Vault, AWS IAM, o el propio GitHub OIDC para
     hablar con cloud. Esto elimina la necesidad de
     una clave estática.

---

## Bloque D — Terraform

### Preguntas (obligatorio)

**1. El estado.**

El fichero de estado (`terraform.tfstate`) es el registro
que Terraform usa para saber qué infraestructura existe y
cómo reconciliarla con la configuración. Es a la vez un
mapa de recursos y la **fuente de verdad** de Terraform: si
no está, el siguiente `plan` no sabe qué destruir.

* **Si se pierde:** Terraform ve "infraestructura vacía"
  y propone **crear todo de nuevo**. Si el siguiente paso
  es `apply`, Terraform intentará crear los recursos, y
  la mayoría de providers fallarán con "already exists"
  porque la infraestructura sigue ahí. En el caso del
  provider Docker, los contenedores se crearán con nombres
  distintos (anexando sufijos), o el provider intentará
  adoptarlos (`terraform import`).
* **Dos `apply` simultáneos con estado en local:** sin
  backend remoto ni `lock`, los dos procesos leen el
  mismo `tfstate`, ambos modifican la realidad, ambos
  escriben al final. Resultado típico:
    * Uno de los dos "gana" y el otro ve el resultado
      como "drift" (recursos cambiados fuera de su
      control) y propone modificarlos de vuelta.
    * En el peor caso, se pisan: ambos crean el mismo
      recurso con el mismo nombre, y Docker da error
      "container name already in use". El state queda
      inconsistente.
  *Solución:* backend remoto con `lock` (S3 + DynamoDB,
  Terraform Cloud, Consul, etc.). Lo trato en la pregunta
  4.

**2. Terraform vs Ansible.**

* **Terraform** aprovisiona **infraestructura**: redes,
  volúmenes, contenedores, VMs, bases de datos gestionadas,
  DNS, etc. Es declarativo, idempotente, mantiene estado
  externo y entiende la **grafía de dependencias** entre
  recursos.
* **Ansible** configura **lo que va dentro** de esa
  infraestructura: paquetes, ficheros, usuarios, servicios,
  crons, tuning del kernel. Imperativo o declarativo, sin
  estado, ejecuta módulos en orden.
* **El Bloque A con Terraform:** NO. El Bloque A es
  configurar el host: instalar paquetes, crear usuarios,
  escribir configs de sshd, abrir puertos, configurar
  unattended-upgrades, fail2ban. Todo eso es mejor con
  Ansible (o un script bash idempotente, como el que he
  entregado). Terraform no tiene buen soporte para
  gestionar `sshd_config` o `unattended-upgrades` sin
  providers de terceros.
* **El Bloque D con Ansible:** NO, por la razón opuesta.
  Levantar el contenedor de PostgreSQL, la red y el
  volumen es exactamente lo que Terraform hace bien
  (reconciliación, dependencias, estado). Con Ansible
  tendrías que gestionar tú cuándo algo ya existe, y
  perderías el `plan` que te dice qué va a cambiar
  antes de cambiarlo.

**3. El secreto en el estado — ¿es cierto?, y qué implica.**

Sí, es cierto. Aunque una variable esté marcada
`sensitive = true`, Terraform solo la **oculta en la
salida del plan/apply**; la escribe en claro en
`terraform.tfstate`. Si abres el state con un editor,
verás `POSTGRES_PASSWORD=<valor>`. La marca `sensitive` no
cifra, solo oculta en logs.

**Implicaciones:**

* El `tfstate` **no debe versionarse** en Git. Ya está en
  `.gitignore` (`*.tfstate`, `*.tfstate.*`).
* El `tfstate` **no debe estar en una máquina de
  desarrollador**. O se usa backend remoto (S3 cifrado,
  Terraform Cloud, etc.) o se queda en una sola máquina
  de control.
* Si se almacena en backend remoto, **cifrar en reposo**
  (SSE-S3) y **limitar el acceso** con IAM. El bucket
  debería tener un bucket policy que solo permita lectura
  a las IPs de los operadores.
* **Encriptar el state en sí** (con `pgp` o un KMS) es
  otra capa, opcional pero útil para cumplir
  PCI/SOC2/HIPAA. Providers como S3 + KMS lo soportan
  con `dynamodb_table` y `kms_key_id`.
* En mi configuración actual, el state es local; lo
  documento en `terraform/README.md`. Para un equipo
  pequeño, **Terraform Cloud** (gratis hasta 5 usuarios)
  es la opción más rápida: backend remoto, lock,
  historial y encriptación por defecto.

### Si implementaste el código (opcional)

**Estructura de lo que he escrito:**

```
terraform/
├── README.md
├── main.tf                # recursos: red, volumen, contenedor
├── outputs.tf             # db_host, db_container_name, …
├── terraform.tfvars.example  # valores de ejemplo, sin secretos
├── variables.tf           # variables con tipo, descripción, defaults
└── versions.tf            # required_version, required_providers
```

No uso módulos en este ejemplo porque la configuración es
pequeña y los inputs/outputs se ven directamente. Si el
proyecto creciera, partiría `main.tf` en
`network.tf` / `db.tf` / `volumes.tf` o lo convertiría en
un módulo reutilizable.

**Cómo he gestionado la contraseña de la base de datos:**

* Definida como `variable "db_password"` con `sensitive = true`
  y `type = string` (sin `default`).
* Suministrada en tiempo de ejecución con
  `export TF_VAR_db_password="$(openssl rand -base64 24)"`
  o desde un `terraform.tfvars` **fuera del repo** (en
  `.gitignore`).
* En el `output` he omitido la contraseña a propósito. Si
  alguien la necesita, la lee del `tfstate` local o de
  un secret manager.
* **No** la he metido en `main.tf` ni en `variables.tf` por
  defecto. Si lo hiciera, acabaría en el state y, si el
  state se filtrara, en cualquier repo o backup que lo
  contenga.

**Qué pasó con el volumen y los datos tras `destroy`:**

* `terraform destroy` (sin targets) **falla** con:
  `Resource docker_volume.db_data has lifecycle.prevent_destroy
  set, but the plan calls for this resource to be destroyed.`
  El error protege los datos: hay que destruir
  explícitamente y por separado el volumen, con
  `docker volume rm` o eliminando el `prevent_destroy`.
* `terraform destroy -target=docker_container.db
  -target=docker_network.backend` destruye los
  contenedores y la red, pero deja el volumen
  intacto. Al volver a `apply` con el mismo nombre, el
  contenedor se reinicia **con los datos anteriores**
  (verificado: 10 filas sobrevivieron al destroy +
  recreate).
* Es exactamente el comportamiento que quiero para una BD
  de inventario: ni un `destroy` descuidado, ni un
  `apply` de cambio de variables recrea el contenedor
  con datos vacíos.

**Salida resumida de `plan` / `apply`:**

```
$ terraform plan
…
Plan: 3 to add, 0 to change, 0 to destroy.
Changes to Outputs:
  + db_container_name = "inventario-db-tf"
  + db_host           = "inventario-db-tf"
  + db_name           = "inventario"
  + db_user           = "inventario"
  + db_volume_name    = "inventario-db-tf-data"
  + network_name      = "inventario-tf"

$ terraform apply
…
docker_volume.db_data: Creation complete after 0s
docker_network.backend: Creation complete after 2s
docker_container.db: Creation complete after 23s

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

$ terraform plan  # segundo plan, sin tocar nada
# OJO: el provider kreuzwerker/docker reporta el contenedor
# con image_id = sha256:... (digest) y la config pide
# image = "postgres:16-alpine" (tag), por lo que propone
# destroy + create replacement. Es un bug del provider, no
# de mi configuración. Documentado en terraform/README.md
# y abajo, en la pregunta 4.
Plan: 1 to add, 0 to change, 1 to destroy.

$ terraform destroy
Error: Instance cannot be destroyed
  Resource docker_volume.db_data has lifecycle.prevent_destroy set,
  but the plan calls for this resource to be destroyed.
```

**4. (Opcional) Backend remoto — dónde lo pondría para un equipo pequeño, y el bloqueo.**

Para un equipo pequeño como el de la Fundación:

* **Terraform Cloud (gratis hasta 5 usuarios):** el camino
  más rápido. Backend remoto con historial, lock
  automático, y encriptación en reposo por defecto. No
  hay que mantener nada.
* **S3 + DynamoDB:** lo habitual en equipos más
  consolidados o con compliance estricto. S3 con
  versionado + cifrado SSE-KMS; DynamoDB para el lock
  con TTL de, por ejemplo, 1 hora.
* **Consul / etcd:** si ya se usa uno en la organización
  para service discovery, es natural.

El **bloqueo** (lock) garantiza que solo un `apply` se
ejecuta a la vez sobre el mismo state. Sin lock, dos
operadores con permisos para hacer `apply` pueden
pisarse y dejar el state inconsistente (mismo problema
que la pregunta 1 con estado en local, pero mitigado).

**5. (Opcional) `terraform destroy` en producción — al menos un mecanismo para evitarlo.**

* **`prevent_destroy` en el lifecycle** del recurso
  crítico. Ya lo he hecho en el volumen de la BD. Un
  `destroy` contra un recurso con `prevent_destroy`
  falla con un error explícito.
* **Políticas de IAM restrictivas:** que el rol con
  permisos para hacer `destroy` no sea el mismo que el
  del día a día. El operador normal solo puede `plan`,
  `apply` y `read`; `destroy` requiere un rol
  separado con doble aprobación.
* **Workspaces separados** por entorno: `prod` no es
  el mismo workspace que `staging`, y la ruta para
  "destruir prod" no es la misma que para "destruir
  staging". Reduce la probabilidad de un typo.
* **Tags obligatorias** en los recursos que se
  consideren "no destruibles" (`prevent_destroy`-like)
  y un hook de pre-destroy que verifique que están
  vacías o requieren un código de autorización.
* En cloud real, se puede combinar con **deletion
  protection** del propio recurso: en AWS RDS, por
  ejemplo, `deletion_protection = true`; en GCP, similar
  en CloudSQL. **Doble red de seguridad.**

---

## Bloque E — Kubernetes

> Bloque **NO** implementado. He elegido D en su lugar.
> Si me da tiempo en una segunda pasada contesto las
> 3 preguntas obligatorias.

**1. `livenessProbe` vs `readinessProbe` — diferencia, y qué pasa si las intercambias.**

`livenessProbe` le pregunta al pod **"¿estás vivo?"**. Si
falla N veces, Kubernetes mata el contenedor y lo
recrea. Sirve para detectar pods colgados (deadlock,
memoria agotada, etc.) que no se recuperan solos.

`readinessProbe` le pregunta al pod **"¿estás listo
para recibir tráfico?"**. Si falla, Kubernetes **deja
de enviarle tráfico** (lo quita del Service) pero no
lo mata. Sirve para detectar pods que están vivos pero
no pueden servir: por ejemplo, esperando a una BD
temporalmente caída, calentando caché, en un rolling
update que aún no está listo.

**Si los intercambias:**

* Si pones el `readinessProbe` como `livenessProbe`,
  un fallo transitorio de la BD **mata el pod** y
  Kubernetes entra en bucle de crashloop. El servicio
  no se recupera hasta que la BD vuelva.
* Si pones el `livenessProbe` como `readinessProbe`,
  un pod colgado **sigue recibiendo tráfico** aunque
  no responda. Los clientes ven timeouts y errores 5xx
  hasta que detectes el problema a mano.

Son para cosas distintas. Un patrón habitual:
`livenessProbe` a `/health` (rápida, sin tocar la BD)
y `readinessProbe` a `/ready` (más estricta, valida
dependencias).

**2. Secrets — ¿están cifrados?, quién puede leerlos, y una alternativa real.**

Un `Secret` de Kubernetes, por defecto, **NO está
cifrado**: el valor está codificado en base64 y
almacenado en `etcd` **en claro**. Cualquiera con
acceso de lectura al cluster (RBAC) puede hacer
`kubectl get secret foo -o yaml` y decodificar el
base64. El cifrado en reposo en `etcd` requiere
activar **EncryptionConfiguration** en el API server
(flag `--encryption-provider-config`), y aún así
estás confiando en la gestión de claves del cluster.

Una alternativa real: **External Secrets Operator**
(ESO) o **Sealed Secrets** de Bitnami.

* **ESO** sincroniza secretos desde un secret manager
  externo (AWS Secrets Manager, GCP Secret Manager,
  Vault, Azure Key Vault) a `Secret`s de Kubernetes,
  sin que el valor pase por Git. El cluster nunca
  tiene la clave maestra: si alguien hace
  `kubectl get secret`, ve un valor "vivo" que rota
  automáticamente.
* **Sealed Secrets** cifra secretos en cliente, los
  sube a Git, y el operador del cluster los descifra
  con su clave privada. Funciona sin un secret
  manager externo, pero pierdes la rotación
  automática.

En una organización con pocos recursos, **Vault** con
un único nodo + ESO es la opción más sólida. En una
organización aún más pequeña, empezar con Sealed
Secrets y migrar a ESO cuando aparezca un secret
manager.

**3. ¿Merece la pena Kubernetes para una organización así?**

Honestamente, **no** para la Fundación tal como
describen la oferta. Para el tamaño y los servicios
descritos, Docker Compose + un systemd timer + un
watchdog (lo que se entrega en los Bloques A y B)
cubre el 90 % de los casos, y deja el 10 % restante
mucho más fácil de entender y depurar.

Kubernetes aporta cuando:

* Tienes **decenas de servicios** con release
  coordinado y necesitas orquestación (rolling
  updates, canary, etc.).
* Necesitas **multi-cloud** o portabilidad entre
  proveedores.
* El equipo tiene **capacidad de operar Kubernetes
  24/7** (alguien de guardia entiende un CrashLoopBackOff
  sin pedir ayuda).
* El **coste de oportunidad** de pagar a un proveedor
  gestionado (EKS, GKE, AKS) tiene sentido frente al
  tiempo ahorrado.

Cambiaría de opinión si:

* La Fundación empieza a tener varios productos
  digitales con varios servicios cada uno.
* Necesitan **autoscaling real** (no solo "más
  contenedores en una VM más grande").
* Adoptan **GitOps** (ArgoCD / Flux) y quieren
  reconciliación continua.

Con 3 servicios y un servidor, el coste operativo de
Kubernetes (cluster, redes, ingress, cert-manager,
operators varios) es mayor que el beneficio.

---

## Bloque F — Incidencia

**Enlace a tu análisis:** [`docs/incidencia.md`](docs/incidencia.md)

> Resumen: causa raíz = el `find` sin comillas del script
> de backup, que **nunca borró nada** en 8 meses. Disco
> lleno la madrugada del 2 de agosto. PostgreSQL cae. La
> API no resuelve `db`. Nginx devuelve 502. El `up -d`
> del compañero de las 08:05 no resuelve nada.
>
> Cadena causal, pistas falsas (incluido el
> `docker compose up -d` y el `load average` de 14),
> mecanismo exacto del `find`, resolución inmediata
> (con los pasos peligrosos marcados), resolución de
> fondo por relación coste/beneficio, y análisis de los
> dos fallos de monitorización, están todos en
> `docs/incidencia.md`.

---

## Notas finales

* Lo que más tiempo me ha llevado de la prueba no ha
  sido ningún bloque técnico, sino el setup del entorno
  (instalar Docker dentro del WSL, arreglar `systemd`
  con `/etc/wsl.conf`, instalar terraform/shellcheck/
  hadolint). El enunciado dice que ese tiempo no cuenta,
  y razón tiene.
* El script de backup original me ha parecido un
  hallazgo muy realista: es exactamente el tipo de
  código que se queda en producción durante años sin que
  nadie lo toque, y donde un bug ortográfico puede
  tirar el servicio. Mi versión corregida es la que
  recomendaría, con un test de regresión en CI que
  detectaría la regresión del `find` la primera noche.
* Lo que menos me convence de lo entregado es el
  `--workers=1` en el Dockerfile: lo he puesto porque
  el `init_schema()` del `app.py` no es seguro con
  varios workers, pero la solución de fondo sería
  reescribir el `app.py` para usar migraciones. La
  prueba pide no tocar la lógica de la app, así que
  documento la mitigación y me quedo con la conciencia
  tranquila.
* Si pudiera rehacer algo, separaría la monitorización
  de "HTTP responde" en chequeos separados para
  "disco tiene espacio" y "ratio de backups es normal".
  El aviso del 03:45 habría sido mucho más útil con
  eso.
* Crítica al enunciado: el ejemplo de la aplicación es
  muy pequeño (un `equipos` con 4 campos) para evaluar
  el tipo de decisiones reales de producción. En
  positivo: la trampa del `find` y el `docker.sock`
  son un acierto; si los encuentras, sabes mirar.
