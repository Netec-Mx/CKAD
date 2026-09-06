# Solución del reto — Práctica 18: Endurecimiento básico de Pods

## Alcance

El reto exige aplicar un perfil de mínimo privilegio con:

- `runAsNonRoot`
- UID/GID explícitos
- `allowPrivilegeEscalation: false`
- `privileged: false`
- `capabilities.drop: ALL`
- `readOnlyRootFilesystem: true`
- `emptyDir` para `/tmp`
- `seccompProfile: RuntimeDefault`

---

## Reto 1. Crear `api-secure`

### Paso 1. Crear el Pod endurecido

```bash
cat > api-secure.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: api-secure
  namespace: lab18
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command:
        - sh
        - -c
        - |
          echo "inicio" > /tmp/status.txt
          sleep 3600
      securityContext:
        privileged: false
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir: {}
EOF
```

```bash
kubectl apply -f api-secure.yaml
```

### Paso 2. Validar UID y GID

```bash
kubectl exec api-secure -n lab18 -- id
```

**Resultado esperado:** UID 1000 y GID 3000.

### Paso 3. Validar escritura en `/tmp`

```bash
kubectl exec api-secure -n lab18 -- cat /tmp/status.txt
```

**Resultado esperado:**

```text
inicio
```

### Paso 4. Validar que el root filesystem es de solo lectura

```bash
kubectl exec api-secure -n lab18 -- sh -c 'touch /root/test'
```

**Resultado esperado:** error de filesystem de solo lectura o permiso denegado.

### Paso 5. Validar configuración de seguridad

```bash
kubectl get pod api-secure -n lab18 -o yaml
```

Confirma:

```text
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 3000
seccompProfile:
  type: RuntimeDefault
allowPrivilegeEscalation: false
privileged: false
readOnlyRootFilesystem: true
drop:
- ALL
```

---

## Reto 2. Corregir un Pod inseguro

La solución final del Pod auditado debe quedar equivalente a:

```bash
cat > legacy-api-secure.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: legacy-api
  namespace: lab18
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: busybox:1.38.0-musl
      command:
        - sh
        - -c
        - |
          echo "legacy secured" > /tmp/app.log
          sleep 3600
      securityContext:
        privileged: false
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir: {}
EOF
```

```bash
kubectl delete pod legacy-api -n lab18 --ignore-not-found
```

```bash
kubectl apply -f legacy-api-secure.yaml
```

### Validación

```bash
kubectl get pod legacy-api -n lab18
```

```bash
kubectl exec legacy-api -n lab18 -- id
```

```bash
kubectl exec legacy-api -n lab18 -- cat /tmp/app.log
```

El reto queda resuelto cuando:

- no se ejecuta como root;
- no es privileged;
- no permite escalación;
- elimina todas las capabilities;
- usa seccomp RuntimeDefault;
- root filesystem es de solo lectura;
- `/tmp` sigue siendo escribible mediante `emptyDir`.

---

## Limpieza

```bash
kubectl delete namespace lab18 --wait=true
```
