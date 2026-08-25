---
layout: lab
title: "Práctica 11: Estrategia blue/green"
permalink: /lab11/lab11/
images_base: /labs/lab11/img
duration: "40 minutos"
objective:
  - Implementar una estrategia blue/green en Kubernetes mediante dos Deployments coexistentes y un Service estable, comprendiendo cómo los labels y selectores permiten cambiar el tráfico entre versiones y recuperar rápidamente la versión anterior sin recrear el punto de acceso.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Haber completado la Práctica 9 Rolling update y rollback.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica implementarás una estrategia blue/green manteniendo dos versiones de una aplicación disponibles al mismo tiempo. Construirás de forma guiada la versión Blue y un Service estable que inicialmente dirigirá el tráfico hacia ella. Después resolverás como reto la creación de Green, comprobarás que ambas versiones pueden coexistir sin compartir tráfico, realizarás el cambio del Service hacia Green y finalmente recuperarás Blue ante un incidente simulado. La práctica concluye con una limpieza independiente que solo debe ejecutarse cuando todos los retos hayan sido validados.
slug: lab11
lab_number: 11
final_result: >
  Al finalizar habrás desplegado dos versiones independientes de una aplicación mediante Deployments Blue y Green, mantenido un único Service como punto estable de acceso y utilizado sus selectores para decidir qué conjunto de Pods recibe tráfico. También habrás ejecutado un cambio Blue a Green y una recuperación Green a Blue sin eliminar ninguna de las dos versiones, demostrando el funcionamiento esencial del patrón blue/green y resolviendo la mitad final de la práctica sin comandos de implementación.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza nginx:1.31.4-alpine3.24-slim para ambas versiones y el contenido HTTP permite distinguir visualmente Blue de Green.
  - La estrategia blue/green de esta práctica se implementa mediante recursos Kubernetes estándar; no existe un objeto API denominado BlueGreen.
  - Los selectores de los dos Deployments no se superponen entre sí; cada uno incluye app=web y un valor diferente para version.
  - Los primeros 12 pasos son guiados y los siguientes 12 pasos corresponden al reto. Los 2 pasos finales de limpieza no forman parte de la proporción 50/50.
references:
  - text: Deployments en Kubernetes
    url: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
  - text: Services en Kubernetes
    url: https://kubernetes.io/docs/concepts/services-networking/service/
  - text: Labels y selectors en Kubernetes
    url: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
  - text: EndpointSlices en Kubernetes
    url: https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
  - text: Imagen oficial de NGINX
    url: https://hub.docker.com/_/nginx
prev: /lab10/lab10/
next: /lab12/lab12/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y comprender la estrategia blue/green — 6 min

Prepararás el workspace y el namespace de la práctica y revisarás el mecanismo que hará posible la conmutación de tráfico. El objetivo es comprender que Blue y Green permanecen desplegados simultáneamente, mientras un Service estable selecciona solo una versión mediante labels.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, comprobarás el contexto Kubernetes y prepararás el namespace donde coexistirán las dos versiones de la aplicación.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab11` y accede a él para mantener separados los manifiestos de esta práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab11`; los archivos locales se conservarán después de limpiar los recursos Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab11 && cd workspace/lab11
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab11`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que kubectl continúa utilizando el contexto del clúster local antes de crear cualquiera de los recursos del escenario blue/green.

  > **Importante:** El contexto esperado es `kind-ckad`. La práctica modifica selectores de Service, por lo que debes asegurarte de trabajar únicamente sobre el clúster del curso.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab11` para aislar las versiones Blue y Green, el Service y el cliente utilizado durante las pruebas.

  > **Advertencia:** Si `lab11` ya existe por una ejecución anterior, revisa primero su contenido para evitar que Pods antiguos coincidan con los selectores utilizados en esta práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab11
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab11 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Reconocer el mecanismo de selección de tráfico

Examinarás los campos que conectan un Service con sus Pods y prepararás un cliente interno desde el que posteriormente probarás el mismo nombre de Service antes y después del cambio de versión.

- {% include step_label.html %} Consulta el campo `selector` de un Service para identificar cómo Kubernetes determina qué Pods forman parte de su backend.

  > **Nota:** Un Service con selector observa continuamente los Pods cuyas etiquetas coinciden y actualiza los EndpointSlices asociados; esta relación será el mecanismo de conmutación entre Blue y Green.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain service.spec.selector
  ```

  > **Salida esperada:** kubectl describe `selector` como el mapa de labels utilizado para dirigir tráfico hacia Pods.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el selector del Deployment para recordar que cada controlador debe administrar únicamente los Pods pertenecientes a su propia versión.

  > **Importante:** Los selectores de `web-blue` y `web-green` incluirán valores distintos de `version`; de esta manera los dos Deployments pueden coexistir sin intentar administrar los mismos Pods.
  {: .lab-note .important .compact}

  ```bash
  kubectl explain deployment.spec.selector
  ```

  > **Salida esperada:** kubectl muestra que `spec.selector` determina qué Pods son administrados por el Deployment.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea un Pod cliente basado en BusyBox que permanecerá activo y servirá para realizar solicitudes HTTP al Service desde dentro del clúster.

  > **Nota:** Mantener un cliente estable permite probar siempre el mismo nombre DNS del Service y comprobar que el backend cambia sin modificar la forma en que el consumidor accede a la aplicación.
  {: .lab-note .info .compact}

  ```bash
  kubectl run client -n lab11 --image=busybox:1.38.0-musl --restart=Never --command -- sh -c 'sleep 3600'
  ```

  > **Salida esperada:** Kubernetes responde `pod/client created`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🔵 Tarea 2. Construir y exponer la versión Blue — 9 min

Construirás de forma guiada la versión inicialmente activa. El Deployment Blue utilizará labels que identifican tanto la aplicación como su versión, mientras que el Service utilizará esos mismos valores para enviar tráfico exclusivamente hacia los Pods Blue.

### Tarea 2.1. Crear la versión Blue

Definirás el Deployment Blue con tres réplicas y contenido HTTP propio, lo aplicarás al clúster y esperarás a que todas las réplicas estén disponibles antes de exponerlas.

- {% include step_label.html %} Crea `blue.yaml` con un Deployment denominado `web-blue`, tres réplicas y labels que distinguen explícitamente esta versión mediante `version: blue`.

  > **Nota:** El contenedor escribe `VERSION BLUE` en la página inicial antes de iniciar NGINX. Esto permite comprobar funcionalmente qué versión respondió sin construir una imagen personalizada.
  {: .lab-note .info .compact}

  ```bash
  cat > blue.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: web-blue
    namespace: lab11
  spec:
    replicas: 3
    selector:
      matchLabels:
        app: web
        version: blue
    template:
      metadata:
        labels:
          app: web
          version: blue
      spec:
        containers:
          - name: nginx
            image: nginx:1.31.4-alpine3.24-slim
            imagePullPolicy: IfNotPresent
            command:
              - /bin/sh
              - -c
              - 'echo "VERSION BLUE" > /usr/share/nginx/html/index.html && exec nginx -g "daemon off;"'
            ports:
              - containerPort: 80
  EOF
  ```

  > **Salida esperada:** Se crea `blue.yaml` con el Deployment `web-blue`, tres réplicas y los labels `app=web` y `version=blue`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el manifiesto Blue para registrar el Deployment y permitir que su controlador cree las tres réplicas solicitadas.

  > **Importante:** El Deployment mantiene su propio selector `app=web,version=blue`; Green utilizará posteriormente otro valor de `version` para evitar cualquier superposición entre controladores.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f blue.yaml
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/web-blue created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que el Deployment Blue complete su rollout antes de utilizarlo como backend activo.

  > **Nota:** La versión no debe recibir tráfico hasta que sus tres réplicas estén disponibles; `rollout status` comprueba el estado del Deployment sin introducir una pausa arbitraria.
  {: .lab-note .info .compact}

  ```bash
  kubectl rollout status deployment/web-blue -n lab11 --timeout=60s
  ```

  > **Salida esperada:** kubectl informa que `deployment "web-blue" successfully rolled out`.
  {: .lab-note .output .compact}

### Tarea 2.2. Crear el punto estable de acceso

Definirás un Service cuyo nombre no cambiará durante la práctica. Inicialmente su selector incluirá `version=blue`, por lo que únicamente los Pods de esa versión aparecerán en los EndpointSlices y recibirán solicitudes.

- {% include step_label.html %} Crea `service.yaml` con un Service ClusterIP denominado `web` cuyo selector apunte exclusivamente a los Pods Blue.

  > **Importante:** El Service utiliza dos condiciones, `app=web` y `version=blue`. El primer label identifica la aplicación y el segundo decide cuál de las versiones desplegadas recibe tráfico.
  {: .lab-note .important .compact}

  ```bash
  cat > service.yaml <<'EOF'
  apiVersion: v1
  kind: Service
  metadata:
    name: web
    namespace: lab11
  spec:
    selector:
      app: web
      version: blue
    ports:
      - port: 80
        targetPort: 80
  EOF
  ```

  > **Salida esperada:** Se crea `service.yaml` con un Service `web` que selecciona `app=web,version=blue`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el Service para crear el endpoint estable que utilizará el cliente independientemente de cuál versión sea activa.

  > **Nota:** El Service conserva su nombre `web` durante todo el escenario. El cambio blue/green se realizará sobre su selector y no creando un segundo endpoint para el consumidor.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f service.yaml
  ```

  > **Salida esperada:** Kubernetes responde `service/web created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Realiza una solicitud HTTP desde el Pod cliente al nombre DNS `web` para comprobar qué versión recibe el tráfico inicialmente.

  > **Importante:** El cliente no conoce nombres de Pods ni de Deployments; utiliza exclusivamente el Service. Este desacoplamiento permite cambiar el backend sin modificar al consumidor.
  {: .lab-note .important .compact}

  ```bash
  kubectl exec client -n lab11 -- wget -qO- http://web
  ```

  > **Salida esperada:** La respuesta es exactamente `VERSION BLUE`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🟢 Tarea 3. Reto: construir y preparar la versión Green — 9 min

A partir de esta tarea comienza la parte no guiada. Deberás construir una segunda versión completa sin interrumpir Blue y demostrar que Green está preparada antes de recibir tráfico. Los comandos proporcionados serán únicamente de observación o validación.

### Tarea 3.1. Construir Green sin afectar Blue

Interpretarás los requisitos del nuevo ambiente, construirás por tu cuenta el Deployment y validarás que alcanza el estado esperado manteniendo intacta la versión activa.

- {% include step_label.html %} Analiza el escenario y determina qué elementos del Deployment Blue debes reutilizar conceptualmente y cuáles deben diferenciar obligatoriamente a Green.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl --help`, `kubectl explain` y los manifiestos creados en las tareas guiadas como referencia.
  {: .lab-note .important .compact}

  ```text
  Reto Green:

  Prepara una nueva versión sin interrumpir Blue.

  Requisitos:
  - Deployment: web-green
  - Namespace: lab11
  - Réplicas: 3
  - Imagen: nginx:1.31.4-alpine3.24-slim
  - Labels del Pod:
      app=web
      version=green
  - El selector del Deployment debe corresponder a esos labels.
  - Puerto del contenedor: 80
  - La página inicial debe responder exactamente: VERSION GREEN
  - Los tres Pods deben quedar Ready.
  - No modifiques web-blue.
  - No modifiques todavía el Service web.
  ```

  > **Salida esperada:** Identificas que Green necesita su propio Deployment y selector, pero debe compartir el label de aplicación `app=web`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta el Deployment `web-green` y espera hasta considerar que la nueva versión está preparada para recibir tráfico.

  > **Nota:** Puedes crear un nuevo manifiesto dentro de `workspace/lab11` utilizando `blue.yaml` como referencia, pero no debes editar Blue para convertirlo en Green.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora la versión Green.

  No continúes hasta considerar satisfechos:
  - nombre;
  - réplicas;
  - labels y selector;
  - imagen;
  - contenido HTTP;
  - disponibilidad.
  ```

  > **Salida esperada:** Existe `deployment/web-green` con tres réplicas disponibles y Blue continúa desplegado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el Deployment Green y corrige por tu cuenta cualquier propiedad que todavía no coincida con los requisitos.

  > **Advertencia:** No modifiques el Service durante esta validación. Una característica fundamental del patrón es preparar completamente Green antes de enviarle tráfico de usuarios.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get deployment web-green -n lab11 -o wide
  ```

  > **Salida esperada:** `web-green` muestra `3/3` réplicas disponibles y utiliza la imagen solicitada.
  {: .lab-note .output .compact}

### Tarea 3.2. Demostrar la coexistencia de Blue y Green

Comprobarás que las dos versiones tienen sus propias réplicas, identificarás cuál continúa seleccionando el Service y demostrarás mediante una solicitud real que Green todavía no recibe tráfico.

- {% include step_label.html %} Lista conjuntamente los Pods Blue y Green para comprobar que ambos grupos existen simultáneamente y pueden distinguirse mediante sus labels.

  > **Nota:** Blue/green mantiene dos conjuntos funcionales al mismo tiempo. Esto permite realizar el cambio de tráfico sin tener que crear Green en el momento del cutover.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab11 -l app=web --show-labels
  ```

  > **Salida esperada:** Se muestran seis Pods Ready: tres con `version=blue` y tres con `version=green`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona el selector actual del Service para identificar qué versión está autorizada a formar parte de su backend.

  > **Importante:** No cambies todavía el selector. Este paso comprueba que preparar Green no alteró el enrutamiento activo.
  {: .lab-note .important .compact}

  ```bash
  kubectl get service web -n lab11 -o jsonpath='Selector={.spec.selector}{"\n"}'
  ```

  > **Salida esperada:** El selector contiene `app:web` y `version:blue`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Solicita nuevamente la aplicación desde el cliente para demostrar que la existencia de Green no modifica por sí sola la versión atendida por el Service.

  > **Nota:** El Service sigue resolviendo mediante el mismo nombre `web`; la respuesta debe continuar proveniendo de Blue mientras su selector no cambie.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec client -n lab11 -- wget -qO- http://web
  ```

  > **Salida esperada:** La respuesta continúa siendo `VERSION BLUE`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🔀 Tarea 4. Reto: realizar el cutover y recuperar Blue — 12 min

Ejecutarás las dos operaciones esenciales del patrón blue/green. Primero cambiarás el tráfico hacia una versión Green ya preparada y después responderás a un incidente devolviendo el mismo Service a Blue, sin eliminar Deployments ni cambiar el endpoint utilizado por el cliente.

### Tarea 4.1. Cambiar el tráfico de Blue hacia Green

Interpretarás las restricciones del cutover, realizarás por tu cuenta el cambio mínimo necesario y validarás que el Service conserva su identidad mientras su conjunto de backends pasa a Green.

- {% include step_label.html %} Analiza la solicitud de cambio a producción y determina qué recurso debe modificarse para dirigir el mismo endpoint hacia Green.

  > **Importante:** El objetivo no es desplegar nuevamente Green ni crear otro Service. La solución debe conservar las dos versiones y el punto de acceso existente.
  {: .lab-note .important .compact}

  ```text
  Cambio aprobado:

  Green ha superado las validaciones y debe recibir el tráfico.

  Restricciones:
  - No elimines web-blue.
  - No elimines web-green.
  - No recrees el Service web.
  - El nombre del Service debe continuar siendo web.
  - Solo los Pods Green deben quedar seleccionados por web.
  - El cliente debe seguir utilizando http://web.
  ```

  > **Salida esperada:** Determinas qué propiedad del Service controla el conjunto de Pods que debe recibir tráfico.
  {: .lab-note .output .compact}

- {% include step_label.html %} Realiza por tu cuenta el cutover Blue → Green respetando todas las restricciones del escenario.

  > **Advertencia:** No cambies los labels de los Pods ni los selectores de los Deployments para forzar el resultado. La conmutación debe preservar ambos grupos como versiones independientes.
  {: .lab-note .warning .compact}

  ```text
  Ejecuta ahora el cambio de tráfico.

  Antes de continuar confirma por tu cuenta que:
  - el Service sigue existiendo;
  - Blue sigue desplegado;
  - Green sigue desplegado;
  - el selector activo corresponde únicamente a Green.
  ```

  > **Salida esperada:** El Service `web` permanece en el namespace y su backend activo cambia de Blue a Green.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba directamente el selector del Service después del cutover para verificar que el cambio quedó almacenado en el API Server.

  > **Nota:** Esta consulta evalúa el estado declarativo del Service; una solución correcta debe mostrar ahora el valor Green sin haber cambiado el nombre del recurso.
  {: .lab-note .info .compact}

  ```bash
  kubectl get service web -n lab11 -o jsonpath='Service={.metadata.name} Selector={.spec.selector}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Service=web` y el selector contiene `version:green`.
  {: .lab-note .output .compact}

### Tarea 4.2. Recuperar Blue ante un incidente

Simularás una decisión de recuperación posterior al cambio. Deberás devolver el tráfico hacia la versión anterior utilizando el mismo mecanismo de conmutación y confirmar que Green permanece disponible para análisis.

- {% include step_label.html %} Verifica funcionalmente el cutover desde el mismo Pod cliente antes de recibir el incidente de recuperación.

  > **Importante:** La comprobación se realiza desde el mismo consumidor y con el mismo nombre DNS utilizado para Blue; únicamente el backend del Service debe haber cambiado.
  {: .lab-note .important .compact}

  ```bash
  kubectl exec client -n lab11 -- wget -qO- http://web
  ```

  > **Salida esperada:** La respuesta cambia a `VERSION GREEN`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Analiza el incidente y recupera por tu cuenta Blue sin eliminar Green ni recrear el Service.

  > **Advertencia:** La recuperación debe ser una conmutación de tráfico, no un rollback del Deployment Green ni una eliminación de recursos. Ambas versiones deben continuar existiendo después de la operación.
  {: .lab-note .warning .compact}

  ```text
  Incidente:

  Después del cutover se detectó un problema funcional en Green.

  Recupera el servicio cumpliendo:
  - El mismo Service web debe volver a dirigir tráfico a Blue.
  - No elimines Green.
  - No recrees Blue.
  - No recrees el Service.
  - Los 3 Pods Blue deben permanecer Ready.
  - Los 3 Pods Green deben permanecer Ready.
  ```

  > **Salida esperada:** El selector del Service vuelve a identificar Blue y ambos Deployments permanecen desplegados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta la validación funcional final desde el cliente y comprueba que la recuperación devolvió el endpoint estable a la versión Blue.

  > **Nota:** Si la respuesta continúa siendo Green, revisa por tu cuenta el selector del Service y la coincidencia de labels antes de considerar finalizado el reto.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec client -n lab11 -- wget -qO- http://web
  ```

  > **Salida esperada:** La respuesta vuelve a ser `VERSION BLUE`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar el entorno de la práctica — 4 min

Esta tarea no forma parte de la evaluación 50/50. Debes ejecutarla únicamente después de terminar el reto completo, verificar el cutover Blue → Green, comprobar la recuperación Green → Blue y confirmar que ya no necesitas conservar los recursos activos para revisión.

### Tarea 5.1. Retirar los recursos del laboratorio

Eliminarás de forma controlada el namespace utilizado por la práctica y comprobarás posteriormente que Kubernetes completó la limpieza, conservando los manifiestos locales como material de estudio.

- {% include step_label.html %} Cuando hayas terminado completamente los retos y confirmado todos los resultados, elimina el namespace `lab11` para retirar las dos versiones, el Service y el cliente de prueba.

  > **Advertencia:** No ejecutes este paso mientras todavía estés resolviendo o revisando el reto. La eliminación del namespace borra todos los recursos namespaced utilizados para demostrar la estrategia blue/green.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab11 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab11" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que `lab11` ya no existe para confirmar que el clúster quedó preparado para la siguiente práctica.

  > **Importante:** Conserva `workspace/lab11` y sus manifiestos locales; la limpieza debe afectar únicamente a los recursos activos de Kubernetes.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab11 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab11`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}