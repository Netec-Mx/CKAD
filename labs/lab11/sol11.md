# Solución del reto — Práctica 11: Estrategia blue/green

## Alcance

Este solucionario cubre únicamente el reto de consolidación de la estrategia Blue/Green.

El objetivo es mantener dos versiones simultáneas de una aplicación y cambiar el tráfico mediante el selector de un `Service`.

---

## Solución del reto

### Paso 1. Crear la versión Blue

```bash
cat > blue.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-blue
  namespace: lab11
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      version: blue
  template:
    metadata:
      labels:
        app: web
        version: blue
    spec:
      containers:
        - name: nginx
          image: nginx:1.31.4-alpine3.24-slim
          ports:
            - containerPort: 80
EOF
```

```bash
kubectl apply -f blue.yaml
```

**Resultado esperado:** `web-blue` queda disponible con tres réplicas.

---

### Paso 2. Crear la versión Green

```bash
cat > green.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-green
  namespace: lab11
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      version: green
  template:
    metadata:
      labels:
        app: web
        version: green
    spec:
      containers:
        - name: nginx
          image: nginx:1.32.0-alpine
          ports:
            - containerPort: 80
EOF
```

```bash
kubectl apply -f green.yaml
```

**Resultado esperado:** Blue y Green coexisten con tres Pods cada uno.

---

### Paso 3. Crear el Service apuntando inicialmente a Blue

```bash
cat > service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: lab11
spec:
  selector:
    app: web
    version: blue
  ports:
    - port: 80
      targetPort: 80
EOF
```

```bash
kubectl apply -f service.yaml
```

**Resultado esperado:** el Service selecciona únicamente los Pods Blue.

---

### Paso 4. Validar endpoints Blue

```bash
kubectl get endpointslices -n lab11 -l kubernetes.io/service-name=web
```

**Resultado esperado:** los endpoints corresponden únicamente a Pods con `version=blue`.

---

### Paso 5. Ejecutar el cutover a Green

```bash
kubectl patch service web -n lab11 -p '{"spec":{"selector":{"app":"web","version":"green"}}}'
```

**Resultado esperado:**

```text
service/web patched
```

---

### Paso 6. Validar endpoints Green

```bash
kubectl get endpointslices -n lab11 -l kubernetes.io/service-name=web
```

**Resultado esperado:** los endpoints ahora corresponden a Pods Green.

---

### Paso 7. Confirmar el selector activo

```bash
kubectl get service web -n lab11 -o jsonpath='{.spec.selector}{"\n"}'
```

**Resultado esperado:** aparece `version:green`.

---

## Simular recuperación

### Paso 8. Regresar el tráfico a Blue

```bash
kubectl patch service web -n lab11 -p '{"spec":{"selector":{"app":"web","version":"blue"}}}'
```

**Resultado esperado:** el Service vuelve a seleccionar Blue sin recrear los Deployments.

---

### Paso 9. Confirmar ambos ambientes

```bash
kubectl get deployments,pods -n lab11 -L version
```

**Resultado esperado:** Blue y Green continúan desplegados simultáneamente.

---

## Validación final

El reto está resuelto cuando:

- Blue y Green existen al mismo tiempo.
- cada versión mantiene sus Pods independientes.
- el Service puede cambiar de Blue a Green modificando solo su selector.
- es posible regresar a Blue sin reconstruir la aplicación.

---

## Limpieza

```bash
kubectl delete namespace lab11 --wait=true
```

---

## Resumen

```text
Blue Deployment ─┐
                 ├── Service ──► usuarios
Green Deployment ┘

selector version=blue
        ↓
cutover
        ↓
selector version=green
```

Blue/Green separa el despliegue de una nueva versión del momento en que recibe tráfico.
