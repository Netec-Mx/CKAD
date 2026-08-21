---
layout: lab
title: "Práctica 3: Construcción y ejecución de una aplicación en Pod"
permalink: /lab3/lab3/
images_base: /labs/lab3/img
duration: "45 minutos"
objective:
  - Construir una imagen de contenedor para una aplicación web sencilla, validarla localmente con Docker, cargarla en el clúster kind del curso y ejecutarla dentro de un Pod Kubernetes definido mediante YAML, verificando su funcionamiento, acceso, logs, actualización y limpieza.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Tener Docker Desktop operativo con Linux containers y acceso desde Git Bash.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica construirás una aplicación web mínima y la empaquetarás como una imagen de contenedor basada en NGINX. Primero validarás la imagen con Docker, después la cargarás directamente en los nodos del clúster kind y crearás un Pod mediante un manifiesto YAML. Finalmente inspeccionarás el Pod, accederás a la aplicación mediante port-forward, revisarás sus logs y construirás una segunda versión para observar cómo una aplicación cambia desde el código hasta su ejecución dentro de Kubernetes.
slug: lab3
lab_number: 3
final_result: >
  Al finalizar habrás construido dos versiones locales de una imagen de aplicación, comprobado su funcionamiento con Docker, cargado ambas imágenes dentro del clúster kind ckad y ejecutado la aplicación mediante un Pod Kubernetes definido declarativamente. También habrás utilizado kubectl para inspeccionar estado, eventos, logs y ubicación del Pod, acceder a la aplicación mediante port-forward, reemplazar la versión desplegada y eliminar de forma controlada todos los recursos Kubernetes utilizados durante la práctica conservando los archivos locales generados.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y asumen que el participante inicia desde la raíz del directorio ckad-labs.
  - La imagen base utilizada en esta práctica es nginx:1.31.4-alpine, disponible como imagen oficial de NGINX.
  - Las imágenes ckad-lab3:v1 y ckad-lab3:v2 se mantienen únicamente en el Docker Engine local y se cargan directamente en los nodos kind; no es necesario publicar imágenes en Docker Hub u otro registry.
  - El manifiesto utiliza imagePullPolicy IfNotPresent para permitir que Kubernetes utilice las imágenes cargadas previamente en los nodos kind.
  - Los archivos creados dentro de workspace/lab3 permanecen únicamente en el ambiente local del participante.
references:
  - text: Guía oficial de kind para cargar imágenes locales
    url: https://kind.sigs.k8s.io/docs/user/quick-start/
  - text: Documentación de imágenes de contenedor en Kubernetes
    url: https://kubernetes.io/docs/concepts/containers/images/
  - text: Referencia oficial de kubectl run
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_run/
  - text: Referencia oficial de kubectl port-forward
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_port-forward/
  - text: Imagen oficial de NGINX
    url: https://hub.docker.com/_/nginx
prev: /lab2/lab2/
next: /lab4/lab4/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 🔎 Tarea 1. Preparar la aplicación y su definición de contenedor — 7 min

Prepararás un workspace exclusivo para la práctica, crearás una aplicación web estática mínima y definirás el Dockerfile que permitirá empaquetarla como una imagen reproducible. También revisarás los archivos antes de comenzar el proceso de construcción.

### Tarea 1.1. Crear el workspace y la aplicación web

Crearás el directorio local de trabajo y generarás una página HTML sencilla que permita identificar claramente la versión ejecutada dentro del contenedor y posteriormente dentro de Kubernetes.

- {% include step_label.html %} Crea el directorio `workspace/lab3/app` desde la raíz de `ckad-labs` y accede a él para mantener separados el código y los archivos generados durante esta práctica.

  > **Nota:** El directorio `workspace` representa el espacio de trabajo local del participante y no necesita enviarse nuevamente al repositorio público del curso.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab3/app && cd workspace/lab3/app
  ```

  > **Salida esperada:** El comando finaliza sin errores y la terminal queda ubicada dentro de `ckad-labs/workspace/lab3/app`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el archivo `index.html` con una página mínima que identifique la aplicación como CKAD Lab 3 y marque esta primera compilación como versión `v1`.

  > **Importante:** Mantén exactamente el texto `Version: v1`, porque posteriormente lo utilizaremos para verificar que Kubernetes realmente está ejecutando la imagen correcta.
  {: .lab-note .important .compact}

  ```bash
  cat > index.html <<'HTML'
  <!DOCTYPE html>
  <html lang="es">
  <head>
    <meta charset="UTF-8">
    <title>CKAD Lab 3</title>
  </head>
  <body>
    <h1>CKAD Lab 3</h1>
    <p>Pod application running</p>
    <p>Version: v1</p>
  </body>
  </html>
  HTML
  ```

  > **Salida esperada:** Se crea el archivo `index.html` sin mostrar errores en la terminal.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa el contenido del archivo creado antes de construir la imagen para comprobar que la aplicación contiene la información esperada.

  > **Advertencia:** Si el texto indica otra versión o el HTML está incompleto, corrígelo antes de construir la imagen; una imagen ya creada conservará el contenido existente en ese momento.
  {: .lab-note .warning .compact}

  ```bash
  cat index.html
  ```

  > **Salida esperada:** Se muestra el HTML completo y aparece la línea `Version: v1`.
  {: .lab-note .output .compact}

### Tarea 1.2. Crear y revisar el Dockerfile

Definirás una imagen sencilla basada en NGINX y copiarás la página web al directorio servido por el servidor HTTP. Después revisarás los archivos que formarán parte del contexto de construcción.

- {% include step_label.html %} Crea un `Dockerfile` que utilice la imagen oficial `nginx:1.31.4-alpine` y copie la página web al directorio utilizado por NGINX para servir contenido estático.

  > **Nota:** La variante Alpine mantiene una imagen pequeña y suficiente para esta práctica. Utilizamos un tag específico en lugar de `latest` para mejorar la reproducibilidad.
  {: .lab-note .info .compact}

  ```bash
  cat > Dockerfile <<'DOCKERFILE'
  FROM nginx:1.31.4-alpine
  COPY index.html /usr/share/nginx/html/index.html
  EXPOSE 80
  DOCKERFILE
  ```

  > **Salida esperada:** Se crea el archivo `Dockerfile` sin errores.
  {: .lab-note .output .compact}

- {% include step_label.html %} Examina el Dockerfile con números de línea e identifica las instrucciones utilizadas para seleccionar la imagen base, copiar la aplicación y documentar el puerto HTTP.

  > **Importante:** `EXPOSE 80` documenta el puerto utilizado por la aplicación, pero por sí solo no publica ningún puerto hacia Windows ni crea un Service en Kubernetes.
  {: .lab-note .important .compact}

  ```bash
  cat -n Dockerfile
  ```

  > **Salida esperada:** Se muestran tres instrucciones: `FROM nginx:1.31.4-alpine`, `COPY index.html /usr/share/nginx/html/index.html` y `EXPOSE 80`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Lista el contenido del directorio actual para confirmar que el contexto de construcción contiene únicamente los archivos requeridos por esta primera imagen.

  > **Advertencia:** Docker envía el contexto de construcción al builder. Evita ejecutar builds desde directorios que contengan archivos grandes o información innecesaria.
  {: .lab-note .warning .compact}

  ```bash
  ls -lh
  ```

  > **Salida esperada:** Se muestran al menos `Dockerfile` e `index.html` dentro de `workspace/lab3/app`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🐳 Tarea 2. Construir y validar la imagen con Docker — 8 min

Construirás la primera versión de la imagen de aplicación y comprobarás su existencia antes de utilizar Kubernetes. Después ejecutarás temporalmente un contenedor local y validarás la respuesta HTTP para separar problemas de imagen de posibles problemas del clúster.

### Tarea 2.1. Construir e inspeccionar la imagen v1

Utilizarás Docker para empaquetar la aplicación con el tag `ckad-lab3:v1` y consultarás sus metadatos básicos. Esta imagen será posteriormente transferida a los nodos de kind.

- {% include step_label.html %} Construye la imagen de aplicación desde el Dockerfile actual y asígnale el nombre `ckad-lab3` con el tag específico `v1`.

  > **Nota:** El punto final indica que Docker debe utilizar el directorio actual como contexto de construcción.
  {: .lab-note .info .compact}

  ```bash
  docker build -t ckad-lab3:v1 .
  ```

  > **Salida esperada:** Docker procesa el Dockerfile, descarga la imagen base si es necesario y finaliza creando correctamente `ckad-lab3:v1`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la imagen recién creada para confirmar su nombre, tag, identificador y tamaño antes de intentar cargarla en Kubernetes.

  > **Importante:** El tag debe ser exactamente `v1`; evita utilizar `latest`, ya que posteriormente kind y Kubernetes trabajarán con tags explícitos para controlar qué imagen está disponible.
  {: .lab-note .important .compact}

  ```bash
  docker image ls ckad-lab3:v1
  ```

  > **Salida esperada:** Se muestra una fila para `ckad-lab3` con tag `v1`, un identificador de imagen y su tamaño.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona la arquitectura y el sistema operativo de la imagen para verificar que corresponde a un contenedor Linux compatible con los nodos kind.

  > **Nota:** kind ejecuta nodos Kubernetes como contenedores Linux; la arquitectura puede variar según el equipo, pero debe ser compatible con el Docker Engine utilizado.
  {: .lab-note .info .compact}

  ```bash
  docker image inspect ckad-lab3:v1 --format 'OS={{.Os}} Architecture={{.Architecture}}'
  ```

  > **Salida esperada:** Se muestra `OS=linux` junto con una arquitectura compatible, normalmente `amd64` o `arm64`.
  {: .lab-note .output .compact}

### Tarea 2.2. Probar la aplicación fuera de Kubernetes

Ejecutarás un contenedor temporal desde la imagen recién construida, comprobarás la página mediante HTTP y eliminarás el contenedor para dejar libre el puerto utilizado durante la validación.

- {% include step_label.html %} Ejecuta la imagen `ckad-lab3:v1` como un contenedor temporal denominado `lab3-local` y publica el puerto HTTP del contenedor en el puerto local `8080`.

  > **Importante:** La opción `-p 8080:80` conecta el puerto 8080 de Windows con el puerto 80 del contenedor. Esta publicación pertenece únicamente a Docker y todavía no involucra Kubernetes.
  {: .lab-note .important .compact}

  ```bash
  docker run -d --name lab3-local -p 8080:80 ckad-lab3:v1
  ```

  > **Salida esperada:** Docker devuelve el identificador del nuevo contenedor y este queda ejecutándose en segundo plano.
  {: .lab-note .output .compact}

- {% include step_label.html %} Solicita la página desde Git Bash utilizando `curl` y verifica que el contenido corresponde a la versión `v1` construida en la imagen.

  > **Nota:** Esta prueba demuestra que el servidor NGINX y el archivo HTML funcionan correctamente antes de introducir variables adicionales relacionadas con Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  curl -s http://localhost:8080
  ```

  > **Salida esperada:** Se devuelve el HTML de la aplicación y aparece el texto `Version: v1`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el contenedor temporal y comprueba que el puerto 8080 deja de estar asociado a la prueba local antes de utilizarlo posteriormente con port-forward.

  > **Advertencia:** Utiliza `-f` únicamente sobre el contenedor `lab3-local`; no ejecutes operaciones generales de limpieza que puedan eliminar contenedores pertenecientes al clúster kind.
  {: .lab-note .warning .compact}

  ```bash
  docker rm -f lab3-local
  ```

  > **Salida esperada:** Docker devuelve `lab3-local`, indicando que el contenedor fue eliminado.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 📦 Tarea 3. Cargar la imagen en kind y ejecutar el Pod — 10 min

Transferirás la imagen construida localmente hacia los nodos del clúster kind y confirmarás su presencia antes de crear el workload. Después generarás un manifiesto base, ajustarás la política de descarga y crearás un Pod Kubernetes utilizando la imagen local.

### Tarea 3.1. Incorporar la imagen al clúster kind

Validarás que el clúster correcto continúa disponible, cargarás la imagen en sus nodos y comprobarás directamente desde uno de ellos que el runtime de contenedores puede localizarla.

- {% include step_label.html %} Comprueba que kind reconoce el clúster `ckad` antes de transferir la imagen local hacia sus nodos.

  > **Nota:** El nombre del clúster es necesario porque `kind load docker-image` debe saber a qué conjunto de nodos transferir la imagen.
  {: .lab-note .info .compact}

  ```bash
  kind get clusters
  ```

  > **Salida esperada:** La lista contiene el clúster `ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Carga `ckad-lab3:v1` dentro del clúster kind para que los nodos puedan utilizar la imagen sin depender de un registry externo.

  > **Importante:** Docker Desktop y los nodos kind no comparten automáticamente el mismo almacén de imágenes. `kind load docker-image` copia explícitamente la imagen local al clúster.
  {: .lab-note .important .compact}

  ```bash
  kind load docker-image ckad-lab3:v1 --name ckad
  ```

  > **Salida esperada:** kind informa que la imagen `ckad-lab3:v1` fue cargada correctamente en los nodos del clúster `ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta las imágenes conocidas por el runtime del nodo `ckad-worker` y filtra la imagen cargada para verificar que realmente se encuentra disponible dentro de kind.

  > **Advertencia:** Utiliza `docker exec` únicamente para inspección del nodo. No elimines imágenes ni modifiques manualmente el runtime interno de los nodos kind.
  {: .lab-note .warning .compact}

  ```bash
  docker exec ckad-worker crictl images | grep ckad-lab3
  ```

  > **Salida esperada:** Se muestra una entrada correspondiente a `ckad-lab3` con el tag `v1`.
  {: .lab-note .output .compact}

### Tarea 3.2. Crear el manifiesto y desplegar el Pod

Crearás un namespace aislado, generarás un manifiesto base con kubectl y ajustarás la política de imagen antes de aplicar el recurso declarativamente.

- {% include step_label.html %} Crea el namespace `lab3` para aislar los recursos Kubernetes utilizados por esta práctica.

  > **Nota:** El namespace permitirá eliminar todos los recursos del laboratorio de forma controlada al finalizar sin afectar workloads de otras prácticas.
  {: .lab-note .info .compact}

  ```bash
  kubectl create namespace lab3
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab3 created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Genera un manifiesto YAML para un Pod denominado `ckad-web` utilizando la imagen local `ckad-lab3:v1`, sin crear todavía el recurso en Kubernetes.

  > **Importante:** `--dry-run=client -o yaml` permite obtener rápidamente una definición válida de Pod y reutilizarla como punto de partida para una configuración declarativa.
  {: .lab-note .important .compact}

  ```bash
  kubectl run ckad-web --image=ckad-lab3:v1 --restart=Never -n lab3 --dry-run=client -o yaml > ../pod.yaml
  ```

  > **Salida esperada:** No se crea ningún Pod y aparece el archivo `workspace/lab3/pod.yaml`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Abre `pod.yaml` en Visual Studio Code, agrega `imagePullPolicy: IfNotPresent` debajo del campo `image`, guarda el archivo y aplica el manifiesto al clúster.

  > **Advertencia:** `imagePullPolicy` debe quedar dentro del elemento del contenedor y con la misma indentación que `image`. Una indentación incorrecta puede hacer que el manifiesto sea inválido.
  {: .lab-note .warning .compact}

  ```bash
  code ../pod.yaml
  ```

  > **Salida esperada:** Visual Studio Code abre `workspace/lab3/pod.yaml`. Después de agregar y guardar `imagePullPolicy: IfNotPresent`, el archivo queda listo para aplicarse en el siguiente comando indicado por el instructor.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🔬 Tarea 4. Inspeccionar y acceder a la aplicación en Kubernetes — 10 min

Aplicarás el manifiesto preparado, comprobarás que Kubernetes programó el Pod correctamente, analizarás su información operativa y observarás los logs generados por NGINX. Después utilizarás port-forward para acceder desde Windows a la aplicación ejecutada dentro del clúster.

### Tarea 4.1. Crear y analizar el Pod en ejecución

Crearás el Pod desde el YAML preparado y revisarás tanto su ubicación como los eventos producidos durante scheduling, creación e inicio del contenedor.

- {% include step_label.html %} Aplica el manifiesto `pod.yaml` y espera hasta que `ckad-web` alcance la condición `Ready` para confirmar que Kubernetes inició correctamente la imagen local.

  > **Importante:** Si la espera termina por timeout, no recrees inmediatamente el Pod. Continúa con `kubectl describe` para determinar si el problema está relacionado con scheduling o con la imagen.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f ../pod.yaml && kubectl wait --for=condition=Ready pod/ckad-web -n lab3 --timeout=60s
  ```

  > **Salida esperada:** Kubernetes responde `pod/ckad-web created` y posteriormente `pod/ckad-web condition met`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el Pod en formato ampliado para identificar su estado, dirección IP interna y nodo donde el scheduler decidió ejecutarlo.

  > **Nota:** La columna `NODE` relaciona directamente el objeto Pod con uno de los nodos disponibles del clúster.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod ckad-web -n lab3 -o wide
  ```

  > **Salida esperada:** `ckad-web` aparece con `READY` igual a `1/1`, `STATUS` igual a `Running`, una dirección IP y un nodo asignado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Examina detalladamente el Pod para identificar la imagen utilizada, la política de descarga, las condiciones y los eventos generados durante su ciclo de inicio.

  > **Nota:** La sección `Events` es especialmente útil para diferenciar problemas de scheduling, disponibilidad de imagen, creación del sandbox o inicio del contenedor.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe pod ckad-web -n lab3
  ```

  > **Salida esperada:** Se muestra información detallada de `ckad-web`, incluyendo `Image: ckad-lab3:v1`, `Image Pull Policy: IfNotPresent`, estado del contenedor y eventos recientes.
  {: .lab-note .output .compact}

### Tarea 4.2. Consultar logs y acceder mediante port-forward

Revisarás la salida generada por NGINX y abrirás temporalmente un túnel local hacia el Pod para comprobar desde Windows que la aplicación responde realmente desde Kubernetes.

- {% include step_label.html %} Consulta los logs actuales del Pod para confirmar que kubectl puede recuperar la salida estándar generada por el contenedor NGINX.

  > **Nota:** Antes de recibir tráfico HTTP los logs pueden contener únicamente mensajes de inicialización; después del acceso aparecerán registros adicionales de solicitudes.
  {: .lab-note .info .compact}

  ```bash
  kubectl logs pod/ckad-web -n lab3
  ```

  > **Salida esperada:** Se muestran mensajes de inicio de NGINX o registros existentes del contenedor sin errores de acceso.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inicia un port-forward en segundo plano desde el puerto local 8080 hacia el puerto 80 del Pod y guarda el identificador del proceso para poder detenerlo posteriormente.

  > **Importante:** `kubectl port-forward` mantiene una conexión activa mientras el proceso existe. Guardaremos su PID para finalizar únicamente este túnel al terminar la validación.
  {: .lab-note .important .compact}

  ```bash
  kubectl port-forward pod/ckad-web 8080:80 -n lab3 > ../port-forward.log 2>&1 & echo $! > ../port-forward.pid
  ```

  > **Salida esperada:** Git Bash devuelve el control de la terminal y se crean `port-forward.log` y `port-forward.pid` dentro de `workspace/lab3`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera brevemente a que el túnel esté disponible, consulta la aplicación y detén únicamente el proceso de port-forward cuando hayas confirmado la respuesta.

  > **Advertencia:** No cierres Docker Desktop ni elimines el Pod durante la prueba. El túnel depende de que `ckad-web` continúe ejecutándose.
  {: .lab-note .warning .compact}

  ```bash
  sleep 2 && curl -s http://localhost:8080 && kill "$(cat ../port-forward.pid)"
  ```

  > **Salida esperada:** `curl` devuelve el HTML servido desde Kubernetes y aparece `Version: v1`; después el proceso de port-forward termina.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🔄 Tarea 5. Construir una nueva versión y limpiar el laboratorio — 10 min

Modificarás el contenido de la aplicación, construirás una nueva imagen y la cargarás al clúster. Después reemplazarás el Pod para ejecutar la versión actualizada, verificarás el resultado y eliminarás únicamente los recursos Kubernetes de esta práctica.

### Tarea 5.1. Construir y cargar la versión v2

Actualizarás el código local para identificar una nueva versión, reconstruirás la imagen con un tag diferente y la incorporarás nuevamente a los nodos del clúster kind.

- {% include step_label.html %} Modifica el archivo `index.html` reemplazando únicamente la cadena `Version: v1` por `Version: v2` y confirma el cambio antes de reconstruir la imagen.

  > **Nota:** Utilizar un tag nuevo evita ambigüedades entre dos contenidos diferentes y facilita observar qué versión está ejecutando Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  sed -i 's/Version: v1/Version: v2/' index.html && grep 'Version:' index.html
  ```

  > **Salida esperada:** Se muestra la línea HTML que contiene `Version: v2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Construye una segunda imagen denominada `ckad-lab3:v2` utilizando el mismo Dockerfile pero incorporando el contenido actualizado de la aplicación.

  > **Importante:** No sobrescribas el tag `v1`. Mantener ambas imágenes facilita comprender que un tag identifica una versión concreta del artefacto construido.
  {: .lab-note .important .compact}

  ```bash
  docker build -t ckad-lab3:v2 .
  ```

  > **Salida esperada:** Docker finaliza correctamente y crea la imagen `ckad-lab3:v2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Carga la nueva imagen dentro del clúster `ckad` y confirma que ambos tags de la aplicación permanecen disponibles localmente.

  > **Advertencia:** Cargar una imagen nueva en kind no actualiza automáticamente Pods existentes. Un Pod que ya está ejecutando `v1` continuará usando esa versión hasta que sea reemplazado.
  {: .lab-note .warning .compact}

  ```bash
  kind load docker-image ckad-lab3:v2 --name ckad && docker image ls ckad-lab3
  ```

  > **Salida esperada:** kind informa que `ckad-lab3:v2` fue cargada y Docker muestra al menos los tags `v1` y `v2`.
  {: .lab-note .output .compact}

### Tarea 5.2. Reemplazar el Pod, validar v2 y limpiar

Actualizarás el manifiesto local para apuntar a la nueva imagen y recrearás el Pod, ya que el cambio de imagen de un Pod individual no representa un mecanismo completo de rollout. Finalmente comprobarás la versión y eliminarás el namespace.

- {% include step_label.html %} Actualiza el manifiesto `pod.yaml` para utilizar `ckad-lab3:v2` y muestra la línea de imagen resultante antes de aplicar cualquier cambio.

  > **Importante:** En workloads administrados normalmente se utilizarían controladores como Deployment para manejar cambios de versión. Aquí usamos un Pod individual porque el objetivo es comprender directamente su construcción y ciclo de vida.
  {: .lab-note .important .compact}

  ```bash
  sed -i 's/ckad-lab3:v1/ckad-lab3:v2/' ../pod.yaml && grep -E 'image:|imagePullPolicy:' ../pod.yaml
  ```

  > **Salida esperada:** El manifiesto muestra `image: ckad-lab3:v2` y conserva `imagePullPolicy: IfNotPresent`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el Pod actual, vuelve a crearlo utilizando el manifiesto actualizado y espera hasta que la nueva instancia alcance la condición `Ready`.

  > **Advertencia:** Un Pod individual tiene campos que no pueden modificarse libremente una vez creado. Para este ejercicio se elimina y vuelve a crear deliberadamente; las actualizaciones administradas se estudiarán con controladores apropiados.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete pod ckad-web -n lab3 --wait=true && kubectl apply -f ../pod.yaml && kubectl wait --for=condition=Ready pod/ckad-web -n lab3 --timeout=60s
  ```

  > **Salida esperada:** El Pod anterior es eliminado, Kubernetes crea nuevamente `ckad-web` y `kubectl wait` confirma que la nueva instancia está `Ready`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Verifica que el nuevo Pod utiliza `ckad-lab3:v2`, consulta la página directamente desde el contenedor y elimina finalmente el namespace `lab3`.

  > **Nota:** Los archivos `Dockerfile`, `index.html` y `pod.yaml` se conservarán en `workspace/lab3`; únicamente se eliminan los recursos activos del clúster.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod ckad-web -n lab3 -o jsonpath='Image={.spec.containers[0].image}{"\n"}' && kubectl exec -n lab3 ckad-web -- wget -qO- http://127.0.0.1/ | grep 'Version:' && kubectl delete namespace lab3 --wait=true
  ```

  > **Salida esperada:** Se muestra `Image=ckad-lab3:v2`, la respuesta HTML contiene `Version: v2` y Kubernetes finaliza indicando `namespace "lab3" deleted`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}