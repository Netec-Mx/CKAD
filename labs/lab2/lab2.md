---
layout: lab
title: "Práctica 2: Gestión básica con kubectl y YAML"
permalink: /lab2/lab2/
images_base: /labs/lab2/img
duration: "45 minutos"
objective:
  - Administrar recursos básicos de Kubernetes utilizando kubectl y manifiestos YAML, aplicando enfoques imperativos y declarativos, herramientas de descubrimiento, consultas especializadas y técnicas de generación rápida de configuraciones orientadas a la preparación para CKAD.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Disponer del clúster kind denominado ckad con un nodo Control Plane y dos Worker Nodes en estado Ready.
  - Tener kubectl configurado con acceso al contexto kind-ckad.
  - Trabajar desde Visual Studio Code utilizando Git Bash como terminal principal.
  - Disponer localmente del directorio ckad-labs obtenido desde el repositorio público del curso.
introduction:
  - En esta práctica comenzarás a trabajar directamente con Kubernetes utilizando kubectl y manifiestos YAML. Explorarás el clúster y la API, crearás recursos mediante comandos imperativos, generarás manifiestos con dry-run, analizarás su estructura, aplicarás cambios declarativamente y utilizarás diferentes formatos de salida, JSONPath, labels y selectores. Los archivos generados permanecerán únicamente en tu workspace local y al finalizar eliminarás todos los recursos utilizados durante la práctica.
slug: lab2
lab_number: 2
final_result: >
  Al finalizar podrás utilizar kubectl para descubrir recursos y consultar ayuda directamente desde el clúster, crear Pods mediante comandos imperativos, generar manifiestos YAML sin escribirlos completamente desde cero, interpretar las secciones apiVersion, kind, metadata y spec, administrar recursos declarativamente mediante kubectl apply y kubectl diff, consultar información utilizando diferentes formatos de salida, JSONPath y selectores, y eliminar de forma controlada los recursos utilizados durante la práctica.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y asumen que el participante comienza dentro del directorio ckad-labs obtenido durante la Práctica 1.
  - El clúster de referencia utilizado durante el curso ejecuta Kubernetes 1.36.1 y utiliza el contexto kubectl kind-ckad.
  - Los archivos YAML creados durante esta práctica se almacenarán en workspace/lab2 y permanecerán únicamente en la estación local del participante.
  - No elimines ni reconstruyas el clúster ckad durante esta práctica; únicamente serán eliminados los recursos creados específicamente para lab2.
references:
  - text: Referencia rápida oficial de kubectl
    url: https://kubernetes.io/docs/reference/kubectl/quick-reference/
  - text: Convenciones de uso de kubectl
    url: https://kubernetes.io/docs/reference/kubectl/conventions/
  - text: Administración declarativa de objetos Kubernetes
    url: https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/
  - text: Soporte JSONPath en kubectl
    url: https://kubernetes.io/docs/reference/kubectl/jsonpath/
prev: /lab1/lab1/
next: /lab3/lab3/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 🔎 Tarea 1. Explorar el clúster y la API con kubectl — 7 min

Antes de crear recursos revisarás el contexto activo, la topología disponible y las capacidades expuestas por la API de Kubernetes. También utilizarás las herramientas de ayuda incorporadas en kubectl para descubrir recursos, campos y opciones sin depender de documentación externa.

### Tarea 1.1. Validar el contexto y explorar el clúster

Confirmarás que kubectl apunta al clúster correcto y revisarás los nodos y namespaces disponibles antes de realizar cambios. Estas verificaciones reducen el riesgo de ejecutar comandos accidentalmente sobre otro entorno Kubernetes.

- {% include step_label.html %} Comprueba el contexto activo de kubectl para asegurarte de que todos los comandos de esta práctica serán enviados al clúster local `ckad` creado anteriormente.

  > **Importante:** El contexto esperado es `kind-ckad`. Si aparece un contexto diferente, no continúes creando recursos hasta seleccionar explícitamente el contexto correcto.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la información general del clúster y confirma que kubectl mantiene comunicación con el API Server y los servicios principales de Kubernetes.

  > **Nota:** kind publica el Kubernetes API Server utilizando un puerto local dinámico, por lo que la dirección exacta mostrada puede ser diferente entre participantes.
  {: .lab-note .info .compact}

  ```bash
  kubectl cluster-info
  ```

  > **Salida esperada:** Se muestra la dirección del Kubernetes control plane y la información de CoreDNS sin errores de conexión, autenticación o certificados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Lista simultáneamente los nodos y namespaces actuales para reconocer la topología disponible y los espacios lógicos existentes antes de crear el namespace de esta práctica.

  > **Advertencia:** No modifiques ni elimines namespaces del sistema como `kube-system`, `kube-public` o `kube-node-lease`, ya que contienen recursos necesarios para el funcionamiento del clúster.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get nodes && printf '\nNamespaces disponibles:\n' && kubectl get namespaces
  ```

  > **Salida esperada:** Se muestran `ckad-control-plane`, `ckad-worker` y `ckad-worker2` en estado `Ready`, seguidos por namespaces como `default`, `kube-system`, `kube-public` y `kube-node-lease`.
  {: .lab-note .output .compact}

### Tarea 1.2. Descubrir recursos y utilizar la ayuda integrada

Utilizarás comandos de descubrimiento incluidos en kubectl para identificar recursos de la API, consultar la estructura de un Pod y revisar la ayuda disponible para operaciones comunes durante el examen CKAD.

- {% include step_label.html %} Consulta los recursos disponibles en la API y filtra aquellos relacionados con Pods, namespaces y Deployments para identificar sus nombres cortos, versiones y alcance.

  > **Nota:** `kubectl api-resources` obtiene la información directamente del API Server y permite descubrir qué tipos de recursos admite realmente el clúster conectado.
  {: .lab-note .info .compact}

  ```bash
  kubectl api-resources | grep -E '^(pods|namespaces|deployments)'
  ```

  > **Salida esperada:** Se muestran entradas correspondientes a `pods`, `namespaces` y `deployments`, incluyendo columnas como `SHORTNAMES`, `APIVERSION`, `NAMESPACED` y `KIND`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Utiliza `kubectl explain` para consultar directamente desde el esquema OpenAPI la definición del campo `spec.containers` de un Pod.

  > **Importante:** `kubectl explain` es especialmente útil cuando necesitas recordar rápidamente la estructura o el nombre exacto de un campo YAML sin abandonar la terminal.
  {: .lab-note .important .compact}

  ```bash
  kubectl explain pod.spec.containers
  ```

  > **Salida esperada:** kubectl muestra información del campo `containers`, su tipo, si es requerido y una descripción de su función dentro de `PodSpec`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la ayuda específica de `kubectl get` para localizar opciones de salida disponibles que posteriormente utilizarás para inspeccionar objetos Kubernetes.

  > **Nota:** Todos los comandos principales de kubectl proporcionan ayuda integrada mediante `--help`; acostumbrarte a utilizarla reduce la necesidad de memorizar todas las opciones.
  {: .lab-note .info .compact}

  ```bash
  kubectl get --help | grep -A 12 "Output options"
  ```

  > **Salida esperada:** Se muestra la sección de opciones de salida o líneas relacionadas con formatos disponibles para representar los recursos consultados.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## ⚡ Tarea 2. Crear y administrar recursos de forma imperativa — 8 min

Utilizarás comandos imperativos de kubectl para crear rápidamente un namespace y un Pod, consultar su estado y analizar eventos y propiedades. Después eliminarás el recurso para diferenciar este flujo de la administración declarativa que utilizarás posteriormente.

### Tarea 2.1. Crear recursos mediante comandos imperativos

Prepararás un namespace aislado para la práctica y crearás un Pod directamente desde la línea de comandos. Esta técnica permite trabajar rápidamente sin preparar previamente un archivo YAML.

- {% include step_label.html %} Crea un namespace denominado `lab2` para mantener aislados todos los objetos Kubernetes utilizados durante esta práctica.

  > **Nota:** Los namespaces permiten agrupar recursos namespaced dentro de un mismo clúster. Utilizar uno por práctica facilita identificar y eliminar posteriormente los objetos creados.
  {: .lab-note .info .compact}

  ```bash
  kubectl create namespace lab2
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab2 created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea de forma imperativa un Pod denominado `web-imperative` utilizando la imagen estable `nginx:1.28-alpine` dentro del namespace `lab2`.

  > **Importante:** `kubectl run` crea directamente un Pod. En esta práctica se utiliza para comparar el enfoque imperativo con la administración mediante manifiestos YAML que realizarás después.
  {: .lab-note .important .compact}

  ```bash
  kubectl run web-imperative --image=nginx:1.28-alpine --restart=Never -n lab2
  ```

  > **Salida esperada:** Kubernetes responde `pod/web-imperative created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que el Pod alcance la condición `Ready` y después consulta información ampliada para verificar la imagen, dirección IP y nodo asignado.

  > **Advertencia:** No continúes si `kubectl wait` termina por timeout. En ese caso debes revisar el Pod con `kubectl describe` antes de realizar operaciones adicionales.
  {: .lab-note .warning .compact}

  ```bash
  kubectl wait --for=condition=Ready pod/web-imperative -n lab2 --timeout=60s && kubectl get pod web-imperative -n lab2 -o wide
  ```

  > **Salida esperada:** `kubectl wait` informa que se cumplió la condición y el Pod aparece con `STATUS` igual a `Running`, `READY` igual a `1/1` y un nodo asignado.
  {: .lab-note .output .compact}

### Tarea 2.2. Inspeccionar y eliminar un recurso imperativo

Consultarás el mismo objeto desde diferentes perspectivas para distinguir entre información resumida y diagnóstico detallado. Finalmente eliminarás el Pod antes de comenzar el flujo basado en YAML.

- {% include step_label.html %} Consulta el Pod en formato estándar y posteriormente en formato ampliado para observar cómo `-o wide` incorpora información adicional sin modificar el recurso.

  > **Nota:** El formato estándar está orientado a revisión rápida, mientras que `-o wide` incorpora columnas adicionales como dirección IP y nodo asignado.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod web-imperative -n lab2 && kubectl get pod web-imperative -n lab2 -o wide
  ```

  > **Salida esperada:** Ambas consultas muestran el mismo Pod; la segunda incluye columnas adicionales como `IP`, `NODE` y otros datos disponibles.
  {: .lab-note .output .compact}

- {% include step_label.html %} Examina detalladamente el Pod mediante `kubectl describe` para identificar configuración, condiciones, dirección IP, contenedores y eventos registrados por Kubernetes.

  > **Importante:** La sección `Events` suele ser uno de los primeros lugares que debes revisar cuando un Pod no inicia correctamente, porque registra decisiones y errores relacionados con scheduling, imágenes y ejecución.
  {: .lab-note .important .compact}

  ```bash
  kubectl describe pod web-imperative -n lab2
  ```

  > **Salida esperada:** Se presenta información detallada del Pod y al final una sección `Events` con eventos relacionados con scheduling, descarga de la imagen, creación e inicio del contenedor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el Pod creado imperativamente y confirma que ya no existe dentro del namespace antes de continuar con los manifiestos declarativos.

  > **Advertencia:** Elimina únicamente `web-imperative`. Mantén el namespace `lab2`, ya que seguirá utilizándose durante el resto de la práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete pod web-imperative -n lab2 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `pod "web-imperative" deleted`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 📝 Tarea 3. Generar y comprender manifiestos YAML — 9 min

Utilizarás kubectl como generador de manifiestos para reducir el tiempo necesario para escribir YAML manualmente. Después analizarás las principales secciones del objeto y prepararás una copia local que servirá como fuente declarativa durante el resto del laboratorio.

### Tarea 3.1. Generar un manifiesto YAML con kubectl

Crearás un workspace local exclusivo para esta práctica y utilizarás `--dry-run=client` junto con `-o yaml` para generar una definición de Pod sin enviar todavía ningún objeto al API Server.

- {% include step_label.html %} Crea el directorio local `workspace/lab2` desde la raíz de `ckad-labs` y accede a él para mantener separados los archivos generados durante esta práctica.

  > **Nota:** `workspace` representa el área de trabajo local del participante. Los archivos creados aquí no necesitan enviarse nuevamente al repositorio público del curso.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab2 && cd workspace/lab2
  ```

  > **Salida esperada:** El comando finaliza sin errores y la terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Genera la representación YAML de un Pod denominado `web-yaml` utilizando `--dry-run=client` y muestra el resultado directamente en la terminal sin crear el recurso.

  > **Importante:** `--dry-run=client` procesa la solicitud localmente y evita enviarla al API Server. Combinado con `-o yaml` es una técnica rápida para generar plantillas durante tareas CKAD.
  {: .lab-note .important .compact}

  ```bash
  kubectl run web-yaml --image=nginx:1.28-alpine --restart=Never -n lab2 --dry-run=client -o yaml
  ```

  > **Salida esperada:** Se muestra un manifiesto YAML que contiene, entre otros campos, `apiVersion: v1`, `kind: Pod`, `metadata`, `spec` y la imagen `nginx:1.28-alpine`; no se crea ningún Pod en el clúster.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta nuevamente la generación y redirige la salida hacia `web-pod.yaml` para disponer de una definición declarativa editable en el workspace local.

  > **Advertencia:** El operador `>` reemplaza el contenido del archivo si ya existe. Verifica que te encuentras en `workspace/lab2` antes de ejecutarlo para no sobrescribir accidentalmente otro manifiesto.
  {: .lab-note .warning .compact}

  ```bash
  kubectl run web-yaml --image=nginx:1.28-alpine --restart=Never -n lab2 --dry-run=client -o yaml > web-pod.yaml
  ```

  > **Salida esperada:** El comando no imprime contenido en pantalla y se crea localmente el archivo `web-pod.yaml`.
  {: .lab-note .output .compact}

### Tarea 3.2. Analizar la estructura del manifiesto

Examinarás el archivo generado para relacionar las secciones fundamentales de un objeto Kubernetes con su función dentro de la API. También comprobarás el namespace y la definición del contenedor antes de enviarlo al clúster.

- {% include step_label.html %} Muestra el manifiesto completo con números de línea para identificar visualmente los bloques principales que conforman el objeto Kubernetes.

  > **Nota:** Los objetos Kubernetes suelen definir `apiVersion`, `kind`, `metadata` y `spec`. Comprender esta estructura facilita modificar manifiestos existentes sin depender exclusivamente de comandos imperativos.
  {: .lab-note .info .compact}

  ```bash
  cat -n web-pod.yaml
  ```

  > **Salida esperada:** Se muestra el contenido numerado de `web-pod.yaml`, incluyendo `apiVersion: v1`, `kind: Pod`, `metadata:` y `spec:`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Extrae las líneas que identifican versión de API, tipo de objeto, nombre y namespace para reconocer los metadatos mínimos utilizados por Kubernetes.

  > **Importante:** `apiVersion` y `kind` determinan el esquema del objeto, mientras que `metadata.name` y `metadata.namespace` identifican dónde será almacenado dentro del clúster.
  {: .lab-note .important .compact}

  ```bash
  grep -E '^(apiVersion:|kind:|  name:|  namespace:)' web-pod.yaml
  ```

  > **Salida esperada:** Se muestran valores equivalentes a `apiVersion: v1`, `kind: Pod`, `name: web-yaml` y `namespace: lab2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Localiza la definición del contenedor y la imagen configurada para comprobar que el estado deseado registrado en `spec` corresponde al workload previsto.

  > **Nota:** La sección `spec` expresa gran parte del estado deseado del objeto. En un Pod contiene, entre otros elementos, la colección de contenedores que Kubernetes debe ejecutar.
  {: .lab-note .info .compact}

  ```bash
  grep -A 6 'containers:' web-pod.yaml
  ```

  > **Salida esperada:** Se muestra la sección de contenedores incluyendo `image: nginx:1.28-alpine` y el nombre generado para el contenedor.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🚀 Tarea 4. Administrar recursos de forma declarativa — 12 min

Utilizarás el manifiesto YAML como fuente del estado deseado y administrarás el objeto mediante `kubectl apply`. Después modificarás localmente labels y propiedades del contenedor, revisarás previamente las diferencias y aplicarás los cambios al recurso existente.

### Tarea 4.1. Crear el recurso desde YAML

Aplicarás el manifiesto generado anteriormente, validarás el Pod resultante y recuperarás desde el API Server la representación YAML del objeto para comparar configuración local y estado almacenado.

- {% include step_label.html %} Aplica `web-pod.yaml` para crear declarativamente el Pod definido en el archivo dentro del namespace `lab2`.

  > **Importante:** Cuando un recurso vaya a administrarse declarativamente con `kubectl apply`, conviene crearlo desde el principio utilizando `apply` para mantener un flujo consistente de configuración.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f web-pod.yaml
  ```

  > **Salida esperada:** Kubernetes responde `pod/web-yaml created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que el Pod alcance la condición `Ready` y comprueba que el objeto declarado en el archivo se encuentra ejecutándose correctamente.

  > **Nota:** Esperar explícitamente una condición evita depender de tiempos arbitrarios y permite continuar únicamente cuando Kubernetes confirma que el recurso alcanzó el estado solicitado.
  {: .lab-note .info .compact}

  ```bash
  kubectl wait --for=condition=Ready pod/web-yaml -n lab2 --timeout=60s && kubectl get pod web-yaml -n lab2
  ```

  > **Salida esperada:** `kubectl wait` informa que se cumplió la condición y posteriormente `web-yaml` aparece con `READY` igual a `1/1` y `STATUS` igual a `Running`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Recupera desde Kubernetes la representación YAML completa del Pod para observar campos adicionales que el API Server y otros componentes incorporaron al objeto almacenado.

  > **Nota:** El YAML recuperado desde el clúster contiene más información que el manifiesto original porque Kubernetes agrega metadatos, valores predeterminados y una sección `status`.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod web-yaml -n lab2 -o yaml
  ```

  > **Salida esperada:** Se muestra el objeto completo con campos adicionales como `uid`, `resourceVersion`, información del nodo y una sección `status`.
  {: .lab-note .output .compact}

### Tarea 4.2. Modificar y volver a aplicar el manifiesto

Editarás el estado deseado directamente desde Visual Studio Code, utilizarás `kubectl diff` para anticipar los cambios y aplicarás nuevamente el archivo para comprobar cómo Kubernetes actualiza el objeto existente.

- {% include step_label.html %} Abre `web-pod.yaml` desde Git Bash utilizando Visual Studio Code para modificar el manifiesto local sin abandonar el entorno de trabajo del curso.

  > **Nota:** El comando `code` abre el archivo utilizando Visual Studio Code. Si ya tienes VS Code abierto, el documento normalmente aparecerá como una nueva pestaña en la ventana existente.
  {: .lab-note .info .compact}

  ```bash
  code web-pod.yaml
  ```

  > **Salida esperada:** Visual Studio Code abre `web-pod.yaml` y permite editar directamente el manifiesto almacenado en `workspace/lab2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega manualmente el label `environment: training` dentro de `metadata.labels`, guarda el archivo y utiliza `kubectl diff` para visualizar la diferencia antes de modificar el recurso activo.

  > **Importante:** En VS Code coloca `environment: training` con la misma indentación que los demás labels dentro de `metadata.labels`. YAML depende de la indentación; evita utilizar tabuladores.
  {: .lab-note .important .compact}

  ```bash
  kubectl diff -f web-pod.yaml
  ```

  > **Salida esperada:** Se muestra una diferencia entre el estado activo y el manifiesto local donde aparece la incorporación del label `environment: training`. `kubectl diff` puede finalizar con código de salida `1` cuando existen diferencias; esto es esperado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica nuevamente el manifiesto modificado y consulta los labels del Pod para confirmar que Kubernetes incorporó el nuevo metadato sin crear un segundo objeto.

  > **Advertencia:** No cambies campos inmutables del Pod durante esta tarea. Algunas propiedades de `PodSpec` no pueden modificarse después de crear el recurso y provocarían que `kubectl apply` rechazara la actualización.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply -f web-pod.yaml && kubectl get pod web-yaml -n lab2 --show-labels
  ```

  > **Salida esperada:** Kubernetes responde `pod/web-yaml configured` y la columna `LABELS` incluye `environment=training`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## ✅ Tarea 5. Consultar, filtrar y limpiar los recursos — 9 min

Finalizarás utilizando formatos de salida útiles para CKAD, consultas JSONPath y selectores basados en labels. Después eliminarás el recurso desde su manifiesto y borrarás el namespace para devolver el clúster a un estado limpio sin eliminar los archivos locales creados.

### Tarea 5.1. Consultar información de forma eficiente

Extraerás información específica del recurso evitando revisar manualmente todo el YAML. Utilizarás salida ampliada, JSONPath y un selector para practicar tres mecanismos frecuentes de consulta mediante kubectl.

- {% include step_label.html %} Consulta todos los Pods del namespace utilizando formato ampliado para identificar rápidamente estado, dirección IP y nodo donde Kubernetes programó cada workload.

  > **Nota:** `-o wide` es una forma rápida de obtener datos operativos adicionales sin tener que utilizar una expresión personalizada o inspeccionar el YAML completo.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab2 -o wide
  ```

  > **Salida esperada:** Se muestra `web-yaml` en estado `Running`, junto con su dirección IP y el nombre del nodo donde está ejecutándose.
  {: .lab-note .output .compact}

- {% include step_label.html %} Utiliza JSONPath para extraer únicamente el nombre del Pod, la imagen utilizada y el nodo asignado a partir del objeto devuelto por el API Server.

  > **Importante:** JSONPath permite obtener campos concretos sin procesar visualmente todo el objeto. Dominar consultas sencillas puede ahorrar tiempo significativo durante ejercicios prácticos.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pod web-yaml -n lab2 -o jsonpath='Pod={.metadata.name}{"\n"}Image={.spec.containers[0].image}{"\n"}Node={.spec.nodeName}{"\n"}'
  ```

  > **Salida esperada:** Se muestran tres líneas con el nombre `web-yaml`, la imagen `nginx:1.28-alpine` y el nodo asignado al Pod.
  {: .lab-note .output .compact}

- {% include step_label.html %} Filtra los Pods mediante el label incorporado anteriormente para comprobar cómo Kubernetes permite localizar recursos a partir de metadatos en lugar de utilizar únicamente sus nombres.

  > **Nota:** Los selectores son fundamentales para relacionar y consultar recursos Kubernetes. La opción `-l` es la forma abreviada de `--selector`.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab2 -l environment=training --show-labels
  ```

  > **Salida esperada:** La consulta devuelve `web-yaml` y muestra entre sus labels `environment=training`.
  {: .lab-note .output .compact}

### Tarea 5.2. Eliminar los recursos y validar el estado final

Utilizarás el mismo manifiesto declarativo para eliminar el objeto que representa y después borrarás el namespace completo. Finalmente confirmarás que el clúster principal continúa disponible para las prácticas posteriores.

- {% include step_label.html %} Elimina el Pod utilizando como referencia el mismo archivo YAML que se utilizó para crearlo y actualizarlo declarativamente.

  > **Nota:** `kubectl delete -f` identifica los objetos definidos en el archivo y solicita su eliminación al API Server, manteniendo el manifiesto local disponible para reutilizarlo posteriormente.
  {: .lab-note .info .compact}

  ```bash
  kubectl delete -f web-pod.yaml --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `pod "web-yaml" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab2` y espera a que Kubernetes complete su terminación para garantizar que ningún recurso de la práctica permanezca activo.

  > **Advertencia:** Verifica cuidadosamente el nombre antes de ejecutar el comando. No elimines namespaces del sistema ni recursos pertenecientes a otras prácticas.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab2 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab2" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace desapareció y confirma simultáneamente que los tres nodos del clúster `ckad` continúan operativos para la siguiente práctica.

  > **Importante:** El archivo `workspace/lab2/web-pod.yaml` debe conservarse localmente aunque el objeto Kubernetes haya sido eliminado; así podrás revisar posteriormente la sintaxis utilizada durante el laboratorio.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab2 --ignore-not-found && kubectl get nodes
  ```

  > **Salida esperada:** No se muestra ningún namespace denominado `lab2` y los nodos `ckad-control-plane`, `ckad-worker` y `ckad-worker2` continúan en estado `Ready`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---