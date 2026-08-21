---
layout: lab
title: "Práctica 1: Preparación del entorno CKAD"
permalink: /lab1/lab1/
images_base: /labs/lab1/img
duration: "45 minutos"
objective:
  - Preparar y validar una estación de trabajo Windows para las prácticas CKAD, configurando WSL2, Docker Desktop, kubectl y kind, obteniendo el repositorio del curso y desplegando un clúster Kubernetes multinodo funcional con un nodo Control Plane y dos Worker Nodes.
prerequisites:
  - Equipo con Windows 11 de 64 bits y al menos 8 GB de memoria RAM.
  - Virtualización por hardware habilitada en BIOS o UEFI.
  - Visual Studio Code y Git Bash instalados.
  - Docker Desktop instalado con acceso al backend WSL2.
  - Conexión a Internet y acceso al repositorio Git proporcionado por el instructor.
introduction:
  - En esta práctica prepararás la estación de trabajo que utilizarás durante el resto del curso CKAD. Desde Windows y Git Bash validarás WSL2 y Docker Desktop, obtendrás el repositorio de laboratorios, comprobarás las herramientas kubectl y kind y desplegarás un clúster Kubernetes local multinodo reproducible. Finalmente ejecutarás una carga de trabajo temporal para confirmar que el entorno puede crear, programar y eliminar recursos correctamente antes de continuar con las siguientes prácticas.
slug: lab1
lab_number: 1
final_result: >
  Al finalizar dispondrás de una estación Windows preparada para las prácticas CKAD, con Docker Desktop utilizando WSL2, kubectl y kind disponibles desde Git Bash, una copia local del repositorio del curso y un clúster Kubernetes denominado ckad formado por un nodo Control Plane y dos Worker Nodes en estado Ready. También habrás validado el funcionamiento del clúster mediante el despliegue y eliminación controlada de una carga de trabajo de prueba.
notes:
  - Los comandos de esta práctica están diseñados para ejecutarse desde Git Bash en Windows, excepto las comprobaciones que invocan explícitamente componentes nativos de Windows mediante PowerShell o WSL.
  - Para mantener un entorno homogéneo entre participantes, el clúster de esta práctica utiliza kind v0.32.0 y la imagen kindest/node:v1.36.1.
  - Docker Desktop debe trabajar con contenedores Linux y utilizar WSL2 como backend; no se utilizará el clúster Kubernetes integrado de Docker Desktop.
  - No elimines el clúster ckad al finalizar la práctica, ya que será reutilizado en las prácticas posteriores.
references:
  - text: Instalación de WSL en Windows
    url: https://learn.microsoft.com/es-es/windows/wsl/install
  - text: Docker Desktop con backend WSL2
    url: https://docs.docker.com/desktop/features/wsl/
  - text: Instalación de kubectl en Windows
    url: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
  - text: Guía oficial de inicio rápido de kind
    url: https://kind.sigs.k8s.io/docs/user/quick-start/
prev: /
next: /lab2/lab2/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 🔎 Tarea 1. Validar la estación de trabajo Windows — 10 min

Antes de desplegar Kubernetes comprobarás que Windows dispone de las capacidades necesarias para ejecutar contenedores Linux mediante WSL2. También validarás Docker Desktop y confirmarás que el motor seleccionado es apropiado para crear nodos Kubernetes con kind.

### Tarea 1.1. Comprobar Windows y virtualización

Validarás la versión del sistema operativo y el soporte de virtualización antes de utilizar WSL2. Estas comprobaciones permiten detectar anticipadamente configuraciones incompatibles con Docker Desktop o con los contenedores Linux utilizados por kind.

- {% include step_label.html %} Abre **GitBash** y consulta la edición, versión y compilación de Windows instalada para confirmar que estás trabajando sobre una estación Windows 11 compatible con el entorno del curso.

  > **Nota:** El comando utiliza PowerShell desde Git Bash únicamente para obtener información del sistema operativo. No necesitas cambiar de terminal para ejecutar esta comprobación.
  {: .lab-note .info .compact}

  ```bash
  powershell.exe -NoProfile -Command "Get-ComputerInfo | Select-Object WindowsProductName,WindowsVersion,OsBuildNumber"
  ```

  > **Salida esperada:** Se muestran los campos `WindowsProductName`, `WindowsVersion` y `OsBuildNumber`. El producto debe identificar una edición compatible de Windows 11.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inicia la distribución Ubuntu configurada con WSL2 y consulta el kernel Linux para comprobar funcionalmente que Windows puede ejecutar correctamente el entorno utilizado posteriormente por Docker Desktop.

  > **Importante:** Esta validación sustituye la comprobación de `VirtualizationFirmwareEnabled`, ya que en máquinas virtuales ese valor puede aparecer como `False` aunque WSL2 funcione correctamente. Lo importante para esta práctica es confirmar que una distribución configurada con WSL2 puede iniciarse y ejecutar comandos Linux sin errores.
  {: .lab-note .important .compact}

  ```bash
  wsl.exe -d Ubuntu -- uname -r
  ```

  > **Salida esperada:** Se muestra la versión del kernel utilizado por WSL2, normalmente con una referencia similar a `microsoft-standard-WSL2`. El comando debe finalizar sin errores relacionados con virtualización, Hyper-V o Virtual Machine Platform.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba la versión instalada de Windows Subsystem for Linux para verificar que WSL está disponible y conocer la versión que utilizará Docker Desktop como backend.

  > **Advertencia:** Docker Desktop requiere WSL2 actualizado. Si el comando indica que `wsl` no existe o solicita instalar el componente, corrige WSL antes de continuar con Docker Desktop.
  {: .lab-note .warning .compact}

  ```bash
  wsl.exe --version
  ```

  > **Salida esperada:** Se muestran las versiones de WSL, kernel Linux, WSLg y otros componentes. La versión de WSL debe ser 2.1.5 o superior.
  {: .lab-note .output .compact}

### Tarea 1.2. Validar WSL2 y Docker Desktop

Confirmarás que existe una distribución trabajando sobre WSL2, actualizarás el subsistema cuando corresponda y revisarás la configuración de Docker Desktop que servirá como runtime para los nodos Kubernetes.

- {% include step_label.html %} Lista las distribuciones Linux registradas en Windows e identifica la versión de WSL utilizada por cada una para confirmar que al menos una distribución trabaja con WSL2.

  > **Nota:** La columna `VERSION` es diferente de la versión de la distribución Linux. En esta práctica debe mostrar `2` para la distribución que utilices.
  {: .lab-note .info .compact}

  ```bash
  wsl.exe --list --verbose
  ```

  > **Salida esperada:** Aparece al menos una distribución Linux y su columna `VERSION` contiene el valor `2`. Es habitual encontrar una distribución como `Ubuntu`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Solicita a Windows buscar e instalar la actualización más reciente disponible de WSL antes de iniciar la infraestructura Kubernetes del curso.

  > **Importante:** Mantener WSL actualizado reduce incompatibilidades con versiones recientes de Docker Desktop. Si Windows solicita privilegios administrativos, autoriza la operación con una cuenta permitida para el laboratorio.
  {: .lab-note .important .compact}

  ```bash
  wsl.exe --update
  ```

  > **Salida esperada:** WSL informa que busca actualizaciones y confirma la instalación de una actualización o indica que ya se encuentra en la versión más reciente disponible.
  {: .lab-note .output .compact}

- {% include step_label.html %} Abre Docker Desktop y verifica que utilice WSL2 y contenedores Linux; después confirma desde Git Bash que el Docker Engine está disponible.

  > **Importante:** En Docker Desktop abre **Settings → General** y confirma **Use WSL 2 based engine**. No crees un clúster desde la vista **Kubernetes** de Docker Desktop, porque durante el curso administraremos el clúster mediante la CLI de `kind`. Si Docker Desktop ofrece cambiar entre Windows y Linux containers, selecciona **Linux containers**.
  {: .lab-note .important .compact}

  {%raw%}
  ```bash
  docker info --format 'Server={{.ServerVersion}} | OS={{.OperatingSystem}} | Type={{.OSType}}'
  ```
  {%endraw%}

  > **Salida esperada:** Docker responde con la versión del servidor, un sistema operativo asociado a Docker Desktop y `Type=linux`, confirmando que el runtime está disponible para kind.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 📦 Tarea 2. Preparar el repositorio de laboratorios — 6 min

Obtendrás únicamente el contenido necesario para las prácticas desde el repositorio Git mediante `sparse-checkout` y establecerás `ckad-labs` como espacio de trabajo. También validarás elementos destinados a mantener un comportamiento consistente entre Windows y Linux.

### Tarea 2.1. Obtener únicamente los laboratorios del repositorio

Comprobarás Git y utilizarás `sparse-checkout` para obtener únicamente el directorio `ckad-labs` y el archivo `.gitattributes` desde el repositorio del curso. Así evitarás incorporar al espacio de trabajo contenido que no forma parte de las prácticas.

- {% include step_label.html %} Verifica que Git esté disponible desde Git Bash y registra su versión antes de preparar la descarga selectiva del repositorio.

  > **Nota:** Git Bash incluye normalmente acceso directo a Git. La funcionalidad `sparse-checkout` utilizada en esta práctica está disponible en versiones modernas de Git para Windows.
  {: .lab-note .info .compact}

  ```bash
  git --version
  ```

  > **Salida esperada:** Se muestra una respuesta con formato similar a `git version 2.x.x.windows.x` sin errores de comando no encontrado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Clona la estructura Git del repositorio sin realizar el checkout completo y configura una vista de trabajo selectiva que incluya únicamente `ckad-labs` y `.gitattributes`.

  > **Importante:** Sustituye `<URL_DEL_REPOSITORIO>` por la URL exacta proporcionada por el instructor. `--filter=blob:none` evita descargar inicialmente blobs innecesarios y `--no-checkout` permite definir primero qué rutas estarán visibles.
  {: .lab-note .important .compact}

  ```bash
  cd Desktop
  git clone --filter=blob:none --no-checkout <URL_DEL_REPOSITORIO> ckad-course && cd ckad-course && git sparse-checkout init --cone && git sparse-checkout set ckad-labs .gitattributes && git checkout
  ```

  > **Salida esperada:** Git crea `ckad-course`, configura `sparse-checkout` y realiza el checkout mostrando `ckad-labs`, `.gitattributes` y los metadatos internos administrados por Git, sin incorporar los demás directorios del repositorio al espacio de trabajo.
  {: .lab-note .output .compact}

- {% include step_label.html %} Accede al directorio `ckad-labs`, confirma la ruta actual y comprueba visualmente que el checkout selectivo mantiene fuera del espacio de trabajo los demás directorios del repositorio.

  > **Advertencia:** No ejecutes `git sparse-checkout disable`, ya que restauraría el checkout completo del repositorio. A partir de este punto trabaja dentro de `ckad-course/ckad-labs`.
  {: .lab-note .warning .compact}

  ```bash
  cd ckad-labs && pwd && printf '\nContenido visible en la raíz del checkout:\n' && ls -la ..
  ```

  > **Salida esperada:** La ruta termina en `/ckad-course/ckad-labs` y en la raíz visible del checkout aparecen principalmente `.git`, `.gitattributes` y `ckad-labs`, sin los demás directorios internos del repositorio.
  {: .lab-note .output .compact}

### Tarea 2.2. Validar la estructura del laboratorio

Revisarás los recursos entregados por el repositorio y confirmarás que el directorio `setup` contiene los archivos requeridos para crear un entorno reproducible durante esta y las siguientes prácticas.

- {% include step_label.html %} Lista el contenido principal de `ckad-labs` para familiarizarte con la organización utilizada por las prácticas del curso.

  > **Nota:** El repositorio puede incorporar archivos auxiliares adicionales con el tiempo. Lo importante es conservar `setup` y los directorios de las prácticas sin modificar su ubicación.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** Se observan el directorio `setup`, el archivo `README.md` y los directorios de laboratorios disponibles en la versión actual del curso.
  {: .lab-note .output .compact}

- {% include step_label.html %} Examina el contenido del directorio `setup` y confirma que se encuentran disponibles los archivos utilizados para administrar el clúster local.

  > **Importante:** Como mínimo deben estar disponibles `kind-config.yaml` y los scripts de administración definidos para el curso. No edites estos archivos durante esta comprobación.
  {: .lab-note .important .compact}

  ```bash
  ls -la setup/
  ```

  > **Salida esperada:** Se muestra `kind-config.yaml` junto con los scripts disponibles, como `create-cluster.sh`, `delete-cluster.sh`, `reset-cluster.sh` y `verify-environment.sh`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Verifica la política de finales de línea definida en el repositorio para evitar que Windows convierta scripts Bash de formato LF a CRLF.

  > **Advertencia:** Los scripts `.sh` ejecutados en entornos Linux pueden fallar con errores relacionados con `/bin/bash^M` cuando contienen finales de línea CRLF. El repositorio debe conservar estos archivos con formato LF.
  {: .lab-note .warning .compact}

  ```bash
  grep -E '^\*\.sh.*eol=lf' ../.gitattributes 2>/dev/null || true
  ```

  > **Salida esperada:** Se muestra una regla equivalente a `*.sh text eol=lf`. Si no aparece, informa al instructor antes de modificar los scripts del repositorio.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🛠️ Tarea 3. Instalar y validar las herramientas Kubernetes — 8 min

Prepararás las herramientas de línea de comandos que utilizarás durante todo el curso. Instalarás o actualizarás `kubectl` y `kind`, comprobarás las versiones disponibles desde Git Bash y verificarás que kind pueda utilizar correctamente el Docker Engine.

### Tarea 3.1. Preparar kubectl

Instalarás o actualizarás `kubectl`, identificarás el ejecutable utilizado por Git Bash y revisarás el estado inicial de sus contextos antes de que kind genere la configuración del nuevo clúster.

- {% include step_label.html %} Utiliza Windows Package Manager para instalar `kubectl` o actualizar el paquete existente a una versión compatible con Kubernetes 1.36.

  > **Nota:** Si `kubectl` ya está instalado y actualizado, `winget` puede indicar que no existe una actualización disponible. Ese resultado también es válido.
  {: .lab-note .info .compact}

  ```bash
  winget install -e --id Kubernetes.kubectl --accept-package-agreements --accept-source-agreements
  ```

  > **Salida esperada:** `winget` instala `Kubernetes.kubectl`, confirma que ya está instalado o informa que no existe una actualización posterior disponible.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba qué ejecutable `kubectl` encuentra Git Bash y consulta la versión del cliente para detectar instalaciones duplicadas o versiones incompatibles.

  > **Importante:** Para este laboratorio se recomienda `kubectl` 1.36.x. El cliente Kubernetes admite una diferencia de una versión menor respecto al API Server, pero mantener ambas versiones cercanas simplifica la experiencia del curso.
  {: .lab-note .important .compact}

  ```bash
  command -v kubectl && kubectl version --client
  ```

  > **Salida esperada:** Primero se muestra la ruta del ejecutable `kubectl` y después una versión de cliente compatible, preferentemente `v1.36.x`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los contextos Kubernetes registrados antes de crear el nuevo clúster para conocer el estado inicial del archivo `kubeconfig`.

  > **Advertencia:** Es posible que aparezcan contextos pertenecientes a otros clústeres. No los elimines. kind agregará un contexto independiente denominado `kind-ckad`.
  {: .lab-note .warning .compact}

  ```bash
  kubectl config get-contexts
  ```

  > **Salida esperada:** Se muestra una tabla de contextos existentes o una lista vacía si nunca se ha configurado un clúster Kubernetes en la estación.
  {: .lab-note .output .compact}

### Tarea 3.2. Preparar kind y su runtime

Instalarás la versión actual de kind, comprobarás el binario utilizado por la terminal y confirmarás que Docker está exponiendo el runtime Linux requerido para crear nodos Kubernetes como contenedores.

- {% include step_label.html %} Instala `kind` utilizando Windows Package Manager para disponer de la herramienta encargada de construir el clúster local de las prácticas.

  > **Nota:** La versión de referencia de esta práctica es `kind v0.32.0`. Si el paquete ya está instalado, `winget` conservará o actualizará la instalación según corresponda.
  {: .lab-note .info .compact}

  ```bash
  winget install Kubernetes.kind --accept-package-agreements --accept-source-agreements
  ```

  > **Salida esperada:** `winget` instala Kubernetes kind o informa que la versión correspondiente ya se encuentra instalada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Identifica la ubicación del ejecutable `kind` utilizado por Git Bash y verifica su versión antes de crear recursos de Kubernetes.

  > **Importante:** Si acabas de instalar kind y Git Bash responde `command not found`, cierra y vuelve a abrir la terminal integrada de VS Code para que Windows actualice las rutas disponibles en la sesión.
  {: .lab-note .important .compact}

  ```bash
  command -v kind && kind version
  ```

  > **Salida esperada:** Se muestra la ruta del ejecutable y una versión equivalente a `kind v0.32.0`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que el Docker Engine trabaja con contenedores Linux y realiza una consulta directa para garantizar que kind podrá comunicarse con el runtime.

  > **Advertencia:** `OSType` debe ser `linux`. kind para Windows no puede crear este entorno utilizando Windows containers.
  {: .lab-note .warning .compact}

  {%raw%}
  ```bash
  docker info --format 'Docker={{.ServerVersion}} | OSType={{.OSType}} | Architecture={{.Architecture}}'
  ```
  {%endraw%}

  > **Salida esperada:** Docker devuelve información del servidor y muestra `OSType=linux` junto con la arquitectura disponible, normalmente `x86_64` o `aarch64`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🚀 Tarea 4. Crear el clúster Kubernetes multinodo — 12 min

Construirás el clúster local que servirá como plataforma común para las prácticas CKAD. Antes del despliegue revisarás su topología, descargarás de forma explícita la imagen de Kubernetes y crearás un entorno reproducible denominado `ckad`.

### Tarea 4.1. Revisar la configuración del clúster

Examinarás el manifiesto de configuración preparado en el repositorio y confirmarás que define exactamente un nodo Control Plane y dos Worker Nodes antes de iniciar la creación del clúster.

- {% include step_label.html %} Muestra el archivo `setup/kind-config.yaml` para revisar la configuración que utilizará kind durante la creación del entorno Kubernetes.

  > **Nota:** kind utiliza el API `kind.x-k8s.io/v1alpha4` para describir la topología del clúster. Este archivo pertenece a la infraestructura del laboratorio y será reutilizado posteriormente.
  {: .lab-note .info .compact}

  ```bash
  cat setup/kind-config.yaml
  ```

  > **Salida esperada:** El manifiesto muestra `kind: Cluster`, `apiVersion: kind.x-k8s.io/v1alpha4` y una sección `nodes` con las funciones de los nodos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Cuenta las funciones declaradas en el archivo para comprobar que la topología contiene exactamente un Control Plane y dos Worker Nodes.

  > **Importante:** Esta topología será la referencia común del curso. No agregues ni elimines nodos aunque tu equipo disponga de recursos adicionales.
  {: .lab-note .important .compact}

  {%raw%}
  ```bash
  printf 'Control Plane: '; grep -c 'role: control-plane' setup/kind-config.yaml; printf 'Workers: '; grep -c 'role: worker' setup/kind-config.yaml
  ```
  {%endraw%}

  > **Salida esperada:** El resultado indica `Control Plane: 1` y `Workers: 2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Descarga anticipadamente la imagen de nodo Kubernetes utilizada por el curso para separar posibles problemas de conectividad del proceso posterior de creación del clúster.

  > **Advertencia:** La imagen ocupa espacio en Docker y puede tardar en descargarse la primera vez. No cierres Docker Desktop ni interrumpas la operación mientras la descarga se encuentre en progreso.
  {: .lab-note .warning .compact}

  ```bash
  docker pull kindest/node:v1.36.1
  ```

  > **Salida esperada:** Docker descarga las capas necesarias o indica `Image is up to date` y finaliza mostrando `kindest/node:v1.36.1`.
  {: .lab-note .output .compact}

### Tarea 4.2. Desplegar y registrar el clúster ckad

Crearás el clúster usando la configuración del repositorio, verificarás los contenedores que representan sus nodos y confirmarás que kind haya agregado automáticamente el contexto correspondiente a `kubeconfig`.

- {% include step_label.html %} Crea el clúster denominado `ckad` fijando explícitamente Kubernetes 1.36.1 y utilizando la topología definida en `setup/kind-config.yaml`.

  > **Importante:** Utiliza exactamente el nombre `ckad`. kind generará a partir de él el contexto `kind-ckad`, utilizado por los comandos y scripts de prácticas posteriores.
  {: .lab-note .important .compact}

  ```bash
  kind create cluster --name ckad --image kindest/node:v1.36.1 --config setup/kind-config.yaml --wait 120s
  ```

  > **Salida esperada:** kind prepara los nodos, escribe la configuración de acceso y finaliza indicando que el clúster fue creado correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los clústeres registrados por kind y los contenedores Docker asociados para comprobar físicamente la existencia de los tres nodos.

  > **Nota:** Los nodos kind son contenedores Docker. Por eso pueden observarse directamente mediante `docker ps` aunque Kubernetes los gestione posteriormente como nodos del clúster.
  {: .lab-note .info .compact}

  {%raw%}
  ```bash
  kind get clusters && docker ps --filter "name=ckad-" --format 'table {{.Names}}\t{{.Status}}'
  ```
  {%endraw%}

  > **Salida esperada:** `kind get clusters` muestra `ckad` y Docker lista tres contenedores con nombres equivalentes a `ckad-control-plane`, `ckad-worker` y `ckad-worker2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo de kubectl para confirmar que la creación del clúster actualizó correctamente la configuración local de Kubernetes.

  > **Advertencia:** El contexto debe ser `kind-ckad`. Si aparece otro contexto, evita ejecutar recursos hasta seleccionar explícitamente el contexto correcto.
  {: .lab-note .warning .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## ✅ Tarea 5. Validar el entorno CKAD — 9 min

Realizarás las comprobaciones finales del plano de control, nodos y componentes del sistema. Después desplegarás una carga de trabajo temporal para demostrar que el clúster puede programar Pods correctamente y dejarás nuevamente el entorno limpio.

### Tarea 5.1. Comprobar el estado de Kubernetes

Validarás la comunicación con el API Server, revisarás que los tres nodos estén disponibles y comprobarás los componentes fundamentales desplegados en el namespace `kube-system`.

- {% include step_label.html %} Consulta la información de conexión del clúster para verificar que `kubectl` puede comunicarse correctamente con el Kubernetes API Server.

  > **Nota:** Las direcciones y puertos locales pueden variar entre equipos porque kind publica dinámicamente el acceso al API Server.
  {: .lab-note .info .compact}

  ```bash
  kubectl cluster-info
  ```

  > **Salida esperada:** Se muestran las direcciones del Kubernetes control plane y de CoreDNS sin errores de conexión o autenticación.
  {: .lab-note .output .compact}

- {% include step_label.html %} Lista los nodos con información ampliada y confirma que el Control Plane y ambos Workers hayan alcanzado el estado operativo esperado.

  > **Importante:** Los tres nodos deben aparecer en estado `Ready` antes de ejecutar cargas de trabajo. Si alguno permanece `NotReady`, espera unos segundos y repite la consulta.
  {: .lab-note .important .compact}

  ```bash
  kubectl get nodes -o wide
  ```

  > **Salida esperada:** Se muestran `ckad-control-plane`, `ckad-worker` y `ckad-worker2`; los tres presentan `STATUS` igual a `Ready` y una versión Kubernetes `v1.36.1`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa los Pods del namespace `kube-system` para comprobar que los componentes esenciales de red, DNS y Control Plane se encuentran disponibles.

  > **Advertencia:** No elimines ni modifiques recursos del namespace `kube-system`. Estos componentes mantienen operativo el clúster y serán administrados automáticamente por Kubernetes y kind.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get pods -n kube-system -o wide
  ```

  > **Salida esperada:** Los Pods esenciales muestran estados operativos, principalmente `Running`; entre ellos pueden encontrarse CoreDNS, kube-proxy, etcd, kube-apiserver, kube-controller-manager y kube-scheduler.
  {: .lab-note .output .compact}

### Tarea 5.2. Ejecutar una prueba funcional y limpiar recursos

Crearás un namespace temporal y desplegarás una carga sencilla para comprobar la programación real de Pods sobre los Worker Nodes. Finalmente eliminarás los recursos de prueba sin destruir el clúster que utilizarás posteriormente.

- {% include step_label.html %} Crea un namespace temporal denominado `ckad-validation` para aislar los recursos empleados exclusivamente durante la comprobación funcional.

  > **Nota:** Utilizar un namespace dedicado simplifica la limpieza y evita mezclar la validación inicial con recursos que serán creados posteriormente durante otras prácticas.
  {: .lab-note .info .compact}

  ```bash
  kubectl create namespace ckad-validation
  ```

  > **Salida esperada:** Kubernetes responde `namespace/ckad-validation created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Despliega una carga temporal basada en BusyBox, espera a que el Pod alcance el estado disponible y consulta el nodo donde Kubernetes lo programó.

  > **Importante:** El propósito de esta carga no es estudiar Deployments todavía, sino comprobar de extremo a extremo que el API Server acepta recursos, el scheduler selecciona un nodo y el runtime inicia el contenedor.
  {: .lab-note .important .compact}

  ```bash
  kubectl create deployment validation --image=busybox:1.37 -n ckad-validation -- sleep 3600 && kubectl wait --for=condition=Available deployment/validation -n ckad-validation --timeout=90s && kubectl get pods -n ckad-validation -o wide
  ```

  > **Salida esperada:** Se crea el Deployment `validation`, `kubectl wait` informa que está disponible y el Pod aparece `Running` con un valor en la columna `NODE`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace temporal y comprueba que desapareció, manteniendo intacto el clúster `ckad` para utilizarlo en las siguientes prácticas.

  > **Advertencia:** Elimina únicamente `ckad-validation`. No ejecutes `kind delete cluster`, ya que destruiría la infraestructura que acabas de preparar y que será reutilizada posteriormente.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace ckad-validation --wait=true && kubectl get namespace ckad-validation --ignore-not-found
  ```

  > **Salida esperada:** Kubernetes informa `namespace "ckad-validation" deleted` y la segunda consulta no devuelve recursos, confirmando que la carga temporal fue eliminada.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}