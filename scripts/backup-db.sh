#!/bin/bash
#
# Backup de la base de datos de inventario.
#
# Este script se escribió con prisa hace dos años y nadie lo ha vuelto a mirar.
# "Funciona" en el sentido de que casi siempre genera un fichero.
#
# Hay dos cosas concretas que queremos que encuentres:
#
#   1. Un fallo capaz de borrar datos que no debería borrar.
#   2. Una línea que parece hacer su trabajo y que en realidad no borra nunca
#      nada. (Si has leído el Bloque F, esta te va a sonar.)
#
# Aparte de esas dos, hay bastantes más problemas: de manejo de errores, de
# seguridad, de qué pasa si algo falla a mitad y de qué se llega a saber cuando
# falla. Arregla los que consideres importantes y explica los cambios en
# ENTREGA.md.

BACKUP_DIR=/var/backups/inventario
DB_NAME=inventario
DB_USER=inventario
DB_PASSWORD=inventario123
DB_HOST=localhost
RETENTION_DAYS=7

FECHA=`date +%d-%m-%Y`
DESTINO=$BACKUP_DIR/inventario-$FECHA.sql

echo "Iniciando backup en $DESTINO"

mkdir $BACKUP_DIR
cd $BACKUP_DIR

export PGPASSWORD=$DB_PASSWORD
pg_dump -h $DB_HOST -U $DB_USER $DB_NAME > $DESTINO

gzip $DESTINO

echo "Limpiando backups de más de $RETENTION_DAYS días"
find $BACKUP_DIR -name *.sql.gz -mtime +$RETENTION_DAYS -exec rm {} \;

# Limpieza de los temporales que deja pg_dump cuando se interrumpe
rm -rf $BACKUP_DIR/tmp/*

echo "Backup completado"
exit 0
