---
layout: lab
title: "Práctica 26: Publicación con Ingress"
permalink: /lab26/lab26/
images_base: /labs/lab26/img
duration: "45 minutos"
objective:
  - Publicar aplicaciones HTTP mediante Ingress y Gateway API, implementar routing por host y path, relacionar Ingress con Services y migrar reglas hacia Gateway y HTTPRoute utilizando un controller moderno y mantenido.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 24 Exposición interna con Service ClusterIP.
  - Haber completado la Práctica 25 Exposición externa básica.
  - Disponer de Helm instalado y funcional.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Disponer de Docker Desktop funcionando con contenedores Linux.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica trabajarás primero con el recurso estable Ingress para publicar Services mediante reglas HTTP por hostname y path. Después migrarás el mismo modelo hacia Gateway API utilizando Gateway y HTTPRoute. Traefik actuará como controller para ambos mecanismos, permitiendo comparar la API tradicional de Ingress con el modelo moderno recomendado por Kubernetes. Las pruebas externas se ejecutarán desde un contenedor Docker conectado a la red kind y utilizarán headers Host explícitos, evitando modificaciones al DNS o al archivo hosts del equipo.
slug: lab26
lab_number: 26
final_result: >
  Al finalizar habrás publicado aplicaciones mediante Ingress y Gateway API, validado routing HTTP por host y path, identificado la función del controller, relacionado reglas con Services y EndpointSlices y migrado una publicación desde Ingress hacia Gateway y HTTPRoute. También habrás demostrado tráfico externo mediante un único Traefik Controller y explicado las diferencias entre ambos modelos.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - La práctica utiliza Gateway API Standard v1.6.1 y Traefik Helm chart 41.2.0, cuyo Traefik Proxy predeterminado pertenece a la línea 3.7.
  - El recurso Ingress networking.k8s.io/v1 continúa estable, pero su API está congelada; Kubernetes recomienda Gateway API para nuevas capacidades.
  - Se utiliza ingressClassName traefik en lugar de depender de la anotación histórica kubernetes.io/ingress.class.
  - Gateway API separa responsabilidades mediante GatewayClass, Gateway y HTTPRoute.
  - Traefik queda instalado como infraestructura compartida del clúster después de la práctica; únicamente se elimina el namespace lab26.
  - El Service de Traefik utiliza NodePort 30084 para las pruebas externas desde un contenedor Docker conectado a la red kind.
  - Los primeros 5 pasos son guiados y los siguientes 20 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 20/80.
references:
  - text: Kubernetes Ingress
    url: https://kubernetes.io/docs/concepts/services-networking/ingress/
  - text: Kubernetes Ingress Controllers
    url: https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/
  - text: Gateway API Getting Started
    url: https://gateway-api.sigs.k8s.io/guides/getting-started/introduction/
  - text: Traefik Kubernetes Gateway API
    url: https://doc.traefik.io/traefik/providers/kubernetes-gateway/
  - text: Traefik Kubernetes Quick Start
    url: https://doc.traefik.io/traefik/getting-started/quick-start-with-kubernetes/
prev: /lab25/lab25/
next: /lab27/lab27/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar el controller y comprender los modelos de publicación — 9 min

Prepararás el workspace e instalarás la infraestructura necesaria para que un mismo Traefik Controller procese recursos Ingress y Gateway API.

### Tarea 1.1. Preparar el entorno

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea `workspace/lab26` y accede al directorio para almacenar los manifiestos de publicación.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab26`.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab26 && cd workspace/lab26
  ```

  > **Salida esperada:** La terminal queda ubicada dentro de `ckad-labs/workspace/lab26`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo antes de instalar CRDs y un controller con alcance de clúster.

  > **Importante:** El contexto esperado es `kind-ckad`.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab26` para aislar los backends, Services, Ingress, Gateway y HTTPRoute de la práctica.

  > **Advertencia:** Si el namespace ya existe, revisa sus reglas de routing antes de continuar para evitar conflictos con hostnames reutilizados.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab26
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab26 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Instalar Gateway API y Traefik

- {% include step_label.html %} Instala las CRDs Standard de Gateway API v1.6.1 y despliega Traefik chart 41.2.0 con los providers de Ingress y Gateway API habilitados y NodePort `30084` para HTTP.

  > **Importante:** El recurso Ingress por sí solo no procesa tráfico. Traefik será el controller que observe tanto Ingress como Gateway API durante toda la práctica.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
  ```
  ```bash
  helm repo add traefik https://traefik.github.io/charts
  helm repo update
  ```
  ```bash
  helm upgrade --install traefik traefik/traefik --namespace traefik --create-namespace --version 41.2.0 --set providers.kubernetesIngress.enabled=true --set providers.kubernetesGateway.enabled=true --set service.type=NodePort --set ports.web.nodePort=30084 --wait
  ```

  > **Salida esperada:** Gateway API CRDs quedan registradas y el release Helm `traefik` finaliza correctamente en el namespace `traefik`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba la disponibilidad del controller, la IngressClass y la GatewayClass para confirmar que ambos modelos pueden utilizar la misma implementación.

  > **Nota:** Ingress utiliza `IngressClass`; Gateway API utiliza `GatewayClass`. Ambas representan la relación con un controller, pero pertenecen a modelos de API diferentes.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n traefik
  ```
  ```bash
  kubectl get ingressclass
  ```
  ```bash
  kubectl get gatewayclass
  ```

  > **Salida esperada:** Traefik está Running y existen clases administradas por Traefik para procesar Ingress y Gateway API.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: publicar una aplicación mediante Ingress — 7 min

Construirás un backend interno y lo publicarás por hostname mediante un recurso Ingress estándar.

### Tarea 2.1. Crear el backend interno

- {% include step_label.html %} Analiza los requisitos de `web` y define una relación correcta entre Deployment y Service antes de crear cualquier regla externa.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Conserva manifiestos locales y utiliza los recursos aprendidos en las prácticas anteriores.
  {: .lab-note .important .compact}

  ```text
  Deployment:
  - nombre: web
  - namespace: lab26
  - replicas: 2
  - imagen: nginx:1.31.4-alpine3.24-slim
  - puerto de aplicación: 80

  Service:
  - nombre: web
  - type: ClusterIP
  - port: 80
  - targetPort: 80
  ```

  > **Salida esperada:** Defines labels, selector y puertos compatibles entre `web` y su Service.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta Deployment y Service y confirma que el Service dispone de endpoints antes de crear el Ingress.

  > **Nota:** Un Ingress correctamente escrito no puede compensar un Service sin backends.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:
  - web con 2 Pods Ready;
  - Service web existente;
  - EndpointSlices con backends.
  ```

  > **Salida esperada:** El backend está disponible internamente y listo para recibir una regla Ingress.
  {: .lab-note .output .compact}

### Tarea 2.2. Publicar por hostname

- {% include step_label.html %} Crea por tu cuenta un Ingress `web` que utilice `ingressClassName: traefik` y publique el Service mediante el hostname solicitado.

  > **Importante:** Utiliza la API `networking.k8s.io/v1`, `pathType: Prefix` y referencia el puerto del Service, no el `targetPort`.
  {: .lab-note .important .compact}

  ```text
  Ingress:
  - nombre: web
  - namespace: lab26
  - ingressClassName: traefik
  - host: web.lab26.local
  - path: /
  - pathType: Prefix
  - backend Service: web
  - backend port: 80
  ```

  > **Salida esperada:** El Ingress existe y contiene una regla hacia `web:80`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida la publicación desde un cliente Docker externo utilizando el NodePort del controller y un header Host explícito.

  > **Nota:** El hostname no necesita registrarse en DNS ni en el archivo hosts porque el header HTTP se envía directamente durante la prueba.
  {: .lab-note .info .compact}

  ```bash
  docker run --rm --network kind busybox:1.38.0-musl wget -qO- --header='Host: web.lab26.local' http://ckad-control-plane:30084/
  ```

  > **Salida esperada:** Se devuelve el HTML predeterminado de NGINX publicado mediante el Ingress.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🛣️ Tarea 3. Reto: implementar routing por path con Ingress — 9 min

Crearás dos backends diferenciados y utilizarás un solo hostname para dirigir rutas distintas hacia Services independientes.

### Tarea 3.1. Crear backends diferenciados

- {% include step_label.html %} Diseña dos backends llamados `frontend` y `api` que permitan reconocer inequívocamente qué Service atendió cada solicitud.

  > **Importante:** El backend `api` debe responder correctamente cuando reciba una solicitud bajo `/api`; evita depender de anotaciones de rewrite específicas de un controller.
  {: .lab-note .important .compact}

  ```text
  frontend:
  - Deployment y Service ClusterIP
  - 2 replicas
  - respuesta identificable como FRONTEND
  - debe responder en /

  api:
  - Deployment y Service ClusterIP
  - 2 replicas
  - respuesta identificable como API
  - debe responder bajo /api
  ```

  > **Salida esperada:** Defines dos aplicaciones distinguibles y compatibles con las rutas solicitadas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta ambos backends y valida sus EndpointSlices antes de crear el routing L7.

  > **Nota:** Comprueba los backends de forma independiente para no confundir un error de aplicación con un error de Ingress.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:
  - frontend Ready con endpoints;
  - api Ready con endpoints.
  ```

  > **Salida esperada:** Ambos Services disponen de backends elegibles.
  {: .lab-note .output .compact}

### Tarea 3.2. Crear y validar reglas por path

- {% include step_label.html %} Crea un Ingress `apps` que publique `frontend` y `api` bajo el mismo hostname utilizando reglas Prefix.

  > **Importante:** La ruta `/api` es más específica que `/`; ambas deben pertenecer al host `apps.lab26.local`.
  {: .lab-note .important .compact}

  ```text
  Host: apps.lab26.local

  /     -> frontend
  /api  -> api

  ingressClassName: traefik
  ```

  > **Salida esperada:** El Ingress `apps` contiene dos paths y cada uno referencia el Service correspondiente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida desde un cliente externo que `/` y `/api` producen respuestas de backends diferentes.

  > **Nota:** Utiliza el mismo NodePort y cambia únicamente el path manteniendo el hostname.
  {: .lab-note .info .compact}

  ```text
  Debes probar:
  - Host apps.lab26.local + /
  - Host apps.lab26.local + /api

  Ambas solicitudes deben responder correctamente
  y permitir distinguir FRONTEND de API.
  ```

  > **Salida esperada:** `/` llega a `frontend` y `/api` llega a `api`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona el Ingress activo y relaciona cada backend con el puerto real del Service que utiliza.

  > **Importante:** El backend de Ingress referencia `Service.name` y `Service.port`; no referencia directamente Pods ni `targetPort`.
  {: .lab-note .important .compact}

  ```bash
  kubectl describe ingress apps -n lab26
  ```

  > **Salida esperada:** Se observan las reglas de `apps.lab26.local`, sus dos paths y los Services de backend.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🔄 Tarea 4. Reto: migrar de Ingress a Gateway API — 9 min

Recrearás el routing anterior utilizando el modelo Gateway API para comparar responsabilidades y estructura sin cambiar los Services existentes.

### Tarea 4.1. Traducir el modelo de publicación

- {% include step_label.html %} Analiza el Ingress `apps` y determina cómo se distribuyen sus responsabilidades entre `Gateway` y `HTTPRoute`.

  > **Importante:** El Gateway define el punto de entrada y sus listeners; HTTPRoute define hostnames, matches y backendRefs.
  {: .lab-note .important .compact}

  ```text
  Traduce conceptualmente:

  IngressClass
      -> GatewayClass

  reglas de entrada
      -> Gateway listener

  host + paths + backends
      -> HTTPRoute
  ```

  > **Salida esperada:** Identificas qué elementos pertenecen al Gateway y cuáles deben quedar dentro del HTTPRoute.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta un Gateway `lab26-gateway` y un HTTPRoute `apps-gateway` que reproduzcan el routing con un hostname nuevo.

  > **Nota:** Utiliza las APIs estables `gateway.networking.k8s.io/v1` y conserva los Services `frontend` y `api`.
  {: .lab-note .info .compact}

  ```text
  Gateway:
  - nombre: lab26-gateway
  - namespace: lab26
  - gatewayClassName: traefik
  - listener HTTP
  - port: 80
  - protocol: HTTP

  HTTPRoute:
  - nombre: apps-gateway
  - hostname: apps-gw.lab26.local
  - /     -> frontend
  - /api  -> api
  ```

  > **Salida esperada:** Gateway y HTTPRoute quedan creados y el route referencia los Services existentes.
  {: .lab-note .output .compact}

### Tarea 4.2. Validar Gateway y HTTPRoute

- {% include step_label.html %} Inspecciona las condiciones del Gateway para comprobar que el controller aceptó y programó la infraestructura solicitada.

  > **Importante:** En Gateway API las condiciones permiten verificar si el recurso fue aceptado y programado antes de culpar a los backends.
  {: .lab-note .important .compact}

  ```bash
  kubectl get gateway lab26-gateway -n lab26
  ```
  ```bash
  kubectl describe gateway lab26-gateway -n lab26
  ```

  > **Salida esperada:** El Gateway presenta condiciones que indican aceptación por el controller y un listener HTTP válido.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona `apps-gateway` y confirma que se encuentra asociado al Gateway y que sus referencias de backend son válidas.

  > **Nota:** HTTPRoute utiliza `parentRefs` para adjuntarse a Gateway y `backendRefs` para dirigir tráfico hacia Services.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe httproute apps-gateway -n lab26
  ```

  > **Salida esperada:** El HTTPRoute aparece aceptado por `lab26-gateway` y sus reglas apuntan a `frontend` y `api`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Demuestra desde el cliente Docker externo que Gateway API reproduce el comportamiento de las dos rutas utilizando el nuevo hostname.

  > **Importante:** El objetivo es cambiar el modelo de configuración sin cambiar los backends de aplicación.
  {: .lab-note .important .compact}

  ```text
  Valida mediante NodePort 30084:

  Host: apps-gw.lab26.local
  /     -> FRONTEND
  /api  -> API
  ```

  > **Salida esperada:** Ambas rutas funcionan mediante Gateway API y producen las mismas respuestas lógicas que la publicación Ingress.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧭 Tarea 5. Reto: construir una publicación completa con Gateway API — 9 min

Diseñarás una nueva publicación con tres rutas utilizando exclusivamente Gateway API para la configuración L7.

### Tarea 5.1. Diseñar e implementar la arquitectura

- {% include step_label.html %} Diseña tres backends independientes que puedan identificarse por su respuesta y que soporten las rutas requeridas sin rewrites propietarios.

  > **Importante:** Mantén los backends detrás de Services ClusterIP; Gateway API debe referenciar Services y no Pods directamente.
  {: .lab-note .important .compact}

  ```text
  Backends:

  portal
  - respuesta PORTAL
  - ruta /

  api-v2
  - respuesta API-V2
  - ruta /api

  metrics
  - respuesta METRICS
  - ruta /metrics
  ```

  > **Salida esperada:** Defines Deployments y Services capaces de responder correctamente en las tres rutas solicitadas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta los tres backends y valida que todos dispongan de Pods Ready y EndpointSlices.

  > **Nota:** No construyas todavía el HTTPRoute si algún Service carece de endpoints.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:
  - portal Ready;
  - api-v2 Ready;
  - metrics Ready;
  - los tres Services con endpoints.
  ```

  > **Salida esperada:** Los tres backends están disponibles internamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea por tu cuenta la configuración Gateway API necesaria para publicar los tres backends bajo `platform.lab26.local`.

  > **Importante:** Puedes reutilizar `lab26-gateway` o justificar un Gateway nuevo; las tres reglas deben estar expresadas mediante HTTPRoute.
  {: .lab-note .important .compact}

  ```text
  Host:
  platform.lab26.local

  Routing:
  /         -> portal
  /api      -> api-v2
  /metrics  -> metrics
  ```

  > **Salida esperada:** Existe un HTTPRoute aceptado que representa las tres reglas.
  {: .lab-note .output .compact}

### Tarea 5.2. Demostrar routing y comparar modelos

- {% include step_label.html %} Verifica condiciones y referencias del HTTPRoute antes de realizar las pruebas externas.

  > **Nota:** Utiliza el estado de Gateway API para detectar problemas de asociación o backends antes de probar conectividad.
  {: .lab-note .info .compact}

  ```text
  Debes confirmar:
  - parent Gateway aceptado;
  - HTTPRoute aceptado;
  - tres reglas presentes;
  - backendRefs hacia Services correctos.
  ```

  > **Salida esperada:** El route aparece asociado al Gateway sin errores de referencias.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta pruebas externas para `/`, `/api` y `/metrics` utilizando el hostname `platform.lab26.local`.

  > **Importante:** Las tres solicitudes deben entrar por Traefik NodePort `30084` y diferenciar claramente el backend alcanzado.
  {: .lab-note .important .compact}

  ```text
  Valida desde un contenedor Docker externo:

  /         -> PORTAL
  /api      -> API-V2
  /metrics  -> METRICS
  ```

  > **Salida esperada:** Las tres rutas responden mediante los Services correctos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Explica la diferencia arquitectónica entre la publicación Ingress inicial y la solución final con Gateway API.

  > **Nota:** No basta con indicar que ambas enrutan HTTP; describe cómo Gateway API separa infraestructura de rutas.
  {: .lab-note .info .compact}

  ```text
  Compara:

  Ingress:
  IngressClass
       ↓
  Ingress
       ↓
  Services

  Gateway API:
  GatewayClass
       ↓
  Gateway
       ↓
  HTTPRoute
       ↓
  Services
  ```

  > **Salida esperada:** Explicas que Ingress concentra reglas en un único recurso mientras Gateway API separa clase, punto de entrada y rutas mediante recursos independientes.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🧹 Tarea 6. Limpiar el entorno de la práctica — 2 min

La limpieza no forma parte de la proporción 20/80. Eliminarás los recursos de `lab26`, pero conservarás Traefik, Gateway API CRDs y sus clases como infraestructura compartida del clúster.

### Tarea 6.1. Retirar los recursos del laboratorio

- {% include step_label.html %} Revisa una última vez Deployments, Services, Ingress, Gateway y HTTPRoute antes de eliminar el namespace.

  > **Nota:** Confirma que completaste tanto las pruebas Ingress como las pruebas Gateway API.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployments,pods,services,ingresses,gateways,httproutes -n lab26
  ```

  > **Salida esperada:** Se muestran los recursos creados durante ambas fases de publicación.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab26` únicamente cuando ya no necesites conservar reglas ni evidencia de routing.

  > **Advertencia:** La eliminación destruye los backends, Ingress, Gateway y HTTPRoute namespaced, pero no desinstala Traefik ni las CRDs de Gateway API.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab26 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab26" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace ya no existe.

  > **Importante:** La ausencia de salida es el resultado esperado con `--ignore-not-found`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab26 --ignore-not-found
  ```

  > **Salida esperada:** No se muestra ningún namespace `lab26`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los archivos locales permanecen disponibles para comparar manifiestos Ingress y Gateway API después de la limpieza.

  > **Nota:** Traefik y Gateway API permanecen instalados; `workspace/lab26` conserva el material de estudio.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio conserva los manifiestos creados durante la práctica.
  {: .lab-note .output .compact}

{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

{% include support-prompt.html task="tarea6" %}