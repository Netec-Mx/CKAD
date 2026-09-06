# Solución del reto — Práctica 7: Personalización con Kustomize

## Alcance

Este solucionario cubre únicamente la **Tarea 5: Reto de consolidación con Kustomize** de la Práctica 7.

El objetivo es construir un nuevo overlay `qa` reutilizando la base existente y cumpliendo estos requisitos:

- Reutilizar `../../base`.
- Namespace final: `lab7-qa`.
- Prefijo de nombres: `qa-`.
- Label: `environment=qa`.
- Propagar el label a los selectores.
- Deployment `web` con 2 réplicas.
- No modificar ningún archivo dentro de `base/`.

---

## Solución — Tarea 5.1. Construir el overlay QA

### Paso 1. Crear el directorio del overlay

Desde `ckad-labs/workspace/lab7` ejecuta:

```bash
mkdir -p overlays/qa
```

Valida la estructura actual:

```bash
ls -R base overlays
```

**Resultado esperado:** existe `overlays/qa` y permanecen disponibles `base`, `overlays/dev` y `overlays/prod`.

---

### Paso 2. Crear `overlays/qa/kustomization.yaml`

Crea el archivo con la personalización requerida:

```bash
cat > overlays/qa/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: lab7-qa
namePrefix: qa-

labels:
  - pairs:
      environment: qa
    includeSelectors: true

replicas:
  - name: web
    count: 2
EOF
```

La solución reutiliza íntegramente la base. No necesita copiar `Deployment`, `Service` ni `ConfigMap`.

Puedes revisar el archivo con:

```bash
cat overlays/qa/kustomization.yaml
```

**Resultado esperado:** el overlay contiene únicamente las transformaciones necesarias para QA.

---

### Paso 3. Renderizar el overlay

Genera el YAML final sin aplicarlo todavía:

```bash
kubectl kustomize overlays/qa > qa-rendered.yaml
```

Comprueba las transformaciones principales:

```bash
grep -E 'namespace: lab7-qa|name: qa-|environment: qa|replicas: 2' qa-rendered.yaml
```

**Resultado esperado:** aparecen:

- `namespace: lab7-qa`
- nombres con prefijo `qa-`
- `environment: qa`
- `replicas: 2`

---

### Paso 4. Verificar que el selector también recibió el label QA

Comprueba específicamente los bloques relacionados con `environment`:

```bash
grep -n -A4 -B4 'environment: qa' qa-rendered.yaml
```

**Resultado esperado:** `environment: qa` aparece tanto en metadata/Pod template como en los selectores que Kustomize debe transformar.

La opción responsable es:

```yaml
includeSelectors: true
```

---

### Paso 5. Confirmar el ConfigMap generado

Busca el recurso ConfigMap en la salida renderizada:

```bash
grep -n -A8 '^kind: ConfigMap' qa-rendered.yaml
```

**Resultado esperado:** aparece un ConfigMap cuyo nombre comienza con algo similar a:

```text
qa-web-config-
```

seguido por el sufijo hash generado por Kustomize.

El Deployment debe utilizar automáticamente ese mismo nombre transformado.

---

## Solución — Tarea 5.2. Desplegar y validar el reto

### Paso 6. Crear el namespace QA

Kustomize asigna el namespace a los recursos, pero la base no contiene un objeto `Namespace`. Por eso debes crearlo antes del despliegue:

```bash
kubectl create namespace lab7-qa
```

**Resultado esperado:**

```text
namespace/lab7-qa created
```

---

### Paso 7. Aplicar el overlay QA

Despliega directamente desde el directorio Kustomize:

```bash
kubectl apply -k overlays/qa
```

**Resultado esperado:** Kubernetes crea el ConfigMap generado, el Service `qa-web` y el Deployment `qa-web`.

---

### Paso 8. Esperar la disponibilidad del Deployment

```bash
kubectl rollout status deployment/qa-web -n lab7-qa --timeout=60s
```

**Resultado esperado:**

```text
deployment "qa-web" successfully rolled out
```

---

### Paso 9. Validar el Deployment

```bash
kubectl get deployment qa-web -n lab7-qa
```

**Resultado esperado:** `qa-web` muestra dos réplicas deseadas y disponibles.

Comprueba específicamente el valor declarado:

```bash
kubectl get deployment qa-web -n lab7-qa -o jsonpath='Replicas={.spec.replicas}{"\n"}'
```

**Resultado esperado:**

```text
Replicas=2
```

---

### Paso 10. Validar los Pods mediante el label del ambiente

```bash
kubectl get pods -n lab7-qa -l environment=qa
```

**Resultado esperado:** aparecen dos Pods del Deployment `qa-web`, ambos en estado `Running` y `READY 1/1`.

---

### Paso 11. Validar el Service

```bash
kubectl get service qa-web -n lab7-qa
```

**Resultado esperado:** existe el Service `qa-web` de tipo `ClusterIP`.

Puedes comprobar su selector con:

```bash
kubectl get service qa-web -n lab7-qa -o jsonpath='{.spec.selector}{"\n"}'
```

**Resultado esperado:** el selector incluye los labels transformados correspondientes al ambiente QA.

---

### Paso 12. Validar el ConfigMap generado

```bash
kubectl get configmap -n lab7-qa
```

**Resultado esperado:** aparece un ConfigMap con nombre similar a:

```text
qa-web-config-<hash>
```

Comprueba que el Deployment referencia el ConfigMap generado:

```bash
kubectl get deployment qa-web -n lab7-qa -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef.name}{"\n"}'
```

**Resultado esperado:** se devuelve el nombre `qa-web-config-<hash>` existente en el namespace.

---

## Validación completa del reto

Ejecuta las mismas comprobaciones utilizadas por la práctica:

```bash
kubectl get deployment qa-web -n lab7-qa
```

```bash
kubectl get pods -n lab7-qa -l environment=qa
```

```bash
kubectl get service qa-web -n lab7-qa
```

```bash
kubectl get configmap -n lab7-qa
```

```bash
kubectl get deployment qa-web -n lab7-qa -o jsonpath='Replicas={.spec.replicas}{"\n"}'
```

El reto está resuelto correctamente si se cumple todo lo siguiente:

- `lab7-qa` existe.
- `qa-web` existe.
- `qa-web` tiene 2 réplicas.
- Los 2 Pods están Ready.
- Los Pods pueden localizarse mediante `environment=qa`.
- Existe el Service `qa-web`.
- Existe un ConfigMap generado por Kustomize.
- El Deployment referencia correctamente el ConfigMap generado.
- No se modificó ningún archivo dentro de `base/`.

---

## Solución final del overlay

El archivo esencial que resuelve el reto es:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: lab7-qa
namePrefix: qa-

labels:
  - pairs:
      environment: qa
    includeSelectors: true

replicas:
  - name: web
    count: 2
```

---

## Limpieza

Cuando hayas terminado las validaciones, elimina únicamente los namespaces utilizados en esta práctica:

```bash
kubectl delete namespace lab7-dev lab7-prod lab7-qa --ignore-not-found --wait=true
```

Comprueba que desaparecieron:

```bash
kubectl get namespace lab7-dev lab7-prod lab7-qa --ignore-not-found
```

**Resultado esperado:** no se muestran los namespaces.

Los directorios `base/` y `overlays/` permanecen dentro de `workspace/lab7` como material de estudio.

---

## Resumen de la solución

La clave del reto es no duplicar recursos. El overlay QA solo expresa diferencias:

```text
base
  ↓ reutilizada por
overlays/qa
  ├── namespace: lab7-qa
  ├── namePrefix: qa-
  ├── environment=qa
  └── replicas: 2
```

Kustomize toma los recursos definidos en `base/`, aplica estas transformaciones y produce los objetos finales `qa-web` y `qa-web-config-<hash>` sin alterar los manifiestos originales.
