# Solución del reto — Práctica 25: Exposición externa básica

## Alcance

Este solucionario cubre los retos de la Práctica 25 relacionados con:

- `NodePort`
- selector
- EndpointSlice
- `port`
- `targetPort`
- `nodePort`
- acceso externo al clúster kind

> En este entorno kind sobre Docker Desktop no se asume que `localhost:<nodePort>` funcione sin `extraPortMappings`. La validación externa se realiza desde un contenedor conectado a la red Docker `kind`.

---

## Reto 1. Corregir el Service `shop`

Los Pods utilizan:

```text
app=shop
```

pero el Service fue creado con:

```text
app=shop-web
```

Además, NGINX escucha en el puerto 80 y el Service apunta inicialmente a `targetPort: 8080`.

---

### Paso 1. Revisar Pods y labels

```bash
kubectl get pods -n lab25 --show-labels
```

---

### Paso 2. Revisar el Service

```bash
kubectl get service shop -n lab25 -o yaml
```

---

### Paso 3. Corregir el selector

```bash
kubectl patch service shop -n lab25 -p '{"spec":{"selector":{"app":"shop"}}}'
```

---

### Paso 4. Validar EndpointSlices

```bash
kubectl get endpointslices -n lab25 -l kubernetes.io/service-name=shop
```

**Resultado esperado:** ahora aparecen backends.

---

### Paso 5. Corregir `targetPort`

Suponiendo que el Service debe conservar:

```text
port: 9000
nodePort: 30082
```

corrige únicamente el destino:

```bash
kubectl patch service shop -n lab25 -p '{"spec":{"ports":[{"port":9000,"targetPort":80,"nodePort":30082}]}}'
```

---

## Reto 2. Validar acceso externo

### Paso 6. Consultar los nodos kind

```bash
docker ps --format '{{.Names}}' | grep '^ckad-'
```

**Resultado esperado:** aparecen `ckad-control-plane`, `ckad-worker` y `ckad-worker2`.

---

### Paso 7. Probar `shop` desde la red Docker kind

```bash
docker run --rm --network kind busybox:1.38.0-musl wget -qO- http://ckad-control-plane:30082
```

**Resultado esperado:** responde NGINX.

---

## Reto 3. Crear `public-api`

### Paso 8. Crear Deployment y Service NodePort

```bash
cat > public-api.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: public-api
  namespace: lab25
spec:
  replicas: 2
  selector:
    matchLabels:
      app: public-api
  template:
    metadata:
      labels:
        app: public-api
    spec:
      containers:
        - name: nginx
          image: nginx:1.31.4-alpine3.24-slim
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: public-api
  namespace: lab25
spec:
  type: NodePort
  selector:
    app: public-api
  ports:
    - port: 8080
      targetPort: 80
      nodePort: 30083
EOF
```

```bash
kubectl apply -f public-api.yaml
```

---

### Paso 9. Validar Kubernetes

```bash
kubectl get service public-api -n lab25
```

```bash
kubectl get endpointslices -n lab25 -l kubernetes.io/service-name=public-api
```

---

### Paso 10. Validar acceso externo

```bash
docker run --rm --network kind busybox:1.38.0-musl wget -qO- http://ckad-control-plane:30083
```

**Resultado esperado:** NGINX responde desde el Service `public-api`.

---

## Validación final

El reto queda resuelto cuando:

- selector y labels coinciden;
- EndpointSlices contienen los Pods;
- `targetPort` apunta al puerto real del contenedor;
- NodePort queda asignado correctamente;
- el servicio responde desde un cliente externo conectado a la red Docker `kind`.

---

## Limpieza

```bash
kubectl delete namespace lab25 --wait=true
```

Con esto también se liberan los `nodePort` utilizados por la práctica.
