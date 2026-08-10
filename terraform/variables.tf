variable "db_name" {
  description = "Nombre lógico de la base de datos."
  type        = string
  default     = "inventario"
}

variable "db_user" {
  description = "Usuario de la base de datos."
  type        = string
  default     = "inventario"
}

# IMPORTANTE: esta contraseña se mete como variable, no en el código.
# En el repo solo hay un .example. En el server real:
#   1) export TF_VAR_db_password="$(openssl rand -base64 24)"
#   2) terraform apply
# O usar un .tfvars que NO se versiona.
# Aún así, acabará en el state en claro: lo trato en D.3.
variable "db_password" {
  description = "Contraseña de la base de datos. NO en el repo. Marcada sensible para que Terraform no la imprima en consola."
  type        = string
  sensitive   = true
}

variable "db_image" {
  description = "Imagen de PostgreSQL a usar."
  type        = string
  default     = "postgres:16-alpine"
}

variable "postgres_data_path" {
  description = "Ruta del host donde persiste el volumen de datos."
  type        = string
  default     = "./.data/postgres"
}

variable "network_name" {
  description = "Nombre de la red Docker donde vivirá la BD."
  type        = string
  default     = "inventario-tf"
}

variable "container_name" {
  description = "Nombre del contenedor de PostgreSQL."
  type        = string
  default     = "inventario-db-tf"
}
