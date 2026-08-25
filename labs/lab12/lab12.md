---
layout: lab
title: "Práctica 12: Estrategia canary"
permalink: /lab12/lab12/
images_base: /labs/lab12/img
duration: "40 minutos"
objective:
  - Implementar una estrategia canary en Kubernetes mediante Deployments Stable y Canary que comparten un Service, comprender cómo la cantidad relativa de Pods modifica la exposición de cada versión y resolver escenarios de incremento, promoción y recuperación sin cambiar el endpoint utilizado por los consumidores.
prerequisites:
  - Haber completado la Práctica 11 Estrategia blue/green.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica implementarás una estrategia canary utilizando dos Deployments que representan una versión Stable y una versión Canary de la misma aplicación. Ambas compartirán el label que utiliza un único Service, por lo que coexistirán como backends del mismo endpoint. Primero construirás de forma guiada el escenario inicial con mayor cantidad de réplicas Stable y una réplica Canary. Después resolverás como reto el incremento progresivo de Canary, su promoción relativa y una recuperación ante un incidente, interpretando la distribución observada sin asumir porcentajes exactos de tráfico.
slug: lab12
lab_number: 12
final_result: >
  Al finalizar habrás desplegado versiones Stable y Canary detrás de un único Service, comprobado que ambas pueden recibir solicitudes mientras conservan Deployments independientes y modificado su exposición relativa ajustando la cantidad de réplicas disponibles. También habrás resuelto escenarios de incremento, promoción y recuperación de Canary sin recibir comandos de implementación, comprendiendo que un Service estándar no proporciona ponderación porcentual exacta y que la práctica utiliza el número relativo de endpoints como aproximación didáctica.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza nginx:1.31.4-alpine3.24-slim para Stable y Canary; cada Deployment sirve un contenido HTTP diferente para identificar la versión que respondió.
  - El Service selecciona únicamente app=web, mientras cada Deployment utiliza además track=stable o track=canary para mantener separados sus Pods.
  - Un Service estándar no garantiza una distribución exacta como 80/20 o 90/10. La cantidad relativa de Pods se utiliza en esta práctica para observar una exposición aproximada entre versiones.
  - Los primeros 12 pasos son guiados y los siguientes 12 pasos corresponden al reto. Los 2 pasos finales de limpieza no forman parte de la proporción 50/50.
references:
  - text: Services en Kubernetes
    url: https://kubernetes.io/docs/concepts/services-networking/service/
  - text: Labels y selectors en Kubernetes
    url: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
  - text: EndpointSlices en Kubernetes
    url: https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
  - text: Deployments en Kubernetes
    url: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
  - text: Imagen oficial de NGINX
    url: https://hub.docker.com/_/nginx
prev: /lab11/lab11/
next: /lab13/lab13/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y comprender la estrategia canary — 6 min

Prepararás el workspace y el namespace de la práctica y revisarás el mecanismo que permitirá que Stable y Canary formen parte simultáneamente del mismo Service. El objetivo es distinguir esta estrategia de blue/green y comprender qué papel cumplen los labels y los endpoints disponibles.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, confirmarás el contexto de kubectl y prepararás un namespace aislado donde coexistirán las dos versiones de la aplicación y el cliente utilizado para generar solicitudes.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab12` y accede a él para almacenar todos los manifiestos de la práctica sin mezclarlos con ejercicios anteriores.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab12`; los archivos locales se conservarán incluso después de eliminar los recursos Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab12 && cd workspace/lab12
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab12`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo para asegurarte de que todas las operaciones de la práctica se realizarán sobre el clúster local del curso.

  > **Importante:** El valor esperado es `kind-ckad`. No continúes si kubectl apunta a un contexto diferente.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab12` para aislar Deployments, Service, Pods y pruebas de tráfico utilizados durante el escenario Canary.

  > **Advertencia:** Si `lab12` ya existe por una ejecución anterior, revisa primero su contenido para evitar que recursos antiguos coincidan con los selectors de esta práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab12
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab12 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Reconocer cómo compartir tráfico entre versiones

Consultarás los campos que permiten a un Service seleccionar Pods y prepararás un cliente interno que realizará todas las pruebas sobre un único endpoint, independientemente de qué versión responda.

- {% include step_label.html %} Consulta la definición de `Service.spec.selector` para recordar cómo un Service determina qué Pods pueden convertirse en backends de red.

  > **Nota:** En esta práctica el Service utilizará únicamente `app=web`; por ello tanto Stable como Canary podrán coincidir con el selector aunque cada versión mantenga un label `track` diferente.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain service.spec.selector
  ```

  > **Salida esperada:** kubectl describe `selector` como el mapa de labels utilizado para dirigir el tráfico hacia Pods.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta `Deployment.spec.selector` para relacionar cada Deployment con los Pods de su propia versión y evitar que ambos controladores administren el mismo conjunto de réplicas.

  > **Importante:** `web-stable` utilizará `app=web,track=stable` y `web-canary` utilizará `app=web,track=canary`; los selectores de los Deployments no deben superponerse.
  {: .lab-note .important .compact}

  ```bash
  kubectl explain deployment.spec.selector
  ```

  > **Salida esperada:** kubectl muestra que el selector del Deployment identifica los Pods que administra ese controlador.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea un Pod cliente que permanezca activo y permita realizar múltiples solicitudes al mismo Service desde dentro del clúster durante toda la práctica.

  > **Nota:** Utilizar siempre el mismo cliente y el mismo nombre DNS permite observar cambios en los backends sin modificar la forma en que el consumidor accede a la aplicación.
  {: .lab-note .info .compact}

  ```bash
  kubectl run client -n lab12 --image=busybox:1.38.0-musl --restart=Never --command -- sh -c 'sleep 3600'
  ```

  > **Salida esperada:** Kubernetes responde `pod/client created`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🟦 Tarea 2. Construir Stable e introducir Canary — 9 min

Construirás de forma guiada las dos versiones iniciales. Stable comenzará con cuatro réplicas y Canary con una sola, mientras un único Service seleccionará ambos grupos mediante `app=web`. Después generarás varias solicitudes para comprobar que las dos versiones pueden responder.

### Tarea 2.1. Crear Stable y el Service compartido

Definirás en un mismo manifiesto el Deployment Stable y el Service estable. El Deployment utilizará un selector específico de versión, mientras que el Service utilizará un selector más amplio que posteriormente también coincidirá con los Pods Canary.

- {% include step_label.html %} Crea `stable.yaml` con el Deployment `web-stable` de cuatro réplicas y el Service `web`, asegurando que el Service seleccione únicamente `app=web` y no el label `track`.

  > **Importante:** Esta diferencia de selectores es intencional. El Deployment debe controlar únicamente Stable, pero el Service debe aceptar cualquier Pod de la aplicación que utilice `app=web`, incluida posteriormente la versión Canary.
  {: .lab-note .important .compact}

  ```bash
  cat > stable.yaml <<'EOF_STABLE'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: web-stable
    namespace: lab12
  spec:
    replicas: 4
    selector:
      matchLabels:
        app: web
        track: stable
    template:
      metadata:
        labels:
          app: web
          track: stable
      spec:
        containers:
          - name: nginx
            image: nginx:1.31.4-alpine3.24-slim
            imagePullPolicy: IfNotPresent
            command:
              - /bin/sh
              - -c
              - 'echo "VERSION STABLE" > /usr/share/nginx/html/index.html && exec nginx -g "daemon off;"'
            ports:
              - containerPort: 80
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: web
    namespace: lab12
  spec:
    selector:
      app: web
    ports:
      - port: 80
        targetPort: 80
  EOF_STABLE
  ```

  > **Salida esperada:** Se crea `stable.yaml` con un Deployment de cuatro réplicas y un Service cuyo selector es únicamente `app=web`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica `stable.yaml` para crear la versión Stable y el punto de acceso que conservará el mismo nombre durante todo el ejercicio.

  > **Nota:** Aunque el archivo contiene dos objetos Kubernetes, esta operación representa una sola acción declarativa: aplicar el estado definido en el manifiesto.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f stable.yaml
  ```

  > **Salida esperada:** Kubernetes crea `deployment.apps/web-stable` y `service/web`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que las cuatro réplicas Stable estén disponibles antes de introducir la versión Canary como segundo conjunto de backends.

  > **Importante:** Comenzar desde una versión Stable completamente disponible permite atribuir correctamente cualquier cambio posterior a la introducción de Canary.
  {: .lab-note .important .compact}

  ```bash
  kubectl rollout status deployment/web-stable -n lab12 --timeout=60s
  ```

  > **Salida esperada:** kubectl informa que `deployment "web-stable" successfully rolled out`.
  {: .lab-note .output .compact}

### Tarea 2.2. Introducir la primera réplica Canary

Crearás un Deployment independiente con una sola réplica Canary. Al compartir `app=web`, su Pod también será elegible para el Service, mientras que `track=canary` permitirá seguir administrándolo de forma separada.

- {% include step_label.html %} Crea `canary.yaml` con el Deployment `web-canary`, una réplica y contenido HTTP diferente para poder identificar cuándo una solicitud fue atendida por Canary.

  > **Nota:** El label `track=canary` separa este Deployment de Stable, pero `app=web` hace que su Pod también coincida con el selector del Service existente.
  {: .lab-note .info .compact}

  ```bash
  cat > canary.yaml <<'EOF_CANARY'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: web-canary
    namespace: lab12
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: web
        track: canary
    template:
      metadata:
        labels:
          app: web
          track: canary
      spec:
        containers:
          - name: nginx
            image: nginx:1.31.4-alpine3.24-slim
            imagePullPolicy: IfNotPresent
            command:
              - /bin/sh
              - -c
              - 'echo "VERSION CANARY" > /usr/share/nginx/html/index.html && exec nginx -g "daemon off;"'
            ports:
              - containerPort: 80
  EOF_CANARY
  ```

  > **Salida esperada:** Se crea `canary.yaml` con un Deployment de una réplica y labels `app=web,track=canary`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el manifiesto Canary para incorporar la nueva versión sin eliminar ni modificar el Deployment Stable.

  > **Importante:** Stable y Canary deben coexistir. La estrategia de esta práctica no sustituye inmediatamente la versión anterior, sino que añade un conjunto adicional de endpoints elegibles.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f canary.yaml
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/web-canary created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta varias solicitudes consecutivas desde el cliente y observa las respuestas para comprobar que el mismo Service puede alcanzar tanto Stable como Canary.

  > **Advertencia:** No esperes una proporción exacta de respuestas. Un Service estándar no implementa pesos porcentuales; con cuatro Pods Stable y uno Canary normalmente observarás Stable con mayor frecuencia, pero cada ejecución puede producir una distribución diferente.
  {: .lab-note .warning .compact}

  ```bash
  kubectl exec client -n lab12 -- sh -c 'for i in $(seq 1 20); do wget -qO- http://web; done'
  ```

  > **Salida esperada:** Entre las múltiples respuestas pueden aparecer `VERSION STABLE` y `VERSION CANARY`; Stable normalmente aparece con mayor frecuencia, sin que exista una garantía de porcentaje exacto.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 📈 Tarea 3. Reto: incrementar progresivamente Canary — 9 min

A partir de esta tarea comienza la parte no guiada. Deberás modificar la exposición relativa de Canary sin crear otro Service ni retirar Stable. Los comandos disponibles en los pasos son de observación y validación; las acciones de implementación quedan bajo tu responsabilidad.

### Tarea 3.1. Aumentar la capacidad Canary

Interpretarás un requerimiento de incremento progresivo, decidirás qué objeto debe modificarse y comprobarás posteriormente que Stable y Canary siguen disponibles detrás del mismo endpoint.

- {% include step_label.html %} Analiza el escenario y determina cómo aumentar la presencia de Canary entre los endpoints disponibles sin cambiar el Service ni reducir todavía Stable.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl --help`, `kubectl explain` y los manifiestos creados durante la sección guiada como referencia.
  {: .lab-note .important .compact}

  ```text
  Reto de incremento:

  Canary superó la validación inicial.

  Debes dejar el escenario con:
  - web-stable: 4 réplicas.
  - web-canary: 2 réplicas.
  - Ambos Deployments disponibles.
  - Un único Service llamado web.
  - El Service debe seguir seleccionando app=web.
  - No crees un segundo Service.
  - No elimines ningún Deployment.
  ```

  > **Salida esperada:** Identificas qué Deployment necesita cambiar de tamaño y qué recursos deben permanecer intactos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta el incremento solicitado y espera hasta considerar que las nuevas réplicas Canary están disponibles.

  > **Nota:** La estrategia de implementación forma parte del reto. El objetivo es modificar el estado deseado del controlador adecuado, no crear Pods Canary manualmente.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora el incremento Canary.

  No continúes hasta considerar satisfechos:
  - Stable = 4 réplicas;
  - Canary = 2 réplicas;
  - todos los Pods Ready;
  - Service web sin cambios de identidad.
  ```

  > **Salida esperada:** Canary dispone de dos réplicas y Stable conserva sus cuatro réplicas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida la cantidad de réplicas de ambos Deployments y corrige cualquier diferencia antes de analizar el tráfico.

  > **Advertencia:** La validación debe mostrar Deployments administrando sus propios Pods; no aceptes una solución basada en Pods creados manualmente.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get deployments -n lab12
  ```

  > **Salida esperada:** `web-stable` muestra `4/4` y `web-canary` muestra `2/2` réplicas disponibles.
  {: .lab-note .output .compact}

### Tarea 3.2. Observar la nueva exposición relativa

Comprobarás los Pods y endpoints elegibles, generarás una nueva muestra de solicitudes e interpretarás el resultado sin convertirlo en una garantía matemática de distribución.

- {% include step_label.html %} Lista los Pods de la aplicación mostrando sus labels para confirmar que existen cuatro endpoints potenciales Stable y dos Canary.

  > **Nota:** El label `track` permite contar cada grupo independientemente aunque el Service utilice únicamente `app=web` para seleccionar ambos.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab12 -l app=web --show-labels
  ```

  > **Salida esperada:** Se muestran seis Pods Ready: cuatro con `track=stable` y dos con `track=canary`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Genera una nueva muestra de solicitudes desde el cliente para observar si Canary aparece con mayor frecuencia relativa que cuando solo existía una réplica.

  > **Importante:** Interpreta esta prueba como una observación, no como una medición garantizada. El Service no ofrece pesos de tráfico configurables en este escenario.
  {: .lab-note .important .compact}

  ```bash
  kubectl exec client -n lab12 -- sh -c 'for i in $(seq 1 30); do wget -qO- http://web; done'
  ```

  > **Salida esperada:** Se observan respuestas de Stable y Canary. Canary puede aparecer con mayor frecuencia que en la primera prueba, pero no existe una proporción exacta garantizada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona los EndpointSlices asociados al Service para relacionar los Pods Ready con los backends de red que Kubernetes mantiene para `web`.

  > **Nota:** Los EndpointSlices permiten observar las direcciones que respaldan al Service. Su presencia ayuda a conectar conceptualmente los labels de los Pods con los destinos reales disponibles para el tráfico.
  {: .lab-note .info .compact}

  ```bash
  kubectl get endpointslices -n lab12 -l kubernetes.io/service-name=web
  ```

  > **Salida esperada:** Se muestra al menos un EndpointSlice asociado al Service `web` con endpoints correspondientes a los Pods seleccionados.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🚦 Tarea 4. Reto: promover Canary y recuperar Stable — 12 min

Resolverás dos decisiones operativas. Primero aumentarás la presencia de Canary hasta convertirla en la versión predominante sin retirar Stable; después responderás a un incidente reduciendo su exposición y recuperando Stable como grupo predominante, manteniendo siempre el mismo Service.

### Tarea 4.1. Promover Canary de forma relativa

Recibirás un escenario de promoción y deberás decidir cómo redistribuir las réplicas sin modificar el endpoint de los consumidores ni convertir la práctica en una sustitución blue/green.

- {% include step_label.html %} Analiza la solicitud de promoción y determina qué cambios de capacidad permiten que Canary tenga una presencia mayor que Stable entre los backends disponibles.

  > **Importante:** No se solicita eliminar Stable ni cambiar el selector del Service para apuntar exclusivamente a Canary. Ambas versiones deben seguir siendo elegibles simultáneamente.
  {: .lab-note .important .compact}

  ```text
  Promoción Canary:

  La nueva versión superó las pruebas.

  Estado requerido:
  - web-stable: 2 réplicas.
  - web-canary: 4 réplicas.
  - Todos los Pods Ready.
  - Service web sin recrearse.
  - Selector del Service: app=web.
  - Ambas versiones deben continuar desplegadas.
  ```

  > **Salida esperada:** Identificas que la promoción requiere ajustar la capacidad relativa de ambos Deployments conservando el Service compartido.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta la promoción y espera hasta que ambos Deployments alcancen el número de réplicas solicitado.

  > **Advertencia:** No elimines Stable para simular una promoción completa. Este ejercicio busca mantener coexistencia y modificar exposición relativa, que es la característica diferenciadora del escenario Canary.
  {: .lab-note .warning .compact}

  ```text
  Implementa ahora la promoción.

  Antes de continuar verifica por tu cuenta:
  - Stable = 2 réplicas;
  - Canary = 4 réplicas;
  - ambos Deployments disponibles;
  - Service web existente y sin nuevo nombre.
  ```

  > **Salida esperada:** Canary queda con cuatro réplicas y Stable con dos, manteniendo ambas versiones operativas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el estado de los Deployments después de la promoción antes de generar tráfico adicional.

  > **Nota:** Esta consulta confirma el estado deseado y disponible de cada controlador; si los valores no coinciden, corrige la implementación antes de continuar.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployment web-stable web-canary -n lab12
  ```

  > **Salida esperada:** `web-stable` muestra `2/2` y `web-canary` muestra `4/4` réplicas disponibles.
  {: .lab-note .output .compact}

### Tarea 4.2. Recuperar Stable ante un incidente Canary

Simularás la detección de un problema posterior a la promoción. Deberás disminuir Canary y recuperar Stable como versión predominante sin destruir la evidencia del incidente ni modificar el endpoint del consumidor.

- {% include step_label.html %} Genera una muestra de solicitudes después de la promoción para comprobar que ambas versiones continúan respondiendo y observar la nueva relación entre los grupos disponibles.

  > **Nota:** Con más réplicas Canary que Stable es razonable observar más respuestas Canary en una muestra amplia, pero el resultado sigue sin representar un porcentaje contractual.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec client -n lab12 -- sh -c 'for i in $(seq 1 30); do wget -qO- http://web; done'
  ```

  > **Salida esperada:** Aparecen respuestas `VERSION STABLE` y `VERSION CANARY`; Canary puede aparecer con mayor frecuencia debido a que dispone de más endpoints.
  {: .lab-note .output .compact}

- {% include step_label.html %} Analiza el incidente y recupera por tu cuenta una configuración donde Stable vuelva a ser predominante mientras Canary permanece desplegado para diagnóstico.

  > **Advertencia:** No elimines Canary y no cambies el selector del Service para excluirlo por completo. El objetivo es reducir su exposición conservando la versión problemática disponible para análisis.
  {: .lab-note .warning .compact}

  ```text
  Incidente Canary:

  Se detectó un problema funcional después de aumentar su exposición.

  Recupera el servicio dejando:
  - web-stable: 4 réplicas.
  - web-canary: 1 réplica.
  - Todos los Pods Ready.
  - Service web sin cambios de nombre.
  - Selector del Service: app=web.
  - Canary debe permanecer desplegado.
  ```

  > **Salida esperada:** Stable vuelve a disponer de cuatro réplicas y Canary queda reducido a una réplica sin ser eliminado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Realiza la validación final del reto comprobando simultáneamente la capacidad de ambos Deployments y el selector del Service antes de pasar a la limpieza.

  > **Importante:** No continúes a la siguiente tarea si alguno de los valores no coincide. La limpieza eliminará el escenario y ya no podrás revisar el resultado activo.
  {: .lab-note .important .compact}

  ```bash
  kubectl get deployment web-stable web-canary -n lab12
  kubectl get service web -n lab12 -o jsonpath='Selector={.spec.selector}{"\n"}'
  ```

  > **Salida esperada:** Stable muestra `4/4`, Canary `1/1` y el Service conserva un selector basado en `app=web`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar el entorno de la práctica — 4 min

Esta tarea no forma parte de la evaluación 50/50. Debes ejecutarla únicamente cuando hayas terminado todos los retos, comprobado los diferentes niveles de exposición de Stable y Canary, completado la promoción y realizado la recuperación ante el incidente.

### Tarea 5.1. Retirar los recursos del laboratorio

Eliminarás de forma controlada el namespace completo y comprobarás después que Kubernetes terminó la limpieza, conservando los manifiestos locales para revisión posterior.

- {% include step_label.html %} Cuando hayas terminado completamente los retos y confirmado todos sus criterios de éxito, elimina el namespace `lab12` para retirar Deployments, Service, EndpointSlices y Pods utilizados durante la práctica.

  > **Advertencia:** No ejecutes este paso mientras todavía estés resolviendo o revisando el reto. La eliminación del namespace destruye el escenario activo completo.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab12 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab12" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace `lab12` ya no existe para confirmar que el clúster quedó limpio antes de continuar con la siguiente práctica.

  > **Importante:** Conserva `workspace/lab12` y los manifiestos `stable.yaml` y `canary.yaml`; la limpieza debe afectar únicamente a los recursos activos de Kubernetes.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab12 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab12`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}