# Solución del reto — Práctica 12: Estrategia canary

## Alcance

Este solucionario cubre únicamente el reto de consolidación de Canary.

El objetivo es mantener dos versiones detrás del mismo `Service` y variar progresivamente la proporción de réplicas.

> Importante: un Service estándar de Kubernetes no implementa porcentajes de tráfico exactos. La cantidad de réplicas solo aproxima la exposición relativa de cada versión.

---

## Solución del reto

### Paso 1. Crear la versión estable

```bash
cat > stable.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-stable
  namespace: lab12
spec:
  replicas: 4
  selector:
    matchLabels:
      app: web
      track: stable
  template:
    metadata:
      labels:
        app: web
        track: stable
    spec:
      containers:
        - name: nginx
          image: nginx:1.31.4-alpine3.24-slim
EOF
```

```bash
kubectl apply -f stable.yaml
```

---

### Paso 2. Crear Canary

```bash
cat > canary.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-canary
  namespace: lab12
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
      track: canary
  template:
    metadata:
      labels:
        app: web
        track: canary
    spec:
      containers:
        - name: nginx
          image: nginx:1.32.0-alpine
EOF
```

```bash
kubectl apply -f canary.yaml
```

---

### Paso 3. Crear un Service común

```bash
cat > service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: lab12
spec:
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
EOF
```

```bash
kubectl apply -f service.yaml
```

**Resultado esperado:** el Service selecciona Pods Stable y Canary porque ambos comparten `app=web`.

---

### Paso 4. Validar distribución inicial

```bash
kubectl get pods -n lab12 -l app=web -L track
```

**Resultado esperado:**

- 4 Pods `stable`
- 1 Pod `canary`

---

## Aumentar progresivamente Canary

### Paso 5. Escalar Canary a 2

```bash
kubectl scale deployment web-canary -n lab12 --replicas=2
```

**Resultado esperado:** quedan 4 Stable y 2 Canary.

---

### Paso 6. Validar endpoints

```bash
kubectl get endpointslices -n lab12 -l kubernetes.io/service-name=web
```

**Resultado esperado:** el Service dispone de endpoints correspondientes a ambas versiones.

---

### Paso 7. Aumentar Canary y reducir Stable

```bash
kubectl scale deployment web-stable -n lab12 --replicas=2
```

```bash
kubectl scale deployment web-canary -n lab12 --replicas=4
```

**Resultado esperado:** quedan 2 Stable y 4 Canary.

---

### Paso 8. Confirmar el estado

```bash
kubectl get deployments -n lab12
```

**Resultado esperado:** `web-stable` tiene 2 réplicas y `web-canary` 4.

---

## Recuperación

### Paso 9. Reducir Canary

```bash
kubectl scale deployment web-canary -n lab12 --replicas=0
```

---

### Paso 10. Restaurar Stable

```bash
kubectl scale deployment web-stable -n lab12 --replicas=4
```

**Resultado esperado:** todo el conjunto de endpoints vuelve a corresponder a Stable.

---

## Validación final

```bash
kubectl get pods -n lab12 -l app=web -L track
```

El reto queda resuelto cuando:

- Stable y Canary pueden coexistir.
- el Service selecciona ambas versiones.
- las réplicas pueden ajustarse progresivamente.
- Canary puede retirarse sin modificar el Service.
- Stable puede recuperarse rápidamente.

---

## Limpieza

```bash
kubectl delete namespace lab12 --wait=true
```

---

## Resumen

```text
Service app=web
     ↓
Stable Pods + Canary Pods
```

Canary permite introducir una versión nueva gradualmente. Con un Service estándar, la proporción de réplicas es una aproximación y no una garantía de porcentaje exacto de tráfico.
