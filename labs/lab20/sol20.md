# Solución del reto — Práctica 20: Implementación de probes

## Reto 1. Readiness y Service

### Paso 1. Crear `web-ready`

```bash
cat > web-ready.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-ready
  namespace: lab20
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-ready
  template:
    metadata:
      labels:
        app: web-ready
    spec:
      containers:
        - name: nginx
          image: nginx:1.31.4-alpine3.24-slim
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: web-ready
  namespace: lab20
spec:
  selector:
    app: web-ready
  ports:
    - port: 80
      targetPort: 80
EOF
```

```bash
kubectl apply -f web-ready.yaml
```

### Paso 2. Validar

```bash
kubectl rollout status deployment/web-ready -n lab20 --timeout=60s
```

```bash
kubectl get pods -n lab20 -l app=web-ready
```

```bash
kubectl get endpointslices -n lab20 -l kubernetes.io/service-name=web-ready
```

### Paso 3. Provocar fallo de readiness

```bash
kubectl patch deployment web-ready -n lab20 --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/healthz"}]'
```

### Paso 4. Observar Running pero no Ready

```bash
kubectl get pods -n lab20 -l app=web-ready
```

**Resultado esperado:** Pods `Running`, pero `READY 0/1`.

Consulta EndpointSlices:

```bash
kubectl get endpointslices -n lab20 -l kubernetes.io/service-name=web-ready -o yaml
```

Los endpoints pueden seguir representados, pero con `conditions.ready: false`.

### Paso 5. Restaurar readiness

```bash
kubectl patch deployment web-ready -n lab20 --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```

---

## Reto 2. Liveness y reinicios

### Paso 6. Crear `live-demo`

```bash
cat > live-demo.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: live-demo
  namespace: lab20
spec:
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command:
        - sh
        - -c
        - touch /tmp/healthy; sleep 15; rm -f /tmp/healthy; sleep 3600
      livenessProbe:
        exec:
          command:
            - test
            - -f
            - /tmp/healthy
        initialDelaySeconds: 3
        periodSeconds: 3
        failureThreshold: 2
EOF
```

```bash
kubectl apply -f live-demo.yaml
```

### Paso 7. Observar reinicio

```bash
kubectl get pod live-demo -n lab20 -w
```

Finaliza con `Ctrl+C`.

### Paso 8. Validar restartCount

```bash
kubectl get pod live-demo -n lab20 -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}'
```

Debe ser mayor que 0.

---

## Reto 3. Startup probe

### Paso 9. Crear aplicación de arranque lento

```bash
cat > slow-start.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: slow-start
  namespace: lab20
spec:
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command:
        - sh
        - -c
        - |
          sleep 20
          touch /tmp/started
          while true; do sleep 30; done
      startupProbe:
        exec:
          command:
            - test
            - -f
            - /tmp/started
        periodSeconds: 2
        failureThreshold: 15
      readinessProbe:
        exec:
          command:
            - test
            - -f
            - /tmp/started
        periodSeconds: 3
      livenessProbe:
        exec:
          command:
            - test
            - -f
            - /tmp/started
        periodSeconds: 5
EOF
```

```bash
kubectl apply -f slow-start.yaml
```

### Paso 10. Validar arranque sin reinicios

```bash
kubectl get pod slow-start -n lab20 -w
```

Cuando llegue a `1/1`, termina con `Ctrl+C`.

```bash
kubectl get pod slow-start -n lab20 -o jsonpath='Ready={.status.containerStatuses[0].ready} Restarts={.status.containerStatuses[0].restartCount}{"\n"}'
```

**Resultado esperado:** `Ready=true` y `Restarts=0`.

---

## Limpieza

```bash
kubectl delete namespace lab20 --wait=true
```
