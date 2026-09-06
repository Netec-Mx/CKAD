# Solución del reto — Práctica 16: ServiceAccount y permisos mínimos

## Alcance

Este solucionario cubre las tareas de reto de la Práctica 16.

La meta es aplicar mínimo privilegio con:

- `ServiceAccount`
- `Role`
- `RoleBinding`
- asociación del ServiceAccount a un Pod
- validación con `kubectl auth can-i`
- corrección de permisos excesivos

---

## Reto 1. Crear `inventory-sa` con lectura de Pods

### Paso 1. Crear el ServiceAccount

```bash
kubectl create serviceaccount inventory-sa -n lab16
```

**Resultado esperado:**

```text
serviceaccount/inventory-sa created
```

### Paso 2. Crear el Role

```bash
cat > inventory-role.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: inventory-reader
  namespace: lab16
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
EOF
```

```bash
kubectl apply -f inventory-role.yaml
```

### Paso 3. Crear el RoleBinding

```bash
cat > inventory-binding.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: inventory-reader-binding
  namespace: lab16
subjects:
  - kind: ServiceAccount
    name: inventory-sa
    namespace: lab16
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: inventory-reader
EOF
```

```bash
kubectl apply -f inventory-binding.yaml
```

### Paso 4. Validar permisos permitidos

```bash
kubectl auth can-i get pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
```

```bash
kubectl auth can-i list pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
```

**Resultado esperado:**

```text
yes
yes
```

### Paso 5. Validar permisos denegados

```bash
kubectl auth can-i create pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
```

```bash
kubectl auth can-i delete pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
```

**Resultado esperado:**

```text
no
no
```

---

## Reto 2. Asociar la identidad a un Pod

### Paso 6. Crear un Pod que use `inventory-sa`

```bash
cat > inventory-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: inventory-client
  namespace: lab16
spec:
  serviceAccountName: inventory-sa
  containers:
    - name: client
      image: busybox:1.38.0-musl
      command: ["sh", "-c", "sleep 3600"]
EOF
```

```bash
kubectl apply -f inventory-pod.yaml
```

### Paso 7. Validar el ServiceAccount efectivo

```bash
kubectl get pod inventory-client -n lab16 -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

**Resultado esperado:**

```text
inventory-sa
```

---

## Reto 3. Corregir permisos excesivos

El estado correcto debe permitir únicamente lectura de `pods` y `configmaps`, sin modificar ninguno de los dos recursos.

### Paso 8. Ajustar el Role

```bash
cat > inventory-role.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: inventory-reader
  namespace: lab16
rules:
  - apiGroups: [""]
    resources:
      - pods
      - configmaps
    verbs:
      - get
      - list
EOF
```

```bash
kubectl apply -f inventory-role.yaml
```

### Paso 9. Validar lectura de ConfigMaps

```bash
kubectl auth can-i get configmaps --as=system:serviceaccount:lab16:inventory-sa -n lab16
```

```bash
kubectl auth can-i list configmaps --as=system:serviceaccount:lab16:inventory-sa -n lab16
```

**Resultado esperado:**

```text
yes
yes
```

### Paso 10. Confirmar que modificar ConfigMaps sigue prohibido

```bash
kubectl auth can-i create configmaps --as=system:serviceaccount:lab16:inventory-sa -n lab16
```

```bash
kubectl auth can-i delete configmaps --as=system:serviceaccount:lab16:inventory-sa -n lab16
```

**Resultado esperado:**

```text
no
no
```

### Paso 11. Confirmar aislamiento al namespace

```bash
kubectl auth can-i list pods --as=system:serviceaccount:lab16:inventory-sa -n default
```

**Resultado esperado:**

```text
no
```

---

## Validación final

```bash
kubectl get serviceaccount,role,rolebinding -n lab16
```

El reto queda resuelto cuando:

- `inventory-sa` existe.
- puede `get` y `list` Pods.
- puede `get` y `list` ConfigMaps.
- no puede crear, modificar o eliminar esos recursos.
- el Pod usa `inventory-sa`.
- los permisos no se extienden a otros namespaces.

---

## Limpieza

```bash
kubectl delete namespace lab16 --wait=true
```
