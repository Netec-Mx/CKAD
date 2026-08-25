---
layout: lab
title: "Práctica 8: Despliegue de aplicación con Deployment"
permalink: /lab8/lab8/
images_base: /labs/lab8/img
duration: "45 minutos"
objective:
  - Crear y administrar una aplicación mediante Deployment, comprendiendo la relación entre Deployment, ReplicaSet y Pods, practicando escalado, reconciliación del estado deseado y actualizaciones RollingUpdate, y resolviendo un reto final sin comandos de implementación.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 3 Construcción y ejecución de una aplicación en Pod.
  - Haber completado la Práctica 7 Personalización con Kustomize.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica evolucionarás desde la ejecución de Pods individuales hacia la administración declarativa de aplicaciones mediante Deployment. Crearás un Deployment desde YAML, observarás el ReplicaSet y los Pods que controla, modificarás el número de réplicas, comprobarás la reconciliación automática cuando desaparece un Pod y ejecutarás una actualización RollingUpdate. La práctica finaliza con un reto de consolidación en el que deberás crear y validar un segundo Deployment sin recibir los comandos de implementación.
slug: lab8
lab_number: 8
final_result: >
  Al finalizar habrás creado y administrado un Deployment Kubernetes con múltiples réplicas, identificado el ReplicaSet responsable de sus Pods, escalado el workload, comprobado la recuperación automática del estado deseado después de eliminar un Pod y realizado una actualización controlada de la imagen mediante RollingUpdate. También habrás resuelto un reto parcialmente guiado en el que construirás un segundo Deployment a partir de requisitos y criterios de validación sin recibir los comandos de solución.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - La imagen utilizada es nginx:1.31.4-alpine3.24-slim, con tag explícito para mantener reproducibilidad.
  - Cada paso contiene una única acción principal; no se encadenan operaciones de creación, validación y eliminación en un mismo comando.
  - Las Tareas 1 a 4 son guiadas y representan 26 de los 32 pasos. La Tarea 5 contiene 6 pasos de reto y representa el 20 por ciento de la práctica.
references:
  - text: Deployments en Kubernetes
    url: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
  - text: ReplicaSets en Kubernetes
    url: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/
  - text: Referencia oficial de kubectl create deployment
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_deployment/
  - text: Referencia oficial de kubectl rollout
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/
  - text: Imagen oficial de NGINX
    url: https://hub.docker.com/_/nginx
prev: /lab7/lab7/
next: /lab9/lab9/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y comprender el recurso Deployment — 7 min

Prepararás el workspace y el namespace de la práctica, validarás que kubectl utiliza el clúster correcto y consultarás directamente el esquema de Kubernetes para reconocer los campos fundamentales que relacionan Deployment, ReplicaSet y Pods.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local de la práctica, comprobarás el contexto activo y prepararás un namespace independiente antes de crear workloads administrados.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab8` y accede a él; permanecerás en `ckad-labs/workspace/lab8` durante el resto de la práctica.

  > **Nota:** Los manifiestos creados en este workspace permanecen únicamente en la estación local y pueden conservarse como material de repaso.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab8 && cd workspace/lab8
  ```

  > **Salida esperada:** La terminal queda ubicada dentro de `ckad-labs/workspace/lab8`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo antes de crear recursos para confirmar que los siguientes comandos se enviarán al clúster local del curso.

  > **Importante:** El contexto esperado es `kind-ckad`. Si aparece otro valor, corrige el contexto antes de continuar.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab8` para aislar todos los recursos Kubernetes que utilizarás durante esta práctica.

  > **Advertencia:** Si el namespace ya existe por una ejecución anterior, revisa primero su contenido para evitar mezclar recursos antiguos con el ejercicio actual.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab8
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab8 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Explorar la estructura del Deployment

Utilizarás las capacidades de descubrimiento de kubectl para reconocer el recurso Deployment y revisar los campos responsables de réplicas, selectores y plantilla de Pods.

- {% include step_label.html %} Consulta la entrada del recurso Deployment en la API para identificar su grupo, versión, alcance y nombre corto.

  > **Nota:** Los Deployments pertenecen al grupo de API `apps` y son recursos namespaced.
  {: .lab-note .info .compact}

  ```bash
  kubectl api-resources | grep '^deployments'
  ```

  > **Salida esperada:** Se muestra `deployments`, su nombre corto `deploy`, la versión `apps/v1`, alcance namespaced y kind `Deployment`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el campo `spec.replicas` para relacionar el número deseado de Pods con la configuración declarada en un Deployment.

  > **Importante:** El controlador intenta mantener el número de réplicas indicado en `spec.replicas`; esa reconciliación se comprobará posteriormente.
  {: .lab-note .important .compact}

  ```bash
  kubectl explain deployment.spec.replicas
  ```

  > **Salida esperada:** kubectl muestra la descripción y tipo del campo `replicas`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta de forma recursiva la estructura de `spec` para localizar `selector`, `template` y `strategy` antes de construir el manifiesto.

  > **Nota:** En `apps/v1`, el selector del Deployment debe coincidir con los labels definidos dentro de la plantilla de Pods.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain deployment.spec --recursive | head -n 45
  ```

  > **Salida esperada:** Se muestran campos como `replicas`, `selector`, `strategy` y `template` dentro de la especificación.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🧱 Tarea 2. Crear y desplegar la aplicación — 9 min

Generarás una definición inicial de Deployment con kubectl, revisarás y complementarás el manifiesto desde Visual Studio Code y posteriormente crearás el workload declarativamente para observar los objetos que Kubernetes genera y administra.

### Tarea 2.1. Generar y completar el manifiesto

Utilizarás `--dry-run=client` para obtener una definición base y después ajustarás réplicas, labels y puerto sin escribir manualmente toda la estructura desde cero.

- {% include step_label.html %} Genera el manifiesto `deployment.yaml` para un Deployment denominado `web` utilizando la imagen NGINX indicada, sin crear todavía ningún recurso en el clúster.

  > **Nota:** Generar YAML mediante kubectl permite ahorrar tiempo y reduce errores de estructura durante actividades prácticas.
  {: .lab-note .info .compact}

  ```bash
  kubectl create deployment web --image=nginx:1.31.4-alpine3.24-slim --replicas=3 -n lab8 --dry-run=client -o yaml > deployment.yaml
  ```

  > **Salida esperada:** Se crea localmente `deployment.yaml` y no aparece todavía ningún Deployment `web` en el clúster.
  {: .lab-note .output .compact}

- {% include step_label.html %} Abre `deployment.yaml` en Visual Studio Code para revisar la definición generada antes de aplicarla.

  > **Importante:** Comprueba especialmente que `spec.selector.matchLabels` coincide con `spec.template.metadata.labels`.
  {: .lab-note .important .compact}

  ```bash
  code deployment.yaml
  ```

  > **Salida esperada:** Visual Studio Code abre el archivo `deployment.yaml` almacenado en `workspace/lab8`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega manualmente `containerPort: 80` dentro del contenedor y valida el archivo contra el API Server sin persistir el recurso.

  > **Advertencia:** `containerPort` debe quedar dentro del elemento del contenedor. Una indentación incorrecta puede provocar un error de validación.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply --dry-run=server -f deployment.yaml
  ```

  > **Salida esperada:** Kubernetes responde con un resultado equivalente a `deployment.apps/web created (server dry run)`.
  {: .lab-note .output .compact}

### Tarea 2.2. Crear e inspeccionar la jerarquía de recursos

Aplicarás el manifiesto y revisarás cada nivel de la relación Deployment → ReplicaSet → Pods mediante comandos independientes.

- {% include step_label.html %} Crea el Deployment utilizando el manifiesto previamente validado.

  > **Importante:** `kubectl apply` registra el estado deseado del Deployment; el controlador será responsable de crear los objetos subordinados.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f deployment.yaml
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/web created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que el Deployment alcance disponibilidad antes de continuar con la inspección de sus recursos administrados.

  > **Nota:** `rollout status` observa el progreso del Deployment sin requerir tiempos arbitrarios de espera.
  {: .lab-note .info .compact}

  ```bash
  kubectl rollout status deployment/web -n lab8 --timeout=60s
  ```

  > **Salida esperada:** kubectl informa que el Deployment `web` completó satisfactoriamente su rollout.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta Deployment, ReplicaSet y Pods para reconocer la jerarquía generada a partir del único manifiesto aplicado.

  > **Nota:** El Deployment administra ReplicaSets y estos mantienen el conjunto de Pods requerido por el estado deseado.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployment,replicaset,pods -n lab8
  ```

  > **Salida esperada:** Se muestra `deployment.apps/web`, un ReplicaSet asociado y tres Pods en estado `Running`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 📈 Tarea 3. Escalar y comprobar la reconciliación — 8 min

Modificarás el número deseado de réplicas y observarás cómo el controlador ajusta automáticamente la cantidad de Pods. Después eliminarás deliberadamente un Pod y comprobarás que el ReplicaSet crea un reemplazo para recuperar el estado deseado.

### Tarea 3.1. Escalar el Deployment

Consultarás primero el estado actual, modificarás únicamente el número de réplicas y verificarás por separado el resultado del escalado.

- {% include step_label.html %} Consulta el número deseado, actual y disponible de réplicas antes de realizar cualquier modificación.

  > **Nota:** Registrar el estado previo permite comparar claramente el efecto que produce una operación de escalado.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployment web -n lab8
  ```

  > **Salida esperada:** El Deployment muestra tres réplicas deseadas y, después del rollout inicial, tres réplicas disponibles.
  {: .lab-note .output .compact}

- {% include step_label.html %} Escala el Deployment `web` de tres a cuatro réplicas utilizando el subcomando especializado de kubectl.

  > **Importante:** `kubectl scale` modifica el tamaño deseado del Deployment; no necesitas crear manualmente un cuarto Pod.
  {: .lab-note .important .compact}

  ```bash
  kubectl scale deployment/web -n lab8 --replicas=4
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/web scaled`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que Kubernetes creó la réplica adicional y que los cuatro Pods se encuentran disponibles.

  > **Nota:** Los nombres de los Pods incluyen un hash del ReplicaSet y un sufijo generado automáticamente.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab8 -l app=web
  ```

  > **Salida esperada:** Se muestran cuatro Pods administrados por el Deployment y todos terminan alcanzando estado `Running`.
  {: .lab-note .output .compact}

### Tarea 3.2. Comprobar la recuperación automática de Pods

Identificarás uno de los Pods existentes, lo eliminarás deliberadamente y observarás cómo el controlador recupera el número deseado sin intervención manual.

- {% include step_label.html %} Obtén los nombres actuales de los Pods administrados por `web` y selecciona uno para utilizarlo en la prueba de reconciliación.

  > **Nota:** Anota uno de los nombres mostrados; en el siguiente paso lo utilizarás para eliminar únicamente esa réplica.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab8 -l app=web
  ```

  > **Salida esperada:** Se muestran cuatro nombres de Pod pertenecientes al Deployment `web`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina uno de los Pods utilizando el nombre que identificaste en el paso anterior, sin modificar el Deployment ni el ReplicaSet.

  > **Advertencia:** Sustituye `<NOMBRE_DEL_POD>` por un Pod perteneciente exclusivamente a `web`. No elimines el Deployment.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete pod <NOMBRE_DEL_POD> -n lab8
  ```

  > **Salida esperada:** Kubernetes confirma la eliminación del Pod seleccionado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta nuevamente los Pods y verifica que aparece una nueva réplica para recuperar el total deseado de cuatro.

  > **Importante:** El nuevo Pod es consecuencia de la reconciliación realizada por el ReplicaSet; no fue creado manualmente.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n lab8 -l app=web
  ```

  > **Salida esperada:** El conjunto vuelve a contener cuatro Pods; uno de los nombres es diferente al observado antes de la eliminación.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🔄 Tarea 4. Actualizar la aplicación mediante RollingUpdate — 12 min

Modificarás la plantilla del Deployment para provocar una nueva revisión, observarás el rollout de forma independiente y analizarás los ReplicaSets resultantes para comprender cómo Kubernetes reemplaza progresivamente los Pods de una versión anterior.

### Tarea 4.1. Ejecutar una actualización de imagen

Consultarás la imagen actual, aplicarás un cambio controlado sobre la plantilla y esperarás por separado a que Kubernetes complete la actualización.

- {% include step_label.html %} Consulta la imagen actualmente declarada en el Deployment antes de iniciar la actualización.

  > **Nota:** Verificar el valor actual evita cambiar accidentalmente un contenedor distinto cuando un workload contiene varias imágenes.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployment web -n lab8 -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `nginx:1.31.4-alpine3.24-slim`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Actualiza la imagen del contenedor `nginx` utilizando un tag diferente de la misma imagen oficial para provocar una nueva revisión del Deployment.

  > **Importante:** Cambiar la plantilla de Pods provoca un nuevo rollout. En esta práctica utilizarás `nginx:1.31.4-alpine3.24`, también perteneciente a la misma versión explícita de NGINX.
  {: .lab-note .important .compact}

  ```bash
  kubectl set image deployment/web nginx=nginx:1.31.4-alpine3.24 -n lab8
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/web image updated`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que el RollingUpdate finalice antes de analizar la nueva revisión.

  > **Advertencia:** Si el rollout excede el timeout, no elimines el Deployment; utiliza `kubectl describe` y los eventos para investigar el problema.
  {: .lab-note .warning .compact}

  ```bash
  kubectl rollout status deployment/web -n lab8 --timeout=60s
  ```

  > **Salida esperada:** kubectl informa que `deployment "web" successfully rolled out`.
  {: .lab-note .output .compact}

### Tarea 4.2. Inspeccionar la revisión resultante

Revisarás ReplicaSets, historial e imagen activa mediante operaciones separadas para distinguir claramente qué evidencia aporta cada comando.

- {% include step_label.html %} Consulta los ReplicaSets del namespace para identificar la revisión anterior y la nueva revisión creada por el cambio de imagen.

  > **Nota:** Los ReplicaSets anteriores suelen conservarse con cero réplicas para mantener historial de revisiones y permitir operaciones posteriores de rollback.
  {: .lab-note .info .compact}

  ```bash
  kubectl get replicasets -n lab8
  ```

  > **Salida esperada:** Se observan al menos dos ReplicaSets asociados con `web`; uno mantiene las réplicas activas y el anterior permanece con cero réplicas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el historial de rollout del Deployment para comprobar que Kubernetes registra las revisiones producidas por cambios en la plantilla.

  > **Importante:** El historial pertenece al Deployment y se conserva mediante sus ReplicaSets anteriores mientras no sean eliminados por la política de historial.
  {: .lab-note .important .compact}

  ```bash
  kubectl rollout history deployment/web -n lab8
  ```

  > **Salida esperada:** Se muestran al menos dos números de revisión para `deployment.apps/web`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Verifica la imagen actualmente utilizada por los Pods después de completar el RollingUpdate.

  > **Nota:** Esta consulta inspecciona el estado real de los Pods y permite confirmar que ya utilizan la nueva variante de imagen.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab8 -l app=web -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.containers[0].image}{"\n"}{end}'
  ```

  > **Salida esperada:** Los cuatro Pods muestran `nginx:1.31.4-alpine3.24`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🎯 Tarea 5. Reto de consolidación con Deployment — 9 min

Resolverás un segundo escenario utilizando lo aprendido durante las tareas guiadas. Los pasos mantienen la secuencia visual del laboratorio, pero no proporcionan los comandos de implementación: deberás decidir cómo construir, corregir y validar el Deployment solicitado.

### Tarea 5.1. Construir el Deployment del reto

Analizarás los requisitos, implementarás la solución utilizando los recursos que consideres adecuados y después ejecutarás únicamente las validaciones proporcionadas.

- {% include step_label.html %} Analiza el escenario del reto y determina qué propiedades debes configurar para satisfacer todos los requisitos sin modificar el Deployment `web` existente.

  > **Importante:** A partir de este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl --help`, `kubectl explain` y generación de YAML mediante `--dry-run=client`.
  {: .lab-note .important .compact}

  ```text
  Escenario:

  El equipo de API necesita un segundo Deployment dentro de lab8.

  Requisitos:
  - Deployment: api
  - Réplicas: 2
  - Imagen: nginx:1.31.4-alpine3.24-slim
  - Label de los Pods: app=api
  - Contenedor: nginx
  - containerPort: 80
  - Los dos Pods deben terminar Ready.
  ```

  > **Salida esperada:** Identificas los campos y recursos necesarios para construir la solución sin alterar `deployment/web`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta el Deployment `api`, utilizando un manifiesto o comandos de generación según prefieras.

  > **Nota:** No se evalúa el método utilizado para construir la solución; se evalúa el estado final almacenado en Kubernetes.
  {: .lab-note .info .compact}

  ```text
  Construye la solución ahora.

  No continúes con el siguiente paso hasta considerar
  satisfechos todos los requisitos del escenario.
  ```

  > **Salida esperada:** Existe un Deployment denominado `api` dentro de `lab8` y su configuración pretende cumplir todos los requisitos solicitados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta la primera validación del reto y corrige por tu cuenta cualquier requisito que no coincida con el estado solicitado.

  > **Advertencia:** Un Deployment existente no implica que la solución sea correcta; revisa también réplicas, labels, imagen y disponibilidad.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get deployment api -n lab8 -o wide
  ```

  > **Salida esperada:** `api` aparece con dos réplicas deseadas y dos réplicas disponibles.
  {: .lab-note .output .compact}

### Tarea 5.2. Validar reconciliación y estado final

Comprobarás que el Deployment creado realmente administra sus Pods, provocarás una pérdida de una réplica y evaluarás si Kubernetes recupera automáticamente el estado deseado antes de realizar la limpieza final.

- {% include step_label.html %} Valida que los Pods del reto pueden localizarse mediante `app=api` y selecciona uno de sus nombres para la prueba de recuperación.

  > **Nota:** Este comando es únicamente de evaluación; si no aparecen exactamente dos Pods, deberás corregir tu implementación antes de continuar.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab8 -l app=api
  ```

  > **Salida esperada:** Se muestran exactamente dos Pods administrados por el Deployment `api` y ambos alcanzan estado `Running`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina una de las dos réplicas del reto y determina si tu solución recupera automáticamente la cantidad solicitada.

  > **Advertencia:** Sustituye `<POD_API>` por uno de los Pods con label `app=api`. No elimines el Deployment `api`.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete pod <POD_API> -n lab8
  ```

  > **Salida esperada:** Kubernetes elimina la réplica seleccionada y el controlador comienza a crear otra para recuperar el estado deseado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Realiza la validación final de ambos Deployments y confirma que el estado deseado se recuperó correctamente después de la prueba.

  > **Importante:** No corrijas manualmente creando Pods individuales. La validación final debe demostrar que ambos Deployments mantienen por sí mismos la cantidad de réplicas solicitada.
  {: .lab-note .important .compact}

  ```bash
  kubectl get deployments,pods -n lab8
  ```

  > **Salida esperada:** `web` conserva cuatro réplicas disponibles y `api` vuelve a tener dos réplicas disponibles después de la prueba de reconciliación.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab8` para retirar todos los Deployments, ReplicaSets y Pods creados durante esta práctica.

  > **Advertencia:** Verifica que el nombre sea exactamente `lab8`. Eliminar un namespace borra todos los recursos namespaced que contiene.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab8 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab8" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace `lab8` ya no existe y confirma que los nodos del clúster continúan disponibles para la siguiente práctica.

  > **Importante:** Los archivos locales creados dentro de `workspace/lab8` deben conservarse; la limpieza afecta únicamente a los recursos Kubernetes del namespace.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab8 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab8`, confirmando que los recursos de la práctica fueron eliminados.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}