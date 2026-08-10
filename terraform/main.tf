# terraform/main.tf
# Levanta la parte de datos de la aplicación:
#   • red bridge propia
#   • volumen nombrado persistente (cuelga del host, sobrevive a destroy
#     porque se crea con lifecycle.prevent_destroy)
#   • contenedor PostgreSQL conectado a la red y usando el volumen
#
# Por qué este recorte: con esto se ve todo lo que pide el Bloque D
# (estado, secretos, variables, versionado) sin re-implementar la app
# entera. La api se levanta con docker compose como en el Bloque B,
# reutilizando la red y la BD.

resource "docker_network" "backend" {
  name   = var.network_name
  driver = "bridge"
}

# Volumen persistente. Lo materializamos como bind mount en una ruta
# controlada por Terraform (en lugar de un volume Docker) para que la
# ruta sea explícita y reproducible. .data/ está en .gitignore.
resource "docker_volume" "db_data" {
  name = "${var.container_name}-data"

  lifecycle {
    # Por defecto, un destroy borraría el volumen y con él los datos.
    # Para este caso (BD de inventario) NO queremos eso. Si alguien
    # quiere borrar los datos, que lo haga explícitamente con
    # `docker volume rm` o eliminando la protección del lifecycle.
    prevent_destroy = true
  }
}

# Contenedor de PostgreSQL
resource "docker_container" "db" {
  name     = var.container_name
  image    = var.db_image
  hostname = var.container_name

  env = [
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
  ]

  # Volumen nombrado (gestionado por Terraform arriba)
  volumes {
    volume_name    = docker_volume.db_data.name
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name = docker_network.backend.name
  }

  # 5432 NO se expone al host: la BD solo es accesible desde la red interna.
  # Para conectarte desde el host, usa `docker exec` o `docker network`.

  # Reinicia salvo que se pare a mano
  restart = "unless-stopped"

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U ${var.db_user} -d ${var.db_name}"]
    interval = "10s"
    timeout  = "3s"
    retries  = 5
  }
}
