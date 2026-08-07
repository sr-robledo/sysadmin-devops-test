# Bloque A — Tu entorno Linux: hardening, servicios y backups

**Obligatorio · ~40 min · Se hace en el entorno Linux que hayas montado en [la preparación](00-preparacion.md)**

[← Índice](../README.md) · [Siguiente: Bloque B →](02-bloque-b-docker-compose.md)

---

## Contexto

Tienes una máquina Linux recién instalada — tuya, montada como describe la
preparación. Va a alojar la API de inventario, que maneja datos internos de la
organización. Antes de poner nada encima, hay que dejarla en un estado
defendible.

Este bloque es el de más peso de la prueba.

---

## A.1 — Acceso y hardening base

Deja esta máquina en un estado en el que la dejarías tú si fuera de la Fundación.
Como mínimo esperamos que hayas trabajado sobre:

- **Usuarios y acceso.** Un usuario de servicio propio para administrar, con
  `sudo`. Acceso por clave, no por contraseña. Y decidir qué hacer con el acceso
  directo de `root` por SSH.
- **Configuración de SSH.** Revisa qué hay por defecto y endurécelo. Si cambias el
  puerto, dinos por qué lo consideras útil (y si crees que no lo es, dilo también
  — es una respuesta perfectamente válida y la discutiremos).
- **Firewall.** Trata esta máquina como si estuviera en internet (si usaste una VM
  cloud, lo está de verdad; si usaste WSL2 o una VM local, razónalo igual).
  Define una política por defecto y abre solo lo que hace falta. Usa `ufw` o
  `nftables`, lo que prefieras, pero justifica la elección.
- **Actualizaciones.** Deja el sistema al día y decide qué política de
  actualizaciones automáticas aplicas. Hay más de una respuesta correcta; queremos
  la tuya y su motivo.

Con dejar cada uno de estos cuatro puntos resuelto y una frase que explique por
qué, es suficiente — no hace falta un informe extenso.

Una herramienta más, a tu criterio: si consideras que `fail2ban` o algo
equivalente aporta aquí, instálalo. Si consideras que con un firewall bien puesto y
sin autenticación por contraseña no aporta, no lo instales y explica el
razonamiento. Ambas posturas se pueden defender.


## A.2 — Reproducibilidad

Todo lo anterior tiene que quedar **reproducible desde el repositorio**. Que
funcione en tu máquina no basta; el objetivo es que otra persona pueda repetirlo
leyendo lo que entregas.

**La vía por defecto, y la que consideramos suficiente para este punto:**
documentación paso a paso en `docs/`, lo bastante precisa como para reproducirla
sin tener que interpretar nada — qué comando, con qué opciones, y por qué.

Si te sobra tiempo y prefieres automatizarlo, también vale un script de
aprovisionamiento idempotente en `scripts/` o un playbook de Ansible — lo
contamos como extra, no como requisito. Si eliges esa vía, que se pueda ejecutar
dos veces seguidas sin romper nada: eso es lo que significa idempotente, y es lo
que te preguntaremos en la entrevista aunque no lo implementes.

Lo que no vale, en cualquiera de los casos, es "hice unos cuantos comandos y
funciona" sin dejar rastro de cuáles.

## A.3 — El script de backup

En [`scripts/backup-db.sh`](../scripts/backup-db.sh) hay un script de backup real,
del tipo que aparece en cualquier organización que lleve unos años funcionando.

Hay **dos fallos concretos** que queremos que encuentres y que señales
explícitamente en `ENTREGA.md`. Queremos saber que los has visto y que entiendes por
qué son peligrosos, no solo que los has arreglado:

1. Uno capaz de **borrar datos que no debería borrar**.
2. Uno que hace que una línea **parezca hacer su trabajo sin hacerlo nunca**. Esta
   es la que provoca la incidencia del [Bloque F](06-bloque-f-incidencia.md); si te
   atascas, ese bloque te da la pista.

Además de esos dos, hay más problemas: de robustez, de manejo de errores, de
seguridad, de comportamiento cuando algo va mal a mitad, y de qué se llega a saber
cuando falla. Arregla los que consideres importantes — dejar el script limpio de
`shellcheck` es un buen criterio de parada, no hace falta ir más allá.

Dos cosas que sí pedimos concretamente:

- Que el script pase `shellcheck` sin avisos, o que los que queden estén
  silenciados a propósito y con un comentario que lo explique.
- Que las credenciales dejen de estar donde están ahora. Decide tú dónde deben
  estar y por qué.

## A.4 — Ejecución programada

Se quiere un backup **diario, de madrugada**, y que **no se pierda si la máquina
estaba apagada** a esa hora.

Impleméntalo con systemd (hay esqueletos en [`systemd/`](../systemd/) — están
incompletos a propósito, complétalos). Instálalo en tu entorno, arráncalo y
**demuestra que funciona**: no queremos ver la unidad, queremos ver que ha
ejecutado. Recuerda comprobar antes que tu entorno tiene systemd de verdad (ver
[la preparación](00-preparacion.md)) — si no, este punto necesitas hacerlo en una
VM local o cloud.

Copia al repositorio la versión final de las unidades, la misma que está instalada
en la máquina.

Y una pregunta para `ENTREGA.md`: **¿por qué systemd timer y no cron?** O al
contrario, si defiendes cron. Hay argumentos para ambos lados.

## A.5 — Y si el backup falla, ¿quién se entera?

Un backup del que nadie comprueba nada es un backup que descubres roto el día que
lo necesitas.

No pedimos que montes un stack de monitorización. Pedimos que resuelvas el mínimo
imprescindible: **que si el backup falla, alguien lo sepa**. Un log que se pueda
consultar, un aviso, una comprobación posterior... lo que te parezca proporcionado
para una organización pequeña. Dos o tres líneas explicando qué has montado son
suficientes.

Y responde también a esto, en dos líneas: **¿cómo verificarías que un backup se
puede restaurar de verdad?** No hace falta que lo hagas; con explicar el
procedimiento nos vale.

---

## Qué entregar de este bloque

En el repositorio:

- El script de aprovisionamiento, playbook o documentación de A.1–A.2
- `scripts/backup-db.sh` corregido
- Las unidades systemd en `systemd/`
- Lo que hayas montado para A.5

En `ENTREGA.md`:

- Los dos fallos del script, identificados y explicados
- Tus decisiones sobre SSH, firewall y actualizaciones, con el motivo
- La postura sobre `fail2ban`, sea la que sea
- systemd timer vs cron
- Cómo verificarías una restauración
- **Evidencia de que funciona.** Salida de comandos pegada como texto: el estado
  del firewall, el estado del timer, el registro de la última ejecución, el listado
  del directorio de backups. Texto plano, no capturas de pantalla — así podemos
  buscar dentro y comentarlo.

---

[Siguiente: Bloque B — Docker y Docker Compose →](02-bloque-b-docker-compose.md)
