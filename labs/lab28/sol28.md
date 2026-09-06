# Solución del reto — Práctica 28: Troubleshooting de conectividad

## Alcance

Este solucionario cubre los retos de troubleshooting de red de la Práctica 28.

Método recomendado:

```text
cliente
  ↓
DNS
  ↓
Service
  ↓
selector
  ↓
EndpointSlice
  ↓
port / targetPort
  ↓
readiness
  ↓
proceso dentro del Pod
```

---

## Reto 1. DNS incorrecto

El cliente intenta resolver un Service inexistente:

```text
inventory-api
```

pero el Service real se llama:

```text
inventory
```

---

### Paso 1. Validar Services

```bash
kubectl get service -n lab28-backend
```

---

### Paso 2. Probar el nombre incorrecto

```bash
kubectl exec -n lab28 client -- nslookup inventory-api.lab28-backend
```

**Resultado esperado:** falla la resolución.

---

### Paso 3. Probar el nombre correcto

```bash
kubectl exec -n lab28 client -- nslookup inventory.lab28-backend
```

**Resultado esperado:** resuelve correctamente.

También es válido el FQDN:

```text
inventory.lab28-backend.svc.cluster.local
```

---

## Reto 2. Service sin endpoints por selector

Los Pods utilizan:

```text
app=catalog
```

pero el Service selecciona:

```text
app=catalog-api
```

---

### Paso 4. Revisar Pods

```bash
kubectl get pods -n lab28 --show-labels
```

---

### Paso 5. Revisar selector

```bash
kubectl get service catalog -n lab28 -o jsonpath='{.spec.selector}{"\n"}'
```

---

### Paso 6. Revisar EndpointSlices

```bash
kubectl get endpointslices -n lab28 -l kubernetes.io/service-name=catalog
```

---

### Paso 7. Corregir selector

```bash
kubectl patch service catalog -n lab28 -p '{"spec":{"selector":{"app":"catalog"}}}'
```

---

### Paso 8. Validar recuperación

```bash
kubectl get endpointslices -n lab28 -l kubernetes.io/service-name=catalog
```

**Resultado esperado:** aparecen backends.

---

## Reto 3. `targetPort` incorrecto

El Service `payments` expone:

```text
port: 8080
```

pero inicialmente dirige a:

```text
targetPort: 8081
```

mientras NGINX escucha en 80.

---

### Paso 9. Revisar Service

```bash
kubectl get service payments -n lab28 -o yaml
```

---

### Paso 10. Corregir `targetPort`

```bash
kubectl patch service payments -n lab28 -p '{"spec":{"ports":[{"port":8080,"targetPort":80}]}}'
```

---

### Paso 11. Probar acceso

Desde el cliente definido por la práctica:

```bash
kubectl exec -n lab28 client -- wget -qO- --timeout=3 http://payments:8080
```

**Resultado esperado:** responde NGINX.

---

## Reto 4. Readiness defectuosa

Se introduce una readiness probe a:

```text
/healthz
```

que NGINX no sirve correctamente.

---

### Paso 12. Revisar estado

```bash
kubectl get pods -n lab28 -l app=payments
```

**Resultado esperado:** el Pod puede estar `Running`, pero `READY 0/1`.

---

### Paso 13. Revisar eventos de la probe

```bash
kubectl describe pod -n lab28 -l app=payments
```

---

### Paso 14. Corregir la ruta

```bash
kubectl patch deployment payments -n lab28 --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```

---

### Paso 15. Esperar recuperación

```bash
kubectl rollout status deployment/payments -n lab28 --timeout=60s
```

---

### Paso 16. Revisar EndpointSlices

```bash
kubectl get endpointslices -n lab28 -l kubernetes.io/service-name=payments -o yaml
```

Un endpoint no Ready puede seguir representado en EndpointSlice, pero con:

```text
conditions.ready: false
```

Lo importante es distinguir entre “existe endpoint” y “existe backend Ready utilizable”.

---

## Reto 5. Arquitectura segmentada frontend → api → database

La aplicación `database` escucha en:

```text
9000
```

pero el Service expone:

```text
port: 9090
```

y tiene un `targetPort` incorrecto.

---

### Paso 17. Revisar Service database

```bash
kubectl get service database -n lab28-backend -o yaml
```

---

### Paso 18. Revisar Pod backend

```bash
kubectl get pods -n lab28-backend -o wide
```

---

### Paso 19. Corregir `targetPort`

```bash
kubectl patch service database -n lab28-backend -p '{"spec":{"ports":[{"port":9090,"targetPort":9000}]}}'
```

---

### Paso 20. Validar EndpointSlice

```bash
kubectl get endpointslices -n lab28-backend -l kubernetes.io/service-name=database
```

---

### Paso 21. Probar la ruta

Desde el componente API:

```bash
kubectl exec -n lab28 deploy/api -- wget -qO- --timeout=3 http://database.lab28-backend:9090
```

**Resultado esperado:** la comunicación funciona después de corregir el `targetPort`.

---

## Validación final

El reto está resuelto cuando puedes diagnosticar cada capa en orden:

```text
DNS correcto
↓
Service existe
↓
selector coincide
↓
EndpointSlice tiene backend Ready
↓
port/targetPort correctos
↓
readiness correcta
↓
proceso escucha en el puerto esperado
```

No se requiere NetworkPolicy para explicar los fallos de esta práctica porque el clúster principal conserva su red original.

---

## Limpieza

```bash
kubectl delete namespace lab28 --wait=true
```

```bash
kubectl delete namespace lab28-backend --wait=true
```
