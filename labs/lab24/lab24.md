---
layout: lab
title: "Práctica 24: Exposición interna con Service ClusterIP"
permalink: /lab24/lab24/
images_base: /labs/lab24/img
duration: "35 minutos"
objective:
  - Exponer aplicaciones internamente mediante Services de tipo ClusterIP, relacionar labels y selectors con EndpointSlices, validar resolución DNS y diferenciar correctamente service port y targetPort durante pruebas y troubleshooting.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Haber completado la Práctica 22 Depuración de aplicaciones fallidas.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica utilizarás Services ClusterIP para publicar aplicaciones únicamente dentro del clúster. La sección guiada mostrará la relación entre labels, selector y EndpointSlices. Después resolverás retos donde deberás crear Services con puertos distintos a los de la aplicación, validar DNS interno, identificar Services sin endpoints y corregir targetPort incorrectos. El reto final integra Deployment, Service, cliente y validación extremo a extremo mediante DNS.
slug: lab24
lab_number: 24
final_result: >
  Al finalizar habrás creado Services ClusterIP, relacionado selectors con labels de Pods, validado EndpointSlices y resolución DNS interna, diferenciado port de targetPort y corregido fallos de conectividad causados por selectors o puertos incorrectos. También habrás demostrado comunicación funcional entre un cliente y un backend utilizando únicamente el nombre DNS del Service.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza nginx:1.31.4-alpine3.24-slim como imagen HTTP de referencia y busybox:1.38.0-musl como cliente interno.
  - ClusterIP es el tipo de Service predeterminado y expone la aplicación dentro del clúster.
  - Un Service con selector obtiene sus backends a partir de Pods cuyos labels coinciden; Kubernetes representa esos backends mediante EndpointSlices.
  - port representa el puerto expuesto por el Service y targetPort el puerto al que el Service dirige el tráfico en los Pods.
  - Los Services reciben nombres DNS dentro del clúster. En el mismo namespace puede utilizarse el nombre corto del Service.
  - Los primeros 5 pasos son guiados y los siguientes 20 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 20/80.
references:
  - text: Service
    url: https://kubernetes.io/docs/concepts/services-networking/service/
  - text: EndpointSlices
    url: https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
  - text: DNS for Services and Pods
    url: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
prev: /lab23/lab23/
next: /lab25/lab25/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Comprender ClusterIP y selección de Pods — 7 min

Prepararás el workspace y crearás un ejemplo mínimo para observar cómo un Service selecciona Pods mediante labels y cómo Kubernetes representa esos backends mediante EndpointSlices.

### Tarea 1.1. Preparar el entorno

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea `workspace/lab24` y accede al directorio para almacenar los manifiestos de esta práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab24`.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab24 && cd workspace/lab24
  ```

  > **Salida esperada:** La terminal queda ubicada dentro de `ckad-labs/workspace/lab24`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo antes de crear Services y workloads en el clúster.

  > **Importante:** El contexto esperado es `kind-ckad`.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab24` para aislar todos los recursos de conectividad interna.

  > **Advertencia:** Si el namespace ya existe, revisa sus Services y EndpointSlices antes de continuar para no mezclar recursos de ejecuciones anteriores.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab24
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab24 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Crear un ejemplo mínimo de Service

- {% include step_label.html %} Crea un Deployment `demo-web` de dos réplicas con label `app=demo-web` y expónlo mediante un Service ClusterIP que seleccione esa misma label.

  > **Nota:** El Service no contiene Pods; su selector determina dinámicamente qué Pods forman parte del backend.
  {: .lab-note .info .compact}

  ```bash
  cat > demo-web.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: demo-web
    namespace: lab24
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: demo-web
    template:
      metadata:
        labels:
          app: demo-web
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
    name: demo-web
    namespace: lab24
  spec:
    type: ClusterIP
    selector:
      app: demo-web
    ports:
      - port: 80
        targetPort: 80
  EOF
  ```
  ```bash
  kubectl apply -f demo-web.yaml
  ```

  > **Salida esperada:** Se crean `deployment/demo-web` y `service/demo-web`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida la ClusterIP, el selector y los EndpointSlices para observar la relación entre Service y réplicas.

  > **Importante:** Un Service puede existir aunque no tenga endpoints; por eso conviene validar selector y EndpointSlices, no solo la presencia de ClusterIP.
  {: .lab-note .important .compact}

  ```bash
  kubectl get service demo-web -n lab24
  ```
  ```bash
  kubectl get endpointslices -n lab24 -l kubernetes.io/service-name=demo-web
  ```

  > **Salida esperada:** `demo-web` muestra tipo `ClusterIP` y existe un EndpointSlice con direcciones asociadas a sus Pods.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: exponer un Deployment internamente — 5 min

Crearás un backend de tres réplicas y un Service cuyo puerto de entrada sea diferente al puerto real del contenedor.

### Tarea 2.1. Crear el backend

- {% include step_label.html %} Analiza los requisitos de `backend` y determina qué labels deberán permitir que posteriormente un Service seleccione exactamente sus tres Pods.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Conserva manifiestos locales y decide por tu cuenta la estructura necesaria.
  {: .lab-note .important .compact}

  ```text
  Deployment:
  - nombre: backend
  - namespace: lab24
  - replicas: 3
  - imagen: nginx:1.31.4-alpine3.24-slim
  - aplicación escucha en puerto 80
  ```

  > **Salida esperada:** Defines una estrategia de labels coherente para el Deployment y sus Pods.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `backend` y espera hasta que las tres réplicas estén disponibles.

  > **Nota:** El Service todavía no es necesario en este paso; primero demuestra que el workload funciona por sí mismo.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:
  - Deployment backend existente
  - replicas=3
  - 3 Pods Ready
  ```

  > **Salida esperada:** `backend` dispone de tres réplicas Ready.
  {: .lab-note .output .compact}

### Tarea 2.2. Crear el Service ClusterIP

- {% include step_label.html %} Crea por tu cuenta un Service `backend` de tipo ClusterIP que exponga el puerto `8080` y dirija tráfico al puerto `80` de los Pods.

  > **Importante:** Debes distinguir `port` de `targetPort`; ambos valores no tienen que ser iguales.
  {: .lab-note .important .compact}

  ```text
  Service:
  - nombre: backend
  - namespace: lab24
  - type: ClusterIP
  - port: 8080
  - targetPort: 80
  - selector compatible con backend
  ```

  > **Salida esperada:** El Service `backend` existe con una ClusterIP asignada y la configuración de puertos solicitada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el tipo de Service, su ClusterIP, `port` y `targetPort` desde el objeto activo.

  > **Nota:** La validación directa del recurso evita depender únicamente del manifiesto local.
  {: .lab-note .info .compact}

  ```bash
  kubectl get service backend -n lab24 -o jsonpath='Type={.spec.type} ClusterIP={.spec.clusterIP} Port={.spec.ports[0].port} TargetPort={.spec.ports[0].targetPort}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Type=ClusterIP`, una ClusterIP válida, `Port=8080` y `TargetPort=80`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🌐 Tarea 3. Reto: validar DNS, Service y EndpointSlices — 7 min

Crearás un cliente interno y demostrarás que puede llegar al backend mediante DNS, además de relacionar las IP de Pods con los endpoints publicados por el Service.

### Tarea 3.1. Validar descubrimiento DNS

- {% include step_label.html %} Crea por tu cuenta un Pod `client` con BusyBox que permanezca activo y pueda utilizarse para realizar consultas internas.

  > **Nota:** El cliente debe pertenecer al mismo namespace para que el nombre corto `backend` pueda resolverse directamente.
  {: .lab-note .info .compact}

  ```text
  Pod:
  - nombre: client
  - namespace: lab24
  - imagen: busybox:1.38.0-musl
  - debe permanecer Running
  ```

  > **Salida esperada:** `client` queda Running dentro de `lab24`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Demuestra por tu cuenta que `client` puede acceder al backend utilizando tanto el nombre corto del Service como un nombre DNS con namespace.

  > **Importante:** Utiliza el puerto del Service, no el puerto interno del contenedor.
  {: .lab-note .important .compact}

  ```text
  Debes validar acceso mediante:
  - backend:8080
  - backend.lab24:8080
  ```

  > **Salida esperada:** Ambas formas de nombre permiten obtener una respuesta HTTP de NGINX.
  {: .lab-note .output .compact}

### Tarea 3.2. Relacionar Service y endpoints

- {% include step_label.html %} Obtén la ClusterIP de `backend` y confirma que corresponde al Service, no a una IP individual de Pod.

  > **Nota:** ClusterIP es una dirección virtual estable para el Service; los Pods pueden cambiar de IP cuando son recreados.
  {: .lab-note .info .compact}

  ```bash
  kubectl get service backend -n lab24 -o wide
  ```

  > **Salida esperada:** El Service muestra una ClusterIP y el puerto `8080/TCP`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los EndpointSlices asociados a `backend` y determina cuántas direcciones representan a las tres réplicas.

  > **Importante:** El Service puede tener varios EndpointSlices; no asumas que siempre habrá uno solo en entornos más grandes.
  {: .lab-note .important .compact}

  ```bash
  kubectl get endpointslices -n lab24 -l kubernetes.io/service-name=backend -o wide
  ```

  > **Salida esperada:** Los EndpointSlices contienen direcciones que corresponden a los Pods seleccionados por el Service.
  {: .lab-note .output .compact}

- {% include step_label.html %} Compara las IP de los Pods `backend` con las direcciones publicadas en los EndpointSlices.

  > **Nota:** Esta comparación demuestra que el selector del Service está resolviendo hacia las réplicas correctas.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab24 -l app=backend -o wide
  ```

  > **Salida esperada:** Las IP de los Pods coinciden con las direcciones observadas en los EndpointSlices.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🛠️ Tarea 4. Reto: corregir selector y puertos — 7 min

Resolverás un Service que primero no tiene endpoints por un selector incorrecto y, después, continúa sin responder debido a un `targetPort` equivocado.

### Tarea 4.1. Diagnosticar un Service sin endpoints

- {% include step_label.html %} Crea por tu cuenta un Deployment `catalog` con NGINX y un Service `catalog` cuyo selector no coincida inicialmente con los labels de los Pods.

  > **Advertencia:** El fallo es deliberado. No corrijas inmediatamente el selector; primero demuestra el síntoma.
  {: .lab-note .warning .compact}

  ```text
  Deployment catalog:
  - replicas: 2
  - label real: app=catalog
  - imagen: nginx:1.31.4-alpine3.24-slim

  Service catalog:
  - selector inicial: app=catalog-api
  - port: 9000
  - targetPort inicial: 8080
  ```

  > **Salida esperada:** Los Pods están Running y el Service existe, pero inicialmente no dispone de endpoints.
  {: .lab-note .output .compact}

- {% include step_label.html %} Investiga labels, selector y EndpointSlices hasta identificar por qué `catalog` no tiene backends.

  > **Importante:** Un Service con ClusterIP válida puede seguir siendo inútil si su selector no encuentra Pods.
  {: .lab-note .important .compact}

  ```text
  Determina:
  - labels de los Pods;
  - selector del Service;
  - EndpointSlices;
  - causa raíz del primer fallo.
  ```

  > **Salida esperada:** Identificas la diferencia entre `app=catalog` y `app=catalog-api`.
  {: .lab-note .output .compact}

### Tarea 4.2. Corregir y validar puertos

- {% include step_label.html %} Corrige por tu cuenta únicamente el selector del Service y confirma que aparecen endpoints.

  > **Nota:** En este punto el Service puede continuar sin responder porque todavía existe un segundo error independiente.
  {: .lab-note .info .compact}

  ```text
  Primer estado corregido:
  - selector compatible
  - EndpointSlices con Pods catalog
  - conservar port=9000
  - conservar temporalmente targetPort=8080
  ```

  > **Salida esperada:** `catalog` obtiene endpoints después de corregir el selector.
  {: .lab-note .output .compact}

- {% include step_label.html %} Prueba el Service desde `client`, identifica por qué sigue fallando pese a tener endpoints y determina el segundo cambio necesario.

  > **Importante:** Tener endpoints demuestra selección correcta, pero no garantiza que `targetPort` apunte al puerto donde escucha la aplicación.
  {: .lab-note .important .compact}

  ```text
  Investiga:
  - Service port: 9000
  - targetPort actual: 8080
  - puerto real de NGINX: 80
  ```

  > **Salida esperada:** Determinas que el Service dirige tráfico al puerto incorrecto del Pod.
  {: .lab-note .output .compact}

- {% include step_label.html %} Corrige por tu cuenta `targetPort` y valida acceso desde `client` utilizando el puerto `9000` del Service.

  > **Nota:** El consumidor debe utilizar el puerto del Service; Kubernetes redirige internamente hacia el `targetPort`.
  {: .lab-note .info .compact}

  ```text
  Estado final requerido:
  - port=9000
  - targetPort=80
  - endpoints presentes
  - acceso HTTP funcional
  ```

  > **Salida esperada:** `client` puede obtener una respuesta HTTP desde `catalog:9000`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧭 Tarea 5. Reto: construir comunicación interna completa — 7 min

Diseñarás una solución nueva sin reutilizar los manifiestos anteriores y demostrarás conectividad extremo a extremo mediante DNS y ClusterIP.

### Tarea 5.1. Diseñar la arquitectura interna

- {% include step_label.html %} Analiza los requisitos de `api` y define una estrategia coherente de labels y selector antes de crear los recursos.

  > **Importante:** El selector del Service debe coincidir con labels estables del Pod template, no con nombres generados de Pods.
  {: .lab-note .important .compact}

  ```text
  Deployment:
  - nombre: api
  - namespace: lab24
  - replicas: 3
  - imagen: nginx:1.31.4-alpine3.24-slim
  - puerto de aplicación: 80

  Service:
  - nombre: api-internal
  - type: ClusterIP
  - port: 8080
  - targetPort: 80
  ```

  > **Salida esperada:** Defines labels y selector compatibles para unir `api-internal` con las tres réplicas de `api`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta el Deployment y Service y espera hasta que las tres réplicas estén Ready.

  > **Nota:** No continúes únicamente porque el Service tenga ClusterIP; confirma también la disponibilidad del workload.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:
  - Deployment api con 3 Pods Ready
  - Service api-internal existente
  - port 8080
  - targetPort 80
  ```

  > **Salida esperada:** La aplicación `api` y su Service interno quedan creados correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea por tu cuenta un Pod `frontend-client` con BusyBox que permanezca activo para realizar la validación funcional.

  > **Nota:** Mantén al cliente dentro de `lab24` para utilizar el nombre corto del Service.
  {: .lab-note .info .compact}

  ```text
  Pod:
  - nombre: frontend-client
  - namespace: lab24
  - imagen: busybox:1.38.0-musl
  - debe permanecer Running
  ```

  > **Salida esperada:** `frontend-client` está Running y disponible para ejecutar pruebas.
  {: .lab-note .output .compact}

### Tarea 5.2. Demostrar funcionamiento extremo a extremo

- {% include step_label.html %} Valida que `api-internal` dispone de endpoints que corresponden a las tres réplicas de `api`.

  > **Importante:** No continúes si el Service carece de endpoints; corrige primero labels o selector.
  {: .lab-note .important .compact}

  ```bash
  kubectl get endpointslices -n lab24 -l kubernetes.io/service-name=api-internal -o wide
  ```

  > **Salida esperada:** Los EndpointSlices contienen direcciones asociadas a los Pods del Deployment `api`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta una prueba funcional desde `frontend-client` hacia `api-internal:8080` utilizando el nombre DNS del Service.

  > **Importante:** No utilices IPs directas de Pods; el objetivo es demostrar comunicación mediante la abstracción Service.
  {: .lab-note .important .compact}

  ```bash
  kubectl exec frontend-client -n lab24 -- wget -qO- http://api-internal:8080
  ```

  > **Salida esperada:** Se devuelve el contenido HTML predeterminado servido por NGINX.
  {: .lab-note .output .compact}

- {% include step_label.html %} Emite una conclusión final relacionando labels, selector, EndpointSlices, DNS, `port` y `targetPort` con la comunicación observada.

  > **Nota:** El objetivo final es poder explicar la ruta del tráfico, no solo demostrar que un comando respondió.
  {: .lab-note .info .compact}

  ```text
  Explica el flujo:

  frontend-client
      ↓ DNS
  api-internal
      ↓ ClusterIP:8080
  EndpointSlice
      ↓
  Pods api
      ↓ targetPort 80
  NGINX
  ```

  > **Salida esperada:** Describes correctamente la cadena que permite que el cliente alcance una de las réplicas mediante el Service.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🧹 Tarea 6. Limpiar el entorno de la práctica — 2 min

La limpieza no forma parte de la proporción 20/80. Ejecútala únicamente después de completar todas las pruebas de conectividad y troubleshooting.

### Tarea 6.1. Retirar los recursos del laboratorio

- {% include step_label.html %} Revisa una última vez Deployments, Pods, Services y EndpointSlices antes de eliminar el namespace.

  > **Nota:** Confirma que ya completaste las pruebas de `backend`, `catalog` y `api-internal`.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployments,pods,services,endpointslices -n lab24
  ```

  > **Salida esperada:** Se muestran los recursos utilizados durante la práctica y sus estados finales.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab24` únicamente cuando ya no necesites conservar endpoints ni pruebas activas.

  > **Advertencia:** La eliminación destruye todos los Services y workloads del laboratorio.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab24 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab24" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace ya no existe.

  > **Importante:** La ausencia de salida es el resultado esperado con `--ignore-not-found`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab24 --ignore-not-found
  ```

  > **Salida esperada:** No se muestra ningún namespace `lab24`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Verifica que los manifiestos locales permanecen disponibles para revisar posteriormente los escenarios de Service.

  > **Nota:** La limpieza afecta únicamente al clúster y conserva `workspace/lab24`.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio conserva los manifiestos creados durante la práctica.
  {: .lab-note .output .compact}

{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

{% include support-prompt.html task="tarea6" %}