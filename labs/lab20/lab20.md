---
layout: lab
title: "Práctica 20: Implementación de probes"
permalink: /lab20/lab20/
images_base: /labs/lab20/img
duration: "40 minutos"
objective:
  - Implementar y validar readinessProbe, livenessProbe y startupProbe, interpretar su efecto sobre disponibilidad y reinicios y diagnosticar el comportamiento de aplicaciones que dejan de estar listas, dejan de estar saludables o requieren un arranque lento.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica utilizarás probes para separar tres preguntas fundamentales sobre una aplicación en Kubernetes: si ya terminó de arrancar, si está preparada para recibir tráfico y si continúa saludable. La primera sección será guiada y mostrará la sintaxis y el efecto de readiness. Después resolverás retos donde deberás implementar readiness, provocar y diagnosticar reinicios mediante liveness y proteger una aplicación de arranque lento con startupProbe sin recibir los comandos de implementación.
slug: lab20
lab_number: 20
final_result: >
  Al finalizar habrás configurado readiness, liveness y startup probes, observado un Pod Running pero no Ready, relacionado readiness con los endpoints disponibles para un Service, provocado reinicios controlados mediante liveness y diagnosticado su causa. También habrás protegido una aplicación de arranque lento con startupProbe y comprobado que alcanza estado Ready sin reinicios innecesarios.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza nginx:1.31.4-alpine3.24-slim como imagen HTTP de referencia y busybox:1.38.0-musl para escenarios controlados.
  - readinessProbe determina si un contenedor está preparado para recibir tráfico; una falla de readiness no reinicia por sí sola el contenedor.
  - livenessProbe determina si un contenedor continúa saludable y puede provocar su reinicio después de alcanzar el umbral de fallos.
  - startupProbe protege aplicaciones de arranque lento; mientras no tenga éxito, Kubernetes no ejecuta las probes de liveness y readiness configuradas para ese contenedor.
  - La práctica utiliza mecanismos HTTP y exec para mostrar que las probes pueden comprobar salud de formas distintas.
  - Los primeros 6 pasos son guiados y los siguientes 14 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 30/70.
references:
  - text: Liveness, Readiness, and Startup Probes
    url: https://kubernetes.io/docs/concepts/workloads/pods/probes/
  - text: Configure Liveness, Readiness and Startup Probes
    url: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
  - text: Services en Kubernetes
    url: https://kubernetes.io/docs/concepts/services-networking/service/
  - text: EndpointSlices en Kubernetes
    url: https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
prev: /lab19/lab19/
next: /lab21/lab21/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y comprender las probes — 8 min

Prepararás el workspace y el namespace y revisarás cómo Kubernetes define readiness, liveness y startup probes. Después crearás un ejemplo guiado con readiness HTTP para observar la diferencia entre un Pod en ejecución y un contenedor declarado Ready.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, validarás el contexto activo y prepararás el namespace donde se ejecutarán todos los escenarios de salud.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab20` y accede a él para almacenar los manifiestos y evidencias de esta práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab20`; los archivos locales se conservarán después de limpiar el namespace.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab20 && cd workspace/lab20
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab20`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo para asegurarte de que las pruebas de salud se ejecutarán sobre el clúster local del curso.

  > **Importante:** El valor esperado es `kind-ckad`. No continúes si kubectl apunta a otro contexto.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab20` para aislar Deployments, Services y Pods utilizados durante las pruebas de readiness, liveness y startup.

  > **Advertencia:** Si `lab20` ya existe por una ejecución anterior, revisa primero sus workloads para evitar que reinicios o endpoints antiguos alteren las observaciones.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab20
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab20 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Explorar y observar una readiness probe

Revisarás los campos de las tres probes y crearás un Deployment mínimo con una comprobación HTTP de readiness.

- {% include step_label.html %} Consulta la estructura de las tres probes para identificar mecanismos como `httpGet`, `tcpSocket` y `exec`, además de sus parámetros de tiempo y umbrales.

  > **Nota:** Las tres probes comparten mecanismos de diagnóstico, pero Kubernetes interpreta sus resultados de manera diferente según el tipo de probe.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain pod.spec.containers.livenessProbe --recursive
  ```
  ```bash
  kubectl explain pod.spec.containers.readinessProbe --recursive
  ```
  ```bash
  kubectl explain pod.spec.containers.startupProbe --recursive
  ```

  > **Salida esperada:** La salida incluye mecanismos como `exec`, `httpGet` y `tcpSocket`, además de campos como `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds` y `failureThreshold`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `probe-demo.yaml` con un Deployment NGINX de una réplica y una readiness probe HTTP sobre la ruta `/` y el puerto `80`.

  > **Importante:** La readiness probe no determina si el proceso debe reiniciarse; determina si el contenedor debe considerarse preparado para recibir tráfico.
  {: .lab-note .important .compact}

  ```bash
  cat > probe-demo.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: probe-demo
    namespace: lab20
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: probe-demo
    template:
      metadata:
        labels:
          app: probe-demo
      spec:
        containers:
          - name: nginx
            image: nginx:1.31.4-alpine3.24-slim
            ports:
              - containerPort: 80
            readinessProbe:
              httpGet:
                path: /
                port: 80
              initialDelaySeconds: 2
              periodSeconds: 3
  EOF
  ```

  > **Salida esperada:** Se crea `probe-demo.yaml` con una readiness probe HTTP configurada sobre `/`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el Deployment y observa la columna `READY` para confirmar que el contenedor supera la probe antes de ser considerado disponible.

  > **Nota:** Puede existir un intervalo breve donde el Pod esté `Running` pero todavía muestre `0/1` en `READY`; ambos estados representan conceptos distintos.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f probe-demo.yaml
  ```
  ```bash
  kubectl get pods -n lab20 -l app=probe-demo
  ```

  > **Salida esperada:** El Deployment se crea y, después de superar la readiness probe, su Pod muestra `1/1` en la columna `READY`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: implementar readiness y observar disponibilidad — 7 min

A partir de esta tarea comienza la parte no guiada. Deberás crear una aplicación con readiness HTTP y relacionar el estado Ready de sus Pods con los backends publicados por un Service.

### Tarea 2.1. Configurar readiness en una aplicación

Interpretarás el requerimiento y decidirás cómo construir Deployment y Service sin recibir los comandos de implementación.

- {% include step_label.html %} Analiza el escenario de `web-ready` y determina cómo configurar la probe y el punto de acceso solicitado.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl explain`, `kubectl --help` y el ejemplo guiado como referencia.
  {: .lab-note .important .compact}

  ```text
  Reto readiness:

  Deployment:
  - Nombre: web-ready
  - Namespace: lab20
  - Réplicas: 2
  - Imagen: nginx:1.31.4-alpine3.24-slim

  Service:
  - Nombre: web-ready
  - Tipo: ClusterIP
  - Puerto: 80

  readinessProbe:
  - HTTP GET
  - path: /
  - port: 80
  - initialDelaySeconds: 2
  - periodSeconds: 3
  ```

  > **Salida esperada:** Identificas los objetos y campos necesarios para que ambos Pods sean evaluados mediante readiness y queden detrás del mismo Service.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `web-ready` y espera hasta que las dos réplicas estén disponibles.

  > **Nota:** El Service debe seleccionar los Pods del Deployment y conservar el mismo nombre durante toda la prueba.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora la solución.

  No continúes hasta que:
  - Deployment web-ready exista;
  - replicas = 2;
  - ambos Pods estén Ready;
  - Service web-ready exista.
  ```

  > **Salida esperada:** El Deployment muestra dos réplicas disponibles y el Service `web-ready` existe en `lab20`.
  {: .lab-note .output .compact}

### Tarea 2.2. Observar el efecto de readiness

Validarás el estado Ready y provocarás por tu cuenta que una de las réplicas deje de superar la probe sin terminar el proceso principal.

- {% include step_label.html %} Comprueba que ambos Pods están Ready y que Kubernetes publica endpoints para el Service antes de provocar el fallo.

  > **Nota:** Esta validación establece el estado inicial funcional. Después podrás comparar qué cambia cuando una réplica deja de estar Ready.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab20 -l app=web-ready
  ```
  ```bash
  kubectl get endpointslices -n lab20 -l kubernetes.io/service-name=web-ready
  ```

  > **Salida esperada:** Los dos Pods muestran `1/1` Ready y existe al menos un EndpointSlice asociado al Service.
  {: .lab-note .output .compact}

- {% include step_label.html %} Provoca por tu cuenta que una sola réplica deje de responder correctamente a la ruta utilizada por readiness y observa el estado resultante sin detener NGINX.

  > **Importante:** El objetivo es producir un Pod que continúe `Running` pero pase a `Ready=False`. No elimines el Pod ni detengas el proceso principal.
  {: .lab-note .important .compact}

  ```text
  Estado que debes conseguir:

  - un Pod web-ready continúa Running;
  - ese Pod pasa a 0/1 Ready;
  - el otro Pod continúa 1/1 Ready;
  - el Service permanece existente.
  ```

  > **Salida esperada:** Uno de los Pods permanece `Running` pero muestra `0/1` en `READY`, mientras la otra réplica continúa disponible.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🔁 Tarea 3. Reto: implementar liveness y diagnosticar reinicios — 9 min

Crearás un contenedor cuyo indicador de salud desaparezca después de iniciar. La liveness probe deberá detectar el fallo y provocar reinicios que posteriormente tendrás que diagnosticar.

### Tarea 3.1. Crear un fallo controlado de liveness

Diseñarás un Pod donde el proceso principal continúe activo, pero la comprobación de salud falle después de algunos segundos.

- {% include step_label.html %} Analiza el escenario y determina cómo utilizar una liveness probe de tipo `exec` para comprobar la existencia de un archivo de salud.

  > **Importante:** El proceso principal debe continuar ejecutándose aunque el archivo desaparezca; de esa manera el reinicio será consecuencia de la liveness probe y no de la terminación normal del proceso.
  {: .lab-note .important .compact}

  ```text
  Reto liveness:

  Pod:
  - Nombre: health-app
  - Namespace: lab20
  - Imagen: busybox:1.38.0-musl

  Comportamiento:
  - crear /tmp/healthy al iniciar;
  - eliminar /tmp/healthy después de aproximadamente 15 segundos;
  - mantener el proceso principal activo.

  livenessProbe:
  - tipo exec;
  - debe comprobar /tmp/healthy;
  - periodSeconds: 3;
  - failureThreshold: 2.
  ```

  > **Salida esperada:** Identificas cómo separar el proceso principal del indicador utilizado por la liveness probe.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `health-app` y espera hasta observar que el contador de reinicios aumenta después de que la comprobación falle repetidamente.

  > **Advertencia:** No elimines manualmente el Pod durante la prueba. Necesitas conservar el mismo objeto para observar `RESTARTS` y el estado anterior del contenedor.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get pod health-app -n lab20
  ```

  > **Salida esperada:** Después del tiempo necesario, `health-app` continúa existiendo y la columna `RESTARTS` muestra al menos un reinicio.
  {: .lab-note .output .compact}

### Tarea 3.2. Diagnosticar el reinicio

Utilizarás el estado del Pod, sus eventos y la información de la ejecución anterior para relacionar el reinicio con la liveness probe.

- {% include step_label.html %} Consulta el Pod con información ampliada para identificar eventos relacionados con fallos de liveness y reinicios del contenedor.

  > **Nota:** `kubectl describe` reúne condiciones, estado del contenedor y eventos recientes, por lo que es una de las primeras herramientas útiles para diagnosticar probes.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe pod health-app -n lab20
  ```

  > **Salida esperada:** Los eventos incluyen mensajes relacionados con `Liveness probe failed` y reinicio o terminación del contenedor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el contador de reinicios directamente desde `containerStatuses` para confirmar que Kubernetes reinició el contenedor dentro del mismo Pod.

  > **Importante:** Un fallo de liveness provoca normalmente un restart del contenedor; no implica por sí solo la creación de un Pod con nombre nuevo.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pod health-app -n lab20 -o jsonpath='Pod={.metadata.name} Restarts={.status.containerStatuses[0].restartCount}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Pod=health-app` y un valor `Restarts` mayor que cero.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los logs de la ejecución anterior para practicar el uso de `--previous` cuando un contenedor ha sido reiniciado.

  > **Nota:** En este escenario puede haber poca salida porque el proceso no necesita escribir logs; el objetivo es reconocer la técnica correcta para recuperar la ejecución anterior.
  {: .lab-note .info .compact}

  ```bash
  kubectl logs health-app -n lab20 --previous
  ```

  > **Salida esperada:** kubectl devuelve los logs de la instancia anterior del contenedor o una salida vacía si el proceso no escribió mensajes antes del reinicio.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## ⏳ Tarea 4. Reto: combinar startup, readiness y liveness — 11 min

Resolverás un escenario de arranque lento donde una liveness agresiva sería problemática. Deberás configurar las tres probes para que startup proteja la fase inicial y readiness y liveness actúen después de que la aplicación esté disponible.

### Tarea 4.1. Proteger una aplicación de arranque lento

Diseñarás un Pod que tarde aproximadamente 20 segundos en crear su indicador de inicio y que posteriormente permanezca saludable.

- {% include step_label.html %} Analiza el comportamiento de `slow-api` y determina cómo coordinar startup, readiness y liveness sin provocar un ciclo de reinicios durante el arranque.

  > **Importante:** Si existe `startupProbe`, Kubernetes no ejecuta las probes de liveness y readiness del contenedor hasta que startup tenga éxito.
  {: .lab-note .important .compact}

  ```text
  Reto final:

  Pod:
  - Nombre: slow-api
  - Namespace: lab20
  - Imagen: busybox:1.38.0-musl

  Comportamiento:
  - esperar aproximadamente 20 segundos;
  - crear /tmp/started;
  - crear /tmp/ready;
  - permanecer ejecutándose.

  startupProbe:
  - exec sobre /tmp/started
  - periodSeconds: 2
  - failureThreshold suficiente para superar 20 segundos

  readinessProbe:
  - exec sobre /tmp/ready
  - periodSeconds: 3

  livenessProbe:
  - exec sobre /tmp/started
  - periodSeconds: 5

  Estado final:
  - Running
  - Ready
  - Restarts=0
  ```

  > **Salida esperada:** Identificas que startup necesita una ventana total mayor al tiempo aproximado de inicialización antes de que liveness y readiness comiencen a ejecutarse.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `slow-api` y observa su transición desde el arranque hasta quedar Ready.

  > **Advertencia:** No reduzcas artificialmente el tiempo de arranque para lograr el resultado. La finalidad es dimensionar correctamente la startup probe.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get pod slow-api -n lab20 -w
  ```

  > **Salida esperada:** El Pod aparece inicialmente sin estar Ready y posteriormente alcanza `1/1` Ready sin entrar en un ciclo de reinicios.
  {: .lab-note .output .compact}

### Tarea 4.2. Validar las tres probes

Comprobarás que el estado final cumple funcionalidad y que el objeto activo contiene las tres probes requeridas.

- {% include step_label.html %} Consulta estado, condición Ready y contador de reinicios después de que termine el arranque.

  > **Nota:** Un diseño correcto debe permitir completar la inicialización antes de aplicar comprobaciones periódicas que podrían interferir con el proceso.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod slow-api -n lab20 -o jsonpath='Phase={.status.phase} Ready={.status.containerStatuses[0].ready} Restarts={.status.containerStatuses[0].restartCount}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Phase=Running Ready=true Restarts=0`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona el Pod activo para confirmar que están configuradas startup, readiness y liveness probes en el mismo contenedor.

  > **Importante:** No des por terminado el reto únicamente por el estado `Running`; el objeto debe contener explícitamente las tres probes solicitadas.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pod slow-api -n lab20 -o jsonpath='Startup={.spec.containers[0].startupProbe.exec.command} Readiness={.spec.containers[0].readinessProbe.exec.command} Liveness={.spec.containers[0].livenessProbe.exec.command}{"\n"}'
  ```

  > **Salida esperada:** La salida muestra comandos configurados para las tres probes.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa los eventos finales del Pod para confirmar que no existen reinicios repetitivos provocados por una liveness prematura.

  > **Advertencia:** Si aparecen múltiples eventos de liveness fallida durante la fase inicial, revisa la configuración de startup antes de continuar.
  {: .lab-note .warning .compact}

  ```bash
  kubectl describe pod slow-api -n lab20
  ```

  > **Salida esperada:** El Pod permanece Ready y no presenta un patrón de reinicios continuos por fallos de liveness durante el arranque.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar el entorno de la práctica — 5 min

Esta tarea no forma parte de la evaluación 30/70. Ejecútala únicamente después de terminar los retos, observar los efectos de readiness y liveness y validar correctamente el escenario de startup.

### Tarea 5.1. Revisar y retirar los recursos del laboratorio

Realizarás una última inspección, eliminarás el namespace y confirmarás que los recursos Kubernetes desaparecieron mientras los manifiestos locales permanecen disponibles para repaso.

- {% include step_label.html %} Revisa una última vez los Deployments, Pods y Services creados antes de destruir el escenario de pruebas.

  > **Nota:** Debes haber terminado especialmente el diagnóstico de `health-app` y la validación de `slow-api` antes de continuar.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployments,pods,services -n lab20
  ```

  > **Salida esperada:** Se muestran los workloads y Services utilizados durante la práctica con sus estados actuales.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab20` únicamente cuando ya no necesites revisar condiciones, reinicios, eventos o endpoints.

  > **Advertencia:** Eliminar el namespace destruye también la evidencia de fallos de probes utilizada durante el diagnóstico.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab20 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab20" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace ya no existe para confirmar que la limpieza del clúster terminó correctamente.

  > **Importante:** La ausencia de salida es el resultado esperado debido al uso de `--ignore-not-found`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab20 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab20`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los archivos locales permanecen en el workspace para revisar posteriormente las configuraciones de probes utilizadas.

  > **Nota:** La limpieza afecta únicamente a Kubernetes; conserva `workspace/lab20` como material de estudio.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio continúa mostrando `probe-demo.yaml` y los manifiestos creados durante los retos.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}