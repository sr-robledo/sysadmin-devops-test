# Bloque C — CI con GitHub Actions

**Obligatorio · ~25 min**

[← Bloque B](02-bloque-b-docker-compose.md) · [Índice](../README.md) · [Siguiente: Bloque D →](04-bloque-d-terraform.md)

---

## Contexto

Ahora mismo, si alguien mete un cambio que rompe el `Dockerfile` o el script de
backup, no se entera nadie hasta que falla en producción. Queremos que el
repositorio se valide solo.

**Alcance: el pipeline no despliega.** Construye, valida y publica la imagen. El
despliegue en tu entorno lo haces tú a mano y lo documentas. Es una decisión
deliberada por nuestra parte, y en la entrevista te preguntaremos qué harías
distinto si quisiéramos despliegue automático — piénsalo mientras lo montas.

---

## C.1 — El workflow

Crea el workflow (o los workflows, si te parece mejor separarlos) en
`.github/workflows/`. Tiene que hacer, como mínimo:

**Validar.**
- `shellcheck` sobre los scripts de `scripts/`
- Análisis del `Dockerfile` con `hadolint`
- Validar la sintaxis del compose

**Construir y publicar.**
- Construir la imagen de `app/`
- Publicarla en **GHCR** (`ghcr.io`), el registro de contenedores de GitHub
- Etiquetarla con criterio. `latest` a secas no es una estrategia de etiquetado;
  queremos poder saber qué commit corresponde a cada imagen y poder volver atrás.

**Comportarse bien.**
- Dispararse en `push` y en `pull_request`, con la diferencia de comportamiento que
  tenga sentido entre ambos casos
- Permisos del token mínimos y explícitos

Opcional, si te sobra tiempo: usar caché de capas para que la segunda ejecución
sea más rápida, y fijar las acciones de terceros por commit SHA en vez de por
etiqueta. Ninguna de las dos es obligatoria, pero la segunda te la preguntamos en
`ENTREGA.md` aunque no la implementes — ver más abajo.

**Y que se vea que funciona.** Tiene que haber al menos una ejecución en verde en
tu fork. Deja el enlace en `ENTREGA.md`.

## C.2 — Publicar en GHCR desde un fork

Aviso, para que no te bloquee: publicar en GHCR desde un fork a veces tropieza con
los permisos del `GITHUB_TOKEN` por defecto, o con restricciones propias del fork
que no controlas. Si te pasa, **no es un fracaso**: documenta qué falla
exactamente, por qué, y qué habrías hecho en el repositorio original. Un
diagnóstico correcto de un problema de permisos vale tanto como el push en sí.

## C.3 — El paso que no hay

El pipeline termina con una imagen publicada. Falta el último tramo.

Explica en `ENTREGA.md`, **sin implementarlo**, cómo llevarías esa imagen al
servidor de forma automática. Tres cosas, en pocas líneas cada una:

- Qué mecanismo usarías, y por qué ese y no otro.
- Cómo gestionarías las credenciales de acceso al servidor.
- Por qué meter una clave SSH en los secrets del repositorio es una solución que
  funciona pero que tiene un problema, y cómo lo mitigarías.

No hace falta media página; con tres respuestas cortas y bien pensadas basta.

---

## Qué entregar de este bloque

En el repositorio:

- El workflow o workflows en `.github/workflows/`

En `ENTREGA.md`:

- Enlace a una ejecución en verde
- Tu estrategia de etiquetado de imágenes y su motivo
- Qué diferencia hay en el comportamiento entre `push` y `pull_request`, y por qué
- Cómo has fijado las versiones de las acciones de terceros y qué riesgo evita eso
- La respuesta a C.3

---

[Siguiente: Bloque D — Terraform →](04-bloque-d-terraform.md) · o salta al
[Bloque E — Kubernetes](05-bloque-e-kubernetes.md)
