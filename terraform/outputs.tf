output "network_name" {
  description = "Nombre de la red creada, para que la api (compose) se conecte."
  value       = docker_network.backend.name
}

output "db_container_name" {
  description = "Nombre del contenedor de la BD."
  value       = docker_container.db.name
}

output "db_volume_name" {
  description = "Nombre del volumen persistente (no se borra con destroy gracias a prevent_destroy)."
  value       = docker_volume.db_data.name
}

output "db_host" {
  description = "Host que la api usará como DB_HOST. Dentro de la red inventario-tf, equivale al nombre del contenedor."
  value       = docker_container.db.name
}

# Por seguridad, NO exponemos la contraseña como output.
# Si alguien la necesita, que la lea de su tfvars o del state (en local).
output "db_user" {
  description = "Usuario de la BD."
  value       = var.db_user
}

output "db_name" {
  description = "Nombre de la BD."
  value       = var.db_name
}
