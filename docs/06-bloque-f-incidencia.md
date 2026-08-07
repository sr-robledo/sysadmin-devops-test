# Bloque F — Diagnóstico de una incidencia

**Obligatorio · ~20 min · No hay que ejecutar nada**

[← Bloque D](04-bloque-d-terraform.md) / [← Bloque E](05-bloque-e-kubernetes.md) · [Índice](../README.md)

---

## Cómo funciona este bloque

Aquí no se toca el servidor. Es un ejercicio escrito.

Te damos una incidencia y las evidencias que tendrías delante. Queremos ver **cómo
razonas**: en qué orden mirarías las cosas, qué descartas, cómo llegas a la causa
raíz y qué haces después.

Escribe tu respuesta en un fichero aparte, `docs/incidencia.md`, y enlázalo desde
`ENTREGA.md`.

Una advertencia: **varias de estas evidencias no llevan a ninguna parte**. Son
consecuencias, no causas. Parte de lo que evaluamos es que no te quedes con el
primer síntoma llamativo.

---

## La incidencia

Es lunes por la mañana. En el sistema de tickets hay esto, entrado a las 08:12:

> «Desde el sábado por la noche el inventario va fatal. A veces cargaba y a veces
> salía un error 502. Esta mañana ya no carga nada. No hemos cambiado nada.»

El servicio es la misma aplicación de esta prueba: nginx como reverse proxy, la API
en un contenedor, PostgreSQL en otro, todo con Docker Compose en una única VM
Ubuntu. Lleva ocho meses funcionando sin incidencias. El último despliegue fue hace
tres semanas.

Un dato más, que te dan de pasada y sin darle importancia: **a las 08:05 un
compañero entró al servidor y lanzó `docker compose up -d` para ver si «se
arreglaba»**, antes de avisar a nadie.

Todas las evidencias están tomadas el domingo 2 de agosto de 2026 sobre las 08:14.

---

## Evidencias

### 1. Log de nginx

```
2026/08/02 03:41:18 [error] 812#812: *29104 connect() failed (111: Connection refused) while connecting to upstream, client: 10.20.4.51, server: _, request: "GET /equipos HTTP/1.1", upstream: "http://172.19.0.4:8080/equipos", host: "inventario.interno"
2026/08/02 03:41:18 [error] 812#812: *29104 no live upstreams while connecting to upstream, client: 10.20.4.51
2026/08/02 04:02:55 [error] 812#812: *29331 upstream prematurely closed connection while reading response header from upstream, client: 10.20.4.77
2026/08/02 07:58:03 [error] 812#812: *31022 connect() failed (111: Connection refused) while connecting to upstream, client: 10.20.4.51
2026/08/02 08:09:44 [error] 812#812: *31088 connect() failed (111: Connection refused) while connecting to upstream, client: 10.20.4.51
```

### 2. `docker compose ps -a`

```
NAME                 IMAGE          STATUS                     PORTS
inventario-api-1     compose-api    Exited (1) 4 minutes ago
inventario-db-1      postgres       Exited (2) 4 hours ago
inventario-proxy-1   nginx          Up 8 months                0.0.0.0:80->80/tcp
```

### 3. `docker logs inventario-api-1 --tail 10`

```
Traceback (most recent call last):
  File "/app/app.py", line 104, in <module>
    init_schema()
  File "/app/app.py", line 31, in init_schema
    with get_connection() as conn, conn.cursor() as cur:
  File "/app/app.py", line 22, in get_connection
    return psycopg2.connect(
psycopg2.OperationalError: could not translate host name "db" to address: Temporary failure in name resolution
```

### 4. `docker logs inventario-db-1 --tail 12`

```
2026-08-02 03:38:41.118 UTC [204] ERROR: could not write to file "pg_wal/xlogtemp.204": No space left on device
2026-08-02 03:38:41.118 UTC [204] PANIC: could not write to file "pg_wal/xlogtemp.204": No space left on device
2026-08-02 03:38:42.551 UTC [1] LOG:  checkpointer process (PID 204) was terminated by signal 6: Aborted
2026-08-02 03:38:42.551 UTC [1] LOG:  terminating any other active server processes
2026-08-02 03:38:43.004 UTC [1] LOG:  all server processes terminated; reinitializing
2026-08-02 03:39:10.887 UTC [1] LOG:  database system was not properly shut down; automatic recovery in progress
2026-08-02 03:39:11.402 UTC [231] FATAL: the database system is in recovery mode
2026-08-02 03:39:44.019 UTC [1] PANIC: could not write to file "pg_wal/000000010000000000000A3F": No space left on device
2026-08-02 03:39:44.630 UTC [1] LOG:  startup process was terminated by signal 6: Aborted
2026-08-02 03:39:44.630 UTC [1] LOG:  aborting startup due to startup process failure
2026-08-02 03:39:44.812 UTC [1] LOG:  database system is shut down
```

### 5. `df -h`

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1        39G   39G     0 100% /
tmpfs           2.0G  1.2M  2.0G   1% /run
/dev/vda15      105M  6.1M   99M   6% /boot/efi
tmpfs           395M  4.0K  395M   1% /run/user/1000
```

### 6. `sudo du -sh /var/* 2>/dev/null | sort -h | tail -5`

```
216M    /var/cache
389M    /var/log
1.1G    /var/tmp
6.4G    /var/lib
28G     /var/backups
```

### 7. El directorio de backups

```
$ ls -lah /var/backups/inventario | head -6
total 28G
drwxr-xr-x  2 root root  20K Aug  2 03:00 .
drwxr-xr-x  4 root root 4.0K Dec 14  2025 ..
-rw-r--r--  1 root root  61M Dec 15  2025 inventario-15-12-2025.sql.gz
-rw-r--r--  1 root root  62M Dec 16  2025 inventario-16-12-2025.sql.gz
-rw-r--r--  1 root root  62M Dec 17  2025 inventario-17-12-2025.sql.gz

$ ls /var/backups/inventario | wc -l
231

$ ls -lah /var/backups/inventario | tail -3
-rw-r--r--  1 root root 139M Jul 31 03:00 inventario-31-07-2025.sql.gz
-rw-r--r--  1 root root 139M Aug  1 03:00 inventario-01-08-2026.sql.gz
-rw-r--r--  1 root root    0 Aug  2 03:00 inventario-02-08-2026.sql
```

### 8. El backup programado

```
$ systemctl status inventario-backup.timer
● inventario-backup.timer - Backup diario inventario
     Loaded: loaded (/etc/systemd/system/inventario-backup.timer; enabled)
     Active: active (waiting) since Sun 2025-12-14 22:10:03 UTC; 7 months 19 days ago
    Trigger: Mon 2026-08-03 03:00:00 UTC; 18h left

$ journalctl -u inventario-backup.service -n 8 --no-pager
Aug 02 03:00:01 srv-inv systemd[1]: Starting Backup diario inventario...
Aug 02 03:00:01 srv-inv backup-db.sh[3011]: Iniciando backup en /var/backups/inventario/inventario-02-08-2026.sql
Aug 02 03:00:01 srv-inv backup-db.sh[3011]: mkdir: cannot create directory '/var/backups/inventario': File exists
Aug 02 03:00:38 srv-inv backup-db.sh[3014]: pg_dump: error: query failed: server closed the connection unexpectedly
Aug 02 03:00:38 srv-inv backup-db.sh[3011]: Limpiando backups de más de 7 días
Aug 02 03:00:38 srv-inv backup-db.sh[3011]: find: paths must precede expression: 'inventario-16-12-2025.sql.gz'
Aug 02 03:00:38 srv-inv backup-db.sh[3011]: Backup completado
Aug 02 03:00:38 srv-inv systemd[1]: inventario-backup.service: Deactivated successfully.
```

### 9. `uptime` y `dmesg`

```
$ uptime
 08:14:22 up 231 days,  4:19,  1 user,  load average: 14.82, 11.40, 9.77

$ sudo dmesg | tail -3
[19981204.113] Out of memory: Killed process 30112 (gzip) total-vm:1180244kB, anon-rss:1032288kB
[19981231.882] docker0: port 3(vethb81c4a2) entered disabled state
[19982051.447] overlayfs: failed to resolve '/var/lib/docker/overlay2/l/QK4...': No space left on device
```

### 10. Monitorización

El único aviso automático que existe es un chequeo HTTP externo que hace `GET /`
cada 5 minutos y avisa por correo si falla dos veces seguidas. Ese correo se envió a
las 03:45 al buzón `sistemas@` — que a esa hora no lee nadie, y que el lunes por la
mañana tenía 1.400 correos sin leer.

---

## Qué queremos que escribas

En `docs/incidencia.md`, y por este orden:

**1. Primera hipótesis y por qué.** Con esas diez evidencias delante, ¿qué mirarías
primero, y en qué orden? Que se vea el razonamiento, no solo la conclusión.

**2. Causa raíz.** Cuál es, y la **cadena completa** desde la causa hasta el ticket
del usuario. Cada eslabón enlazado con la evidencia que lo sostiene. Ojo: la causa
raíz no es "el disco está lleno" — eso es un eslabón intermedio. Sigue tirando del
hilo.

**3. Las pistas falsas.** Señala al menos **dos** evidencias que parecen relevantes
y que son consecuencia y no causa, o que directamente despistan. Di por qué. Este
punto puntúa alto.

**4. La línea que no borra nada.** En la evidencia 8 hay un error de `find` que
lleva ocho meses apareciendo cada noche. Explica **exactamente** por qué falla esa
línea del script — el mecanismo, no una descripción vaga — y por qué eso significa
que la retención de backups no ha funcionado nunca.

**5. Resolución inmediata.** Los pasos, en orden, para tener el servicio arriba lo
antes posible, y qué comprobarías después de cada uno. Marca cuáles de esos pasos
son **peligrosos** si te los tomas a la ligera: aquí hay una forma muy fácil de
convertir una caída de servicio en una pérdida de datos permanente. Incluye
también, en un par de líneas, por qué los contenedores no volvieron solos entre
las 03:39 y las 08:14 — hay una razón concreta, relacionada con algo que has
tenido que arreglar en el Bloque B.

**6. Resolución de fondo.** Qué cambias para que esto no pueda repetirse. Al menos
**tres** medidas, **ordenadas por relación entre coste y beneficio**. Nos interesa
más el orden que la lista.

**7. La monitorización, dos fallos.** No detectó lo que tenía que detectar, y
cuando avisó, el aviso no sirvió de nada. Analiza los dos fallos por separado
(¿qué métrica habría cazado esto con días de margen, no minutos? ¿por qué no llegó
a nadie el aviso?), y de paso explica por qué la evidencia 8 registra tres errores
seguidos y aun así termina en `Deactivated successfully` — ¿tu versión corregida
del script del Bloque A habría reportado esto igual?

**Extensión:** una página. Se valora la precisión, no el volumen. **Si algo
no lo sabes, dilo** — eso puntúa más que rellenar con humo.

---

[← Volver al índice](../README.md) · Cuando acabes, repasa que
[`ENTREGA.md`](../ENTREGA.md) esté completo y abre la Pull Request.
