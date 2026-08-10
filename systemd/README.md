# Unidades systemd

Aquí van las unidades que crees para el **Bloque A**.

Se esperan al menos dos ficheros:

- `inventario-backup.service` — ejecuta `scripts/backup-db.sh`
- `inventario-backup.timer` — lo dispara de forma periódica

Los `.example` que hay en esta carpeta son un punto de partida incompleto,
no una solución. Cámbialos de nombre, complétalos y quédate solo con lo que
de verdad necesitas.

Recuerda copiar aquí la versión final de lo que instalaste en tu entorno,
no una versión "de mentira" que no hayas probado. Si difieren, lo veremos.
