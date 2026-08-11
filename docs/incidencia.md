# Bloque F — Diagnóstico de la incidencia (02-08-2026)

## TL;DR

La caída de servicio fue un efecto colateral. La causa raíz es un **bug de
ocho meses en el script de backup**: el patrón de `find` está sin comillas y
el shell lo expande antes de pasárselo a `find`, así que la retención de
backups **nunca funcionó**. En `ls /var/backups/inventario | wc -l` hay 231
ficheros. El más antiguo, de diciembre de 2025. La carpeta pesa 28 GB. El
disco se llenó la madrugada del 2 de agosto. PostgreSQL cayó al no poder
escribir WAL. La API se quedó sin BD. Nginx devolvió 502. A las 08:05 un
compañero hizo `docker compose up -d` (ya inútil, los contenedores seguían
igual de rotos).

---

## 1. Primera hipótesis y orden de investigación

Con diez evidencias delante, la lectura natural es la que invita el síntoma:
"502 en nginx", "contenedores Exited", "could not translate host name
\"db\"". El instinto es mirar el compose, los logs de la API, la red de
Docker. Pero los tres son **consecuencias**.

Lo que miraría primero, y en este orden:

1. **`df -h`** (evidencia 5). Disco al 100 % es una pista muy gorda y la
   primera que se confirma o descarta. En este caso, confirmado: `/dev/vda1
   39G 39G 0 100%`. Cualquier otra teoría es secundaria hasta que el disco
   tenga espacio.
2. **`du -sh /var/*`** (evidencia 6). `/var/backups 28G` en un disco de
   39G explica la saturación casi sola. Con eso ya tenemos dirección:
   investigar `/var/backups`.
3. **Listado del directorio de backups** (evidencia 7). 231 ficheros con
   nombres tipo `inventario-DD-MM-YYYY.sql.gz`, los más recientes de
   este agosto, los más antiguos de diciembre de 2025. **El script de
   backup debería haber borrado los de más de 7 días. No lo ha hecho**.
   Esto es la dirección de la causa raíz.
4. **El log del backup del 2 de agosto** (evidencia 8). Tres errores en
   una noche — el `mkdir` (cosmético), el `pg_dump failed` (la BD
   muriendo), y el `find: paths must precede expression` (el bug del
   find). El último se ve 7 meses más atrás, no solo hoy.
5. **PostgreSQL logs** (evidencia 4). `PANIC: could not write to file
   "pg_wal/...": No space left on device`. El WAL no se puede escribir,
   el proceso aborta, postgres entra en modo "recovery", no levanta.
6. **`dmesg` y `uptime`** (evidencia 9). El OOM kill de gzip y el load
   average alto son **consecuencias**: la BD se quedó sin disco, los
   procesos intentaron moverse a swap, la RAM se llenó, el kernel mató
   al compresor. No son la causa.

## 2. Causa raíz y cadena completa

**Causa raíz:** el script `backup-db.sh` borra NUNCA los backups antiguos.

**Mecanismo** (detalle exacto en el punto 4): la línea de retención es

```bash
find $BACKUP_DIR -name *.sql.gz -mtime +$RETENTION_DAYS -exec rm {} \;
```

El `*.sql.gz` está **sin comillas**. El shell lo expande *como glob* en
el directorio actual (o en `$BACKUP_DIR` si tiene CDs previos — los tiene)
**antes** de invocar `find`. Si hay uno o más ficheros que encajan con
el patrón, `find` recibe la lista de nombres literales como argumentos
*posicionales*, no como argumento de `-name`. La salida del find es la
lista de paths a borrar, que **no coincide con nada** porque son paths
relativos al directorio equivocado o porque literalmente no existen.
Resultado: el find se ejecuta, no encuentra nada que encaje con esos
nombres, no borra nada, sale 0, el script sigue.

Llevo ocho meses (de diciembre de 2025 a agosto de 2026) con esta línea
corriendo cada noche sin hacer nada. La carpeta crece sin parar.

**Cadena completa, eslabón a eslabón:**

1. **Diciembre 2025 → 2 ago 2026:** el script corre cada noche, copia
   `pg_dump` a `/var/backups/inventario/inventario-DD-MM-YYYY.sql.gz`,
   llega a la línea de retención, no borra nada, sale 0. (Evidencia 7:
   231 ficheros, los más antiguos de dic-2025.)
2. **2 ago 2026, ~03:00:** el backup de la noche se intenta crear. En
   algún momento la BD intenta escribir WAL y se queda sin disco.
   PostgreSQL entra en PANIC, se apaga, intenta recovery, vuelve a
   fallar por el mismo motivo. (Evidencia 4.)
3. **2 ago 2026, ~03:38:** PostgreSQL termina shutdown. La BD no está.
   (Evidencia 2: `inventario-db-1 Exited (2) 4 hours ago` — los "4
   hours" están medidos a las 08:14.)
4. **2 ago 2026, 03:41:** nginx intenta pasar la primera petición al
   upstream `api:8080`. La API tampoco está sana: el `init_schema()` se
   ejecuta en el import de la app y necesita conectar a `db`, pero `db`
   no existe (exited), y el resolver de Docker devuelve "Temporary
   failure in name resolution". La API sale con código 1. (Evidencias 1
   y 3: errores de nginx + traceback de psycopg2.)
5. **2 ago 2026, 03:41 → 08:05:** los contenedores api y db están
   `Exited`. El `proxy` (nginx) sigue vivo porque no depende de nadie
   para arrancar, y devuelve 502. (Evidencia 2: solo el proxy está Up.)
6. **2 ago 2026, 08:05:** un compañero entra y hace `docker compose
   up -d` "a ver si se arregla". No se arregla: el estado de los
   contenedores no cambia, y la BD sigue sin poder escribir WAL por
   el disco lleno. (El enunciado da este detalle explícitamente.)
7. **2 ago 2026, 08:12:** entra el ticket. El `uptime 231 days` y el
   `load average 14.82` son de un sistema que lleva horas fighting
   por sobrevivir: el kernel mató un proceso (gzip, evidencia 9) y el
   load refleja la cola de procesos en swap. (Evidencia 9.)

**Por qué la cadena tiene eslabones "finos" en sitios raros:** porque
la causa raíz no es el disco lleno en abstracto, es que el disco se
llenó **por no borrar lo que había que borrar**. Si el script hubiese
hecho su trabajo, hoy no estaríamos aquí.

## 3. Pistas falsas (dos, tal como pide el enunciado)

### Pista falsa 1 — "El compañero la lió a las 08:05 con `docker compose up -d`"

Es lo primero que se comenta en voz alta y el enunciado lo da
explícitamente "sin darle importancia". A las 08:05 el sistema ya
llevaba cuatro horas caído, los contenedores ya estaban Exited, y el
disco ya estaba al 100 % desde la madrugada. **`up -d` no rompe nada
que ya no estuviese roto.** Lo más que hace es dejar el proxy "Up" de
nuevo, que es lo que ya estaba.

Despista porque tiene todo el aspecto de un culpable humano y cercano,
y porque cualquier persona que llega a una incidencia busca "qué ha
cambiado recientemente" — y este es el cambio más reciente y más
documentado. Pero los logs (evidencia 1) muestran los 502 desde las
03:41, mucho antes de las 08:05. La pista no encaja con los
timestamps.

### Pista falsa 2 — El load average de 14.82, el OOM kill, el `uptime 231 days`

Las tres métricas llaman la atención por lo aparatosas. `uptime 231
days` sugiere "este servidor ha sido estable durante mucho tiempo,
¿qué ha pasado?". El load de 14 invita a pensar en CPU, en
contenedores desbocados, en un loop infinito. El OOM kill de gzip
invita a pensar en una fuga de memoria o en un backup mal dimensionado.

Las tres son **consecuencia**, no causa:

* El load es alto porque la BD no levanta, los procesos intentan
  escribir a disco, el kernel los manda a swap, y la swap entra en
  contención. El load no es la causa, es el síntoma de un sistema que
  lleva horas intentando hacer IO contra un disco lleno.
* El OOM kill de gzip (evidencia 9, línea 1) no es una fuga: el kernel
  mata el compresor porque el sistema necesita memoria para otras
  cosas. gzip es la víctima, no el culpable.
* El `uptime 231 days` no dice "el sistema es estable". Dice "el
  sistema no se ha reiniciado desde hace 231 días, así que cualquier
  estado oculto tiene tiempo de sobra para crecer". El servidor no
  estaba sano; estaba estable en el sentido de "no se ha caído", no en
  el sentido de "funciona bien".

Si te quedas en cualquiera de las tres, malgastas tiempo. La causa
raíz está en el script de backup, no en el runtime del domingo.

(Mención honorífica: el `[19982051.447] overlayfs: failed to resolve
'/var/lib/docker/overlay2/...': No space left on device` de la misma
evidencia 9. Esto sí es relevante — confirma que Docker no puede
operar por falta de espacio — pero también es consecuencia, no causa.
La causa es la que ha llenado el disco, no el disco en sí.)

## 4. La línea del `find` que no borra nunca — mecanismo exacto

La línea en cuestión:

```bash
find $BACKUP_DIR -name *.sql.gz -mtime +$RETENTION_DAYS -exec rm {} \;
```

Lo que pasa, paso a paso, cuando el shell la ejecuta en el directorio
`/var/backups/inventario` (donde está el `cd $BACKUP_DIR` previo del
script):

1. El shell ve `*.sql.gz` y, **antes** de llamar a find, lo expande
   como glob. Encuentra los 231 ficheros que encajan (o un subconjunto
   muy grande de ellos).
2. El shell **sustituye** el `*.sql.gz` por la lista de nombres de
   ficheros. La línea queda equivalente a:

   ```bash
   find $BACKUP_DIR -name inventario-15-12-2025.sql.gz inventario-16-12-2025.sql.gz ... 231 más ... -mtime +7 -exec rm {} \;
   ```

3. `find` recibe esa lista de argumentos posicionales. Interpreta:

   * `-name inventario-15-12-2025.sql.gz` → busca ese nombre
   * `inventario-16-12-2025.sql.gz` → esto ya no es argumento de `-name`,
     es **otro path**, que find interpreta como otro punto de partida
     para buscar
   * `inventario-17-12-2025.sql.gz` → idem
   * ... hasta 231 paths
   * Y al final `-mtime +7 -exec rm {} \;` → opciones y la acción

4. Como `find` está buscando el nombre exacto `inventario-15-12-2025.sql.gz`
   en `$BACKUP_DIR` y ese nombre **es** uno de los ficheros de
   `$BACKUP_DIR`, sí lo encuentra y sí ejecuta el `rm` — pero solo
   para ese fichero en concreto. El resto de los nombres que el shell
   ha inyectado como paths se procesan por separado, cada uno con su
   propia lista de filtros `-name X -mtime +7`. Para cada uno de esos
   230 restantes, el filtro `-name X` solo se cumple si el fichero
   existe en el path correspondiente y solo si su mtime es > 7 días.
   En la práctica, sí, los borra — **pero solo si casualmente la lista
   que el shell le pasa coincide con la lista de ficheros en el
   directorio y todos tienen > 7 días**.

5. **El error que vemos en el log** (`find: paths must precede
   expression: 'inventario-16-12-2025.sql.gz'`) es lo que pasa cuando
   el shell expande un `*` que **no** encuentra coincidencias en el
   directorio actual pero el `set -f` no está activo. En sistemas
   con `nullglob` o con un shell que deja el `*` literal cuando no
   expande, find recibe el `*` como argumento y se queja. En otros
   sistemas, el `*` se expande a la lista de nombres, y la retención
   funciona *accidentalmente* — pero solo en parte, y dejando siempre
   los últimos 7 días que sí son jóvenes.

**¿Por qué significa que la retención no ha funcionado nunca?**

Tres posibilidades, las tres malas:

* (a) El shell expande el `*` a la lista de ficheros, find recibe
  paths posicionales, el filtrado se vuelve errático, y en promedio
  la mitad de los días se borra lo que toca y la otra mitad no. Esto
  es coherente con tener 231 ficheros cuando deberíamos tener 7.
* (b) El shell está en un modo (por ejemplo, ejecutado por systemd
  con un PATH minimal) en el que el `*` se queda literal y find
  evalúa el patrón él mismo. En este caso **sí debería funcionar**,
  y entonces la retención habría borrado los antiguos. Pero la
  evidencia 7 dice que no lo ha hecho. Descartado por observación.
* (c) El shell está expandiendo el `*` correctamente, pero a un
  subconjunto distinto del que la lógica querría. Por ejemplo, si el
  `cd $BACKUP_DIR` del script falla silenciosamente (no hay
  `set -e` en el original), find busca en otra ruta y nunca ve los
  ficheros reales.

La realidad es la mezcla de las tres: una línea mal escrita en
`set +e` con un glob sin comillas no garantiza NADA. La única forma
de que funcione de verdad es poner el patrón entre comillas:

```bash
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'inventario-*.sql.gz' -mtime "+$RETENTION_DAYS" -delete
```

Y es exactamente lo que hace mi versión corregida del script
(`scripts/backup-db.sh` en este repo). La forma más rápida de
verificar el arreglo en producción es: dejar correr el script
corregido un par de noches y comprobar que `ls /var/backups/inventario
| wc -l` baja a 7 u 8.

## 5. Resolución inmediata

**Antes de tocar nada: hacer copia de seguridad de los backups que
hay.** Aunque suene raro, `/var/backups/inventario` es ahora mismo
**lo más valioso del servidor** — la BD caída puede no tener los
datos de los últimos días, pero los 231 ficheros .gz son
recuperables. Borrarlos a lo loco es convertir un incidente en un
desastre.

Pasos en orden, con verificación tras cada uno:

1. **No borrar `/var/backups/inventario`.** Mover a un disco externo
   o a `s3 cp` lo que se pueda. Si no hay sitio ni en el disco
   externo, comprimir más (`gzip -9` o `zstd -19`) y mover lo
   reciente. **PELIGROSO si te lo tomas a la ligera:** un
   `rm -rf` aquí convierte caída de servicio en pérdida de datos
   permanente.
2. **Liberar espacio urgentemente en `/`.** `apt clean`, borrar
   `/var/log/*.gz` antiguos, `journalctl --vacuum-size=200M`.
   **PELIGROSO si te lo tomas a la ligera:** `rm -rf /var/log/*`
   deja sin logs a los siguientes que vengan a mirar.
3. **Comprobar por qué postgres no levanta.** `docker logs
   inventario-db-1 --tail 30` (que es exactamente la evidencia 4
   de este enunciado). Si está en bucle de PANIC por WAL corrupto,
   hay dos opciones: (a) tirar de backup del día anterior si
   hay uno sano; (b) dejar que postgres haga recovery automático
   desde el último checkpoint, **lo que solo funciona si el
   sistema de ficheros no está lleno**. Tras liberar espacio,
   un `docker compose start db` debería recuperarlo. **PELIGROSO
   si te lo tomas a la ligera:** un `docker rm` + `docker volume
   rm` borraría la BD sin vuelta atrás.
4. **Cuando la BD esté `Healthy`** (verificar con
   `docker exec inventario-db-1 pg_isready`), levantar la API.
   El `depends_on: condition: service_healthy` que el compose
   del Bloque B ya tiene se encarga del orden; en el compose
   original el orden era `depends_on: - db` a secas, lo que solo
   espera al *arranque* del contenedor, no a que la BD esté lista,
   pero eso es un problema del compose, no de la incidencia.
5. **Levantar nginx (proxy)** y verificar con `curl -v
   http://localhost/equipos` desde el host. Esperar HTTP 200 y
   que la lista no esté vacía.
6. **Hacer un backup manual AHORA.** `pg_dump ... | gzip >
   /var/backups/inventario/inventario-$(date +%F).sql.gz`. Si
   sale bien, copiarlo fuera del servidor.

**Por qué los contenedores no volvieron solos entre las 03:39 y
las 08:14** (casi cinco horas, el dato que pide el enunciado):

El compose original no tiene `restart: unless-stopped` (ni
`always`, ni `on-failure`). Sin política de restart, **docker no
relanza un contenedor que ha salido con código de error**. La API
salió con `Exited (1)` cuando no pudo resolver `db`; la BD salió
con `Exited (2)` cuando se quedó sin disco. Ninguna de las dos
vuelve sola. Y el `docker compose up -d` de las 08:05 tampoco lo
soluciona porque los up *intentan* arrancar el contenedor, pero
la BD sigue sin poder escribir WAL hasta que el disco tenga
espacio, así que el contenedor arranca, falla al instante, vuelve
a salir, y se queda en bucle. Por eso la api también: aunque su
única dependencia es que `db` esté sana, y `db` no lo está, la
api sale con `Exited (1)` por el `init_schema` y se queda
exited.

**Esto se arregla con el `restart: unless-stopped` y el
`healthcheck: condition: service_healthy` que tiene el compose
corregido del Bloque B.** Si en el momento de la incidencia el
compose ya los hubiera tenido, los contenedores habrían reintentado
al subir; el reintento habría seguido fallando por el disco lleno,
pero el operador habría visto el bucle claramente en `docker
compose ps` en lugar de quedarse con la duda de "estaba roto, lo
arrancamos y sigue roto".

## 6. Resolución de fondo — por relación coste/beneficio

Ordenadas de **mayor beneficio por menor esfuerzo** a **menor
beneficio por mayor esfuerzo**:

1. **Arreglar el script de backup (coste: muy bajo; beneficio:
   enorme).** El bug es una comilla. La corrección está ya en
   `scripts/backup-db.sh` de este repo. Coste: 0 (ya hecho).
   Beneficio: resuelve la causa raíz directamente, y por sí solo
   previene la recurrencia.
2. **Monitorizar espacio en disco (coste: bajo; beneficio: alto).**
   Un chequeo de `df -h` o `pg_database_size()` cada 5 minutos
   con alerta cuando supere el 80 %. Esto habría avisado con
   días de margen, no con minutos. Lo natural es montarlo con
   el mismo `cron`/timer que ya vigila el backup (el watchdog
   que el Bloque A.5 añade ya mira tamaño y antigüedad, no
   espacio libre del disco — habría que extenderlo).
3. **Mover backups fuera del mismo disco (coste: medio; beneficio:
   alto).** `/var/backups` en el mismo volumen que la BD es el
   error de diseño que ha permitido que un backup "que no borra"
   tumbe la BD. Mover a otro volumen, NFS, S3 — lo que sea,
   pero no el mismo disco. El `cp` final de mi script ya
   manda el `.sql.gz` a un path que puede ser remoto sin
   cambios.
4. **Rotación y límite de logs (coste: muy bajo; beneficio:
   medio).** `journalctl --vacuum-size=...` y un
   `/etc/logrotate.d/inventario` específico. No es lo que ha
   pasado aquí, pero el `du -sh /var/log 389M` indica que la
   cosa va justo.
5. **Backups verificados automáticamente (coste: medio; beneficio:
   medio).** El watchdog del Bloque A.5 verifica tamaño y
   antigüedad, pero no verifica *que el backup se puede
   restaurar*. Una restore automática semanal a una BD
   descartable, con un `SELECT count(*)` comparado contra
   la BD real, cierra el ciclo.
6. **Límite de tamaño por backup (coste: bajo; beneficio:
   cuestionable).** Un .sql.gz de 5 GB probablemente es síntoma
   de algo mal, pero en una BD de inventario de equipos puede
   ser legítimo. Lo dejo como opcional.

## 7. La monitorización — dos fallos separados

### Fallo 1: la métrica que vigilaba no era la que importaba

El único chequeo automático era `GET /` cada 5 minutos. Eso
mide **si la API responde**, no si la BD está sana, no si el
disco tiene espacio, no si los backups están corriendo. Cuando
la BD cae, la API también, y el chequeo se entera. Pero cuando
la BD todavía está viva y solo se está llenando el disco
**debajo de ella**, este chequeo no se entera. La métrica
correcta habría sido `df /var/backups` o `pg_database_size()`
o el ratio de backups (231 cuando deberían ser 7). Eso habría
avisado con **días** de margen, no con minutos.

En general, monitorizar "el síntoma que ve el usuario" (HTTP
200) es necesario pero no suficiente. Hace falta también
monitorizar las precondiciones del síntoma (disco, RAM,
replicación de la BD, edad del último backup, número de
backups retenidos vs. esperado). La primera alerta habría
llegado la primera noche en que la retención falló: el ratio
"Nº de backups / días desde el primero" se disparó.

### Fallo 2: el aviso llegó a quien no podía actuar

El chequeo HTTP sí se disparó a las 03:45. Mandó un correo a
`sistemas@`. A las 03:45 nadie lee ese buzón, y el lunes a
primera hora tenía 1.400 correos sin leer. El aviso no fue
inútil por la herramienta, fue inútil por el **canal**: correo
electrónico sin paginación, sin guardia, sin escalado.

Para una organización pequeña, lo proporcionado no es PagerDuty
(que vale para organizaciones que se lo pueden permitir), es:

* Aviso a un canal con personas activas a esa hora (en
 una guardia rotatoria).
* O alerta a un servicio que sí pita: Pushover, Telegram
  bot, SMS vía gateway, llamada automática.
* O, más sencillo: que la alerta **se acumule con otra cosa
  que ya pita** (el despertador de on-call, la app de
  guardia, el panel de Nagios/Zabbix si lo hay).

Si el aviso del 03:45 hubiese llegado al móvil de la persona
de guardia, el problema se habría resuelto a las cuatro de la
mañana, con el sistema reiniciado en una hora y sin ticket
abierto por la mañana.

### ¿Por qué el backup del 2 de agosto terminó en
"Deactivated successfully" si tuvo tres errores?

Porque el script original no tiene `set -euo pipefail`. Los
tres errores:

* `mkdir: cannot create directory '/var/backups/inventario':
  File exists` — cosmético, el directorio ya estaba; sigue.
* `pg_dump: error: query failed: server closed the connection
  unexpectedly` — la BD se ha muerto. Sin `set -e`, el script
  **no aborta**. El `gzip` siguiente se ejecuta sobre un
  `.sql` incompleto, genera un `.sql.gz` corrupto, pero
  termina "bien".
* `find: paths must precede expression:
  'inventario-16-12-2025.sql.gz'` — el bug del find. Sin
  `set -e`, sigue.

El script llega al `echo "Backup completado"` final, sale con
`exit 0`, systemd marca el service como "Deactivated
successfully" y el watchdog (si lo hubiera) vería exit 0 y
no alertaría.

**Mi versión corregida del script**, con `set -euo pipefail`,
`trap` para cleanup, validación de que `pg_dump` haya escrito
algo, y exit code != 0 en cualquier error, **sí habría
reportado este backup como fallido**. El `systemd` lo habría
reflejado como `failed`, el `journalctl` tendría líneas con
`ERROR`, y el watchdog que añadí en el Bloque A.5
(`backup-watchdog.sh`) vería el exit code y mandaría un
correo de alerta. **Pero no habría resuelto la causa** — la
causa raíz (el `find` sin comillas) seguiría llenando el
disco hasta que se arreglase. La detección no es la cura.

---

## Notas finales

Lo que más me ha llamado la atención de esta incidencia es que
**la causa raíz es ortográfica**. Una línea con un `*` sin
comillas en un script de hace dos años ha provocado cinco horas
de caída y, si no se hubiera detectado a tiempo, una pérdida
de datos. La monitorización de "HTTP responde" es estándar y
razonable, pero no sustituye a un script que haga
correctamente lo que dice hacer.

Si con más tiempo tuviese que añadir algo, sería un test
automático del script de backup en CI: levantar una BD
temporal, hacer un backup, simular el paso del tiempo con
`touch -d "8 days ago"`, ejecutar de nuevo, y verificar que
el fichero de hace 8 días se ha borrado. Es un test de
regresión de una línea que habría cazado el bug la primera
noche que se desplegó el script, en lugar de ocho meses
después.
