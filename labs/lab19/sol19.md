# Solución del reto — Práctica 19: Consumo básico de CRD desde kubectl

## Alcance

El CRD `AppConfig` ya fue instalado en la parte guiada.

Debes descubrir y consumir:

- API group: `training.ckad.io`
- versión: `v1`
- kind: `AppConfig`
- plural: `appconfigs`
- short name: `acfg`
- scope: Namespaced

Campos requeridos:

- `replicas`: integer, 1–10
- `environment`: development | staging | production
- `featureEnabled`: boolean

---

## Reto 1. Descubrir la API

### Paso 1. Encontrar el recurso

```bash
kubectl api-resources | grep -i appconfig
```

**Resultado esperado:** aparece `appconfigs`, short name `acfg`, grupo `training.ckad.io/v1`.

### Paso 2. Consultar el esquema

```bash
kubectl explain appconfig
```

```bash
kubectl explain appconfig.spec
```

```bash
kubectl explain appconfig.spec.replicas
```

```bash
kubectl explain appconfig.spec.environment
```

```bash
kubectl explain appconfig.spec.featureEnabled
```

---

## Reto 2. Crear `frontend`

### Paso 3. Crear el Custom Resource

```bash
cat > frontend-appconfig.yaml <<'EOF'
apiVersion: training.ckad.io/v1
kind: AppConfig
metadata:
  name: frontend
  namespace: lab19
spec:
  replicas: 3
  environment: staging
  featureEnabled: true
EOF
```

```bash
kubectl apply -f frontend-appconfig.yaml
```

### Paso 4. Consultarlo

```bash
kubectl get appconfig frontend -n lab19
```

```bash
kubectl get acfg frontend -n lab19 -o yaml
```

---

## Reto 3. Modificar el recurso

### Paso 5. Cambiar replicas a 5

```bash
kubectl patch appconfig frontend -n lab19 --type=merge -p '{"spec":{"replicas":5}}'
```

### Paso 6. Validar

```bash
kubectl get appconfig frontend -n lab19 -o jsonpath='{.spec.replicas}{"\n"}'
```

**Resultado esperado:**

```text
5
```

---

## Reto 4. Reconstruir un recurso sin abrir el CRD

### Paso 7. Crear `backend`

```bash
cat > backend-appconfig.yaml <<'EOF'
apiVersion: training.ckad.io/v1
kind: AppConfig
metadata:
  name: backend
  namespace: lab19
spec:
  replicas: 2
  environment: production
  featureEnabled: false
EOF
```

```bash
kubectl apply -f backend-appconfig.yaml
```

### Paso 8. Validar ambos objetos

```bash
kubectl get appconfigs -n lab19
```

**Resultado esperado:** aparecen `frontend` y `backend`.

---

## Validar alcance

### Paso 9. Confirmar que los AppConfig son namespaced

```bash
kubectl api-resources | grep -i appconfig
```

La columna `NAMESPACED` debe indicar `true`.

### Paso 10. Confirmar que el CRD es cluster-scoped

```bash
kubectl get crd appconfigs.training.ckad.io
```

---

## Limpieza

Primero elimina las instancias:

```bash
kubectl delete namespace lab19 --wait=true
```

Después elimina el CRD didáctico:

```bash
kubectl delete crd appconfigs.training.ckad.io
```

La clave es distinguir el ciclo de vida del CRD cluster-scoped de sus instancias namespaced.
