# Solución del reto — Práctica 9: Rolling update y rollback

## Alcance

Este solucionario cubre únicamente la **Tarea 5: Reto de consolidación de rollout y rollback** de la Práctica 9.

El reto parte del Deployment existente:

- Nombre: `web`
- Namespace: `lab9`
- Réplicas: `4`
- Estrategia: `RollingUpdate`
- El historial de revisiones debe conservarse.

La solución debe:

1. Actualizar correctamente `web` a `nginx:1.31.4-alpine3.24-slim`.
2. Mantener 4 réplicas.
3. Completar el rollout.
4. Verificar que todos los Pods queden Ready.
5. Simular la condición defectuosa descrita en el reto.
6. Recuperar la última revisión funcional mediante rollback.
7. Confirmar que el historial continúa disponible.

---

# Solución — Tarea 5.1. Resolver el RollingUpdate del reto

## Paso 1. Revisar el estado inicial del Deployment

Antes de modificar el Deployment, confirma su estado actual:

```bash
kubectl get deployment web -n lab9
```

**Resultado esperado:** `web` existe y mantiene cuatro réplicas.

Consulta también la imagen activa:

```bash
kubectl get deployment web -n lab9 -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

**Resultado esperado:** se muestra la versión funcional que quedó activa después del rollback realizado en la tarea anterior.

---

## Paso 2. Consultar el historial antes del nuevo cambio

```bash
kubectl rollout history deployment/web -n lab9
```

**Resultado esperado:** Kubernetes muestra las revisiones generadas durante los RollingUpdates y rollback anteriores.

Este paso permite comparar posteriormente el historial con la nueva revisión creada por el reto.

---

## Paso 3. Actualizar la imagen solicitada

El requisito del reto indica que `web` debe utilizar:

```text
nginx:1.31.4-alpine3.24-slim
```

Ejecuta:

```bash
kubectl set image deployment/web nginx=nginx:1.31.4-alpine3.24-slim -n lab9
```

**Resultado esperado:**

```text
deployment.apps/web image updated
```

Este cambio modifica `spec.template` y provoca un nuevo rollout.

---

## Paso 4. Esperar a que finalice el RollingUpdate

```bash
kubectl rollout status deployment/web -n lab9 --timeout=60s
```

**Resultado esperado:**

```text
deployment "web" successfully rolled out
```

No continúes si el rollout no termina correctamente.

---

## Paso 5. Confirmar las cuatro réplicas

```bash
kubectl get deployment web -n lab9
```

**Resultado esperado:** el Deployment presenta un estado equivalente a:

```text
NAME   READY   UP-TO-DATE   AVAILABLE
web    4/4     4            4
```

Comprueba directamente el valor deseado:

```bash
kubectl get deployment web -n lab9 -o jsonpath='Replicas={.spec.replicas}{"\n"}'
```

**Resultado esperado:**

```text
Replicas=4
```

---

## Paso 6. Confirmar que todos los Pods están Ready

```bash
kubectl get pods -n lab9 -l app=web
```

**Resultado esperado:** existen cuatro Pods y todos muestran:

```text
READY   STATUS
1/1     Running
```

---

## Paso 7. Confirmar la imagen realmente utilizada por los Pods

```bash
kubectl get pods -n lab9 -l app=web -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.containers[0].image}{"\n"}{end}'
```

**Resultado esperado:** los cuatro Pods muestran:

```text
nginx:1.31.4-alpine3.24-slim
```

Esto confirma el estado real del workload, no únicamente la configuración declarada en el Deployment.

---

## Paso 8. Confirmar que existe una nueva revisión

```bash
kubectl rollout history deployment/web -n lab9
```

**Resultado esperado:** aparece una revisión adicional correspondiente a la actualización realizada en el reto.

Puedes consultar la revisión actual:

```bash
kubectl get deployment web -n lab9 -o jsonpath='CurrentRevision={.metadata.annotations.deployment\.kubernetes\.io/revision}{"\n"}'
```

**Resultado esperado:** se muestra el número de revisión actualmente activo.

---

# Solución — Tarea 5.2. Resolver el rollback del reto

El escenario indica que una actualización posterior deja al Deployment utilizando una imagen que no puede iniciar correctamente.

Para resolver completamente el reto necesitamos reproducir esa condición defectuosa y después recuperar la última revisión funcional.

---

## Paso 9. Simular la actualización defectuosa descrita por el incidente

Configura deliberadamente una imagen inexistente:

```bash
kubectl set image deployment/web nginx=nginx:lab9-challenge-image-does-not-exist -n lab9
```

**Resultado esperado:**

```text
deployment.apps/web image updated
```

Esto crea una nueva revisión defectuosa sin modificar manualmente los Pods.

---

## Paso 10. Observar el fallo

```bash
kubectl get pods -n lab9 -l app=web
```

**Resultado esperado:** al menos uno de los Pods de la nueva revisión presenta un estado como:

```text
ErrImagePull
```

o:

```text
ImagePullBackOff
```

Debido a RollingUpdate, algunos Pods de la revisión funcional anterior pueden seguir disponibles mientras la nueva revisión no logra progresar.

---

## Paso 11. Confirmar la imagen defectuosa declarada

```bash
kubectl get deployment web -n lab9 -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

**Resultado esperado:**

```text
nginx:lab9-challenge-image-does-not-exist
```

---

## Paso 12. Revisar el historial para identificar la revisión funcional anterior

```bash
kubectl rollout history deployment/web -n lab9
```

**Resultado esperado:** aparece una nueva revisión correspondiente a la imagen defectuosa y permanecen disponibles las revisiones anteriores.

La última revisión funcional es la inmediatamente anterior al cambio defectuoso y contiene:

```text
nginx:1.31.4-alpine3.24-slim
```

---

## Paso 13. Ejecutar el rollback

Revierte a la revisión funcional anterior:

```bash
kubectl rollout undo deployment/web -n lab9
```

**Resultado esperado:**

```text
deployment.apps/web rolled back
```

`kubectl rollout undo` restaura la plantilla de la revisión anterior sin editar manualmente el Deployment.

---

## Paso 14. Esperar a que termine la recuperación

```bash
kubectl rollout status deployment/web -n lab9 --timeout=60s
```

**Resultado esperado:**

```text
deployment "web" successfully rolled out
```

---

## Paso 15. Confirmar nuevamente las cuatro réplicas

```bash
kubectl get deployment web -n lab9
```

**Resultado esperado:** `web` vuelve a mostrar cuatro réplicas disponibles.

Una salida equivalente sería:

```text
READY
4/4
```

---

## Paso 16. Confirmar que todos los Pods están Ready

```bash
kubectl get pods -n lab9 -l app=web
```

**Resultado esperado:** los cuatro Pods están `Running` y `1/1 Ready`.

---

## Paso 17. Confirmar la imagen recuperada

```bash
kubectl get pods -n lab9 -l app=web -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.containers[0].image}{"\n"}{end}'
```

**Resultado esperado:** todos los Pods vuelven a utilizar:

```text
nginx:1.31.4-alpine3.24-slim
```

---

## Paso 18. Validar el historial final

Ejecuta la validación solicitada por la práctica:

```bash
kubectl rollout history deployment/web -n lab9
```

**Resultado esperado:** el historial continúa disponible después del rollback.

El reto queda resuelto si:

- el historial no fue eliminado;
- la revisión defectuosa queda registrada;
- el Deployment se encuentra nuevamente en una plantilla funcional;
- existen 4 réplicas;
- todos los Pods están Ready.

---

# Validación completa del reto

Ejecuta:

```bash
kubectl get deployment web -n lab9
```

```bash
kubectl get pods -n lab9 -l app=web
```

```bash
kubectl get deployment web -n lab9 -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

```bash
kubectl rollout history deployment/web -n lab9
```

```bash
kubectl get replicasets -n lab9
```

El estado correcto debe cumplir:

```text
Deployment: web
Réplicas: 4
Pods Ready: 4
Imagen funcional: nginx:1.31.4-alpine3.24-slim
Historial: disponible
Rollback: completado
```

---

# Qué ocurrió durante el reto

La secuencia lógica fue:

```text
Revisión funcional
nginx:1.31.4-alpine3.24-slim
        ↓
Nueva revisión defectuosa
nginx:lab9-challenge-image-does-not-exist
        ↓
ErrImagePull / ImagePullBackOff
        ↓
kubectl rollout undo
        ↓
Restauración de plantilla funcional
        ↓
4 Pods Ready
```

El rollback no consiste en reparar Pods individuales. Kubernetes modifica nuevamente el estado deseado del Deployment y sus controladores realizan la reconciliación necesaria.

---

# Relación entre Deployment, revisiones y ReplicaSets

Cada cambio en `spec.template` puede generar una nueva revisión:

```text
Deployment web
   │
   ├── ReplicaSet revisión anterior
   │      replicas: 0
   │
   ├── ReplicaSet revisión funcional
   │      replicas: 4
   │
   └── ReplicaSet revisión defectuosa
          replicas: 0 después del rollback
```

Los ReplicaSets anteriores pueden conservarse para permitir operaciones de rollback.

Puedes relacionarlos con sus revisiones mediante:

```bash
kubectl get rs -n lab9 -o custom-columns='NAME:.metadata.name,REVISION:.metadata.annotations.deployment\.kubernetes\.io/revision,DESIRED:.spec.replicas'
```

**Resultado esperado:** aparecen ReplicaSets asociados a distintas revisiones y únicamente el correspondiente al estado activo mantiene las réplicas deseadas.

---

# Limpieza

Ejecuta esta limpieza solamente después de terminar completamente el reto.

## Paso 19. Eliminar el namespace

```bash
kubectl delete namespace lab9 --wait=true
```

**Resultado esperado:**

```text
namespace "lab9" deleted
```

---

## Paso 20. Confirmar la limpieza

```bash
kubectl get namespace lab9 --ignore-not-found
```

**Resultado esperado:** no se muestra ningún namespace `lab9`.

Los archivos locales dentro de:

```text
ckad-labs/workspace/lab9
```

se conservan como material de estudio.

---

# Resumen de la solución

La solución del reto utiliza únicamente mecanismos propios del Deployment:

```text
Actualizar imagen
      ↓
kubectl set image
      ↓
RollingUpdate
      ↓
kubectl rollout status
      ↓
validar 4/4 Ready
      ↓
crear condición defectuosa
      ↓
diagnosticar
      ↓
kubectl rollout undo
      ↓
validar recuperación
```

La idea principal es que un Deployment mantiene historial de revisiones y permite recuperar una plantilla funcional mediante rollback sin reparar ni sustituir manualmente sus Pods.
