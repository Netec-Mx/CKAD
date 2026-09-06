---
layout: lab
title: "Práctica 23: Monitoreo básico de recursos"
permalink: /lab23/lab23/
images_base: /labs/lab23/img
duration: "35 minutos"
objective:
  - Consultar métricas básicas de CPU y memoria con kubectl top, comparar consumo observado entre Pods y nodos y correlacionar las métricas obtenidas con requests y limits declarados en los workloads.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 17 Control de recursos de aplicaciones.
  - Haber completado la Práctica 22 Depuración de aplicaciones fallidas.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica habilitarás la Metrics API en el clúster local y utilizarás kubectl top para observar consumo real de CPU y memoria. Después resolverás retos donde deberás establecer una línea base, generar carga controlada de CPU y memoria, comparar workloads y relacionar consumo observado con requests y limits. Las métricas pueden variar entre ejecuciones, por lo que el objetivo será interpretar tendencias y diferencias relativas, no reproducir valores exactos.
slug: lab23
lab_number: 23
final_result: >
  Al finalizar habrás habilitado Metrics Server en kind, consultado métricas de nodos y Pods, identificado workloads con mayor consumo de CPU y memoria y comparado esos valores con requests y limits declarados. También habrás distinguido entre configuración de recursos y consumo real observado, evitando interpretar un valor alto como un fallo sin contexto.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - La práctica utiliza Metrics Server v0.9.0, compatible con Kubernetes 1.34 y versiones posteriores.
  - kubectl top depende de la Metrics API y no mide CPU o memoria directamente.
  - En el clúster kind del laboratorio se agrega --kubelet-insecure-tls a Metrics Server porque los certificados de servicio de kubelet no se validan contra una CA confiable para este escenario local; esta opción es únicamente para pruebas.
  - Las métricas no aparecen instantáneamente después de crear un workload; puede ser necesario esperar varios segundos hasta que Metrics Server disponga de una muestra.
  - requests y limits representan configuración declarada; los valores mostrados por kubectl top representan consumo observado y no tienen por qué coincidir.
  - Los primeros 5 pasos son guiados y los siguientes 20 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 20/80.
references:
  - text: Metrics Server
    url: https://github.com/kubernetes-sigs/metrics-server
  - text: Metrics Server v0.9.0
    url: https://github.com/kubernetes-sigs/metrics-server/releases/tag/v0.9.0
  - text: kubectl top
    url: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#top
  - text: Resource Management for Pods and Containers
    url: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
prev: /lab22/lab22/
next: /lab24/lab24/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 📊 Tarea 1. Preparar Metrics API y kubectl top — 7 min

Configurarás el workspace y habilitarás Metrics Server en el clúster local para disponer de la API que utiliza `kubectl top`.

### Tarea 1.1. Preparar el entorno

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea `workspace/lab23` y accede al directorio para almacenar los manifiestos de los workloads de monitoreo.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab23`.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab23 && cd workspace/lab23
  ```

  > **Salida esperada:** La terminal queda ubicada dentro de `ckad-labs/workspace/lab23`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que kubectl apunta al clúster local correcto antes de instalar un componente con alcance de clúster.

  > **Importante:** El contexto esperado es `kind-ckad`; Metrics Server se instala fuera del namespace del laboratorio.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab23` para aislar los workloads cuyo consumo observarás durante la práctica.

  > **Advertencia:** Si `lab23` ya existe, revisa primero sus workloads para no mezclar métricas de ejecuciones anteriores.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab23
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab23 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Habilitar y comprobar Metrics API

- {% include step_label.html %} Instala Metrics Server v0.9.0 y adapta su conexión hacia los kubelets del clúster kind agregando la opción requerida para certificados autofirmados del entorno local.

  > **Advertencia:** `--kubelet-insecure-tls` deshabilita la validación de certificados del kubelet y se utiliza aquí únicamente en un clúster local de laboratorio; no es una recomendación para producción.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.0/components.yaml
  ```
  ```bash
  kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
  ```

  > **Salida esperada:** Los recursos de Metrics Server se crean o actualizan y el Deployment queda configurado con `--kubelet-insecure-tls`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que Metrics Server esté disponible y comprueba que la Metrics API devuelve consumo de los nodos.

  > **Importante:** Si `kubectl top` muestra temporalmente `Metrics API not available`, espera unos segundos y vuelve a consultarlo; Metrics Server necesita obtener sus primeras muestras.
  {: .lab-note .important .compact}

  ```bash
  kubectl rollout status deployment/metrics-server -n kube-system --timeout=90s
  ```
  ```bash
  kubectl top nodes
  ```

  > **Salida esperada:** El Deployment completa su rollout y `kubectl top nodes` muestra CPU y memoria para los nodos `ckad-control-plane`, `ckad-worker` y `ckad-worker2`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: establecer una línea base de consumo — 5 min

Crearás dos workloads de referencia y obtendrás una primera lectura que servirá para comparar posteriormente las cargas de CPU y memoria.

### Tarea 2.1. Crear workloads de referencia

- {% include step_label.html %} Analiza los requisitos de `idle-app` y determina cómo crear un Deployment de dos réplicas cuyo proceso permanezca prácticamente inactivo.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Conserva manifiestos locales para cada workload que construyas.
  {: .lab-note .important .compact}

  ```text
  Deployment:
  - nombre: idle-app
  - namespace: lab23
  - replicas: 2
  - imagen: busybox:1.38.0-musl
  - proceso persistente con actividad mínima
  ```

  > **Salida esperada:** Identificas una forma de mantener dos contenedores activos sin generar carga significativa.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea por tu cuenta `idle-app` y un segundo Deployment `web-app` de dos réplicas utilizando NGINX.

  > **Nota:** Ambos workloads actuarán como referencia frente a las cargas sintéticas de las siguientes tareas.
  {: .lab-note .info .compact}

  ```text
  web-app:
  - namespace: lab23
  - replicas: 2
  - imagen: nginx:1.31.4-alpine3.24-slim
  - ambos Pods Ready
  ```

  > **Salida esperada:** `idle-app` y `web-app` disponen de dos Pods Running cada uno.
  {: .lab-note .output .compact}

### Tarea 2.2. Obtener la línea base

- {% include step_label.html %} Obtén métricas de todos los Pods de `lab23` y observa las unidades utilizadas para CPU y memoria.

  > **Nota:** CPU suele mostrarse en millicores (`m`) y memoria en unidades binarias como `Mi`; los valores concretos variarán.
  {: .lab-note .info .compact}

  ```bash
  kubectl top pods -n lab23
  ```

  > **Salida esperada:** Se muestran los cuatro Pods de referencia con columnas `CPU(cores)` y `MEMORY(bytes)`; no se exige un valor numérico exacto.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el consumo de los nodos y determina si la carga de los workloads de referencia representa una fracción pequeña de los recursos disponibles.

  > **Importante:** El consumo de nodo incluye procesos del sistema y componentes de Kubernetes, no únicamente los Pods de `lab23`.
  {: .lab-note .important .compact}

  ```bash
  kubectl top nodes
  ```

  > **Salida esperada:** Se muestran métricas de CPU y memoria para los tres nodos del clúster.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🔥 Tarea 3. Reto: generar y analizar carga de CPU — 7 min

Crearás un workload intensivo en CPU con requests y limits definidos y compararás su consumo observado contra la línea base.

### Tarea 3.1. Crear carga controlada de CPU

- {% include step_label.html %} Analiza los requisitos de `cpu-load` y determina cómo mantener un proceso consumiendo CPU continuamente dentro de un contenedor limitado.

  > **Importante:** El objetivo es generar una diferencia observable, no alcanzar exactamente el valor del limit.
  {: .lab-note .important .compact}

  ```text
  Pod:
  - nombre: cpu-load
  - namespace: lab23
  - imagen: busybox:1.38.0-musl
  - debe permanecer Running
  - debe generar carga continua de CPU

  Recursos:
  - CPU request: 100m
  - CPU limit: 500m
  - memory request: 32Mi
  - memory limit: 64Mi
  ```

  > **Salida esperada:** Identificas cómo mantener un proceso intensivo de CPU con requests y limits explícitos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `cpu-load` y confirma que permanece Running antes de analizar sus métricas.

  > **Advertencia:** No utilices una carga que termine inmediatamente; Metrics Server necesita tiempo para observar el proceso.
  {: .lab-note .warning .compact}

  ```text
  Estado requerido:
  - cpu-load Running
  - request CPU 100m
  - limit CPU 500m
  ```

  > **Salida esperada:** `cpu-load` permanece ejecutándose con los recursos solicitados.
  {: .lab-note .output .compact}

### Tarea 3.2. Identificar consumo de CPU

- {% include step_label.html %} Espera una nueva muestra de métricas y consulta nuevamente los Pods del namespace.

  > **Nota:** Metrics Server recopila métricas periódicamente; una pausa breve ayuda a evitar comparar un Pod recién creado sin muestra disponible.
  {: .lab-note .info .compact}

  ```bash
  sleep 20
  kubectl top pods -n lab23
  ```

  > **Salida esperada:** `cpu-load` aparece en la tabla y presenta un consumo de CPU apreciablemente mayor que los Pods inactivos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ordena las métricas por CPU y determina cuál workload presenta el mayor consumo observado.

  > **Importante:** El valor de `100m` definido como request no significa que el contenedor consuma exactamente `100m`.
  {: .lab-note .important .compact}

  ```bash
  kubectl top pods -n lab23 --sort-by=cpu
  ```

  > **Salida esperada:** `cpu-load` aparece entre los Pods con mayor consumo de CPU y claramente por encima de `idle-app`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la configuración de recursos activa de `cpu-load` y compárala con el consumo mostrado por `kubectl top`.

  > **Nota:** Esta comparación separa capacidad solicitada y limitada de consumo efectivo en un momento determinado.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod cpu-load -n lab23 -o jsonpath='{.spec.containers[0].resources}{"\n"}'
  ```

  > **Salida esperada:** Se observan request `100m`, limit `500m`, request de memoria `32Mi` y limit `64Mi`; estos valores no tienen que coincidir con `kubectl top`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🧠 Tarea 4. Reto: generar y analizar presión de memoria — 7 min

Crearás un proceso que mantenga una cantidad observable de memoria reservada, pero sin superar su limit ni provocar OOMKilled.

### Tarea 4.1. Crear consumo controlado de memoria

- {% include step_label.html %} Analiza el escenario de `memory-load` y determina cómo reservar aproximadamente 120 MiB de memoria manteniendo el proceso activo.

  > **Importante:** A diferencia de la Práctica 17, aquí no debes provocar `OOMKilled`; el consumo debe permanecer por debajo del limit.
  {: .lab-note .important .compact}

  ```text
  Pod:
  - nombre: memory-load
  - namespace: lab23
  - imagen: python:3.13-alpine3.24
  - reservar aproximadamente 120 MiB
  - mantener la memoria asignada y el proceso Running

  Recursos:
  - memory request: 64Mi
  - memory limit: 256Mi
  - CPU request: 25m
  - CPU limit: 200m
  ```

  > **Salida esperada:** Identificas una forma de mantener memoria asignada sin superar el limit de `256Mi`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `memory-load` y confirma que permanece estable antes de recopilar métricas.

  > **Advertencia:** Si el Pod termina con OOMKilled, la carga supera lo requerido para este ejercicio y debe corregirse antes de continuar.
  {: .lab-note .warning .compact}

  ```text
  Estado requerido:
  - memory-load Running
  - sin reinicios por OOM
  - request 64Mi
  - limit 256Mi
  ```

  > **Salida esperada:** `memory-load` permanece Running sin reinicios provocados por memoria.
  {: .lab-note .output .compact}

### Tarea 4.2. Comparar consumo de memoria

- {% include step_label.html %} Espera a que exista una muestra para el nuevo Pod y consulta el consumo del namespace.

  > **Nota:** No se exige que la métrica coincida exactamente con 120 MiB, porque el proceso y el runtime consumen memoria adicional.
  {: .lab-note .info .compact}

  ```bash
  sleep 20
  kubectl top pods -n lab23
  ```

  > **Salida esperada:** `memory-load` aparece con un consumo de memoria claramente superior a los workloads de referencia y continúa Running.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ordena los Pods por memoria y determina cuál presenta el consumo más alto en la muestra actual.

  > **Importante:** Un consumo mayor no constituye automáticamente una falla; debe interpretarse frente a configuración, límites y comportamiento esperado.
  {: .lab-note .important .compact}

  ```bash
  kubectl top pods -n lab23 --sort-by=memory
  ```

  > **Salida esperada:** `memory-load` aparece entre los primeros resultados por consumo de memoria.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta requests y limits de `memory-load` y confirma que el consumo observado permanece dentro del escenario esperado.

  > **Nota:** La métrica es una observación temporal y puede variar; el objetivo es compararla con el orden de magnitud de los recursos declarados.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod memory-load -n lab23 -o jsonpath='{.spec.containers[0].resources}{"\n"}'
  ```

  > **Salida esperada:** Se muestran request de memoria `64Mi`, limit `256Mi`, request CPU `25m` y limit `200m`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧭 Tarea 5. Reto: comparar workloads y emitir un diagnóstico — 7 min

Resolverás un escenario de análisis sin que se te indique inicialmente qué workload consume más CPU o memoria. Deberás localizarlo y relacionar las métricas con la configuración declarada.

### Tarea 5.1. Investigar el consumo del namespace

- {% include step_label.html %} Obtén una vista actual del consumo de todos los Pods y determina qué workloads merecen una inspección más detallada.

  > **Importante:** Basa tu conclusión en las métricas actuales y no únicamente en los nombres de los Pods.
  {: .lab-note .important .compact}

  ```text
  El equipo informa que alguna aplicación de lab23
  consume más recursos que el resto.

  Determina:
  - cuál destaca por CPU;
  - cuál destaca por memoria.
  ```

  > **Salida esperada:** Identificas a partir de métricas que `cpu-load` destaca por CPU y `memory-load` por memoria.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ordena o filtra las métricas de CPU para respaldar con evidencia cuál Pod consume más procesador.

  > **Nota:** Puedes elegir la consulta que consideres más eficiente; el resultado debe poder justificarse con la salida de kubectl.
  {: .lab-note .info .compact}

  ```text
  Produce evidencia ordenada o filtrada
  que permita identificar el mayor consumidor de CPU.
  ```

  > **Salida esperada:** La evidencia sitúa a `cpu-load` claramente por encima de los Pods inactivos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ordena o filtra las métricas de memoria para respaldar cuál Pod mantiene la mayor cantidad de memoria observada.

  > **Nota:** Los valores exactos pueden cambiar entre muestras; utiliza comparación relativa.
  {: .lab-note .info .compact}

  ```text
  Produce evidencia ordenada o filtrada
  que permita identificar el mayor consumidor de memoria.
  ```

  > **Salida esperada:** La evidencia identifica `memory-load` como uno de los mayores consumidores de memoria del namespace.
  {: .lab-note .output .compact}

### Tarea 5.2. Correlacionar métricas con configuración

- {% include step_label.html %} Recupera requests y limits de `cpu-load` y compáralos con el consumo observado.

  > **Importante:** No interpretes el request como una cantidad que el proceso deba consumir permanentemente.
  {: .lab-note .important .compact}

  ```text
  Compara:
  - CPU observado
  - CPU request
  - CPU limit
  ```

  > **Salida esperada:** Concluyes que `100m` es request y `500m` limit, mientras la métrica representa uso observado y puede variar.
  {: .lab-note .output .compact}

- {% include step_label.html %} Recupera requests y limits de `memory-load` y determina si el consumo observado es compatible con el escenario configurado.

  > **Nota:** El objetivo es razonar sobre el consumo, no exigir que sea idéntico a la cantidad reservada por el proceso.
  {: .lab-note .info .compact}

  ```text
  Compara:
  - memoria observada
  - request 64Mi
  - limit 256Mi
  ```

  > **Salida esperada:** Concluyes que el workload consume más que la línea base pero permanece dentro del escenario esperado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Emite una conclusión final distinguiendo configuración declarada, consumo real y existencia o ausencia de un problema operativo.

  > **Importante:** Un workload que consume más recursos no está necesariamente defectuoso si ese consumo es intencional, estable y compatible con sus límites.
  {: .lab-note .important .compact}

  ```text
  Conclusión requerida:

  1. mayor consumidor de CPU;
  2. mayor consumidor de memoria;
  3. diferencia entre uso, request y limit;
  4. indicar si existe evidencia de OOMKilled,
     reinicios o inestabilidad.
  ```

  > **Salida esperada:** Identificas `cpu-load` y `memory-load` como cargas deliberadas y concluyes que el mayor consumo observado no implica por sí mismo una falla.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🧹 Tarea 6. Limpiar el entorno de la práctica — 2 min

La limpieza no forma parte de la proporción 20/80. Eliminarás únicamente los workloads de `lab23`; Metrics Server permanecerá instalado como infraestructura compartida del clúster.

### Tarea 6.1. Retirar los workloads del laboratorio

- {% include step_label.html %} Revisa una última vez Pods y Deployments antes de eliminar el namespace.

  > **Nota:** Metrics Server se encuentra en `kube-system` y no será eliminado.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods,deployments -n lab23
  ```

  > **Salida esperada:** Se muestran `idle-app`, `web-app`, `cpu-load` y `memory-load` con sus estados actuales.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab23` después de completar todas las comparaciones.

  > **Advertencia:** Después de eliminar el namespace ya no podrás consultar métricas de estos Pods.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab23 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab23" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que el namespace desapareció del clúster.

  > **Importante:** La ausencia de salida es el resultado esperado con `--ignore-not-found`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab23 --ignore-not-found
  ```

  > **Salida esperada:** No se muestra ningún namespace `lab23`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Verifica que los archivos locales permanecen disponibles para revisar los manifiestos utilizados.

  > **Nota:** La limpieza afecta al namespace, no a `workspace/lab23` ni a Metrics Server.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** Los manifiestos locales permanecen dentro de `workspace/lab23`.
  {: .lab-note .output .compact}

{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

{% include support-prompt.html task="tarea6" %}