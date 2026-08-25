---
layout: lab
title: "Práctica 21: Análisis de logs y eventos"
permalink: /lab21/lab21/
images_base: /labs/lab21/img
duration: "40 minutos"
objective:
  - Analizar logs actuales y anteriores de contenedores, interpretar eventos y condiciones de Pods, distinguir problemas de aplicación de problemas observados por Kubernetes y aplicar un flujo básico de diagnóstico mediante kubectl.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Haber completado la Práctica 20 Implementación de probes.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica utilizarás las principales fuentes de evidencia disponibles desde kubectl para analizar el comportamiento de aplicaciones. La sección guiada mostrará cómo consultar logs, describir recursos y revisar eventos. Después resolverás retos donde deberás filtrar mensajes, consultar logs por contenedor, recuperar la salida de una ejecución anterior con --previous y correlacionar estados, eventos y logs para identificar una causa raíz. La práctica prepara el terreno para una sesión posterior de troubleshooting más estructurada.
slug: lab21
lab_number: 21
final_result: >
  Al finalizar habrás consultado logs de contenedores individuales, distinguido logs actuales de logs anteriores, interpretado eventos asociados a Pods, identificado reinicios y diagnosticado fallos como ImagePullBackOff mediante evidencia proporcionada por Kubernetes. También habrás aplicado un flujo básico de observación que combina get, describe, events y logs antes de corregir un recurso.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza busybox:1.38.0-musl para generar logs controlados y nginx:1.31.4-alpine3.24-slim para escenarios de aplicación.
  - kubectl logs consulta stdout y stderr del contenedor; kubectl describe muestra estado, condiciones y eventos asociados al recurso.
  - kubectl logs --previous recupera la salida de la instancia anterior de un contenedor cuando existe una ejecución previa terminada.
  - Los eventos son recursos del namespace y permiten observar decisiones o errores reportados por componentes de Kubernetes.
  - Los primeros 6 pasos son guiados y los siguientes 14 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 30/70.
references:
  - text: Debug Running Pods
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/
  - text: Debug Pods
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
  - text: Referencia oficial de kubectl logs
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/
  - text: Referencia oficial de kubectl describe
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_describe/
  - text: Referencia oficial de kubectl events
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_events/
prev: /lab20/lab20/
next: /lab22/lab22/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y comprender logs y eventos — 8 min

Prepararás el workspace y el namespace y crearás una aplicación sencilla que genere mensajes periódicos. Después consultarás sus logs y los eventos relacionados para diferenciar qué información procede del contenedor y cuál es reportada por Kubernetes.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, confirmarás el contexto activo y prepararás un namespace aislado para todos los escenarios de observabilidad.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab21` y accede a él para almacenar los manifiestos y evidencias de esta práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab21`; los archivos locales se conservarán después de limpiar los recursos Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab21 && cd workspace/lab21
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab21`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo para asegurarte de que todas las observaciones y pruebas se realizarán sobre el clúster local del curso.

  > **Importante:** El valor esperado es `kind-ckad`. No continúes si kubectl apunta a otro contexto.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab21` para aislar los Pods, Deployments y eventos utilizados durante los ejercicios de diagnóstico.

  > **Advertencia:** Si `lab21` ya existe por una ejecución anterior, revisa primero sus recursos y eventos para evitar mezclar evidencia antigua con la práctica actual.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab21
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab21 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Explorar logs, describe y eventos

Crearás un Pod que escriba mensajes periódicos y utilizarás distintas vistas de kubectl para comprender qué información aporta cada fuente.

- {% include step_label.html %} Crea un Pod llamado `log-demo` que permanezca ejecutándose y escriba mensajes numerados en stdout cada pocos segundos.

  > **Nota:** Los logs de Kubernetes provienen de la salida estándar y de error del proceso del contenedor; este Pod genera evidencia predecible para la sección guiada.
  {: .lab-note .info .compact}

  ```bash
  kubectl run log-demo -n lab21 --image=busybox:1.38.0-musl --restart=Never --command -- sh -c 'i=1; while true; do echo "INFO ciclo=$i aplicacion=log-demo"; i=$((i+1)); sleep 3; done'
  ```

  > **Salida esperada:** Kubernetes responde `pod/log-demo created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los logs del contenedor para observar directamente los mensajes emitidos por la aplicación.

  > **Importante:** `kubectl logs` muestra lo que escribe el proceso del contenedor; no sustituye la información de estado y eventos que Kubernetes mantiene por separado.
  {: .lab-note .important .compact}

  ```bash
  kubectl logs log-demo -n lab21 --tail=5
  ```

  > **Salida esperada:** Se muestran hasta cinco líneas recientes con mensajes `INFO` y números de ciclo.
  {: .lab-note .output .compact}

- {% include step_label.html %} Describe el Pod y consulta los eventos recientes del namespace para comparar la evidencia de la aplicación con la evidencia generada por Kubernetes.

  > **Nota:** `describe` reúne estado, condiciones y eventos asociados al recurso, mientras la consulta de eventos permite revisar el historial reciente del namespace de forma más amplia.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe pod log-demo -n lab21
  ```
  ```bash
  kubectl get events -n lab21 --sort-by=.metadata.creationTimestamp
  ```

  > **Salida esperada:** `describe` muestra el estado del Pod y eventos como scheduling, pull o inicio del contenedor; la lista de eventos presenta entradas ordenadas cronológicamente.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: analizar logs de una aplicación — 7 min

A partir de esta tarea comienza la parte no guiada. Deberás construir workloads que generen evidencia útil y seleccionar por tu cuenta las opciones de kubectl adecuadas para localizar mensajes y consultar contenedores específicos.

### Tarea 2.1. Identificar mensajes relevantes

Crearás una aplicación que produzca mensajes de distintos niveles y deberás recuperar únicamente la información necesaria para reconstruir la secuencia del problema.

- {% include step_label.html %} Analiza el escenario de `api-logger` y determina cómo generar una secuencia repetitiva de mensajes INFO, WARNING y ERROR que pueda consultarse posteriormente.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl logs --help`, `kubectl explain` y técnicas ya practicadas.
  {: .lab-note .important .compact}

  ```text
  Reto de logs:

  Pod:
  - Nombre: api-logger
  - Namespace: lab21
  - Imagen: busybox:1.38.0-musl
  - Debe permanecer Running.

  Debe generar repetidamente mensajes similares a:
  - INFO request accepted
  - WARNING latency high
  - ERROR backend unavailable
  ```

  > **Salida esperada:** Identificas cómo construir un contenedor persistente que produzca una secuencia de logs útil para análisis.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `api-logger` y recupera una muestra reciente suficiente para identificar el último WARNING, el último ERROR y el orden en que ocurrieron.

  > **Nota:** Puedes utilizar opciones de `kubectl logs` y herramientas básicas de shell para reducir la salida; la estrategia concreta forma parte del reto.
  {: .lab-note .info .compact}

  ```text
  Evidencia requerida:

  - último WARNING;
  - último ERROR;
  - determinar cuál ocurrió primero en la secuencia observada.
  ```

  > **Salida esperada:** Obtienes una muestra de logs donde puedes identificar claramente los mensajes WARNING y ERROR y su orden relativo.
  {: .lab-note .output .compact}

### Tarea 2.2. Consultar logs de un Pod con múltiples contenedores

Construirás un Pod con dos contenedores que generen mensajes diferentes y demostrarás que puedes seleccionar la fuente correcta de logs.

- {% include step_label.html %} Crea por tu cuenta un Pod denominado `app-with-sidecar` con dos contenedores persistentes llamados `app` y `sidecar`, cada uno generando mensajes claramente distinguibles.

  > **Importante:** Un Pod con varios contenedores requiere identificar qué contenedor debe consultarse cuando utilizas `kubectl logs`.
  {: .lab-note .important .compact}

  ```text
  Reto multi-container:

  Pod: app-with-sidecar
  Namespace: lab21

  Container app:
  - Imagen: busybox:1.38.0-musl
  - Debe generar mensajes que incluyan APP

  Container sidecar:
  - Imagen: busybox:1.38.0-musl
  - Debe generar mensajes que incluyan SIDECAR
  ```

  > **Salida esperada:** `app-with-sidecar` queda `Running` con dos contenedores activos que producen logs distintos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Recupera por separado una muestra de los logs de `app` y otra de `sidecar` sin mezclar ambos orígenes.

  > **Advertencia:** Si kubectl solicita que especifiques un contenedor, utiliza la información disponible en el Pod para seleccionar el nombre correcto en lugar de eliminar contenedores.
  {: .lab-note .warning .compact}

  ```text
  Debes demostrar:

  - logs únicamente del contenedor app;
  - logs únicamente del contenedor sidecar.
  ```

  > **Salida esperada:** Una consulta muestra mensajes `APP` y otra consulta independiente muestra mensajes `SIDECAR`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🔁 Tarea 3. Reto: diagnosticar reinicios y recuperar logs anteriores — 9 min

Crearás un contenedor que escriba evidencia antes de terminar con error. Kubernetes lo reiniciará y deberás distinguir la salida de la ejecución actual de la ejecución anterior.

### Tarea 3.1. Generar reinicios controlados

Diseñarás un workload cuyo proceso falle después de emitir varios mensajes y que vuelva a iniciarse automáticamente.

- {% include step_label.html %} Analiza el escenario de `crash-app` y determina cómo crear un Deployment cuyo contenedor escriba mensajes, termine con código distinto de cero y vuelva a ejecutarse.

  > **Importante:** Necesitas una instancia anterior terminada para practicar `kubectl logs --previous`; no corrijas el fallo durante esta subtarea.
  {: .lab-note .important .compact}

  ```text
  Reto de reinicio:

  Deployment:
  - Nombre: crash-app
  - Namespace: lab21
  - Réplicas: 1
  - Imagen: busybox:1.38.0-musl

  El proceso debe:
  - escribir "START crash-app";
  - escribir "ERROR simulated failure";
  - esperar unos segundos;
  - terminar con código 1.
  ```

  > **Salida esperada:** Identificas cómo construir un contenedor que genere logs útiles antes de fallar y sea reiniciado por Kubernetes.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `crash-app` y observa el Pod hasta que el contador de reinicios sea mayor que cero.

  > **Advertencia:** No elimines el Pod ni el Deployment durante la observación; necesitas conservar la información de la ejecución anterior.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get pods -n lab21 -l app=crash-app
  ```

  > **Salida esperada:** El Pod asociado a `crash-app` muestra uno o más reinicios y puede encontrarse temporalmente en `CrashLoopBackOff`.
  {: .lab-note .output .compact}

### Tarea 3.2. Diferenciar ejecución actual y anterior

Consultarás estado y logs para reconstruir qué ocurrió antes del reinicio más reciente.

- {% include step_label.html %} Consulta el contador de reinicios y el estado anterior del contenedor para confirmar que existe una ejecución terminada disponible para análisis.

  > **Nota:** `containerStatuses` conserva información de la ejecución actual y, cuando corresponde, de `lastState`.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab21 -l app=crash-app -o jsonpath='{range .items[*]}{.metadata.name}{" Restarts="}{.status.containerStatuses[0].restartCount}{" LastReason="}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}'
  ```

  > **Salida esperada:** El Pod muestra `Restarts` mayor que cero y una razón de terminación anterior.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los logs de la ejecución actual del contenedor para distinguirlos de la evidencia perteneciente a una instancia anterior.

  > **Importante:** La salida actual puede corresponder a un nuevo intento de inicio y no necesariamente contiene todo lo ocurrido antes del reinicio previo.
  {: .lab-note .important .compact}

  ```bash
  kubectl logs deployment/crash-app -n lab21
  ```

  > **Salida esperada:** Se muestran mensajes pertenecientes a la ejecución actual del contenedor, como `START crash-app` y posiblemente `ERROR simulated failure`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Recupera los logs del contenedor anterior para confirmar qué mensajes quedaron registrados antes de su última terminación.

  > **Nota:** `--previous` es especialmente útil cuando el contenedor ya fue reiniciado y la evidencia necesaria pertenece a la instancia inmediatamente anterior.
  {: .lab-note .info .compact}

  ```bash
  kubectl logs deployment/crash-app -n lab21 --previous
  ```

  > **Salida esperada:** Se muestran los logs de la ejecución anterior, incluyendo `START crash-app` y `ERROR simulated failure`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🧭 Tarea 4. Reto: correlacionar eventos y determinar causa raíz — 11 min

Resolverás un escenario donde un Pod no puede iniciar correctamente. Deberás utilizar estado, eventos y disponibilidad de logs para determinar la causa y corregir el recurso sin recibir la secuencia de comandos.

### Tarea 4.1. Diagnosticar un Pod que no inicia

Crearás deliberadamente un workload con una imagen inexistente y utilizarás evidencia de Kubernetes para identificar el problema.

- {% include step_label.html %} Analiza el escenario de `broken-app` y crea por tu cuenta un Pod que utilice exactamente la imagen inexistente indicada para provocar un error de descarga.

  > **Advertencia:** El fallo es deliberado. No sustituyas todavía la imagen por una válida porque necesitas observar los estados y eventos producidos por Kubernetes.
  {: .lab-note .warning .compact}

  ```text
  Reto de causa raíz:

  Pod:
  - Nombre: broken-app
  - Namespace: lab21
  - Imagen: nginx:lab21-image-does-not-exist

  Objetivo inicial:
  - conservar el fallo el tiempo suficiente para diagnosticarlo.
  ```

  > **Salida esperada:** `broken-app` existe y no logra iniciar correctamente debido a la imagen solicitada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Determina la causa utilizando el estado y los eventos del Pod y registra mentalmente qué evidencia demuestra que el problema ocurre antes del inicio del contenedor.

  > **Importante:** Si el contenedor nunca inició, es posible que no existan logs de aplicación. En ese caso los eventos son una fuente de evidencia más útil.
  {: .lab-note .important .compact}

  ```text
  Debes determinar:

  - estado mostrado por kubectl;
  - último evento relevante;
  - razón probable;
  - si deberían existir logs de aplicación.
  ```

  > **Salida esperada:** Identificas estados como `ErrImagePull` o `ImagePullBackOff` y eventos que indican que Kubernetes no puede descargar la imagen.
  {: .lab-note .output .compact}

### Tarea 4.2. Aplicar un flujo de diagnóstico y corregir el recurso

Seguirás un orden de observación reutilizable y corregirás únicamente después de reunir evidencia suficiente.

- {% include step_label.html %} Inspecciona el estado detallado y los eventos recientes de `broken-app` para completar la evidencia antes de realizar cualquier corrección.

  > **Nota:** Un flujo útil comienza con el estado general, continúa con `describe` y eventos, y utiliza logs cuando el contenedor realmente llegó a ejecutarse.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe pod broken-app -n lab21
   ```
  ```bash
  kubectl get events -n lab21 --field-selector involvedObject.name=broken-app --sort-by=.metadata.creationTimestamp
  ```

  > **Salida esperada:** La evidencia indica errores de pull de imagen asociados a `nginx:lab21-image-does-not-exist`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba por tu cuenta si existen logs utilizables para `broken-app` y explica por qué su presencia o ausencia es coherente con el estado observado.

  > **Importante:** No todos los fallos producen logs de aplicación. Cuando la imagen no puede descargarse, el proceso del contenedor nunca llega a iniciar.
  {: .lab-note .important .compact}

  ```text
  Determina si kubectl logs puede recuperar
  evidencia útil de broken-app y relaciona
  el resultado con los eventos observados.
  ```

  > **Salida esperada:** Concluyes que el fallo ocurre antes de iniciar la aplicación y que los eventos proporcionan la evidencia principal.
  {: .lab-note .output .compact}

- {% include step_label.html %} Corrige por tu cuenta `broken-app` para utilizar `nginx:1.31.4-alpine3.24-slim` y valida que el Pod alcance estado `Running`.

  > **Advertencia:** Corrige únicamente después de haber identificado la causa raíz. El objetivo no es probar imágenes al azar, sino resolver el problema a partir de evidencia.
  {: .lab-note .warning .compact}

  ```text
  Estado final requerido:

  broken-app
  - imagen: nginx:1.31.4-alpine3.24-slim
  - Phase: Running
  - contenedor Ready
  ```

  > **Salida esperada:** `broken-app` utiliza la imagen válida y alcanza estado `Running` con su contenedor Ready.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar el entorno de la práctica — 5 min

Esta tarea no forma parte de la evaluación 30/70. Ejecútala únicamente después de terminar los retos, recuperar logs anteriores, diagnosticar `broken-app` y validar su corrección.

### Tarea 5.1. Revisar y retirar los recursos del laboratorio

Realizarás una última inspección, eliminarás el namespace y conservarás los manifiestos locales para utilizar esta práctica como referencia antes del laboratorio de troubleshooting.

- {% include step_label.html %} Revisa una última vez los Pods y Deployments existentes para confirmar que terminaste todas las observaciones y diagnósticos.

  > **Nota:** Debes haber finalizado especialmente el análisis de `crash-app` y la corrección de `broken-app` antes de continuar.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods,deployments -n lab21
  ```

  > **Salida esperada:** Se muestran los workloads utilizados durante la práctica y sus estados actuales.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab21` únicamente cuando ya no necesites consultar logs, estados o eventos de los recursos del laboratorio.

  > **Advertencia:** La eliminación del namespace destruye los Pods y la evidencia asociada que todavía pueda ser útil para diagnóstico.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab21 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab21" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace ya no existe para confirmar que la limpieza de recursos Kubernetes terminó correctamente.

  > **Importante:** La ausencia de salida es el resultado esperado debido al uso de `--ignore-not-found`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab21 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab21`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los archivos creados durante la práctica permanecen disponibles dentro del workspace para repasar posteriormente el flujo de diagnóstico.

  > **Nota:** La limpieza afecta únicamente al clúster; conserva `workspace/lab21` como material de estudio.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio continúa mostrando los manifiestos y archivos locales creados durante los retos.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}