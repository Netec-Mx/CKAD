# Solución del reto — Práctica 8: Despliegue de aplicación con Deployment

## Alcance

Este solucionario cubre únicamente la sección de **reto final** de la Práctica 8.

El objetivo es aplicar de forma autónoma los conceptos practicados previamente con `Deployment`, `ReplicaSet`, réplicas y reconciliación.

La solución utiliza:

- Namespace: `lab8`
- Deployment del reto: `api`
- Réplicas: `2`
- Imagen: `nginx:1.31.4-alpine3.24-slim`
- Label principal: `app=api`

---

## Solución del reto

### Paso 1. Crear el manifiesto del Deployment `api`

Desde `ckad-labs/workspace/lab8`, crea el archivo:

```bash
cat > api-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: lab8
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: nginx
          image: nginx:1.31.4-alpine3.24-slim
          ports:
            - containerPort: 80
EOF
```

**Resultado esperado:** se crea `api-deployment.yaml` con un Deployment de dos réplicas.

---

### Paso 2. Validar el manifiesto antes de aplicarlo

```bash
kubectl apply --dry-run=client -f api-deployment.yaml
```

**Resultado esperado:**

```text
deployment.apps/api created (dry run)
```

Esta comprobación valida la estructura del manifiesto sin crear todavía recursos reales.

---

### Paso 3. Crear el Deployment

```bash
kubectl apply -f api-deployment.yaml
```

**Resultado esperado:**

```text
deployment.apps/api created
```

---

### Paso 4. Esperar a que el Deployment quede disponible

```bash
kubectl rollout status deployment/api -n lab8 --timeout=60s
```

**Resultado esperado:**

```text
deployment "api" successfully rolled out
```

---

### Paso 5. Validar las dos réplicas

```bash
kubectl get deployment api -n lab8
```

**Resultado esperado:** el Deployment muestra dos réplicas deseadas, actualizadas y disponibles.

Una salida equivalente sería:

```text
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
api    2/2     2            2           ...
```

Comprueba directamente el número de réplicas declarado:

```bash
kubectl get deployment api -n lab8 -o jsonpath='Replicas={.spec.replicas}{"\n"}'
```

**Resultado esperado:**

```text
Replicas=2
```

---

## Validar la relación Deployment → ReplicaSet → Pods

### Paso 6. Consultar los Pods administrados por `api`

```bash
kubectl get pods -n lab8 -l app=api
```

**Resultado esperado:** aparecen dos Pods `Running` y `Ready`.

Ejemplo:

```text
NAME                  READY   STATUS    RESTARTS   AGE
api-xxxxxxxxxx-aaaaa  1/1     Running   0          ...
api-xxxxxxxxxx-bbbbb  1/1     Running   0          ...
```

---

### Paso 7. Consultar el ReplicaSet

```bash
kubectl get replicasets -n lab8
```

**Resultado esperado:** aparece un ReplicaSet asociado al Deployment `api`.

El nombre tendrá un formato similar a:

```text
api-xxxxxxxxxx
```

---

### Paso 8. Visualizar la jerarquía de recursos

```bash
kubectl get deployment,replicaset,pods -n lab8 -l app=api
```

**Resultado esperado:** se observan los recursos administrados que representan la relación lógica:

```text
Deployment api
      ↓
ReplicaSet api-<hash>
      ↓
2 Pods api-<hash>-<id>
```

El Deployment mantiene el estado deseado y delega al ReplicaSet la conservación del número de Pods.

---

## Demostrar reconciliación

### Paso 9. Guardar el nombre de uno de los Pods

```bash
API_POD=$(kubectl get pods -n lab8 -l app=api -o jsonpath='{.items[0].metadata.name}')
```

Comprueba el valor obtenido:

```bash
echo "$API_POD"
```

**Resultado esperado:** se muestra el nombre de uno de los Pods administrados por `api`.

Ejemplo:

```text
api-xxxxxxxxxx-aaaaa
```

---

### Paso 10. Eliminar deliberadamente un Pod

```bash
kubectl delete pod "$API_POD" -n lab8
```

**Resultado esperado:** Kubernetes confirma la eliminación del Pod seleccionado.

Ejemplo:

```text
pod "api-xxxxxxxxxx-aaaaa" deleted
```

---

### Paso 11. Observar la reconciliación

```bash
kubectl get pods -n lab8 -l app=api -w
```

**Resultado esperado:** aparece un nuevo Pod creado automáticamente por el ReplicaSet para recuperar las dos réplicas deseadas.

Cuando nuevamente existan dos Pods `Running`, termina la observación con:

```text
Ctrl+C
```

---

### Paso 12. Confirmar el estado final

```bash
kubectl get deployment api -n lab8
```

**Resultado esperado:** el Deployment vuelve a mostrar:

```text
READY 2/2
```

Comprueba también los Pods:

```bash
kubectl get pods -n lab8 -l app=api
```

**Resultado esperado:** existen nuevamente dos Pods Ready, aunque uno de sus nombres es diferente al observado antes de la eliminación.

---

## ¿Por qué Kubernetes recreó el Pod?

El estado deseado del Deployment contiene:

```yaml
spec:
  replicas: 2
```

La relación es:

```text
Deployment
   ↓
ReplicaSet
   ↓
Pods
```

Cuando eliminaste manualmente un Pod:

```text
Estado deseado: 2 Pods
Estado observado: 1 Pod
```

El controlador detectó la diferencia y creó automáticamente un reemplazo:

```text
Estado deseado: 2
       ↓
Reconciliación
       ↓
Estado observado: 2
```

Esta es una de las ideas centrales de Kubernetes: los controladores trabajan continuamente para acercar el **estado observado** al **estado deseado**.

---

## Validación completa del reto

Ejecuta:

```bash
kubectl get deployment api -n lab8
```

```bash
kubectl get replicasets -n lab8
```

```bash
kubectl get pods -n lab8 -l app=api
```

```bash
kubectl get deployment api -n lab8 -o jsonpath='Replicas={.spec.replicas}{"\n"}'
```

El reto está resuelto correctamente cuando:

- Existe el Deployment `api`.
- `api` declara exactamente `2` réplicas.
- Existe un ReplicaSet administrado por el Deployment.
- Existen dos Pods con `app=api`.
- Ambos Pods están Ready.
- Al eliminar manualmente uno de los Pods, Kubernetes crea un reemplazo.
- El Deployment regresa automáticamente a `2/2` réplicas disponibles.

---

## Manifiesto final de la solución

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: lab8
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: nginx
          image: nginx:1.31.4-alpine3.24-slim
          ports:
            - containerPort: 80
```

---

## Limpieza

La limpieza debe realizarse únicamente después de completar y validar el reto.

Elimina el namespace utilizado por la práctica:

```bash
kubectl delete namespace lab8 --wait=true
```

**Resultado esperado:**

```text
namespace "lab8" deleted
```

Comprueba que ya no existe:

```bash
kubectl get namespace lab8 --ignore-not-found
```

**Resultado esperado:** no se muestra ningún namespace `lab8`.

El archivo local `api-deployment.yaml` permanece disponible dentro de `workspace/lab8` como material de estudio.

---

## Resumen de la solución

El reto demuestra este comportamiento:

```text
Deployment api
replicas: 2
     ↓
ReplicaSet
     ↓
Pod A + Pod B

Eliminar Pod A
     ↓
ReplicaSet detecta 1/2
     ↓
crea Pod C
     ↓
estado final 2/2
```

La clave no es solamente crear dos Pods, sino comprender que el Deployment mantiene declarativamente el estado deseado y Kubernetes reconcilia automáticamente cualquier desviación.
