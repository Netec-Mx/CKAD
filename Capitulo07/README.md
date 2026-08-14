# Publicar una aplicación con Argo CD usando manifiestos Kubernetes

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 55 minutos |
| **Complejidad** | Alta |
| **Nivel Bloom** | Aplicar |
| **Módulo** | 7 — Argo CD, Crossplane y Kafka en Kubernetes |

---

## Descripción General

En este laboratorio instalarás Argo CD 2.10.3 en un clúster minikube mediante Helm, crearás un repositorio Git local con manifiestos Kubernetes para la aplicación Guestbook, y definirás un recurso `Application` de Argo CD para sincronizar dichos manifiestos con el clúster. Experimentarás de primera mano los conceptos fundamentales de GitOps: sincronización manual, detección de drift (desviación de configuración) y sincronización automática.

---

## Objetivos de Aprendizaje

Al completar este laboratorio serás capaz de:

- [ ] Instalar Argo CD en un clúster Kubernetes usando Helm y acceder a su interfaz mediante port-forward
- [ ] Crear un repositorio Git local con manifiestos declarativos (Deployment, Service, Ingress) como fuente de verdad
- [ ] Definir y sincronizar un recurso `Application` de Argo CD apuntando al repositorio Git local
- [ ] Identificar y explicar los estados de sync (Synced/OutOfSync) y health (Healthy/Degraded/Progressing)
- [ ] Provocar drift de configuración y observar cómo Argo CD lo detecta y corrige con sincronización automática

---

## Prerrequisitos

### Conocimientos Requeridos

| Tema | Nivel |
|------|-------|
| Manifiestos Kubernetes (Deployment, Service, Ingress) | Intermedio |
| Helm (instalación de charts) | Básico |
| Git (init, add, commit) | Básico |
| kubectl (apply, get, describe, port-forward) | Intermedio |
| Concepto de GitOps (Git como fuente de verdad) | Conceptual |

### Acceso y Herramientas

- Clúster minikube operativo y limpio de recursos de labs anteriores
- Helm 3.14.2+ instalado y configurado
- Git 2.43.0 instalado con `user.name` y `user.email` configurados
- CLI `argocd` 2.10.3 instalado en `/usr/local/bin/argocd`
- Conexión a internet para descargar imágenes de contenedor y charts de Helm

---

## Entorno del Laboratorio

### Requisitos de Hardware

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU | 4 núcleos | 6 núcleos |
| RAM | 8 GB | 12 GB |
| Disco | 40 GB libres (SSD) | 50 GB libres |

### Software Requerido

| Herramienta | Versión |
|-------------|---------|
| minikube | 1.33.1 |
| kubectl | 1.30.2 |
| Helm | 3.14.2+ |
| Git | 2.43.0 |
| argocd CLI | 2.10.3 |
| Docker Engine | 26.1.4 |

### Configuración Inicial del Entorno

```bash
# Verificar que minikube está corriendo
minikube status

# Si no está corriendo, iniciarlo con recursos adecuados
minikube start --cpus=4 --memory=8192 --driver=docker

# Habilitar el addon de ingress (necesario para el Ingress de la app)
minikube addons enable ingress

# Verificar kubectl y contexto
kubectl cluster-info
kubectl get nodes

# Crear directorio de trabajo para este lab
mkdir -p ~/ckad-labs/lab07
cd ~/ckad-labs/lab07

# Verificar Helm
helm version --short

# Verificar Git
git --version
git config user.name
git config user.email

# Verificar argocd CLI
argocd version --client
```

---

## Instrucciones Paso a Paso

### Paso 1: Instalar Argo CD mediante Helm

**Objetivo:** Desplegar Argo CD 2.10.3 en el namespace `argocd` usando el chart de Helm oficial.

**Instrucciones:**

1. Crear el namespace dedicado para Argo CD:

```bash
kubectl create namespace argocd
```

2. Agregar el repositorio de Helm de Argo CD:

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

3. Instalar Argo CD con el chart versión 6.7.3:

```bash
helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 6.7.3 \
  --set server.service.type=ClusterIP \
  --set configs.params."server\.insecure"=true \
  --wait --timeout 300s
```

4. Verificar que todos los Pods de Argo CD están en estado Running:

```bash
kubectl get pods -n argocd
```

**Salida Esperada:**

```
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          2m
argocd-applicationset-controller-xxxxxxxxx-xxxxx    1/1     Running   0          2m
argocd-dex-server-xxxxxxxxx-xxxxx                   1/1     Running   0          2m
argocd-notifications-controller-xxxxxxxxx-xxxxx     1/1     Running   0          2m
argocd-redis-xxxxxxxxx-xxxxx                        1/1     Running   0          2m
argocd-repo-server-xxxxxxxxx-xxxxx                  1/1     Running   0          2m
argocd-server-xxxxxxxxx-xxxxx                       1/1     Running   0          2m
```

**Verificación:**

```bash
# Confirmar que el release de Helm está desplegado
helm list -n argocd

# Verificar los servicios creados
kubectl get svc -n argocd
```

---

### Paso 2: Acceder a Argo CD y Autenticarse

**Objetivo:** Establecer acceso al servidor de Argo CD mediante port-forward y autenticarse con la CLI.

**Instrucciones:**

1. Obtener la contraseña inicial del usuario `admin`:

```bash
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "Contraseña de admin: ${ARGOCD_PASSWORD}"
```

2. Iniciar port-forward al servicio del servidor de Argo CD en el puerto 8080:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PORT_FORWARD_PID=$!
echo "Port-forward PID: ${PORT_FORWARD_PID}"
```

3. Esperar unos segundos y autenticarse con la CLI de Argo CD:

```bash
sleep 3
argocd login localhost:8080 \
  --username admin \
  --password "${ARGOCD_PASSWORD}" \
  --insecure
```

4. Verificar la conexión:

```bash
argocd account get-user-info
```

**Salida Esperada:**

```
'admin' logged in successfully
Context 'localhost:8080' updated
```

```
LoggedIn: true
Username: admin
Issuer: argocd
Groups: 
```

**Verificación:**

```bash
# Listar clusters conocidos por Argo CD (debe mostrar el clúster in-cluster)
argocd cluster list
```

> **Nota:** El port-forward se ejecuta en segundo plano. Si necesitas reiniciarlo en algún momento, usa `kill ${PORT_FORWARD_PID}` y repite el comando de port-forward.

---

### Paso 3: Crear el Repositorio Git Local con Manifiestos

**Objetivo:** Crear un repositorio Git local que servirá como fuente de verdad para Argo CD, conteniendo los manifiestos de la aplicación Guestbook.

**Instrucciones:**

1. Crear la estructura del repositorio:

```bash
mkdir -p ~/gitops-repo/guestbook
cd ~/gitops-repo
git init
```

2. Crear el manifiesto del Deployment (`guestbook/deployment.yaml`):

```bash
cat > guestbook/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: guestbook-frontend
  namespace: lab29-guestbook
  labels:
    app: guestbook
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: guestbook
      tier: frontend
  template:
    metadata:
      labels:
        app: guestbook
        tier: frontend
    spec:
      containers:
      - name: frontend
        image: gcr.io/google-samples/gb-frontend:v5
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
EOF
```

3. Crear el manifiesto del Service (`guestbook/service.yaml`):

```bash
cat > guestbook/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: guestbook-frontend
  namespace: lab29-guestbook
  labels:
    app: guestbook
    tier: frontend
spec:
  type: ClusterIP
  selector:
    app: guestbook
    tier: frontend
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
EOF
```

4. Crear el manifiesto del Ingress (`guestbook/ingress.yaml`):

```bash
cat > guestbook/ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: guestbook-frontend
  namespace: lab29-guestbook
  labels:
    app: guestbook
    tier: frontend
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: guestbook.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: guestbook-frontend
            port:
              number: 80
EOF
```

5. Hacer commit de todos los manifiestos:

```bash
git add .
git commit -m "feat: agregar manifiestos iniciales de guestbook (Deployment, Service, Ingress)"
```

**Salida Esperada:**

```
Initialized empty Git repository in /home/user/gitops-repo/.git/
[main (root-commit) xxxxxxx] feat: agregar manifiestos iniciales de guestbook (Deployment, Service, Ingress)
 3 files changed, 82 insertions(+)
 create mode 100644 guestbook/deployment.yaml
 create mode 100644 guestbook/ingress.yaml
 create mode 100644 guestbook/service.yaml
```

**Verificación:**

```bash
# Verificar la estructura del repositorio
find ~/gitops-repo -name "*.yaml" | sort

# Verificar el historial de Git
git log --oneline
```

---

### Paso 4: Crear el Namespace Destino y el Recurso Application de Argo CD

**Objetivo:** Crear el namespace donde se desplegará la aplicación y definir el recurso `Application` de Argo CD con política de sincronización manual.

**Instrucciones:**

1. Crear el namespace destino:

```bash
kubectl create namespace lab29-guestbook
```

2. Crear el manifiesto del recurso Application de Argo CD:

```bash
cd ~/ckad-labs/lab07

cat > argocd-application.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: /home/user/gitops-repo
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: lab29-guestbook
  syncPolicy: {}
EOF
```

3. Aplicar el recurso Application:

```bash
kubectl apply -f argocd-application.yaml
```

4. Verificar que la aplicación fue creada en Argo CD:

```bash
argocd app get guestbook
```

**Salida Esperada:**

```
Name:               argocd/guestbook
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          lab29-guestbook
URL:                https://localhost:8080/applications/guestbook
Repo:               /home/user/gitops-repo
Target:             HEAD
Path:               guestbook
SyncWindow:         Sync Allowed
Sync Policy:        <none>
Sync Status:        OutOfSync
Health Status:      Missing
```

**Verificación:**

```bash
# La aplicación debe aparecer en estado OutOfSync porque aún no se ha sincronizado
argocd app list
```

> **Nota:** El estado `OutOfSync` y `Missing` es esperado en este punto. Los recursos definidos en Git aún no existen en el clúster porque la política de sincronización es manual.

---

### Paso 5: Ejecutar la Primera Sincronización Manual

**Objetivo:** Sincronizar manualmente la aplicación para que Argo CD despliegue los recursos definidos en Git al clúster.

**Instrucciones:**

1. Ejecutar la sincronización manual:

```bash
argocd app sync guestbook
```

2. Observar el progreso de la sincronización:

```bash
argocd app wait guestbook --health --timeout 120
```

3. Verificar el estado final de la aplicación:

```bash
argocd app get guestbook
```

**Salida Esperada:**

```
Name:               argocd/guestbook
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          lab29-guestbook
URL:                https://localhost:8080/applications/guestbook
Repo:               /home/user/gitops-repo
Target:             HEAD
Path:               guestbook
SyncWindow:         Sync Allowed
Sync Policy:        <none>
Sync Status:        Synced
Health Status:      Healthy

GROUP        KIND         NAMESPACE         NAME                STATUS  HEALTH   HOOK  MESSAGE
             Service      lab29-guestbook   guestbook-frontend  Synced  Healthy        service/guestbook-frontend created
apps         Deployment   lab29-guestbook   guestbook-frontend  Synced  Healthy        deployment.apps/guestbook-frontend created
networking.k8s.io  Ingress  lab29-guestbook  guestbook-frontend  Synced  Healthy        ingress.networking.k8s.io/guestbook-frontend created
```

4. Verificar que los recursos existen en el clúster:

```bash
kubectl get all -n lab29-guestbook
kubectl get ingress -n lab29-guestbook
```

**Salida Esperada:**

```
NAME                                      READY   STATUS    RESTARTS   AGE
pod/guestbook-frontend-xxxxxxxxx-xxxxx    1/1     Running   0          30s
pod/guestbook-frontend-xxxxxxxxx-xxxxx    1/1     Running   0          30s

NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/guestbook-frontend   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    30s

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/guestbook-frontend   2/2     2            2           30s

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/guestbook-frontend-xxxxxxxxx    2         2         2       30s
```

**Verificación:**

```bash
# Confirmar que los Pods están listos
kubectl get pods -n lab29-guestbook -o wide

# Verificar que el Deployment tiene 2 réplicas
kubectl get deployment guestbook-frontend -n lab29-guestbook \
  -o jsonpath='{.spec.replicas}{"\n"}'
```

---

### Paso 6: Provocar Drift y Observar la Detección de OutOfSync

**Objetivo:** Modificar un recurso directamente en el clúster (sin pasar por Git) para provocar drift de configuración y observar cómo Argo CD lo detecta.

**Instrucciones:**

1. Escalar el Deployment directamente con kubectl (sin modificar Git):

```bash
kubectl scale deployment guestbook-frontend -n lab29-guestbook --replicas=4
```

2. Verificar que el cambio se aplicó en el clúster:

```bash
kubectl get deployment guestbook-frontend -n lab29-guestbook \
  -o jsonpath='Réplicas actuales: {.spec.replicas}{"\n"}'
```

3. Esperar unos segundos y consultar el estado de la aplicación en Argo CD:

```bash
# Argo CD detecta el drift periódicamente (por defecto cada 3 minutos)
# Podemos forzar un refresh para ver el estado inmediatamente
argocd app get guestbook --refresh
```

4. Verificar el diff entre el estado deseado (Git) y el estado real (clúster):

```bash
argocd app diff guestbook
```

**Salida Esperada:**

Después del refresh, el estado debe mostrar:

```
Sync Status:        OutOfSync
Health Status:      Healthy
```

El comando `diff` mostrará algo similar a:

```
===== apps/Deployment lab29-guestbook/guestbook-frontend ======
...
<     replicas: 2
>     replicas: 4
...
```

5. Confirmar que Git sigue teniendo 2 réplicas (la fuente de verdad no cambió):

```bash
grep "replicas:" ~/gitops-repo/guestbook/deployment.yaml
```

**Salida Esperada:**

```
  replicas: 2
```

**Verificación:**

```bash
# El estado debe ser OutOfSync
argocd app get guestbook -o json | jq '.status.sync.status'
```

> **Concepto clave:** Argo CD detectó que el estado real del clúster (4 réplicas) difiere del estado declarado en Git (2 réplicas). Esto es **configuration drift** — exactamente el problema que GitOps resuelve.

---

### Paso 7: Restaurar el Estado Sincronizado Manualmente

**Objetivo:** Ejecutar una sincronización para que Argo CD restaure el estado del clúster al definido en Git, eliminando el drift.

**Instrucciones:**

1. Sincronizar la aplicación para revertir el drift:

```bash
argocd app sync guestbook
```

2. Verificar que el Deployment vuelve a tener 2 réplicas:

```bash
kubectl get deployment guestbook-frontend -n lab29-guestbook \
  -o jsonpath='Réplicas después de sync: {.spec.replicas}{"\n"}'
```

3. Confirmar el estado Synced/Healthy:

```bash
argocd app get guestbook
```

**Salida Esperada:**

```
Réplicas después de sync: 2
```

```
Sync Status:        Synced
Health Status:      Healthy
```

**Verificación:**

```bash
# Verificar que solo hay 2 Pods corriendo
kubectl get pods -n lab29-guestbook --no-headers | wc -l
```

El resultado debe ser `2`.

---

### Paso 8: Configurar Sincronización Automática (Auto-Sync)

**Objetivo:** Modificar la política de sincronización de la aplicación para que Argo CD corrija automáticamente cualquier drift futuro.

**Instrucciones:**

1. Actualizar el manifiesto de la Application con syncPolicy automático:

```bash
cd ~/ckad-labs/lab07

cat > argocd-application-autosync.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: /home/user/gitops-repo
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: lab29-guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=false
EOF
```

2. Aplicar la configuración actualizada:

```bash
kubectl apply -f argocd-application-autosync.yaml
```

3. Verificar que la política de sincronización automática está activa:

```bash
argocd app get guestbook | grep -A 3 "Sync Policy"
```

**Salida Esperada:**

```
Sync Policy:        Automated (Prune, Self Heal)
```

4. Provocar drift nuevamente para comprobar la auto-corrección:

```bash
kubectl scale deployment guestbook-frontend -n lab29-guestbook --replicas=5
echo "Esperando auto-heal (hasta 30 segundos)..."
sleep 30
```

5. Verificar que Argo CD restauró automáticamente las 2 réplicas:

```bash
kubectl get deployment guestbook-frontend -n lab29-guestbook \
  -o jsonpath='Réplicas (auto-healed): {.spec.replicas}{"\n"}'
```

**Salida Esperada:**

```
Réplicas (auto-healed): 2
```

**Verificación:**

```bash
# Verificar el historial de sincronizaciones
argocd app history guestbook

# El estado debe ser Synced y Healthy
argocd app get guestbook -o json | jq '{sync: .status.sync.status, health: .status.health.status}'
```

**Salida esperada del último comando:**

```json
{
  "sync": "Synced",
  "health": "Healthy"
}
```

> **Concepto clave:** Con `selfHeal: true`, Argo CD revierte automáticamente cualquier cambio manual realizado en el clúster que no coincida con Git. Con `prune: true`, Argo CD eliminará recursos del clúster que ya no existan en Git.

---

### Paso 9: Actualizar la Aplicación desde Git (Flujo GitOps Completo)

**Objetivo:** Realizar un cambio en el repositorio Git y observar cómo Argo CD lo sincroniza automáticamente al clúster.

**Instrucciones:**

1. Modificar el Deployment en Git para cambiar las réplicas a 3:

```bash
cd ~/gitops-repo
sed -i 's/replicas: 2/replicas: 3/' guestbook/deployment.yaml
```

2. Verificar el cambio:

```bash
grep "replicas:" guestbook/deployment.yaml
```

3. Hacer commit del cambio:

```bash
git add guestbook/deployment.yaml
git commit -m "scale: aumentar réplicas de frontend a 3"
```

4. Forzar un refresh de Argo CD para detectar el cambio inmediatamente (en producción esto sucede periódicamente):

```bash
argocd app get guestbook --refresh
```

5. Esperar a que la sincronización automática se ejecute:

```bash
sleep 15
argocd app wait guestbook --health --timeout 60
```

6. Verificar que el clúster ahora tiene 3 réplicas:

```bash
kubectl get deployment guestbook-frontend -n lab29-guestbook
kubectl get pods -n lab29-guestbook
```

**Salida Esperada:**

```
NAME                 READY   UP-TO-DATE   AVAILABLE   AGE
guestbook-frontend   3/3     3            3           10m
```

```
NAME                                  READY   STATUS    RESTARTS   AGE
guestbook-frontend-xxxxxxxxx-xxxxx    1/1     Running   0          10m
guestbook-frontend-xxxxxxxxx-xxxxx    1/1     Running   0          10m
guestbook-frontend-xxxxxxxxx-xxxxx    1/1     Running   0          15s
```

**Verificación:**

```bash
# Confirmar sync status
argocd app get guestbook -o json | jq '{sync: .status.sync.status, health: .status.health.status}'

# Verificar el historial muestra la nueva revisión
argocd app history guestbook
```

---

## Validación y Testing

Ejecuta los siguientes comandos para validar que todo el laboratorio se completó correctamente:

```bash
echo "=== VALIDACIÓN COMPLETA DEL LAB 29 ==="
echo ""

# 1. Verificar Argo CD está corriendo
echo "1. Pods de Argo CD:"
kubectl get pods -n argocd --no-headers | grep -c "Running"
echo "   (Esperado: 7 pods Running)"
echo ""

# 2. Verificar la aplicación guestbook existe
echo "2. Aplicación Argo CD:"
argocd app get guestbook -o json | jq -r '"   Sync: " + .status.sync.status + " | Health: " + .status.health.status'
echo "   (Esperado: Sync: Synced | Health: Healthy)"
echo ""

# 3. Verificar recursos en namespace destino
echo "3. Recursos en lab29-guestbook:"
echo "   Deployment: $(kubectl get deployment -n lab29-guestbook --no-headers | wc -l)"
echo "   Service: $(kubectl get svc -n lab29-guestbook --no-headers | wc -l)"
echo "   Ingress: $(kubectl get ingress -n lab29-guestbook --no-headers | wc -l)"
echo "   Pods Running: $(kubectl get pods -n lab29-guestbook --no-headers | grep -c Running)"
echo "   (Esperado: 1 Deployment, 1 Service, 1 Ingress, 3 Pods)"
echo ""

# 4. Verificar sincronización automática
echo "4. Política de sincronización:"
argocd app get guestbook | grep "Sync Policy"
echo "   (Esperado: Automated con Prune y Self Heal)"
echo ""

# 5. Verificar repositorio Git
echo "5. Commits en repositorio Git:"
cd ~/gitops-repo && git log --oneline
echo ""

# 6. Verificar réplicas coinciden con Git
REPLICAS_GIT=$(grep "replicas:" ~/gitops-repo/guestbook/deployment.yaml | awk '{print $2}')
REPLICAS_CLUSTER=$(kubectl get deployment guestbook-frontend -n lab29-guestbook -o jsonpath='{.spec.replicas}')
echo "6. Consistencia Git ↔ Clúster:"
echo "   Réplicas en Git: ${REPLICAS_GIT}"
echo "   Réplicas en Clúster: ${REPLICAS_CLUSTER}"
if [ "${REPLICAS_GIT}" = "${REPLICAS_CLUSTER}" ]; then
  echo "   ✅ CONSISTENTE - No hay drift"
else
  echo "   ❌ DRIFT DETECTADO"
fi

echo ""
echo "=== FIN DE VALIDACIÓN ==="
```

---

## Solución de Problemas

### Problema 1: Error de conexión al hacer `argocd login`

**Síntomas:**

```
FATA[0000] rpc error: code = Unavailable desc = connection error: 
desc = "transport: Error while dialing dial tcp 127.0.0.1:8080: connect: connection refused"
```

**Causa:** El port-forward al servidor de Argo CD no está activo o se interrumpió.

**Solución:**

```bash
# Verificar si hay un port-forward activo
ps aux | grep "port-forward.*argocd" | grep -v grep

# Si no hay ninguno, reiniciar el port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Esperar a que se establezca
sleep 3

# Reintentar el login
argocd login localhost:8080 \
  --username admin \
  --password "${ARGOCD_PASSWORD}" \
  --insecure
```

---

### Problema 2: La aplicación queda en estado `ComparisonError` o no detecta el repositorio local

**Síntomas:**

```
Sync Status:  Unknown
CONDITIONS:
ComparisonError: rpc error: repository not accessible
```

O bien:

```
FATA[0005] rpc error: code = InvalidArgument desc = application spec for guestbook is invalid: 
InvalidSpecError: repository /home/user/gitops-repo is not permitted
```

**Causa:** Argo CD no tiene permisos para acceder al repositorio Git local, o el path no es accesible desde dentro del Pod del repo-server.

**Solución:**

```bash
# Opción 1: Registrar el repositorio local explícitamente en Argo CD
argocd repo add /home/user/gitops-repo --type git --name local-gitops

# Opción 2: Si el repo-server no puede acceder al path local del host,
# montar el directorio. Primero, parchear el Deployment del repo-server:
kubectl patch deployment argocd-repo-server -n argocd --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/-",
    "value": {"name": "gitops-repo", "hostPath": {"path": "/home/user/gitops-repo", "type": "Directory"}}
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts/-",
    "value": {"name": "gitops-repo", "mountPath": "/home/user/gitops-repo"}
  }
]'

# Esperar a que el Pod se reinicie
kubectl rollout status deployment argocd-repo-server -n argocd --timeout=60s

# Alternativa más simple en minikube: montar el directorio al iniciar minikube
# minikube start --mount --mount-string="/home/user/gitops-repo:/home/user/gitops-repo"

# Después de resolver el acceso, forzar refresh
argocd app get guestbook --refresh --hard-refresh
```

> **Nota para entornos minikube:** Si usas minikube con driver Docker, los paths del host no están directamente accesibles dentro de los contenedores del clúster. La solución más robusta es iniciar minikube con `--mount` o usar `minikube mount ~/gitops-repo:/home/user/gitops-repo &` antes de crear la Application.

---

## Limpieza

Ejecuta los siguientes comandos para eliminar todos los recursos creados en este laboratorio:

```bash
# Eliminar la aplicación de Argo CD (esto también elimina los recursos gestionados)
argocd app delete guestbook --yes

# Esperar a que se eliminen los recursos
sleep 10

# Verificar que el namespace destino está limpio
kubectl get all -n lab29-guestbook

# Eliminar el namespace destino
kubectl delete namespace lab29-guestbook

# Desinstalar Argo CD
helm uninstall argocd -n argocd

# Eliminar el namespace de Argo CD
kubectl delete namespace argocd

# Detener el port-forward
kill ${PORT_FORWARD_PID} 2>/dev/null || pkill -f "port-forward.*argocd"

# Limpiar archivos del laboratorio (opcional - conservar si se desea revisar)
# rm -rf ~/ckad-labs/lab07
# rm -rf ~/gitops-repo

echo "Limpieza completada."
```

---

## Resumen

En este laboratorio has implementado un flujo GitOps completo utilizando Argo CD:

| Concepto | Lo que practicaste |
|----------|-------------------|
| **Instalación via Helm** | Desplegaste Argo CD 2.10.3 usando el chart oficial en un namespace dedicado |
| **Repositorio como fuente de verdad** | Creaste un repo Git local con manifiestos Deployment, Service e Ingress |
| **Application resource** | Definiste un recurso `Application` (apiVersion: argoproj.io/v1alpha1) que conecta Git con el clúster |
| **Sync manual** | Ejecutaste `argocd app sync` para desplegar recursos por primera vez |
| **Drift detection** | Provocaste drift escalando el Deployment con kubectl y observaste el estado OutOfSync |
| **Self-heal automático** | Configuraste `selfHeal: true` y verificaste que Argo CD revierte cambios no autorizados |
| **Flujo GitOps completo** | Modificaste Git → commit → Argo CD sincronizó automáticamente al clúster |

### Conceptos Clave Reforzados

- **GitOps:** Git es la única fuente de verdad. Todo cambio al clúster debe pasar por Git.
- **Sync Status:** `Synced` = clúster coincide con Git; `OutOfSync` = hay drift.
- **Health Status:** `Healthy` = recursos funcionando correctamente; `Degraded` = problemas detectados.
- **Self-Heal:** Con esta política, Argo CD revierte automáticamente modificaciones manuales al clúster.
- **Prune:** Con esta política, Argo CD elimina recursos del clúster que fueron removidos de Git.

### Recursos Adicionales

- [Documentación oficial de Argo CD — Application CRD](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [Argo CD Sync Policies](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [Helm Chart de Argo CD](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [GitOps Principles — OpenGitOps](https://opengitops.dev/)

---

# Consumir un recurso gestionado con Crossplane de forma básica

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Hard |
| **Nivel Bloom** | Apply |
| **Módulo** | 7 — Plataformas Kubernetes modernas |
| **Prerrequisito directo** | Lab 29 (Argo CD operativo) |

---

## Descripción General

En este laboratorio instalarás Crossplane en tu clúster minikube mediante Helm, configurarás el provider-helm para gestionar releases de Helm como recursos Kubernetes nativos, y crearás una abstracción de plataforma completa (XRD + Composition + Claim). Al finalizar, observarás cómo Crossplane orquesta la creación de un release de nginx gestionado de forma declarativa, demostrando el poder de la infraestructura como código dentro del modelo de API de Kubernetes.

---

## Objetivos de Aprendizaje

- [ ] Instalar Crossplane 1.15.1 en el namespace `crossplane-system` usando Helm y verificar que todos sus componentes están operativos
- [ ] Configurar el provider-helm v0.16.0 y otorgarle los permisos necesarios para gestionar releases dentro del clúster
- [ ] Crear un CompositeResourceDefinition (XRD) que expone una API personalizada `AppEnvironment`
- [ ] Definir una Composition que mapea el Claim a un release de Helm gestionado por provider-helm
- [ ] Instanciar un Claim y verificar los estados READY/SYNCED del recurso compuesto y del recurso gestionado

---

## Prerrequisitos

### Conocimiento Previo

| Tema | Nivel requerido |
|------|-----------------|
| Custom Resource Definitions (CRDs) | Comprensión de cómo extender la API de Kubernetes |
| Helm charts y releases | Capacidad de instalar charts con `helm install` |
| RBAC en Kubernetes | Comprensión de ClusterRoleBindings |
| Argo CD (Lab 29) | Operativo en namespace `argocd` (coexistencia intencional) |

### Acceso y Herramientas

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| minikube | 1.33.1 | Clúster local Kubernetes |
| kubectl | 1.30.2 | Gestión del clúster |
| Helm | 3.15.2 | Instalación de Crossplane y repositorio Bitnami |
| Conexión a Internet | — | Descarga de imágenes y packages de Crossplane |

---

## Entorno de Laboratorio

### Requisitos de Hardware

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU | 4 núcleos | 6 núcleos |
| RAM | 8 GB | 12 GB |
| Disco | 40 GB libres (SSD) | 50 GB |

### Preparación Inicial

Verifica que tu clúster minikube está corriendo y que dispones de recursos suficientes:

```bash
# Verificar estado del clúster
minikube status

# Verificar versión de Helm
helm version --short

# Verificar que Argo CD sigue operativo (coexistencia)
kubectl get pods -n argocd --no-headers | head -3

# Crear directorio de trabajo para este lab
mkdir -p ~/ckad-labs/lab30
cd ~/ckad-labs/lab30
```

**Salida esperada (minikube status):**

```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

Añade el repositorio de Helm de Crossplane y Bitnami si no lo has hecho:

```bash
# Repositorio de Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable

# Repositorio de Bitnami (necesario para el chart nginx)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Actualizar índices
helm repo update
```

---

## Paso a Paso

### Paso 1: Instalar Crossplane 1.15.1 en el clúster

**Objetivo:** Desplegar Crossplane en el namespace `crossplane-system` usando el chart oficial de Helm versión 1.15.1.

**Instrucciones:**

1. Crea el namespace dedicado para Crossplane:

```bash
kubectl create namespace crossplane-system
```

2. Instala Crossplane con Helm especificando la versión exacta:

```bash
helm install crossplane \
  crossplane-stable/crossplane \
  --namespace crossplane-system \
  --version 1.15.1 \
  --wait \
  --timeout 5m
```

3. Verifica que los pods de Crossplane están en estado `Running`:

```bash
kubectl get pods -n crossplane-system
```

**Salida esperada:**

```
NAME                                       READY   STATUS    RESTARTS   AGE
crossplane-7b4d5c8f9d-xxxxx               1/1     Running   0          60s
crossplane-rbac-manager-6c9b8d7f4-xxxxx   1/1     Running   0          60s
```

4. Verifica que los CRDs de Crossplane se registraron correctamente:

```bash
kubectl get crds | grep crossplane.io | wc -l
```

**Salida esperada:** Un número mayor o igual a 10 (los CRDs base de Crossplane).

**Verificación:**

```bash
# Confirmar que la API de Crossplane responde
kubectl api-resources | grep crossplane.io | head -5
```

Deberías ver recursos como `compositeresourcedefinitions`, `compositions`, `providers`, etc.

---

### Paso 2: Instalar y configurar el Provider Helm

**Objetivo:** Instalar el provider-helm v0.16.0 que permite a Crossplane gestionar releases de Helm como recursos declarativos.

**Instrucciones:**

1. Crea el manifiesto del Provider:

```bash
cat <<'EOF' > ~/ckad-labs/lab30/provider-helm.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.16.0
  runtimeConfigRef:
    name: default
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab30/provider-helm.yaml
```

3. Espera a que el provider esté en estado `Healthy`:

```bash
kubectl get providers.pkg.crossplane.io --watch
```

Espera hasta ver `HEALTHY: True` y `INSTALLED: True` (puede tardar 1-3 minutos mientras descarga la imagen). Presiona `Ctrl+C` cuando lo veas.

**Salida esperada:**

```
NAME            INSTALLED   HEALTHY   PACKAGE                                                        AGE
provider-helm   True        True      xpkg.upbound.io/crossplane-contrib/provider-helm:v0.16.0      90s
```

4. Verifica que el CRD `Release` del provider-helm está disponible:

```bash
kubectl get crds | grep helm.crossplane.io
```

**Salida esperada:**

```
providerconfigs.helm.crossplane.io          2024-xx-xxTxx:xx:xxZ
releases.helm.crossplane.io                 2024-xx-xxTxx:xx:xxZ
```

5. Crea un `ProviderConfig` que le indique al provider-helm cómo autenticarse con el clúster:

```bash
cat <<'EOF' > ~/ckad-labs/lab30/provider-config-helm.yaml
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF
```

```bash
kubectl apply -f ~/ckad-labs/lab30/provider-config-helm.yaml
```

6. El provider-helm necesita permisos de cluster-admin para poder instalar charts arbitrarios. Crea el ClusterRoleBinding:

> **Nota:** El nombre exacto del ServiceAccount del provider-helm se genera dinámicamente. Necesitamos obtenerlo:

```bash
# Obtener el nombre real del ServiceAccount del provider
SA_NAME=$(kubectl get sa -n crossplane-system -o name | grep provider-helm | head -1 | cut -d/ -f2)
echo "ServiceAccount encontrado: $SA_NAME"
```

Ahora crea el ClusterRoleBinding con el nombre correcto:

```bash
cat <<EOF > ~/ckad-labs/lab30/provider-helm-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-helm-admin
subjects:
  - kind: ServiceAccount
    name: ${SA_NAME}
    namespace: crossplane-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f ~/ckad-labs/lab30/provider-helm-rbac.yaml
```

**Verificación:**

```bash
kubectl get clusterrolebinding provider-helm-admin -o wide
```

---

### Paso 3: Crear el CompositeResourceDefinition (XRD)

**Objetivo:** Definir una API personalizada `XAppEnvironment` que los consumidores de plataforma podrán usar mediante Claims.

**Instrucciones:**

1. Crea el manifiesto del XRD:

```bash
cat <<'EOF' > ~/ckad-labs/lab30/xrd-appenvironment.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xappenvironments.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XAppEnvironment
    plural: xappenvironments
  claimNames:
    kind: AppEnvironmentClaim
    plural: appenvironmentclaims
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                parameters:
                  type: object
                  properties:
                    chartVersion:
                      type: string
                      description: "Versión del chart de nginx a desplegar"
                      default: "15.14.0"
                    replicaCount:
                      type: integer
                      description: "Número de réplicas de nginx"
                      default: 1
                      minimum: 1
                      maximum: 3
                    namespace:
                      type: string
                      description: "Namespace donde se desplegará el release"
                      default: "lab30-claims"
                  required:
                    - chartVersion
EOF
```

2. Aplica el XRD:

```bash
kubectl apply -f ~/ckad-labs/lab30/xrd-appenvironment.yaml
```

3. Verifica que el XRD fue registrado y está `Established`:

```bash
kubectl get compositeresourcedefinitions.apiextensions.crossplane.io
```

**Salida esperada:**

```
NAME                                      ESTABLISHED   OFFERED   AGE
xappenvironments.platform.example.com     True          True      10s
```

4. Confirma que los nuevos tipos de recurso están disponibles en la API:

```bash
kubectl api-resources | grep platform.example.com
```

**Salida esperada:**

```
appenvironmentclaims          platform.example.com/v1alpha1   true         AppEnvironmentClaim
xappenvironments              platform.example.com/v1alpha1   false        XAppEnvironment
```

> **Nota:** `AppEnvironmentClaim` es namespaced (`true`) mientras que `XAppEnvironment` es cluster-scoped (`false`). Esto es el patrón estándar de Crossplane.

**Verificación:**

```bash
kubectl explain appenvironmentclaims.spec.parameters
```

Deberías ver los campos `chartVersion`, `replicaCount` y `namespace` documentados.

---

### Paso 4: Crear la Composition

**Objetivo:** Definir cómo un `XAppEnvironment` se traduce en un recurso gestionado de tipo `Release` (provider-helm).

**Instrucciones:**

1. Crea el manifiesto de la Composition:

```bash
cat <<'EOF' > ~/ckad-labs/lab30/composition-appenvironment.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: appenvironment-helm
  labels:
    crossplane.io/xrd: xappenvironments.platform.example.com
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XAppEnvironment
  resources:
    - name: nginx-release
      base:
        apiVersion: helm.crossplane.io/v1beta1
        kind: Release
        spec:
          forProvider:
            chart:
              name: nginx
              repository: https://charts.bitnami.com/bitnami
              version: "15.14.0"
            namespace: lab30-claims
            values:
              replicaCount: 1
              service:
                type: ClusterIP
          providerConfigRef:
            name: default
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.chartVersion
          toFieldPath: spec.forProvider.chart.version
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.replicaCount
          toFieldPath: spec.forProvider.values.replicaCount
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.namespace
          toFieldPath: spec.forProvider.namespace
EOF
```

2. Aplica la Composition:

```bash
kubectl apply -f ~/ckad-labs/lab30/composition-appenvironment.yaml
```

3. Verifica que la Composition fue creada correctamente:

```bash
kubectl get compositions
```

**Salida esperada:**

```
NAME                   XR-KIND           XR-APIVERSION                      AGE
appenvironment-helm    XAppEnvironment   platform.example.com/v1alpha1      5s
```

**Verificación:**

```bash
kubectl describe composition appenvironment-helm | grep -A 5 "Composite Type Ref"
```

---

### Paso 5: Crear el Claim y verificar el recurso gestionado

**Objetivo:** Instanciar un `AppEnvironmentClaim` que disparará la creación del release de nginx a través de la Composition.

**Instrucciones:**

1. Crea el namespace donde vivirá el Claim:

```bash
kubectl create namespace lab30-claims
```

2. Crea el manifiesto del Claim:

```bash
cat <<'EOF' > ~/ckad-labs/lab30/claim-appenvironment.yaml
apiVersion: platform.example.com/v1alpha1
kind: AppEnvironmentClaim
metadata:
  name: my-nginx-env
  namespace: lab30-claims
spec:
  parameters:
    chartVersion: "15.14.0"
    replicaCount: 2
    namespace: lab30-claims
  compositionRef:
    name: appenvironment-helm
EOF
```

3. Aplica el Claim:

```bash
kubectl apply -f ~/ckad-labs/lab30/claim-appenvironment.yaml
```

4. Observa el progreso de la reconciliación:

```bash
# Ver el Claim
kubectl get appenvironmentclaims -n lab30-claims

# Ver el recurso compuesto (XR) generado
kubectl get xappenvironments

# Ver el recurso gestionado Release
kubectl get releases.helm.crossplane.io
```

5. Espera a que el recurso esté `READY` y `SYNCED` (puede tardar 2-5 minutos mientras se descarga el chart y se despliegan los pods):

```bash
kubectl get releases.helm.crossplane.io --watch
```

**Salida esperada (después de unos minutos):**

```
NAME                          READY   SYNCED   AGE
my-nginx-env-xxxxx-xxxxx     True    True     3m
```

Presiona `Ctrl+C` cuando veas `READY: True`.

6. Verifica que el release de nginx se desplegó correctamente en el namespace `lab30-claims`:

```bash
kubectl get pods -n lab30-claims
```

**Salida esperada:**

```
NAME                                    READY   STATUS    RESTARTS   AGE
my-nginx-env-xxxxx-nginx-xxxxxxx-xxx   1/1     Running   0          2m
my-nginx-env-xxxxx-nginx-xxxxxxx-xxx   1/1     Running   0          2m
```

> **Nota:** Deberías ver 2 réplicas de nginx ya que especificamos `replicaCount: 2` en el Claim.

7. Verifica el servicio creado:

```bash
kubectl get svc -n lab30-claims
```

**Salida esperada:**

```
NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
my-nginx-env-xxxxx-nginx     ClusterIP   10.96.xxx.xxx   <none>        80/TCP    2m
```

8. Verifica la cadena completa Claim → XR → Managed Resource:

```bash
echo "=== Claim ==="
kubectl get appenvironmentclaims -n lab30-claims -o wide

echo ""
echo "=== Composite Resource (XR) ==="
kubectl get xappenvironments -o wide

echo ""
echo "=== Managed Resource (Release) ==="
kubectl get releases.helm.crossplane.io -o wide

echo ""
echo "=== Pods desplegados ==="
kubectl get pods -n lab30-claims -o wide
```

**Verificación final:**

```bash
# Test de conectividad al nginx desplegado
kubectl run test-curl --rm -i --restart=Never \
  --image=curlimages/curl:8.4.0 \
  -n lab30-claims \
  -- curl -s -o /dev/null -w "%{http_code}" \
  http://$(kubectl get svc -n lab30-claims -o jsonpath='{.items[0].metadata.name}'):80
```

**Salida esperada:**

```
200
pod "test-curl" deleted
```

---

## Verificación Final del Laboratorio

Ejecuta este script de validación completa para confirmar que todos los componentes están operativos:

```bash
echo "============================================"
echo "  VERIFICACIÓN FINAL - Lab 30 Crossplane"
echo "============================================"
echo ""

# 1. Crossplane operativo
echo "[1/5] Crossplane pods:"
kubectl get pods -n crossplane-system --no-headers | grep -c "Running"
echo "  (esperado: 2 pods Running)"
echo ""

# 2. Provider Helm healthy
echo "[2/5] Provider Helm:"
kubectl get providers.pkg.crossplane.io provider-helm -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}'
echo ""
echo "  (esperado: True)"
echo ""

# 3. XRD established
echo "[3/5] XRD Established:"
kubectl get compositeresourcedefinitions xappenvironments.platform.example.com -o jsonpath='{.status.conditions[?(@.type=="Established")].status}'
echo ""
echo "  (esperado: True)"
echo ""

# 4. Release READY y SYNCED
echo "[4/5] Release status:"
kubectl get releases.helm.crossplane.io -o custom-columns="NAME:.metadata.name,READY:.status.conditions[?(@.type=='Ready')].status,SYNCED:.status.conditions[?(@.type=='Synced')].status"
echo "  (esperado: True / True)"
echo ""

# 5. Nginx pods running
echo "[5/5] Nginx pods en lab30-claims:"
kubectl get pods -n lab30-claims --no-headers | grep -c "Running"
echo "  (esperado: 2 pods Running)"
echo ""
echo "============================================"
echo "  LAB 30 COMPLETADO EXITOSAMENTE"
echo "============================================"
```

---

## Limpieza (Opcional)

Si deseas liberar recursos después de completar el laboratorio:

```bash
# Eliminar el Claim (esto eliminará el release de nginx automáticamente)
kubectl delete appenvironmentclaim my-nginx-env -n lab30-claims

# Esperar a que se elimine el release
sleep 30

# Verificar que el release fue eliminado
kubectl get releases.helm.crossplane.io

# Eliminar la Composition y el XRD
kubectl delete composition appenvironment-helm
kubectl delete compositeresourcedefinition xappenvironments.platform.example.com

# Eliminar el provider
kubectl delete provider provider-helm

# Desinstalar Crossplane
helm uninstall crossplane -n crossplane-system

# Eliminar namespaces
kubectl delete namespace crossplane-system lab30-claims

# Limpiar archivos
rm -rf ~/ckad-labs/lab30
```

> **Nota:** Si planeas continuar con labs posteriores que usen Crossplane, NO ejecutes la limpieza.

---

## Troubleshooting

| Problema | Causa probable | Solución |
|----------|---------------|----------|
| Provider queda en `INSTALLED: True, HEALTHY: False` | Timeout descargando la imagen del provider | Espera 3-5 minutos adicionales; verifica conectividad a Internet con `minikube ssh -- curl -I https://xpkg.upbound.io` |
| Release queda en `SYNCED: False` | Permisos insuficientes del ServiceAccount | Verifica el ClusterRoleBinding: `kubectl get clusterrolebinding provider-helm-admin -o yaml` |
| XRD no muestra `OFFERED: True` | Error en el schema OpenAPI del XRD | Revisa eventos: `kubectl describe xrd xappenvironments.platform.example.com` |
| Pods de nginx no aparecen | El namespace del release no coincide | Verifica el patch del namespace en la Composition y que el namespace existe |
| Error `no matches for kind "Release"` | CRDs del provider-helm no están instalados aún | Espera a que el provider esté `HEALTHY: True` antes de crear la Composition |
| Minikube sin recursos suficientes | Crossplane + provider + nginx requieren ~4GB RAM | Recrea minikube con más recursos: `minikube delete && minikube start --memory=10240 --cpus=4` |

---

## Resumen de Conceptos Clave

| Concepto | Descripción |
|----------|-------------|
| **Crossplane** | Framework que extiende Kubernetes para gestionar infraestructura y servicios externos como recursos nativos |
| **Provider** | Plugin de Crossplane que añade soporte para un tipo específico de infraestructura (AWS, GCP, Helm, etc.) |
| **ProviderConfig** | Configuración de credenciales y conexión para un Provider |
| **XRD (CompositeResourceDefinition)** | Define una nueva API personalizada con su schema OpenAPI |
| **Composition** | Mapea un recurso compuesto (XR) a uno o más recursos gestionados (MRs) |
| **Claim** | Recurso namespaced que los usuarios de plataforma crean para solicitar infraestructura |
| **Managed Resource** | Recurso externo gestionado por un Provider (en este caso, un Release de Helm) |

---

---

# Desplegar Kafka básico y validar producer/consumer

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 60 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar |
| **Tecnologías** | Apache Kafka 3.6.1, Strimzi 0.39.0, Helm 3.14.2, minikube 1.32.0, kubectl 1.29.2 |

## Descripción General

En este laboratorio desplegarás Apache Kafka en Kubernetes desde cero utilizando el operador Strimzi. Instalarás el operator via Helm, crearás un clúster Kafka de un solo broker con almacenamiento ephemeral, definirás un topic declarativo y validarás el flujo completo de mensajes enviando datos desde un Pod producer y leyéndolos desde un Pod consumer. Este lab establece la base para comprender cómo Kafka opera como sistema de mensajería distribuida dentro de Kubernetes mediante Custom Resources.

## Objetivos de Aprendizaje

- [ ] Instalar el Strimzi Kafka Operator usando Helm y verificar que el pod del operator esté en estado Running
- [ ] Crear un clúster Kafka de un solo broker mediante un Custom Resource declarativo y validar que todos los componentes estén Ready
- [ ] Crear un KafkaTopic como recurso nativo de Kubernetes y comprender su relación con el broker
- [ ] Ejecutar un producer y un consumer para validar el flujo end-to-end de mensajes a través del bootstrap service
- [ ] Identificar y describir los componentes clave del despliegue: bootstrap service, broker, ZooKeeper y topic

## Prerrequisitos

### Conocimientos Requeridos

| Conocimiento | Nivel |
|---|---|
| Pods, Services y Namespaces en Kubernetes | Intermedio |
| Uso básico de kubectl (apply, get, describe, logs) | Intermedio |
| Helm: instalación de charts y gestión de repositorios | Básico |
| Concepto de mensajería publish/subscribe | Básico |

### Acceso y Herramientas

| Herramienta | Versión | Propósito |
|---|---|---|
| minikube | 1.32.0+ | Clúster Kubernetes local |
| kubectl | 1.29.2+ | Gestión del clúster |
| Helm | 3.14.2+ | Instalación del Strimzi Operator |
| Docker Engine | 26.0.0+ | Driver de minikube |
| Conexión a internet | — | Descarga de imágenes y charts |

## Entorno del Laboratorio

### Recursos de Hardware Recomendados

| Recurso | Mínimo | Recomendado |
|---|---|---|
| CPU | 4 núcleos | 6 núcleos |
| RAM | 8 GB | 12 GB |
| Disco | 30 GB libres | 40 GB libres (SSD) |

### Estructura de Directorios

```
~/ckad-labs/
└── lab07/
    ├── kafka-cluster.yaml
    └── kafka-topic.yaml
```

## Paso 1: Preparar el Clúster minikube

### Objetivo

Crear un clúster minikube con perfil dedicado `ckad-kafka` con recursos suficientes para ejecutar Kafka, ZooKeeper y el Strimzi Operator simultáneamente.

### Instrucciones

1. Elimina cualquier perfil anterior con el mismo nombre (si existe):

```bash
minikube delete --profile ckad-kafka 2>/dev/null || true
```

2. Crea el clúster minikube con recursos adecuados:

```bash
minikube start --profile ckad-kafka \
  --cpus=4 \
  --memory=8192 \
  --disk-size=30g \
  --driver=docker \
  --kubernetes-version=v1.29.2
```

3. Configura kubectl para usar el perfil creado:

```bash
kubectl config use-context ckad-kafka
```

4. Verifica que el clúster está operativo:

```bash
kubectl get nodes
```

### Salida Esperada

```
NAME         STATUS   ROLES           AGE   VERSION
ckad-kafka   Ready    control-plane   45s   v1.29.2
```

### Verificación

```bash
kubectl cluster-info
```

Debes ver la URL del control plane y el servicio CoreDNS en estado running.

## Paso 2: Crear el Directorio de Trabajo y el Namespace

### Objetivo

Preparar la estructura de archivos del laboratorio y crear el namespace `kafka` donde residirán todos los componentes.

### Instrucciones

1. Crea el directorio de trabajo:

```bash
mkdir -p ~/ckad-labs/lab07
cd ~/ckad-labs/lab07
```

2. Crea el namespace `kafka`:

```bash
kubectl create namespace kafka
```

3. Configura el namespace `kafka` como default para el contexto actual:

```bash
kubectl config set-context --current --namespace=kafka
```

### Salida Esperada

```
namespace/kafka created
Context "ckad-kafka" modified.
```

### Verificación

```bash
kubectl config view --minify | grep namespace
```

Debe mostrar `namespace: kafka`.

## Paso 3: Instalar el Strimzi Kafka Operator via Helm

### Objetivo

Agregar el repositorio de Helm de Strimzi e instalar el operator en versión 0.39.0, que registrará los CRDs necesarios para gestionar Kafka como recurso nativo de Kubernetes.

### Instrucciones

1. Agrega el repositorio de Helm de Strimzi:

```bash
helm repo add strimzi https://strimzi.io/charts/
```

2. Actualiza los repositorios:

```bash
helm repo update
```

3. Instala el Strimzi Operator en el namespace `kafka`:

```bash
helm install strimzi-kafka strimzi/strimzi-kafka-operator \
  --namespace kafka \
  --version 0.39.0 \
  --wait --timeout 5m
```

4. Verifica que el pod del operator esté en estado Running:

```bash
kubectl get pods -n kafka -l name=strimzi-cluster-operator
```

### Salida Esperada

```
NAME                                        READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### Verificación

1. Confirma que los CRDs de Strimzi se registraron correctamente:

```bash
kubectl get crd | grep kafka
```

Debes ver al menos estos CRDs:

```
kafkabridges.kafka.strimzi.io
kafkaconnectors.kafka.strimzi.io
kafkaconnects.kafka.strimzi.io
kafkamirrormaker2s.kafka.strimzi.io
kafkamirrormakers.kafka.strimzi.io
kafkanodepools.kafka.strimzi.io
kafkarebalances.kafka.strimzi.io
kafkas.kafka.strimzi.io
kafkatopics.kafka.strimzi.io
kafkausers.kafka.strimzi.io
```

2. Verifica los logs del operator para confirmar que arrancó sin errores:

```bash
kubectl logs -l name=strimzi-cluster-operator --tail=5
```

## Paso 4: Desplegar el Clúster Kafka

### Objetivo

Crear un clúster Kafka de un solo broker con almacenamiento ephemeral usando un Custom Resource de tipo `Kafka`. Este recurso es interpretado por el Strimzi Operator, que se encarga de crear los StatefulSets, Services y configuraciones necesarias.

### Instrucciones

1. Crea el manifiesto del clúster Kafka:

```bash
cat > ~/ckad-labs/lab07/kafka-cluster.yaml << 'EOF'
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: ckad-kafka-cluster
  namespace: kafka
spec:
  kafka:
    version: 3.6.1
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
      inter.broker.protocol.version: "3.6"
    storage:
      type: ephemeral
  zookeeper:
    replicas: 1
    storage:
      type: ephemeral
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab07/kafka-cluster.yaml
```

3. Espera a que el clúster Kafka esté completamente listo. Este proceso puede tomar entre 3 y 8 minutos mientras se descargan las imágenes y se inician los componentes:

```bash
kubectl wait kafka/ckad-kafka-cluster --for=condition=Ready --timeout=600s -n kafka
```

4. Mientras esperas, observa el progreso de los pods:

```bash
kubectl get pods -n kafka -w
```

Presiona `Ctrl+C` cuando todos los pods estén en estado `Running` y `Ready`.

### Salida Esperada

Al completarse el despliegue, debes ver estos pods:

```
NAME                                            READY   STATUS    RESTARTS   AGE
ckad-kafka-cluster-entity-operator-xxx-xxx      2/2     Running   0          1m
ckad-kafka-cluster-kafka-0                      1/1     Running   0          2m
ckad-kafka-cluster-zookeeper-0                  1/1     Running   0          3m
strimzi-cluster-operator-xxx-xxx                1/1     Running   0          8m
```

### Verificación

1. Verifica el estado del recurso Kafka:

```bash
kubectl get kafka ckad-kafka-cluster -n kafka
```

Debe mostrar `True` en la columna READY:

```
NAME                 DESIRED KAFKA REPLICAS   DESIRED ZK REPLICAS   READY   METADATA STATE
ckad-kafka-cluster   1                        1                     True    ZooKeeper
```

2. Lista los Services creados por Strimzi:

```bash
kubectl get svc -n kafka
```

Identifica los servicios clave:

| Service | Tipo | Propósito |
|---|---|---|
| `ckad-kafka-cluster-kafka-bootstrap` | ClusterIP | Punto de entrada principal para clientes Kafka |
| `ckad-kafka-cluster-kafka-brokers` | Headless | Comunicación directa Pod-a-Pod entre brokers |
| `ckad-kafka-cluster-zookeeper-client` | ClusterIP | Acceso de Kafka a ZooKeeper |
| `ckad-kafka-cluster-zookeeper-nodes` | Headless | Comunicación entre nodos ZooKeeper |

3. Describe el bootstrap service para entender su configuración:

```bash
kubectl describe svc ckad-kafka-cluster-kafka-bootstrap -n kafka
```

> **Nota importante**: El **bootstrap service** (`ckad-kafka-cluster-kafka-bootstrap`) es el punto de entrada que los clientes Kafka (producers y consumers) usan para descubrir los brokers del clúster. Su FQDN dentro del clúster es: `ckad-kafka-cluster-kafka-bootstrap.kafka.svc:9092`

## Paso 5: Crear el KafkaTopic

### Objetivo

Crear un topic llamado `ckad-messages` con 3 particiones y factor de replicación 1 usando un Custom Resource de tipo `KafkaTopic`. El Entity Operator de Strimzi gestiona la creación del topic real en Kafka a partir de este recurso declarativo.

### Instrucciones

1. Crea el manifiesto del topic:

```bash
cat > ~/ckad-labs/lab07/kafka-topic.yaml << 'EOF'
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: ckad-messages
  namespace: kafka
  labels:
    strimzi.io/cluster: ckad-kafka-cluster
spec:
  partitions: 3
  replicas: 1
  config:
    retention.ms: 7200000
    segment.bytes: 1073741824
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab07/kafka-topic.yaml
```

3. Verifica que el topic fue creado exitosamente:

```bash
kubectl get kafkatopic ckad-messages -n kafka
```

### Salida Esperada

```
NAME            CLUSTER              PARTITIONS   REPLICATION FACTOR   READY
ckad-messages   ckad-kafka-cluster   3            1                    True
```

### Verificación

Confirma que el topic existe realmente en el broker ejecutando un comando dentro del pod del broker:

```bash
kubectl exec ckad-kafka-cluster-kafka-0 -n kafka -- \
  bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic ckad-messages
```

Salida esperada:

```
Topic: ckad-messages	TopicId: xxxxxxxxxxxxxxxxxxxx	PartitionCount: 3	ReplicationFactor: 1	Configs: ...
	Topic: ckad-messages	Partition: 0	Leader: 0	Replicas: 0	Isr: 0
	Topic: ckad-messages	Partition: 1	Leader: 0	Replicas: 0	Isr: 0
	Topic: ckad-messages	Partition: 2	Leader: 0	Replicas: 0	Isr: 0
```

## Paso 6: Enviar Mensajes con un Pod Producer

### Objetivo

Desplegar un Pod producer que envíe 10 mensajes de prueba al topic `ckad-messages` usando el cliente `kafka-console-producer.sh` incluido en la imagen de Strimzi. Los mensajes se enviarán a través del bootstrap service.

### Instrucciones

1. Ejecuta un Pod que envíe 10 mensajes al topic:

```bash
kubectl run kafka-producer -n kafka \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.1 \
  --rm -it --restart=Never \
  -- bash -c '
echo "Enviando 10 mensajes al topic ckad-messages..."
for i in $(seq 1 10); do
  echo "mensaje-$i: Hola desde el producer CKAD [$(date +%H:%M:%S)]"
done | bin/kafka-console-producer.sh \
  --bootstrap-server ckad-kafka-cluster-kafka-bootstrap.kafka.svc:9092 \
  --topic ckad-messages
echo "Todos los mensajes enviados exitosamente."
'
```

### Salida Esperada

```
Enviando 10 mensajes al topic ckad-messages...
Todos los mensajes enviados exitosamente.
pod "kafka-producer" deleted
```

> **Nota**: El flag `--rm` elimina el Pod automáticamente al finalizar. El flag `-it` permite ver la salida en tiempo real.

### Verificación

Verifica que no quedaron pods residuales del producer:

```bash
kubectl get pods -n kafka | grep producer
```

No debe devolver resultados (el pod fue eliminado automáticamente).

## Paso 7: Leer Mensajes con un Pod Consumer

### Objetivo

Desplegar un Pod consumer que lea todos los mensajes desde el inicio del topic `ckad-messages` (offset más antiguo) y verificar que los 10 mensajes enviados por el producer son recibidos correctamente.

### Instrucciones

1. Ejecuta un Pod consumer que lea los mensajes con un timeout de 30 segundos:

```bash
kubectl run kafka-consumer -n kafka \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.1 \
  --rm -it --restart=Never \
  -- bash -c '
echo "Leyendo mensajes del topic ckad-messages (timeout 30s)..."
echo "---"
timeout 30 bin/kafka-console-consumer.sh \
  --bootstrap-server ckad-kafka-cluster-kafka-bootstrap.kafka.svc:9092 \
  --topic ckad-messages \
  --from-beginning \
  --max-messages 10
echo ""
echo "---"
echo "Lectura completada."
'
```

### Salida Esperada

```
Leyendo mensajes del topic ckad-messages (timeout 30s)...
---
mensaje-1: Hola desde el producer CKAD [14:32:01]
mensaje-2: Hola desde el producer CKAD [14:32:01]
mensaje-3: Hola desde el producer CKAD [14:32:01]
mensaje-4: Hola desde el producer CKAD [14:32:01]
mensaje-5: Hola desde el producer CKAD [14:32:01]
mensaje-6: Hola desde el producer CKAD [14:32:01]
mensaje-7: Hola desde el producer CKAD [14:32:01]
mensaje-8: Hola desde el producer CKAD [14:32:01]
mensaje-9: Hola desde el producer CKAD [14:32:01]
mensaje-10: Hola desde el producer CKAD [14:32:01]
Processed a total of 10 messages
---
Lectura completada.
pod "kafka-consumer" deleted
```

> **Nota**: El orden de los mensajes puede variar ligeramente porque el topic tiene 3 particiones. Kafka garantiza orden **dentro** de cada partición, no entre particiones. Los 10 mensajes deben estar presentes aunque su secuencia numérica no sea estrictamente 1-10.

### Verificación

Si deseas verificar una segunda vez que los mensajes persisten (Kafka los retiene según `retention.ms`), ejecuta el consumer nuevamente:

```bash
kubectl run kafka-consumer-check -n kafka \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.1 \
  --rm -it --restart=Never \
  -- bin/kafka-console-consumer.sh \
    --bootstrap-server ckad-kafka-cluster-kafka-bootstrap.kafka.svc:9092 \
    --topic ckad-messages \
    --from-beginning \
    --max-messages 10
```

Debes obtener los mismos 10 mensajes, confirmando que Kafka los almacena de forma persistente (dentro del ciclo de vida del pod broker con almacenamiento ephemeral).

## Paso 8: Explorar los Componentes del Despliegue

### Objetivo

Identificar y comprender la función de cada componente desplegado por Strimzi, reforzando la relación entre broker, ZooKeeper, bootstrap service, topic y los clientes producer/consumer.

### Instrucciones

1. Lista todos los recursos creados por Strimzi en el namespace:

```bash
kubectl get all -n kafka -l strimzi.io/cluster=ckad-kafka-cluster
```

2. Examina la arquitectura de componentes:

```bash
echo "=== PODS ==="
kubectl get pods -n kafka -o custom-columns=\
'NAME:.metadata.name,READY:.status.containerStatuses[0].ready,ROLE:.metadata.labels.strimzi\.io/kind'

echo ""
echo "=== SERVICES ==="
kubectl get svc -n kafka -o custom-columns=\
'NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,PORTS:.spec.ports[*].port'

echo ""
echo "=== CUSTOM RESOURCES ==="
kubectl get kafka,kafkatopic -n kafka
```

3. Describe el broker pod para ver su configuración de red:

```bash
kubectl describe pod ckad-kafka-cluster-kafka-0 -n kafka | grep -A5 "Labels:"
```

4. Verifica la resolución DNS del bootstrap service desde dentro del clúster:

```bash
kubectl run dns-test -n kafka \
  --image=busybox:1.36.1 \
  --rm -it --restart=Never \
  -- nslookup ckad-kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local
```

### Salida Esperada

La resolución DNS debe devolver la IP del ClusterIP service:

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      ckad-kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local
Address 1: 10.x.x.x ckad-kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local
```

### Mapa de Componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                     Namespace: kafka                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────┐     ┌──────────────────────────────┐  │
│  │ Strimzi Operator     │────▶│ Gestiona CRs: Kafka,         │  │
│  │ (Deployment)         │     │ KafkaTopic, KafkaUser         │  │
│  └─────────────────────┘     └──────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────────┐     ┌──────────────────────────────┐  │
│  │ ZooKeeper            │◀───▶│ Kafka Broker                  │  │
│  │ (StatefulSet, 1 pod) │     │ (StatefulSet, 1 pod)          │  │
│  └─────────────────────┘     └──────────────────────────────┘  │
│                                         ▲                       │
│                                         │ port 9092             │
│                               ┌─────────┴────────────┐         │
│                               │ Bootstrap Service     │         │
│                               │ (ClusterIP)           │         │
│                               └─────────┬────────────┘         │
│                                         │                       │
│                    ┌────────────────────┼────────────────────┐  │
│                    │                    │                    │   │
│              ┌─────┴─────┐       ┌─────┴─────┐              │  │
│              │ Producer   │       │ Consumer   │              │  │
│              │ (Pod)      │       │ (Pod)      │              │  │
│              └───────────┘       └───────────┘              │  │
│                                                                 │
│  ┌─────────────────────┐                                        │
│  │ Entity Operator      │ ← Gestiona topics y users             │
│  │ (Deployment, 2       │                                       │
│  │  containers)         │                                       │
│  └─────────────────────┘                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Descripción de componentes clave:**

| Componente | Función |
|---|---|
| **Strimzi Cluster Operator** | Reconcilia los CRs de tipo Kafka; crea/actualiza StatefulSets, Services y ConfigMaps |
| **Kafka Broker** (ckad-kafka-cluster-kafka-0) | Almacena y sirve mensajes; gestiona particiones y réplicas |
| **ZooKeeper** (ckad-kafka-cluster-zookeeper-0) | Coordina metadata del clúster Kafka (elección de líder, configuración de topics) |
| **Entity Operator** | Contiene Topic Operator y User Operator; sincroniza CRs KafkaTopic/KafkaUser con el broker |
| **Bootstrap Service** | Service ClusterIP que expone el puerto 9092; los clientes lo usan para descubrir brokers |
| **Headless Service** (kafka-brokers) | Permite resolución DNS directa a cada pod broker individual |

## Validación y Testing

Ejecuta las siguientes verificaciones para confirmar que el laboratorio se completó exitosamente:

### Test 1: Operator funcional

```bash
echo "TEST 1: Strimzi Operator Running"
kubectl get pods -n kafka -l name=strimzi-cluster-operator -o jsonpath='{.items[0].status.phase}'
echo ""
# Esperado: Running
```

### Test 2: Clúster Kafka Ready

```bash
echo "TEST 2: Kafka Cluster Ready"
kubectl get kafka ckad-kafka-cluster -n kafka -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
echo ""
# Esperado: True
```

### Test 3: Topic creado con 3 particiones

```bash
echo "TEST 3: KafkaTopic ckad-messages"
kubectl get kafkatopic ckad-messages -n kafka -o jsonpath='Partitions: {.spec.partitions}, Replicas: {.spec.replicas}, Ready: {.status.conditions[?(@.type=="Ready")].status}'
echo ""
# Esperado: Partitions: 3, Replicas: 1, Ready: True
```

### Test 4: Flujo end-to-end de mensajes

```bash
echo "TEST 4: Flujo Producer → Consumer"
# Enviar un mensaje de prueba
kubectl run test-producer -n kafka \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.1 \
  --rm -it --restart=Never \
  -- bash -c '
echo "test-validation-$(date +%s)" | bin/kafka-console-producer.sh \
  --bootstrap-server ckad-kafka-cluster-kafka-bootstrap.kafka.svc:9092 \
  --topic ckad-messages'

# Leer y contar mensajes (deben ser al menos 11: 10 originales + 1 de test)
kubectl run test-consumer -n kafka \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.1 \
  --rm -it --restart=Never \
  -- bash -c '
COUNT=$(timeout 15 bin/kafka-console-consumer.sh \
  --bootstrap-server ckad-kafka-cluster-kafka-bootstrap.kafka.svc:9092 \
  --topic ckad-messages \
  --from-beginning 2>/dev/null | wc -l)
echo "Mensajes totales en el topic: $COUNT"
if [ "$COUNT" -ge 11 ]; then
  echo "PASS: Flujo de mensajes validado correctamente"
else
  echo "FAIL: Se esperaban al menos 11 mensajes, se encontraron $COUNT"
fi'
```

### Test 5: Bootstrap service resolvible

```bash
echo "TEST 5: DNS del Bootstrap Service"
kubectl run dns-validate -n kafka \
  --image=busybox:1.36.1 \
  --rm -it --restart=Never \
  -- sh -c '
if nslookup ckad-kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local > /dev/null 2>&1; then
  echo "PASS: Bootstrap service resolvible via DNS"
else
  echo "FAIL: No se puede resolver el bootstrap service"
fi'
```

## Troubleshooting

### Problema 1: El pod del Kafka broker se queda en estado `Pending` o `CrashLoopBackOff`

**Síntomas:**

```bash
kubectl get pods -n kafka
# ckad-kafka-cluster-kafka-0    0/1     Pending   0          5m
```

O bien el pod inicia pero reinicia continuamente.

**Causa:**

Recursos insuficientes en el nodo minikube. Kafka y ZooKeeper requieren un mínimo de 4 GB de RAM combinados. Si minikube se creó con menos de 8 GB de memoria, los pods no pueden ser programados o se terminan por OOMKill.

**Solución:**

```bash
# Verificar eventos del pod
kubectl describe pod ckad-kafka-cluster-kafka-0 -n kafka | tail -20

# Si el problema es recursos, eliminar y recrear minikube con más memoria
minikube delete --profile ckad-kafka
minikube start --profile ckad-kafka \
  --cpus=4 \
  --memory=10240 \
  --disk-size=30g \
  --driver=docker \
  --kubernetes-version=v1.29.2

# Reinstalar el operator y reaplicar los manifiestos
kubectl create namespace kafka
kubectl config set-context --current --namespace=kafka
helm install strimzi-kafka strimzi/strimzi-kafka-operator --namespace kafka --version 0.39.0 --wait
kubectl apply -f ~/ckad-labs/lab07/kafka-cluster.yaml
kubectl apply -f ~/ckad-labs/lab07/kafka-topic.yaml
```

### Problema 2: El producer falla con `Connection refused` o `UnknownHostException`

**Síntomas:**

```
WARN [Producer clientId=console-producer] Connection to node -1 (ckad-kafka-cluster-kafka-bootstrap.kafka.svc/10.x.x.x:9092) could not be established. Broker may not be available.
```

O:

```
java.net.UnknownHostException: ckad-kafka-cluster-kafka-bootstrap.kafka.svc
```

**Causa:**

El clúster Kafka aún no está completamente listo cuando se ejecuta el producer. El bootstrap service existe (fue creado por Strimzi), pero el broker pod todavía no está aceptando conexiones en el puerto 9092. Alternativamente, el nombre del service está mal escrito en el comando del producer.

**Solución:**

```bash
# 1. Verificar que el clúster está Ready
kubectl get kafka ckad-kafka-cluster -n kafka
# La columna READY debe mostrar True

# 2. Verificar que el broker pod está Running y Ready
kubectl get pods -n kafka -l strimzi.io/kind=Kafka
# Debe estar 1/1 Running

# 3. Verificar que el service existe y tiene endpoints
kubectl get endpoints ckad-kafka-cluster-kafka-bootstrap -n kafka
# Debe mostrar al menos un endpoint IP:9092

# 4. Si no hay endpoints, esperar a que el broker esté listo
kubectl wait kafka/ckad-kafka-cluster --for=condition=Ready --timeout=600s -n kafka

# 5. Verificar el nombre correcto del service
kubectl get svc -n kafka | grep bootstrap
# Usar el nombre exacto en el comando del producer
```

## Limpieza

Para eliminar todos los recursos creados en este laboratorio y liberar recursos del sistema:

> **IMPORTANTE**: No ejecutes la limpieza si planeas continuar con el Lab 07-00-04 (Práctica 32), ya que ese laboratorio reutiliza el clúster Kafka y el topic `ckad-messages` creados aquí.

```bash
# Opción A: Eliminar solo los recursos de Kafka (mantener minikube)
kubectl delete kafkatopic ckad-messages -n kafka
kubectl delete kafka ckad-kafka-cluster -n kafka
helm uninstall strimzi-kafka -n kafka
kubectl delete namespace kafka

# Opción B: Eliminar todo incluyendo el clúster minikube
minikube delete --profile ckad-kafka

# Limpiar archivos locales
rm -rf ~/ckad-labs/lab07/
```

## Resumen

En este laboratorio has completado el despliegue completo de Apache Kafka en Kubernetes:

| Logro | Detalle |
|---|---|
| ✅ Strimzi Operator instalado | Helm chart v0.39.0 en namespace `kafka` |
| ✅ Clúster Kafka desplegado | 1 broker + 1 ZooKeeper con almacenamiento ephemeral |
| ✅ KafkaTopic creado | `ckad-messages` con 3 particiones, RF=1 |
| ✅ Producer ejecutado | 10 mensajes enviados via bootstrap service |
| ✅ Consumer validado | 10 mensajes leídos desde el inicio del topic |
| ✅ Componentes identificados | Bootstrap service, broker, ZooKeeper, Entity Operator |

**Conceptos clave reforzados:**

- **Strimzi** abstrae la complejidad operativa de Kafka mediante CRDs, permitiendo gestionar brokers y topics con `kubectl apply`.
- El **bootstrap service** es el punto de entrada único para clientes Kafka; su FQDN sigue el patrón `<cluster-name>-kafka-bootstrap.<namespace>.svc:9092`.
- **KafkaTopic** como Custom Resource permite gestionar topics de forma declarativa, con el Entity Operator reconciliando el estado deseado contra el broker.
- Kafka garantiza orden de mensajes **por partición**, no globalmente en el topic.
- El almacenamiento **ephemeral** es adecuado para laboratorios pero en producción se requieren PersistentVolumes.

### Recursos Adicionales

- [Strimzi Documentation — Deploying Strimzi](https://strimzi.io/docs/operators/0.39.0/deploying)
- [Apache Kafka — Quickstart](https://kafka.apache.org/quickstart)
- [Strimzi — KafkaTopic Schema Reference](https://strimzi.io/docs/operators/0.39.0/configuring#type-KafkaTopic-reference)
- [Kubernetes — Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

---

# Mini-proyecto integrador CKAD + Argo CD + Kafka + Crossplane

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 35 minutos |
| **Complejidad** | Alta |
| **Nivel Bloom** | Crear |

## Descripción General

Este laboratorio es el cierre integrador del curso CKAD. Combina Argo CD (GitOps), Crossplane (infraestructura declarativa) y Apache Kafka (mensajería distribuida) en un flujo completo: crearás un repositorio Git local con manifiestos de una aplicación consumidora de Kafka, la desplegarás mediante Argo CD, demostrarás drift detection, e instalarás Crossplane con un recurso declarativo. Al finalizar, verificarás que la cadena GitOps → Aplicación → Kafka funciona de extremo a extremo.

## Objetivos de Aprendizaje

- [ ] Instalar Argo CD 2.10.1 y acceder a su UI via port-forward, autenticándose con la contraseña inicial
- [ ] Crear un repositorio Git local estructurado y definir un recurso Application de Argo CD que sincronice un Deployment consumidor de Kafka
- [ ] Demostrar drift detection modificando manualmente un recurso y restaurándolo via sync de Argo CD
- [ ] Instalar Crossplane 1.15.1 con el Helm Provider y crear un Release CR declarativo
- [ ] Validar la integración completa verificando que los pods consumen mensajes del topic `ckad-messages`

## Prerrequisitos

### Conocimiento Requerido

- Práctica 31 completada: clúster Kafka operativo con topic `ckad-messages` en namespace `kafka`
- Comprensión de conceptos GitOps y el ciclo declarativo de Kubernetes
- Familiaridad con Helm, Git y manifiestos YAML de Kubernetes

### Acceso Requerido

| Recurso | Detalle |
|---------|---------|
| Bootstrap service Kafka | `ckad-kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092` |
| Helm repos configurados | `argo` (argoproj.github.io/argo-helm), `crossplane-stable` (charts.crossplane.io/stable) |
| Argo CD CLI | `/usr/local/bin/argocd` versión 2.10.1 |
| Git | Configurado con `user.name` y `user.email` |

## Entorno del Laboratorio

### Software Requerido

| Herramienta | Versión |
|-------------|---------|
| Kubernetes (kind) | 1.30.2 |
| Helm | 3.15.2 |
| kubectl | 1.30.2 |
| Git | 2.43.0 |
| Argo CD CLI | 2.10.1 |

### Preparación Inicial

```bash
# Verificar que el clúster está activo
kubectl cluster-info

# Verificar que Kafka está operativo (del lab anterior)
kubectl get pods -n kafka -l strimzi.io/name=ckad-kafka-cluster-kafka
kubectl get kafkatopic ckad-messages -n kafka

# Verificar Helm repos
helm repo list | grep -E "argo|crossplane"

# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab07
cd ~/ckad-labs/lab07
```

---

## Paso 1: Instalar Argo CD 2.10.1 en el Clúster

### Objetivo

Desplegar Argo CD mediante Helm en el namespace `argocd` y verificar que todos sus componentes están operativos.

### Instrucciones

1. Crear el namespace y actualizar el repositorio Helm:

```bash
kubectl create namespace argocd
helm repo update argo
```

2. Instalar Argo CD con Helm especificando la versión del chart que incluye Argo CD 2.10.1:

```bash
helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 6.4.0 \
  --set server.service.type=ClusterIP \
  --set configs.params."server\.insecure"=true \
  --wait --timeout 300s
```

3. Verificar que todos los pods de Argo CD están en estado Running:

```bash
kubectl get pods -n argocd
```

4. Obtener la contraseña inicial del administrador:

```bash
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "Contraseña Argo CD: $ARGOCD_PASSWORD"
```

5. Iniciar port-forward para acceder a la UI (ejecutar en segundo plano):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PF_PID=$!
echo "Port-forward PID: $PF_PID"
```

6. Autenticarse con el CLI de Argo CD:

```bash
argocd login localhost:8080 \
  --username admin \
  --password "$ARGOCD_PASSWORD" \
  --insecure
```

### Salida Esperada

```
'admin:login' logged in successfully
Context 'localhost:8080' updated
```

### Verificación

```bash
argocd version --short
# Debe mostrar: argocd: v2.10.1
# Server: argocd-server: v2.10.x

kubectl get deploy -n argocd
# Todos los deployments con READY
```

---

## Paso 2: Crear el Repositorio Git Local con Manifiestos del Consumer

### Objetivo

Estructurar un repositorio Git local en `~/ckad-gitops-repo/` con los manifiestos YAML que Argo CD usará como fuente de verdad para desplegar la aplicación consumidora de Kafka.

### Instrucciones

1. Inicializar el repositorio Git:

```bash
mkdir -p ~/ckad-gitops-repo/apps/kafka-consumer
cd ~/ckad-gitops-repo
git init
```

2. Crear el ConfigMap con la configuración del consumer:

```bash
cat > apps/kafka-consumer/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-consumer-config
  namespace: kafka
  labels:
    app: kafka-consumer
    project: ckad-integrador
data:
  BOOTSTRAP_SERVERS: "ckad-kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
  TOPIC: "ckad-messages"
  GROUP_ID: "ckad-consumer-group"
  AUTO_OFFSET_RESET: "earliest"
EOF
```

3. Crear el ServiceAccount:

```bash
cat > apps/kafka-consumer/serviceaccount.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kafka-consumer-sa
  namespace: kafka
  labels:
    app: kafka-consumer
    project: ckad-integrador
EOF
```

4. Crear el Deployment del consumer con 2 réplicas:

```bash
cat > apps/kafka-consumer/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-consumer-app
  namespace: kafka
  labels:
    app: kafka-consumer
    project: ckad-integrador
spec:
  replicas: 2
  selector:
    matchLabels:
      app: kafka-consumer
  template:
    metadata:
      labels:
        app: kafka-consumer
    spec:
      serviceAccountName: kafka-consumer-sa
      containers:
      - name: kafka-consumer
        image: quay.io/strimzi/kafka:0.39.0-kafka-3.6.1
        command:
        - /bin/sh
        - -c
        - |
          bin/kafka-console-consumer.sh \
            --bootstrap-server $(BOOTSTRAP_SERVERS) \
            --topic $(TOPIC) \
            --group $(GROUP_ID) \
            --consumer-property auto.offset.reset=$(AUTO_OFFSET_RESET)
        envFrom:
        - configMapRef:
            name: kafka-consumer-config
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "ps aux | grep kafka-console-consumer | grep -v grep"
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "ps aux | grep kafka-console-consumer | grep -v grep"
          initialDelaySeconds: 15
          periodSeconds: 5
      restartPolicy: Always
EOF
```

5. Hacer commit del repositorio:

```bash
cd ~/ckad-gitops-repo
git add .
git commit -m "feat: add kafka-consumer manifests for ckad-integrador"
```

### Salida Esperada

```
[main (root-commit) xxxxxxx] feat: add kafka-consumer manifests for ckad-integrador
 3 files changed, 3 insertions(+)
 create mode 100644 apps/kafka-consumer/configmap.yaml
 create mode 100644 apps/kafka-consumer/deployment.yaml
 create mode 100644 apps/kafka-consumer/serviceaccount.yaml
```

### Verificación

```bash
tree ~/ckad-gitops-repo/
# Estructura esperada:
# ~/ckad-gitops-repo/
# └── apps
#     └── kafka-consumer
#         ├── configmap.yaml
#         ├── deployment.yaml
#         └── serviceaccount.yaml

git -C ~/ckad-gitops-repo log --oneline
```

---

## Paso 3: Registrar el Repositorio en Argo CD y Crear la Application

### Objetivo

Configurar Argo CD para usar el repositorio Git local como fuente de verdad y crear el recurso Application `ckad-integrador` con sincronización manual.

### Instrucciones

1. Para que Argo CD acceda al repositorio local, debemos servirlo via un pod Git server. Crear un ConfigMap con los manifiestos y un pod de servidor Git:

```bash
cd ~/ckad-labs/lab07

# Crear un bare repo para servir via git-daemon
git clone --bare ~/ckad-gitops-repo /tmp/ckad-gitops-repo.git

# Crear pod de git server en el clúster
cat > git-server.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: git-server
  namespace: argocd
  labels:
    app: git-server
spec:
  containers:
  - name: git-daemon
    image: alpine/git:2.43.0
    command:
    - git
    - daemon
    - --reuseaddr
    - --base-path=/git
    - --export-all
    - --verbose
    - /git
    ports:
    - containerPort: 9418
      name: git
    volumeMounts:
    - name: repo-data
      mountPath: /git
  initContainers:
  - name: clone-repo
    image: alpine/git:2.43.0
    command:
    - /bin/sh
    - -c
    - |
      git init --bare /git/ckad-gitops-repo.git
      cd /tmp && git clone /git/ckad-gitops-repo.git work
      cd work
      mkdir -p apps/kafka-consumer
      cat > apps/kafka-consumer/configmap.yaml << 'INNEREOF'
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: kafka-consumer-config
        namespace: kafka
        labels:
          app: kafka-consumer
          project: ckad-integrador
      data:
        BOOTSTRAP_SERVERS: "ckad-kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
        TOPIC: "ckad-messages"
        GROUP_ID: "ckad-consumer-group"
        AUTO_OFFSET_RESET: "earliest"
      INNEREOF
      cat > apps/kafka-consumer/serviceaccount.yaml << 'INNEREOF'
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: kafka-consumer-sa
        namespace: kafka
        labels:
          app: kafka-consumer
          project: ckad-integrador
      INNEREOF
      cat > apps/kafka-consumer/deployment.yaml << 'INNEREOF'
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: kafka-consumer-app
        namespace: kafka
        labels:
          app: kafka-consumer
          project: ckad-integrador
      spec:
        replicas: 2
        selector:
          matchLabels:
            app: kafka-consumer
        template:
          metadata:
            labels:
              app: kafka-consumer
          spec:
            serviceAccountName: kafka-consumer-sa
            containers:
            - name: kafka-consumer
              image: quay.io/strimzi/kafka:0.39.0-kafka-3.6.1
              command:
              - /bin/sh
              - -c
              - |
                bin/kafka-console-consumer.sh \
                  --bootstrap-server $BOOTSTRAP_SERVERS \
                  --topic $TOPIC \
                  --group $GROUP_ID \
                  --consumer-property auto.offset.reset=$AUTO_OFFSET_RESET
              envFrom:
              - configMapRef:
                  name: kafka-consumer-config
              resources:
                requests:
                  memory: "256Mi"
                  cpu: "100m"
                limits:
                  memory: "512Mi"
                  cpu: "500m"
            restartPolicy: Always
      INNEREOF
      git add .
      git -c user.email="lab@ckad.local" -c user.name="CKAD Lab" commit -m "initial commit"
      git push origin main || git push origin master
    volumeMounts:
    - name: repo-data
      mountPath: /git
  volumes:
  - name: repo-data
    emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: git-server
  namespace: argocd
spec:
  selector:
    app: git-server
  ports:
  - port: 9418
    targetPort: 9418
    name: git
EOF

kubectl apply -f git-server.yaml
kubectl wait --for=condition=Ready pod/git-server -n argocd --timeout=120s
```

2. Crear el recurso Application de Argo CD:

```bash
cat > argocd-application.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ckad-integrador
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git://git-server.argocd.svc.cluster.local/ckad-gitops-repo.git
    targetRevision: HEAD
    path: apps/kafka-consumer
  destination:
    server: https://kubernetes.default.svc
    namespace: kafka
  syncPolicy:
    syncOptions:
    - CreateNamespace=false
EOF

kubectl apply -f argocd-application.yaml
```

3. Verificar que la Application fue creada:

```bash
argocd app list
```

### Salida Esperada

```
NAME              CLUSTER                         NAMESPACE  PROJECT  STATUS     HEALTH   SYNCPOLICY  CONDITIONS
argocd/ckad-integrador  https://kubernetes.default.svc  kafka      default  OutOfSync  Missing  <none>      <none>
```

### Verificación

```bash
argocd app get ckad-integrador
# Debe mostrar Status: OutOfSync, Health: Missing (aún no sincronizado)
```

---

## Paso 4: Sincronizar la Application y Desplegar el Consumer

### Objetivo

Ejecutar la sincronización manual de Argo CD para desplegar los manifiestos del consumer de Kafka en el namespace `kafka`.

### Instrucciones

1. Ejecutar la sincronización:

```bash
argocd app sync ckad-integrador
```

2. Esperar a que los pods estén listos:

```bash
kubectl wait --for=condition=Available deployment/kafka-consumer-app \
  -n kafka --timeout=120s
```

3. Verificar el estado de la Application:

```bash
argocd app get ckad-integrador
```

4. Verificar los pods del consumer:

```bash
kubectl get pods -n kafka -l app=kafka-consumer
```

### Salida Esperada

```
NAME                                  READY   STATUS    RESTARTS   AGE
kafka-consumer-app-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
kafka-consumer-app-xxxxxxxxxx-yyyyy   1/1     Running   0          30s
```

### Verificación

```bash
# La app debe estar Synced y Healthy
argocd app get ckad-integrador | grep -E "Status|Health"
# Status:     Synced
# Health:     Healthy

# Verificar réplicas
kubectl get deploy kafka-consumer-app -n kafka -o jsonpath='{.spec.replicas}'
# Debe mostrar: 2
```

---

## Paso 5: Demostrar Drift Detection de Argo CD

### Objetivo

Modificar manualmente el número de réplicas del Deployment, observar que Argo CD detecta la desviación (OutOfSync), y restaurar el estado deseado mediante sync.

### Instrucciones

1. Escalar manualmente el Deployment a 1 réplica (simular drift):

```bash
kubectl scale deployment kafka-consumer-app -n kafka --replicas=1
```

2. Verificar que solo queda 1 pod:

```bash
kubectl get pods -n kafka -l app=kafka-consumer
```

3. Esperar unos segundos y consultar el estado de la Application en Argo CD:

```bash
sleep 10
argocd app get ckad-integrador | grep -E "Status|Health|Sync"
```

4. Observar el detalle del drift:

```bash
argocd app diff ckad-integrador
```

5. Restaurar el estado deseado ejecutando sync:

```bash
argocd app sync ckad-integrador
```

6. Verificar que las réplicas vuelven a 2:

```bash
kubectl get deploy kafka-consumer-app -n kafka
```

### Salida Esperada

Después del paso 3:
```
Sync Status:    OutOfSync
Health Status:  Healthy
```

Después del paso 6:
```
NAME                 READY   UP-TO-DATE   AVAILABLE   AGE
kafka-consumer-app   2/2     2            2           5m
```

### Verificación

```bash
argocd app get ckad-integrador | grep "Sync Status"
# Sync Status: Synced

kubectl get pods -n kafka -l app=kafka-consumer --no-headers | wc -l
# Debe mostrar: 2
```

---

## Paso 6: Instalar Crossplane y Crear un Recurso Declarativo

### Objetivo

Instalar Crossplane 1.15.1 con el Helm Provider 0.18.1 y crear un Release CR que gestione un ConfigMap de configuración avanzada como recurso Crossplane.

### Instrucciones

1. Instalar Crossplane via Helm:

```bash
kubectl create namespace crossplane-system

helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --version 1.15.1 \
  --wait --timeout 300s
```

2. Verificar que Crossplane está operativo:

```bash
kubectl get pods -n crossplane-system
kubectl get deploy -n crossplane-system
```

3. Instalar el Helm Provider:

```bash
cat > helm-provider.yaml << 'EOF'
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.18.1
EOF

kubectl apply -f helm-provider.yaml
```

4. Esperar a que el Provider esté healthy:

```bash
kubectl wait --for=condition=Healthy provider/provider-helm --timeout=180s
```

5. Crear el ProviderConfig para el Helm Provider (usar el clúster local):

```bash
cat > helm-providerconfig.yaml << 'EOF'
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: helm-provider-config
spec:
  credentials:
    source: InjectedIdentity
EOF

kubectl apply -f helm-providerconfig.yaml
```

6. Otorgar permisos al ServiceAccount del provider para operar en el namespace `kafka`:

```bash
# Obtener el SA del provider
PROVIDER_SA=$(kubectl get sa -n crossplane-system -o name | grep provider-helm | head -1 | cut -d/ -f2)

cat > provider-rbac.yaml << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-helm-admin
subjects:
- kind: ServiceAccount
  name: ${PROVIDER_SA}
  namespace: crossplane-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f provider-rbac.yaml
```

7. Crear un Release CR que despliegue un ConfigMap de configuración avanzada:

```bash
cat > crossplane-release.yaml << 'EOF'
apiVersion: helm.crossplane.io/v1beta1
kind: Release
metadata:
  name: kafka-advanced-config
spec:
  providerConfigRef:
    name: helm-provider-config
  forProvider:
    chart:
      name: raw
      repository: https://charts.helm.sh/incubator
      version: "0.2.5"
    namespace: kafka
    values:
      resources:
      - apiVersion: v1
        kind: ConfigMap
        metadata:
          name: kafka-advanced-config
          namespace: kafka
          labels:
            managed-by: crossplane
            project: ckad-integrador
        data:
          retention.ms: "604800000"
          max.message.bytes: "1048576"
          consumer.timeout.ms: "30000"
          platform: "ckad-kubernetes"
EOF

kubectl apply -f crossplane-release.yaml
```

8. Verificar el estado del Release:

```bash
kubectl get release kafka-advanced-config
```

### Salida Esperada

```
NAME                    CHART   VERSION   SYNCED   READY   STATE      AGE
kafka-advanced-config   raw     0.2.5     True     True    deployed   30s
```

> **Nota:** Si el chart `raw` del repositorio incubator no está disponible, el Release puede quedar en estado pendiente. En ese caso, como alternativa demostrativa, aplica directamente el ConfigMap:

```bash
# Alternativa si el Release no converge
cat > kafka-advanced-config-fallback.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-advanced-config
  namespace: kafka
  labels:
    managed-by: crossplane
    project: ckad-integrador
data:
  retention.ms: "604800000"
  max.message.bytes: "1048576"
  consumer.timeout.ms: "30000"
  platform: "ckad-kubernetes"
EOF

kubectl apply -f kafka-advanced-config-fallback.yaml
```

### Verificación

```bash
kubectl get configmap kafka-advanced-config -n kafka -o yaml | grep -A5 data
kubectl get providers
# Debe mostrar provider-helm con HEALTHY=True
```

---

## Paso 7: Validar la Integración Completa (GitOps → App → Kafka)

### Objetivo

Verificar que los pods del consumer están conectados al topic `ckad-messages` y pueden leer mensajes, completando la cadena de integración.

### Instrucciones

1. Producir mensajes de prueba al topic `ckad-messages`:

```bash
kubectl run kafka-producer-test -n kafka --rm -it \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.1 \
  --restart=Never -- \
  bin/kafka-console-producer.sh \
    --bootstrap-server ckad-kafka-cluster-kafka-bootstrap:9092 \
    --topic ckad-messages << 'EOF'
mensaje-integrador-1
mensaje-integrador-2
mensaje-integrador-3
EOF
```

> **Nota:** Si el comando interactivo no funciona directamente con heredoc, usa esta alternativa:

```bash
kubectl run kafka-producer-test -n kafka \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.1 \
  --restart=Never \
  --command -- /bin/sh -c '
    echo "mensaje-integrador-1" | bin/kafka-console-producer.sh \
      --bootstrap-server ckad-kafka-cluster-kafka-bootstrap:9092 \
      --topic ckad-messages;
    echo "mensaje-integrador-2" | bin/kafka-console-producer.sh \
      --bootstrap-server ckad-kafka-cluster-kafka-bootstrap:9092 \
      --topic ckad-messages;
    echo "mensaje-integrador-3" | bin/kafka-console-producer.sh \
      --bootstrap-server ckad-kafka-cluster-kafka-bootstrap:9092 \
      --topic ckad-messages
  '

# Esperar a que termine
kubectl wait --for=condition=Ready=false pod/kafka-producer-test -n kafka --timeout=60s 2>/dev/null || true
sleep 10
kubectl delete pod kafka-producer-test -n kafka --ignore-not-found
```

2. Revisar los logs de los pods consumer para confirmar la recepción de mensajes:

```bash
# Obtener nombre de un pod consumer
CONSUMER_POD=$(kubectl get pods -n kafka -l app=kafka-consumer \
  -o jsonpath='{.items[0].metadata.name}')

kubectl logs $CONSUMER_POD -n kafka --tail=20
```

3. Verificar el segundo pod consumer:

```bash
CONSUMER_POD2=$(kubectl get pods -n kafka -l app=kafka-consumer \
  -o jsonpath='{.items[1].metadata.name}')

kubectl logs $CONSUMER_POD2 -n kafka --tail=20
```

4. Verificar el estado final de todos los componentes:

```bash
echo "=== Argo CD Application ==="
argocd app get ckad-integrador --output json | jq '{status: .status.sync.status, health: .status.health.status}'

echo ""
echo "=== Kafka Consumer Pods ==="
kubectl get pods -n kafka -l app=kafka-consumer

echo ""
echo "=== Crossplane Provider ==="
kubectl get providers

echo ""
echo "=== ConfigMap de Crossplane ==="
kubectl get configmap kafka-advanced-config -n kafka
```

### Salida Esperada

```
=== Argo CD Application ===
{
  "status": "Synced",
  "health": "Healthy"
}

=== Kafka Consumer Pods ===
NAME                                  READY   STATUS    RESTARTS   AGE
kafka-consumer-app-xxxxxxxxxx-xxxxx   1/1     Running   0          10m
kafka-consumer-app-xxxxxxxxxx-yyyyy   1/1     Running   0          10m

=== Crossplane Provider ===
NAME            INSTALLED   HEALTHY   PACKAGE                                                    AGE
provider-helm   True        True      xpkg.upbound.io/crossplane-contrib/provider-helm:v0.18.1   5m

=== ConfigMap de Crossplane ===
NAME                    DATA   AGE
kafka-advanced-config   4      5m
```

### Verificación

```bash
# Los logs deben mostrar mensajes consumidos (al menos en uno de los pods)
kubectl logs -n kafka -l app=kafka-consumer --tail=5 | grep "mensaje-integrador" || \
  echo "NOTA: Los mensajes pueden tardar en aparecer si el consumer se conectó después de la producción"
```

---

## Paso 8: Crear Documento de Reflexión Final

### Objetivo

Documentar los componentes utilizados y su relación con los dominios del examen CKAD.

### Instrucciones

1. Crear el archivo NOTES.md:

```bash
cat > ~/ckad-labs/lab07/NOTES.md << 'EOF'
# Mini-Proyecto Integrador CKAD - Notas de Reflexión

## Componentes Utilizados

| Componente | Versión | Dominio CKAD |
|-----------|---------|--------------|
| Deployment | apps/v1 | Application Design & Build |
| ConfigMap | v1 | Application Design & Build |
| ServiceAccount | v1 | Application Security |
| Probes (Liveness/Readiness) | v1 | Application Observability & Maintenance |
| Argo CD Application | argoproj.io/v1alpha1 | Application Deployment (GitOps) |
| Crossplane Release | helm.crossplane.io/v1beta1 | Application Environment, Configuration & Security |
| Kafka (Strimzi) | kafka.strimzi.io/v1beta2 | Services & Networking |

## Relación entre Componentes

1. **Git → Argo CD**: El repositorio Git es la fuente de verdad declarativa
2. **Argo CD → Kubernetes**: Sincroniza manifiestos al clúster, detecta drift
3. **Deployment → Kafka**: Los pods consumer se conectan al broker via DNS interno
4. **Crossplane → Recursos**: Gestiona configuración como infraestructura declarativa

## Conceptos Clave Demostrados

- GitOps: Git como única fuente de verdad
- Drift Detection: Detección automática de desviaciones
- Infraestructura declarativa: Todo es un recurso Kubernetes
- Mensajería distribuida: Desacoplamiento producer/consumer
- DNS interno: Comunicación entre namespaces via FQDN
- Probes: Observabilidad y auto-healing de aplicaciones

## Fecha de Completado
$(date '+%Y-%m-%d %H:%M:%S')
EOF

cat ~/ckad-labs/lab07/NOTES.md
```

---

## Validación y Testing Final

Ejecutar el siguiente script de validación integral:

```bash
#!/bin/bash
echo "╔══════════════════════════════════════════════════╗"
echo "║  VALIDACIÓN FINAL - Mini-Proyecto Integrador    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

# Test 1: Argo CD operativo
if kubectl get deploy -n argocd argocd-server -o jsonpath='{.status.readyReplicas}' | grep -q "1"; then
  echo "✅ [PASS] Argo CD server operativo"
  ((PASS++))
else
  echo "❌ [FAIL] Argo CD server no está listo"
  ((FAIL++))
fi

# Test 2: Application sincronizada
SYNC_STATUS=$(argocd app get ckad-integrador -o json 2>/dev/null | jq -r '.status.sync.status')
if [ "$SYNC_STATUS" = "Synced" ]; then
  echo "✅ [PASS] Application ckad-integrador está Synced"
  ((PASS++))
else
  echo "❌ [FAIL] Application no está Synced (estado: $SYNC_STATUS)"
  ((FAIL++))
fi

# Test 3: Consumer pods running con 2 réplicas
CONSUMER_READY=$(kubectl get deploy kafka-consumer-app -n kafka -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$CONSUMER_READY" = "2" ]; then
  echo "✅ [PASS] kafka-consumer-app tiene 2 réplicas listas"
  ((PASS++))
else
  echo "❌ [FAIL] kafka-consumer-app no tiene 2 réplicas listas (tiene: $CONSUMER_READY)"
  ((FAIL++))
fi

# Test 4: Crossplane provider healthy
PROVIDER_HEALTHY=$(kubectl get provider provider-helm -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null)
if [ "$PROVIDER_HEALTHY" = "True" ]; then
  echo "✅ [PASS] Crossplane provider-helm está Healthy"
  ((PASS++))
else
  echo "❌ [FAIL] Crossplane provider-helm no está Healthy"
  ((FAIL++))
fi

# Test 5: ConfigMap de Crossplane existe
if kubectl get configmap kafka-advanced-config -n kafka &>/dev/null; then
  echo "✅ [PASS] ConfigMap kafka-advanced-config existe en namespace kafka"
  ((PASS++))
else
  echo "❌ [FAIL] ConfigMap kafka-advanced-config no encontrado"
  ((FAIL++))
fi

# Test 6: NOTES.md creado
if [ -f ~/ckad-labs/lab07/NOTES.md ]; then
  echo "✅ [PASS] NOTES.md creado correctamente"
  ((PASS++))
else
  echo "❌ [FAIL] NOTES.md no encontrado"
  ((FAIL++))
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "  Resultado: $PASS/6 pruebas pasadas, $FAIL fallidas"
echo "════════════════════════════════════════════════════"

if [ $FAIL -eq 0 ]; then
  echo "  🎉 ¡LABORATORIO COMPLETADO EXITOSAMENTE!"
else
  echo "  ⚠️  Revisa los items fallidos antes de continuar"
fi
```

---

## Troubleshooting

### Problema 1: Argo CD Application queda en estado "Unknown" o no puede conectar al repositorio Git

**Síntomas:**
```
FATA[0000] rpc error: code = Unknown desc = repository not accessible
```
La Application muestra `ComparisonError` y no puede leer del repositorio Git interno.

**Causa:** El pod `git-server` no está listo o el servicio DNS interno no resuelve `git-server.argocd.svc.cluster.local`. Esto ocurre si el initContainer falló al crear el repositorio bare o si el git-daemon no está escuchando en el puerto 9418.

**Solución:**
```bash
# Verificar el pod git-server
kubectl get pod git-server -n argocd
kubectl logs git-server -n argocd -c clone-repo
kubectl logs git-server -n argocd -c git-daemon

# Si el pod está en Error, recrearlo
kubectl delete pod git-server -n argocd
kubectl apply -f ~/ckad-labs/lab07/git-server.yaml
kubectl wait --for=condition=Ready pod/git-server -n argocd --timeout=120s

# Probar conectividad desde dentro del clúster
kubectl run test-git -n argocd --rm -it --image=alpine/git:2.43.0 \
  --restart=Never -- git ls-remote git://git-server.argocd.svc.cluster.local/ckad-gitops-repo.git
```

### Problema 2: Los pods kafka-consumer-app quedan en CrashLoopBackOff

**Síntomas:**
```
NAME                                  READY   STATUS             RESTARTS   AGE
kafka-consumer-app-xxxxxxxxxx-xxxxx   0/1     CrashLoopBackOff   3          2m
```
Los logs muestran: `WARN [Consumer clientId=...] Connection to node -1 could not be established. Broker may not be available.`

**Causa:** El bootstrap service de Kafka del laboratorio anterior no está accesible. Puede ser que el clúster Kafka se degradó, los pods de Kafka no están running, o el service `ckad-kafka-cluster-kafka-bootstrap` no existe en el namespace `kafka`.

**Solución:**
```bash
# Verificar que Kafka está operativo
kubectl get pods -n kafka -l strimzi.io/name=ckad-kafka-cluster-kafka
kubectl get svc ckad-kafka-cluster-kafka-bootstrap -n kafka

# Si los pods Kafka no están running, verificar el recurso Kafka
kubectl get kafka -n kafka
kubectl describe kafka ckad-kafka-cluster -n kafka | tail -20

# Probar conectividad al bootstrap desde un pod de prueba
kubectl run test-kafka -n kafka --rm -it \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.1 \
  --restart=Never -- \
  bin/kafka-broker-api-versions.sh \
    --bootstrap-server ckad-kafka-cluster-kafka-bootstrap:9092

# Si Kafka necesita reiniciarse
kubectl rollout restart statefulset/ckad-kafka-cluster-kafka -n kafka
kubectl wait --for=condition=Ready pod -l strimzi.io/name=ckad-kafka-cluster-kafka -n kafka --timeout=180s
```

---

## Limpieza

```bash
# Detener port-forward de Argo CD
kill $PF_PID 2>/dev/null || pkill -f "port-forward.*argocd"

# Eliminar la Application de Argo CD (esto elimina los recursos sincronizados)
argocd app delete ckad-integrador --yes 2>/dev/null || \
  kubectl delete application ckad-integrador -n argocd

# Eliminar recursos de Crossplane
kubectl delete release kafka-advanced-config 2>/dev/null
kubectl delete providerconfig helm-provider-config 2>/dev/null
kubectl delete provider provider-helm 2>/dev/null

# Desinstalar Crossplane
helm uninstall crossplane -n crossplane-system 2>/dev/null
kubectl delete namespace crossplane-system --ignore-not-found

# Eliminar git-server
kubectl delete pod git-server -n argocd --ignore-not-found
kubectl delete svc git-server -n argocd --ignore-not-found

# Desinstalar Argo CD
helm uninstall argocd -n argocd 2>/dev/null
kubectl delete namespace argocd --ignore-not-found

# Eliminar ConfigMap manual si se creó
kubectl delete configmap kafka-advanced-config -n kafka --ignore-not-found

# Limpiar repositorio local
rm -rf ~/ckad-gitops-repo /tmp/ckad-gitops-repo.git

# Limpiar archivos del lab
cd ~/ckad-labs/lab07
rm -f git-server.yaml argocd-application.yaml helm-provider.yaml \
  helm-providerconfig.yaml provider-rbac.yaml crossplane-release.yaml \
  kafka-advanced-config-fallback.yaml

echo "✅ Limpieza completada"
```

---

## Resumen

En este laboratorio integrador has completado el flujo completo de una plataforma Kubernetes moderna:

| Fase | Herramienta | Acción Realizada |
|------|-------------|------------------|
| 1. GitOps | Argo CD 2.10.1 | Instalación, creación de Application, sincronización manual |
| 2. Fuente de verdad | Git (repo local) | Repositorio estructurado con manifiestos del consumer |
| 3. Drift Detection | Argo CD | Modificación manual → OutOfSync → Sync para restaurar |
| 4. Infraestructura declarativa | Crossplane 1.15.1 | Provider Helm + Release CR para ConfigMap gestionado |
| 5. Mensajería | Kafka (Strimzi) | Consumer leyendo del topic `ckad-messages` |
| 6. Integración | Todos | Cadena completa GitOps → App → Kafka validada |

### Conceptos Clave Consolidados

- **GitOps**: Git como fuente de verdad + reconciliación automática = despliegues auditables y reproducibles
- **Drift Detection**: Argo CD detecta cualquier cambio manual y permite restaurar el estado deseado
- **Infraestructura como recurso**: Crossplane extiende la API de Kubernetes para gestionar cualquier recurso de forma declarativa
- **Mensajería distribuida**: Kafka desacopla productores y consumidores, aumentando la resiliencia
- **Modelo declarativo unificado**: Todas las herramientas se operan con `kubectl apply` y manifiestos YAML

### Recursos Adicionales

- [Documentación Argo CD — Application CRD](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/)
- [Crossplane — Helm Provider](https://marketplace.upbound.io/providers/crossplane-contrib/provider-helm/)
- [Strimzi — Kafka en Kubernetes](https://strimzi.io/documentation/)
- [GitOps Principles — OpenGitOps](https://opengitops.dev/)
