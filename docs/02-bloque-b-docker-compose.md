# Bloque B — Docker y Docker Compose

**Obligatorio · ~30 min**

[← Bloque A](01-bloque-a-servidor.md) · [Índice](../README.md) · [Siguiente: Bloque C →](03-bloque-c-github-actions.md)

---

## Contexto

La aplicación tiene un `Dockerfile` y un `docker-compose.yml` que alguien escribió
para "salir del paso" y que llevan meses así. Ambos **funcionan**: si haces
`docker compose up` la cosa arranca. El problema no es que no funcione; el problema
es lo que pasa el día que crezca o el día que alguien la encuentre en internet.

---

## B.1 — El Dockerfile

Revisa [`app/Dockerfile`](../app/Dockerfile) y arréglalo.

Hay problemas de varias familias:

- **Tamaño y tiempo de build.** La imagen es mucho más grande de lo que necesita y
  se reconstruye entera cuando no hace falta. Ambas cosas tienen arreglo.
- **Seguridad.** Hay al menos dos decisiones aquí que no pasarían una revisión.
- **Aptitud para producción.** Cómo arranca la aplicación no es cómo debería
  arrancar una aplicación Python que va a recibir tráfico. Fíjate en qué hay en
  `requirements.txt` que ahora mismo no se está usando.
- **Reproducibilidad.** Un `build` hoy y el mismo `build` en seis meses deberían
  darte lo mismo. Ahora no es el caso.

Añade también lo que falte alrededor: si el `Dockerfile` necesita compañía para
funcionar bien, créala. No hace falta tocar `app.py` para nada de este bloque.

**Deja constancia de la mejora.** Antes y después: tamaño de la imagen. Un
`docker images` pegado en `ENTREGA.md` es suficiente. Si has reducido el tamaño a
una fracción, queremos verlo.

## B.2 — El compose

Revisa [`compose/docker-compose.yml`](../compose/docker-compose.yml) y arréglalo.
Aquí los problemas son más graves que en el `Dockerfile`. Pistas de por dónde
mirar, sin decirte las respuestas:

- **Exposición.** Trata esta máquina como si tuviera IP pública (igual que en el
  Bloque A). ¿Qué servicios de este compose deberían ser alcanzables desde
  internet? ¿Lo son solo esos?
- **Persistencia.** Haz esta prueba mental, o mejor, real: `docker compose down` y
  `docker compose up`. ¿Siguen ahí los datos? ¿Debería ser así?
- **Secretos.** Están en el sitio equivocado. Muévelos y explica a dónde y por qué.
  Si creas un fichero de ejemplo para que otros sepan qué variables hacen falta,
  bien pensado.
- **Orden de arranque.** `depends_on` tal cual está no significa lo que la mayoría
  de la gente cree que significa. Averigua qué significa exactamente y qué hace
  falta añadir para conseguir lo que se pretendía. La aplicación expone `/health` y
  `/ready` — están ahí por algo, y la diferencia entre los dos importa.
- **Resiliencia.** Si la máquina se reinicia a las 4 de la mañana, ¿vuelve la
  aplicación sola?
- **El servicio `proxy`.** Tiene dos líneas que no deberían estar ahí. Una de ellas
  es, en la práctica, dar acceso de root al host. Identifícala y di por qué.
- **Recursos.** Un contenedor sin límites puede tumbar la máquina entera. Decide si
  quieres poner límites y cuáles.

No te pedimos que apliques una lista cerrada. Te pedimos criterio: arregla lo que
importa, ignora lo cosmético, y **di explícitamente qué has decidido no arreglar y
por qué**. Esa última parte nos interesa igual que la primera. Como criterio de
parada: con arreglar los 4 o 5 problemas más graves de esta lista es suficiente;
preferimos eso bien explicado a un intento de cubrirlo todo a medias.

## B.3 — Levántalo en tu entorno

Con tu versión corregida, deja la aplicación **corriendo en la misma máquina del
Bloque A** y accesible.

Demuestra que funciona de punta a punta: una petición que cree un equipo y otra que
lo lea de vuelta, saliendo la respuesta de la base de datos. Un par de `curl` con
su salida pegada en `ENTREGA.md`.

Ata esto con el Bloque A: el firewall que configuraste tiene que seguir siendo
coherente con los puertos que ahora necesitas. Si has tenido que abrir algo,
cuéntalo.

---

## Qué entregar de este bloque

En el repositorio:

- `app/Dockerfile` corregido, con lo que hayas añadido alrededor
- `compose/docker-compose.yml` corregido
- El fichero de ejemplo de variables de entorno, si lo has creado (el real, con
  valores, **no**)

En `ENTREGA.md`:

- Los cambios del `Dockerfile`, agrupados y con su motivo
- Tamaño de imagen antes y después, si lo has medido (opcional, no lo hagas
  expresamente para esto si no lo tenías ya)
- Los cambios del compose, con su motivo
- Las dos líneas problemáticas del servicio `proxy`, señaladas
- Qué es lo que `depends_on` no hace, y qué has puesto en su lugar
- Lo que has decidido **no** arreglar, y por qué
- Los `curl` de B.3 con su salida

---

[Siguiente: Bloque C — CI con GitHub Actions →](03-bloque-c-github-actions.md)
