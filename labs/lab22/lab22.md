---
layout: lab
title: "Práctica 22: Depuración de aplicaciones fallidas"
permalink: /lab22/lab22/
images_base: /labs/lab22/img
duration: "70 minutos"
objective:
  - Aplicar un método sistemático de troubleshooting para observar síntomas, recopilar evidencia, identificar causas raíz, realizar correcciones mínimas y validar la recuperación de aplicaciones con fallos de imagen, proceso, configuración, probes y conectividad mediante Services.
prerequisites:
  - Haber completado la Práctica 20 Implementación de probes.
  - Haber completado la Práctica 21 Análisis de logs y eventos.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica aplicarás troubleshooting de forma sistemática sobre aplicaciones deliberadamente defectuosas. Primero aprenderás un flujo repetible basado en observación, inspección, evidencia, causa raíz, corrección y validación. Después resolverás retos con fallos de imagen, procesos que reinician, referencias de configuración incorrectas, readiness defectuosa y una aplicación multicapa donde deberás determinar qué componente impide la comunicación sin recibir los comandos de solución.
slug: lab22
lab_number: 22
final_result: >
  Al finalizar habrás aplicado un proceso reproducible de diagnóstico sobre distintos tipos de fallos de Kubernetes utilizando get, describe, eventos, logs actuales y anteriores, configuración activa y EndpointSlices. Habrás corregido únicamente la causa necesaria en cada escenario y demostrado la recuperación mediante estado Ready, estabilidad de contenedores y comunicación funcional entre aplicaciones.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza nginx:1.31.4-alpine3.24-slim para aplicaciones HTTP y busybox:1.38.0-musl para escenarios controlados.
  - Un contenedor que nunca inicia puede no disponer de logs de aplicación; en problemas como ImagePullBackOff los eventos suelen aportar la evidencia principal.
  - kubectl logs --previous permite recuperar los logs de la instancia anterior de un contenedor cuando este ya fue reiniciado.
  - Un Pod Running no implica necesariamente Ready; una readinessProbe defectuosa puede impedir que un Pod reciba tráfico sin detener su proceso.
  - Los Services con selector utilizan EndpointSlices para representar sus backends; un selector incorrecto puede dejar al Service sin endpoints aunque los Pods estén Running.
  - Los primeros 9 pasos son guiados y los siguientes 21 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 30/70.
references:
  - text: Debug Running Pods
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/
  - text: Debug Pods
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
  - text: kubectl logs
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/
  - text: Liveness, Readiness, and Startup Probes
    url: https://kubernetes.io/docs/concepts/workloads/pods/probes/
  - text: EndpointSlices
    url: https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
  - text: Services
    url: https://kubernetes.io/docs/concepts/services-networking/service/
prev: /lab21/lab21/
next: /lab23/lab23/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Aplicar un método sistemático de troubleshooting — 16 min

Aprenderás un flujo reutilizable para diagnosticar aplicaciones: observar el síntoma, inspeccionar el recurso, recopilar evidencia, identificar la causa raíz, realizar el cambio mínimo y validar la recuperación.

### Tarea 1.1. Preparar el entorno de trabajo

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea `workspace/lab22` y accede al directorio para almacenar manifiestos defectuosos, correcciones y evidencias.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab22`; los archivos locales se conservarán después de limpiar Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab22 && cd workspace/lab22
  ```

  > **Salida esperada:** La terminal queda ubicada dentro de `ckad-labs/workspace/lab22`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo antes de crear los escenarios deliberadamente defectuosos.

  > **Importante:** El contexto esperado es `kind-ckad`. No continúes si kubectl apunta a otro clúster.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab22` para aislar todos los recursos de troubleshooting.

  > **Advertencia:** Si `lab22` ya existe, revisa sus recursos antes de continuar para no mezclar estados o eventos anteriores.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab22
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab22 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Observar, inspeccionar y recopilar evidencia

- {% include step_label.html %} Crea un Pod guiado que escriba un error explícito y termine con código distinto de cero para disponer de un fallo controlado.

  > **Nota:** El escenario es sencillo porque aquí se practica el método de diagnóstico, no la dificultad del error.
  {: .lab-note .info .compact}

  ```bash
  cat > guided-failure.yaml <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: guided-failure
    namespace: lab22
  spec:
    restartPolicy: Never
    containers:
      - name: app
        image: busybox:1.38.0-musl
        command:
          - sh
          - -c
          - |
            echo "INFO starting application"
            echo "ERROR required configuration missing"
            exit 1
  EOF
  ```
  ```bash
  kubectl apply -f guided-failure.yaml
  ```

  > **Salida esperada:** Se crea `guided-failure` y el contenedor termina después de emitir los mensajes.
  {: .lab-note .output .compact}

- {% include step_label.html %} Observa primero el estado general del Pod para describir el síntoma antes de intentar corregirlo.

  > **Importante:** Troubleshooting comienza describiendo qué ocurre, no modificando inmediatamente el recurso.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pod guided-failure -n lab22 -o wide
  ```

  > **Salida esperada:** El Pod aparece terminado con estado `Error` o equivalente y no está Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona el Pod y consulta sus logs para combinar evidencia de Kubernetes con la salida de la aplicación.

  > **Nota:** `describe` aporta estado, condiciones y eventos; `logs` aporta stdout y stderr del proceso.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe pod guided-failure -n lab22
  ```
  ```bash
  kubectl logs guided-failure -n lab22
  ```

  > **Salida esperada:** La terminación aparece en el estado y los logs incluyen `ERROR required configuration missing`.
  {: .lab-note .output .compact}

### Tarea 1.3. Identificar causa, corregir y validar

- {% include step_label.html %} Confirma la razón y el código de salida para respaldar la causa raíz con evidencia objetiva.

  > **Importante:** La causa debe explicar el síntoma observado y estar respaldada por el estado del contenedor.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pod guided-failure -n lab22 -o jsonpath='Reason={.status.containerStatuses[0].state.terminated.reason} ExitCode={.status.containerStatuses[0].state.terminated.exitCode}{"\n"}'
  ```

  > **Salida esperada:** La salida muestra una terminación con código `1`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Corrige el manifiesto guiado para que el proceso registre una configuración válida y permanezca activo.

  > **Nota:** Aquí el cambio se entrega explícitamente; en los siguientes escenarios deberás inferirlo.
  {: .lab-note .info .compact}

  ```bash
  cat > guided-failure.yaml <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: guided-failure
    namespace: lab22
  spec:
    restartPolicy: Never
    containers:
      - name: app
        image: busybox:1.38.0-musl
        command:
          - sh
          - -c
          - |
            echo "INFO configuration loaded"
            sleep 3600
  EOF
  ```
  ```bash
  kubectl delete pod guided-failure -n lab22 --wait=true
  ```
  ```bash
  kubectl apply -f guided-failure.yaml
  ```

  > **Salida esperada:** Se recrea `guided-failure` con el comportamiento corregido.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida que la corrección resolvió el problema comprobando readiness y logs de la nueva ejecución.

  > **Importante:** El diagnóstico termina cuando demuestras recuperación, no cuando simplemente aplicas un cambio.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait --for=condition=Ready pod/guided-failure -n lab22 --timeout=30s
  ```
  ```bash
  kubectl logs guided-failure -n lab22
  ```

  > **Salida esperada:** El Pod alcanza Ready y los logs muestran `INFO configuration loaded`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: resolver fallos de imagen y proceso — 15 min

Aplicarás el método anterior sin recibir comandos de solución: primero evidencia, después causa raíz, corrección mínima y validación.

### Tarea 2.1. Diagnosticar un fallo de imagen

- {% include step_label.html %} Crea el Deployment defectuoso `frontend` y conserva el fallo el tiempo suficiente para observarlo.

  > **Advertencia:** No corrijas la imagen al leer el manifiesto; primero debes demostrar la causa mediante estado y eventos.
  {: .lab-note .warning .compact}

  ```bash
  cat > frontend-broken.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: frontend
    namespace: lab22
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: frontend
    template:
      metadata:
        labels:
          app: frontend
      spec:
        containers:
          - name: nginx
            image: nginx:lab22-version-does-not-exist
  EOF
  ```
  ```bash
  kubectl apply -f frontend-broken.yaml
  ```

  > **Salida esperada:** `deployment/frontend` existe, pero sus Pods no alcanzan Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Investiga las réplicas y recopila evidencia suficiente para determinar en qué fase del ciclo de vida ocurre el fallo.

  > **Importante:** Decide qué fuente aporta más valor si el proceso de aplicación nunca llegó a iniciar.
  {: .lab-note .important .compact}

  ```text
  Determina:
  - estado de los Pods;
  - razón visible;
  - eventos relevantes;
  - si NGINX llegó a iniciar.
  ```

  > **Salida esperada:** Identificas `ErrImagePull` o `ImagePullBackOff` y eventos que señalan una imagen inexistente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Formula la causa raíz y define el cambio mínimo para recuperar `frontend` sin alterar su número de réplicas.

  > **Nota:** La causa debe explicar por qué ambas réplicas presentan el mismo síntoma.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:
  - Deployment frontend conservado;
  - replicas=2;
  - imagen nginx:1.31.4-alpine3.24-slim;
  - ambas réplicas Ready.
  ```

  > **Salida esperada:** Concluyes que el tag de imagen es la causa raíz y defines la sustitución necesaria.
  {: .lab-note .output .compact}

### Tarea 2.2. Diagnosticar un proceso que reinicia

- {% include step_label.html %} Implementa por tu cuenta la corrección mínima de `frontend` y demuestra que el rollout finaliza correctamente.

  > **Importante:** No recrees el namespace ni sustituyas el Deployment por Pods independientes.
  {: .lab-note .important .compact}

  ```bash
  kubectl rollout status deployment/frontend -n lab22 --timeout=60s
  ```

  > **Salida esperada:** `frontend` dispone de dos réplicas Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el escenario `worker`, cuyo proceso registra un error y termina repetidamente.

  > **Advertencia:** Mantén el fallo activo el tiempo suficiente para disponer de una ejecución anterior.
  {: .lab-note .warning .compact}

  ```bash
  cat > worker-broken.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: worker
    namespace: lab22
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: worker
    template:
      metadata:
        labels:
          app: worker
      spec:
        containers:
          - name: worker
            image: busybox:1.38.0-musl
            command:
              - sh
              - -c
              - |
                echo "INFO worker starting"
                sleep 3
                echo "ERROR queue configuration invalid"
                exit 1
  EOF
  ```
  ```bash
  kubectl apply -f worker-broken.yaml
  ```

  > **Salida esperada:** Se crea `worker` y su Pod comienza a registrar reinicios.
  {: .lab-note .output .compact}

- {% include step_label.html %} Analiza `worker`, selecciona la ejecución de logs adecuada e identifica la causa del reinicio.

  > **Nota:** La instancia actual y la inmediatamente anterior pueden contener evidencia diferente.
  {: .lab-note .info .compact}

  ```text
  Obtén evidencia de:
  - RESTARTS > 0;
  - estado anterior;
  - mensaje previo al fallo;
  - causa probable.
  ```

  > **Salida esperada:** Identificas `ERROR queue configuration invalid` y relacionas la terminación con los reinicios.
  {: .lab-note .output .compact}

- {% include step_label.html %} Corrige por tu cuenta `worker` para que registre una configuración válida y permanezca ejecutándose.

  > **Importante:** Conserva el Deployment y modifica únicamente el comportamiento causante de la terminación.
  {: .lab-note .important .compact}

  ```text
  Estado final:
  - Pod Running;
  - proceso estable;
  - sin reinicios continuos;
  - log con configuración válida.
  ```

  > **Salida esperada:** El nuevo Pod de `worker` permanece estable.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## ⚙️ Tarea 3. Reto: diagnosticar configuración y readiness — 16 min

Resolverás un fallo de dependencia de configuración y otro donde el proceso está Running pero Kubernetes no considera al Pod preparado.

### Tarea 3.1. Resolver una dependencia de configuración

- {% include step_label.html %} Crea el ConfigMap y el Deployment defectuoso proporcionados sin corregir sus referencias.

  > **Advertencia:** No cambies keys antes de observar cómo Kubernetes reporta la dependencia inválida.
  {: .lab-note .warning .compact}

  ```bash
  cat > config-api-broken.yaml <<'EOF'
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: config-api-settings
    namespace: lab22
  data:
    APP_ENV: production
    LOG_LEVEL: info
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: config-api
    namespace: lab22
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: config-api
    template:
      metadata:
        labels:
          app: config-api
      spec:
        containers:
          - name: app
            image: busybox:1.38.0-musl
            command:
              - sh
              - -c
              - 'echo "APP_ENV=$APP_ENV LOG_LEVEL=$LOG_LEVEL"; sleep 3600'
            env:
              - name: APP_ENV
                valueFrom:
                  configMapKeyRef:
                    name: config-api-settings
                    key: APP_ENVIRONMENT
              - name: LOG_LEVEL
                valueFrom:
                  configMapKeyRef:
                    name: config-api-settings
                    key: LOG_LEVEL
  EOF
  ```
  ```bash
  kubectl apply -f config-api-broken.yaml
  ```

  > **Salida esperada:** ConfigMap y Deployment existen, pero el Pod no inicia correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Investiga el Pod y los objetos relacionados hasta determinar la dependencia exacta que impide crear correctamente el contenedor.

  > **Importante:** Comprueba tanto las keys publicadas como las solicitadas por el consumidor.
  {: .lab-note .important .compact}

  ```text
  Determina:
  - estado del Pod;
  - evento relevante;
  - ConfigMap esperado;
  - keys existentes;
  - key solicitada;
  - causa raíz.
  ```

  > **Salida esperada:** Identificas que el Deployment solicita `APP_ENVIRONMENT`, pero existe `APP_ENV`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Corrige por tu cuenta únicamente la referencia incorrecta y demuestra que el contenedor recibe ambos valores desde el ConfigMap.

  > **Nota:** No reemplaces las variables con valores hardcoded; conserva el consumo mediante ConfigMap.
  {: .lab-note .info .compact}

  ```bash
  kubectl rollout status deployment/config-api -n lab22 --timeout=60s
  ```

  > **Salida esperada:** `config-api` completa el rollout y puede utilizar `APP_ENV=production` y `LOG_LEVEL=info`.
  {: .lab-note .output .compact}

### Tarea 3.2. Resolver un Pod Running pero no Ready

- {% include step_label.html %} Crea `web-health` con una readiness probe defectuosa y conserva inicialmente el síntoma.

  > **Advertencia:** No confundas `Running` con `Ready`; NGINX puede estar activo mientras Kubernetes lo excluye del tráfico.
  {: .lab-note .warning .compact}

  ```bash
  cat > web-health-broken.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: web-health
    namespace: lab22
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: web-health
    template:
      metadata:
        labels:
          app: web-health
      spec:
        containers:
          - name: nginx
            image: nginx:1.31.4-alpine3.24-slim
            ports:
              - containerPort: 80
            readinessProbe:
              httpGet:
                path: /healthz
                port: 80
              initialDelaySeconds: 2
              periodSeconds: 3
              failureThreshold: 2
  EOF
  ```
  ```bash
  kubectl apply -f web-health-broken.yaml
  ```

  > **Salida esperada:** NGINX inicia, pero el Pod permanece `0/1` Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Investiga condiciones, eventos y configuración hasta demostrar por qué el Pod está Running pero no Ready.

  > **Importante:** El diagnóstico debe explicar la diferencia entre proceso activo y disponibilidad para tráfico.
  {: .lab-note .important .compact}

  ```text
  Determina:
  - Phase;
  - condición Ready;
  - resultado de la probe;
  - path configurado;
  - path funcional.
  ```

  > **Salida esperada:** Determinas que `/healthz` falla mientras `/` responde correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Corrige por tu cuenta la readiness probe sin eliminarla ni cambiar imagen o puerto.

  > **Nota:** La corrección mínima debe actuar sobre el parámetro defectuoso, no deshabilitar la comprobación.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:
  - Deployment conservado;
  - readinessProbe presente;
  - path funcional;
  - Pod 1/1 Ready.
  ```

  > **Salida esperada:** El nuevo Pod alcanza condición Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida simultáneamente disponibilidad y configuración activa de readiness.

  > **Importante:** Eliminar la probe no cumple el reto aunque el Pod quede Ready.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n lab22 -l app=web-health
  ```
  ```bash
  kubectl get deployment web-health -n lab22 -o jsonpath='Path={.spec.template.spec.containers[0].readinessProbe.httpGet.path} Port={.spec.template.spec.containers[0].readinessProbe.httpGet.port}{"\n"}'
  ```

  > **Salida esperada:** El Pod muestra `1/1` Ready y la probe HTTP permanece configurada sobre la ruta funcional.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🧭 Tarea 4. Reto: diagnosticar una aplicación multicapa — 17 min

Resolverás un problema de comunicación entre un cliente, un Service y dos réplicas backend sin recibir inicialmente la ubicación del error.

### Tarea 4.1. Investigar el fallo de comunicación

- {% include step_label.html %} Crea el escenario multicapa proporcionado sin modificar labels, selectors o puertos.

  > **Advertencia:** Primero demuestra el fallo desde el estado activo del clúster antes de corregir el YAML.
  {: .lab-note .warning .compact}

  ```bash
  cat > multilayer-broken.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: backend
    namespace: lab22
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: backend
    template:
      metadata:
        labels:
          app: backend
          tier: api
      spec:
        containers:
          - name: nginx
            image: nginx:1.31.4-alpine3.24-slim
            ports:
              - containerPort: 80
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: backend
    namespace: lab22
  spec:
    selector:
      app: backend-api
    ports:
      - port: 80
        targetPort: 80
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: frontend-client
    namespace: lab22
  spec:
    containers:
      - name: client
        image: busybox:1.38.0-musl
        command:
          - sh
          - -c
          - 'sleep 3600'
  EOF
  ```
  ```bash
  kubectl apply -f multilayer-broken.yaml
  ```

  > **Salida esperada:** Backend y cliente se crean; el Service existe, pero la comunicación mediante `backend` no funciona.
  {: .lab-note .output .compact}

- {% include step_label.html %} Determina el alcance del problema comprobando por tu cuenta estado de Pods, existencia del Service y resultado de una solicitud desde el cliente.

  > **Importante:** Separa “backend caído” de “Service sin backends” antes de modificar recursos.
  {: .lab-note .important .compact}

  ```text
  Determina:
  - estado de backend;
  - estado de frontend-client;
  - existencia del Service;
  - resultado de http://backend.
  ```

  > **Salida esperada:** Los Pods están Running, pero la solicitud mediante el Service no obtiene una respuesta HTTP correcta.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona labels, selector y EndpointSlices hasta identificar por qué el Service no dispone de backends utilizables.

  > **Nota:** EndpointSlice permite comprobar qué endpoints fueron asociados realmente al Service.
  {: .lab-note .info .compact}

  ```text
  Investiga:
  - labels reales;
  - selector del Service;
  - EndpointSlices;
  - endpoints disponibles;
  - causa raíz.
  ```

  > **Salida esperada:** Identificas Pods con `app=backend` y Service con selector `app=backend-api`.
  {: .lab-note .output .compact}

### Tarea 4.2. Corregir y demostrar la recuperación completa

- {% include step_label.html %} Corrige por tu cuenta únicamente el selector del Service sin recrear los Deployments ni usar IPs directas de Pods.

  > **Importante:** La solución debe conservar el patrón Service → Pods.
  {: .lab-note .important .compact}

  ```text
  Estado requerido:
  - Service backend conservado;
  - selector compatible;
  - port 80;
  - targetPort 80;
  - EndpointSlices con backends.
  ```

  > **Salida esperada:** El Service comienza a disponer de endpoints de los Pods `backend`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida que Kubernetes haya poblado los EndpointSlices después de corregir el selector.

  > **Nota:** Esta comprobación demuestra que la capa de descubrimiento ya reconoce backends elegibles.
  {: .lab-note .info .compact}

  ```bash
  kubectl get endpointslices -n lab22 -l kubernetes.io/service-name=backend
  ```

  > **Salida esperada:** Se muestra un EndpointSlice con direcciones correspondientes a las réplicas backend.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta una prueba funcional desde `frontend-client` hacia el nombre DNS corto del Service.

  > **Importante:** Esta es la validación extremo a extremo; disponer de endpoints por sí solo no demuestra funcionalidad completa.
  {: .lab-note .important .compact}

  ```bash
  kubectl exec frontend-client -n lab22 -- wget -qO- http://backend
  ```

  > **Salida esperada:** Se devuelve el HTML predeterminado servido por NGINX.
  {: .lab-note .output .compact}

- {% include step_label.html %} Realiza una revisión final de los recursos principales antes de iniciar la limpieza.

  > **Advertencia:** No continúes si algún workload corregido todavía presenta Pods no Ready o reinicios continuos.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get deployments,pods,services -n lab22
  ```

  > **Salida esperada:** Los Deployments muestran sus réplicas disponibles y los Pods corregidos presentan un estado coherente.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar el entorno de la práctica — 6 min

Esta tarea no forma parte de la evaluación 30/70. Ejecútala únicamente después de completar todos los diagnósticos y validaciones funcionales.

### Tarea 5.1. Revisar y retirar los recursos del laboratorio

- {% include step_label.html %} Revisa una última vez Deployments, Pods, Services y ConfigMaps antes de destruir el escenario.

  > **Nota:** Confirma que todos los retos quedaron resueltos antes de perder la evidencia del clúster.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployments,pods,services,configmaps -n lab22
  ```

  > **Salida esperada:** Se muestran los recursos utilizados y sus estados finales.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab22` únicamente cuando ya no necesites logs, eventos o estados para revisar los diagnósticos.

  > **Advertencia:** La eliminación destruye la evidencia activa del laboratorio.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab22 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab22" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace ya no existe.

  > **Importante:** La ausencia de salida es el resultado esperado con `--ignore-not-found`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab22 --ignore-not-found
  ```

  > **Salida esperada:** No se muestra ningún namespace `lab22`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los manifiestos locales permanecen disponibles para comparar versiones defectuosas y corregidas.

  > **Nota:** La limpieza afecta al clúster, no a `workspace/lab22`.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio conserva los manifiestos creados durante la práctica.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}