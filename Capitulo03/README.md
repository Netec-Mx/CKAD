# Despliegue de aplicación con Deployment

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Crear |
| **Módulo** | 3 — Workloads en Kubernetes |

## Descripción General

En este laboratorio crearás un Deployment completo de Kubernetes para la aplicación `nginx:1.27.0`, configurando estrategia de actualización RollingUpdate, resource requests/limits, y probes de liveness y readiness. Explorarás la relación jerárquica Deployment → ReplicaSet → Pod, practicarás el escalamiento manual y prepararás el historial de revisiones para el laboratorio de rollback posterior.

## Objetivos de Aprendizaje

- [ ] Crear un Deployment con configuración completa incluyendo strategy, resources y probes
- [ ] Comprender la relación jerárquica Deployment → ReplicaSet → Pod y cómo el selector de etiquetas los vincula
- [ ] Configurar liveness y readiness probes para garantizar disponibilidad real de la aplicación
- [ ] Escalar manualmente un Deployment usando `kubectl scale` y verificar el comportamiento del ReplicaSet
- [ ] Inspeccionar el historial de revisiones y entender la anotación `kubernetes.io/change-cause`

## Prerrequisitos

### Conocimientos Requeridos

- Comprensión de Pods y su ciclo de vida (labs anteriores)
- Familiaridad con la estructura de manifiestos YAML de Kubernetes
- Concepto de ReplicaSets y la función de los controladores de Kubernetes
- Uso básico de `kubectl` y sus alias configurados

### Acceso Requerido

- Clúster kind 0.23.0 con Kubernetes 1.30.2 operativo
- `kubectl` 1.30.2 configurado y funcional
- Imagen `nginx:1.27.0` disponible en el clúster
- Acceso de escritura al directorio `~/ckad-labs/`

## Entorno del Laboratorio

### Software Necesario

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| kind | 0.23.0 | Clúster Kubernetes local |
| Kubernetes | 1.30.2 | Plataforma de orquestación |
| kubectl | 1.30.2 | CLI de gestión del clúster |
| nginx | 1.27.0 | Imagen de la aplicación web |

### Alias Activos

```bash
alias k=kubectl
alias kns='kubectl config set-context --current --namespace'
alias kgp='kubectl get pods'
alias kd='kubectl describe'
```

### Preparación Inicial del Entorno

```bash
# Verificar que el clúster está operativo
kubectl cluster-info

# Crear el directorio de trabajo para este laboratorio
mkdir -p ~/ckad-labs/lab08

# Crear el namespace dedicado para este laboratorio
kubectl create namespace ckad-workloads

# Establecer el namespace como default en el contexto actual
kubectl config set-context --current --namespace=ckad-workloads

# Verificar el namespace activo
kubectl config view --minify | grep namespace
```

**Salida esperada:**

```
namespace: ckad-workloads
```

## Paso a Paso

### Paso 1: Crear el Manifiesto del Deployment

**Objetivo:** Escribir un manifiesto YAML completo para el Deployment `webapp-deployment` con 3 réplicas, estrategia RollingUpdate, resource requests/limits, y probes de salud.

**Instrucciones:**

1. Cambia al directorio de trabajo del laboratorio:

```bash
cd ~/ckad-labs/lab08
```

2. Crea el archivo del manifiesto del Deployment:

```bash
cat <<'EOF' > webapp-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
  namespace: ckad-workloads
  labels:
    app: webapp
    tier: frontend
  annotations:
    kubernetes.io/change-cause: "Despliegue inicial con nginx:1.27.0"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: webapp
        tier: frontend
    spec:
      containers:
        - name: nginx
          image: nginx:1.27.0
          ports:
            - containerPort: 80
              protocol: TCP
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /healthz
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 15
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 3
EOF
```

3. Valida la sintaxis del manifiesto antes de aplicarlo:

```bash
kubectl apply --dry-run=client -f webapp-deployment.yaml
```

**Salida esperada:**

```
deployment.apps/webapp-deployment created (dry run)
```

**Verificación:**

```bash
# Confirmar que el archivo existe y tiene contenido válido
cat webapp-deployment.yaml | grep -E "^kind:|replicas:|image:|maxSurge:|readinessProbe:|livenessProbe:"
```

Debes ver las líneas clave del manifiesto confirmando la estructura correcta.

---

### Paso 2: Aplicar el Deployment al Clúster

**Objetivo:** Desplegar el Deployment en el clúster y monitorear el proceso de creación de pods.

**Instrucciones:**

1. Aplica el manifiesto al clúster:

```bash
kubectl apply -f webapp-deployment.yaml
```

**Salida esperada:**

```
deployment.apps/webapp-deployment created
```

2. Monitorea el estado del rollout en tiempo real:

```bash
kubectl rollout status deployment/webapp-deployment
```

**Salida esperada:**

```
Waiting for deployment "webapp-deployment" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "webapp-deployment" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "webapp-deployment" rollout to finish: 2 of 3 updated replicas are available...
deployment "webapp-deployment" successfully rolled out
```

3. Verifica que los 3 pods están en estado Running y Ready:

```bash
kubectl get pods -l app=webapp -o wide
```

**Salida esperada (ejemplo):**

```
NAME                                 READY   STATUS    RESTARTS   AGE   IP           NODE
webapp-deployment-7d9f8b6c4d-abc12   1/1     Running   0          45s   10.244.0.5   ckad-worker
webapp-deployment-7d9f8b6c4d-def34   1/1     Running   0          45s   10.244.0.6   ckad-worker
webapp-deployment-7d9f8b6c4d-ghi56   1/1     Running   0          45s   10.244.0.7   ckad-worker2
```

**Verificación:**

```bash
# Confirmar que el Deployment muestra 3/3 réplicas disponibles
kubectl get deployment webapp-deployment
```

La columna `AVAILABLE` debe mostrar `3`.

---

### Paso 3: Explorar la Jerarquía Deployment → ReplicaSet → Pod

**Objetivo:** Comprender cómo el Deployment gestiona ReplicaSets y cómo los label selectors vinculan los tres niveles jerárquicos.

**Instrucciones:**

1. Lista el ReplicaSet creado por el Deployment:

```bash
kubectl get replicasets -l app=webapp
```

**Salida esperada (ejemplo):**

```
NAME                           DESIRED   CURRENT   READY   AGE
webapp-deployment-7d9f8b6c4d   3         3         3       2m
```

2. Examina los detalles del ReplicaSet para ver la relación con el Deployment:

```bash
kubectl describe replicaset -l app=webapp | head -30
```

Observa el campo `Controlled By: Deployment/webapp-deployment` que confirma la jerarquía.

3. Inspecciona un Pod para verificar que está controlado por el ReplicaSet:

```bash
# Obtener el nombre del primer pod
POD_NAME=$(kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')

# Describir el pod y buscar la referencia al owner
kubectl describe pod $POD_NAME | grep -A 2 "Controlled By"
```

**Salida esperada:**

```
Controlled By:  ReplicaSet/webapp-deployment-7d9f8b6c4d
```

4. Visualiza la cadena completa de ownership:

```bash
# Deployment -> ReplicaSet
echo "=== DEPLOYMENT ==="
kubectl get deployment webapp-deployment -o jsonpath='{.metadata.name}' && echo ""

# ReplicaSet controlado por el Deployment
echo "=== REPLICASET ==="
kubectl get rs -l app=webapp -o jsonpath='{.items[0].metadata.name}' && echo ""
echo "  Owner: $(kubectl get rs -l app=webapp -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}/{.items[0].metadata.ownerReferences[0].name}')"

# Pods controlados por el ReplicaSet
echo "=== PODS ==="
kubectl get pods -l app=webapp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
```

**Verificación:**

```bash
# Verificar que los labels del selector coinciden en todos los niveles
echo "Deployment selector:"
kubectl get deployment webapp-deployment -o jsonpath='{.spec.selector.matchLabels}' && echo ""
echo "ReplicaSet selector:"
kubectl get rs -l app=webapp -o jsonpath='{.items[0].spec.selector.matchLabels}' && echo ""
echo "Pod labels:"
kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.labels}' && echo ""
```

Los tres niveles deben compartir `app: webapp` como label vinculante.

---

### Paso 4: Inspeccionar la Configuración del Deployment

**Objetivo:** Analizar los detalles de configuración del Deployment usando `kubectl describe` para verificar strategy, probes y resources.

**Instrucciones:**

1. Obtén la descripción completa del Deployment:

```bash
kubectl describe deployment webapp-deployment
```

2. Verifica los campos clave en la salida. Busca las siguientes secciones:

```bash
# Verificar la estrategia de actualización
kubectl get deployment webapp-deployment -o jsonpath='{.spec.strategy}' | jq .
```

**Salida esperada:**

```json
{
  "rollingUpdate": {
    "maxSurge": 1,
    "maxUnavailable": 0
  },
  "type": "RollingUpdate"
}
```

3. Verifica las probes configuradas:

```bash
# Readiness probe
kubectl get deployment webapp-deployment -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' | jq .
```

**Salida esperada:**

```json
{
  "failureThreshold": 3,
  "httpGet": {
    "path": "/",
    "port": 80,
    "scheme": "HTTP"
  },
  "initialDelaySeconds": 5,
  "periodSeconds": 10,
  "successThreshold": 1,
  "timeoutSeconds": 3
}
```

4. Verifica los resource limits:

```bash
kubectl get deployment webapp-deployment -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq .
```

**Salida esperada:**

```json
{
  "limits": {
    "cpu": "200m",
    "memory": "256Mi"
  },
  "requests": {
    "cpu": "100m",
    "memory": "128Mi"
  }
}
```

**Verificación:**

```bash
# Verificar que la liveness probe está configurada (aunque /healthz retornará 404)
kubectl get deployment webapp-deployment -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}'
```

Debe mostrar `/healthz`.

> **Nota importante:** La ruta `/healthz` no existe en nginx por defecto y retornará 404. Esto es intencional para este laboratorio: la liveness probe eventualmente fallará y reiniciará los pods. En un entorno real, configurarías una ruta válida. Para este ejercicio, observarás este comportamiento como parte del aprendizaje sobre probes. Si deseas evitar reinicios durante el laboratorio, puedes ajustar el `failureThreshold` o usar la ruta `/` para ambas probes.

---

### Paso 5: Ajustar la Liveness Probe para Estabilidad del Lab

**Objetivo:** Modificar la liveness probe para usar una ruta válida (`/`) y evitar reinicios innecesarios durante las prácticas de escalamiento.

**Instrucciones:**

1. Edita el manifiesto para corregir la liveness probe:

```bash
sed -i 's|path: /healthz|path: /|' webapp-deployment.yaml
```

2. Actualiza la anotación de change-cause:

```bash
sed -i 's|Despliegue inicial con nginx:1.27.0|Corrección liveness probe path a / para estabilidad|' webapp-deployment.yaml
```

3. Aplica el manifiesto actualizado:

```bash
kubectl apply -f webapp-deployment.yaml
```

4. Monitorea el rollout de la actualización:

```bash
kubectl rollout status deployment/webapp-deployment
```

**Salida esperada:**

```
deployment "webapp-deployment" successfully rolled out
```

5. Verifica que ahora hay dos ReplicaSets (el anterior escalado a 0 y el nuevo con 3 réplicas):

```bash
kubectl get replicasets -l app=webapp
```

**Salida esperada (ejemplo):**

```
NAME                           DESIRED   CURRENT   READY   AGE
webapp-deployment-5b8f9d7c2a   3         3         3       30s
webapp-deployment-7d9f8b6c4d   0         0         0       5m
```

**Verificación:**

```bash
# Confirmar que no hay reinicios en los pods nuevos
kubectl get pods -l app=webapp -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase
```

La columna RESTARTS debe mostrar `0` para todos los pods.

---

### Paso 6: Escalar el Deployment Manualmente

**Objetivo:** Practicar el escalamiento horizontal del Deployment usando `kubectl scale` y observar cómo el ReplicaSet gestiona los pods adicionales.

**Instrucciones:**

1. Escala el Deployment de 3 a 5 réplicas:

```bash
kubectl scale deployment webapp-deployment --replicas=5
```

**Salida esperada:**

```
deployment.apps/webapp-deployment scaled
```

2. Observa la creación de los nuevos pods en tiempo real:

```bash
kubectl get pods -l app=webapp -w
```

Presiona `Ctrl+C` cuando los 5 pods estén en estado `Running 1/1`.

3. Verifica el estado del Deployment:

```bash
kubectl get deployment webapp-deployment
```

**Salida esperada:**

```
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
webapp-deployment   5/5     5            5           7m
```

4. Confirma que el ReplicaSet refleja las 5 réplicas:

```bash
kubectl get rs -l app=webapp --sort-by=.metadata.creationTimestamp
```

5. Escala de vuelta a 3 réplicas:

```bash
kubectl scale deployment webapp-deployment --replicas=3
```

6. Verifica la terminación de los pods excedentes:

```bash
kubectl get pods -l app=webapp
```

**Salida esperada:**

```
NAME                                 READY   STATUS    RESTARTS   AGE
webapp-deployment-5b8f9d7c2a-xxx01   1/1     Running   0          3m
webapp-deployment-5b8f9d7c2a-xxx02   1/1     Running   0          3m
webapp-deployment-5b8f9d7c2a-xxx03   1/1     Running   0          3m
```

**Verificación:**

```bash
# Confirmar exactamente 3 pods activos
PODS_COUNT=$(kubectl get pods -l app=webapp --no-headers | wc -l)
echo "Pods activos: $PODS_COUNT"
[ "$PODS_COUNT" -eq 3 ] && echo "✓ Escalamiento correcto" || echo "✗ Número incorrecto de pods"
```

---

### Paso 7: Crear el Service ClusterIP para Verificar Conectividad

**Objetivo:** Crear un Service de tipo ClusterIP que exponga el Deployment y verificar la conectividad interna al clúster.

**Instrucciones:**

1. Crea el manifiesto del Service:

```bash
cat <<'EOF' > webapp-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: ckad-workloads
  labels:
    app: webapp
spec:
  type: ClusterIP
  selector:
    app: webapp
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
EOF
```

2. Aplica el Service:

```bash
kubectl apply -f webapp-service.yaml
```

**Salida esperada:**

```
service/webapp-service created
```

3. Verifica que el Service tiene endpoints asignados:

```bash
kubectl get endpoints webapp-service
```

**Salida esperada (ejemplo):**

```
NAME             ENDPOINTS                                      AGE
webapp-service   10.244.0.8:80,10.244.0.9:80,10.244.1.5:80     5s
```

4. Verifica la conectividad usando un pod temporal:

```bash
kubectl run test-connectivity --rm -it --restart=Never \
  --image=busybox:1.36.1 -- wget -qO- --timeout=5 http://webapp-service.ckad-workloads.svc.cluster.local/
```

**Salida esperada:**

Debes ver el HTML de la página de bienvenida de nginx, confirmando que el Service resuelve correctamente y enruta tráfico a los pods del Deployment.

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

**Verificación:**

```bash
# Verificar que el Service tiene exactamente 3 endpoints (uno por pod)
ENDPOINTS_COUNT=$(kubectl get endpoints webapp-service -o jsonpath='{.subsets[0].addresses}' | jq '. | length')
echo "Endpoints activos: $ENDPOINTS_COUNT"
[ "$ENDPOINTS_COUNT" -eq 3 ] && echo "✓ Service correctamente vinculado" || echo "✗ Número incorrecto de endpoints"
```

---

### Paso 8: Inspeccionar el Historial de Revisiones del Deployment

**Objetivo:** Examinar el historial de rollout del Deployment y comprender cómo la anotación `kubernetes.io/change-cause` documenta cada revisión.

**Instrucciones:**

1. Consulta el historial de revisiones:

```bash
kubectl rollout history deployment/webapp-deployment
```

**Salida esperada:**

```
deployment.apps/webapp-deployment
REVISION  CHANGE-CAUSE
1         Despliegue inicial con nginx:1.27.0
2         Corrección liveness probe path a / para estabilidad
```

2. Inspecciona los detalles de una revisión específica:

```bash
kubectl rollout history deployment/webapp-deployment --revision=1
```

**Salida esperada (parcial):**

```
deployment.apps/webapp-deployment with revision #1
Pod Template:
  Labels:       app=webapp
                pod-template-hash=7d9f8b6c4d
                tier=frontend
  Annotations:  kubernetes.io/change-cause: Despliegue inicial con nginx:1.27.0
  Containers:
   nginx:
    Image:      nginx:1.27.0
    Port:       80/TCP
    ...
```

3. Compara con la revisión actual:

```bash
kubectl rollout history deployment/webapp-deployment --revision=2
```

4. Añade una nueva anotación de change-cause para preparar el siguiente laboratorio:

```bash
kubectl annotate deployment webapp-deployment \
  kubernetes.io/change-cause="Preparado para Lab 03-00-02: rolling update y rollback" \
  --overwrite
```

5. Verifica que la anotación se actualizó en el historial:

```bash
kubectl rollout history deployment/webapp-deployment
```

**Salida esperada:**

```
deployment.apps/webapp-deployment
REVISION  CHANGE-CAUSE
1         Despliegue inicial con nginx:1.27.0
2         Preparado para Lab 03-00-02: rolling update y rollback
```

**Verificación:**

```bash
# Confirmar que hay exactamente 2 revisiones
REVISIONS=$(kubectl rollout history deployment/webapp-deployment --no-headers | wc -l)
echo "Revisiones en historial: $REVISIONS"
[ "$REVISIONS" -eq 2 ] && echo "✓ Historial correcto" || echo "✗ Historial inesperado"
```

---

### Paso 9: Verificar el Comportamiento de las Probes

**Objetivo:** Confirmar que las readiness probes están funcionando correctamente observando las condiciones del pod y los eventos del Deployment.

**Instrucciones:**

1. Verifica las condiciones de readiness de los pods:

```bash
kubectl get pods -l app=webapp -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
```

**Salida esperada:**

```
webapp-deployment-5b8f9d7c2a-xxx01	True
webapp-deployment-5b8f9d7c2a-xxx02	True
webapp-deployment-5b8f9d7c2a-xxx03	True
```

2. Inspecciona los eventos recientes del Deployment:

```bash
kubectl describe deployment webapp-deployment | tail -20
```

3. Verifica que no hay eventos de probe failure:

```bash
kubectl get events --namespace=ckad-workloads --field-selector reason=Unhealthy --no-headers 2>/dev/null | wc -l
```

Si el resultado es `0`, las probes están funcionando correctamente.

4. Inspecciona los detalles de un pod para ver la configuración de probes activa:

```bash
POD_NAME=$(kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD_NAME | grep -A 5 "Liveness\|Readiness"
```

**Salida esperada:**

```
    Liveness:       http-get http://:80/ delay=10s timeout=3s period=15s #success=1 #failure=3
    Readiness:      http-get http://:80/ delay=5s timeout=3s period=10s #success=1 #failure=3
```

**Verificación:**

```bash
# Verificar 0 reinicios en todos los pods
TOTAL_RESTARTS=$(kubectl get pods -l app=webapp -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | paste -sd+ | bc)
echo "Total reinicios: $TOTAL_RESTARTS"
[ "$TOTAL_RESTARTS" -eq 0 ] && echo "✓ Probes estables, sin reinicios" || echo "⚠ Se detectaron reinicios"
```

## Validación y Testing

Ejecuta la siguiente secuencia completa de validación para confirmar que el laboratorio se completó correctamente:

```bash
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   VALIDACIÓN FINAL - Lab 03-00-01                       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Namespace existe
echo "1. Namespace ckad-workloads:"
kubectl get namespace ckad-workloads > /dev/null 2>&1 && echo "   ✓ Existe" || echo "   ✗ No encontrado"

# Test 2: Deployment existe con 3 réplicas disponibles
echo "2. Deployment webapp-deployment:"
AVAILABLE=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ "$AVAILABLE" -eq 3 ] 2>/dev/null && echo "   ✓ 3/3 réplicas disponibles" || echo "   ✗ Réplicas: $AVAILABLE (esperado: 3)"

# Test 3: Imagen correcta
echo "3. Imagen del contenedor:"
IMAGE=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[ "$IMAGE" = "nginx:1.27.0" ] && echo "   ✓ nginx:1.27.0" || echo "   ✗ Imagen: $IMAGE"

# Test 4: Estrategia RollingUpdate
echo "4. Estrategia de actualización:"
STRATEGY=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.spec.strategy.type}' 2>/dev/null)
[ "$STRATEGY" = "RollingUpdate" ] && echo "   ✓ RollingUpdate" || echo "   ✗ Estrategia: $STRATEGY"

# Test 5: maxSurge y maxUnavailable
echo "5. Parámetros RollingUpdate:"
MAX_SURGE=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' 2>/dev/null)
MAX_UNAVAIL=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null)
[ "$MAX_SURGE" = "1" ] && [ "$MAX_UNAVAIL" = "0" ] && echo "   ✓ maxSurge=1, maxUnavailable=0" || echo "   ✗ maxSurge=$MAX_SURGE, maxUnavailable=$MAX_UNAVAIL"

# Test 6: Resources configurados
echo "6. Resource requests/limits:"
CPU_REQ=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
MEM_LIM=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)
[ "$CPU_REQ" = "100m" ] && [ "$MEM_LIM" = "256Mi" ] && echo "   ✓ cpu:100m/200m, memory:128Mi/256Mi" || echo "   ✗ cpu_req=$CPU_REQ, mem_lim=$MEM_LIM"

# Test 7: Readiness probe
echo "7. Readiness probe:"
RD_PATH=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
[ "$RD_PATH" = "/" ] && echo "   ✓ HTTP GET / :80" || echo "   ✗ Path: $RD_PATH"

# Test 8: Service existe con endpoints
echo "8. Service webapp-service:"
EP_COUNT=$(kubectl get endpoints webapp-service -n ckad-workloads -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | jq '. | length' 2>/dev/null)
[ "$EP_COUNT" -eq 3 ] 2>/dev/null && echo "   ✓ 3 endpoints activos" || echo "   ✗ Endpoints: $EP_COUNT"

# Test 9: Historial de revisiones
echo "9. Historial de rollout:"
REV_COUNT=$(kubectl rollout history deployment/webapp-deployment -n ckad-workloads --no-headers 2>/dev/null | wc -l)
[ "$REV_COUNT" -ge 2 ] 2>/dev/null && echo "   ✓ $REV_COUNT revisiones registradas" || echo "   ✗ Revisiones: $REV_COUNT"

# Test 10: Archivos en directorio de trabajo
echo "10. Archivos de manifiesto:"
[ -f ~/ckad-labs/lab08/webapp-deployment.yaml ] && [ -f ~/ckad-labs/lab08/webapp-service.yaml ] && echo "   ✓ Manifiestos presentes en ~/ckad-labs/lab08/" || echo "   ✗ Archivos faltantes"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Validación completada"
echo "═══════════════════════════════════════════════════════════"
```

## Troubleshooting

### Problema 1: Pods en estado CrashLoopBackOff por Liveness Probe

**Síntomas:**

```
NAME                                 READY   STATUS             RESTARTS     AGE
webapp-deployment-7d9f8b6c4d-abc12   0/1     CrashLoopBackOff   5 (30s ago)  4m
```

Al describir el pod se observa:

```
Warning  Unhealthy  Liveness probe failed: HTTP probe failed with statuscode: 404
```

**Causa:** La liveness probe está configurada con `path: /healthz`, pero nginx no tiene esa ruta configurada por defecto. Después de `failureThreshold` intentos fallidos (3 × 15s = 45s después del `initialDelaySeconds`), kubelet reinicia el contenedor.

**Solución:**

```bash
# Opción 1: Cambiar la ruta de la liveness probe a /
kubectl patch deployment webapp-deployment --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/path", "value": "/"}]'

# Opción 2: Editar el manifiesto y re-aplicar
sed -i 's|path: /healthz|path: /|' ~/ckad-labs/lab08/webapp-deployment.yaml
kubectl apply -f ~/ckad-labs/lab08/webapp-deployment.yaml

# Verificar que los pods se estabilizan
kubectl rollout status deployment/webapp-deployment
```

---

### Problema 2: Service sin Endpoints — Pods no Reciben Tráfico

**Síntomas:**

```bash
kubectl get endpoints webapp-service
```

```
NAME             ENDPOINTS   AGE
webapp-service   <none>      30s
```

Al intentar acceder al Service desde un pod de prueba:

```
wget: can't connect to remote host (10.96.45.123): Connection refused
```

**Causa:** El selector del Service (`app: webapp`) no coincide con los labels de los pods del Deployment. Esto ocurre comúnmente cuando se usa un label diferente en el `spec.template.metadata.labels` del Deployment (por ejemplo, `app: webapp-deployment` en lugar de `app: webapp`).

**Solución:**

```bash
# Diagnosticar: comparar labels del Service selector vs labels de los pods
echo "Service selector:"
kubectl get service webapp-service -o jsonpath='{.spec.selector}' | jq .

echo "Pod labels:"
kubectl get pods -l app=webapp --show-labels

# Si no aparecen pods, verificar qué labels tienen
kubectl get pods -n ckad-workloads --show-labels

# Corregir: asegurar que el selector del Service coincide con los labels del pod template
kubectl patch service webapp-service --type='json' \
  -p='[{"op": "replace", "path": "/spec/selector", "value": {"app": "webapp"}}]'

# Verificar que los endpoints aparecen
kubectl get endpoints webapp-service
```

## Limpieza

> **⚠️ NO ejecutar la limpieza si vas a continuar con el Lab 03-00-02.** El Deployment `webapp-deployment` debe permanecer activo para el siguiente laboratorio donde se practicarán rolling updates y rollbacks.

Si necesitas limpiar el entorno por completo:

```bash
# Eliminar todos los recursos del namespace
kubectl delete deployment webapp-deployment -n ckad-workloads
kubectl delete service webapp-service -n ckad-workloads

# Eliminar el namespace (solo si no se usará en labs posteriores)
kubectl delete namespace ckad-workloads

# Restaurar el namespace por defecto
kubectl config set-context --current --namespace=ckad-dev

# Los archivos de manifiesto se conservan para referencia
ls ~/ckad-labs/lab08/
```

## Resumen

En este laboratorio has completado las siguientes tareas:

| Concepto | Habilidad Demostrada |
|----------|---------------------|
| Deployment | Creación con manifiesto completo (strategy, resources, probes) |
| Jerarquía de recursos | Exploración de la cadena Deployment → ReplicaSet → Pod |
| Label selectors | Vinculación entre controladores y pods mediante `matchLabels` |
| Probes de salud | Configuración y diagnóstico de readiness y liveness probes |
| Escalamiento | Uso de `kubectl scale` para ajustar réplicas dinámicamente |
| Historial de rollout | Inspección de revisiones y uso de `change-cause` |
| Service ClusterIP | Exposición interna y verificación de conectividad |

### Conceptos Clave Reforzados

- Un **Deployment** es el recurso por defecto para aplicaciones sin estado que requieren alta disponibilidad, como se vio en la lección sobre selección de workloads.
- La estrategia **RollingUpdate** con `maxUnavailable: 0` garantiza cero downtime durante actualizaciones.
- Las **readiness probes** determinan cuándo un pod está listo para recibir tráfico del Service.
- Las **liveness probes** permiten que kubelet reinicie contenedores que dejaron de responder.
- El **historial de revisiones** (`rollout history`) es fundamental para gestionar rollbacks, tema del próximo laboratorio.

### Recursos Adicionales

- [Kubernetes Deployments — Documentación Oficial](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Managing Resources for Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Kubernetes Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)

### Próximo Laboratorio

En el **Lab 03-00-02** modificarás el Deployment `webapp-deployment` para practicar rolling updates, actualizaciones de imagen, y rollbacks usando `kubectl rollout undo`. El Deployment creado en este laboratorio es el punto de partida directo.

---

# Rolling update y rollback

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar |
| **Prerrequisito** | Lab 03-00-01 completado |
| **Namespace** | `ckad-workloads` |
| **Directorio de trabajo** | `~/ckad-labs/lab09/` |

## Descripción General

En este laboratorio ejecutarás el ciclo completo de actualizaciones progresivas (rolling updates) y rollbacks sobre el Deployment `webapp-deployment` creado en el Lab 03-00-01. Experimentarás con actualizaciones exitosas, simularás un despliegue fallido con una imagen inexistente, realizarás rollbacks a revisiones específicas y finalmente implementarás un patrón canary básico usando dos Deployments que comparten el mismo selector de Service para distribuir tráfico de forma proporcional.

## Objetivos de Aprendizaje

- [ ] Ejecutar una actualización progresiva (rolling update) cambiando la imagen del contenedor y monitorear su progreso en tiempo real
- [ ] Simular un despliegue fallido con una imagen inexistente y verificar que la estrategia `maxUnavailable: 0` protege el servicio existente
- [ ] Realizar un rollback a una revisión anterior específica usando `kubectl rollout undo --to-revision`
- [ ] Implementar un canary deployment básico con dos Deployments que comparten labels para distribuir tráfico a través de un mismo Service
- [ ] Inspeccionar el historial de revisiones y los ReplicaSets generados durante el ciclo de vida del Deployment

## Prerrequisitos

### Conocimiento Previo

| Tema | Nivel |
|------|-------|
| Deployments y ReplicaSets en Kubernetes | Intermedio |
| Estrategia RollingUpdate (maxSurge, maxUnavailable) | Básico |
| Comandos `kubectl` para gestión de workloads | Intermedio |
| Modelo de Service y label selectors | Básico |

### Acceso Requerido

- Clúster Kubernetes funcional (kind o minikube)
- `kubectl` 1.30.2 configurado con acceso al clúster
- Deployment `webapp-deployment` corriendo en namespace `ckad-workloads` con 3 réplicas (nginx:1.27.0)
- Service `webapp-service` apuntando a los pods con label `app=webapp`
- Acceso a Docker Hub para descargar `nginx:1.27.1`

## Entorno del Laboratorio

### Software Necesario

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| kubectl | 1.30.2 | Gestión del clúster |
| kind | 0.23.0 | Clúster local Kubernetes |
| curl | 8.5.0 | Verificación de conectividad |
| watch | (sistema) | Monitoreo en tiempo real |

### Preparación del Entorno

```bash
# Verificar que los alias están activos
alias k=kubectl

# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab09
cd ~/ckad-labs/lab09

# Verificar namespace y Deployment existente del Lab 03-00-01
kubectl get deployment webapp-deployment -n ckad-workloads -o wide
kubectl get svc webapp-service -n ckad-workloads

# Establecer namespace de trabajo
kubectl config set-context --current --namespace=ckad-workloads
```

**Salida esperada (verificación del Deployment):**
```
NAME                READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES         SELECTOR
webapp-deployment   3/3     3            3           ...   nginx        nginx:1.27.0   app=webapp
```

> **Nota:** Si el Deployment no existe, debes completar primero el Lab 03-00-01 o recrearlo con la imagen `nginx:1.27.0`, 3 réplicas y label `app=webapp`.

## Procedimiento Paso a Paso

### Paso 1: Verificar el Estado Inicial y la Estrategia de Actualización

**Objetivo:** Confirmar que el Deployment tiene la estrategia RollingUpdate configurada correctamente y documentar la revisión inicial.

**Instrucciones:**

1. Inspeccionar la estrategia de actualización actual del Deployment:

```bash
kubectl describe deployment webapp-deployment -n ckad-workloads | grep -A 5 "StrategyType"
```

2. Si la estrategia no tiene `maxUnavailable: 0`, aplicar un parche para garantizar zero-downtime durante las actualizaciones:

```bash
kubectl patch deployment webapp-deployment -n ckad-workloads --type='json' \
  -p='[{"op": "replace", "path": "/spec/strategy", "value": {"type": "RollingUpdate", "rollingUpdate": {"maxSurge": 1, "maxUnavailable": 0}}}]'
```

3. Verificar el historial de revisiones actual:

```bash
kubectl rollout history deployment/webapp-deployment -n ckad-workloads
```

4. Anotar los ReplicaSets existentes:

```bash
kubectl get replicasets -n ckad-workloads -l app=webapp -o wide
```

**Salida esperada:**
```
deployment.apps/webapp-deployment
REVISION  CHANGE-CAUSE
1         <none>
```

```
NAME                           DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES         SELECTOR
webapp-deployment-xxxxxxxxxx   3         3         3       ...   nginx        nginx:1.27.0   app=webapp,...
```

**Verificación:**
```bash
# Confirmar que maxUnavailable es 0
kubectl get deployment webapp-deployment -n ckad-workloads \
  -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}{"\n"}'
# Debe mostrar: 0
```

---

### Paso 2: Ejecutar un Rolling Update Exitoso

**Objetivo:** Actualizar la imagen de `nginx:1.27.0` a `nginx:1.27.1` y observar el proceso de rolling update en tiempo real.

**Instrucciones:**

1. En una terminal separada, iniciar el monitoreo en tiempo real de los pods:

```bash
watch -n 1 'kubectl get pods -n ckad-workloads -l app=webapp -o wide'
```

2. En otra terminal, ejecutar la actualización de imagen con anotación de causa:

```bash
kubectl set image deployment/webapp-deployment nginx=nginx:1.27.1 \
  -n ckad-workloads
```

3. Registrar la causa del cambio en la anotación del Deployment:

```bash
kubectl annotate deployment/webapp-deployment -n ckad-workloads \
  kubernetes.io/change-cause="Actualización a nginx:1.27.1 - rolling update exitoso"
```

4. Monitorear el progreso del rollout:

```bash
kubectl rollout status deployment/webapp-deployment -n ckad-workloads
```

5. Una vez completado, verificar los ReplicaSets (debe haber dos: el antiguo con 0 réplicas y el nuevo con 3):

```bash
kubectl get replicasets -n ckad-workloads -l app=webapp -o wide
```

6. Confirmar la imagen actual en los pods:

```bash
kubectl get pods -n ckad-workloads -l app=webapp \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

**Salida esperada (rollout status):**
```
Waiting for deployment "webapp-deployment" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "webapp-deployment" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "webapp-deployment" rollout to finish: 2 of 3 updated replicas are available...
deployment "webapp-deployment" successfully rolled out
```

**Salida esperada (ReplicaSets):**
```
NAME                           DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES         SELECTOR
webapp-deployment-aaaaaa       0         0         0       ...   nginx        nginx:1.27.0   app=webapp,...
webapp-deployment-bbbbbb       3         3         3       ...   nginx        nginx:1.27.1   app=webapp,...
```

**Verificación:**
```bash
# Verificar que la revisión 2 existe en el historial
kubectl rollout history deployment/webapp-deployment -n ckad-workloads
```

Salida esperada:
```
REVISION  CHANGE-CAUSE
1         <none>
2         Actualización a nginx:1.27.1 - rolling update exitoso
```

---

### Paso 3: Simular un Rolling Update Fallido

**Objetivo:** Provocar un despliegue fallido con una imagen inexistente y verificar que la estrategia `maxUnavailable: 0` protege los pods en servicio.

**Instrucciones:**

1. Intentar actualizar a una imagen que no existe:

```bash
kubectl set image deployment/webapp-deployment nginx=nginx:1.99.99-nonexistent \
  -n ckad-workloads
```

2. Anotar la causa del cambio:

```bash
kubectl annotate deployment/webapp-deployment -n ckad-workloads \
  kubernetes.io/change-cause="Intento fallido: imagen nginx:1.99.99-nonexistent" --overwrite
```

3. Observar el estado del rollout (quedará bloqueado):

```bash
kubectl rollout status deployment/webapp-deployment -n ckad-workloads --timeout=30s
```

4. Verificar el estado de los pods — los nuevos estarán en `ImagePullBackOff` o `ErrImagePull`:

```bash
kubectl get pods -n ckad-workloads -l app=webapp
```

5. Confirmar que los pods originales (nginx:1.27.1) siguen corriendo y sirviendo tráfico:

```bash
kubectl get pods -n ckad-workloads -l app=webapp \
  -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

6. Inspeccionar los eventos del Deployment para ver el error de pull:

```bash
kubectl describe deployment webapp-deployment -n ckad-workloads | tail -20
```

**Salida esperada (pods):**
```
NAME                                 READY   STATUS             RESTARTS   AGE
webapp-deployment-bbbbbb-xxxxx       1/1     Running            0          5m
webapp-deployment-bbbbbb-yyyyy       1/1     Running            0          5m
webapp-deployment-bbbbbb-zzzzz       1/1     Running            0          5m
webapp-deployment-cccccc-aaaaa       0/1     ImagePullBackOff   0          30s
```

> **Observación clave:** Gracias a `maxUnavailable: 0`, los 3 pods de la revisión anterior permanecen activos. El nuevo pod no puede arrancar, pero el servicio no se ve afectado. Esto demuestra la importancia de configurar correctamente la estrategia de rolling update.

**Verificación:**
```bash
# Confirmar que hay exactamente 3 pods Running
kubectl get pods -n ckad-workloads -l app=webapp --field-selector=status.phase=Running --no-headers | wc -l
# Debe mostrar: 3
```

---

### Paso 4: Ejecutar Rollback al Estado Anterior

**Objetivo:** Revertir el despliegue fallido usando `kubectl rollout undo` para restaurar la imagen funcional.

**Instrucciones:**

1. Ejecutar rollback a la revisión inmediatamente anterior:

```bash
kubectl rollout undo deployment/webapp-deployment -n ckad-workloads
```

2. Monitorear el rollback:

```bash
kubectl rollout status deployment/webapp-deployment -n ckad-workloads
```

3. Verificar que todos los pods volvieron a la imagen correcta:

```bash
kubectl get pods -n ckad-workloads -l app=webapp \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

4. Revisar el historial actualizado:

```bash
kubectl rollout history deployment/webapp-deployment -n ckad-workloads
```

**Salida esperada (rollback):**
```
deployment.apps/webapp-deployment rolled back
```

**Salida esperada (imágenes de pods):**
```
webapp-deployment-bbbbbb-xxxxx    nginx:1.27.1
webapp-deployment-bbbbbb-yyyyy    nginx:1.27.1
webapp-deployment-bbbbbb-zzzzz    nginx:1.27.1
```

**Salida esperada (historial):**
```
REVISION  CHANGE-CAUSE
1         <none>
3         Intento fallido: imagen nginx:1.99.99-nonexistent
4         Actualización a nginx:1.27.1 - rolling update exitoso
```

> **Nota:** Al hacer rollback, la revisión 2 se convierte en revisión 4. Kubernetes no duplica revisiones sino que las renumera.

**Verificación:**
```bash
kubectl get deployment webapp-deployment -n ckad-workloads \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# Debe mostrar: nginx:1.27.1
```

---

### Paso 5: Rollback a una Revisión Específica (Revisión 1)

**Objetivo:** Usar `kubectl rollout undo --to-revision` para volver a la imagen original `nginx:1.27.0` (revisión 1).

**Instrucciones:**

1. Listar las revisiones disponibles con detalle:

```bash
kubectl rollout history deployment/webapp-deployment -n ckad-workloads
```

2. Inspeccionar los detalles de la revisión 1 para confirmar la imagen:

```bash
kubectl rollout history deployment/webapp-deployment -n ckad-workloads --revision=1
```

3. Ejecutar rollback a la revisión 1:

```bash
kubectl rollout undo deployment/webapp-deployment -n ckad-workloads --to-revision=1
```

4. Esperar a que se complete:

```bash
kubectl rollout status deployment/webapp-deployment -n ckad-workloads
```

5. Verificar que los pods ahora usan `nginx:1.27.0`:

```bash
kubectl get pods -n ckad-workloads -l app=webapp \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

6. Anotar la causa del cambio:

```bash
kubectl annotate deployment/webapp-deployment -n ckad-workloads \
  kubernetes.io/change-cause="Rollback a nginx:1.27.0 - revisión estable" --overwrite
```

**Salida esperada (detalles revisión 1):**
```
deployment.apps/webapp-deployment with revision #1
Pod Template:
  Labels:       app=webapp
                pod-template-hash=xxxxxxxxxx
  Containers:
   nginx:
    Image:      nginx:1.27.0
    Port:       <none>
    ...
```

**Salida esperada (imágenes de pods después del rollback):**
```
webapp-deployment-xxxxxxxxxx-xxxxx    nginx:1.27.0
webapp-deployment-xxxxxxxxxx-yyyyy    nginx:1.27.0
webapp-deployment-xxxxxxxxxx-zzzzz    nginx:1.27.0
```

**Verificación:**
```bash
kubectl get deployment webapp-deployment -n ckad-workloads \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# Debe mostrar: nginx:1.27.0
```

---

### Paso 6: Implementar un Canary Deployment

**Objetivo:** Crear un segundo Deployment `webapp-canary` con 1 réplica usando `nginx:1.27.1` y los mismos labels `app=webapp` para que el Service `webapp-service` distribuya tráfico entre las 3 réplicas estables y 1 réplica canary.

**Instrucciones:**

1. Crear el manifiesto del Deployment canary:

```bash
cat <<'EOF' > ~/ckad-labs/lab09/webapp-canary.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-canary
  namespace: ckad-workloads
  labels:
    app: webapp
    track: canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
      track: canary
  template:
    metadata:
      labels:
        app: webapp
        track: canary
    spec:
      containers:
        - name: nginx
          image: nginx:1.27.1
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
EOF
```

2. Aplicar el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab09/webapp-canary.yaml
```

3. Verificar que ambos Deployments están corriendo:

```bash
kubectl get deployments -n ckad-workloads -l app=webapp
```

4. Verificar que el Service `webapp-service` ve los 4 pods (3 stable + 1 canary):

```bash
kubectl get endpoints webapp-service -n ckad-workloads
```

5. Confirmar que hay 4 endpoints listados:

```bash
kubectl get endpoints webapp-service -n ckad-workloads -o jsonpath='{.subsets[0].addresses}' | jq '. | length'
```

6. Probar la distribución de tráfico ejecutando múltiples requests al Service. Primero, crear un pod de prueba:

```bash
kubectl run curl-test --image=busybox:1.36.1 -n ckad-workloads \
  --rm -it --restart=Never -- sh -c '
  for i in $(seq 1 20); do
    wget -qO- http://webapp-service/index.html 2>/dev/null | grep -o "nginx/[0-9.]*" || echo "no-version"
    sleep 0.5
  done
'
```

> **Nota:** Dado que ambas versiones de nginx (1.27.0 y 1.27.1) sirven la misma página por defecto, la diferencia visible puede ser mínima. La distribución se verifica por el número de endpoints.

7. Verificar la distribución por pod usando los logs del Service (alternativa más confiable):

```bash
kubectl get pods -n ckad-workloads -l app=webapp -o wide --show-labels
```

**Salida esperada (Deployments):**
```
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
webapp-canary       1/1     1            1           30s
webapp-deployment   3/3     3            3           ...
```

**Salida esperada (endpoints):**
```
NAME             ENDPOINTS                                            AGE
webapp-service   10.244.x.x:80,10.244.x.x:80,10.244.x.x:80 + 1 more...   ...
```

**Verificación:**
```bash
# Confirmar 4 pods totales con label app=webapp
kubectl get pods -n ckad-workloads -l app=webapp --no-headers | wc -l
# Debe mostrar: 4

# Verificar que el pod canary tiene la imagen correcta
kubectl get pods -n ckad-workloads -l track=canary \
  -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
# Debe mostrar: nginx:1.27.1
```

---

### Paso 7: Verificar la Distribución del Tráfico Canary

**Objetivo:** Demostrar que el Service distribuye tráfico a ambos Deployments proporcionalmente al número de pods (75% stable, 25% canary).

**Instrucciones:**

1. Personalizar la respuesta de cada grupo para distinguirlos. Inyectar un identificador en el pod canary:

```bash
CANARY_POD=$(kubectl get pods -n ckad-workloads -l track=canary -o jsonpath='{.items[0].metadata.name}')
kubectl exec $CANARY_POD -n ckad-workloads -- sh -c 'echo "CANARY-v1.27.1" > /usr/share/nginx/html/version.txt'
```

2. Inyectar identificador en los pods stable:

```bash
for POD in $(kubectl get pods -n ckad-workloads -l app=webapp,track!=canary -o jsonpath='{.items[*].metadata.name}'); do
  kubectl exec $POD -n ckad-workloads -- sh -c 'echo "STABLE-v1.27.0" > /usr/share/nginx/html/version.txt' 2>/dev/null || true
done
```

3. Ejecutar 20 requests al endpoint `/version.txt` y contar la distribución:

```bash
kubectl run traffic-test --image=busybox:1.36.1 -n ckad-workloads \
  --rm -it --restart=Never -- sh -c '
  STABLE=0; CANARY=0
  for i in $(seq 1 20); do
    RESP=$(wget -qO- http://webapp-service/version.txt 2>/dev/null)
    case "$RESP" in
      *STABLE*) STABLE=$((STABLE+1)) ;;
      *CANARY*) CANARY=$((CANARY+1)) ;;
    esac
  done
  echo "Stable: $STABLE / Canary: $CANARY (de 20 requests)"
'
```

**Salida esperada (aproximada):**
```
Stable: 15 / Canary: 5 (de 20 requests)
```

> **Nota:** La distribución exacta varía debido a la naturaleza round-robin de kube-proxy, pero debe aproximarse a 75%/25% (3:1 ratio) con suficientes muestras.

**Verificación:**

La distribución debe mostrar que ambos grupos reciben tráfico, demostrando que el Service selecciona pods basándose en el label `app=webapp` independientemente del Deployment que los gestiona.

---

## Validación y Testing

Ejecutar la siguiente secuencia de verificaciones para confirmar que todos los objetivos se cumplieron:

```bash
echo "=== VALIDACIÓN COMPLETA DEL LAB 03-00-02 ==="

echo ""
echo "1. Deployment webapp-deployment con nginx:1.27.0 (estado estable):"
IMG=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "   Imagen actual: $IMG"
[ "$IMG" = "nginx:1.27.0" ] && echo "   ✓ CORRECTO" || echo "   ✗ ERROR: debería ser nginx:1.27.0"

echo ""
echo "2. Réplicas del Deployment principal:"
READY=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.status.readyReplicas}')
echo "   Ready: $READY/3"
[ "$READY" = "3" ] && echo "   ✓ CORRECTO" || echo "   ✗ ERROR: deberían ser 3"

echo ""
echo "3. Historial de revisiones (debe tener múltiples):"
REVISIONS=$(kubectl rollout history deployment/webapp-deployment -n ckad-workloads --no-headers | wc -l)
echo "   Revisiones registradas: $REVISIONS"
[ "$REVISIONS" -ge 3 ] && echo "   ✓ CORRECTO (>=3 revisiones)" || echo "   ✗ ERROR: deberían existir al menos 3 revisiones"

echo ""
echo "4. Deployment canary existe:"
kubectl get deployment webapp-canary -n ckad-workloads > /dev/null 2>&1
[ $? -eq 0 ] && echo "   ✓ CORRECTO" || echo "   ✗ ERROR: webapp-canary no encontrado"

echo ""
echo "5. Canary usa nginx:1.27.1:"
CANARY_IMG=$(kubectl get deployment webapp-canary -n ckad-workloads -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
echo "   Imagen canary: $CANARY_IMG"
[ "$CANARY_IMG" = "nginx:1.27.1" ] && echo "   ✓ CORRECTO" || echo "   ✗ ERROR: debería ser nginx:1.27.1"

echo ""
echo "6. Service webapp-service tiene 4 endpoints:"
EP_COUNT=$(kubectl get endpoints webapp-service -n ckad-workloads -o jsonpath='{.subsets[0].addresses}' | jq '. | length' 2>/dev/null)
echo "   Endpoints: $EP_COUNT"
[ "$EP_COUNT" = "4" ] && echo "   ✓ CORRECTO" || echo "   ✗ ERROR: deberían ser 4 endpoints"

echo ""
echo "7. Estrategia maxUnavailable=0:"
MAX_UNAVAIL=$(kubectl get deployment webapp-deployment -n ckad-workloads -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}')
echo "   maxUnavailable: $MAX_UNAVAIL"
[ "$MAX_UNAVAIL" = "0" ] && echo "   ✓ CORRECTO" || echo "   ✗ ERROR: debería ser 0"

echo ""
echo "=== FIN DE VALIDACIÓN ==="
```

## Troubleshooting

### Problema 1: El rolling update se queda bloqueado indefinidamente

**Síntomas:**
- `kubectl rollout status` no avanza
- Los nuevos pods permanecen en estado `Pending` o `ContainerCreating`
- No se observan pods en `ImagePullBackOff` (la imagen es válida)

**Causa:**
Con `maxUnavailable: 0` y `maxSurge: 1`, Kubernetes necesita crear un pod adicional antes de terminar uno existente. Si el clúster no tiene recursos suficientes (CPU/memoria) para programar el pod extra, el rollout se bloquea porque el scheduler no puede colocar el nuevo pod.

**Solución:**
```bash
# Verificar eventos del pod pendiente
kubectl get pods -n ckad-workloads -l app=webapp | grep -v Running
kubectl describe pod <pod-pendiente> -n ckad-workloads | grep -A 5 Events

# Si es un problema de recursos, reducir los requests o agregar un nodo
kubectl top nodes

# Alternativa: aumentar maxSurge para dar más margen
kubectl patch deployment webapp-deployment -n ckad-workloads --type='json' \
  -p='[{"op": "replace", "path": "/spec/strategy/rollingUpdate/maxSurge", "value": 2}]'
```

---

### Problema 2: El Service no distribuye tráfico al pod canary

**Síntomas:**
- `kubectl get endpoints webapp-service` muestra solo 3 IPs (no incluye el pod canary)
- Todas las requests van al Deployment stable
- El pod canary está `Running` pero no recibe tráfico

**Causa:**
El selector del Service no coincide con los labels del pod canary. El Service `webapp-service` probablemente usa un selector que incluye un label adicional (como `pod-template-hash` o `track: stable`) que excluye los pods del Deployment canary. El selector debe ser únicamente `app: webapp` para capturar ambos conjuntos de pods.

**Solución:**
```bash
# Verificar el selector actual del Service
kubectl get svc webapp-service -n ckad-workloads -o jsonpath='{.spec.selector}{"\n"}'

# Debe mostrar solo: {"app":"webapp"}
# Si tiene selectores adicionales, parchear:
kubectl patch svc webapp-service -n ckad-workloads --type='json' \
  -p='[{"op": "replace", "path": "/spec/selector", "value": {"app": "webapp"}}]'

# Verificar que los labels del pod canary incluyen app=webapp
kubectl get pods -n ckad-workloads -l track=canary --show-labels

# Confirmar que los endpoints ahora incluyen 4 IPs
kubectl get endpoints webapp-service -n ckad-workloads
```

## Limpieza

Para dejar el entorno en el estado esperado para el Lab 03-00-03, eliminar **solo** el Deployment canary y mantener el Deployment principal con `nginx:1.27.0`:

```bash
# Eliminar el Deployment canary
kubectl delete deployment webapp-canary -n ckad-workloads

# Verificar que solo queda el Deployment principal
kubectl get deployments -n ckad-workloads

# Confirmar estado estable: 3 réplicas con nginx:1.27.0
kubectl get deployment webapp-deployment -n ckad-workloads -o wide

# Verificar que el Service vuelve a tener 3 endpoints
kubectl get endpoints webapp-service -n ckad-workloads

# Limpiar pods de prueba huérfanos (si los hay)
kubectl delete pod --field-selector=status.phase==Succeeded -n ckad-workloads 2>/dev/null
kubectl delete pod --field-selector=status.phase==Failed -n ckad-workloads 2>/dev/null
```

**Estado final esperado:**
```
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
webapp-deployment   3/3     3            3           ...
```

> **Importante:** El Deployment `webapp-deployment` con `nginx:1.27.0` y 3 réplicas debe permanecer activo como prerequisito del Lab 03-00-03.

## Resumen

En este laboratorio aplicaste el ciclo completo de gestión de actualizaciones en Kubernetes:

| Fase | Acción | Resultado |
|------|--------|-----------|
| Rolling Update exitoso | `kubectl set image` → nginx:1.27.1 | Nueva revisión creada, zero-downtime |
| Rolling Update fallido | Imagen inexistente | Pods en ImagePullBackOff, servicio protegido por maxUnavailable:0 |
| Rollback inmediato | `kubectl rollout undo` | Reversión a revisión funcional |
| Rollback específico | `--to-revision=1` | Restauración a nginx:1.27.0 |
| Canary deployment | Segundo Deployment con mismos labels | Distribución 75/25 del tráfico |

### Conceptos Clave Reforzados

- La estrategia `RollingUpdate` con `maxUnavailable: 0` garantiza que nunca se reduce la capacidad durante una actualización
- Kubernetes mantiene un historial de ReplicaSets que permite rollbacks instantáneos sin re-pull de imágenes
- El patrón canary con múltiples Deployments aprovecha el modelo de Service basado en label selectors para distribuir tráfico proporcionalmente
- `kubectl rollout history` y `--to-revision` proporcionan control granular sobre el versionado de despliegues

### Recursos Adicionales

- [Kubernetes Docs: Performing a Rolling Update](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Kubernetes Docs: Deployments - Rolling Back](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-back-a-deployment)
- [Kubernetes Docs: Canary Deployments](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/#canary-deployments)

---

# Jobs y CronJobs

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 40 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar |
| **Namespace principal** | `ckad-batch` |
| **Directorio de trabajo** | `~/ckad-labs/lab10/` |

## Descripción General

En este laboratorio implementarás cargas de trabajo batch en Kubernetes utilizando Jobs y CronJobs. Crearás un Job simple con ejecución única, un Job paralelo con múltiples completions, un CronJob programado con políticas de retención y un Job con imagen inválida para observar el comportamiento de reintentos. Al finalizar, comprenderás cuándo y cómo utilizar estos recursos frente a Deployments o DaemonSets.

## Objetivos de Aprendizaje

- [ ] Crear y ejecutar un Job de Kubernetes con control de `completions`, `parallelism`, `backoffLimit` y `activeDeadlineSeconds`
- [ ] Configurar un Job paralelo y observar la creación simultánea de Pods hasta alcanzar el número de completions deseado
- [ ] Crear un CronJob con expresión cron, políticas de concurrencia y retención de historial de Jobs completados
- [ ] Inspeccionar logs y estado de Pods creados por Jobs y CronJobs para verificar ejecución exitosa
- [ ] Distinguir los casos de uso apropiados entre Job, CronJob, Deployment y DaemonSet según el tipo de carga de trabajo

## Prerrequisitos

### Conocimiento Requerido

| Concepto | Nivel |
|----------|-------|
| Manifiestos YAML de Kubernetes | Intermedio |
| Comandos kubectl básicos (get, describe, logs) | Intermedio |
| Tipos de workload (Deployment, DaemonSet, StatefulSet) | Conceptual |
| Expresiones cron (formato de 5 campos) | Básico |

### Acceso Requerido

- Clúster kind 0.23.0 con Kubernetes 1.30.2 operativo
- kubectl 1.30.2 configurado y conectado al clúster
- Acceso a imágenes `alpine:3.20.1` y `busybox:1.36.1`
- Terminal bash con alias estándar del curso configurados

## Entorno del Laboratorio

### Software Utilizado

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| kind | 0.23.0 | Clúster Kubernetes local |
| Kubernetes | 1.30.2 | Plataforma de orquestación |
| kubectl | 1.30.2 | CLI de gestión del clúster |
| alpine | 3.20.1 | Imagen base para Jobs |
| busybox | 1.36.1 | Imagen ligera para workers |

### Preparación del Entorno

```bash
# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab10
cd ~/ckad-labs/lab10

# Crear namespace dedicado para este laboratorio
kubectl create namespace ckad-batch

# Verificar que el namespace existe
kubectl get namespace ckad-batch

# Establecer el namespace como default para esta sesión
kubectl config set-context --current --namespace=ckad-batch

# Verificar contexto actual
kubectl config view --minify | grep namespace
```

**Salida esperada:**
```
namespace created
NAME          STATUS   AGE
ckad-batch    Active   2s
namespace: ckad-batch
```

## Paso a Paso

### Paso 1: Crear un Job Simple de Procesamiento de Datos

**Objetivo:** Crear un Job llamado `data-processor-job` que ejecute un script de procesamiento simulado con control de completions, reintentos y tiempo límite.

**Instrucciones:**

1. Crea el manifiesto del Job:

```bash
cat <<'EOF' > ~/ckad-labs/lab10/data-processor-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processor-job
  namespace: ckad-batch
  labels:
    app: data-processor
    type: batch
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 3
  activeDeadlineSeconds: 120
  template:
    metadata:
      labels:
        app: data-processor
    spec:
      restartPolicy: Never
      containers:
        - name: processor
          image: alpine:3.20.1
          command:
            - /bin/sh
            - -c
            - |
              echo "=== DATA PROCESSOR JOB STARTED ==="
              echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
              echo "Hostname: $(hostname)"
              echo "---"
              echo "Phase 1: Generating data records..."
              for i in $(seq 1 100); do
                echo "[$(date -u +%H:%M:%S)] Record $i processed"
              done
              echo "---"
              echo "Phase 2: Simulating computation..."
              sleep 5
              echo "---"
              echo "Phase 3: Writing results..."
              RESULT="Processed 100 records in $(hostname) at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
              echo "RESULT: $RESULT"
              echo "=== DATA PROCESSOR JOB COMPLETED ==="
              exit 0
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab10/data-processor-job.yaml
```

3. Observa el progreso del Job en tiempo real:

```bash
kubectl get job data-processor-job -w
```

4. Espera aproximadamente 10 segundos y luego presiona `Ctrl+C`. Verifica el estado final:

```bash
kubectl get job data-processor-job
```

**Salida esperada:**
```
NAME                 COMPLETIONS   DURATION   AGE
data-processor-job   1/1           8s         15s
```

**Verificación:**

```bash
# Verificar que el Job se completó exitosamente
kubectl get job data-processor-job -o jsonpath='{.status.conditions[0].type}'
echo ""

# Verificar el Pod creado por el Job
kubectl get pods --selector=job-name=data-processor-job
```

**Salida esperada:**
```
Complete
NAME                       READY   STATUS      RESTARTS   AGE
data-processor-job-xxxxx   0/1     Completed   0          20s
```

5. Revisa los logs del Pod completado:

```bash
kubectl logs job/data-processor-job
```

**Salida esperada (extracto):**
```
=== DATA PROCESSOR JOB STARTED ===
Timestamp: 2024-XX-XXTXX:XX:XXZ
Hostname: data-processor-job-xxxxx
---
Phase 1: Generating data records...
[XX:XX:XX] Record 1 processed
[XX:XX:XX] Record 2 processed
...
[XX:XX:XX] Record 100 processed
---
Phase 2: Simulating computation...
---
Phase 3: Writing results...
RESULT: Processed 100 records in data-processor-job-xxxxx at 2024-XX-XXTXX:XX:XXZ
=== DATA PROCESSOR JOB COMPLETED ===
```

6. Inspecciona los detalles del Job:

```bash
kubectl describe job data-processor-job | grep -A 5 "Pods Statuses"
```

**Salida esperada:**
```
Pods Statuses:    0 Active (0 Ready) / 1 Succeeded / 0 Failed
```

---

### Paso 2: Crear un Job Paralelo con Múltiples Workers

**Objetivo:** Crear un Job llamado `parallel-worker-job` que ejecute 6 completions con un paralelismo de 2, observando cómo Kubernetes crea Pods simultáneamente.

**Instrucciones:**

1. Crea el manifiesto del Job paralelo:

```bash
cat <<'EOF' > ~/ckad-labs/lab10/parallel-worker-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-worker-job
  namespace: ckad-batch
  labels:
    app: parallel-worker
    type: batch
spec:
  completions: 6
  parallelism: 2
  backoffLimit: 4
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels:
        app: parallel-worker
    spec:
      restartPolicy: Never
      containers:
        - name: worker
          image: busybox:1.36.1
          command:
            - /bin/sh
            - -c
            - |
              WORKER_ID=$(echo $HOSTNAME | awk -F'-' '{print $NF}')
              echo "Worker $WORKER_ID started at $(date -u +%H:%M:%S)"
              echo "Processing batch assigned to $(hostname)..."
              sleep $(shuf -i 3-8 -n 1)
              echo "Worker $WORKER_ID completed at $(date -u +%H:%M:%S)"
              exit 0
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab10/parallel-worker-job.yaml
```

3. Observa la creación de Pods en paralelo (ejecuta rápidamente después de aplicar):

```bash
kubectl get pods --selector=job-name=parallel-worker-job -w
```

> **Nota:** Observa cómo se crean exactamente 2 Pods simultáneamente. Cuando uno completa, se crea otro hasta alcanzar 6 completions totales. Presiona `Ctrl+C` cuando todos muestren `Completed`.

4. Verifica el progreso del Job:

```bash
kubectl get job parallel-worker-job
```

**Salida esperada (cuando completa):**
```
NAME                  COMPLETIONS   DURATION   AGE
parallel-worker-job   6/6           25s        30s
```

**Verificación:**

```bash
# Listar todos los Pods creados por el Job paralelo
kubectl get pods --selector=job-name=parallel-worker-job --sort-by=.status.startTime

# Contar Pods completados
kubectl get pods --selector=job-name=parallel-worker-job --field-selector=status.phase=Succeeded --no-headers | wc -l
```

**Salida esperada:**
```
6
```

5. Revisa los logs de todos los workers:

```bash
kubectl logs --selector=job-name=parallel-worker-job --prefix=true
```

**Salida esperada (ejemplo):**
```
[pod/parallel-worker-job-xxxxx/worker] Worker xxxxx started at 14:30:05
[pod/parallel-worker-job-xxxxx/worker] Processing batch assigned to parallel-worker-job-xxxxx...
[pod/parallel-worker-job-xxxxx/worker] Worker xxxxx completed at 14:30:10
...
```

---

### Paso 3: Crear un CronJob Programado

**Objetivo:** Crear un CronJob llamado `cleanup-cronjob` que ejecute cada 2 minutos una tarea de limpieza simulada, con políticas de retención y concurrencia configuradas.

**Instrucciones:**

1. Crea el manifiesto del CronJob:

```bash
cat <<'EOF' > ~/ckad-labs/lab10/cleanup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-cronjob
  namespace: ckad-batch
  labels:
    app: cleanup
    type: scheduled
spec:
  schedule: "*/2 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    metadata:
      labels:
        app: cleanup
    spec:
      activeDeadlineSeconds: 60
      template:
        metadata:
          labels:
            app: cleanup
        spec:
          restartPolicy: OnFailure
          containers:
            - name: cleanup
              image: alpine:3.20.1
              command:
                - /bin/sh
                - -c
                - |
                  echo "=== CLEANUP TASK STARTED ==="
                  echo "Execution time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
                  echo "Scanning for temporary files..."
                  sleep 2
                  echo "Found 15 temporary files older than 24h"
                  echo "Removing /tmp/cache-*.dat ... done"
                  echo "Removing /tmp/session-*.tmp ... done"
                  echo "Removing /tmp/upload-*.part ... done"
                  echo "Freed 256MB of disk space"
                  echo "=== CLEANUP TASK COMPLETED ==="
                  exit 0
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab10/cleanup-cronjob.yaml
```

3. Verifica que el CronJob fue creado correctamente:

```bash
kubectl get cronjob cleanup-cronjob
```

**Salida esperada:**
```
NAME              SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cleanup-cronjob   */2 * * * *   False     0        <none>          5s
```

4. Espera la primera ejecución (máximo 2 minutos). Monitorea con:

```bash
# Observar cuándo se dispara el primer Job
kubectl get cronjob cleanup-cronjob -w
```

> **Nota:** Espera hasta que la columna `LAST SCHEDULE` muestre un valor. Presiona `Ctrl+C`.

5. Una vez que se haya ejecutado al menos una vez, verifica los Jobs creados:

```bash
kubectl get jobs --selector=app=cleanup
```

**Salida esperada (después de la primera ejecución):**
```
NAME                         COMPLETIONS   DURATION   AGE
cleanup-cronjob-1718234520   1/1           5s         30s
```

6. Espera una segunda ejecución (otros 2 minutos) y verifica la retención:

```bash
# Esperar la segunda ejecución
echo "Esperando segunda ejecución del CronJob (hasta 2 minutos)..."
sleep 120

# Verificar Jobs acumulados
kubectl get jobs --selector=app=cleanup --sort-by=.metadata.creationTimestamp
```

**Salida esperada (después de 2 ejecuciones):**
```
NAME                         COMPLETIONS   DURATION   AGE
cleanup-cronjob-1718234520   1/1           5s         2m30s
cleanup-cronjob-1718234640   1/1           5s         30s
```

7. Revisa los logs de la última ejecución:

```bash
# Obtener el nombre del último Job creado por el CronJob
LAST_JOB=$(kubectl get jobs --selector=app=cleanup --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
echo "Último Job: $LAST_JOB"

# Ver logs
kubectl logs job/$LAST_JOB
```

**Salida esperada:**
```
=== CLEANUP TASK STARTED ===
Execution time: 2024-XX-XXTXX:XX:XXZ
Scanning for temporary files...
Found 15 temporary files older than 24h
Removing /tmp/cache-*.dat ... done
Removing /tmp/session-*.tmp ... done
Removing /tmp/upload-*.part ... done
Freed 256MB of disk space
=== CLEANUP TASK COMPLETED ===
```

**Verificación:**

```bash
# Verificar configuración del CronJob
kubectl get cronjob cleanup-cronjob -o jsonpath='{.spec.concurrencyPolicy}'
echo ""
kubectl get cronjob cleanup-cronjob -o jsonpath='{.spec.successfulJobsHistoryLimit}'
echo ""
kubectl get cronjob cleanup-cronjob -o jsonpath='{.spec.failedJobsHistoryLimit}'
echo ""
```

**Salida esperada:**
```
Forbid
3
1
```

---

### Paso 4: Modificar el Schedule del CronJob para Producción

**Objetivo:** Cambiar la expresión cron del CronJob de cada 2 minutos (prueba) a las 2:00 AM diariamente (producción).

**Instrucciones:**

1. Aplica el patch para cambiar el schedule:

```bash
kubectl patch cronjob cleanup-cronjob -p '{"spec":{"schedule":"0 2 * * *"}}'
```

2. Verifica el cambio:

```bash
kubectl get cronjob cleanup-cronjob
```

**Salida esperada:**
```
NAME              SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cleanup-cronjob   0 2 * * *   False     0        XXs             5m
```

3. Documenta la diferencia entre ambas expresiones:

```bash
echo "Schedule de laboratorio: */2 * * * * (cada 2 minutos - solo para pruebas)"
echo "Schedule de producción:  0 2 * * *   (diariamente a las 02:00 UTC)"
```

4. Revierte al schedule de prueba para continuar observando si lo deseas:

```bash
kubectl patch cronjob cleanup-cronjob -p '{"spec":{"schedule":"*/2 * * * *"}}'
```

---

### Paso 5: Observar Comportamiento de Fallo con backoffLimit

**Objetivo:** Crear un Job con una imagen inválida para observar el comportamiento de reintentos y el estado `CrashLoopBackOff`/`ImagePullBackOff`.

**Instrucciones:**

1. Crea el manifiesto del Job con imagen inválida:

```bash
cat <<'EOF' > ~/ckad-labs/lab10/failing-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: failing-job
  namespace: ckad-batch
  labels:
    app: failing-job
    type: batch
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 3
  activeDeadlineSeconds: 90
  template:
    metadata:
      labels:
        app: failing-job
    spec:
      restartPolicy: Never
      containers:
        - name: broken
          image: alpine:99.99.99-nonexistent
          command:
            - /bin/sh
            - -c
            - echo "This will never run"
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab10/failing-job.yaml
```

3. Observa los reintentos del Job:

```bash
# Espera unos 30 segundos para que se acumulen los reintentos
sleep 30

# Ver los Pods creados (habrá múltiples intentos)
kubectl get pods --selector=job-name=failing-job
```

**Salida esperada (después de varios reintentos):**
```
NAME                READY   STATUS             RESTARTS   AGE
failing-job-xxxxx   0/1     ErrImagePull       0          30s
failing-job-yyyyy   0/1     ImagePullBackOff   0          25s
failing-job-zzzzz   0/1     ImagePullBackOff   0          15s
```

4. Espera a que el Job alcance el `backoffLimit` y sea marcado como fallido:

```bash
# Esperar a que el Job falle completamente (puede tomar 1-2 minutos)
sleep 60

kubectl get job failing-job
```

**Salida esperada:**
```
NAME          COMPLETIONS   DURATION   AGE
failing-job   0/1           90s        90s
```

5. Inspecciona la condición de fallo del Job:

```bash
kubectl describe job failing-job | grep -A 3 "Conditions:"
```

**Salida esperada:**
```
Conditions:
  Type    Status  Reason
  ----    ------  ------
  Failed  True    BackoffLimitExceeded
```

6. Verifica el número de Pods fallidos:

```bash
kubectl get pods --selector=job-name=failing-job --no-headers | wc -l
```

**Salida esperada:**
```
4
```

> **Explicación:** Con `backoffLimit: 3`, Kubernetes permite 1 intento inicial + 3 reintentos = 4 Pods totales antes de declarar el Job como fallido.

---

### Paso 6: Crear un Job con restartPolicy: OnFailure

**Objetivo:** Demostrar la diferencia entre `restartPolicy: Never` (crea nuevos Pods) y `restartPolicy: OnFailure` (reinicia el contenedor en el mismo Pod).

**Instrucciones:**

1. Crea un Job que falla intencionalmente pero usa `restartPolicy: OnFailure`:

```bash
cat <<'EOF' > ~/ckad-labs/lab10/retry-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: retry-job
  namespace: ckad-batch
  labels:
    app: retry-job
    type: batch
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 4
  template:
    metadata:
      labels:
        app: retry-job
    spec:
      restartPolicy: OnFailure
      containers:
        - name: flaky-task
          image: busybox:1.36.1
          command:
            - /bin/sh
            - -c
            - |
              ATTEMPT_FILE="/tmp/attempt-count"
              if [ ! -f "$ATTEMPT_FILE" ]; then
                echo "1" > "$ATTEMPT_FILE"
              fi
              ATTEMPT=$(cat "$ATTEMPT_FILE")
              echo "Attempt number: $ATTEMPT"
              if [ "$ATTEMPT" -lt 3 ]; then
                echo "Simulating failure on attempt $ATTEMPT"
                echo $((ATTEMPT + 1)) > "$ATTEMPT_FILE"
                exit 1
              fi
              echo "Success on attempt $ATTEMPT!"
              exit 0
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab10/retry-job.yaml
```

3. Observa el comportamiento — con `OnFailure`, el Pod se reinicia en lugar de crear uno nuevo:

```bash
sleep 20
kubectl get pods --selector=job-name=retry-job
```

**Salida esperada:**
```
NAME              READY   STATUS      RESTARTS      AGE
retry-job-xxxxx   0/1     Completed   2 (15s ago)   20s
```

> **Nota clave:** Con `restartPolicy: OnFailure`, solo se crea **un Pod** que se reinicia internamente. Con `restartPolicy: Never`, se crean **múltiples Pods** (uno por intento). En este caso, dado que `/tmp` no persiste entre reinicios del contenedor, el Job podría no converger. Esto demuestra que `OnFailure` reinicia el contenedor dentro del mismo Pod.

4. Verifica que solo existe un Pod (no múltiples):

```bash
kubectl get pods --selector=job-name=retry-job --no-headers | wc -l
```

**Salida esperada:**
```
1
```

---

## Validación y Pruebas

Ejecuta los siguientes comandos para validar que todos los componentes del laboratorio funcionan correctamente:

```bash
echo "========================================="
echo "  VALIDACIÓN COMPLETA - Lab 03-00-03"
echo "========================================="
echo ""

# 1. Verificar namespace
echo "1. Namespace ckad-batch:"
kubectl get namespace ckad-batch -o jsonpath='{.status.phase}'
echo ""
echo ""

# 2. Verificar Job simple completado
echo "2. data-processor-job:"
kubectl get job data-processor-job -o jsonpath='   Status: {.status.conditions[0].type}, Completions: {.status.succeeded}/1'
echo ""
echo ""

# 3. Verificar Job paralelo completado
echo "3. parallel-worker-job:"
kubectl get job parallel-worker-job -o jsonpath='   Status: {.status.conditions[0].type}, Completions: {.status.succeeded}/6'
echo ""
echo ""

# 4. Verificar CronJob existe y tiene ejecuciones
echo "4. cleanup-cronjob:"
kubectl get cronjob cleanup-cronjob -o jsonpath='   Schedule: {.spec.schedule}, ConcurrencyPolicy: {.spec.concurrencyPolicy}'
echo ""
CRON_JOBS=$(kubectl get jobs --selector=app=cleanup --no-headers 2>/dev/null | wc -l)
echo "   Jobs ejecutados por CronJob: $CRON_JOBS"
echo ""

# 5. Verificar Job fallido
echo "5. failing-job:"
kubectl get job failing-job -o jsonpath='   Status: {.status.conditions[0].type}, Reason: {.status.conditions[0].reason}'
echo ""
echo ""

# 6. Verificar archivos de manifiesto
echo "6. Manifiestos en ~/ckad-labs/lab10/:"
ls -1 ~/ckad-labs/lab10/*.yaml
echo ""

echo "========================================="
echo "  VALIDACIÓN COMPLETADA"
echo "========================================="
```

**Salida esperada:**
```
=========================================
  VALIDACIÓN COMPLETA - Lab 03-00-03
=========================================

1. Namespace ckad-batch:
Active

2. data-processor-job:
   Status: Complete, Completions: 1/1

3. parallel-worker-job:
   Status: Complete, Completions: 6/6

4. cleanup-cronjob:
   Schedule: */2 * * * *, ConcurrencyPolicy: Forbid
   Jobs ejecutados por CronJob: 2

5. failing-job:
   Status: Failed, Reason: BackoffLimitExceeded

6. Manifiestos en ~/ckad-labs/lab10/:
/home/user/ckad-labs/lab10/cleanup-cronjob.yaml
/home/user/ckad-labs/lab10/data-processor-job.yaml
/home/user/ckad-labs/lab10/failing-job.yaml
/home/user/ckad-labs/lab10/parallel-worker-job.yaml
/home/user/ckad-labs/lab10/retry-job.yaml

=========================================
  VALIDACIÓN COMPLETADA
=========================================
```

---

## Solución de Problemas

### Problema 1: El Job paralelo no alcanza las 6 completions y queda en estado activo

**Síntomas:**
```
$ kubectl get job parallel-worker-job
NAME                  COMPLETIONS   DURATION   AGE
parallel-worker-job   4/6           120s       2m
```
Los Pods quedan en estado `Pending` y no se programan.

**Causa:** El clúster no tiene recursos suficientes (CPU/memoria) para crear 2 Pods simultáneamente. Con un clúster kind de un solo nodo y recursos limitados, los Pods pueden quedar pendientes esperando recursos disponibles.

**Solución:**

```bash
# Verificar si hay Pods pendientes
kubectl get pods --selector=job-name=parallel-worker-job --field-selector=status.phase=Pending

# Verificar eventos del Pod pendiente
kubectl describe pod $(kubectl get pods --selector=job-name=parallel-worker-job --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}')

# Si es un problema de recursos, reducir el paralelismo
kubectl delete job parallel-worker-job
# Editar el manifiesto y cambiar parallelism: 2 a parallelism: 1
sed -i 's/parallelism: 2/parallelism: 1/' ~/ckad-labs/lab10/parallel-worker-job.yaml
kubectl apply -f ~/ckad-labs/lab10/parallel-worker-job.yaml
```

---

### Problema 2: El CronJob no crea Jobs según el schedule esperado

**Síntomas:**
```
$ kubectl get cronjob cleanup-cronjob
NAME              SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cleanup-cronjob   */2 * * * *   False     0        <none>          5m
```
Han pasado más de 2 minutos y `LAST SCHEDULE` sigue mostrando `<none>`.

**Causa:** El controlador de CronJobs tiene un margen de tolerancia. Si el CronJob se creó justo después de un minuto par (por ejemplo, a las 14:02:50), la próxima ejecución será a las 14:04:00. Además, si el reloj del nodo está desincronizado o el controlador tiene retraso, puede haber un desfase. Otra causa posible es que el campo `suspend` esté en `true`.

**Solución:**

```bash
# Verificar que no está suspendido
kubectl get cronjob cleanup-cronjob -o jsonpath='{.spec.suspend}'
echo ""

# Verificar la hora actual del clúster vs. la hora del sistema
kubectl run time-check --image=busybox:1.36.1 --rm -it --restart=Never -- date -u

# Si han pasado más de 100 segundos desde la última programación esperada,
# Kubernetes marca el CronJob como "missed". Verificar eventos:
kubectl describe cronjob cleanup-cronjob | grep -A 5 "Events"

# Forzar una ejecución manual para verificar que el template funciona:
kubectl create job cleanup-manual-test --from=cronjob/cleanup-cronjob

# Verificar que el Job manual se ejecuta correctamente
kubectl get job cleanup-manual-test
kubectl logs job/cleanup-manual-test
```

---

## Limpieza

```bash
# Eliminar todos los recursos del laboratorio
kubectl delete cronjob cleanup-cronjob -n ckad-batch
kubectl delete job data-processor-job parallel-worker-job failing-job retry-job -n ckad-batch 2>/dev/null

# Eliminar Jobs creados manualmente (si existen)
kubectl delete job cleanup-manual-test -n ckad-batch 2>/dev/null

# Eliminar Pods huérfanos (si quedaron)
kubectl delete pods --selector=app=failing-job -n ckad-batch 2>/dev/null

# Opcional: Eliminar el namespace completo
# kubectl delete namespace ckad-batch

# Restaurar el contexto al namespace principal del curso
kubectl config set-context --current --namespace=ckad-dev

# Verificar
kubectl config view --minify | grep namespace
```

**Salida esperada:**
```
cronjob.batch "cleanup-cronjob" deleted
job.batch "data-processor-job" deleted
job.batch "parallel-worker-job" deleted
job.batch "failing-job" deleted
job.batch "retry-job" deleted
namespace: ckad-dev
```

---

## Resumen

En este laboratorio has implementado y verificado los siguientes conceptos clave de cargas de trabajo batch en Kubernetes:

| Concepto | Recurso | Configuración Clave |
|----------|---------|---------------------|
| Tarea de ejecución única | Job | `completions: 1`, `parallelism: 1` |
| Procesamiento paralelo | Job | `completions: 6`, `parallelism: 2` |
| Tarea programada | CronJob | `schedule`, `concurrencyPolicy: Forbid` |
| Control de reintentos | Job | `backoffLimit: 3`, `restartPolicy: Never` |
| Retención de historial | CronJob | `successfulJobsHistoryLimit: 3` |
| Tiempo límite | Job | `activeDeadlineSeconds: 120` |

**Decisiones clave aprendidas:**

- **`restartPolicy: Never`** → Kubernetes crea un nuevo Pod por cada reintento (útil para debugging, ya que los logs de cada intento se preservan)
- **`restartPolicy: OnFailure`** → Kubernetes reinicia el contenedor dentro del mismo Pod (más eficiente en recursos)
- **`concurrencyPolicy: Forbid`** → Evita que se ejecuten múltiples instancias simultáneas del CronJob
- **`backoffLimit`** → Define el número máximo de reintentos antes de declarar el Job como fallido

### Recursos Adicionales

- [Documentación oficial: Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [Documentación oficial: CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- [Referencia de expresiones cron](https://crontab.guru/)
- [Patrones de procesamiento paralelo con Jobs](https://kubernetes.io/docs/tasks/job/parallel-processing-expansion/)

---

# Estrategia blue/green

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 40 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Crear |
| **Recurso principal** | Kubernetes Deployment + Service (ClusterIP) |

## Descripción General

En este laboratorio implementarás una estrategia de despliegue blue/green utilizando exclusivamente recursos nativos de Kubernetes. Crearás dos Deployments independientes que representan versiones distintas de una aplicación web (blue = v1, green = v2) y controlarás el enrutamiento de tráfico mediante la manipulación del selector de un único Service de tipo ClusterIP. Verificarás que el cambio de versión ocurre sin downtime y practicarás el rollback inmediato redirigiendo el selector de regreso a la versión original.

## Objetivos de Aprendizaje

- [ ] Comprender el modelo conceptual de la estrategia blue/green y su implementación con recursos nativos de Kubernetes
- [ ] Crear dos Deployments independientes (blue y green) con etiquetas diferenciadas que representen versiones distintas de la misma aplicación
- [ ] Implementar el cambio de tráfico entre versiones manipulando el selector de un único Service
- [ ] Verificar que el cutover entre versiones ocurre sin downtime observable desde el punto de vista del cliente
- [ ] Ejecutar rollback inmediato redirigiendo el selector del Service a la versión anterior

## Prerrequisitos

### Conocimientos Requeridos

| Tema | Nivel |
|------|-------|
| Manifiestos YAML para Kubernetes | Intermedio |
| Deployments y ReplicaSets | Intermedio |
| Services (ClusterIP) y selectors | Intermedio |
| Labels y selectors en Kubernetes | Básico |
| kubectl apply, patch, exec | Básico |

### Acceso Requerido

- Clúster minikube operativo (v1.32.0+)
- kubectl configurado (v1.29.3+)
- Acceso a internet para descargar imágenes nginx desde Docker Hub

## Entorno de Laboratorio

### Software Necesario

| Componente | Versión | Propósito |
|------------|---------|-----------|
| minikube | 1.32.0+ | Clúster Kubernetes local |
| kubectl | 1.29.3+ | CLI de administración |
| curl | 8.5.0+ | Pruebas de conectividad |

### Imágenes de Contenedor

| Imagen | Propósito |
|--------|-----------|
| `nginx:1.24.0` | Deployment blue (versión v1) |
| `nginx:1.25.3` | Deployment green (versión v2) |
| `busybox:1.36.1` | Pod temporal para pruebas de conectividad |

### Configuración Inicial

```bash
# Verificar que minikube está corriendo
minikube status

# Verificar conectividad con el clúster
kubectl cluster-info

# Crear el directorio de trabajo para este laboratorio
mkdir -p ~/ckad-labs/lab06
cd ~/ckad-labs/lab06
```

## Paso a Paso

### Paso 1: Crear el Namespace del Laboratorio

**Objetivo:** Crear el namespace `deployments-lab` que será reutilizado en las prácticas 12 y 13.

**Instrucciones:**

1. Crea el namespace `deployments-lab`:

```bash
kubectl create namespace deployments-lab
```

2. Configura el contexto actual para usar este namespace por defecto:

```bash
kubectl config set-context --current --namespace=deployments-lab
```

3. Verifica la configuración:

```bash
kubectl config view --minify | grep namespace
```

**Salida esperada:**

```
namespace: deployments-lab
```

**Verificación:**

```bash
kubectl get namespace deployments-lab -o jsonpath='{.status.phase}'
```

Debe mostrar: `Active`

---

### Paso 2: Crear el Deployment Blue (v1)

**Objetivo:** Crear el Deployment `webapp-blue` con 3 réplicas usando nginx:1.24.0 que sirva una página identificándose como versión v1.

**Instrucciones:**

1. Crea el archivo de manifiesto para el Deployment blue:

```bash
cat <<'EOF' > webapp-blue-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-blue
  namespace: deployments-lab
  labels:
    app: webapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: blue
  template:
    metadata:
      labels:
        app: webapp
        version: blue
    spec:
      containers:
        - name: nginx
          image: nginx:1.24.0
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
          lifecycle:
            postStart:
              exec:
                command:
                  - /bin/sh
                  - -c
                  - |
                    echo '<!DOCTYPE html><html><body><h1>Version: v1 (blue)</h1><p>Deployment: webapp-blue</p><p>Image: nginx:1.24.0</p></body></html>' > /usr/share/nginx/html/index.html
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f webapp-blue-deployment.yaml
```

3. Espera a que todas las réplicas estén listas:

```bash
kubectl rollout status deployment/webapp-blue --timeout=60s
```

**Salida esperada:**

```
deployment "webapp-blue" successfully rolled out
```

**Verificación:**

```bash
kubectl get deployment webapp-blue -o wide
```

Debe mostrar 3/3 réplicas disponibles con imagen `nginx:1.24.0`:

```
NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES         SELECTOR
webapp-blue   3/3     3            3           30s   nginx        nginx:1.24.0   app=webapp,version=blue
```

---

### Paso 3: Crear el Deployment Green (v2)

**Objetivo:** Crear el Deployment `webapp-green` con 3 réplicas usando nginx:1.25.3 que sirva una página identificándose como versión v2.

**Instrucciones:**

1. Crea el archivo de manifiesto para el Deployment green:

```bash
cat <<'EOF' > webapp-green-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-green
  namespace: deployments-lab
  labels:
    app: webapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: green
  template:
    metadata:
      labels:
        app: webapp
        version: green
    spec:
      containers:
        - name: nginx
          image: nginx:1.25.3
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
          lifecycle:
            postStart:
              exec:
                command:
                  - /bin/sh
                  - -c
                  - |
                    echo '<!DOCTYPE html><html><body><h1>Version: v2 (green)</h1><p>Deployment: webapp-green</p><p>Image: nginx:1.25.3</p></body></html>' > /usr/share/nginx/html/index.html
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f webapp-green-deployment.yaml
```

3. Espera a que todas las réplicas estén listas:

```bash
kubectl rollout status deployment/webapp-green --timeout=60s
```

**Salida esperada:**

```
deployment "webapp-green" successfully rolled out
```

**Verificación:**

```bash
kubectl get deployment webapp-green -o wide
```

Debe mostrar 3/3 réplicas disponibles con imagen `nginx:1.25.3`:

```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES         SELECTOR
webapp-green   3/3     3            3           25s   nginx        nginx:1.25.3   app=webapp,version=green
```

4. Verifica que ambos Deployments están activos simultáneamente:

```bash
kubectl get deployments -l app=webapp
```

```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
webapp-blue    3/3     3            3           90s
webapp-green   3/3     3            3           25s
```

---

### Paso 4: Crear el Service Apuntando a Blue

**Objetivo:** Crear un Service de tipo ClusterIP llamado `webapp-service` cuyo selector apunte inicialmente a la versión blue (v1).

**Instrucciones:**

1. Crea el archivo de manifiesto del Service:

```bash
cat <<'EOF' > webapp-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: deployments-lab
  labels:
    app: webapp
spec:
  type: ClusterIP
  selector:
    app: webapp
    version: blue
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      name: http
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f webapp-service.yaml
```

3. Verifica el Service creado:

```bash
kubectl get service webapp-service
```

**Salida esperada:**

```
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
webapp-service   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    5s
```

**Verificación:**

Confirma que el selector del Service apunta a `version: blue`:

```bash
kubectl get service webapp-service -o jsonpath='{.spec.selector}' | jq .
```

```json
{
  "app": "webapp",
  "version": "blue"
}
```

Verifica que los endpoints corresponden a los pods blue:

```bash
kubectl get endpoints webapp-service
```

Debe mostrar 3 IPs (una por cada réplica del Deployment blue).

---

### Paso 5: Verificar el Tráfico hacia la Versión Blue

**Objetivo:** Confirmar que el Service enruta el tráfico exclusivamente a los pods de la versión blue (v1).

**Instrucciones:**

1. Lanza un pod temporal para realizar pruebas de conectividad:

```bash
kubectl run test-client --image=busybox:1.36.1 --restart=Never --rm -it -- /bin/sh -c \
  'for i in 1 2 3 4 5; do wget -qO- http://webapp-service.deployments-lab.svc.cluster.local 2>/dev/null; echo "---"; done'
```

**Salida esperada:**

Todas las respuestas deben mostrar la versión v1 (blue):

```
<!DOCTYPE html><html><body><h1>Version: v1 (blue)</h1><p>Deployment: webapp-blue</p><p>Image: nginx:1.24.0</p></body></html>
---
<!DOCTYPE html><html><body><h1>Version: v1 (blue)</h1><p>Deployment: webapp-blue</p><p>Image: nginx:1.24.0</p></body></html>
---
<!DOCTYPE html><html><body><h1>Version: v1 (blue)</h1><p>Deployment: webapp-blue</p><p>Image: nginx:1.24.0</p></body></html>
---
<!DOCTYPE html><html><body><h1>Version: v1 (blue)</h1><p>Deployment: webapp-blue</p><p>Image: nginx:1.24.0</p></body></html>
---
<!DOCTYPE html><html><body><h1>Version: v1 (blue)</h1><p>Deployment: webapp-blue</p><p>Image: nginx:1.24.0</p></body></html>
---
```

**Verificación:**

Ninguna respuesta debe contener "v2" o "green". El 100% del tráfico va a la versión blue.

---

### Paso 6: Ejecutar el Cutover a Green (v2)

**Objetivo:** Cambiar el tráfico de la versión blue a la versión green modificando el selector del Service. Este cambio debe ser instantáneo y sin downtime.

**Instrucciones:**

1. Modifica el selector del Service para apuntar a `version: green` usando `kubectl patch`:

```bash
kubectl patch service webapp-service -p '{"spec":{"selector":{"app":"webapp","version":"green"}}}'
```

**Salida esperada:**

```
service/webapp-service patched
```

2. Verifica que el selector se actualizó correctamente:

```bash
kubectl get service webapp-service -o jsonpath='{.spec.selector}' | jq .
```

```json
{
  "app": "webapp",
  "version": "green"
}
```

3. Confirma que los endpoints ahora apuntan a los pods green:

```bash
kubectl get endpoints webapp-service
```

Debe mostrar 3 IPs diferentes a las anteriores (correspondientes a los pods del Deployment green).

**Verificación:**

Ejecuta nuevamente la prueba de conectividad:

```bash
kubectl run test-client2 --image=busybox:1.36.1 --restart=Never --rm -it -- /bin/sh -c \
  'for i in 1 2 3 4 5; do wget -qO- http://webapp-service.deployments-lab.svc.cluster.local 2>/dev/null; echo "---"; done'
```

Todas las respuestas deben mostrar ahora la versión v2 (green):

```
<!DOCTYPE html><html><body><h1>Version: v2 (green)</h1><p>Deployment: webapp-green</p><p>Image: nginx:1.25.3</p></body></html>
---
<!DOCTYPE html><html><body><h1>Version: v2 (green)</h1><p>Deployment: webapp-green</p><p>Image: nginx:1.25.3</p></body></html>
---
...
```

---

### Paso 7: Ejecutar Rollback a Blue (v1)

**Objetivo:** Simular un rollback inmediato redirigiendo el selector del Service de regreso a la versión blue, demostrando la velocidad de recuperación de la estrategia blue/green.

**Instrucciones:**

1. Restaura el selector del Service a `version: blue`:

```bash
kubectl patch service webapp-service -p '{"spec":{"selector":{"app":"webapp","version":"blue"}}}'
```

**Salida esperada:**

```
service/webapp-service patched
```

2. Verifica el selector actualizado:

```bash
kubectl get service webapp-service -o jsonpath='{.spec.selector.version}'
```

```
blue
```

3. Confirma el rollback con una prueba de conectividad:

```bash
kubectl run test-client3 --image=busybox:1.36.1 --restart=Never --rm -it -- /bin/sh -c \
  'for i in 1 2 3 4 5; do wget -qO- http://webapp-service.deployments-lab.svc.cluster.local 2>/dev/null; echo "---"; done'
```

**Salida esperada:**

Todas las respuestas deben mostrar de nuevo la versión v1 (blue):

```
<!DOCTYPE html><html><body><h1>Version: v1 (blue)</h1><p>Deployment: webapp-blue</p><p>Image: nginx:1.24.0</p></body></html>
---
...
```

**Verificación:**

```bash
kubectl get endpoints webapp-service -o jsonpath='{.subsets[0].addresses[*].targetRef.name}'
```

Los nombres de los pods deben contener `webapp-blue`.

---

### Paso 8: Verificar el Estado Final del Laboratorio

**Objetivo:** Confirmar que el estado final es el esperado: ambos Deployments activos con 3 réplicas cada uno y el Service apuntando a blue.

**Instrucciones:**

1. Verifica el estado de los Deployments:

```bash
kubectl get deployments -l app=webapp -o custom-columns=\
NAME:.metadata.name,\
READY:.status.readyReplicas,\
IMAGE:.spec.template.spec.containers[0].image,\
VERSION:.spec.selector.matchLabels.version
```

**Salida esperada:**

```
NAME           READY   IMAGE          VERSION
webapp-blue    3       nginx:1.24.0   blue
webapp-green   3       nginx:1.25.3   green
```

2. Verifica el Service:

```bash
kubectl describe service webapp-service | grep -A2 "Selector:"
```

```
Selector:          app=webapp,version=blue
```

3. Cuenta el total de pods en el namespace:

```bash
kubectl get pods -l app=webapp --no-headers | wc -l
```

Debe mostrar: `6` (3 blue + 3 green)

## Validación y Pruebas

Ejecuta el siguiente script de validación completa para confirmar que todos los componentes están correctamente configurados:

```bash
#!/bin/bash
echo "=== Validación del Lab 03-00-04 ==="
echo ""

# Test 1: Namespace existe
echo -n "1. Namespace deployments-lab existe: "
kubectl get namespace deployments-lab &>/dev/null && echo "✅ PASS" || echo "❌ FAIL"

# Test 2: Deployment blue tiene 3 réplicas ready
echo -n "2. webapp-blue tiene 3/3 réplicas: "
BLUE_READY=$(kubectl get deployment webapp-blue -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "$BLUE_READY" = "3" ] && echo "✅ PASS" || echo "❌ FAIL (got: $BLUE_READY)"

# Test 3: Deployment green tiene 3 réplicas ready
echo -n "3. webapp-green tiene 3/3 réplicas: "
GREEN_READY=$(kubectl get deployment webapp-green -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "$GREEN_READY" = "3" ] && echo "✅ PASS" || echo "❌ FAIL (got: $GREEN_READY)"

# Test 4: Imagen correcta en blue
echo -n "4. webapp-blue usa nginx:1.24.0: "
BLUE_IMG=$(kubectl get deployment webapp-blue -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[ "$BLUE_IMG" = "nginx:1.24.0" ] && echo "✅ PASS" || echo "❌ FAIL (got: $BLUE_IMG)"

# Test 5: Imagen correcta en green
echo -n "5. webapp-green usa nginx:1.25.3: "
GREEN_IMG=$(kubectl get deployment webapp-green -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[ "$GREEN_IMG" = "nginx:1.25.3" ] && echo "✅ PASS" || echo "❌ FAIL (got: $GREEN_IMG)"

# Test 6: Service existe y apunta a blue
echo -n "6. webapp-service selector apunta a blue: "
SVC_VER=$(kubectl get service webapp-service -o jsonpath='{.spec.selector.version}' 2>/dev/null)
[ "$SVC_VER" = "blue" ] && echo "✅ PASS" || echo "❌ FAIL (got: $SVC_VER)"

# Test 7: Service tiene endpoints activos
echo -n "7. webapp-service tiene 3 endpoints: "
EP_COUNT=$(kubectl get endpoints webapp-service -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | jq '. | length' 2>/dev/null)
[ "$EP_COUNT" = "3" ] && echo "✅ PASS" || echo "❌ FAIL (got: $EP_COUNT)"

# Test 8: Labels correctas en pods blue
echo -n "8. Pods blue tienen labels app=webapp,version=blue: "
BLUE_PODS=$(kubectl get pods -l app=webapp,version=blue --no-headers 2>/dev/null | wc -l)
[ "$BLUE_PODS" = "3" ] && echo "✅ PASS" || echo "❌ FAIL (got: $BLUE_PODS pods)"

# Test 9: Labels correctas en pods green
echo -n "9. Pods green tienen labels app=webapp,version=green: "
GREEN_PODS=$(kubectl get pods -l app=webapp,version=green --no-headers 2>/dev/null | wc -l)
[ "$GREEN_PODS" = "3" ] && echo "✅ PASS" || echo "❌ FAIL (got: $GREEN_PODS pods)"

echo ""
echo "=== Validación completada ==="
```

Guarda y ejecuta:

```bash
chmod +x ~/ckad-labs/lab06/validate.sh
bash ~/ckad-labs/lab06/validate.sh
```

Todos los tests deben mostrar `✅ PASS`.

## Solución de Problemas

### Problema 1: El pod test-client queda en estado Pending o Error

**Síntomas:**

```
Error from server: error when creating pod: ... pod "test-client" already exists
```

O el pod queda en estado `Pending` sin ejecutarse.

**Causa:** Un pod temporal anterior con el mismo nombre no se eliminó correctamente (por ejemplo, si se interrumpió la ejecución con Ctrl+C antes de que terminara).

**Solución:**

```bash
# Eliminar el pod residual
kubectl delete pod test-client --force --grace-period=0 2>/dev/null
kubectl delete pod test-client2 --force --grace-period=0 2>/dev/null
kubectl delete pod test-client3 --force --grace-period=0 2>/dev/null

# Reintentar la prueba con un nombre diferente
kubectl run test-fix --image=busybox:1.36.1 --restart=Never --rm -it -- /bin/sh -c \
  'wget -qO- http://webapp-service.deployments-lab.svc.cluster.local 2>/dev/null'
```

---

### Problema 2: El Service no muestra endpoints después del patch

**Síntomas:**

```bash
kubectl get endpoints webapp-service
# Muestra: webapp-service   <none>   10s
```

El Service no tiene endpoints asociados tras cambiar el selector.

**Causa:** Error tipográfico en el valor del selector durante el `kubectl patch`. Por ejemplo, se escribió `"version":"greeen"` en lugar de `"version":"green"`, o se omitió el label `app: webapp` en el patch, dejando un selector incompleto que no coincide con ningún pod.

**Solución:**

```bash
# Verificar el selector actual del Service
kubectl get service webapp-service -o jsonpath='{.spec.selector}'

# Verificar qué labels tienen los pods disponibles
kubectl get pods --show-labels -l app=webapp

# Corregir el selector con el patch correcto (incluir AMBOS labels)
kubectl patch service webapp-service -p '{"spec":{"selector":{"app":"webapp","version":"green"}}}'

# Confirmar que los endpoints se resolvieron
kubectl get endpoints webapp-service
```

Si el problema persiste, elimina y recrea el Service:

```bash
kubectl delete service webapp-service
kubectl apply -f webapp-service.yaml
# Luego aplica el patch deseado
```

## Limpieza

> **⚠️ IMPORTANTE:** NO ejecutes la limpieza si vas a continuar con las Prácticas 12 y 13. El namespace `deployments-lab` y los recursos creados en este laboratorio serán reutilizados.

Si necesitas limpiar el entorno al finalizar todas las prácticas del batch:

```bash
# Eliminar todos los recursos del namespace
kubectl delete namespace deployments-lab

# Restaurar el namespace por defecto en el contexto
kubectl config set-context --current --namespace=ckad-dev

# Eliminar archivos de manifiesto locales
rm -rf ~/ckad-labs/lab06/
```

## Resumen

En este laboratorio has implementado una estrategia de despliegue blue/green completa utilizando únicamente recursos nativos de Kubernetes:

| Concepto | Implementación |
|----------|---------------|
| **Dos versiones coexistentes** | Deployments `webapp-blue` (nginx:1.24.0) y `webapp-green` (nginx:1.25.3) con 3 réplicas cada uno |
| **Enrutamiento de tráfico** | Service `webapp-service` con selector que discrimina por label `version` |
| **Cutover instantáneo** | `kubectl patch` del selector de `version: blue` a `version: green` |
| **Rollback inmediato** | `kubectl patch` del selector de regreso a `version: blue` |
| **Zero downtime** | Ambos Deployments permanecen activos; solo cambia el enrutamiento del Service |

### Puntos Clave

- La estrategia blue/green en Kubernetes se implementa manteniendo **dos Deployments activos simultáneamente** y controlando el tráfico mediante el selector de un Service.
- El cambio de versión es **instantáneo** porque no implica crear ni destruir pods — solo redirige los endpoints del Service.
- El rollback es igualmente instantáneo: basta con revertir el selector a la versión anterior.
- El costo de esta estrategia es el **doble de recursos** (ambas versiones corren en paralelo), lo cual es el trade-off principal frente a rolling updates.
- Las labels son el mecanismo fundamental que habilita esta estrategia; un diseño cuidadoso de labels es esencial.

### Estado Final para la Práctica 12

El namespace `deployments-lab` queda con:
- `webapp-blue`: 3 réplicas, nginx:1.24.0, labels `app=webapp, version=blue`
- `webapp-green`: 3 réplicas, nginx:1.25.3, labels `app=webapp, version=green`
- `webapp-service`: ClusterIP, selector `app=webapp, version=blue`

### Recursos Adicionales

- [Documentación oficial: Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Documentación oficial: Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Documentación oficial: Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [Blue/Green Deployments — CNCF Blog](https://www.cncf.io/blog/)

---

# Estrategia Canary

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 40 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Crear |
| **Prerrequisito directo** | Lab 03-00-04 (Práctica 11 — Blue/Green) |

## Descripción General

En este laboratorio implementarás una estrategia de despliegue **canary** en Kubernetes, controlando el porcentaje de tráfico que recibe la nueva versión mediante la proporción de réplicas entre dos Deployments que comparten un mismo Service. A diferencia de blue/green (donde el cambio es instantáneo al 100%), canary permite una exposición gradual: primero un pequeño porcentaje de usuarios recibe la nueva versión y, si todo funciona correctamente, se incrementa progresivamente hasta completar la promoción. Trabajarás sobre el namespace `deployments-lab` heredado de la Práctica 11, donde `webapp-blue` (nginx:1.24.0) está activo con 3 réplicas.

## Objetivos de Aprendizaje

Al finalizar este laboratorio serás capaz de:

- [ ] Comprender el modelo conceptual de la estrategia canary y sus diferencias respecto a blue/green
- [ ] Implementar un despliegue canary controlando el porcentaje de tráfico mediante la proporción de réplicas
- [ ] Crear un Deployment canary que coexista con el Deployment estable compartiendo un Service común
- [ ] Ajustar progresivamente el peso del tráfico canary escalando réplicas de ambos Deployments
- [ ] Promover el canary a producción o ejecutar rollback completo según criterios de validación

## Prerrequisitos

### Conocimientos Requeridos

| Concepto | Nivel |
|----------|-------|
| Kubernetes Deployments y ReplicaSets | Intermedio |
| Services y Selectors | Intermedio |
| kubectl scale | Básico |
| Labels y selectors multi-criterio | Intermedio |
| Bash scripting básico (loops) | Básico |

### Acceso Requerido

- Clúster Kubernetes funcional (kind o minikube)
- `kubectl` configurado con acceso al clúster
- Namespace `deployments-lab` con los recursos de la Práctica 11 activos
- `webapp-blue` con 3 réplicas ejecutando nginx:1.24.0
- `webapp-service` apuntando a `version=blue`

## Entorno del Laboratorio

### Verificación del Estado Heredado

```bash
# Verificar que el namespace y recursos de la Práctica 11 existen
kubectl get namespace deployments-lab
kubectl get deployments -n deployments-lab
kubectl get svc webapp-service -n deployments-lab
kubectl get pods -n deployments-lab -l app=webapp
```

**Salida esperada (aproximada):**

```
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
webapp-blue       3/3     3            3           15m

NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
webapp-service   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    15m
```

### Directorio de Trabajo

```bash
mkdir -p ~/ckad-labs/lab05/canary
cd ~/ckad-labs/lab05/canary
```

## Paso a Paso

### Paso 1: Analizar el Estado Actual del Service

**Objetivo:** Comprender el selector actual del Service y por qué debe modificarse para soportar canary.

**Instrucciones:**

1. Inspecciona el selector actual del Service:

```bash
kubectl get svc webapp-service -n deployments-lab -o yaml | grep -A 5 selector
```

2. Verifica las etiquetas actuales de los pods de `webapp-blue`:

```bash
kubectl get pods -n deployments-lab -l app=webapp --show-labels
```

3. Observa que el Service actualmente usa el selector `app: webapp, version: blue`, lo cual impide que pods con otra etiqueta `version` reciban tráfico.

**Salida esperada:**

```yaml
  selector:
    app: webapp
    version: blue
```

**Verificación:**

```bash
# Confirmar que solo pods con version=blue están seleccionados
kubectl get endpoints webapp-service -n deployments-lab
```

Los endpoints deben mostrar exactamente 3 IPs (una por cada réplica de webapp-blue).

---

### Paso 2: Modificar el Service para Selector Ampliado

**Objetivo:** Cambiar el selector del Service para que use únicamente `app: webapp`, permitiendo que múltiples Deployments con diferentes versiones reciban tráfico simultáneamente.

**Instrucciones:**

1. Crea el manifiesto del Service actualizado:

```bash
cat <<'EOF' > webapp-service-canary.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: deployments-lab
spec:
  selector:
    app: webapp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF
```

2. Aplica el cambio al Service existente:

```bash
kubectl apply -f webapp-service-canary.yaml
```

3. Verifica que el selector se actualizó correctamente:

```bash
kubectl get svc webapp-service -n deployments-lab -o jsonpath='{.spec.selector}' | jq .
```

**Salida esperada:**

```json
{
  "app": "webapp"
}
```

**Verificación:**

```bash
# Los endpoints deben seguir mostrando los 3 pods de webapp-blue
# ya que también tienen la etiqueta app=webapp
kubectl get endpoints webapp-service -n deployments-lab
```

> **Nota conceptual:** Al eliminar `version: blue` del selector, cualquier pod con la etiqueta `app: webapp` será incluido en los endpoints del Service. Esta es la clave de la estrategia canary basada en réplicas.

---

### Paso 3: Crear el Deployment Canary

**Objetivo:** Desplegar `webapp-canary` con 1 réplica usando nginx:1.25.3, compartiendo la etiqueta `app: webapp` con el Deployment estable.

**Instrucciones:**

1. Crea el manifiesto del Deployment canary:

```bash
cat <<'EOF' > webapp-canary-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-canary
  namespace: deployments-lab
  labels:
    app: webapp
    track: canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
      track: canary
  template:
    metadata:
      labels:
        app: webapp
        track: canary
        version: canary
    spec:
      containers:
        - name: nginx
          image: nginx:1.25.3
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
EOF
```

2. Aplica el Deployment canary:

```bash
kubectl apply -f webapp-canary-deployment.yaml
```

3. Espera a que el pod canary esté listo:

```bash
kubectl rollout status deployment/webapp-canary -n deployments-lab --timeout=60s
```

**Salida esperada:**

```
deployment "webapp-canary" successfully rolled out
```

4. Verifica el estado de todos los pods:

```bash
kubectl get pods -n deployments-lab -l app=webapp -o wide --show-labels
```

**Salida esperada (4 pods totales):**

```
NAME                             READY   STATUS    RESTARTS   AGE   LABELS
webapp-blue-xxxxx-aaaaa          1/1     Running   0          20m   app=webapp,version=blue,...
webapp-blue-xxxxx-bbbbb          1/1     Running   0          20m   app=webapp,version=blue,...
webapp-blue-xxxxx-ccccc          1/1     Running   0          20m   app=webapp,version=blue,...
webapp-canary-yyyyy-ddddd        1/1     Running   0          30s   app=webapp,track=canary,version=canary,...
```

**Verificación:**

```bash
# Los endpoints ahora deben incluir 4 IPs (3 blue + 1 canary)
kubectl get endpoints webapp-service -n deployments-lab
```

---

### Paso 4: Verificar la Distribución de Tráfico Inicial (~25% Canary)

**Objetivo:** Confirmar que aproximadamente el 25% del tráfico (1 de 4 pods) llega al canary mediante pruebas repetidas.

**Instrucciones:**

1. Personaliza la página de respuesta de cada versión para distinguirlas. Primero, configura los pods estables:

```bash
# Configurar respuesta en pods webapp-blue
for pod in $(kubectl get pods -n deployments-lab -l app=webapp,version=blue -o name); do
  kubectl exec -n deployments-lab $pod -- bash -c 'echo "STABLE v1.24.0" > /usr/share/nginx/html/index.html'
done
```

2. Configura la respuesta del pod canary:

```bash
# Configurar respuesta en pod webapp-canary
for pod in $(kubectl get pods -n deployments-lab -l app=webapp,track=canary -o name); do
  kubectl exec -n deployments-lab $pod -- bash -c 'echo "CANARY v1.25.3" > /usr/share/nginx/html/index.html'
done
```

3. Obtén la IP del ClusterIP del Service:

```bash
SVC_IP=$(kubectl get svc webapp-service -n deployments-lab -o jsonpath='{.spec.clusterIP}')
echo "Service IP: $SVC_IP"
```

4. Ejecuta un loop de pruebas desde un pod temporal:

```bash
kubectl run curl-test --image=busybox:1.36.1 -n deployments-lab \
  --rm -it --restart=Never -- sh -c "
    STABLE=0; CANARY=0; TOTAL=20;
    for i in \$(seq 1 \$TOTAL); do
      RESPONSE=\$(wget -qO- http://webapp-service.deployments-lab.svc.cluster.local 2>/dev/null)
      if echo \"\$RESPONSE\" | grep -q 'CANARY'; then
        CANARY=\$((CANARY+1))
      else
        STABLE=\$((STABLE+1))
      fi
    done
    echo '--- Distribución de tráfico ---'
    echo \"STABLE: \$STABLE/\$TOTAL\"
    echo \"CANARY: \$CANARY/\$TOTAL\"
    echo \"Porcentaje canary: \$(( CANARY * 100 / TOTAL ))%\"
  "
```

**Salida esperada (aproximada):**

```
--- Distribución de tráfico ---
STABLE: 15/20
CANARY: 5/20
Porcentaje canary: 25%
```

> **Nota:** La distribución es estadística basada en round-robin. Con 20 solicitudes, espera valores cercanos al 25% para canary, pero variaciones son normales.

**Verificación:**

El porcentaje canary debe estar entre 15% y 35% con 20 solicitudes, confirmando que la proporción 3:1 funciona.

---

### Paso 5: Escalar Canary al 50% del Tráfico

**Objetivo:** Incrementar la proporción de tráfico canary escalando a 2 réplicas (2 canary + 3 stable = ~40%) y luego igualando a 3:3 para un 50% exacto.

**Instrucciones:**

1. Escala el canary a 2 réplicas:

```bash
kubectl scale deployment/webapp-canary -n deployments-lab --replicas=2
```

2. Espera a que el nuevo pod esté listo:

```bash
kubectl rollout status deployment/webapp-canary -n deployments-lab --timeout=60s
```

3. Configura la respuesta del nuevo pod canary:

```bash
for pod in $(kubectl get pods -n deployments-lab -l app=webapp,track=canary -o name); do
  kubectl exec -n deployments-lab $pod -- bash -c 'echo "CANARY v1.25.3" > /usr/share/nginx/html/index.html'
done
```

4. Verifica la distribución actual (2 canary / 5 total = ~40%):

```bash
kubectl run curl-test-2 --image=busybox:1.36.1 -n deployments-lab \
  --rm -it --restart=Never -- sh -c "
    STABLE=0; CANARY=0; TOTAL=20;
    for i in \$(seq 1 \$TOTAL); do
      RESPONSE=\$(wget -qO- http://webapp-service.deployments-lab.svc.cluster.local 2>/dev/null)
      if echo \"\$RESPONSE\" | grep -q 'CANARY'; then
        CANARY=\$((CANARY+1))
      else
        STABLE=\$((STABLE+1))
      fi
    done
    echo '--- Distribución 40% ---'
    echo \"STABLE: \$STABLE/\$TOTAL\"
    echo \"CANARY: \$CANARY/\$TOTAL\"
    echo \"Porcentaje canary: \$(( CANARY * 100 / TOTAL ))%\"
  "
```

5. Ahora escala el canary a 3 réplicas para lograr 50%:

```bash
kubectl scale deployment/webapp-canary -n deployments-lab --replicas=3
kubectl rollout status deployment/webapp-canary -n deployments-lab --timeout=60s
```

6. Configura la respuesta en el nuevo pod:

```bash
for pod in $(kubectl get pods -n deployments-lab -l app=webapp,track=canary -o name); do
  kubectl exec -n deployments-lab $pod -- bash -c 'echo "CANARY v1.25.3" > /usr/share/nginx/html/index.html'
done
```

7. Verifica el estado actual de pods:

```bash
kubectl get pods -n deployments-lab -l app=webapp --show-labels | grep -c Running
```

**Salida esperada:**

```
6
```

**Verificación:**

```bash
# Confirmar 6 endpoints en el Service
kubectl get endpoints webapp-service -n deployments-lab -o jsonpath='{.subsets[0].addresses}' | jq 'length'
```

Debe devolver `6`.

---

### Paso 6: Promover el Canary a Producción

**Objetivo:** Completar la promoción del canary escalando `webapp-blue` a 0 réplicas y `webapp-canary` a 3 réplicas, simulando la finalización exitosa del despliegue.

**Instrucciones:**

1. Escala el Deployment estable a 0 réplicas:

```bash
kubectl scale deployment/webapp-blue -n deployments-lab --replicas=0
```

2. Verifica que solo quedan pods canary:

```bash
kubectl get pods -n deployments-lab -l app=webapp
```

**Salida esperada:**

```
NAME                             READY   STATUS    RESTARTS   AGE
webapp-canary-yyyyy-aaaaa        1/1     Running   0          5m
webapp-canary-yyyyy-bbbbb        1/1     Running   0          3m
webapp-canary-yyyyy-ccccc        1/1     Running   0          2m
```

3. Verifica que el 100% del tráfico va al canary:

```bash
kubectl run curl-test-3 --image=busybox:1.36.1 -n deployments-lab \
  --rm -it --restart=Never -- sh -c "
    CANARY=0; TOTAL=10;
    for i in \$(seq 1 \$TOTAL); do
      RESPONSE=\$(wget -qO- http://webapp-service.deployments-lab.svc.cluster.local 2>/dev/null)
      if echo \"\$RESPONSE\" | grep -q 'CANARY'; then
        CANARY=\$((CANARY+1))
      fi
    done
    echo \"CANARY: \$CANARY/\$TOTAL (debe ser 100%)\"
  "
```

**Salida esperada:**

```
CANARY: 10/10 (debe ser 100%)
```

4. Confirma los Deployments finales:

```bash
kubectl get deployments -n deployments-lab
```

**Salida esperada:**

```
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
webapp-blue     0/0     0            0           25m
webapp-canary   3/3     3            3           10m
```

**Verificación:**

```bash
# Solo 3 endpoints activos, todos del canary
kubectl get endpoints webapp-service -n deployments-lab
```

---

### Paso 7: Simular un Rollback

**Objetivo:** Demostrar la capacidad de revertir el canary y restaurar la versión estable en caso de problemas detectados.

**Instrucciones:**

1. Simula un rollback escalando `webapp-blue` de vuelta y reduciendo `webapp-canary`:

```bash
kubectl scale deployment/webapp-blue -n deployments-lab --replicas=3
kubectl scale deployment/webapp-canary -n deployments-lab --replicas=0
```

2. Espera a que los pods estables estén listos:

```bash
kubectl rollout status deployment/webapp-blue -n deployments-lab --timeout=60s
```

3. Verifica el rollback:

```bash
kubectl get pods -n deployments-lab -l app=webapp
```

**Salida esperada:**

```
NAME                           READY   STATUS    RESTARTS   AGE
webapp-blue-xxxxx-aaaaa        1/1     Running   0          10s
webapp-blue-xxxxx-bbbbb        1/1     Running   0          10s
webapp-blue-xxxxx-ccccc        1/1     Running   0          10s
```

4. Configura las respuestas y verifica:

```bash
for pod in $(kubectl get pods -n deployments-lab -l app=webapp,version=blue -o name); do
  kubectl exec -n deployments-lab $pod -- bash -c 'echo "STABLE v1.24.0" > /usr/share/nginx/html/index.html'
done

kubectl run curl-test-4 --image=busybox:1.36.1 -n deployments-lab \
  --rm -it --restart=Never -- sh -c "
    STABLE=0; TOTAL=10;
    for i in \$(seq 1 \$TOTAL); do
      RESPONSE=\$(wget -qO- http://webapp-service.deployments-lab.svc.cluster.local 2>/dev/null)
      if echo \"\$RESPONSE\" | grep -q 'STABLE'; then
        STABLE=\$((STABLE+1))
      fi
    done
    echo \"STABLE: \$STABLE/\$TOTAL (debe ser 100%)\"
  "
```

**Salida esperada:**

```
STABLE: 10/10 (debe ser 100%)
```

**Verificación:**

El rollback es exitoso cuando el 100% del tráfico retorna a la versión estable.

---

### Paso 8: Restaurar Estado Final (Canary Promovido)

**Objetivo:** Dejar el namespace en el estado final requerido: `webapp-canary` con 3 réplicas como deployment activo para la Práctica 13.

**Instrucciones:**

1. Promueve nuevamente el canary como versión activa:

```bash
kubectl scale deployment/webapp-blue -n deployments-lab --replicas=0
kubectl scale deployment/webapp-canary -n deployments-lab --replicas=3
kubectl rollout status deployment/webapp-canary -n deployments-lab --timeout=60s
```

2. Configura la respuesta en todos los pods canary:

```bash
for pod in $(kubectl get pods -n deployments-lab -l app=webapp,track=canary -o name); do
  kubectl exec -n deployments-lab $pod -- bash -c 'echo "CANARY v1.25.3" > /usr/share/nginx/html/index.html'
done
```

3. Verifica el estado final:

```bash
echo "=== Deployments ==="
kubectl get deployments -n deployments-lab

echo ""
echo "=== Pods activos ==="
kubectl get pods -n deployments-lab -l app=webapp

echo ""
echo "=== Service selector ==="
kubectl get svc webapp-service -n deployments-lab -o jsonpath='{.spec.selector}'
echo ""

echo ""
echo "=== Endpoints ==="
kubectl get endpoints webapp-service -n deployments-lab
```

**Salida esperada:**

```
=== Deployments ===
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
webapp-blue     0/0     0            0           30m
webapp-canary   3/3     3            3           15m

=== Pods activos ===
NAME                             READY   STATUS    RESTARTS   AGE
webapp-canary-yyyyy-aaaaa        1/1     Running   0          60s
webapp-canary-yyyyy-bbbbb        1/1     Running   0          60s
webapp-canary-yyyyy-ccccc        1/1     Running   0          60s

=== Service selector ===
{"app":"webapp"}

=== Endpoints ===
NAME             ENDPOINTS                                      AGE
webapp-service   10.244.x.x:80,10.244.x.x:80,10.244.x.x:80    30m
```

## Validación y Pruebas

Ejecuta el siguiente script de validación completa:

```bash
#!/bin/bash
echo "========================================="
echo " VALIDACIÓN FINAL - Lab 03-00-05"
echo " Estrategia Canary"
echo "========================================="
echo ""

PASS=0
FAIL=0

# Test 1: Namespace existe
if kubectl get namespace deployments-lab &>/dev/null; then
  echo "✅ PASS: Namespace 'deployments-lab' existe"
  PASS=$((PASS+1))
else
  echo "❌ FAIL: Namespace 'deployments-lab' no existe"
  FAIL=$((FAIL+1))
fi

# Test 2: webapp-canary existe con 3 réplicas
CANARY_REPLICAS=$(kubectl get deployment webapp-canary -n deployments-lab -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$CANARY_REPLICAS" = "3" ]; then
  echo "✅ PASS: webapp-canary tiene 3 réplicas configuradas"
  PASS=$((PASS+1))
else
  echo "❌ FAIL: webapp-canary no tiene 3 réplicas (actual: $CANARY_REPLICAS)"
  FAIL=$((FAIL+1))
fi

# Test 3: webapp-canary usa nginx:1.25.3
CANARY_IMAGE=$(kubectl get deployment webapp-canary -n deployments-lab -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
if [ "$CANARY_IMAGE" = "nginx:1.25.3" ]; then
  echo "✅ PASS: webapp-canary usa imagen nginx:1.25.3"
  PASS=$((PASS+1))
else
  echo "❌ FAIL: webapp-canary no usa nginx:1.25.3 (actual: $CANARY_IMAGE)"
  FAIL=$((FAIL+1))
fi

# Test 4: webapp-blue escalado a 0
BLUE_REPLICAS=$(kubectl get deployment webapp-blue -n deployments-lab -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$BLUE_REPLICAS" = "0" ]; then
  echo "✅ PASS: webapp-blue escalado a 0 réplicas"
  PASS=$((PASS+1))
else
  echo "❌ FAIL: webapp-blue no está en 0 réplicas (actual: $BLUE_REPLICAS)"
  FAIL=$((FAIL+1))
fi

# Test 5: Service selector solo tiene app=webapp
SELECTOR=$(kubectl get svc webapp-service -n deployments-lab -o jsonpath='{.spec.selector}' 2>/dev/null)
if echo "$SELECTOR" | grep -q '"app":"webapp"' && ! echo "$SELECTOR" | grep -q '"version"'; then
  echo "✅ PASS: Service selector usa solo app=webapp"
  PASS=$((PASS+1))
else
  echo "❌ FAIL: Service selector incorrecto (actual: $SELECTOR)"
  FAIL=$((FAIL+1))
fi

# Test 6: Canary pods tienen label track=canary
CANARY_PODS=$(kubectl get pods -n deployments-lab -l track=canary --no-headers 2>/dev/null | wc -l)
if [ "$CANARY_PODS" = "3" ]; then
  echo "✅ PASS: 3 pods con label track=canary en ejecución"
  PASS=$((PASS+1))
else
  echo "❌ FAIL: No hay 3 pods con track=canary (actual: $CANARY_PODS)"
  FAIL=$((FAIL+1))
fi

# Test 7: Endpoints del Service apuntan a 3 pods
EP_COUNT=$(kubectl get endpoints webapp-service -n deployments-lab -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | jq 'length' 2>/dev/null)
if [ "$EP_COUNT" = "3" ]; then
  echo "✅ PASS: Service tiene 3 endpoints activos"
  PASS=$((PASS+1))
else
  echo "❌ FAIL: Service no tiene 3 endpoints (actual: $EP_COUNT)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "========================================="
echo " Resultado: $PASS PASS / $FAIL FAIL"
echo "========================================="
```

Guarda y ejecuta:

```bash
chmod +x ~/ckad-labs/lab05/canary/validate.sh
~/ckad-labs/lab05/canary/validate.sh
```

**Resultado esperado:** 7 PASS / 0 FAIL.

## Troubleshooting

### Problema 1: El Pod Canary No Recibe Tráfico

**Síntomas:** Al ejecutar el loop de pruebas, el 100% de las respuestas son "STABLE" y 0% "CANARY", a pesar de que el pod canary está en estado Running.

**Causa:** El selector del Service todavía contiene `version: blue`, por lo que solo los pods con esa etiqueta exacta son incluidos en los endpoints. El pod canary tiene `version: canary` y queda excluido.

**Solución:**

```bash
# Verificar el selector actual
kubectl get svc webapp-service -n deployments-lab -o jsonpath='{.spec.selector}'

# Si muestra {"app":"webapp","version":"blue"}, corregir:
kubectl patch svc webapp-service -n deployments-lab \
  --type='json' \
  -p='[{"op": "remove", "path": "/spec/selector/version"}]'

# Verificar que los endpoints ahora incluyen el pod canary
kubectl get endpoints webapp-service -n deployments-lab
```

---

### Problema 2: El Loop de curl Muestra "wget: bad address" o Timeouts

**Síntomas:** El pod temporal `curl-test` no puede resolver `webapp-service.deployments-lab.svc.cluster.local` o las conexiones fallan con timeout.

**Causa:** El pod temporal se creó en un namespace diferente a `deployments-lab`, o el DNS del clúster no está funcionando correctamente, o hay un pod con el mismo nombre que no se eliminó de una ejecución anterior.

**Solución:**

```bash
# Verificar si hay pods residuales con el nombre curl-test
kubectl get pods -n deployments-lab | grep curl-test

# Eliminar pods residuales si existen
kubectl delete pod curl-test -n deployments-lab --force --grace-period=0 2>/dev/null
kubectl delete pod curl-test-2 -n deployments-lab --force --grace-period=0 2>/dev/null

# Verificar DNS desde un pod temporal
kubectl run dns-test --image=busybox:1.36.1 -n deployments-lab \
  --rm -it --restart=Never -- nslookup webapp-service.deployments-lab.svc.cluster.local

# Si DNS funciona, probar conectividad directa con la IP del Service
SVC_IP=$(kubectl get svc webapp-service -n deployments-lab -o jsonpath='{.spec.clusterIP}')
kubectl run conn-test --image=busybox:1.36.1 -n deployments-lab \
  --rm -it --restart=Never -- wget -qO- http://$SVC_IP
```

## Cleanup

> **⚠️ NO ejecutar el cleanup si vas a continuar con la Práctica 13.** El estado final de este lab es prerequisito para el siguiente.

Si necesitas limpiar completamente el laboratorio:

```bash
# Eliminar solo los recursos de este lab (mantener namespace para Práctica 13)
kubectl delete deployment webapp-canary -n deployments-lab
kubectl scale deployment/webapp-blue -n deployments-lab --replicas=3

# O eliminar todo el namespace (solo si no continúas)
# kubectl delete namespace deployments-lab
```

Para limpiar los archivos locales:

```bash
rm -rf ~/ckad-labs/lab05/canary/
```

## Resumen

En este laboratorio has implementado una estrategia de despliegue **canary** completa en Kubernetes:

| Concepto | Implementación |
|----------|---------------|
| Control de tráfico | Proporción de réplicas entre Deployments |
| Selector compartido | `app: webapp` en Service sin restricción de versión |
| Progresión gradual | 25% → 40% → 50% → 100% mediante `kubectl scale` |
| Promoción | Escalar stable a 0, canary a réplicas deseadas |
| Rollback | Escalar canary a 0, stable a réplicas originales |

### Diferencias Clave: Canary vs Blue/Green

| Aspecto | Blue/Green | Canary |
|---------|-----------|--------|
| Cambio de tráfico | Instantáneo (0% → 100%) | Gradual (incrementos controlados) |
| Riesgo | Mayor (todos los usuarios afectados) | Menor (solo un porcentaje) |
| Recursos adicionales | Doble infraestructura temporal | Solo réplicas adicionales del canary |
| Complejidad de rollback | Cambiar selector | Escalar réplicas |
| Detección de problemas | Post-switch | Durante la progresión |

### Limitaciones del Enfoque por Réplicas

- La granularidad mínima es 1/N (donde N es el total de pods)
- No permite control exacto de porcentaje sin ajustar el total de réplicas
- Para control más fino, se requieren service meshes (Istio, Linkerd) o ingress controllers con weighted routing

### Recursos Adicionales

- [Kubernetes Documentation — Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Canary Deployments — Kubernetes Blog](https://kubernetes.io/blog/2018/04/30/zero-downtime-deployment-kubernetes-jenkins/)
- [Flagger — Progressive Delivery for Kubernetes](https://flagger.app/)

---

# Despliegue con Helm

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Hard |
| **Nivel Bloom** | Apply |
| **Tecnologías** | Helm 3.14.3, Go templating, kubectl, nginx:1.25.3, nginx:1.26.2 |

## Descripción General

En esta práctica instalarás y configurarás Helm como gestor de paquetes para Kubernetes, crearás un Helm chart personalizado desde cero que encapsula un Deployment y un Service para la aplicación webapp, y gestionarás el ciclo de vida completo de un release: instalación, upgrade con `--set`, rollback y validación de manifiestos renderizados. Este lab consolida la comprensión de cómo Helm abstrae la complejidad de los manifiestos YAML mediante templating y valores configurables.

## Objetivos de Aprendizaje

- [ ] Instalar y verificar Helm 3.14.3 como gestor de paquetes para Kubernetes
- [ ] Crear un Helm chart personalizado con estructura completa (Chart.yaml, values.yaml, templates/)
- [ ] Gestionar el ciclo de vida de un release Helm: install, upgrade, rollback y uninstall
- [ ] Personalizar despliegues mediante values.yaml y flags `--set` en tiempo de instalación
- [ ] Validar manifiestos renderizados con `helm template` y compatibilidad de APIs con `kubectl api-versions`

## Prerrequisitos

### Conocimientos Requeridos

- Comprensión de Deployments y Services de Kubernetes (Prácticas 11 y 12)
- Sintaxis YAML avanzada y conceptos de templating
- Familiaridad con la línea de comandos y estructura de directorios

### Acceso y Herramientas

- Clúster Kubernetes funcional (kind o minikube)
- `kubectl` configurado y conectado al clúster
- Helm 3.14.3 instalado en el sistema
- Acceso a internet para descargar charts del repositorio Bitnami

## Entorno del Laboratorio

### Software Requerido

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| Helm | 3.14.3 | Gestor de paquetes Kubernetes |
| kubectl | 1.30.2 | CLI de Kubernetes |
| kind | 0.23.0 | Clúster local Kubernetes |
| Docker Engine | 26.1.4 | Runtime de contenedores |

### Preparación Inicial

```bash
# Crear directorio de trabajo para este lab
mkdir -p ~/ckad-labs/lab06
cd ~/ckad-labs/lab06

# Verificar que el clúster está activo
kubectl cluster-info

# Crear el namespace dedicado para este lab
kubectl create namespace helm-lab

# Configurar el contexto para usar helm-lab
kubectl config set-context --current --namespace=helm-lab
```

## Paso a Paso

### Paso 1: Verificar la Instalación de Helm

**Objetivo:** Confirmar que Helm 3.14.3 está correctamente instalado y funcional.

**Instrucciones:**

1. Verificar la versión de Helm instalada:

```bash
helm version --short
```

2. Si Helm no está instalado o la versión es incorrecta, instalar la versión específica:

```bash
# Descargar e instalar Helm 3.14.3
curl -fsSL https://get.helm.sh/helm-v3.14.3-linux-amd64.tar.gz -o helm.tar.gz
tar -zxvf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
rm -rf linux-amd64 helm.tar.gz
```

3. Verificar que Helm puede comunicarse con el clúster:

```bash
helm list --namespace helm-lab
```

4. Confirmar las variables de entorno de Helm:

```bash
helm env
```

**Salida Esperada:**

```
$ helm version --short
v3.14.3+g085e725

$ helm list --namespace helm-lab
NAME    NAMESPACE       REVISION        UPDATED STATUS  CHART   APP VERSION
```

**Verificación:**

```bash
# La versión debe ser exactamente 3.14.3
helm version --short | grep -q "v3.14.3" && echo "✓ Helm 3.14.3 verificado" || echo "✗ Versión incorrecta"
```

---

### Paso 2: Agregar el Repositorio Bitnami e Instalar un Chart Externo

**Objetivo:** Familiarizarse con el flujo de trabajo de Helm instalando un chart externo del repositorio Bitnami.

**Instrucciones:**

1. Agregar el repositorio Bitnami:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

2. Actualizar el índice de repositorios:

```bash
helm repo update
```

3. Buscar el chart de nginx disponible:

```bash
helm search repo bitnami/nginx --version 15.14.0
```

4. Inspeccionar los valores por defecto del chart:

```bash
helm show values bitnami/nginx --version 15.14.0 | head -50
```

5. Instalar el chart bitnami/nginx con valores personalizados:

```bash
helm install nginx-explore bitnami/nginx \
  --version 15.14.0 \
  --namespace helm-lab \
  --set replicaCount=1 \
  --set service.type=ClusterIP
```

6. Verificar el release instalado:

```bash
helm list --namespace helm-lab
```

7. Verificar los recursos creados:

```bash
kubectl get all --namespace helm-lab -l app.kubernetes.io/instance=nginx-explore
```

**Salida Esperada:**

```
$ helm repo add bitnami https://charts.bitnami.com/bitnami
"bitnami" has been added to your repositories

$ helm list --namespace helm-lab
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
nginx-explore   helm-lab        1               2024-...                                deployed        nginx-15.14.0   1.25.4
```

**Verificación:**

```bash
helm status nginx-explore --namespace helm-lab | grep -q "STATUS: deployed" && echo "✓ Release nginx-explore desplegado" || echo "✗ Error en despliegue"
```

8. Desinstalar el chart exploratorio (ya no se necesita):

```bash
helm uninstall nginx-explore --namespace helm-lab
```

---

### Paso 3: Crear la Estructura del Helm Chart Personalizado

**Objetivo:** Construir manualmente la estructura completa de un Helm chart llamado `webapp-chart`.

**Instrucciones:**

1. Crear la estructura de directorios del chart:

```bash
cd ~/ckad-labs/lab06
mkdir -p webapp-chart/templates
```

2. Crear el archivo `Chart.yaml`:

```bash
cat > webapp-chart/Chart.yaml << 'EOF'
apiVersion: v2
name: webapp-chart
description: Helm chart para la aplicación webapp del curso CKAD
type: application
version: 0.1.0
appVersion: "1.0.0"
keywords:
  - webapp
  - nginx
  - ckad
maintainers:
  - name: CKAD Student
EOF
```

3. Crear el archivo `values.yaml` con los valores por defecto:

```bash
cat > webapp-chart/values.yaml << 'EOF'
# Valores por defecto para webapp-chart
replicaCount: 2

image:
  repository: nginx
  tag: "1.25.3"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

containerPort: 80

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 250m
    memory: 256Mi

labels:
  app: webapp
  tier: frontend
EOF
```

4. Verificar la estructura creada:

```bash
find webapp-chart/ -type f | sort
```

**Salida Esperada:**

```
webapp-chart/Chart.yaml
webapp-chart/values.yaml
```

**Verificación:**

```bash
# Validar que Chart.yaml tiene los campos requeridos
grep -q "apiVersion: v2" webapp-chart/Chart.yaml && \
grep -q "name: webapp-chart" webapp-chart/Chart.yaml && \
grep -q "version: 0.1.0" webapp-chart/Chart.yaml && \
echo "✓ Chart.yaml válido" || echo "✗ Chart.yaml incompleto"
```

---

### Paso 4: Crear los Templates del Chart

**Objetivo:** Implementar los templates de Deployment y Service usando Go templating con referencias a `.Values`.

**Instrucciones:**

1. Crear el template `_helpers.tpl` con funciones auxiliares:

```bash
cat > webapp-chart/templates/_helpers.tpl << 'EOF'
{{/*
Generar el nombre completo del release
*/}}
{{- define "webapp-chart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generar labels estándar
*/}}
{{- define "webapp-chart.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/*
Generar selector labels
*/}}
{{- define "webapp-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
EOF
```

2. Crear el template del Deployment:

```bash
cat > webapp-chart/templates/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "webapp-chart.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "webapp-chart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "webapp-chart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "webapp-chart.selectorLabels" . | nindent 8 }}
        app: {{ .Values.labels.app }}
        tier: {{ .Values.labels.tier }}
    spec:
      containers:
        - name: webapp
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.containerPort }}
              protocol: TCP
          resources:
            requests:
              cpu: {{ .Values.resources.requests.cpu }}
              memory: {{ .Values.resources.requests.memory }}
            limits:
              cpu: {{ .Values.resources.limits.cpu }}
              memory: {{ .Values.resources.limits.memory }}
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
EOF
```

3. Crear el template del Service:

```bash
cat > webapp-chart/templates/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "webapp-chart.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "webapp-chart.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "webapp-chart.selectorLabels" . | nindent 4 }}
EOF
```

4. Crear un template NOTES.txt para mostrar información post-instalación:

```bash
cat > webapp-chart/templates/NOTES.txt << 'EOF'
=======================================================
  webapp-chart ha sido desplegado exitosamente!
=======================================================

Release: {{ .Release.Name }}
Namespace: {{ .Release.Namespace }}
Réplicas: {{ .Values.replicaCount }}
Imagen: {{ .Values.image.repository }}:{{ .Values.image.tag }}

Para acceder a la aplicación:
  kubectl port-forward svc/{{ include "webapp-chart.fullname" . }} 8083:{{ .Values.service.port }} -n {{ .Release.Namespace }}

Luego visita: http://localhost:8083
EOF
```

5. Verificar la estructura completa del chart:

```bash
find webapp-chart/ -type f | sort
```

**Salida Esperada:**

```
webapp-chart/Chart.yaml
webapp-chart/templates/NOTES.txt
webapp-chart/templates/_helpers.tpl
webapp-chart/templates/deployment.yaml
webapp-chart/templates/service.yaml
webapp-chart/values.yaml
```

**Verificación:**

```bash
# Validar la sintaxis del chart con helm lint
helm lint webapp-chart/
```

La salida debe indicar:

```
==> Linting webapp-chart/
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

---

### Paso 5: Validar el Chart con helm template

**Objetivo:** Renderizar los manifiestos localmente sin instalar en el clúster para verificar la correcta interpolación de valores.

**Instrucciones:**

1. Renderizar el chart con valores por defecto:

```bash
helm template webapp-release webapp-chart/ --namespace helm-lab
```

2. Verificar que el Deployment tiene 2 réplicas y la imagen correcta:

```bash
helm template webapp-release webapp-chart/ --namespace helm-lab | grep -A2 "replicas:"
helm template webapp-release webapp-chart/ --namespace helm-lab | grep "image:"
```

3. Renderizar con valores personalizados para validar overrides:

```bash
helm template webapp-release webapp-chart/ \
  --namespace helm-lab \
  --set replicaCount=4 \
  --set image.tag=1.26.2
```

4. Guardar el manifiesto renderizado para inspección:

```bash
helm template webapp-release webapp-chart/ --namespace helm-lab > /tmp/rendered-manifests.yaml
cat /tmp/rendered-manifests.yaml
```

5. Validar compatibilidad de APIs con `kubectl api-versions`:

```bash
# Listar las API versions disponibles en el clúster
kubectl api-versions | grep -E "^apps/v1|^v1$"

# Verificar que las APIs usadas en los templates están disponibles
grep "apiVersion:" /tmp/rendered-manifests.yaml
```

**Salida Esperada:**

```
$ helm template webapp-release webapp-chart/ --namespace helm-lab | grep "image:"
          image: "nginx:1.25.3"

$ helm template webapp-release webapp-chart/ --namespace helm-lab | grep "replicas:"
  replicas: 2

$ kubectl api-versions | grep -E "^apps/v1|^v1$"
apps/v1
v1
```

**Verificación:**

```bash
# Confirmar que ambas APIs usadas están disponibles
kubectl api-versions | grep -q "apps/v1" && echo "✓ apps/v1 disponible" || echo "✗ apps/v1 no encontrada"
kubectl api-versions | grep -q "^v1$" && echo "✓ v1 disponible" || echo "✗ v1 no encontrada"
```

---

### Paso 6: Instalar el Chart en el Clúster

**Objetivo:** Realizar la primera instalación del chart personalizado y verificar que los recursos se crean correctamente.

**Instrucciones:**

1. Instalar el chart con el nombre de release `webapp-release`:

```bash
helm install webapp-release webapp-chart/ \
  --namespace helm-lab \
  --wait \
  --timeout 120s
```

2. Verificar el estado del release:

```bash
helm list --namespace helm-lab
```

3. Verificar los recursos creados en el namespace:

```bash
kubectl get all --namespace helm-lab
```

4. Verificar que los pods están en estado Running:

```bash
kubectl get pods --namespace helm-lab -l app.kubernetes.io/instance=webapp-release
```

5. Inspeccionar el Deployment creado:

```bash
kubectl describe deployment webapp-release-webapp-chart --namespace helm-lab
```

6. Verificar el Service:

```bash
kubectl get svc webapp-release-webapp-chart --namespace helm-lab
```

**Salida Esperada:**

```
$ helm list --namespace helm-lab
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
webapp-release  helm-lab        1               2024-...                                deployed        webapp-chart-0.1.0      1.0.0

$ kubectl get pods --namespace helm-lab -l app.kubernetes.io/instance=webapp-release
NAME                                           READY   STATUS    RESTARTS   AGE
webapp-release-webapp-chart-xxxxxxxxx-xxxxx    1/1     Running   0          30s
webapp-release-webapp-chart-xxxxxxxxx-xxxxx    1/1     Running   0          30s
```

**Verificación:**

```bash
# Confirmar 2 réplicas en Running
RUNNING_PODS=$(kubectl get pods --namespace helm-lab -l app.kubernetes.io/instance=webapp-release --field-selector=status.phase=Running --no-headers | wc -l)
[ "$RUNNING_PODS" -eq 2 ] && echo "✓ 2 réplicas en Running" || echo "✗ Esperadas 2 réplicas, encontradas: $RUNNING_PODS"

# Confirmar imagen correcta
kubectl get deployment webapp-release-webapp-chart -n helm-lab -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -q "nginx:1.25.3" && echo "✓ Imagen nginx:1.25.3 correcta" || echo "✗ Imagen incorrecta"
```

---

### Paso 7: Realizar un Upgrade del Release

**Objetivo:** Actualizar el release modificando el número de réplicas y la versión de imagen mediante flags `--set`.

**Instrucciones:**

1. Ejecutar el upgrade cambiando réplicas a 4 e imagen a nginx:1.26.2:

```bash
helm upgrade webapp-release webapp-chart/ \
  --namespace helm-lab \
  --set replicaCount=4 \
  --set image.tag=1.26.2 \
  --wait \
  --timeout 120s
```

2. Verificar que el release está en revisión 2:

```bash
helm list --namespace helm-lab
```

3. Verificar el historial del release:

```bash
helm history webapp-release --namespace helm-lab
```

4. Confirmar que ahora hay 4 pods:

```bash
kubectl get pods --namespace helm-lab -l app.kubernetes.io/instance=webapp-release
```

5. Verificar la nueva imagen desplegada:

```bash
kubectl get deployment webapp-release-webapp-chart -n helm-lab \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

6. Verificar el número de réplicas en el Deployment:

```bash
kubectl get deployment webapp-release-webapp-chart -n helm-lab \
  -o jsonpath='{.spec.replicas}{"\n"}'
```

**Salida Esperada:**

```
$ helm history webapp-release --namespace helm-lab
REVISION        UPDATED                         STATUS          CHART                   APP VERSION     DESCRIPTION
1               2024-...                        superseded      webapp-chart-0.1.0      1.0.0           Install complete
2               2024-...                        deployed        webapp-chart-0.1.0      1.0.0           Upgrade complete

$ kubectl get deployment webapp-release-webapp-chart -n helm-lab -o jsonpath='{.spec.template.spec.containers[0].image}'
nginx:1.26.2

$ kubectl get deployment webapp-release-webapp-chart -n helm-lab -o jsonpath='{.spec.replicas}'
4
```

**Verificación:**

```bash
# Confirmar 4 réplicas
REPLICAS=$(kubectl get deployment webapp-release-webapp-chart -n helm-lab -o jsonpath='{.spec.replicas}')
[ "$REPLICAS" -eq 4 ] && echo "✓ Upgrade a 4 réplicas exitoso" || echo "✗ Réplicas: $REPLICAS (esperadas 4)"

# Confirmar imagen actualizada
IMG=$(kubectl get deployment webapp-release-webapp-chart -n helm-lab -o jsonpath='{.spec.template.spec.containers[0].image}')
[ "$IMG" = "nginx:1.26.2" ] && echo "✓ Imagen actualizada a nginx:1.26.2" || echo "✗ Imagen: $IMG"
```

---

### Paso 8: Ejecutar Rollback a la Revisión 1

**Objetivo:** Revertir el release a su estado original (revisión 1) y verificar que los recursos vuelven a su configuración inicial.

**Instrucciones:**

1. Ejecutar el rollback a la revisión 1:

```bash
helm rollback webapp-release 1 --namespace helm-lab --wait
```

2. Verificar el historial actualizado:

```bash
helm history webapp-release --namespace helm-lab
```

3. Confirmar que las réplicas volvieron a 2:

```bash
kubectl get deployment webapp-release-webapp-chart -n helm-lab \
  -o jsonpath='{.spec.replicas}{"\n"}'
```

4. Confirmar que la imagen volvió a nginx:1.25.3:

```bash
kubectl get deployment webapp-release-webapp-chart -n helm-lab \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

5. Esperar a que los pods se estabilicen y verificar:

```bash
kubectl rollout status deployment webapp-release-webapp-chart -n helm-lab --timeout=60s
kubectl get pods --namespace helm-lab -l app.kubernetes.io/instance=webapp-release
```

**Salida Esperada:**

```
$ helm rollback webapp-release 1 --namespace helm-lab --wait
Rollback was a success! Happy Helming!

$ helm history webapp-release --namespace helm-lab
REVISION        UPDATED                         STATUS          CHART                   APP VERSION     DESCRIPTION
1               2024-...                        superseded      webapp-chart-0.1.0      1.0.0           Install complete
2               2024-...                        superseded      webapp-chart-0.1.0      1.0.0           Upgrade complete
3               2024-...                        deployed        webapp-chart-0.1.0      1.0.0           Rollback to 1

$ kubectl get deployment webapp-release-webapp-chart -n helm-lab -o jsonpath='{.spec.replicas}'
2

$ kubectl get deployment webapp-release-webapp-chart -n helm-lab -o jsonpath='{.spec.template.spec.containers[0].image}'
nginx:1.25.3
```

**Verificación:**

```bash
# Confirmar rollback exitoso
REVISION=$(helm list --namespace helm-lab -o json | grep -o '"revision":"[0-9]*"' | grep -o '[0-9]*')
REPLICAS=$(kubectl get deployment webapp-release-webapp-chart -n helm-lab -o jsonpath='{.spec.replicas}')
IMG=$(kubectl get deployment webapp-release-webapp-chart -n helm-lab -o jsonpath='{.spec.template.spec.containers[0].image}')

[ "$REPLICAS" -eq 2 ] && echo "✓ Réplicas restauradas a 2" || echo "✗ Réplicas: $REPLICAS"
[ "$IMG" = "nginx:1.25.3" ] && echo "✓ Imagen restaurada a nginx:1.25.3" || echo "✗ Imagen: $IMG"
```

---

### Paso 9: Realizar Upgrade Final para Estado Deseado

**Objetivo:** Dejar el release en su configuración final con los valores por defecto (2 réplicas, nginx:1.25.3) confirmando que el release `webapp-release` queda activo en el namespace `helm-lab`.

**Instrucciones:**

1. Verificar el estado actual del release:

```bash
helm status webapp-release --namespace helm-lab
```

2. Obtener los valores activos del release:

```bash
helm get values webapp-release --namespace helm-lab --all
```

3. Renderizar y validar el manifiesto final:

```bash
helm get manifest webapp-release --namespace helm-lab
```

4. Confirmar la conectividad del Service:

```bash
# Obtener el ClusterIP del service
kubectl get svc webapp-release-webapp-chart -n helm-lab -o jsonpath='{.spec.clusterIP}{"\n"}'

# Probar conectividad desde un pod temporal
kubectl run test-curl --rm -it --restart=Never \
  --namespace helm-lab \
  --image=busybox:1.36.1 \
  -- wget -qO- http://webapp-release-webapp-chart.helm-lab.svc.cluster.local:80 | head -5
```

**Salida Esperada:**

```
$ helm status webapp-release --namespace helm-lab
NAME: webapp-release
...
STATUS: deployed
REVISION: 3

$ kubectl run test-curl --rm -it --restart=Never --namespace helm-lab --image=busybox:1.36.1 -- wget -qO- http://webapp-release-webapp-chart.helm-lab.svc.cluster.local:80 | head -5
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

**Verificación:**

```bash
helm status webapp-release --namespace helm-lab | grep -q "STATUS: deployed" && echo "✓ Release webapp-release activo y desplegado" || echo "✗ Release no está en estado deployed"
```

## Validación y Testing

Ejecutar la siguiente secuencia completa de validaciones para confirmar el éxito del laboratorio:

```bash
echo "========================================="
echo "  VALIDACIÓN FINAL - Lab 03-00-06"
echo "========================================="
echo ""

# 1. Helm version
echo "1. Versión de Helm:"
helm version --short
echo ""

# 2. Release activo
echo "2. Release activo en helm-lab:"
helm list --namespace helm-lab --filter webapp-release
echo ""

# 3. Historial del release
echo "3. Historial del release:"
helm history webapp-release --namespace helm-lab
echo ""

# 4. Pods en ejecución
echo "4. Pods del release:"
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=webapp-release
echo ""

# 5. Deployment details
echo "5. Deployment:"
kubectl get deployment webapp-release-webapp-chart -n helm-lab -o wide
echo ""

# 6. Service
echo "6. Service:"
kubectl get svc webapp-release-webapp-chart -n helm-lab
echo ""

# 7. Chart structure
echo "7. Estructura del chart:"
find ~/ckad-labs/lab06/webapp-chart/ -type f | sort
echo ""

# 8. API compatibility
echo "8. APIs utilizadas disponibles:"
kubectl api-versions | grep -E "^apps/v1$|^v1$"
echo ""

echo "========================================="
echo "  VALIDACIÓN COMPLETADA"
echo "========================================="
```

**Criterios de Éxito:**

| Criterio | Condición |
|----------|-----------|
| Helm instalado | Versión v3.14.3 |
| Chart creado | 6 archivos en webapp-chart/ |
| Release activo | STATUS: deployed |
| Revisiones | Mínimo 3 en historial |
| Pods Running | 2 réplicas en estado Running |
| Imagen correcta | nginx:1.25.3 (post-rollback) |
| Service accesible | Responde con página nginx |

## Troubleshooting

### Problema 1: Error "cannot re-use a name that is still in use"

**Síntomas:**

```
Error: cannot re-use a name that is still in use
```

Este error aparece al intentar ejecutar `helm install` con un nombre de release que ya existe.

**Causa:** Se está ejecutando `helm install` cuando el release ya fue instalado previamente. Helm no permite reusar nombres de release con `install`.

**Solución:**

```bash
# Opción 1: Usar helm upgrade en lugar de install
helm upgrade webapp-release webapp-chart/ --namespace helm-lab --set replicaCount=2

# Opción 2: Usar install con --replace (no recomendado en producción)
helm install webapp-release webapp-chart/ --namespace helm-lab --replace

# Opción 3: Desinstalar primero y volver a instalar
helm uninstall webapp-release --namespace helm-lab
helm install webapp-release webapp-chart/ --namespace helm-lab --wait
```

---

### Problema 2: Pods en estado CrashLoopBackOff tras el upgrade

**Síntomas:**

```
$ kubectl get pods -n helm-lab
NAME                                           READY   STATUS             RESTARTS   AGE
webapp-release-webapp-chart-xxxxx-xxxxx        0/1     CrashLoopBackOff   3          2m
```

Los pods no pasan a estado Running después de un `helm upgrade`.

**Causa:** Se especificó un tag de imagen inexistente o un repositorio incorrecto en el flag `--set`. Por ejemplo, un typo como `--set image.tag=1.26.22` (versión que no existe en Docker Hub).

**Solución:**

```bash
# 1. Verificar qué imagen se configuró
kubectl get deployment webapp-release-webapp-chart -n helm-lab \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# 2. Revisar los eventos del pod para confirmar el error de pull
kubectl describe pod -n helm-lab -l app.kubernetes.io/instance=webapp-release | grep -A5 "Events:"

# 3. Hacer rollback a la última revisión funcional
helm rollback webapp-release 0 --namespace helm-lab --wait
# (revisión 0 = última revisión exitosa)

# 4. Verificar que los pods se recuperaron
kubectl get pods -n helm-lab -l app.kubernetes.io/instance=webapp-release
```

## Limpieza

> **Nota:** El release `webapp-release` debe permanecer activo en el namespace `helm-lab` ya que será referenciado en las prácticas del módulo 4. Solo ejecutar la limpieza si se desea reiniciar el lab completamente.

```bash
# === LIMPIEZA PARCIAL (recomendada) ===
# Eliminar solo recursos temporales de exploración
kubectl delete pod test-curl --namespace helm-lab --ignore-not-found=true
rm -f /tmp/rendered-manifests.yaml

# === LIMPIEZA COMPLETA (solo si se necesita reiniciar) ===
# Desinstalar todos los releases
helm uninstall webapp-release --namespace helm-lab 2>/dev/null
helm uninstall nginx-explore --namespace helm-lab 2>/dev/null

# Eliminar el namespace
kubectl delete namespace helm-lab

# Restaurar el namespace por defecto
kubectl config set-context --current --namespace=ckad-dev

# Eliminar el directorio de trabajo
rm -rf ~/ckad-labs/lab06/webapp-chart
```

## Resumen

En esta práctica has completado el ciclo de vida completo de gestión de paquetes con Helm:

- **Instalación y configuración** de Helm 3.14.3 con verificación de conectividad al clúster
- **Exploración** de charts externos (bitnami/nginx) para comprender la estructura y flujo de trabajo
- **Creación manual** de un chart personalizado con `Chart.yaml`, `values.yaml`, helpers y templates de Deployment/Service
- **Validación pre-instalación** con `helm template` y verificación de compatibilidad de APIs
- **Gestión del ciclo de vida**: install → upgrade (con `--set`) → rollback → verificación
- **Go templating**: uso de `{{ .Values.* }}`, `{{ include }}`, `{{ .Release.* }}` y funciones como `nindent`

### Conceptos Clave Aplicados

| Concepto | Aplicación en el Lab |
|----------|---------------------|
| Selección de workload | El chart encapsula un Deployment (aplicación sin estado, réplicas intercambiables) |
| Helm como abstracción | Los templates permiten reutilizar manifiestos con diferentes configuraciones |
| Versionado de releases | El historial de revisiones permite rollback seguro |
| Validación dry-run | `helm template` previene errores antes del despliegue |

### Recursos Adicionales

- [Documentación oficial de Helm](https://helm.sh/docs/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Go Template Language](https://pkg.go.dev/text/template)
- [Helm Template Functions (Sprig)](https://masterminds.github.io/sprig/)
- [Artifact Hub - Repositorio de Charts](https://artifacthub.io/)
