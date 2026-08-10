# Bloque E — Kubernetes

**Elige este bloque *o* el [Bloque D](04-bloque-d-terraform.md) · ~20 min**

[← Bloque C](03-bloque-c-github-actions.md) · [Índice](../README.md) · [Siguiente: Bloque F →](06-bloque-f-incidencia.md)

---

## Contexto

**Lo obligatorio de este bloque son las preguntas de E.3, no los manifiestos.**
Kubernetes aparece en la oferta, pero a nadie se le exige dominarlo para este
puesto. Lo que queremos ver es si entiendes **qué problema resuelve** cada pieza
y, sobre todo, si tienes criterio para decir cuándo NO hace falta. Una respuesta
honesta vale mucho más que manifiestos copiados sin comprenderlos.

Si quieres implementarlo, genial — suma como extra —, y a continuación tienes
cómo. Si no, salta directo a la sección **E.3 — Las preguntas**, más abajo.

## Opcional: si quieres implementarlo

Un clúster local con **kind** en tu propia máquina. Nadie espera que montes un clúster de
producción en 20 minutos; lo que queremos ver es si sabes escribir manifiestos
sensatos y si entiendes qué hace cada pieza.

```bash
# En tu entorno Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
kind create cluster --name inventario

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

> Tu entorno necesita unos 4 GB de RAM libres para que kind vaya cómodo. Si vas
> justo, para los contenedores del Bloque B mientras trabajas en este.

### E.1 — Lo que hay que desplegar

En un directorio `k8s/`, los manifiestos para desplegar la aplicación y su base de
datos. Manifiestos planos (`kubectl apply -f`) o Kustomize, como prefieras.

Se espera:

- Un **Namespace** propio. No trabajes en `default`.
- La **API**: `Deployment` con 2 réplicas + `Service`
- **La base de datos**: piensa qué objeto le corresponde a algo con estado y por
  qué no es un `Deployment` normal. Con su almacenamiento persistente. Si prefieres
  algo más simple, un `Deployment` con una réplica y un `PersistentVolumeClaim`
  también es aceptable aquí — lo importante es que lo justifiques en E.3.
- **Configuración y secretos** separados del manifiesto de la aplicación, cada uno
  en el objeto que le toca. Ojo con qué significa exactamente "Secret" en
  Kubernetes — hay una pregunta sobre esto más abajo.
- **Probes.** La aplicación expone `/health` y `/ready`. Están ahí precisamente para
  esto y no son lo mismo: usa cada una donde corresponde y prepárate para explicar
  la diferencia.
- **Límites de recursos.** `requests` y `limits`. Sabiendo lo que hace cada uno.
- **Contexto de seguridad.** Sin privilegios que no necesite, sin correr como root.
- **Acceso desde fuera.** `port-forward` documentado o `NodePort` es suficiente
  aquí; no hace falta Ingress.

### E.2 — Que funcione

Despliégalo y llega hasta el final: que la aplicación responda y que hable con su
base de datos.

Opcional, si te sobra tiempo: demuestra el rolling update — cambia algo, aplica, y
captura la salida de `kubectl rollout status` y de `kubectl get pods` durante la
transición.

## E.3 — Las preguntas (obligatorio)

Responde en `ENTREGA.md`. Las tres primeras son obligatorias; las dos últimas,
opcionales y suman.

**1. Probes.** Diferencia entre `livenessProbe` y `readinessProbe`. Con un ejemplo
concreto de qué pasa si las intercambias.

**2. Secrets.** Un `Secret` de Kubernetes, tal cual, **no está cifrado** — está
codificado en base64. Confirma si eso es cierto (razónalo aunque no lo hayas
implementado), di quién puede leerlo, y nombra al menos una forma de gestionar
secretos de verdad.

**3. La pregunta honesta.** Para una organización del tamaño de la Fundación, con
un puñado de servicios internos, **¿merece la pena Kubernetes?** Respóndenos de
verdad, no lo que creas que queremos oír. Si tu respuesta es "no, con Docker
Compose y systemd bien puestos vamos mejor", explica cuándo cambiaría eso. Ese tipo
de criterio nos interesa más que saber escribir manifiestos.

**4. (Opcional) Estado.** ¿Por qué la base de datos no va normalmente en un
`Deployment` sin más? ¿Qué te daría el objeto pensado para esto que un
`Deployment` no te da?

**5. (Opcional) requests vs limits.** Qué hace cada uno. Y qué le pasa a un pod
que supera su límite de memoria, comparado con lo que le pasa si supera su límite
de CPU. No son lo mismo en absoluto.

---

## Qué entregar de este bloque

En `ENTREGA.md`, obligatorio:

- Las respuestas 1, 2 y 3 de E.3

Opcional, si implementaste los manifiestos:

- El directorio `k8s/` con los manifiestos (nada de secretos con valores reales)
- `kubectl get all -n <tu-namespace>` con su salida
- La evidencia del rolling update
- Las respuestas 4 y 5

---

[Siguiente: Bloque F — Diagnóstico de una incidencia →](06-bloque-f-incidencia.md)
