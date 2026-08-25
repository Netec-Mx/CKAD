---
layout: lab
title: "Práctica 9: Rolling update y rollback"
permalink: /lab9/lab9/
images_base: /labs/lab9/img
duration: "45 minutos"
objective:
  - Ejecutar, observar y diagnosticar actualizaciones RollingUpdate sobre un Deployment, consultar su historial de revisiones, provocar una actualización defectuosa y recuperar la última versión funcional mediante rollback, finalizando con un reto parcialmente guiado orientado a escenarios tipo examen.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica administrarás el ciclo de actualización de una aplicación desplegada mediante Deployment. Revisarás la estrategia RollingUpdate y sus parámetros, ejecutarás una actualización funcional, observarás los ReplicaSets y revisiones generadas, provocarás deliberadamente una actualización defectuosa para diagnosticar su impacto y recuperarás el estado estable mediante rollback. Finalmente resolverás un reto sin comandos de implementación y limpiarás el entorno únicamente cuando hayas terminado por completo la práctica.
slug: lab9
lab_number: 9
final_result: >
  Al finalizar habrás ejecutado y validado un RollingUpdate, identificado revisiones y ReplicaSets asociados a un Deployment, diagnosticado una actualización defectuosa que no consigue progresar y restaurado la aplicación mediante kubectl rollout undo. También habrás resuelto un reto de actualización y recuperación sin comandos de solución y habrás limpiado el namespace de la práctica únicamente después de completar todas las validaciones.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - La estrategia RollingUpdate es la utilizada por defecto en Deployment y permite reemplazar Pods progresivamente.
  - Cada paso contiene una acción principal; las operaciones de crear, revisar, actualizar, diagnosticar, revertir y limpiar se mantienen separadas.
  - Las Tareas 1 a 4 son guiadas. La Tarea 5 contiene seis pasos de reto y dos pasos adicionales de limpieza.
references:
  - text: Deployments en Kubernetes
    url: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
  - text: Referencia oficial de kubectl rollout
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/
  - text: Referencia oficial de kubectl rollout undo
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_undo/
  - text: Tutorial oficial de Rolling Update
    url: https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/
prev: /lab8/lab8/
next: /lab10/lab10/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y revisar la estrategia de actualización — 7 min

Prepararás el workspace y el namespace del laboratorio, crearás un Deployment inicial y revisarás su estrategia RollingUpdate antes de realizar cualquier cambio de versión.

### Tarea 1.1. Preparar el entorno

Crearás el directorio local de trabajo, validarás el contexto y prepararás el namespace utilizado durante toda la práctica.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab9` y accede a él; permanecerás en `ckad-labs/workspace/lab9` durante el resto de la práctica.

  > **Nota:** Los manifiestos y archivos generados en este workspace permanecerán únicamente en tu estación local.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab9 && cd workspace/lab9
  ```

  > **Salida esperada:** La terminal queda ubicada dentro de `ckad-labs/workspace/lab9`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que kubectl continúa utilizando el contexto `kind-ckad`.

  > **Importante:** No continúes si el contexto activo corresponde a otro clúster.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab9` para aislar los recursos utilizados en el laboratorio.

  > **Advertencia:** Si `lab9` ya existe por una ejecución anterior, revisa primero su contenido antes de reutilizarlo.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab9
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab9 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Crear y revisar el Deployment inicial

Generarás un Deployment con varias réplicas y examinarás los parámetros que controlan el comportamiento de RollingUpdate.

- {% include step_label.html %} Genera `deployment.yaml` para un Deployment denominado `web` con cuatro réplicas y una imagen NGINX estable.

  > **Nota:** Utilizar varias réplicas permite observar con mayor claridad el reemplazo progresivo durante una actualización.
  {: .lab-note .info .compact}

  ```bash
  kubectl create deployment web --image=nginx:1.31.4-alpine3.24-slim --replicas=4 -n lab9 --dry-run=client -o yaml > deployment.yaml
  ```

  > **Salida esperada:** Se crea `deployment.yaml` sin crear todavía el Deployment en el clúster.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el manifiesto para crear el Deployment inicial.

  > **Importante:** El Deployment se convertirá en la revisión base desde la que se realizarán las actualizaciones posteriores.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f deployment.yaml
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/web created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la estrategia activa del Deployment y revisa los valores de `maxSurge` y `maxUnavailable`.

  > **Nota:** RollingUpdate controla cuántos Pods adicionales pueden crearse temporalmente y cuántos pueden quedar no disponibles durante la actualización.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployment web -n lab9 -o jsonpath='Strategy={.spec.strategy.type} MaxSurge={.spec.strategy.rollingUpdate.maxSurge} MaxUnavailable={.spec.strategy.rollingUpdate.maxUnavailable}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Strategy=RollingUpdate` y los valores configurados para `MaxSurge` y `MaxUnavailable`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🔄 Tarea 2. Ejecutar y observar un RollingUpdate — 9 min

Actualizarás la imagen del Deployment y observarás cómo Kubernetes crea una nueva revisión y sustituye progresivamente los Pods sin eliminar simultáneamente todas las réplicas existentes.

### Tarea 2.1. Ejecutar la actualización

Registrarás la versión actual, modificarás la imagen y observarás el progreso del rollout mediante operaciones independientes.

- {% include step_label.html %} Consulta la imagen actualmente declarada en la plantilla del Deployment antes de realizar la actualización.

  > **Nota:** Registrar el valor previo facilita comprobar posteriormente que la actualización realmente cambió la plantilla.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployment web -n lab9 -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `nginx:1.31.4-alpine3.24-slim`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Actualiza la imagen del contenedor `nginx` para provocar una nueva revisión del Deployment.

  > **Importante:** Un cambio en `spec.template` genera un nuevo rollout y un nuevo ReplicaSet.
  {: .lab-note .important .compact}

  ```bash
  kubectl set image deployment/web nginx=nginx:1.31.4-alpine3.24 -n lab9
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/web image updated`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que Kubernetes complete el RollingUpdate.

  > **Advertencia:** Si el rollout excede el timeout, no elimines el Deployment; continúa con diagnóstico.
  {: .lab-note .warning .compact}

  ```bash
  kubectl rollout status deployment/web -n lab9 --timeout=60s
  ```

  > **Salida esperada:** kubectl informa que el Deployment `web` completó correctamente el rollout.
  {: .lab-note .output .compact}

### Tarea 2.2. Verificar el reemplazo progresivo

Comprobarás los Pods y ReplicaSets resultantes y confirmarás que la versión nueva quedó activa.

- {% include step_label.html %} Consulta los Pods administrados por el Deployment después de completar la actualización.

  > **Nota:** Los Pods activos deben corresponder al ReplicaSet generado por la revisión nueva.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab9 -l app=web
  ```

  > **Salida esperada:** Se muestran cuatro Pods en estado `Running`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los ReplicaSets para identificar cuál mantiene las réplicas activas y cuál corresponde a la versión anterior.

  > **Importante:** El ReplicaSet anterior suele permanecer con cero réplicas para conservar historial.
  {: .lab-note .important .compact}

  ```bash
  kubectl get replicasets -n lab9
  ```

  > **Salida esperada:** Se muestran al menos dos ReplicaSets asociados con `web`; uno mantiene cuatro réplicas y el anterior cero.
  {: .lab-note .output .compact}

- {% include step_label.html %} Verifica la imagen utilizada actualmente por los Pods.

  > **Nota:** Esta comprobación confirma el estado real de las réplicas, no únicamente la configuración del Deployment.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab9 -l app=web -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.containers[0].image}{"\n"}{end}'
  ```

  > **Salida esperada:** Los cuatro Pods muestran `nginx:1.31.4-alpine3.24`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 📚 Tarea 3. Analizar revisiones e historial — 8 min

Explorarás el historial registrado por Kubernetes y relacionarás cada revisión con los ReplicaSets conservados por el Deployment.

### Tarea 3.1. Consultar el historial de rollout

Utilizarás los comandos específicos de rollout para identificar las revisiones conocidas y examinar una de ellas con mayor detalle.

- {% include step_label.html %} Consulta el historial completo del Deployment `web`.

  > **Nota:** Kubernetes registra revisiones cuando cambia la plantilla de Pods del Deployment.
  {: .lab-note .info .compact}

  ```bash
  kubectl rollout history deployment/web -n lab9
  ```

  > **Salida esperada:** Se muestran al menos dos revisiones disponibles.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los detalles de la revisión 1 para identificar la imagen utilizada originalmente.

  > **Importante:** El número de revisión permite recuperar información de una versión previa concreta.
  {: .lab-note .important .compact}

  ```bash
  kubectl rollout history deployment/web -n lab9 --revision=1
  ```

  > **Salida esperada:** La revisión muestra información del contenedor y la imagen original.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los detalles de la revisión 2 para comparar la configuración con la revisión anterior.

  > **Nota:** La revisión nueva debe reflejar el cambio realizado mediante `kubectl set image`.
  {: .lab-note .info .compact}

  ```bash
  kubectl rollout history deployment/web -n lab9 --revision=2
  ```

  > **Salida esperada:** Se muestra la imagen correspondiente a la segunda revisión.
  {: .lab-note .output .compact}

### Tarea 3.2. Relacionar revisiones con ReplicaSets

Examinarás la revisión almacenada en cada ReplicaSet y comprobarás qué versión mantiene réplicas activas.

- {% include step_label.html %} Lista los ReplicaSets mostrando la anotación de revisión asociada a cada uno.

  > **Importante:** La anotación `deployment.kubernetes.io/revision` permite relacionar cada ReplicaSet con el historial del Deployment.
  {: .lab-note .important .compact}

  ```bash
  kubectl get rs -n lab9 -o custom-columns='NAME:.metadata.name,REVISION:.metadata.annotations.deployment\.kubernetes\.io/revision,DESIRED:.spec.replicas'
  ```

  > **Salida esperada:** Se muestran ReplicaSets con revisiones diferentes y sus cantidades deseadas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta nuevamente el Deployment para confirmar qué revisión está activa actualmente.

  > **Nota:** La revisión activa corresponde al ReplicaSet que mantiene las réplicas actuales del workload.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployment web -n lab9 -o jsonpath='CurrentRevision={.metadata.annotations.deployment\.kubernetes\.io/revision}{"\n"}'
  ```

  > **Salida esperada:** Se muestra la revisión actual del Deployment.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🛠️ Tarea 4. Provocar una actualización defectuosa y ejecutar rollback — 12 min

Introducirás deliberadamente una imagen inexistente para observar un rollout que no consigue progresar. Después diagnosticarás el problema y restaurarás la última revisión funcional mediante rollback.

### Tarea 4.1. Provocar y diagnosticar el fallo

Cambiarás la imagen a un tag inválido y utilizarás estado, Pods y eventos para confirmar por qué la nueva revisión no alcanza disponibilidad.

- {% include step_label.html %} Configura deliberadamente una imagen inexistente para iniciar una actualización defectuosa.

  > **Advertencia:** Este cambio es intencional y provocará errores de descarga de imagen en los Pods nuevos.
  {: .lab-note .warning .compact}

  ```bash
  kubectl set image deployment/web nginx=nginx:lab9-image-does-not-exist -n lab9
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/web image updated`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el estado de los Pods para identificar las réplicas que no pueden iniciar con la nueva imagen.

  > **Nota:** El estado puede evolucionar entre `ErrImagePull` e `ImagePullBackOff`.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab9
  ```

  > **Salida esperada:** Al menos un Pod de la nueva revisión presenta un estado relacionado con error de descarga de imagen.
  {: .lab-note .output .compact}

- {% include step_label.html %} Examina el Deployment y sus eventos para confirmar que la actualización no progresa debido a la imagen inválida.

  > **Importante:** Los eventos aportan evidencia concreta sobre errores de pull y permiten diferenciar este problema de fallos de scheduling o configuración.
  {: .lab-note .important .compact}

  ```bash
  kubectl describe deployment web -n lab9
  ```

  > **Salida esperada:** La descripción muestra la imagen defectuosa, disponibilidad incompleta y eventos relacionados con la nueva revisión.
  {: .lab-note .output .compact}

### Tarea 4.2. Recuperar la última versión funcional

Utilizarás el mecanismo oficial de rollback del Deployment y verificarás que las réplicas vuelven a utilizar la versión anterior.

- {% include step_label.html %} Revierte el Deployment a la revisión funcional anterior.

  > **Importante:** `kubectl rollout undo` restaura la plantilla correspondiente a la revisión previa sin necesidad de editar manualmente la imagen.
  {: .lab-note .important .compact}

  ```bash
  kubectl rollout undo deployment/web -n lab9
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/web rolled back`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que el rollback complete el rollout y la aplicación recupere disponibilidad.

  > **Nota:** El rollback también genera actividad de reconciliación hasta que el estado deseado vuelve a quedar satisfecho.
  {: .lab-note .info .compact}

  ```bash
  kubectl rollout status deployment/web -n lab9 --timeout=60s
  ```

  > **Salida esperada:** kubectl informa que el Deployment completó correctamente el rollout después de la reversión.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🎯 Tarea 5. Reto de consolidación de rollout y rollback — 9 min

Resolverás un escenario adicional sin comandos de implementación. Deberás aplicar una actualización, comprobar su revisión y posteriormente recuperar una versión funcional cuando aparezca una condición defectuosa.

### Tarea 5.1. Resolver el RollingUpdate del reto

Analizarás los requisitos, ejecutarás por tu cuenta la actualización y utilizarás únicamente los comandos de validación proporcionados.

- {% include step_label.html %} Analiza el escenario y determina qué acciones debes realizar para actualizar correctamente el Deployment existente.

  > **Importante:** A partir de este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl --help`, `kubectl explain` y los comandos de rollout aprendidos anteriormente.
  {: .lab-note .important .compact}

  ```text
  Escenario:

  El Deployment web debe actualizarse nuevamente.

  Requisitos:
  - Mantener 4 réplicas.
  - Utilizar la imagen nginx:1.31.4-alpine3.24-slim.
  - Completar el RollingUpdate.
  - Mantener el historial de revisiones.
  - Todos los Pods deben terminar Ready.
  ```

  > **Salida esperada:** Identificas el procedimiento necesario para cumplir la actualización sin modificar otros recursos del namespace.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta por tu cuenta la actualización solicitada y espera hasta considerar que el estado final cumple todos los requisitos.

  > **Nota:** El método de implementación forma parte del reto; no se evalúa si utilizaste un comando imperativo o una modificación declarativa, sino el estado final.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora el RollingUpdate.

  No continúes hasta considerar que:
  - la imagen es correcta;
  - existen 4 réplicas;
  - el rollout terminó;
  - los Pods están Ready.
  ```

  > **Salida esperada:** El Deployment queda actualizado según los requisitos del escenario.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida la actualización y corrige cualquier requisito que aún no esté satisfecho.

  > **Advertencia:** No des por terminado el reto únicamente porque el Deployment exista; verifica imagen, disponibilidad e historial.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get deployment web -n lab9
  ```

  > **Salida esperada:** `web` muestra cuatro réplicas deseadas y disponibles.
  {: .lab-note .output .compact}

### Tarea 5.2. Resolver el rollback del reto

Recibirás una condición defectuosa, decidirás cómo recuperar el último estado funcional y validarás la revisión final.

- {% include step_label.html %} Analiza la nueva condición del reto y determina cómo recuperar la última versión funcional del Deployment.

  > **Importante:** No se proporciona el comando de rollback. Debes seleccionar el mecanismo correcto a partir de lo practicado anteriormente.
  {: .lab-note .important .compact}

  ```text
  Incidente:

  Una actualización posterior dejó el Deployment con
  una imagen que no puede iniciar correctamente.

  Objetivo:
  - Recuperar la última revisión funcional.
  - Mantener 4 réplicas.
  - Dejar todos los Pods Ready.
  - Conservar el historial de revisiones.
  ```

  > **Salida esperada:** Determinas qué revisión recuperar y qué comando o procedimiento utilizar.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta por tu cuenta la recuperación y espera hasta que el Deployment vuelva a estar disponible.

  > **Nota:** La corrección debe realizarse sobre el Deployment; no sustituyas manualmente Pods individuales.
  {: .lab-note .info .compact}

  ```text
  Recupera ahora el último estado funcional.

  Verifica por tu cuenta el progreso antes
  de continuar con la validación final.
  ```

  > **Salida esperada:** El Deployment recupera una revisión funcional y vuelve a mantener sus réplicas disponibles.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el estado final del reto comprobando el historial de revisiones.

  > **Advertencia:** Si alguna condición no coincide con el objetivo, corrígela antes de pasar a la subtarea de limpieza.
  {: .lab-note .warning .compact}

  ```bash
  kubectl rollout history deployment/web -n lab9
  ```

  > **Salida esperada:** El historial permanece disponible y el Deployment se encuentra nuevamente en una revisión funcional.
  {: .lab-note .output .compact}

### Tarea 5.3. Limpiar el entorno de la práctica

Ejecuta esta subtarea únicamente cuando hayas terminado completamente el reto, validado todos los criterios de éxito y ya no necesites conservar los recursos activos para revisión.

- {% include step_label.html %} Cuando hayas terminado completamente el reto y confirmado todos sus criterios de éxito, elimina el namespace `lab9`.

  > **Advertencia:** No ejecutes este paso mientras todavía estés resolviendo o revisando el reto. Eliminar el namespace borra Deployments, ReplicaSets, Pods y demás recursos namespaced utilizados durante la práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab9 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab9" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace `lab9` ya no existe y confirma que la limpieza del entorno Kubernetes fue completada.

  > **Importante:** Conserva los archivos locales almacenados en `workspace/lab9`; únicamente se eliminan los recursos activos del clúster.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab9 --ignore-not-found
  ```

  > **Salida esperada:** No se muestra ningún namespace denominado `lab9`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}