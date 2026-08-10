# terraform/

Esta carpeta solo levanta la parte de datos de la aplicación
(PostgreSQL) con el provider `kreuzwerker/docker`. No toca AWS, no
gasta dinero, y se ejecuta contra el Docker del entorno del Bloque A.

## Por qué solo la BD

Levantar toda la app con Terraform cuando ya tenemos un compose
bien montado (Bloque B) sería duplicar trabajo. Lo que nos importa
en el Bloque D es:

*   estructura del estado
*   separación variables / código
*   tratamiento de secretos
*   versionado de Terraform y providers
*   lo que pasa con el volumen tras `destroy`

Todo eso se ve perfectamente con la BD sola. Para usarla desde la
app, conecta el servicio `api` de compose a la misma red:

```yaml
# compose/docker-compose.yml
networks:
  default:
    external: true
    name: inventario-tf
```

## Cómo se usa

```bash
cd terraform/

# 1) Generar contraseña y exportarla (NO en el repo)
export TF_VAR_db_password="$(openssl rand -base64 24)"

# 2) Inicializar
terraform init

# 3) Ver qué se va a crear
terraform plan

# 4) Aplicar
terraform apply

# 5) Inspeccionar
docker ps
docker volume ls | grep inventario
```

## Sobre el estado y los secretos

El estado queda en `terraform.tfstate` (local, sin backend remoto).
La contraseña marcada como `sensitive = true` se escribe en el state
**en claro**. Lo trato en detalle en `ENTREGA.md`, pregunta 3 de
D.3.
