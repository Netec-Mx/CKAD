# Solución del reto — Práctica 15: Manejo de información sensible con Secrets

## Alcance

Este solucionario cubre únicamente el reto de consolidación de `Secret`.

El objetivo es:

- crear un Secret;
- consumir valores mediante variables de entorno;
- montar un Secret como volumen;
- rotar un valor;
- comprobar la diferencia entre env y volumen;
- evitar mostrar información sensible innecesariamente.

> Importante: Base64 no equivale a cifrado. Un Secret de Kubernetes requiere controles de acceso y protección adicional del almacenamiento para considerarse seguro.

---

## Solución del reto

### Paso 1. Crear el Secret

```bash
kubectl create secret generic app-secret -n lab15 \
  --from-literal=DB_USER=appuser \
  --from-literal=DB_PASSWORD='InitialPass123!'
```

**Resultado esperado:**

```text
secret/app-secret created
```

---

### Paso 2. Crear un Pod que consuma el Secret mediante env

```bash
cat > secret-env-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-app
  namespace: lab15
spec:
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command: ["sh", "-c", "sleep 3600"]
      env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: DB_USER
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: DB_PASSWORD
EOF
```

```bash
kubectl apply -f secret-env-pod.yaml
```

---

### Paso 3. Validar únicamente el usuario

Para evitar imprimir la contraseña:

```bash
kubectl exec -n lab15 secret-env-app -- sh -c 'test "$DB_USER" = "appuser" && echo "DB_USER cargado correctamente"'
```

**Resultado esperado:**

```text
DB_USER cargado correctamente
```

---

## Montar el Secret como volumen

### Paso 4. Crear el Pod

```bash
cat > secret-volume-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-app
  namespace: lab15
spec:
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: secrets
          mountPath: /var/run/app-secrets
          readOnly: true
  volumes:
    - name: secrets
      secret:
        secretName: app-secret
EOF
```

```bash
kubectl apply -f secret-volume-pod.yaml
```

---

### Paso 5. Validar archivos sin mostrar contraseña

```bash
kubectl exec -n lab15 secret-volume-app -- ls -l /var/run/app-secrets
```

**Resultado esperado:** aparecen archivos correspondientes a `DB_USER` y `DB_PASSWORD`.

---

## Rotar el Secret

### Paso 6. Actualizar el valor sensible

```bash
kubectl create secret generic app-secret -n lab15 \
  --from-literal=DB_USER=appuser \
  --from-literal=DB_PASSWORD='RotatedPass456!' \
  --dry-run=client -o yaml | kubectl apply -f -
```

**Resultado esperado:** `secret/app-secret configured`.

---

### Paso 7. Comprobar que el Pod con env no se actualiza automáticamente

Obtén un hash del valor cargado, sin imprimirlo:

```bash
kubectl exec -n lab15 secret-env-app -- sh -c 'printf %s "$DB_PASSWORD" | sha256sum'
```

Guarda mentalmente o compara el hash si es necesario.

La variable del proceso continúa siendo la que existía cuando se creó el container.

---

### Paso 8. Recrear el Pod con env

```bash
kubectl delete pod secret-env-app -n lab15
```

```bash
kubectl apply -f secret-env-pod.yaml
```

**Resultado esperado:** el nuevo Pod carga el valor rotado.

---

### Paso 9. Validar el Secret montado

Sin mostrar el contenido, comprueba que el archivo existe y tiene datos:

```bash
kubectl exec -n lab15 secret-volume-app -- sh -c 'test -s /var/run/app-secrets/DB_PASSWORD && echo "Secret montado disponible"'
```

**Resultado esperado:**

```text
Secret montado disponible
```

Los Secrets proyectados como volumen pueden actualizarse posteriormente por kubelet.

---

## Validación final

```bash
kubectl get secret app-secret -n lab15
```

```bash
kubectl get pods -n lab15
```

El reto queda resuelto cuando:

- existe `app-secret`;
- la aplicación consume claves con `secretKeyRef`;
- otro Pod consume el Secret como volumen;
- se realiza una rotación;
- el Pod que usa variables de entorno necesita recrearse para cargar el nuevo valor;
- el Secret montado permanece disponible como archivo proyectado;
- la contraseña no se imprime innecesariamente en terminal.

---

## Limpieza

```bash
kubectl delete namespace lab15 --wait=true
```

**Resultado esperado:** se eliminan Pods, Secret y demás recursos del laboratorio.

---

## Resumen

```text
Secret
 ├── secretKeyRef / envFrom
 │      └── se carga al crear el container
 │
 └── volume
        └── archivo proyectado
```

La rotación debe diseñarse teniendo en cuenta cómo consume el secreto cada aplicación. Además, `data` codificado en Base64 no constituye cifrado.
