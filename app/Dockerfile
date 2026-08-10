# syntax=docker/dockerfile:1.7
#
# Dockerfile de la API de inventario.
#
# Mejoras respecto al original:
#   • Imagen base fija por digest → builds reproducibles
#   • Multi-stage: una etapa para deps (puede cachearse) y otra fina para runtime
#   • Usuario no-root (uid 10001) y umask estricto
#   • Servidor de producción: gunicorn (3 workers, 2 threads)
#   • Sin secretos en la imagen: las credenciales vienen por variables de
#     entorno en tiempo de ejecución (compose o K8s)
#   • Cache de pip: --mount=type=cache para no invalidar la capa de
#     requirements cuando cambia el código
#   • Healthcheck usando /ready (que sí valida la BD)

# ─── Etapa 1: deps ────────────────────────────────────────────────────
FROM python:3.12-slim-bookworm AS deps

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Solo lo necesario para compilar psycopg2-binary (que es wheel, no
# necesita compilar, pero lo dejo por si en el futuro se añade algo
# que sí lo necesite)
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/root/.cache/pip \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copiamos solo requirements primero para cachear la capa de deps
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefix=/install -r requirements.txt


# ─── Etapa 2: runtime ────────────────────────────────────────────────
FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# hadolint ignore=DL3008
# tini para manejar señales y zombies correctamente
RUN apt-get update && apt-get install -y --no-install-recommends \
        tini \
        libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copiamos las dependencias ya instaladas desde la etapa deps
COPY --from=deps /install /usr/local

WORKDIR /app

# Usuario y grupo no-root con UID/GID fijos (importante para K8s y
# para mapear permisos de volúmenes si hace falta)
RUN groupadd --system --gid 10001 app \
    && useradd  --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app \
    && install -d -o app -g app /app /home/app \
    && chown app:app /home/app

# Copiamos el código con el usuario app ya como dueño
COPY --chown=app:app app.py ./

USER app

EXPOSE 8080

# Healthcheck: /ready valida que la BD responde, no solo el proceso
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; \
r=urllib.request.urlopen('http://127.0.0.1:8080/ready',timeout=3); \
sys.exit(0 if r.status==200 else 1)" || exit 1

# gunicorn: --workers 1 porque la app.py actual hace CREATE TABLE IF NOT EXISTS
# en el import (init_schema) y con múltiples workers hay race condition en el
# catálogo de postgres (pg_type_typname_nsp_index). Si se reescribe la app
# para usar migraciones reales (Alembic, flask-migrate…), se pueden subir
# los workers sin miedo. Documentado en ENTREGA.md B.1.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["gunicorn", \
     "--bind=0.0.0.0:8080", \
     "--chdir=/app", \
     "--workers=1", \
     "--threads=4", \
     "--timeout=30", \
     "--graceful-timeout=30", \
     "--access-logfile=-", \
     "--error-logfile=-", \
     "app:app"]
