---
layout: lab
title: "Práctica 25: Exposición externa básica"
permalink: /lab25/lab25/
images_base: /labs/lab25/img
duration: "30 minutos"
objective:
  - Exponer aplicaciones mediante Services de tipo NodePort, diferenciar port, targetPort y nodePort, validar acceso interno y desde un cliente externo al clúster Kubernetes y diagnosticar fallos causados por selectors y puertos incorrectos.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 24 Exposición interna con Service ClusterIP.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Disponer de Docker Desktop funcionando con contenedores Linux.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica utilizarás NodePort como mecanismo básico de exposición externa en el clúster local kind. Primero observarás de forma guiada la relación entre ClusterIP, port, targetPort y nodePort. Después resolverás retos para publicar aplicaciones, comprobar acceso interno por DNS y validar acceso desde un cliente Docker externo al clúster Kubernetes. También diagnosticarás Services con selectors y puertos incorrectos antes de construir una exposición completa sin recibir comandos de implementación.
slug: lab25
lab_number: 25
final_result: >
  Al finalizar habrás creado Services NodePort, validado acceso interno mediante DNS y acceso desde un cliente externo al clúster Kubernetes, relacionado selectors con EndpointSlices y diferenciado port, targetPort y nodePort. También habrás diagnosticado y corregido fallos de exposición causados por ausencia de endpoints o por un targetPort incorrecto.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza nginx:1.31.4-alpine3.24-slim como servidor HTTP y busybox:1.38.0-musl para clientes de prueba.
  - NodePort conserva una ClusterIP y además publica el mismo puerto de nodo en los nodos del clúster dentro del rango configurado para NodePort.
  - port es el puerto del Service, targetPort es el puerto del backend y nodePort es el puerto publicado en los nodos.
  - En Docker Desktop para Windows no se asume que un NodePort de kind sea accesible mediante localhost si el clúster no fue creado con extraPortMappings.
  - Las validaciones externas utilizan un contenedor Docker temporal conectado a la red kind. Ese cliente está fuera del clúster Kubernetes y accede al puerto publicado en un nodo kind.
  - Los primeros 5 pasos son guiados y los siguientes 20 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 20/80.
references:
  - text: Service
    url: https://kubernetes.io/docs/concepts/services-networking/service/
  - text: kind Configuration
    url: https://kind.sigs.k8s.io/docs/user/configuration/
  - text: EndpointSlices
    url: https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
  - text: DNS for Services and Pods
    url: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
prev: /lab24/lab24/
next: /lab26/lab26/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Comprender NodePort y la ruta de tráfico — 6 min

Prepararás el workspace y crearás un ejemplo mínimo para observar cómo Kubernetes agrega un puerto de nodo a un Service y cómo el tráfico continúa resolviéndose hacia los Pods seleccionados.

### Tarea 1.1. Preparar el entorno

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea `workspace/lab25` y accede al directorio para almacenar los manifiestos utilizados durante la práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab25`.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab25 && cd workspace/lab25
  ```

  > **Salida esperada:** La terminal queda ubicada dentro de `ckad-labs/workspace/lab25`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que kubectl apunta al clúster local correcto antes de crear recursos de exposición.

  > **Importante:** El contexto esperado es `kind-ckad`.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab25` para aislar los workloads y Services NodePort del laboratorio.

  > **Advertencia:** Si `lab25` ya existe, revisa primero sus Services para evitar colisiones con los NodePorts fijos utilizados en esta práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab25
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab25 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Crear un ejemplo mínimo de NodePort

- {% include step_label.html %} Crea `demo-external` con dos réplicas NGINX y un Service NodePort que publique el puerto `30080`.

  > **Nota:** El Service mantiene una ClusterIP para tráfico interno y añade un NodePort accesible a través de los nodos.
  {: .lab-note .info .compact}

  ```bash
  cat > demo-external.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: demo-external
    namespace: lab25
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: demo-external
    template:
      metadata:
        labels:
          app: demo-external
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
    name: demo-external
    namespace: lab25
  spec:
    type: NodePort
    selector:
      app: demo-external
    ports:
      - port: 80
        targetPort: 80
        nodePort: 30080
  EOF
  ```
  ```bash
  kubectl apply -f demo-external.yaml
  ```

  > **Salida esperada:** Se crean `deployment/demo-external` y `service/demo-external`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona el Service para distinguir ClusterIP, `port`, `targetPort` y `nodePort`.

  > **Importante:** `nodePort` publica el tráfico en los nodos; `targetPort` continúa indicando el puerto real donde escucha la aplicación.
  {: .lab-note .important .compact}

  ```bash
  kubectl get service demo-external -n lab25 -o jsonpath='Type={.spec.type} ClusterIP={.spec.clusterIP} Port={.spec.ports[0].port} TargetPort={.spec.ports[0].targetPort} NodePort={.spec.ports[0].nodePort}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Type=NodePort`, `Port=80`, `TargetPort=80` y `NodePort=30080`, además de una ClusterIP.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: exponer una aplicación con NodePort — 5 min

Crearás un Deployment de tres réplicas y lo publicarás mediante un NodePort cuyos tres niveles de puerto sean diferentes o explícitos.

### Tarea 2.1. Crear el workload

- {% include step_label.html %} Analiza los requisitos de `web-public` y define labels que permitan seleccionar exactamente sus tres réplicas.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Conserva los manifiestos que construyas.
  {: .lab-note .important .compact}

  ```text
  Deployment:
  - nombre: web-public
  - namespace: lab25
  - replicas: 3
  - imagen: nginx:1.31.4-alpine3.24-slim
  - aplicación escucha en 80
  ```

  > **Salida esperada:** Defines una estrategia de labels coherente para el workload.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `web-public` y espera hasta que sus tres réplicas estén Ready.

  > **Nota:** Valida primero el workload antes de introducir la capa de exposición.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:
  - Deployment web-public
  - replicas=3
  - 3 Pods Ready
  ```

  > **Salida esperada:** `web-public` dispone de tres réplicas Ready.
  {: .lab-note .output .compact}

### Tarea 2.2. Crear el Service externo

- {% include step_label.html %} Crea por tu cuenta un Service `web-public` de tipo NodePort con los puertos solicitados y un selector compatible con el Deployment.

  > **Importante:** Distingue el puerto utilizado por clientes internos del puerto publicado en los nodos.
  {: .lab-note .important .compact}

  ```text
  Service:
  - nombre: web-public
  - type: NodePort
  - port: 8080
  - targetPort: 80
  - nodePort: 30081
  ```

  > **Salida esperada:** El Service existe con ClusterIP y NodePort `30081`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida desde el objeto activo que Kubernetes almacenó exactamente los puertos requeridos.

  > **Nota:** La inspección del recurso activo confirma que la exposición aplicada coincide con el diseño.
  {: .lab-note .info .compact}

  ```bash
  kubectl get service web-public -n lab25 -o jsonpath='Type={.spec.type} Port={.spec.ports[0].port} TargetPort={.spec.ports[0].targetPort} NodePort={.spec.ports[0].nodePort}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Type=NodePort Port=8080 TargetPort=80 NodePort=30081`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🌐 Tarea 3. Reto: validar acceso interno y externo — 6 min

Comprobarás que un NodePort sigue funcionando como Service interno y, además, que puede alcanzarse desde un cliente externo al clúster Kubernetes.

### Tarea 3.1. Validar acceso interno

- {% include step_label.html %} Crea por tu cuenta un Pod `internal-client` con BusyBox que permanezca Running dentro de `lab25`.

  > **Nota:** El cliente interno permitirá validar el Service mediante DNS sin utilizar NodePort.
  {: .lab-note .info .compact}

  ```text
  Pod:
  - nombre: internal-client
  - namespace: lab25
  - imagen: busybox:1.38.0-musl
  - proceso persistente
  ```

  > **Salida esperada:** `internal-client` queda Running.
  {: .lab-note .output .compact}

- {% include step_label.html %} Demuestra acceso desde `internal-client` hacia `web-public` utilizando el nombre DNS y el puerto del Service.

  > **Importante:** Desde dentro del clúster utiliza `port=8080`; `nodePort=30081` no es necesario para esta ruta.
  {: .lab-note .important .compact}

  ```text
  Debes obtener una respuesta HTTP desde:
  web-public:8080
  ```

  > **Salida esperada:** El cliente interno obtiene el HTML predeterminado de NGINX.
  {: .lab-note .output .compact}

### Tarea 3.2. Validar acceso mediante NodePort

- {% include step_label.html %} Comprueba que los nodos kind pertenecen a la red Docker `kind` que se utilizará para la prueba externa.

  > **Nota:** El cliente Docker temporal no pertenece a Kubernetes; únicamente comparte la red Docker donde viven los contenedores que representan a los nodos kind.
  {: .lab-note .info .compact}

  {%raw%}
  ```bash
  docker network inspect kind --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'
  ```
  {%endraw%}

  > **Salida esperada:** La salida incluye `ckad-control-plane`, `ckad-worker` y `ckad-worker2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Desde un contenedor Docker externo al clúster, accede al NodePort publicado en `ckad-control-plane`.

  > **Importante:** Esta prueba evita depender de `localhost` en Windows y demuestra el acceso mediante el puerto expuesto en un nodo kind.
  {: .lab-note .important .compact}

  ```bash
  docker run --rm --network kind busybox:1.38.0-musl wget -qO- http://ckad-control-plane:30081
  ```

  > **Salida esperada:** El cliente Docker devuelve el HTML predeterminado de NGINX servido por `web-public`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Repite la prueba contra otro nodo para comprobar que el mismo NodePort está publicado en los nodos del clúster.

  > **Nota:** NodePort expone el puerto de nodo para el Service; la implementación de red de Kubernetes dirige después el tráfico hacia un backend válido.
  {: .lab-note .info .compact}

  ```bash
  docker run --rm --network kind busybox:1.38.0-musl wget -qO- http://ckad-worker:30081
  ```

  > **Salida esperada:** El segundo acceso también devuelve el contenido HTML del backend.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🛠️ Tarea 4. Reto: corregir selector y puertos — 6 min

Resolverás un NodePort que inicialmente carece de endpoints y que después conserva un segundo error en `targetPort`.

### Tarea 4.1. Diagnosticar un Service externo sin backends

- {% include step_label.html %} Crea por tu cuenta un Deployment `shop` y un Service NodePort deliberadamente defectuoso con los parámetros proporcionados.

  > **Advertencia:** No corrijas los errores durante la creación; necesitas observar cada síntoma por separado.
  {: .lab-note .warning .compact}

  ```text
  Deployment shop:
  - replicas: 2
  - label: app=shop
  - imagen: nginx:1.31.4-alpine3.24-slim

  Service shop:
  - type: NodePort
  - selector inicial: app=shop-web
  - port: 8080
  - targetPort inicial: 8080
  - nodePort: 30082
  ```

  > **Salida esperada:** Los Pods están Running y el Service existe, pero inicialmente no dispone de backends seleccionados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Investiga selector, labels y EndpointSlices hasta identificar por qué el NodePort no tiene backends.

  > **Importante:** La existencia de un `nodePort` no garantiza que haya Pods detrás del Service.
  {: .lab-note .important .compact}

  ```text
  Determina:
  - labels reales;
  - selector activo;
  - EndpointSlices;
  - causa del primer fallo.
  ```

  > **Salida esperada:** Identificas la diferencia entre `app=shop` y `app=shop-web`.
  {: .lab-note .output .compact}

### Tarea 4.2. Corregir y validar puertos

- {% include step_label.html %} Corrige únicamente el selector y confirma que aparecen endpoints sin modificar todavía `targetPort`.

  > **Nota:** El Service puede adquirir endpoints y continuar fallando por una causa diferente.
  {: .lab-note .info .compact}

  ```text
  Primer estado corregido:
  - selector compatible
  - endpoints presentes
  - targetPort permanece temporalmente en 8080
  ```

  > **Salida esperada:** `shop` comienza a mostrar endpoints asociados a sus Pods.
  {: .lab-note .output .compact}

- {% include step_label.html %} Prueba el NodePort desde un cliente Docker externo, analiza por qué falla pese a existir endpoints y determina el segundo error.

  > **Importante:** NGINX escucha en `80`; disponer de endpoints no corrige automáticamente una traducción de puerto incorrecta.
  {: .lab-note .important .compact}

  ```text
  Debes investigar el acceso externo por:
  ckad-control-plane:30082

  Compara:
  - Service port 8080
  - targetPort 8080
  - puerto real de NGINX 80
  ```

  > **Salida esperada:** Determinas que `targetPort=8080` no corresponde al puerto donde escucha NGINX.
  {: .lab-note .output .compact}

- {% include step_label.html %} Corrige por tu cuenta `targetPort` y demuestra acceso funcional mediante `nodePort=30082`.

  > **Nota:** Conserva `port=8080` y `nodePort=30082`; únicamente el backend port necesita corregirse.
  {: .lab-note .info .compact}

  ```text
  Estado final:
  - port=8080
  - targetPort=80
  - nodePort=30082
  - endpoints presentes
  - acceso externo funcional
  ```

  > **Salida esperada:** Un cliente Docker externo puede obtener una respuesta HTTP mediante `ckad-control-plane:30082`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧭 Tarea 5. Reto: construir una exposición externa completa — 5 min

Diseñarás una solución nueva sin reutilizar los manifiestos anteriores y demostrarás tanto acceso interno como externo.

### Tarea 5.1. Diseñar e implementar la solución

- {% include step_label.html %} Analiza los requisitos de `public-api` y define labels, selector y relación de puertos antes de crear los recursos.

  > **Importante:** El selector debe utilizar labels del Pod template y la aplicación continúa escuchando en puerto `80`.
  {: .lab-note .important .compact}

  ```text
  Deployment:
  - nombre: public-api
  - replicas: 3
  - imagen: nginx:1.31.4-alpine3.24-slim

  Service:
  - nombre: public-api
  - type: NodePort
  - port: 8080
  - targetPort: 80
  - nodePort: 30083
  ```

  > **Salida esperada:** Defines una configuración coherente de labels, selector y puertos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta Deployment y Service y deja las tres réplicas Ready.

  > **Nota:** No continúes si el workload no está disponible o el Service carece de endpoints.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:
  - public-api con 3 Pods Ready
  - Service NodePort existente
  - EndpointSlices con backends
  ```

  > **Salida esperada:** Deployment y Service están disponibles y relacionados correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida por tu cuenta que los EndpointSlices corresponden a los Pods de `public-api`.

  > **Importante:** Esta comprobación confirma la relación selector → backend antes de probar tráfico.
  {: .lab-note .important .compact}

  ```text
  Debes demostrar:
  - selector correcto;
  - tres réplicas elegibles;
  - endpoints publicados.
  ```

  > **Salida esperada:** Los endpoints corresponden a las réplicas del Deployment `public-api`.
  {: .lab-note .output .compact}

### Tarea 5.2. Demostrar exposición interna y externa

- {% include step_label.html %} Valida acceso interno desde `internal-client` mediante DNS y `port=8080`.

  > **Nota:** Un Service NodePort continúa disponible mediante su ClusterIP y DNS dentro del clúster.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec internal-client -n lab25 -- wget -qO- http://public-api:8080
  ```

  > **Salida esperada:** Se devuelve el HTML predeterminado de NGINX.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida acceso externo utilizando un contenedor Docker temporal y `nodePort=30083`.

  > **Importante:** El cliente está fuera de Kubernetes; accede al nodo kind a través de la red Docker `kind`.
  {: .lab-note .important .compact}

  ```bash
  docker run --rm --network kind busybox:1.38.0-musl wget -qO- http://ckad-control-plane:30083
  ```

  > **Salida esperada:** El cliente externo recibe el contenido HTML de `public-api`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Explica la ruta completa del tráfico y distingue los tres puertos utilizados en la solución.

  > **Nota:** El objetivo final es comprender la trayectoria, no solamente obtener una respuesta HTTP.
  {: .lab-note .info .compact}

  ```text
  Explica:

  cliente Docker externo
      ↓
  ckad-control-plane:30083
      ↓ nodePort
  Service public-api
      ↓ port 8080 / selección
  EndpointSlice
      ↓
  Pods public-api
      ↓ targetPort 80
  NGINX
  ```

  > **Salida esperada:** Distingues correctamente `nodePort=30083`, `port=8080` y `targetPort=80` y describes su papel en la ruta.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🧹 Tarea 6. Limpiar el entorno de la práctica — 2 min

La limpieza no forma parte de la proporción 20/80. Ejecútala únicamente después de completar las pruebas internas, externas y de troubleshooting.

### Tarea 6.1. Retirar los recursos del laboratorio

- {% include step_label.html %} Revisa una última vez Deployments, Pods, Services y EndpointSlices antes de eliminar el namespace.

  > **Nota:** Confirma que ya validaste `web-public`, `shop` y `public-api`.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployments,pods,services,endpointslices -n lab25
  ```

  > **Salida esperada:** Se muestran los recursos utilizados durante la práctica y sus estados finales.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab25` cuando ya no necesites los NodePorts ni las pruebas activas.

  > **Advertencia:** La eliminación retira todos los Services NodePort del laboratorio y libera sus puertos.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab25 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab25" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace desapareció del clúster.

  > **Importante:** La ausencia de salida es el resultado esperado con `--ignore-not-found`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab25 --ignore-not-found
  ```

  > **Salida esperada:** No se muestra ningún namespace `lab25`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los manifiestos locales permanecen disponibles para revisar posteriormente la configuración de NodePort.

  > **Nota:** La limpieza afecta únicamente a Kubernetes y conserva `workspace/lab25`.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio conserva los manifiestos creados durante la práctica.
  {: .lab-note .output .compact}

{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

{% include support-prompt.html task="tarea6" %}