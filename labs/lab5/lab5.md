---
layout: lab
title: "Práctica 5: Diseño de Pod con patrón sidecar"
permalink: /lab5/lab5/
images_base: /labs/lab5/img
duration: "50 minutos"
objective:
  - Diseñar, desplegar y diagnosticar un Pod que utilice un sidecar nativo para procesar continuamente información generada por la aplicación principal, compartiendo datos mediante un volumen emptyDir y utilizando herramientas de kubectl para inspeccionar estados, logs, reinicios y comportamiento multicontenedor.
prerequisites:
  - Haber completado la Práctica 4 Diseño de Pod con init container.
  - Disponer del clúster kind denominado ckad con Kubernetes 1.36.1 y el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code utilizando Git Bash dentro del directorio local ckad-labs.
introduction:
  - En esta práctica diseñarás un Pod multicontenedor utilizando el mecanismo nativo de sidecar de Kubernetes. La aplicación principal generará eventos periódicamente en un archivo almacenado en un volumen emptyDir, mientras un sidecar definido como init container reiniciable permanecerá ejecutándose y enviará ese contenido a su salida estándar. Observarás cómo ambos contenedores comparten datos, consultarás sus logs de forma independiente y provocarás un fallo controlado en el sidecar para analizar reinicios y comprobar que la aplicación principal puede continuar ejecutándose.
slug: lab5
lab_number: 5
final_result: >
  Al finalizar habrás desplegado un Pod compuesto por una aplicación principal y un sidecar nativo que se ejecutan de forma concurrente, utilizado un volumen emptyDir para compartir un archivo de logs, consultado estados y logs específicos de cada contenedor, comprobado mediante JSONPath y kubectl describe la configuración multicontenedor, provocado un fallo controlado que genera reinicios únicamente en el sidecar y restaurado finalmente la configuración funcional antes de eliminar los recursos Kubernetes de la práctica.
notes:
  - Esta práctica utiliza sidecar containers nativos, funcionalidad estable y habilitada por defecto en Kubernetes moderno. El sidecar se define dentro de initContainers con restartPolicy Always.
  - La imagen utilizada para ambos procesos es busybox:1.38.0-musl para mantener el escenario pequeño, reproducible y centrado en el comportamiento Kubernetes.
  - El volumen emptyDir es compartido por los contenedores del Pod y sus datos existen únicamente mientras el Pod permanezca asociado al nodo.
  - Los archivos YAML creados dentro de workspace/lab5 permanecen únicamente en la estación local del participante.
  - No elimines ni reconstruyas el clúster ckad; la limpieza final afecta únicamente al namespace lab5.
references:
  - text: Sidecar Containers en Kubernetes
    url: https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/
  - text: Volúmenes Kubernetes y emptyDir
    url: https://kubernetes.io/docs/concepts/storage/volumes/
  - text: Comunicación entre contenedores mediante un volumen compartido
    url: https://kubernetes.io/docs/tasks/access-application-cluster/communicate-containers-same-pod-shared-volume/
  - text: Referencia oficial de kubectl logs
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/
  - text: Imagen oficial BusyBox
    url: https://hub.docker.com/_/busybox
prev: /lab4/lab4/
next: /lab6/lab6/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 🔎 Tarea 1. Preparar el escenario multicontenedor — 7 min

Prepararás un workspace exclusivo, validarás el clúster utilizado y crearás un namespace aislado. Después definirás la estructura inicial del Pod y el volumen emptyDir que permitirá intercambiar datos entre la aplicación principal y el sidecar.

### Tarea 1.1. Preparar el workspace y el namespace

Crearás el directorio local de trabajo y comprobarás que kubectl continúa conectado al clúster correcto antes de incorporar nuevos recursos Kubernetes.

- {% include step_label.html %} Crea el directorio `workspace/lab5`, accede a él y confirma la ruta local desde la que trabajarás durante toda la práctica.

  > **Nota:** Los manifiestos creados dentro de `workspace/lab5` son archivos locales de trabajo y no necesitan publicarse nuevamente en el repositorio del curso.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab5 && cd workspace/lab5 && pwd
  ```

  > **Salida esperada:** La ruta mostrada termina en `/ckad-labs/workspace/lab5`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo de kubectl para confirmar que los recursos de la práctica se crearán en el clúster `ckad` del curso.

  > **Importante:** El contexto esperado es `kind-ckad`. Si aparece otro contexto, selecciónalo antes de continuar para evitar crear recursos en un clúster diferente.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta las versiones del cliente y del servidor Kubernetes para confirmar que el clúster utiliza una versión compatible con sidecar containers nativos.

  > **Nota:** El clúster del curso utiliza Kubernetes 1.36.1. Los sidecar containers nativos son una funcionalidad estable en esta versión y se definen mediante `restartPolicy: Always` dentro de `initContainers`.
  {: .lab-note .info .compact}

  ```bash
  kubectl version
  ```

  > **Salida esperada:** Se muestra la información del cliente y del servidor; la versión del servidor corresponde a Kubernetes `v1.36.1`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab5` para mantener aislados todos los recursos utilizados durante el ejercicio.

  > **Advertencia:** Si `lab5` ya existe debido a una ejecución anterior incompleta, revisa sus recursos antes de reutilizarlo para evitar resultados distintos a los documentados.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab5
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab5 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Definir el Pod y el volumen compartido

Crearás el manifiesto base y declararás un volumen `emptyDir` denominado `shared-logs`, que será utilizado simultáneamente por la aplicación principal y el sidecar.

- {% include step_label.html %} Crea el archivo `sidecar-pod.yaml` con los metadatos del Pod y una política de reinicio apropiada para una aplicación de larga ejecución.

  > **Nota:** El nombre `sidecar-demo` se conservará durante toda la práctica para facilitar consultas, diagnóstico y limpieza.
  {: .lab-note .info .compact}

  ```bash
  cat > sidecar-pod.yaml <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: sidecar-demo
    namespace: lab5
    labels:
      app: sidecar-demo
  spec:
    restartPolicy: Always
  EOF
  ```

  > **Salida esperada:** Se crea `sidecar-pod.yaml` con `kind: Pod`, namespace `lab5` y nombre `sidecar-demo`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega el volumen `emptyDir` denominado `shared-logs` dentro de `spec` para proporcionar almacenamiento común a los procesos del Pod.

  > **Importante:** Todos los contenedores del mismo Pod pueden montar el mismo `emptyDir` y leer o escribir sus archivos, aunque utilicen rutas de montaje diferentes.
  {: .lab-note .important .compact}

  ```bash
  cat >> sidecar-pod.yaml <<'EOF'
    volumes:
      - name: shared-logs
        emptyDir: {}
  EOF
  ```

  > **Salida esperada:** El manifiesto contiene un volumen denominado `shared-logs` con `emptyDir: {}`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el esquema del API Server para comprobar la definición del campo `emptyDir` antes de incorporar los contenedores que utilizarán el volumen.

  > **Nota:** `kubectl explain` permite confirmar rápidamente la ubicación y propósito de campos YAML directamente desde el esquema conocido por Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain pod.spec.volumes.emptyDir
  ```

  > **Salida esperada:** kubectl muestra la descripción y propiedades disponibles para un volumen de tipo `emptyDir`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🧩 Tarea 2. Diseñar el Pod con patrón sidecar — 11 min

Definirás primero el sidecar nativo y después la aplicación principal. Ambos procesos utilizarán el mismo volumen, pero con responsabilidades diferentes: la aplicación producirá eventos y el sidecar los observará continuamente.

### Tarea 2.1. Definir el sidecar nativo

Agregarás un contenedor dentro de `initContainers` con `restartPolicy: Always`. A diferencia de un init container tradicional, este proceso permanecerá activo mientras se ejecuta la aplicación principal.

- {% include step_label.html %} Agrega un init container denominado `log-sidecar` con `restartPolicy: Always`, convirtiéndolo en un sidecar nativo de Kubernetes.

  > **Importante:** Un init container tradicional debe terminar antes de iniciar la aplicación; un sidecar nativo utiliza `restartPolicy: Always` dentro de `initContainers` para permanecer ejecutándose durante la vida de los contenedores principales.
  {: .lab-note .important .compact}

  ```bash
  cat >> sidecar-pod.yaml <<'EOF'
    initContainers:
      - name: log-sidecar
        image: busybox:1.38.0-musl
        imagePullPolicy: IfNotPresent
        restartPolicy: Always
  EOF
  ```

  > **Salida esperada:** El manifiesto contiene `initContainers`, el contenedor `log-sidecar` y `restartPolicy: Always`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Configura el sidecar para esperar la creación del archivo y después seguir continuamente las nuevas líneas escritas por la aplicación.

  > **Nota:** El bucle inicial evita que `tail` termine antes de que la aplicación cree `app.log`; después `tail -f` mantiene el proceso observando el archivo mientras la aplicación continúa escribiendo eventos.
  {: .lab-note .info .compact}

  ```bash
  cat >> sidecar-pod.yaml <<'EOF'
        command:
          - /bin/sh
          - -c
          - |
            echo "Sidecar iniciado; esperando app.log..."
            while [ ! -f /var/log/shared/app.log ]; do sleep 1; done
            echo "app.log detectado; iniciando seguimiento."
            tail -f /var/log/shared/app.log
  EOF
  ```

  > **Salida esperada:** El sidecar contiene un comando que espera `/var/log/shared/app.log` y posteriormente ejecuta `tail -f`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Monta `shared-logs` en `/var/log/shared` dentro del sidecar para darle acceso al archivo que generará la aplicación principal.

  > **Advertencia:** El nombre del `volumeMount` debe coincidir exactamente con el volumen `shared-logs`; de lo contrario Kubernetes rechazará la definición del Pod.
  {: .lab-note .warning .compact}

  ```bash
  cat >> sidecar-pod.yaml <<'EOF'
        volumeMounts:
          - name: shared-logs
            mountPath: /var/log/shared
  EOF
  ```

  > **Salida esperada:** `log-sidecar` monta `shared-logs` en `/var/log/shared`.
  {: .lab-note .output .compact}

### Tarea 2.2. Definir la aplicación principal

Agregarás un contenedor productor que escribirá eventos periódicos en el volumen compartido. Sus propios logs estándar permitirán distinguir la salida de la aplicación de la salida procesada por el sidecar.

- {% include step_label.html %} Agrega el contenedor principal `app` utilizando BusyBox como proceso ligero para generar eventos de forma continua.

  > **Nota:** El propósito de la aplicación es producir datos observables y mantener el escenario centrado en el patrón sidecar, no en la lógica de una aplicación específica.
  {: .lab-note .info .compact}

  ```bash
  cat >> sidecar-pod.yaml <<'EOF'
    containers:
      - name: app
        image: busybox:1.38.0-musl
        imagePullPolicy: IfNotPresent
  EOF
  ```

  > **Salida esperada:** El manifiesto incorpora la sección `containers` con un contenedor denominado `app`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Configura la aplicación para generar un evento numerado cada tres segundos, escribirlo simultáneamente en `app.log` y mostrar una confirmación en su propia salida estándar.

  > **Importante:** La aplicación escribe los datos funcionales en el archivo compartido; el sidecar es responsable de leer ese archivo y reflejarlo en sus propios logs.
  {: .lab-note .important .compact}

  ```bash
  cat >> sidecar-pod.yaml <<'EOF'
        command:
          - /bin/sh
          - -c
          - |
            i=1
            while true; do
              event="$(date -u +%Y-%m-%dT%H:%M:%SZ) application-event-$i"
              echo "$event" >> /var/log/shared/app.log
              echo "APP generated: $event"
              i=$((i+1))
              sleep 3
            done
  EOF
  ```

  > **Salida esperada:** El contenedor `app` contiene un bucle que genera eventos numerados cada tres segundos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Monta el volumen `shared-logs` en `/var/log/shared` dentro de la aplicación para que pueda escribir los eventos en el mismo almacenamiento observado por el sidecar.

  > **Importante:** El nombre del volumen debe coincidir exactamente con `shared-logs`; ambos contenedores utilizarán el mismo `emptyDir` mediante esta referencia.
  {: .lab-note .important .compact}

  ```bash
  cat >> sidecar-pod.yaml <<'EOF'
        volumeMounts:
          - name: shared-logs
            mountPath: /var/log/shared
  EOF
  ```

  > **Salida esperada:** El contenedor `app` contiene un `volumeMount` denominado `shared-logs` en `/var/log/shared`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el manifiesto completo contra el API Server mediante un dry-run antes de crear el Pod real.

  > **Advertencia:** No continúes si Kubernetes devuelve un error de validación. Esta comprobación confirma que `restartPolicy: Always` es aceptado para el sidecar y que la estructura YAML es válida.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply --dry-run=server -f sidecar-pod.yaml
  ```

  > **Salida esperada:** Kubernetes responde con un resultado equivalente a `pod/sidecar-demo created (server dry run)` sin crear todavía el recurso.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🚀 Tarea 3. Desplegar e inspeccionar el Pod multicontenedor — 9 min

Crearás el Pod y comprobarás que tanto la aplicación como el sidecar permanecen activos de forma concurrente. Después analizarás su representación mediante get, describe y JSONPath para diferenciar sus estados individuales.

### Tarea 3.1. Desplegar y validar el estado del Pod

Aplicarás el manifiesto y observarás la transición hasta que el contenedor principal quede Ready y el sidecar se mantenga activo.

- {% include step_label.html %} Crea el Pod `sidecar-demo` utilizando el manifiesto validado y comienza la ejecución del escenario multicontenedor.

  > **Nota:** Kubernetes inicia el sidecar nativo desde `initContainers` y continúa con la aplicación principal una vez que el sidecar se considera iniciado.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f sidecar-pod.yaml
  ```

  > **Salida esperada:** Kubernetes responde `pod/sidecar-demo created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que el Pod alcance la condición `Ready` para confirmar que la aplicación principal inició mientras el sidecar nativo permanece activo.

  > **Importante:** Aunque el sidecar se define dentro de `initContainers`, permanece ejecutándose durante la vida del Pod. No continúes si se alcanza el timeout; utiliza `kubectl describe` para diagnosticar el estado.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait --for=condition=Ready pod/sidecar-demo -n lab5 --timeout=60s
  ```

  > **Salida esperada:** kubectl responde `pod/sidecar-demo condition met`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el estado resumido del Pod después de alcanzar la condición Ready para comprobar que permanece ejecutándose.

  > **Nota:** El valor `READY` representa los contenedores de aplicación listos; el sidecar nativo continúa registrado dentro de los estados de init containers.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod sidecar-demo -n lab5
  ```

  > **Salida esperada:** `sidecar-demo` aparece en estado `Running` y el contenedor principal se muestra listo.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el Pod en formato ampliado para identificar la dirección IP y el nodo donde Kubernetes ejecuta el workload.

  > **Nota:** Todos los contenedores que pertenecen al Pod comparten la identidad de red del Pod y se ejecutan en el mismo nodo.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod sidecar-demo -n lab5 -o wide
  ```

  > **Salida esperada:** Se muestra `sidecar-demo` en estado `Running`, junto con una dirección IP y el nodo asignado.
  {: .lab-note .output .compact}

### Tarea 3.2. Inspeccionar individualmente los contenedores

Examinarás las secciones de estado mantenidas por Kubernetes para distinguir el sidecar nativo de la aplicación principal y verificar que ambos procesos permanecen ejecutándose.

- {% include step_label.html %} Examina el Pod con `kubectl describe` y localiza las secciones correspondientes a `Init Containers`, `Containers`, `Conditions` y `Events`.

  > **Nota:** Un sidecar nativo continúa apareciendo dentro de `Init Containers` aunque permanezca activo simultáneamente con los contenedores de aplicación.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe pod sidecar-demo -n lab5
  ```

  > **Salida esperada:** `log-sidecar` aparece dentro de `Init Containers` en ejecución y `app` aparece dentro de `Containers` también en ejecución.
  {: .lab-note .output .compact}

- {% include step_label.html %} Extrae mediante JSONPath el nombre y estado del contenedor principal para verificar que la aplicación se encuentra actualmente ejecutándose.

  > **Importante:** Los estados de los contenedores principales se almacenan en `status.containerStatuses`, separados de los estados pertenecientes a init containers.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pod sidecar-demo -n lab5 -o jsonpath='App={.status.containerStatuses[0].name} Running={.status.containerStatuses[0].state.running.startedAt}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `App=app` seguido por la fecha y hora de inicio del contenedor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta mediante JSONPath el estado del sidecar nativo y compara su ubicación dentro de `initContainerStatuses`.

  > **Nota:** Los sidecars nativos utilizan el modelo de init containers reiniciables, por lo que su estado se consulta mediante `status.initContainerStatuses`.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod sidecar-demo -n lab5 -o jsonpath='Sidecar={.status.initContainerStatuses[0].name} Running={.status.initContainerStatuses[0].state.running.startedAt} Restarts={.status.initContainerStatuses[0].restartCount}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Sidecar=log-sidecar`, una fecha de inicio y normalmente `Restarts=0`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 📊 Tarea 4. Validar datos compartidos y logs multicontenedor — 10 min

Comprobarás que los dos procesos observan los mismos datos almacenados en el volumen y después utilizarás `kubectl logs` seleccionando explícitamente cada contenedor para distinguir la salida de la aplicación de la salida procesada por el sidecar.

### Tarea 4.1. Comprobar el volumen compartido

Inspeccionarás el archivo desde ambos contenedores para demostrar que el mecanismo de intercambio es el volumen `emptyDir` y no una copia independiente de los datos.

- {% include step_label.html %} Lee las últimas líneas de `app.log` desde el contenedor principal para observar los eventos producidos por la aplicación.

  > **Nota:** El archivo aumenta continuamente mientras `app` permanece activo. `MSYS_NO_PATHCONV=1` evita que Git Bash transforme la ruta Linux `/var/log/shared/app.log` en una ruta de Windows antes de enviarla al contenedor.
  {: .lab-note .info .compact}

  ```bash
  MSYS_NO_PATHCONV=1 kubectl exec -n lab5 sidecar-demo -c app -- tail -n 5 /var/log/shared/app.log
  ```

  > **Salida esperada:** Se muestran cinco eventos recientes con timestamp UTC y valores como `application-event-1`, `application-event-2` o posteriores.
  {: .lab-note .output .compact}

- {% include step_label.html %} Lee el mismo archivo desde `log-sidecar` para confirmar que ambos contenedores observan el contenido almacenado en `shared-logs`.

  > **Importante:** Los dos comandos acceden al mismo archivo desde contenedores diferentes. `MSYS_NO_PATHCONV=1` conserva la ruta Linux sin conversiones automáticas de Git Bash.
  {: .lab-note .important .compact}

  ```bash
  MSYS_NO_PATHCONV=1 kubectl exec -n lab5 sidecar-demo -c log-sidecar -- tail -n 5 /var/log/shared/app.log
  ```

  > **Salida esperada:** Se muestran eventos equivalentes a los observados desde `app`, confirmando que ambos contenedores acceden al mismo archivo.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta desde el manifiesto activo los nombres de los volúmenes montados por la aplicación y el sidecar para confirmar que ambos referencian `shared-logs`.

  > **Nota:** JSONPath permite validar la relación directamente desde la configuración registrada en el API Server.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod sidecar-demo -n lab5 -o jsonpath='AppVolume={.spec.containers[0].volumeMounts[0].name}{"\n"}SidecarVolume={.spec.initContainers[0].volumeMounts[0].name}{"\n"}'
  ```

  > **Salida esperada:** Se muestran `AppVolume=shared-logs` y `SidecarVolume=shared-logs`.
  {: .lab-note .output .compact}

### Tarea 4.2. Consultar logs específicos de cada contenedor

Distinguirás la salida estándar de la aplicación y del sidecar, observando cómo Kubernetes conserva un flujo de logs independiente para cada contenedor que forma parte del Pod.

- {% include step_label.html %} Consulta los últimos logs del contenedor `app` para identificar los mensajes emitidos directamente por la aplicación productora.

  > **Nota:** La opción `-c app` selecciona explícitamente el contenedor del que deseas obtener logs dentro del Pod multicontenedor.
  {: .lab-note .info .compact}

  ```bash
  kubectl logs sidecar-demo -n lab5 -c app --tail=5
  ```

  > **Salida esperada:** Se muestran líneas iniciadas por `APP generated:` con los eventos producidos recientemente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los últimos logs de `log-sidecar` y compara su salida con los eventos almacenados en el archivo compartido.

  > **Importante:** El sidecar no genera los eventos originales; los consume desde `app.log` y los expone a través de su propia salida estándar.
  {: .lab-note .important .compact}

  ```bash
  kubectl logs sidecar-demo -n lab5 -c log-sidecar --tail=8
  ```

  > **Salida esperada:** Se observan los mensajes de inicio del sidecar y eventos `application-event-N` leídos desde el archivo compartido.
  {: .lab-note .output .compact}

- {% include step_label.html %} Sigue durante aproximadamente diez segundos los logs del sidecar para observar cómo aparecen nuevos eventos mientras la aplicación continúa escribiendo información.

  > **Advertencia:** `kubectl logs -f` permanece conectado continuamente; `timeout 10s` detiene automáticamente el seguimiento después de aproximadamente diez segundos. Al finalizar por timeout, Git Bash recupera el prompt y no queda un proceso de seguimiento activo.
  {: .lab-note .warning .compact}

  ```bash
  timeout 10s kubectl logs sidecar-demo -n lab5 -c log-sidecar -f
  ```

  > **Salida esperada:** Durante varios segundos aparecen nuevos eventos generados por `app`; después el seguimiento termina automáticamente y Git Bash recupera el prompt.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🛠️ Tarea 5. Diagnosticar un fallo del sidecar y limpiar — 13 min

Introducirás un fallo controlado únicamente en el sidecar para observar sus reinicios mientras la aplicación principal continúa trabajando. Después utilizarás estado y logs del sidecar para encontrar la causa, restaurarás el manifiesto funcional y limpiarás el namespace.

### Tarea 5.1. Provocar un fallo controlado en el sidecar

Guardarás una copia conocida como funcional y modificarás el comando del sidecar para terminar deliberadamente después de iniciar, permitiendo observar la política de reinicio independiente.

- {% include step_label.html %} Conserva una copia del manifiesto funcional antes de introducir la configuración defectuosa utilizada para troubleshooting.

  > **Nota:** La copia `sidecar-pod-working.yaml` permitirá restaurar exactamente el estado conocido como correcto sin reconstruir manualmente el manifiesto.
  {: .lab-note .info .compact}

  ```bash
  cp sidecar-pod.yaml sidecar-pod-working.yaml
  ```

  > **Salida esperada:** Se crea `sidecar-pod-working.yaml` en el workspace actual.
  {: .lab-note .output .compact}

- {% include step_label.html %} Sustituye temporalmente el comando `tail -f` por una secuencia que informa un error y termina con código `1`, provocando reinicios únicamente en el sidecar.

  > **Advertencia:** El cambio es deliberadamente defectuoso. No lo reutilices fuera de este escenario de diagnóstico; el sidecar comenzará a reiniciarse por su `restartPolicy: Always`.
  {: .lab-note .warning .compact}

  ```bash
  sed -i 's#tail -f /var/log/shared/app.log#echo "ERROR: sidecar simulation failed"; sleep 2; exit 1#' sidecar-pod.yaml
  ```

  > **Salida esperada:** `sidecar-pod.yaml` contiene ahora el mensaje `ERROR: sidecar simulation failed` seguido por `exit 1`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el Pod funcional para permitir que Kubernetes cree una nueva instancia utilizando el manifiesto defectuoso.

  > **Advertencia:** Elimina únicamente `sidecar-demo` dentro de `lab5`; no elimines el namespace ni el clúster durante el escenario de diagnóstico.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete pod sidecar-demo -n lab5 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `pod "sidecar-demo" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el manifiesto defectuoso para crear nuevamente `sidecar-demo` con el fallo controlado en `log-sidecar`.

  > **Importante:** La aplicación principal debe poder iniciar aunque el sidecar termine con código `1` y sea reiniciado por Kubernetes.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f sidecar-pod.yaml
  ```

  > **Salida esperada:** Kubernetes responde `pod/sidecar-demo created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera diez segundos para permitir que el sidecar falle y sea reiniciado varias veces antes de consultar su estado.

  > **Nota:** La espera es intencional para que el contador de reinicios tenga tiempo de incrementarse y el escenario sea observable.
  {: .lab-note .info .compact}

  ```bash
  sleep 10
  ```

  > **Salida esperada:** El comando finaliza después de aproximadamente diez segundos y Git Bash recupera el prompt.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el estado general del Pod para comprobar que la aplicación principal continúa ejecutándose durante los reinicios del sidecar.

  > **Nota:** El Pod puede mostrar un estado relacionado con la inicialización o no estar completamente Ready mientras el sidecar se reinicia; el diagnóstico detallado se realizará en el siguiente paso.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod sidecar-demo -n lab5
  ```

  > **Salida esperada:** El Pod `sidecar-demo` continúa existiendo y el contador de reinicios aumenta mientras el sidecar defectuoso se recupera repetidamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Extrae el estado Ready de la aplicación y el contador de reinicios del sidecar para comprobar que el fallo permanece aislado al proceso auxiliar.

  > **Importante:** `AppReady=true` confirma que el contenedor principal sigue operativo, mientras `SidecarRestarts` debe mostrar al menos un reinicio.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pod sidecar-demo -n lab5 -o jsonpath='AppReady={.status.containerStatuses[0].ready} SidecarRestarts={.status.initContainerStatuses[0].restartCount}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `AppReady=true` y `SidecarRestarts` con un valor igual o mayor que `1`.
  {: .lab-note .output .compact}

### Tarea 5.2. Diagnosticar, restaurar y limpiar

Utilizarás la descripción y los logs del sidecar para localizar la causa del fallo. Finalmente restaurarás el manifiesto funcional, comprobarás que ambos procesos se estabilizan y eliminarás el namespace.

- {% include step_label.html %} Examina el Pod y localiza el estado, código de salida, contador de reinicios y eventos asociados específicamente con `log-sidecar`.

  > **Nota:** `kubectl describe` permite comprobar que el problema se encuentra en el sidecar mientras el contenedor `app` conserva un estado operativo independiente.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe pod sidecar-demo -n lab5
  ```

  > **Salida esperada:** `log-sidecar` muestra reinicios y una terminación anterior con código distinto de cero; el contenedor `app` aparece ejecutándose.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los logs actuales del sidecar para identificar el mensaje de error emitido antes de cada terminación controlada.

  > **Importante:** Se consultan los logs de la instancia actual porque son suficientes para identificar el fallo y evitan depender de la disponibilidad de logs históricos del runtime. El sidecar imprime el mismo mensaje en cada reinicio.
  {: .lab-note .important .compact}

  ```bash
  kubectl logs sidecar-demo -n lab5 -c log-sidecar
  ```

  > **Salida esperada:** Los logs contienen `ERROR: sidecar simulation failed`, permitiendo identificar directamente la causa introducida en el manifiesto.
  {: .lab-note .output .compact}

- {% include step_label.html %} Restaura el manifiesto funcional copiando la versión guardada sobre `sidecar-pod.yaml` antes de recrear el Pod.

  > **Importante:** Esta operación elimina del manifiesto el fallo controlado y recupera exactamente la configuración que funcionaba antes del ejercicio de troubleshooting.
  {: .lab-note .important .compact}

  ```bash
  cp sidecar-pod-working.yaml sidecar-pod.yaml
  ```

  > **Salida esperada:** El comando finaliza sin errores y `sidecar-pod.yaml` vuelve a contener el comando funcional del sidecar.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el Pod defectuoso para detener sus reinicios y permitir la creación de una instancia limpia con la configuración restaurada.

  > **Advertencia:** Elimina únicamente `sidecar-demo`; el namespace se conservará hasta completar las validaciones finales.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete pod sidecar-demo -n lab5 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `pod "sidecar-demo" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea nuevamente el Pod utilizando el manifiesto funcional restaurado.

  > **Nota:** El nuevo Pod inicia con contadores de reinicio propios y ya no contiene la terminación deliberada con `exit 1`.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f sidecar-pod.yaml
  ```

  > **Salida esperada:** Kubernetes responde `pod/sidecar-demo created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que el Pod restaurado alcance la condición `Ready` antes de evaluar sus estados finales.

  > **Importante:** No continúes con la limpieza si se alcanza el timeout; revisa primero el Pod con `kubectl describe` para confirmar la causa.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait --for=condition=Ready pod/sidecar-demo -n lab5 --timeout=60s
  ```

  > **Salida esperada:** kubectl responde `pod/sidecar-demo condition met`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el estado general del Pod restaurado para comprobar que la aplicación se encuentra ejecutándose normalmente.

  > **Nota:** Una vez alcanzada la condición Ready no es necesario introducir una espera artificial adicional; Kubernetes ya confirmó que el Pod cumple su condición de disponibilidad.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod sidecar-demo -n lab5
  ```

  > **Salida esperada:** `sidecar-demo` aparece en estado `Running`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida de forma independiente que la aplicación y el sidecar estén listos y que el sidecar restaurado no haya requerido reinicios.

  > **Importante:** Al tratarse de un Pod nuevo y funcional, el resultado esperado es `AppReady=true`, `SidecarRunning=true` y `SidecarRestarts=0`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pod sidecar-demo -n lab5 -o jsonpath='AppReady={.status.containerStatuses[0].ready} SidecarRunning={.status.initContainerStatuses[0].ready} SidecarRestarts={.status.initContainerStatuses[0].restartCount}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `AppReady=true SidecarRunning=true SidecarRestarts=0`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab5` únicamente después de completar todas las validaciones y confirmar que el escenario restaurado funciona correctamente.

  > **Advertencia:** Esta es la limpieza final de la práctica. Conserva `sidecar-pod.yaml` y `sidecar-pod-working.yaml` dentro de `workspace/lab5` como material de revisión.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab5 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab5" deleted`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}