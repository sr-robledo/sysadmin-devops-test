# Bloque D — Terraform

**Elige este bloque *o* el [Bloque E](05-bloque-e-kubernetes.md) · ~20 min**

[← Bloque C](03-bloque-c-github-actions.md) · [Índice](../README.md) · [Siguiente: Bloque F →](06-bloque-f-incidencia.md)

---

## Contexto

**Lo obligatorio de este bloque son las preguntas de D.3, no el código.**
Terraform aparece en la oferta, pero a nadie se le exige dominarlo para este
puesto. Lo que queremos ver es si entiendes **qué problema resuelve** y **cuándo
tiene sentido usarlo**, no si sabes escribir HCL de memoria. Una respuesta
honesta de "no lo he usado en producción, pero entiendo que sirve para X" vale
mucho más que código copiado sin entenderlo.

Si quieres implementarlo, genial — suma como extra —, y a continuación tienes
cómo. Si no, salta directo a la sección **D.3 — Las preguntas**, más abajo.

## Opcional: si quieres implementarlo

No te pedimos una cuenta en un cloud ni que gastes dinero. Vamos a usar Terraform
contra **Docker en tu propia máquina** (la del Bloque A, o cualquiera con Docker),
con el provider `kreuzwerker/docker`.

Puede parecer un ejercicio de juguete, y para lo que hace lo es. Pero evalúa
exactamente lo que nos interesa: si entiendes qué es el **estado**, si sabes
estructurar un módulo, si separas configuración de código y si sabes qué NO debe
acabar en Git. Todo eso es idéntico contra AWS, Azure o DigitalOcean.

```bash
# En tu entorno Linux
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### D.1 — Lo que hay que construir

En un directorio `terraform/`, escribe la configuración que levante la parte de
datos de la aplicación:

- La **red** propia donde vivirán los contenedores
- El **volumen** persistente para PostgreSQL
- El **contenedor** de PostgreSQL, conectado a esa red y usando ese volumen

Solo la base de datos. No hace falta que replantees toda la aplicación en
Terraform; con esto se ve todo lo que queremos ver.

Requisitos:

- **Versiones fijadas.** Del propio Terraform y del provider. Con `required_version`
  y `required_providers`.
- **Nada hardcodeado** que debiera ser configurable: nombre de la base de datos,
  usuario, versión de la imagen, nombres de recursos. Variables con tipo,
  descripción y, cuando tenga sentido, valor por defecto.
- **La contraseña de la base de datos, tratada como lo que es.** Marcada como
  sensible, y fuera del código. Que no aparezca en el repositorio ni en la salida
  de `terraform apply`.
- **Outputs útiles.** Piensa qué querría saber quien ejecuta esto.
- **Formateado y validado.** `terraform fmt` y `terraform validate` limpios.

### D.2 — Ejecútalo

Haz `init`, `plan` y `apply` de verdad en tu entorno. Comprueba que el contenedor
existe y que la base de datos responde.

Después haz un `plan` otra vez, sin cambiar nada, y **mira lo que dice**. Si dice
algo distinto de "no changes", tienes una configuración que no converge y merece la
pena entender por qué. Coméntalo si te pasa.

Luego `destroy`, y comprueba qué ha pasado con el volumen y con los datos.

## D.3 — Las preguntas (obligatorio)

Responde en `ENTREGA.md`. Las tres primeras son obligatorias; las dos últimas,
opcionales y suman.

**1. El estado.** ¿Qué es el fichero de estado y qué pasa exactamente si lo pierdes?
¿Y si dos personas ejecutan `apply` a la vez con el estado en local?

**2. Terraform vs Ansible.** Los dos aparecen en la oferta. ¿Qué problema resuelve
cada uno? ¿Habría tenido sentido hacer el Bloque A con Terraform? ¿Y este bloque
con Ansible? Queremos ver que entiendes la diferencia entre aprovisionar
infraestructura y configurar lo que va dentro.

**3. El secreto.** Aunque no esté en Git, la contraseña de la base de datos **sí
acaba en el fichero de estado, en claro**. Confirma si eso es cierto (aunque no
hayas implementado el bloque, puedes razonarlo) y di qué implica para cómo hay que
tratar el estado.

**4. (Opcional) Backend remoto.** Para un equipo pequeño como el de la Fundación,
¿dónde pondrías el estado y por qué? Menciona el bloqueo.

**5. (Opcional) `terraform destroy` en producción.** Alguien lo ejecuta por error
contra el entorno bueno. ¿Qué mecanismos existen para que eso no llegue a pasar?
Nombra al menos uno.

---

## Qué entregar de este bloque

En `ENTREGA.md`, obligatorio:

- Las respuestas 1, 2 y 3 de D.3

Opcional, si implementaste el código:

- El directorio `terraform/` con la configuración
- El fichero de ejemplo de variables, si lo usas — **sin valores reales**
- El `.gitignore` actualizado con lo que corresponda (revisa qué genera Terraform
  que no debe subirse; hay más de una cosa)
- Salida resumida de `plan` y `apply`, y qué pasó con el volumen tras `destroy`
- Las respuestas 4 y 5

---

[Siguiente: Bloque F — Diagnóstico de una incidencia →](06-bloque-f-incidencia.md)
