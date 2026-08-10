# Entrega — prueba técnica

> Este es el documento que leemos primero. Rellénalo a medida que avanzas, no al
> final con prisa.
>
> Borra estas instrucciones y las de cada sección cuando las hayas leído.
>
> **Sé breve.** Preferimos tres frases precisas a tres párrafos. Y **si no has hecho
> algo, dilo** — un "no llegué al Bloque E por tiempo" es una respuesta válida y
> profesional; dejar el hueco en blanco no.
>
> Rellenar este documento debería llevarte unos **15 minutos**, no media hora.
> Las secciones marcadas **(opcional)** solo hace falta rellenarlas si
> implementaste esa parte — no las dejes en blanco por vergüenza, simplemente
> bórralas si no aplican.

---

## 0. Resumen

- **Bloques completados:** A / B / C / D o E / F →
- **Tiempo aproximado dedicado:**
- **Qué he dejado fuera y por qué:**
- **De lo que he entregado, lo que menos me convence:**

> Esa última línea la preguntamos en serio. Nadie entrega algo perfecto en 3 horas.
> Saber dónde están las costuras de tu propio trabajo es una señal muy buena.

## 1. Suposiciones que he tenido que hacer

> Todo lo que el enunciado dejaba ambiguo y has resuelto tú por tu cuenta.

-

## 2. Entorno

- **Qué usé como entorno Linux (WSL2 / VM local / VM cloud) y por qué:**
- **Distro y versión:**
- **¿Tenía IP pública real, o lo tratasteis como hipotético?:**
- **Versiones de Docker / Compose / Terraform / kind, según lo que hayas usado:**

---

## Bloque A — Tu entorno Linux

### A.1 y A.2 — Hardening y reproducibilidad

**Qué he hecho:**

**Decisiones y su motivo** (SSH, firewall, política de actualizaciones):

**Sobre `fail2ban`** — lo he instalado / no lo he instalado, porque:

**Cómo se reproduce todo esto:** (script, playbook o documento; enlázalo)

### A.3 — El script de backup

**Fallo 1 — el destructivo:** ¿cuál es, y qué pasa exactamente cuando se dispara?

**Fallo 2 — el que no borra nunca nada:** ¿cuál es, y el mecanismo exacto por el que falla?

**Los demás cambios:**

**Dónde he puesto las credenciales, y por qué ahí:**

### A.4 — Ejecución programada

**systemd timer vs cron:**

### A.5 — Detección de fallos

**Qué he montado:**

**Cómo verificaría que un backup se restaura de verdad:**

### Evidencias del bloque A

> Salida de comandos como texto, no capturas. Firewall, estado del timer, última
> ejecución, listado del directorio de backups.

```
```

---

## Bloque B — Docker y Docker Compose

### B.1 — Dockerfile

**Cambios, agrupados por motivo:**

**Tamaño de imagen antes / después (opcional):**

```
```

### B.2 — Compose

**Cambios y su motivo:**

**Las dos líneas problemáticas del servicio `proxy`:** ¿cuáles, y qué permite cada una?

**`depends_on`:** qué no hace, y qué he puesto para conseguir el efecto que se buscaba:

**Lo que he decidido NO arreglar, y por qué:**

### B.3 — Evidencia de funcionamiento

> Un `curl` que cree un equipo y otro que lo lea de vuelta, con sus salidas.

```
```

---

## Bloque C — CI con GitHub Actions

**Enlace a una ejecución en verde:**

**Estrategia de etiquetado de imágenes, y su motivo:**

**Diferencia de comportamiento entre `push` y `pull_request`, y por qué:**

**Cómo he fijado las versiones de las acciones de terceros, y qué riesgo evita:**

**Si no he podido publicar en GHCR:** qué falla exactamente y qué haría en el repo original:

### C.3 — El despliegue que no está

> Tres respuestas cortas: mecanismo elegido y por qué, gestión de credenciales, y
> el problema de la clave SSH en los secrets con su mitigación.

---

## Bloque D — Terraform

> Elige D **o** E. Borra la sección del que no hayas hecho. Lo obligatorio son las
> tres primeras preguntas; el código y las dos últimas preguntas son opcionales.

### Preguntas (obligatorio)

1. **El estado** — qué es, qué pasa si se pierde, y qué pasa con dos `apply` simultáneos en local:
2. **Terraform vs Ansible** — qué resuelve cada uno; ¿el Bloque A con Terraform? ¿este con Ansible?
3. **El secreto en el estado** — ¿es cierto que la contraseña acaba ahí en claro?, y qué implica:

### Si implementaste el código (opcional)

**Estructura de lo que he escrito:**

**Cómo he gestionado la contraseña de la base de datos:**

**Qué pasó con el volumen y los datos tras `destroy`:**

**Salida resumida de `plan` / `apply`:**

```
```

4. **(Opcional) Backend remoto** — dónde lo pondría para un equipo pequeño, y el bloqueo:
5. **(Opcional) `terraform destroy` en producción** — al menos un mecanismo para evitarlo:

---

## Bloque E — Kubernetes

> Elige D **o** E. Borra la sección del que no hayas hecho. Lo obligatorio son las
> tres primeras preguntas; los manifiestos y las dos últimas preguntas son
> opcionales.

### Preguntas (obligatorio)

1. **`livenessProbe` vs `readinessProbe`** — diferencia, y qué pasa si las intercambias:
2. **Secrets** — ¿están cifrados?, quién puede leerlos, y una alternativa real:
3. **¿Merece la pena K8s para una organización así?** — respuesta honesta, y cuándo cambiaría:

### Si implementaste los manifiestos (opcional)

**Estructura de los manifiestos:**

**Qué he usado para exponer la aplicación, y qué implica:**

**`kubectl get all -n <namespace>`:**

```
```

**Evidencia del rolling update:**

```
```

4. **(Opcional) Estado** — por qué la base de datos no va normalmente en un `Deployment`:
5. **(Opcional) `requests` vs `limits`** — qué hace cada uno, y superar el límite de memoria frente a superar el de CPU:

---

## Bloque F — Incidencia

**Enlace a tu análisis:** [docs/incidencia.md](docs/incidencia.md)

---

## Notas finales

> Espacio libre. Lo que quieras contarnos: algo que te ha llamado la atención, una
> decisión de la que quieres dar contexto, algo que harías distinto con más tiempo,
> o una crítica al propio enunciado. Todo eso se lee.
