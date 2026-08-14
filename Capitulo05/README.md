# Implementación de probes

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 40 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar |
| **Namespace** | `lab-probes` |
| **Directorio de trabajo** | `~/ckad-labs/lab05/` |

## Descripción General

En este laboratorio implementarás los tres tipos de probes de Kubernetes (Liveness, Readiness y Startup) sobre un Deployment basado en nginx con un endpoint de salud personalizado. Observarás cómo Kubernetes utiliza estas probes para decidir cuándo reiniciar un contenedor degradado, cuándo remover un Pod de los endpoints de un Service y cómo proteger aplicaciones con arranque lento. Simularás fallos modificando la respuesta del endpoint de salud y verificarás el comportamiento del clúster mediante eventos, endpoints y contadores de reinicio.

## Objetivos de Aprendizaje

- [ ] Implementar Liveness Probe con `httpGet`, `exec` y `tcpSocket` para detectar y reiniciar contenedores en estado degradado
- [ ] Configurar Readiness Probe para controlar cuándo un Pod recibe tráfico desde un Service, observando la remoción y re-adición de endpoints
- [ ] Agregar Startup Probe con `failureThreshold` alto para proteger aplicaciones con tiempo de arranque variable
- [ ] Ajustar los parámetros `initialDelaySeconds`, `periodSeconds`, `failureThreshold` y `successThreshold` para escenarios realistas
- [ ] Observar el comportamiento de reinicio y exclusión de endpoints usando `kubectl describe`, `kubectl get events` y `kubectl get endpoints`

## Prerrequisitos

### Conocimiento requerido

| Tema | Nivel |
|------|-------|
| Ciclo de vida de Pods (fases, condiciones, estados de contenedor) | Intermedio |
| Kubernetes Services y distribución de tráfico mediante endpoints | Básico |
| Comandos `kubectl describe pod` y `kubectl get events` | Básico |
| Edición de manifiestos YAML de Kubernetes | Básico |

### Acceso requerido

- Clúster minikube 1.33.1 activo y accesible con `kubectl` 1.30.2
- Permisos para crear namespaces, Deployments, Services, ConfigMaps y Pods
- Conectividad a internet para descargar imágenes de contenedor

## Entorno del Laboratorio

### Software utilizado

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| minikube | 1.33.1 | Clúster local de Kubernetes |
| kubectl | 1.30.2 | CLI de administración del clúster |
| nginx | 1.27.0 | Imagen base para Deployment con probes httpGet/tcpSocket |
| busybox | 1.36.1 | Imagen para demostrar probes de tipo exec |

### Preparación del entorno

```bash
# Verificar que minikube está activo
minikube status

# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab05
cd ~/ckad-labs/lab05

# Crear el namespace dedicado para este laboratorio
kubectl create namespace lab-probes

# Establecer el namespace como default en el contexto actual
kubectl config set-context --current --namespace=lab-probes

# Verificar el namespace activo
kubectl config view --minify | grep namespace
```

**Salida esperada:**

```
    namespace: lab-probes
```

## Paso a Paso

### Paso 1: Desplegar aplicación sin probes y observar comportamiento por defecto

**Objetivo:** Demostrar que sin probes configuradas, Kubernetes marca el Pod como Ready inmediatamente después de que el contenedor arranca, sin verificar si la aplicación realmente puede servir tráfico.

**Instrucciones:**

1. Crear el ConfigMap que servirá como endpoint de salud personalizado para nginx:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/healthz-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-healthz
  namespace: lab-probes
data:
  healthz.conf: |
    server {
      listen 8080;
      location /healthz {
        return 200 'OK\n';
        add_header Content-Type text/plain;
      }
      location / {
        return 200 'App Running\n';
        add_header Content-Type text/plain;
      }
    }
EOF
kubectl apply -f ~/ckad-labs/lab05/healthz-configmap.yaml
```

2. Crear un Deployment sin probes:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/deploy-no-probes.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-no-probes
  namespace: lab-probes
  labels:
    app: webapp-no-probes
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp-no-probes
  template:
    metadata:
      labels:
        app: webapp-no-probes
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: healthz-config
          mountPath: /etc/nginx/conf.d/healthz.conf
          subPath: healthz.conf
      volumes:
      - name: healthz-config
        configMap:
          name: nginx-healthz
EOF
kubectl apply -f ~/ckad-labs/lab05/deploy-no-probes.yaml
```

3. Observar cómo el Pod se marca como Ready de inmediato:

```bash
kubectl get pods -w
```

Presionar `Ctrl+C` después de ver el estado `1/1 Running`.

4. Crear un Service para este Deployment:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/svc-no-probes.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-no-probes-svc
  namespace: lab-probes
spec:
  selector:
    app: webapp-no-probes
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
EOF
kubectl apply -f ~/ckad-labs/lab05/svc-no-probes.yaml
```

5. Verificar que el endpoint se registra inmediatamente:

```bash
kubectl get endpoints webapp-no-probes-svc
```

**Salida esperada:**

```
NAME                   ENDPOINTS          AGE
webapp-no-probes-svc   172.17.x.x:8080    5s
```

**Verificación:**

```bash
# El Pod debe mostrar READY 1/1 y condición Ready=True
kubectl get pod -l app=webapp-no-probes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}'
```

Resultado esperado: `True`

> **Observación clave:** El Pod se marcó como Ready sin que Kubernetes verificara si la aplicación responde correctamente. En producción, esto puede causar que un Service envíe tráfico a instancias que aún no están listas.

---

### Paso 2: Implementar Liveness Probe con httpGet

**Objetivo:** Configurar una Liveness Probe que verifica periódicamente el endpoint `/healthz` y reinicia el contenedor si la aplicación deja de responder correctamente.

**Instrucciones:**

1. Crear un nuevo Deployment con Liveness Probe:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/deploy-liveness.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-liveness
  namespace: lab-probes
  labels:
    app: webapp-liveness
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp-liveness
  template:
    metadata:
      labels:
        app: webapp-liveness
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: healthz-config
          mountPath: /etc/nginx/conf.d/healthz.conf
          subPath: healthz.conf
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 3
          successThreshold: 1
      volumes:
      - name: healthz-config
        configMap:
          name: nginx-healthz
EOF
kubectl apply -f ~/ckad-labs/lab05/deploy-liveness.yaml
```

2. Esperar a que el Pod esté Running y verificar la configuración de la probe:

```bash
kubectl get pods -l app=webapp-liveness
kubectl describe pod -l app=webapp-liveness | grep -A 10 "Liveness:"
```

**Salida esperada:**

```
    Liveness:       http-get http://:8080/healthz delay=5s timeout=2s period=5s #success=1 #failure=3
```

3. Verificar que la Liveness Probe pasa correctamente (sin reinicios):

```bash
kubectl get pods -l app=webapp-liveness
```

**Salida esperada:**

```
NAME                               READY   STATUS    RESTARTS   AGE
webapp-liveness-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

**Verificación:**

```bash
# Confirmar 0 reinicios después de al menos 20 segundos
sleep 20
kubectl get pod -l app=webapp-liveness -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}'
```

Resultado esperado: `0`

---

### Paso 3: Simular fallo de Liveness Probe y observar reinicio

**Objetivo:** Provocar que la Liveness Probe falle modificando el endpoint `/healthz` para que devuelva HTTP 500, y observar cómo Kubernetes reinicia el contenedor automáticamente.

**Instrucciones:**

1. Actualizar el ConfigMap para que `/healthz` devuelva un código 500:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/healthz-configmap-fail.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-healthz-fail
  namespace: lab-probes
data:
  healthz.conf: |
    server {
      listen 8080;
      location /healthz {
        return 500 'UNHEALTHY\n';
        add_header Content-Type text/plain;
      }
      location / {
        return 200 'App Running\n';
        add_header Content-Type text/plain;
      }
    }
EOF
kubectl apply -f ~/ckad-labs/lab05/healthz-configmap-fail.yaml
```

2. Crear un Deployment que use el ConfigMap con fallo:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/deploy-liveness-fail.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-liveness-fail
  namespace: lab-probes
  labels:
    app: webapp-liveness-fail
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp-liveness-fail
  template:
    metadata:
      labels:
        app: webapp-liveness-fail
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: healthz-config
          mountPath: /etc/nginx/conf.d/healthz.conf
          subPath: healthz.conf
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 3
          successThreshold: 1
      volumes:
      - name: healthz-config
        configMap:
          name: nginx-healthz-fail
EOF
kubectl apply -f ~/ckad-labs/lab05/deploy-liveness-fail.yaml
```

3. Observar los eventos en tiempo real (esperar ~20 segundos para ver el ciclo de reinicio):

```bash
kubectl get events --field-selector involvedObject.kind=Pod --watch
```

Presionar `Ctrl+C` después de observar eventos `Unhealthy` y `Killing`.

4. Verificar que el contador de reinicios aumenta:

```bash
kubectl get pods -l app=webapp-liveness-fail
```

**Salida esperada (después de ~30 segundos):**

```
NAME                                    READY   STATUS    RESTARTS      AGE
webapp-liveness-fail-xxxxxxxxxx-xxxxx   1/1     Running   2 (5s ago)   45s
```

5. Examinar los eventos detallados del Pod:

```bash
kubectl describe pod -l app=webapp-liveness-fail | grep -A 20 "Events:"
```

**Salida esperada (fragmento):**

```
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  60s                default-scheduler  Successfully assigned...
  Normal   Pulled     15s (x3 over 55s)  kubelet            Container image "nginx:1.27.0" already present
  Warning  Unhealthy  10s (x9 over 50s)  kubelet            Liveness probe failed: HTTP probe failed with statuscode: 500
  Normal   Killing    10s (x3 over 40s)  kubelet            Container nginx failed liveness probe, will be restarted
```

**Verificación:**

```bash
# Confirmar que RESTARTS > 0
RESTARTS=$(kubectl get pod -l app=webapp-liveness-fail -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')
echo "Reinicios: $RESTARTS"
[ "$RESTARTS" -gt 0 ] && echo "✓ Liveness Probe provocó reinicio correctamente"
```

---

### Paso 4: Implementar Readiness Probe y observar endpoints

**Objetivo:** Configurar una Readiness Probe que controla si el Pod recibe tráfico desde un Service, y observar cómo los endpoints se actualizan dinámicamente según el estado de la probe.

**Instrucciones:**

1. Crear un Deployment con Readiness Probe:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/deploy-readiness.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-readiness
  namespace: lab-probes
  labels:
    app: webapp-readiness
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp-readiness
  template:
    metadata:
      labels:
        app: webapp-readiness
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: healthz-config
          mountPath: /etc/nginx/conf.d/healthz.conf
          subPath: healthz.conf
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 3
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 2
          successThreshold: 1
      volumes:
      - name: healthz-config
        configMap:
          name: nginx-healthz
EOF
kubectl apply -f ~/ckad-labs/lab05/deploy-readiness.yaml
```

2. Crear un Service asociado:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/svc-readiness.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-readiness-svc
  namespace: lab-probes
spec:
  selector:
    app: webapp-readiness
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
EOF
kubectl apply -f ~/ckad-labs/lab05/svc-readiness.yaml
```

3. Esperar a que ambos Pods estén Ready y verificar los endpoints:

```bash
kubectl wait --for=condition=Ready pod -l app=webapp-readiness --timeout=30s
kubectl get endpoints webapp-readiness-svc
```

**Salida esperada:**

```
NAME                   ENDPOINTS                           AGE
webapp-readiness-svc   172.17.x.x:8080,172.17.x.y:8080   10s
```

4. Simular fallo de Readiness ejecutando un comando dentro de uno de los Pods para eliminar la configuración de nginx:

```bash
# Obtener el nombre del primer Pod
POD_NAME=$(kubectl get pods -l app=webapp-readiness -o jsonpath='{.items[0].metadata.name}')
echo "Pod seleccionado: $POD_NAME"

# Eliminar el archivo de configuración del endpoint de salud
kubectl exec $POD_NAME -- rm /etc/nginx/conf.d/healthz.conf
kubectl exec $POD_NAME -- nginx -s reload
```

5. Esperar ~15 segundos y observar que el Pod pierde la condición Ready:

```bash
sleep 15
kubectl get pods -l app=webapp-readiness
```

**Salida esperada:**

```
NAME                                READY   STATUS    RESTARTS   AGE
webapp-readiness-xxxxxxxxxx-aaaaa   0/1     Running   0          60s
webapp-readiness-xxxxxxxxxx-bbbbb   1/1     Running   0          60s
```

6. Verificar que el endpoint fue removido del Service:

```bash
kubectl get endpoints webapp-readiness-svc
```

**Salida esperada (solo un endpoint):**

```
NAME                   ENDPOINTS          AGE
webapp-readiness-svc   172.17.x.y:8080    30s
```

**Verificación:**

```bash
# Confirmar que el Pod no-ready tiene condición Ready=False
kubectl get pod $POD_NAME -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

Resultado esperado: `False`

> **Observación clave:** A diferencia de la Liveness Probe, la Readiness Probe NO reinicia el contenedor. Solo lo remueve de los endpoints del Service hasta que vuelva a pasar la verificación.

---

### Paso 5: Implementar Startup Probe para arranque lento

**Objetivo:** Configurar una Startup Probe que protege aplicaciones con tiempo de arranque variable, evitando que la Liveness Probe las mate prematuramente durante el inicio.

**Instrucciones:**

1. Crear un Deployment que combina las tres probes:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/deploy-all-probes.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-all-probes
  namespace: lab-probes
  labels:
    app: webapp-all-probes
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp-all-probes
  template:
    metadata:
      labels:
        app: webapp-all-probes
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: healthz-config
          mountPath: /etc/nginx/conf.d/healthz.conf
          subPath: healthz.conf
        startupProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 2
          timeoutSeconds: 2
          failureThreshold: 15
          successThreshold: 1
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 10
          timeoutSeconds: 2
          failureThreshold: 3
          successThreshold: 1
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 2
          successThreshold: 1
      volumes:
      - name: healthz-config
        configMap:
          name: nginx-healthz
EOF
kubectl apply -f ~/ckad-labs/lab05/deploy-all-probes.yaml
```

2. Verificar la configuración de las tres probes:

```bash
kubectl describe pod -l app=webapp-all-probes | grep -E "(Liveness|Readiness|Startup):"
```

**Salida esperada:**

```
    Liveness:       http-get http://:8080/healthz delay=0s timeout=2s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8080/healthz delay=0s timeout=2s period=5s #success=1 #failure=2
    Startup:        http-get http://:8080/healthz delay=0s timeout=2s period=2s #success=1 #failure=15
```

3. Explicar la lógica de la configuración:

```bash
echo "=== Análisis de la Startup Probe ==="
echo "Tiempo máximo de arranque permitido: failureThreshold(15) × periodSeconds(2) = 30 segundos"
echo "La Liveness Probe NO se ejecuta hasta que la Startup Probe pase al menos una vez."
echo "La Readiness Probe NO se ejecuta hasta que la Startup Probe pase al menos una vez."
echo ""
echo "=== Después del arranque exitoso ==="
echo "Liveness: verifica cada 10s, reinicia tras 3 fallos consecutivos (30s de tolerancia)"
echo "Readiness: verifica cada 5s, remueve de endpoints tras 2 fallos (10s de tolerancia)"
```

**Verificación:**

```bash
# Esperar a que el Pod esté completamente listo
kubectl wait --for=condition=Ready pod -l app=webapp-all-probes --timeout=60s

# Verificar que no hay reinicios (la Startup Probe protegió el arranque)
kubectl get pods -l app=webapp-all-probes
```

Resultado esperado: `RESTARTS: 0`

---

### Paso 6: Implementar Liveness Probe con exec (busybox)

**Objetivo:** Demostrar el uso de probes de tipo `exec` que ejecutan un comando dentro del contenedor y evalúan el código de salida (0 = éxito, ≠ 0 = fallo).

**Instrucciones:**

1. Crear un Pod con probe de tipo exec:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/pod-exec-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: exec-probe-demo
  namespace: lab-probes
  labels:
    app: exec-probe-demo
spec:
  containers:
  - name: app
    image: busybox:1.36.1
    command:
    - /bin/sh
    - -c
    - |
      # Crear archivo de salud al iniciar
      touch /tmp/healthy
      echo "App started, health file created"
      # Después de 30 segundos, eliminar el archivo para simular fallo
      sleep 30
      rm -f /tmp/healthy
      echo "Health file removed - simulating failure"
      # Mantener el contenedor vivo
      sleep 3600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
      successThreshold: 1
EOF
kubectl apply -f ~/ckad-labs/lab05/pod-exec-probe.yaml
```

2. Observar que inicialmente el Pod está sano:

```bash
sleep 10
kubectl get pod exec-probe-demo
```

**Salida esperada:**

```
NAME              READY   STATUS    RESTARTS   AGE
exec-probe-demo   1/1     Running   0          15s
```

3. Esperar a que el archivo sea eliminado (~30s desde la creación) y observar el reinicio:

```bash
echo "Esperando 35 segundos para que se elimine /tmp/healthy..."
sleep 35

# Observar los eventos
kubectl get events --field-selector involvedObject.name=exec-probe-demo --sort-by='.lastTimestamp'
```

4. Verificar que el Pod fue reiniciado:

```bash
kubectl get pod exec-probe-demo
```

**Salida esperada (después de ~50 segundos desde la creación):**

```
NAME              READY   STATUS    RESTARTS      AGE
exec-probe-demo   1/1     Running   1 (10s ago)   55s
```

**Verificación:**

```bash
RESTARTS=$(kubectl get pod exec-probe-demo -o jsonpath='{.status.containerStatuses[0].restartCount}')
echo "Reinicios por exec probe: $RESTARTS"
[ "$RESTARTS" -ge 1 ] && echo "✓ Exec Liveness Probe funcionó correctamente"
```

---

### Paso 7: Implementar probe con tcpSocket

**Objetivo:** Demostrar el uso de probes de tipo `tcpSocket` que verifican si un puerto TCP está aceptando conexiones.

**Instrucciones:**

1. Crear un Pod con Liveness Probe de tipo tcpSocket:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/pod-tcp-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tcp-probe-demo
  namespace: lab-probes
  labels:
    app: tcp-probe-demo
spec:
  containers:
  - name: nginx
    image: nginx:1.27.0
    ports:
    - containerPort: 80
    livenessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
      failureThreshold: 3
    readinessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 2
      periodSeconds: 5
      failureThreshold: 2
EOF
kubectl apply -f ~/ckad-labs/lab05/pod-tcp-probe.yaml
```

2. Verificar que las probes tcpSocket están configuradas:

```bash
kubectl describe pod tcp-probe-demo | grep -A 5 -E "(Liveness|Readiness):"
```

**Salida esperada:**

```
    Liveness:       tcp-socket :80 delay=5s timeout=1s period=10s #success=1 #failure=3
    Readiness:      tcp-socket :80 delay=2s timeout=1s period=5s #success=1 #failure=2
```

3. Confirmar que el Pod está sano (nginx escucha en puerto 80):

```bash
kubectl wait --for=condition=Ready pod/tcp-probe-demo --timeout=30s
kubectl get pod tcp-probe-demo
```

**Salida esperada:**

```
NAME             READY   STATUS    RESTARTS   AGE
tcp-probe-demo   1/1     Running   0          20s
```

**Verificación:**

```bash
# Verificar que el Pod mantiene 0 reinicios (el puerto 80 está activo)
sleep 15
kubectl get pod tcp-probe-demo -o jsonpath='{.status.containerStatuses[0].restartCount}'
```

Resultado esperado: `0`

> **Nota:** `tcpSocket` es ideal para servicios que no exponen endpoints HTTP de salud (bases de datos, brokers de mensajería, servicios gRPC).

---

### Paso 8: Observar interacción completa entre Service y Readiness Probe

**Objetivo:** Crear un escenario completo donde se observa cómo los endpoints de un Service se actualizan dinámicamente basándose en el estado de la Readiness Probe de múltiples réplicas.

**Instrucciones:**

1. Escalar el Deployment con todas las probes a 3 réplicas:

```bash
kubectl scale deployment webapp-all-probes --replicas=3
kubectl wait --for=condition=Ready pod -l app=webapp-all-probes --timeout=60s
```

2. Crear un Service para este Deployment:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/svc-all-probes.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-all-probes-svc
  namespace: lab-probes
spec:
  selector:
    app: webapp-all-probes
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
EOF
kubectl apply -f ~/ckad-labs/lab05/svc-all-probes.yaml
```

3. Verificar que los 3 endpoints están registrados:

```bash
kubectl get endpoints webapp-all-probes-svc
```

**Salida esperada:**

```
NAME                    ENDPOINTS                                             AGE
webapp-all-probes-svc   172.17.x.a:8080,172.17.x.b:8080,172.17.x.c:8080     5s
```

4. Simular fallo de Readiness en uno de los Pods:

```bash
# Seleccionar el primer Pod
FAIL_POD=$(kubectl get pods -l app=webapp-all-probes -o jsonpath='{.items[0].metadata.name}')
echo "Simulando fallo en: $FAIL_POD"

# Eliminar la configuración de salud
kubectl exec $FAIL_POD -- rm /etc/nginx/conf.d/healthz.conf
kubectl exec $FAIL_POD -- nginx -s reload
```

5. Esperar y observar la reducción de endpoints:

```bash
sleep 15
echo "=== Estado de los Pods ==="
kubectl get pods -l app=webapp-all-probes

echo ""
echo "=== Endpoints del Service ==="
kubectl get endpoints webapp-all-probes-svc
```

**Salida esperada:**

```
=== Estado de los Pods ===
NAME                                 READY   STATUS    RESTARTS   AGE
webapp-all-probes-xxxxxxxxxx-aaaaa   0/1     Running   0          2m
webapp-all-probes-xxxxxxxxxx-bbbbb   1/1     Running   0          2m
webapp-all-probes-xxxxxxxxxx-ccccc   1/1     Running   0          2m

=== Endpoints del Service ===
NAME                    ENDPOINTS                          AGE
webapp-all-probes-svc   172.17.x.b:8080,172.17.x.c:8080   60s
```

**Verificación:**

```bash
# Contar endpoints activos (debe ser 2, no 3)
ENDPOINT_COUNT=$(kubectl get endpoints webapp-all-probes-svc -o jsonpath='{.subsets[0].addresses}' | jq '. | length')
echo "Endpoints activos: $ENDPOINT_COUNT"
[ "$ENDPOINT_COUNT" -eq 2 ] && echo "✓ Readiness Probe removió correctamente el Pod del Service"
```

---

## Validación y Testing

Ejecutar la siguiente secuencia de verificaciones para confirmar que todos los objetivos del laboratorio se cumplieron:

```bash
echo "============================================"
echo "  VALIDACIÓN FINAL DEL LABORATORIO"
echo "============================================"
echo ""

# Test 1: Verificar que el namespace existe
echo "1. Namespace lab-probes:"
kubectl get namespace lab-probes > /dev/null 2>&1 && echo "   ✓ Existe" || echo "   ✗ No encontrado"

# Test 2: Deployment con Liveness Probe (httpGet)
echo "2. Liveness Probe httpGet:"
LIVENESS=$(kubectl get pod -l app=webapp-liveness -o jsonpath='{.items[0].spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null)
[ "$LIVENESS" = "/healthz" ] && echo "   ✓ Configurada en /healthz" || echo "   ✗ No configurada"

# Test 3: Deployment con fallo de Liveness (reinicios > 0)
echo "3. Liveness Probe provocó reinicios:"
FAIL_RESTARTS=$(kubectl get pod -l app=webapp-liveness-fail -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
[ "${FAIL_RESTARTS:-0}" -gt 0 ] && echo "   ✓ Reinicios: $FAIL_RESTARTS" || echo "   ✗ Sin reinicios detectados"

# Test 4: Readiness Probe configurada
echo "4. Readiness Probe configurada:"
READINESS=$(kubectl get pod -l app=webapp-readiness -o jsonpath='{.items[0].spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
[ "$READINESS" = "/healthz" ] && echo "   ✓ Configurada en /healthz" || echo "   ✗ No configurada"

# Test 5: Startup Probe configurada
echo "5. Startup Probe configurada:"
STARTUP=$(kubectl get pod -l app=webapp-all-probes -o jsonpath='{.items[0].spec.containers[0].startupProbe.httpGet.path}' 2>/dev/null)
[ "$STARTUP" = "/healthz" ] && echo "   ✓ Configurada en /healthz" || echo "   ✗ No configurada"

# Test 6: Exec probe demo
echo "6. Exec Probe (busybox):"
EXEC_RESTARTS=$(kubectl get pod exec-probe-demo -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
[ "${EXEC_RESTARTS:-0}" -ge 1 ] && echo "   ✓ Reinicio por exec probe: $EXEC_RESTARTS" || echo "   ✗ Sin reinicios"

# Test 7: TCP Socket probe
echo "7. TCP Socket Probe:"
TCP_PROBE=$(kubectl get pod tcp-probe-demo -o jsonpath='{.spec.containers[0].livenessProbe.tcpSocket.port}' 2>/dev/null)
[ "$TCP_PROBE" = "80" ] && echo "   ✓ Configurada en puerto 80" || echo "   ✗ No configurada"

# Test 8: Tres probes en un solo contenedor
echo "8. Tres probes simultáneas (all-probes):"
HAS_ALL=$(kubectl get pod -l app=webapp-all-probes -o jsonpath='{.items[0].spec.containers[0].startupProbe.httpGet.path},{.items[0].spec.containers[0].livenessProbe.httpGet.path},{.items[0].spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
[ "$HAS_ALL" = "/healthz,/healthz,/healthz" ] && echo "   ✓ Startup + Liveness + Readiness configuradas" || echo "   ✗ Configuración incompleta"

echo ""
echo "============================================"
echo "  VALIDACIÓN COMPLETADA"
echo "============================================"
```

---

## Troubleshooting

### Problema 1: Pod en CrashLoopBackOff con mensaje "nginx: [emerg] open() failed"

**Síntomas:**

```
NAME                               READY   STATUS             RESTARTS   AGE
webapp-liveness-xxxxxxxxxx-xxxxx   0/1     CrashLoopBackOff   3          2m
```

Al ejecutar `kubectl logs`:
```
nginx: [emerg] open() "/etc/nginx/conf.d/healthz.conf" failed (2: No such file or directory)
```

**Causa:** El ConfigMap `nginx-healthz` no fue creado antes del Deployment, o el nombre del ConfigMap en el volumen no coincide con el nombre del ConfigMap creado. El `subPath` en el volumeMount requiere que el archivo exista exactamente con ese nombre en el ConfigMap.

**Solución:**

```bash
# Verificar que el ConfigMap existe
kubectl get configmap nginx-healthz -n lab-probes

# Si no existe, crearlo
kubectl apply -f ~/ckad-labs/lab05/healthz-configmap.yaml

# Verificar que la clave en el ConfigMap coincide con el subPath
kubectl get configmap nginx-healthz -o jsonpath='{.data}' | jq 'keys'
# Debe mostrar: ["healthz.conf"]

# Reiniciar el Deployment para que monte el volumen correctamente
kubectl rollout restart deployment webapp-liveness -n lab-probes
```

---

### Problema 2: Readiness Probe falla pero los endpoints no se actualizan

**Síntomas:**

El Pod muestra `READY 0/1` pero `kubectl get endpoints` sigue mostrando la IP del Pod en la lista de endpoints.

```
NAME                                READY   STATUS    RESTARTS   AGE
webapp-readiness-xxxxxxxxxx-aaaaa   0/1     Running   0          2m

# Pero endpoints aún muestra la IP
NAME                   ENDPOINTS                           AGE
webapp-readiness-svc   172.17.0.5:8080,172.17.0.6:8080    3m
```

**Causa:** El selector del Service no coincide exactamente con los labels del Pod. Kubernetes usa coincidencia exacta de labels para asociar Pods con Services. Si hay un typo en el label (por ejemplo, `app: webapp-readines` vs `app: webapp-readiness`), el Service no controla ese Pod y los endpoints que muestra pertenecen a otros Pods que sí coinciden.

**Solución:**

```bash
# Verificar los labels del Pod
kubectl get pod -l app=webapp-readiness --show-labels

# Verificar el selector del Service
kubectl get svc webapp-readiness-svc -o jsonpath='{.spec.selector}'

# Comparar que coincidan exactamente
# Si no coinciden, editar el Service o el Deployment:
kubectl edit svc webapp-readiness-svc
# Asegurar que spec.selector.app = "webapp-readiness"

# Forzar actualización de endpoints
kubectl get endpoints webapp-readiness-svc -o yaml
```

---

## Limpieza

```bash
# Eliminar todos los recursos del namespace
kubectl delete namespace lab-probes

# Restaurar el namespace por defecto del contexto
kubectl config set-context --current --namespace=ckad-dev

# Verificar
kubectl config view --minify | grep namespace

# Opcional: eliminar archivos de manifiestos
# rm -rf ~/ckad-labs/lab05/
```

**Salida esperada:**

```
namespace "lab-probes" deleted
Context "minikube" modified.
    namespace: ckad-dev
```

---

## Resumen

En este laboratorio aplicaste los tres tipos de probes de Kubernetes en escenarios progresivos:

| Probe | Tipo demostrado | Comportamiento ante fallo |
|-------|----------------|--------------------------|
| **Liveness** | `httpGet`, `exec`, `tcpSocket` | Reinicia el contenedor |
| **Readiness** | `httpGet`, `tcpSocket` | Remueve el Pod de los endpoints del Service |
| **Startup** | `httpGet` | Protege el arranque; si falla, mata el contenedor |

**Parámetros clave configurados:**

| Parámetro | Propósito | Valor típico |
|-----------|-----------|--------------|
| `initialDelaySeconds` | Tiempo de espera antes de la primera verificación | 0-10s |
| `periodSeconds` | Intervalo entre verificaciones | 5-10s |
| `timeoutSeconds` | Tiempo máximo de espera por respuesta | 1-3s |
| `failureThreshold` | Fallos consecutivos antes de actuar | 2-5 |
| `successThreshold` | Éxitos consecutivos para marcar como sano | 1 (Liveness/Startup siempre 1) |

**Fórmula de tiempo máximo de arranque con Startup Probe:**
```
Tiempo máximo = failureThreshold × periodSeconds
Ejemplo: 15 × 2s = 30 segundos
```

### Recursos adicionales

- [Configurar Liveness, Readiness y Startup Probes — Documentación oficial](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Pod Lifecycle — Kubernetes API Reference](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#container-probes)
- [Probe v1 core — Kubernetes API](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#Probe)

---

# Análisis de logs y eventos

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 40 minutos |
| **Complejidad** | Fácil |
| **Nivel Bloom** | Aplicar |
| **Namespace** | `ckad-debug` |
| **Directorio de trabajo** | `~/ckad-labs/lab05/` |

---

## Visión General

En este laboratorio desplegarás tres escenarios de fallos controlados en Kubernetes para practicar el flujo de diagnóstico basado en estados de Pod, logs de contenedores y eventos del clúster. Trabajarás con un Pod en `CrashLoopBackOff` por error de configuración, un Pod multi-contenedor con sidecar de logging compartiendo un volumen `emptyDir`, y un Deployment cuyo Pod es terminado por `OOMKilled` debido a límites de memoria insuficientes. Al finalizar, dominarás las herramientas fundamentales de observabilidad nativa de Kubernetes.

---

## Objetivos de Aprendizaje

- [ ] Interpretar los estados `CrashLoopBackOff`, `OOMKilled` y `Completed` usando `kubectl get` y `kubectl describe`
- [ ] Extraer y filtrar logs con `kubectl logs` usando los flags `--container`, `--previous`, `--tail` y `--since`
- [ ] Analizar eventos de Kubernetes a nivel de namespace y recurso específico para identificar causas raíz
- [ ] Correlacionar logs de múltiples contenedores en un Pod sidecar para reconstruir el flujo de actividad

---

## Prerrequisitos

### Conocimientos

| Requisito | Descripción |
|-----------|-------------|
| kubectl básico | Familiaridad con `kubectl get`, `describe`, `apply` y `delete` |
| Ciclo de vida de contenedores | Comprensión de cómo un contenedor arranca, ejecuta y termina |
| YAML de Kubernetes | Capacidad de leer y crear manifiestos de Pods y Deployments |

### Acceso y entorno

| Requisito | Verificación |
|-----------|-------------|
| Clúster Kubernetes activo | `kubectl cluster-info` retorna URL del control plane |
| kubectl configurado | `kubectl version --client` muestra v1.30.x |
| Namespace `ckad-debug` NO existe | `kubectl get ns ckad-debug` retorna `NotFound` |

---

## Entorno del Laboratorio

### Software requerido

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| kubectl | 1.30.2 | Interacción con el clúster |
| kind / minikube | 0.23.0 / 1.33.1 | Clúster local |
| bash | 5.x | Shell de trabajo |

### Imágenes de contenedor

| Imagen | Uso en este lab |
|--------|-----------------|
| `nginx:1.27.0` | Contenedor principal en Pod multi-contenedor |
| `busybox:1.36.1` | Sidecar de logging y Pod con CrashLoopBackOff |

### Preparación inicial

```bash
# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab05
cd ~/ckad-labs/lab05

# Verificar que el clúster está operativo
kubectl cluster-info

# Verificar que el namespace no existe previamente
kubectl get ns ckad-debug 2>&1 | grep -q "NotFound" && echo "OK: namespace no existe" || echo "ADVERTENCIA: namespace ya existe"
```

---

## Paso a Paso

### Paso 1: Crear el namespace de trabajo

**Objetivo:** Establecer el namespace `ckad-debug` que será utilizado en este laboratorio y en la Práctica 22.

**Instrucciones:**

1. Crea el namespace:

```bash
kubectl create namespace ckad-debug
```

2. Configura el contexto actual para usar este namespace por defecto:

```bash
kubectl config set-context --current --namespace=ckad-debug
```

3. Verifica la configuración:

```bash
kubectl config view --minify | grep namespace
```

**Salida esperada:**

```
namespace: ckad-debug
```

**Verificación:**

```bash
kubectl get ns ckad-debug -o jsonpath='{.status.phase}'
```

Debe retornar: `Active`

---

### Paso 2: Escenario 1 — Pod en CrashLoopBackOff

**Objetivo:** Desplegar un Pod que falla por una variable de entorno mal configurada, diagnosticar la causa usando `kubectl describe` y `kubectl logs --previous`.

**Instrucciones:**

1. Crea el manifiesto del Pod con error de configuración:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/crashloop-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: crashloop-pod
  namespace: ckad-debug
  labels:
    scenario: crashloop
spec:
  restartPolicy: Always
  containers:
  - name: app
    image: busybox:1.36.1
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "Iniciando aplicación..."
      if [ -z "$APP_CONFIG_PATH" ]; then
        echo "ERROR: APP_CONFIG_PATH no está definida. Abortando." >&2
        exit 1
      fi
      if [ ! -f "$APP_CONFIG_PATH" ]; then
        echo "ERROR: Archivo de configuración no encontrado en $APP_CONFIG_PATH" >&2
        exit 1
      fi
      echo "Configuración cargada desde $APP_CONFIG_PATH"
      sleep 3600
    env:
    - name: APP_CONFIG_PATH
      value: "/etc/app/config.yaml"
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab05/crashloop-pod.yaml
```

3. Espera 30 segundos para que el Pod entre en `CrashLoopBackOff`:

```bash
sleep 30
```

4. Observa el estado del Pod:

```bash
kubectl get pod crashloop-pod -o wide
```

**Salida esperada:**

```
NAME            READY   STATUS             RESTARTS      AGE   IP           NODE       ...
crashloop-pod   0/1     CrashLoopBackOff   2 (12s ago)   30s   10.244.x.x  kind-...   ...
```

5. Inspecciona el estado detallado del contenedor:

```bash
kubectl describe pod crashloop-pod
```

6. Localiza la sección `State` y `Last State` en la salida. Observa los campos:

```bash
# Extraer el reason del estado actual
kubectl get pod crashloop-pod -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}'
```

**Salida esperada:**

```
CrashLoopBackOff
```

7. Consulta el número de reinicios:

```bash
kubectl get pod crashloop-pod -o jsonpath='{.status.containerStatuses[0].restartCount}'
```

8. Revisa los logs del intento anterior (el contenedor ya terminó):

```bash
kubectl logs crashloop-pod --previous
```

**Salida esperada:**

```
Iniciando aplicación...
ERROR: Archivo de configuración no encontrado en /etc/app/config.yaml
```

9. Revisa los logs del intento actual (puede estar disponible brevemente):

```bash
kubectl logs crashloop-pod --tail=5
```

10. Examina los eventos asociados al Pod:

```bash
kubectl describe pod crashloop-pod | grep -A 20 "^Events:"
```

**Salida esperada (similar a):**

```
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  45s                default-scheduler  Successfully assigned ckad-debug/crashloop-pod to ...
  Normal   Pulled     15s (x3 over 44s)  kubelet            Container image "busybox:1.36.1" already present on machine
  Normal   Created    15s (x3 over 44s)  kubelet            Created container app
  Normal   Started    15s (x3 over 44s)  kubelet            Started container app
  Warning  BackOff    3s (x2 over 28s)   kubelet            Back-off restarting failed container app in pod crashloop-pod_ckad-debug(...)
```

**Verificación:**

```bash
# Confirmar que el Pod tiene restartCount > 0 y estado CrashLoopBackOff
RESTARTS=$(kubectl get pod crashloop-pod -o jsonpath='{.status.containerStatuses[0].restartCount}')
STATE=$(kubectl get pod crashloop-pod -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}')
echo "Reinicios: $RESTARTS | Estado: $STATE"
[ "$RESTARTS" -ge 2 ] && [ "$STATE" = "CrashLoopBackOff" ] && echo "✓ Escenario 1 verificado correctamente"
```

---

### Paso 3: Escenario 2 — Pod multi-contenedor con sidecar de logging

**Objetivo:** Desplegar un Pod con un contenedor principal nginx y un sidecar busybox que lee los logs de acceso desde un volumen compartido `emptyDir`. Practicar `kubectl logs --container` para acceder a logs de contenedores específicos.

**Instrucciones:**

1. Crea el manifiesto del Pod multi-contenedor:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/sidecar-logging-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-logging-pod
  namespace: ckad-debug
  labels:
    scenario: sidecar-logging
spec:
  restartPolicy: Always
  volumes:
  - name: shared-logs
    emptyDir: {}
  containers:
  - name: webapp
    image: nginx:1.27.0
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  - name: log-reader
    image: busybox:1.36.1
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "[log-reader] Iniciando sidecar de logging..."
      echo "[log-reader] Monitoreando /var/log/nginx/access.log"
      # Esperar a que nginx cree el archivo de log
      while [ ! -f /var/log/nginx/access.log ]; do
        sleep 1
      done
      echo "[log-reader] Archivo de log detectado. Iniciando tail..."
      tail -f /var/log/nginx/access.log
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
      readOnly: true
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab05/sidecar-logging-pod.yaml
```

3. Espera a que ambos contenedores estén listos:

```bash
kubectl wait --for=condition=Ready pod/sidecar-logging-pod --timeout=60s
```

**Salida esperada:**

```
pod/sidecar-logging-pod condition met
```

4. Verifica que ambos contenedores están Running:

```bash
kubectl get pod sidecar-logging-pod
```

**Salida esperada:**

```
NAME                  READY   STATUS    RESTARTS   AGE
sidecar-logging-pod   2/2     Running   0          15s
```

5. Genera tráfico HTTP hacia el contenedor nginx para producir logs:

```bash
# Ejecutar un Pod temporal para generar solicitudes HTTP
kubectl run curl-client --image=busybox:1.36.1 --rm -it --restart=Never -- /bin/sh -c \
  'for i in 1 2 3 4 5; do wget -q -O /dev/null http://sidecar-logging-pod:80/; echo "Request $i sent"; sleep 1; done'
```

**Salida esperada:**

```
Request 1 sent
Request 2 sent
Request 3 sent
Request 4 sent
Request 5 sent
pod "curl-client" deleted
```

6. Consulta los logs del contenedor principal (webapp/nginx):

```bash
kubectl logs sidecar-logging-pod --container=webapp --tail=10
```

> **Nota:** Los logs de stdout de nginx muestran errores; los logs de acceso van al archivo en el volumen compartido.

7. Consulta los logs del sidecar (log-reader):

```bash
kubectl logs sidecar-logging-pod --container=log-reader --tail=10
```

**Salida esperada (similar a):**

```
[log-reader] Iniciando sidecar de logging...
[log-reader] Monitoreando /var/log/nginx/access.log
[log-reader] Archivo de log detectado. Iniciando tail...
10.244.x.x - - [DD/Mon/YYYY:HH:MM:SS +0000] "GET / HTTP/1.1" 200 615 "-" "Wget"
10.244.x.x - - [DD/Mon/YYYY:HH:MM:SS +0000] "GET / HTTP/1.1" 200 615 "-" "Wget"
...
```

8. Filtra logs del sidecar por tiempo (últimos 2 minutos):

```bash
kubectl logs sidecar-logging-pod --container=log-reader --since=2m
```

9. Verifica los estados de ambos contenedores con jsonpath:

```bash
kubectl get pod sidecar-logging-pod -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state.running.startedAt}{"\n"}{end}'
```

**Salida esperada:**

```
webapp: 2024-xx-xxTxx:xx:xxZ
log-reader: 2024-xx-xxTxx:xx:xxZ
```

10. Examina la sección Events del Pod:

```bash
kubectl describe pod sidecar-logging-pod | grep -A 15 "^Events:"
```

**Verificación:**

```bash
# Confirmar que ambos contenedores están running y hay logs del sidecar
READY=$(kubectl get pod sidecar-logging-pod -o jsonpath='{.status.containerStatuses[?(@.name=="log-reader")].ready}')
LOGS=$(kubectl logs sidecar-logging-pod --container=log-reader --tail=1 2>/dev/null)
echo "log-reader ready: $READY"
echo "Última línea de log: $LOGS"
[ "$READY" = "true" ] && echo "✓ Escenario 2 verificado correctamente"
```

---

### Paso 4: Escenario 3 — Pod OOMKilled por límite de memoria insuficiente

**Objetivo:** Desplegar un Deployment cuyo Pod consume más memoria que su límite, provocando un estado `OOMKilled`. Diagnosticar usando `kubectl describe` y eventos.

**Instrucciones:**

1. Crea el manifiesto del Deployment con límite de memoria restrictivo:

```bash
cat <<'EOF' > ~/ckad-labs/lab05/oomkilled-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oomkilled-deploy
  namespace: ckad-debug
  labels:
    scenario: oomkilled
spec:
  replicas: 1
  selector:
    matchLabels:
      app: memory-hog
  template:
    metadata:
      labels:
        app: memory-hog
    spec:
      containers:
      - name: memory-hog
        image: busybox:1.36.1
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "Iniciando proceso con consumo de memoria..."
          echo "Límite configurado: 32Mi"
          # Intentar asignar ~64MB de memoria (supera el límite de 32Mi)
          dd if=/dev/zero bs=1M count=64 | cat > /dev/null &
          # Alternativa que consume heap
          head -c 67108864 /dev/urandom > /tmp/bigfile
          echo "Archivo creado, manteniendo en memoria..."
          cat /tmp/bigfile > /dev/null
          sleep 3600
        resources:
          requests:
            memory: "16Mi"
            cpu: "50m"
          limits:
            memory: "32Mi"
            cpu: "100m"
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab05/oomkilled-deploy.yaml
```

3. Espera 20 segundos para que el Pod sea terminado por OOM:

```bash
sleep 20
```

4. Observa el estado del Pod del Deployment:

```bash
kubectl get pods -l app=memory-hog
```

**Salida esperada (similar a):**

```
NAME                                READY   STATUS      RESTARTS      AGE
oomkilled-deploy-xxxxxxxxx-xxxxx   0/1     OOMKilled   1 (5s ago)    20s
```

> **Nota:** El estado puede alternar entre `OOMKilled` y `CrashLoopBackOff` dependiendo del momento en que se consulte.

5. Obtén el nombre exacto del Pod:

```bash
OOM_POD=$(kubectl get pods -l app=memory-hog -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $OOM_POD"
```

6. Inspecciona el estado detallado del contenedor:

```bash
kubectl describe pod $OOM_POD
```

7. Extrae el reason del último estado terminado:

```bash
kubectl get pod $OOM_POD -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
```

**Salida esperada:**

```
OOMKilled
```

8. Verifica el exit code (137 = SIGKILL por OOM):

```bash
kubectl get pod $OOM_POD -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
```

**Salida esperada:**

```
137
```

9. Revisa los logs del intento anterior:

```bash
kubectl logs $OOM_POD --previous --tail=5
```

**Salida esperada (similar a):**

```
Iniciando proceso con consumo de memoria...
Límite configurado: 32Mi
```

10. Consulta los eventos del Deployment y del Pod:

```bash
kubectl get events --sort-by='.lastTimestamp' --field-selector involvedObject.name=$OOM_POD
```

**Verificación:**

```bash
# Confirmar OOMKilled
REASON=$(kubectl get pod $OOM_POD -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)
EXIT_CODE=$(kubectl get pod $OOM_POD -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}' 2>/dev/null)
echo "Reason: $REASON | Exit Code: $EXIT_CODE"
[ "$REASON" = "OOMKilled" ] && [ "$EXIT_CODE" = "137" ] && echo "✓ Escenario 3 verificado correctamente"
```

---

### Paso 5: Análisis consolidado de eventos del namespace

**Objetivo:** Practicar la consulta de eventos a nivel de namespace completo, filtrar por tipo Warning y correlacionar con los escenarios desplegados.

**Instrucciones:**

1. Lista todos los eventos del namespace ordenados cronológicamente:

```bash
kubectl get events -n ckad-debug --sort-by='.lastTimestamp'
```

2. Filtra solo eventos de tipo Warning:

```bash
kubectl get events -n ckad-debug --field-selector type=Warning
```

**Salida esperada (similar a):**

```
LAST SEEN   TYPE      REASON    OBJECT                              MESSAGE
2m          Warning   BackOff   pod/crashloop-pod                   Back-off restarting failed container...
30s         Warning   BackOff   pod/oomkilled-deploy-xxxxx-xxxxx    Back-off restarting failed container...
```

3. Obtén eventos en formato detallado con campos adicionales:

```bash
kubectl get events -n ckad-debug --sort-by='.lastTimestamp' -o custom-columns=\
TIEMPO:.lastTimestamp,\
TIPO:.type,\
RAZON:.reason,\
OBJETO:.involvedObject.name,\
MENSAJE:.message
```

4. Filtra eventos específicos del Pod crashloop:

```bash
kubectl get events -n ckad-debug --field-selector involvedObject.name=crashloop-pod
```

5. Compara el conteo de eventos entre los tres escenarios:

```bash
echo "=== Eventos por Pod ==="
echo "crashloop-pod:"
kubectl get events -n ckad-debug --field-selector involvedObject.name=crashloop-pod --no-headers | wc -l

echo "sidecar-logging-pod:"
kubectl get events -n ckad-debug --field-selector involvedObject.name=sidecar-logging-pod --no-headers | wc -l

echo "oomkilled-deploy Pod:"
kubectl get events -n ckad-debug --field-selector involvedObject.name=$OOM_POD --no-headers | wc -l
```

**Verificación:**

```bash
# El Pod con más eventos Warning debe ser crashloop-pod o el OOMKilled
WARNING_COUNT=$(kubectl get events -n ckad-debug --field-selector type=Warning --no-headers | wc -l)
echo "Total eventos Warning en ckad-debug: $WARNING_COUNT"
[ "$WARNING_COUNT" -ge 2 ] && echo "✓ Eventos Warning detectados correctamente"
```

---

### Paso 6: Uso avanzado de kubectl logs con flags combinados

**Objetivo:** Dominar las opciones de filtrado de `kubectl logs` para escenarios de producción.

**Instrucciones:**

1. Obtén las últimas 3 líneas de log del sidecar:

```bash
kubectl logs sidecar-logging-pod --container=log-reader --tail=3
```

2. Obtén logs del sidecar de los últimos 60 segundos:

```bash
kubectl logs sidecar-logging-pod --container=log-reader --since=60s
```

3. Obtén logs del contenedor anterior del Pod crashloop (última ejecución fallida):

```bash
kubectl logs crashloop-pod --previous
```

4. Combina `--previous` con `--tail` para obtener solo las últimas 2 líneas del intento fallido:

```bash
kubectl logs crashloop-pod --previous --tail=2
```

**Salida esperada:**

```
ERROR: Archivo de configuración no encontrado en /etc/app/config.yaml
```

5. Obtén logs con timestamps:

```bash
kubectl logs sidecar-logging-pod --container=log-reader --tail=5 --timestamps=true
```

**Salida esperada (similar a):**

```
2024-xx-xxTxx:xx:xx.xxxxxxxxxZ [log-reader] Archivo de log detectado. Iniciando tail...
2024-xx-xxTxx:xx:xx.xxxxxxxxxZ 10.244.x.x - - [DD/Mon/YYYY:HH:MM:SS +0000] "GET / HTTP/1.1" 200 615 "-" "Wget"
...
```

6. Intenta obtener logs de todos los contenedores del Pod multi-contenedor simultáneamente:

```bash
kubectl logs sidecar-logging-pod --all-containers=true --tail=3
```

**Verificación:**

```bash
# Verificar que --previous funciona con crashloop-pod
PREV_LOG=$(kubectl logs crashloop-pod --previous --tail=1 2>/dev/null)
echo "Último log del intento anterior: $PREV_LOG"
echo "$PREV_LOG" | grep -q "ERROR" && echo "✓ Flags de kubectl logs verificados correctamente"
```

---

## Validación y Testing

Ejecuta el siguiente script de validación integral para confirmar que los tres escenarios están correctamente desplegados y diagnosticados:

```bash
#!/bin/bash
echo "=========================================="
echo "  VALIDACIÓN INTEGRAL - Lab 05-00-02"
echo "=========================================="

PASS=0
FAIL=0

# Test 1: Namespace existe
echo -n "[Test 1] Namespace ckad-debug existe: "
if kubectl get ns ckad-debug &>/dev/null; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 2: crashloop-pod está en CrashLoopBackOff
echo -n "[Test 2] crashloop-pod en CrashLoopBackOff: "
STATE=$(kubectl get pod crashloop-pod -n ckad-debug -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
if [ "$STATE" = "CrashLoopBackOff" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (estado actual: $STATE)"; ((FAIL++))
fi

# Test 3: crashloop-pod tiene restartCount >= 2
echo -n "[Test 3] crashloop-pod restartCount >= 2: "
RESTARTS=$(kubectl get pod crashloop-pod -n ckad-debug -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
if [ "$RESTARTS" -ge 2 ] 2>/dev/null; then
  echo "PASS (reinicios: $RESTARTS)"; ((PASS++))
else
  echo "FAIL (reinicios: $RESTARTS)"; ((FAIL++))
fi

# Test 4: sidecar-logging-pod tiene 2 contenedores Ready
echo -n "[Test 4] sidecar-logging-pod 2/2 Ready: "
READY=$(kubectl get pod sidecar-logging-pod -n ckad-debug -o jsonpath='{.status.containerStatuses[*].ready}' 2>/dev/null)
if [ "$READY" = "true true" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (ready: $READY)"; ((FAIL++))
fi

# Test 5: sidecar-logging-pod tiene volumen emptyDir
echo -n "[Test 5] Volumen emptyDir configurado: "
VOL_TYPE=$(kubectl get pod sidecar-logging-pod -n ckad-debug -o jsonpath='{.spec.volumes[0].emptyDir}' 2>/dev/null)
if [ "$VOL_TYPE" = "{}" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 6: oomkilled-deploy Pod tiene lastState OOMKilled
echo -n "[Test 6] OOMKilled detectado: "
OOM_POD=$(kubectl get pods -n ckad-debug -l app=memory-hog -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
REASON=$(kubectl get pod $OOM_POD -n ckad-debug -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)
if [ "$REASON" = "OOMKilled" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (reason: $REASON)"; ((FAIL++))
fi

# Test 7: Exit code 137 en OOMKilled
echo -n "[Test 7] Exit code 137 (SIGKILL): "
EXIT=$(kubectl get pod $OOM_POD -n ckad-debug -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}' 2>/dev/null)
if [ "$EXIT" = "137" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (exitCode: $EXIT)"; ((FAIL++))
fi

# Test 8: Eventos Warning existen en el namespace
echo -n "[Test 8] Eventos Warning presentes: "
WARNINGS=$(kubectl get events -n ckad-debug --field-selector type=Warning --no-headers 2>/dev/null | wc -l)
if [ "$WARNINGS" -ge 1 ]; then
  echo "PASS (warnings: $WARNINGS)"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

echo "=========================================="
echo "  Resultado: $PASS PASS / $FAIL FAIL"
echo "=========================================="
```

Guarda y ejecuta:

```bash
cat <<'SCRIPT' > ~/ckad-labs/lab05/validate-lab05-02.sh
# (pegar el script anterior aquí)
SCRIPT
chmod +x ~/ckad-labs/lab05/validate-lab05-02.sh
bash ~/ckad-labs/lab05/validate-lab05-02.sh
```

**Resultado esperado:** 8 PASS / 0 FAIL

---

## Troubleshooting

### Problema 1: El Pod crashloop-pod no entra en CrashLoopBackOff

**Síntomas:**
- `kubectl get pod crashloop-pod` muestra estado `Running` en lugar de `CrashLoopBackOff`
- El campo `restartCount` permanece en 0

**Causa:**
El Pod puede tardar algunos segundos en fallar y Kubernetes necesita al menos 2-3 reinicios antes de aplicar el backoff exponencial. Si el Pod se consulta demasiado pronto, puede aparecer momentáneamente como `Running` o `Error`.

**Solución:**

```bash
# Esperar al menos 45 segundos después del apply
sleep 45

# Verificar el estado nuevamente
kubectl get pod crashloop-pod -w

# Si sigue en Running, verificar que el manifiesto tiene el comando correcto
kubectl get pod crashloop-pod -o jsonpath='{.spec.containers[0].args[0]}' | head -5

# Si el manifiesto es correcto pero el Pod no falla, eliminarlo y recrearlo
kubectl delete pod crashloop-pod
kubectl apply -f ~/ckad-labs/lab05/crashloop-pod.yaml
sleep 45
kubectl get pod crashloop-pod
```

---

### Problema 2: kubectl logs --previous retorna "previous terminated container not found"

**Síntomas:**
- Al ejecutar `kubectl logs crashloop-pod --previous` se obtiene el error:
  ```
  Error from server: previous terminated container "app" in pod "crashloop-pod" not found
  ```

**Causa:**
El contenedor aún no ha completado su primer ciclo de fallo-reinicio. El flag `--previous` solo funciona cuando existe al menos un contenedor terminado anterior al actual. Esto ocurre cuando se consulta inmediatamente después del primer arranque.

**Solución:**

```bash
# Verificar que hay al menos 1 reinicio
kubectl get pod crashloop-pod -o jsonpath='{.status.containerStatuses[0].restartCount}'

# Si restartCount es 0, esperar a que el contenedor falle y se reinicie
kubectl wait --for=jsonpath='{.status.containerStatuses[0].restartCount}'=1 pod/crashloop-pod --timeout=60s

# Ahora --previous debería funcionar
kubectl logs crashloop-pod --previous

# Alternativa: usar logs sin --previous para ver el intento actual (si el contenedor está ejecutándose brevemente)
kubectl logs crashloop-pod
```

---

## Limpieza

Para eliminar todos los recursos creados en este laboratorio:

```bash
# Eliminar recursos individuales
kubectl delete pod crashloop-pod -n ckad-debug --grace-period=0 --force 2>/dev/null
kubectl delete pod sidecar-logging-pod -n ckad-debug --grace-period=0 --force 2>/dev/null
kubectl delete deployment oomkilled-deploy -n ckad-debug 2>/dev/null

# Verificar que no quedan recursos
kubectl get all -n ckad-debug
```

> **IMPORTANTE:** NO elimines el namespace `ckad-debug`. Será reutilizado en la Práctica 22 (Lab 05-00-03).

```bash
# Restaurar el namespace por defecto si es necesario
kubectl config set-context --current --namespace=ckad-dev
```

---

## Resumen

### Conceptos clave practicados

| Concepto | Comando/Técnica |
|----------|----------------|
| Estado CrashLoopBackOff | `kubectl get pod` + `kubectl describe pod` → sección State/Last State |
| Logs de intentos anteriores | `kubectl logs <pod> --previous` |
| Pod multi-contenedor | `kubectl logs <pod> --container=<nombre>` |
| Filtrado temporal de logs | `kubectl logs --since=60s --tail=10` |
| Todos los logs simultáneos | `kubectl logs <pod> --all-containers=true` |
| OOMKilled (exit code 137) | `kubectl get pod -o jsonpath` → `.lastState.terminated.reason` |
| Eventos del namespace | `kubectl get events --sort-by=.lastTimestamp` |
| Eventos Warning | `kubectl get events --field-selector type=Warning` |
| Eventos de un recurso | `kubectl get events --field-selector involvedObject.name=<pod>` |

### Flujo de diagnóstico establecido

```
kubectl get pods → identificar STATUS anormal
    ↓
kubectl describe pod <nombre> → leer Conditions + State + Events
    ↓
kubectl logs <pod> [--previous] [--container] → obtener detalle del error
    ↓
kubectl get events --sort-by=.lastTimestamp → contexto temporal completo
```

### Recursos adicionales

- [Pod Lifecycle — Kubernetes Docs](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Debug Running Pods — Kubernetes Docs](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
- [kubectl logs Reference](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/)
- [Container States — API Reference](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#ContainerState)

---

# Depuración de aplicaciones fallidas

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 70 minutos |
| **Complejidad** | Alta |
| **Nivel Bloom** | Aplicar |
| **Namespace** | `ckad-debug` |
| **Directorio de trabajo** | `~/ckad-labs/lab05/` |

---

## Descripción General

Este laboratorio presenta cuatro escenarios progresivos de troubleshooting en Kubernetes que simulan fallos reales en producción. Trabajarás con probes mal configuradas que causan reinicios continuos, Pods que no alcanzan el estado Ready, recursos faltantes (ConfigMaps y PVCs) que impiden el arranque de contenedores, y contenedores distroless que requieren depuración con contenedores efímeros. Al completar todos los escenarios, todos los recursos del namespace `ckad-debug` estarán en estado Running/Ready.

---

## Objetivos de Aprendizaje

- [ ] Diagnosticar y corregir una liveness probe HTTP mal configurada que genera reinicios innecesarios, verificando la estabilización del Deployment
- [ ] Manipular el estado interno de un contenedor mediante `kubectl exec` para satisfacer una readiness probe basada en archivo
- [ ] Resolver fallos de arranque causados por ConfigMaps inexistentes y PersistentVolumeClaims no vinculados
- [ ] Utilizar `kubectl debug` con contenedores efímeros para inspeccionar contenedores distroless en ejecución
- [ ] Aplicar el flujo sistemático de diagnóstico: `kubectl get` → `kubectl describe` → `kubectl logs` → corrección

---

## Prerrequisitos

### Conocimientos Requeridos

| Tema | Nivel |
|------|-------|
| Fases y estados de Pods (Pending, Running, CrashLoopBackOff) | Intermedio |
| Probes HTTP, TCP y exec en Kubernetes | Básico |
| ConfigMaps y montaje de variables de entorno | Básico |
| PersistentVolumeClaims y PersistentVolumes | Básico |
| Comandos kubectl (describe, logs, exec, get) | Intermedio |

### Acceso Requerido

- Clúster Kubernetes funcional (kind o minikube)
- Namespace `ckad-debug` existente (creado en Práctica 21)
- Acceso a internet para descargar imágenes desde Docker Hub
- `kubectl` configurado y operativo

---

## Entorno del Laboratorio

### Software Necesario

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| kubectl | 1.30.2 | Gestión del clúster |
| kind | 0.23.0 | Clúster local |
| Docker Engine | 26.1.4 | Runtime de contenedores |
| bash | 5.x | Shell de trabajo |

### Imágenes de Contenedor

| Imagen | Uso |
|--------|-----|
| `nginx:1.27.0` | Servidor web para escenarios de probes |
| `busybox:1.36.1` | Contenedor efímero de depuración y Pods auxiliares |
| `gcr.io/distroless/static:nonroot` | Contenedor distroless para escenario de debug |

### Preparación Inicial

```bash
# Verificar que el namespace ckad-debug existe
kubectl get namespace ckad-debug

# Si no existe (en caso de no haber completado Práctica 21), crearlo:
kubectl create namespace ckad-debug 2>/dev/null || true

# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab05/debug-apps
cd ~/ckad-labs/lab05/debug-apps

# Verificar alias activos
alias k=kubectl 2>/dev/null || alias k=kubectl
alias kgp='kubectl get pods' 2>/dev/null || alias kgp='kubectl get pods'
alias kd='kubectl describe' 2>/dev/null || alias kd='kubectl describe'
```

---

## Paso a Paso

### Paso 1: Desplegar los recursos con fallos intencionados

**Objetivo:** Crear los cuatro escenarios de troubleshooting en el namespace `ckad-debug` para simular fallos reales.

#### Instrucciones

1. Crear el manifiesto del Deployment con liveness probe incorrecta:

```bash
cat > ~/ckad-labs/lab05/debug-apps/probe-misconfigured.yaml << 'ENDOFFILE'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe-misconfigured
  namespace: ckad-debug
  labels:
    app: probe-misconfigured
spec:
  replicas: 1
  selector:
    matchLabels:
      app: probe-misconfigured
  template:
    metadata:
      labels:
        app: probe-misconfigured
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 3
          periodSeconds: 3
ENDOFFILE
```

2. Crear el manifiesto del Pod con readiness probe basada en archivo:

```bash
cat > ~/ckad-labs/lab05/debug-apps/readiness-demo.yaml << 'ENDOFFILE'
apiVersion: v1
kind: Pod
metadata:
  name: readiness-demo
  namespace: ckad-debug
  labels:
    app: readiness-demo
spec:
  containers:
  - name: app
    image: busybox:1.36.1
    command: ["sh", "-c", "echo 'App running' && sleep 3600"]
    readinessProbe:
      exec:
        command:
        - cat
        - /tmp/ready
      initialDelaySeconds: 5
      periodSeconds: 5
ENDOFFILE
```

3. Crear el manifiesto del Pod con ConfigMap faltante:

```bash
cat > ~/ckad-labs/lab05/debug-apps/broken-config.yaml << 'ENDOFFILE'
apiVersion: v1
kind: Pod
metadata:
  name: broken-config
  namespace: ckad-debug
  labels:
    app: broken-config
spec:
  containers:
  - name: app
    image: nginx:1.27.0
    ports:
    - containerPort: 80
    envFrom:
    - configMapRef:
        name: app-config
ENDOFFILE
```

4. Crear el manifiesto del Pod con PVC inexistente:

```bash
cat > ~/ckad-labs/lab05/debug-apps/broken-volume.yaml << 'ENDOFFILE'
apiVersion: v1
kind: Pod
metadata:
  name: broken-volume
  namespace: ckad-debug
  labels:
    app: broken-volume
spec:
  containers:
  - name: app
    image: nginx:1.27.0
    ports:
    - containerPort: 80
    volumeMounts:
    - name: data-volume
      mountPath: /usr/share/nginx/html
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: app-data-pvc
ENDOFFILE
```

5. Crear un Pod distroless para el escenario de debug:

```bash
cat > ~/ckad-labs/lab05/debug-apps/distroless-app.yaml << 'ENDOFFILE'
apiVersion: v1
kind: Pod
metadata:
  name: distroless-app
  namespace: ckad-debug
  labels:
    app: distroless-app
spec:
  containers:
  - name: app
    image: gcr.io/distroless/static:nonroot
    command: ["/bin/sh", "-c", "sleep 3600"]
ENDOFFILE
```

> **Nota:** El Pod distroless fallará intencionalmente porque la imagen distroless no tiene shell. Lo reemplazaremos con una alternativa funcional en el paso correspondiente.

6. Aplicar todos los manifiestos:

```bash
kubectl apply -f ~/ckad-labs/lab05/debug-apps/probe-misconfigured.yaml
kubectl apply -f ~/ckad-labs/lab05/debug-apps/readiness-demo.yaml
kubectl apply -f ~/ckad-labs/lab05/debug-apps/broken-config.yaml
kubectl apply -f ~/ckad-labs/lab05/debug-apps/broken-volume.yaml
kubectl apply -f ~/ckad-labs/lab05/debug-apps/distroless-app.yaml
```

7. Esperar 30 segundos y verificar el estado general:

```bash
sleep 30
kubectl get pods -n ckad-debug -o wide
```

#### Salida Esperada

```
NAME                                   READY   STATUS             RESTARTS      AGE
broken-config                          0/1     CreateContainerConfigError   0    30s
broken-volume                          0/1     Pending            0             30s
distroless-app                         0/1     CrashLoopBackOff   1             30s
probe-misconfigured-xxxxxxxxx-xxxxx    0/1     Running            1             30s
readiness-demo                         0/1     Running            0             30s
```

#### Verificación

```bash
# Confirmar que hay exactamente 0 Pods en estado Ready (1/1)
READY_COUNT=$(kubectl get pods -n ckad-debug --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c "true" 2>/dev/null || echo "0")
echo "Pods Ready: $READY_COUNT (esperado: 0)"
```

---

### Paso 2: Escenario 1 — Diagnosticar y corregir la liveness probe incorrecta

**Objetivo:** Identificar que la liveness probe apunta al puerto 8080 (incorrecto) en lugar del puerto 80 donde nginx escucha, corregir el Deployment y verificar la estabilización.

#### Instrucciones

1. Observar los reinicios del Pod del Deployment:

```bash
kubectl get pods -n ckad-debug -l app=probe-misconfigured
```

2. Inspeccionar los eventos del Pod para identificar el fallo:

```bash
POD_NAME=$(kubectl get pods -n ckad-debug -l app=probe-misconfigured -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD_NAME -n ckad-debug
```

3. Observar la sección de Events — buscar mensajes como:

```
Warning  Unhealthy  Liveness probe failed: Get "http://10.x.x.x:8080/": dial tcp 10.x.x.x:8080: connect: connection refused
```

4. Verificar el número de reinicios (debería ser > 0):

```bash
kubectl get pod $POD_NAME -n ckad-debug -o jsonpath='{.status.containerStatuses[0].restartCount}'
echo ""
```

5. Identificar la configuración incorrecta de la probe:

```bash
kubectl get pod $POD_NAME -n ckad-debug -o jsonpath='{.spec.containers[0].livenessProbe.httpGet.port}'
echo " (incorrecto - nginx escucha en 80)"
```

6. Corregir el Deployment cambiando el puerto de ambas probes de 8080 a 80:

```bash
cat > ~/ckad-labs/lab05/debug-apps/probe-misconfigured-fixed.yaml << 'ENDOFFILE'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe-misconfigured
  namespace: ckad-debug
  labels:
    app: probe-misconfigured
spec:
  replicas: 1
  selector:
    matchLabels:
      app: probe-misconfigured
  template:
    metadata:
      labels:
        app: probe-misconfigured
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 3
        startupProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 2
          failureThreshold: 5
ENDOFFILE
```

7. Aplicar la corrección:

```bash
kubectl apply -f ~/ckad-labs/lab05/debug-apps/probe-misconfigured-fixed.yaml
```

8. Monitorear el rollout:

```bash
kubectl rollout status deployment/probe-misconfigured -n ckad-debug --timeout=60s
```

9. Verificar el historial de rollout:

```bash
kubectl rollout history deployment/probe-misconfigured -n ckad-debug
```

#### Salida Esperada

```
deployment "probe-misconfigured" successfully rolled out
```

```
deployment.apps/probe-misconfigured
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

#### Verificación

```bash
# El Pod debe estar 1/1 Ready sin reinicios
kubectl get pods -n ckad-debug -l app=probe-misconfigured
# Esperar 20 segundos y confirmar que restartCount sigue en 0
sleep 20
NEW_POD=$(kubectl get pods -n ckad-debug -l app=probe-misconfigured -o jsonpath='{.items[0].metadata.name}')
RESTARTS=$(kubectl get pod $NEW_POD -n ckad-debug -o jsonpath='{.status.containerStatuses[0].restartCount}')
echo "Reinicios después de corrección: $RESTARTS (esperado: 0)"
```

---

### Paso 3: Escenario 2 — Hacer que el Pod pase la readiness probe

**Objetivo:** El Pod `readiness-demo` está Running pero no Ready porque la readiness probe verifica la existencia de `/tmp/ready`. Crear el archivo para que el Pod pase a Ready.

#### Instrucciones

1. Verificar el estado actual del Pod:

```bash
kubectl get pod readiness-demo -n ckad-debug
```

2. Confirmar que el Pod está Running pero no Ready (0/1):

```bash
kubectl get pod readiness-demo -n ckad-debug -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
echo " (esperado: False)"
```

3. Inspeccionar los eventos para ver los fallos de readiness:

```bash
kubectl describe pod readiness-demo -n ckad-debug | grep -A 5 "Events:"
```

4. Observar el mensaje de la probe fallida:

```bash
kubectl describe pod readiness-demo -n ckad-debug | grep "Readiness probe failed"
```

5. Crear el archivo `/tmp/ready` dentro del contenedor usando `kubectl exec`:

```bash
kubectl exec readiness-demo -n ckad-debug -- touch /tmp/ready
```

6. Esperar a que la probe detecte el archivo (máximo 10 segundos):

```bash
sleep 10
kubectl get pod readiness-demo -n ckad-debug
```

7. Confirmar que la condición Ready cambió a True:

```bash
kubectl get pod readiness-demo -n ckad-debug -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
echo " (esperado: True)"
```

#### Salida Esperada

```
NAME             READY   STATUS    RESTARTS   AGE
readiness-demo   1/1     Running   0          3m
```

#### Verificación

```bash
# Verificar que el Pod está Ready
READY_STATUS=$(kubectl get pod readiness-demo -n ckad-debug -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
if [ "$READY_STATUS" = "True" ]; then
  echo "PASS: readiness-demo está Ready"
else
  echo "FAIL: readiness-demo no está Ready (status: $READY_STATUS)"
fi
```

---

### Paso 4: Escenario 3 — Resolver recursos faltantes (ConfigMap y PVC)

**Objetivo:** El Pod `broken-config` no arranca por un ConfigMap inexistente y el Pod `broken-volume` está Pending por un PVC no vinculado. Crear los recursos faltantes para resolver ambos problemas.

#### Instrucciones

1. Diagnosticar el Pod `broken-config`:

```bash
kubectl describe pod broken-config -n ckad-debug | grep -A 3 "Warning"
```

2. Observar el error específico del ConfigMap:

```bash
kubectl get pod broken-config -n ckad-debug -o jsonpath='{.status.containerStatuses[0].state.waiting.message}'
echo ""
```

3. Verificar que el ConfigMap `app-config` no existe:

```bash
kubectl get configmap app-config -n ckad-debug 2>&1
```

4. Crear el ConfigMap faltante con datos de configuración válidos:

```bash
kubectl create configmap app-config -n ckad-debug \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=80 \
  --from-literal=APP_NAME=debug-lab-app \
  --from-literal=LOG_LEVEL=info
```

5. Esperar a que el Pod `broken-config` se recupere automáticamente:

```bash
sleep 15
kubectl get pod broken-config -n ckad-debug
```

6. Si el Pod no se recupera automáticamente, eliminarlo para que se recree (los Pods standalone no se recrean, así que reaplicamos):

```bash
# Si sigue en error, eliminar y recrear
if kubectl get pod broken-config -n ckad-debug -o jsonpath='{.status.phase}' | grep -qv "Running"; then
  kubectl delete pod broken-config -n ckad-debug --grace-period=0 --force 2>/dev/null
  sleep 5
  kubectl apply -f ~/ckad-labs/lab05/debug-apps/broken-config.yaml
fi
sleep 10
kubectl get pod broken-config -n ckad-debug
```

7. Ahora diagnosticar el Pod `broken-volume`:

```bash
kubectl describe pod broken-volume -n ckad-debug | grep -A 5 "Events:"
```

8. Verificar que el PVC `app-data-pvc` no existe:

```bash
kubectl get pvc app-data-pvc -n ckad-debug 2>&1
```

9. Crear el PersistentVolume y PersistentVolumeClaim necesarios:

```bash
cat > ~/ckad-labs/lab05/debug-apps/pv-pvc.yaml << 'ENDOFFILE'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: app-data-pv
  labels:
    type: local
spec:
  storageClassName: standard
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /tmp/app-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
  namespace: ckad-debug
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
ENDOFFILE
```

10. Aplicar el PV y PVC:

```bash
kubectl apply -f ~/ckad-labs/lab05/debug-apps/pv-pvc.yaml
```

11. Verificar que el PVC está Bound:

```bash
kubectl get pvc app-data-pvc -n ckad-debug
```

12. Esperar a que el Pod `broken-volume` pase a Running:

```bash
sleep 15
kubectl get pod broken-volume -n ckad-debug
```

13. Si el Pod sigue en Pending, puede requerir recreación:

```bash
if kubectl get pod broken-volume -n ckad-debug -o jsonpath='{.status.phase}' | grep -q "Pending"; then
  kubectl delete pod broken-volume -n ckad-debug --grace-period=0 --force 2>/dev/null
  sleep 5
  kubectl apply -f ~/ckad-labs/lab05/debug-apps/broken-volume.yaml
fi
sleep 15
kubectl get pod broken-volume -n ckad-debug
```

#### Salida Esperada

```
NAME            READY   STATUS    RESTARTS   AGE
broken-config   1/1     Running   0          15s
broken-volume   1/1     Running   0          15s
```

#### Verificación

```bash
# Verificar ambos Pods
for POD in broken-config broken-volume; do
  STATUS=$(kubectl get pod $POD -n ckad-debug -o jsonpath='{.status.phase}')
  READY=$(kubectl get pod $POD -n ckad-debug -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  echo "$POD: Phase=$STATUS, Ready=$READY"
done
```

---

### Paso 5: Escenario 4 — Depurar contenedor distroless con contenedor efímero

**Objetivo:** El Pod `distroless-app` falla porque la imagen distroless no tiene shell. Reemplazar con una versión funcional y demostrar el uso de `kubectl debug` para inspeccionar contenedores sin herramientas.

#### Instrucciones

1. Verificar que el Pod distroless está en CrashLoopBackOff:

```bash
kubectl get pod distroless-app -n ckad-debug
```

2. Revisar los logs para confirmar el error:

```bash
kubectl logs distroless-app -n ckad-debug
```

3. Intentar exec (fallará porque no hay shell):

```bash
kubectl exec distroless-app -n ckad-debug -- ls / 2>&1 || echo "Error esperado: no hay shell en la imagen distroless"
```

4. Eliminar el Pod fallido y crear una versión funcional con una imagen que simule un contenedor "minimal" (sin herramientas de debug):

```bash
kubectl delete pod distroless-app -n ckad-debug --grace-period=0 --force 2>/dev/null
sleep 5
```

5. Crear un Pod con imagen mínima que funcione pero sin herramientas de depuración:

```bash
cat > ~/ckad-labs/lab05/debug-apps/distroless-app-fixed.yaml << 'ENDOFFILE'
apiVersion: v1
kind: Pod
metadata:
  name: distroless-app
  namespace: ckad-debug
  labels:
    app: distroless-app
spec:
  containers:
  - name: app
    image: nginx:1.27.0
    command: ["nginx", "-g", "daemon off;"]
    ports:
    - containerPort: 80
ENDOFFILE
```

6. Aplicar el Pod funcional:

```bash
kubectl apply -f ~/ckad-labs/lab05/debug-apps/distroless-app-fixed.yaml
sleep 10
kubectl get pod distroless-app -n ckad-debug
```

7. Demostrar el uso de `kubectl debug` con contenedor efímero para inspeccionar el Pod:

```bash
kubectl debug -it distroless-app -n ckad-debug --image=busybox:1.36.1 --target=app -- sh -c "echo '=== Proceso del contenedor target ===' && ps aux && echo '=== Sistema de archivos compartido ===' && ls /proc/1/root/etc/nginx/ && echo '=== Conectividad de red ===' && wget -qO- http://localhost:80 | head -5 && echo '=== Debug completado ==='"
```

> **Nota:** El flag `--target=app` permite compartir el namespace de procesos con el contenedor `app`, lo que permite ver sus procesos. Si el comando interactivo no funciona en tu entorno, puedes usar la versión no interactiva siguiente.

8. Alternativa no interactiva para verificar que el debug funciona:

```bash
kubectl debug distroless-app -n ckad-debug --image=busybox:1.36.1 --target=app -- wget -qO- http://localhost:80 2>/dev/null | head -3
```

9. Verificar que el Pod sigue Running después del debug:

```bash
kubectl get pod distroless-app -n ckad-debug
```

#### Salida Esperada

```
NAME             READY   STATUS    RESTARTS   AGE
distroless-app   1/1     Running   0          30s
```

Salida del contenedor efímero:
```
=== Proceso del contenedor target ===
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
=== Conectividad de red ===
<!DOCTYPE html>
<html>
<head>
=== Debug completado ===
```

#### Verificación

```bash
# Verificar que el Pod está Running y Ready
PHASE=$(kubectl get pod distroless-app -n ckad-debug -o jsonpath='{.status.phase}')
READY=$(kubectl get pod distroless-app -n ckad-debug -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
echo "distroless-app: Phase=$PHASE, Ready=$READY (esperado: Running, True)"
```

---

### Paso 6: Verificación final — Todos los escenarios resueltos

**Objetivo:** Confirmar que todos los Pods y Deployments del namespace `ckad-debug` están en estado saludable.

#### Instrucciones

1. Listar todos los Pods del namespace:

```bash
kubectl get pods -n ckad-debug -o wide
```

2. Verificar que todos están Ready:

```bash
kubectl get pods -n ckad-debug -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
```

3. Verificar el Deployment:

```bash
kubectl get deployment -n ckad-debug
```

4. Verificar los recursos creados (ConfigMap y PVC):

```bash
echo "=== ConfigMaps ==="
kubectl get configmap -n ckad-debug
echo ""
echo "=== PVCs ==="
kubectl get pvc -n ckad-debug
echo ""
echo "=== PVs ==="
kubectl get pv | grep app-data
```

#### Salida Esperada

```
NAME                                   READY   STATUS    RESTARTS   AGE
broken-config                          1/1     Running   0          5m
broken-volume                          1/1     Running   0          5m
distroless-app                         1/1     Running   0          3m
probe-misconfigured-xxxxxxxxx-xxxxx    1/1     Running   0          8m
readiness-demo                         1/1     Running   0          10m
```

```
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
probe-misconfigured   1/1     1            1           12m
```

#### Verificación

```bash
# Script de verificación final completo
echo "========================================="
echo "  VERIFICACIÓN FINAL - Lab 05-00-03"
echo "========================================="
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0

# Verificar cada Pod
for POD in broken-config broken-volume distroless-app readiness-demo; do
  READY=$(kubectl get pod $POD -n ckad-debug -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  if [ "$READY" = "True" ]; then
    echo "PASS: $POD está Ready"
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    echo "FAIL: $POD NO está Ready (status: $READY)"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
done

# Verificar Deployment
AVAILABLE=$(kubectl get deployment probe-misconfigured -n ckad-debug -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
if [ "$AVAILABLE" = "1" ]; then
  echo "PASS: Deployment probe-misconfigured tiene 1 réplica disponible"
  TOTAL_PASS=$((TOTAL_PASS + 1))
else
  echo "FAIL: Deployment probe-misconfigured no tiene réplicas disponibles"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
fi

# Verificar ConfigMap
if kubectl get configmap app-config -n ckad-debug &>/dev/null; then
  echo "PASS: ConfigMap app-config existe"
  TOTAL_PASS=$((TOTAL_PASS + 1))
else
  echo "FAIL: ConfigMap app-config no existe"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
fi

# Verificar PVC
PVC_STATUS=$(kubectl get pvc app-data-pvc -n ckad-debug -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$PVC_STATUS" = "Bound" ]; then
  echo "PASS: PVC app-data-pvc está Bound"
  TOTAL_PASS=$((TOTAL_PASS + 1))
else
  echo "FAIL: PVC app-data-pvc no está Bound (status: $PVC_STATUS)"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
fi

echo ""
echo "========================================="
echo "  Resultados: $TOTAL_PASS PASS / $TOTAL_FAIL FAIL"
echo "========================================="
```

---

## Resumen del Laboratorio

| Escenario | Problema | Solución | Comando Clave |
|-----------|----------|----------|---------------|
| 1 - Liveness Probe | Puerto incorrecto (8080 vs 80) | Cambiar puerto en probe a 80 | `kubectl describe pod` |
| 2 - Readiness Probe | Archivo `/tmp/ready` no existe | `kubectl exec -- touch /tmp/ready` | `kubectl exec` |
| 3a - ConfigMap | ConfigMap `app-config` no existe | `kubectl create configmap` | `kubectl describe pod` |
| 3b - PVC | PVC `app-data-pvc` no vinculado | Crear PV + PVC | `kubectl get pvc` |
| 4 - Distroless | No hay shell para depurar | `kubectl debug --image=busybox` | `kubectl debug` |

---

## Limpieza (Opcional)

```bash
# Eliminar todos los recursos del namespace (mantener namespace para siguientes labs)
kubectl delete deployment probe-misconfigured -n ckad-debug
kubectl delete pod readiness-demo broken-config broken-volume distroless-app -n ckad-debug
kubectl delete configmap app-config -n ckad-debug
kubectl delete pvc app-data-pvc -n ckad-debug
kubectl delete pv app-data-pv 2>/dev/null

# Limpiar archivos locales
rm -rf ~/ckad-labs/lab05/debug-apps/
```

---

## Troubleshooting Común

| Problema | Causa | Solución |
|----------|-------|----------|
| Pod en `ImagePullBackOff` | Sin acceso a internet o imagen incorrecta | Verificar conectividad: `kubectl describe pod` → Events |
| PVC en `Pending` indefinidamente | No hay StorageClass `standard` o no hay PV disponible | Crear PV manualmente o usar StorageClass por defecto del clúster |
| `kubectl debug` no funciona | Versión de kubectl < 1.23 | Actualizar kubectl o usar `kubectl exec` con Pod de debug separado |
| Pod no se recupera tras crear ConfigMap | Pods standalone no se recrean automáticamente | Eliminar y recrear el Pod |
| Contenedor efímero no ve procesos del target | Feature gate `EphemeralContainers` deshabilitado | Verificar versión del clúster (requiere 1.25+) |

---

---

# Monitoreo básico de recursos

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 35 minutos |
| **Complejidad** | Fácil |
| **Nivel Bloom** | Aplicar |
| **Módulo** | 5 — Observabilidad y estados de Pods |

---

## Descripción General

En este laboratorio utilizarás `kubectl top` para visualizar el consumo real de CPU y memoria en el clúster, desplegarás Pods con carga controlada para observar métricas en tiempo real, y provocarás intencionalmente un evento OOMKilled para correlacionar los estados de contenedor (vistos en la lección 5.1) con las métricas reportadas por metrics-server. Aprenderás a diferenciar entre `requests` (scheduling) y `limits` (enforcement) mediante observación directa del comportamiento del clúster.

---

## Objetivos de Aprendizaje

Al completar este laboratorio serás capaz de:

- [ ] Usar `kubectl top pods` y `kubectl top nodes` para visualizar el consumo actual de CPU y memoria en el clúster
- [ ] Configurar `requests` y `limits` de CPU y memoria en contenedores y observar su impacto en métricas
- [ ] Identificar Pods que superan sus limits de memoria (OOMKilled) correlacionando estados de contenedor con métricas
- [ ] Interpretar la diferencia entre requests (scheduling) y limits (enforcement) en el contexto de observabilidad
- [ ] Ordenar y filtrar métricas de Pods por consumo de CPU y memoria usando opciones de `kubectl top`

---

## Prerrequisitos

### Conocimientos previos

| Tema | Nivel requerido |
|------|----------------|
| Estados de Pods y contenedores (lección 5.1) | Comprensión de `OOMKilled`, `CrashLoopBackOff`, `restartCount` |
| Manifiestos YAML de Pods | Capacidad de escribir specs con `resources` |
| Comandos básicos de kubectl | `get`, `describe`, `logs`, `apply`, `delete` |

### Acceso y entorno

- Práctica 22 completada: Pods en estado `Running` en namespace `ckad-debug`
- Addon `metrics-server` habilitado en minikube
- Mínimo 60 segundos transcurridos desde la habilitación de metrics-server

---

## Entorno del Laboratorio

### Hardware mínimo

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU | 2 núcleos | 4 núcleos |
| RAM | 4 GB | 8 GB |
| Disco | 20 GB libres | 30 GB libres |

### Software requerido

| Herramienta | Versión |
|-------------|---------|
| minikube | 1.33.1 |
| kubectl | 1.30.2 |
| Docker Engine | 26.1.4 |

### Preparación del entorno

```bash
# Verificar que minikube está corriendo
minikube status

# Habilitar metrics-server si no está activo
minikube addons enable metrics-server

# Esperar a que metrics-server esté disponible (mínimo 60s)
echo "Esperando a que metrics-server esté operativo..."
kubectl wait --for=condition=Available deployment/metrics-server \
  -n kube-system --timeout=120s

# Verificar que el namespace ckad-debug existe
kubectl get namespace ckad-debug

# Crear directorio de trabajo para este lab
mkdir -p ~/ckad-labs/lab05/lab05-00-04
cd ~/ckad-labs/lab05/lab05-00-04
```

---

## Paso a Paso

### Paso 1: Verificar metrics-server y métricas de nodos

**Objetivo:** Confirmar que metrics-server está operativo y visualizar el consumo de recursos a nivel de nodo.

**Instrucciones:**

1. Verificar que el deployment de metrics-server está corriendo:

```bash
kubectl get deployment metrics-server -n kube-system
```

2. Consultar las métricas del nodo:

```bash
kubectl top nodes
```

3. Observar los campos reportados: nombre del nodo, CPU utilizada (cores y porcentaje), y memoria utilizada (bytes y porcentaje):

```bash
kubectl top nodes --no-headers
```

**Salida esperada:**

```
NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
minikube   250m         12%    1200Mi          30%
```

> **Nota:** Los valores exactos variarán según tu sistema. Lo importante es que el comando retorne datos sin error.

**Verificación:**

```bash
# Si este comando retorna datos numéricos, metrics-server está operativo
kubectl top nodes | grep -v "NAME" | wc -l
```

El resultado debe ser `1` (o más si tienes múltiples nodos).

---

### Paso 2: Visualizar métricas de Pods existentes en ckad-debug

**Objetivo:** Usar `kubectl top pods` para ver el consumo de recursos de los Pods creados en prácticas anteriores.

**Instrucciones:**

1. Listar los Pods en ejecución en el namespace `ckad-debug`:

```bash
kubectl get pods -n ckad-debug
```

2. Visualizar las métricas de CPU y memoria de esos Pods:

```bash
kubectl top pods -n ckad-debug
```

3. Ordenar los Pods por consumo de CPU (mayor primero):

```bash
kubectl top pods -n ckad-debug --sort-by=cpu
```

4. Ordenar los Pods por consumo de memoria:

```bash
kubectl top pods -n ckad-debug --sort-by=memory
```

5. Visualizar métricas de todos los namespaces para tener una vista global:

```bash
kubectl top pods --all-namespaces --sort-by=memory
```

6. Visualizar métricas incluyendo los contenedores individuales dentro de cada Pod:

```bash
kubectl top pods -n ckad-debug --containers
```

**Salida esperada (ejemplo):**

```
NAME                  CPU(cores)   MEMORY(bytes)
debug-pod-1           1m           10Mi
debug-pod-2           2m           15Mi
```

**Verificación:**

```bash
# Confirmar que kubectl top retorna datos para al menos un Pod
kubectl top pods -n ckad-debug --no-headers | wc -l
```

El resultado debe ser mayor o igual a 1.

---

### Paso 3: Desplegar Pod de carga controlada (stress-demo)

**Objetivo:** Crear un Pod con la imagen `polinux/stress:1.0.4` que consuma CPU y memoria de forma controlada, configurando `requests` y `limits` explícitos.

**Instrucciones:**

1. Crear el manifiesto YAML para el Pod `stress-demo`:

```bash
cat <<'EOF' > stress-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: stress-demo
  namespace: ckad-debug
  labels:
    app: stress-demo
    purpose: metrics-lab
spec:
  containers:
  - name: stress
    image: polinux/stress:1.0.4
    command: ["stress"]
    args:
    - "--cpu"
    - "1"
    - "--vm"
    - "1"
    - "--vm-bytes"
    - "64M"
    - "--vm-hang"
    - "1"
    - "--timeout"
    - "600s"
    resources:
      requests:
        cpu: "50m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
EOF
```

2. Aplicar el manifiesto:

```bash
kubectl apply -f stress-demo.yaml
```

3. Esperar a que el Pod esté en estado `Running`:

```bash
kubectl wait --for=condition=Ready pod/stress-demo -n ckad-debug --timeout=60s
```

4. Verificar el estado del Pod:

```bash
kubectl get pod stress-demo -n ckad-debug
```

**Salida esperada:**

```
NAME          READY   STATUS    RESTARTS   AGE
stress-demo   1/1     Running   0          15s
```

**Verificación:**

```bash
kubectl get pod stress-demo -n ckad-debug -o jsonpath='{.status.phase}'
```

Debe retornar: `Running`

---

### Paso 4: Observar métricas en tiempo real

**Objetivo:** Usar `watch` para monitorear cómo el Pod `stress-demo` consume recursos y correlacionar con los `requests` y `limits` configurados.

**Instrucciones:**

1. Observar las métricas en tiempo real (ejecutar y esperar ~30 segundos para que metrics-server recopile datos):

```bash
# Esperar 30 segundos para que metrics-server capture datos del nuevo Pod
sleep 30

# Ver métricas una vez
kubectl top pods -n ckad-debug
```

2. Para observación continua (presionar Ctrl+C para detener):

```bash
watch -n 2 kubectl top pods -n ckad-debug --sort-by=cpu
```

3. Comparar el consumo real con los requests y limits configurados:

```bash
echo "=== Requests y Limits configurados ==="
kubectl get pod stress-demo -n ckad-debug -o jsonpath='{.spec.containers[0].resources}' | jq .

echo ""
echo "=== Consumo real (métricas) ==="
kubectl top pod stress-demo -n ckad-debug
```

4. Observar que el consumo de CPU reportado estará limitado por el `limit` de 200m (CPU throttling):

```bash
kubectl top pod stress-demo -n ckad-debug --no-headers
```

**Salida esperada:**

```
=== Requests y Limits configurados ===
{
  "limits": {
    "cpu": "200m",
    "memory": "128Mi"
  },
  "requests": {
    "cpu": "50m",
    "memory": "64Mi"
  }
}

=== Consumo real (métricas) ===
NAME          CPU(cores)   MEMORY(bytes)
stress-demo   200m         66Mi
```

> **Interpretación clave:** El Pod solicita `--cpu 1` (1 core completo = 1000m) pero el limit es 200m. El kernel de Linux aplica CPU throttling, limitando el consumo real a ~200m. La memoria real (~64Mi) está dentro del limit de 128Mi, por lo que no hay OOMKill.

**Verificación:**

```bash
# Verificar que el Pod sigue Running sin reinicios (no hay OOMKill)
kubectl get pod stress-demo -n ckad-debug -o jsonpath='{.status.containerStatuses[0].restartCount}'
```

Debe retornar: `0`

---

### Paso 5: Provocar OOMKilled con un Pod que excede su límite de memoria

**Objetivo:** Desplegar un Pod con un límite de memoria bajo (32Mi) que intente usar 64Mi, observar el estado `OOMKilled` y correlacionar con las métricas y eventos.

**Instrucciones:**

1. Crear el manifiesto para el Pod `oom-trigger`:

```bash
cat <<'EOF' > oom-trigger.yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-trigger
  namespace: ckad-debug
  labels:
    app: oom-trigger
    purpose: metrics-lab
spec:
  containers:
  - name: stress
    image: polinux/stress:1.0.4
    command: ["stress"]
    args:
    - "--vm"
    - "1"
    - "--vm-bytes"
    - "64M"
    - "--timeout"
    - "600s"
    resources:
      requests:
        cpu: "10m"
        memory: "32Mi"
      limits:
        cpu: "100m"
        memory: "32Mi"
EOF
```

2. Aplicar el manifiesto:

```bash
kubectl apply -f oom-trigger.yaml
```

3. Observar cómo el Pod entra en ciclo de reinicio (esperar ~10 segundos):

```bash
sleep 10
kubectl get pod oom-trigger -n ckad-debug
```

4. Verificar el estado del contenedor — debe mostrar `OOMKilled`:

```bash
kubectl get pod oom-trigger -n ckad-debug -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
```

5. Revisar el conteo de reinicios:

```bash
kubectl get pod oom-trigger -n ckad-debug -o jsonpath='{.status.containerStatuses[0].restartCount}'
```

6. Usar `kubectl describe` para ver los eventos asociados al OOMKill:

```bash
kubectl describe pod oom-trigger -n ckad-debug | tail -20
```

7. Intentar ver métricas del Pod en OOMKilled/CrashLoopBackOff:

```bash
kubectl top pod oom-trigger -n ckad-debug 2>&1 || echo "NOTA: No se pueden obtener métricas de Pods que no están corriendo"
```

**Salida esperada:**

```
NAME          READY   STATUS             RESTARTS      AGE
oom-trigger   0/1     CrashLoopBackOff   3 (15s ago)   45s
```

Estado del contenedor:

```
OOMKilled
```

Eventos (extracto):

```
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  50s                default-scheduler  Successfully assigned ckad-debug/oom-trigger to minikube
  Normal   Pulled     10s (x4 over 48s)  kubelet            Container image "polinux/stress:1.0.4" already present on machine
  Normal   Created    10s (x4 over 48s)  kubelet            Created container stress
  Normal   Started    10s (x4 over 48s)  kubelet            Started container stress
  Warning  BackOff    5s (x3 over 35s)   kubelet            Back-off restarting failed container
```

> **Interpretación:** `kubectl top` no muestra métricas de Pods en estado `CrashLoopBackOff` porque el contenedor no está ejecutándose el tiempo suficiente para que metrics-server capture una muestra. Esto es un comportamiento esperado y una limitación importante a entender.

**Verificación:**

```bash
# Confirmar que el reason es OOMKilled
REASON=$(kubectl get pod oom-trigger -n ckad-debug -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}')
if [ "$REASON" = "OOMKilled" ]; then
  echo "✅ CORRECTO: El Pod fue terminado por OOMKilled"
else
  echo "❌ INCORRECTO: Se esperaba OOMKilled pero se obtuvo: $REASON"
fi
```

---

### Paso 6: Comparar requests vs limits — impacto en scheduling y enforcement

**Objetivo:** Comprender visualmente la diferencia entre requests (usados para scheduling) y limits (usados para enforcement) revisando las métricas y el estado del nodo.

**Instrucciones:**

1. Ver la capacidad y la asignación de recursos del nodo:

```bash
kubectl describe node minikube | grep -A 10 "Allocated resources"
```

2. Observar cómo los `requests` se reflejan en la asignación del nodo pero los `limits` no afectan al scheduling:

```bash
echo "=== Requests totales del namespace ckad-debug ==="
kubectl get pods -n ckad-debug -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests}{"\n"}{end}'
```

3. Comparar el consumo real (métricas) vs lo reservado (requests) vs lo máximo permitido (limits):

```bash
echo ""
echo "=== Tabla comparativa: stress-demo ==="
echo "-------------------------------------------"
echo "Recurso     | Request | Limit  | Real (top)"
echo "-------------------------------------------"

CPU_REAL=$(kubectl top pod stress-demo -n ckad-debug --no-headers 2>/dev/null | awk '{print $2}')
MEM_REAL=$(kubectl top pod stress-demo -n ckad-debug --no-headers 2>/dev/null | awk '{print $3}')

echo "CPU         | 50m     | 200m   | ${CPU_REAL:-N/A}"
echo "Memoria     | 64Mi    | 128Mi  | ${MEM_REAL:-N/A}"
echo "-------------------------------------------"
```

4. Verificar los eventos de tipo Warning que podrían indicar throttling o problemas de recursos:

```bash
kubectl get events -n ckad-debug --field-selector type=Warning --sort-by='.lastTimestamp'
```

**Salida esperada (ejemplo de tabla comparativa):**

```
=== Tabla comparativa: stress-demo ===
-------------------------------------------
Recurso     | Request | Limit  | Real (top)
-------------------------------------------
CPU         | 50m     | 200m   | 199m
Memoria     | 64Mi    | 128Mi  | 66Mi
-------------------------------------------
```

> **Conceptos clave:**
> - **Request < Real < Limit:** situación normal. El Pod usa más que su request pero menos que su limit.
> - **Real ≈ Limit (CPU):** indica CPU throttling activo. El proceso quiere más CPU pero el kernel lo restringe.
> - **Real > Limit (Memoria):** imposible en la práctica — el kernel mata el proceso (OOMKill) antes de que esto ocurra.

**Verificación:**

```bash
# Verificar que stress-demo sigue corriendo (demuestra que limits de CPU no matan el Pod)
kubectl get pod stress-demo -n ckad-debug -o jsonpath='{.status.phase}'
```

Debe retornar: `Running`

---

### Paso 7: Explorar opciones avanzadas de kubectl top

**Objetivo:** Practicar opciones adicionales de `kubectl top` que son útiles para monitoreo en entornos con múltiples namespaces.

**Instrucciones:**

1. Ver métricas de todos los Pods en todos los namespaces, ordenados por CPU:

```bash
kubectl top pods --all-namespaces --sort-by=cpu | head -15
```

2. Ver métricas de todos los Pods en todos los namespaces, ordenados por memoria:

```bash
kubectl top pods --all-namespaces --sort-by=memory | head -15
```

3. Ver métricas con detalle por contenedor (útil para Pods multi-contenedor):

```bash
kubectl top pods -n ckad-debug --containers
```

4. Obtener solo las métricas del Pod `stress-demo` sin cabecera (útil para scripting):

```bash
kubectl top pod stress-demo -n ckad-debug --no-headers
```

5. Combinar con otros comandos para crear un reporte rápido:

```bash
echo "=== Reporte de recursos - namespace ckad-debug ==="
echo ""
echo "--- Pods ordenados por CPU ---"
kubectl top pods -n ckad-debug --sort-by=cpu 2>/dev/null
echo ""
echo "--- Pods ordenados por Memoria ---"
kubectl top pods -n ckad-debug --sort-by=memory 2>/dev/null
echo ""
echo "--- Estado de Pods ---"
kubectl get pods -n ckad-debug -o wide
```

**Salida esperada (ejemplo):**

```
=== Reporte de recursos - namespace ckad-debug ===

--- Pods ordenados por CPU ---
NAME          CPU(cores)   MEMORY(bytes)
stress-demo   199m         66Mi
debug-pod-1   1m           10Mi

--- Pods ordenados por Memoria ---
NAME          CPU(cores)   MEMORY(bytes)
stress-demo   199m         66Mi
debug-pod-1   1m           10Mi

--- Estado de Pods ---
NAME          READY   STATUS             RESTARTS      AGE     IP           NODE       ...
stress-demo   1/1     Running            0             5m      172.17.0.5   minikube   ...
oom-trigger   0/1     CrashLoopBackOff   5 (30s ago)   4m      172.17.0.6   minikube   ...
```

**Verificación:**

```bash
# Confirmar que --sort-by funciona correctamente
kubectl top pods -n ckad-debug --sort-by=cpu --no-headers 2>/dev/null | head -1 | awk '{print $1}'
```

Debe retornar el nombre del Pod con mayor consumo de CPU (probablemente `stress-demo`).

---

## Validación y Pruebas

Ejecuta el siguiente script de validación completa para confirmar que todos los objetivos del laboratorio se han cumplido:

```bash
#!/bin/bash
echo "============================================"
echo "  VALIDACIÓN - Lab 05-00-04"
echo "  Monitoreo básico de recursos"
echo "============================================"
echo ""

PASS=0
FAIL=0

# Test 1: metrics-server operativo
echo -n "1. metrics-server disponible: "
if kubectl top nodes &>/dev/null; then
  echo "✅ PASS"
  ((PASS++))
else
  echo "❌ FAIL"
  ((FAIL++))
fi

# Test 2: kubectl top pods funciona en ckad-debug
echo -n "2. kubectl top pods en ckad-debug: "
if kubectl top pods -n ckad-debug &>/dev/null; then
  echo "✅ PASS"
  ((PASS++))
else
  echo "❌ FAIL"
  ((FAIL++))
fi

# Test 3: stress-demo está Running
echo -n "3. Pod stress-demo en Running: "
PHASE=$(kubectl get pod stress-demo -n ckad-debug -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$PHASE" = "Running" ]; then
  echo "✅ PASS"
  ((PASS++))
else
  echo "❌ FAIL (fase: $PHASE)"
  ((FAIL++))
fi

# Test 4: stress-demo tiene requests y limits configurados
echo -n "4. stress-demo con resources configurados: "
REQ_CPU=$(kubectl get pod stress-demo -n ckad-debug -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
LIM_MEM=$(kubectl get pod stress-demo -n ckad-debug -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null)
if [ "$REQ_CPU" = "50m" ] && [ "$LIM_MEM" = "128Mi" ]; then
  echo "✅ PASS"
  ((PASS++))
else
  echo "❌ FAIL (req_cpu=$REQ_CPU, lim_mem=$LIM_MEM)"
  ((FAIL++))
fi

# Test 5: oom-trigger muestra OOMKilled
echo -n "5. Pod oom-trigger con OOMKilled: "
OOM_REASON=$(kubectl get pod oom-trigger -n ckad-debug -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)
if [ "$OOM_REASON" = "OOMKilled" ]; then
  echo "✅ PASS"
  ((PASS++))
else
  echo "❌ FAIL (reason: $OOM_REASON)"
  ((FAIL++))
fi

# Test 6: oom-trigger tiene restartCount > 0
echo -n "6. oom-trigger con reinicios > 0: "
RESTARTS=$(kubectl get pod oom-trigger -n ckad-debug -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
if [ "$RESTARTS" -gt 0 ] 2>/dev/null; then
  echo "✅ PASS (reinicios: $RESTARTS)"
  ((PASS++))
else
  echo "❌ FAIL (reinicios: $RESTARTS)"
  ((FAIL++))
fi

# Test 7: --sort-by=cpu funciona
echo -n "7. Ordenamiento por CPU funciona: "
if kubectl top pods -n ckad-debug --sort-by=cpu &>/dev/null; then
  echo "✅ PASS"
  ((PASS++))
else
  echo "❌ FAIL"
  ((FAIL++))
fi

# Test 8: --all-namespaces funciona
echo -n "8. Métricas all-namespaces: "
COUNT=$(kubectl top pods --all-namespaces --no-headers 2>/dev/null | wc -l)
if [ "$COUNT" -gt 0 ]; then
  echo "✅ PASS ($COUNT pods con métricas)"
  ((PASS++))
else
  echo "❌ FAIL"
  ((FAIL++))
fi

echo ""
echo "============================================"
echo "  RESULTADO: $PASS pasaron, $FAIL fallaron"
echo "============================================"

if [ $FAIL -eq 0 ]; then
  echo "  🎉 ¡Laboratorio completado exitosamente!"
else
  echo "  ⚠️  Revisa los pasos fallidos antes de continuar."
fi
```

Guarda y ejecuta:

```bash
chmod +x ~/ckad-labs/lab05/lab05-00-04/validate.sh 2>/dev/null
bash ~/ckad-labs/lab05/lab05-00-04/validate.sh
```

---

## Solución de Problemas

### Problema 1: `kubectl top` retorna "error: Metrics API not available"

**Síntomas:**

```
error: Metrics API not available
```

o bien:

```
error: metrics not available yet
```

**Causa:** El addon `metrics-server` no está habilitado o no ha tenido tiempo suficiente para iniciar la recolección de métricas. Metrics-server necesita al menos 60-90 segundos después de iniciar para tener datos disponibles.

**Solución:**

```bash
# Verificar si el addon está habilitado
minikube addons list | grep metrics-server

# Si no está habilitado, activarlo
minikube addons enable metrics-server

# Verificar que el deployment esté Ready
kubectl get deployment metrics-server -n kube-system

# Esperar a que esté disponible
kubectl wait --for=condition=Available deployment/metrics-server \
  -n kube-system --timeout=120s

# Esperar al menos 60 segundos adicionales para recolección de datos
echo "Esperando 60 segundos para recolección de métricas..."
sleep 60

# Reintentar
kubectl top nodes
```

---

### Problema 2: Pod `stress-demo` no muestra métricas o muestra 0m/0Mi

**Síntomas:**

```
NAME          CPU(cores)   MEMORY(bytes)
stress-demo   0m           0Mi
```

O el Pod no aparece en la salida de `kubectl top pods`.

**Causa:** Metrics-server recopila datos en intervalos (por defecto cada 15 segundos). Si el Pod fue creado recientemente, puede que aún no haya una muestra disponible. También puede ocurrir si la imagen `polinux/stress:1.0.4` no se descargó correctamente y el contenedor no está realmente ejecutando la carga.

**Solución:**

```bash
# Verificar que el Pod está realmente Running y el contenedor ejecutándose
kubectl get pod stress-demo -n ckad-debug -o wide
kubectl describe pod stress-demo -n ckad-debug | grep -A 5 "State:"

# Verificar que no hay errores en los logs del contenedor
kubectl logs stress-demo -n ckad-debug

# Si los logs muestran que stress está corriendo, esperar más tiempo
sleep 45
kubectl top pod stress-demo -n ckad-debug

# Si la imagen no se descargó, verificar conectividad
kubectl get events -n ckad-debug --field-selector involvedObject.name=stress-demo

# Si persiste el problema, eliminar y recrear
kubectl delete pod stress-demo -n ckad-debug
kubectl apply -f stress-demo.yaml
sleep 45
kubectl top pod stress-demo -n ckad-debug
```

---

## Limpieza

Elimina los Pods de carga creados en este laboratorio, pero **mantén el namespace `ckad-debug`** con los recursos base de prácticas anteriores para uso en el Módulo 6.

```bash
# Eliminar los Pods de stress creados en este lab
kubectl delete pod stress-demo -n ckad-debug
kubectl delete pod oom-trigger -n ckad-debug

# Verificar que solo quedan los Pods de prácticas anteriores
kubectl get pods -n ckad-debug

# Verificar que el namespace sigue existiendo
kubectl get namespace ckad-debug

echo "✅ Limpieza completada. Namespace ckad-debug preservado para Módulo 6."
```

> **Importante:** NO elimines el namespace `ckad-debug` ni los Pods de prácticas anteriores. Serán utilizados en los laboratorios del Módulo 6 donde se expondrán como servicios.

---

## Resumen

### Conceptos clave aprendidos

| Concepto | Descripción |
|----------|-------------|
| `kubectl top nodes` | Muestra consumo real de CPU y memoria a nivel de nodo |
| `kubectl top pods` | Muestra consumo real de CPU y memoria por Pod |
| `--sort-by=cpu/memory` | Ordena la salida por el recurso indicado |
| `--all-namespaces` | Muestra métricas de todos los namespaces |
| `--containers` | Desglosa métricas por contenedor individual |
| `requests` | Reserva mínima usada para scheduling; no limita el consumo real |
| `limits` | Techo máximo de consumo; CPU se throttlea, memoria causa OOMKill |
| `OOMKilled` | El kernel termina el contenedor por exceder el limit de memoria |
| CPU throttling | El kernel restringe ciclos de CPU sin matar el proceso |

### Relación requests vs limits vs consumo real

```
requests ≤ consumo real ≤ limits  →  Situación normal
consumo real ≈ limit (CPU)       →  CPU throttling activo
consumo real > limit (memoria)   →  OOMKilled (imposible mantener)
```

### Conexión con la lección 5.1

Este laboratorio demostró en la práctica los estados de contenedor estudiados en la lección 5.1:

- **Estado `Terminated` con reason `OOMKilled`:** observado directamente en el Pod `oom-trigger`
- **Estado `Waiting` con reason `CrashLoopBackOff`:** resultado del ciclo de reinicios tras OOMKill
- **Campo `restartCount`:** indicador cuantitativo de inestabilidad correlacionado con métricas
- **Eventos de tipo Warning:** `BackOff` registrado en la bitácora del Pod

### Recursos adicionales

- [Documentación oficial: Gestión de recursos para contenedores](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Documentación oficial: Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Documentación oficial: Herramientas de monitoreo de recursos](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-usage-monitoring/)
- [Kubernetes: Significado de OOMKilled](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/)
