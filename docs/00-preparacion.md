# Antes de empezar

[← Volver al índice](../README.md)

---

## 1. Fork y clonado

Haz **fork** de este repositorio a tu cuenta personal de GitHub y clona tu fork:

```bash
git clone https://github.com/TU-USUARIO/sysadmin-devops-test.git
cd sysadmin-devops-test
```

Añade este repositorio como remoto `upstream`, por si publicamos alguna
corrección durante la prueba:

```bash
git remote add upstream https://github.com/Fundacion-Cibervoluntarios/sysadmin-devops-test.git
```

Trabaja **siempre en tu fork**. No intentes hacer push a este repositorio.

## 2. Tu entorno Linux

**No te damos ningún servidor.** Necesitas una máquina Linux con `sudo`, y la
aportas tú. Cualquiera de estas opciones vale — elige la que mejor conozcas:

- **WSL2** en tu Windows, con una distro Ubuntu.
- Una **VM local** (VirtualBox, multipass, Vagrant...) con una imagen Ubuntu.
- Una **VM gratuita en un cloud** (capa gratuita de Oracle Cloud, AWS, GCP...),
  si prefieres tener una IP pública real.

Recomendamos Ubuntu porque los comandos de esta guía asumen `apt` y `ufw`. Si
usas otra distro, adapta lo que haga falta y dilo en `ENTREGA.md` — no resta.

**El tiempo de montar esta máquina no cuenta** dentro de las 2 h – 2 h 30
estimadas para la prueba. Empieza a contar el tiempo cuando ya tengas una
terminal Linux delante.

**Sobre la IP pública.** Si usas una VM en un cloud, tendrás una IP pública real
y el Bloque A (firewall, exposición de puertos) aplica tal cual está escrito.
Si usas WSL2 o una VM local, no tendrás IP pública — **trata el ejercicio como
si la tuvieras**: configura y razona como si cualquier puerto que abras fuera
visible desde internet. Dilo en `ENTREGA.md` si es tu caso.

**Sobre systemd.** El Bloque A.4 pide un timer de systemd real y en ejecución.
Compruébalo con `systemctl status` antes de empezar: si no responde, tu entorno
no tiene systemd de verdad (pasa en algunas configuraciones de WSL2 o en
contenedores) y ese punto concreto necesitas hacerlo en una VM local o cloud.

Es tu máquina: si la rompes, no hace falta que nos avises, simplemente
recréala. `sudo` completo, puedes hacer lo que necesites con ella.


## 3. Cómo se evalúa Git

Estamos evolucionando cada vez más a una metodología GitOps, por lo tanto
evaluamos cómo usas y te organizas en git.

**Ramas.** Con una rama de trabajo distinta de `main` ya cumples este punto — no
hagas todos los commits directamente en `main`. Si además separas por bloque o
por área (`bloque-a/hardening-ssh`, `feat/compose-hardening`...), lo valoramos
como un extra, pero no es obligatorio para esta prueba.

**Commits.** Que cada commit sea un cambio con sentido propio y que el mensaje
diga *qué* cambia y, cuando no sea obvio, *por qué*.

**La Pull Request final.** Ábrela en tu propio fork, de tu rama de integración
hacia tu `main`, y **déjala abierta sin mergear**. Su descripción debe servir como
resumen de lo que has hecho. Es lo que leeríamos si esto fuera un cambio real
entrando en producción.


## 4. Qué se espera que entregues

Un fork que contenga:

- Los ficheros del repositorio corregidos y mejorados
- Lo nuevo que hayas creado (workflows, unidades systemd, HCL o manifiestos)
- **`ENTREGA.md` relleno** — es lo primero que vamos a leer
- La documentación que consideres necesaria, donde consideres que va

Sobre este último punto: no te decimos cuántos README tienes que escribir ni
dónde. Decide tú. Si un directorio necesita su propio README porque tiene
particularidades, créalo. Si con `ENTREGA.md` y buenos comentarios en el código
basta, tampoco pasa nada. Lo que evaluamos es si alguien que llega nuevo puede
reproducir tu trabajo.

## 5. Herramientas

En tu equipo anfitrión, solo necesitas Git y lo que haga falta para levantar el
entorno que hayas elegido (WSL, VirtualBox/multipass/Vagrant, o el CLI del cloud
que uses).

Todo lo demás — Docker, `ufw`, systemd, Terraform, `kind`... — se instala **dentro**
de esa máquina Linux, siguiendo las guías de cada bloque.

---

Cuando tengas tu entorno Linux listo, empieza por el [Bloque A](01-bloque-a-servidor.md).
