# Prueba técnica — SysAdmin con conocimientos DevOps

Fundación Cibervoluntarios

---

## Qué es esto

Un escenario pequeño pero realista: una API interna de inventario de equipos, con
su base de datos, que hay que **contenerizar, desplegar en tu propio entorno
Linux, automatizar y dejar documentada**.

**No te damos ningún servidor.** Tú aportas el entorno: tu portátil con WSL2, una
VM local (VirtualBox, multipass, Vagrant...) o una VM gratuita de algún cloud
(Oracle Cloud, AWS, GCP...). Los detalles están en
[la preparación](docs/00-preparacion.md), y el tiempo que dediques a montarlo **no
cuenta** dentro de la estimación de abajo.

No buscamos que completes el 100%. Buscamos ver **cómo trabajas**: qué priorizas,
qué decisiones tomas y si sabes explicar por qué. Un repositorio con tres bloques
bien hechos y bien documentados vale más que seis a medias y sin documentar.

**Tiempo estimado: 2 h – 2 h 30 min, con IA, una vez tengas tu entorno listo.** Si
a las 2 h 30 no has terminado, para y entrega lo que tengas explicando qué falta.
Como decimos, no esperamos ni buscamos que la completes al 100%.

## Qué NO esperamos

Que domines las ocho tecnologías que aparecen en la oferta. Que escribas
Terraform o Kubernetes de memoria si no los usas en tu día a día — de hecho, en
los bloques D y E lo único obligatorio son las preguntas, no el código. Que
entregues algo perfecto o completo. Decir "esto no lo sé" o "esto lo he dejado
fuera por tiempo" es una respuesta válida y suma, no resta — nos interesa más que
inventar algo para rellenar el hueco.

## Sobre el uso de IA

**Puedes usar IA sin límite y sin declararlo.** Nos parece bien; nosotros también
la usamos. De hecho, esta prueba está hecha por IA con revisiones de un humano.

Aun así, consideramos la IA como una herramienta de apoyo. Te pediremos que
defiendas tus decisiones y que expliques conceptos concretos de lo que has
entregado.

---

## Índice

Lee primero la preparación, y luego los bloques en orden.

| | Documento | Obligatorio | Tiempo aprox. |
|---|---|---|---|
| — | [Antes de empezar](docs/00-preparacion.md) | Sí | 10 min |
| A | [Tu entorno Linux: hardening, servicios y backups](docs/01-bloque-a-servidor.md) | Sí | 40 min |
| B | [Docker y Docker Compose](docs/02-bloque-b-docker-compose.md) | Sí | 30 min |
| C | [CI con GitHub Actions](docs/03-bloque-c-github-actions.md) | Sí | 25 min |
| D | [Terraform](docs/04-bloque-d-terraform.md) | Preguntas sí, código opcional | 20 min |
| E | [Kubernetes](docs/05-bloque-e-kubernetes.md) | Preguntas sí, código opcional | 20 min |
| F | [Diagnóstico de una incidencia](docs/06-bloque-f-incidencia.md) | Sí | 20 min |

Los bloques D y E son alternativos: **elige uno de los dos y contesta sus
preguntas** — eso es lo obligatorio del bloque. Implementarlo (el HCL, los
manifiestos, ejecutarlo de verdad) es opcional y suma como extra; no hace falta
para aprobar ese bloque. Si te sobra tiempo, también puedes contestar las
preguntas del otro bloque, o implementar ambos — pero primero asegúrate de que A,
B, C y F están sólidos.

---

## Qué evaluamos

Cuatro cosas, en este orden de importancia:

**1. Criterio técnico.** Que las decisiones tengan sentido para un entorno real,
no para un tutorial. Que detectes lo que está mal en lo que te damos y sepas por
qué está mal.

**2. Documentación.** Comprendemos que esta tarea lleva tiempo, por lo que no
pedimos un nivel de detalle o una documentación 100% precisa.

**3. Manejo de Git.** Historial legible, commits con sentido, ramas, una Pull
Request final. Ver el punto correspondiente en [la preparación](docs/00-preparacion.md).

**4. Alcance y priorización.** Qué eliges hacer y qué eliges dejar fuera. Decirlo
explícitamente puntúa; dejarlo en silencio no.

Y una cosa que **no** evaluamos: la lógica de la aplicación Python. Funciona tal
cual, no la toques salvo que necesites hacerlo (y entonces cuéntanoslo).

---

## El punto de partida

```
├── app/                     # La aplicación. No es el objeto de la prueba.
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile           # ⚠ Funciona, pero es malo. Arréglalo.
├── compose/
│   ├── docker-compose.yml   # ⚠ Funciona, pero es peor. Arréglalo.
│   └── nginx.conf
├── scripts/
│   └── backup-db.sh         # ⚠ Tiene un fallo que borra datos. Encuéntralo.
├── systemd/                 # Esqueletos que debes completar.
├── docs/                    # El enunciado, por bloques.
├── ENTREGA.md               # ⚠ Tu documento principal. Rellénalo.
└── job_description.md        # La oferta, por contexto.
```

Los tres ficheros marcados con ⚠ contienen problemas puestos a propósito. No te
decimos cuántos ni cuáles. Algunos son de seguridad, otros de fiabilidad, otros
simplemente de mantenimiento. Encontrar los importantes y **saber distinguirlos de
los cosméticos** es parte de la prueba.

---

## Entrega

Resumen rápido (el detalle está en [la preparación](docs/00-preparacion.md)):

1. Haz **fork** de este repositorio a tu cuenta de GitHub.
2. Trabaja en ramas, no directamente en `main`.
3. Rellena [`ENTREGA.md`](ENTREGA.md) — es lo primero que vamos a leer.
4. Abre una **Pull Request** en tu propio fork (`tu-rama` → `tu main`) que recoja
   el trabajo (todas las ramas), y déjala abierta.
5. Mándanos el enlace a tu fork y a la PR por correo electrónico.

## Dudas

Si algo del enunciado es ambiguo, **no te bloquees**: decide tú, deja escrita la
suposición que has hecho en `ENTREGA.md` y sigue. Eso es exactamente lo que
esperamos del puesto.

Si te bloquea un problema técnico ajeno a la prueba (por ejemplo, tu proveedor
cloud gratuito no te deja crear la VM), escríbenos y lo vemos.

Suerte.
