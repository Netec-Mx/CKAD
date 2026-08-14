# Construcción y ejecución de una aplicación en Pod

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Crear |
| **Módulo** | 2 — Anatomía de un Pod |

## Visión General

En este laboratorio construirás una imagen de contenedor personalizada basada en nginx:1.27.0 que sirve una aplicación web estática, la cargarás en el registro interno de minikube y la desplegarás como Pod en el namespace `ckad-dev`. Configurarás variables de entorno, almacenamiento persistente mediante PersistentVolume/PersistentVolumeClaim, y un volumen `emptyDir` compartido entre dos contenedores dentro del mismo Pod para demostrar la comunicación inter-contenedor descrita en la lección de anatomía de un Pod.

## Objetivos de Aprendizaje

- [ ] Construir una imagen Docker personalizada (`ckad-webapp:1.0.0`) basada en nginx:1.27.0 con contenido web estático
- [ ] Desplegar un Pod multi-contenedor con variables de entorno, comandos personalizados y argumentos configurados en el spec
- [ ] Crear un PersistentVolume (hostPath) y PersistentVolumeClaim, montándolos en el contenedor de aplicación
- [ ] Implementar un volumen `emptyDir` compartido entre dos contenedores para intercambio de datos efímeros
- [ ] Verificar el funcionamiento completo mediante `kubectl exec`, `kubectl logs` y `kubectl port-forward`

## Prerrequisitos

### Conocimientos Requeridos

| Tema | Detalle |
|------|---------|
| Kubectl básico | Comandos `apply`, `get`, `describe`, `exec`, `logs` |
| Manifiestos YAML | Estructura de cuatro campos raíz: `apiVersion`, `kind`, `metadata`, `spec` |
| Dockerfile | Instrucciones `FROM`, `COPY`, `RUN`, `EXPOSE`, `CMD` |
| Namespaces | Concepto y uso de `ckad-dev` como namespace de trabajo |

### Acceso Requerido

- Laboratorio 01-00-02 completado (namespace `ckad-dev` existente, contexto kubectl configurado)
- Directorio `~/ckad-labs/lab03/` existente
- Docker Engine 26.1.4 operativo
- Clúster minikube en ejecución

## Entorno de Laboratorio

### Software Necesario

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| Docker Engine | 26.1.4 | Construcción de imagen |
| minikube | 1.33.1 | Clúster Kubernetes local |
| kubectl | 1.30.2 | Gestión del clúster |
| nginx | 1.27.0 | Imagen base del contenedor |
| busybox | 1.36.1 | Contenedor sidecar |

### Configuración Inicial

Verifica que el entorno está listo antes de comenzar:

```bash
# Verificar que minikube está en ejecución
minikube status

# Verificar el namespace activo
kubectl config view --minify | grep namespace

# Confirmar que estamos en ckad-dev
# Si no aparece ckad-dev, configurarlo:
kubectl config set-context --current --namespace=ckad-dev

# Verificar que el directorio de trabajo existe
ls ~/ckad-labs/lab03/

# Posicionarse en el directorio de trabajo
cd ~/ckad-labs/lab03/
```

**Salida esperada** para `minikube status`:
```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

## Paso a Paso

### Paso 1: Crear el contenido web estático

**Objetivo:** Crear la página HTML que servirá la aplicación web personalizada.

**Instrucciones:**

1. Posiciónate en el directorio de trabajo:

```bash
cd ~/ckad-labs/lab03/
```

2. Crea el archivo `index.html` con el contenido de la aplicación:

```bash
cat <<'EOF' > index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CKAD Webapp</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; max-width: 600px; margin: 0 auto; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #326ce5; }
        .info { background: #e8f4fd; padding: 15px; border-radius: 4px; margin: 10px 0; }
        code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>CKAD Webapp v1.0.0</h1>
        <div class="info">
            <p><strong>Aplicación:</strong> ckad-webapp</p>
            <p><strong>Base:</strong> nginx:1.27.0</p>
            <p><strong>Namespace:</strong> ckad-dev</p>
        </div>
        <p>Pod desplegado correctamente en Kubernetes.</p>
    </div>
</body>
</html>
EOF
```

3. Crea un archivo de configuración nginx personalizado para exponer el puerto 8080:

```bash
cat <<'EOF' > nginx.conf
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    location /data {
        alias /usr/share/nginx/html/data;
        autoindex on;
    }

    location /shared {
        alias /usr/share/nginx/html/shared;
        autoindex on;
    }
}
EOF
```

**Verificación:**

```bash
ls -la ~/ckad-labs/lab03/
```

**Salida esperada:**
```
total 16
drwxr-xr-x 2 user user 4096 ... .
drwxr-xr-x 7 user user 4096 ... ..
-rw-r--r-- 1 user user  ... index.html
-rw-r--r-- 1 user user  ... nginx.conf
```

---

### Paso 2: Crear el Dockerfile y construir la imagen

**Objetivo:** Construir la imagen `ckad-webapp:1.0.0` basada en nginx:1.27.0 con el contenido web estático.

**Instrucciones:**

1. Crea el Dockerfile:

```bash
cat <<'EOF' > Dockerfile
# Imagen base oficial de nginx con versión fija
FROM nginx:1.27.0

# Metadatos de la imagen
LABEL maintainer="ckad-student"
LABEL version="1.0.0"
LABEL description="CKAD Webapp - Aplicación web estática para laboratorio"

# Eliminar configuración default de nginx
RUN rm -f /etc/nginx/conf.d/default.conf

# Copiar configuración personalizada de nginx
COPY nginx.conf /etc/nginx/conf.d/webapp.conf

# Copiar contenido web estático
COPY index.html /usr/share/nginx/html/index.html

# Crear directorios para volúmenes
RUN mkdir -p /usr/share/nginx/html/data && \
    mkdir -p /usr/share/nginx/html/shared && \
    chown -R nginx:nginx /usr/share/nginx/html/data && \
    chown -R nginx:nginx /usr/share/nginx/html/shared

# Puerto expuesto por el contenedor
EXPOSE 80

# Comando por defecto (heredado de nginx, se puede sobreescribir)
CMD ["nginx", "-g", "daemon off;"]
EOF
```

2. Construye la imagen con Docker:

```bash
docker build -t ckad-webapp:1.0.0 .
```

**Salida esperada:**
```
[+] Building 12.3s (10/10) FINISHED
 => [internal] load build definition from Dockerfile
 => [internal] load .dockerignore
 => [internal] load metadata for docker.io/library/nginx:1.27.0
 => [1/5] FROM docker.io/library/nginx:1.27.0
 => [2/5] RUN rm -f /etc/nginx/conf.d/default.conf
 => [3/5] COPY nginx.conf /etc/nginx/conf.d/webapp.conf
 => [4/5] COPY index.html /usr/share/nginx/html/index.html
 => [5/5] RUN mkdir -p /usr/share/nginx/html/data && ...
 => exporting to image
 => => naming to docker.io/library/ckad-webapp:1.0.0
```

3. Verifica que la imagen existe localmente:

```bash
docker images ckad-webapp
```

**Salida esperada:**
```
REPOSITORY   TAG     IMAGE ID       CREATED          SIZE
ckad-webapp  1.0.0   a1b2c3d4e5f6   10 seconds ago   187MB
```

**Verificación:**

```bash
# Prueba rápida local (opcional pero recomendada)
docker run --rm -d --name test-webapp -p 9090:80 ckad-webapp:1.0.0
curl -s http://localhost:9090 | grep "CKAD Webapp"
docker stop test-webapp
```

**Salida esperada del curl:**
```
        <h1>CKAD Webapp v1.0.0</h1>
```

---

### Paso 3: Cargar la imagen en minikube

**Objetivo:** Transferir la imagen `ckad-webapp:1.0.0` al registro interno de minikube para que los Pods puedan usarla.

**Instrucciones:**

1. Carga la imagen en minikube:

```bash
minikube image load ckad-webapp:1.0.0
```

> **Nota:** Este comando puede tardar 30-60 segundos dependiendo del tamaño de la imagen y la velocidad del disco.

2. Verifica que la imagen está disponible dentro de minikube:

```bash
minikube image list | grep ckad-webapp
```

**Salida esperada:**
```
docker.io/library/ckad-webapp:1.0.0
```

**Verificación:**

```bash
# Confirmar que la imagen se puede referenciar
minikube image list --format table | grep ckad-webapp
```

---

### Paso 4: Crear el PersistentVolume y PersistentVolumeClaim

**Objetivo:** Provisionar almacenamiento persistente usando hostPath que será montado en el Pod de aplicación.

**Instrucciones:**

1. Crea el manifiesto del PersistentVolume:

```bash
cat <<'EOF' > webapp-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: webapp-pv
  labels:
    type: local
    app: webapp
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/webapp"
EOF
```

2. Crea el manifiesto del PersistentVolumeClaim:

```bash
cat <<'EOF' > webapp-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: webapp-pvc
  namespace: ckad-dev
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

3. Aplica ambos manifiestos:

```bash
kubectl apply -f webapp-pv.yaml
kubectl apply -f webapp-pvc.yaml
```

**Salida esperada:**
```
persistentvolume/webapp-pv created
persistentvolumeclaim/webapp-pvc created
```

4. Verifica el estado del PV y PVC:

```bash
kubectl get pv webapp-pv
kubectl get pvc webapp-pvc -n ckad-dev
```

**Salida esperada:**
```
NAME        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                STORAGECLASS   AGE
webapp-pv   1Gi        RWO            Retain           Bound    ckad-dev/webapp-pvc   manual         10s

NAME         STATUS   VOLUME      CAPACITY   ACCESS MODES   STORAGECLASS   AGE
webapp-pvc   Bound    webapp-pv   1Gi        RWO            manual         8s
```

**Verificación:**

```bash
# El STATUS debe ser "Bound" en ambos
kubectl get pvc webapp-pvc -n ckad-dev -o jsonpath='{.status.phase}'
echo ""
```

**Salida esperada:**
```
Bound
```

---

### Paso 5: Crear el manifiesto del Pod multi-contenedor

**Objetivo:** Definir un Pod con dos contenedores (nginx + busybox sidecar), variables de entorno, el PVC montado y un volumen emptyDir compartido.

**Instrucciones:**

1. Crea el manifiesto completo del Pod:

```bash
cat <<'EOF' > webapp-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
  namespace: ckad-dev
  labels:
    app: webapp
    version: "1.0.0"
    environment: development
spec:
  # Definición de volúmenes disponibles para los contenedores
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: webapp-pvc
    - name: shared-data
      emptyDir: {}

  containers:
    # Contenedor principal: aplicación web nginx
    - name: webapp
      image: ckad-webapp:1.0.0
      imagePullPolicy: Never
      ports:
        - containerPort: 80
          name: http
          protocol: TCP
      env:
        - name: APP_ENV
          value: "development"
        - name: APP_VERSION
          value: "1.0.0"
      # Comando y argumentos que controlan el inicio
      command: ["nginx"]
      args: ["-g", "daemon off;"]
      volumeMounts:
        - name: persistent-storage
          mountPath: /usr/share/nginx/html/data
        - name: shared-data
          mountPath: /usr/share/nginx/html/shared

    # Contenedor sidecar: escribe datos en volumen compartido
    - name: sidecar-writer
      image: busybox:1.36.1
      imagePullPolicy: Never
      command: ["sh", "-c"]
      args:
        - |
          echo "Sidecar iniciado a las $(date)" > /shared-data/status.txt;
          echo "Entorno: $APP_ENV" >> /shared-data/status.txt;
          echo "Version: $APP_VERSION" >> /shared-data/status.txt;
          while true; do
            echo "Heartbeat: $(date)" >> /shared-data/heartbeat.log;
            sleep 30;
          done
      env:
        - name: APP_ENV
          value: "development"
        - name: APP_VERSION
          value: "1.0.0"
      volumeMounts:
        - name: shared-data
          mountPath: /shared-data

  restartPolicy: Always
EOF
```

**Puntos clave del manifiesto:**

| Campo | Propósito |
|-------|-----------|
| `imagePullPolicy: Never` | Usa la imagen cargada localmente en minikube, no intenta descargar de registro remoto |
| `command` + `args` | Sobreescribe el CMD del Dockerfile para control explícito del inicio |
| `env` | Variables de entorno inyectadas directamente en el spec del contenedor |
| `volumes[].persistentVolumeClaim` | Monta el PVC creado previamente |
| `volumes[].emptyDir` | Volumen temporal compartido entre contenedores |
| `volumeMounts` | Punto de montaje específico para cada contenedor |

**Verificación:**

```bash
# Validar sintaxis YAML antes de aplicar
kubectl apply -f webapp-pod.yaml --dry-run=client
```

**Salida esperada:**
```
pod/webapp-pod created (dry run)
```

---

### Paso 6: Cargar la imagen busybox en minikube y desplegar el Pod

**Objetivo:** Asegurar que ambas imágenes están disponibles en minikube y desplegar el Pod.

**Instrucciones:**

1. Descarga y carga la imagen busybox:1.36.1 en minikube:

```bash
docker pull busybox:1.36.1
minikube image load busybox:1.36.1
```

2. Verifica que ambas imágenes están disponibles:

```bash
minikube image list | grep -E "ckad-webapp|busybox"
```

**Salida esperada:**
```
docker.io/library/busybox:1.36.1
docker.io/library/ckad-webapp:1.0.0
```

3. Despliega el Pod:

```bash
kubectl apply -f webapp-pod.yaml
```

**Salida esperada:**
```
pod/webapp-pod created
```

4. Observa el estado del Pod hasta que esté Running:

```bash
kubectl get pod webapp-pod -n ckad-dev -w
```

**Salida esperada** (espera hasta ver `2/2 Running`):
```
NAME         READY   STATUS              RESTARTS   AGE
webapp-pod   0/2     ContainerCreating   0          3s
webapp-pod   2/2     Running             0          8s
```

Presiona `Ctrl+C` para salir del watch.

**Verificación:**

```bash
kgp webapp-pod
```

**Salida esperada:**
```
NAME         READY   STATUS    RESTARTS   AGE
webapp-pod   2/2     Running   0          30s
```

---

### Paso 7: Verificar variables de entorno y comandos

**Objetivo:** Confirmar que las variables de entorno y los comandos configurados en el spec están activos dentro de los contenedores.

**Instrucciones:**

1. Verifica las variables de entorno en el contenedor principal:

```bash
kubectl exec webapp-pod -c webapp -- env | grep -E "APP_ENV|APP_VERSION"
```

**Salida esperada:**
```
APP_ENV=development
APP_VERSION=1.0.0
```

2. Verifica las variables de entorno en el contenedor sidecar:

```bash
kubectl exec webapp-pod -c sidecar-writer -- env | grep -E "APP_ENV|APP_VERSION"
```

**Salida esperada:**
```
APP_ENV=development
APP_VERSION=1.0.0
```

3. Verifica el proceso principal del contenedor nginx:

```bash
kubectl exec webapp-pod -c webapp -- ps aux | head -5
```

**Salida esperada** (similar a):
```
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
   29 nginx     0:00 nginx: worker process
   ...
```

4. Inspecciona los detalles del Pod:

```bash
kubectl describe pod webapp-pod | grep -A 3 "Environment"
```

**Salida esperada:**
```
    Environment:
      APP_ENV:      development
      APP_VERSION:  1.0.0
--
    Environment:
      APP_ENV:      development
      APP_VERSION:  1.0.0
```

---

### Paso 8: Verificar el almacenamiento persistente (PVC)

**Objetivo:** Confirmar que el PersistentVolumeClaim está montado correctamente y es funcional.

**Instrucciones:**

1. Verifica que el volumen está montado en el contenedor webapp:

```bash
kubectl exec webapp-pod -c webapp -- df -h /usr/share/nginx/html/data
```

**Salida esperada** (los valores exactos pueden variar):
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        30G  5.2G   24G  18% /usr/share/nginx/html/data
```

2. Escribe un archivo en el volumen persistente:

```bash
kubectl exec webapp-pod -c webapp -- sh -c 'echo "Datos persistentes - $(date)" > /usr/share/nginx/html/data/test.txt'
```

3. Lee el archivo para confirmar la escritura:

```bash
kubectl exec webapp-pod -c webapp -- cat /usr/share/nginx/html/data/test.txt
```

**Salida esperada:**
```
Datos persistentes - Mon Jul 15 10:30:45 UTC 2024
```

4. Verifica el montaje en la descripción del Pod:

```bash
kubectl describe pod webapp-pod | grep -A 2 "persistent-storage"
```

**Salida esperada:**
```
      persistent-storage:
        Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
        ClaimName:  webapp-pvc
```

---

### Paso 9: Verificar el volumen emptyDir compartido

**Objetivo:** Demostrar que el contenedor sidecar escribe datos en el volumen `emptyDir` y el contenedor nginx puede leerlos.

**Instrucciones:**

1. Verifica que el sidecar ha escrito el archivo de estado:

```bash
kubectl exec webapp-pod -c sidecar-writer -- cat /shared-data/status.txt
```

**Salida esperada:**
```
Sidecar iniciado a las Mon Jul 15 10:30:40 UTC 2024
Entorno: development
Version: 1.0.0
```

2. Verifica el archivo de heartbeat:

```bash
kubectl exec webapp-pod -c sidecar-writer -- cat /shared-data/heartbeat.log
```

**Salida esperada** (al menos una línea):
```
Heartbeat: Mon Jul 15 10:30:40 UTC 2024
Heartbeat: Mon Jul 15 10:31:10 UTC 2024
```

3. **Punto clave:** Lee los mismos archivos desde el contenedor nginx (demuestra que comparten el volumen):

```bash
kubectl exec webapp-pod -c webapp -- cat /usr/share/nginx/html/shared/status.txt
```

**Salida esperada:**
```
Sidecar iniciado a las Mon Jul 15 10:30:40 UTC 2024
Entorno: development
Version: 1.0.0
```

4. Confirma que el directorio shared es accesible desde nginx:

```bash
kubectl exec webapp-pod -c webapp -- ls -la /usr/share/nginx/html/shared/
```

**Salida esperada:**
```
total 12
drwxrwxrwx 2 root root 4096 ... .
drwxr-xr-x 5 root root 4096 ... ..
-rw-r--r-- 1 root root  ... heartbeat.log
-rw-r--r-- 1 root root  ... status.txt
```

---

### Paso 10: Verificar acceso HTTP con port-forward

**Objetivo:** Exponer la aplicación web localmente y verificar que sirve contenido correctamente, incluyendo los datos del volumen compartido.

**Instrucciones:**

1. Inicia el port-forward en segundo plano (puerto reservado 8080):

```bash
kubectl port-forward pod/webapp-pod 8080:80 -n ckad-dev &
PF_PID=$!
echo "Port-forward PID: $PF_PID"
```

2. Espera un momento y verifica la página principal:

```bash
sleep 2
curl -s http://localhost:8080 | grep -E "CKAD Webapp|v1.0.0"
```

**Salida esperada:**
```
        <h1>CKAD Webapp v1.0.0</h1>
```

3. Verifica el acceso a los datos compartidos vía HTTP:

```bash
curl -s http://localhost:8080/shared/status.txt
```

**Salida esperada:**
```
Sidecar iniciado a las Mon Jul 15 10:30:40 UTC 2024
Entorno: development
Version: 1.0.0
```

4. Verifica el acceso a los datos persistentes vía HTTP:

```bash
curl -s http://localhost:8080/data/test.txt
```

**Salida esperada:**
```
Datos persistentes - Mon Jul 15 10:30:45 UTC 2024
```

5. Detén el port-forward:

```bash
kill $PF_PID 2>/dev/null
wait $PF_PID 2>/dev/null
```

---

## Validación y Testing

Ejecuta las siguientes verificaciones para confirmar que todo el laboratorio se completó correctamente:

```bash
echo "=== VALIDACIÓN COMPLETA DEL LABORATORIO 02-00-01 ==="
echo ""

# 1. Verificar imagen en minikube
echo "1. Imagen ckad-webapp:1.0.0 en minikube:"
minikube image list | grep ckad-webapp && echo "   ✓ PASS" || echo "   ✗ FAIL"
echo ""

# 2. Verificar PV
echo "2. PersistentVolume webapp-pv:"
kubectl get pv webapp-pv -o jsonpath='{.status.phase}' | grep -q "Bound" && echo "   ✓ PASS - Status: Bound" || echo "   ✗ FAIL"
echo ""

# 3. Verificar PVC
echo "3. PersistentVolumeClaim webapp-pvc:"
kubectl get pvc webapp-pvc -n ckad-dev -o jsonpath='{.status.phase}' | grep -q "Bound" && echo "   ✓ PASS - Status: Bound" || echo "   ✗ FAIL"
echo ""

# 4. Verificar Pod Running con 2 contenedores
echo "4. Pod webapp-pod (2/2 Running):"
READY=$(kubectl get pod webapp-pod -n ckad-dev -o jsonpath='{.status.containerStatuses[*].ready}')
if [ "$READY" = "true true" ]; then
    echo "   ✓ PASS - Ambos contenedores ready"
else
    echo "   ✗ FAIL - Ready: $READY"
fi
echo ""

# 5. Verificar variables de entorno
echo "5. Variables de entorno APP_ENV y APP_VERSION:"
ENV_CHECK=$(kubectl exec webapp-pod -c webapp -- env 2>/dev/null | grep -c -E "APP_ENV=development|APP_VERSION=1.0.0")
if [ "$ENV_CHECK" -eq 2 ]; then
    echo "   ✓ PASS - Ambas variables configuradas"
else
    echo "   ✗ FAIL - Variables encontradas: $ENV_CHECK/2"
fi
echo ""

# 6. Verificar volumen compartido
echo "6. Volumen emptyDir compartido (lectura cruzada):"
kubectl exec webapp-pod -c webapp -- cat /usr/share/nginx/html/shared/status.txt > /dev/null 2>&1 && echo "   ✓ PASS - Nginx lee datos del sidecar" || echo "   ✗ FAIL"
echo ""

# 7. Verificar volumen persistente
echo "7. Volumen persistente montado:"
kubectl exec webapp-pod -c webapp -- ls /usr/share/nginx/html/data/test.txt > /dev/null 2>&1 && echo "   ✓ PASS - Archivo persistente accesible" || echo "   ✗ FAIL"
echo ""

echo "=== FIN DE VALIDACIÓN ==="
```

**Salida esperada:**
```
=== VALIDACIÓN COMPLETA DEL LABORATORIO 02-00-01 ===

1. Imagen ckad-webapp:1.0.0 en minikube:
   ✓ PASS

2. PersistentVolume webapp-pv:
   ✓ PASS - Status: Bound

3. PersistentVolumeClaim webapp-pvc:
   ✓ PASS - Status: Bound

4. Pod webapp-pod (2/2 Running):
   ✓ PASS - Ambos contenedores ready

5. Variables de entorno APP_ENV y APP_VERSION:
   ✓ PASS - Ambas variables configuradas

6. Volumen emptyDir compartido (lectura cruzada):
   ✓ PASS - Nginx lee datos del sidecar

7. Volumen persistente montado:
   ✓ PASS - Archivo persistente accesible

=== FIN DE VALIDACIÓN ===
```

## Troubleshooting

### Problema 1: Pod en estado ImagePullBackOff o ErrImageNeverPull

**Síntomas:**
```
NAME         READY   STATUS              RESTARTS   AGE
webapp-pod   0/2     ErrImageNeverPull   0          15s
```

O bien:
```
NAME         READY   STATUS             RESTARTS   AGE
webapp-pod   0/2     ImagePullBackOff   0          30s
```

**Causa:** La imagen `ckad-webapp:1.0.0` no fue cargada correctamente en minikube, o se omitió `imagePullPolicy: Never` en el manifiesto. Cuando `imagePullPolicy` es `Never`, Kubernetes no intenta descargar la imagen de un registro remoto, pero si la imagen no existe localmente en el nodo, el Pod falla. Si no se especifica `imagePullPolicy: Never` y la imagen no tiene tag `latest`, Kubernetes intentará hacer pull desde Docker Hub donde la imagen no existe.

**Solución:**

```bash
# 1. Verificar que la imagen existe localmente en Docker
docker images ckad-webapp:1.0.0

# 2. Si no aparece, reconstruir
cd ~/ckad-labs/lab03/
docker build -t ckad-webapp:1.0.0 .

# 3. Cargar en minikube (puede requerir re-ejecución)
minikube image load ckad-webapp:1.0.0

# 4. Verificar que está en minikube
minikube image list | grep ckad-webapp

# 5. Eliminar el Pod fallido y recrear
kubectl delete pod webapp-pod -n ckad-dev
kubectl apply -f webapp-pod.yaml

# 6. Hacer lo mismo para busybox si es necesario
minikube image list | grep busybox || (docker pull busybox:1.36.1 && minikube image load busybox:1.36.1)
```

---

### Problema 2: PVC en estado Pending (no se vincula al PV)

**Síntomas:**
```
NAME         STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
webapp-pvc   Pending                                      manual         2m
```

El Pod queda en estado `Pending` con el evento:
```
Events:
  Warning  FailedScheduling  pod/webapp-pod  persistentvolumeclaim "webapp-pvc" not found
```

O bien el PVC existe pero no se vincula:
```
Events:
  Normal  WaitForFirstConsumer  persistentvolumeclaim/webapp-pvc  waiting for first consumer...
```

**Causa:** El PV y el PVC no coinciden en `storageClassName`, `accessModes` o `capacity`. Otra causa común es que el PV se creó en un namespace diferente (los PV son cluster-scoped, pero el PVC debe referenciar el storageClassName exacto). También puede ocurrir si se aplicó el PVC antes que el PV y el storageClass tiene `volumeBindingMode: WaitForFirstConsumer`.

**Solución:**

```bash
# 1. Verificar que el PV existe y su storageClassName
kubectl get pv webapp-pv -o yaml | grep -E "storageClassName|capacity|accessModes"

# 2. Verificar que el PVC solicita los mismos valores
kubectl get pvc webapp-pvc -n ckad-dev -o yaml | grep -E "storageClassName|storage|accessModes"

# 3. Si no coinciden, eliminar y recrear con valores correctos
kubectl delete pvc webapp-pvc -n ckad-dev
kubectl delete pv webapp-pv

# 4. Asegurar que ambos usan storageClassName: manual
kubectl apply -f webapp-pv.yaml
kubectl apply -f webapp-pvc.yaml

# 5. Verificar vinculación
kubectl get pv webapp-pv
kubectl get pvc webapp-pvc -n ckad-dev

# 6. Si el Pod estaba pendiente, eliminarlo y recrear
kubectl delete pod webapp-pod -n ckad-dev --ignore-not-found
kubectl apply -f webapp-pod.yaml
```

## Limpieza

Ejecuta los siguientes comandos para eliminar todos los recursos creados en este laboratorio:

```bash
# Eliminar el Pod
kubectl delete pod webapp-pod -n ckad-dev

# Eliminar el PVC (debe hacerse antes de eliminar el PV)
kubectl delete pvc webapp-pvc -n ckad-dev

# Eliminar el PV
kubectl delete pv webapp-pv

# Verificar que no quedan recursos
kubectl get pods -n ckad-dev
kubectl get pvc -n ckad-dev
kubectl get pv | grep webapp

# Opcional: eliminar la imagen de minikube (no recomendado si se usará en labs posteriores)
# minikube image rm docker.io/library/ckad-webapp:1.0.0
```

> **Nota:** No elimines la imagen `ckad-webapp:1.0.0` de minikube ni de Docker local, ya que se reutilizará en laboratorios posteriores (02-00-02 y 02-00-03).

## Resumen

En este laboratorio has completado el ciclo completo de construcción y despliegue de una aplicación en un Pod de Kubernetes:

| Concepto | Lo que practicaste |
|----------|-------------------|
| **Dockerfile + Build** | Creaste una imagen personalizada `ckad-webapp:1.0.0` basada en nginx:1.27.0 |
| **minikube image load** | Transferiste la imagen al registro interno del clúster local |
| **Variables de entorno** | Configuraste `APP_ENV` y `APP_VERSION` directamente en el spec del Pod |
| **command + args** | Controlaste el comportamiento de inicio sobreescribiendo el CMD de la imagen |
| **PersistentVolume/PVC** | Provisionaste almacenamiento persistente con hostPath y storageClass manual |
| **emptyDir** | Implementaste comunicación inter-contenedor mediante volumen temporal compartido |
| **Pod multi-contenedor** | Desplegaste un patrón sidecar con nginx + busybox cooperando en el mismo Pod |
| **port-forward** | Verificaste el acceso HTTP a la aplicación en puerto local 8080 |

### Relación con la Lección

Este laboratorio aplica directamente los conceptos de la lección 2.1 (Anatomía de un Pod):
- Los cuatro campos raíz del manifiesto (`apiVersion`, `kind`, `metadata`, `spec`)
- La comunicación entre contenedores del mismo Pod vía volúmenes compartidos
- La definición de `spec.containers` con imagen, comandos, variables de entorno y montajes
- La declaración de volúmenes en `spec.volumes` y su referencia en `volumeMounts`

### Recursos Adicionales

- [Kubernetes Docs: Volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Kubernetes Docs: Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Kubernetes Docs: Multi-container Pods](https://kubernetes.io/docs/concepts/workloads/pods/#how-pods-manage-multiple-containers)
- [Docker Docs: Dockerfile reference](https://docs.docker.com/engine/reference/builder/)
- [minikube Docs: Pushing images](https://minikube.sigs.k8s.io/docs/handbook/pushing/)

---

# Diseño de Pod con init container

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Crear |
| **Namespace** | ckad-dev |
| **Directorio de trabajo** | ~/ckad-labs/lab04/ |

## Descripción General

En este laboratorio diseñarás un Pod con múltiples init containers que realizan tareas de preparación antes de que el contenedor principal arranque. Implementarás comunicación entre init containers y el contenedor principal mediante un volumen `emptyDir` compartido, observarás el ciclo de vida secuencial de los init containers en tiempo real, y diagnosticarás el comportamiento del Pod cuando un init container falla.

## Objetivos de Aprendizaje

- [ ] Diseñar un Pod con init containers que ejecuten tareas de preparación obligatorias antes del arranque del contenedor principal
- [ ] Implementar comunicación entre init container y contenedor principal mediante un volumen emptyDir compartido
- [ ] Observar y comprender las transiciones de estado del Pod durante la ejecución secuencial de init containers
- [ ] Diagnosticar y recuperar un Pod cuando un init container falla intencionalmente
- [ ] Aplicar variables de entorno y argumentos de comando en init containers para parametrizar la lógica de inicialización

## Prerrequisitos

### Conocimientos Requeridos

| Conocimiento | Fuente |
|---|---|
| Estructura YAML de un Pod (apiVersion, kind, metadata, spec) | Lección 2.1 |
| Volúmenes emptyDir y montaje con volumeMounts | Lab 02-00-01 |
| Comandos kubectl logs, kubectl describe, kubectl exec | Lab 02-00-01 |
| Ciclo de vida de un Pod: Pending → Running → Succeeded/Failed | Lección 2.1 |

### Acceso y Recursos

- Clúster minikube en ejecución con imagen `ckad-webapp:1.0.0` cargada
- Namespace `ckad-dev` configurado como default en el contexto kubectl
- Aliases de kubectl activos (`k`, `kgp`, `kd`)

## Entorno del Laboratorio

### Software Requerido

| Herramienta | Versión | Propósito |
|---|---|---|
| minikube | 1.33.1 | Clúster Kubernetes local |
| kubectl | 1.30.2 | Gestión del clúster |
| Kubernetes | 1.30.x | Plataforma de orquestación |

### Imágenes de Contenedor

| Imagen | Uso |
|---|---|
| `ckad-webapp:1.0.0` | Contenedor principal (Nginx personalizado) |
| `busybox:1.36.1` | Init containers |

### Preparación del Entorno

```bash
# Verificar que minikube está en ejecución
minikube status

# Verificar namespace activo
kubectl config view --minify | grep namespace

# Verificar que la imagen ckad-webapp:1.0.0 está disponible
minikube image list | grep ckad-webapp

# Crear directorio de trabajo si no existe
mkdir -p ~/ckad-labs/lab04
cd ~/ckad-labs/lab04
```

## Paso a Paso

### Paso 1: Crear el Pod con un init container básico

**Objetivo:** Crear un manifiesto YAML con un Pod que incluya un init container (`init-config`) que genera un archivo HTML dinámico en un volumen compartido, y un contenedor principal que sirve ese archivo.

**Instrucciones:**

1. Cambia al directorio de trabajo:

```bash
cd ~/ckad-labs/lab04
```

2. Crea el archivo de manifiesto `webapp-init-pod.yaml`:

```bash
cat <<'EOF' > webapp-init-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-init-pod
  namespace: ckad-dev
  labels:
    app: webapp-init
    lab: "02-00-02"
spec:
  volumes:
    - name: html-volume
      emptyDir: {}

  initContainers:
    - name: init-config
      image: busybox:1.36.1
      env:
        - name: APP_VERSION
          value: "1.0.0"
        - name: ENVIRONMENT
          value: "development"
      command: ["sh", "-c"]
      args:
        - |
          echo "=== Init container init-config iniciando ==="
          echo "Generando archivo de configuracion..."
          cat > /init-data/index.html <<HTMLCONTENT
          <!DOCTYPE html>
          <html>
          <head><title>CKAD Lab 02-00-02</title></head>
          <body>
          <h1>Pod con Init Container</h1>
          <p>Fecha de generacion: $(date)</p>
          <p>Hostname: $(hostname)</p>
          <p>App Version: ${APP_VERSION}</p>
          <p>Environment: ${ENVIRONMENT}</p>
          </body>
          </html>
          HTMLCONTENT
          echo "Archivo index.html generado exitosamente en /init-data/"
          ls -la /init-data/
          echo "=== Init container init-config finalizado ==="
      volumeMounts:
        - name: html-volume
          mountPath: /init-data

  containers:
    - name: webapp
      image: ckad-webapp:1.0.0
      imagePullPolicy: Never
      ports:
        - containerPort: 80
          name: http
      volumeMounts:
        - name: html-volume
          mountPath: /usr/share/nginx/html
EOF
```

3. Aplica el manifiesto:

```bash
kubectl apply -f webapp-init-pod.yaml
```

4. Observa la creación del Pod:

```bash
kubectl get pod webapp-init-pod -n ckad-dev -w
```

Presiona `Ctrl+C` cuando el Pod alcance el estado `Running`.

**Salida esperada:**

```
NAME              READY   STATUS     RESTARTS   AGE
webapp-init-pod   0/1     Init:0/1   0          2s
webapp-init-pod   0/1     PodInitializing   0   3s
webapp-init-pod   1/1     Running    0          4s
```

**Verificación:**

```bash
# Verificar que el Pod está Running
kubectl get pod webapp-init-pod -n ckad-dev -o wide

# Verificar logs del init container
kubectl logs webapp-init-pod -n ckad-dev -c init-config
```

La salida de logs debe mostrar el mensaje "Archivo index.html generado exitosamente".

---

### Paso 2: Validar la comunicación entre init container y contenedor principal

**Objetivo:** Confirmar que el contenedor principal sirve correctamente el archivo HTML generado por el init container a través del volumen compartido.

**Instrucciones:**

1. Realiza un port-forward al Pod:

```bash
kubectl port-forward pod/webapp-init-pod 8081:80 -n ckad-dev &
```

2. Espera 2 segundos y verifica el contenido servido:

```bash
sleep 2
curl -s http://localhost:8081
```

3. Verifica que el contenido incluye las variables de entorno inyectadas:

```bash
curl -s http://localhost:8081 | grep -E "(App Version|Environment|Fecha|Hostname)"
```

4. Detén el port-forward:

```bash
kill %1 2>/dev/null
```

**Salida esperada:**

```html
<p>App Version: 1.0.0</p>
<p>Environment: development</p>
<p>Fecha de generacion: Mon Jun 10 14:30:00 UTC 2024</p>
<p>Hostname: webapp-init-pod</p>
```

**Verificación:**

```bash
# Verificar directamente dentro del contenedor principal
kubectl exec webapp-init-pod -n ckad-dev -c webapp -- cat /usr/share/nginx/html/index.html
```

El archivo debe existir y contener el HTML generado por `init-config`.

---

### Paso 3: Eliminar el Pod y añadir un segundo init container con espera de servicio

**Objetivo:** Rediseñar el Pod con dos init containers secuenciales: `init-wait` (verifica disponibilidad DNS) e `init-config` (genera configuración), demostrando la ejecución ordenada.

**Instrucciones:**

1. Elimina el Pod actual:

```bash
kubectl delete pod webapp-init-pod -n ckad-dev
```

2. Crea el manifiesto actualizado con dos init containers:

```bash
cat <<'EOF' > webapp-init-pod-v2.yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-init-pod
  namespace: ckad-dev
  labels:
    app: webapp-init
    lab: "02-00-02"
    version: v2
spec:
  volumes:
    - name: html-volume
      emptyDir: {}

  initContainers:
    - name: init-wait
      image: busybox:1.36.1
      command: ["sh", "-c"]
      args:
        - |
          echo "=== Init container init-wait iniciando ==="
          echo "Esperando disponibilidad del servicio DNS del cluster..."
          RETRIES=0
          MAX_RETRIES=10
          until nslookup kube-dns.kube-system.svc.cluster.local > /dev/null 2>&1; do
            RETRIES=$((RETRIES + 1))
            if [ $RETRIES -ge $MAX_RETRIES ]; then
              echo "ERROR: Timeout esperando servicio DNS despues de $MAX_RETRIES intentos"
              exit 1
            fi
            echo "Intento $RETRIES/$MAX_RETRIES - DNS no disponible, reintentando en 2s..."
            sleep 2
          done
          echo "Servicio DNS verificado exitosamente tras $RETRIES reintentos"
          echo "=== Init container init-wait finalizado ==="

    - name: init-config
      image: busybox:1.36.1
      env:
        - name: APP_VERSION
          value: "2.0.0"
        - name: ENVIRONMENT
          value: "development"
        - name: INIT_TIMESTAMP
          value: "generated-at-runtime"
      command: ["sh", "-c"]
      args:
        - |
          echo "=== Init container init-config iniciando ==="
          TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
          cat > /init-data/index.html <<HTMLCONTENT
          <!DOCTYPE html>
          <html>
          <head><title>CKAD Lab 02-00-02 - v2</title></head>
          <body>
          <h1>Pod con Init Containers Secuenciales</h1>
          <hr>
          <h2>Informacion del Pod</h2>
          <ul>
            <li><strong>Hostname:</strong> $(hostname)</li>
            <li><strong>Fecha de generacion:</strong> ${TIMESTAMP}</li>
            <li><strong>App Version:</strong> ${APP_VERSION}</li>
            <li><strong>Environment:</strong> ${ENVIRONMENT}</li>
          </ul>
          <h2>Init Containers Ejecutados</h2>
          <ol>
            <li>init-wait: Verificacion DNS completada</li>
            <li>init-config: Archivo HTML generado</li>
          </ol>
          </body>
          </html>
          HTMLCONTENT
          echo "Archivo generado con timestamp: ${TIMESTAMP}"
          echo "=== Init container init-config finalizado ==="
      volumeMounts:
        - name: html-volume
          mountPath: /init-data

  containers:
    - name: webapp
      image: ckad-webapp:1.0.0
      imagePullPolicy: Never
      ports:
        - containerPort: 80
          name: http
      volumeMounts:
        - name: html-volume
          mountPath: /usr/share/nginx/html
EOF
```

3. Aplica el nuevo manifiesto y observa en tiempo real:

```bash
kubectl apply -f webapp-init-pod-v2.yaml
```

4. En la misma terminal, observa las transiciones de estado:

```bash
kubectl get pod webapp-init-pod -n ckad-dev -w
```

Presiona `Ctrl+C` cuando alcance `Running`.

**Salida esperada:**

```
NAME              READY   STATUS     RESTARTS   AGE
webapp-init-pod   0/1     Init:0/2   0          1s
webapp-init-pod   0/1     Init:1/2   0          5s
webapp-init-pod   0/1     PodInitializing   0   7s
webapp-init-pod   1/1     Running    0          8s
```

Observa las transiciones: `Init:0/2` → `Init:1/2` → `PodInitializing` → `Running`. Esto demuestra que los init containers se ejecutan secuencialmente.

**Verificación:**

```bash
# Verificar logs de init-wait
echo "--- Logs de init-wait ---"
kubectl logs webapp-init-pod -n ckad-dev -c init-wait

# Verificar logs de init-config
echo "--- Logs de init-config ---"
kubectl logs webapp-init-pod -n ckad-dev -c init-config

# Verificar estado del Pod
kubectl get pod webapp-init-pod -n ckad-dev
```

---

### Paso 4: Inspeccionar el ciclo de vida con kubectl describe

**Objetivo:** Analizar los eventos del Pod para comprender la secuencia exacta de ejecución de los init containers y el contenedor principal.

**Instrucciones:**

1. Ejecuta describe sobre el Pod:

```bash
kubectl describe pod webapp-init-pod -n ckad-dev
```

2. Identifica las siguientes secciones en la salida:

```bash
# Filtrar la sección de Init Containers
kubectl describe pod webapp-init-pod -n ckad-dev | grep -A 20 "Init Containers:"

# Filtrar los eventos
kubectl describe pod webapp-init-pod -n ckad-dev | grep -A 30 "Events:"
```

3. Verifica que ambos init containers muestran estado `Terminated` con razón `Completed`:

```bash
kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.status.initContainerStatuses[*].name}' && echo ""
kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.status.initContainerStatuses[0].state}' && echo ""
kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.status.initContainerStatuses[1].state}' && echo ""
```

**Salida esperada:**

La sección de eventos debe mostrar una secuencia similar a:

```
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  30s   default-scheduler  Successfully assigned ckad-dev/webapp-init-pod to minikube
  Normal  Pulled     29s   kubelet            Container image "busybox:1.36.1" already present on machine
  Normal  Created    29s   kubelet            Created container init-wait
  Normal  Started    29s   kubelet            Started container init-wait
  Normal  Pulled     25s   kubelet            Container image "busybox:1.36.1" already present on machine
  Normal  Created    25s   kubelet            Created container init-config
  Normal  Started    25s   kubelet            Started container init-config
  Normal  Pulled     23s   kubelet            Container image "ckad-webapp:1.0.0" already present on machine
  Normal  Created    23s   kubelet            Created container webapp
  Normal  Started    23s   kubelet            Started container webapp
```

Los init containers muestran estado `Terminated` con razón `Completed` y exit code `0`:

```json
{"terminated":{"exitCode":0,"reason":"Completed"}}
```

**Verificación:**

```bash
# Confirmar exit codes de ambos init containers
kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{range .status.initContainerStatuses[*]}{.name}: exitCode={.state.terminated.exitCode}, reason={.state.terminated.reason}{"\n"}{end}'
```

Salida esperada:

```
init-wait: exitCode=0, reason=Completed
init-config: exitCode=0, reason=Completed
```

---

### Paso 5: Simular fallo en un init container

**Objetivo:** Crear un Pod con un init container que falla intencionalmente para observar cómo Kubernetes maneja el error y bloquea el arranque del contenedor principal.

**Instrucciones:**

1. Elimina el Pod actual:

```bash
kubectl delete pod webapp-init-pod -n ckad-dev
```

2. Crea un manifiesto con un init container que falla:

```bash
cat <<'EOF' > webapp-init-pod-fail.yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-init-pod
  namespace: ckad-dev
  labels:
    app: webapp-init
    lab: "02-00-02"
    version: fail-test
spec:
  volumes:
    - name: html-volume
      emptyDir: {}

  initContainers:
    - name: init-wait
      image: busybox:1.36.1
      command: ["sh", "-c"]
      args:
        - |
          echo "=== Init container init-wait iniciando ==="
          echo "Este init container completara exitosamente"
          sleep 2
          echo "=== Init container init-wait finalizado ==="

    - name: init-fail
      image: busybox:1.36.1
      command: ["sh", "-c"]
      args:
        - |
          echo "=== Init container init-fail iniciando ==="
          echo "Simulando un fallo critico de inicializacion..."
          echo "ERROR: No se puede conectar al servicio de configuracion externo"
          sleep 2
          exit 1

    - name: init-config
      image: busybox:1.36.1
      command: ["sh", "-c"]
      args:
        - |
          echo "=== Init container init-config iniciando ==="
          echo "Este init container NUNCA deberia ejecutarse"
          echo "=== Init container init-config finalizado ==="
      volumeMounts:
        - name: html-volume
          mountPath: /init-data

  containers:
    - name: webapp
      image: ckad-webapp:1.0.0
      imagePullPolicy: Never
      ports:
        - containerPort: 80
          name: http
      volumeMounts:
        - name: html-volume
          mountPath: /usr/share/nginx/html
EOF
```

3. Aplica el manifiesto:

```bash
kubectl apply -f webapp-init-pod-fail.yaml
```

4. Observa el comportamiento del Pod durante 30 segundos:

```bash
kubectl get pod webapp-init-pod -n ckad-dev -w
```

Presiona `Ctrl+C` después de observar al menos un reinicio del init container fallido.

**Salida esperada:**

```
NAME              READY   STATUS       RESTARTS   AGE
webapp-init-pod   0/1     Init:0/3     0          1s
webapp-init-pod   0/1     Init:1/3     0          4s
webapp-init-pod   0/1     Init:1/3     0          7s
webapp-init-pod   0/1     Init:1/3     1 (2s ago) 9s
webapp-init-pod   0/1     Init:1/3     2 (2s ago) 12s
```

Observa que el Pod permanece en `Init:1/3` y el contador de RESTARTS aumenta. El init container `init-config` (tercero) nunca se ejecuta.

5. Verifica los logs del init container que falla:

```bash
kubectl logs webapp-init-pod -n ckad-dev -c init-fail
```

6. Confirma que `init-config` no se ha ejecutado:

```bash
kubectl logs webapp-init-pod -n ckad-dev -c init-config 2>&1
```

**Salida esperada del comando anterior:**

```
Error from server (BadRequest): container "init-config" in pod "webapp-init-pod" is waiting to start: PodInitializing
```

7. Inspecciona el estado detallado:

```bash
kubectl describe pod webapp-init-pod -n ckad-dev | grep -A 5 "init-fail"
```

**Verificación:**

```bash
# Verificar que el Pod no alcanza Running
POD_STATUS=$(kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.status.phase}')
echo "Estado del Pod: $POD_STATUS"

# Verificar que init-fail tiene exit code 1
kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.status.initContainerStatuses[1].lastState.terminated.exitCode}' && echo ""
```

El estado del Pod debe ser `Pending` y el exit code de `init-fail` debe ser `1`.

---

### Paso 6: Recuperar el Pod corrigiendo el init container

**Objetivo:** Eliminar el Pod fallido y desplegar una versión corregida que demuestre la recuperación exitosa.

**Instrucciones:**

1. Elimina el Pod fallido:

```bash
kubectl delete pod webapp-init-pod -n ckad-dev
```

2. Crea la versión corregida (sin el init container que falla):

```bash
cat <<'EOF' > webapp-init-pod-fixed.yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-init-pod
  namespace: ckad-dev
  labels:
    app: webapp-init
    lab: "02-00-02"
    version: fixed
spec:
  volumes:
    - name: html-volume
      emptyDir: {}

  initContainers:
    - name: init-wait
      image: busybox:1.36.1
      command: ["sh", "-c"]
      args:
        - |
          echo "=== Init container init-wait iniciando ==="
          echo "Verificando disponibilidad DNS..."
          until nslookup kube-dns.kube-system.svc.cluster.local > /dev/null 2>&1; do
            echo "Esperando DNS..."
            sleep 1
          done
          echo "DNS disponible"
          echo "=== Init container init-wait finalizado ==="

    - name: init-config
      image: busybox:1.36.1
      env:
        - name: APP_VERSION
          value: "2.0.1-fixed"
        - name: ENVIRONMENT
          value: "development"
      command: ["sh", "-c"]
      args:
        - |
          echo "=== Init container init-config iniciando ==="
          TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
          cat > /init-data/index.html <<HTMLCONTENT
          <!DOCTYPE html>
          <html>
          <head><title>CKAD Lab 02-00-02 - Fixed</title></head>
          <body>
          <h1>Pod Recuperado Exitosamente</h1>
          <hr>
          <h2>Informacion del Pod</h2>
          <ul>
            <li><strong>Hostname:</strong> $(hostname)</li>
            <li><strong>Fecha de generacion:</strong> ${TIMESTAMP}</li>
            <li><strong>App Version:</strong> ${APP_VERSION}</li>
            <li><strong>Environment:</strong> ${ENVIRONMENT}</li>
            <li><strong>Estado:</strong> Init container problematico eliminado</li>
          </ul>
          <h2>Init Containers Ejecutados</h2>
          <ol>
            <li>init-wait: Verificacion DNS completada</li>
            <li>init-config: Archivo HTML generado correctamente</li>
          </ol>
          </body>
          </html>
          HTMLCONTENT
          echo "Archivo generado exitosamente"
          echo "=== Init container init-config finalizado ==="
      volumeMounts:
        - name: html-volume
          mountPath: /init-data

  containers:
    - name: webapp
      image: ckad-webapp:1.0.0
      imagePullPolicy: Never
      ports:
        - containerPort: 80
          name: http
      volumeMounts:
        - name: html-volume
          mountPath: /usr/share/nginx/html
EOF
```

3. Aplica y verifica:

```bash
kubectl apply -f webapp-init-pod-fixed.yaml
kubectl wait --for=condition=Ready pod/webapp-init-pod -n ckad-dev --timeout=60s
```

4. Confirma el funcionamiento completo:

```bash
kubectl port-forward pod/webapp-init-pod 8081:80 -n ckad-dev &
sleep 2
curl -s http://localhost:8081 | grep -E "(Recuperado|App Version|Estado)"
kill %1 2>/dev/null
```

**Salida esperada:**

```html
<h1>Pod Recuperado Exitosamente</h1>
<li><strong>App Version:</strong> 2.0.1-fixed</li>
<li><strong>Estado:</strong> Init container problematico eliminado</li>
```

**Verificación:**

```bash
# Verificar Pod Running con 0 restarts
kubectl get pod webapp-init-pod -n ckad-dev
```

El Pod debe estar en estado `Running` con `RESTARTS` en `0`.

---

## Verificación Final del Laboratorio

Ejecuta el siguiente script para validar que todos los objetivos se han cumplido:

```bash
echo "============================================"
echo "  VERIFICACIÓN FINAL - Lab 02-00-02"
echo "============================================"
echo ""

PASS=0
FAIL=0

# Test 1: Pod Running
echo -n "[TEST 1] Pod webapp-init-pod en estado Running: "
STATUS=$(kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$STATUS" = "Running" ]; then
  echo "PASS ✓"
  PASS=$((PASS + 1))
else
  echo "FAIL ✗ (Estado actual: $STATUS)"
  FAIL=$((FAIL + 1))
fi

# Test 2: Tiene 2 init containers
echo -n "[TEST 2] Pod tiene 2 init containers: "
INIT_COUNT=$(kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.spec.initContainers}' | jq length 2>/dev/null)
if [ "$INIT_COUNT" = "2" ]; then
  echo "PASS ✓"
  PASS=$((PASS + 1))
else
  echo "FAIL ✗ (Encontrados: $INIT_COUNT)"
  FAIL=$((FAIL + 1))
fi

# Test 3: Init containers completados con exit code 0
echo -n "[TEST 3] Ambos init containers completados (exit code 0): "
EXIT1=$(kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.status.initContainerStatuses[0].state.terminated.exitCode}' 2>/dev/null)
EXIT2=$(kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.status.initContainerStatuses[1].state.terminated.exitCode}' 2>/dev/null)
if [ "$EXIT1" = "0" ] && [ "$EXIT2" = "0" ]; then
  echo "PASS ✓"
  PASS=$((PASS + 1))
else
  echo "FAIL ✗ (Exit codes: $EXIT1, $EXIT2)"
  FAIL=$((FAIL + 1))
fi

# Test 4: Volumen emptyDir compartido
echo -n "[TEST 4] Volumen emptyDir html-volume configurado: "
VOL=$(kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.spec.volumes[0].name}' 2>/dev/null)
if [ "$VOL" = "html-volume" ]; then
  echo "PASS ✓"
  PASS=$((PASS + 1))
else
  echo "FAIL ✗ (Volumen encontrado: $VOL)"
  FAIL=$((FAIL + 1))
fi

# Test 5: Contenido HTML servido correctamente
echo -n "[TEST 5] Contenido HTML generado por init container presente: "
CONTENT=$(kubectl exec webapp-init-pod -n ckad-dev -c webapp -- cat /usr/share/nginx/html/index.html 2>/dev/null)
if echo "$CONTENT" | grep -q "App Version"; then
  echo "PASS ✓"
  PASS=$((PASS + 1))
else
  echo "FAIL ✗ (Contenido no encontrado)"
  FAIL=$((FAIL + 1))
fi

# Test 6: Variables de entorno utilizadas
echo -n "[TEST 6] Variables de entorno reflejadas en HTML: "
if echo "$CONTENT" | grep -q "2.0.1-fixed"; then
  echo "PASS ✓"
  PASS=$((PASS + 1))
else
  echo "FAIL ✗ (Version no encontrada en HTML)"
  FAIL=$((FAIL + 1))
fi

# Test 7: Pod sin restarts
echo -n "[TEST 7] Pod sin restarts (0): "
RESTARTS=$(kubectl get pod webapp-init-pod -n ckad-dev -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
if [ "$RESTARTS" = "0" ]; then
  echo "PASS ✓"
  PASS=$((PASS + 1))
else
  echo "FAIL ✗ (Restarts: $RESTARTS)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "============================================"
echo "  RESULTADOS: $PASS/7 tests pasados"
echo "============================================"

if [ $FAIL -eq 0 ]; then
  echo "  ¡LABORATORIO COMPLETADO EXITOSAMENTE! ✓"
else
  echo "  Laboratorio incompleto. Revisa los tests fallidos."
fi
echo "============================================"
```

## Limpieza

```bash
# Eliminar todos los recursos del laboratorio
kubectl delete pod webapp-init-pod -n ckad-dev --ignore-not-found=true

# Verificar limpieza
kubectl get pods -n ckad-dev -l lab=02-00-02

# Limpiar archivos de manifiesto (opcional)
# rm -f ~/ckad-labs/lab04/webapp-init-pod*.yaml
```

## Resumen de Conceptos Clave

| Concepto | Descripción |
|---|---|
| **Init Containers** | Contenedores que se ejecutan hasta completarse antes de que arranquen los contenedores principales del Pod |
| **Ejecución Secuencial** | Los init containers se ejecutan uno a uno en orden; si uno falla, se reintenta antes de continuar |
| **Volumen emptyDir** | Volumen efímero que permite compartir datos entre init containers y contenedores principales |
| **Estado Init:N/M** | Indica que N de M init containers han completado exitosamente |
| **Fallo de Init Container** | Bloquea el arranque del Pod; Kubernetes reintenta con backoff exponencial |
| **Variables de Entorno en Init** | Permiten parametrizar la lógica de inicialización sin modificar la imagen |

## Troubleshooting Común

| Problema | Causa | Solución |
|---|---|---|
| Pod en `Init:0/2` indefinidamente | Primer init container no completa | `kubectl logs <pod> -c init-wait` para diagnosticar |
| Pod en `Init:CrashLoopBackOff` | Init container falla repetidamente | Verificar exit code con `kubectl describe pod` |
| HTML vacío en contenedor principal | Rutas de volumeMount no coinciden | Verificar que mountPath del init y del contenedor principal comparten el mismo volumen |
| `ImagePullBackOff` en init container | Imagen no disponible en el nodo | Verificar con `minikube image list` |
| Port-forward no responde | Pod no está en Running | Esperar a que todos los init containers completen |

---

# Diseño de Pod con patrón sidecar

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 50 minutos |
| **Complejidad** | Alta |
| **Nivel Bloom** | Crear |
| **Directorio de trabajo** | `~/ckad-labs/lab05/` |
| **Namespace principal** | `ckad-dev` |
| **Namespace secundario** | `ckad-staging` |

## Descripción General

En este laboratorio implementarás el patrón sidecar desplegando un Pod con tres contenedores: un contenedor principal (`ckad-webapp:1.0.0`) que genera logs de acceso, un sidecar de logging (`log-collector`) que procesa esos logs en tiempo real, y un segundo sidecar (`metrics-exporter`) que simula la exportación de métricas. Utilizarás volúmenes `emptyDir` compartidos para la comunicación entre contenedores y Kustomize para gestionar variantes del Pod en los namespaces `ckad-dev` y `ckad-staging`. El laboratorio cierra con una comparación documentada de los patrones init container, sidecar y contenedor único.

## Objetivos de Aprendizaje

- [ ] Implementar el patrón sidecar con un contenedor auxiliar de logging que extiende la funcionalidad del contenedor principal sin modificar su imagen
- [ ] Configurar múltiples volúmenes `emptyDir` compartidos para comunicación entre contenedores dentro del mismo Pod
- [ ] Diseñar comunicación `localhost` entre contenedores del mismo Pod para un proxy sidecar básico
- [ ] Aplicar Kustomize 5.4.2 con estructura base/overlays para gestionar variantes del Pod sidecar en múltiples namespaces
- [ ] Evaluar y documentar criterios de diseño para elegir entre sidecar, init container y contenedor único

## Prerrequisitos

### Conocimientos Previos

| Requisito | Referencia |
|-----------|------------|
| Pods multi-contenedor y ciclo de vida de init containers | Lab 02-00-02 |
| Volúmenes `emptyDir` y montaje en contenedores | Lab 02-00-01 / Lab 02-00-02 |
| Namespaces `ckad-dev` y `ckad-staging` configurados | Lab 01-00-02 |
| Estructura YAML de un Pod (apiVersion, kind, metadata, spec) | Lección 2.1 |

### Acceso y Herramientas

| Herramienta | Versión | Verificación |
|-------------|---------|--------------|
| minikube | 1.33.1 | `minikube status` |
| kubectl | 1.30.2 | `kubectl version --client` |
| kustomize | 5.4.2 | `kustomize version` |
| Imagen `ckad-webapp:1.0.0` | Local en minikube | `minikube image list \| grep ckad-webapp` |
| Imagen `busybox:1.36.1` | Docker Hub | `minikube image list \| grep busybox` |

## Entorno del Laboratorio

### Verificación Inicial

```bash
# Verificar que minikube está corriendo
minikube status

# Verificar namespace activo
kubectl config view --minify | grep namespace

# Verificar que los namespaces existen
kubectl get ns ckad-dev ckad-staging

# Verificar imagen ckad-webapp disponible
minikube image list | grep ckad-webapp

# Verificar kustomize
kustomize version

# Crear directorio de trabajo si no existe
mkdir -p ~/ckad-labs/lab05
cd ~/ckad-labs/lab05
```

### Estructura de Directorios Objetivo

```
~/ckad-labs/lab05/
├── webapp-sidecar-pod.yaml
├── kustomize/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   └── webapp-sidecar-pod.yaml
│   └── overlays/
│       ├── dev/
│       │   ├── kustomization.yaml
│       │   └── patch-dev.yaml
│       └── staging/
│           ├── kustomization.yaml
│           └── patch-staging.yaml
└── comparacion-patrones.md
```

## Paso a Paso

### Paso 1: Diseñar el Pod con sidecar de logging

**Objetivo:** Crear el manifiesto YAML del Pod `webapp-sidecar-pod` con el contenedor principal y el sidecar `log-collector` que comparten un volumen para logs.

**Instrucciones:**

1. Navega al directorio de trabajo:

```bash
cd ~/ckad-labs/lab05
```

2. Crea el manifiesto base del Pod con el contenedor principal y el primer sidecar:

```bash
cat > webapp-sidecar-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: webapp-sidecar-pod
  namespace: ckad-dev
  labels:
    app: webapp-sidecar
    pattern: sidecar
    env: dev
spec:
  volumes:
    - name: log-volume
      emptyDir: {}
    - name: metrics-volume
      emptyDir: {}

  containers:
    # Contenedor principal: webapp que genera access logs
    - name: webapp
      image: ckad-webapp:1.0.0
      imagePullPolicy: Never
      ports:
        - containerPort: 80
          name: http
      volumeMounts:
        - name: log-volume
          mountPath: /var/log/nginx

    # Sidecar 1: recopila y formatea logs con timestamp
    - name: log-collector
      image: busybox:1.36.1
      command:
        - sh
        - -c
        - |
          echo "[log-collector] Iniciando tail de access.log..."
          # Esperar a que el archivo de log exista
          while [ ! -f /var/log/nginx/access.log ]; do
            sleep 1
          done
          # Procesar logs añadiendo timestamp formateado
          tail -f /var/log/nginx/access.log | while read line; do
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${line}"
          done
      volumeMounts:
        - name: log-volume
          mountPath: /var/log/nginx
          readOnly: true

    # Sidecar 2: simula exportación de métricas
    - name: metrics-exporter
      image: busybox:1.36.1
      command:
        - sh
        - -c
        - |
          echo "[metrics-exporter] Iniciando generación de métricas..."
          while true; do
            TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%SZ')
            RANDOM_REQUESTS=$((RANDOM % 100 + 1))
            RANDOM_LATENCY=$((RANDOM % 500 + 10))
            cat > /metrics/metrics.json << METRICS
          {
            "timestamp": "${TIMESTAMP}",
            "container": "webapp",
            "metrics": {
              "requests_total": ${RANDOM_REQUESTS},
              "avg_latency_ms": ${RANDOM_LATENCY},
              "status": "healthy",
              "uptime_seconds": $(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
            }
          }
          METRICS
            sleep 10
          done
      volumeMounts:
        - name: metrics-volume
          mountPath: /metrics

  restartPolicy: Always
EOF
```

3. Revisa la estructura del manifiesto:

```bash
cat webapp-sidecar-pod.yaml
```

**Salida esperada:**

El archivo YAML debe mostrar un Pod con tres contenedores (`webapp`, `log-collector`, `metrics-exporter`) y dos volúmenes (`log-volume`, `metrics-volume`).

**Verificación:**

```bash
# Validar sintaxis YAML sin aplicar
kubectl apply --dry-run=client -f webapp-sidecar-pod.yaml
```

Salida esperada:
```
pod/webapp-sidecar-pod created (dry run)
```

### Paso 2: Desplegar el Pod y verificar contenedores

**Objetivo:** Aplicar el manifiesto al clúster y confirmar que los tres contenedores arrancan correctamente.

**Instrucciones:**

1. Aplica el manifiesto:

```bash
kubectl apply -f webapp-sidecar-pod.yaml
```

2. Espera a que todos los contenedores estén en estado Running:

```bash
kubectl wait --for=condition=Ready pod/webapp-sidecar-pod -n ckad-dev --timeout=60s
```

3. Verifica el estado del Pod mostrando todos los contenedores:

```bash
kubectl get pod webapp-sidecar-pod -n ckad-dev -o wide
```

4. Inspecciona los detalles de cada contenedor:

```bash
kubectl describe pod webapp-sidecar-pod -n ckad-dev | grep -A 5 "Container ID"
```

**Salida esperada:**

```
NAME                 READY   STATUS    RESTARTS   AGE   IP           NODE
webapp-sidecar-pod   3/3     Running   0          30s   172.17.x.x   minikube
```

El campo `READY` debe mostrar `3/3`, indicando que los tres contenedores están listos.

**Verificación:**

```bash
# Confirmar que los tres contenedores están corriendo
kubectl get pod webapp-sidecar-pod -n ckad-dev -o jsonpath='{.status.containerStatuses[*].name}' && echo
```

Salida esperada:
```
webapp log-collector metrics-exporter
```

```bash
# Verificar que todos están en estado running
kubectl get pod webapp-sidecar-pod -n ckad-dev -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state.running.startedAt}{"\n"}{end}'
```

### Paso 3: Validar el sidecar de logging

**Objetivo:** Generar tráfico hacia el contenedor principal y verificar que el sidecar `log-collector` procesa y formatea los logs correctamente.

**Instrucciones:**

1. Inicia un port-forward al contenedor webapp en el puerto 8082:

```bash
kubectl port-forward pod/webapp-sidecar-pod 8082:80 -n ckad-dev &
PF_PID=$!
sleep 2
```

2. Genera tráfico HTTP hacia la webapp:

```bash
# Realizar múltiples peticiones para generar logs
for i in $(seq 1 5); do
  curl -s http://localhost:8082/ > /dev/null
  sleep 1
done
```

3. Verifica los logs del contenedor principal:

```bash
kubectl logs webapp-sidecar-pod -c webapp -n ckad-dev --tail=5
```

4. Verifica los logs formateados del sidecar `log-collector`:

```bash
kubectl logs webapp-sidecar-pod -c log-collector -n ckad-dev --tail=10
```

5. Detén el port-forward:

```bash
kill $PF_PID 2>/dev/null
```

**Salida esperada:**

Los logs del `log-collector` deben mostrar las peticiones con timestamp formateado:
```
[log-collector] Iniciando tail de access.log...
[2024-01-15 10:30:45] 127.0.0.1 - - [15/Jan/2024:10:30:45 +0000] "GET / HTTP/1.1" 200 ...
[2024-01-15 10:30:46] 127.0.0.1 - - [15/Jan/2024:10:30:46 +0000] "GET / HTTP/1.1" 200 ...
```

**Verificación:**

```bash
# Confirmar que log-collector tiene salida con timestamps
kubectl logs webapp-sidecar-pod -c log-collector -n ckad-dev | grep -c "^\[20"
```

El resultado debe ser mayor que 0, indicando que hay líneas con timestamp procesadas.

### Paso 4: Validar el sidecar de métricas

**Objetivo:** Verificar que el sidecar `metrics-exporter` genera correctamente el archivo JSON de métricas en el volumen compartido.

**Instrucciones:**

1. Lee el archivo de métricas generado por el sidecar:

```bash
kubectl exec webapp-sidecar-pod -c metrics-exporter -n ckad-dev -- cat /metrics/metrics.json
```

2. Valida que el JSON tiene la estructura esperada:

```bash
kubectl exec webapp-sidecar-pod -c metrics-exporter -n ckad-dev -- cat /metrics/metrics.json | jq .
```

3. Espera 10 segundos y verifica que las métricas se actualizan:

```bash
sleep 12
kubectl exec webapp-sidecar-pod -c metrics-exporter -n ckad-dev -- cat /metrics/metrics.json | jq '.timestamp'
```

**Salida esperada:**

```json
{
  "timestamp": "2024-01-15T10:31:00Z",
  "container": "webapp",
  "metrics": {
    "requests_total": 42,
    "avg_latency_ms": 235,
    "status": "healthy",
    "uptime_seconds": 120
  }
}
```

**Verificación:**

```bash
# Verificar que el archivo existe y tiene contenido válido
kubectl exec webapp-sidecar-pod -c metrics-exporter -n ckad-dev -- \
  sh -c 'test -f /metrics/metrics.json && echo "OK: metrics.json existe" || echo "ERROR: no existe"'
```

### Paso 5: Verificar comunicación localhost entre contenedores

**Objetivo:** Demostrar que todos los contenedores del Pod comparten la misma interfaz de red y pueden comunicarse vía `localhost`.

**Instrucciones:**

1. Desde el sidecar `log-collector`, realiza una petición HTTP al contenedor webapp usando localhost:

```bash
kubectl exec webapp-sidecar-pod -c log-collector -n ckad-dev -- \
  wget -qO- http://localhost:80/ 2>/dev/null | head -5
```

2. Desde el sidecar `metrics-exporter`, verifica la conectividad al puerto 80:

```bash
kubectl exec webapp-sidecar-pod -c metrics-exporter -n ckad-dev -- \
  wget -qO- --timeout=5 http://localhost:80/ 2>/dev/null | head -3
```

3. Verifica que todos los contenedores comparten la misma IP:

```bash
# IP vista desde webapp
kubectl exec webapp-sidecar-pod -c webapp -n ckad-dev -- hostname -i

# IP vista desde log-collector
kubectl exec webapp-sidecar-pod -c log-collector -n ckad-dev -- hostname -i

# IP vista desde metrics-exporter
kubectl exec webapp-sidecar-pod -c metrics-exporter -n ckad-dev -- hostname -i
```

**Salida esperada:**

Las tres ejecuciones de `hostname -i` deben devolver la misma dirección IP (por ejemplo, `172.17.0.5`), confirmando que comparten el namespace de red.

**Verificación:**

```bash
# Comparar IPs - deben ser idénticas
IP_WEBAPP=$(kubectl exec webapp-sidecar-pod -c webapp -n ckad-dev -- hostname -i)
IP_COLLECTOR=$(kubectl exec webapp-sidecar-pod -c log-collector -n ckad-dev -- hostname -i)
IP_METRICS=$(kubectl exec webapp-sidecar-pod -c metrics-exporter -n ckad-dev -- hostname -i)

echo "webapp: $IP_WEBAPP"
echo "log-collector: $IP_COLLECTOR"
echo "metrics-exporter: $IP_METRICS"

if [ "$IP_WEBAPP" = "$IP_COLLECTOR" ] && [ "$IP_WEBAPP" = "$IP_METRICS" ]; then
  echo "✓ CORRECTO: Todos los contenedores comparten la misma IP"
else
  echo "✗ ERROR: Las IPs no coinciden"
fi
```

### Paso 6: Configurar estructura Kustomize base

**Objetivo:** Crear la estructura Kustomize con un manifiesto base del Pod sidecar que será reutilizado por los overlays de dev y staging.

**Instrucciones:**

1. Crea la estructura de directorios:

```bash
mkdir -p ~/ckad-labs/lab05/kustomize/{base,overlays/dev,overlays/staging}
```

2. Crea el manifiesto base (sin namespace ni etiquetas de entorno específicas):

```bash
cat > ~/ckad-labs/lab05/kustomize/base/webapp-sidecar-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: webapp-sidecar-pod
  labels:
    app: webapp-sidecar
    pattern: sidecar
spec:
  volumes:
    - name: log-volume
      emptyDir: {}
    - name: metrics-volume
      emptyDir: {}

  containers:
    - name: webapp
      image: ckad-webapp:1.0.0
      imagePullPolicy: Never
      ports:
        - containerPort: 80
          name: http
      volumeMounts:
        - name: log-volume
          mountPath: /var/log/nginx

    - name: log-collector
      image: busybox:1.36.1
      command:
        - sh
        - -c
        - |
          while [ ! -f /var/log/nginx/access.log ]; do sleep 1; done
          tail -f /var/log/nginx/access.log | while read line; do
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${line}"
          done
      volumeMounts:
        - name: log-volume
          mountPath: /var/log/nginx
          readOnly: true

    - name: metrics-exporter
      image: busybox:1.36.1
      command:
        - sh
        - -c
        - |
          while true; do
            cat > /metrics/metrics.json << METRICS
          {"timestamp":"$(date -u '+%Y-%m-%dT%H:%M:%SZ')","requests_total":$((RANDOM % 100)),"status":"healthy"}
          METRICS
            sleep 10
          done
      volumeMounts:
        - name: metrics-volume
          mountPath: /metrics

  restartPolicy: Always
EOF
```

3. Crea el archivo `kustomization.yaml` de la base:

```bash
cat > ~/ckad-labs/lab05/kustomize/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - webapp-sidecar-pod.yaml

commonLabels:
  managed-by: kustomize
EOF
```

**Verificación:**

```bash
# Verificar que kustomize puede procesar la base
kustomize build ~/ckad-labs/lab05/kustomize/base/ | head -20
```

### Paso 7: Crear overlay de desarrollo (dev)

**Objetivo:** Crear el overlay de Kustomize para el namespace `ckad-dev` con etiqueta `env=dev`.

**Instrucciones:**

1. Crea el archivo de patch para dev:

```bash
cat > ~/ckad-labs/lab05/kustomize/overlays/dev/patch-dev.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: webapp-sidecar-pod
  labels:
    env: dev
    tier: development
  annotations:
    description: "Pod sidecar para entorno de desarrollo"
spec:
  containers:
    - name: webapp
      env:
        - name: APP_ENV
          value: "development"
        - name: LOG_LEVEL
          value: "debug"
EOF
```

2. Crea el `kustomization.yaml` del overlay dev:

```bash
cat > ~/ckad-labs/lab05/kustomize/overlays/dev/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ckad-dev

resources:
  - ../../base

patches:
  - path: patch-dev.yaml
    target:
      kind: Pod
      name: webapp-sidecar-pod
EOF
```

3. Verifica la salida del overlay dev:

```bash
kustomize build ~/ckad-labs/lab05/kustomize/overlays/dev/
```

**Salida esperada:**

El manifiesto generado debe incluir `namespace: ckad-dev`, la etiqueta `env: dev`, y las variables de entorno `APP_ENV=development` y `LOG_LEVEL=debug` en el contenedor webapp.

**Verificación:**

```bash
# Verificar que el namespace es correcto
kustomize build ~/ckad-labs/lab05/kustomize/overlays/dev/ | grep "namespace:"

# Verificar que la etiqueta env está presente
kustomize build ~/ckad-labs/lab05/kustomize/overlays/dev/ | grep "env:"
```

### Paso 8: Crear overlay de staging

**Objetivo:** Crear el overlay de Kustomize para el namespace `ckad-staging` con etiqueta `env=staging` y variable `APP_ENV=staging`.

**Instrucciones:**

1. Crea el archivo de patch para staging:

```bash
cat > ~/ckad-labs/lab05/kustomize/overlays/staging/patch-staging.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: webapp-sidecar-pod
  labels:
    env: staging
    tier: pre-production
  annotations:
    description: "Pod sidecar para entorno de staging"
spec:
  containers:
    - name: webapp
      env:
        - name: APP_ENV
          value: "staging"
        - name: LOG_LEVEL
          value: "info"
    - name: log-collector
      resources:
        requests:
          memory: "32Mi"
          cpu: "50m"
        limits:
          memory: "64Mi"
          cpu: "100m"
    - name: metrics-exporter
      resources:
        requests:
          memory: "32Mi"
          cpu: "50m"
        limits:
          memory: "64Mi"
          cpu: "100m"
EOF
```

2. Crea el `kustomization.yaml` del overlay staging:

```bash
cat > ~/ckad-labs/lab05/kustomize/overlays/staging/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ckad-staging

resources:
  - ../../base

patches:
  - path: patch-staging.yaml
    target:
      kind: Pod
      name: webapp-sidecar-pod
EOF
```

3. Verifica la salida del overlay staging:

```bash
kustomize build ~/ckad-labs/lab05/kustomize/overlays/staging/
```

**Salida esperada:**

El manifiesto generado debe incluir `namespace: ckad-staging`, la etiqueta `env: staging`, la variable `APP_ENV=staging`, y los límites de recursos en los sidecars.

**Verificación:**

```bash
# Verificar namespace staging
kustomize build ~/ckad-labs/lab05/kustomize/overlays/staging/ | grep "namespace:"

# Verificar que tiene resource limits
kustomize build ~/ckad-labs/lab05/kustomize/overlays/staging/ | grep -A 2 "limits:"
```

### Paso 9: Aplicar overlays y verificar despliegue

**Objetivo:** Desplegar el Pod sidecar en ambos namespaces usando Kustomize y verificar que las variantes son correctas.

**Instrucciones:**

1. Elimina el Pod original desplegado manualmente (del Paso 2):

```bash
kubectl delete pod webapp-sidecar-pod -n ckad-dev --ignore-not-found
```

2. Aplica el overlay de dev:

```bash
kustomize build ~/ckad-labs/lab05/kustomize/overlays/dev/ | kubectl apply -f -
```

3. Aplica el overlay de staging:

```bash
kustomize build ~/ckad-labs/lab05/kustomize/overlays/staging/ | kubectl apply -f -
```

4. Espera a que ambos Pods estén listos:

```bash
kubectl wait --for=condition=Ready pod/webapp-sidecar-pod -n ckad-dev --timeout=60s
kubectl wait --for=condition=Ready pod/webapp-sidecar-pod -n ckad-staging --timeout=60s
```

5. Verifica ambos Pods:

```bash
echo "=== Pod en ckad-dev ==="
kubectl get pod webapp-sidecar-pod -n ckad-dev --show-labels

echo ""
echo "=== Pod en ckad-staging ==="
kubectl get pod webapp-sidecar-pod -n ckad-staging --show-labels
```

**Salida esperada:**

```
=== Pod en ckad-dev ===
NAME                 READY   STATUS    RESTARTS   AGE   LABELS
webapp-sidecar-pod   3/3     Running   0          15s   app=webapp-sidecar,env=dev,managed-by=kustomize,...

=== Pod en ckad-staging ===
NAME                 READY   STATUS    RESTARTS   AGE   LABELS
webapp-sidecar-pod   3/3     Running   0          10s   app=webapp-sidecar,env=staging,managed-by=kustomize,...
```

**Verificación:**

```bash
# Verificar variable APP_ENV en dev
kubectl exec webapp-sidecar-pod -c webapp -n ckad-dev -- env | grep APP_ENV

# Verificar variable APP_ENV en staging
kubectl exec webapp-sidecar-pod -c webapp -n ckad-staging -- env | grep APP_ENV

# Verificar resource limits en staging (solo staging tiene limits)
kubectl get pod webapp-sidecar-pod -n ckad-staging -o jsonpath='{.spec.containers[?(@.name=="log-collector")].resources.limits}' && echo
```

Salida esperada para dev:
```
APP_ENV=development
```

Salida esperada para staging:
```
APP_ENV=staging
```

### Paso 10: Documentar comparación de patrones

**Objetivo:** Crear un documento que compare los tres patrones de diseño de Pod (init container, sidecar, contenedor único) con criterios de decisión claros.

**Instrucciones:**

1. Crea el documento de comparación:

```bash
cat > ~/ckad-labs/lab05/comparacion-patrones.md << 'EOF'
# Comparación de Patrones de Diseño de Pod

## 1. Contenedor Único (Single Container)

**Cuándo usarlo:**
- La aplicación es autosuficiente y no requiere procesos auxiliares
- No se necesita procesamiento de logs separado ni proxies
- Simplicidad es prioritaria sobre modularidad

**Características:**
- Un solo proceso principal por Pod
- Menor consumo de recursos
- Depuración más sencilla
- Ejemplo: API REST simple, worker de cola de mensajes

**Limitaciones:**
- Toda la lógica debe estar en una sola imagen
- Cambios en funcionalidad auxiliar requieren rebuild de la imagen principal

---

## 2. Init Container

**Cuándo usarlo:**
- Se necesita preparar el entorno ANTES de que arranque la aplicación principal
- Descargar configuraciones, esperar dependencias, migrar base de datos
- La tarea auxiliar debe completarse una sola vez y terminar

**Características:**
- Se ejecutan secuencialmente ANTES de los contenedores principales
- Deben completarse exitosamente (exit 0) para que el Pod continúe
- Comparten volúmenes con los contenedores principales
- No se ejecutan durante la vida del Pod

**Limitaciones:**
- No pueden proporcionar funcionalidad continua (solo ejecución única)
- Aumentan el tiempo de arranque del Pod
- Si fallan, bloquean todo el Pod

**Ejemplo del curso:** Lab 02-00-02 - init container que prepara archivos de configuración

---

## 3. Sidecar

**Cuándo usarlo:**
- Se necesita funcionalidad continua que complementa al contenedor principal
- Logging, monitoreo, proxy, sincronización de datos en tiempo real
- Se quiere mantener la imagen principal sin modificaciones (separación de responsabilidades)

**Características:**
- Se ejecutan en PARALELO con el contenedor principal
- Comparten red (localhost) y pueden compartir volúmenes
- Ciclo de vida ligado al Pod completo
- Permiten composición modular de funcionalidades

**Limitaciones:**
- Mayor consumo de recursos (CPU/RAM por cada sidecar)
- Complejidad adicional en debugging (múltiples streams de logs)
- No hay garantía de orden de arranque entre contenedores principales

**Ejemplo del curso:** Este laboratorio - log-collector y metrics-exporter

---

## Tabla Comparativa Resumen

| Criterio | Contenedor Único | Init Container | Sidecar |
|----------|-----------------|----------------|---------|
| Ejecución | Continua | Una vez (antes) | Continua (paralelo) |
| Modifica imagen principal | Sí | No | No |
| Comparte red | N/A | No (termina antes) | Sí (localhost) |
| Comparte volúmenes | N/A | Sí | Sí |
| Uso de recursos | Mínimo | Temporal | Permanente |
| Caso típico | App simple | Setup/migración | Logging/proxy/metrics |
| Complejidad operativa | Baja | Media | Alta |

---

## Criterios de Decisión

1. ¿La tarea auxiliar necesita ejecutarse continuamente? → **Sidecar**
2. ¿La tarea auxiliar solo necesita ejecutarse una vez al inicio? → **Init Container**
3. ¿No hay tareas auxiliares? → **Contenedor Único**
4. ¿Se necesita comunicación en tiempo real entre procesos? → **Sidecar** (localhost)
5. ¿Se quiere evitar modificar la imagen de la aplicación? → **Init Container o Sidecar**
EOF
```

2. Revisa el documento:

```bash
cat ~/ckad-labs/lab05/comparacion-patrones.md
```

**Verificación:**

```bash
# Verificar que el archivo existe y tiene contenido sustancial
wc -l ~/ckad-labs/lab05/comparacion-patrones.md
```

El archivo debe tener al menos 70 líneas de contenido.

## Validación y Testing

Ejecuta el siguiente script de validación integral para confirmar que todos los objetivos del laboratorio se han cumplido:

```bash
#!/bin/bash
echo "=========================================="
echo "  VALIDACIÓN INTEGRAL - Lab 02-00-03"
echo "=========================================="
echo ""

PASS=0
FAIL=0

# Test 1: Pod en ckad-dev con 3 contenedores Running
echo "[Test 1] Pod webapp-sidecar-pod en ckad-dev con 3/3 Ready"
READY=$(kubectl get pod webapp-sidecar-pod -n ckad-dev -o jsonpath='{.status.containerStatuses[?(@.ready==true)].name}' 2>/dev/null | wc -w)
if [ "$READY" -eq 3 ]; then
  echo "  ✓ PASS: 3 contenedores Ready"
  ((PASS++))
else
  echo "  ✗ FAIL: Solo $READY contenedores Ready"
  ((FAIL++))
fi

# Test 2: Pod en ckad-staging con 3 contenedores Running
echo "[Test 2] Pod webapp-sidecar-pod en ckad-staging con 3/3 Ready"
READY=$(kubectl get pod webapp-sidecar-pod -n ckad-staging -o jsonpath='{.status.containerStatuses[?(@.ready==true)].name}' 2>/dev/null | wc -w)
if [ "$READY" -eq 3 ]; then
  echo "  ✓ PASS: 3 contenedores Ready"
  ((PASS++))
else
  echo "  ✗ FAIL: Solo $READY contenedores Ready"
  ((FAIL++))
fi

# Test 3: Volumen log-volume existe
echo "[Test 3] Volumen log-volume configurado en Pod dev"
VOL=$(kubectl get pod webapp-sidecar-pod -n ckad-dev -o jsonpath='{.spec.volumes[?(@.name=="log-volume")].name}')
if [ "$VOL" = "log-volume" ]; then
  echo "  ✓ PASS: log-volume existe"
  ((PASS++))
else
  echo "  ✗ FAIL: log-volume no encontrado"
  ((FAIL++))
fi

# Test 4: Volumen metrics-volume existe
echo "[Test 4] Volumen metrics-volume configurado en Pod dev"
VOL=$(kubectl get pod webapp-sidecar-pod -n ckad-dev -o jsonpath='{.spec.volumes[?(@.name=="metrics-volume")].name}')
if [ "$VOL" = "metrics-volume" ]; then
  echo "  ✓ PASS: metrics-volume existe"
  ((PASS++))
else
  echo "  ✗ FAIL: metrics-volume no encontrado"
  ((FAIL++))
fi

# Test 5: Etiqueta env=dev en ckad-dev
echo "[Test 5] Etiqueta env=dev en Pod de ckad-dev"
ENV_LABEL=$(kubectl get pod webapp-sidecar-pod -n ckad-dev -o jsonpath='{.metadata.labels.env}')
if [ "$ENV_LABEL" = "dev" ]; then
  echo "  ✓ PASS: env=dev"
  ((PASS++))
else
  echo "  ✗ FAIL: env=$ENV_LABEL"
  ((FAIL++))
fi

# Test 6: Etiqueta env=staging en ckad-staging
echo "[Test 6] Etiqueta env=staging en Pod de ckad-staging"
ENV_LABEL=$(kubectl get pod webapp-sidecar-pod -n ckad-staging -o jsonpath='{.metadata.labels.env}')
if [ "$ENV_LABEL" = "staging" ]; then
  echo "  ✓ PASS: env=staging"
  ((PASS++))
else
  echo "  ✗ FAIL: env=$ENV_LABEL"
  ((FAIL++))
fi

# Test 7: Variable APP_ENV en staging
echo "[Test 7] Variable APP_ENV=staging en contenedor webapp de ckad-staging"
APP_ENV=$(kubectl exec webapp-sidecar-pod -c webapp -n ckad-staging -- env 2>/dev/null | grep APP_ENV | cut -d= -f2)
if [ "$APP_ENV" = "staging" ]; then
  echo "  ✓ PASS: APP_ENV=staging"
  ((PASS++))
else
  echo "  ✗ FAIL: APP_ENV=$APP_ENV"
  ((FAIL++))
fi

# Test 8: metrics.json existe en metrics-exporter
echo "[Test 8] Archivo metrics.json generado por metrics-exporter"
METRICS=$(kubectl exec webapp-sidecar-pod -c metrics-exporter -n ckad-dev -- cat /metrics/metrics.json 2>/dev/null)
if echo "$METRICS" | grep -q "timestamp"; then
  echo "  ✓ PASS: metrics.json contiene timestamp"
  ((PASS++))
else
  echo "  ✗ FAIL: metrics.json no válido"
  ((FAIL++))
fi

# Test 9: Comunicación localhost funciona
echo "[Test 9] Comunicación localhost entre contenedores"
RESPONSE=$(kubectl exec webapp-sidecar-pod -c log-collector -n ckad-dev -- wget -qO- --timeout=5 http://localhost:80/ 2>/dev/null | head -1)
if echo "$RESPONSE" | grep -qi "html\|<!DOCTYPE\|nginx\|welcome"; then
  echo "  ✓ PASS: localhost:80 accesible desde sidecar"
  ((PASS++))
else
  echo "  ✗ FAIL: No se pudo acceder a localhost:80"
  ((FAIL++))
fi

# Test 10: Estructura Kustomize existe
echo "[Test 10] Estructura Kustomize completa"
if [ -f ~/ckad-labs/lab05/kustomize/base/kustomization.yaml ] && \
   [ -f ~/ckad-labs/lab05/kustomize/overlays/dev/kustomization.yaml ] && \
   [ -f ~/ckad-labs/lab05/kustomize/overlays/staging/kustomization.yaml ]; then
  echo "  ✓ PASS: Estructura Kustomize completa"
  ((PASS++))
else
  echo "  ✗ FAIL: Faltan archivos de Kustomize"
  ((FAIL++))
fi

# Test 11: Documento de comparación existe
echo "[Test 11] Documento comparacion-patrones.md"
if [ -f ~/ckad-labs/lab05/comparacion-patrones.md ] && [ $(wc -l < ~/ckad-labs/lab05/comparacion-patrones.md) -gt 50 ]; then
  echo "  ✓ PASS: Documento existe con contenido suficiente"
  ((PASS++))
else
  echo "  ✗ FAIL: Documento no existe o está incompleto"
  ((FAIL++))
fi

echo ""
echo "=========================================="
echo "  RESULTADOS: $PASS passed, $FAIL failed"
echo "=========================================="

if [ $FAIL -eq 0 ]; then
  echo "  🎉 ¡LABORATORIO COMPLETADO EXITOSAMENTE!"
else
  echo "  ⚠️  Revisa los tests fallidos antes de continuar"
fi
```

Guarda y ejecuta el script:

```bash
cat > ~/ckad-labs/lab05/validate.sh << 'SCRIPT'
# (pegar el contenido del script anterior)
SCRIPT
chmod +x ~/ckad-labs/lab05/validate.sh
bash ~/ckad-labs/lab05/validate.sh
```

## Troubleshooting

### Problema 1: El sidecar log-collector no muestra logs formateados

**Síntomas:**
- `kubectl logs webapp-sidecar-pod -c log-collector` solo muestra el mensaje inicial "Iniciando tail de access.log..." pero no muestra líneas de log procesadas.
- El contenedor está en estado Running pero sin actividad.

**Causa:**
El archivo `/var/log/nginx/access.log` no existe aún porque nginx no ha recibido peticiones, o nginx escribe los logs en una ubicación diferente. En la imagen `ckad-webapp:1.0.0`, nginx puede estar configurado para escribir logs en `/var/log/nginx/access.log` pero el archivo no se crea hasta la primera petición.

**Solución:**

```bash
# 1. Verificar si el archivo de log existe en el contenedor webapp
kubectl exec webapp-sidecar-pod -c webapp -n ckad-dev -- ls -la /var/log/nginx/

# 2. Si no existe, generar tráfico para crear el archivo
kubectl port-forward pod/webapp-sidecar-pod 8082:80 -n ckad-dev &
sleep 2
curl -s http://localhost:8082/ > /dev/null
kill %1

# 3. Verificar la configuración de nginx para la ruta de logs
kubectl exec webapp-sidecar-pod -c webapp -n ckad-dev -- cat /etc/nginx/nginx.conf | grep access_log

# 4. Si la ruta es diferente, actualizar el manifiesto con la ruta correcta
# y re-aplicar con: kubectl replace --force -f webapp-sidecar-pod.yaml
```

### Problema 2: Kustomize overlay de staging falla con error de merge en containers

**Síntomas:**
- Al ejecutar `kustomize build ~/ckad-labs/lab05/kustomize/overlays/staging/` se obtiene un error similar a:
  ```
  Error: failed to apply strategic merge patch: conflict in containers
  ```
- O el resultado no incluye las variables de entorno ni los resource limits.

**Causa:**
El strategic merge patch de Kubernetes usa el campo `name` dentro de `containers[]` como clave de merge. Si el patch no especifica correctamente el nombre del contenedor, Kustomize no puede identificar qué contenedor modificar, o intenta agregar contenedores duplicados en lugar de parchear los existentes.

**Solución:**

```bash
# 1. Verificar que el patch tiene los nombres correctos de contenedores
cat ~/ckad-labs/lab05/kustomize/overlays/staging/patch-staging.yaml | grep "name:"

# 2. Los nombres deben coincidir EXACTAMENTE con la base: webapp, log-collector, metrics-exporter

# 3. Verificar la estructura del patch - debe ser un Pod válido con los campos a modificar
kustomize build ~/ckad-labs/lab05/kustomize/overlays/staging/ 2>&1

# 4. Si hay conflicto, asegurar que el kustomization.yaml usa el target correcto:
cat ~/ckad-labs/lab05/kustomize/overlays/staging/kustomization.yaml

# 5. Alternativa: usar patchesJson6902 en lugar de strategic merge si el problema persiste
# Reescribir kustomization.yaml con:
cat > ~/ckad-labs/lab05/kustomize/overlays/staging/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ckad-staging
resources:
  - ../../base
patches:
  - path: patch-staging.yaml
    target:
      kind: Pod
      name: webapp-sidecar-pod
EOF

# 6. Verificar de nuevo
kustomize build ~/ckad-labs/lab05/kustomize/overlays/staging/
```

## Limpieza

Ejecuta los siguientes comandos para eliminar todos los recursos creados en este laboratorio:

```bash
# Eliminar Pods desplegados
kubectl delete pod webapp-sidecar-pod -n ckad-dev --ignore-not-found
kubectl delete pod webapp-sidecar-pod -n ckad-staging --ignore-not-found

# Verificar que no quedan Pods del laboratorio
kubectl get pods -n ckad-dev -l app=webapp-sidecar
kubectl get pods -n ckad-staging -l app=webapp-sidecar

# (Opcional) Mantener los archivos del laboratorio para referencia
echo "Archivos del laboratorio en ~/ckad-labs/lab05/ conservados para referencia"
ls ~/ckad-labs/lab05/
```

> **Nota:** No elimines los namespaces `ckad-dev` ni `ckad-staging` ya que son utilizados por otros laboratorios del curso.

## Resumen

En este laboratorio has implementado exitosamente el patrón sidecar, uno de los patrones de diseño de Pod más importantes en Kubernetes. Los logros clave incluyen:

- **Pod multi-contenedor con sidecars:** Desplegaste un Pod con tres contenedores cooperantes que comparten red y volúmenes sin modificar la imagen principal.
- **Comunicación inter-contenedor:** Verificaste que todos los contenedores de un Pod comparten la misma IP y se comunican vía `localhost`, tal como se describe en la lección de anatomía del Pod.
- **Volúmenes `emptyDir` múltiples:** Configuraste dos volúmenes independientes para separar responsabilidades (logs vs métricas).
- **Kustomize base/overlays:** Gestionaste variantes del mismo Pod para diferentes entornos sin duplicar manifiestos, aplicando patches estratégicos.
- **Criterios de diseño:** Documentaste cuándo usar cada patrón (sidecar, init container, contenedor único) con criterios técnicos fundamentados.

### Conceptos Clave Reforzados de la Lección 2.1

| Concepto de la lección | Aplicación en este laboratorio |
|------------------------|-------------------------------|
| Pod como "host lógico" | Tres procesos compartiendo IP y volúmenes |
| `spec.containers` con múltiples entradas | webapp + log-collector + metrics-exporter |
| `spec.volumes` con `emptyDir` | log-volume y metrics-volume |
| `volumeMounts` por contenedor | Cada contenedor monta solo los volúmenes que necesita |
| Comunicación vía `localhost` | Sidecar accede al webapp por localhost:80 |
| `metadata.labels` para organización | Etiquetas de app, pattern y env |

### Recursos Adicionales

- [Kubernetes Patterns: Sidecar](https://kubernetes.io/blog/2015/06/the-distributed-system-toolkit-patterns/)
- [Documentación oficial: Multi-container Pods](https://kubernetes.io/docs/concepts/workloads/pods/#how-pods-manage-multiple-containers)
- [Kustomize: Strategic Merge Patch](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patches/)
- [Documentación de Kustomize: Overlays](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/)

---

# Uso de volúmenes efímeros y persistentes

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 65 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar |
| **Directorio de trabajo** | `~/ckad-labs/lab06/` |
| **Namespace** | `ckad-storage` |

## Descripción General

En este laboratorio explorarás las dos categorías fundamentales de almacenamiento en Kubernetes: volúmenes efímeros (`emptyDir`) y volúmenes persistentes (`PersistentVolume` + `PersistentVolumeClaim`). Desplegarás Pods multi-contenedor que comparten datos mediante `emptyDir`, observarás cómo esos datos desaparecen al eliminar el Pod, y luego implementarás almacenamiento persistente con `hostPath` que sobrevive al ciclo de vida del Pod. Esta práctica consolida los conceptos de anatomía del Pod vistos en la lección 2.1, específicamente `spec.volumes` y `volumeMounts`.

## Objetivos de Aprendizaje

- [ ] Crear y montar volúmenes efímeros `emptyDir` para compartir datos entre contenedores de un mismo Pod
- [ ] Definir un PersistentVolume (PV) con almacenamiento local y reclamar capacidad mediante un PersistentVolumeClaim (PVC)
- [ ] Montar PVCs en Pods y verificar que los datos sobreviven a la eliminación y recreación del Pod
- [ ] Verificar experimentalmente la diferencia de comportamiento entre volúmenes efímeros y persistentes
- [ ] Comprender los modos de acceso (`ReadWriteOnce`) y las políticas de reclamación (`Retain`)

## Prerrequisitos

### Conocimientos Previos

| Concepto | Nivel Requerido |
|----------|----------------|
| Estructura YAML de un Pod (apiVersion, kind, metadata, spec) | Comprensión sólida |
| Pods multi-contenedor y `volumeMounts` | Familiaridad práctica |
| Comandos básicos de kubectl (apply, get, describe, exec, logs, delete) | Uso fluido |
| Navegación en terminal Linux (cd, cat, echo, mkdir) | Básico |

### Acceso Requerido

- Clúster kind 0.23.0 con Kubernetes 1.30.2 operativo (1 control-plane + 2 workers)
- kubectl 1.30.2 configurado con kubeconfig apuntando al clúster kind
- Imágenes `busybox:1.36.1` y `nginx:1.27.0` pre-descargadas en los nodos
- Aliases de kubectl activos (`k`, `kgp`, `kd`)

## Entorno del Laboratorio

### Software Requerido

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| kind | 0.23.0 | Clúster Kubernetes local |
| Kubernetes | 1.30.2 | Plataforma de orquestación |
| kubectl | 1.30.2 | CLI de administración |
| busybox | 1.36.1 | Contenedores escritor/lector |
| nginx | 1.27.0 | Servidor web para fase persistente |

### Configuración Inicial del Entorno

```bash
# Verificar que el clúster kind está operativo
kubectl cluster-info

# Verificar nodos disponibles (debe mostrar 1 control-plane + 2 workers)
kubectl get nodes -o wide

# Crear el directorio de trabajo del laboratorio
mkdir -p ~/ckad-labs/lab06
cd ~/ckad-labs/lab06

# Crear el namespace dedicado para este laboratorio
kubectl create namespace ckad-storage

# Configurar el namespace como default para el contexto actual
kubectl config set-context --current --namespace=ckad-storage

# Verificar namespace activo
kubectl config view --minify | grep namespace
```

**Salida esperada del último comando:**

```
    namespace: ckad-storage
```

```bash
# Crear el directorio hostPath en los nodos worker para la fase persistente
# (kind usa contenedores Docker como nodos)
docker exec kind-worker mkdir -p /mnt/ckad-data
docker exec kind-worker2 mkdir -p /mnt/ckad-data

# Verificar que los directorios existen
docker exec kind-worker ls -la /mnt/ckad-data
docker exec kind-worker2 ls -la /mnt/ckad-data
```

## Paso a Paso

---

### Paso 1: Crear el Pod multi-contenedor con volumen emptyDir

**Objetivo:** Desplegar un Pod con dos contenedores (escritor y lector) que comparten un volumen efímero `emptyDir` montado en `/data`, demostrando la comunicación entre contenedores mediante sistema de archivos compartido.

**Instrucciones:**

1. Crea el manifiesto YAML para el Pod multi-contenedor:

```bash
cd ~/ckad-labs/lab06

cat <<'EOF' > storage-demo-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: storage-demo-pod
  namespace: ckad-storage
  labels:
    app: storage-demo
    type: ephemeral
spec:
  volumes:
    - name: shared-data
      emptyDir: {}

  containers:
    - name: escritor
      image: busybox:1.36.1
      command:
        - sh
        - -c
        - |
          while true; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Escritura desde contenedor escritor" >> /data/log.txt
            sleep 5
          done
      volumeMounts:
        - name: shared-data
          mountPath: /data

    - name: lector
      image: busybox:1.36.1
      command:
        - sh
        - -c
        - |
          echo "Esperando archivo log.txt..."
          while [ ! -f /data/log.txt ]; do sleep 1; done
          echo "Archivo encontrado. Leyendo continuamente..."
          tail -f /data/log.txt
      volumeMounts:
        - name: shared-data
          mountPath: /data
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f storage-demo-pod.yaml
```

3. Espera a que ambos contenedores estén en estado Running:

```bash
kubectl get pod storage-demo-pod -w
```

**Salida esperada:**

```
NAME               READY   STATUS    RESTARTS   AGE
storage-demo-pod   2/2     Running   0          15s
```

Presiona `Ctrl+C` para salir del watch cuando veas `2/2 Running`.

**Verificación:**

```bash
# Verificar que el Pod tiene 2 contenedores corriendo
kubectl get pod storage-demo-pod -o jsonpath='{.status.containerStatuses[*].name}' && echo
```

Salida esperada:

```
escritor lector
```

---

### Paso 2: Verificar el intercambio de datos vía emptyDir

**Objetivo:** Confirmar que el contenedor escritor genera datos en `/data/log.txt` y que el contenedor lector puede acceder al mismo archivo a través del volumen compartido.

**Instrucciones:**

1. Revisa los logs del contenedor lector para confirmar que lee los datos escritos:

```bash
kubectl logs storage-demo-pod -c lector --tail=5
```

**Salida esperada (ejemplo):**

```
2024-07-15 10:30:05 - Escritura desde contenedor escritor
2024-07-15 10:30:10 - Escritura desde contenedor escritor
2024-07-15 10:30:15 - Escritura desde contenedor escritor
2024-07-15 10:30:20 - Escritura desde contenedor escritor
2024-07-15 10:30:25 - Escritura desde contenedor escritor
```

2. Accede al contenedor escritor y verifica el contenido del archivo directamente:

```bash
kubectl exec storage-demo-pod -c escritor -- cat /data/log.txt
```

3. Accede al contenedor lector y verifica que ve el mismo archivo:

```bash
kubectl exec storage-demo-pod -c lector -- wc -l /data/log.txt
```

4. Escribe un archivo adicional desde el lector y verifica que el escritor también lo ve:

```bash
# Escribir desde el lector
kubectl exec storage-demo-pod -c lector -- sh -c "echo 'Dato del lector' > /data/extra.txt"

# Leer desde el escritor
kubectl exec storage-demo-pod -c escritor -- cat /data/extra.txt
```

**Salida esperada:**

```
Dato del lector
```

**Verificación:**

```bash
# Listar archivos en /data desde ambos contenedores
echo "=== Desde escritor ==="
kubectl exec storage-demo-pod -c escritor -- ls -la /data/
echo "=== Desde lector ==="
kubectl exec storage-demo-pod -c lector -- ls -la /data/
```

Ambos contenedores deben mostrar los mismos archivos (`log.txt` y `extra.txt`).

---

### Paso 3: Demostrar la naturaleza efímera del emptyDir

**Objetivo:** Eliminar el Pod y recrearlo para comprobar que los datos almacenados en `emptyDir` se pierden completamente al destruir el Pod.

**Instrucciones:**

1. Registra cuántas líneas tiene el log antes de eliminar el Pod:

```bash
kubectl exec storage-demo-pod -c escritor -- wc -l /data/log.txt
```

Anota el número de líneas (por ejemplo: `15 /data/log.txt`).

2. Elimina el Pod:

```bash
kubectl delete pod storage-demo-pod
```

**Salida esperada:**

```
pod "storage-demo-pod" deleted
```

3. Recrea el Pod con el mismo manifiesto:

```bash
kubectl apply -f storage-demo-pod.yaml
```

4. Espera a que esté Running:

```bash
kubectl wait --for=condition=Ready pod/storage-demo-pod --timeout=60s
```

5. Verifica que el archivo log.txt comienza desde cero:

```bash
# Esperar unos segundos para que se generen nuevas entradas
sleep 10

kubectl exec storage-demo-pod -c escritor -- wc -l /data/log.txt
```

**Salida esperada:**

```
2 /data/log.txt
```

El archivo tiene solo las líneas nuevas (aproximadamente 2, dependiendo del tiempo transcurrido). Las líneas anteriores se perdieron.

6. Verifica que el archivo `extra.txt` ya no existe:

```bash
kubectl exec storage-demo-pod -c escritor -- ls /data/
```

**Salida esperada:**

```
log.txt
```

**Verificación:**

```bash
# Confirmar que SOLO existe log.txt con pocas líneas
kubectl exec storage-demo-pod -c lector -- sh -c "cat /data/log.txt | head -3"
```

Las marcas de tiempo deben ser recientes, confirmando que los datos anteriores se perdieron.

---

### Paso 4: Crear el PersistentVolume (PV) con hostPath

**Objetivo:** Definir un PersistentVolume de 1Gi con política de reclamación `Retain` y modo de acceso `ReadWriteOnce`, usando `hostPath` para simular almacenamiento local en el nodo worker.

**Instrucciones:**

1. Crea el manifiesto del PersistentVolume:

```bash
cat <<'EOF' > pv-local-01.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-local-01
  labels:
    type: local
    lab: storage
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/ckad-data
    type: DirectoryOrCreate
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f pv-local-01.yaml
```

3. Verifica que el PV se creó correctamente:

```bash
kubectl get pv pv-local-01
```

**Salida esperada:**

```
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pv-local-01   1Gi        RWO            Retain           Available                           manual                  <unset>            5s
```

El estado debe ser `Available` (disponible para ser reclamado).

**Verificación:**

```bash
kubectl describe pv pv-local-01 | grep -E "Capacity|Access|Reclaim|Status|Path"
```

Salida esperada (parcial):

```
    Capacity:      1Gi
    Access Modes:  RWO
    Reclaim Policy: Retain
    Status:        Available
    Path:          /mnt/ckad-data
```

---

### Paso 5: Crear el PersistentVolumeClaim (PVC)

**Objetivo:** Crear un PVC que reclame el PV definido anteriormente, vinculándolo al namespace `ckad-storage` con la StorageClass `manual`.

**Instrucciones:**

1. Crea el manifiesto del PVC:

```bash
cat <<'EOF' > pvc-app-data.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-app-data
  namespace: ckad-storage
  labels:
    app: persistent-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f pvc-app-data.yaml
```

3. Verifica que el PVC se vinculó al PV:

```bash
kubectl get pvc pvc-app-data
```

**Salida esperada:**

```
NAME           STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc-app-data   Bound    pv-local-01   1Gi        RWO            manual         <unset>                 3s
```

El estado debe ser `Bound`, indicando que el PVC encontró un PV compatible y se vinculó a él.

4. Verifica que el PV ahora muestra el claim:

```bash
kubectl get pv pv-local-01
```

**Salida esperada:**

```
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                      STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pv-local-01   1Gi        RWO            Retain           Bound    ckad-storage/pvc-app-data   manual         <unset>                          2m
```

**Verificación:**

```bash
# Verificar el binding bidireccional
echo "=== PVC -> PV ==="
kubectl get pvc pvc-app-data -o jsonpath='{.spec.volumeName}' && echo
echo "=== PV -> PVC ==="
kubectl get pv pv-local-01 -o jsonpath='{.spec.claimRef.name}' && echo
```

Salida esperada:

```
=== PVC -> PV ===
pv-local-01
=== PV -> PVC ===
pvc-app-data
```

---

### Paso 6: Desplegar el Pod con volumen persistente

**Objetivo:** Crear un Pod con nginx que monta el PVC en `/usr/share/nginx/html`, escribir contenido en el volumen y servir la página.

**Instrucciones:**

1. Crea el manifiesto del Pod persistente:

```bash
cat <<'EOF' > persistent-app-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: persistent-app-pod
  namespace: ckad-storage
  labels:
    app: persistent-app
    type: persistent
spec:
  volumes:
    - name: app-storage
      persistentVolumeClaim:
        claimName: pvc-app-data

  containers:
    - name: nginx
      image: nginx:1.27.0
      ports:
        - containerPort: 80
          name: http
      volumeMounts:
        - name: app-storage
          mountPath: /usr/share/nginx/html
      resources:
        requests:
          memory: "64Mi"
          cpu: "100m"
        limits:
          memory: "128Mi"
          cpu: "250m"
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f persistent-app-pod.yaml
```

3. Espera a que el Pod esté listo:

```bash
kubectl wait --for=condition=Ready pod/persistent-app-pod --timeout=60s
```

4. Escribe un archivo `index.html` en el volumen persistente:

```bash
kubectl exec persistent-app-pod -- sh -c 'echo "<html><body><h1>Datos Persistentes en Kubernetes</h1><p>Este archivo sobrevive a la eliminacion del Pod.</p><p>Timestamp: $(date)</p></body></html>" > /usr/share/nginx/html/index.html'
```

5. Verifica que nginx sirve el contenido:

```bash
kubectl exec persistent-app-pod -- curl -s http://localhost/
```

**Salida esperada:**

```html
<html><body><h1>Datos Persistentes en Kubernetes</h1><p>Este archivo sobrevive a la eliminacion del Pod.</p><p>Timestamp: Mon Jul 15 10:45:32 UTC 2024</p></body></html>
```

6. Escribe un archivo adicional para la verificación posterior:

```bash
kubectl exec persistent-app-pod -- sh -c 'echo "persistencia-verificada" > /usr/share/nginx/html/test.txt'
```

**Verificación:**

```bash
kubectl exec persistent-app-pod -- ls -la /usr/share/nginx/html/
```

Debe mostrar `index.html` y `test.txt`.

---

### Paso 7: Demostrar la persistencia de datos tras eliminar el Pod

**Objetivo:** Eliminar el Pod `persistent-app-pod`, recrearlo con el mismo manifiesto y verificar que los archivos escritos anteriormente siguen disponibles en el volumen.

**Instrucciones:**

1. Registra el contenido actual antes de eliminar:

```bash
echo "=== Contenido antes de eliminar ==="
kubectl exec persistent-app-pod -- cat /usr/share/nginx/html/index.html
kubectl exec persistent-app-pod -- cat /usr/share/nginx/html/test.txt
```

2. Elimina el Pod:

```bash
kubectl delete pod persistent-app-pod
```

**Salida esperada:**

```
pod "persistent-app-pod" deleted
```

3. Verifica que el PVC sigue existiendo y vinculado:

```bash
kubectl get pvc pvc-app-data
```

**Salida esperada:**

```
NAME           STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc-app-data   Bound    pv-local-01   1Gi        RWO            manual         <unset>                 5m
```

El PVC permanece `Bound` aunque el Pod fue eliminado.

4. Recrea el Pod:

```bash
kubectl apply -f persistent-app-pod.yaml
kubectl wait --for=condition=Ready pod/persistent-app-pod --timeout=60s
```

5. Verifica que los datos persisten:

```bash
echo "=== Contenido después de recrear ==="
kubectl exec persistent-app-pod -- cat /usr/share/nginx/html/index.html
kubectl exec persistent-app-pod -- cat /usr/share/nginx/html/test.txt
```

**Salida esperada:**

```
=== Contenido después de recrear ===
<html><body><h1>Datos Persistentes en Kubernetes</h1><p>Este archivo sobrevive a la eliminacion del Pod.</p><p>Timestamp: Mon Jul 15 10:45:32 UTC 2024</p></body></html>
persistencia-verificada
```

Los datos están intactos. El timestamp es el original, confirmando que no se regeneró el archivo.

6. Verifica que nginx sirve correctamente el contenido persistido:

```bash
kubectl exec persistent-app-pod -- curl -s http://localhost/
```

**Verificación:**

```bash
# Verificación final de persistencia
kubectl exec persistent-app-pod -- sh -c '
  if [ -f /usr/share/nginx/html/test.txt ]; then
    content=$(cat /usr/share/nginx/html/test.txt)
    if [ "$content" = "persistencia-verificada" ]; then
      echo "ÉXITO: Los datos persisten correctamente tras recrear el Pod"
    else
      echo "ERROR: El contenido del archivo no coincide"
    fi
  else
    echo "ERROR: El archivo test.txt no existe"
  fi
'
```

Salida esperada:

```
ÉXITO: Los datos persisten correctamente tras recrear el Pod
```

---

### Paso 8: Comparación documentada de comportamientos

**Objetivo:** Crear un documento de referencia que resuma las diferencias observadas entre volúmenes efímeros y persistentes, consolidando el aprendizaje experimental.

**Instrucciones:**

1. Crea un archivo de comparación con los resultados observados:

```bash
cat <<'EOF' > ~/ckad-labs/lab06/comparacion-volumenes.md
# Comparación: Volúmenes Efímeros vs Persistentes

## Resumen de Pruebas Realizadas

| Característica | emptyDir (Efímero) | PV/PVC (Persistente) |
|---|---|---|
| Ciclo de vida | Ligado al Pod | Independiente del Pod |
| Datos tras eliminar Pod | Se pierden completamente | Se mantienen intactos |
| Compartir entre contenedores | Sí (mismo Pod) | Sí (mismo Pod) |
| Compartir entre Pods | No | Sí (si el modo lo permite) |
| Requiere pre-provisión | No | Sí (PV debe existir) |
| Caso de uso típico | Cache, datos temporales, comunicación inter-contenedor | Bases de datos, logs, archivos de configuración |

## Observaciones del Laboratorio

### emptyDir (storage-demo-pod)
- El volumen se crea automáticamente al iniciar el Pod
- Ambos contenedores (escritor y lector) acceden al mismo directorio /data
- Al eliminar y recrear el Pod, log.txt comienza desde cero
- El archivo extra.txt creado manualmente desapareció

### PV/PVC (persistent-app-pod)
- El PV debe crearse antes que el PVC
- El PVC se vincula automáticamente al PV compatible (matching por storageClassName y capacidad)
- Al eliminar el Pod, el PVC permanece Bound
- Al recrear el Pod, index.html y test.txt siguen disponibles
- La política Retain garantiza que el PV no se elimina al liberar el PVC

## Modos de Acceso Observados
- ReadWriteOnce (RWO): El volumen puede ser montado como lectura-escritura por un solo nodo
- Adecuado para cargas de trabajo que corren en un solo nodo

## Políticas de Reclamación
- Retain: El PV se conserva tras eliminar el PVC (requiere limpieza manual)
- Delete: El PV se elimina automáticamente al borrar el PVC (no usado en este lab)
EOF
```

2. Verifica el contenido:

```bash
cat ~/ckad-labs/lab06/comparacion-volumenes.md
```

3. Lista todos los artefactos generados en el laboratorio:

```bash
ls -la ~/ckad-labs/lab06/
```

**Salida esperada:**

```
total XX
drwxr-xr-x 2 user user 4096 Jul 15 11:00 .
drwxr-xr-x 8 user user 4096 Jul 15 10:00 ..
-rw-r--r-- 1 user user  XXX Jul 15 11:00 comparacion-volumenes.md
-rw-r--r-- 1 user user  XXX Jul 15 10:20 persistent-app-pod.yaml
-rw-r--r-- 1 user user  XXX Jul 15 10:15 pv-local-01.yaml
-rw-r--r-- 1 user user  XXX Jul 15 10:17 pvc-app-data.yaml
-rw-r--r-- 1 user user  XXX Jul 15 10:05 storage-demo-pod.yaml
```

---

## Validación y Testing

Ejecuta la siguiente secuencia de validación completa para confirmar que todos los objetivos del laboratorio se cumplieron:

```bash
echo "=========================================="
echo "  VALIDACIÓN COMPLETA - Lab 02-00-04"
echo "=========================================="
echo ""

# Test 1: Namespace existe
echo "--- Test 1: Namespace ckad-storage ---"
kubectl get namespace ckad-storage -o jsonpath='{.metadata.name}' && echo " ✓"

# Test 2: Pod emptyDir está corriendo con 2 contenedores
echo "--- Test 2: Pod storage-demo-pod (emptyDir) ---"
READY=$(kubectl get pod storage-demo-pod -o jsonpath='{.status.containerStatuses[?(@.ready==true)].name}' | wc -w)
if [ "$READY" -eq 2 ]; then
  echo "  2/2 contenedores Ready ✓"
else
  echo "  ERROR: Solo $READY contenedores Ready ✗"
fi

# Test 3: emptyDir funciona (escritor escribe, lector lee)
echo "--- Test 3: Comunicación vía emptyDir ---"
LINES=$(kubectl exec storage-demo-pod -c escritor -- wc -l /data/log.txt 2>/dev/null | awk '{print $1}')
if [ "$LINES" -gt 0 ]; then
  echo "  log.txt tiene $LINES líneas ✓"
else
  echo "  ERROR: log.txt vacío o no existe ✗"
fi

# Test 4: PV existe y está Bound
echo "--- Test 4: PersistentVolume pv-local-01 ---"
PV_STATUS=$(kubectl get pv pv-local-01 -o jsonpath='{.status.phase}')
echo "  Estado: $PV_STATUS $([ '$PV_STATUS' = 'Bound' ] && echo '✓' || echo '✗')"

# Test 5: PVC existe y está Bound
echo "--- Test 5: PersistentVolumeClaim pvc-app-data ---"
PVC_STATUS=$(kubectl get pvc pvc-app-data -o jsonpath='{.status.phase}')
echo "  Estado: $PVC_STATUS $([ '$PVC_STATUS' = 'Bound' ] && echo '✓' || echo '✗')"

# Test 6: Pod persistente está corriendo
echo "--- Test 6: Pod persistent-app-pod ---"
POD_STATUS=$(kubectl get pod persistent-app-pod -o jsonpath='{.status.phase}')
echo "  Estado: $POD_STATUS $([ '$POD_STATUS' = 'Running' ] && echo '✓' || echo '✗')"

# Test 7: Datos persisten en el volumen
echo "--- Test 7: Persistencia de datos ---"
TEST_CONTENT=$(kubectl exec persistent-app-pod -- cat /usr/share/nginx/html/test.txt 2>/dev/null)
if [ "$TEST_CONTENT" = "persistencia-verificada" ]; then
  echo "  Datos persistentes intactos ✓"
else
  echo "  ERROR: Datos no encontrados o incorrectos ✗"
fi

# Test 8: Archivos de manifiesto existen
echo "--- Test 8: Artefactos del laboratorio ---"
for f in storage-demo-pod.yaml pv-local-01.yaml pvc-app-data.yaml persistent-app-pod.yaml comparacion-volumenes.md; do
  if [ -f ~/ckad-labs/lab06/$f ]; then
    echo "  $f ✓"
  else
    echo "  $f ✗ (NO ENCONTRADO)"
  fi
done

echo ""
echo "=========================================="
echo "  VALIDACIÓN COMPLETADA"
echo "=========================================="
```

## Troubleshooting

### Problema 1: PVC queda en estado Pending

**Síntomas:**

```
$ kubectl get pvc pvc-app-data
NAME           STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc-app-data   Pending                                      manual         30s
```

El PVC no se vincula al PV y permanece en `Pending` indefinidamente.

**Causa:** El `storageClassName` del PVC no coincide con el del PV. Si el PV usa `storageClassName: manual` pero el PVC especifica un valor diferente (o no lo especifica, en cuyo caso Kubernetes usa la StorageClass default del clúster), no habrá match.

**Solución:**

```bash
# Verificar storageClassName de ambos recursos
echo "PV storageClassName:"
kubectl get pv pv-local-01 -o jsonpath='{.spec.storageClassName}' && echo

echo "PVC storageClassName:"
kubectl get pvc pvc-app-data -o jsonpath='{.spec.storageClassName}' && echo

# Si no coinciden, eliminar el PVC y recrearlo con el valor correcto
kubectl delete pvc pvc-app-data

# Editar pvc-app-data.yaml asegurando: storageClassName: manual
# Luego reaplicar:
kubectl apply -f pvc-app-data.yaml

# Verificar que ahora está Bound
kubectl get pvc pvc-app-data
```

También verificar que la capacidad solicitada por el PVC (500Mi) no exceda la capacidad del PV (1Gi). El PVC solicita ≤ PV es requisito para el binding.

---

### Problema 2: Pod persistent-app-pod queda en ContainerCreating

**Síntomas:**

```
$ kubectl get pod persistent-app-pod
NAME                  READY   STATUS              RESTARTS   AGE
persistent-app-pod    0/1     ContainerCreating   0          45s
```

El Pod no avanza a `Running` y queda atascado en `ContainerCreating`.

**Causa:** El Pod fue programado en un nodo donde el directorio `hostPath` (`/mnt/ckad-data`) no existe, o el PV está vinculado a un nodo específico diferente al que el scheduler eligió. En clústeres kind con múltiples workers, `hostPath` es local a cada nodo-contenedor.

**Solución:**

```bash
# Inspeccionar eventos del Pod
kubectl describe pod persistent-app-pod | tail -20

# Verificar en qué nodo se programó
kubectl get pod persistent-app-pod -o jsonpath='{.spec.nodeName}' && echo

# Crear el directorio en TODOS los nodos worker
docker exec kind-worker mkdir -p /mnt/ckad-data
docker exec kind-worker2 mkdir -p /mnt/ckad-data

# Si el Pod sigue atascado, eliminarlo y recrearlo
kubectl delete pod persistent-app-pod
kubectl apply -f persistent-app-pod.yaml

# Verificar que inicia correctamente
kubectl wait --for=condition=Ready pod/persistent-app-pod --timeout=60s
```

Si el problema persiste, verificar que el PVC está en estado `Bound`:

```bash
kubectl get pvc pvc-app-data
# Si está en Pending, resolver primero el Problema 1
```

---

## Limpieza

```bash
# Eliminar los Pods del laboratorio
kubectl delete pod storage-demo-pod persistent-app-pod -n ckad-storage

# Eliminar el PVC
kubectl delete pvc pvc-app-data -n ckad-storage

# Eliminar el PV (nota: con política Retain, el PV queda en Released)
kubectl delete pv pv-local-01

# Limpiar datos del hostPath en los nodos
docker exec kind-worker rm -rf /mnt/ckad-data
docker exec kind-worker2 rm -rf /mnt/ckad-data

# Verificar que no quedan recursos
echo "=== Pods ==="
kubectl get pods -n ckad-storage
echo "=== PVCs ==="
kubectl get pvc -n ckad-storage
echo "=== PVs ==="
kubectl get pv

# NOTA: NO eliminar el namespace ckad-storage ni los archivos en ~/ckad-labs/lab06/
# ya que serán reutilizados en el Lab 02-00-05
```

**Nota importante:** Los manifiestos YAML en `~/ckad-labs/lab06/` se conservan intencionalmente. Serán la base para personalización con Kustomize en el siguiente laboratorio.

## Resumen

En este laboratorio has aplicado de forma práctica los dos modelos fundamentales de almacenamiento en Kubernetes:

| Concepto Practicado | Resultado Observado |
|---|---|
| `emptyDir` entre contenedores | Comunicación exitosa vía sistema de archivos compartido |
| Eliminación de Pod con `emptyDir` | Pérdida total de datos |
| PersistentVolume con `hostPath` | Almacenamiento provisionado independiente del Pod |
| PersistentVolumeClaim (binding) | Vinculación automática por storageClassName y capacidad |
| Eliminación y recreación de Pod con PVC | Datos intactos tras el ciclo de vida |
| Política `Retain` | PV conservado tras desvinculación |
| Modo `ReadWriteOnce` | Acceso lectura-escritura desde un solo nodo |

### Conceptos Clave Consolidados

- **`spec.volumes`** declara los volúmenes disponibles en el Pod (tanto efímeros como persistentes)
- **`volumeMounts`** en cada contenedor define dónde se monta el volumen en el sistema de archivos
- El ciclo de vida del PVC es independiente del Pod: eliminar el Pod no afecta al PVC ni al PV
- La StorageClass actúa como "pegamento" entre PV y PVC para el binding automático

### Recursos Adicionales

- [Kubernetes Volumes — Documentación Oficial](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Persistent Volumes — Documentación Oficial](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [emptyDir — Referencia API](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
- [Configure a Pod to Use a PersistentVolume for Storage](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/)

---

# Personalización con Kustomize

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 55 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar |
| **Prerrequisito directo** | Lab 02-00-04 |

## Descripción General

En este laboratorio construirás una estructura completa de Kustomize con directorio base y overlays diferenciados para los entornos `dev` y `prod`. Partiendo de los manifiestos YAML generados en el Lab 02-00-04 (PersistentVolumeClaim y Pod con volumen persistente), aplicarás transformadores, patches estratégicos y generadores de ConfigMap para personalizar despliegues sin duplicar manifiestos. Al finalizar, tendrás recursos desplegados en namespaces separados con configuraciones específicas por entorno.

## Objetivos de Aprendizaje

- [ ] Estructurar un directorio base de Kustomize referenciando recursos existentes del Lab 02-00-04
- [ ] Crear overlays independientes para `dev` y `prod` con transformadores `namePrefix`, `commonLabels` y `commonAnnotations`
- [ ] Aplicar Strategic Merge Patches y JSON 6902 Patches para modificar recursos de CPU/memoria sin duplicar manifiestos
- [ ] Configurar un `ConfigMapGenerator` que inyecte un archivo `nginx.conf` como volumen montado en el Pod
- [ ] Desplegar recursos en namespaces diferenciados (`ckad-dev` y `ckad-prod`) usando `kubectl apply -k`

## Prerrequisitos

### Conocimientos requeridos

- Comprensión de la estructura YAML de un Pod (campos `apiVersion`, `kind`, `metadata`, `spec`)
- Familiaridad con volúmenes (`emptyDir`, PVC) y montajes (`volumeMounts`)
- Conceptos básicos de namespaces en Kubernetes
- Experiencia con `kubectl apply` y navegación de directorios en terminal

### Acceso requerido

- Clúster kind operativo con kubectl 1.30.2 configurado
- Namespaces `ckad-dev` y `ckad-prod` existentes en el clúster
- Manifiestos del Lab 02-00-04 disponibles en `~/ckad-labs/lab06/`
- Kustomize 5.4.2 accesible en PATH

## Entorno del Laboratorio

### Software necesario

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| kubectl | 1.30.2 | Gestión del clúster y aplicación de manifiestos |
| kustomize | 5.4.2 | Construcción y validación de overlays |
| kind | 0.23.0 | Clúster Kubernetes local |
| bash | 5.x | Shell para comandos y scripts |

### Preparación inicial del entorno

```bash
# Verificar que los alias están activos
alias k=kubectl
alias kgp='kubectl get pods'

# Verificar acceso al clúster
k cluster-info

# Confirmar que los namespaces existen
k get ns ckad-dev ckad-prod

# Si no existen, crearlos
k create ns ckad-dev --dry-run=client -o yaml | k apply -f -
k create ns ckad-prod --dry-run=client -o yaml | k apply -f -

# Verificar que kustomize está disponible
kustomize version

# Confirmar que los manifiestos del lab anterior existen
ls ~/ckad-labs/lab06/persistent-app-pod.yaml
ls ~/ckad-labs/lab06/pvc-app-data.yaml
```

### Verificación de manifiestos del Lab 02-00-04

Si los archivos del lab anterior no existen, créalos con el siguiente contenido mínimo:

```bash
mkdir -p ~/ckad-labs/lab06

cat > ~/ckad-labs/lab06/pvc-app-data.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
  labels:
    app: persistent-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

cat > ~/ckad-labs/lab06/persistent-app-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: persistent-app-pod
  labels:
    app: persistent-app
spec:
  containers:
    - name: nginx
      image: nginx:1.27.0
      ports:
        - containerPort: 80
      resources:
        requests:
          cpu: "100m"
          memory: "64Mi"
        limits:
          cpu: "250m"
          memory: "256Mi"
      volumeMounts:
        - name: app-storage
          mountPath: /usr/share/nginx/html
  volumes:
    - name: app-storage
      persistentVolumeClaim:
        claimName: app-data-pvc
  restartPolicy: Always
EOF
```

## Paso a Paso

### Paso 1: Crear la estructura de directorios de Kustomize

**Objetivo:** Establecer la jerarquía de directorios `base/` y `overlays/` que Kustomize requiere para gestionar múltiples entornos.

**Instrucciones:**

1. Crea el directorio raíz del laboratorio y la estructura completa:

```bash
mkdir -p ~/ckad-labs/lab07/base
mkdir -p ~/ckad-labs/lab07/overlays/dev
mkdir -p ~/ckad-labs/lab07/overlays/prod
```

2. Verifica la estructura creada:

```bash
find ~/ckad-labs/lab07 -type d | sort
```

**Salida esperada:**

```
/home/<usuario>/ckad-labs/lab07
/home/<usuario>/ckad-labs/lab07/base
/home/<usuario>/ckad-labs/lab07/overlays
/home/<usuario>/ckad-labs/lab07/overlays/dev
/home/<usuario>/ckad-labs/lab07/overlays/prod
```

**Verificación:**

```bash
# Confirmar que los 5 directorios existen
test -d ~/ckad-labs/lab07/base && echo "OK: base/" || echo "FALTA: base/"
test -d ~/ckad-labs/lab07/overlays/dev && echo "OK: overlays/dev/" || echo "FALTA: overlays/dev/"
test -d ~/ckad-labs/lab07/overlays/prod && echo "OK: overlays/prod/" || echo "FALTA: overlays/prod/"
```

---

### Paso 2: Copiar recursos base y crear el kustomization.yaml principal

**Objetivo:** Poblar el directorio `base/` con los manifiestos del Lab 02-00-04 y crear el archivo `kustomization.yaml` que los referencia.

**Instrucciones:**

1. Copia los manifiestos del lab anterior al directorio base:

```bash
cp ~/ckad-labs/lab06/persistent-app-pod.yaml ~/ckad-labs/lab07/base/
cp ~/ckad-labs/lab06/pvc-app-data.yaml ~/ckad-labs/lab07/base/
```

2. Crea el archivo `kustomization.yaml` en el directorio base:

```bash
cat > ~/ckad-labs/lab07/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Recursos base reutilizables por todos los overlays
resources:
  - pvc-app-data.yaml
  - persistent-app-pod.yaml

# Etiquetas comunes aplicadas a todos los recursos
commonLabels:
  managed-by: kustomize
  course: ckad-labs
EOF
```

3. Valida la configuración base con un dry-run:

```bash
cd ~/ckad-labs/lab07
kustomize build base/
```

**Salida esperada:**

El comando debe generar YAML válido mostrando tanto el PVC como el Pod con las etiquetas `managed-by: kustomize` y `course: ckad-labs` añadidas en `metadata.labels` y en los selectores correspondientes.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  labels:
    app: persistent-app
    course: ckad-labs
    managed-by: kustomize
  name: app-data-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: persistent-app
    course: ckad-labs
    managed-by: kustomize
  name: persistent-app-pod
...
```

**Verificación:**

```bash
# Verificar que kustomize build no produce errores
kustomize build base/ > /dev/null 2>&1 && echo "BUILD OK" || echo "BUILD FAILED"

# Contar recursos generados (deben ser 2)
kustomize build base/ | grep -c "^kind:"
```

---

### Paso 3: Crear el overlay de desarrollo (dev)

**Objetivo:** Configurar el overlay `dev` que aplica `namePrefix`, reduce recursos de CPU/memoria y apunta al namespace `ckad-dev`.

**Instrucciones:**

1. Crea el archivo `kustomization.yaml` del overlay dev:

```bash
cat > ~/ckad-labs/lab07/overlays/dev/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Referencia al directorio base
resources:
  - ../../base

# Namespace destino para todos los recursos
namespace: ckad-dev

# Transformadores
namePrefix: dev-

commonLabels:
  environment: development

commonAnnotations:
  team: desarrollo
  lab: "02-00-05"

# Patches para reducir recursos del contenedor nginx
patches:
  - target:
      kind: Pod
      name: persistent-app-pod
    patch: |-
      apiVersion: v1
      kind: Pod
      metadata:
        name: persistent-app-pod
      spec:
        containers:
          - name: nginx
            resources:
              requests:
                cpu: "50m"
                memory: "32Mi"
              limits:
                cpu: "100m"
                memory: "128Mi"
EOF
```

2. Valida el overlay dev con dry-run:

```bash
kustomize build overlays/dev/
```

**Salida esperada:**

Los recursos deben mostrar:
- Nombres con prefijo `dev-` (ej: `dev-persistent-app-pod`, `dev-app-data-pvc`)
- Namespace `ckad-dev`
- Etiqueta `environment: development`
- Anotaciones `team: desarrollo` y `lab: "02-00-05"`
- Recursos del contenedor nginx reducidos a `limits: cpu: 100m, memory: 128Mi`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    lab: "02-00-05"
    team: desarrollo
  labels:
    app: persistent-app
    course: ckad-labs
    environment: development
    managed-by: kustomize
  name: dev-app-data-pvc
  namespace: ckad-dev
...
---
apiVersion: v1
kind: Pod
metadata:
  annotations:
    lab: "02-00-05"
    team: desarrollo
  labels:
    app: persistent-app
    course: ckad-labs
    environment: development
    managed-by: kustomize
  name: dev-persistent-app-pod
  namespace: ckad-dev
spec:
  containers:
  - name: nginx
    image: nginx:1.27.0
    resources:
      limits:
        cpu: "100m"
        memory: "128Mi"
      requests:
        cpu: "50m"
        memory: "32Mi"
...
```

**Verificación:**

```bash
# Verificar namePrefix
kustomize build overlays/dev/ | grep "name: dev-" | wc -l
# Esperado: 2 (PVC y Pod)

# Verificar namespace
kustomize build overlays/dev/ | grep "namespace: ckad-dev" | wc -l
# Esperado: 2

# Verificar limits de CPU
kustomize build overlays/dev/ | grep -A1 "limits:" | grep "cpu"
# Esperado: cpu: "100m"
```

---

### Paso 4: Crear el overlay de producción (prod)

**Objetivo:** Configurar el overlay `prod` con recursos incrementados, anotaciones de versión y namespace `ckad-prod`.

**Instrucciones:**

1. Crea el archivo `kustomization.yaml` del overlay prod:

```bash
cat > ~/ckad-labs/lab07/overlays/prod/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Referencia al directorio base
resources:
  - ../../base

# Namespace destino
namespace: ckad-prod

# Transformadores
namePrefix: prod-

commonLabels:
  environment: production

commonAnnotations:
  team: operaciones
  lab: "02-00-05"
  version: "1.0.0"
  release-date: "2024-06-15"

# Patches para incrementar recursos del contenedor nginx
patches:
  - target:
      kind: Pod
      name: persistent-app-pod
    patch: |-
      apiVersion: v1
      kind: Pod
      metadata:
        name: persistent-app-pod
      spec:
        containers:
          - name: nginx
            resources:
              requests:
                cpu: "250m"
                memory: "256Mi"
              limits:
                cpu: "500m"
                memory: "512Mi"
EOF
```

2. Valida el overlay prod:

```bash
kustomize build overlays/prod/
```

**Salida esperada:**

Los recursos deben mostrar:
- Nombres con prefijo `prod-` (ej: `prod-persistent-app-pod`, `prod-app-data-pvc`)
- Namespace `ckad-prod`
- Etiqueta `environment: production`
- Anotaciones de versión (`version: "1.0.0"`, `release-date: "2024-06-15"`)
- Recursos del contenedor nginx incrementados a `limits: cpu: 500m, memory: 512Mi`

**Verificación:**

```bash
# Verificar namePrefix prod
kustomize build overlays/prod/ | grep "name: prod-" | wc -l
# Esperado: 2

# Verificar namespace prod
kustomize build overlays/prod/ | grep "namespace: ckad-prod" | wc -l
# Esperado: 2

# Verificar limits de CPU en prod
kustomize build overlays/prod/ | grep -A1 "limits:" | grep "cpu"
# Esperado: cpu: "500m"

# Verificar anotación de versión
kustomize build overlays/prod/ | grep "version:"
# Esperado: version: "1.0.0"
```

---

### Paso 5: Agregar un JSON 6902 Patch al overlay prod

**Objetivo:** Demostrar el uso de JSON Patch (RFC 6902) como alternativa al Strategic Merge Patch para modificaciones quirúrgicas.

**Instrucciones:**

1. Crea un archivo de JSON Patch para agregar un volumen `emptyDir` adicional al Pod de producción:

```bash
cat > ~/ckad-labs/lab07/overlays/prod/add-cache-volume.yaml << 'EOF'
- op: add
  path: /spec/volumes/-
  value:
    name: cache-volume
    emptyDir:
      sizeLimit: "100Mi"
- op: add
  path: /spec/containers/0/volumeMounts/-
  value:
    name: cache-volume
    mountPath: /var/cache/nginx
EOF
```

2. Actualiza el `kustomization.yaml` de prod para incluir el JSON Patch:

```bash
cat > ~/ckad-labs/lab07/overlays/prod/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: ckad-prod

namePrefix: prod-

commonLabels:
  environment: production

commonAnnotations:
  team: operaciones
  lab: "02-00-05"
  version: "1.0.0"
  release-date: "2024-06-15"

# Strategic Merge Patch para recursos
patches:
  - target:
      kind: Pod
      name: persistent-app-pod
    patch: |-
      apiVersion: v1
      kind: Pod
      metadata:
        name: persistent-app-pod
      spec:
        containers:
          - name: nginx
            resources:
              requests:
                cpu: "250m"
                memory: "256Mi"
              limits:
                cpu: "500m"
                memory: "512Mi"
  # JSON 6902 Patch para agregar volumen de cache
  - target:
      kind: Pod
      name: persistent-app-pod
    path: add-cache-volume.yaml
EOF
```

3. Valida que el patch se aplica correctamente:

```bash
kustomize build overlays/prod/ | grep -A3 "cache-volume"
```

**Salida esperada:**

```yaml
    - mountPath: /var/cache/nginx
      name: cache-volume
...
  - emptyDir:
      sizeLimit: 100Mi
    name: cache-volume
```

**Verificación:**

```bash
# Verificar que el build completo sigue siendo válido
kustomize build overlays/prod/ > /dev/null 2>&1 && echo "BUILD OK" || echo "BUILD FAILED"

# Contar volúmenes en el Pod (debe ser 2: app-storage + cache-volume)
kustomize build overlays/prod/ | grep "name: .*volume\|name: app-storage" | wc -l
```

---

### Paso 6: Configurar ConfigMapGenerator con nginx.conf

**Objetivo:** Usar `configMapGenerator` de Kustomize para crear un ConfigMap a partir de un archivo `nginx.conf` e inyectarlo como volumen en el Pod.

**Instrucciones:**

1. Crea el archivo de configuración nginx en el directorio base:

```bash
cat > ~/ckad-labs/lab07/base/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }

    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    location /status {
        stub_status on;
        access_log off;
    }
}
EOF
```

2. Actualiza el `kustomization.yaml` base para incluir el `configMapGenerator`:

```bash
cat > ~/ckad-labs/lab07/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - pvc-app-data.yaml
  - persistent-app-pod.yaml

commonLabels:
  managed-by: kustomize
  course: ckad-labs

# Generador de ConfigMap desde archivo
configMapGenerator:
  - name: nginx-config
    files:
      - nginx.conf
EOF
```

3. Actualiza el manifiesto del Pod base para montar el ConfigMap:

```bash
cat > ~/ckad-labs/lab07/base/persistent-app-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: persistent-app-pod
  labels:
    app: persistent-app
spec:
  containers:
    - name: nginx
      image: nginx:1.27.0
      ports:
        - containerPort: 80
      resources:
        requests:
          cpu: "100m"
          memory: "64Mi"
        limits:
          cpu: "250m"
          memory: "256Mi"
      volumeMounts:
        - name: app-storage
          mountPath: /usr/share/nginx/html
        - name: nginx-config-volume
          mountPath: /etc/nginx/conf.d
  volumes:
    - name: app-storage
      persistentVolumeClaim:
        claimName: app-data-pvc
    - name: nginx-config-volume
      configMap:
        name: nginx-config
  restartPolicy: Always
EOF
```

4. Verifica que el ConfigMap se genera con hash en el nombre:

```bash
kustomize build base/ | grep "name: nginx-config"
```

**Salida esperada:**

```
  name: nginx-config-<hash>
  name: nginx-config-<hash>
```

El hash (ej: `nginx-config-7g9h2kd5m8`) garantiza que cambios en el contenido del ConfigMap fuerzan un redeploy del Pod.

**Verificación:**

```bash
# Verificar que se generan 3 recursos (PVC + Pod + ConfigMap)
kustomize build base/ | grep -c "^kind:"
# Esperado: 3

# Verificar que el Pod referencia el ConfigMap con hash
kustomize build base/ | grep -B2 -A2 "nginx-config-volume"
```

---

### Paso 7: Desplegar el overlay dev en el clúster

**Objetivo:** Aplicar los recursos del overlay `dev` al namespace `ckad-dev` y verificar su creación correcta.

**Instrucciones:**

1. Realiza un dry-run previo para inspeccionar lo que se desplegará:

```bash
cd ~/ckad-labs/lab07
kubectl apply -k overlays/dev/ --dry-run=client -o yaml | head -80
```

2. Aplica el overlay dev al clúster:

```bash
kubectl apply -k overlays/dev/
```

**Salida esperada:**

```
configmap/dev-nginx-config-<hash> created
persistentvolumeclaim/dev-app-data-pvc created
pod/dev-persistent-app-pod created
```

3. Verifica los recursos creados en `ckad-dev`:

```bash
kubectl get all,configmap,pvc -n ckad-dev -l environment=development
```

**Salida esperada:**

```
NAME                         READY   STATUS    RESTARTS   AGE
pod/dev-persistent-app-pod   1/1     Running   0          30s

NAME                                  DATA   AGE
configmap/dev-nginx-config-<hash>     1      30s

NAME                                     STATUS   VOLUME   CAPACITY   ACCESS MODES
persistentvolumeclaim/dev-app-data-pvc   Bound    ...      1Gi        RWO
```

4. Verifica las etiquetas y anotaciones del Pod:

```bash
kubectl describe pod dev-persistent-app-pod -n ckad-dev | grep -A10 "Labels:\|Annotations:"
```

**Verificación:**

```bash
# Verificar que el Pod está Running
kubectl get pod dev-persistent-app-pod -n ckad-dev -o jsonpath='{.status.phase}'
echo ""
# Esperado: Running

# Verificar los limits de recursos
kubectl get pod dev-persistent-app-pod -n ckad-dev -o jsonpath='{.spec.containers[0].resources.limits}'
echo ""
# Esperado: {"cpu":"100m","memory":"128Mi"}

# Verificar que el ConfigMap está montado
kubectl exec dev-persistent-app-pod -n ckad-dev -- ls /etc/nginx/conf.d/
# Esperado: nginx.conf

# Verificar el endpoint /health
kubectl exec dev-persistent-app-pod -n ckad-dev -- curl -s localhost/health
# Esperado: OK
```

---

### Paso 8: Desplegar el overlay prod en el clúster

**Objetivo:** Aplicar los recursos del overlay `prod` al namespace `ckad-prod` y verificar las diferencias respecto a dev.

**Instrucciones:**

1. Aplica el overlay prod:

```bash
kubectl apply -k overlays/prod/
```

**Salida esperada:**

```
configmap/prod-nginx-config-<hash> created
persistentvolumeclaim/prod-app-data-pvc created
pod/prod-persistent-app-pod created
```

2. Verifica los recursos en `ckad-prod`:

```bash
kubectl get all,configmap,pvc -n ckad-prod -l environment=production
```

3. Compara los recursos entre ambos entornos:

```bash
echo "=== DEV Resources ==="
kubectl get pod dev-persistent-app-pod -n ckad-dev -o jsonpath='{.spec.containers[0].resources.limits}'
echo ""

echo "=== PROD Resources ==="
kubectl get pod prod-persistent-app-pod -n ckad-prod -o jsonpath='{.spec.containers[0].resources.limits}'
echo ""
```

**Salida esperada:**

```
=== DEV Resources ===
{"cpu":"100m","memory":"128Mi"}
=== PROD Resources ===
{"cpu":"500m","memory":"512Mi"}
```

4. Verifica el volumen de cache adicional en prod:

```bash
kubectl get pod prod-persistent-app-pod -n ckad-prod -o jsonpath='{.spec.volumes[*].name}'
echo ""
# Esperado: app-storage nginx-config-volume cache-volume
```

5. Verifica las anotaciones de versión en prod:

```bash
kubectl get pod prod-persistent-app-pod -n ckad-prod -o jsonpath='{.metadata.annotations}' | jq .
```

**Salida esperada:**

```json
{
  "lab": "02-00-05",
  "release-date": "2024-06-15",
  "team": "operaciones",
  "version": "1.0.0"
}
```

**Verificación:**

```bash
# Verificar que prod Pod está Running
kubectl get pod prod-persistent-app-pod -n ckad-prod -o jsonpath='{.status.phase}'
echo ""
# Esperado: Running

# Verificar que el cache volume existe
kubectl exec prod-persistent-app-pod -n ckad-prod -- df -h /var/cache/nginx
# Debe mostrar el mount point sin errores

# Verificar health endpoint en prod
kubectl exec prod-persistent-app-pod -n ckad-prod -- curl -s localhost/health
# Esperado: OK
```

---

### Paso 9: Agregar un SecretGenerator al overlay prod

**Objetivo:** Demostrar el uso de `secretGenerator` para gestionar credenciales de forma declarativa sin exponerlas en manifiestos base.

**Instrucciones:**

1. Agrega un `secretGenerator` al overlay prod:

```bash
cat > ~/ckad-labs/lab07/overlays/prod/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: ckad-prod

namePrefix: prod-

commonLabels:
  environment: production

commonAnnotations:
  team: operaciones
  lab: "02-00-05"
  version: "1.0.0"
  release-date: "2024-06-15"

patches:
  - target:
      kind: Pod
      name: persistent-app-pod
    patch: |-
      apiVersion: v1
      kind: Pod
      metadata:
        name: persistent-app-pod
      spec:
        containers:
          - name: nginx
            resources:
              requests:
                cpu: "250m"
                memory: "256Mi"
              limits:
                cpu: "500m"
                memory: "512Mi"
  - target:
      kind: Pod
      name: persistent-app-pod
    path: add-cache-volume.yaml

# Generador de Secrets
secretGenerator:
  - name: app-credentials
    literals:
      - DB_HOST=postgres.ckad-prod.svc.cluster.local
      - DB_PORT=5432
      - DB_USER=app_user
      - DB_PASSWORD=s3cur3P@ss!
    type: Opaque
EOF
```

2. Verifica que el Secret se genera correctamente:

```bash
cd ~/ckad-labs/lab07
kustomize build overlays/prod/ | grep -A10 "kind: Secret"
```

**Salida esperada:**

```yaml
apiVersion: v1
data:
  DB_HOST: cG9zdGdyZXMuY2thZC1wcm9kLnN2Yy5jbHVzdGVyLmxvY2Fs
  DB_PASSWORD: czNjdXIzUEBzcyE=
  DB_PORT: NTQzMg==
  DB_USER: YXBwX3VzZXI=
kind: Secret
metadata:
  annotations:
    lab: "02-00-05"
    release-date: "2024-06-15"
    team: operaciones
    version: "1.0.0"
  labels:
    course: ckad-labs
    environment: production
    managed-by: kustomize
  name: prod-app-credentials-<hash>
  namespace: ckad-prod
type: Opaque
```

3. Aplica la actualización al clúster:

```bash
kubectl apply -k overlays/prod/
```

4. Verifica el Secret en el clúster:

```bash
kubectl get secrets -n ckad-prod -l environment=production
```

**Verificación:**

```bash
# Decodificar un valor del secret para confirmar
kubectl get secret -n ckad-prod -l environment=production -o jsonpath='{.items[0].data.DB_USER}' | base64 -d
echo ""
# Esperado: app_user
```

---

### Paso 10: Verificar la estructura final del proyecto

**Objetivo:** Confirmar que la estructura de directorios y archivos es completa y coherente.

**Instrucciones:**

1. Muestra el árbol completo del proyecto:

```bash
find ~/ckad-labs/lab07 -type f | sort
```

**Salida esperada:**

```
/home/<usuario>/ckad-labs/lab07/base/kustomization.yaml
/home/<usuario>/ckad-labs/lab07/base/nginx.conf
/home/<usuario>/ckad-labs/lab07/base/persistent-app-pod.yaml
/home/<usuario>/ckad-labs/lab07/base/pvc-app-data.yaml
/home/<usuario>/ckad-labs/lab07/overlays/dev/kustomization.yaml
/home/<usuario>/ckad-labs/lab07/overlays/prod/add-cache-volume.yaml
/home/<usuario>/ckad-labs/lab07/overlays/prod/kustomization.yaml
```

2. Ejecuta un build final de ambos overlays para confirmar que no hay errores:

```bash
echo "=== BUILD DEV ===" && kustomize build overlays/dev/ > /dev/null && echo "OK"
echo "=== BUILD PROD ===" && kustomize build overlays/prod/ > /dev/null && echo "OK"
```

**Salida esperada:**

```
=== BUILD DEV ===
OK
=== BUILD PROD ===
OK
```

## Validación y Pruebas

Ejecuta el siguiente bloque de validación completa para confirmar que todos los objetivos del laboratorio se han cumplido:

```bash
#!/bin/bash
echo "============================================"
echo "  VALIDACIÓN COMPLETA - Lab 02-00-05"
echo "============================================"

PASS=0
FAIL=0

# Test 1: Estructura de directorios
echo -n "[1/8] Estructura de directorios... "
if [ -f ~/ckad-labs/lab07/base/kustomization.yaml ] && \
   [ -f ~/ckad-labs/lab07/overlays/dev/kustomization.yaml ] && \
   [ -f ~/ckad-labs/lab07/overlays/prod/kustomization.yaml ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 2: Build base sin errores
echo -n "[2/8] Build base válido... "
if kustomize build ~/ckad-labs/lab07/base/ > /dev/null 2>&1; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 3: Build dev sin errores
echo -n "[3/8] Build overlay dev válido... "
if kustomize build ~/ckad-labs/lab07/overlays/dev/ > /dev/null 2>&1; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 4: Build prod sin errores
echo -n "[4/8] Build overlay prod válido... "
if kustomize build ~/ckad-labs/lab07/overlays/prod/ > /dev/null 2>&1; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

# Test 5: Pod dev Running en ckad-dev
echo -n "[5/8] Pod dev en namespace ckad-dev... "
STATUS=$(kubectl get pod dev-persistent-app-pod -n ckad-dev -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$STATUS" = "Running" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (status: $STATUS)"; ((FAIL++))
fi

# Test 6: Pod prod Running en ckad-prod
echo -n "[6/8] Pod prod en namespace ckad-prod... "
STATUS=$(kubectl get pod prod-persistent-app-pod -n ckad-prod -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$STATUS" = "Running" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (status: $STATUS)"; ((FAIL++))
fi

# Test 7: Recursos diferenciados
echo -n "[7/8] Recursos CPU diferenciados (dev=100m, prod=500m)... "
DEV_CPU=$(kubectl get pod dev-persistent-app-pod -n ckad-dev -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
PROD_CPU=$(kubectl get pod prod-persistent-app-pod -n ckad-prod -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
if [ "$DEV_CPU" = "100m" ] && [ "$PROD_CPU" = "500m" ]; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL (dev=$DEV_CPU, prod=$PROD_CPU)"; ((FAIL++))
fi

# Test 8: ConfigMap generado y montado
echo -n "[8/8] ConfigMap montado en /etc/nginx/conf.d... "
if kubectl exec dev-persistent-app-pod -n ckad-dev -- ls /etc/nginx/conf.d/nginx.conf > /dev/null 2>&1; then
  echo "PASS"; ((PASS++))
else
  echo "FAIL"; ((FAIL++))
fi

echo "============================================"
echo "  Resultado: $PASS/8 PASS, $FAIL/8 FAIL"
echo "============================================"
```

## Troubleshooting

### Problema 1: Error "no matches for kind PersistentVolumeClaim" al aplicar overlays

**Síntomas:**

```
error: resource mapping not found for name: "dev-app-data-pvc" namespace: "ckad-dev"
```

O el PVC queda en estado `Pending` indefinidamente.

**Causa:** El clúster kind no tiene un StorageClass por defecto configurado, o el nombre del PVC en el patch no coincide con el nombre original tras aplicar `namePrefix`.

**Solución:**

```bash
# Verificar StorageClass disponible
kubectl get storageclass

# Si no hay StorageClass, crear una para kind
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF

# Si el problema es el nombre del PVC, verificar que el Pod referencia
# el nombre correcto. Kustomize actualiza automáticamente las referencias
# de PVC dentro del Pod cuando usa namePrefix, pero solo si el nombre
# coincide exactamente con el definido en el PVC.
kustomize build overlays/dev/ | grep claimName
# Debe mostrar: claimName: dev-app-data-pvc
```

---

### Problema 2: El patch de recursos no se aplica — el Pod mantiene los limits originales

**Síntomas:**

Después de `kubectl apply -k overlays/dev/`, el Pod muestra los limits originales (250m/256Mi) en lugar de los reducidos (100m/128Mi).

```bash
kubectl get pod dev-persistent-app-pod -n ckad-dev -o jsonpath='{.spec.containers[0].resources.limits}'
# Muestra: {"cpu":"250m","memory":"256Mi"}  <-- valores base, no parcheados
```

**Causa:** El campo `name` en el Strategic Merge Patch dentro de `spec.containers` no coincide exactamente con el nombre del contenedor definido en el manifiesto base. Kustomize usa el campo `name` como clave de merge para listas de contenedores.

**Solución:**

```bash
# Verificar el nombre exacto del contenedor en el base
grep "name:" ~/ckad-labs/lab07/base/persistent-app-pod.yaml

# El patch DEBE usar exactamente el mismo nombre de contenedor
# Correcto:
#   containers:
#     - name: nginx          <-- debe coincidir exactamente
#       resources: ...

# Verificar que el build muestra los valores correctos ANTES de aplicar
kustomize build overlays/dev/ | grep -A6 "resources:"

# Si el build muestra valores correctos pero el clúster no,
# eliminar y recrear el Pod (los Pods no se actualizan in-place)
kubectl delete -k overlays/dev/
kubectl apply -k overlays/dev/
```

## Limpieza

```bash
# Eliminar recursos del overlay dev
kubectl delete -k ~/ckad-labs/lab07/overlays/dev/

# Eliminar recursos del overlay prod
kubectl delete -k ~/ckad-labs/lab07/overlays/prod/

# Verificar que no quedan recursos
kubectl get pods,pvc,configmap,secret -n ckad-dev -l managed-by=kustomize
kubectl get pods,pvc,configmap,secret -n ckad-prod -l managed-by=kustomize

# NOTA: NO eliminar los archivos de ~/ckad-labs/lab07/ ya que
# establecen el patrón de gestión que se referencia en labs posteriores
```

## Resumen

En este laboratorio has aplicado los principios fundamentales de Kustomize para gestionar configuraciones diferenciadas por entorno:

| Concepto | Aplicación en este lab |
|----------|----------------------|
| **Directorio base** | Manifiestos reutilizables (PVC, Pod, ConfigMap) sin duplicación |
| **Overlays** | Personalizaciones por entorno (dev/prod) con namespaces separados |
| **namePrefix** | Diferenciación de nombres: `dev-` vs `prod-` |
| **commonLabels** | Etiquetas automáticas: `environment: development/production` |
| **commonAnnotations** | Metadatos de versión y equipo responsable |
| **Strategic Merge Patch** | Modificación de recursos CPU/memoria sin duplicar el Pod completo |
| **JSON 6902 Patch** | Adición quirúrgica de volúmenes en producción |
| **ConfigMapGenerator** | Gestión declarativa de nginx.conf con hash automático |
| **SecretGenerator** | Credenciales generadas con hash para rotación automática |

### Relación con la anatomía del Pod

Los conceptos de esta lección sobre la estructura del Pod (`spec.containers`, `spec.volumes`, `volumeMounts`, `resources`) se aplican directamente en los patches de Kustomize. Comprender que el campo `name` en `containers` actúa como clave de merge es esencial para escribir patches correctos.

### Recursos adicionales

- [Documentación oficial de Kustomize](https://kustomize.io/)
- [Kustomize — Referencia de kustomization.yaml](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/)
- [Strategic Merge Patch en Kubernetes](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#customizing)
- [JSON Patch RFC 6902](https://datatracker.ietf.org/doc/html/rfc6902)
