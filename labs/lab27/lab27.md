---
layout: lab
title: "Práctica 27: Restricción de tráfico con NetworkPolicy"
permalink: /lab27/lab27/
images_base: /labs/lab27/img
duration: "50 minutos"
objective:
  - Aplicar NetworkPolicy para aislar Pods y permitir únicamente flujos de red autorizados mediante podSelector, namespaceSelector y puertos, validando tráfico permitido y bloqueado dentro de una arquitectura segmentada.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 24 Exposición interna con Service ClusterIP.
  - Haber completado la Práctica 25 Exposición externa básica.
  - Disponer de kind, kubectl y Docker Desktop funcionando con contenedores Linux.
  - Disponer del clúster principal kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica utilizarás un clúster kind temporal denominado ckad-netpol con Calico como CNI para garantizar enforcement real de NetworkPolicy sin modificar el clúster principal del curso. Después de preparar la infraestructura resolverás retos de aislamiento ingress, selección de clientes mediante labels, autorización entre namespaces y restricción por puerto. El reto final consistirá en expresar y validar una matriz de comunicación entre frontend, backend y database utilizando únicamente las conexiones necesarias.
slug: lab27
lab_number: 27
final_result: >
  Al finalizar habrás creado y validado políticas de red Kubernetes que implementan default deny, permiten clientes seleccionados, autorizan tráfico desde namespaces concretos y restringen conexiones por puerto. También habrás construido una segmentación completa donde únicamente los flujos explícitamente requeridos permanecen permitidos y habrás eliminado el clúster temporal sin afectar el clúster principal ckad.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster temporal utiliza Kubernetes 1.36.1 y Calico 3.32.1, versión probada oficialmente con Kubernetes 1.34, 1.35 y 1.36.
  - kind incluye normalmente kindnetd como implementación de red básica. Para utilizar Calico como CNI, el clúster temporal se crea con disableDefaultCNI true.
  - Calico no se instala encima del CNI del clúster principal; por esta razón se utiliza ckad-netpol y se conserva intacto kind-ckad.
  - Todas las políticas de la práctica utilizan el recurso estándar networking.k8s.io/v1 NetworkPolicy y no recursos propietarios de Calico.
  - Las NetworkPolicies son aditivas. Un Pod queda aislado para una dirección cuando alguna política que lo selecciona incluye esa dirección en policyTypes.
  - Ingress representa tráfico que entra a los Pods seleccionados y Egress representa tráfico que sale de ellos.
  - Las pruebas bloqueadas pueden finalizar por timeout; esto constituye evidencia esperada cuando una política niega el flujo.
  - Los primeros 5 pasos son guiados y los siguientes 20 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 20/80.
references:
  - text: Kubernetes Network Policies
    url: https://kubernetes.io/docs/concepts/services-networking/network-policies/
  - text: Calico Installation on kind
    url: https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind
  - text: Calico System Requirements
    url: https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
  - text: Calico Kubernetes Default Deny
    url: https://docs.tigera.io/calico/latest/network-policy/get-started/kubernetes-default-deny
  - text: kind Configuration
    url: https://kind.sigs.k8s.io/docs/user/configuration/
prev: /lab26/lab26/
next: /lab28/lab28/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar un clúster con soporte real de NetworkPolicy — 10 min

Crearás un clúster temporal separado del entorno principal para utilizar Calico como CNI y garantizar que las NetworkPolicies sean aplicadas realmente.

### Tarea 1.1. Preparar el entorno

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea `workspace/lab27` y accede al directorio donde conservarás la configuración del clúster y las políticas.

  > **Nota:** El workspace permanece en el repositorio local aunque el clúster temporal se elimine al terminar.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab27 && cd workspace/lab27
  ```

  > **Salida esperada:** La terminal queda ubicada dentro de `ckad-labs/workspace/lab27`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que el contexto inicial corresponde al clúster principal `ckad` antes de crear un entorno independiente para NetworkPolicy.

  > **Importante:** Esta comprobación permite demostrar al final que la práctica no modificó ni eliminó el clúster principal.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea la configuración de `ckad-netpol` deshabilitando el CNI predeterminado de kind y utilizando un Pod CIDR compatible con la instalación recomendada de Calico.

  > **Importante:** Calico debe actuar como CNI del clúster desde su creación; no se instalará sobre kindnetd.
  {: .lab-note .important .compact}

  ```bash
  cat > kind-netpol.yaml <<'EOF'
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  networking:
    disableDefaultCNI: true
    podSubnet: 192.168.0.0/16
  nodes:
    - role: control-plane
    - role: worker
    - role: worker
  EOF
  ```
  ```bash
  kind create cluster --name ckad-netpol --image kindest/node:v1.36.1 --config kind-netpol.yaml
  ```

  > **Salida esperada:** kind crea `ckad-netpol` con un control plane y dos workers y cambia el contexto activo a `kind-ckad-netpol`; los nodos pueden permanecer temporalmente `NotReady` hasta instalar el CNI.
  {: .lab-note .output .compact}

### Tarea 1.2. Instalar y validar Calico

- {% include step_label.html %} Instala Calico 3.32.1 mediante el operador y los recursos recomendados para kind.

  > **Advertencia:** No ejecutes estos manifiestos contra `kind-ckad`; el contexto debe ser `kind-ckad-netpol`.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/v1_crd_projectcalico_org.yaml
  ```
  ```bash
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml
  ```
  ```bash
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/custom-resources.yaml
  ```

  > **Salida esperada:** Se crean las CRDs, el operador de Tigera y la instalación de Calico para el clúster temporal.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que los nodos estén Ready y verifica que los componentes de Calico se encuentren ejecutándose antes de comenzar las políticas.

  > **Importante:** No continúes si los nodos permanecen NotReady; una NetworkPolicy no puede validarse correctamente sin networking operativo.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait --for=condition=Ready nodes --all --timeout=180s
  ```
  ```bash
  kubectl get nodes
  ```
  ```bash
  kubectl get pods -n calico-system
  ```

  > **Salida esperada:** Los tres nodos muestran `Ready` y los componentes principales de Calico aparecen Running en `calico-system`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: aplicar default deny y acceso selectivo — 7 min

Crearás una aplicación inicialmente accesible y después aislarás sus Pods para permitir solamente clientes explícitamente autorizados.

### Tarea 2.1. Construir el escenario base

- {% include step_label.html %} Crea por tu cuenta el namespace `lab27-app`, un Deployment `web` de dos réplicas, su Service ClusterIP y dos clientes persistentes.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Valida primero que exista conectividad antes de aplicar políticas.
  {: .lab-note .important .compact}

  ```text
  Namespace:
  - lab27-app

  Deployment web:
  - replicas: 2
  - imagen: nginx:1.31.4-alpine3.24-slim
  - label de Pods: app=web

  Service web:
  - port: 80
  - targetPort: 80

  Clientes:
  - allowed-client con access=allowed
  - blocked-client con access=blocked
  - imagen: busybox:1.38.0-musl
  - ambos persistentes
  ```

  > **Salida esperada:** Los dos clientes y las dos réplicas de `web` están Running y el Service dispone de endpoints.
  {: .lab-note .output .compact}

- {% include step_label.html %} Demuestra que ambos clientes pueden alcanzar `web:80` antes de crear cualquier NetworkPolicy.

  > **Nota:** Esta línea base es imprescindible: si la comunicación ya falla sin políticas, no podrás atribuir el bloqueo a NetworkPolicy.
  {: .lab-note .info .compact}

  ```text
  Línea base requerida:

  allowed-client -> web:80  PERMITIDO
  blocked-client -> web:80  PERMITIDO
  ```

  > **Salida esperada:** Ambos clientes obtienen una respuesta HTTP de `web`.
  {: .lab-note .output .compact}

### Tarea 2.2. Aislar y autorizar

- {% include step_label.html %} Implementa una política de default deny de ingreso para los Pods de `lab27-app` y demuestra que ambos clientes dejan de alcanzar `web`.

  > **Importante:** Utiliza `networking.k8s.io/v1` y expresa explícitamente aislamiento Ingress; no elimines el Service para provocar el fallo.
  {: .lab-note .important .compact}

  ```text
  Después de default deny:

  allowed-client -> web:80  BLOQUEADO
  blocked-client -> web:80  BLOQUEADO
  ```

  > **Salida esperada:** Ambas conexiones dejan de obtener respuesta mientras los Pods continúan Running.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea una segunda NetworkPolicy que permita ingreso hacia `app=web` únicamente desde Pods con `access=allowed`.

  > **Nota:** Las políticas son aditivas: la nueva regla debe agregar el flujo autorizado sin eliminar el aislamiento general.
  {: .lab-note .info .compact}

  ```text
  Estado requerido:

  allowed-client -> web:80  PERMITIDO
  blocked-client -> web:80  BLOQUEADO
  ```

  > **Salida esperada:** Solo `allowed-client` recupera acceso HTTP hacia `web`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🏷️ Tarea 3. Reto: controlar tráfico entre namespaces — 9 min

Extenderás el aislamiento para autorizar clientes según el namespace del que proceden y no únicamente por labels de Pod.

### Tarea 3.1. Crear clientes en namespaces diferentes

- {% include step_label.html %} Crea dos namespaces adicionales, etiquétalos como confiable y no confiable y despliega un cliente persistente en cada uno.

  > **Importante:** `namespaceSelector` evalúa labels del namespace. Los nombres de namespace por sí solos no sustituyen una selección por labels cuando el requisito está expresado de esa forma.
  {: .lab-note .important .compact}

  ```text
  lab27-client:
  - label team=trusted
  - Pod trusted-client

  lab27-untrusted:
  - label team=untrusted
  - Pod untrusted-client

  Imagen de clientes:
  - busybox:1.38.0-musl
  ```

  > **Salida esperada:** Ambos namespaces existen con sus labels y cada cliente permanece Running.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba la conectividad de ambos clientes hacia `web` y utiliza el resultado para determinar cómo influyen las políticas ya existentes.

  > **Nota:** Una política con `podSelector` en `from` selecciona Pods del mismo namespace que la política, salvo que se combine con un `namespaceSelector`.
  {: .lab-note .info .compact}

  ```text
  Registra el resultado de:

  trusted-client -> web:80
  untrusted-client -> web:80
  ```

  > **Salida esperada:** Los clientes externos a `lab27-app` no quedan autorizados por la regla basada únicamente en `access=allowed`.
  {: .lab-note .output .compact}

### Tarea 3.2. Autorizar por namespaceSelector

- {% include step_label.html %} Diseña una política que permita tráfico hacia `app=web` desde cualquier Pod perteneciente a namespaces con `team=trusted`.

  > **Importante:** El requisito selecciona el namespace de origen; no agregues el label `team=trusted` directamente al Pod para evitar resolver un problema diferente.
  {: .lab-note .important .compact}

  ```text
  Requisito:

  namespace team=trusted
       ↓
      web:80
       ✓

  namespace team=untrusted
       ↓
      web:80
       ✗
  ```

  > **Salida esperada:** Defines una regla `from` basada en `namespaceSelector`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica por tu cuenta la política y valida que `trusted-client` obtenga acceso mientras `untrusted-client` permanece bloqueado.

  > **Nota:** Conserva las políticas anteriores; la nueva autorización debe sumarse a ellas.
  {: .lab-note .info .compact}

  ```text
  Resultado requerido:

  trusted-client   -> web:80  PERMITIDO
  untrusted-client -> web:80  BLOQUEADO
  ```

  > **Salida esperada:** Solo el cliente del namespace etiquetado `team=trusted` recibe respuesta.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona las NetworkPolicies activas y explica qué selector controla los Pods protegidos y qué selector controla el origen autorizado.

  > **Importante:** `spec.podSelector` selecciona los Pods a los que se aplica la política; los selectors dentro de `from` describen posibles orígenes.
  {: .lab-note .important .compact}

  ```bash
  kubectl get networkpolicies -n lab27-app
  ```

  > **Salida esperada:** Se muestran varias políticas coexistiendo de forma aditiva en `lab27-app`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🔐 Tarea 4. Reto: restringir por Pod selector y puerto — 9 min

Crearás un nuevo backend y limitarás el acceso tanto por identidad del cliente como por puerto de destino.

### Tarea 4.1. Preparar clientes y backend

- {% include step_label.html %} Crea un Deployment `backend` y dos clientes con roles distintos dentro de `lab27-app`.

  > **Nota:** Mantén este escenario independiente de `web` utilizando labels específicas para el nuevo backend.
  {: .lab-note .info .compact}

  ```text
  backend:
  - replicas: 2
  - imagen: nginx:1.31.4-alpine3.24-slim
  - label app=backend
  - Service backend port 80

  Clientes:
  - frontend-client label role=frontend
  - monitor-client label role=monitor
  - busybox:1.38.0-musl
  ```

  > **Salida esperada:** Backend y clientes permanecen Running y el Service dispone de endpoints.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida que ambos roles pueden llegar inicialmente a `backend:80` antes de aplicar aislamiento sobre el nuevo backend.

  > **Importante:** No reutilices como evidencia las pruebas realizadas contra `web`; cada Pod queda aislado según las políticas que lo seleccionan.
  {: .lab-note .important .compact}

  ```text
  Línea base:

  frontend-client -> backend:80  PERMITIDO
  monitor-client  -> backend:80  PERMITIDO
  ```

  > **Salida esperada:** Ambos clientes pueden alcanzar el Service `backend`.
  {: .lab-note .output .compact}

### Tarea 4.2. Permitir identidad y puerto específicos

- {% include step_label.html %} Diseña una NetworkPolicy que seleccione únicamente `app=backend` y permita TCP/80 exclusivamente desde Pods con `role=frontend`.

  > **Importante:** La regla debe combinar selección de origen y puerto; no cambies labels del Service ni elimines al cliente monitor.
  {: .lab-note .important .compact}

  ```text
  Política requerida:

  role=frontend -> backend TCP/80  PERMITIDO
  role=monitor  -> backend TCP/80  BLOQUEADO
  ```

  > **Salida esperada:** Defines una política que aísla `backend` y expresa una única autorización de ingreso.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica la política y comprueba que el resultado coincide con la matriz requerida.

  > **Nota:** Un timeout desde `monitor-client` es un resultado válido para demostrar enforcement de la política.
  {: .lab-note .info .compact}

  ```text
  Resultado esperado:

  frontend-client -> backend:80  ✓
  monitor-client  -> backend:80  ✗
  ```

  > **Salida esperada:** El frontend obtiene respuesta HTTP y el monitor no logra establecer la conexión.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona la política activa y explica por qué no afecta a los Pods `web` aunque se encuentre en el mismo namespace.

  > **Importante:** NetworkPolicy solo aísla los Pods seleccionados por `spec.podSelector`; el alcance del namespace no implica que todos sus Pods queden automáticamente seleccionados.
  {: .lab-note .important .compact}

  ```bash
  kubectl describe networkpolicy -n lab27-app
  ```

  > **Salida esperada:** Puedes identificar la política que selecciona `app=backend`, su origen `role=frontend` y el puerto TCP permitido.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧭 Tarea 5. Reto: construir una segmentación completa — 13 min

Diseñarás una arquitectura nueva donde solo los flujos mínimos requeridos entre frontend, backend y database permanezcan permitidos.

### Tarea 5.1. Diseñar e implementar la arquitectura

- {% include step_label.html %} Crea el namespace `lab27-prod` y diseña labels inequívocas para las tres capas antes de implementar cualquier política.

  > **Importante:** La matriz de comunicación debe poder expresarse mediante selectors claros; evita labels ambiguas compartidas accidentalmente entre capas.
  {: .lab-note .important .compact}

  ```text
  Namespace:
  - lab27-prod

  Capas:
  - frontend
  - backend
  - database

  Flujo requerido:
  frontend -> backend
  backend  -> database
  ```

  > **Salida esperada:** Defines una estrategia de labels que distingue las tres capas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta las tres capas y sus Services utilizando puertos distintos para hacer explícita la segmentación.

  > **Nota:** Los procesos pueden ser servidores HTTP simples; el objetivo evaluado es conectividad, no semántica de la aplicación.
  {: .lab-note .info .compact}

  ```text
  frontend:
  - cliente o proceso persistente

  backend:
  - Service backend
  - puerto 8080

  database:
  - Service database
  - puerto 5432

  Recomendación:
  - utilizar python:3.13-alpine3.24 para servidores HTTP
    escuchando en los puertos requeridos
  ```

  > **Salida esperada:** Las tres capas están Running y los Services `backend` y `database` disponen de endpoints.
  {: .lab-note .output .compact}

- {% include step_label.html %} Demuestra antes de aplicar políticas que los flujos requeridos y al menos un flujo que después será prohibido funcionan inicialmente.

  > **Importante:** Necesitas una línea base para diferenciar restricciones de NetworkPolicy de errores de aplicación o Service.
  {: .lab-note .important .compact}

  ```text
  Antes de políticas:

  frontend -> backend:8080   PERMITIDO
  backend  -> database:5432  PERMITIDO
  frontend -> database:5432  PERMITIDO
  ```

  > **Salida esperada:** Los tres flujos de línea base pueden establecer conexión.
  {: .lab-note .output .compact}

### Tarea 5.2. Aplicar y validar la matriz de seguridad

- {% include step_label.html %} Diseña e implementa las políticas necesarias para permitir únicamente la matriz de comunicación requerida.

  > **Importante:** Aplica aislamiento sobre los destinos y luego agrega únicamente los orígenes y puertos necesarios. No resuelvas el reto eliminando Services o Pods.
  {: .lab-note .important .compact}

  ```text
  Matriz final:

  frontend -> backend:8080   PERMITIDO
  backend  -> database:5432  PERMITIDO
  frontend -> database:5432  BLOQUEADO
  otro Pod -> backend:8080   BLOQUEADO
  ```

  > **Salida esperada:** Existen NetworkPolicies que expresan las autorizaciones mínimas de ingreso para backend y database.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta pruebas positivas y negativas y demuestra que los cuatro resultados coinciden con la matriz requerida.

  > **Advertencia:** No consideres una política correcta únicamente porque bloquea tráfico; también debes demostrar que los flujos legítimos siguen funcionando.
  {: .lab-note .warning .compact}

  ```text
  Evidencia requerida:

  ✓ frontend -> backend:8080
  ✓ backend  -> database:5432
  ✗ frontend -> database:5432
  ✗ cliente no autorizado -> backend:8080
  ```

  > **Salida esperada:** Los dos flujos autorizados funcionan y los dos flujos no autorizados son bloqueados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Emite una conclusión final explicando qué Pods quedan aislados, qué selectors conceden acceso y por qué NetworkPolicy implementa una lista de flujos permitidos en lugar de una ruta de red.

  > **Nota:** Relaciona cada decisión con la pregunta: quién puede hablar con quién, en qué dirección y mediante qué puerto.
  {: .lab-note .info .compact}

  ```text
  Explica:

  1. qué Pods protege cada política;
  2. qué origen autoriza cada regla;
  3. qué puerto permanece permitido;
  4. qué flujos quedan bloqueados por ausencia de una regla allow.
  ```

  > **Salida esperada:** Describes correctamente la segmentación resultante y el comportamiento aditivo de las políticas.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🧹 Tarea 6. Limpiar el entorno de la práctica — 2 min

La limpieza no forma parte de la proporción 20/80. Debido a que Calico fue instalado exclusivamente en `ckad-netpol`, eliminarás el clúster temporal completo y regresarás al clúster principal `ckad`.

### Tarea 6.1. Retirar el clúster temporal

- {% include step_label.html %} Revisa una última vez los namespaces y NetworkPolicies antes de destruir el entorno de pruebas.

  > **Nota:** Confirma que terminaste las pruebas positivas y negativas porque toda la evidencia del clúster temporal desaparecerá.
  {: .lab-note .info .compact}

  ```bash
  kubectl get networkpolicies -A
  ```

  > **Salida esperada:** Se muestran las NetworkPolicies creadas en `lab27-app` y `lab27-prod`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el clúster `ckad-netpol` para retirar Calico y todos los recursos creados durante esta práctica sin tocar el clúster principal.

  > **Advertencia:** Asegúrate de escribir `ckad-netpol`; eliminar `ckad` destruiría el entorno principal del curso.
  {: .lab-note .warning .compact}

  ```bash
  kind delete cluster --name ckad-netpol
  ```

  > **Salida esperada:** kind confirma la eliminación del clúster `ckad-netpol`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Regresa explícitamente al contexto `kind-ckad` y confirma que el clúster principal continúa operativo.

  > **Importante:** Esta validación demuestra que Metrics Server, Traefik y los demás componentes compartidos del curso permanecen intactos.
  {: .lab-note .important .compact}

  ```bash
  kubectl config use-context kind-ckad
  ```
  ```bash
  kubectl get nodes
  ```

  > **Salida esperada:** El contexto cambia a `kind-ckad` y los nodos `ckad-control-plane`, `ckad-worker` y `ckad-worker2` continúan Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que los archivos locales de la práctica permanecen disponibles para repasar la configuración y las políticas diseñadas.

  > **Nota:** La eliminación del clúster no afecta `workspace/lab27`.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio conserva `kind-netpol.yaml` y los manifiestos creados durante los retos.
  {: .lab-note .output .compact}

{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

{% include support-prompt.html task="tarea6" %}