"""
API mínima de inventario de equipos, no es la metodología de inventario
que se usa en la Fundación, es solo un ejemplo para la prueba.

Esta aplicación NO es el objeto de la prueba: funciona tal cual y no necesitas
modificar su lógica. Está aquí para que tengas algo real que contenerizar,
desplegar y monitorizar. Si necesitas tocarla, documenta por qué.

Variables de entorno que espera:
  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
  APP_PORT (opcional, por defecto 8080)
"""

import os

import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)


def get_connection():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ.get("DB_NAME", "inventario"),
        user=os.environ.get("DB_USER", "inventario"),
        password=os.environ.get("DB_PASSWORD", ""),
        connect_timeout=5,
    )


def init_schema():
    with get_connection() as conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS equipos (
                id        SERIAL PRIMARY KEY,
                hostname  TEXT NOT NULL UNIQUE,
                so        TEXT NOT NULL,
                ubicacion TEXT
            )
            """
        )
        conn.commit()


init_schema()


@app.get("/health")
def health():
    """Liveness: la app responde. No comprueba dependencias."""
    return jsonify(status="ok"), 200


@app.get("/ready")
def ready():
    """Readiness: la app responde Y la base de datos es alcanzable."""
    try:
        with get_connection() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
    except Exception as exc:  # noqa: BLE001
        return jsonify(status="error", detail=str(exc)), 503
    return jsonify(status="ready"), 200


@app.get("/equipos")
def listar_equipos():
    with get_connection() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, hostname, so, ubicacion FROM equipos ORDER BY id")
        filas = cur.fetchall()
    return jsonify(
        [
            {"id": f[0], "hostname": f[1], "so": f[2], "ubicacion": f[3]}
            for f in filas
        ]
    )


@app.post("/equipos")
def crear_equipo():
    datos = request.get_json(silent=True) or {}
    for campo in ("hostname", "so"):
        if not datos.get(campo):
            return jsonify(error=f"falta el campo '{campo}'"), 400

    with get_connection() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO equipos (hostname, so, ubicacion) VALUES (%s, %s, %s) "
            "ON CONFLICT (hostname) DO UPDATE SET so = EXCLUDED.so, "
            "ubicacion = EXCLUDED.ubicacion RETURNING id",
            (datos["hostname"], datos["so"], datos.get("ubicacion")),
        )
        nuevo_id = cur.fetchone()[0]
        conn.commit()
    return jsonify(id=nuevo_id), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("APP_PORT", "8080")))
