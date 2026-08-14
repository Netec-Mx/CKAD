# Configuración de aplicaciones con ConfigMaps

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Apply (Aplicar) |
| **Namespace** | `config-lab` |
| **Directorio de trabajo** | `~/ckad-labs/lab06/` |

## Descripción General

En esta práctica aplicarás el principio de separación de configuración y código creando ConfigMaps y consumiéndolos mediante variables de entorno individuales, inyección masiva con `envFrom`, y montaje como volúmenes. Observarás el comportamiento de actualización en caliente de los ConfigMaps montados como volúmenes versus la inmutabilidad de las variables de entorno sin reinicio del Pod. Finalmente, crearás un Deployment que combina ambos métodos de consumo.

## Objetivos de Aprendizaje

- [ ] Crear ConfigMaps de forma imperativa y declarativa con datos clave-valor y archivos de configuración completos
- [ ] Consumir ConfigMaps como variables de entorno individuales (`valueFrom.configMapKeyRef`) y masivas (`envFrom`)
- [ ] Montar ConfigMaps como volúmenes y verificar la accesibilidad de archivos dentro del contenedor
- [ ] Demostrar el comportamiento de actualización automática en volúmenes vs. la necesidad de reinicio para variables de entorno
- [ ] Crear un Deployment multi-réplica que combine ambos métodos de consumo de ConfigMaps

## Prerrequisitos

### Conocimientos Previos

- Comprensión de variables de entorno en Linux y contenedores
- Familiaridad con volúmenes en Kubernetes (conceptos básicos)
- Experiencia con el ciclo de vida de Pods y Deployments (Prácticas 11-13)
- Uso básico de `kubectl exec` para inspección de contenedores

### Acceso Requerido

- Clúster Kubernetes funcional (kind o minikube)
- `kubectl` configurado y conectado al clúster
- Acceso a internet para descargar la imagen `nginx:1.25.3`

## Entorno del Laboratorio

### Software Necesario

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| kubectl | 1.30.2 | Gestión del clúster |
| kind / minikube | 0.23.0 / 1.33.1 | Clúster local |
| Docker Engine | 26.1.4 | Runtime de contenedores |

### Preparación Inicial

```bash
# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab06
cd ~/ckad-labs/lab06

# Verificar conectividad al clúster
kubectl cluster-info

# Crear namespace dedicado para este laboratorio
kubectl create namespace config-lab

# Establecer namespace por defecto para esta sesión
kubectl config set-context --current --namespace=config-lab

# Verificar namespace activo
kubectl config view --minify | grep namespace
```

**Salida esperada:**
```
namespace: config-lab
```

---

## Paso 1: Crear el ConfigMap con datos clave-valor y archivo de configuración

### Objetivo

Crear un ConfigMap llamado `app-config` que contenga tanto pares clave-valor simples (para variables de entorno) como un archivo de configuración completo (`app.properties`).

### Instrucciones

1. Crea el archivo `app.properties` con la configuración completa de la aplicación:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/app.properties
# Application Configuration File
app.name=webapp
app.description=CKAD Lab Application
app.cache.enabled=true
app.cache.ttl=3600
app.database.pool.size=10
app.database.pool.timeout=30000
app.feature.dark-mode=false
app.feature.notifications=true
app.metrics.enabled=true
app.metrics.interval=15
EOF
```

2. Crea el manifiesto YAML declarativo del ConfigMap:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/configmap-app-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: config-lab
  labels:
    app: webapp
    lab: "04-00-01"
data:
  # Claves individuales para uso como variables de entorno
  APP_ENV: "production"
  APP_PORT: "8080"
  APP_LOG_LEVEL: "info"
  APP_VERSION: "1.0.0"
  # Archivo de configuración completo (clave multi-línea)
  app.properties: |
    # Application Configuration File
    app.name=webapp
    app.description=CKAD Lab Application
    app.cache.enabled=true
    app.cache.ttl=3600
    app.database.pool.size=10
    app.database.pool.timeout=30000
    app.feature.dark-mode=false
    app.feature.notifications=true
    app.metrics.enabled=true
    app.metrics.interval=15
EOF
```

3. Aplica el manifiesto al clúster:

```bash
kubectl apply -f ~/ckad-labs/lab06/configmap-app-config.yaml
```

4. Verifica la creación del ConfigMap:

```bash
kubectl describe configmap app-config
```

### Salida Esperada

```
Name:         app-config
Namespace:    config-lab
Labels:       app=webapp
              lab=04-00-01
Annotations:  <none>

Data
====
APP_ENV:
----
production
APP_LOG_LEVEL:
----
info
APP_PORT:
----
8080
APP_VERSION:
----
1.0.0
app.properties:
----
# Application Configuration File
app.name=webapp
app.description=CKAD Lab Application
app.cache.enabled=true
app.cache.ttl=3600
app.database.pool.size=10
app.database.pool.timeout=30000
app.feature.dark-mode=false
app.feature.notifications=true
app.metrics.enabled=true
app.metrics.interval=15


BinaryData
====

Events:  <none>
```

### Verificación

```bash
# Confirmar que el ConfigMap tiene 5 claves de datos
kubectl get configmap app-config -o jsonpath='{.data}' | jq 'keys'
```

**Salida esperada:**
```json
[
  "APP_ENV",
  "APP_LOG_LEVEL",
  "APP_PORT",
  "APP_VERSION",
  "app.properties"
]
```

---

## Paso 2: Consumir ConfigMap como variables de entorno individuales

### Objetivo

Crear un Pod que consuma claves específicas del ConfigMap como variables de entorno usando `valueFrom.configMapKeyRef`.

### Instrucciones

1. Crea el manifiesto del Pod:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/pod-env-individual.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-env-individual
  namespace: config-lab
  labels:
    app: webapp
    test: env-individual
spec:
  containers:
  - name: nginx
    image: nginx:1.25.3
    ports:
    - containerPort: 80
    env:
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV
    - name: APP_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_PORT
    - name: APP_LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_LOG_LEVEL
    - name: APP_VERSION
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_VERSION
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab06/pod-env-individual.yaml
```

3. Espera a que el Pod esté en estado Running:

```bash
kubectl wait --for=condition=Ready pod/pod-env-individual --timeout=60s
```

4. Verifica las variables de entorno dentro del contenedor:

```bash
kubectl exec pod-env-individual -- env | grep -E "^APP_"
```

### Salida Esperada

```
APP_ENV=production
APP_PORT=8080
APP_LOG_LEVEL=info
APP_VERSION=1.0.0
```

### Verificación

```bash
# Verificar un valor específico
kubectl exec pod-env-individual -- printenv APP_ENV
```

**Salida esperada:**
```
production
```

---

## Paso 3: Consumir ConfigMap completo con envFrom

### Objetivo

Crear un segundo Pod que inyecte todas las claves del ConfigMap como variables de entorno usando `envFrom.configMapRef`.

### Instrucciones

1. Crea el manifiesto del Pod con `envFrom`:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/pod-env-from.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-env-from
  namespace: config-lab
  labels:
    app: webapp
    test: env-from
spec:
  containers:
  - name: nginx
    image: nginx:1.25.3
    ports:
    - containerPort: 80
    envFrom:
    - configMapRef:
        name: app-config
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab06/pod-env-from.yaml
```

3. Espera a que el Pod esté listo:

```bash
kubectl wait --for=condition=Ready pod/pod-env-from --timeout=60s
```

4. Verifica que TODAS las claves del ConfigMap están disponibles como variables de entorno:

```bash
kubectl exec pod-env-from -- env | grep -E "^APP_|^app\."
```

### Salida Esperada

```
APP_ENV=production
APP_LOG_LEVEL=info
APP_PORT=8080
APP_VERSION=1.0.0
app.properties=# Application Configuration File
app.name=webapp
...
```

> **Nota:** Observa que la clave `app.properties` (el archivo multi-línea completo) también se inyecta como variable de entorno. Esto puede no ser deseable en todos los casos — es una consideración importante al usar `envFrom` con ConfigMaps que contienen mezcla de datos simples y archivos.

### Verificación

```bash
# Contar las variables inyectadas desde el ConfigMap
kubectl exec pod-env-from -- env | grep -c -E "^APP_"
```

**Salida esperada:**
```
4
```

---

## Paso 4: Montar ConfigMap como volumen

### Objetivo

Crear un Pod que monte el ConfigMap como volumen en `/etc/app-config/`, exponiendo cada clave como un archivo independiente dentro del directorio.

### Instrucciones

1. Crea el manifiesto del Pod con volumen montado:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/pod-volume-mount.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-volume-mount
  namespace: config-lab
  labels:
    app: webapp
    test: volume-mount
spec:
  containers:
  - name: nginx
    image: nginx:1.25.3
    ports:
    - containerPort: 80
    volumeMounts:
    - name: config-volume
      mountPath: /etc/app-config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: app-config
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab06/pod-volume-mount.yaml
```

3. Espera a que el Pod esté listo:

```bash
kubectl wait --for=condition=Ready pod/pod-volume-mount --timeout=60s
```

4. Lista los archivos montados en el directorio de configuración:

```bash
kubectl exec pod-volume-mount -- ls -la /etc/app-config/
```

5. Lee el contenido del archivo `app.properties`:

```bash
kubectl exec pod-volume-mount -- cat /etc/app-config/app.properties
```

6. Verifica una clave individual montada como archivo:

```bash
kubectl exec pod-volume-mount -- cat /etc/app-config/APP_ENV
```

### Salida Esperada

Listado de archivos:
```
total 0
drwxrwxrwx 3 root root 140 ... .
drwxr-xr-x 1 root root  60 ... ..
lrwxrwxrwx 1 root root  14 ... APP_ENV -> ..data/APP_ENV
lrwxrwxrwx 1 root root  20 ... APP_LOG_LEVEL -> ..data/APP_LOG_LEVEL
lrwxrwxrwx 1 root root  15 ... APP_PORT -> ..data/APP_PORT
lrwxrwxrwx 1 root root  18 ... APP_VERSION -> ..data/APP_VERSION
lrwxrwxrwx 1 root root  21 ... app.properties -> ..data/app.properties
```

Contenido de `app.properties`:
```
# Application Configuration File
app.name=webapp
app.description=CKAD Lab Application
app.cache.enabled=true
app.cache.ttl=3600
app.database.pool.size=10
app.database.pool.timeout=30000
app.feature.dark-mode=false
app.feature.notifications=true
app.metrics.enabled=true
app.metrics.interval=15
```

Contenido de `APP_ENV`:
```
production
```

### Verificación

```bash
# Verificar que el montaje es de solo lectura
kubectl exec pod-volume-mount -- touch /etc/app-config/test 2>&1 | grep -i "read-only"
```

**Salida esperada (contiene):**
```
Read-only file system
```

---

## Paso 5: Observar actualización automática en volúmenes montados

### Objetivo

Modificar el ConfigMap y observar que los archivos montados como volumen se actualizan automáticamente (con latencia de ~60 segundos), mientras que las variables de entorno permanecen con el valor original.

### Instrucciones

1. Registra el valor actual de `APP_LOG_LEVEL` en el Pod con volumen:

```bash
echo "--- Valor en volumen ANTES de actualizar ---"
kubectl exec pod-volume-mount -- cat /etc/app-config/APP_LOG_LEVEL
```

2. Registra el valor actual en el Pod con variables de entorno:

```bash
echo "--- Valor en env ANTES de actualizar ---"
kubectl exec pod-env-individual -- printenv APP_LOG_LEVEL
```

3. Actualiza el ConfigMap cambiando `APP_LOG_LEVEL` de `info` a `debug`:

```bash
kubectl patch configmap app-config -p '{"data":{"APP_LOG_LEVEL":"debug"}}'
```

4. Verifica que el ConfigMap se actualizó:

```bash
kubectl get configmap app-config -o jsonpath='{.data.APP_LOG_LEVEL}'
echo ""
```

**Salida esperada:**
```
debug
```

5. Espera hasta 90 segundos para la propagación al volumen y verifica:

```bash
echo "Esperando propagación al volumen (hasta 90s)..."
# Verificar cada 10 segundos hasta que cambie
for i in $(seq 1 9); do
  VALUE=$(kubectl exec pod-volume-mount -- cat /etc/app-config/APP_LOG_LEVEL 2>/dev/null)
  if [ "$VALUE" = "debug" ]; then
    echo "✅ Volumen actualizado después de ~$((i*10)) segundos: APP_LOG_LEVEL=$VALUE"
    break
  fi
  echo "  Intento $i: aún '$VALUE', esperando 10s..."
  sleep 10
done
```

6. Verifica que la variable de entorno NO se actualizó en el Pod con env:

```bash
echo "--- Valor en env DESPUÉS de actualizar ConfigMap ---"
kubectl exec pod-env-individual -- printenv APP_LOG_LEVEL
```

### Salida Esperada

La variable de entorno sigue mostrando el valor original:
```
--- Valor en env DESPUÉS de actualizar ConfigMap ---
info
```

Mientras que el volumen muestra el valor actualizado:
```
✅ Volumen actualizado después de ~30 segundos: APP_LOG_LEVEL=debug
```

### Verificación

```bash
# Confirmar la diferencia entre ambos métodos
echo "Volumen: $(kubectl exec pod-volume-mount -- cat /etc/app-config/APP_LOG_LEVEL)"
echo "Env var: $(kubectl exec pod-env-individual -- printenv APP_LOG_LEVEL)"
```

**Salida esperada:**
```
Volumen: debug
Env var: info
```

> **Conclusión clave:** Los volúmenes montados desde ConfigMaps se sincronizan automáticamente. Las variables de entorno requieren reiniciar el Pod para reflejar cambios.

---

## Paso 6: Restaurar ConfigMap y crear Deployment combinado

### Objetivo

Restaurar el ConfigMap a su estado original y crear un Deployment `configmap-webapp` con 2 réplicas que consume el ConfigMap por ambos métodos simultáneamente (variables de entorno y volumen montado).

### Instrucciones

1. Restaura el valor de `APP_LOG_LEVEL` a `info`:

```bash
kubectl patch configmap app-config -p '{"data":{"APP_LOG_LEVEL":"info"}}'
```

2. Crea el manifiesto del Deployment:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/deployment-configmap-webapp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: configmap-webapp
  namespace: config-lab
  labels:
    app: webapp
    component: configmap-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
      component: configmap-demo
  template:
    metadata:
      labels:
        app: webapp
        component: configmap-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.25.3
        ports:
        - containerPort: 80
        # Método 1: Variables de entorno individuales
        env:
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_ENV
        - name: APP_PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_PORT
        - name: APP_LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_LOG_LEVEL
        - name: APP_VERSION
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_VERSION
        # Método 2: Volumen montado con archivo de configuración
        volumeMounts:
        - name: config-volume
          mountPath: /etc/app-config
          readOnly: true
      volumes:
      - name: config-volume
        configMap:
          name: app-config
          items:
          - key: app.properties
            path: app.properties
EOF
```

> **Nota:** En este Deployment usamos `items` en la definición del volumen para montar únicamente el archivo `app.properties`, evitando que las claves simples (APP_ENV, APP_PORT, etc.) también se creen como archivos en el directorio montado.

3. Aplica el Deployment:

```bash
kubectl apply -f ~/ckad-labs/lab06/deployment-configmap-webapp.yaml
```

4. Espera a que las réplicas estén disponibles:

```bash
kubectl rollout status deployment/configmap-webapp --timeout=90s
```

5. Verifica el estado de los Pods del Deployment:

```bash
kubectl get pods -l component=configmap-demo
```

### Salida Esperada

```
NAME                               READY   STATUS    RESTARTS   AGE
configmap-webapp-xxxxxxxxx-xxxxx   1/1     Running   0          30s
configmap-webapp-xxxxxxxxx-xxxxx   1/1     Running   0          30s
```

### Verificación

```bash
# Obtener nombre del primer Pod del Deployment
POD_NAME=$(kubectl get pods -l component=configmap-demo -o jsonpath='{.items[0].metadata.name}')

# Verificar variables de entorno
echo "=== Variables de entorno ==="
kubectl exec $POD_NAME -- env | grep "^APP_" | sort

# Verificar volumen montado
echo ""
echo "=== Archivo montado ==="
kubectl exec $POD_NAME -- cat /etc/app-config/app.properties

# Verificar que SOLO app.properties está en el directorio (gracias a items)
echo ""
echo "=== Contenido del directorio /etc/app-config/ ==="
kubectl exec $POD_NAME -- ls /etc/app-config/
```

**Salida esperada de variables:**
```
=== Variables de entorno ===
APP_ENV=production
APP_LOG_LEVEL=info
APP_PORT=8080
APP_VERSION=1.0.0
```

**Salida esperada del directorio:**
```
=== Contenido del directorio /etc/app-config/ ===
app.properties
```

---

## Paso 7: Método imperativo alternativo (referencia)

### Objetivo

Demostrar la creación imperativa de ConfigMaps como método rápido para el examen CKAD, comparando con el enfoque declarativo usado anteriormente.

### Instrucciones

1. Crea un ConfigMap imperativo desde literales:

```bash
kubectl create configmap app-config-imperative \
  --from-literal=APP_ENV=staging \
  --from-literal=APP_PORT=9090 \
  --from-literal=APP_LOG_LEVEL=debug \
  --from-literal=APP_VERSION=2.0.0 \
  -n config-lab
```

2. Crea un ConfigMap imperativo desde archivo:

```bash
kubectl create configmap app-config-from-file \
  --from-file=~/ckad-labs/lab06/app.properties \
  -n config-lab
```

3. Compara ambos ConfigMaps:

```bash
echo "=== ConfigMap desde literales ==="
kubectl get configmap app-config-imperative -o yaml | grep -A 20 "^data:"

echo ""
echo "=== ConfigMap desde archivo ==="
kubectl get configmap app-config-from-file -o yaml | grep -A 15 "^data:"
```

### Salida Esperada

```
=== ConfigMap desde literales ===
data:
  APP_ENV: staging
  APP_LOG_LEVEL: debug
  APP_PORT: "9090"
  APP_VERSION: 2.0.0

=== ConfigMap desde archivo ===
data:
  app.properties: |
    # Application Configuration File
    app.name=webapp
    ...
```

### Verificación

```bash
# Listar todos los ConfigMaps en el namespace
kubectl get configmaps -n config-lab
```

**Salida esperada (3 ConfigMaps creados + kube-root-ca.crt):**
```
NAME                    DATA   AGE
app-config              5      ...
app-config-from-file    1      ...
app-config-imperative   4      ...
kube-root-ca.crt        1      ...
```

---

## Validación y Pruebas Finales

Ejecuta el siguiente bloque de validación para confirmar que todos los objetivos del laboratorio se han cumplido:

```bash
echo "╔══════════════════════════════════════════════════════╗"
echo "║   VALIDACIÓN FINAL - Lab 04-00-01 ConfigMaps        ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Test 1: ConfigMap principal existe con 5 claves
echo -n "1. ConfigMap 'app-config' con 5 claves: "
COUNT=$(kubectl get configmap app-config -o json | jq '.data | length')
[ "$COUNT" -eq 5 ] && echo "✅ PASS ($COUNT claves)" || echo "❌ FAIL ($COUNT claves)"

# Test 2: Pod con env individual tiene variables correctas
echo -n "2. Pod 'pod-env-individual' con APP_ENV=production: "
VAL=$(kubectl exec pod-env-individual -- printenv APP_ENV 2>/dev/null)
[ "$VAL" = "production" ] && echo "✅ PASS" || echo "❌ FAIL (valor: $VAL)"

# Test 3: Pod con envFrom tiene todas las variables
echo -n "3. Pod 'pod-env-from' con envFrom funcional: "
VAL=$(kubectl exec pod-env-from -- printenv APP_VERSION 2>/dev/null)
[ "$VAL" = "1.0.0" ] && echo "✅ PASS" || echo "❌ FAIL (valor: $VAL)"

# Test 4: Pod con volumen tiene archivo montado
echo -n "4. Pod 'pod-volume-mount' con /etc/app-config/app.properties: "
kubectl exec pod-volume-mount -- test -f /etc/app-config/app.properties 2>/dev/null
[ $? -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL"

# Test 5: Deployment con 2 réplicas Running
echo -n "5. Deployment 'configmap-webapp' con 2/2 réplicas: "
READY=$(kubectl get deployment configmap-webapp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "$READY" = "2" ] && echo "✅ PASS" || echo "❌ FAIL (ready: $READY)"

# Test 6: Deployment usa ambos métodos (env + volume)
echo -n "6. Deployment combina env + volumeMount: "
POD=$(kubectl get pods -l component=configmap-demo -o jsonpath='{.items[0].metadata.name}')
HAS_ENV=$(kubectl exec $POD -- printenv APP_ENV 2>/dev/null)
HAS_FILE=$(kubectl exec $POD -- cat /etc/app-config/app.properties 2>/dev/null | head -1)
[ -n "$HAS_ENV" ] && [ -n "$HAS_FILE" ] && echo "✅ PASS" || echo "❌ FAIL"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Todos los tests deben mostrar ✅ PASS para completar"
echo "════════════════════════════════════════════════════════"
```

---

## Troubleshooting

### Problema 1: Pod en estado CreateContainerConfigError

**Síntomas:**
```
NAME                 READY   STATUS                       RESTARTS   AGE
pod-env-individual   0/1     CreateContainerConfigError   0          15s
```

**Causa:** El ConfigMap referenciado no existe en el namespace actual, o el nombre de la clave en `configMapKeyRef.key` tiene un error tipográfico. Kubernetes no puede iniciar el contenedor si una referencia a ConfigMap es obligatoria y no se encuentra.

**Solución:**
```bash
# Verificar que el ConfigMap existe en el namespace correcto
kubectl get configmap app-config -n config-lab

# Si no existe, verificar el namespace actual
kubectl config view --minify | grep namespace

# Revisar eventos del Pod para el mensaje exacto
kubectl describe pod pod-env-individual | grep -A 5 "Events:"

# Verificar las claves disponibles en el ConfigMap
kubectl get configmap app-config -o jsonpath='{.data}' | jq 'keys'
```

### Problema 2: Volumen montado no muestra actualizaciones después de 2 minutos

**Síntomas:** Después de ejecutar `kubectl patch` para actualizar el ConfigMap, el archivo en `/etc/app-config/` sigue mostrando el valor anterior incluso después de esperar más de 2 minutos.

**Causa:** El kubelet sincroniza los ConfigMaps montados como volúmenes según su periodo de sincronización configurado (`--sync-frequency`, por defecto 60s) más el TTL del caché de ConfigMaps. En algunos entornos locales (kind/minikube), la latencia puede ser mayor. Además, si el volumen se montó con `subPath`, la actualización automática **no funciona**.

**Solución:**
```bash
# Verificar que NO se está usando subPath (subPath impide actualización automática)
kubectl get pod pod-volume-mount -o yaml | grep -A 3 volumeMounts

# Verificar que el ConfigMap realmente se actualizó
kubectl get configmap app-config -o jsonpath='{.data.APP_LOG_LEVEL}'

# Si el volumen no se actualiza después de 3 minutos, forzar recreación del Pod
kubectl delete pod pod-volume-mount
kubectl apply -f ~/ckad-labs/lab06/pod-volume-mount.yaml
kubectl wait --for=condition=Ready pod/pod-volume-mount --timeout=60s

# Verificar nuevo valor
kubectl exec pod-volume-mount -- cat /etc/app-config/APP_LOG_LEVEL
```

---

## Limpieza

> **⚠️ IMPORTANTE:** NO ejecutes la limpieza si vas a continuar con la Práctica 15 (Secrets). El Deployment `configmap-webapp` y el ConfigMap `app-config` se reutilizan en el siguiente laboratorio.

Si necesitas limpiar el entorno (solo al finalizar todo el módulo):

```bash
# Eliminar todos los recursos del namespace
kubectl delete namespace config-lab

# Restaurar namespace por defecto
kubectl config set-context --current --namespace=ckad-dev

# Eliminar archivos locales (opcional)
rm -rf ~/ckad-labs/lab06/
```

Para limpieza parcial (mantener Deployment para Práctica 15):

```bash
# Eliminar solo los Pods de prueba individuales
kubectl delete pod pod-env-individual pod-env-from pod-volume-mount -n config-lab

# Eliminar ConfigMaps auxiliares (no el principal)
kubectl delete configmap app-config-imperative app-config-from-file -n config-lab
```

---

## Resumen

En esta práctica has aplicado el principio de configuración externa en Kubernetes mediante ConfigMaps:

| Concepto | Lo que aprendiste |
|----------|-------------------|
| **Creación declarativa** | Manifiestos YAML con datos clave-valor y archivos multi-línea |
| **Creación imperativa** | `kubectl create configmap` con `--from-literal` y `--from-file` |
| **env + valueFrom** | Inyección selectiva de claves como variables de entorno |
| **envFrom** | Inyección masiva de todas las claves del ConfigMap |
| **Volumen montado** | Exposición de claves como archivos en el sistema de archivos del contenedor |
| **Actualización en caliente** | Volúmenes se sincronizan automáticamente; variables de entorno no |
| **items en volumen** | Control granular de qué claves se montan como archivos |

### Puntos Clave para el Examen CKAD

- `kubectl create configmap` es el método más rápido durante el examen
- Las variables de entorno **NO** se actualizan sin reiniciar el Pod
- Los volúmenes con `subPath` **NO** reciben actualizaciones automáticas
- `envFrom` inyecta TODAS las claves, incluyendo las que contienen archivos multi-línea

### Recursos Adicionales

- [Documentación oficial: ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Configurar Pods con ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [The Twelve-Factor App — Factor III](https://12factor.net/es/config)

---

---

# Manejo de información sensible con Secrets

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar (Apply) |
| **Namespace** | `config-lab` |
| **Directorio de trabajo** | `~/ckad-labs/lab04/` |

## Descripción General

Este laboratorio extiende el Deployment `configmap-webapp` creado en la Práctica 14, incorporando Secrets de Kubernetes para gestionar información sensible como credenciales de base de datos y certificados TLS. El estudiante aprenderá a crear Secrets de distintos tipos, consumirlos como variables de entorno y volúmenes, y comprender las limitaciones de seguridad del almacenamiento en base64 frente a soluciones de cifrado real.

## Objetivos de Aprendizaje

- [ ] Crear Secrets de tipo Opaque mediante comandos imperativos y manifiestos declarativos con valores en base64
- [ ] Crear Secrets de tipo `kubernetes.io/tls` usando certificados auto-firmados generados con openssl
- [ ] Consumir Secrets como variables de entorno (`secretKeyRef`) y como volúmenes montados en Pods
- [ ] Demostrar la facilidad de decodificación base64 y argumentar la necesidad de cifrado real en producción
- [ ] Asociar una ServiceAccount al Deployment como introducción a RBAC básico

## Prerrequisitos

### Conocimientos Previos

| Requisito | Descripción |
|-----------|-------------|
| Práctica 14 completada | Namespace `config-lab` activo con Deployment `configmap-webapp` funcionando |
| Encoding base64 | Uso del comando `base64` y `base64 -d` en Linux |
| Certificados TLS | Conceptos básicos de clave privada, certificado y openssl |
| Volúmenes en Kubernetes | Montaje de volúmenes y volumeMounts (cubierto en Práctica 14) |

### Acceso Requerido

- Clúster Kubernetes activo (kind o minikube)
- `kubectl` configurado con acceso de administrador al clúster
- `openssl` disponible en el sistema (versión 3.0+)
- Namespace `config-lab` existente con el Deployment `configmap-webapp`

## Entorno del Laboratorio

### Verificación del Estado Inicial

```bash
# Verificar que el namespace config-lab existe
kubectl get namespace config-lab

# Verificar que el Deployment de la Práctica 14 está activo
kubectl get deployment configmap-webapp -n config-lab

# Verificar que los ConfigMaps de la Práctica 14 existen
kubectl get configmaps -n config-lab
```

**Salida esperada:**
```
NAME               STATUS   AGE
config-lab         Active   ...

NAME               READY   UP-TO-DATE   AVAILABLE   AGE
configmap-webapp   1/1     1            1           ...
```

### Software Utilizado

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| kubectl | 1.30.2 | Gestión del clúster |
| openssl | 3.0.2+ | Generación de certificados TLS |
| base64 | coreutils | Codificación/decodificación de datos |
| nginx | 1.25.3 | Imagen del contenedor webapp |

---

## Paso 1: Crear un Secret de Tipo Opaque (Imperativo)

### Objetivo

Crear el Secret `app-secrets` con credenciales de base de datos usando el comando imperativo `kubectl create secret generic`, que codifica automáticamente los valores en base64.

### Instrucciones

1. Navegar al directorio de trabajo:

```bash
cd ~/ckad-labs/lab04/
```

2. Crear el Secret de tipo Opaque con las credenciales de base de datos:

```bash
kubectl create secret generic app-secrets \
  --from-literal=DB_HOST=postgres-service \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=webapp_db \
  --from-literal=DB_USER=webapp_user \
  --from-literal=DB_PASSWORD='S3cur3P@ssw0rd!' \
  -n config-lab
```

3. Verificar que el Secret fue creado correctamente:

```bash
kubectl get secret app-secrets -n config-lab
```

4. Inspeccionar el contenido del Secret (valores codificados en base64):

```bash
kubectl get secret app-secrets -n config-lab -o yaml
```

### Salida Esperada

```
secret/app-secrets created

NAME          TYPE     DATA   AGE
app-secrets   Opaque   5      5s
```

Al inspeccionar con `-o yaml`, se observarán los valores codificados en base64 bajo el campo `data`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: config-lab
type: Opaque
data:
  DB_HOST: cG9zdGdyZXMtc2VydmljZQ==
  DB_NAME: d2ViYXBwX2Ri
  DB_PASSWORD: UzNjdXIzUEBzc3cwcmQh
  DB_PORT: NTQzMg==
  DB_USER: d2ViYXBwX3VzZXI=
```

### Verificación

```bash
# Decodificar un valor para confirmar que es correcto
kubectl get secret app-secrets -n config-lab \
  -o jsonpath='{.data.DB_HOST}' | base64 -d && echo
```

**Resultado esperado:** `postgres-service`

---

## Paso 2: Explorar la Creación Declarativa de Secrets

### Objetivo

Comprender cómo se crean Secrets mediante manifiestos YAML con valores en base64, y demostrar que base64 NO es cifrado sino simple codificación.

### Instrucciones

1. Codificar manualmente los valores para entender el proceso:

```bash
echo -n 'postgres-service' | base64
echo -n '5432' | base64
echo -n 'webapp_db' | base64
echo -n 'webapp_user' | base64
echo -n 'S3cur3P@ssw0rd!' | base64
```

2. Crear el manifiesto declarativo equivalente (solo como referencia, no aplicar porque el Secret ya existe):

```bash
cat > ~/ckad-labs/lab04/app-secrets-declarative.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets-declarative
  namespace: config-lab
  labels:
    app: configmap-webapp
    purpose: database-credentials
type: Opaque
data:
  # IMPORTANTE: Estos valores son base64, NO están cifrados
  # Cualquier persona con acceso al manifiesto puede decodificarlos
  DB_HOST: cG9zdGdyZXMtc2VydmljZQ==
  DB_PORT: NTQzMg==
  DB_NAME: d2ViYXBwX2Ri
  DB_USER: d2ViYXBwX3VzZXI=
  DB_PASSWORD: UzNjdXIzUEBzc3cwcmQh
EOF
```

3. Alternativa con `stringData` (valores en texto plano que Kubernetes codifica automáticamente):

```bash
cat > ~/ckad-labs/lab04/app-secrets-stringdata.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets-stringdata
  namespace: config-lab
  labels:
    app: configmap-webapp
type: Opaque
stringData:
  # stringData acepta texto plano; Kubernetes lo codifica a base64 al almacenarlo
  DB_HOST: postgres-service
  DB_PORT: "5432"
  DB_NAME: webapp_db
  DB_USER: webapp_user
  DB_PASSWORD: "S3cur3P@ssw0rd!"
EOF
```

4. Demostrar la decodificación trivial (ejercicio de auditoría):

```bash
echo "=== AUDITORÍA DE SEGURIDAD: Decodificación de Secrets ==="
echo ""
echo "DB_HOST:"
kubectl get secret app-secrets -n config-lab -o jsonpath='{.data.DB_HOST}' | base64 -d && echo
echo ""
echo "DB_USER:"
kubectl get secret app-secrets -n config-lab -o jsonpath='{.data.DB_USER}' | base64 -d && echo
echo ""
echo "DB_PASSWORD:"
kubectl get secret app-secrets -n config-lab -o jsonpath='{.data.DB_PASSWORD}' | base64 -d && echo
echo ""
echo "⚠️  CONCLUSIÓN: base64 NO es cifrado. Cualquier usuario con permisos"
echo "   'get' sobre Secrets puede leer las credenciales en texto plano."
echo "   En producción, usar: Sealed Secrets, HashiCorp Vault, o encryption at rest."
```

### Salida Esperada

```
=== AUDITORÍA DE SEGURIDAD: Decodificación de Secrets ===

DB_HOST:
postgres-service

DB_USER:
webapp_user

DB_PASSWORD:
S3cur3P@ssw0rd!

⚠️  CONCLUSIÓN: base64 NO es cifrado. Cualquier usuario con permisos
   'get' sobre Secrets puede leer las credenciales en texto plano.
   En producción, usar: Sealed Secrets, HashiCorp Vault, o encryption at rest.
```

### Verificación

```bash
# Confirmar que la codificación base64 es reversible trivialmente
echo "UzNjdXIzUEBzc3cwcmQh" | base64 -d
```

**Resultado esperado:** `S3cur3P@ssw0rd!`

---

## Paso 3: Generar Certificados TLS y Crear Secret de Tipo kubernetes.io/tls

### Objetivo

Generar un certificado TLS auto-firmado con openssl y almacenarlo como un Secret de tipo `kubernetes.io/tls`, que Kubernetes valida estructuralmente.

### Instrucciones

1. Crear un directorio para los certificados:

```bash
mkdir -p ~/ckad-labs/lab04/tls
cd ~/ckad-labs/lab04/tls
```

2. Generar la clave privada RSA:

```bash
openssl genrsa -out tls.key 2048
```

3. Generar el certificado auto-firmado (válido por 365 días):

```bash
openssl req -new -x509 \
  -key tls.key \
  -out tls.crt \
  -days 365 \
  -subj "/CN=configmap-webapp.config-lab.svc.cluster.local/O=CKAD-Labs"
```

4. Verificar que los archivos se generaron correctamente:

```bash
ls -la ~/ckad-labs/lab04/tls/
openssl x509 -in tls.crt -text -noout | head -15
```

5. Crear el Secret de tipo TLS:

```bash
kubectl create secret tls app-tls-secret \
  --cert=tls.crt \
  --key=tls.key \
  -n config-lab
```

6. Verificar el Secret TLS creado:

```bash
kubectl get secret app-tls-secret -n config-lab
kubectl describe secret app-tls-secret -n config-lab
```

### Salida Esperada

```
secret/app-tls-secret created

NAME             TYPE                DATA   AGE
app-tls-secret   kubernetes.io/tls   2      3s
```

La descripción mostrará:

```
Name:         app-tls-secret
Namespace:    config-lab
Type:         kubernetes.io/tls

Data
====
tls.crt:  1127 bytes
tls.key:  1704 bytes
```

### Verificación

```bash
# Confirmar que el tipo es correcto y contiene las claves esperadas
kubectl get secret app-tls-secret -n config-lab -o jsonpath='{.type}'
echo ""
kubectl get secret app-tls-secret -n config-lab -o jsonpath='{.data}' | jq 'keys'
```

**Resultado esperado:**
```
kubernetes.io/tls
["tls.crt","tls.key"]
```

---

## Paso 4: Crear un Secret de Tipo basic-auth

### Objetivo

Crear un Secret de tipo `kubernetes.io/basic-auth` para demostrar los distintos tipos de Secrets que Kubernetes soporta nativamente.

### Instrucciones

1. Crear el Secret de tipo basic-auth:

```bash
cat > ~/ckad-labs/lab04/basic-auth-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: app-basic-auth
  namespace: config-lab
  labels:
    app: configmap-webapp
type: kubernetes.io/basic-auth
stringData:
  username: admin
  password: "Admin@2024!"
EOF
```

2. Aplicar el manifiesto:

```bash
kubectl apply -f ~/ckad-labs/lab04/basic-auth-secret.yaml
```

3. Verificar la creación:

```bash
kubectl get secret app-basic-auth -n config-lab
```

### Salida Esperada

```
secret/app-basic-auth created

NAME             TYPE                          DATA   AGE
app-basic-auth   kubernetes.io/basic-auth      2      2s
```

### Verificación

```bash
# Listar todos los Secrets en el namespace
kubectl get secrets -n config-lab
```

**Resultado esperado (debe mostrar al menos 3 Secrets):**
```
NAME             TYPE                          DATA   AGE
app-basic-auth   kubernetes.io/basic-auth      2      ...
app-secrets      Opaque                        5      ...
app-tls-secret   kubernetes.io/tls             2      ...
```

---

## Paso 5: Crear la ServiceAccount para el Deployment

### Objetivo

Crear una ServiceAccount dedicada `webapp-sa` que se asociará al Deployment, introduciendo el concepto de identidad de Pod y RBAC básico.

### Instrucciones

1. Crear el manifiesto de la ServiceAccount:

```bash
cat > ~/ckad-labs/lab04/webapp-serviceaccount.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webapp-sa
  namespace: config-lab
  labels:
    app: configmap-webapp
    purpose: rbac-identity
automountServiceAccountToken: false
EOF
```

2. Aplicar la ServiceAccount:

```bash
kubectl apply -f ~/ckad-labs/lab04/webapp-serviceaccount.yaml
```

3. Verificar la creación:

```bash
kubectl get serviceaccount webapp-sa -n config-lab
```

### Salida Esperada

```
serviceaccount/webapp-sa created

NAME        SECRETS   AGE
webapp-sa   0         3s
```

### Verificación

```bash
kubectl describe serviceaccount webapp-sa -n config-lab
```

---

## Paso 6: Actualizar el Deployment para Consumir Secrets

### Objetivo

Modificar el Deployment `configmap-webapp` para que consuma el Secret `app-secrets` como variables de entorno mediante `secretKeyRef`, monte el Secret `app-tls-secret` como volumen en `/etc/tls/`, y use la ServiceAccount `webapp-sa`.

### Instrucciones

1. Crear el manifiesto actualizado del Deployment:

```bash
cat > ~/ckad-labs/lab04/configmap-webapp-with-secrets.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: configmap-webapp
  namespace: config-lab
  labels:
    app: configmap-webapp
    version: v2-secrets
spec:
  replicas: 1
  selector:
    matchLabels:
      app: configmap-webapp
  template:
    metadata:
      labels:
        app: configmap-webapp
        version: v2-secrets
    spec:
      serviceAccountName: webapp-sa
      containers:
      - name: nginx
        image: nginx:1.25.3
        ports:
        - containerPort: 80
          name: http
        env:
        # Variables desde ConfigMap (Práctica 14)
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_ENV
              optional: true
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: LOG_LEVEL
              optional: true
        # Variables sensibles desde Secret
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: DB_HOST
        - name: DB_PORT
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: DB_PORT
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: DB_NAME
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: DB_USER
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: DB_PASSWORD
        volumeMounts:
        - name: tls-certs
          mountPath: /etc/tls
          readOnly: true
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
          readOnly: true
      volumes:
      - name: tls-certs
        secret:
          secretName: app-tls-secret
          defaultMode: 0400
      - name: nginx-config
        configMap:
          name: app-config
          optional: true
EOF
```

> **Nota:** El campo `optional: true` en las referencias a ConfigMap permite que el Deployment funcione incluso si el ConfigMap `app-config` de la Práctica 14 tiene claves diferentes. Los `secretKeyRef` no llevan `optional` porque las credenciales son obligatorias.

2. Aplicar el Deployment actualizado:

```bash
kubectl apply -f ~/ckad-labs/lab04/configmap-webapp-with-secrets.yaml
```

3. Esperar a que el nuevo Pod esté listo:

```bash
kubectl rollout status deployment/configmap-webapp -n config-lab --timeout=60s
```

4. Verificar que el Pod está corriendo:

```bash
kubectl get pods -n config-lab -l app=configmap-webapp
```

### Salida Esperada

```
deployment.apps/configmap-webapp configured
deployment "configmap-webapp" successfully rolled out

NAME                                READY   STATUS    RESTARTS   AGE
configmap-webapp-xxxxxxxxxx-xxxxx   1/1     Running   0          15s
```

### Verificación

```bash
# Obtener el nombre del Pod
POD_NAME=$(kubectl get pods -n config-lab -l app=configmap-webapp -o jsonpath='{.items[0].metadata.name}')
echo "Pod activo: $POD_NAME"

# Verificar que la ServiceAccount está asignada
kubectl get pod $POD_NAME -n config-lab -o jsonpath='{.spec.serviceAccountName}' && echo
```

**Resultado esperado:** `webapp-sa`

---

## Paso 7: Verificar el Consumo de Secrets en el Pod

### Objetivo

Confirmar que las variables de entorno sensibles están disponibles dentro del contenedor y que los certificados TLS están montados correctamente, sin exponer valores en logs.

### Instrucciones

1. Verificar las variables de entorno de base de datos (sin imprimir la contraseña completa):

```bash
POD_NAME=$(kubectl get pods -n config-lab -l app=configmap-webapp -o jsonpath='{.items[0].metadata.name}')

echo "=== Variables de Base de Datos ==="
kubectl exec $POD_NAME -n config-lab -- env | grep "^DB_" | sort
```

2. Verificar que los certificados TLS están montados:

```bash
echo "=== Certificados TLS montados ==="
kubectl exec $POD_NAME -n config-lab -- ls -la /etc/tls/
```

3. Verificar el contenido del certificado (solo el subject):

```bash
kubectl exec $POD_NAME -n config-lab -- cat /etc/tls/tls.crt | openssl x509 -subject -noout 2>/dev/null || \
kubectl exec $POD_NAME -n config-lab -- head -1 /etc/tls/tls.crt
```

4. Verificar los permisos restrictivos del volumen TLS:

```bash
kubectl exec $POD_NAME -n config-lab -- stat -c '%a %n' /etc/tls/tls.key /etc/tls/tls.crt
```

5. Demostrar buena práctica: verificar existencia sin imprimir valor:

```bash
echo "=== Buena práctica: verificar sin exponer ==="
kubectl exec $POD_NAME -n config-lab -- sh -c '
  if [ -n "$DB_PASSWORD" ]; then
    echo "DB_PASSWORD: [CONFIGURADA - ${#DB_PASSWORD} caracteres]"
  else
    echo "DB_PASSWORD: [NO CONFIGURADA]"
  fi
'
```

### Salida Esperada

```
=== Variables de Base de Datos ===
DB_HOST=postgres-service
DB_NAME=webapp_db
DB_PASSWORD=S3cur3P@ssw0rd!
DB_PORT=5432
DB_USER=webapp_user

=== Certificados TLS montados ===
total 0
lrwxrwxrwx 1 root root 14 ... tls.crt -> ..data/tls.crt
lrwxrwxrwx 1 root root 14 ... tls.key -> ..data/tls.key

=== Buena práctica: verificar sin exponer ===
DB_PASSWORD: [CONFIGURADA - 16 caracteres]
```

### Verificación

```bash
# Verificación completa del estado del Pod
kubectl describe pod $POD_NAME -n config-lab | grep -A 5 "Environment:"
kubectl describe pod $POD_NAME -n config-lab | grep -A 3 "Mounts:"
```

---

## Paso 8: Ejercicio de Auditoría de Seguridad

### Objetivo

Demostrar las limitaciones de seguridad de los Secrets en Kubernetes y la facilidad con que un usuario con permisos puede acceder a los datos sensibles.

### Instrucciones

1. Extraer todos los valores del Secret usando jsonpath:

```bash
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     EJERCICIO DE AUDITORÍA: Vulnerabilidades de Secrets     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Extracción directa con jsonpath + base64 -d:"
echo "   ─────────────────────────────────────────────"

for key in DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD; do
  value=$(kubectl get secret app-secrets -n config-lab -o jsonpath="{.data.$key}" | base64 -d)
  echo "   $key = $value"
done
```

2. Extraer el Secret completo en formato JSON:

```bash
echo ""
echo "2. Exportación completa del Secret (simulando exfiltración):"
echo "   ──────────────────────────────────────────────────────────"
kubectl get secret app-secrets -n config-lab -o json | jq '{
  name: .metadata.name,
  type: .type,
  data_decoded: (.data | to_entries | map({key: .key, value: (.value | @base64d)}) | from_entries)
}'
```

3. Documentar las implicaciones:

```bash
echo ""
echo "3. Implicaciones de seguridad:"
echo "   ────────────────────────────"
echo "   ⚠️  Cualquier usuario con 'kubectl get secret' puede leer credenciales"
echo "   ⚠️  Los Secrets se almacenan en etcd codificados en base64 (NO cifrados)"
echo "   ⚠️  Los manifiestos YAML con Secrets NO deben almacenarse en Git"
echo ""
echo "   ✅ Mitigaciones recomendadas:"
echo "   • Habilitar encryption at rest en etcd"
echo "   • Usar Sealed Secrets (Bitnami) para GitOps"
echo "   • Integrar HashiCorp Vault o AWS Secrets Manager"
echo "   • Aplicar RBAC estricto: limitar 'get' en Secrets por namespace"
echo "   • Usar audit logging para detectar accesos a Secrets"
```

### Salida Esperada

```
╔══════════════════════════════════════════════════════════════╗
║     EJERCICIO DE AUDITORÍA: Vulnerabilidades de Secrets     ║
╚══════════════════════════════════════════════════════════════╝

1. Extracción directa con jsonpath + base64 -d:
   ─────────────────────────────────────────────
   DB_HOST = postgres-service
   DB_PORT = 5432
   DB_NAME = webapp_db
   DB_USER = webapp_user
   DB_PASSWORD = S3cur3P@ssw0rd!

2. Exportación completa del Secret (simulando exfiltración):
   ──────────────────────────────────────────────────────────
{
  "name": "app-secrets",
  "type": "Opaque",
  "data_decoded": {
    "DB_HOST": "postgres-service",
    "DB_NAME": "webapp_db",
    "DB_PASSWORD": "S3cur3P@ssw0rd!",
    "DB_PORT": "5432",
    "DB_USER": "webapp_user"
  }
}
```

### Verificación

Este paso es conceptual. La verificación consiste en que el estudiante comprenda que:
- El acceso a Secrets requiere únicamente permisos RBAC de `get` sobre el recurso `secrets`
- No existe cifrado real sin configuración adicional del clúster

---

## Validación y Pruebas

### Validación Integral del Laboratorio

Ejecutar el siguiente script para verificar que todos los componentes están correctamente configurados:

```bash
#!/bin/bash
echo "╔══════════════════════════════════════════════════════╗"
echo "║   VALIDACIÓN INTEGRAL - Lab 04-00-02 (Secrets)     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

# Test 1: Secret app-secrets existe y es tipo Opaque
echo -n "✓ Test 1: Secret 'app-secrets' (Opaque)... "
TYPE=$(kubectl get secret app-secrets -n config-lab -o jsonpath='{.type}' 2>/dev/null)
if [ "$TYPE" = "Opaque" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (type=$TYPE)"
  ((FAIL++))
fi

# Test 2: Secret app-secrets tiene 5 claves
echo -n "✓ Test 2: app-secrets tiene 5 claves... "
COUNT=$(kubectl get secret app-secrets -n config-lab -o json | jq '.data | length')
if [ "$COUNT" = "5" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (count=$COUNT)"
  ((FAIL++))
fi

# Test 3: Secret app-tls-secret existe y es tipo TLS
echo -n "✓ Test 3: Secret 'app-tls-secret' (TLS)... "
TYPE=$(kubectl get secret app-tls-secret -n config-lab -o jsonpath='{.type}' 2>/dev/null)
if [ "$TYPE" = "kubernetes.io/tls" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (type=$TYPE)"
  ((FAIL++))
fi

# Test 4: Secret app-basic-auth existe
echo -n "✓ Test 4: Secret 'app-basic-auth' (basic-auth)... "
TYPE=$(kubectl get secret app-basic-auth -n config-lab -o jsonpath='{.type}' 2>/dev/null)
if [ "$TYPE" = "kubernetes.io/basic-auth" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (type=$TYPE)"
  ((FAIL++))
fi

# Test 5: ServiceAccount webapp-sa existe
echo -n "✓ Test 5: ServiceAccount 'webapp-sa'... "
if kubectl get serviceaccount webapp-sa -n config-lab &>/dev/null; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL"
  ((FAIL++))
fi

# Test 6: Deployment usa ServiceAccount webapp-sa
echo -n "✓ Test 6: Deployment usa ServiceAccount 'webapp-sa'... "
SA=$(kubectl get deployment configmap-webapp -n config-lab -o jsonpath='{.spec.template.spec.serviceAccountName}')
if [ "$SA" = "webapp-sa" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (sa=$SA)"
  ((FAIL++))
fi

# Test 7: Pod tiene variables DB_* configuradas
echo -n "✓ Test 7: Pod tiene variables DB_HOST y DB_PASSWORD... "
POD=$(kubectl get pods -n config-lab -l app=configmap-webapp -o jsonpath='{.items[0].metadata.name}')
DB_HOST=$(kubectl exec $POD -n config-lab -- printenv DB_HOST 2>/dev/null)
DB_PASS=$(kubectl exec $POD -n config-lab -- printenv DB_PASSWORD 2>/dev/null)
if [ "$DB_HOST" = "postgres-service" ] && [ "$DB_PASS" = 'S3cur3P@ssw0rd!' ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL"
  ((FAIL++))
fi

# Test 8: Certificados TLS montados en /etc/tls/
echo -n "✓ Test 8: TLS montado en /etc/tls/... "
TLS_FILES=$(kubectl exec $POD -n config-lab -- ls /etc/tls/ 2>/dev/null | tr '\n' ' ')
if echo "$TLS_FILES" | grep -q "tls.crt" && echo "$TLS_FILES" | grep -q "tls.key"; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (files=$TLS_FILES)"
  ((FAIL++))
fi

echo ""
echo "════════════════════════════════════════"
echo "  Resultados: $PASS PASS / $FAIL FAIL"
echo "════════════════════════════════════════"

if [ $FAIL -eq 0 ]; then
  echo "  🎉 ¡Todos los tests pasaron!"
else
  echo "  ❌ Hay $FAIL test(s) fallido(s). Revisa los pasos anteriores."
fi
```

Guardar y ejecutar:

```bash
cat > ~/ckad-labs/lab04/validate-lab04-02.sh << 'SCRIPT'
# (pegar el contenido del script anterior)
SCRIPT
chmod +x ~/ckad-labs/lab04/validate-lab04-02.sh
bash ~/ckad-labs/lab04/validate-lab04-02.sh
```

**Resultado esperado:** 8 PASS / 0 FAIL

---

## Solución de Problemas

### Problema 1: El Pod queda en estado CreateContainerConfigError

**Síntomas:**
```
NAME                                READY   STATUS                       RESTARTS   AGE
configmap-webapp-xxxxxxxxxx-xxxxx   0/1     CreateContainerConfigError   0          30s
```

**Causa:**
El Secret referenciado en `secretKeyRef` no existe en el namespace o tiene un nombre de clave incorrecto. A diferencia de `configMapKeyRef` con `optional: true`, las referencias a Secrets sin `optional` son obligatorias y bloquean la creación del contenedor.

**Solución:**

```bash
# Identificar el error exacto
POD_NAME=$(kubectl get pods -n config-lab -l app=configmap-webapp -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD_NAME -n config-lab | grep -A 5 "Warning"

# Verificar que el Secret existe con las claves correctas
kubectl get secret app-secrets -n config-lab -o jsonpath='{.data}' | jq 'keys'

# Si falta el Secret, recrearlo
kubectl create secret generic app-secrets \
  --from-literal=DB_HOST=postgres-service \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=webapp_db \
  --from-literal=DB_USER=webapp_user \
  --from-literal=DB_PASSWORD='S3cur3P@ssw0rd!' \
  -n config-lab --dry-run=client -o yaml | kubectl apply -f -

# Forzar recreación del Pod
kubectl rollout restart deployment/configmap-webapp -n config-lab
```

---

### Problema 2: Error al crear Secret TLS — "tls: failed to find any PEM data"

**Síntomas:**
```
error: tls: failed to find any PEM data in certificate input
```

**Causa:**
El archivo `tls.crt` o `tls.key` no tiene formato PEM válido. Esto ocurre cuando openssl no generó correctamente los archivos, cuando se especificó una ruta incorrecta, o cuando el archivo está vacío.

**Solución:**

```bash
# Verificar que los archivos existen y tienen contenido
ls -la ~/ckad-labs/lab04/tls/
file ~/ckad-labs/lab04/tls/tls.crt
file ~/ckad-labs/lab04/tls/tls.key

# Verificar formato PEM (debe comenzar con -----BEGIN)
head -1 ~/ckad-labs/lab04/tls/tls.crt
head -1 ~/ckad-labs/lab04/tls/tls.key

# Si los archivos están corruptos, regenerar
cd ~/ckad-labs/lab04/tls/
rm -f tls.key tls.crt

openssl genrsa -out tls.key 2048
openssl req -new -x509 \
  -key tls.key \
  -out tls.crt \
  -days 365 \
  -subj "/CN=configmap-webapp.config-lab.svc.cluster.local/O=CKAD-Labs"

# Verificar validez
openssl x509 -in tls.crt -text -noout | head -5

# Eliminar el Secret anterior si existe y recrear
kubectl delete secret app-tls-secret -n config-lab --ignore-not-found
kubectl create secret tls app-tls-secret \
  --cert=tls.crt \
  --key=tls.key \
  -n config-lab
```

---

## Limpieza

> **⚠️ IMPORTANTE:** NO ejecutar la limpieza si vas a continuar con laboratorios posteriores del Módulo 4 que dependan del namespace `config-lab`. Este laboratorio representa el **estado final** del módulo.

Para limpiar **solo los recursos creados en este laboratorio** (preservando los de la Práctica 14):

```bash
# Limpieza selectiva (solo Secrets y ServiceAccount de este lab)
kubectl delete secret app-secrets app-tls-secret app-basic-auth -n config-lab
kubectl delete serviceaccount webapp-sa -n config-lab

# Revertir el Deployment al estado de la Práctica 14 (si se desea)
# kubectl rollout undo deployment/configmap-webapp -n config-lab

# Limpiar archivos locales
rm -rf ~/ckad-labs/lab04/tls/
rm -f ~/ckad-labs/lab04/app-secrets-declarative.yaml
rm -f ~/ckad-labs/lab04/app-secrets-stringdata.yaml
rm -f ~/ckad-labs/lab04/basic-auth-secret.yaml
rm -f ~/ckad-labs/lab04/webapp-serviceaccount.yaml
rm -f ~/ckad-labs/lab04/configmap-webapp-with-secrets.yaml
rm -f ~/ckad-labs/lab04/validate-lab04-02.sh
```

Para limpieza completa del módulo (elimina todo):

```bash
kubectl delete namespace config-lab
rm -rf ~/ckad-labs/lab04/
```

---

## Resumen

### Conceptos Clave Aprendidos

| Concepto | Detalle |
|----------|---------|
| Secret Opaque | Tipo genérico para almacenar pares clave-valor sensibles |
| Secret TLS | Tipo validado que requiere `tls.crt` y `tls.key` en formato PEM |
| Secret basic-auth | Tipo semántico para credenciales usuario/contraseña |
| `secretKeyRef` | Referencia individual a una clave de un Secret como variable de entorno |
| `volumes.secret` | Montaje de un Secret completo como archivos en un directorio |
| `defaultMode: 0400` | Permisos restrictivos para archivos sensibles montados |
| `stringData` | Campo para definir valores en texto plano (Kubernetes codifica a base64) |
| ServiceAccount | Identidad del Pod para RBAC; limita qué recursos puede acceder |
| base64 ≠ cifrado | Los Secrets NO están cifrados por defecto; requieren encryption at rest |

### Comparación ConfigMap vs Secret

| Aspecto | ConfigMap | Secret |
|---------|-----------|--------|
| Tipo de dato | No sensible | Sensible |
| Almacenamiento en etcd | Texto plano | Base64 (no cifrado por defecto) |
| Tamaño máximo | 1 MiB | 1 MiB |
| Referencia en Pod | `configMapKeyRef` | `secretKeyRef` |
| Montaje como volumen | `volumes.configMap` | `volumes.secret` |
| Visible en `kubectl describe pod` | Sí (valores) | No (solo referencia) |

### Estado Final del Namespace

Al completar este laboratorio, el namespace `config-lab` contiene:

```
config-lab/
├── Deployment: configmap-webapp (nginx:1.25.3)
│   ├── ServiceAccount: webapp-sa
│   ├── Env from ConfigMap: app-config (APP_ENV, LOG_LEVEL) [optional]
│   ├── Env from Secret: app-secrets (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD)
│   └── Volume mount: /etc/tls/ ← Secret app-tls-secret
├── ConfigMap: app-config (de Práctica 14)
├── Secret: app-secrets (Opaque, 5 keys)
├── Secret: app-tls-secret (kubernetes.io/tls, 2 keys)
├── Secret: app-basic-auth (kubernetes.io/basic-auth, 2 keys)
└── ServiceAccount: webapp-sa
```

### Recursos Adicionales

- [Documentación oficial: Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Tipos de Secrets en Kubernetes](https://kubernetes.io/docs/concepts/configuration/secret/#secret-types)
- [Cifrado de datos en reposo (encryption at rest)](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- [Sealed Secrets (Bitnami)](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)

---

# ServiceAccount y permisos mínimos

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 50 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar (Apply) |
| **Tecnologías** | Kubernetes ServiceAccount, RBAC (Role, RoleBinding), kubectl auth can-i, bitnami/kubectl:1.30.2 |

## Descripción General

En este laboratorio crearás una ServiceAccount dedicada con permisos mínimos siguiendo el principio de menor privilegio (least privilege). Configurarás un Role que permite únicamente leer ConfigMaps y Secrets dentro de un namespace específico, vincularás la ServiceAccount mediante un RoleBinding, y desplegarás un Pod que demuestre tanto el acceso autorizado como la denegación efectiva de operaciones no permitidas. Este patrón conecta directamente con la configuración externa de aplicaciones: una aplicación que consume ConfigMaps y Secrets solo necesita permisos de lectura sobre esos recursos específicos.

## Objetivos de Aprendizaje

Al completar este laboratorio serás capaz de:

- [ ] Crear ServiceAccounts dedicadas para aplicaciones, evitando el uso de la ServiceAccount `default`
- [ ] Definir Roles con permisos mínimos necesarios usando verbos (`get`, `list`) y recursos específicos (`configmaps`, `secrets`)
- [ ] Vincular ServiceAccounts a Roles mediante RoleBindings y verificar permisos con `kubectl auth can-i`
- [ ] Desplegar un Pod que utilice una ServiceAccount personalizada y confirmar que el token montado corresponde a dicha cuenta
- [ ] Demostrar la restricción efectiva cuando un Pod intenta acceder a recursos no autorizados de la API

## Prerrequisitos

### Conocimiento Previo

| Concepto | Nivel requerido |
|----------|----------------|
| Modelo RBAC de Kubernetes (sujetos, roles, bindings) | Comprensión conceptual |
| ServiceAccounts y su relación con Pods | Conocimiento básico |
| Comandos kubectl básicos (create, apply, get, describe) | Uso práctico |
| Configuración externa con ConfigMaps y Secrets | Lección 4.1 completada |

### Acceso Requerido

- Clúster minikube 1.33.1 iniciado y funcional
- kubectl 1.30.2 configurado y apuntando al clúster local
- Conexión a internet para descargar la imagen `bitnami/kubectl:1.30.2`
- Permisos de administrador del clúster (acceso completo vía minikube)

## Entorno de Laboratorio

### Software Necesario

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| minikube | 1.33.1 | Clúster Kubernetes local |
| kubectl | 1.30.2 | CLI de administración del clúster |
| bitnami/kubectl | 1.30.2 | Imagen para pruebas internas desde Pod |

### Preparación Inicial del Entorno

```bash
# Verificar que minikube está corriendo
minikube status

# Verificar versión de kubectl
kubectl version --client --short 2>/dev/null || kubectl version --client

# Crear directorio de trabajo para este laboratorio
mkdir -p ~/ckad-labs/lab04-rbac
cd ~/ckad-labs/lab04-rbac
```

## Procedimiento Paso a Paso

### Paso 1: Crear el Namespace de Trabajo

**Objetivo:** Establecer un namespace aislado `lab-rbac` donde se crearán todos los recursos RBAC del laboratorio.

**Instrucciones:**

1. Crea el namespace `lab-rbac`:

```bash
kubectl create namespace lab-rbac
```

2. Configura el contexto actual para usar este namespace por defecto:

```bash
kubectl config set-context --current --namespace=lab-rbac
```

3. Verifica que el namespace está activo:

```bash
kubectl config view --minify | grep namespace
```

**Salida esperada:**

```
namespace: lab-rbac
```

**Verificación:**

```bash
kubectl get namespace lab-rbac -o jsonpath='{.status.phase}'
```

Debe mostrar: `Active`

---

### Paso 2: Crear Recursos de Configuración para las Pruebas

**Objetivo:** Crear un ConfigMap y un Secret que servirán como recursos objetivo para verificar los permisos de lectura de la ServiceAccount.

**Instrucciones:**

1. Crea un archivo de manifiesto para el ConfigMap:

```bash
cat <<'EOF' > configmap-app.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: lab-rbac
  labels:
    app: demo-rbac
data:
  log_level: "info"
  app_mode: "production"
  max_retries: "3"
EOF
```

2. Crea un archivo de manifiesto para el Secret:

```bash
cat <<'EOF' > secret-app.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: lab-rbac
  labels:
    app: demo-rbac
type: Opaque
data:
  database_url: cG9zdGdyZXM6Ly91c2VyOnBhc3NAZGItaG9zdDo1NDMyL215ZGI=
  api_key: c2VjcmV0LWFwaS1rZXktMTIzNDU=
EOF
```

3. Aplica ambos manifiestos:

```bash
kubectl apply -f configmap-app.yaml
kubectl apply -f secret-app.yaml
```

**Salida esperada:**

```
configmap/app-config created
secret/app-secret created
```

**Verificación:**

```bash
kubectl get configmap app-config -o jsonpath='{.data.log_level}'
echo
kubectl get secret app-secret -o jsonpath='{.data.api_key}' | base64 -d
echo
```

Debe mostrar `info` y `secret-api-key-12345` respectivamente.

---

### Paso 3: Crear la ServiceAccount Dedicada

**Objetivo:** Crear una ServiceAccount `app-reader-sa` que proporcionará identidad específica a los Pods de la aplicación, separándolos de la ServiceAccount `default`.

**Instrucciones:**

1. Crea el manifiesto de la ServiceAccount:

```bash
cat <<'EOF' > serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader-sa
  namespace: lab-rbac
  labels:
    app: demo-rbac
    purpose: config-reader
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f serviceaccount.yaml
```

3. Inspecciona la ServiceAccount creada:

```bash
kubectl get serviceaccount app-reader-sa -o yaml
```

**Salida esperada:**

```
serviceaccount/app-reader-sa created
```

**Verificación:**

```bash
kubectl get serviceaccounts -n lab-rbac
```

Debe listar al menos dos ServiceAccounts: `default` y `app-reader-sa`.

---

### Paso 4: Definir el Role con Permisos Mínimos

**Objetivo:** Crear un Role llamado `configmap-reader` que otorga exclusivamente los verbos `get` y `list` sobre los recursos `configmaps` y `secrets` dentro del namespace `lab-rbac`.

**Instrucciones:**

1. Crea el manifiesto del Role:

```bash
cat <<'EOF' > role-configmap-reader.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: configmap-reader
  namespace: lab-rbac
  labels:
    app: demo-rbac
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f role-configmap-reader.yaml
```

3. Describe el Role para verificar las reglas:

```bash
kubectl describe role configmap-reader -n lab-rbac
```

**Salida esperada:**

```
role.rbac.authorization.k8s.io/configmap-reader created
```

La salida del `describe` debe mostrar:

```
PolicyRule:
  Resources   Non-Resource URLs  Resource Names  Verbs
  ---------   -----------------  --------------  -----
  configmaps  []                 []              [get list]
  secrets     []                 []              [get list]
```

**Verificación:**

```bash
kubectl get role configmap-reader -n lab-rbac -o jsonpath='{.rules[0].verbs}'
```

Debe mostrar: `["get","list"]`

---

### Paso 5: Crear el RoleBinding

**Objetivo:** Vincular la ServiceAccount `app-reader-sa` al Role `configmap-reader` mediante un RoleBinding, activando los permisos definidos.

**Instrucciones:**

1. Crea el manifiesto del RoleBinding:

```bash
cat <<'EOF' > rolebinding-app-reader.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-binding
  namespace: lab-rbac
  labels:
    app: demo-rbac
subjects:
- kind: ServiceAccount
  name: app-reader-sa
  namespace: lab-rbac
roleRef:
  kind: Role
  name: configmap-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f rolebinding-app-reader.yaml
```

3. Describe el RoleBinding para confirmar la vinculación:

```bash
kubectl describe rolebinding app-reader-binding -n lab-rbac
```

**Salida esperada:**

```
rolebinding.rbac.authorization.k8s.io/app-reader-binding created
```

El `describe` debe mostrar:

```
Role:
  Kind:  Role
  Name:  configmap-reader
Subjects:
  Kind            Name           Namespace
  ----            ----           ---------
  ServiceAccount  app-reader-sa  lab-rbac
```

**Verificación:**

```bash
kubectl get rolebinding app-reader-binding -n lab-rbac -o jsonpath='{.subjects[0].name}'
```

Debe mostrar: `app-reader-sa`

---

### Paso 6: Verificar Permisos con kubectl auth can-i

**Objetivo:** Usar `kubectl auth can-i` para validar los permisos otorgados y las restricciones efectivas antes de desplegar un Pod, simulando la identidad de la ServiceAccount.

**Instrucciones:**

1. Verifica que la ServiceAccount PUEDE listar ConfigMaps:

```bash
kubectl auth can-i list configmaps \
  --as=system:serviceaccount:lab-rbac:app-reader-sa \
  -n lab-rbac
```

2. Verifica que la ServiceAccount PUEDE obtener Secrets:

```bash
kubectl auth can-i get secrets \
  --as=system:serviceaccount:lab-rbac:app-reader-sa \
  -n lab-rbac
```

3. Verifica que la ServiceAccount NO PUEDE listar Pods:

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:lab-rbac:app-reader-sa \
  -n lab-rbac
```

4. Verifica que la ServiceAccount NO PUEDE crear ConfigMaps:

```bash
kubectl auth can-i create configmaps \
  --as=system:serviceaccount:lab-rbac:app-reader-sa \
  -n lab-rbac
```

5. Verifica que la ServiceAccount NO PUEDE eliminar Secrets:

```bash
kubectl auth can-i delete secrets \
  --as=system:serviceaccount:lab-rbac:app-reader-sa \
  -n lab-rbac
```

**Salida esperada:**

```
yes
yes
no
no
no
```

**Verificación:**

Los comandos 1 y 2 deben retornar `yes`. Los comandos 3, 4 y 5 deben retornar `no`. Esto confirma que el principio de menor privilegio está correctamente aplicado.

---

### Paso 7: Desplegar un Pod con la ServiceAccount Personalizada

**Objetivo:** Crear un Pod basado en `bitnami/kubectl:1.30.2` que utilice la ServiceAccount `app-reader-sa` y permanezca activo para ejecutar pruebas interactivas.

**Instrucciones:**

1. Crea el manifiesto del Pod:

```bash
cat <<'EOF' > pod-rbac-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: rbac-test-pod
  namespace: lab-rbac
  labels:
    app: demo-rbac
    component: rbac-tester
spec:
  serviceAccountName: app-reader-sa
  containers:
  - name: kubectl-container
    image: bitnami/kubectl:1.30.2
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
  restartPolicy: Never
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f pod-rbac-test.yaml
```

3. Espera a que el Pod esté en estado Running:

```bash
kubectl wait --for=condition=Ready pod/rbac-test-pod -n lab-rbac --timeout=120s
```

**Salida esperada:**

```
pod/rbac-test-pod created
pod/rbac-test-pod condition met
```

**Verificación:**

```bash
kubectl get pod rbac-test-pod -n lab-rbac -o jsonpath='{.spec.serviceAccountName}'
```

Debe mostrar: `app-reader-sa`

---

### Paso 8: Verificar el Token Montado en el Pod

**Objetivo:** Confirmar que el Pod tiene montado el token proyectado (projected service account token) correspondiente a `app-reader-sa` y que la identidad es correcta.

**Instrucciones:**

1. Verifica la ruta del token montado dentro del Pod:

```bash
kubectl exec rbac-test-pod -n lab-rbac -- ls /var/run/secrets/kubernetes.io/serviceaccount/
```

2. Lee el nombre de la ServiceAccount desde el archivo montado:

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/namespace
```

3. Decodifica el token JWT para verificar el sujeto (sin instalar herramientas adicionales):

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  sh -c "cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -d'.' -f2 | base64 -d 2>/dev/null | head -c 500"
echo
```

**Salida esperada:**

El comando 1 debe listar:
```
ca.crt
namespace
token
```

El comando 2 debe mostrar:
```
lab-rbac
```

El comando 3 debe mostrar un JSON que contiene `"sub":"system:serviceaccount:lab-rbac:app-reader-sa"` (entre otros campos).

**Verificación:**

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  sh -c "cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -d'.' -f2 | base64 -d 2>/dev/null" | grep -o '"sub":"[^"]*"'
```

Debe mostrar: `"sub":"system:serviceaccount:lab-rbac:app-reader-sa"`

---

### Paso 9: Probar Acceso Autorizado desde Dentro del Pod

**Objetivo:** Ejecutar comandos kubectl desde dentro del Pod para demostrar que la ServiceAccount puede efectivamente leer ConfigMaps y Secrets según los permisos otorgados.

**Instrucciones:**

1. Lista los ConfigMaps del namespace desde dentro del Pod:

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  kubectl get configmaps -n lab-rbac
```

2. Obtén el contenido específico del ConfigMap `app-config`:

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  kubectl get configmap app-config -n lab-rbac -o jsonpath='{.data}'
```

3. Lista los Secrets del namespace:

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  kubectl get secrets -n lab-rbac
```

4. Obtén un valor específico del Secret:

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  kubectl get secret app-secret -n lab-rbac -o jsonpath='{.data.api_key}'
```

**Salida esperada:**

Comando 1 — lista que incluye `app-config`:
```
NAME               DATA   AGE
app-config         3      Xm
kube-root-ca.crt   1      Xm
```

Comando 2:
```
{"app_mode":"production","log_level":"info","max_retries":"3"}
```

Comando 3 — lista que incluye `app-secret`:
```
NAME         TYPE     DATA   AGE
app-secret   Opaque   2      Xm
```

Comando 4:
```
c2VjcmV0LWFwaS1rZXktMTIzNDU=
```

**Verificación:**

Todos los comandos deben ejecutarse exitosamente sin errores de permisos. El Pod puede leer la configuración externa exactamente como fue diseñado.

---

### Paso 10: Demostrar Denegación de Acceso para Recursos No Autorizados

**Objetivo:** Intentar operaciones no permitidas desde dentro del Pod para demostrar que RBAC restringe efectivamente el acceso, siguiendo el principio de menor privilegio.

**Instrucciones:**

1. Intenta listar Pods (verbo `list` sobre recurso `pods` — no autorizado):

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  kubectl get pods -n lab-rbac
```

2. Intenta crear un ConfigMap (verbo `create` — no autorizado):

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  kubectl create configmap test-cm --from-literal=key=value -n lab-rbac
```

3. Intenta eliminar el Secret existente (verbo `delete` — no autorizado):

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  kubectl delete secret app-secret -n lab-rbac
```

4. Intenta listar Pods en otro namespace (acceso cross-namespace — no autorizado):

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  kubectl get pods -n kube-system
```

**Salida esperada:**

Cada comando debe producir un error de tipo `Forbidden`:

Comando 1:
```
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:lab-rbac:app-reader-sa" cannot list resource "pods" in API group "" in the namespace "lab-rbac"
```

Comando 2:
```
Error from server (Forbidden): configmaps is forbidden: User "system:serviceaccount:lab-rbac:app-reader-sa" cannot create resource "configmaps" in API group "" in the namespace "lab-rbac"
```

Comando 3:
```
Error from server (Forbidden): secrets "app-secret" is forbidden: User "system:serviceaccount:lab-rbac:app-reader-sa" cannot delete resource "secrets" in API group "" in the namespace "lab-rbac"
```

Comando 4:
```
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:lab-rbac:app-reader-sa" cannot list resource "pods" in API group "" in the namespace "kube-system"
```

**Verificación:**

Todos los comandos deben fallar con código de salida distinto de 0. Verifica uno de ellos:

```bash
kubectl exec rbac-test-pod -n lab-rbac -- \
  kubectl get pods -n lab-rbac 2>&1; echo "Exit code: $?"
```

El mensaje debe contener `Forbidden` y el exit code debe ser distinto de 0.

---

### Paso 11: Comparar con la ServiceAccount Default

**Objetivo:** Demostrar la diferencia entre usar una ServiceAccount personalizada con permisos definidos y la ServiceAccount `default` que típicamente no tiene permisos RBAC explícitos.

**Instrucciones:**

1. Despliega un Pod temporal usando la ServiceAccount `default`:

```bash
cat <<'EOF' > pod-default-sa.yaml
apiVersion: v1
kind: Pod
metadata:
  name: default-sa-pod
  namespace: lab-rbac
  labels:
    app: demo-rbac
    component: default-sa-test
spec:
  serviceAccountName: default
  containers:
  - name: kubectl-container
    image: bitnami/kubectl:1.30.2
    command: ["sleep", "300"]
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
  restartPolicy: Never
EOF
kubectl apply -f pod-default-sa.yaml
kubectl wait --for=condition=Ready pod/default-sa-pod -n lab-rbac --timeout=120s
```

2. Intenta listar ConfigMaps con la ServiceAccount `default`:

```bash
kubectl exec default-sa-pod -n lab-rbac -- \
  kubectl get configmaps -n lab-rbac
```

3. Verifica con `kubectl auth can-i` los permisos de la SA default:

```bash
kubectl auth can-i list configmaps \
  --as=system:serviceaccount:lab-rbac:default \
  -n lab-rbac
```

**Salida esperada:**

Comando 2 debe producir un error `Forbidden`:
```
Error from server (Forbidden): configmaps is forbidden: User "system:serviceaccount:lab-rbac:default" cannot list resource "configmaps" in API group "" in the namespace "lab-rbac"
```

Comando 3:
```
no
```

**Verificación:**

Esto demuestra que la ServiceAccount `default` no tiene permisos explícitos, y que nuestra `app-reader-sa` obtiene sus capacidades exclusivamente del Role vinculado mediante el RoleBinding.

---

## Validación y Pruebas

Ejecuta el siguiente bloque de validación completo para confirmar que todos los componentes están correctamente configurados:

```bash
echo "=== VALIDACIÓN COMPLETA DEL LABORATORIO ==="
echo ""

echo "1. Namespace lab-rbac existe:"
kubectl get namespace lab-rbac -o jsonpath='{.status.phase}'
echo ""

echo "2. ServiceAccount app-reader-sa existe:"
kubectl get sa app-reader-sa -n lab-rbac -o name
echo ""

echo "3. Role configmap-reader tiene verbos correctos:"
kubectl get role configmap-reader -n lab-rbac -o jsonpath='{.rules[0].verbs}'
echo ""

echo "4. Role configmap-reader tiene recursos correctos:"
kubectl get role configmap-reader -n lab-rbac -o jsonpath='{.rules[0].resources}'
echo ""

echo "5. RoleBinding app-reader-binding vincula SA correcta:"
kubectl get rolebinding app-reader-binding -n lab-rbac -o jsonpath='{.subjects[0].name}'
echo ""

echo "6. RoleBinding referencia Role correcto:"
kubectl get rolebinding app-reader-binding -n lab-rbac -o jsonpath='{.roleRef.name}'
echo ""

echo "7. Pod rbac-test-pod usa ServiceAccount correcta:"
kubectl get pod rbac-test-pod -n lab-rbac -o jsonpath='{.spec.serviceAccountName}'
echo ""

echo "8. Pod puede leer ConfigMaps (acceso autorizado):"
kubectl auth can-i list configmaps --as=system:serviceaccount:lab-rbac:app-reader-sa -n lab-rbac
echo ""

echo "9. Pod NO puede listar Pods (acceso denegado):"
kubectl auth can-i list pods --as=system:serviceaccount:lab-rbac:app-reader-sa -n lab-rbac
echo ""

echo "10. Pod NO puede crear recursos (solo lectura):"
kubectl auth can-i create configmaps --as=system:serviceaccount:lab-rbac:app-reader-sa -n lab-rbac
echo ""

echo "=== VALIDACIÓN COMPLETADA ==="
```

**Resultados esperados:**

```
=== VALIDACIÓN COMPLETA DEL LABORATORIO ===

1. Namespace lab-rbac existe:
Active
2. ServiceAccount app-reader-sa existe:
serviceaccount/app-reader-sa
3. Role configmap-reader tiene verbos correctos:
["get","list"]
4. Role configmap-reader tiene recursos correctos:
["configmaps","secrets"]
5. RoleBinding app-reader-binding vincula SA correcta:
app-reader-sa
6. RoleBinding referencia Role correcto:
configmap-reader
7. Pod rbac-test-pod usa ServiceAccount correcta:
app-reader-sa
8. Pod puede leer ConfigMaps (acceso autorizado):
yes
9. Pod NO puede listar Pods (acceso denegado):
no
10. Pod NO puede crear recursos (solo lectura):
no

=== VALIDACIÓN COMPLETADA ===
```

---

## Resolución de Problemas

### Problema 1: El Pod no puede comunicarse con la API de Kubernetes

**Síntomas:**

Al ejecutar `kubectl exec rbac-test-pod -- kubectl get configmaps`, se obtiene un error de conexión:

```
Unable to connect to the server: dial tcp: lookup kubernetes.default.svc on 10.96.0.10:53: no such host
```

O bien:

```
Error from server: error dialing backend: dial tcp 192.168.49.2:8443: connect: connection refused
```

**Causa:**

El Pod no puede resolver el servicio `kubernetes.default.svc` o la red del clúster no permite la comunicación con el API server. Esto puede ocurrir si el CoreDNS no está funcionando correctamente o si hay una NetworkPolicy restrictiva en el namespace.

**Solución:**

```bash
# Verificar que CoreDNS está funcionando
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Verificar que el servicio kubernetes existe
kubectl get svc kubernetes -n default

# Probar resolución DNS desde el Pod
kubectl exec rbac-test-pod -n lab-rbac -- \
  sh -c "cat /etc/resolv.conf"

# Si CoreDNS no funciona, reiniciar minikube
minikube stop && minikube start

# Verificar que no hay NetworkPolicies bloqueando tráfico
kubectl get networkpolicies -n lab-rbac
```

---

### Problema 2: El RoleBinding no otorga permisos — `kubectl auth can-i` retorna `no` para operaciones que deberían estar permitidas

**Síntomas:**

Después de crear el Role y el RoleBinding, la verificación muestra que la ServiceAccount no tiene permisos:

```bash
kubectl auth can-i list configmaps --as=system:serviceaccount:lab-rbac:app-reader-sa -n lab-rbac
# Retorna: no
```

**Causa:**

El error más común es una discrepancia en el campo `namespace` del sujeto en el RoleBinding, o un error tipográfico en el nombre de la ServiceAccount o del Role. El RoleBinding debe referenciar exactamente el nombre de la SA y el namespace donde reside.

**Solución:**

```bash
# Verificar que el nombre de la SA en el RoleBinding coincide exactamente
kubectl get rolebinding app-reader-binding -n lab-rbac -o yaml | grep -A5 "subjects:"

# Verificar que el roleRef apunta al Role correcto
kubectl get rolebinding app-reader-binding -n lab-rbac -o yaml | grep -A4 "roleRef:"

# Verificar que la SA existe en el namespace correcto
kubectl get sa app-reader-sa -n lab-rbac

# Si hay discrepancias, eliminar y recrear el RoleBinding
kubectl delete rolebinding app-reader-binding -n lab-rbac
kubectl apply -f rolebinding-app-reader.yaml

# Verificar que el namespace en subjects coincide con el namespace de la SA
# El campo subjects[].namespace DEBE ser "lab-rbac"
kubectl get rolebinding app-reader-binding -n lab-rbac \
  -o jsonpath='{.subjects[0].namespace}'
```

Asegúrate de que el campo `subjects[0].namespace` es `lab-rbac` y que `subjects[0].name` es exactamente `app-reader-sa` (sin espacios ni errores tipográficos).

---

## Limpieza

> **⚠️ IMPORTANTE:** NO ejecutes la limpieza de este laboratorio. El namespace `lab-rbac`, la ServiceAccount `app-reader-sa`, el Role `configmap-reader` y el RoleBinding `app-reader-binding` son reutilizados como punto de partida en la **Práctica 17**.

Si necesitas limpiar únicamente el Pod de prueba con la ServiceAccount `default` (que no se reutiliza):

```bash
# Eliminar solo el Pod de comparación (no necesario para lab siguiente)
kubectl delete pod default-sa-pod -n lab-rbac --ignore-not-found
```

Para una limpieza completa al finalizar toda la secuencia de laboratorios (solo cuando se indique):

```bash
# ⚠️ SOLO ejecutar cuando se hayan completado TODOS los labs del batch
kubectl delete namespace lab-rbac
kubectl config set-context --current --namespace=ckad-dev
rm -rf ~/ckad-labs/lab04-rbac
```

---

## Resumen

En este laboratorio has implementado el principio de menor privilegio en Kubernetes mediante RBAC:

| Recurso Creado | Propósito |
|----------------|-----------|
| Namespace `lab-rbac` | Aislamiento del entorno de trabajo |
| ConfigMap `app-config` | Recurso de configuración externa (datos no sensibles) |
| Secret `app-secret` | Recurso de configuración externa (datos sensibles) |
| ServiceAccount `app-reader-sa` | Identidad dedicada para la aplicación |
| Role `configmap-reader` | Permisos mínimos: solo `get` y `list` sobre `configmaps` y `secrets` |
| RoleBinding `app-reader-binding` | Vinculación entre la SA y el Role |
| Pod `rbac-test-pod` | Demostración práctica de acceso controlado |

**Conceptos clave reforzados:**

- La ServiceAccount `default` no debe usarse en producción; cada aplicación necesita su propia identidad con permisos explícitos
- Los Roles definen QUÉ se puede hacer; los RoleBindings definen QUIÉN puede hacerlo
- `kubectl auth can-i --as=` permite validar permisos antes de desplegar, evitando errores en tiempo de ejecución
- La configuración externa (ConfigMaps y Secrets de la Lección 4.1) se complementa con RBAC para garantizar que solo las aplicaciones autorizadas pueden leer los datos de configuración

### Recursos Adicionales

- [Documentación oficial: RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Documentación oficial: Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Documentación oficial: Projected Service Account Tokens](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection)
- [Kubernetes Security Best Practices: Principle of Least Privilege](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)

---

# Control de recursos de aplicaciones

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 55 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar |
| **Namespace** | `lab-rbac` |
| **Imagen base** | `nginx:1.27.0` |

## Descripción General

En este laboratorio configurarás el control de recursos en Kubernetes aplicando Requests y Limits a un Deployment, estableciendo políticas a nivel de namespace mediante ResourceQuota y LimitRange, y observando el comportamiento del clúster cuando los contenedores exceden sus límites asignados. Verificarás las clases de Quality of Service (QoS) resultantes y el consumo real de recursos usando `kubectl top`.

## Objetivos de Aprendizaje

- [ ] Configurar Requests y Limits de CPU y memoria en contenedores de un Deployment para garantizar calidad de servicio
- [ ] Crear un objeto ResourceQuota a nivel de namespace para limitar el consumo total de recursos del equipo
- [ ] Definir un LimitRange que establezca valores por defecto y máximos para contenedores sin especificación explícita
- [ ] Observar el comportamiento de OOMKilled y CPU throttling cuando un contenedor excede sus límites
- [ ] Verificar el consumo real de recursos con `kubectl top pods` y compararlo con los valores configurados

## Prerrequisitos

### Conocimientos Requeridos

- Comprensión de las clases de QoS en Kubernetes: **Guaranteed**, **Burstable** y **BestEffort**
- Conocimiento de unidades de recursos: millicores (`m`) para CPU y mebibytes (`Mi`) para memoria
- Familiaridad con Deployments, Pods y namespaces de Kubernetes
- Comprensión del principio de configuración externa (Lección 4.1)

### Acceso y Entorno

- Namespace `lab-rbac` activo con ServiceAccount `app-reader-sa` y RoleBinding de la Práctica 16
- Addon `metrics-server` de minikube habilitado y funcional
- Acceso con permisos de administrador al clúster minikube

## Entorno de Laboratorio

### Requisitos de Hardware

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU | 2 núcleos | 4 núcleos |
| RAM | 8 GB | 12 GB |
| Disco | 30 GB libres | 40 GB libres (SSD) |

### Software Requerido

| Herramienta | Versión |
|-------------|---------|
| minikube | 1.33.1 |
| kubectl | 1.30.2 |
| Docker Engine | 26.1.4 |
| metrics-server (addon) | 0.7.1 |

### Preparación del Entorno

```bash
# Verificar que minikube está corriendo
minikube status

# Habilitar metrics-server si no está activo
minikube addons enable metrics-server

# Verificar que metrics-server responde (puede tardar 1-2 minutos tras habilitarlo)
kubectl top nodes

# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab17
cd ~/ckad-labs/lab17

# Verificar que el namespace lab-rbac existe
kubectl get namespace lab-rbac

# Establecer el namespace de trabajo
kubectl config set-context --current --namespace=lab-rbac
```

**Salida esperada de `kubectl top nodes`:**

```
NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
minikube   250m         6%     1200Mi          15%
```

> **Nota:** Si `kubectl top nodes` devuelve un error `metrics not available`, espera 60 segundos y reintenta. El metrics-server necesita tiempo para recopilar las primeras métricas.

## Paso a Paso

### Paso 1: Crear el LimitRange con valores por defecto y máximos

**Objetivo:** Definir un objeto LimitRange que establezca automáticamente Requests y Limits para cualquier contenedor que no los especifique explícitamente, y que impida la creación de contenedores que excedan los máximos permitidos.

**Instrucciones:**

1. Crea el archivo de manifiesto para el LimitRange:

```bash
cat <<'EOF' > ~/ckad-labs/lab17/limitrange.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: lab-rbac
spec:
  limits:
  - type: Container
    default:
      cpu: "100m"
      memory: "128Mi"
    defaultRequest:
      cpu: "50m"
      memory: "64Mi"
    max:
      cpu: "500m"
      memory: "512Mi"
    min:
      cpu: "10m"
      memory: "16Mi"
EOF
```

2. Aplica el LimitRange al namespace:

```bash
kubectl apply -f ~/ckad-labs/lab17/limitrange.yaml
```

3. Verifica la creación del LimitRange:

```bash
kubectl describe limitrange default-limits -n lab-rbac
```

**Salida esperada:**

```
Name:       default-limits
Namespace:  lab-rbac
Type        Resource  Min   Max    Default Request  Default Limit  Max Limit/Request Ratio
----        --------  ---   ---    ---------------  -------------  -----------------------
Container   cpu       10m   500m   50m              100m           -
Container   memory    16Mi  512Mi  64Mi             128Mi          -
```

**Verificación:**

```bash
# Confirmar que el LimitRange está activo
kubectl get limitrange -n lab-rbac -o name
```

Debe mostrar: `limitrange/default-limits`

---

### Paso 2: Crear la ResourceQuota del namespace

**Objetivo:** Establecer un límite superior total de recursos que todos los Pods del namespace pueden consumir en conjunto, simulando un presupuesto de equipo.

**Instrucciones:**

1. Crea el manifiesto de la ResourceQuota:

```bash
cat <<'EOF' > ~/ckad-labs/lab17/resourcequota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ns-quota
  namespace: lab-rbac
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "1Gi"
    limits.cpu: "2"
    limits.memory: "1Gi"
    pods: "10"
EOF
```

2. Aplica la ResourceQuota:

```bash
kubectl apply -f ~/ckad-labs/lab17/resourcequota.yaml
```

3. Verifica el estado de la quota:

```bash
kubectl describe resourcequota ns-quota -n lab-rbac
```

**Salida esperada:**

```
Name:            ns-quota
Namespace:       lab-rbac
Resource         Used  Hard
--------         ----  ----
limits.cpu       0     2
limits.memory    0     1Gi
pods             0     10
requests.cpu     0     2
requests.memory  0     1Gi
```

> **Nota:** La columna `Used` puede mostrar valores distintos de 0 si ya hay Pods corriendo en el namespace de la Práctica 16. Esto es normal.

**Verificación:**

```bash
kubectl get resourcequota ns-quota -n lab-rbac -o jsonpath='{.status.hard.limits\.cpu}'
echo
```

Debe mostrar: `2`

---

### Paso 3: Desplegar el Deployment con Requests y Limits explícitos

**Objetivo:** Crear un Deployment `resource-demo-app` con configuración explícita de recursos que resulte en una clasificación QoS **Guaranteed** (requests = limits).

**Instrucciones:**

1. Crea el manifiesto del Deployment:

```bash
cat <<'EOF' > ~/ckad-labs/lab17/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-demo-app
  namespace: lab-rbac
  labels:
    app: resource-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: resource-demo
  template:
    metadata:
      labels:
        app: resource-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "200m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "128Mi"
EOF
```

2. Aplica el Deployment:

```bash
kubectl apply -f ~/ckad-labs/lab17/deployment.yaml
```

3. Espera a que los Pods estén en estado Running:

```bash
kubectl rollout status deployment/resource-demo-app -n lab-rbac --timeout=60s
```

4. Verifica los Pods:

```bash
kubectl get pods -n lab-rbac -l app=resource-demo -o wide
```

**Salida esperada:**

```
NAME                                 READY   STATUS    RESTARTS   AGE   IP            NODE
resource-demo-app-xxxxxxxxx-xxxxx    1/1     Running   0          30s   172.17.0.x    minikube
resource-demo-app-xxxxxxxxx-yyyyy    1/1     Running   0          30s   172.17.0.y    minikube
```

**Verificación:**

```bash
# Verificar la clase QoS del Pod
kubectl get pod -n lab-rbac -l app=resource-demo -o jsonpath='{.items[0].status.qosClass}'
echo
```

Debe mostrar: `Guaranteed`

> **Concepto clave:** Un Pod obtiene QoS class **Guaranteed** cuando todos sus contenedores tienen requests iguales a limits tanto para CPU como para memoria. Esto le da la máxima prioridad y protección contra eviction.

---

### Paso 4: Verificar la clasificación QoS y la asignación de recursos

**Objetivo:** Inspeccionar en detalle cómo Kubernetes asignó los recursos y clasificó el Pod, comprendiendo las implicaciones de cada clase QoS.

**Instrucciones:**

1. Obtén el nombre de uno de los Pods:

```bash
POD_NAME=$(kubectl get pods -n lab-rbac -l app=resource-demo -o jsonpath='{.items[0].metadata.name}')
echo "Pod seleccionado: $POD_NAME"
```

2. Describe el Pod para ver los recursos asignados:

```bash
kubectl describe pod $POD_NAME -n lab-rbac | grep -A 10 "Containers:" | head -15
```

3. Verifica la sección de recursos específicamente:

```bash
kubectl get pod $POD_NAME -n lab-rbac -o jsonpath='{.spec.containers[0].resources}' | jq .
```

**Salida esperada:**

```json
{
  "limits": {
    "cpu": "200m",
    "memory": "128Mi"
  },
  "requests": {
    "cpu": "200m",
    "memory": "128Mi"
  }
}
```

4. Verifica el consumo actual de la ResourceQuota:

```bash
kubectl describe resourcequota ns-quota -n lab-rbac
```

**Salida esperada (sección relevante):**

```
Resource         Used   Hard
--------         ----   ----
limits.cpu       400m   2
limits.memory    256Mi  1Gi
pods             2      10
requests.cpu     400m   2
requests.memory  256Mi  1Gi
```

> **Análisis:** Con 2 réplicas, cada una usando 200m CPU y 128Mi de memoria, el consumo total es 400m CPU y 256Mi de memoria. La quota permite hasta 2 CPU (2000m) y 1Gi (1024Mi).

**Verificación:**

```bash
# Confirmar que la quota refleja 2 Pods activos
kubectl get resourcequota ns-quota -n lab-rbac -o jsonpath='{.status.used.pods}'
echo
```

---

### Paso 5: Intentar escalar más allá de la ResourceQuota

**Objetivo:** Demostrar que la ResourceQuota actúa como un mecanismo de admisión que impide la creación de Pods cuando se excede el presupuesto de recursos del namespace.

**Instrucciones:**

1. Intenta escalar el Deployment a 12 réplicas (excede el límite de 10 Pods y los recursos):

```bash
kubectl scale deployment resource-demo-app -n lab-rbac --replicas=12
```

2. Observa el estado del Deployment:

```bash
kubectl get deployment resource-demo-app -n lab-rbac
```

**Salida esperada:**

```
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
resource-demo-app   2/12    10           2           3m
```

> **Nota:** El número de Pods Ready dependerá de la quota. Con 200m por Pod y un límite de 2000m (2 CPU), el máximo teórico es 10 Pods por CPU. Sin embargo, la quota de pods es 10, y también puede haber otros Pods en el namespace consumiendo recursos.

3. Verifica los eventos del ReplicaSet para ver el error de admisión:

```bash
kubectl get events -n lab-rbac --sort-by='.lastTimestamp' | grep -i "quota\|forbidden\|exceeded" | tail -5
```

**Salida esperada (similar a):**

```
...  Warning  FailedCreate  replicaset/resource-demo-app-xxxxx  Error creating: pods "resource-demo-app-xxxxx-xxxxx" is forbidden: exceeded quota: ns-quota, requested: limits.cpu=200m,limits.memory=128Mi, used: limits.cpu=2,limits.memory=1Gi, limited: limits.cpu=2,limits.memory=1Gi
```

4. También verifica con el ReplicaSet directamente:

```bash
RS_NAME=$(kubectl get rs -n lab-rbac -l app=resource-demo -o jsonpath='{.items[0].metadata.name}')
kubectl describe rs $RS_NAME -n lab-rbac | grep -A 5 "Conditions:"
```

5. Revierte el escalado a 2 réplicas:

```bash
kubectl scale deployment resource-demo-app -n lab-rbac --replicas=2
```

6. Confirma que vuelve al estado normal:

```bash
kubectl get deployment resource-demo-app -n lab-rbac
```

**Salida esperada:**

```
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
resource-demo-app   2/2     2            2           5m
```

**Verificación:**

```bash
# Confirmar que la quota se liberó correctamente
kubectl get resourcequota ns-quota -n lab-rbac -o jsonpath='{.status.used.limits\.cpu}'
echo
```

Debe mostrar: `400m`

---

### Paso 6: Observar el comportamiento OOMKilled

**Objetivo:** Crear un Pod que intencionalmente exceda su límite de memoria para observar cómo Kubernetes termina el contenedor con el estado OOMKilled.

**Instrucciones:**

1. Crea un Pod de prueba que consumirá más memoria de la permitida:

```bash
cat <<'EOF' > ~/ckad-labs/lab17/oom-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-demo
  namespace: lab-rbac
spec:
  containers:
  - name: memory-hog
    image: nginx:1.27.0
    resources:
      requests:
        cpu: "50m"
        memory: "32Mi"
      limits:
        cpu: "50m"
        memory: "32Mi"
    command:
    - "/bin/sh"
    - "-c"
    - |
      # Llenar la memoria hasta exceder el límite de 32Mi
      echo "Iniciando consumo de memoria..."
      # Usar dd para crear un archivo en /dev/shm (tmpfs = RAM)
      dd if=/dev/zero of=/dev/shm/fill bs=1M count=64 2>/dev/null
      echo "Completado"
      sleep 3600
EOF
```

2. Aplica el Pod:

```bash
kubectl apply -f ~/ckad-labs/lab17/oom-pod.yaml
```

3. Observa el estado del Pod (espera 10-15 segundos):

```bash
sleep 15
kubectl get pod oom-demo -n lab-rbac
```

**Salida esperada:**

```
NAME       READY   STATUS      RESTARTS      AGE
oom-demo   0/1     OOMKilled   1 (5s ago)    15s
```

4. Verifica el motivo de terminación:

```bash
kubectl get pod oom-demo -n lab-rbac -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
echo
```

**Salida esperada:**

```
OOMKilled
```

5. Inspecciona los detalles del evento:

```bash
kubectl describe pod oom-demo -n lab-rbac | grep -A 3 "Last State:"
```

**Salida esperada (similar a):**

```
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
      Started:      ...
```

> **Concepto clave:** El exit code 137 indica que el proceso fue terminado por una señal SIGKILL (128 + 9 = 137). El kernel Linux OOM Killer interviene cuando el contenedor excede su cgroup memory limit.

**Verificación:**

```bash
# Verificar que el Pod tiene restarts > 0
kubectl get pod oom-demo -n lab-rbac -o jsonpath='{.status.containerStatuses[0].restartCount}'
echo
```

Debe mostrar un número mayor que 0.

---

### Paso 7: Verificar el consumo real con kubectl top

**Objetivo:** Usar `kubectl top pods` para comparar el consumo real de recursos de los Pods con los valores de Requests y Limits configurados.

**Instrucciones:**

1. Verifica el consumo de recursos de los Pods del Deployment:

```bash
kubectl top pods -n lab-rbac -l app=resource-demo
```

**Salida esperada (valores aproximados):**

```
NAME                                 CPU(cores)   MEMORY(bytes)
resource-demo-app-xxxxxxxxx-xxxxx    1m           3Mi
resource-demo-app-xxxxxxxxx-yyyyy    1m           3Mi
```

> **Análisis:** nginx en reposo consume muy pocos recursos (~1-3m CPU y ~3-5Mi memoria). Sin embargo, los Requests (200m CPU, 128Mi) reservan esos recursos en el nodo, y los Limits (200m CPU, 128Mi) establecen el techo máximo. La diferencia entre consumo real y Requests es capacidad reservada pero no utilizada.

2. Compara con los recursos configurados:

```bash
echo "=== Recursos Configurados ==="
kubectl get pods -n lab-rbac -l app=resource-demo -o custom-columns=\
NAME:.metadata.name,\
REQ_CPU:.spec.containers[0].resources.requests.cpu,\
LIM_CPU:.spec.containers[0].resources.limits.cpu,\
REQ_MEM:.spec.containers[0].resources.requests.memory,\
LIM_MEM:.spec.containers[0].resources.limits.memory

echo ""
echo "=== Consumo Real ==="
kubectl top pods -n lab-rbac -l app=resource-demo
```

**Salida esperada:**

```
=== Recursos Configurados ===
NAME                                REQ_CPU   LIM_CPU   REQ_MEM   LIM_MEM
resource-demo-app-xxxxxxxxx-xxxxx   200m      200m      128Mi     128Mi
resource-demo-app-xxxxxxxxx-yyyyy   200m      200m      128Mi     128Mi

=== Consumo Real ===
NAME                                 CPU(cores)   MEMORY(bytes)
resource-demo-app-xxxxxxxxx-xxxxx    1m           3Mi
resource-demo-app-xxxxxxxxx-yyyyy    1m           3Mi
```

3. Verifica también el consumo a nivel de nodo:

```bash
kubectl top nodes
```

**Verificación:**

```bash
# Confirmar que kubectl top funciona correctamente
kubectl top pods -n lab-rbac --no-headers | wc -l
```

Debe mostrar al menos 2 líneas (los 2 Pods del Deployment, más posiblemente el oom-demo en CrashLoopBackOff).

---

### Paso 8: Verificar el efecto del LimitRange en Pods sin recursos explícitos

**Objetivo:** Demostrar que el LimitRange aplica automáticamente valores por defecto a contenedores que no especifican Requests ni Limits.

**Instrucciones:**

1. Crea un Pod sin especificación de recursos:

```bash
cat <<'EOF' > ~/ckad-labs/lab17/pod-no-resources.yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-resources-pod
  namespace: lab-rbac
spec:
  containers:
  - name: nginx
    image: nginx:1.27.0
    ports:
    - containerPort: 80
EOF
```

2. Aplica el Pod:

```bash
kubectl apply -f ~/ckad-labs/lab17/pod-no-resources.yaml
```

3. Verifica que el LimitRange inyectó valores por defecto:

```bash
kubectl get pod no-resources-pod -n lab-rbac -o jsonpath='{.spec.containers[0].resources}' | jq .
```

**Salida esperada:**

```json
{
  "limits": {
    "cpu": "100m",
    "memory": "128Mi"
  },
  "requests": {
    "cpu": "50m",
    "memory": "64Mi"
  }
}
```

4. Verifica la clase QoS de este Pod:

```bash
kubectl get pod no-resources-pod -n lab-rbac -o jsonpath='{.status.qosClass}'
echo
```

**Salida esperada:**

```
Burstable
```

> **Concepto clave:** Como los Requests (50m/64Mi) son diferentes de los Limits (100m/128Mi), el Pod se clasifica como **Burstable**. Esto significa que puede usar más recursos que sus Requests (hasta los Limits), pero tiene menor prioridad que los Pods Guaranteed ante una situación de presión de recursos.

5. Verifica la actualización de la ResourceQuota:

```bash
kubectl get resourcequota ns-quota -n lab-rbac -o custom-columns=\
RESOURCE:.spec.hard,\
USED:.status.used
```

**Verificación:**

```bash
# Verificar que los defaults del LimitRange se aplicaron
kubectl describe pod no-resources-pod -n lab-rbac | grep -A 6 "Limits:"
```

---

## Validación y Testing

Ejecuta el siguiente script de validación integral para confirmar que todos los componentes están correctamente configurados:

```bash
#!/bin/bash
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Validación Lab 04-00-04: Control de Recursos       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0

# Test 1: LimitRange existe
echo -n "[1/7] LimitRange 'default-limits' existe... "
if kubectl get limitrange default-limits -n lab-rbac &>/dev/null; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL"; ((FAIL++))
fi

# Test 2: ResourceQuota existe
echo -n "[2/7] ResourceQuota 'ns-quota' existe... "
if kubectl get resourcequota ns-quota -n lab-rbac &>/dev/null; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL"; ((FAIL++))
fi

# Test 3: Deployment con 2 réplicas Running
echo -n "[3/7] Deployment 'resource-demo-app' con 2 réplicas Ready... "
READY=$(kubectl get deployment resource-demo-app -n lab-rbac -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$READY" == "2" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (Ready: $READY)"; ((FAIL++))
fi

# Test 4: QoS class es Guaranteed
echo -n "[4/7] QoS class del Deployment es 'Guaranteed'... "
QOS=$(kubectl get pods -n lab-rbac -l app=resource-demo -o jsonpath='{.items[0].status.qosClass}' 2>/dev/null)
if [ "$QOS" == "Guaranteed" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (QoS: $QOS)"; ((FAIL++))
fi

# Test 5: Pod oom-demo tiene OOMKilled en historial
echo -n "[5/7] Pod 'oom-demo' experimentó OOMKilled... "
OOM_REASON=$(kubectl get pod oom-demo -n lab-rbac -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)
if [ "$OOM_REASON" == "OOMKilled" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (Reason: $OOM_REASON)"; ((FAIL++))
fi

# Test 6: Pod sin recursos tiene defaults del LimitRange
echo -n "[6/7] Pod 'no-resources-pod' tiene limits inyectados... "
LIM_CPU=$(kubectl get pod no-resources-pod -n lab-rbac -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
if [ "$LIM_CPU" == "100m" ]; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (CPU limit: $LIM_CPU)"; ((FAIL++))
fi

# Test 7: kubectl top funciona
echo -n "[7/7] kubectl top pods devuelve métricas... "
if kubectl top pods -n lab-rbac --no-headers 2>/dev/null | grep -q "resource-demo"; then
  echo "✅ PASS"; ((PASS++))
else
  echo "❌ FAIL (metrics-server no responde)"; ((FAIL++))
fi

echo ""
echo "═══════════════════════════════════════════"
echo "Resultado: $PASS/7 pruebas exitosas, $FAIL fallidas"
echo "═══════════════════════════════════════════"
```

Guarda y ejecuta:

```bash
cat <<'SCRIPT' > ~/ckad-labs/lab17/validate.sh
# (pegar el script anterior aquí)
SCRIPT
chmod +x ~/ckad-labs/lab17/validate.sh
bash ~/ckad-labs/lab17/validate.sh
```

**Resultado esperado:** 7/7 pruebas exitosas.

---

## Troubleshooting

### Problema 1: kubectl top pods devuelve "error: Metrics API not available"

**Síntomas:**

```
error: Metrics API not available
```

o bien:

```
Error from server (ServiceUnavailable): the server is currently unable to handle the request
```

**Causa:** El addon `metrics-server` no está habilitado o no ha terminado de inicializarse. El metrics-server necesita entre 30 y 90 segundos después de habilitarse para comenzar a servir datos.

**Solución:**

```bash
# Verificar el estado del addon
minikube addons list | grep metrics-server

# Si no está habilitado, habilitarlo
minikube addons enable metrics-server

# Verificar que el Pod del metrics-server está Running
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Esperar a que esté listo
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s

# Esperar 60 segundos adicionales para la primera recolección de métricas
sleep 60

# Reintentar
kubectl top nodes
kubectl top pods -n lab-rbac
```

---

### Problema 2: El Deployment no puede crear Pods — "exceeded quota"

**Síntomas:**

Al aplicar el Deployment o al escalarlo, los Pods quedan en estado Pending y los eventos muestran:

```
Error creating: pods "resource-demo-app-xxx" is forbidden: exceeded quota: ns-quota
```

**Causa:** Ya existen otros Pods en el namespace `lab-rbac` (de la Práctica 16 u otros laboratorios) que consumen parte de la ResourceQuota. Cuando se intenta crear los Pods del Deployment, la suma total excede los límites establecidos.

**Solución:**

```bash
# Verificar el consumo actual de la quota
kubectl describe resourcequota ns-quota -n lab-rbac

# Identificar qué Pods consumen recursos en el namespace
kubectl get pods -n lab-rbac -o custom-columns=\
NAME:.metadata.name,\
REQ_CPU:.spec.containers[0].resources.requests.cpu,\
LIM_CPU:.spec.containers[0].resources.limits.cpu

# Opción A: Eliminar Pods innecesarios de prácticas anteriores
kubectl delete pod <pod-innecesario> -n lab-rbac

# Opción B: Aumentar la quota temporalmente
kubectl patch resourcequota ns-quota -n lab-rbac --type='json' \
  -p='[{"op": "replace", "path": "/spec/hard/limits.cpu", "value": "4"}]'

# Verificar que el Deployment puede crear sus Pods
kubectl rollout status deployment/resource-demo-app -n lab-rbac --timeout=60s
```

---

## Cleanup

> **Importante:** El Deployment `resource-demo-app` y los objetos de control de recursos **NO deben eliminarse** ya que son referenciados en la Práctica 18 como base para el endurecimiento de seguridad.

Elimina únicamente los Pods de prueba que no se reutilizarán:

```bash
# Eliminar el Pod de prueba OOMKilled
kubectl delete pod oom-demo -n lab-rbac --force --grace-period=0

# Eliminar el Pod sin recursos explícitos
kubectl delete pod no-resources-pod -n lab-rbac

# Verificar que el Deployment sigue activo
kubectl get deployment resource-demo-app -n lab-rbac

# Verificar estado final del namespace
echo "=== Estado final del namespace lab-rbac ==="
echo ""
echo "--- Deployments ---"
kubectl get deployments -n lab-rbac
echo ""
echo "--- LimitRange ---"
kubectl get limitrange -n lab-rbac
echo ""
echo "--- ResourceQuota ---"
kubectl describe resourcequota ns-quota -n lab-rbac
```

**Estado esperado al finalizar:**

| Recurso | Nombre | Estado |
|---------|--------|--------|
| Deployment | `resource-demo-app` | 2/2 Ready ✅ |
| LimitRange | `default-limits` | Activo ✅ |
| ResourceQuota | `ns-quota` | Activo ✅ |
| Pod | `oom-demo` | Eliminado 🗑️ |
| Pod | `no-resources-pod` | Eliminado 🗑️ |

---

## Resumen

### Conceptos Clave Aprendidos

| Concepto | Descripción |
|----------|-------------|
| **Requests** | Recursos garantizados para el contenedor; usados por el scheduler para decidir en qué nodo colocar el Pod |
| **Limits** | Techo máximo de recursos; si se excede la memoria, el contenedor es terminado (OOMKilled); si se excede CPU, se aplica throttling |
| **ResourceQuota** | Límite total de recursos a nivel de namespace; actúa como mecanismo de admisión |
| **LimitRange** | Política que inyecta defaults y valida mínimos/máximos por contenedor individual |
| **QoS Guaranteed** | Requests = Limits para todos los recursos; máxima protección contra eviction |
| **QoS Burstable** | Requests < Limits; puede usar más recursos pero con menor prioridad |
| **OOMKilled** | El kernel termina el proceso cuando excede el memory limit del cgroup (exit code 137) |

### Relación con la Configuración Externa

Este laboratorio complementa los conceptos de la Lección 4.1 sobre configuración externa. Así como los ConfigMaps y Secrets externalizan la **configuración funcional** de una aplicación (URLs, credenciales, flags), los Requests, Limits, ResourceQuotas y LimitRanges externalizan la **configuración operacional** — los parámetros que definen cómo la aplicación consume recursos del clúster. Ambos tipos de configuración se gestionan como objetos Kubernetes independientes de la imagen del contenedor, manteniendo el principio de inmutabilidad del artefacto.

### Recursos Adicionales

- [Documentación oficial: Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Documentación oficial: Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Documentación oficial: Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Documentación oficial: Quality of Service for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/)
- [Kubernetes Patterns — Capítulo: Predictable Demands (O'Reilly)](https://www.oreilly.com/library/view/kubernetes-patterns/9781492050278/)

---

---

# Endurecimiento básico de Pods

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 70 minutos |
| **Complejidad** | Hard |
| **Nivel Bloom** | Apply |
| **Namespace** | `lab-rbac` |
| **Directorio de trabajo** | `~/ckad-labs/lab04/` |

## Descripción General

En este laboratorio se transforma progresivamente el Deployment `resource-demo-app` (creado en la Práctica 17) en un Deployment endurecido aplicando SecurityContext a nivel de Pod y contenedor. Se trabaja de forma incremental: primero se configuran UID/GID, luego se establece el filesystem como solo lectura con volúmenes temporales, después se eliminan capabilities Linux innecesarias y finalmente se bloquea la escalada de privilegios. Cada paso incluye verificación funcional para confirmar que nginx sigue respondiendo correctamente.

## Objetivos de Aprendizaje

- [ ] Aplicar `runAsUser`, `runAsGroup` y `fsGroup` a nivel de Pod para ejecutar contenedores como usuario no-root
- [ ] Configurar `readOnlyRootFilesystem: true` y montar volúmenes `emptyDir` en directorios que requieren escritura
- [ ] Eliminar todas las capabilities Linux con `drop: [ALL]` y agregar únicamente las estrictamente necesarias
- [ ] Configurar `allowPrivilegeEscalation: false` y `runAsNonRoot: true` para prevenir escalada de privilegios
- [ ] Validar que el Pod endurecido arranca correctamente y sirve tráfico HTTP sin errores

## Prerrequisitos

### Conocimiento Requerido

- Modelo de usuarios y grupos en Linux (UID/GID) y permisos de archivos
- Concepto de Linux capabilities y por qué su eliminación reduce la superficie de ataque
- Familiaridad con manifiestos YAML de Kubernetes (Deployments, Pods, Volumes)
- Comprensión de ConfigMaps y configuración externa (lección 4.1)

### Acceso Requerido

- Clúster Kubernetes funcional (kind o minikube)
- `kubectl` configurado con acceso al clúster
- Namespace `lab-rbac` existente con el Deployment `resource-demo-app` de la Práctica 17

## Entorno de Laboratorio

### Software Requerido

| Herramienta | Versión |
|-------------|---------|
| Docker Engine | 26.1.4 |
| kind | 0.23.0 |
| kubectl | 1.30.2 |
| nginx (imagen) | 1.27.0 |

### Preparación del Entorno

```bash
# Verificar que el namespace lab-rbac existe
kubectl get namespace lab-rbac

# Verificar que el Deployment resource-demo-app existe
kubectl -n lab-rbac get deployment resource-demo-app

# Crear directorio de trabajo
mkdir -p ~/ckad-labs/lab04/hardening
cd ~/ckad-labs/lab04/hardening

# Verificar alias activos
alias k=kubectl 2>/dev/null || alias k=kubectl
```

Si el Deployment `resource-demo-app` no existe de la Práctica 17, créelo con este manifiesto base:

```bash
cat <<'EOF' > ~/ckad-labs/lab04/hardening/resource-demo-app-base.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-demo-app
  namespace: lab-rbac
  labels:
    app: resource-demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-demo-app
  template:
    metadata:
      labels:
        app: resource-demo-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
EOF

kubectl apply -f ~/ckad-labs/lab04/hardening/resource-demo-app-base.yaml
kubectl -n lab-rbac rollout status deployment/resource-demo-app --timeout=60s
```

---

## Paso 1: Exportar el Manifiesto Actual y Establecer la Línea Base

### Objetivo

Obtener el manifiesto actual del Deployment como punto de partida y verificar que la aplicación funciona antes de aplicar cambios de seguridad.

### Instrucciones

1. Exporte el Deployment actual a un archivo YAML limpio:

```bash
cd ~/ckad-labs/lab04/hardening

kubectl -n lab-rbac get deployment resource-demo-app -o yaml | \
  kubectl neat > resource-demo-app-hardened.yaml 2>/dev/null || \
  kubectl -n lab-rbac get deployment resource-demo-app -o yaml > resource-demo-app-hardened.yaml
```

> **Nota:** Si `kubectl neat` no está instalado, edite manualmente el archivo para eliminar campos gestionados por el sistema (`managedFields`, `resourceVersion`, `uid`, `creationTimestamp`, `generation`, `status`).

2. Verifique que el Pod actual está corriendo:

```bash
kubectl -n lab-rbac get pods -l app=resource-demo-app -o wide
```

3. Compruebe el usuario actual con el que ejecuta nginx:

```bash
POD_NAME=$(kubectl -n lab-rbac get pods -l app=resource-demo-app -o jsonpath='{.items[0].metadata.name}')
kubectl -n lab-rbac exec $POD_NAME -- id
kubectl -n lab-rbac exec $POD_NAME -- whoami
```

4. Verifique que nginx responde:

```bash
kubectl -n lab-rbac exec $POD_NAME -- curl -s http://localhost:80 | head -5
```

### Salida Esperada

```
uid=0(root) gid=0(root) groups=0(root)
root
```

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

### Verificación

El Pod ejecuta como `root` (UID 0) — esto es lo que vamos a endurecer. Nginx responde en el puerto 80.

---

## Paso 2: Configurar SecurityContext a Nivel de Pod (UID/GID)

### Objetivo

Agregar `runAsUser: 1000`, `runAsGroup: 3000` y `fsGroup: 2000` al Pod. Dado que nginx:1.27.0 estándar requiere root para el puerto 80, se reconfigurará para escuchar en un puerto no privilegiado (8080).

### Instrucciones

1. Cree un ConfigMap con una configuración de nginx que escuche en el puerto 8080 (puerto no privilegiado):

```bash
cat <<'EOF' > nginx-nonroot-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-hardened-config
  namespace: lab-rbac
data:
  nginx.conf: |
    worker_processes auto;
    pid /tmp/nginx.pid;
    error_log /tmp/error.log warn;

    events {
        worker_connections 1024;
    }

    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;

        # Usar directorios temporales escribibles
        client_body_temp_path /tmp/client_body;
        proxy_temp_path /tmp/proxy;
        fastcgi_temp_path /tmp/fastcgi;
        uwsgi_temp_path /tmp/uwsgi;
        scgi_temp_path /tmp/scgi;

        access_log /tmp/access.log;

        sendfile on;
        keepalive_timeout 65;

        server {
            listen 8080;
            server_name localhost;

            location / {
                root /usr/share/nginx/html;
                index index.html index.htm;
            }

            location /healthz {
                return 200 'OK\n';
                add_header Content-Type text/plain;
            }
        }
    }
EOF

kubectl apply -f nginx-nonroot-config.yaml
```

2. Cree el manifiesto del Deployment endurecido con SecurityContext de Pod:

```bash
cat <<'EOF' > resource-demo-app-step2.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-demo-app
  namespace: lab-rbac
  labels:
    app: resource-demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-demo-app
  template:
    metadata:
      labels:
        app: resource-demo-app
    spec:
      # ══════════════════════════════════════════════
      # SecurityContext a nivel de Pod
      # ══════════════════════════════════════════════
      securityContext:
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: tmp-volume
          mountPath: /tmp
        - name: cache-volume
          mountPath: /var/cache/nginx
        - name: run-volume
          mountPath: /var/run
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-hardened-config
      - name: tmp-volume
        emptyDir: {}
      - name: cache-volume
        emptyDir: {}
      - name: run-volume
        emptyDir: {}
EOF

kubectl apply -f resource-demo-app-step2.yaml
```

3. Espere a que el nuevo Pod esté listo:

```bash
kubectl -n lab-rbac rollout status deployment/resource-demo-app --timeout=90s
```

4. Verifique el usuario dentro del contenedor:

```bash
POD_NAME=$(kubectl -n lab-rbac get pods -l app=resource-demo-app -o jsonpath='{.items[0].metadata.name}')
kubectl -n lab-rbac exec $POD_NAME -- id
```

5. Verifique que nginx responde en el puerto 8080:

```bash
kubectl -n lab-rbac exec $POD_NAME -- curl -s http://localhost:8080/healthz
```

6. Verifique el propietario de archivos en los volúmenes montados:

```bash
kubectl -n lab-rbac exec $POD_NAME -- ls -la /tmp/
kubectl -n lab-rbac exec $POD_NAME -- ls -la /var/cache/nginx/
```

### Salida Esperada

```
uid=1000 gid=3000 groups=2000
```

```
OK
```

Los archivos en `/tmp/` deben mostrar grupo `2000` (fsGroup) y los directorios deben ser accesibles para el usuario 1000.

### Verificación

```bash
# Confirmar que runAsUser es 1000
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsUser}'
echo ""
# Debe imprimir: 1000

# Confirmar que runAsGroup es 3000
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsGroup}'
echo ""
# Debe imprimir: 3000

# Confirmar que fsGroup es 2000
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.securityContext.fsGroup}'
echo ""
# Debe imprimir: 2000
```

---

## Paso 3: Configurar readOnlyRootFilesystem

### Objetivo

Establecer el filesystem raíz del contenedor como solo lectura para prevenir que un atacante modifique binarios o archivos de configuración dentro del contenedor. Los directorios que necesitan escritura ya están montados como `emptyDir`.

### Instrucciones

1. Actualice el manifiesto agregando `readOnlyRootFilesystem: true` al securityContext del contenedor:

```bash
cat <<'EOF' > resource-demo-app-step3.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-demo-app
  namespace: lab-rbac
  labels:
    app: resource-demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-demo-app
  template:
    metadata:
      labels:
        app: resource-demo-app
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
        # ══════════════════════════════════════════════
        # SecurityContext a nivel de contenedor
        # ══════════════════════════════════════════════
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: tmp-volume
          mountPath: /tmp
        - name: cache-volume
          mountPath: /var/cache/nginx
        - name: run-volume
          mountPath: /var/run
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-hardened-config
      - name: tmp-volume
        emptyDir: {}
      - name: cache-volume
        emptyDir: {}
      - name: run-volume
        emptyDir: {}
EOF

kubectl apply -f resource-demo-app-step3.yaml
```

2. Espere el rollout:

```bash
kubectl -n lab-rbac rollout status deployment/resource-demo-app --timeout=90s
```

3. Verifique que el filesystem raíz es de solo lectura intentando escribir:

```bash
POD_NAME=$(kubectl -n lab-rbac get pods -l app=resource-demo-app -o jsonpath='{.items[0].metadata.name}')

# Esto debe FALLAR (read-only filesystem)
kubectl -n lab-rbac exec $POD_NAME -- sh -c 'touch /usr/share/nginx/html/test.txt' 2>&1

# Esto debe FUNCIONAR (emptyDir montado)
kubectl -n lab-rbac exec $POD_NAME -- sh -c 'touch /tmp/test.txt && echo "Escritura en /tmp exitosa"'
```

4. Confirme que nginx sigue respondiendo:

```bash
kubectl -n lab-rbac exec $POD_NAME -- curl -s http://localhost:8080/healthz
```

### Salida Esperada

```
touch: cannot touch '/usr/share/nginx/html/test.txt': Read-only file system
command terminated with exit code 1
```

```
Escritura en /tmp exitosa
```

```
OK
```

### Verificación

```bash
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'
echo ""
# Debe imprimir: true
```

---

## Paso 4: Eliminar Capabilities y Agregar Solo las Necesarias

### Objetivo

Aplicar el principio de mínimo privilegio eliminando todas las capabilities Linux con `drop: [ALL]`. Dado que nginx escucha en el puerto 8080 (> 1024), no necesita `NET_BIND_SERVICE`. Se agrega únicamente si fuera necesario para demostrar el patrón.

### Instrucciones

1. Actualice el manifiesto con la configuración de capabilities:

```bash
cat <<'EOF' > resource-demo-app-step4.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-demo-app
  namespace: lab-rbac
  labels:
    app: resource-demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-demo-app
  template:
    metadata:
      labels:
        app: resource-demo-app
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
        securityContext:
          readOnlyRootFilesystem: true
          # ══════════════════════════════════════════════
          # Capabilities: eliminar todas, no agregar ninguna
          # (puerto 8080 > 1024, no requiere NET_BIND_SERVICE)
          # ══════════════════════════════════════════════
          capabilities:
            drop:
              - ALL
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: tmp-volume
          mountPath: /tmp
        - name: cache-volume
          mountPath: /var/cache/nginx
        - name: run-volume
          mountPath: /var/run
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-hardened-config
      - name: tmp-volume
        emptyDir: {}
      - name: cache-volume
        emptyDir: {}
      - name: run-volume
        emptyDir: {}
EOF

kubectl apply -f resource-demo-app-step4.yaml
```

2. Espere el rollout:

```bash
kubectl -n lab-rbac rollout status deployment/resource-demo-app --timeout=90s
```

3. Verifique las capabilities del proceso dentro del contenedor:

```bash
POD_NAME=$(kubectl -n lab-rbac get pods -l app=resource-demo-app -o jsonpath='{.items[0].metadata.name}')

# Verificar que /proc/1/status muestra capabilities vacías
kubectl -n lab-rbac exec $POD_NAME -- cat /proc/1/status | grep -i cap
```

4. Confirme funcionalidad:

```bash
kubectl -n lab-rbac exec $POD_NAME -- curl -s http://localhost:8080/healthz
```

### Salida Esperada

Las líneas `CapPrm`, `CapEff` y `CapBnd` deben mostrar valores reducidos (ceros o valores mínimos):

```
CapInh: 0000000000000000
CapPrm: 0000000000000000
CapEff: 0000000000000000
CapBnd: 0000000000000000
CapAmb: 0000000000000000
```

```
OK
```

### Verificación

```bash
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}'
echo ""
# Debe imprimir: ALL
```

---

## Paso 5: Configurar allowPrivilegeEscalation y runAsNonRoot

### Objetivo

Agregar las últimas capas de endurecimiento: `allowPrivilegeEscalation: false` impide que un proceso hijo obtenga más privilegios que el padre, y `runAsNonRoot: true` hace que el kubelet rechace el Pod si intenta ejecutar como root.

### Instrucciones

1. Cree el manifiesto final completamente endurecido:

```bash
cat <<'EOF' > resource-demo-app-hardened-final.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-demo-app
  namespace: lab-rbac
  labels:
    app: resource-demo-app
    security: hardened
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-demo-app
  template:
    metadata:
      labels:
        app: resource-demo-app
        security: hardened
    spec:
      # ══════════════════════════════════════════════════════
      # SecurityContext a nivel de Pod
      # ══════════════════════════════════════════════════════
      securityContext:
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
        runAsNonRoot: true
      # ══════════════════════════════════════════════════════
      # initContainer para preparar directorios
      # ══════════════════════════════════════════════════════
      initContainers:
      - name: init-permissions
        image: busybox:1.36.1
        command:
        - sh
        - -c
        - |
          echo "Preparando directorios temporales..."
          mkdir -p /work-tmp/client_body /work-tmp/proxy /work-tmp/fastcgi /work-tmp/uwsgi /work-tmp/scgi
          echo "Directorios creados exitosamente"
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
        volumeMounts:
        - name: tmp-volume
          mountPath: /work-tmp
      containers:
      - name: nginx
        image: nginx:1.27.0
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
        # ══════════════════════════════════════════════════════
        # SecurityContext a nivel de contenedor (completo)
        # ══════════════════════════════════════════════════════
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 3
          periodSeconds: 5
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: tmp-volume
          mountPath: /tmp
        - name: cache-volume
          mountPath: /var/cache/nginx
        - name: run-volume
          mountPath: /var/run
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-hardened-config
      - name: tmp-volume
        emptyDir: {}
      - name: cache-volume
        emptyDir: {}
      - name: run-volume
        emptyDir: {}
EOF

kubectl apply -f resource-demo-app-hardened-final.yaml
```

2. Espere el rollout completo:

```bash
kubectl -n lab-rbac rollout status deployment/resource-demo-app --timeout=120s
```

3. Verifique que el initContainer se ejecutó correctamente:

```bash
POD_NAME=$(kubectl -n lab-rbac get pods -l app=resource-demo-app -o jsonpath='{.items[0].metadata.name}')
kubectl -n lab-rbac logs $POD_NAME -c init-permissions
```

4. Verifique todos los campos de seguridad:

```bash
# runAsNonRoot a nivel de Pod
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsNonRoot}'
echo " <- runAsNonRoot (Pod)"

# allowPrivilegeEscalation a nivel de contenedor
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}'
echo " <- allowPrivilegeEscalation"

# Verificar identidad
kubectl -n lab-rbac exec $POD_NAME -- id
```

5. Pruebe la funcionalidad completa:

```bash
kubectl -n lab-rbac exec $POD_NAME -- curl -s http://localhost:8080/
kubectl -n lab-rbac exec $POD_NAME -- curl -s http://localhost:8080/healthz
```

### Salida Esperada

```
Preparando directorios temporales...
Directorios creados exitosamente
```

```
true <- runAsNonRoot (Pod)
false <- allowPrivilegeEscalation
uid=1000 gid=3000 groups=2000
```

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

```
OK
```

### Verificación

```bash
# Verificación completa de todos los campos de seguridad
echo "=== Verificación de Endurecimiento ==="
echo -n "runAsUser: "
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsUser}'
echo ""
echo -n "runAsGroup: "
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsGroup}'
echo ""
echo -n "fsGroup: "
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.securityContext.fsGroup}'
echo ""
echo -n "runAsNonRoot: "
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsNonRoot}'
echo ""
echo -n "readOnlyRootFilesystem: "
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'
echo ""
echo -n "allowPrivilegeEscalation: "
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}'
echo ""
echo -n "capabilities.drop: "
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop}'
echo ""
echo "=== Fin Verificación ==="
```

Salida esperada:

```
=== Verificación de Endurecimiento ===
runAsUser: 1000
runAsGroup: 3000
fsGroup: 2000
runAsNonRoot: true
readOnlyRootFilesystem: true
allowPrivilegeEscalation: false
capabilities.drop: ["ALL"]
=== Fin Verificación ===
```

---

## Paso 6: Validación de Seguridad Negativa

### Objetivo

Confirmar que las restricciones de seguridad funcionan correctamente intentando operaciones que deberían ser bloqueadas.

### Instrucciones

1. Intente escribir en el filesystem raíz:

```bash
POD_NAME=$(kubectl -n lab-rbac get pods -l app=resource-demo-app -o jsonpath='{.items[0].metadata.name}')

kubectl -n lab-rbac exec $POD_NAME -- sh -c 'touch /etc/malicious-file' 2>&1
```

2. Intente cambiar de usuario (debe fallar sin capabilities):

```bash
kubectl -n lab-rbac exec $POD_NAME -- sh -c 'cat /etc/shadow' 2>&1
```

3. Verifique que no se puede escuchar en un puerto privilegiado (< 1024):

```bash
# Esto fallará porque se eliminó NET_BIND_SERVICE y no somos root
kubectl -n lab-rbac exec $POD_NAME -- sh -c 'apt-get update 2>&1 || echo "No se puede modificar el sistema"'
```

4. Confirme que la aplicación sigue funcional a pesar de las restricciones:

```bash
kubectl -n lab-rbac exec $POD_NAME -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/healthz
echo ""
```

### Salida Esperada

```
touch: cannot touch '/etc/malicious-file': Read-only file system
command terminated with exit code 1
```

```
cat: /etc/shadow: Permission denied
command terminated with exit code 1
```

```
No se puede modificar el sistema
```

```
200
```

### Verificación

Todas las operaciones maliciosas fallan, pero la aplicación responde con HTTP 200. Esto confirma que el endurecimiento no afecta la funcionalidad legítima.

---

## Validación y Pruebas Finales

Ejecute el siguiente script de validación integral:

```bash
#!/bin/bash
echo "╔══════════════════════════════════════════════════╗"
echo "║  VALIDACIÓN FINAL - Pod Endurecido              ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

NAMESPACE="lab-rbac"
DEPLOY="resource-demo-app"
PASS=0
FAIL=0

# Test 1: Deployment existe y está disponible
echo -n "[TEST 1] Deployment disponible: "
AVAILABLE=$(kubectl -n $NAMESPACE get deployment $DEPLOY -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
if [ "$AVAILABLE" == "1" ]; then echo "✅ PASS"; ((PASS++)); else echo "❌ FAIL (available=$AVAILABLE)"; ((FAIL++)); fi

POD_NAME=$(kubectl -n $NAMESPACE get pods -l app=$DEPLOY -o jsonpath='{.items[0].metadata.name}')

# Test 2: runAsUser = 1000
echo -n "[TEST 2] runAsUser=1000: "
VAL=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsUser}')
if [ "$VAL" == "1000" ]; then echo "✅ PASS"; ((PASS++)); else echo "❌ FAIL (got $VAL)"; ((FAIL++)); fi

# Test 3: runAsGroup = 3000
echo -n "[TEST 3] runAsGroup=3000: "
VAL=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsGroup}')
if [ "$VAL" == "3000" ]; then echo "✅ PASS"; ((PASS++)); else echo "❌ FAIL (got $VAL)"; ((FAIL++)); fi

# Test 4: fsGroup = 2000
echo -n "[TEST 4] fsGroup=2000: "
VAL=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.spec.securityContext.fsGroup}')
if [ "$VAL" == "2000" ]; then echo "✅ PASS"; ((PASS++)); else echo "❌ FAIL (got $VAL)"; ((FAIL++)); fi

# Test 5: runAsNonRoot = true
echo -n "[TEST 5] runAsNonRoot=true: "
VAL=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsNonRoot}')
if [ "$VAL" == "true" ]; then echo "✅ PASS"; ((PASS++)); else echo "❌ FAIL (got $VAL)"; ((FAIL++)); fi

# Test 6: readOnlyRootFilesystem = true
echo -n "[TEST 6] readOnlyRootFilesystem=true: "
VAL=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}')
if [ "$VAL" == "true" ]; then echo "✅ PASS"; ((PASS++)); else echo "❌ FAIL (got $VAL)"; ((FAIL++)); fi

# Test 7: allowPrivilegeEscalation = false
echo -n "[TEST 7] allowPrivilegeEscalation=false: "
VAL=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}')
if [ "$VAL" == "false" ]; then echo "✅ PASS"; ((PASS++)); else echo "❌ FAIL (got $VAL)"; ((FAIL++)); fi

# Test 8: capabilities drop ALL
echo -n "[TEST 8] capabilities.drop=[ALL]: "
VAL=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}')
if [ "$VAL" == "ALL" ]; then echo "✅ PASS"; ((PASS++)); else echo "❌ FAIL (got $VAL)"; ((FAIL++)); fi

# Test 9: nginx responde HTTP 200
echo -n "[TEST 9] nginx responde 200: "
HTTP_CODE=$(kubectl -n $NAMESPACE exec $POD_NAME -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/healthz 2>/dev/null)
if [ "$HTTP_CODE" == "200" ]; then echo "✅ PASS"; ((PASS++)); else echo "❌ FAIL (HTTP $HTTP_CODE)"; ((FAIL++)); fi

# Test 10: initContainer presente
echo -n "[TEST 10] initContainer presente: "
INIT=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.spec.initContainers[0].name}')
if [ "$INIT" == "init-permissions" ]; then echo "✅ PASS"; ((PASS++)); else echo "❌ FAIL (got $INIT)"; ((FAIL++)); fi

echo ""
echo "════════════════════════════════════════════════════"
echo "  Resultados: $PASS/10 PASS, $FAIL/10 FAIL"
echo "════════════════════════════════════════════════════"

if [ $FAIL -eq 0 ]; then
  echo "  🎉 ¡Laboratorio completado exitosamente!"
else
  echo "  ⚠️  Revise los tests fallidos antes de continuar."
fi
```

Guarde y ejecute:

```bash
cat <<'SCRIPT' > validate-hardening.sh
# (copie el script de arriba aquí)
SCRIPT
chmod +x validate-hardening.sh
bash validate-hardening.sh
```

---

## Solución de Problemas

### Problema 1: Pod en CrashLoopBackOff después de agregar runAsUser

**Síntomas:**
```
$ kubectl -n lab-rbac get pods
NAME                                 READY   STATUS             RESTARTS   AGE
resource-demo-app-xxx-yyy            0/1     CrashLoopBackOff   3          2m
```

Los logs muestran:
```
nginx: [emerg] open() "/var/run/nginx.pid" failed (13: Permission denied)
```
o
```
nginx: [emerg] bind() to 0.0.0.0:80 failed (13: Permission denied)
```

**Causa:**
La imagen estándar de nginx:1.27.0 intenta:
1. Escribir el archivo PID en `/var/run/nginx.pid` (requiere permisos de escritura)
2. Escuchar en el puerto 80 (requiere capability `NET_BIND_SERVICE` o root)

Al cambiar a un usuario no-root (UID 1000), ambas operaciones fallan.

**Solución:**
1. Asegúrese de que el ConfigMap `nginx-hardened-config` está aplicado con `pid /tmp/nginx.pid` y `listen 8080`
2. Monte un `emptyDir` en `/var/run` para permitir escritura del PID alternativo
3. Monte un `emptyDir` en `/tmp` para los logs y archivos temporales
4. Verifique que el ConfigMap está montado correctamente:

```bash
kubectl -n lab-rbac describe pod $POD_NAME | grep -A5 "Mounts:"
kubectl -n lab-rbac exec $POD_NAME -- cat /etc/nginx/nginx.conf | head -3
```

---

### Problema 2: Pod rechazado con "container has runAsNonRoot and image will run as root"

**Síntomas:**
```
$ kubectl -n lab-rbac describe pod $POD_NAME
...
Warning  Failed  container has runAsNonRoot and image will run as root
```

El Pod queda en estado `CreateContainerConfigError`.

**Causa:**
Se configuró `runAsNonRoot: true` pero NO se especificó `runAsUser` con un UID distinto de 0. Kubernetes verifica la directiva USER de la imagen Docker; si la imagen define USER como root (o no define USER, que por defecto es root), el kubelet rechaza el Pod.

**Solución:**
Asegúrese de que `runAsUser: 1000` está definido en el `securityContext` a nivel de Pod o contenedor:

```bash
# Verificar que runAsUser está configurado
kubectl -n lab-rbac get pod $POD_NAME -o jsonpath='{.spec.securityContext.runAsUser}'

# Si no está configurado, edite el Deployment
kubectl -n lab-rbac edit deployment resource-demo-app
# Agregue bajo spec.template.spec.securityContext:
#   runAsUser: 1000
```

Alternativamente, aplique nuevamente el manifiesto del Paso 5 que incluye ambos campos (`runAsNonRoot: true` y `runAsUser: 1000`):

```bash
kubectl apply -f resource-demo-app-hardened-final.yaml
```

---

## Limpieza

> **⚠️ IMPORTANTE:** NO elimine los recursos de este laboratorio si va a continuar con la Práctica 19. El Deployment `resource-demo-app` endurecido es prerrequisito para el siguiente laboratorio.

Si necesita limpiar completamente (solo al final del curso):

```bash
# Eliminar Deployment
kubectl -n lab-rbac delete deployment resource-demo-app

# Eliminar ConfigMap
kubectl -n lab-rbac delete configmap nginx-hardened-config

# Eliminar archivos locales
rm -rf ~/ckad-labs/lab04/hardening/
```

Para verificar el estado final que se preserva para la Práctica 19:

```bash
kubectl -n lab-rbac get deployment resource-demo-app -o wide
kubectl -n lab-rbac get configmap nginx-hardened-config
kubectl -n lab-rbac get pods -l app=resource-demo-app
```

---

## Resumen

### Conceptos Aplicados

| Concepto | Configuración | Propósito |
|----------|--------------|-----------|
| `runAsUser: 1000` | Pod securityContext | Ejecutar como usuario no-root |
| `runAsGroup: 3000` | Pod securityContext | Grupo primario del proceso |
| `fsGroup: 2000` | Pod securityContext | Grupo propietario de volúmenes |
| `runAsNonRoot: true` | Pod securityContext | Kubelet rechaza ejecución como root |
| `readOnlyRootFilesystem: true` | Container securityContext | Filesystem raíz inmutable |
| `allowPrivilegeEscalation: false` | Container securityContext | Bloquea escalada de privilegios |
| `capabilities.drop: [ALL]` | Container securityContext | Elimina todas las capabilities Linux |
| `emptyDir` volumes | Volumes | Directorios temporales escribibles |
| `initContainers` | Pod spec | Preparación de filesystem |

### Relación con Configuración Externa

Este laboratorio demuestra un patrón complementario a la configuración externa (lección 4.1): la configuración de nginx se externaliza mediante un **ConfigMap** (`nginx-hardened-config`), permitiendo que la misma imagen `nginx:1.27.0` funcione tanto en modo root (configuración por defecto) como en modo endurecido (configuración personalizada). Esto ejemplifica el principio de que la configuración debe vivir fuera de la imagen.

### Recursos Adicionales

- [Documentación oficial: Pod Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Documentación oficial: Set capabilities for a Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-capabilities-for-a-container)
- [Linux Capabilities - man page](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CIS Kubernetes Benchmark - Container Security](https://www.cisecurity.org/benchmark/kubernetes)

---

# Consumo básico de CRD desde kubectl

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 35 minutos |
| **Complejidad** | Fácil |
| **Nivel Bloom** | Aplicar |
| **Prerrequisitos** | Clúster minikube activo, kubectl configurado |
| **Namespace** | `lab-crd` |

## Descripción General

En este laboratorio explorarás el modelo de extensión de Kubernetes mediante Custom Resource Definitions (CRDs). Instalarás un CRD personalizado llamado `Widget` en el grupo de API `example.com/v1`, crearás múltiples instancias de Custom Resources, y las gestionarás con los mismos comandos `kubectl` que utilizas para recursos nativos. Esta práctica demuestra cómo Kubernetes permite extender su API declarativa sin necesidad de escribir operadores, aplicando el mismo principio de configuración externa que separa la definición del recurso de su implementación.

## Objetivos de Aprendizaje

- [ ] Instalar un CRD de ejemplo y verificar su registro en la API de Kubernetes mediante `kubectl api-resources`
- [ ] Crear instancias de Custom Resources usando manifiestos YAML correctamente tipados con grupo, versión y Kind
- [ ] Gestionar Custom Resources (listar, describir, actualizar, eliminar) usando comandos kubectl estándar
- [ ] Explorar el esquema de un CRD mediante `kubectl explain` para comprender la validación OpenAPI v3
- [ ] Identificar la relación entre CRDs y operadores como patrón de extensión de Kubernetes

## Prerrequisitos

### Conocimientos Previos

| Concepto | Nivel Requerido |
|----------|----------------|
| Comandos kubectl (get, describe, apply, delete) | Intermedio |
| Estructura de manifiestos YAML de Kubernetes | Intermedio |
| Grupos de API (apps/v1, v1, batch/v1) | Básico |
| Modelo declarativo de Kubernetes | Básico |

### Acceso Requerido

- Clúster minikube v1.33.1 en ejecución
- kubectl v1.30.2 configurado y conectado al clúster
- Permisos de cluster-admin (por defecto en minikube)

## Entorno de Laboratorio

### Software Necesario

| Componente | Versión | Propósito |
|------------|---------|-----------|
| minikube | 1.33.1 | Clúster Kubernetes local |
| kubectl | 1.30.2 | CLI de gestión del clúster |
| bash | 5.x | Shell de ejecución |

### Configuración Inicial

```bash
# Verificar que el clúster está activo
minikube status

# Verificar conectividad con kubectl
kubectl cluster-info

# Crear el directorio de trabajo para este laboratorio
mkdir -p ~/ckad-labs/lab06
cd ~/ckad-labs/lab06

# Crear el namespace dedicado para este laboratorio
kubectl create namespace lab-crd

# Establecer el namespace como contexto activo
kubectl config set-context --current --namespace=lab-crd

# Verificar el namespace activo
kubectl config view --minify | grep namespace
```

**Salida esperada del último comando:**

```
    namespace: lab-crd
```

---

## Paso a Paso

### Paso 1: Explorar los recursos API existentes antes de instalar el CRD

**Objetivo:** Comprender el estado actual de la API de Kubernetes y establecer una línea base para comparar después de instalar el CRD.

**Instrucciones:**

1. Lista todos los grupos de API disponibles en el clúster:

```bash
kubectl api-versions | sort
```

2. Verifica que el grupo `example.com` NO existe aún:

```bash
kubectl api-versions | grep example.com
```

3. Cuenta el número actual de recursos API registrados:

```bash
kubectl api-resources | wc -l
```

4. Observa la estructura de un recurso nativo como referencia:

```bash
kubectl api-resources | grep -E "^NAME|deployments"
```

**Salida esperada:**

```
# El grep de example.com no debe devolver resultados (vacío)
# El conteo de api-resources mostrará un número (por ejemplo, ~60-70 recursos)
```

**Verificación:**

```bash
# Confirmar que example.com no existe
if kubectl api-versions | grep -q "example.com"; then
  echo "ERROR: example.com ya existe"
else
  echo "OK: example.com no registrado aún"
fi
```

---

### Paso 2: Crear el CustomResourceDefinition (CRD) de Widget

**Objetivo:** Definir un CRD llamado `Widget` con esquema OpenAPI v3 que extienda la API de Kubernetes con un nuevo tipo de recurso en el grupo `example.com/v1`.

**Instrucciones:**

1. Crea el archivo del CRD:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/widget-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: widgets.example.com
spec:
  group: example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - color
            - size
            properties:
              color:
                type: string
                description: "Color del widget"
                enum:
                - red
                - blue
                - green
                - yellow
              size:
                type: integer
                description: "Tamaño del widget en unidades"
                minimum: 1
                maximum: 100
              enabled:
                type: boolean
                description: "Si el widget está activo"
                default: true
              tags:
                type: array
                description: "Etiquetas opcionales del widget"
                items:
                  type: string
          status:
            type: object
            properties:
              state:
                type: string
              message:
                type: string
    additionalPrinterColumns:
    - name: Color
      type: string
      jsonPath: .spec.color
    - name: Size
      type: integer
      jsonPath: .spec.size
    - name: Enabled
      type: boolean
      jsonPath: .spec.enabled
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    subresources:
      status: {}
  scope: Namespaced
  names:
    plural: widgets
    singular: widget
    kind: Widget
    shortNames:
    - wg
EOF
```

2. Aplica el CRD al clúster (los CRDs son recursos a nivel de clúster):

```bash
kubectl apply -f ~/ckad-labs/lab06/widget-crd.yaml
```

3. Verifica que el CRD se creó correctamente:

```bash
kubectl get crd widgets.example.com
```

**Salida esperada:**

```
customresourcedefinition.apiextensions.k8s.io/widgets.example.com created
```

```
NAME                  CREATED AT
widgets.example.com   2024-XX-XXTXX:XX:XXZ
```

**Verificación:**

```bash
# Verificar que el CRD está en condición Established
kubectl get crd widgets.example.com -o jsonpath='{.status.conditions[?(@.type=="Established")].status}'
echo ""
```

La salida debe ser `True`.

---

### Paso 3: Verificar el registro del nuevo recurso en la API

**Objetivo:** Confirmar que Kubernetes reconoce el nuevo tipo `Widget` como un recurso válido de la API, verificando grupo, versión, nombres cortos y alcance.

**Instrucciones:**

1. Busca el recurso Widget en la lista de api-resources:

```bash
kubectl api-resources | grep -i widget
```

2. Verifica que el grupo de API `example.com/v1` ahora está disponible:

```bash
kubectl api-versions | grep example.com
```

3. Verifica los nombres cortos (shortNames) del recurso:

```bash
kubectl api-resources | grep -E "^NAME|widgets"
```

4. Explora el esquema del CRD con `kubectl explain`:

```bash
kubectl explain widget
```

5. Explora el esquema de spec en detalle:

```bash
kubectl explain widget.spec
```

6. Inspecciona un campo específico:

```bash
kubectl explain widget.spec.color
```

**Salida esperada del paso 1:**

```
widgets   wg   example.com/v1   true   Widget
```

**Salida esperada del paso 4:**

```
GROUP:      example.com
KIND:       Widget
VERSION:    v1

DESCRIPTION:
    <empty>

FIELDS:
  apiVersion    <string>
  kind          <string>
  metadata      <ObjectMeta>
  spec          <Object>
  status        <Object>
```

**Salida esperada del paso 5:**

```
GROUP:      example.com
KIND:       Widget
VERSION:    v1

FIELD: spec <Object>

DESCRIPTION:
    <empty>

FIELDS:
  color         <string> -required-
    Color del widget
  enabled       <boolean>
    Si el widget está activo
  size          <integer> -required-
    Tamaño del widget en unidades
  tags          <[]string>
    Etiquetas opcionales del widget
```

**Verificación:**

```bash
# Confirmar que kubectl reconoce el shortName
kubectl get wg -n lab-crd
# Debe devolver "No resources found in lab-crd namespace." (no error)
```

---

### Paso 4: Crear instancias de Custom Resources (Widgets)

**Objetivo:** Crear tres instancias de Widget con diferentes configuraciones para demostrar la creación de Custom Resources mediante manifiestos YAML correctamente tipados.

**Instrucciones:**

1. Crea el manifiesto con tres instancias de Widget:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/widgets.yaml
---
apiVersion: example.com/v1
kind: Widget
metadata:
  name: widget-frontend
  namespace: lab-crd
  labels:
    app: frontend
    tier: presentation
spec:
  color: blue
  size: 25
  enabled: true
  tags:
  - "ui"
  - "production"
  - "critical"
---
apiVersion: example.com/v1
kind: Widget
metadata:
  name: widget-backend
  namespace: lab-crd
  labels:
    app: backend
    tier: logic
spec:
  color: green
  size: 50
  enabled: true
  tags:
  - "api"
  - "production"
---
apiVersion: example.com/v1
kind: Widget
metadata:
  name: widget-legacy
  namespace: lab-crd
  labels:
    app: legacy
    tier: data
spec:
  color: red
  size: 10
  enabled: false
  tags:
  - "deprecated"
  - "maintenance"
EOF
```

2. Aplica los manifiestos:

```bash
kubectl apply -f ~/ckad-labs/lab06/widgets.yaml
```

3. Verifica la creación de las tres instancias:

```bash
kubectl get widgets -n lab-crd
```

**Salida esperada del paso 2:**

```
widget/widget-frontend created
widget/widget-backend created
widget/widget-legacy created
```

**Salida esperada del paso 3 (con columnas adicionales definidas en el CRD):**

```
NAME              COLOR   SIZE   ENABLED   AGE
widget-frontend   blue    25     true      10s
widget-backend    green   50     true      10s
widget-legacy     red     10     false     10s
```

**Verificación:**

```bash
# Verificar que hay exactamente 3 widgets
WIDGET_COUNT=$(kubectl get widgets -n lab-crd --no-headers | wc -l)
if [ "$WIDGET_COUNT" -eq 3 ]; then
  echo "OK: 3 widgets creados correctamente"
else
  echo "ERROR: Se esperaban 3 widgets, se encontraron $WIDGET_COUNT"
fi
```

---

### Paso 5: Inspeccionar y describir Custom Resources

**Objetivo:** Utilizar `kubectl describe` y `kubectl get -o yaml` para inspeccionar los detalles de los Custom Resources, demostrando que se gestionan de forma idéntica a los recursos nativos.

**Instrucciones:**

1. Describe el widget-frontend en detalle:

```bash
kubectl describe widget widget-frontend -n lab-crd
```

2. Obtén la representación YAML completa del widget-backend:

```bash
kubectl get widget widget-backend -n lab-crd -o yaml
```

3. Usa el shortName para listar widgets con formato wide:

```bash
kubectl get wg -n lab-crd -o wide
```

4. Filtra widgets por label:

```bash
kubectl get widgets -n lab-crd -l tier=production
```

5. Obtén un campo específico usando jsonpath:

```bash
kubectl get widget widget-frontend -n lab-crd -o jsonpath='{.spec.tags}' | jq .
```

6. Lista widgets con salida JSON filtrada:

```bash
kubectl get widgets -n lab-crd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.color}{"\t"}{.spec.size}{"\n"}{end}'
```

**Salida esperada del paso 1 (parcial):**

```
Name:         widget-frontend
Namespace:    lab-crd
Labels:       app=frontend
              tier=presentation
Annotations:  <none>
API Version:  example.com/v1
Kind:         Widget
Metadata:
  Creation Timestamp:  2024-XX-XXTXX:XX:XXZ
  ...
Spec:
  Color:    blue
  Enabled:  true
  Size:     25
  Tags:
    ui
    production
    critical
Events:  <none>
```

**Salida esperada del paso 6:**

```
widget-frontend	blue	25
widget-backend	green	50
widget-legacy	red	10
```

**Verificación:**

```bash
# Verificar que se puede acceder al recurso vía la API directamente
kubectl get --raw /apis/example.com/v1/namespaces/lab-crd/widgets | jq '.items | length'
# Debe devolver 3
```

---

### Paso 6: Actualizar un Custom Resource

**Objetivo:** Modificar campos de un Custom Resource existente usando `kubectl patch` y `kubectl apply`, demostrando que la validación del esquema OpenAPI se aplica en tiempo real.

**Instrucciones:**

1. Actualiza el tamaño del widget-legacy usando patch:

```bash
kubectl patch widget widget-legacy -n lab-crd --type='merge' -p '{"spec":{"size":15}}'
```

2. Verifica el cambio:

```bash
kubectl get widget widget-legacy -n lab-crd -o jsonpath='{.spec.size}'
echo ""
```

3. Habilita el widget-legacy cambiando `enabled` a `true`:

```bash
kubectl patch widget widget-legacy -n lab-crd --type='merge' -p '{"spec":{"enabled":true}}'
```

4. Verifica que la validación del esquema funciona intentando un valor inválido para color:

```bash
kubectl patch widget widget-legacy -n lab-crd --type='merge' -p '{"spec":{"color":"purple"}}'
```

5. Verifica que la validación de rango funciona intentando un tamaño fuera de límite:

```bash
kubectl patch widget widget-legacy -n lab-crd --type='merge' -p '{"spec":{"size":200}}'
```

6. Actualiza tags del widget-frontend usando apply con un manifiesto modificado:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/widget-frontend-updated.yaml
apiVersion: example.com/v1
kind: Widget
metadata:
  name: widget-frontend
  namespace: lab-crd
  labels:
    app: frontend
    tier: presentation
    version: "2.0"
spec:
  color: yellow
  size: 30
  enabled: true
  tags:
  - "ui"
  - "production"
  - "critical"
  - "updated"
EOF

kubectl apply -f ~/ckad-labs/lab06/widget-frontend-updated.yaml
```

7. Verifica el estado actualizado:

```bash
kubectl get widgets -n lab-crd
```

**Salida esperada del paso 1:**

```
widget/widget-legacy patched
```

**Salida esperada del paso 2:**

```
15
```

**Salida esperada del paso 4 (error de validación):**

```
The Widget "widget-legacy" is invalid: spec.color: Unsupported value: "purple": supported values: "red", "blue", "green", "yellow"
```

**Salida esperada del paso 5 (error de validación):**

```
The Widget "widget-legacy" is invalid: spec.size: Invalid value: 200: spec.size in body should be less than or equal to 100
```

**Salida esperada del paso 7:**

```
NAME              COLOR    SIZE   ENABLED   AGE
widget-frontend   yellow   30     true      3m
widget-backend    green    50     true      3m
widget-legacy     red      15     true      3m
```

**Verificación:**

```bash
# Confirmar que widget-frontend tiene el nuevo label
kubectl get widget widget-frontend -n lab-crd -o jsonpath='{.metadata.labels.version}'
echo ""
# Debe mostrar: 2.0
```

---

### Paso 7: Eliminar un Custom Resource

**Objetivo:** Eliminar una instancia de Custom Resource y verificar que Kubernetes gestiona el ciclo de vida completo del recurso personalizado.

**Instrucciones:**

1. Elimina el widget-legacy:

```bash
kubectl delete widget widget-legacy -n lab-crd
```

2. Verifica que solo quedan dos widgets:

```bash
kubectl get widgets -n lab-crd
```

3. Intenta describir el widget eliminado (debe fallar):

```bash
kubectl get widget widget-legacy -n lab-crd
```

4. Verifica la eliminación usando la API directa:

```bash
kubectl get --raw /apis/example.com/v1/namespaces/lab-crd/widgets | jq '.items[].metadata.name'
```

**Salida esperada del paso 1:**

```
widget "widget-legacy" deleted
```

**Salida esperada del paso 2:**

```
NAME              COLOR    SIZE   ENABLED   AGE
widget-frontend   yellow   30     true      5m
widget-backend    green    50     true      5m
```

**Salida esperada del paso 3:**

```
Error from server (NotFound): widgets.example.com "widget-legacy" not found
```

**Salida esperada del paso 4:**

```
"widget-frontend"
"widget-backend"
```

**Verificación:**

```bash
WIDGET_COUNT=$(kubectl get widgets -n lab-crd --no-headers | wc -l)
if [ "$WIDGET_COUNT" -eq 2 ]; then
  echo "OK: widget-legacy eliminado correctamente, quedan 2 widgets"
else
  echo "ERROR: Se esperaban 2 widgets, se encontraron $WIDGET_COUNT"
fi
```

---

### Paso 8: Explorar la relación CRD-Operador y el subrecurso status

**Objetivo:** Comprender cómo un operador (controlador) interactúa con Custom Resources mediante el subrecurso `status`, y observar la diferencia entre un CRD sin controlador y uno gestionado por un operador.

**Instrucciones:**

1. Observa que el campo status de los widgets está vacío (no hay operador que lo actualice):

```bash
kubectl get widget widget-frontend -n lab-crd -o jsonpath='{.status}'
echo ""
```

2. Intenta actualizar el status directamente (el subrecurso status requiere un endpoint separado):

```bash
kubectl patch widget widget-frontend -n lab-crd --type='merge' --subresource=status -p '{"status":{"state":"active","message":"Widget operativo"}}'
```

3. Verifica que el status se actualizó:

```bash
kubectl get widget widget-frontend -n lab-crd -o jsonpath='{.status}' | jq .
```

4. Observa la lista de CRDs instalados en el clúster para ver si hay otros CRDs de operadores:

```bash
kubectl get crds
```

5. Describe el CRD para ver sus condiciones y metadatos:

```bash
kubectl describe crd widgets.example.com | head -40
```

6. Explora las versiones servidas del CRD:

```bash
kubectl get crd widgets.example.com -o jsonpath='{.spec.versions[*].name}'
echo ""
```

**Salida esperada del paso 1:**

```
(vacío o {})
```

**Salida esperada del paso 3:**

```json
{
  "message": "Widget operativo",
  "state": "active"
}
```

**Salida esperada del paso 6:**

```
v1
```

**Verificación:**

```bash
# Verificar que el subrecurso status funciona independientemente del spec
STATE=$(kubectl get widget widget-frontend -n lab-crd -o jsonpath='{.status.state}')
if [ "$STATE" = "active" ]; then
  echo "OK: Subrecurso status funciona correctamente"
else
  echo "ERROR: Status no se actualizó correctamente"
fi
```

---

## Validación y Pruebas

Ejecuta el siguiente script de validación completa para confirmar que todos los objetivos del laboratorio se cumplieron:

```bash
#!/bin/bash
echo "=== Validación Final del Lab 04-00-06 ==="
echo ""

PASS=0
FAIL=0

# Test 1: CRD existe y está Established
echo -n "1. CRD widgets.example.com existe y está Established: "
STATUS=$(kubectl get crd widgets.example.com -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null)
if [ "$STATUS" = "True" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 2: API group registrado
echo -n "2. API group example.com/v1 registrado: "
if kubectl api-versions | grep -q "example.com/v1"; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 3: Recurso Widget aparece en api-resources
echo -n "3. Widget aparece en kubectl api-resources: "
if kubectl api-resources | grep -q "widgets"; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 4: Existen exactamente 2 widgets en lab-crd
echo -n "4. Existen 2 widgets en namespace lab-crd: "
COUNT=$(kubectl get widgets -n lab-crd --no-headers 2>/dev/null | wc -l)
if [ "$COUNT" -eq 2 ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (encontrados: $COUNT)"; ((FAIL++))
fi

# Test 5: widget-frontend tiene color yellow (actualizado)
echo -n "5. widget-frontend tiene color yellow: "
COLOR=$(kubectl get widget widget-frontend -n lab-crd -o jsonpath='{.spec.color}' 2>/dev/null)
if [ "$COLOR" = "yellow" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (color: $COLOR)"; ((FAIL++))
fi

# Test 6: widget-frontend tiene size 30
echo -n "6. widget-frontend tiene size 30: "
SIZE=$(kubectl get widget widget-frontend -n lab-crd -o jsonpath='{.spec.size}' 2>/dev/null)
if [ "$SIZE" = "30" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (size: $SIZE)"; ((FAIL++))
fi

# Test 7: widget-legacy fue eliminado
echo -n "7. widget-legacy no existe: "
if kubectl get widget widget-legacy -n lab-crd 2>&1 | grep -q "NotFound"; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 8: kubectl explain widget.spec funciona
echo -n "8. kubectl explain widget.spec funciona: "
if kubectl explain widget.spec 2>/dev/null | grep -q "color"; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 9: Validación de esquema funciona (color inválido rechazado)
echo -n "9. Validación de esquema rechaza valores inválidos: "
if kubectl patch widget widget-frontend -n lab-crd --type='merge' -p '{"spec":{"color":"purple"}}' 2>&1 | grep -q -i "invalid\|unsupported"; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 10: Subrecurso status tiene datos
echo -n "10. Subrecurso status de widget-frontend tiene state: "
STATE=$(kubectl get widget widget-frontend -n lab-crd -o jsonpath='{.status.state}' 2>/dev/null)
if [ "$STATE" = "active" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (state: $STATE)"; ((FAIL++))
fi

echo ""
echo "=== Resultado: $PASS/10 pruebas pasaron ==="
if [ "$FAIL" -eq 0 ]; then
  echo "✅ Laboratorio completado exitosamente"
else
  echo "⚠️  $FAIL prueba(s) fallaron - revisa los pasos anteriores"
fi
```

Guarda y ejecuta el script:

```bash
cat <<'SCRIPT' > ~/ckad-labs/lab06/validate.sh
# (pegar el contenido del script anterior)
SCRIPT
chmod +x ~/ckad-labs/lab06/validate.sh
bash ~/ckad-labs/lab06/validate.sh
```

---

## Solución de Problemas

### Problema 1: kubectl explain no muestra campos del spec

**Síntomas:**

```
$ kubectl explain widget.spec
error: couldn't find resource for "widget" in group ""
```

O bien `kubectl explain widget.spec` devuelve `<empty>` sin listar los campos.

**Causa:** Kubernetes necesita un breve momento para registrar el CRD en el discovery cache de kubectl. También puede ocurrir si el CRD no tiene un esquema OpenAPI v3 válido definido bajo `spec.versions[].schema.openAPIV3Schema`.

**Solución:**

```bash
# Invalidar el cache de discovery de kubectl
kubectl api-resources > /dev/null 2>&1

# Esperar unos segundos y reintentar
sleep 3
kubectl explain widget.spec

# Si persiste, verificar que el CRD tiene el esquema definido
kubectl get crd widgets.example.com -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties}' | jq 'keys'

# Si el esquema está vacío, re-aplicar el CRD
kubectl apply -f ~/ckad-labs/lab06/widget-crd.yaml
```

---

### Problema 2: Error "no matches for kind Widget in version example.com/v1" al crear instancias

**Síntomas:**

```
$ kubectl apply -f widgets.yaml
error: unable to recognize "widgets.yaml": no matches for kind "Widget" in version "example.com/v1"
```

**Causa:** El CRD no se ha instalado correctamente o aún no ha alcanzado la condición `Established`. Esto puede ocurrir si hubo un error de sintaxis en el manifiesto del CRD o si se aplicó en un namespace en lugar de a nivel de clúster.

**Solución:**

```bash
# Verificar si el CRD existe
kubectl get crd widgets.example.com

# Si no existe, verificar errores en el manifiesto y re-aplicar
kubectl apply -f ~/ckad-labs/lab06/widget-crd.yaml

# Si existe pero no está Established, verificar condiciones
kubectl get crd widgets.example.com -o jsonpath='{.status.conditions[*]}' | jq .

# Verificar que la condición NamesAccepted es True
kubectl get crd widgets.example.com -o jsonpath='{.status.conditions[?(@.type=="NamesAccepted")].status}'

# Si hay conflicto de nombres, verificar que no hay otro CRD con el mismo nombre
kubectl get crds | grep widget

# Esperar a que el CRD esté listo y reintentar
kubectl wait --for=condition=Established crd/widgets.example.com --timeout=30s
kubectl apply -f ~/ckad-labs/lab06/widgets.yaml
```

---

## Limpieza

El namespace `lab-crd` se mantiene activo como referencia según la especificación del laboratorio. Si deseas limpiar completamente:

```bash
# Eliminar todos los widgets del namespace
kubectl delete widgets --all -n lab-crd

# Restaurar el namespace por defecto del contexto
kubectl config set-context --current --namespace=ckad-dev

# (Opcional) Eliminar el CRD completamente - esto elimina TODAS las instancias en todos los namespaces
# kubectl delete crd widgets.example.com

# (Opcional) Eliminar el namespace
# kubectl delete namespace lab-crd

# Verificar que el contexto volvió al namespace estándar
kubectl config view --minify | grep namespace
```

> **Nota:** Eliminar un CRD elimina automáticamente todas las instancias de Custom Resources asociadas en todos los namespaces. Usa este comando con precaución en entornos compartidos.

---

## Resumen

En este laboratorio has aplicado los conceptos fundamentales de extensión de la API de Kubernetes mediante Custom Resource Definitions:

| Concepto | Comando/Acción Realizada |
|----------|--------------------------|
| Instalar un CRD | `kubectl apply -f widget-crd.yaml` |
| Verificar registro en API | `kubectl api-resources`, `kubectl api-versions` |
| Explorar esquema | `kubectl explain widget.spec` |
| Crear Custom Resources | `kubectl apply -f widgets.yaml` |
| Listar con columnas personalizadas | `kubectl get widgets` (additionalPrinterColumns) |
| Actualizar campos | `kubectl patch widget ... --type=merge` |
| Validación de esquema | OpenAPI v3 con enum, minimum, maximum |
| Eliminar instancias | `kubectl delete widget <nombre>` |
| Subrecurso status | `kubectl patch ... --subresource=status` |

### Conexión con la Configuración Externa

Los CRDs extienden el mismo modelo declarativo que Kubernetes usa para ConfigMaps y Secrets. Así como la configuración externa separa los datos del código (Lección 4.1), los CRDs separan la **definición de un recurso** de su **implementación**, permitiendo que operadores y controladores reaccionen a cambios declarativos en Custom Resources de la misma forma que el kubelet reacciona a cambios en Pods.

### Recursos Adicionales

- [Documentación oficial: Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Documentación oficial: CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)
- [Kubernetes API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
- [Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
