# Solución del reto — Práctica 14: Configuración de aplicaciones con ConfigMaps

## Alcance

Este solucionario cubre únicamente el reto de consolidación de ConfigMaps.

El objetivo es demostrar dos formas comunes de consumir configuración:

- variables de entorno;
- volumen proyectado.

También se valida cómo cambia el comportamiento cuando se actualiza el ConfigMap.

---

## Solución del reto

### Paso 1. Crear el ConfigMap

```bash
kubectl create configmap app-config -n lab14 \
  --from-literal=APP_ENV=qa \
  --from-literal=APP_COLOR=green
```

**Resultado esperado:**

```text
configmap/app-config created
```

---

### Paso 2. Crear un Pod que use variables de entorno

```bash
cat > env-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: env-app
  namespace: lab14
spec:
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command: ["sh", "-c", "env | grep '^APP_' && sleep 3600"]
      envFrom:
        - configMapRef:
            name: app-config
EOF
```

```bash
kubectl apply -f env-pod.yaml
```

---

### Paso 3. Validar variables

```bash
kubectl exec -n lab14 env-app -- env | grep '^APP_'
```

**Resultado esperado:**

```text
APP_ENV=qa
APP_COLOR=green
```

---

## Consumir ConfigMap como volumen

### Paso 4. Crear un Pod con volumen proyectado

```bash
cat > volume-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: volume-app
  namespace: lab14
spec:
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: config
          mountPath: /etc/app-config
          readOnly: true
  volumes:
    - name: config
      configMap:
        name: app-config
EOF
```

```bash
kubectl apply -f volume-pod.yaml
```

---

### Paso 5. Validar archivos montados

```bash
kubectl exec -n lab14 volume-app -- ls -l /etc/app-config
```

```bash
kubectl exec -n lab14 volume-app -- cat /etc/app-config/APP_COLOR
```

**Resultado esperado:**

```text
green
```

---

## Actualizar la configuración

### Paso 6. Cambiar el ConfigMap

```bash
kubectl create configmap app-config -n lab14 \
  --from-literal=APP_ENV=qa \
  --from-literal=APP_COLOR=blue \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Resultado esperado:** `app-config` queda actualizado.

---

### Paso 7. Comprobar la variable de entorno existente

```bash
kubectl exec -n lab14 env-app -- env | grep '^APP_COLOR='
```

**Resultado esperado:** el Pod existente continúa mostrando:

```text
APP_COLOR=green
```

Las variables de entorno se establecen al crear el container.

---

### Paso 8. Recrear el Pod que usa envFrom

```bash
kubectl delete pod env-app -n lab14
```

```bash
kubectl apply -f env-pod.yaml
```

---

### Paso 9. Validar el nuevo valor

```bash
kubectl exec -n lab14 env-app -- env | grep '^APP_COLOR='
```

**Resultado esperado:**

```text
APP_COLOR=blue
```

---

### Paso 10. Validar el volumen proyectado

Después de permitir que kubelet actualice el volumen, ejecuta:

```bash
kubectl exec -n lab14 volume-app -- cat /etc/app-config/APP_COLOR
```

**Resultado esperado:** el archivo termina reflejando:

```text
blue
```

---

## Validación final

El reto está resuelto cuando:

- el ConfigMap se consume como variable de entorno;
- el ConfigMap se consume como volumen;
- actualizar el ConfigMap no cambia una variable de entorno ya cargada;
- recrear el Pod permite consumir el nuevo valor;
- el volumen proyectado puede reflejar posteriormente la actualización.

---

## Limpieza

```bash
kubectl delete namespace lab14 --wait=true
```

---

## Resumen

```text
ConfigMap
 ├── env/envFrom
 │     └── valor cargado al crear container
 │
 └── volume
       └── archivo proyectado actualizable
```

El reto demuestra que la forma de consumir un ConfigMap cambia también la forma en que una actualización llega a la aplicación.
