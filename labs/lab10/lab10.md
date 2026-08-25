---
layout: lab
title: "Práctica 10: Jobs y CronJobs"
permalink: /lab10/lab10/
images_base: /labs/lab10/img
duration: "40 minutos"
objective:
  - Ejecutar cargas de trabajo finitas y programadas mediante Jobs y CronJobs, comprendiendo completions, parallelism, backoffLimit, restartPolicy, programación Cron, concurrencyPolicy e historial de ejecuciones, y resolver un reto final sin comandos de implementación.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica utilizarás Jobs para ejecutar tareas que deben finalizar y CronJobs para programar ejecuciones recurrentes. Crearás un Job simple, analizarás el Pod que genera y sus logs, controlarás múltiples completions y el nivel de parallelism, observarás el comportamiento de backoffLimit ante fallos y construirás un CronJob con política de concurrencia e historial controlado. Finalmente resolverás un reto parcialmente guiado y limpiarás el entorno únicamente después de completar todas las validaciones.
slug: lab10
lab_number: 10
final_result: >
  Al finalizar habrás creado y validado Jobs de ejecución única y múltiple, comprobado cómo Kubernetes registra completions y limita la ejecución simultánea mediante parallelism, observado reintentos controlados por backoffLimit y administrado un CronJob que crea Jobs de forma periódica. También habrás resuelto un reto basado en requisitos sin recibir los comandos de implementación y eliminado el namespace únicamente después de terminar completamente la práctica.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza busybox:1.38.0-musl para ejecutar comandos cortos y observables dentro de Jobs y CronJobs.
  - Los Jobs requieren que la plantilla de Pod utilice restartPolicy Never u OnFailure; no se utiliza Always.
  - Cada paso mantiene una acción principal y las operaciones de creación, aplicación, espera, validación y limpieza permanecen separadas.
  - Las Tareas 1 a 4 contienen 26 pasos guiados. La Tarea 5 contiene 6 pasos de reto y 2 pasos finales de limpieza.
references:
  - text: Jobs en Kubernetes
    url: https://kubernetes.io/docs/concepts/workloads/controllers/job/
  - text: CronJobs en Kubernetes
    url: https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
  - text: Referencia oficial de kubectl create job
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_job/
  - text: Referencia oficial de kubectl create cronjob
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_cronjob/
prev: /lab9/lab9/
next: /lab11/lab11/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar el entorno y reconocer Jobs — 6 min

Prepararás un workspace aislado para la práctica y consultarás directamente el esquema de Kubernetes para distinguir un Job de un workload de ejecución continua. El objetivo es comprender qué propiedades controlan cuándo una tarea se considera terminada y cómo se gestionan sus intentos.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, verificarás que kubectl apunta al clúster correcto y prepararás el namespace donde se ejecutarán todas las cargas de trabajo de esta práctica.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab10` y accede a él para mantener separados los manifiestos y archivos generados en esta práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab10`; los archivos locales se conservarán al finalizar para que puedas revisarlos posteriormente.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab10 && cd workspace/lab10
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab10`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo para confirmar que las operaciones siguientes se realizarán exclusivamente sobre el clúster local utilizado por el curso.

  > **Importante:** El valor esperado es `kind-ckad`. Trabajar sobre un contexto diferente podría crear o eliminar recursos en otro clúster.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab10` para aislar Jobs, CronJobs y Pods del resto de las prácticas del curso.

  > **Advertencia:** Si el namespace ya existe por una ejecución anterior, revisa su contenido antes de continuar para evitar interpretar recursos antiguos como resultados de esta práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab10
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab10 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Explorar las propiedades de un Job

Consultarás campos relevantes del recurso Job para comprender que Kubernetes administra tareas destinadas a finalizar correctamente, en lugar de mantener procesos ejecutándose de forma indefinida.

- {% include step_label.html %} Consulta la definición de `completions` para identificar cómo un Job determina cuántas ejecuciones exitosas necesita antes de considerarse completado.

  > **Nota:** Un Job puede representar desde una única ejecución hasta varias unidades de trabajo; `completions` define cuántas finalizaciones exitosas requiere el controlador.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain job.spec.completions
  ```

  > **Salida esperada:** kubectl muestra la descripción del campo `completions` y su tipo entero.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta de forma recursiva la especificación del Job para localizar `parallelism`, `backoffLimit` y la plantilla de Pod utilizada para ejecutar el trabajo.

  > **Importante:** `parallelism` limita cuántos Pods pueden trabajar simultáneamente y `backoffLimit` controla cuántos fallos se toleran antes de declarar fallido el Job.
  {: .lab-note .important .compact}

  ```bash
  kubectl explain job.spec --recursive | head -n 45
  ```

  > **Salida esperada:** La salida incluye campos como `backoffLimit`, `completions`, `parallelism` y `template`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## ⚙️ Tarea 2. Crear y validar un Job de ejecución única — 8 min

Construirás un Job sencillo que ejecuta una tarea finita, esperarás a que Kubernetes registre su finalización y revisarás el Pod y los logs resultantes. Esta secuencia permite observar que un Job terminado permanece disponible para consultar su resultado.

### Tarea 2.1. Generar y crear el Job

Generarás un manifiesto base mediante kubectl, revisarás las propiedades relevantes del Pod template y crearás el recurso de forma declarativa.

- {% include step_label.html %} Genera el manifiesto `simple-job.yaml` para un Job denominado `simple-job` que ejecute un mensaje corto y finalice, sin crear todavía recursos en el clúster.

  > **Nota:** `--dry-run=client -o yaml` es útil para producir rápidamente una estructura válida que después puede revisarse o modificarse antes de enviarla al API Server.
  {: .lab-note .info .compact}

  ```bash
  kubectl create job simple-job --image=busybox:1.38.0-musl -n lab10 --dry-run=client -o yaml -- sh -c 'echo "Inicio del Job"; date; echo "Trabajo completado"' > simple-job.yaml
  ```

  > **Salida esperada:** Se crea el archivo local `simple-job.yaml` y todavía no existe `job.batch/simple-job` en Kubernetes.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa en el manifiesto el comando del contenedor y la política de reinicio que utilizará el Pod controlado por el Job.

  > **Importante:** Un Job admite `restartPolicy: Never` u `OnFailure`. A diferencia de workloads de larga duración, no utiliza `Always` porque la tarea debe poder finalizar.
  {: .lab-note .important .compact}

  ```bash
  grep -E 'image:|restartPolicy:|command:|args:' simple-job.yaml
  ```

  > **Salida esperada:** Se identifica `busybox:1.38.0-musl`, el comando generado y una política de reinicio válida para Job.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el manifiesto para crear el Job y permitir que su controlador genere el Pod encargado de ejecutar la tarea.

  > **Nota:** El usuario crea el objeto Job; el Pod subordinado es generado automáticamente por el controlador a partir de `spec.template`.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f simple-job.yaml
  ```

  > **Salida esperada:** Kubernetes responde `job.batch/simple-job created`.
  {: .lab-note .output .compact}

### Tarea 2.2. Comprobar finalización y resultado

Esperarás explícitamente la condición de finalización y después inspeccionarás tanto el Pod generado como la salida producida por la tarea.

- {% include step_label.html %} Espera hasta que el Job alcance la condición `Complete`, evitando asumir que terminó únicamente porque el recurso ya existe.

  > **Importante:** `kubectl wait` sincroniza la práctica con el estado real del controlador y evita utilizar pausas arbitrarias mediante `sleep`.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait --for=condition=complete job/simple-job -n lab10 --timeout=60s
  ```

  > **Salida esperada:** kubectl confirma que `job.batch/simple-job` alcanzó la condición solicitada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el Pod creado por el Job y observa que su estado final es `Completed` en lugar de permanecer ejecutándose indefinidamente.

  > **Nota:** El Pod terminado se conserva mientras exista el Job, lo que permite revisar posteriormente información de ejecución, estado y logs.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab10 -l job-name=simple-job
  ```

  > **Salida esperada:** Se muestra un Pod asociado con `simple-job` y su estado es `Completed`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los logs del Job para recuperar la salida generada por el contenedor durante su única ejecución.

  > **Nota:** kubectl permite solicitar logs utilizando directamente el recurso `job/simple-job`, sin necesidad de copiar primero el nombre generado del Pod.
  {: .lab-note .info .compact}

  ```bash
  kubectl logs job/simple-job -n lab10
  ```

  > **Salida esperada:** Se muestran el mensaje `Inicio del Job`, una fecha generada por `date` y `Trabajo completado`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🧮 Tarea 3. Controlar completions, parallelism y reintentos — 8 min

Ampliarás el comportamiento de Jobs para ejecutar varias unidades de trabajo con concurrencia limitada y después provocarás un fallo controlado. Así distinguirás entre cantidad de ejecuciones exitosas, paralelismo máximo y tolerancia a intentos fallidos.

### Tarea 3.1. Ejecutar múltiples completions

Crearás un Job que requiere cuatro finalizaciones exitosas y permite como máximo dos Pods ejecutándose al mismo tiempo, observando cómo Kubernetes administra las unidades pendientes.

- {% include step_label.html %} Crea `multi-job.yaml` con cuatro completions y parallelism igual a dos para representar un trabajo dividido en varias ejecuciones independientes.

  > **Nota:** `completions: 4` define el total requerido y `parallelism: 2` permite que Kubernetes procese hasta dos Pods simultáneamente hasta alcanzar esas cuatro finalizaciones.
  {: .lab-note .info .compact}

  ```bash
  cat > multi-job.yaml <<'EOF'
  apiVersion: batch/v1
  kind: Job
  metadata:
    name: multi-job
    namespace: lab10
  spec:
    completions: 4
    parallelism: 2
    template:
      spec:
        restartPolicy: Never
        containers:
          - name: worker
            image: busybox:1.38.0-musl
            command:
              - sh
              - -c
              - 'echo "Procesando unidad en $(hostname)"; sleep 5'
  EOF
  ```

  > **Salida esperada:** Se crea localmente `multi-job.yaml` con cuatro completions, parallelism dos y `restartPolicy: Never`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el manifiesto para iniciar el procesamiento de las cuatro unidades de trabajo definidas.

  > **Importante:** No necesitas crear cuatro Pods manualmente; el controlador del Job crea nuevas ejecuciones conforme hacen falta hasta alcanzar el número de completions.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f multi-job.yaml
  ```

  > **Salida esperada:** Kubernetes responde `job.batch/multi-job created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que las cuatro ejecuciones requeridas terminen satisfactoriamente.

  > **Nota:** Aunque el Job requiere cuatro completions, solo puede mantener hasta dos Pods activos simultáneamente por el valor de `parallelism`.
  {: .lab-note .info .compact}

  ```bash
  kubectl wait --for=condition=complete job/multi-job -n lab10 --timeout=90s
  ```

  > **Salida esperada:** kubectl confirma que `multi-job` alcanzó la condición `Complete`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el estado final para relacionar `COMPLETIONS` con los cuatro Pods que ejecutaron las unidades de trabajo.

  > **Nota:** Una vez terminadas todas las ejecuciones, los Pods completados pueden permanecer visibles mientras exista el Job.
  {: .lab-note .info .compact}

  ```bash
  kubectl get job,pods -n lab10 -l job-name=multi-job
  ```

  > **Salida esperada:** El Job refleja cuatro completions exitosas y se observan los Pods terminados que participaron en la ejecución.
  {: .lab-note .output .compact}

### Tarea 3.2. Observar backoffLimit ante un fallo

Crearás un segundo Job cuyo comando falla deliberadamente y limitarás los intentos mediante `backoffLimit`, permitiendo observar cuándo Kubernetes deja de reintentar y declara fallida la tarea.

- {% include step_label.html %} Crea `failed-job.yaml` con un comando que termina con código distinto de cero y configura `backoffLimit: 2` para limitar los reintentos del controlador.

  > **Advertencia:** El fallo es intencional. No corrijas `exit 1`; necesitas conservarlo para observar el comportamiento de reintentos del Job.
  {: .lab-note .warning .compact}

  ```bash
  cat > failed-job.yaml <<'EOF'
  apiVersion: batch/v1
  kind: Job
  metadata:
    name: failed-job
    namespace: lab10
  spec:
    backoffLimit: 2
    template:
      spec:
        restartPolicy: Never
        containers:
          - name: worker
            image: busybox:1.38.0-musl
            command:
              - sh
              - -c
              - 'echo "Fallo controlado"; exit 1'
  EOF
  ```

  > **Salida esperada:** Se crea `failed-job.yaml` con `backoffLimit: 2`, `restartPolicy: Never` y un comando que finaliza con error.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el Job defectuoso para iniciar la secuencia controlada de intentos fallidos.

  > **Importante:** Kubernetes puede espaciar los nuevos intentos mediante backoff; el fallo no implica que todos los Pods aparezcan de manera instantánea.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f failed-job.yaml
  ```

  > **Salida esperada:** Kubernetes responde `job.batch/failed-job created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que Kubernetes marque el Job como fallido después de superar el límite de reintentos configurado.

  > **Nota:** La condición `Failed` confirma que el controlador agotó la política de reintentos y dejó de intentar completar el trabajo.
  {: .lab-note .info .compact}

  ```bash
  kubectl wait --for=condition=failed job/failed-job -n lab10 --timeout=90s
  ```

  > **Salida esperada:** kubectl confirma que `job.batch/failed-job` alcanzó la condición `Failed`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## ⏰ Tarea 4. Crear y observar un CronJob — 9 min

Crearás una tarea recurrente programada cada minuto y configurarás políticas que controlan concurrencia e historial. Después observarás cómo el controlador CronJob crea objetos Job y cómo estos generan sus propios Pods.

### Tarea 4.1. Definir el CronJob

Generarás un manifiesto inicial y agregarás propiedades de administración que permiten limitar ejecuciones simultáneas y conservar únicamente una cantidad controlada de resultados anteriores.

- {% include step_label.html %} Genera `report-cronjob.yaml` para un CronJob denominado `report-cronjob` programado cada minuto, sin crearlo todavía en Kubernetes.

  > **Nota:** La expresión `*/1 * * * *` ejecuta el CronJob cada minuto y permite observar una ejecución durante el tiempo disponible de la práctica.
  {: .lab-note .info .compact}

  ```bash
  kubectl create cronjob report-cronjob --image=busybox:1.38.0-musl --schedule='*/1 * * * *' -n lab10 --dry-run=client -o yaml -- sh -c 'echo "Reporte programado"; date' > report-cronjob.yaml
  ```

  > **Salida esperada:** Se crea localmente `report-cronjob.yaml` con la programación `*/1 * * * *`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Abre el manifiesto y agrega `concurrencyPolicy: Forbid`, `successfulJobsHistoryLimit: 2` y `failedJobsHistoryLimit: 1` dentro de `spec`.

  > **Importante:** `Forbid` evita que una nueva ejecución del mismo CronJob comience mientras una anterior continúa activa; los límites de historial controlan cuántos Jobs terminados conserva el controlador.
  {: .lab-note .important .compact}

  ```bash
  code report-cronjob.yaml
  ```

  > **Salida esperada:** Visual Studio Code abre `report-cronjob.yaml` para permitir incorporar las tres propiedades solicitadas dentro de `spec`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el manifiesto contra el API Server sin persistirlo para confirmar que las propiedades agregadas pertenecen a la estructura correcta.

  > **Advertencia:** Revisa la indentación si la validación falla; `concurrencyPolicy` y los límites de historial pertenecen directamente a `CronJob.spec`, no a `jobTemplate.spec`.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply --dry-run=server -f report-cronjob.yaml
  ```

  > **Salida esperada:** Kubernetes devuelve un resultado equivalente a `cronjob.batch/report-cronjob created (server dry run)`.
  {: .lab-note .output .compact}

### Tarea 4.2. Ejecutar y revisar la programación

Crearás el CronJob, observarás su configuración activa y esperarás a que el controlador produzca al menos un Job conforme a la programación establecida.

- {% include step_label.html %} Aplica el manifiesto validado para registrar el CronJob y permitir que el controlador comience a evaluar su programación.

  > **Nota:** El CronJob no ejecuta directamente un contenedor; en cada ocurrencia crea un Job y ese Job es quien genera el Pod de trabajo.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f report-cronjob.yaml
  ```

  > **Salida esperada:** Kubernetes responde `cronjob.batch/report-cronjob created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el CronJob para comprobar la expresión programada, la suspensión y la información de la última ejecución conocida.

  > **Nota:** Inmediatamente después de crearlo, `LAST SCHEDULE` puede aparecer vacío hasta que llegue la siguiente coincidencia de la expresión Cron.
  {: .lab-note .info .compact}

  ```bash
  kubectl get cronjob report-cronjob -n lab10
  ```

  > **Salida esperada:** Se muestra `report-cronjob`, la programación `*/1 * * * *` y `SUSPEND` en `False`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Observa los Jobs del namespace hasta que aparezca una ejecución cuyo nombre comience con `report-cronjob`; cuando la identifiques, finaliza la observación con `Ctrl+C`.

  > **Importante:** Dependiendo del segundo exacto en que creaste el CronJob, la primera ejecución puede tardar hasta aproximadamente un minuto en aparecer.
  {: .lab-note .important .compact}

  ```bash
  kubectl get jobs -n lab10 --watch
  ```

  > **Salida esperada:** Aparece un Job generado automáticamente con un nombre similar a `report-cronjob-########` y alcanza una finalización exitosa.
  {: .lab-note .output .compact}

- {% include step_label.html %} Lista los Pods creados por las ejecuciones programadas y comprueba que la cadena CronJob → Job → Pod produjo una tarea terminada.

  > **Nota:** El nombre del Pod incorpora el nombre del Job que lo creó, permitiendo reconocer visualmente la relación entre los tres niveles.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab10 --sort-by=.metadata.creationTimestamp
  ```

  > **Salida esperada:** Se muestra al menos un Pod cuyo nombre comienza con `report-cronjob` y cuyo estado final es `Completed`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los logs del Pod programado utilizando el nombre observado en el paso anterior para verificar que ejecutó el comando definido en el CronJob.

  > **Nota:** Sustituye `<POD_CRONJOB>` por el nombre de un Pod cuyo prefijo sea `report-cronjob`; no utilices un Pod perteneciente a los Jobs anteriores.
  {: .lab-note .info .compact}

  ```bash
  kubectl logs <POD_CRONJOB> -n lab10
  ```

  > **Salida esperada:** Se muestran `Reporte programado` y la fecha correspondiente a la ejecución.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🎯 Tarea 5. Reto de consolidación con Jobs y CronJobs — 9 min

Resolverás dos requerimientos similares a los que podrías recibir en una evaluación práctica. Los pasos proporcionan escenario y criterios de validación, pero la elección de comandos, generación de YAML y correcciones queda bajo tu responsabilidad.

### Tarea 5.1. Resolver un Job con múltiples ejecuciones

Construirás un Job a partir de requisitos funcionales y demostrarás que comprendes la diferencia entre cantidad total de completions y número máximo de ejecuciones simultáneas.

- {% include step_label.html %} Analiza los requisitos del primer reto y determina qué propiedades del Job necesitas configurar para alcanzar el estado solicitado.

  > **Importante:** A partir de este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl --help`, `kubectl explain` y generación mediante `--dry-run=client`.
  {: .lab-note .important .compact}

  ```text
  Reto 1:

  Crea un Job en el namespace lab10 que cumpla:

  - Nombre: report-job
  - Imagen: busybox:1.38.0-musl
  - Debe completar 3 ejecuciones exitosas.
  - Máximo 2 Pods pueden trabajar simultáneamente.
  - restartPolicy debe ser Never.
  - Cada ejecución debe imprimir: Reporte CKAD completado
  - El Job debe finalizar correctamente.
  ```

  > **Salida esperada:** Identificas que necesitas configurar una plantilla de Pod y controlar tanto completions como parallelism.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `report-job` y espera hasta considerar que las tres ejecuciones solicitadas han terminado correctamente.

  > **Nota:** Puedes generar un manifiesto y modificarlo o escribirlo directamente; el método forma parte de tu estrategia de resolución.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora el Job.

  No continúes hasta considerar satisfechos
  todos los requisitos del Reto 1.
  ```

  > **Salida esperada:** Existe `job.batch/report-job` y alcanza tres completions exitosas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el estado final del Job y corrige cualquier propiedad que todavía no coincida con los requisitos.

  > **Advertencia:** No evalúes únicamente que el Job aparezca como completo; comprueba también `COMPLETIONS`, `parallelism` y la configuración de su plantilla.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get job report-job -n lab10
  ```

  > **Salida esperada:** `report-job` muestra `3/3` completions.
  {: .lab-note .output .compact}

### Tarea 5.2. Resolver un CronJob programado

Crearás una segunda carga de trabajo programada sin recibir el comando de solución y comprobarás que Kubernetes acepta la programación y las políticas solicitadas.

- {% include step_label.html %} Implementa un CronJob denominado `backup-cron` siguiendo los requisitos del escenario y sin modificar `report-cronjob`.

  > **Importante:** El reto evalúa el estado final del recurso. Decide por tu cuenta si generar primero YAML o construir directamente el manifiesto.
  {: .lab-note .important .compact}

  ```text
  Reto 2:

  Crea un CronJob en lab10 con:

  - Nombre: backup-cron
  - Imagen: busybox:1.38.0-musl
  - Programación: cada 5 minutos
  - concurrencyPolicy: Forbid
  - successfulJobsHistoryLimit: 1
  - failedJobsHistoryLimit: 1
  - El comando debe imprimir: Backup CKAD
  - Debe permanecer habilitado.
  ```

  > **Salida esperada:** Existe `cronjob.batch/backup-cron` configurado de acuerdo con todos los requisitos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona las propiedades declaradas del CronJob para comprobar que la programación, la política de concurrencia y los límites de historial coinciden exactamente con el escenario.

  > **Nota:** Este paso es únicamente de validación. Si algún valor no coincide, corrige por tu cuenta el recurso antes de continuar; la forma de resolver la diferencia sigue siendo parte del reto.
  {: .lab-note .info .compact}

  ```bash
  kubectl get cronjob backup-cron -n lab10 -o jsonpath='Schedule={.spec.schedule} Concurrency={.spec.concurrencyPolicy} SuccessHistory={.spec.successfulJobsHistoryLimit} FailedHistory={.spec.failedJobsHistoryLimit} Suspend={.spec.suspend}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Schedule=*/5 * * * *`, `Concurrency=Forbid`, límites de historial iguales a `1` y `Suspend` con valor `false`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Realiza la validación final del reto y corrige cualquier diferencia antes de considerar terminada la práctica.

  > **Advertencia:** No pases todavía a la limpieza si necesitas revisar o corregir alguno de los dos retos; la siguiente subtarea elimina todos los recursos del namespace.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get job report-job -n lab10
  kubectl get cronjob backup-cron -n lab10
  ```

  > **Salida esperada:** `report-job` aparece completado con `3/3` y `backup-cron` muestra la programación `*/5 * * * *` con `SUSPEND` en `False`.
  {: .lab-note .output .compact}

### Tarea 5.3. Limpiar el entorno de la práctica

Ejecuta esta subtarea únicamente cuando hayas terminado los dos retos, validado todos los requisitos y ya no necesites conservar los recursos activos para revisión.

- {% include step_label.html %} Cuando hayas terminado completamente el reto y confirmado los resultados de toda la práctica, elimina el namespace `lab10` para retirar Jobs, CronJobs y Pods creados durante el laboratorio.

  > **Advertencia:** No ejecutes este paso antes de terminar las validaciones. Eliminar el namespace elimina todos los recursos namespaced utilizados durante esta práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab10 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab10" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que `lab10` ya no existe para confirmar que el entorno Kubernetes quedó limpio antes de continuar con la siguiente práctica.

  > **Importante:** No elimines `workspace/lab10`; los manifiestos locales deben conservarse como evidencia y material de repaso.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab10 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab10`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}