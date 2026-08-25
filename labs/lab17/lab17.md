---
layout: lab
title: "Práctica 17: Control de recursos de aplicaciones"
permalink: /lab17/lab17/
images_base: /labs/lab17/img
duration: "55 minutos"
objective:
  - Configurar requests y limits de CPU y memoria, interpretar su efecto sobre scheduling y ejecución, diagnosticar un contenedor terminado por OOMKilled y ajustar recursos para obtener clases QoS BestEffort, Burstable y Guaranteed.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica controlarás los recursos de aplicaciones mediante requests y limits. La sección guiada establece la relación entre recursos solicitados, límites y clases QoS. Después resolverás escenarios donde deberás dimensionar una aplicación, someter un contenedor a presión de CPU, provocar de forma controlada un OOMKilled por memoria y corregir una configuración hasta obtener la clase QoS requerida. La mayor parte de la práctica se desarrolla como reto y los comandos de implementación no se proporcionan.
slug: lab17
lab_number: 17
final_result: >
  Al finalizar habrás configurado requests y limits de CPU y memoria, validado recursos declarados en Pods, comprobado que un proceso intensivo de CPU puede continuar ejecutándose bajo un límite, diagnosticado un OOMKilled provocado por superar un límite de memoria y ajustado una aplicación para obtener una clase QoS Guaranteed. También habrás diferenciado BestEffort, Burstable y Guaranteed a partir de la configuración efectiva de recursos.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - La práctica no depende de Metrics Server; las validaciones utilizan especificaciones, estados de Pods y datos reportados por Kubernetes.
  - Los requests influyen en las decisiones de scheduling y los limits restringen el consumo máximo permitido para el contenedor.
  - Exceder un límite de CPU no implica normalmente terminar el contenedor; el consumo puede ser restringido. Superar un límite de memoria puede terminar el proceso y reportar OOMKilled.
  - Kubernetes clasifica los Pods en BestEffort, Burstable o Guaranteed según los requests y limits configurados en sus contenedores.
  - Se utiliza busybox:1.38.0-musl para pruebas ligeras y python:3.13-alpine3.24 para provocar de forma controlada presión de memoria.
  - Los primeros 6 pasos son guiados y los siguientes 14 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 30/70.
references:
  - text: Resource Management for Pods and Containers
    url: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
  - text: Pod Quality of Service Classes
    url: https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/
  - text: Assign CPU Resources to Containers and Pods
    url: https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/
  - text: Assign Memory Resources to Containers and Pods
    url: https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/
prev: /lab16/lab16/
next: /lab18/lab18/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y comprender requests, limits y QoS — 11 min

Prepararás el workspace y el namespace de la práctica y revisarás los campos que Kubernetes utiliza para expresar solicitudes y límites de recursos. Esta base guiada permitirá resolver posteriormente escenarios de dimensionamiento y diagnóstico sin recibir los comandos de implementación.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, confirmarás el contexto activo y prepararás un namespace aislado para todos los workloads utilizados en las pruebas de CPU, memoria y QoS.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab17` y accede a él para mantener separados los manifiestos y evidencias de esta práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab17`; los archivos locales se conservarán después de limpiar los recursos Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab17 && cd workspace/lab17
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab17`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo para asegurarte de que todas las pruebas de recursos se ejecutarán sobre el clúster local del curso.

  > **Importante:** El contexto esperado es `kind-ckad`. Un contexto diferente podría crear workloads con consumo de recursos en otro clúster.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab17` para aislar las pruebas y poder retirarlas posteriormente mediante una única operación de limpieza.

  > **Advertencia:** Si `lab17` ya existe por una ejecución anterior, revisa y elimina workloads residuales antes de continuar para no alterar las observaciones de reinicios o QoS.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab17
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab17 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Explorar recursos y clases QoS

Revisarás los campos donde se configuran requests y limits y crearás un Pod sencillo para observar cómo Kubernetes deriva automáticamente su clase QoS.

- {% include step_label.html %} Consulta la estructura de recursos de un contenedor para localizar los campos `requests` y `limits` donde se expresan CPU y memoria.

  > **Nota:** Los requests representan recursos solicitados por el contenedor y son relevantes para scheduling; los limits establecen límites máximos que el runtime debe aplicar.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain pod.spec.containers.resources --recursive
  ```

  > **Salida esperada:** La salida incluye `limits` y `requests` y permite identificar recursos como `cpu` y `memory`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea un Pod sin requests ni limits para disponer de un ejemplo mínimo cuya clase QoS pueda observarse directamente.

  > **Importante:** Un Pod cuyos contenedores no especifican requests ni limits de CPU o memoria se clasifica normalmente como `BestEffort`.
  {: .lab-note .important .compact}

  ```bash
  kubectl run qos-demo -n lab17 --image=busybox:1.38.0-musl --restart=Never --command -- sh -c 'sleep 3600'
  ```

  > **Salida esperada:** Kubernetes responde `pod/qos-demo created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la clase QoS asignada al Pod para relacionar la ausencia de requests y limits con la clasificación realizada por Kubernetes.

  > **Nota:** Kubernetes calcula `status.qosClass` a partir de la configuración de recursos de todos los contenedores del Pod.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod qos-demo -n lab17 -o jsonpath='{.status.qosClass}{"\n"}'
  ```

  > **Salida esperada:** El comando devuelve `BestEffort`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: dimensionar recursos de una aplicación — 11 min

A partir de esta tarea comienza la parte no guiada. Deberás configurar una aplicación con recursos específicos y demostrar que los valores declarados realmente llegaron hasta los contenedores creados por Kubernetes.

### Tarea 2.1. Definir requests y limits

Interpretarás el dimensionamiento solicitado y decidirás cómo construir un Deployment que mantenga separados los recursos solicitados de los límites máximos permitidos.

- {% include step_label.html %} Analiza los requisitos de `api` y determina cómo deben expresarse los recursos de cada contenedor dentro del Pod template.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl explain`, `kubectl --help` y generación declarativa como apoyo.
  {: .lab-note .important .compact}

  ```text
  Reto de dimensionamiento:

  Deployment:
  - Nombre: api
  - Namespace: lab17
  - Réplicas: 2
  - Imagen: busybox:1.38.0-musl
  - El contenedor debe permanecer ejecutándose.

  Recursos por contenedor:
  - CPU request: 100m
  - CPU limit: 300m
  - Memory request: 64Mi
  - Memory limit: 128Mi
  ```

  > **Salida esperada:** Identificas que los cuatro valores deben configurarse en `resources.requests` y `resources.limits` dentro del contenedor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta el Deployment `api` y espera hasta que sus dos réplicas estén disponibles.

  > **Advertencia:** No continúes únicamente porque el Deployment exista; ambos Pods deben estar Ready y utilizar exactamente los recursos solicitados.
  {: .lab-note .warning .compact}

  ```text
  Implementa ahora la solución.

  Antes de continuar verifica por tu cuenta:
  - api existe;
  - replicas = 2;
  - ambos Pods Ready;
  - requests y limits configurados.
  ```

  > **Salida esperada:** `deployment/api` alcanza dos réplicas disponibles con la configuración de recursos solicitada.
  {: .lab-note .output .compact}

### Tarea 2.2. Validar recursos declarados

Comprobarás directamente el Pod template y la clase QoS para demostrar que el estado final coincide con el requerimiento y comprender cómo Kubernetes clasifica esta configuración.

- {% include step_label.html %} Consulta los recursos declarados en el primer contenedor del Deployment para verificar CPU y memoria sin depender únicamente del manifiesto local.

  > **Nota:** Consultar el objeto almacenado en Kubernetes confirma la configuración efectiva que está utilizando el controlador.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployment api -n lab17 -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
  ```

  > **Salida esperada:** La salida contiene requests de `100m` y `64Mi`, y limits de `300m` y `128Mi`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la clase QoS de uno de los Pods de `api` para relacionar requests menores que limits con una clasificación diferente a Guaranteed.

  > **Importante:** Al existir requests y limits, pero no ser iguales para CPU y memoria, el Pod debe quedar clasificado como `Burstable`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n lab17 -l app=api -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.status.qosClass}{"\n"}{end}'
  ```

  > **Salida esperada:** Los Pods de `api` muestran la clase QoS `Burstable`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## ⚙️ Tarea 3. Reto: analizar presión de CPU y memoria — 13 min

Construirás dos workloads de prueba. El primero mantendrá un proceso intensivo de CPU bajo un límite configurado y el segundo superará deliberadamente su límite de memoria para observar un `OOMKilled`.

### Tarea 3.1. Analizar un contenedor limitado por CPU

Crearás un Pod que intente consumir CPU continuamente y comprobarás que superar la capacidad asignada no implica necesariamente que Kubernetes termine el contenedor.

- {% include step_label.html %} Analiza el escenario de CPU y determina cómo crear un Pod persistente que ejecute trabajo intensivo sin superar el límite configurado por el runtime.

  > **Importante:** El objetivo no es medir un porcentaje exacto de throttling. Debes comprobar que el proceso continúa ejecutándose mientras existe un límite de CPU explícito.
  {: .lab-note .important .compact}

  ```text
  Reto CPU:

  Pod:
  - Nombre: cpu-burner
  - Namespace: lab17
  - Imagen: busybox:1.38.0-musl
  - Debe ejecutar un ciclo intensivo de CPU.

  Recursos:
  - CPU request: 100m
  - CPU limit: 200m
  - Memory request: 16Mi
  - Memory limit: 32Mi
  ```

  > **Salida esperada:** Identificas cómo crear un Pod con un proceso intensivo y límites explícitos de CPU y memoria.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `cpu-burner` y confirma posteriormente que permanece `Running` en lugar de terminar por intentar consumir más CPU.

  > **Nota:** Los límites de CPU se aplican restringiendo el tiempo de CPU disponible para el contenedor; este comportamiento es diferente a exceder un límite duro de memoria.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod cpu-burner -n lab17
  ```

  > **Salida esperada:** Después de iniciar correctamente, `cpu-burner` permanece en estado `Running`.
  {: .lab-note .output .compact}

### Tarea 3.2. Provocar y diagnosticar presión de memoria

Crearás un workload que intente reservar más memoria de la permitida y utilizarás el estado previo del contenedor para identificar la causa de terminación.

- {% include step_label.html %} Analiza el escenario de memoria y determina cómo construir un Deployment cuyo proceso intente reservar aproximadamente 128 MiB con un límite de solo 64 MiB.

  > **Advertencia:** Esta prueba está diseñada deliberadamente para provocar terminaciones y reinicios. Utiliza únicamente el namespace del laboratorio y no reutilices este patrón en workloads reales.
  {: .lab-note .warning .compact}

  ```text
  Reto de memoria:

  Deployment:
  - Nombre: memory-hog
  - Namespace: lab17
  - Réplicas: 1
  - Imagen: python:3.13-alpine3.24

  El proceso debe intentar reservar:
  - aproximadamente 128 MiB

  Recursos:
  - Memory request: 32Mi
  - Memory limit: 64Mi
  - CPU request: 50m
  - CPU limit: 200m
  ```

  > **Salida esperada:** Identificas que el proceso debe intentar superar deliberadamente el límite de memoria para generar evidencia de terminación.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `memory-hog` y observa sus reinicios hasta que Kubernetes registre al menos una terminación del contenedor.

  > **Importante:** No corrijas todavía el límite. Necesitas conservar el comportamiento defectuoso para analizar la razón de la terminación anterior.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n lab17 -l app=memory-hog
  ```

  > **Salida esperada:** El Pod muestra uno o más reinicios y puede alternar entre estados de ejecución y reinicio según el momento de la consulta.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la razón de la última terminación del contenedor para confirmar que el proceso fue finalizado por exceder el límite de memoria.

  > **Nota:** `lastState.terminated.reason` conserva información de la terminación previa incluso después de que el contenedor haya sido reiniciado por el Deployment.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab17 -l app=memory-hog -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}'
  ```

  > **Salida esperada:** La razón mostrada es `OOMKilled`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🛡️ Tarea 4. Reto: corregir recursos y validar QoS — 14 min

Corregirás el workload con problemas de memoria y después construirás una aplicación crítica cuya configuración de CPU y memoria produzca intencionalmente una clase QoS `Guaranteed`.

### Tarea 4.1. Corregir el workload con OOMKilled

Modificarás el dimensionamiento de `memory-hog` para evitar que el proceso vuelva a superar el límite definido y comprobarás que el nuevo Pod deja de reiniciarse por memoria.

- {% include step_label.html %} Analiza la corrección requerida y determina qué valores deben modificarse para que el proceso de aproximadamente 128 MiB pueda ejecutarse con margen suficiente.

  > **Importante:** La solución debe conservar el Deployment y ajustar su estado deseado; no resuelvas el incidente eliminando permanentemente el workload.
  {: .lab-note .important .compact}

  ```text
  Corrección requerida para memory-hog:

  Memory request: 128Mi
  Memory limit: 256Mi

  Conserva:
  - CPU request: 50m
  - CPU limit: 200m
  - misma imagen;
  - mismo Deployment;
  - mismo proceso.
  ```

  > **Salida esperada:** Identificas que la corrección debe realizarse en los recursos del Pod template del Deployment.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta la corrección y espera a que el nuevo Pod permanezca estable antes de continuar.

  > **Advertencia:** Verifica el Pod nuevo, no una instancia anterior que esté terminando durante el rollout.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get pods -n lab17 -l app=memory-hog
  ```

  > **Salida esperada:** El Pod nuevo alcanza estado `Running` y permanece estable sin incrementar continuamente su contador de reinicios por OOM.
  {: .lab-note .output .compact}

### Tarea 4.2. Construir y demostrar una aplicación Guaranteed

Resolverás un último escenario donde requests y limits deben configurarse de forma que Kubernetes asigne explícitamente la clase QoS `Guaranteed`.

- {% include step_label.html %} Analiza los requisitos de `critical-api` y determina qué relación debe existir entre requests y limits de CPU y memoria para obtener la clase QoS solicitada.

  > **Importante:** Para un Pod `Guaranteed`, cada contenedor debe tener request y limit de CPU y memoria mayores que cero, y cada request debe ser igual a su limit correspondiente.
  {: .lab-note .important .compact}

  ```text
  Reto final:

  Pod:
  - Nombre: critical-api
  - Namespace: lab17
  - Imagen: busybox:1.38.0-musl
  - Debe permanecer Running.

  Recursos requeridos:
  - CPU: 200m
  - Memory: 128Mi

  Objetivo:
  - QoS = Guaranteed
  ```

  > **Salida esperada:** Identificas que CPU request y limit deben ser `200m`, y memory request y limit deben ser `128Mi`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `critical-api` y asegúrate de que el Pod quede en estado `Running` con los recursos solicitados.

  > **Nota:** No basta con configurar únicamente limits; debes cumplir todas las condiciones necesarias para que Kubernetes derive la clase `Guaranteed`.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod critical-api -n lab17
  ```

  > **Salida esperada:** `critical-api` aparece en estado `Running`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la clase QoS final y confirma que Kubernetes clasificó el Pod como `Guaranteed`.

  > **Advertencia:** Si aparece `Burstable`, revisa que requests y limits estén definidos para CPU y memoria y sean exactamente iguales.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get pod critical-api -n lab17 -o jsonpath='{.status.qosClass}{"\n"}'
  ```

  > **Salida esperada:** El comando devuelve `Guaranteed`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar el entorno de la práctica — 6 min

Esta tarea no forma parte de la evaluación 30/70. Debes ejecutarla únicamente cuando hayas terminado los retos, diagnosticado el `OOMKilled`, corregido el workload y comprobado las clases QoS solicitadas.

### Tarea 5.1. Revisar y retirar los recursos del laboratorio

Realizarás una última inspección de los workloads, eliminarás el namespace completo y confirmarás que los recursos Kubernetes desaparecieron mientras los manifiestos locales permanecen disponibles.

- {% include step_label.html %} Revisa una última vez los Deployments y Pods existentes para confirmar que terminaste todas las pruebas de recursos antes de destruir el escenario.

  > **Nota:** Esta revisión permite comprobar que `api`, `cpu-burner`, `memory-hog` y `critical-api` ya fueron analizados antes de la limpieza.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployments,pods -n lab17
  ```

  > **Salida esperada:** Se muestran los workloads utilizados durante la práctica y sus estados actuales.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab17` únicamente después de terminar todas las validaciones y observaciones de CPU, memoria y QoS.

  > **Advertencia:** No ejecutes este paso antes de completar los retos. La eliminación del namespace destruye también la evidencia de reinicios y terminaciones utilizada para diagnosticar `OOMKilled`.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab17 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab17" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que `lab17` ya no existe para confirmar que la limpieza de recursos Kubernetes terminó correctamente.

  > **Importante:** La ausencia de salida es el resultado esperado debido al uso de `--ignore-not-found`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab17 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab17`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los archivos creados durante los retos permanecen disponibles en el workspace para revisar posteriormente tus soluciones.

  > **Nota:** La limpieza debe afectar únicamente al clúster; conserva `workspace/lab17` como material de estudio.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio continúa mostrando los manifiestos y archivos locales creados durante la práctica.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}