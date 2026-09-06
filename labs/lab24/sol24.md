# Solución del reto — Práctica 24: Exposición interna con Service ClusterIP

## Alcance

Este solucionario cubre los retos de la Práctica 24 relacionados con:

- `Service` tipo `ClusterIP`
- selector
- `port`
- `targetPort`
- EndpointSlice
- DNS interno

---

## Reto 1. Corregir un Service sin endpoints

El Deployment `catalog` utiliza Pods con:

```text
app=catalog
```

pero el Service fue configurado con:

```text
app=catalog-api
```

---

### Paso 1. Revisar los labels de los Pods

```bash
kubectl get pods -n lab24 --show-labels
```

Busca los Pods de `catalog`.

---

### Paso 2. Revisar el selector del Service

```bash
kubectl get service catalog -n lab24 -o jsonpath='{.spec.selector}{"\n"}'
```

**Resultado esperado:** el selector incorrecto contiene `app:catalog-api`.

---

### Paso 3. Revisar EndpointSlices

```bash
kubectl get endpointslices -n lab24 -l kubernetes.io/service-name=catalog
```

**Resultado esperado:** no existen backends útiles porque el selector no coincide con los Pods.

---

### Paso 4. Corregir el selector

```bash
kubectl patch service catalog -n lab24 -p '{"spec":{"selector":{"app":"catalog"}}}'
```

**Resultado esperado:**

```text
service/catalog patched
```

---

## Reto 2. Corregir `targetPort`

El Service utiliza:

```text
port: 9000
targetPort: 8080
```

pero NGINX escucha en el puerto 80.

---

### Paso 5. Revisar el Service

```bash
kubectl get service catalog -n lab24 -o yaml
```

---

### Paso 6. Corregir `targetPort`

```bash
kubectl patch service catalog -n lab24 -p '{"spec":{"ports":[{"port":9000,"targetPort":80}]}}'
```

**Resultado esperado:** el Service conserva `port: 9000`, pero dirige el tráfico a `targetPort: 80`.

---

### Paso 7. Validar EndpointSlices

```bash
kubectl get endpointslices -n lab24 -l kubernetes.io/service-name=catalog
```

**Resultado esperado:** aparecen direcciones de Pods backend.

---

## Reto 3. Validar acceso desde un cliente

### Paso 8. Probar resolución DNS

Desde el Pod cliente definido por la práctica:

```bash
kubectl exec -n lab24 client -- nslookup catalog
```

**Resultado esperado:** `catalog` resuelve a la IP ClusterIP del Service.

---

### Paso 9. Probar acceso por nombre

```bash
kubectl exec -n lab24 client -- wget -qO- http://catalog:9000
```

**Resultado esperado:** responde NGINX.

---

## Reto 4. Crear `api-internal`

### Paso 10. Crear Deployment y Service

```bash
cat > api-internal.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-internal
  namespace: lab24
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-internal
  template:
    metadata:
      labels:
        app: api-internal
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
  name: api-internal
  namespace: lab24
spec:
  selector:
    app: api-internal
  ports:
    - port: 8080
      targetPort: 80
EOF
```

```bash
kubectl apply -f api-internal.yaml
```

---

### Paso 11. Validar acceso interno

```bash
kubectl exec -n lab24 client -- wget -qO- http://api-internal:8080
```

**Resultado esperado:** responde NGINX a través del Service.

---

## Validación final

```bash
kubectl get service -n lab24
```

```bash
kubectl get endpointslices -n lab24
```

```bash
kubectl get pods -n lab24 --show-labels
```

El reto queda resuelto cuando:

- los selectors coinciden con los labels;
- `targetPort` coincide con el puerto real del contenedor;
- EndpointSlices contienen backends;
- DNS interno resuelve correctamente;
- el cliente accede por nombre de Service.

---

## Limpieza

```bash
kubectl delete namespace lab24 --wait=true
```
