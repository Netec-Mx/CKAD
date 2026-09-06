# Solución del reto — Práctica 27: Restricción de tráfico con NetworkPolicy

## Alcance

Este solucionario cubre los retos de NetworkPolicy ejecutados sobre el clúster temporal `ckad-netpol` con Calico.

El clúster principal `ckad` no debe eliminarse.

---

## Reto 1. Default deny y cliente autorizado

### Paso 1. Aplicar default deny a `web`

```bash
cat > web-deny.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-default-deny
  namespace: lab27
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Ingress
EOF
```

```bash
kubectl apply -f web-deny.yaml
```

---

### Paso 2. Permitir solo `allowed-client`

```bash
cat > web-allow-client.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-allow-client
  namespace: lab27
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              access: allowed
      ports:
        - protocol: TCP
          port: 80
EOF
```

```bash
kubectl apply -f web-allow-client.yaml
```

---

### Paso 3. Validar cliente permitido

```bash
kubectl exec -n lab27 allowed-client -- wget -qO- --timeout=3 http://web
```

**Resultado esperado:** responde.

---

### Paso 4. Validar cliente bloqueado

```bash
kubectl exec -n lab27 blocked-client -- wget -qO- --timeout=3 http://web
```

**Resultado esperado:** timeout o fallo de conexión.

---

## Reto 2. Permitir por namespace

El namespace autorizado debe tener:

```text
team=trusted
```

---

### Paso 5. Etiquetar namespace confiable

```bash
kubectl label namespace lab27-trusted team=trusted --overwrite
```

---

### Paso 6. Crear política por namespaceSelector

```bash
cat > allow-trusted-ns.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-trusted-namespaces
  namespace: lab27
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              team: trusted
      ports:
        - protocol: TCP
          port: 80
EOF
```

```bash
kubectl apply -f allow-trusted-ns.yaml
```

---

### Paso 7. Validar origen trusted

Desde el cliente del namespace `lab27-trusted`:

```bash
kubectl exec -n lab27-trusted trusted-client -- wget -qO- --timeout=3 http://web.lab27
```

**Resultado esperado:** responde.

---

## Reto 3. Backend accesible solo por frontend

### Paso 8. Crear política

```bash
cat > backend-policy.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-only-frontend
  namespace: lab27
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 80
EOF
```

```bash
kubectl apply -f backend-policy.yaml
```

---

### Paso 9. Validar frontend permitido

```bash
kubectl exec -n lab27 frontend -- wget -qO- --timeout=3 http://backend
```

---

### Paso 10. Validar monitor bloqueado

```bash
kubectl exec -n lab27 monitor -- wget -qO- --timeout=3 http://backend
```

**Resultado esperado:** falla.

---

## Reto 4. Matriz de producción

Requisitos:

```text
frontend -> backend : TCP 8080
backend  -> database: TCP 5432
otros orígenes      : bloqueados
```

---

### Paso 11. Crear política de backend

```bash
cat > prod-backend.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prod-backend
  namespace: prod
spec:
  podSelector:
    matchLabels:
      role: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 8080
EOF
```

```bash
kubectl apply -f prod-backend.yaml
```

---

### Paso 12. Crear política de database

```bash
cat > prod-database.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prod-database
  namespace: prod
spec:
  podSelector:
    matchLabels:
      role: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: backend
      ports:
        - protocol: TCP
          port: 5432
EOF
```

```bash
kubectl apply -f prod-database.yaml
```

---

## Validación final

El reto queda resuelto cuando:

- default deny aísla los Pods seleccionados;
- allowed-client puede acceder y blocked-client no;
- namespaces `team=trusted` pueden ser autorizados;
- backend acepta solo frontend;
- monitor queda bloqueado;
- la matriz frontend → backend → database funciona solo en los puertos permitidos.

> Las NetworkPolicies son aditivas. Una nueva policy no reemplaza las anteriores; se combinan los permisos aplicables.

---

## Limpieza

Este laboratorio utiliza un clúster temporal.

Elimínalo:

```bash
kind delete cluster --name ckad-netpol
```

Después vuelve al clúster principal:

```bash
kubectl config use-context kind-ckad
```

**Resultado esperado:** el contexto activo vuelve a ser `kind-ckad`.

No elimines el clúster principal `ckad`.
