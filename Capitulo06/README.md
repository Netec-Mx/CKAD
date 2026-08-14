# Exposición interna con Service ClusterIP

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 35 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar (Apply) |
| **Namespace** | `ckad-network` |
| **Directorio de trabajo** | `~/ckad-labs/lab06/` |

---

## Descripción General

En este laboratorio desplegarás una aplicación backend con múltiples réplicas y la expondrás internamente mediante un Service de tipo ClusterIP. Practicarás la verificación de Endpoints, la resolución DNS interna en sus tres formatos (nombre corto, con namespace y FQDN), y diagnosticarás un escenario de troubleshooting donde los Endpoints quedan vacíos por un selector incorrecto. Finalmente, simularás una arquitectura multi-tier añadiendo un Service para una base de datos PostgreSQL.

---

## Objetivos de Aprendizaje

Al completar este laboratorio serás capaz de:

- [ ] Crear Services de tipo ClusterIP mediante `kubectl expose` y manifiestos YAML, conectando selectores a Pods de un Deployment
- [ ] Verificar la resolución DNS interna de Services usando los formatos `<service>`, `<service>.<namespace>` y `<service>.<namespace>.svc.cluster.local`
- [ ] Diagnosticar problemas de conectividad entre Services y Pods usando `kubectl describe service`, `kubectl get endpoints` y pruebas con `curl` desde Pods temporales
- [ ] Comprender el rol de los Endpoints como enlace dinámico entre un Service y los Pods seleccionados

---

## Prerrequisitos

### Conocimientos Previos

| Concepto | Nivel requerido |
|----------|----------------|
| Modelo de red plano de Kubernetes | Comprendido (Lección 6.1) |
| DNS interno: resolución de nombres y FQDN | Comprendido (Lección 6.1) |
| Deployments y ReplicaSets | Uso básico |
| `kubectl exec` para ejecutar comandos en Pods | Uso básico |

### Acceso y Herramientas

- Clúster Minikube en ejecución con Kubernetes 1.30.2
- `kubectl` configurado y funcional
- Aliases de kubectl activos (`k`, `kgp`, `kd`)
- El namespace `ckad-network` **no debe existir** previamente

---

## Entorno del Laboratorio

### Software Utilizado

| Componente | Versión / Imagen |
|------------|-----------------|
| Kubernetes (Minikube) | 1.30.2 |
| kubectl | 1.30.2 |
| nginx | `nginx:1.27.0` |
| PostgreSQL | `postgres:16.3` |
| curl (cliente) | `curlimages/curl:8.7.1` |

### Preparación Inicial

```bash
# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab06
cd ~/ckad-labs/lab06

# Verificar que Minikube está corriendo
minikube status

# Verificar que el namespace no existe
kubectl get namespace ckad-network 2>/dev/null && echo "ERROR: namespace ya existe" || echo "OK: namespace no existe"
```

---

## Paso a Paso

### Paso 1: Crear el Namespace y Configurar el Contexto

**Objetivo:** Crear el namespace `ckad-network` aislado para todos los recursos de este laboratorio.

**Instrucciones:**

1. Crea el namespace `ckad-network`:

```bash
kubectl create namespace ckad-network
```

2. Configura el contexto actual para usar este namespace por defecto:

```bash
kubectl config set-context --current --namespace=ckad-network
```

3. Verifica la configuración:

```bash
kubectl config view --minify | grep namespace
```

**Salida esperada:**

```
namespace: ckad-network
```

**Verificación:**

```bash
kubectl get all
```

Debe mostrar `No resources found in ckad-network namespace.`

---

### Paso 2: Desplegar el Backend con un Deployment

**Objetivo:** Crear un Deployment `backend-deploy` con 3 réplicas de nginx que servirá como aplicación backend.

**Instrucciones:**

1. Crea el archivo de manifiesto para el Deployment:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/backend-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-deploy
  namespace: ckad-network
  labels:
    app: backend
    tier: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: api
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 80
          name: http
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab06/backend-deploy.yaml
```

3. Espera a que las 3 réplicas estén listas:

```bash
kubectl rollout status deployment/backend-deploy --timeout=60s
```

**Salida esperada:**

```
deployment "backend-deploy" successfully rolled out
```

**Verificación:**

```bash
kubectl get pods -l app=backend -o wide
```

Debes ver 3 Pods en estado `Running`, cada uno con una IP diferente asignada. Toma nota de estas IPs; las necesitarás en pasos posteriores.

```
NAME                              READY   STATUS    RESTARTS   AGE   IP            NODE
backend-deploy-xxxxxxxxx-xxxxx   1/1     Running   0          30s   10.244.0.X    minikube
backend-deploy-xxxxxxxxx-xxxxx   1/1     Running   0          30s   10.244.0.Y    minikube
backend-deploy-xxxxxxxxx-xxxxx   1/1     Running   0          30s   10.244.0.Z    minikube
```

---

### Paso 3: Crear el Service ClusterIP con kubectl expose

**Objetivo:** Exponer el Deployment internamente mediante un Service de tipo ClusterIP usando el comando imperativo `kubectl expose`.

**Instrucciones:**

1. Crea el Service usando `kubectl expose`:

```bash
kubectl expose deployment backend-deploy \
  --name=backend-svc \
  --type=ClusterIP \
  --port=80 \
  --target-port=80
```

2. Verifica que el Service se creó correctamente:

```bash
kubectl get service backend-svc
```

**Salida esperada:**

```
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
backend-svc   ClusterIP   10.96.X.X       <none>        80/TCP    5s
```

3. Inspecciona los detalles del Service:

```bash
kubectl describe service backend-svc
```

**Salida esperada (fragmento relevante):**

```
Name:              backend-svc
Namespace:         ckad-network
Labels:            app=backend
                   tier=api
Selector:          app=backend
Type:              ClusterIP
IP:                10.96.X.X
Port:              <unset>  80/TCP
TargetPort:        80/TCP
Endpoints:         10.244.0.X:80,10.244.0.Y:80,10.244.0.Z:80
```

**Verificación:**

Confirma que los Endpoints contienen exactamente las IPs de los 3 Pods:

```bash
kubectl get endpoints backend-svc
```

```
NAME          ENDPOINTS                                      AGE
backend-svc   10.244.0.X:80,10.244.0.Y:80,10.244.0.Z:80   10s
```

Compara con las IPs de los Pods:

```bash
kubectl get pods -l app=backend -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}'
```

Las IPs deben coincidir exactamente con los Endpoints del Service.

---

### Paso 4: Desplegar el Pod Cliente para Pruebas de Conectividad

**Objetivo:** Crear un Pod persistente basado en `curlimages/curl:8.7.1` que permanezca activo para ejecutar múltiples pruebas de red.

**Instrucciones:**

1. Crea el manifiesto del Pod cliente:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/client-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: client-pod
  namespace: ckad-network
  labels:
    role: client
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.7.1
    command: ["sleep", "3600"]
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab06/client-pod.yaml
```

3. Espera a que el Pod esté listo:

```bash
kubectl wait --for=condition=Ready pod/client-pod --timeout=30s
```

**Salida esperada:**

```
pod/client-pod condition met
```

**Verificación:**

```bash
kubectl get pod client-pod
```

```
NAME         READY   STATUS    RESTARTS   AGE
client-pod   1/1     Running   0          10s
```

---

### Paso 5: Verificar Conectividad por Nombre Corto del Service

**Objetivo:** Demostrar que desde un Pod en el mismo namespace, se puede acceder al Service usando únicamente su nombre corto (`backend-svc`).

**Instrucciones:**

1. Ejecuta `curl` desde el Pod cliente usando el nombre corto:

```bash
kubectl exec client-pod -- curl -s http://backend-svc
```

**Salida esperada:**

Debes recibir la página HTML por defecto de nginx:

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
</head>
<body>
<h1>Welcome to nginx!</h1>
...
</body>
</html>
```

2. Verifica solo el código de respuesta HTTP:

```bash
kubectl exec client-pod -- curl -s -o /dev/null -w "%{http_code}" http://backend-svc
```

**Salida esperada:**

```
200
```

**Verificación:**

El nombre corto funciona porque el Pod cliente está en el mismo namespace `ckad-network` que el Service. Confirma revisando el `resolv.conf` del Pod:

```bash
kubectl exec client-pod -- cat /etc/resolv.conf
```

Debes ver un sufijo de búsqueda que incluye `ckad-network.svc.cluster.local`:

```
nameserver 10.96.0.10
search ckad-network.svc.cluster.local svc.cluster.local cluster.local
ndots:5
```

---

### Paso 6: Verificar Resolución DNS con Namespace y FQDN

**Objetivo:** Probar los tres formatos de resolución DNS: nombre corto, nombre con namespace y FQDN completo.

**Instrucciones:**

1. Accede usando el formato `<service>.<namespace>`:

```bash
kubectl exec client-pod -- curl -s -o /dev/null -w "%{http_code}" http://backend-svc.ckad-network
```

**Salida esperada:**

```
200
```

2. Accede usando el FQDN completo `<service>.<namespace>.svc.cluster.local`:

```bash
kubectl exec client-pod -- curl -s -o /dev/null -w "%{http_code}" http://backend-svc.ckad-network.svc.cluster.local
```

**Salida esperada:**

```
200
```

3. Verifica la resolución DNS de cada formato (la imagen `curlimages/curl` no tiene `nslookup`, usaremos la opción de verbose de curl):

```bash
# Resolución con nombre corto
kubectl exec client-pod -- curl -sv http://backend-svc 2>&1 | grep "Trying"

# Resolución con namespace
kubectl exec client-pod -- curl -sv http://backend-svc.ckad-network 2>&1 | grep "Trying"

# Resolución con FQDN
kubectl exec client-pod -- curl -sv http://backend-svc.ckad-network.svc.cluster.local 2>&1 | grep "Trying"
```

**Salida esperada:**

En los tres casos, la línea `Trying` mostrará la misma ClusterIP del Service:

```
* Trying 10.96.X.X:80...
```

**Verificación:**

Los tres formatos resuelven a la misma ClusterIP, confirmando que CoreDNS registra correctamente el Service y que los sufijos de búsqueda en `/etc/resolv.conf` permiten la resolución abreviada.

---

### Paso 7: Escenario de Troubleshooting — Selector Incorrecto

**Objetivo:** Simular un error de configuración modificando el selector del Service para que no coincida con ningún Pod, y luego diagnosticar y corregir el problema.

**Instrucciones:**

1. Modifica el Service para usar un selector incorrecto:

```bash
kubectl patch service backend-svc -p '{"spec":{"selector":{"app":"backend-wrong"}}}'
```

2. Verifica que los Endpoints ahora están vacíos:

```bash
kubectl get endpoints backend-svc
```

**Salida esperada:**

```
NAME          ENDPOINTS   AGE
backend-svc   <none>      2m
```

3. Intenta acceder al Service desde el Pod cliente:

```bash
kubectl exec client-pod -- curl -s --max-time 5 http://backend-svc
```

**Salida esperada:**

El comando fallará con un timeout o un error de conexión rechazada:

```
curl: (28) Connection timed out after 5000 milliseconds
```

O bien:

```
curl: (7) Failed to connect to backend-svc port 80 after X ms: Couldn't connect to server
```

4. **Diagnóstico:** Ejecuta los comandos de troubleshooting para identificar la causa:

```bash
# Verificar el selector actual del Service
kubectl describe service backend-svc | grep -A2 "Selector"

# Verificar que no hay Endpoints
kubectl get endpoints backend-svc

# Verificar qué labels tienen los Pods del backend
kubectl get pods -l app=backend --show-labels
```

**Salida del diagnóstico:**

```
Selector:          app=backend-wrong
```

```
NAME          ENDPOINTS   AGE
backend-svc   <none>      3m
```

```
NAME                              READY   STATUS    RESTARTS   AGE   LABELS
backend-deploy-xxx-xxx   1/1     Running   0          5m    app=backend,pod-template-hash=xxx,tier=api
```

El problema es claro: el selector del Service busca `app=backend-wrong`, pero los Pods tienen la label `app=backend`.

5. **Corrección:** Restaura el selector correcto:

```bash
kubectl patch service backend-svc -p '{"spec":{"selector":{"app":"backend"}}}'
```

6. Verifica que los Endpoints se restauraron:

```bash
kubectl get endpoints backend-svc
```

**Salida esperada:**

```
NAME          ENDPOINTS                                      AGE
backend-svc   10.244.0.X:80,10.244.0.Y:80,10.244.0.Z:80   4m
```

7. Confirma que la conectividad se restableció:

```bash
kubectl exec client-pod -- curl -s -o /dev/null -w "%{http_code}" http://backend-svc
```

**Salida esperada:**

```
200
```

**Verificación:**

La relación entre Service y Pods es dinámica y se basa exclusivamente en los selectores de labels. Cuando los selectores no coinciden, los Endpoints quedan vacíos y el Service no puede enrutar tráfico a ningún Pod.

---

### Paso 8: Crear el Service ClusterIP mediante Manifiesto YAML

**Objetivo:** Practicar la creación declarativa de un Service ClusterIP para una base de datos PostgreSQL, simulando una arquitectura multi-tier.

**Instrucciones:**

1. Crea el manifiesto del Pod de PostgreSQL:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/db-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
  namespace: ckad-network
  labels:
    app: database
    tier: data
spec:
  containers:
  - name: postgres
    image: postgres:16.3
    ports:
    - containerPort: 5432
      name: postgres
    env:
    - name: POSTGRES_PASSWORD
      value: "lab-password-2024"
    - name: POSTGRES_DB
      value: "appdb"
EOF
```

2. Crea el manifiesto del Service para la base de datos:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/db-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: db-svc
  namespace: ckad-network
  labels:
    app: database
    tier: data
spec:
  type: ClusterIP
  selector:
    app: database
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
    name: postgres
EOF
```

3. Aplica ambos manifiestos:

```bash
kubectl apply -f ~/ckad-labs/lab06/db-pod.yaml
kubectl apply -f ~/ckad-labs/lab06/db-svc.yaml
```

4. Espera a que el Pod de PostgreSQL esté listo:

```bash
kubectl wait --for=condition=Ready pod/db-pod --timeout=90s
```

**Salida esperada:**

```
pod/db-pod condition met
```

5. Verifica el Service y sus Endpoints:

```bash
kubectl get service db-svc
kubectl get endpoints db-svc
```

**Salida esperada:**

```
NAME     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
db-svc   ClusterIP   10.96.X.X      <none>        5432/TCP   10s

NAME     ENDPOINTS          AGE
db-svc   10.244.0.W:5432    10s
```

6. Prueba la conectividad TCP al Service de la base de datos desde el Pod cliente:

```bash
kubectl exec client-pod -- curl -sv telnet://db-svc:5432 --max-time 3 2>&1 | head -5
```

**Salida esperada (fragmento):**

```
* Trying 10.96.X.X:5432...
* Connected to db-svc (10.96.X.X) port 5432
```

La conexión TCP se establece, confirmando que el Service enruta correctamente al Pod de PostgreSQL.

**Verificación:**

```bash
# Verificar resolución DNS del Service de base de datos
kubectl exec client-pod -- curl -sv http://db-svc.ckad-network.svc.cluster.local:5432 --max-time 3 2>&1 | grep "Connected"
```

Debes ver la conexión exitosa al ClusterIP del Service `db-svc`.

---

### Paso 9: Verificar la Arquitectura Multi-Tier Completa

**Objetivo:** Confirmar que ambos Services están operativos y que el Pod cliente puede alcanzar tanto el backend como la base de datos por DNS interno.

**Instrucciones:**

1. Lista todos los Services en el namespace:

```bash
kubectl get services -n ckad-network
```

**Salida esperada:**

```
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
backend-svc   ClusterIP   10.96.X.X       <none>        80/TCP     10m
db-svc        ClusterIP   10.96.Y.Y       <none>        5432/TCP   2m
```

2. Lista todos los Endpoints:

```bash
kubectl get endpoints -n ckad-network
```

**Salida esperada:**

```
NAME          ENDPOINTS                                      AGE
backend-svc   10.244.0.X:80,10.244.0.Y:80,10.244.0.Z:80   10m
db-svc        10.244.0.W:5432                               2m
```

3. Ejecuta pruebas de conectividad completas desde el Pod cliente:

```bash
echo "=== Test: backend-svc (nombre corto) ==="
kubectl exec client-pod -- curl -s -o /dev/null -w "%{http_code}\n" http://backend-svc

echo "=== Test: backend-svc (FQDN) ==="
kubectl exec client-pod -- curl -s -o /dev/null -w "%{http_code}\n" http://backend-svc.ckad-network.svc.cluster.local

echo "=== Test: db-svc (conectividad TCP) ==="
kubectl exec client-pod -- curl -s --max-time 3 telnet://db-svc:5432 2>&1 | grep -c "Connected" && echo "OK" || echo "FAIL"
```

**Salida esperada:**

```
=== Test: backend-svc (nombre corto) ===
200
=== Test: backend-svc (FQDN) ===
200
=== Test: db-svc (conectividad TCP) ===
OK
```

---

## Validación y Testing

Ejecuta el siguiente script de validación integral para confirmar que todos los objetivos del laboratorio se han cumplido:

```bash
#!/bin/bash
echo "╔══════════════════════════════════════════════╗"
echo "║  Validación Lab 06-00-01 - Service ClusterIP ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

# Test 1: Namespace existe
echo -n "[1/8] Namespace ckad-network existe: "
if kubectl get namespace ckad-network &>/dev/null; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL"; ((FAIL++))
fi

# Test 2: Deployment con 3 réplicas
echo -n "[2/8] Deployment backend-deploy con 3/3 réplicas: "
READY=$(kubectl get deployment backend-deploy -n ckad-network -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$READY" == "3" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (ready: $READY)"; ((FAIL++))
fi

# Test 3: Service backend-svc existe y es ClusterIP
echo -n "[3/8] Service backend-svc tipo ClusterIP: "
TYPE=$(kubectl get service backend-svc -n ckad-network -o jsonpath='{.spec.type}' 2>/dev/null)
if [ "$TYPE" == "ClusterIP" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (type: $TYPE)"; ((FAIL++))
fi

# Test 4: Endpoints de backend-svc no vacíos (3 endpoints)
echo -n "[4/8] backend-svc tiene 3 endpoints: "
EP_COUNT=$(kubectl get endpoints backend-svc -n ckad-network -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | grep -o "ip" | wc -l)
if [ "$EP_COUNT" == "3" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (count: $EP_COUNT)"; ((FAIL++))
fi

# Test 5: Selector correcto en backend-svc
echo -n "[5/8] Selector de backend-svc es app=backend: "
SELECTOR=$(kubectl get service backend-svc -n ckad-network -o jsonpath='{.spec.selector.app}' 2>/dev/null)
if [ "$SELECTOR" == "backend" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (selector: $SELECTOR)"; ((FAIL++))
fi

# Test 6: Pod cliente existe y está Running
echo -n "[6/8] client-pod está Running: "
STATUS=$(kubectl get pod client-pod -n ckad-network -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$STATUS" == "Running" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (status: $STATUS)"; ((FAIL++))
fi

# Test 7: Service db-svc existe
echo -n "[7/8] Service db-svc existe y es ClusterIP: "
DB_TYPE=$(kubectl get service db-svc -n ckad-network -o jsonpath='{.spec.type}' 2>/dev/null)
if [ "$DB_TYPE" == "ClusterIP" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (type: $DB_TYPE)"; ((FAIL++))
fi

# Test 8: Conectividad HTTP desde client-pod a backend-svc
echo -n "[8/8] curl desde client-pod a backend-svc retorna 200: "
HTTP_CODE=$(kubectl exec client-pod -n ckad-network -- curl -s -o /dev/null -w "%{http_code}" http://backend-svc 2>/dev/null)
if [ "$HTTP_CODE" == "200" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (http_code: $HTTP_CODE)"; ((FAIL++))
fi

echo ""
echo "════════════════════════════════════"
echo "Resultado: $PASS/8 pruebas exitosas"
if [ $FAIL -eq 0 ]; then
  echo "🎉 ¡Laboratorio completado exitosamente!"
else
  echo "⚠️  Revisa los tests fallidos antes de continuar."
fi
echo "════════════════════════════════════"
```

Guarda y ejecuta:

```bash
cat <<'SCRIPT' > ~/ckad-labs/lab06/validate.sh
# (pegar el script anterior aquí)
SCRIPT
chmod +x ~/ckad-labs/lab06/validate.sh
bash ~/ckad-labs/lab06/validate.sh
```

---

## Troubleshooting

### Problema 1: El Pod cliente no puede resolver el nombre del Service

**Síntomas:**

```bash
kubectl exec client-pod -- curl -s http://backend-svc
# curl: (6) Could not resolve host: backend-svc
```

**Causa:** CoreDNS no está funcionando correctamente o el Pod no tiene la configuración DNS adecuada. Esto puede ocurrir si CoreDNS está en estado `CrashLoopBackOff` o si el Pod se creó con `dnsPolicy: None` sin configuración manual.

**Diagnóstico y Solución:**

```bash
# 1. Verificar que CoreDNS está corriendo
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Verificar la configuración DNS del Pod
kubectl exec client-pod -- cat /etc/resolv.conf

# 3. Si CoreDNS no está corriendo, reiniciar
kubectl rollout restart deployment/coredns -n kube-system

# 4. Si el resolv.conf no tiene los sufijos correctos, recrear el Pod
kubectl delete pod client-pod
kubectl apply -f ~/ckad-labs/lab06/client-pod.yaml
```

El archivo `/etc/resolv.conf` debe contener `search ckad-network.svc.cluster.local svc.cluster.local cluster.local` y un `nameserver` apuntando al ClusterIP del Service `kube-dns` (típicamente `10.96.0.10`).

---

### Problema 2: El Service tiene Endpoints pero curl retorna timeout

**Síntomas:**

```bash
kubectl get endpoints backend-svc
# Muestra IPs correctas

kubectl exec client-pod -- curl -s --max-time 5 http://backend-svc
# curl: (28) Connection timed out after 5000 milliseconds
```

**Causa:** Los Pods del backend están en estado `Running` pero el contenedor nginx no está escuchando en el puerto correcto, o existe un `NetworkPolicy` que bloquea el tráfico. Otra causa común es que `targetPort` del Service no coincide con el `containerPort` real del Pod.

**Diagnóstico y Solución:**

```bash
# 1. Verificar que nginx responde directamente por IP del Pod
POD_IP=$(kubectl get pod -l app=backend -o jsonpath='{.items[0].status.podIP}')
kubectl exec client-pod -- curl -s --max-time 3 http://$POD_IP:80

# 2. Verificar el puerto configurado en el Service
kubectl get service backend-svc -o jsonpath='{.spec.ports[0].targetPort}'
# Debe ser 80

# 3. Verificar que no hay NetworkPolicies bloqueando
kubectl get networkpolicies -n ckad-network

# 4. Si el targetPort es incorrecto, corregir:
kubectl patch service backend-svc -p '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'

# 5. Verificar que el contenedor escucha en el puerto esperado
kubectl exec -it $(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}') -- ss -tlnp
```

Si el problema es un `targetPort` incorrecto, la corrección del patch restaurará la conectividad inmediatamente.

---

## Limpieza

> **Nota:** Los recursos de este laboratorio (`backend-deploy`, `backend-svc`, `db-svc`, `db-pod`) se reutilizan en la **Práctica 25** (lab 06-00-02). **No ejecutes la limpieza** si vas a continuar con el siguiente laboratorio.

Si necesitas limpiar completamente el entorno:

```bash
# Eliminar todos los recursos del namespace
kubectl delete namespace ckad-network

# Restaurar el contexto al namespace anterior
kubectl config set-context --current --namespace=ckad-dev

# Verificar
kubectl config view --minify | grep namespace
```

---

## Resumen

### Conceptos Clave Practicados

| Concepto | Comando / Técnica |
|----------|-------------------|
| Creación imperativa de Service | `kubectl expose deployment --type=ClusterIP` |
| Creación declarativa de Service | Manifiesto YAML con `spec.type: ClusterIP` |
| Verificación de Endpoints | `kubectl get endpoints <service>` |
| DNS nombre corto | `curl http://backend-svc` (mismo namespace) |
| DNS con namespace | `curl http://backend-svc.ckad-network` |
| DNS FQDN | `curl http://backend-svc.ckad-network.svc.cluster.local` |
| Troubleshooting selector | `kubectl describe svc` + comparar labels de Pods |
| Diagnóstico de conectividad | Pod temporal con curl + verificación de Endpoints |

### Relación con el Modelo de Red

Este laboratorio demuestra en la práctica los conceptos de la Lección 6.1:

- Las **IPs de los Pods son efímeras** → por eso usamos Services con DNS estable
- El **DNS interno (CoreDNS)** registra automáticamente cada Service creado
- Los **Endpoints** son el enlace dinámico entre la IP virtual del Service y las IPs reales de los Pods
- El modelo de **red plano** permite que `client-pod` alcance cualquier Pod del backend sin NAT

### Recursos Adicionales

- [Documentación oficial: Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Documentación oficial: DNS para Services y Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Debugging Services en Kubernetes](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)

---

---

# Exposición externa básica

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 30 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar (Apply) |

## Descripción General

En este laboratorio expondrás aplicaciones del clúster Kubernetes al exterior utilizando dos mecanismos complementarios: **Service NodePort** para acceso directo por puerto del nodo, e **Ingress** para enrutamiento HTTP basado en paths. Trabajarás sobre los recursos existentes del namespace `ckad-network` creados en la Práctica 24, añadiendo un segundo Deployment frontend y configurando reglas de Ingress que demuestren el flujo completo de tráfico externo hasta los Pods.

## Objetivos de Aprendizaje

- [ ] Crear un Service de tipo NodePort y verificar acceso externo desde el host usando `minikube ip`
- [ ] Configurar un recurso Ingress con reglas path-based para enrutar tráfico HTTP a múltiples Services
- [ ] Verificar el flujo completo: host → Ingress Controller → Service ClusterIP → Pod
- [ ] Diagnosticar problemas comunes de Ingress usando `kubectl describe ingress` y `kubectl get endpoints`

## Prerrequisitos

### Conocimientos Previos

- Modelo de red plano de Kubernetes y DNS interno (Lección 6.1)
- Conceptos de Service ClusterIP y comunicación Pod-a-Pod
- Práctica 24 completada: namespace `ckad-network` con Deployment `backend-deploy` y Service `backend-svc` operativos

### Acceso Requerido

- Clúster minikube en ejecución con al menos 2 CPUs y 4 GB RAM
- Permisos de escritura en `/etc/hosts` del sistema host
- Conectividad a internet para descargar imágenes de contenedor

## Entorno de Laboratorio

### Software Requerido

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| minikube | 1.33.1 | Clúster Kubernetes local |
| kubectl | 1.30.2 | Gestión del clúster |
| curl | 8.5.0 | Pruebas de conectividad HTTP |
| nginx (imagen) | 1.27.0 | Aplicación de prueba |

### Preparación del Entorno

```bash
# Verificar que minikube está corriendo
minikube status

# Verificar el namespace ckad-network y recursos de la Práctica 24
kubectl get all -n ckad-network

# Crear directorio de trabajo para este laboratorio
mkdir -p ~/ckad-labs/lab06
cd ~/ckad-labs/lab06
```

**Salida esperada** (verificación de recursos previos):

```
NAME                                  READY   STATUS    RESTARTS   AGE
pod/backend-deploy-xxxxxxxxx-xxxxx    1/1     Running   0          XXm
pod/backend-deploy-xxxxxxxxx-xxxxx    1/1     Running   0          XXm

NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/backend-svc   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    XXm

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/backend-deploy   2/2     2            2           XXm
```

---

## Paso 1: Crear Service NodePort para el Backend

### Objetivo

Exponer el Deployment `backend-deploy` fuera del clúster mediante un Service de tipo NodePort en el puerto 30080, permitiendo acceso directo desde el host.

### Instrucciones

1. Crea el manifiesto del Service NodePort:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/backend-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-nodeport
  namespace: ckad-network
  labels:
    app: backend
    exposure: external
spec:
  type: NodePort
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab06/backend-nodeport.yaml
```

3. Verifica que el Service se creó correctamente:

```bash
kubectl get svc backend-nodeport -n ckad-network -o wide
```

4. Obtén la IP del nodo minikube:

```bash
minikube ip
```

5. Prueba el acceso externo desde el host:

```bash
curl -s http://$(minikube ip):30080
```

### Salida Esperada

```
service/backend-nodeport created
```

```
NAME               TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
backend-nodeport   NodePort   10.96.xxx.xxx   <none>        80:30080/TCP   5s
```

La respuesta de `curl` debe mostrar la página por defecto de nginx o el contenido configurado en `backend-deploy`:

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

### Verificación

```bash
# Confirmar que el NodePort 30080 está asignado
kubectl get svc backend-nodeport -n ckad-network -o jsonpath='{.spec.ports[0].nodePort}'
# Debe devolver: 30080

# Confirmar que los endpoints están poblados
kubectl get endpoints backend-nodeport -n ckad-network
# Debe mostrar IPs de los Pods del backend
```

---

## Paso 2: Habilitar el Addon Ingress en Minikube

### Objetivo

Activar el controlador Ingress NGINX en minikube para poder crear recursos Ingress que enruten tráfico HTTP.

### Instrucciones

1. Verifica si el addon ingress ya está habilitado:

```bash
minikube addons list | grep ingress
```

2. Si no está habilitado, actívalo:

```bash
minikube addons enable ingress
```

3. Espera a que el controlador Ingress esté completamente operativo:

```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

4. Verifica que los Pods del controlador están corriendo:

```bash
kubectl get pods -n ingress-nginx
```

### Salida Esperada

```
💡  ingress is an addon maintained by Kubernetes. For any concerns contact minikube on GitHub.
🔎  Verifying ingress addon...
🌟  The 'ingress' addon is enabled
```

```
pod/ingress-nginx-controller-xxxxx-xxxxx condition met
```

```
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-xxxxx        0/1     Completed   0          XXs
ingress-nginx-admission-patch-xxxxx         0/1     Completed   0          XXs
ingress-nginx-controller-xxxxx-xxxxx        1/1     Running     0          XXs
```

### Verificación

```bash
# Confirmar que el IngressClass nginx existe
kubectl get ingressclass
# Debe mostrar: nginx   nginx   ...
```

---

## Paso 3: Crear el Deployment y Service Frontend

### Objetivo

Desplegar una aplicación frontend con nginx sirviendo una página personalizada, expuesta internamente con un Service ClusterIP para ser utilizada por el Ingress.

### Instrucciones

1. Crea un ConfigMap con el contenido HTML personalizado para el frontend:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/frontend-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-html
  namespace: ckad-network
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Frontend - CKAD Lab</title></head>
    <body>
    <h1>Frontend Application</h1>
    <p>Served from frontend-deploy in ckad-network namespace</p>
    </body>
    </html>
EOF
```

2. Crea el Deployment del frontend con 2 réplicas:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/frontend-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deploy
  namespace: ckad-network
  labels:
    app: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: nginx
          image: nginx:1.27.0
          ports:
            - containerPort: 80
          volumeMounts:
            - name: html-volume
              mountPath: /usr/share/nginx/html
      volumes:
        - name: html-volume
          configMap:
            name: frontend-html
EOF
```

3. Crea el Service ClusterIP para el frontend:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/frontend-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: ckad-network
  labels:
    app: frontend
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF
```

4. Aplica todos los manifiestos:

```bash
kubectl apply -f ~/ckad-labs/lab06/frontend-configmap.yaml
kubectl apply -f ~/ckad-labs/lab06/frontend-deploy.yaml
kubectl apply -f ~/ckad-labs/lab06/frontend-svc.yaml
```

5. Verifica que los Pods del frontend están corriendo:

```bash
kubectl get pods -n ckad-network -l app=frontend
```

6. Verifica que el Service tiene endpoints:

```bash
kubectl get endpoints frontend-svc -n ckad-network
```

### Salida Esperada

```
configmap/frontend-html created
deployment.apps/frontend-deploy created
service/frontend-svc created
```

```
NAME                               READY   STATUS    RESTARTS   AGE
frontend-deploy-xxxxxxxxx-xxxxx    1/1     Running   0          15s
frontend-deploy-xxxxxxxxx-xxxxx    1/1     Running   0          15s
```

```
NAME           ENDPOINTS                         AGE
frontend-svc   10.244.x.x:80,10.244.x.x:80      20s
```

### Verificación

```bash
# Probar el frontend internamente desde un Pod de debug
kubectl run test-frontend --image=busybox:1.36.1 --rm -it --restart=Never \
  -n ckad-network -- wget -qO- http://frontend-svc.ckad-network.svc.cluster.local
```

Debe devolver el HTML personalizado con "Frontend Application".

---

## Paso 4: Crear el Recurso Ingress con Reglas Path-Based

### Objetivo

Configurar un recurso Ingress que enrute el tráfico HTTP basado en paths: `/backend` hacia `backend-svc` y `/frontend` hacia `frontend-svc`.

### Instrucciones

1. Crea el manifiesto del Ingress:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: ckad-network
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: app.ckad.local
      http:
        paths:
          - path: /backend
            pathType: Prefix
            backend:
              service:
                name: backend-svc
                port:
                  number: 80
          - path: /frontend
            pathType: Prefix
            backend:
              service:
                name: frontend-svc
                port:
                  number: 80
EOF
```

2. Aplica el recurso Ingress:

```bash
kubectl apply -f ~/ckad-labs/lab06/app-ingress.yaml
```

3. Verifica que el Ingress se creó y tiene una dirección asignada:

```bash
kubectl get ingress app-ingress -n ckad-network
```

> **Nota:** La columna ADDRESS puede tardar 30-60 segundos en poblarse con la IP del controlador.

4. Espera a que el Ingress tenga dirección asignada:

```bash
# Esperar hasta que ADDRESS esté disponible
for i in $(seq 1 12); do
  ADDRESS=$(kubectl get ingress app-ingress -n ckad-network -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -n "$ADDRESS" ]; then
    echo "Ingress ADDRESS: $ADDRESS"
    break
  fi
  echo "Esperando asignación de ADDRESS... ($i/12)"
  sleep 5
done
```

5. Examina los detalles del Ingress:

```bash
kubectl describe ingress app-ingress -n ckad-network
```

### Salida Esperada

```
ingress.networking.k8s.io/app-ingress created
```

```
NAME          CLASS   HOSTS            ADDRESS        PORTS   AGE
app-ingress   nginx   app.ckad.local   192.168.49.2   80      45s
```

La salida de `describe` debe mostrar:

```
Rules:
  Host            Path  Backends
  ----            ----  --------
  app.ckad.local
                  /backend    backend-svc:80 (10.244.x.x:80,10.244.x.x:80)
                  /frontend   frontend-svc:80 (10.244.x.x:80,10.244.x.x:80)
```

### Verificación

```bash
# Confirmar que ambos backends tienen endpoints activos
kubectl get endpoints backend-svc frontend-svc -n ckad-network
```

---

## Paso 5: Configurar Resolución DNS Local y Probar el Ingress

### Objetivo

Configurar la resolución del hostname `app.ckad.local` en el host y verificar que el Ingress enruta correctamente las solicitudes a cada Service según el path.

### Instrucciones

1. Añade la entrada DNS local en `/etc/hosts`:

```bash
# Obtener la IP de minikube
MINIKUBE_IP=$(minikube ip)
echo "IP de minikube: $MINIKUBE_IP"

# Agregar entrada en /etc/hosts (requiere sudo)
echo "$MINIKUBE_IP app.ckad.local" | sudo tee -a /etc/hosts
```

2. Verifica la resolución del nombre:

```bash
ping -c 1 app.ckad.local
```

3. Prueba el path `/backend` a través del Ingress:

```bash
curl -s http://app.ckad.local/backend
```

4. Prueba el path `/frontend` a través del Ingress:

```bash
curl -s http://app.ckad.local/frontend
```

5. Alternativamente, prueba sin modificar `/etc/hosts` usando el header `Host`:

```bash
curl -s -H "Host: app.ckad.local" http://$(minikube ip)/backend
curl -s -H "Host: app.ckad.local" http://$(minikube ip)/frontend
```

### Salida Esperada

Para `/backend` (página por defecto de nginx del backend):

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

Para `/frontend` (página personalizada del frontend):

```html
<!DOCTYPE html>
<html>
<head><title>Frontend - CKAD Lab</title></head>
<body>
<h1>Frontend Application</h1>
<p>Served from frontend-deploy in ckad-network namespace</p>
</body>
</html>
```

### Verificación

```bash
# Verificar que ambos paths responden con HTTP 200
curl -s -o /dev/null -w "%{http_code}" http://app.ckad.local/backend
# Debe devolver: 200

curl -s -o /dev/null -w "%{http_code}" http://app.ckad.local/frontend
# Debe devolver: 200
```

---

## Paso 6: Escenario de Troubleshooting — Ingress con Service Incorrecto

### Objetivo

Simular un error común de configuración de Ingress (nombre de Service incorrecto) y diagnosticarlo usando herramientas nativas de Kubernetes.

### Instrucciones

1. Crea un Ingress mal configurado con un nombre de Service que no existe:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/broken-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: broken-ingress
  namespace: ckad-network
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: broken.ckad.local
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend-api-svc
                port:
                  number: 80
EOF
```

2. Aplica el Ingress defectuoso:

```bash
kubectl apply -f ~/ckad-labs/lab06/broken-ingress.yaml
```

3. Intenta acceder al path — observarás un error 503:

```bash
curl -s -o /dev/null -w "%{http_code}" -H "Host: broken.ckad.local" http://$(minikube ip)/api
```

4. **Diagnóstico paso 1** — Inspecciona el Ingress:

```bash
kubectl describe ingress broken-ingress -n ckad-network
```

5. **Diagnóstico paso 2** — Verifica si el Service referenciado existe:

```bash
kubectl get svc backend-api-svc -n ckad-network
```

6. **Diagnóstico paso 3** — Lista los endpoints disponibles:

```bash
kubectl get endpoints -n ckad-network
```

7. **Corrección** — Identifica el nombre correcto del Service y actualiza el Ingress:

```bash
# Listar Services disponibles en el namespace
kubectl get svc -n ckad-network

# Corregir el manifiesto: cambiar 'backend-api-svc' por 'backend-svc'
sed -i 's/backend-api-svc/backend-svc/' ~/ckad-labs/lab06/broken-ingress.yaml

# Reaplicar
kubectl apply -f ~/ckad-labs/lab06/broken-ingress.yaml
```

8. Verifica que ahora funciona correctamente:

```bash
# Esperar unos segundos para que el controlador actualice la configuración
sleep 5

curl -s -o /dev/null -w "%{http_code}" -H "Host: broken.ckad.local" http://$(minikube ip)/api
```

### Salida Esperada

Paso 3 (antes de la corrección):

```
503
```

Paso 4 (describe ingress — indicadores del problema):

```
Rules:
  Host              Path  Backends
  ----              ----  --------
  broken.ckad.local
                    /api   backend-api-svc:80 (<error: endpoints "backend-api-svc" not found>)
```

Paso 5 (Service no encontrado):

```
Error from server (NotFound): services "backend-api-svc" not found
```

Paso 8 (después de la corrección):

```
200
```

### Verificación

```bash
# Confirmar que el Ingress corregido muestra endpoints válidos
kubectl describe ingress broken-ingress -n ckad-network | grep -A2 "Rules:" 
```

---

## Validación y Testing Final

Ejecuta esta secuencia completa de verificaciones para confirmar que todo el laboratorio funciona correctamente:

```bash
echo "=== Validación Completa del Lab 06-00-02 ==="
echo ""

# 1. Verificar Service NodePort
echo "1. Service NodePort (backend-nodeport):"
kubectl get svc backend-nodeport -n ckad-network -o jsonpath='{.spec.type}:{.spec.ports[0].nodePort}'
echo ""
NODEPORT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$(minikube ip):30080)
echo "   Acceso NodePort HTTP status: $NODEPORT_STATUS"
echo ""

# 2. Verificar Deployments
echo "2. Deployments activos:"
kubectl get deploy -n ckad-network -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,REPLICAS:.spec.replicas'
echo ""

# 3. Verificar Services
echo "3. Services en ckad-network:"
kubectl get svc -n ckad-network -o custom-columns='NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,PORTS:.spec.ports[*].port'
echo ""

# 4. Verificar Ingress
echo "4. Ingress resources:"
kubectl get ingress -n ckad-network
echo ""

# 5. Probar rutas del Ingress
echo "5. Pruebas de Ingress paths:"
BACKEND_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: app.ckad.local" http://$(minikube ip)/backend)
FRONTEND_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: app.ckad.local" http://$(minikube ip)/frontend)
echo "   /backend → HTTP $BACKEND_CODE"
echo "   /frontend → HTTP $FRONTEND_CODE"
echo ""

# 6. Resumen
echo "=== Resultados ==="
if [ "$NODEPORT_STATUS" = "200" ] && [ "$BACKEND_CODE" = "200" ] && [ "$FRONTEND_CODE" = "200" ]; then
  echo "✅ TODAS LAS VALIDACIONES PASARON"
else
  echo "❌ ALGUNAS VALIDACIONES FALLARON - Revisar pasos anteriores"
fi
```

**Salida esperada:**

```
=== Validación Completa del Lab 06-00-02 ===

1. Service NodePort (backend-nodeport):
NodePort:30080
   Acceso NodePort HTTP status: 200

2. Deployments activos:
NAME              READY   REPLICAS
backend-deploy    2       2
frontend-deploy   2       2

3. Services en ckad-network:
NAME               TYPE        CLUSTER-IP      PORTS
backend-nodeport   NodePort    10.96.x.x       80
backend-svc        ClusterIP   10.96.x.x       80
frontend-svc       ClusterIP   10.96.x.x       80

4. Ingress resources:
NAME             CLASS   HOSTS              ADDRESS        PORTS   AGE
app-ingress      nginx   app.ckad.local     192.168.49.2   80      Xm
broken-ingress   nginx   broken.ckad.local  192.168.49.2   80      Xm

5. Pruebas de Ingress paths:
   /backend → HTTP 200
   /frontend → HTTP 200

=== Resultados ===
✅ TODAS LAS VALIDACIONES PASARON
```

---

## Troubleshooting

### Problema 1: curl al NodePort devuelve "Connection refused"

**Síntomas:**

```bash
$ curl http://$(minikube ip):30080
curl: (7) Failed to connect to 192.168.49.2 port 30080: Connection refused
```

**Causa:** El selector del Service NodePort no coincide con las labels de los Pods del Deployment `backend-deploy`. Esto resulta en un Service sin endpoints, por lo que kube-proxy no tiene destino para enrutar el tráfico.

**Solución:**

```bash
# Verificar las labels del Deployment
kubectl get pods -n ckad-network -l app=backend --show-labels

# Verificar el selector del Service
kubectl get svc backend-nodeport -n ckad-network -o jsonpath='{.spec.selector}'

# Si no coinciden, editar el Service para que el selector sea correcto
kubectl edit svc backend-nodeport -n ckad-network
# Asegurar que spec.selector.app coincide con la label del Pod

# Verificar que los endpoints se poblaron
kubectl get endpoints backend-nodeport -n ckad-network
```

### Problema 2: Ingress devuelve 404 en lugar del contenido esperado

**Síntomas:**

```bash
$ curl -H "Host: app.ckad.local" http://$(minikube ip)/frontend
<html>
<head><title>404 Not Found</title></head>
...
```

**Causa:** La anotación `nginx.ingress.kubernetes.io/rewrite-target: /` no está presente en el Ingress, o el `pathType` está configurado como `Exact` en lugar de `Prefix`. Sin el rewrite, el controlador NGINX reenvía la solicitud al backend con el path original (`/frontend`), que no existe en el servidor nginx del Pod.

**Solución:**

```bash
# Verificar las anotaciones del Ingress
kubectl get ingress app-ingress -n ckad-network -o jsonpath='{.metadata.annotations}'

# Si falta la anotación rewrite-target, agregarla
kubectl annotate ingress app-ingress -n ckad-network \
  nginx.ingress.kubernetes.io/rewrite-target=/ --overwrite

# Verificar el pathType
kubectl get ingress app-ingress -n ckad-network -o jsonpath='{.spec.rules[0].http.paths[*].pathType}'
# Debe mostrar: Prefix Prefix

# Probar nuevamente después de la corrección (esperar 5s para que el controlador recargue)
sleep 5
curl -s -H "Host: app.ckad.local" http://$(minikube ip)/frontend
```

---

## Limpieza

```bash
# Eliminar el Ingress de troubleshooting
kubectl delete ingress broken-ingress -n ckad-network

# NOTA: NO eliminar app-ingress, frontend-deploy, frontend-svc ni backend-nodeport
# ya que pueden ser referenciados en módulos posteriores del curso.

# Eliminar la entrada de /etc/hosts (opcional, si se desea limpiar)
sudo sed -i '/app.ckad.local/d' /etc/hosts

# Verificar recursos restantes en el namespace
kubectl get all,ingress -n ckad-network
```

> **Importante:** Los recursos `app-ingress`, `frontend-deploy`, `frontend-svc`, `backend-nodeport` y los recursos originales de la Práctica 24 (`backend-deploy`, `backend-svc`) se mantienen en el namespace `ckad-network` para uso en laboratorios posteriores.

---

## Resumen

En este laboratorio has implementado los tres niveles de exposición de aplicaciones en Kubernetes:

| Mecanismo | Recurso | Acceso | Caso de Uso |
|-----------|---------|--------|-------------|
| **ClusterIP** | `backend-svc`, `frontend-svc` | Solo dentro del clúster | Comunicación interna entre microservicios |
| **NodePort** | `backend-nodeport` (puerto 30080) | IP del nodo + puerto fijo | Acceso directo para desarrollo/testing |
| **Ingress** | `app-ingress` | Hostname + path HTTP | Enrutamiento HTTP en producción |

**Conceptos clave aplicados:**

- El **DNS interno** de Kubernetes (CoreDNS) permite que el Ingress Controller resuelva los nombres de Service (`backend-svc`, `frontend-svc`) a sus ClusterIPs
- El modelo de **red plano** garantiza que el tráfico fluye sin NAT desde el controlador Ingress hasta los Pods destino
- El troubleshooting de Ingress se basa en verificar: existencia del Service, presencia de endpoints, correctitud del `serviceName` y configuración de anotaciones

### Recursos Adicionales

- [Documentación oficial de Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Ingress Controllers — NGINX](https://kubernetes.github.io/ingress-nginx/)
- [Service tipo NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport)
- [Debugging Ingress](https://kubernetes.github.io/ingress-nginx/troubleshooting/)

---

# Publicación con Ingress

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar |

## Descripción General

En este laboratorio desplegarás un recurso Ingress en Kubernetes para exponer dos aplicaciones HTTP distintas bajo un mismo host virtual (`lab26.local`) utilizando enrutamiento basado en paths (`/app1` y `/app2`). Configurarás el NGINX Ingress Controller como addon de minikube, crearás los Deployments y Services correspondientes, y validarás la conectividad extremo a extremo desde un cliente HTTP hasta los Pods backend, aplicando los conceptos de DNS interno y modelo de red plano estudiados en la lección.

## Objetivos de Aprendizaje

- [ ] Habilitar y verificar el NGINX Ingress Controller como addon de minikube
- [ ] Crear Deployments y Services ClusterIP para dos aplicaciones backend en un namespace dedicado
- [ ] Configurar un recurso Ingress con path-based routing que dirija tráfico a Services distintos
- [ ] Validar el enrutamiento HTTP extremo a extremo usando curl y resolución DNS local
- [ ] Interpretar la salida de `kubectl describe ingress` para diagnosticar configuraciones

## Prerrequisitos

### Conocimientos Previos

- Comprensión del modelo de red plano de Kubernetes y DNS interno (Lección 6.1)
- Familiaridad con Services ClusterIP y su resolución por nombre
- Conceptos HTTP: host headers, paths, códigos de respuesta (200, 404)
- Uso básico de `kubectl apply`, `kubectl get` y `kubectl describe`

### Acceso Requerido

- Terminal con acceso sudo para editar `/etc/hosts`
- Clúster minikube funcional con driver Docker
- Conectividad a Internet para descargar imágenes de contenedor

## Entorno del Laboratorio

### Software Requerido

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| minikube | 1.32.0+ | Clúster Kubernetes local |
| kubectl | 1.29.3+ | Gestión del clúster |
| Docker Engine | 26.x+ | Driver de minikube |
| curl | 8.x+ | Pruebas HTTP |

### Configuración Inicial del Entorno

```bash
# Crear directorio de trabajo para este laboratorio
mkdir -p ~/ckad-labs/lab26
cd ~/ckad-labs/lab26

# Verificar que minikube está corriendo
minikube status

# Si no está corriendo, iniciar con CNI Calico
minikube start --driver=docker --cni=calico

# Verificar conectividad con el clúster
kubectl cluster-info
```

---

## Paso 1: Habilitar el NGINX Ingress Controller

### Objetivo

Activar el addon `ingress` de minikube que despliega automáticamente el NGINX Ingress Controller versión 1.10.x en el namespace `ingress-nginx`.

### Instrucciones

1. Habilita el addon de Ingress en minikube:

```bash
minikube addons enable ingress
```

2. Espera a que el Pod del controlador esté en estado `Running`:

```bash
kubectl get pods -n ingress-nginx --watch
```

Presiona `Ctrl+C` cuando el Pod `ingress-nginx-controller-*` muestre `1/1 Running`.

3. Verifica que el controlador está completamente disponible:

```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Salida Esperada

```
pod/ingress-nginx-controller-xxxxx-xxxxx condition met
```

### Verificación

```bash
# Confirmar que el addon aparece como habilitado
minikube addons list | grep ingress

# Verificar los recursos del namespace ingress-nginx
kubectl get all -n ingress-nginx
```

Debes ver el Deployment, ReplicaSet, Pod y Service del controlador NGINX.

---

## Paso 2: Crear el Namespace del Laboratorio

### Objetivo

Crear el namespace `lab26` donde residirán todos los recursos de este laboratorio, manteniendo aislamiento respecto a otros namespaces del clúster.

### Instrucciones

1. Crea el manifiesto del namespace:

```bash
cat <<'YAML_END' > ~/ckad-labs/lab26/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: lab26
  labels:
    lab: "26"
    purpose: ingress-routing
YAML_END
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab26/namespace.yaml
```

3. Configura el contexto actual para usar `lab26` como namespace por defecto:

```bash
kubectl config set-context --current --namespace=lab26
```

### Salida Esperada

```
namespace/lab26 created
Context "minikube" modified.
```

### Verificación

```bash
kubectl config view --minify | grep namespace
```

Debe mostrar `namespace: lab26`.

---

## Paso 3: Desplegar las Aplicaciones Backend

### Objetivo

Crear dos Deployments (`app1` y `app2`) con la imagen `nginx:1.25.4-alpine`, cada uno sirviendo contenido HTML personalizado que identifique a qué aplicación pertenece la respuesta.

### Instrucciones

1. Crea el manifiesto para el Deployment de `app1`:

```bash
cat <<'YAML_END' > ~/ckad-labs/lab26/deployment-app1.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: lab26
  labels:
    app: app1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: nginx
        image: nginx:1.25.4-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      initContainers:
      - name: setup-html
        image: busybox:1.36.1
        command:
        - sh
        - -c
        - |
          echo '<html><body><h1>Respuesta desde APP1</h1><p>Path: /app1</p></body></html>' > /html/index.html
        volumeMounts:
        - name: html
          mountPath: /html
      volumes:
      - name: html
        emptyDir: {}
YAML_END
```

2. Crea el manifiesto para el Deployment de `app2`:

```bash
cat <<'YAML_END' > ~/ckad-labs/lab26/deployment-app2.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
  namespace: lab26
  labels:
    app: app2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: nginx
        image: nginx:1.25.4-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      initContainers:
      - name: setup-html
        image: busybox:1.36.1
        command:
        - sh
        - -c
        - |
          echo '<html><body><h1>Respuesta desde APP2</h1><p>Path: /app2</p></body></html>' > /html/index.html
        volumeMounts:
        - name: html
          mountPath: /html
      volumes:
      - name: html
        emptyDir: {}
YAML_END
```

3. Aplica ambos Deployments:

```bash
kubectl apply -f ~/ckad-labs/lab26/deployment-app1.yaml
kubectl apply -f ~/ckad-labs/lab26/deployment-app2.yaml
```

4. Espera a que todos los Pods estén listos:

```bash
kubectl wait --for=condition=ready pod --selector=app=app1 --timeout=60s
kubectl wait --for=condition=ready pod --selector=app=app2 --timeout=60s
```

### Salida Esperada

```
deployment.apps/app1 created
deployment.apps/app2 created
pod/app1-xxxxx-xxxxx condition met
pod/app1-xxxxx-xxxxx condition met
pod/app2-xxxxx-xxxxx condition met
pod/app2-xxxxx-xxxxx condition met
```

### Verificación

```bash
kubectl get pods -o wide
```

Debes ver 4 Pods (2 de app1, 2 de app2) en estado `Running`, cada uno con su propia IP asignada por el CNI, confirmando el modelo de red plano donde cada Pod tiene una IP única.

---

## Paso 4: Crear los Services ClusterIP

### Objetivo

Exponer cada Deployment mediante un Service ClusterIP que proporcione un punto de acceso estable con resolución DNS interna, siguiendo el patrón `<nombre-servicio>.<namespace>.svc.cluster.local`.

### Instrucciones

1. Crea el manifiesto de los Services:

```bash
cat <<'YAML_END' > ~/ckad-labs/lab26/services.yaml
apiVersion: v1
kind: Service
metadata:
  name: app1-svc
  namespace: lab26
  labels:
    app: app1
spec:
  type: ClusterIP
  selector:
    app: app1
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: app2-svc
  namespace: lab26
  labels:
    app: app2
spec:
  type: ClusterIP
  selector:
    app: app2
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
YAML_END
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab26/services.yaml
```

3. Verifica que los Services tienen ClusterIP asignada y endpoints activos:

```bash
kubectl get svc
kubectl get endpoints app1-svc app2-svc
```

### Salida Esperada

```
NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
app1-svc   ClusterIP   10.96.x.x      <none>        80/TCP    5s
app2-svc   ClusterIP   10.96.x.x      <none>        80/TCP    5s
```

Los endpoints deben mostrar las IPs de los Pods correspondientes (2 IPs por Service).

### Verificación

Valida la resolución DNS interna y la conectividad a los Services desde un Pod de depuración:

```bash
# Verificar resolución DNS interna del Service
kubectl run dns-test --image=busybox:1.36.1 --rm -it --restart=Never -- \
  nslookup app1-svc.lab26.svc.cluster.local

# Verificar conectividad HTTP al Service
kubectl run curl-test --image=busybox:1.36.1 --rm -it --restart=Never -- \
  wget -qO- http://app1-svc.lab26.svc.cluster.local
```

Debes ver la respuesta HTML "Respuesta desde APP1", confirmando que el DNS interno resuelve correctamente el nombre del Service a su ClusterIP.

---

## Paso 5: Crear el Recurso Ingress con Path-Based Routing

### Objetivo

Configurar un recurso Ingress que enrute peticiones HTTP al host `lab26.local` con paths `/app1` y `/app2` hacia los Services `app1-svc` y `app2-svc` respectivamente.

### Instrucciones

1. Crea el manifiesto del Ingress:

```bash
cat <<'YAML_END' > ~/ckad-labs/lab26/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: lab26-ingress
  namespace: lab26
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: lab26.local
    http:
      paths:
      - path: /app1
        pathType: Prefix
        backend:
          service:
            name: app1-svc
            port:
              number: 80
      - path: /app2
        pathType: Prefix
        backend:
          service:
            name: app2-svc
            port:
              number: 80
YAML_END
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab26/ingress.yaml
```

3. Verifica que el Ingress se creó correctamente:

```bash
kubectl get ingress lab26-ingress
```

4. Inspecciona los detalles del Ingress para confirmar que las reglas están correctamente configuradas:

```bash
kubectl describe ingress lab26-ingress
```

### Salida Esperada

```
NAME            CLASS   HOSTS        ADDRESS        PORTS   AGE
lab26-ingress   nginx   lab26.local  192.168.x.x    80      10s
```

El campo `ADDRESS` puede tardar 30-60 segundos en poblarse. Si aparece vacío, espera y vuelve a ejecutar `kubectl get ingress`.

La salida de `describe` debe mostrar:

```
Rules:
  Host        Path  Backends
  ----        ----  --------
  lab26.local
              /app1   app1-svc:80 (10.244.x.x:80,10.244.x.x:80)
              /app2   app2-svc:80 (10.244.x.x:80,10.244.x.x:80)
```

### Verificación

```bash
# Esperar a que el ADDRESS se asigne
kubectl get ingress lab26-ingress --watch
```

Presiona `Ctrl+C` cuando veas una IP en la columna ADDRESS.

---

## Paso 6: Configurar Resolución DNS Local

### Objetivo

Agregar una entrada en `/etc/hosts` que resuelva `lab26.local` a la IP del nodo minikube, permitiendo que curl pueda alcanzar el Ingress Controller usando el hostname configurado.

### Instrucciones

1. Obtén la IP del nodo minikube:

```bash
MINIKUBE_IP=$(minikube ip)
echo "IP de minikube: $MINIKUBE_IP"
```

2. Agrega la entrada al archivo `/etc/hosts`:

```bash
echo "$MINIKUBE_IP lab26.local" | sudo tee -a /etc/hosts
```

3. Verifica que la resolución funciona:

```bash
ping -c 1 lab26.local
```

### Salida Esperada

```
PING lab26.local (192.168.49.2) 56(84) bytes of data.
64 bytes from lab26.local (192.168.49.2): icmp_seq=1 ttl=64 time=0.xxx ms
```

### Verificación

```bash
# Confirmar que /etc/hosts contiene la entrada correcta
grep lab26.local /etc/hosts

# Verificar resolución con getent
getent hosts lab26.local
```

Debe mostrar la IP de minikube asociada a `lab26.local`.

---

## Paso 7: Validar el Enrutamiento HTTP Extremo a Extremo

### Objetivo

Probar que las peticiones HTTP a `lab26.local/app1` y `lab26.local/app2` son enrutadas correctamente a los backends correspondientes, y que paths no configurados devuelven un error 404.

### Instrucciones

1. Prueba el enrutamiento hacia `app1`:

```bash
curl -s http://lab26.local/app1
```

2. Prueba el enrutamiento hacia `app2`:

```bash
curl -s http://lab26.local/app2
```

3. Prueba un path no configurado para verificar el comportamiento por defecto (404):

```bash
curl -s -o /dev/null -w "%{http_code}" http://lab26.local/noexiste
```

4. Verifica los headers de respuesta para confirmar que NGINX Ingress Controller está sirviendo:

```bash
curl -sI http://lab26.local/app1 | head -10
```

### Salida Esperada

Para `/app1`:
```html
<html><body><h1>Respuesta desde APP1</h1><p>Path: /app1</p></body></html>
```

Para `/app2`:
```html
<html><body><h1>Respuesta desde APP2</h1><p>Path: /app2</p></body></html>
```

Para `/noexiste`:
```
404
```

Los headers deben incluir `Server: nginx` confirmando que el NGINX Ingress Controller está procesando las peticiones.

### Verificación

```bash
# Verificación completa con verbose output
curl -v http://lab26.local/app1 2>&1 | grep -E "(< HTTP|Respuesta)"

# Ejecutar múltiples peticiones para confirmar balanceo entre réplicas
for i in $(seq 1 6); do
  echo "--- Petición $i ---"
  curl -s http://lab26.local/app1
done
```

Todas las peticiones deben devolver la respuesta de APP1, confirmando que el path-based routing funciona correctamente.

---

## Paso 8: Diagnóstico y Troubleshooting

### Objetivo

Practicar técnicas de diagnóstico comunes para Ingress, incluyendo la revisión de logs del controlador y la verificación de la cadena completa de enrutamiento.

### Instrucciones

1. Revisa los logs del NGINX Ingress Controller para ver las peticiones procesadas:

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=20
```

2. Verifica la configuración NGINX generada internamente por el controlador:

```bash
kubectl exec -n ingress-nginx \
  $(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}') \
  -- cat /etc/nginx/nginx.conf | grep -A 5 "lab26.local"
```

3. Comprueba que los endpoints están correctamente asociados al Ingress:

```bash
kubectl describe ingress lab26-ingress | grep -A 10 "Rules:"
```

4. Verifica que no hay eventos de error en el namespace:

```bash
kubectl get events --sort-by='.lastTimestamp' | tail -10
```

### Salida Esperada

Los logs deben mostrar líneas de acceso HTTP 200 para las peticiones exitosas a `/app1` y `/app2`, y HTTP 404 para paths no configurados.

### Verificación

```bash
# Generar tráfico y verificar en logs
curl -s http://lab26.local/app1 > /dev/null
curl -s http://lab26.local/app2 > /dev/null
sleep 2
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=5
```

Debes ver entradas de log con código 200 y los paths `/app1` y `/app2`.

---

## Limpieza del Entorno

### Instrucciones de Limpieza

```bash
# Eliminar todos los recursos del namespace lab26
kubectl delete namespace lab26

# Restaurar el namespace por defecto en el contexto
kubectl config set-context --current --namespace=default

# Eliminar la entrada de /etc/hosts
sudo sed -i '/lab26.local/d' /etc/hosts

# (Opcional) Deshabilitar el addon de ingress si no se necesita más
# minikube addons disable ingress

# Verificar limpieza
kubectl get ns | grep lab26
grep lab26.local /etc/hosts
```

### Verificación de Limpieza

```bash
# Confirmar que el namespace fue eliminado
kubectl get ns lab26 2>&1 | grep "not found"

# Confirmar que /etc/hosts no contiene la entrada
grep -c lab26.local /etc/hosts
```

El primer comando debe devolver un error "not found" y el segundo debe devolver `0`.

---

## Resumen del Laboratorio

### Conceptos Aplicados

| Concepto | Recurso Kubernetes | Aplicación en el Lab |
|----------|-------------------|---------------------|
| Red plana | Pod IPs | Cada Pod recibió IP única del CNI Calico |
| DNS interno | CoreDNS | Services resueltos como `app1-svc.lab26.svc.cluster.local` |
| Service ClusterIP | Service | Abstracción estable sobre Pods efímeros |
| Ingress routing | Ingress | Enrutamiento L7 basado en host y path |
| Ingress Controller | NGINX Pod | Implementación del recurso Ingress |

### Flujo de Tráfico Completo

```
Cliente (curl) → /etc/hosts → lab26.local:80
  → minikube Node IP:80
    → NGINX Ingress Controller (NodePort)
      → Evalúa reglas: host=lab26.local, path=/app1
        → Service app1-svc (ClusterIP)
          → Pod app1 (IP del CNI)
            → Respuesta HTML
```

### Puntos Clave

1. **Ingress no es un balanceador**: Es un recurso declarativo; necesita un Ingress Controller que lo implemente
2. **Rewrite-target**: La anotación `nginx.ingress.kubernetes.io/rewrite-target: /` elimina el prefijo del path antes de enviar al backend
3. **IngressClassName**: En Kubernetes 1.18+ es obligatorio especificar la clase para evitar ambigüedad con múltiples controladores
4. **DNS interno vs externo**: Los Services se resuelven internamente por CoreDNS; el Ingress expone servicios al tráfico externo usando resolución DNS del cliente

### Troubleshooting Común

| Problema | Causa Probable | Solución |
|----------|---------------|----------|
| ADDRESS vacío en Ingress | Controller no procesó el recurso | Verificar `ingressClassName` y logs del controller |
| 404 en path válido | Rewrite-target incorrecto | Revisar anotación y pathType |
| 503 Service Unavailable | Endpoints vacíos | Verificar selector del Service y estado de Pods |
| Timeout en curl | /etc/hosts no configurado | Verificar resolución DNS local |

---

# Restricción de tráfico con NetworkPolicy

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 50 minutos |
| **Complejidad** | Hard |
| **Nivel Bloom** | Apply |
| **Tecnologías** | Kubernetes NetworkPolicy, Calico CNI 3.27.2, podSelector, namespaceSelector, kubectl exec |

## Descripción General

En este laboratorio aplicarás NetworkPolicies para controlar y restringir el tráfico de red entre Pods en un clúster Kubernetes. Partiendo de la topología existente del lab 26 (namespace `lab26` con `app1`, `app2` y sus Services), implementarás una política default-deny que interrumpe toda comunicación, y luego crearás políticas selectivas que permiten únicamente el tráfico autorizado. Introducirás un namespace externo (`lab27-client`) para demostrar el aislamiento entre namespaces y verificarás cada escenario con pruebas de conectividad reales.

## Objetivos de Aprendizaje

- [ ] Aplicar una NetworkPolicy default-deny-all que bloquee todo tráfico ingress y egress en un namespace
- [ ] Crear NetworkPolicies selectivas usando `podSelector` y `namespaceSelector` para permitir tráfico específico
- [ ] Verificar el aislamiento de red entre namespaces usando Pods de prueba con `wget`/`curl`
- [ ] Implementar políticas egress que restrinjan las conexiones salientes de un Pod específico
- [ ] Diagnosticar el impacto de NetworkPolicies en la comunicación Pod-a-Pod dentro del clúster

## Prerrequisitos

### Conocimientos Requeridos

- Modelo de red plano de Kubernetes: comunicación Pod-a-Pod sin NAT
- DNS interno de Kubernetes (`<servicio>.<namespace>.svc.cluster.local`)
- Selectores de etiquetas (`matchLabels`) en recursos Kubernetes
- Conceptos básicos de reglas de firewall (ingress/egress)

### Acceso y Recursos

- Lab 26 completado: namespace `lab26` con Deployments `app1`, `app2`, Services y Ingress operativos
- Clúster minikube con CNI Calico habilitado
- `kubectl` configurado y funcional
- Acceso a internet para descargar imagen `busybox:1.36.1`

## Entorno del Laboratorio

### Software Requerido

| Componente | Versión |
|------------|---------|
| minikube | 1.33.1 |
| kubectl | 1.30.2 |
| Calico CNI | 3.27.2 |
| busybox | 1.36.1 |
| nginx | 1.27.0 |

### Preparación del Directorio de Trabajo

```bash
mkdir -p ~/ckad-labs/lab06
cd ~/ckad-labs/lab06
```

### Verificación del Entorno Previo

Antes de comenzar, confirma que el namespace `lab26` y sus recursos del lab anterior están operativos:

```bash
# Verificar namespace lab26
kubectl get ns lab26

# Verificar Pods en lab26
kubectl get pods -n lab26 -o wide

# Verificar Services en lab26
kubectl get svc -n lab26

# Verificar que Calico está activo como CNI
kubectl get pods -n kube-system -l k8s-app=calico-node
```

**Salida esperada** (ejemplo):

```
NAME                    READY   STATUS    RESTARTS   AGE   IP            NODE
app1-xxxxxxxxx-xxxxx   1/1     Running   0          30m   10.244.1.10   minikube
app2-xxxxxxxxx-xxxxx   1/1     Running   0          30m   10.244.1.11   minikube
```

> **Nota:** Si el namespace `lab26` no existe o los Pods no están corriendo, consulta el lab 26 para recrear la topología antes de continuar.

---

## Paso a Paso

### Paso 1: Verificar la Comunicación Abierta (Estado Base)

**Objetivo:** Confirmar que, sin NetworkPolicies, todos los Pods pueden comunicarse libremente entre sí, demostrando el modelo de red plano de Kubernetes.

**Instrucciones:**

1. Obtén las IPs actuales de los Pods en `lab26`:

```bash
kubectl get pods -n lab26 -o wide --show-labels
```

2. Anota los nombres de los Pods y sus IPs. Almacénalos en variables para uso posterior:

```bash
APP1_POD=$(kubectl get pod -n lab26 -l app=app1 -o jsonpath='{.items[0].metadata.name}')
APP2_POD=$(kubectl get pod -n lab26 -l app=app2 -o jsonpath='{.items[0].metadata.name}')
APP1_IP=$(kubectl get pod -n lab26 -l app=app1 -o jsonpath='{.items[0].status.podIP}')
APP2_IP=$(kubectl get pod -n lab26 -l app=app2 -o jsonpath='{.items[0].status.podIP}')

echo "app1 Pod: $APP1_POD (IP: $APP1_IP)"
echo "app2 Pod: $APP2_POD (IP: $APP2_IP)"
```

3. Prueba la conectividad de `app1` hacia `app2` usando el Service:

```bash
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local
```

4. Prueba la conectividad de `app2` hacia `app1`:

```bash
kubectl exec -n lab26 $APP2_POD -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local
```

5. Prueba la conectividad directa por IP de Pod:

```bash
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=5 http://$APP2_IP
```

**Salida esperada:**

Cada comando debe devolver el contenido HTML del servicio de destino (página de nginx o respuesta de la aplicación), confirmando que la comunicación es libre.

**Verificación:**

```bash
# Todas las pruebas deben retornar exit code 0
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local > /dev/null 2>&1 && echo "✅ app1 → app2: PERMITIDO" || echo "❌ app1 → app2: BLOQUEADO"
kubectl exec -n lab26 $APP2_POD -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "✅ app2 → app1: PERMITIDO" || echo "❌ app2 → app1: BLOQUEADO"
```

---

### Paso 2: Aplicar Política Default-Deny-All (Ingress)

**Objetivo:** Crear una NetworkPolicy que bloquee todo el tráfico ingress hacia todos los Pods del namespace `lab26`, demostrando el comportamiento default-deny.

**Instrucciones:**

1. Crea el manifiesto de la política default-deny ingress:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/default-deny-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: lab26
spec:
  podSelector: {}
  policyTypes:
    - Ingress
EOF
```

> **Explicación:** Un `podSelector: {}` vacío selecciona **todos** los Pods del namespace. Al declarar `policyTypes: [Ingress]` sin definir reglas `ingress`, se bloquea todo tráfico entrante.

2. Aplica la política:

```bash
kubectl apply -f ~/ckad-labs/lab06/default-deny-ingress.yaml
```

3. Verifica que la política fue creada:

```bash
kubectl get networkpolicy -n lab26
```

**Salida esperada:**

```
NAME                   POD-SELECTOR   AGE
default-deny-ingress   <none>         5s
```

4. Prueba la conectividad nuevamente (debe fallar):

```bash
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local
```

**Salida esperada:**

```
wget: download timed out
command terminated with exit code 1
```

**Verificación:**

```bash
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ FALLO: tráfico debería estar bloqueado" || echo "✅ app1 → app2: BLOQUEADO (correcto)"
kubectl exec -n lab26 $APP2_POD -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ FALLO: tráfico debería estar bloqueado" || echo "✅ app2 → app1: BLOQUEADO (correcto)"
```

---

### Paso 3: Aplicar Política Default-Deny-All (Egress)

**Objetivo:** Complementar el aislamiento bloqueando también todo tráfico egress, creando un aislamiento completo en el namespace.

**Instrucciones:**

1. Crea el manifiesto de la política default-deny egress:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/default-deny-egress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: lab26
spec:
  podSelector: {}
  policyTypes:
    - Egress
EOF
```

2. Aplica la política:

```bash
kubectl apply -f ~/ckad-labs/lab06/default-deny-egress.yaml
```

3. Verifica ambas políticas activas:

```bash
kubectl get networkpolicy -n lab26
```

**Salida esperada:**

```
NAME                   POD-SELECTOR   AGE
default-deny-egress    <none>         5s
default-deny-ingress   <none>         2m
```

4. Confirma que ni siquiera la resolución DNS funciona (egress bloqueado incluye DNS):

```bash
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=3 http://app2.lab26.svc.cluster.local 2>&1 | head -5
```

**Salida esperada:**

```
wget: bad address 'app2.lab26.svc.cluster.local'
```

> **Nota importante:** Al bloquear egress, también se bloquea el tráfico UDP al puerto 53 (DNS). Esto impide la resolución de nombres. Las políticas que permitan tráfico deben incluir una regla para DNS si las aplicaciones lo necesitan.

**Verificación:**

```bash
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=3 http://$APP2_IP > /dev/null 2>&1 && echo "❌ FALLO: egress debería estar bloqueado" || echo "✅ Egress bloqueado correctamente"
```

---

### Paso 4: Permitir Tráfico DNS (Egress hacia CoreDNS)

**Objetivo:** Crear una política egress que permita a todos los Pods del namespace `lab26` resolver nombres DNS, habilitando tráfico UDP/TCP al puerto 53 hacia el namespace `kube-system`.

**Instrucciones:**

1. Verifica las etiquetas del namespace `kube-system`:

```bash
kubectl get ns kube-system --show-labels
```

2. Crea la política que permite DNS:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/allow-dns-egress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: lab26
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

3. Aplica la política:

```bash
kubectl apply -f ~/ckad-labs/lab06/allow-dns-egress.yaml
```

4. Verifica que la resolución DNS ahora funciona:

```bash
kubectl exec -n lab26 $APP1_POD -- nslookup app2.lab26.svc.cluster.local
```

**Salida esperada:**

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      app2.lab26.svc.cluster.local
Address 1: 10.96.x.x app2.lab26.svc.cluster.local
```

5. Confirma que la conectividad HTTP sigue bloqueada (ingress de app2 aún denegado):

```bash
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ No debería conectar" || echo "✅ HTTP sigue bloqueado (solo DNS permitido)"
```

**Verificación:**

```bash
kubectl get networkpolicy -n lab26
# Deben existir: default-deny-ingress, default-deny-egress, allow-dns-egress
```

---

### Paso 5: Permitir Tráfico Ingress hacia app1 desde el Ingress Controller

**Objetivo:** Crear una NetworkPolicy que permita tráfico ingress hacia `app1` únicamente desde el Ingress Controller que reside en el namespace `ingress-nginx` (o `kube-system` según la configuración de minikube).

**Instrucciones:**

1. Identifica el namespace donde reside el Ingress Controller:

```bash
# En minikube con addon ingress habilitado
kubectl get pods -A | grep ingress
```

> **Nota:** En minikube, el Ingress Controller suele estar en `ingress-nginx`. Ajusta el `namespaceSelector` según tu entorno.

2. Verifica las etiquetas del namespace del Ingress Controller:

```bash
kubectl get ns ingress-nginx --show-labels
```

3. Crea la política que permite ingress hacia app1 desde el Ingress Controller:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/allow-ingress-to-app1.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-app1
  namespace: lab26
spec:
  podSelector:
    matchLabels:
      app: app1
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - protocol: TCP
          port: 80
EOF
```

4. Aplica la política:

```bash
kubectl apply -f ~/ckad-labs/lab06/allow-ingress-to-app1.yaml
```

5. Verifica la política:

```bash
kubectl describe networkpolicy allow-ingress-to-app1 -n lab26
```

**Salida esperada (parcial):**

```
Name:         allow-ingress-to-app1
Namespace:    lab26
Spec:
  PodSelector:     app=app1
  Allowing ingress traffic:
    To Port: 80/TCP
    From:
      NamespaceSelector: kubernetes.io/metadata.name=ingress-nginx
```

**Verificación:**

La política está aplicada. El Ingress Controller podrá alcanzar app1, pero otros Pods aún no pueden.

---

### Paso 6: Permitir Comunicación entre app1 y app2 (Mismo Namespace)

**Objetivo:** Crear NetworkPolicies que permitan la comunicación bidireccional entre `app1` y `app2` dentro del namespace `lab26`, usando `podSelector`.

**Instrucciones:**

1. Crea la política que permite ingress hacia app2 desde app1:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/allow-app1-to-app2.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app1-to-app2
  namespace: lab26
spec:
  podSelector:
    matchLabels:
      app: app2
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: app1
      ports:
        - protocol: TCP
          port: 80
EOF
```

2. Crea la política egress que permite a app1 enviar tráfico hacia app2:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/allow-app1-egress-to-app2.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app1-egress-to-app2
  namespace: lab26
spec:
  podSelector:
    matchLabels:
      app: app1
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: app2
      ports:
        - protocol: TCP
          port: 80
EOF
```

3. Aplica ambas políticas:

```bash
kubectl apply -f ~/ckad-labs/lab06/allow-app1-to-app2.yaml
kubectl apply -f ~/ckad-labs/lab06/allow-app1-egress-to-app2.yaml
```

4. Prueba la conectividad de app1 hacia app2:

```bash
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local
```

**Salida esperada:**

Debe mostrar el contenido HTML de app2 (respuesta exitosa de nginx).

5. Confirma que app2 **no puede** alcanzar app1 (no se ha creado política egress para app2):

```bash
kubectl exec -n lab26 $APP2_POD -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ No debería conectar" || echo "✅ app2 → app1: BLOQUEADO (correcto)"
```

**Verificación:**

```bash
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local > /dev/null 2>&1 && echo "✅ app1 → app2: PERMITIDO" || echo "❌ FALLO: debería estar permitido"
```

---

### Paso 7: Crear Namespace Externo y Pod Cliente para Probar Aislamiento

**Objetivo:** Crear el namespace `lab27-client` con un Pod de prueba basado en `busybox:1.36.1` para demostrar que el tráfico desde namespaces externos está bloqueado por las NetworkPolicies.

**Instrucciones:**

1. Crea el namespace `lab27-client` con etiquetas:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/namespace-lab27-client.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: lab27-client
  labels:
    purpose: testing
    lab: "27"
EOF
kubectl apply -f ~/ckad-labs/lab06/namespace-lab27-client.yaml
```

2. Despliega un Pod cliente en el nuevo namespace:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/client-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-client
  namespace: lab27-client
  labels:
    role: client
spec:
  containers:
    - name: client
      image: busybox:1.36.1
      command: ["sleep", "3600"]
      resources:
        requests:
          cpu: 50m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 64Mi
EOF
kubectl apply -f ~/ckad-labs/lab06/client-pod.yaml
```

3. Espera a que el Pod esté Running:

```bash
kubectl wait --for=condition=Ready pod/test-client -n lab27-client --timeout=60s
```

4. Intenta conectar desde `lab27-client` hacia app1 en `lab26`:

```bash
kubectl exec -n lab27-client test-client -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local
```

**Salida esperada:**

```
wget: download timed out
command terminated with exit code 1
```

5. Intenta conectar hacia app2:

```bash
kubectl exec -n lab27-client test-client -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local
```

**Salida esperada:**

```
wget: download timed out
command terminated with exit code 1
```

**Verificación:**

```bash
kubectl exec -n lab27-client test-client -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ FALLO: namespace externo NO debería acceder" || echo "✅ lab27-client → app1: BLOQUEADO (aislamiento correcto)"
kubectl exec -n lab27-client test-client -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ FALLO: namespace externo NO debería acceder" || echo "✅ lab27-client → app2: BLOQUEADO (aislamiento correcto)"
```

---

### Paso 8: Permitir Acceso Selectivo desde lab27-client hacia app1

**Objetivo:** Crear una NetworkPolicy que permita tráfico ingress hacia `app1` únicamente desde Pods con label `role=client` en el namespace `lab27-client`, demostrando el uso combinado de `podSelector` y `namespaceSelector`.

**Instrucciones:**

1. Crea la política con selector combinado:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/allow-client-to-app1.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client-to-app1
  namespace: lab26
spec:
  podSelector:
    matchLabels:
      app: app1
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              purpose: testing
          podSelector:
            matchLabels:
              role: client
      ports:
        - protocol: TCP
          port: 80
EOF
```

> **Nota técnica:** Cuando `namespaceSelector` y `podSelector` están en el **mismo elemento** del array `from` (sin guión separador), actúan como AND lógico: el Pod debe cumplir **ambas** condiciones. Si estuvieran como elementos separados (cada uno con su guión), actuarían como OR.

2. Aplica la política:

```bash
kubectl apply -f ~/ckad-labs/lab06/allow-client-to-app1.yaml
```

3. Prueba la conectividad desde test-client hacia app1:

```bash
kubectl exec -n lab27-client test-client -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local
```

**Salida esperada:**

Debe mostrar el contenido HTML de app1 (conexión exitosa).

4. Crea un segundo Pod en `lab27-client` **sin** la etiqueta `role=client`:

```bash
kubectl run unauthorized-client -n lab27-client \
  --image=busybox:1.36.1 \
  --labels="role=unauthorized" \
  --restart=Never \
  --command -- sleep 3600

kubectl wait --for=condition=Ready pod/unauthorized-client -n lab27-client --timeout=60s
```

5. Verifica que el Pod no autorizado **no puede** acceder a app1:

```bash
kubectl exec -n lab27-client unauthorized-client -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ FALLO: Pod no autorizado accedió" || echo "✅ unauthorized-client → app1: BLOQUEADO (correcto)"
```

**Verificación:**

```bash
# Pod autorizado: debe conectar
kubectl exec -n lab27-client test-client -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "✅ test-client → app1: PERMITIDO" || echo "❌ FALLO"

# Pod no autorizado: debe ser bloqueado
kubectl exec -n lab27-client unauthorized-client -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ FALLO" || echo "✅ unauthorized-client → app1: BLOQUEADO"
```

---

### Paso 9: Restringir Egress de app2

**Objetivo:** Crear una política egress para `app2` que solo permita tráfico saliente hacia DNS (puerto 53) y nada más, demostrando que app2 queda completamente aislado en sus conexiones salientes.

**Instrucciones:**

1. Crea la política egress restrictiva para app2:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/restrict-app2-egress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-app2-egress
  namespace: lab26
spec:
  podSelector:
    matchLabels:
      app: app2
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

2. Aplica la política:

```bash
kubectl apply -f ~/ckad-labs/lab06/restrict-app2-egress.yaml
```

3. Verifica que app2 puede resolver DNS pero no conectar a otros servicios:

```bash
# DNS debe funcionar
kubectl exec -n lab26 $APP2_POD -- nslookup app1.lab26.svc.cluster.local

# Conexión HTTP debe fallar
kubectl exec -n lab26 $APP2_POD -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ FALLO: egress debería estar restringido" || echo "✅ app2 egress HTTP: BLOQUEADO (correcto)"
```

4. Verifica que app2 tampoco puede alcanzar IPs externas:

```bash
kubectl exec -n lab26 $APP2_POD -- wget -qO- --timeout=5 http://1.1.1.1 > /dev/null 2>&1 && echo "❌ FALLO: egress externo debería estar bloqueado" || echo "✅ app2 → internet: BLOQUEADO (correcto)"
```

**Salida esperada:**

```
✅ app2 egress HTTP: BLOQUEADO (correcto)
✅ app2 → internet: BLOQUEADO (correcto)
```

**Verificación:**

```bash
kubectl get networkpolicy -n lab26
```

Debe mostrar todas las políticas creadas:

```
NAME                        POD-SELECTOR   AGE
allow-app1-egress-to-app2   app=app1       10m
allow-app1-to-app2          app=app2       10m
allow-client-to-app1        app=app1       5m
allow-dns-egress            <none>         15m
allow-ingress-to-app1       app=app1       12m
default-deny-egress         <none>         18m
default-deny-ingress        <none>         20m
restrict-app2-egress        app=app2       2m
```

---

### Paso 10: Revisión Integral de Políticas y Estado Final

**Objetivo:** Documentar el estado final de todas las NetworkPolicies y realizar una prueba completa de la matriz de conectividad.

**Instrucciones:**

1. Lista todas las políticas con detalles:

```bash
kubectl get networkpolicy -n lab26 -o wide
```

2. Ejecuta la matriz completa de pruebas de conectividad:

```bash
echo "=== MATRIZ DE CONECTIVIDAD ==="
echo ""

# app1 → app2 (debe funcionar)
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local > /dev/null 2>&1 && echo "✅ app1 → app2: PERMITIDO" || echo "❌ app1 → app2: BLOQUEADO"

# app2 → app1 (debe estar bloqueado)
kubectl exec -n lab26 $APP2_POD -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ app2 → app1: PERMITIDO (inesperado)" || echo "✅ app2 → app1: BLOQUEADO"

# test-client → app1 (debe funcionar)
kubectl exec -n lab27-client test-client -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "✅ test-client → app1: PERMITIDO" || echo "❌ test-client → app1: BLOQUEADO"

# test-client → app2 (debe estar bloqueado)
kubectl exec -n lab27-client test-client -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ test-client → app2: PERMITIDO (inesperado)" || echo "✅ test-client → app2: BLOQUEADO"

# unauthorized-client → app1 (debe estar bloqueado)
kubectl exec -n lab27-client unauthorized-client -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1 && echo "❌ unauthorized → app1: PERMITIDO (inesperado)" || echo "✅ unauthorized → app1: BLOQUEADO"

echo ""
echo "=== FIN MATRIZ ==="
```

**Salida esperada:**

```
=== MATRIZ DE CONECTIVIDAD ===

✅ app1 → app2: PERMITIDO
✅ app2 → app1: BLOQUEADO
✅ test-client → app1: PERMITIDO
✅ test-client → app2: BLOQUEADO
✅ unauthorized → app1: BLOQUEADO

=== FIN MATRIZ ===
```

3. Exporta un resumen de las políticas para referencia en el lab 28:

```bash
kubectl get networkpolicy -n lab26 -o yaml > ~/ckad-labs/lab06/all-policies-export.yaml
echo "Políticas exportadas a ~/ckad-labs/lab06/all-policies-export.yaml"
```

---

## Validación y Testing

Ejecuta el siguiente script de validación integral para confirmar que el laboratorio se completó correctamente:

```bash
#!/bin/bash
echo "╔══════════════════════════════════════════════════╗"
echo "║  VALIDACIÓN LAB 06-00-04: NetworkPolicy          ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

# Test 1: Verificar existencia de políticas
POLICY_COUNT=$(kubectl get networkpolicy -n lab26 --no-headers 2>/dev/null | wc -l)
if [ "$POLICY_COUNT" -ge 7 ]; then
  echo "✅ Test 1: $POLICY_COUNT NetworkPolicies encontradas en lab26 (≥7)"
  ((PASS++))
else
  echo "❌ Test 1: Solo $POLICY_COUNT políticas encontradas (esperadas ≥7)"
  ((FAIL++))
fi

# Test 2: Verificar default-deny-ingress
kubectl get networkpolicy default-deny-ingress -n lab26 > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ Test 2: default-deny-ingress existe"
  ((PASS++))
else
  echo "❌ Test 2: default-deny-ingress no encontrada"
  ((FAIL++))
fi

# Test 3: Verificar default-deny-egress
kubectl get networkpolicy default-deny-egress -n lab26 > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ Test 3: default-deny-egress existe"
  ((PASS++))
else
  echo "❌ Test 3: default-deny-egress no encontrada"
  ((FAIL++))
fi

# Test 4: Verificar namespace lab27-client
kubectl get ns lab27-client > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ Test 4: Namespace lab27-client existe"
  ((PASS++))
else
  echo "❌ Test 4: Namespace lab27-client no encontrado"
  ((FAIL++))
fi

# Test 5: app1 puede alcanzar app2
APP1_POD=$(kubectl get pod -n lab26 -l app=app1 -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n lab26 $APP1_POD -- wget -qO- --timeout=5 http://app2.lab26.svc.cluster.local > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ Test 5: app1 → app2 permitido"
  ((PASS++))
else
  echo "❌ Test 5: app1 → app2 bloqueado (debería estar permitido)"
  ((FAIL++))
fi

# Test 6: app2 NO puede alcanzar app1
APP2_POD=$(kubectl get pod -n lab26 -l app=app2 -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n lab26 $APP2_POD -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "✅ Test 6: app2 → app1 bloqueado (correcto)"
  ((PASS++))
else
  echo "❌ Test 6: app2 → app1 permitido (debería estar bloqueado)"
  ((FAIL++))
fi

# Test 7: test-client puede alcanzar app1
kubectl exec -n lab27-client test-client -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ Test 7: test-client → app1 permitido"
  ((PASS++))
else
  echo "❌ Test 7: test-client → app1 bloqueado (debería estar permitido)"
  ((FAIL++))
fi

# Test 8: unauthorized-client NO puede alcanzar app1
kubectl exec -n lab27-client unauthorized-client -- wget -qO- --timeout=5 http://app1.lab26.svc.cluster.local > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "✅ Test 8: unauthorized-client → app1 bloqueado (correcto)"
  ((PASS++))
else
  echo "❌ Test 8: unauthorized-client → app1 permitido (debería estar bloqueado)"
  ((FAIL++))
fi

echo ""
echo "════════════════════════════════════════"
echo "  Resultado: $PASS aprobados / $FAIL fallidos"
echo "════════════════════════════════════════"
```

Guarda y ejecuta:

```bash
cat << 'SCRIPT' > ~/ckad-labs/lab06/validate.sh
# (pegar el script anterior aquí)
SCRIPT
chmod +x ~/ckad-labs/lab06/validate.sh
bash ~/ckad-labs/lab06/validate.sh
```

---

## Troubleshooting

### Problema 1: Las NetworkPolicies no tienen efecto (el tráfico sigue pasando)

**Síntomas:**
- Después de aplicar `default-deny-ingress`, los Pods siguen comunicándose normalmente.
- `kubectl get networkpolicy -n lab26` muestra las políticas, pero no bloquean tráfico.

**Causa:**
El CNI del clúster no soporta NetworkPolicies. Plugins como `kindnet` (default en kind) o `bridge` (default en minikube sin configuración adicional) **no implementan** NetworkPolicies. Solo plugins como **Calico**, **Cilium** o **Weave** las aplican.

**Solución:**

```bash
# Verificar qué CNI está activo
kubectl get pods -n kube-system | grep -E "calico|cilium|weave"

# Si no hay Calico, reiniciar minikube con Calico:
minikube delete
minikube start --cni=calico --memory=4096 --cpus=4

# Esperar a que Calico esté Ready
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n kube-system --timeout=120s

# Verificar
kubectl get pods -n kube-system -l k8s-app=calico-node
```

Después de reiniciar con Calico, deberás recrear los recursos del lab 26 y volver a aplicar las NetworkPolicies.

---

### Problema 2: La resolución DNS falla incluso después de aplicar allow-dns-egress

**Síntomas:**
- `nslookup` desde los Pods devuelve `wget: bad address` o `;; connection timed out`.
- La política `allow-dns-egress` está aplicada según `kubectl get networkpolicy`.

**Causa:**
La etiqueta del namespace `kube-system` usada en el `namespaceSelector` no coincide. Kubernetes no siempre aplica la etiqueta `kubernetes.io/metadata.name` automáticamente en versiones anteriores, o el CoreDNS puede estar en un namespace diferente.

**Solución:**

```bash
# Verificar las etiquetas reales del namespace kube-system
kubectl get ns kube-system -o jsonpath='{.metadata.labels}' | jq .

# Si la etiqueta no existe, agregarla manualmente:
kubectl label namespace kube-system kubernetes.io/metadata.name=kube-system --overwrite

# Verificar dónde está CoreDNS y su IP de servicio
kubectl get svc -n kube-system kube-dns
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

# Alternativa: usar CIDR del Service DNS directamente en la política
cat <<'EOF' > ~/ckad-labs/lab06/allow-dns-egress-cidr.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: lab26
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 10.96.0.10/32
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
kubectl apply -f ~/ckad-labs/lab06/allow-dns-egress-cidr.yaml
```

> **Nota:** Reemplaza `10.96.0.10` con la IP real del servicio `kube-dns` obtenida con `kubectl get svc kube-dns -n kube-system`.

---

## Limpieza

Para eliminar todos los recursos creados en este laboratorio **sin afectar** los recursos del lab 26 necesarios para el lab 28:

```bash
# Eliminar solo las NetworkPolicies (mantener Pods y Services del lab26)
kubectl delete networkpolicy --all -n lab26

# Eliminar el namespace de prueba
kubectl delete namespace lab27-client

# Verificar que los Pods del lab26 siguen operativos
kubectl get pods -n lab26

# Eliminar archivos locales (opcional, se usan como referencia en lab 28)
# rm -rf ~/ckad-labs/lab06/
```

> **Importante:** Si deseas mantener las NetworkPolicies para el lab 28 (troubleshooting), **no ejecutes** el comando `kubectl delete networkpolicy --all`. El lab 28 asume que estas políticas están activas como escenario de diagnóstico.

---

## Resumen

En este laboratorio has aplicado los conceptos fundamentales de aislamiento de red en Kubernetes:

| Concepto | Implementación |
|----------|---------------|
| Default-deny ingress | `podSelector: {}` + `policyTypes: [Ingress]` sin reglas |
| Default-deny egress | `podSelector: {}` + `policyTypes: [Egress]` sin reglas |
| Permitir DNS | Egress al puerto 53 UDP/TCP hacia `kube-system` |
| Ingress selectivo por namespace | `namespaceSelector` + `podSelector` combinados (AND lógico) |
| Egress restrictivo por Pod | `podSelector` específico con reglas egress limitadas |
| Aislamiento entre namespaces | Demostrado con `lab27-client` y selector de etiquetas |

### Puntos Clave

- Las NetworkPolicies son **aditivas**: múltiples políticas que seleccionan el mismo Pod combinan sus reglas (unión de lo permitido).
- Un `podSelector: {}` vacío selecciona **todos** los Pods del namespace.
- Sin un CNI que soporte NetworkPolicies (como Calico), las políticas se crean pero **no se aplican**.
- Bloquear egress también bloquea DNS; siempre incluir una regla para el puerto 53.
- `namespaceSelector` y `podSelector` en el **mismo bloque** `from` actúan como AND; en **bloques separados** actúan como OR.

### Recursos Adicionales

- [Documentación oficial: NetworkPolicies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Editor visual de NetworkPolicy](https://editor.networkpolicy.io/)
- [Recetas de NetworkPolicy por Ahmet Alp Balkan](https://github.com/ahmetb/kubernetes-network-policy-recipes)
- [Calico: Guía de NetworkPolicies](https://docs.tigera.io/calico/latest/network-policy/)

---

# Troubleshooting de conectividad

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 30 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar (Apply) |
| **Módulo** | 6 — Modelo de red Kubernetes |
| **Directorio de trabajo** | `~/ckad-labs/lab06/` |

## Descripción General

En este laboratorio aplicarás una metodología sistemática de diagnóstico para identificar y corregir cuatro escenarios de fallo de conectividad de red deliberadamente introducidos en un clúster Kubernetes. Los escenarios cubren misconfiguraciones comunes en Services, Ingress y NetworkPolicies que un desarrollador de aplicaciones encontrará en entornos reales. Al finalizar, toda la conectividad del entorno lab26 quedará completamente restaurada y funcional.

## Objetivos de Aprendizaje

- [ ] Aplicar una metodología sistemática de diagnóstico (DNS → Service → Endpoints → Pod → NetworkPolicy) para resolver problemas de conectividad
- [ ] Usar herramientas nativas de kubectl (`describe`, `logs`, `exec`, `get endpoints`) para identificar la causa raíz de fallos de red
- [ ] Identificar y corregir cuatro escenarios de fallo predefinidos: selector incorrecto, Ingress mal configurado, NetworkPolicy restrictiva y Pod sin etiquetas correctas
- [ ] Validar la restauración completa de conectividad end-to-end mediante pruebas desde dentro y fuera del clúster

## Prerrequisitos

### Conocimientos Requeridos

- Comprensión de la relación entre Service selectors, Pod labels y Endpoints
- Familiaridad con los campos `spec` de Ingress: `rules`, `backend`, `pathType`
- Conocimiento del modelo de red plano de Kubernetes y DNS interno
- Experiencia básica con `kubectl describe`, `kubectl logs` y `kubectl exec`

### Acceso Requerido

- Clúster minikube operativo con addon `ingress` habilitado
- Namespace `lab26` con los recursos de los labs 26 y 27 desplegados
- Acceso a `kubectl` con contexto configurado

## Entorno del Laboratorio

### Software Necesario

| Herramienta | Versión |
|-------------|---------|
| minikube | 1.33.1 |
| kubectl | 1.30.2 |
| busybox (imagen) | 1.36.1 |
| nginx (imagen) | 1.27.0 |

### Preparación del Entorno

Antes de introducir los escenarios de fallo, debemos asegurar que el entorno base de lab26 existe y funciona correctamente. Si ya completaste los labs 26 y 27, puedes saltar al Paso 1.

```bash
# Verificar que minikube está corriendo
minikube status

# Verificar que el addon ingress está habilitado
minikube addons list | grep ingress

# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab06
cd ~/ckad-labs/lab06

# Verificar namespace lab26
kubectl get ns lab26
```

Si el namespace `lab26` no existe, crea el entorno base con los siguientes manifiestos:

```bash
# Crear namespace lab26
kubectl create namespace lab26
```

```bash
# Crear el manifiesto base del entorno
cat <<'EOF' > ~/ckad-labs/lab06/lab26-base.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: lab26
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
      tier: frontend
  template:
    metadata:
      labels:
        app: web-app
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-svc
  namespace: lab26
spec:
  selector:
    app: web-app
    tier: frontend
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
  namespace: lab26
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: web-app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app-svc
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-web
  namespace: lab26
spec:
  podSelector:
    matchLabels:
      app: web-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 80
EOF
```

```bash
# Aplicar el entorno base
kubectl apply -f ~/ckad-labs/lab06/lab26-base.yaml

# Esperar a que los Pods estén Ready
kubectl wait --for=condition=Ready pod -l app=web-app -n lab26 --timeout=60s
```

**Verificación del entorno base:**

```bash
# Confirmar Pods corriendo
kubectl get pods -n lab26 -o wide

# Confirmar Service con Endpoints
kubectl get endpoints web-app-svc -n lab26

# Confirmar Ingress configurado
kubectl get ingress -n lab26
```

Salida esperada (ejemplo):
```
NAME                          READY   STATUS    RESTARTS   AGE   IP            NODE
web-app-6d4f8b7c9d-abc12     1/1     Running   0          30s   10.244.0.15   minikube
web-app-6d4f8b7c9d-def34     1/1     Running   0          30s   10.244.0.16   minikube
```

---

## Paso a Paso

### Paso 1: Introducir los Escenarios de Fallo

**Objetivo:** Aplicar deliberadamente cuatro misconfiguraciones que rompen la conectividad del entorno. Esto simula un escenario real donde heredas un clúster con problemas.

**Instrucciones:**

1. Ejecuta el siguiente script que introduce los cuatro fallos simultáneamente:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/break-connectivity.sh
#!/bin/bash
echo "=== Introduciendo Escenario 1: Service con selector incorrecto ==="
kubectl patch service web-app-svc -n lab26 --type='json' \
  -p='[{"op": "replace", "path": "/spec/selector/app", "value": "web-application"}]'

echo "=== Introduciendo Escenario 2: Ingress con pathType incorrecto y backend erróneo ==="
kubectl patch ingress web-app-ingress -n lab26 --type='json' \
  -p='[{"op": "replace", "path": "/spec/rules/0/http/paths/0/pathType", "value": "Exact"},{"op": "replace", "path": "/spec/rules/0/http/paths/0/backend/service/name", "value": "web-app-service"}]'

echo "=== Introduciendo Escenario 3: NetworkPolicy demasiado restrictiva ==="
kubectl patch networkpolicy allow-ingress-to-web -n lab26 --type='json' \
  -p='[{"op": "remove", "path": "/spec/ingress/0/from/0/namespaceSelector"}]'

echo "=== Introduciendo Escenario 4: Pod sin etiquetas correctas ==="
kubectl label pod -l app=web-app -n lab26 tier- --overwrite
kubectl label pod $(kubectl get pods -n lab26 -l app=web-app -o jsonpath='{.items[0].metadata.name}') \
  -n lab26 app=web-broken --overwrite

echo "=== Todos los fallos introducidos. Comienza el diagnóstico. ==="
EOF

chmod +x ~/ckad-labs/lab06/break-connectivity.sh
bash ~/ckad-labs/lab06/break-connectivity.sh
```

2. Verifica que la conectividad está rota:

```bash
# Verificar que el Service no tiene Endpoints
kubectl get endpoints web-app-svc -n lab26

# Intentar acceder desde un Pod de prueba
kubectl run test-conn --image=busybox:1.36.1 --rm -it --restart=Never \
  -n lab26 -- wget -qO- --timeout=5 http://web-app-svc.lab26.svc.cluster.local
```

**Salida esperada:**

```
NAME          ENDPOINTS   AGE
web-app-svc   <none>      5m
```

```
wget: download timed out
pod "test-conn" deleted
pod lab26/test-conn terminated (Error)
```

**Verificación:** El Service muestra `<none>` en Endpoints y la conexión desde el Pod de prueba falla con timeout.

---

### Paso 2: Diagnóstico del Escenario 1 — Service sin Endpoints

**Objetivo:** Identificar por qué el Service `web-app-svc` no tiene Endpoints activos y corregir el selector.

**Instrucciones:**

1. Examina el Service actual y sus selectores:

```bash
# Ver detalles del Service
kubectl describe service web-app-svc -n lab26
```

2. Observa el campo `Selector` en la salida:

**Salida esperada (fragmento):**
```
Name:              web-app-svc
Namespace:         lab26
Selector:          app=web-application,tier=frontend
Type:              ClusterIP
IP:                10.96.xxx.xxx
Port:              <unset>  80/TCP
TargetPort:        80/TCP
Endpoints:         <none>
```

3. Compara con las etiquetas reales de los Pods:

```bash
# Ver las etiquetas de todos los Pods en lab26
kubectl get pods -n lab26 --show-labels
```

**Salida esperada:**
```
NAME                       READY   STATUS    LABELS
web-app-6d4f8b7c9d-abc12  1/1     Running   app=web-broken,pod-template-hash=6d4f8b7c9d
web-app-6d4f8b7c9d-def34  1/1     Running   app=web-app,pod-template-hash=6d4f8b7c9d
```

4. Identifica el problema: el selector del Service usa `app=web-application` pero los Pods tienen `app=web-app` (o `app=web-broken`). Corrige el selector:

```bash
# Corregir el selector del Service
kubectl patch service web-app-svc -n lab26 --type='json' \
  -p='[{"op": "replace", "path": "/spec/selector/app", "value": "web-app"}]'
```

5. Verifica que ahora hay al menos un Endpoint (el Pod que aún tiene `app=web-app`):

```bash
kubectl get endpoints web-app-svc -n lab26
```

**Salida esperada:**
```
NAME          ENDPOINTS        AGE
web-app-svc   10.244.0.16:80   6m
```

**Verificación:** El Service ahora muestra al menos una IP en Endpoints. Solo un Pod aparece porque el otro tiene la etiqueta incorrecta (Escenario 4).

---

### Paso 3: Diagnóstico del Escenario 4 — Pod con Etiquetas Incorrectas

**Objetivo:** Identificar el Pod que quedó excluido del Service por tener etiquetas incorrectas y restaurar sus labels.

**Instrucciones:**

1. Lista los Pods con sus etiquetas para identificar la discrepancia:

```bash
kubectl get pods -n lab26 --show-labels
```

2. Identifica el Pod con `app=web-broken` que no coincide con el selector `app=web-app`:

```bash
# Ver qué Pods coinciden con el selector del Service
kubectl get pods -n lab26 -l app=web-app,tier=frontend
```

**Salida esperada:**
```
No resources found in lab26 namespace.
```

3. Nota que incluso el Pod con `app=web-app` no tiene la etiqueta `tier=frontend` (fue removida en el script de fallos). Restaura las etiquetas correctas en ambos Pods:

```bash
# Obtener nombres de los Pods
PODS=$(kubectl get pods -n lab26 -l pod-template-hash -o jsonpath='{.items[*].metadata.name}')

# Restaurar etiquetas en todos los Pods del Deployment
for pod in $PODS; do
  kubectl label pod $pod -n lab26 app=web-app tier=frontend --overwrite
  echo "Etiquetas restauradas en: $pod"
done
```

4. Verifica que el Service ahora tiene ambos Endpoints:

```bash
kubectl get endpoints web-app-svc -n lab26
```

**Salida esperada:**
```
NAME          ENDPOINTS                      AGE
web-app-svc   10.244.0.15:80,10.244.0.16:80  8m
```

5. Prueba la conectividad al Service:

```bash
kubectl run test-svc --image=busybox:1.36.1 --rm -it --restart=Never \
  -n lab26 -- wget -qO- --timeout=5 http://web-app-svc
```

**Salida esperada:**
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

**Verificación:** El Service muestra dos Endpoints y la conexión desde un Pod en el mismo namespace es exitosa. Los Escenarios 1 y 4 están resueltos.

---

### Paso 4: Diagnóstico del Escenario 2 — Ingress Mal Configurado

**Objetivo:** Identificar y corregir la configuración incorrecta del Ingress que impide el enrutamiento de tráfico externo.

**Instrucciones:**

1. Examina el Ingress actual:

```bash
kubectl describe ingress web-app-ingress -n lab26
```

**Salida esperada (fragmento):**
```
Name:             web-app-ingress
Namespace:        lab26
Rules:
  Host            Path  Backends
  ----            ----  --------
  web-app.local
                  /   web-app-service:80 (<error: endpoints "web-app-service" not found>)
Annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /
```

2. Identifica los dos problemas:
   - El backend apunta a `web-app-service` (incorrecto) en vez de `web-app-svc`
   - El `pathType` es `Exact` (solo coincide con `/` exacto, no con subrutas)

3. Verifica los eventos del Ingress:

```bash
kubectl get events -n lab26 --field-selector involvedObject.name=web-app-ingress
```

4. Revisa los logs del Ingress Controller para confirmar el error:

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx \
  --tail=20 | grep -i "error\|web-app"
```

5. Corrige el Ingress con los valores correctos:

```bash
# Corregir backend service name y pathType
kubectl patch ingress web-app-ingress -n lab26 --type='json' -p='[
  {"op": "replace", "path": "/spec/rules/0/http/paths/0/backend/service/name", "value": "web-app-svc"},
  {"op": "replace", "path": "/spec/rules/0/http/paths/0/pathType", "value": "Prefix"}
]'
```

6. Verifica la corrección:

```bash
kubectl describe ingress web-app-ingress -n lab26
```

**Salida esperada (fragmento):**
```
Rules:
  Host            Path  Backends
  ----            ----  --------
  web-app.local
                  /   web-app-svc:80 (10.244.0.15:80,10.244.0.16:80)
```

7. Prueba el acceso a través del Ingress:

```bash
# Obtener IP de minikube
MINIKUBE_IP=$(minikube ip)

# Probar con curl usando el header Host
curl -s --resolve web-app.local:80:${MINIKUBE_IP} http://web-app.local/ | head -5
```

**Salida esperada:**
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

> **Nota:** Si la respuesta es un error 503 o timeout, el problema puede estar relacionado con la NetworkPolicy (Escenario 3). Continúa al siguiente paso.

**Verificación:** El Ingress muestra los Endpoints correctos en su descripción y el backend service name es `web-app-svc` con `pathType: Prefix`.

---

### Paso 5: Diagnóstico del Escenario 3 — NetworkPolicy Demasiado Restrictiva

**Objetivo:** Identificar que la NetworkPolicy bloquea el tráfico legítimo del Ingress Controller y corregirla para permitir el acceso.

**Instrucciones:**

1. Examina la NetworkPolicy actual:

```bash
kubectl describe networkpolicy allow-ingress-to-web -n lab26
```

**Salida esperada (fragmento):**
```
Name:         allow-ingress-to-web
Namespace:    lab26
Spec:
  PodSelector:     app=web-app
  Allowing ingress traffic:
    To Port: 80/TCP
    From:
      PodSelector: (empty)
    ---
    To Port: 80/TCP
    From: <none>
  Policy Types: Ingress
```

2. Analiza el problema: la NetworkPolicy permite tráfico desde Pods dentro del namespace `lab26` (PodSelector vacío = todos los Pods del namespace), pero **no permite tráfico desde el namespace `ingress-nginx`** donde reside el Ingress Controller. El `namespaceSelector` fue eliminado.

3. Verifica que el Ingress Controller está en un namespace diferente:

```bash
kubectl get pods -n ingress-nginx -o wide
```

4. Prueba que el tráfico desde el Ingress Controller está bloqueado:

```bash
# Obtener el nombre del Pod del Ingress Controller
IC_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx \
  -o jsonpath='{.items[0].metadata.name}')

# Obtener IP de un Pod web-app
WEB_POD_IP=$(kubectl get pods -n lab26 -l app=web-app \
  -o jsonpath='{.items[0].status.podIP}')

# Intentar conectar desde el Ingress Controller al Pod
kubectl exec -n ingress-nginx $IC_POD -- curl -s --max-time 3 http://${WEB_POD_IP}:80
```

**Salida esperada:**
```
curl: (28) Connection timed out after 3001 milliseconds
command terminated with exit code 28
```

5. Corrige la NetworkPolicy para permitir tráfico desde el namespace del Ingress Controller:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/networkpolicy-fix.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-web
  namespace: lab26
spec:
  podSelector:
    matchLabels:
      app: web-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 80
EOF

kubectl apply -f ~/ckad-labs/lab06/networkpolicy-fix.yaml
```

6. Verifica que la NetworkPolicy ahora incluye el namespaceSelector:

```bash
kubectl describe networkpolicy allow-ingress-to-web -n lab26
```

**Salida esperada (fragmento):**
```
Spec:
  PodSelector:     app=web-app
  Allowing ingress traffic:
    To Port: 80/TCP
    From:
      NamespaceSelector: kubernetes.io/metadata.name=ingress-nginx
    ---
    To Port: 80/TCP
    From:
      PodSelector: (empty)
  Policy Types: Ingress
```

7. Prueba nuevamente la conectividad desde el Ingress Controller:

```bash
kubectl exec -n ingress-nginx $IC_POD -- curl -s --max-time 5 http://${WEB_POD_IP}:80 | head -3
```

**Salida esperada:**
```html
<!DOCTYPE html>
<html>
<head>
```

**Verificación:** El Ingress Controller puede alcanzar los Pods de la aplicación. La NetworkPolicy permite tráfico desde `ingress-nginx` y desde Pods dentro de `lab26`.

---

### Paso 6: Validación End-to-End Completa

**Objetivo:** Confirmar que todos los escenarios están resueltos y la conectividad funciona en todas las capas.

**Instrucciones:**

1. Verificación de la capa Service:

```bash
echo "=== Verificación 1: Service Endpoints ==="
kubectl get endpoints web-app-svc -n lab26

echo ""
echo "=== Verificación 2: Conectividad Pod-a-Service ==="
kubectl run final-test --image=busybox:1.36.1 --rm -it --restart=Never \
  -n lab26 -- wget -qO- --timeout=5 http://web-app-svc 2>&1 | head -5
```

2. Verificación de la capa Ingress:

```bash
echo "=== Verificación 3: Ingress Backend ==="
kubectl get ingress web-app-ingress -n lab26

echo ""
echo "=== Verificación 4: Acceso vía Ingress ==="
MINIKUBE_IP=$(minikube ip)
curl -s --resolve web-app.local:80:${MINIKUBE_IP} http://web-app.local/ | head -5
```

3. Verificación de DNS interno:

```bash
echo "=== Verificación 5: Resolución DNS ==="
kubectl run dns-test --image=busybox:1.36.1 --rm -it --restart=Never \
  -n lab26 -- nslookup web-app-svc.lab26.svc.cluster.local
```

4. Verificación de la NetworkPolicy:

```bash
echo "=== Verificación 6: Tráfico desde Ingress Controller ==="
IC_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx \
  -o jsonpath='{.items[0].metadata.name}')
WEB_POD_IP=$(kubectl get pods -n lab26 -l app=web-app \
  -o jsonpath='{.items[0].status.podIP}')
kubectl exec -n ingress-nginx $IC_POD -- curl -s --max-time 5 http://${WEB_POD_IP}:80 | head -3
```

**Salida esperada consolidada:**

```
=== Verificación 1: Service Endpoints ===
NAME          ENDPOINTS                      AGE
web-app-svc   10.244.0.15:80,10.244.0.16:80  15m

=== Verificación 2: Conectividad Pod-a-Service ===
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>

=== Verificación 3: Ingress Backend ===
NAME              CLASS   HOSTS           ADDRESS        PORTS   AGE
web-app-ingress   nginx   web-app.local   192.168.49.2   80      15m

=== Verificación 4: Acceso vía Ingress ===
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>

=== Verificación 5: Resolución DNS ===
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      web-app-svc.lab26.svc.cluster.local
Address 1: 10.96.xxx.xxx web-app-svc.lab26.svc.cluster.local

=== Verificación 6: Tráfico desde Ingress Controller ===
<!DOCTYPE html>
<html>
<head>
```

**Verificación:** Las seis pruebas deben completarse exitosamente sin errores de timeout ni respuestas vacías.

---

## Validación y Testing

Ejecuta el siguiente script de validación integral para confirmar que todos los escenarios están resueltos:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/validate-lab28.sh
#!/bin/bash
PASS=0
FAIL=0

echo "╔══════════════════════════════════════════════════╗"
echo "║  Validación Lab 28 - Troubleshooting Conectividad ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Test 1: Service tiene 2 Endpoints
EP_COUNT=$(kubectl get endpoints web-app-svc -n lab26 -o jsonpath='{.subsets[0].addresses}' | grep -o "ip" | wc -l)
if [ "$EP_COUNT" -ge 2 ]; then
  echo "✅ TEST 1 PASS: Service web-app-svc tiene $EP_COUNT endpoints"
  ((PASS++))
else
  echo "❌ TEST 1 FAIL: Service web-app-svc tiene $EP_COUNT endpoints (esperado: 2)"
  ((FAIL++))
fi

# Test 2: Service selector correcto
SVC_SELECTOR=$(kubectl get svc web-app-svc -n lab26 -o jsonpath='{.spec.selector.app}')
if [ "$SVC_SELECTOR" = "web-app" ]; then
  echo "✅ TEST 2 PASS: Service selector app=$SVC_SELECTOR"
  ((PASS++))
else
  echo "❌ TEST 2 FAIL: Service selector app=$SVC_SELECTOR (esperado: web-app)"
  ((FAIL++))
fi

# Test 3: Ingress backend correcto
ING_BACKEND=$(kubectl get ingress web-app-ingress -n lab26 -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}')
if [ "$ING_BACKEND" = "web-app-svc" ]; then
  echo "✅ TEST 3 PASS: Ingress backend = $ING_BACKEND"
  ((PASS++))
else
  echo "❌ TEST 3 FAIL: Ingress backend = $ING_BACKEND (esperado: web-app-svc)"
  ((FAIL++))
fi

# Test 4: Ingress pathType correcto
PATH_TYPE=$(kubectl get ingress web-app-ingress -n lab26 -o jsonpath='{.spec.rules[0].http.paths[0].pathType}')
if [ "$PATH_TYPE" = "Prefix" ]; then
  echo "✅ TEST 4 PASS: Ingress pathType = $PATH_TYPE"
  ((PASS++))
else
  echo "❌ TEST 4 FAIL: Ingress pathType = $PATH_TYPE (esperado: Prefix)"
  ((FAIL++))
fi

# Test 5: NetworkPolicy permite ingress-nginx
NP_NS=$(kubectl get networkpolicy allow-ingress-to-web -n lab26 -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector.matchLabels}')
if echo "$NP_NS" | grep -q "ingress-nginx"; then
  echo "✅ TEST 5 PASS: NetworkPolicy permite tráfico desde ingress-nginx"
  ((PASS++))
else
  echo "❌ TEST 5 FAIL: NetworkPolicy no permite tráfico desde ingress-nginx"
  ((FAIL++))
fi

# Test 6: Pods tienen etiquetas correctas
LABELED_PODS=$(kubectl get pods -n lab26 -l app=web-app,tier=frontend --no-headers | wc -l)
if [ "$LABELED_PODS" -ge 2 ]; then
  echo "✅ TEST 6 PASS: $LABELED_PODS Pods con etiquetas correctas"
  ((PASS++))
else
  echo "❌ TEST 6 FAIL: $LABELED_PODS Pods con etiquetas correctas (esperado: 2)"
  ((FAIL++))
fi

# Test 7: Conectividad Pod-a-Service funcional
CONN_TEST=$(kubectl run val-test --image=busybox:1.36.1 --rm -it --restart=Never \
  -n lab26 -- wget -qO- --timeout=5 http://web-app-svc 2>&1)
if echo "$CONN_TEST" | grep -q "nginx"; then
  echo "✅ TEST 7 PASS: Conectividad Pod-a-Service funcional"
  ((PASS++))
else
  echo "❌ TEST 7 FAIL: Conectividad Pod-a-Service fallida"
  ((FAIL++))
fi

echo ""
echo "════════════════════════════════════"
echo "  Resultados: $PASS/7 PASS, $FAIL/7 FAIL"
echo "════════════════════════════════════"

if [ $FAIL -eq 0 ]; then
  echo "🎉 ¡Todos los escenarios resueltos correctamente!"
else
  echo "⚠️  Revisa los tests fallidos y corrige los problemas."
fi
EOF

chmod +x ~/ckad-labs/lab06/validate-lab28.sh
bash ~/ckad-labs/lab06/validate-lab28.sh
```

**Resultado esperado:**
```
╔══════════════════════════════════════════════════╗
║  Validación Lab 28 - Troubleshooting Conectividad ║
╚══════════════════════════════════════════════════╝

✅ TEST 1 PASS: Service web-app-svc tiene 2 endpoints
✅ TEST 2 PASS: Service selector app=web-app
✅ TEST 3 PASS: Ingress backend = web-app-svc
✅ TEST 4 PASS: Ingress pathType = Prefix
✅ TEST 5 PASS: NetworkPolicy permite tráfico desde ingress-nginx
✅ TEST 6 PASS: 2 Pods con etiquetas correctas
✅ TEST 7 PASS: Conectividad Pod-a-Service funcional

════════════════════════════════════
  Resultados: 7/7 PASS, 0/7 FAIL
════════════════════════════════════
🎉 ¡Todos los escenarios resueltos correctamente!
```

---

## Troubleshooting

### Problema 1: Los Pods se recrean con etiquetas originales del Deployment

**Síntomas:** Después de corregir las etiquetas de los Pods manualmente, los Endpoints aparecen brevemente pero luego vuelven a desaparecer. Al ejecutar `kubectl get pods -n lab26 --show-labels`, se observan Pods nuevos con etiquetas diferentes.

**Causa:** El Deployment controller detecta que los Pods existentes ya no coinciden con su `spec.selector.matchLabels` (porque cambiaste `app=web-app` a `app=web-broken`). Esto hace que el Deployment cree nuevos Pods para mantener el `replicas` deseado. Los Pods "huérfanos" (con `app=web-broken`) siguen corriendo pero no pertenecen al Deployment.

**Solución:**

```bash
# Eliminar Pods huérfanos que no pertenecen al Deployment
kubectl delete pod -n lab26 -l app=web-broken

# Verificar que el Deployment recreó Pods con etiquetas correctas
kubectl get pods -n lab26 --show-labels

# Si los Pods del Deployment no tienen tier=frontend, verificar el template
kubectl get deployment web-app -n lab26 -o jsonpath='{.spec.template.metadata.labels}'
```

Si el template del Deployment tiene las etiquetas correctas, los nuevos Pods las heredarán automáticamente. Solo necesitas corregir las etiquetas en Pods que fueron modificados manualmente y que aún existen.

---

### Problema 2: El curl al Ingress devuelve "connection refused" o "no route to host"

**Síntomas:** Al ejecutar `curl --resolve web-app.local:80:$(minikube ip) http://web-app.local/`, la respuesta es `Connection refused` en lugar del HTML de nginx o un error 503.

**Causa:** El Ingress Controller de minikube no está corriendo o el addon `ingress` no está habilitado. Esto puede ocurrir si minikube fue reiniciado sin re-habilitar los addons, o si el Pod del Ingress Controller está en estado `CrashLoopBackOff`.

**Solución:**

```bash
# Verificar estado del addon ingress
minikube addons list | grep ingress

# Si no está habilitado, activarlo
minikube addons enable ingress

# Verificar que el Pod del Ingress Controller está Running
kubectl get pods -n ingress-nginx

# Si está en CrashLoopBackOff, revisar logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=30

# Esperar a que esté Ready
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Reintentar la prueba
curl -s --resolve web-app.local:80:$(minikube ip) http://web-app.local/ | head -3
```

---

## Limpieza

El entorno de lab26 debe permanecer funcional ya que sirve como base para los labs 29 y 30 del módulo 7. Solo elimina los artefactos temporales del troubleshooting:

```bash
# Eliminar scripts de diagnóstico (opcional, conservar para referencia)
# rm ~/ckad-labs/lab06/break-connectivity.sh

# Verificar estado final limpio
echo "=== Estado final del namespace lab26 ==="
kubectl get all -n lab26
echo ""
kubectl get ingress -n lab26
echo ""
kubectl get networkpolicy -n lab26
```

Si necesitas reiniciar completamente el entorno:

```bash
# SOLO si algo salió irrecuperablemente mal
kubectl delete namespace lab26
kubectl apply -f ~/ckad-labs/lab06/lab26-base.yaml
kubectl wait --for=condition=Ready pod -l app=web-app -n lab26 --timeout=60s
```

---

## Resumen

### Conceptos Clave Aplicados

| Escenario | Herramienta de Diagnóstico | Causa Raíz | Corrección |
|-----------|---------------------------|------------|------------|
| Service sin Endpoints | `kubectl get endpoints`, `kubectl describe svc` | Selector `app=web-application` no coincide con Pods | Corregir selector a `app=web-app` |
| Pod excluido del Service | `kubectl get pods --show-labels` | Etiquetas `app` y `tier` modificadas/eliminadas | Restaurar `app=web-app` y `tier=frontend` |
| Ingress mal configurado | `kubectl describe ingress`, logs del controller | Backend name erróneo + pathType `Exact` | Corregir a `web-app-svc` + `Prefix` |
| NetworkPolicy restrictiva | `kubectl describe netpol`, `kubectl exec` desde IC | Falta `namespaceSelector` para ingress-nginx | Agregar regla con namespaceSelector |

### Metodología de Diagnóstico

La secuencia recomendada para troubleshooting de conectividad en Kubernetes es:

1. **DNS** — ¿El nombre del servicio resuelve? (`nslookup` desde un Pod)
2. **Service** — ¿Existe? ¿Tiene Endpoints? (`kubectl get endpoints`)
3. **Selector ↔ Labels** — ¿Los selectores del Service coinciden con las etiquetas de los Pods?
4. **Ingress** — ¿El backend apunta al Service correcto? ¿El pathType es adecuado?
5. **NetworkPolicy** — ¿Hay políticas que bloquean el tráfico legítimo?
6. **Pod** — ¿El contenedor está escuchando en el puerto esperado? (`kubectl exec -- curl localhost:PORT`)

### Recursos Adicionales

- [Documentación oficial: Debugging Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
- [Documentación oficial: Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Documentación oficial: Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [DNS para Services y Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
