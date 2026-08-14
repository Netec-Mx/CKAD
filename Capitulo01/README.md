# Preparación del entorno CKAD

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Fácil |
| **Nivel Bloom** | Aplicar |
| **Tecnologías** | Docker Engine 26.1.4, minikube 1.33.1, kubectl 1.30.2, bash-completion 2.11, vim 9.0.0749 |

## Descripción General

En este laboratorio instalarás y configurarás desde cero el entorno completo necesario para todos los laboratorios del curso CKAD. Partiendo de un sistema Ubuntu 22.04 LTS limpio, instalarás Docker Engine, minikube y kubectl en sus versiones específicas, iniciarás un clúster Kubernetes de un solo nodo, configurarás alias y autocompletado para maximizar tu productividad con `kubectl`, y explorarás los componentes internos del clúster para comprender la arquitectura que soporta tus aplicaciones.

## Objetivos de Aprendizaje

- [ ] Instalar y verificar Docker 26.1.4, minikube 1.33.1 y kubectl 1.30.2 en Ubuntu 22.04 LTS
- [ ] Iniciar un clúster minikube funcional con Kubernetes 1.30.2 usando el driver Docker
- [ ] Configurar alias de kubectl, autocompletado bash y ajustes de vim para edición YAML eficiente
- [ ] Crear la estructura de directorios estándar `~/ckad-labs/` con subdirectorios por laboratorio
- [ ] Identificar los componentes del plano de control (API Server, etcd, scheduler, controller-manager) verificando su estado en el clúster

## Prerrequisitos

### Conocimientos

- Comandos básicos de Linux: `ls`, `cd`, `mkdir`, `cat`, `echo`, `chmod`, `curl`, `sudo`
- Conceptos básicos de contenedores y virtualización
- Familiaridad con editores de texto en terminal (vim o nano)

### Acceso y Recursos

- Sistema operativo Ubuntu 22.04 LTS instalado y actualizado
- Acceso a internet para descargar binarios e imágenes de contenedor
- Permisos de administrador (`sudo`) en el sistema
- Virtualización habilitada en BIOS/UEFI (requerido para minikube con driver Docker)

## Entorno del Laboratorio

### Requisitos de Hardware

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU | 2 núcleos | 4 núcleos |
| RAM | 4 GB | 8 GB |
| Disco | 30 GB libres | 40 GB libres (SSD) |
| Red | Conexión a internet | Conexión estable ≥10 Mbps |

### Software Objetivo

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| Docker Engine | 26.1.4 | Runtime de contenedores y driver de minikube |
| minikube | 1.33.1 | Clúster Kubernetes local de un solo nodo |
| kubectl | 1.30.2 | Cliente CLI para interactuar con la API de Kubernetes |
| bash-completion | 2.11 | Autocompletado de comandos kubectl |
| vim | 9.0+ | Edición de manifiestos YAML |

---

## Procedimiento Paso a Paso

### Paso 1: Actualizar el Sistema Operativo

**Objetivo:** Asegurar que el sistema tiene los paquetes más recientes y las dependencias necesarias para las instalaciones posteriores.

**Instrucciones:**

1. Abre una terminal en tu sistema Ubuntu 22.04 LTS.

2. Actualiza la lista de paquetes y los paquetes instalados:

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

3. Instala paquetes de utilidades necesarios para los pasos siguientes:

```bash
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common bash-completion vim git jq
```

**Salida esperada:**

```
Reading package lists... Done
Building dependency tree... Done
...
The following NEW packages will be installed:
  bash-completion jq ...
...
Processing triggers for man-db ...
```

**Verificación:**

```bash
bash --version | head -1
vim --version | head -1
git --version
jq --version
```

Debes ver las versiones instaladas sin errores. Confirma que `bash-completion` está presente:

```bash
dpkg -l | grep bash-completion
```

---

### Paso 2: Instalar Docker Engine 26.1.4

**Objetivo:** Instalar Docker Engine en la versión específica 26.1.4, que servirá como runtime de contenedores y driver para minikube.

**Instrucciones:**

1. Elimina versiones anteriores de Docker si existieran:

```bash
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
```

2. Añade la clave GPG oficial de Docker:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

3. Configura el repositorio de Docker:

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

4. Actualiza la lista de paquetes e instala Docker Engine 26.1.4:

```bash
sudo apt-get update
sudo apt-get install -y docker-ce=5:26.1.4-1~ubuntu.22.04~jammy docker-ce-cli=5:26.1.4-1~ubuntu.22.04~jammy containerd.io docker-buildx-plugin
```

> **Nota:** Si la versión exacta no está disponible en el repositorio, lista las versiones disponibles con `apt-cache madison docker-ce` y selecciona la más cercana a 26.1.4.

5. Añade tu usuario al grupo `docker` para ejecutar comandos sin `sudo`:

```bash
sudo usermod -aG docker $USER
```

6. Aplica el cambio de grupo sin cerrar sesión:

```bash
newgrp docker
```

**Salida esperada:**

```
docker-ce is already the newest version (5:26.1.4-1~ubuntu.22.04~jammy).
```

**Verificación:**

```bash
docker --version
```

Salida esperada:

```
Docker version 26.1.4, build 5650f9b
```

Verifica que Docker funciona correctamente:

```bash
docker run --rm hello-world
```

Debes ver el mensaje "Hello from Docker!" confirmando que el daemon está operativo.

---

### Paso 3: Instalar kubectl 1.30.2

**Objetivo:** Instalar el cliente de línea de comandos kubectl en la versión 1.30.2 para interactuar con la API de Kubernetes.

**Instrucciones:**

1. Descarga el binario de kubectl 1.30.2:

```bash
curl -LO "https://dl.k8s.io/release/v1.30.2/bin/linux/amd64/kubectl"
```

2. Descarga el checksum para verificar la integridad:

```bash
curl -LO "https://dl.k8s.io/release/v1.30.2/bin/linux/amd64/kubectl.sha256"
```

3. Verifica la integridad del binario:

```bash
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
```

Salida esperada:

```
kubectl: OK
```

4. Instala kubectl en el PATH del sistema:

```bash
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

5. Limpia los archivos descargados:

```bash
rm -f kubectl kubectl.sha256
```

**Verificación:**

```bash
kubectl version --client --output=yaml
```

Salida esperada (fragmento):

```yaml
clientVersion:
  gitVersion: v1.30.2
  major: "1"
  minor: "30"
```

---

### Paso 4: Instalar minikube 1.33.1

**Objetivo:** Instalar minikube 1.33.1 para crear un clúster Kubernetes local de un solo nodo.

**Instrucciones:**

1. Descarga el binario de minikube 1.33.1:

```bash
curl -LO https://github.com/kubernetes/minikube/releases/download/v1.33.1/minikube-linux-amd64
```

2. Instala minikube en el PATH del sistema:

```bash
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

3. Limpia el archivo descargado:

```bash
rm -f minikube-linux-amd64
```

**Verificación:**

```bash
minikube version
```

Salida esperada:

```
minikube version: v1.33.1
commit: 5883c09216182566a63dff4c326a6fc9ed2982ff
```

---

### Paso 5: Iniciar el Clúster minikube con Kubernetes 1.30.2

**Objetivo:** Crear e iniciar un clúster Kubernetes de un solo nodo usando minikube con el driver Docker y la versión específica de Kubernetes 1.30.2.

**Instrucciones:**

1. Inicia el clúster minikube especificando la versión de Kubernetes y los recursos:

```bash
minikube start \
  --driver=docker \
  --kubernetes-version=v1.30.2 \
  --cpus=2 \
  --memory=4096 \
  --disk-size=20g
```

> **Nota:** Si tienes más recursos disponibles, puedes aumentar `--cpus=4` y `--memory=8192` para mejor rendimiento en laboratorios posteriores.

2. Espera a que el proceso complete. Esto puede tomar entre 2 y 5 minutos dependiendo de tu conexión a internet y velocidad de disco.

**Salida esperada:**

```
😄  minikube v1.33.1 on Ubuntu 22.04
✨  Using the docker driver based on user configuration
📌  Using Docker driver with root privileges
👍  Starting "minikube" primary control-plane node in "minikube" cluster
🚜  Pulling base image v0.0.44 ...
🔥  Creating docker container (CPUs=2, Memory=4096MB) ...
🐳  Preparing Kubernetes v1.30.2 on Docker 26.1.4 ...
    ▪ Generating certificates and keys ...
    ▪ Booting up control plane ...
    ▪ Configuring RBAC rules ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
    ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

**Verificación:**

```bash
minikube status
```

Salida esperada:

```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

Verifica la comunicación con el clúster:

```bash
kubectl cluster-info
```

Salida esperada:

```
Kubernetes control plane is running at https://192.168.49.2:8443
CoreDNS is running at https://192.168.49.2:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

Confirma la versión del servidor:

```bash
kubectl version --output=yaml | grep -A2 serverVersion
```

Debes ver `gitVersion: v1.30.2` en la sección `serverVersion`.

---

### Paso 6: Configurar Alias y Autocompletado de kubectl

**Objetivo:** Configurar alias de productividad y autocompletado bash para kubectl, simulando las condiciones recomendadas para el examen CKAD.

**Instrucciones:**

1. Configura el autocompletado de kubectl para bash:

```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
```

2. Añade los alias obligatorios del curso al archivo `~/.bashrc`:

```bash
cat >> ~/.bashrc << 'EOF'

# === CKAD Aliases ===
alias k=kubectl
alias kns='kubectl config set-context --current --namespace'
alias kgp='kubectl get pods'
alias kd='kubectl describe'

# Autocompletado para el alias 'k'
complete -o default -F __start_kubectl k
EOF
```

3. Recarga el archivo `~/.bashrc` para activar los cambios:

```bash
source ~/.bashrc
```

**Verificación:**

```bash
# Verificar que los alias están activos
alias k
alias kns
alias kgp
alias kd
```

Salida esperada:

```
alias k='kubectl'
alias kns='kubectl config set-context --current --namespace'
alias kgp='kubectl get pods'
alias kd='kubectl describe'
```

Prueba el alias `k`:

```bash
k get nodes
```

Salida esperada:

```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   Xm    v1.30.2
```

Prueba el autocompletado escribiendo `k get no` y presionando `Tab`. Debe autocompletar a `k get nodes`.

---

### Paso 7: Configurar vim para Edición YAML

**Objetivo:** Configurar el editor vim con ajustes óptimos para edición de manifiestos YAML de Kubernetes, respetando la indentación de 2 espacios.

**Instrucciones:**

1. Crea o sobrescribe el archivo `~/.vimrc` con la configuración para YAML:

```bash
cat > ~/.vimrc << 'EOF'
" Configuración CKAD para edición YAML
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set smartindent
set number
set cursorline
set paste
syntax on
filetype plugin indent on
EOF
```

**Verificación:**

```bash
cat ~/.vimrc
```

Confirma que el archivo contiene las 10 líneas de configuración. Prueba abriendo un archivo YAML temporal:

```bash
echo -e "apiVersion: v1\nkind: Pod\nmetadata:\n  name: test" > /tmp/test.yaml
vim /tmp/test.yaml
```

Dentro de vim, verifica que los números de línea aparecen a la izquierda y que al presionar `Tab` se insertan 2 espacios. Sal con `:q!`.

---

### Paso 8: Crear la Estructura de Directorios de Trabajo

**Objetivo:** Crear la estructura de directorios estándar `~/ckad-labs/` que se usará en todos los laboratorios del curso.

**Instrucciones:**

1. Crea el directorio base y todos los subdirectorios de laboratorio:

```bash
mkdir -p ~/ckad-labs/{lab01,lab02,lab03,lab04,lab05}
```

2. Verifica la estructura creada:

```bash
tree ~/ckad-labs/
```

Si `tree` no está instalado:

```bash
sudo apt-get install -y tree
tree ~/ckad-labs/
```

**Salida esperada:**

```
/home/<usuario>/ckad-labs/
├── lab01
├── lab02
├── lab03
├── lab04
└── lab05

5 directories, 0 files
```

**Verificación:**

```bash
ls -la ~/ckad-labs/
```

Confirma que existen los 5 subdirectorios con permisos de lectura/escritura para tu usuario.

---

### Paso 9: Explorar los Componentes del Plano de Control

**Objetivo:** Identificar y verificar el estado de los componentes fundamentales del clúster Kubernetes (API Server, etcd, scheduler, controller-manager, CoreDNS, kube-proxy) examinando los pods del namespace `kube-system`.

**Instrucciones:**

1. Lista todos los pods del namespace `kube-system`:

```bash
kubectl get pods -n kube-system
```

**Salida esperada:**

```
NAME                               READY   STATUS    RESTARTS   AGE
coredns-7db6d8ff4d-xxxxx           1/1     Running   0          Xm
etcd-minikube                      1/1     Running   0          Xm
kube-apiserver-minikube            1/1     Running   0          Xm
kube-controller-manager-minikube   1/1     Running   0          Xm
kube-proxy-xxxxx                   1/1     Running   0          Xm
kube-scheduler-minikube            1/1     Running   0          Xm
storage-provisioner                1/1     Running   0          Xm
```

2. Examina los detalles del API Server para entender su configuración:

```bash
kubectl describe pod kube-apiserver-minikube -n kube-system | head -40
```

3. Verifica el estado del etcd:

```bash
kubectl describe pod etcd-minikube -n kube-system | grep -A5 "State:"
```

4. Identifica el rol de cada componente listando sus contenedores:

```bash
kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
```

**Salida esperada (ejemplo):**

```
NAME                               IMAGE
coredns-7db6d8ff4d-xxxxx           registry.k8s.io/coredns/coredns:v1.11.1
etcd-minikube                      registry.k8s.io/etcd:3.5.12-0
kube-apiserver-minikube            registry.k8s.io/kube-apiserver:v1.30.2
kube-controller-manager-minikube   registry.k8s.io/kube-controller-manager:v1.30.2
kube-proxy-xxxxx                   registry.k8s.io/kube-proxy:v1.30.2
kube-scheduler-minikube            registry.k8s.io/kube-scheduler:v1.30.2
storage-provisioner                gcr.io/k8s-minikube/storage-provisioner:v5
```

5. Verifica que todos los componentes están en estado `Running`:

```bash
kubectl get pods -n kube-system --field-selector=status.phase=Running --no-headers | wc -l
```

El número debe coincidir con el total de pods listados (típicamente 7).

6. Examina los nodos del clúster y sus condiciones:

```bash
kubectl get nodes -o wide
```

```bash
kubectl describe node minikube | grep -A10 "Conditions:"
```

**Verificación:**

Confirma que todos los componentes esenciales están presentes y en estado `Running`:

```bash
echo "=== Verificación de componentes del plano de control ==="
for component in etcd kube-apiserver kube-scheduler kube-controller-manager; do
  status=$(kubectl get pods -n kube-system -l component=$component -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  echo "$component: $status"
done
echo "=== CoreDNS ==="
kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].status.phase}'
echo ""
```

---

### Paso 10: Verificación Final del Entorno Completo

**Objetivo:** Ejecutar una verificación integral que confirme que todas las herramientas, configuraciones y el clúster están operativos.

**Instrucciones:**

1. Ejecuta el siguiente script de verificación completa:

```bash
echo "============================================"
echo "  VERIFICACIÓN DEL ENTORNO CKAD"
echo "============================================"
echo ""

echo "[1/7] Docker Engine:"
docker --version
echo ""

echo "[2/7] kubectl:"
kubectl version --client --short 2>/dev/null || kubectl version --client | grep gitVersion
echo ""

echo "[3/7] minikube:"
minikube version | head -1
echo ""

echo "[4/7] Clúster Kubernetes:"
kubectl cluster-info | head -1
echo ""

echo "[5/7] Nodo del clúster:"
kubectl get nodes
echo ""

echo "[6/7] Alias de kubectl:"
alias k 2>/dev/null && echo "  ✓ alias k activo"
alias kgp 2>/dev/null && echo "  ✓ alias kgp activo"
alias kns 2>/dev/null && echo "  ✓ alias kns activo"
alias kd 2>/dev/null && echo "  ✓ alias kd activo"
echo ""

echo "[7/7] Estructura de directorios:"
ls ~/ckad-labs/ | tr '\n' ' '
echo ""
echo ""
echo "============================================"
echo "  ENTORNO LISTO ✓"
echo "============================================"
```

**Salida esperada:**

```
============================================
  VERIFICACIÓN DEL ENTORNO CKAD
============================================

[1/7] Docker Engine:
Docker version 26.1.4, build 5650f9b

[2/7] kubectl:
  gitVersion: v1.30.2

[3/7] minikube:
minikube version: v1.33.1

[4/7] Clúster Kubernetes:
Kubernetes control plane is running at https://192.168.49.2:8443

[5/7] Nodo del clúster:
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   Xm    v1.30.2

[6/7] Alias de kubectl:
alias k='kubectl'
  ✓ alias k activo
alias kgp='kubectl get pods'
  ✓ alias kgp activo
alias kns='kubectl config set-context --current --namespace'
  ✓ alias kns activo
alias kd='kubectl describe'
  ✓ alias kd activo

[7/7] Estructura de directorios:
lab01 lab02 lab03 lab04 lab05

============================================
  ENTORNO LISTO ✓
============================================
```

---

## Validación y Pruebas

Ejecuta las siguientes comprobaciones para confirmar que el laboratorio se completó exitosamente:

| # | Criterio de Validación | Comando | Resultado Esperado |
|---|---|---|---|
| 1 | Docker instalado y funcional | `docker --version` | `Docker version 26.1.4` |
| 2 | kubectl versión correcta | `kubectl version --client -o yaml \| grep gitVersion` | `v1.30.2` |
| 3 | minikube versión correcta | `minikube version` | `v1.33.1` |
| 4 | Clúster en estado Running | `minikube status \| grep -c Running` | `3` (host, kubelet, apiserver) |
| 5 | Nodo Ready con versión correcta | `kubectl get nodes` | `minikube   Ready   ...   v1.30.2` |
| 6 | Alias k funcional | `k get nodes --no-headers \| wc -l` | `1` |
| 7 | Directorios creados | `ls ~/ckad-labs/ \| wc -l` | `5` |
| 8 | Componentes del plano de control activos | `kubectl get pods -n kube-system --field-selector=status.phase=Running --no-headers \| wc -l` | `≥ 7` |
| 9 | vim configurado | `grep -c expandtab ~/.vimrc` | `1` |
| 10 | Autocompletado configurado | `grep -c "kubectl completion bash" ~/.bashrc` | `1` |

---

## Solución de Problemas

### Problema 1: minikube start falla con error de permisos de Docker

**Síntomas:**

```
❌  Exiting due to PROVIDER_DOCKER_NEWGRP: "docker version --format <no value>-<no value>:<no value>" exit status 1: permission denied while trying to connect to the Docker daemon socket
```

**Causa:** El usuario actual no pertenece al grupo `docker`, o el cambio de grupo no se ha aplicado en la sesión actual. Esto ocurre cuando se ejecutó `sudo usermod -aG docker $USER` pero no se recargó la sesión.

**Solución:**

```bash
# Opción 1: Aplicar el grupo sin cerrar sesión
newgrp docker

# Opción 2: Verificar pertenencia al grupo
groups $USER | grep docker

# Si no aparece 'docker', volver a añadir y reiniciar sesión completa:
sudo usermod -aG docker $USER
# Cerrar la terminal completamente y abrir una nueva

# Verificar que Docker responde sin sudo:
docker ps
```

Si después de `newgrp docker` el problema persiste, cierra sesión completamente (logout/login) y vuelve a intentar `minikube start`.

---

### Problema 2: kubectl get nodes muestra NotReady o no conecta al clúster

**Síntomas:**

```
E1201 10:15:32.123456 Unable to connect to the server: dial tcp 192.168.49.2:8443: connect: connection refused
```

O bien el nodo aparece como `NotReady`:

```
NAME       STATUS     ROLES           AGE   VERSION
minikube   NotReady   control-plane   5m    v1.30.2
```

**Causa:** El clúster minikube no terminó de inicializarse correctamente, el contenedor Docker de minikube se detuvo, o los componentes del plano de control aún están arrancando.

**Solución:**

```bash
# 1. Verificar el estado de minikube
minikube status

# 2. Si host está Stopped, reiniciar:
minikube start

# 3. Si el problema persiste, verificar que Docker está corriendo:
sudo systemctl status docker
sudo systemctl start docker

# 4. Verificar el contenedor de minikube:
docker ps | grep minikube

# 5. Si el contenedor no existe, eliminar y recrear el clúster:
minikube delete
minikube start \
  --driver=docker \
  --kubernetes-version=v1.30.2 \
  --cpus=2 \
  --memory=4096 \
  --disk-size=20g

# 6. Esperar 60 segundos y verificar:
sleep 60
kubectl get nodes
kubectl get pods -n kube-system
```

Si el nodo aparece como `NotReady`, espera 1-2 minutos adicionales. Los componentes de red (CNI, CoreDNS) pueden tardar en estabilizarse. Monitorea con:

```bash
kubectl get nodes -w
```

---

## Limpieza

Este laboratorio **NO requiere limpieza**, ya que establece el entorno base que todos los laboratorios posteriores utilizarán. El clúster minikube, los alias, la configuración de vim y la estructura de directorios deben permanecer intactos.

Si necesitas detener el clúster temporalmente (por ejemplo, para apagar el equipo):

```bash
# Detener el clúster (preserva el estado)
minikube stop

# Reiniciar el clúster cuando vuelvas
minikube start
```

> ⚠️ **No ejecutes `minikube delete`** a menos que necesites recrear el entorno desde cero.

---

## Resumen

En este laboratorio has completado la preparación completa del entorno CKAD:

| Logro | Detalle |
|-------|---------|
| Docker Engine | Versión 26.1.4 instalada y funcional sin sudo |
| kubectl | Versión 1.30.2 instalada y comunicándose con el clúster |
| minikube | Versión 1.33.1 con clúster Kubernetes 1.30.2 activo |
| Productividad | Alias `k`, `kns`, `kgp`, `kd` + autocompletado bash configurados |
| Editor | vim configurado con indentación de 2 espacios para YAML |
| Directorios | Estructura `~/ckad-labs/{lab01..lab05}` creada |
| Arquitectura | Componentes del plano de control identificados y verificados |

Has confirmado que el clúster ejecuta los componentes esenciales que soportan las aplicaciones: el **API Server** recibe tus manifiestos, **etcd** almacena el estado del clúster, el **scheduler** decide dónde ejecutar tus Pods, el **controller-manager** mantiene el estado deseado, **CoreDNS** resuelve nombres de servicio y **kube-proxy** gestiona las reglas de red. Esta comprensión de la arquitectura te acompañará en cada laboratorio posterior.

### Recursos Adicionales

- [Documentación oficial de minikube](https://minikube.sigs.k8s.io/docs/)
- [Referencia de kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Arquitectura de Kubernetes — Componentes](https://kubernetes.io/docs/concepts/overview/components/)
- [Curriculum CKAD — CNCF GitHub](https://github.com/cncf/curriculum)
- [Guía de instalación de Docker Engine en Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

---

# Gestión básica con kubectl y YAML

## Metadata

| Campo | Valor |
|-------|-------|
| **Duración** | 45 minutos |
| **Complejidad** | Fácil |
| **Nivel Bloom** | Aplicar |

## Descripción General

En este laboratorio practicarás el flujo de trabajo completo de kubectl como desarrollador de aplicaciones en Kubernetes. Generarás manifiestos YAML usando el flag `--dry-run=client -o yaml`, crearás namespaces para organizar recursos, desplegarás un Pod con etiquetas y anotaciones, y configurarás el contexto de kubectl para trabajar eficientemente. Al finalizar, tendrás un entorno base en el namespace `ckad-dev` que utilizarás en los laboratorios posteriores del módulo 2.

## Objetivos de Aprendizaje

- [ ] Generar manifiestos YAML base usando `kubectl create` con `--dry-run=client -o yaml` y guardarlos en archivos
- [ ] Crear y gestionar namespaces, configurando el contexto de kubectl para apuntar a `ckad-dev` por defecto
- [ ] Desplegar un Pod desde un manifiesto YAML declarativo usando `kubectl apply -f`
- [ ] Añadir etiquetas y anotaciones a recursos existentes, y filtrar recursos usando selectores `-l`
- [ ] Inspeccionar recursos con `kubectl get`, `kubectl describe`, `kubectl explain` y `kubectl logs`

## Prerrequisitos

### Conocimiento Requerido

- Estructura básica de YAML: indentación con espacios, listas y mapas
- Conceptos fundamentales de Kubernetes: Pod, Namespace, API Server
- Uso básico de la terminal Linux y editor vim

### Acceso y Entorno Previo

- Laboratorio 01-00-01 completado exitosamente
- Clúster minikube 1.33.1 con Kubernetes 1.30.2 en estado `Ready`
- Alias `k=kubectl` y autocompletado de bash configurados en `~/.bashrc`
- Directorio `~/ckad-labs/lab01/` existente
- Archivo `~/.vimrc` configurado para edición YAML

## Entorno del Laboratorio

### Software Requerido

| Herramienta | Versión | Propósito |
|-------------|---------|-----------|
| minikube | 1.33.1 | Clúster local de Kubernetes |
| kubectl | 1.30.2 | CLI para interactuar con el clúster |
| vim | 9.0.0749 | Editor de manifiestos YAML |
| nginx (imagen) | 1.27.0 | Imagen de contenedor para el Pod |

### Verificación del Entorno

Antes de comenzar, confirma que tu entorno está operativo:

```bash
# Verificar que minikube está corriendo
minikube status

# Verificar conectividad con el clúster
kubectl cluster-info

# Verificar que el nodo está Ready
kubectl get nodes

# Verificar que los alias están activos
type k
```

**Salida esperada** (fragmento):

```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured

k is aliased to `kubectl'
```

---

## Paso 1: Generar Manifiesto YAML de Namespace con --dry-run

### Objetivo

Aprender a usar `kubectl create` con `--dry-run=client -o yaml` para generar manifiestos YAML sin crear el recurso en el clúster, permitiendo revisarlos y editarlos antes de aplicarlos.

### Instrucciones

1. Navega al directorio de trabajo del laboratorio:

```bash
cd ~/ckad-labs/lab01/
```

2. Genera el manifiesto YAML para el namespace `ckad-dev` sin crearlo en el clúster:

```bash
kubectl create namespace ckad-dev --dry-run=client -o yaml > ns-ckad-dev.yaml
```

3. Examina el contenido del archivo generado:

```bash
cat ns-ckad-dev.yaml
```

4. Genera los manifiestos para los otros dos namespaces:

```bash
kubectl create namespace ckad-staging --dry-run=client -o yaml > ns-ckad-staging.yaml
kubectl create namespace ckad-prod --dry-run=client -o yaml > ns-ckad-prod.yaml
```

5. Verifica que los tres archivos existen:

```bash
ls -la ns-ckad-*.yaml
```

### Salida Esperada

```yaml
# Contenido de ns-ckad-dev.yaml
apiVersion: v1
kind: Namespace
metadata:
  creationTimestamp: null
  name: ckad-dev
spec: {}
status: {}
```

```
-rw-r--r-- 1 user user  ... ns-ckad-dev.yaml
-rw-r--r-- 1 user user  ... ns-ckad-prod.yaml
-rw-r--r-- 1 user user  ... ns-ckad-staging.yaml
```

### Verificación

```bash
# Confirmar que los archivos contienen YAML válido con Kind: Namespace
grep "kind: Namespace" ns-ckad-*.yaml
```

Debe mostrar tres coincidencias, una por archivo.

---

## Paso 2: Crear los Namespaces en el Clúster

### Objetivo

Aplicar los manifiestos YAML generados para crear los namespaces en el clúster usando el enfoque declarativo con `kubectl apply`.

### Instrucciones

1. Aplica los tres manifiestos de namespace:

```bash
kubectl apply -f ns-ckad-dev.yaml
kubectl apply -f ns-ckad-staging.yaml
kubectl apply -f ns-ckad-prod.yaml
```

2. Verifica que los namespaces se crearon correctamente:

```bash
kubectl get namespaces
```

3. Obtén información detallada del namespace `ckad-dev`:

```bash
kubectl describe namespace ckad-dev
```

### Salida Esperada

```
namespace/ckad-dev created
namespace/ckad-staging created
namespace/ckad-prod created
```

```
NAME              STATUS   AGE
ckad-dev          Active   5s
ckad-prod         Active   3s
ckad-staging      Active   4s
default           Active   ...
kube-node-lease   Active   ...
kube-public       Active   ...
kube-system       Active   ...
```

### Verificación

```bash
# Confirmar que los tres namespaces personalizados están Active
kubectl get ns ckad-dev ckad-staging ckad-prod -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
```

Los tres deben mostrar `Active`.

---

## Paso 3: Configurar el Contexto de kubectl

### Objetivo

Configurar el contexto actual de kubectl para que use `ckad-dev` como namespace por defecto, evitando tener que especificar `-n ckad-dev` en cada comando.

### Instrucciones

1. Verifica el contexto actual antes del cambio:

```bash
kubectl config view --minify | grep namespace
```

2. Configura el namespace por defecto del contexto actual:

```bash
kubectl config set-context --current --namespace=ckad-dev
```

3. Verifica que el cambio se aplicó correctamente:

```bash
kubectl config view --minify | grep namespace
```

4. Usa el alias definido en el laboratorio anterior para confirmar:

```bash
# El alias kns permite cambiar namespace rápidamente
# Verificamos que estamos en ckad-dev
kubectl config get-contexts
```

### Salida Esperada

```
# Antes del cambio (puede no mostrar namespace o mostrar "default")
    namespace: 

# Después del cambio
Context "minikube" modified.

    namespace: ckad-dev
```

La salida de `get-contexts` debe mostrar un asterisco `*` junto al contexto activo con namespace `ckad-dev`:

```
CURRENT   NAME       CLUSTER    AUTHINFO   NAMESPACE
*         minikube   minikube   minikube   ckad-dev
```

### Verificación

```bash
kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}'
echo ""
```

Debe imprimir: `ckad-dev`

---

## Paso 4: Generar y Editar el Manifiesto YAML del Pod

### Objetivo

Generar un manifiesto YAML base para un Pod usando `--dry-run=client`, editarlo con vim para añadir etiquetas estructuradas, y guardarlo listo para aplicar.

### Instrucciones

1. Genera el manifiesto base del Pod:

```bash
kubectl run nginx-lab --image=nginx:1.27.0 --dry-run=client -o yaml > pod-nginx-lab.yaml
```

2. Examina el contenido generado:

```bash
cat pod-nginx-lab.yaml
```

3. Edita el archivo con vim para añadir las etiquetas requeridas:

```bash
vim pod-nginx-lab.yaml
```

4. Modifica la sección `metadata.labels` para que contenga exactamente estas etiquetas:

```yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    app: web
    env: dev
    tier: frontend
  name: nginx-lab
spec:
  containers:
  - image: nginx:1.27.0
    name: nginx-lab
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```

5. Guarda el archivo y sal de vim (`:wq`).

6. Verifica la sintaxis del archivo resultante:

```bash
kubectl apply -f pod-nginx-lab.yaml --dry-run=client
```

### Salida Esperada

```
pod/nginx-lab created (dry run)
```

Esto confirma que el manifiesto es válido sin crear el recurso aún.

### Verificación

```bash
# Verificar que las tres etiquetas están presentes en el archivo
grep -A 4 "labels:" pod-nginx-lab.yaml
```

Debe mostrar `app: web`, `env: dev` y `tier: frontend`.

---

## Paso 5: Crear el Pod en el Namespace ckad-dev

### Objetivo

Aplicar el manifiesto YAML para crear el Pod en el clúster y verificar que se ejecuta correctamente en el namespace configurado.

### Instrucciones

1. Aplica el manifiesto del Pod:

```bash
kubectl apply -f pod-nginx-lab.yaml
```

2. Verifica que el Pod se está creando (puede tardar unos segundos en descargar la imagen):

```bash
kubectl get pods
```

3. Espera a que el Pod esté en estado `Running`:

```bash
kubectl get pods -w
```

Presiona `Ctrl+C` cuando veas el estado `Running`.

4. Obtén información ampliada del Pod:

```bash
kubectl get pods -o wide
```

5. Verifica que el Pod está en el namespace correcto:

```bash
kubectl get pods -n ckad-dev
```

### Salida Esperada

```
pod/nginx-lab created
```

```
NAME        READY   STATUS    RESTARTS   AGE
nginx-lab   1/1     Running   0          15s
```

Con `-o wide`:

```
NAME        READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
nginx-lab   1/1     Running   0          20s   172.17.0.3   minikube   <none>           <none>
```

### Verificación

```bash
# Usar el alias kgp para verificar
kgp
```

Debe mostrar `nginx-lab` con STATUS `Running` y READY `1/1`.

---

## Paso 6: Inspeccionar el Pod con describe y logs

### Objetivo

Usar `kubectl describe` y `kubectl logs` para inspeccionar el estado detallado del Pod y confirmar que nginx está sirviendo correctamente.

### Instrucciones

1. Describe el Pod para ver todos sus detalles:

```bash
kubectl describe pod nginx-lab
```

2. Observa las secciones clave en la salida:
   - **Labels**: deben mostrar las tres etiquetas configuradas
   - **Containers**: debe mostrar la imagen `nginx:1.27.0`
   - **Events**: debe mostrar los eventos de scheduling, pulling y starting

3. Consulta los logs del contenedor:

```bash
kubectl logs nginx-lab
```

4. Obtén la salida en formato JSON para ver la estructura completa del recurso:

```bash
kubectl get pod nginx-lab -o json | head -40
```

5. Extrae solo las etiquetas usando jsonpath:

```bash
kubectl get pod nginx-lab -o jsonpath='{.metadata.labels}' | jq .
```

### Salida Esperada

Fragmento de `kubectl describe`:

```
Name:             nginx-lab
Namespace:        ckad-dev
Priority:         0
Service Account:  default
Node:             minikube/192.168.49.2
Labels:           app=web
                  env=dev
                  tier=frontend
...
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  30s   default-scheduler  Successfully assigned ckad-dev/nginx-lab to minikube
  Normal  Pulling    29s   kubelet            Pulling image "nginx:1.27.0"
  Normal  Pulled     20s   kubelet            Successfully pulled image "nginx:1.27.0"
  Normal  Created    20s   kubelet            Created container nginx-lab
  Normal  Started    20s   kubelet            Started container nginx-lab
```

Salida de jsonpath con jq:

```json
{
  "app": "web",
  "env": "dev",
  "tier": "frontend"
}
```

### Verificación

```bash
# Usar el alias kd para describir
kd pod nginx-lab | grep -A 3 "Labels:"
```

Debe mostrar las tres etiquetas asignadas.

---

## Paso 7: Trabajar con Etiquetas y Selectores

### Objetivo

Practicar la adición de etiquetas a recursos existentes y el filtrado de recursos usando selectores de etiquetas con el flag `-l`.

### Instrucciones

1. Crea un segundo Pod para practicar filtrado (usando imperativo directo para variedad):

```bash
kubectl run nginx-backend --image=nginx:1.27.0 --labels="app=web,env=dev,tier=backend"
```

2. Lista todos los Pods con sus etiquetas:

```bash
kubectl get pods --show-labels
```

3. Filtra Pods por la etiqueta `app=web`:

```bash
kubectl get pods -l app=web
```

4. Filtra Pods por la etiqueta `tier=frontend`:

```bash
kubectl get pods -l tier=frontend
```

5. Filtra Pods usando múltiples selectores (AND lógico):

```bash
kubectl get pods -l app=web,tier=backend
```

6. Filtra Pods excluyendo un valor (operador de desigualdad):

```bash
kubectl get pods -l 'tier!=backend'
```

7. Añade una nueva etiqueta al Pod `nginx-lab`:

```bash
kubectl label pod nginx-lab version=v1
```

8. Verifica la nueva etiqueta:

```bash
kubectl get pod nginx-lab --show-labels
```

9. Modifica una etiqueta existente (requiere `--overwrite`):

```bash
kubectl label pod nginx-lab env=development --overwrite
```

10. Verifica el cambio:

```bash
kubectl get pod nginx-lab --show-labels
```

### Salida Esperada

```
NAME            READY   STATUS    RESTARTS   AGE   LABELS
nginx-backend   1/1     Running   0          5s    app=web,env=dev,tier=backend
nginx-lab       1/1     Running   0          2m    app=web,env=dev,tier=frontend
```

Filtrado con `-l tier=frontend`:

```
NAME        READY   STATUS    RESTARTS   AGE
nginx-lab   1/1     Running   0          2m
```

Después de añadir `version=v1` y modificar `env`:

```
NAME        READY   STATUS    RESTARTS   AGE   LABELS
nginx-lab   1/1     Running   0          3m    app=web,env=development,tier=frontend,version=v1
```

### Verificación

```bash
# Verificar que ambos Pods tienen la etiqueta app=web
kubectl get pods -l app=web --no-headers | wc -l
```

Debe devolver `2`.

---

## Paso 8: Añadir Anotaciones a Recursos

### Objetivo

Usar `kubectl annotate` para añadir metadatos descriptivos a los Pods que no afectan el comportamiento del sistema pero proporcionan contexto operacional.

### Instrucciones

1. Añade una anotación de descripción al Pod `nginx-lab`:

```bash
kubectl annotate pod nginx-lab description="Pod principal de laboratorio CKAD - servidor web nginx"
```

2. Añade una anotación de contacto:

```bash
kubectl annotate pod nginx-lab contact="equipo-desarrollo@empresa.com"
```

3. Verifica las anotaciones con `describe`:

```bash
kubectl describe pod nginx-lab | grep -A 5 "Annotations:"
```

4. Obtén las anotaciones en formato JSON:

```bash
kubectl get pod nginx-lab -o jsonpath='{.metadata.annotations}' | jq .
```

5. Elimina una anotación usando el sufijo `-`:

```bash
kubectl annotate pod nginx-lab contact-
```

6. Confirma la eliminación:

```bash
kubectl describe pod nginx-lab | grep -A 3 "Annotations:"
```

### Salida Esperada

```
Annotations:      contact: equipo-desarrollo@empresa.com
                  description: Pod principal de laboratorio CKAD - servidor web nginx
```

Después de eliminar `contact`:

```
Annotations:      description: Pod principal de laboratorio CKAD - servidor web nginx
```

### Verificación

```bash
kubectl get pod nginx-lab -o jsonpath='{.metadata.annotations.description}'
echo ""
```

Debe imprimir: `Pod principal de laboratorio CKAD - servidor web nginx`

---

## Paso 9: Explorar la API con kubectl explain

### Objetivo

Usar `kubectl explain` para consultar la documentación inline de los campos YAML de Kubernetes directamente desde la terminal, una habilidad esencial durante el examen CKAD.

### Instrucciones

1. Explora la estructura de nivel superior de un Pod:

```bash
kubectl explain pod
```

2. Profundiza en la especificación del Pod:

```bash
kubectl explain pod.spec
```

3. Explora los campos de un contenedor:

```bash
kubectl explain pod.spec.containers
```

4. Consulta un campo específico (por ejemplo, `image`):

```bash
kubectl explain pod.spec.containers.image
```

5. Usa el flag `--recursive` para ver toda la estructura de forma condensada:

```bash
kubectl explain pod.spec.containers --recursive | head -30
```

6. Explora la estructura de un Namespace:

```bash
kubectl explain namespace.metadata
```

### Salida Esperada

Fragmento de `kubectl explain pod.spec.containers.image`:

```
KIND:       Pod
VERSION:    v1

FIELD: image <string>

DESCRIPTION:
    Container image name. More info:
    https://kubernetes.io/docs/concepts/containers/images This field is
    optional to allow higher level config management to default or override
    container images in workload controllers like Deployments and StatefulSets.
```

### Verificación

```bash
# Confirmar que explain funciona para recursos comunes
kubectl explain pod.spec.restartPolicy
```

Debe mostrar la descripción del campo y los valores posibles (`Always`, `OnFailure`, `Never`).

---

## Paso 10: Generar un ConfigMap con --dry-run y Aplicar

### Objetivo

Practicar la generación de manifiestos YAML para otros tipos de recursos (ConfigMap) usando el patrón `--dry-run=client -o yaml`, reforzando el flujo de trabajo declarativo.

### Instrucciones

1. Genera un ConfigMap con datos literales:

```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=development \
  --from-literal=APP_PORT=8080 \
  --from-literal=APP_NAME=nginx-lab \
  --dry-run=client -o yaml > cm-app-config.yaml
```

2. Examina el manifiesto generado:

```bash
cat cm-app-config.yaml
```

3. Aplica el ConfigMap al clúster:

```bash
kubectl apply -f cm-app-config.yaml
```

4. Verifica que el ConfigMap se creó:

```bash
kubectl get configmaps
```

5. Describe el ConfigMap para ver su contenido:

```bash
kubectl describe configmap app-config
```

### Salida Esperada

```yaml
apiVersion: v1
data:
  APP_ENV: development
  APP_NAME: nginx-lab
  APP_PORT: "8080"
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: app-config
```

```
configmap/app-config created
```

```
NAME               DATA   AGE
app-config         3      5s
kube-root-ca.crt   1      10m
```

### Verificación

```bash
kubectl get configmap app-config -o jsonpath='{.data.APP_ENV}'
echo ""
```

Debe imprimir: `development`

---

## Paso 11: Eliminar y Recrear Recursos

### Objetivo

Practicar la eliminación de recursos usando tanto `kubectl delete` imperativo como declarativo con `-f`, y demostrar la idempotencia de `kubectl apply`.

### Instrucciones

1. Elimina el Pod `nginx-backend` usando el comando imperativo:

```bash
kubectl delete pod nginx-backend
```

2. Verifica que fue eliminado:

```bash
kubectl get pods
```

3. Demuestra la idempotencia de `kubectl apply` (aplicar el mismo manifiesto de nuevo):

```bash
kubectl apply -f pod-nginx-lab.yaml
```

4. Observa que el recurso no se modifica si no hay cambios (nota: las etiquetas fueron modificadas en el Paso 7, por lo que puede haber un cambio):

```bash
kubectl get pod nginx-lab --show-labels
```

5. Elimina el Pod usando el archivo de manifiesto:

```bash
kubectl delete -f pod-nginx-lab.yaml
```

6. Verifica la eliminación:

```bash
kubectl get pods
```

7. Recrea el Pod para dejarlo disponible para los siguientes laboratorios. Primero, actualiza el manifiesto para reflejar las etiquetas originales correctas:

```bash
cat > pod-nginx-lab.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: web
    env: dev
    tier: frontend
  name: nginx-lab
spec:
  containers:
  - image: nginx:1.27.0
    name: nginx-lab
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
EOF
```

8. Aplica el manifiesto final:

```bash
kubectl apply -f pod-nginx-lab.yaml
```

9. Espera a que esté Running:

```bash
kubectl wait --for=condition=Ready pod/nginx-lab --timeout=60s
```

### Salida Esperada

```
pod "nginx-backend" deleted
```

```
pod/nginx-lab unchanged
```

(o `configured` si hubo diferencias)

```
pod "nginx-lab" deleted
```

```
pod/nginx-lab created
```

```
pod/nginx-lab condition met
```

### Verificación

```bash
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,LABELS:.metadata.labels
```

Debe mostrar `nginx-lab` en fase `Running` con las etiquetas originales.

---

## Paso 12: Verificación Final del Estado del Entorno

### Objetivo

Confirmar que el entorno queda en el estado esperado para los laboratorios del módulo 2: namespace `ckad-dev` como default, Pod `nginx-lab` corriendo y ConfigMap disponible.

### Instrucciones

1. Verifica el contexto de kubectl:

```bash
kubectl config view --minify | grep namespace
```

2. Lista todos los recursos en el namespace `ckad-dev`:

```bash
kubectl get all -n ckad-dev
```

3. Lista los ConfigMaps:

```bash
kubectl get configmaps -n ckad-dev
```

4. Verifica los archivos generados en el directorio de trabajo:

```bash
ls -la ~/ckad-labs/lab01/*.yaml
```

5. Confirma los namespaces del curso:

```bash
kubectl get ns ckad-dev ckad-staging ckad-prod
```

### Salida Esperada

```
    namespace: ckad-dev
```

```
NAME            READY   STATUS    RESTARTS   AGE
pod/nginx-lab   1/1     Running   0          30s
```

```
NAME               DATA   AGE
app-config         3      5m
kube-root-ca.crt   1      15m
```

```
-rw-r--r-- ... cm-app-config.yaml
-rw-r--r-- ... ns-ckad-dev.yaml
-rw-r--r-- ... ns-ckad-prod.yaml
-rw-r--r-- ... ns-ckad-staging.yaml
-rw-r--r-- ... pod-nginx-lab.yaml
```

```
NAME           STATUS   AGE
ckad-dev       Active   15m
ckad-staging   Active   15m
ckad-prod      Active   15m
```

### Verificación

```bash
# Script de verificación completo
echo "=== Verificación Final del Lab 01-00-02 ==="
echo ""
echo "1. Contexto kubectl:"
kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}'
echo ""
echo ""
echo "2. Pod nginx-lab:"
kubectl get pod nginx-lab -o jsonpath='STATUS={.status.phase} IMAGE={.spec.containers[0].image}'
echo ""
echo ""
echo "3. Etiquetas del Pod:"
kubectl get pod nginx-lab -o jsonpath='{.metadata.labels}' | jq .
echo ""
echo "4. ConfigMap app-config:"
kubectl get cm app-config -o jsonpath='{.data}' | jq .
echo ""
echo "5. Namespaces del curso:"
kubectl get ns ckad-dev ckad-staging ckad-prod --no-headers
echo ""
echo "=== Verificación completada ==="
```

**Resultado esperado completo:**

```
=== Verificación Final del Lab 01-00-02 ===

1. Contexto kubectl:
ckad-dev

2. Pod nginx-lab:
STATUS=Running IMAGE=nginx:1.27.0

3. Etiquetas del Pod:
{
  "app": "web",
  "env": "dev",
  "tier": "frontend"
}

4. ConfigMap app-config:
{
  "APP_ENV": "development",
  "APP_NAME": "nginx-lab",
  "APP_PORT": "8080"
}

5. Namespaces del curso:
ckad-dev       Active   ...
ckad-prod      Active   ...
ckad-staging   Active   ...

=== Verificación completada ===
```

---

## Validación y Testing

Ejecuta las siguientes comprobaciones para confirmar que el laboratorio se completó correctamente:

```bash
# Test 1: Namespace por defecto configurado
test "$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}')" = "ckad-dev" && echo "PASS: Namespace default es ckad-dev" || echo "FAIL: Namespace default incorrecto"

# Test 2: Pod nginx-lab en estado Running
test "$(kubectl get pod nginx-lab -o jsonpath='{.status.phase}')" = "Running" && echo "PASS: Pod nginx-lab está Running" || echo "FAIL: Pod nginx-lab no está Running"

# Test 3: Imagen correcta
test "$(kubectl get pod nginx-lab -o jsonpath='{.spec.containers[0].image}')" = "nginx:1.27.0" && echo "PASS: Imagen es nginx:1.27.0" || echo "FAIL: Imagen incorrecta"

# Test 4: Etiquetas correctas
LABELS=$(kubectl get pod nginx-lab -o jsonpath='{.metadata.labels.app}-{.metadata.labels.env}-{.metadata.labels.tier}')
test "$LABELS" = "web-dev-frontend" && echo "PASS: Etiquetas correctas" || echo "FAIL: Etiquetas incorrectas ($LABELS)"

# Test 5: ConfigMap existe con datos correctos
test "$(kubectl get cm app-config -o jsonpath='{.data.APP_ENV}')" = "development" && echo "PASS: ConfigMap app-config correcto" || echo "FAIL: ConfigMap app-config incorrecto"

# Test 6: Los tres namespaces existen
NS_COUNT=$(kubectl get ns ckad-dev ckad-staging ckad-prod --no-headers 2>/dev/null | wc -l)
test "$NS_COUNT" = "3" && echo "PASS: Tres namespaces del curso existen" || echo "FAIL: Faltan namespaces ($NS_COUNT/3)"

# Test 7: Archivos YAML generados existen
YAML_COUNT=$(ls ~/ckad-labs/lab01/*.yaml 2>/dev/null | wc -l)
test "$YAML_COUNT" -ge "5" && echo "PASS: Archivos YAML generados ($YAML_COUNT)" || echo "FAIL: Faltan archivos YAML ($YAML_COUNT/5)"
```

Todos los tests deben mostrar `PASS`.

---

## Troubleshooting

### Problema 1: El Pod queda en estado ImagePullBackOff

**Síntomas:**

```
NAME        READY   STATUS             RESTARTS   AGE
nginx-lab   0/1     ImagePullBackOff   0          30s
```

**Causa:** La imagen `nginx:1.27.0` no se puede descargar. Esto suele ocurrir por falta de conectividad a Internet desde el nodo de minikube, o por un error tipográfico en el nombre/tag de la imagen.

**Solución:**

```bash
# 1. Verificar el evento de error exacto
kubectl describe pod nginx-lab | grep -A 5 "Events:"

# 2. Verificar conectividad desde minikube
minikube ssh -- curl -sI https://registry-1.docker.io/v2/ | head -3

# 3. Si hay un error en la imagen, corregir el manifiesto
vim ~/ckad-labs/lab01/pod-nginx-lab.yaml
# Asegurar que dice exactamente: image: nginx:1.27.0

# 4. Eliminar y recrear el Pod
kubectl delete pod nginx-lab
kubectl apply -f ~/ckad-labs/lab01/pod-nginx-lab.yaml
```

### Problema 2: El contexto de kubectl no retiene el namespace configurado

**Síntomas:**

```bash
kubectl config view --minify | grep namespace
# No muestra "ckad-dev" o muestra un namespace diferente
```

Al ejecutar `kubectl get pods` se muestran los Pods del namespace `default` en lugar de `ckad-dev`.

**Causa:** El comando `set-context` se ejecutó con un nombre de contexto incorrecto, o hay múltiples contextos configurados y se modificó uno que no es el activo.

**Solución:**

```bash
# 1. Identificar el contexto activo (marcado con *)
kubectl config get-contexts

# 2. Verificar el nombre exacto del contexto activo
CURRENT_CTX=$(kubectl config current-context)
echo "Contexto activo: $CURRENT_CTX"

# 3. Aplicar el namespace al contexto correcto
kubectl config set-context "$CURRENT_CTX" --namespace=ckad-dev

# 4. Verificar
kubectl config view --minify | grep namespace
# Debe mostrar: namespace: ckad-dev

# 5. Confirmar que los Pods se listan del namespace correcto
kubectl get pods
```

---

## Cleanup

> **IMPORTANTE:** NO ejecutes la limpieza de este laboratorio. Los recursos creados (namespaces `ckad-dev`, `ckad-staging`, `ckad-prod`, el Pod `nginx-lab` y el ConfigMap `app-config`) son necesarios para los laboratorios del módulo 2.

Si necesitas reiniciar este laboratorio desde cero por algún motivo, usa los siguientes comandos:

```bash
# SOLO ejecutar si necesitas repetir el laboratorio completo
kubectl delete pod nginx-lab -n ckad-dev --ignore-not-found
kubectl delete configmap app-config -n ckad-dev --ignore-not-found
kubectl delete ns ckad-dev ckad-staging ckad-prod --ignore-not-found
kubectl config set-context --current --namespace=default
rm -f ~/ckad-labs/lab01/ns-*.yaml ~/ckad-labs/lab01/pod-*.yaml ~/ckad-labs/lab01/cm-*.yaml
```

---

## Resumen

En este laboratorio has practicado las habilidades fundamentales de kubectl que utilizarás a lo largo de todo el curso y en el examen CKAD:

| Habilidad | Comando Clave |
|-----------|---------------|
| Generar manifiestos sin crear recursos | `kubectl create ... --dry-run=client -o yaml` |
| Aplicar manifiestos declarativamente | `kubectl apply -f <archivo.yaml>` |
| Gestionar namespaces y contextos | `kubectl config set-context --current --namespace=` |
| Añadir/modificar etiquetas | `kubectl label pod <nombre> key=value [--overwrite]` |
| Filtrar con selectores | `kubectl get pods -l key=value` |
| Añadir/eliminar anotaciones | `kubectl annotate pod <nombre> key=value` / `key-` |
| Explorar la API | `kubectl explain pod.spec.containers` |
| Inspeccionar recursos | `kubectl describe`, `kubectl logs`, `-o json/jsonpath` |

### Puntos Clave

- El patrón `--dry-run=client -o yaml > archivo.yaml` es la forma más rápida de generar manifiestos base durante el examen CKAD.
- Configurar el namespace por defecto del contexto evita errores y ahorra tiempo en cada comando.
- Las etiquetas son el mecanismo principal de selección y agrupación en Kubernetes; los selectores `-l` son fundamentales para filtrar recursos.
- Las anotaciones almacenan metadatos no estructurados que no afectan la lógica del sistema.
- `kubectl explain` es tu documentación inline durante el examen — úsalo en lugar de buscar en el navegador para campos específicos.

### Recursos Adicionales

- [Documentación oficial de kubectl — kubernetes.io](https://kubernetes.io/docs/reference/kubectl/)
- [Kubectl Cheat Sheet — kubernetes.io](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Namespaces — kubernetes.io](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Labels and Selectors — kubernetes.io](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [Annotations — kubernetes.io](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/)
