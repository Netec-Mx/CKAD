# Solución del reto — Práctica 21: Análisis de logs y eventos

## Reto 1. Filtrar logs

### Paso 1. Crear `api-logger`

```bash
cat > api-logger.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: api-logger
  namespace: lab21
spec:
  containers:
    - name: logger
      image: busybox:1.38.0-musl
      command:
        - sh
        - -c
        - |
          while true; do
            echo "INFO request accepted"
            sleep 1
            echo "WARNING latency high"
            sleep 1
            echo "ERROR backend unavailable"
            sleep 2
          done
EOF
```

```bash
kubectl apply -f api-logger.yaml
```

### Paso 2. Obtener muestra reciente

```bash
kubectl logs api-logger -n lab21 --tail=30
```

### Paso 3. Filtrar WARNING

```bash
kubectl logs api-logger -n lab21 --tail=30 | grep WARNING | tail -1
```

### Paso 4. Filtrar ERROR

```bash
kubectl logs api-logger -n lab21 --tail=30 | grep ERROR | tail -1
```

---

## Reto 2. Pod multicontenedor

### Paso 5. Crear `app-with-sidecar`

```bash
cat > app-with-sidecar.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sidecar
  namespace: lab21
spec:
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command: ["sh", "-c", "while true; do echo 'APP processing'; sleep 3; done"]
    - name: sidecar
      image: busybox:1.38.0-musl
      command: ["sh", "-c", "while true; do echo 'SIDECAR shipping logs'; sleep 3; done"]
EOF
```

```bash
kubectl apply -f app-with-sidecar.yaml
```

### Paso 6. Consultar logs del contenedor `app`

```bash
kubectl logs app-with-sidecar -n lab21 -c app --tail=5
```

### Paso 7. Consultar logs del `sidecar`

```bash
kubectl logs app-with-sidecar -n lab21 -c sidecar --tail=5
```

---

## Reto 3. Recuperar logs anteriores

### Paso 8. Crear un contenedor que reinicie

```bash
cat > crash-app.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: crash-app
  namespace: lab21
spec:
  restartPolicy: Always
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command:
        - sh
        - -c
        - echo "ERROR startup failed"; sleep 2; exit 1
EOF
```

```bash
kubectl apply -f crash-app.yaml
```

### Paso 9. Observar reinicios

```bash
kubectl get pod crash-app -n lab21
```

### Paso 10. Consultar logs actuales

```bash
kubectl logs crash-app -n lab21
```

### Paso 11. Consultar ejecución anterior

```bash
kubectl logs crash-app -n lab21 --previous
```

**Resultado esperado:** aparece `ERROR startup failed`.

---

## Reto 4. Diagnosticar ImagePullBackOff

### Paso 12. Crear un Pod con imagen inexistente

```bash
kubectl run broken-image -n lab21 --image=nginx:lab21-does-not-exist --restart=Never
```

### Paso 13. Revisar estado

```bash
kubectl get pod broken-image -n lab21
```

### Paso 14. Revisar eventos

```bash
kubectl describe pod broken-image -n lab21
```

```bash
kubectl get events -n lab21 --sort-by=.metadata.creationTimestamp
```

La evidencia principal será `ErrImagePull` / `ImagePullBackOff`.

### Paso 15. Corregir la imagen

```bash
kubectl set image pod/broken-image broken-image=nginx:1.31.4-alpine3.24-slim -n lab21
```

Si el nombre del contenedor difiere, consulta primero:

```bash
kubectl get pod broken-image -n lab21 -o jsonpath='{.spec.containers[0].name}{"\n"}'
```

### Paso 16. Validar recuperación

```bash
kubectl get pod broken-image -n lab21
```

---

## Limpieza

```bash
kubectl delete namespace lab21 --wait=true
```
