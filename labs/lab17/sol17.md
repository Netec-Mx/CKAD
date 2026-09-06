# Solución del reto — Práctica 17: Control de recursos de aplicaciones

## Alcance

Este solucionario cubre los retos de:

- requests y limits;
- CPU throttling;
- `OOMKilled`;
- corrección de memoria;
- QoS `Burstable` y `Guaranteed`.

---

## Reto 1. Dimensionar el Deployment `api`

### Paso 1. Crear el Deployment

```bash
cat > api.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: lab17
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
        - name: api
          image: busybox:1.38.0-musl
          command: ["sh", "-c", "sleep 3600"]
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 300m
              memory: 128Mi
EOF
```

```bash
kubectl apply -f api.yaml
```

### Paso 2. Validar disponibilidad

```bash
kubectl rollout status deployment/api -n lab17 --timeout=60s
```

### Paso 3. Validar recursos

```bash
kubectl get deployment api -n lab17 -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

### Paso 4. Confirmar QoS Burstable

```bash
kubectl get pods -n lab17 -l app=api -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.status.qosClass}{"\n"}{end}'
```

**Resultado esperado:** `Burstable`.

---

## Reto 2. Presión de CPU

### Paso 5. Crear `cpu-burner`

```bash
cat > cpu-burner.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cpu-burner
  namespace: lab17
spec:
  containers:
    - name: cpu
      image: busybox:1.38.0-musl
      command:
        - sh
        - -c
        - while true; do :; done
      resources:
        requests:
          cpu: 100m
          memory: 16Mi
        limits:
          cpu: 200m
          memory: 32Mi
EOF
```

```bash
kubectl apply -f cpu-burner.yaml
```

### Paso 6. Validar que permanece Running

```bash
kubectl get pod cpu-burner -n lab17
```

**Resultado esperado:** `Running`.

El límite de CPU restringe tiempo de CPU; no implica normalmente terminar el contenedor.

---

## Reto 3. Provocar OOMKilled

### Paso 7. Crear `memory-hog`

```bash
cat > memory-hog.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: memory-hog
  namespace: lab17
spec:
  restartPolicy: Always
  containers:
    - name: memory
      image: python:3.13-alpine3.24
      command:
        - python
        - -c
        - |
          import time
          data = bytearray(100 * 1024 * 1024)
          time.sleep(3600)
      resources:
        requests:
          memory: 16Mi
          cpu: 25m
        limits:
          memory: 32Mi
          cpu: 100m
EOF
```

```bash
kubectl apply -f memory-hog.yaml
```

### Paso 8. Observar reinicios

```bash
kubectl get pod memory-hog -n lab17 -w
```

Finaliza con `Ctrl+C`.

### Paso 9. Confirmar OOMKilled

```bash
kubectl get pod memory-hog -n lab17 -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}'
```

**Resultado esperado:**

```text
OOMKilled
```

---

## Reto 4. Corregir memoria

### Paso 10. Aumentar el límite

Edita `memory-hog.yaml` y deja:

```yaml
resources:
  requests:
    memory: 128Mi
    cpu: 25m
  limits:
    memory: 128Mi
    cpu: 100m
```

Recrea el Pod:

```bash
kubectl delete pod memory-hog -n lab17
```

```bash
kubectl apply -f memory-hog.yaml
```

### Paso 11. Validar estabilidad

```bash
kubectl get pod memory-hog -n lab17
```

**Resultado esperado:** `Running`.

---

## Reto 5. Crear un Pod Guaranteed

### Paso 12. Crear `critical-api`

```bash
cat > critical-api.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: critical-api
  namespace: lab17
spec:
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 200m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 128Mi
EOF
```

```bash
kubectl apply -f critical-api.yaml
```

### Paso 13. Confirmar QoS

```bash
kubectl get pod critical-api -n lab17 -o jsonpath='{.status.qosClass}{"\n"}'
```

**Resultado esperado:**

```text
Guaranteed
```

---

## Limpieza

```bash
kubectl delete namespace lab17 --wait=true
```
