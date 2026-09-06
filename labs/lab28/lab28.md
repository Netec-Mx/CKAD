---
layout: lab
title: "Práctica 28: Troubleshooting de conectividad"
permalink: /lab28/lab28/
images_base: /labs/lab28/img
duration: "30 minutos"
objective:
  - Aplicar un método sistemático de troubleshooting de conectividad para localizar fallos relacionados con DNS, Services, selectors, EndpointSlices, puertos, readiness y procesos de aplicación antes de realizar correcciones.
prerequisites:
  - Haber completado la Práctica 27 Restricción de tráfico con NetworkPolicy.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica aplicarás un flujo de diagnóstico de conectividad sobre escenarios deliberadamente defectuosos. Primero aprenderás a comprobar cada tramo de una comunicación sin modificar recursos prematuramente. Después resolverás retos de DNS, Services sin endpoints, targetPort incorrectos, Pods Running pero no Ready y una arquitectura multicapa donde deberás localizar el punto exacto de falla antes de corregirlo.
slug: lab28
lab_number: 28
final_result: >
  Al finalizar habrás diagnosticado problemas de conectividad siguiendo un orden reproducible: cliente, DNS, Service, selector, EndpointSlice, puertos, readiness y proceso. Habrás identificado y corregido fallos sin recurrir a cambios aleatorios y demostrado recuperación mediante pruebas funcionales por segmento y extremo a extremo.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza nginx:1.31.4-alpine3.24-slim como servidor HTTP y busybox:1.38.0-musl como cliente de diagnóstico.
  - Un Service con ClusterIP puede existir y resolver por DNS aunque carezca de endpoints funcionales.
  - EndpointSlice permite comprobar qué backends han sido seleccionados realmente por un Service.
  - port pertenece al Service y targetPort representa el puerto al que se dirige el tráfico en el backend.
  - Un Pod Running puede permanecer fuera de servicio si no está Ready.
  - En esta práctica no se utiliza NetworkPolicy como causa de fallo porque el clúster principal del curso conserva su networking original.
  - Los primeros 5 pasos son guiados y los siguientes 20 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 20/80.
references:
  - text: Debug Services
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
  - text: DNS for Services and Pods
    url: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
  - text: Service
    url: https://kubernetes.io/docs/concepts/services-networking/service/
  - text: EndpointSlices
    url: https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
  - text: Liveness, Readiness, and Startup Probes
    url: https://kubernetes.io/docs/concepts/workloads/pods/probes/
prev: /lab27/lab27/
next: /lab29/lab29/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Aplicar un método sistemático de conectividad — 6 min

Prepararás un escenario funcional y aprenderás a recorrer una ruta de red por capas antes de modificar cualquier recurso.

### Tarea 1.1. Preparar el entorno

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea `workspace/lab28` y accede al directorio para almacenar los manifiestos y evidencias de diagnóstico.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab28`.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab28 && cd workspace/lab28
  ```

  > **Salida esperada:** La terminal queda ubicada dentro de `ckad-labs/workspace/lab28`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que kubectl apunta al clúster principal del curso antes de comenzar los escenarios.

  > **Importante:** El contexto esperado es `kind-ckad`.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab28` para aislar los recursos principales de troubleshooting.

  > **Advertencia:** Si `lab28` ya existe, revisa sus Services y Pods antes de continuar para no mezclar estados anteriores.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab28
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab28 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Recorrer una ruta funcional

- {% include step_label.html %} Crea un backend funcional, su Service y un cliente persistente para disponer de una ruta conocida antes de estudiar fallos.

  > **Nota:** Este escenario sirve como referencia para el orden de diagnóstico que aplicarás durante el resto de la práctica.
  {: .lab-note .info .compact}

  ```bash
  cat > baseline.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: baseline
    namespace: lab28
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: baseline
    template:
      metadata:
        labels:
          app: baseline
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
    name: baseline
    namespace: lab28
  spec:
    selector:
      app: baseline
    ports:
      - port: 80
        targetPort: 80
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: diag-client
    namespace: lab28
  spec:
    containers:
      - name: client
        image: busybox:1.38.0-musl
        command: ["sh","-c","sleep 3600"]
  EOF
  ```
  ```bash
  kubectl apply -f baseline.yaml
  ```

  > **Salida esperada:** Se crean el Deployment, el Service y el Pod `diag-client`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Recorre la ruta completa comprobando estado, Service, EndpointSlice y acceso desde el cliente para fijar un orden de diagnóstico reproducible.

  > **Importante:** El objetivo no es memorizar comandos aislados, sino comprobar progresivamente dónde deja de funcionar la cadena.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods,services -n lab28
  ```
  ```bash
  kubectl get endpointslices -n lab28 -l kubernetes.io/service-name=baseline
  ```
  ```bash
  kubectl exec diag-client -n lab28 -- wget -qO- http://baseline
  ```

  > **Salida esperada:** El backend está Ready, el Service dispone de endpoints y el cliente obtiene el HTML de NGINX.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: diagnosticar DNS y resolución de Service — 5 min

Resolverás dos fallos de resolución: un nombre de Service incorrecto y una referencia corta utilizada desde otro namespace.

### Tarea 2.1. Identificar un nombre incorrecto

- {% include step_label.html %} Crea por tu cuenta un Deployment y Service `inventory` saludables y conserva `diag-client` como consumidor.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación; primero demuestra que el backend existe y está disponible.
  {: .lab-note .important .compact}

  ```text
  Deployment:
  - nombre: inventory
  - namespace: lab28
  - replicas: 2
  - imagen: nginx:1.31.4-alpine3.24-slim

  Service:
  - nombre: inventory
  - port: 80
  - targetPort: 80
  ```

  > **Salida esperada:** `inventory` está Ready y su Service dispone de endpoints.
  {: .lab-note .output .compact}

- {% include step_label.html %} Investiga por qué `diag-client` no puede alcanzar `inventory-api` y determina si el problema está en DNS, Service o backend.

  > **Nota:** No cambies el Deployment ni el Service antes de comprobar qué nombre existe realmente dentro del namespace.
  {: .lab-note .info .compact}

  ```text
  Síntoma:

  diag-client intenta acceder a:
  inventory-api

  Debes determinar:
  - si el nombre resuelve;
  - qué Service existe;
  - cuál es el nombre correcto.
  ```

  > **Salida esperada:** Identificas que `inventory-api` no corresponde a ningún Service y que el nombre correcto es `inventory`.
  {: .lab-note .output .compact}

### Tarea 2.2. Resolver acceso entre namespaces

- {% include step_label.html %} Crea el namespace `lab28-backend`, despliega allí un Service `inventory` funcional y conserva `diag-client` en `lab28`.

  > **Importante:** El mismo nombre de Service puede existir en namespaces diferentes; la resolución depende del contexto DNS del cliente.
  {: .lab-note .important .compact}

  ```text
  Namespace:
  - lab28-backend

  Backend:
  - Deployment inventory
  - Service inventory
  - port 80
  ```

  > **Salida esperada:** Existe un `inventory` independiente dentro de `lab28-backend`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Determina por qué el nombre corto no representa al Service del otro namespace y demuestra acceso utilizando un nombre DNS adecuado.

  > **Nota:** Puedes utilizar el nombre con namespace o el FQDN completo del Service.
  {: .lab-note .info .compact}

  ```text
  Debes validar una forma equivalente a:

  inventory.lab28-backend
  o
  inventory.lab28-backend.svc.cluster.local
  ```

  > **Salida esperada:** `diag-client` logra acceder al Service ubicado en `lab28-backend`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🔗 Tarea 3. Reto: diagnosticar selector y EndpointSlices — 6 min

Analizarás un Service que existe y resuelve correctamente, pero no dispone de backends debido a una selección incorrecta.

### Tarea 3.1. Localizar el tramo defectuoso

- {% include step_label.html %} Crea por tu cuenta un Deployment `catalog` saludable y un Service `catalog` cuyo selector inicial no coincida con los labels de los Pods.

  > **Advertencia:** No corrijas el selector durante la creación; necesitas conservar el fallo para diagnosticarlo.
  {: .lab-note .warning .compact}

  ```text
  Deployment:
  - nombre: catalog
  - replicas: 2
  - label Pods: app=catalog

  Service:
  - nombre: catalog
  - selector inicial: app=catalog-api
  - port: 80
  - targetPort: 80
  ```

  > **Salida esperada:** Los Pods están Ready y el Service existe, pero no selecciona backends.
  {: .lab-note .output .compact}

- {% include step_label.html %} Determina hasta qué punto funciona la ruta y utiliza EndpointSlices para identificar el primer tramo que falla.

  > **Importante:** La ClusterIP y la resolución DNS pueden ser correctas aunque el Service tenga cero endpoints.
  {: .lab-note .important .compact}

  ```text
  Comprueba conceptualmente:

  cliente
    ↓
  DNS
    ↓
  Service
    ↓
  EndpointSlice
    ↓
  Pods
  ```

  > **Salida esperada:** Concluyes que DNS y Service existen, pero EndpointSlice no contiene backends por el selector incorrecto.
  {: .lab-note .output .compact}

### Tarea 3.2. Corregir y demostrar selección

- {% include step_label.html %} Corrige por tu cuenta únicamente el selector de `catalog` sin recrear el Deployment.

  > **Nota:** La corrección mínima debe restablecer la relación entre Service y Pods.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:
  - selector compatible con app=catalog;
  - Service conservado;
  - Pods sin recreación innecesaria.
  ```

  > **Salida esperada:** El Service comienza a seleccionar las réplicas de `catalog`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida que los EndpointSlices contengan direcciones correspondientes a los Pods `catalog`.

  > **Importante:** Esta es la evidencia directa de que el selector ya encuentra backends.
  {: .lab-note .important .compact}

  ```bash
  kubectl get endpointslices -n lab28 -l kubernetes.io/service-name=catalog -o wide
  ```

  > **Salida esperada:** Los EndpointSlices muestran direcciones de los Pods del Deployment `catalog`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta una prueba desde `diag-client` para demostrar que la conectividad fue recuperada.

  > **Nota:** La validación funcional confirma que el problema no estaba en DNS ni en la aplicación.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec diag-client -n lab28 -- wget -qO- http://catalog
  ```

  > **Salida esperada:** El cliente obtiene el HTML predeterminado de NGINX.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## ⚙️ Tarea 4. Reto: diagnosticar puertos y readiness — 6 min

Resolverás dos fallos sucesivos en el mismo workload: primero un `targetPort` incorrecto y después una readiness probe que mantiene al Pod fuera de servicio.

### Tarea 4.1. Detectar un targetPort incorrecto

- {% include step_label.html %} Crea `payments` con NGINX y un Service que tenga endpoints pero dirija tráfico inicialmente al puerto equivocado.

  > **Advertencia:** Mantén `targetPort=8081` al crear el escenario; el fallo debe existir para poder demostrarlo.
  {: .lab-note .warning .compact}

  ```text
  Deployment payments:
  - replicas: 2
  - imagen: nginx:1.31.4-alpine3.24-slim
  - aplicación escucha en 80

  Service payments:
  - port: 8080
  - targetPort inicial: 8081
  ```

  > **Salida esperada:** Los Pods están Ready, el Service dispone de endpoints, pero el tráfico por `payments:8080` falla.
  {: .lab-note .output .compact}

- {% include step_label.html %} Investiga Service, EndpointSlices y puerto de aplicación hasta identificar por qué la conexión falla pese a existir backends.

  > **Importante:** Cuando hay endpoints presentes, continúa avanzando en la ruta y comprueba la traducción de puertos antes de culpar a DNS.
  {: .lab-note .important .compact}

  ```text
  Compara:
  - Service port: 8080
  - targetPort: 8081
  - puerto real de NGINX: 80
  ```

  > **Salida esperada:** Identificas que `targetPort=8081` no coincide con el puerto donde escucha NGINX.
  {: .lab-note .output .compact}

### Tarea 4.2. Resolver un Pod Running pero no Ready

- {% include step_label.html %} Corrige por tu cuenta `targetPort` y modifica después el Deployment para introducir una readiness probe HTTP sobre `/healthz`.

  > **Importante:** El primer fallo debe quedar resuelto antes de introducir el segundo para que cada síntoma tenga una causa clara.
  {: .lab-note .important .compact}

  ```text
  Estado intermedio:
  - targetPort=80

  Nuevo fallo:
  readinessProbe
  - httpGet path: /healthz
  - port: 80
  ```

  > **Salida esperada:** El Pod permanece Running pero pasa a mostrar condición NotReady después de que la probe falle.
  {: .lab-note .output .compact}

- {% include step_label.html %} Determina por qué el Service deja de disponer de backends Ready aunque el proceso NGINX continúe activo.

  > **Nota:** Readiness controla si un endpoint está preparado para recibir tráfico; `Running` no implica automáticamente `Ready`.
  {: .lab-note .info .compact}

  ```text
  Debes relacionar:
  - Pod Phase;
  - condición Ready;
  - readinessProbe;
  - EndpointSlice.
  ```

  > **Salida esperada:** Identificas que `/healthz` falla y que el Pod no está disponible como backend Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Corrige por tu cuenta la readiness probe y demuestra que `payments:8080` vuelve a responder desde `diag-client`.

  > **Importante:** Conserva la probe y corrige su path; eliminarla no cumple el objetivo del reto.
  {: .lab-note .important .compact}

  ```text
  Estado final:
  - Pod Ready;
  - EndpointSlice con backend Ready;
  - Service port 8080;
  - targetPort 80;
  - acceso HTTP funcional.
  ```

  > **Salida esperada:** `diag-client` obtiene respuesta HTTP mediante `payments:8080`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧭 Tarea 5. Reto: diagnóstico extremo a extremo — 5 min

Analizarás una arquitectura de varias capas donde el síntoma aparece en el cliente, pero la causa se encuentra en una comunicación interna posterior.

### Tarea 5.1. Localizar la falla por segmentos

- {% include step_label.html %} Diseña e implementa una arquitectura `frontend-client → api → database` con Services independientes y un único error deliberado en la comunicación `api → database`.

  > **Importante:** No hagas visible la causa en el nombre de los recursos; el diagnóstico debe basarse en comportamiento y configuración.
  {: .lab-note .important .compact}

  ```text
  Namespace: lab28

  frontend-client:
  - Pod persistente

  api:
  - Deployment
  - Service api
  - port 8080

  database:
  - Deployment
  - Service database
  - port 9090
  - aplicación escucha en 9000

  Error deliberado:
  - el Service database debe contener inicialmente
    una traducción de puerto incorrecta
  ```

  > **Salida esperada:** Todos los Pods pueden estar Running, pero la aplicación completa no funciona extremo a extremo.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba estado y readiness de todos los componentes para descartar primero fallos de scheduling o arranque.

  > **Nota:** No modifiques Services antes de demostrar qué capas están saludables.
  {: .lab-note .info .compact}

  ```text
  Determina:
  - frontend-client Running;
  - api Ready;
  - database Ready;
  - Services existentes.
  ```

  > **Salida esperada:** Los componentes principales están activos y el problema se concentra en conectividad entre capas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Prueba la ruta por segmentos hasta identificar exactamente dónde deja de funcionar la comunicación.

  > **Importante:** Aísla primero `frontend-client → api` y después `api → database`; no asumas que el error está en el primer Service.
  {: .lab-note .important .compact}

  ```text
  Debes concluir:

  frontend-client -> api       ?
  api             -> database  ?
  ```

  > **Salida esperada:** Determinas que el primer segmento funciona y que la falla aparece entre `api` y `database`.
  {: .lab-note .output .compact}

### Tarea 5.2. Corregir y validar extremo a extremo

- {% include step_label.html %} Identifica la causa raíz del tramo `api → database` y corrige únicamente la configuración necesaria.

  > **Importante:** Evita recrear Deployments o cambiar DNS si la evidencia apunta a la traducción de puerto del Service.
  {: .lab-note .important .compact}

  ```text
  Corrección requerida:
  - conservar Service database;
  - conservar port 9090;
  - dirigir tráfico al puerto real de la aplicación.
  ```

  > **Salida esperada:** El Service `database` queda configurado con el `targetPort` correcto.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida nuevamente cada segmento para demostrar que ambos funcionan después de la corrección.

  > **Nota:** La validación segmentada confirma que la corrección resolvió exactamente el tramo defectuoso.
  {: .lab-note .info .compact}

  ```text
  Resultado esperado:

  frontend-client -> api       ✓
  api             -> database  ✓
  ```

  > **Salida esperada:** Ambos segmentos establecen comunicación correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta una prueba final desde `frontend-client` y explica el flujo de diagnóstico utilizado para llegar a la causa raíz.

  > **Importante:** El objetivo final es demostrar que puedes localizar el tramo defectuoso sin realizar cambios aleatorios.
  {: .lab-note .important .compact}

  ```text
  Explica el orden utilizado:

  cliente
    ↓
  DNS
    ↓
  Service
    ↓
  selector
    ↓
  EndpointSlice
    ↓
  port / targetPort
    ↓
  Pod Ready
    ↓
  proceso
  ```

  > **Salida esperada:** La comunicación completa funciona y puedes justificar la corrección mediante la evidencia recopilada.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🧹 Tarea 6. Limpiar el entorno de la práctica — 2 min

La limpieza no forma parte de la proporción 20/80. Ejecútala únicamente después de completar todas las pruebas de conectividad y conservar la evidencia que necesites.

### Tarea 6.1. Retirar los recursos del laboratorio

- {% include step_label.html %} Revisa una última vez Deployments, Pods, Services y EndpointSlices en ambos namespaces antes de eliminar los recursos.

  > **Nota:** Confirma que terminaste especialmente el diagnóstico extremo a extremo.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployments,pods,services,endpointslices -n lab28
  ```
  ```bash
  kubectl get deployments,pods,services,endpointslices -n lab28-backend
  ```

  > **Salida esperada:** Se muestran los recursos utilizados durante la práctica y sus estados finales.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina los namespaces `lab28` y `lab28-backend` cuando ya no necesites realizar más pruebas.

  > **Advertencia:** La eliminación destruye Services, EndpointSlices, Pods y eventos asociados a los escenarios.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab28 lab28-backend --wait=true
  ```

  > **Salida esperada:** Kubernetes confirma la eliminación de ambos namespaces.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que ninguno de los namespaces continúa presente en el clúster.

  > **Importante:** La ausencia de salida es el resultado esperado con `--ignore-not-found`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab28 lab28-backend --ignore-not-found
  ```

  > **Salida esperada:** No se muestran namespaces `lab28` ni `lab28-backend`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los archivos locales se conservaron para repasar posteriormente los escenarios de troubleshooting.

  > **Nota:** La limpieza afecta únicamente a Kubernetes y conserva `workspace/lab28`.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio mantiene los manifiestos creados durante la práctica.
  {: .lab-note .output .compact}

{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

{% include support-prompt.html task="tarea6" %}