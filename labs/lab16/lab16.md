---
layout: lab
title: "Práctica 16: ServiceAccount y permisos mínimos"
permalink: /lab16/lab16/
images_base: /labs/lab16/img
duration: "50 minutos"
objective:
  - Crear identidades de aplicación mediante ServiceAccounts, conceder permisos namespaced con Role y RoleBinding, asociar identidades a Pods y aplicar el principio de mínimo privilegio validando explícitamente tanto operaciones permitidas como denegadas.
prerequisites:
  - Haber completado la Práctica 15 Manejo de información sensible con Secrets.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica trabajarás con identidad y autorización para cargas de trabajo Kubernetes. La primera sección será guiada y te permitirá reconocer cómo se relacionan ServiceAccount, Role y RoleBinding y cómo kubectl auth can-i permite consultar permisos efectivos. Después resolverás escenarios de mínimo privilegio donde deberás crear una identidad, conceder únicamente las operaciones necesarias, asociarla a un Pod y corregir un exceso de permisos sin recibir los comandos de implementación. La práctica finaliza validando también acciones que deben permanecer denegadas y comprobando que los permisos no se extienden fuera del namespace solicitado.
slug: lab16
lab_number: 16
final_result: >
  Al finalizar habrás creado una identidad mediante ServiceAccount, definido permisos namespaced con Role, enlazado la identidad mediante RoleBinding y utilizado el ServiceAccount desde un Pod. También habrás demostrado el principio de mínimo privilegio verificando operaciones permitidas y prohibidas, corregido una configuración RBAC excesiva y comprobado que los permisos no se extienden a otros namespaces. Los retos representan el 70 por ciento del contenido evaluable y requieren decidir por tu cuenta qué recursos y cambios son necesarios.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Cada namespace contiene un ServiceAccount denominado default; si un Pod no especifica serviceAccountName, Kubernetes utiliza ese ServiceAccount.
  - ServiceAccount proporciona identidad. Role define permisos namespaced y RoleBinding conecta una identidad con esos permisos.
  - kubectl auth can-i se utiliza para validar tanto acciones permitidas como acciones que deben permanecer denegadas.
  - La práctica utiliza impersonación con --as para comprobar permisos del ServiceAccount desde la cuenta administrativa del laboratorio.
  - Los primeros 6 pasos son guiados y los siguientes 14 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 30/70.
references:
  - text: Service Accounts en Kubernetes
    url: https://kubernetes.io/docs/concepts/security/service-accounts/
  - text: Configurar Service Accounts para Pods
    url: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
  - text: Autorización RBAC en Kubernetes
    url: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
  - text: Referencia oficial de kubectl auth can-i
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/
prev: /lab15/lab15/
next: /lab17/lab17/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y comprender ServiceAccount y RBAC — 10 min

Prepararás el workspace y el namespace de la práctica y revisarás cómo Kubernetes separa identidad de autorización. El objetivo es reconocer la relación entre ServiceAccount, Role y RoleBinding antes de comenzar los retos de mínimo privilegio.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, confirmarás el contexto activo y prepararás un namespace aislado donde se construirán todas las identidades y reglas RBAC de la práctica.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab16` y accede a él para almacenar los manifiestos y evidencias generadas durante esta práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab16`; los archivos locales se conservarán al finalizar como material de revisión.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab16 && cd workspace/lab16
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab16`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo para confirmar que kubectl continúa conectado al clúster local utilizado por el curso.

  > **Importante:** El valor esperado es `kind-ckad`. No continúes si kubectl apunta a un contexto diferente.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab16` para aislar ServiceAccounts, Roles, RoleBindings y Pods utilizados en los escenarios de autorización.

  > **Advertencia:** Si `lab16` ya existe por una ejecución anterior, revisa primero sus recursos RBAC para evitar que permisos antiguos alteren las validaciones de esta práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab16
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab16 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Reconocer identidad y autorización

Explorarás los recursos que intervienen en RBAC y comprobarás cómo kubectl permite evaluar los permisos de una identidad antes de crear una política propia.

- {% include step_label.html %} Consulta los ServiceAccounts existentes en `lab16` para comprobar que Kubernetes crea automáticamente una identidad `default` dentro de cada namespace.

  > **Nota:** Si un Pod no especifica `serviceAccountName`, Kubernetes le asigna el ServiceAccount `default` de su namespace.
  {: .lab-note .info .compact}

  ```bash
  kubectl get serviceaccounts -n lab16
  ```

  > **Salida esperada:** Se muestra al menos el ServiceAccount denominado `default`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la estructura de Role para identificar los campos que describen grupos de API, recursos y operaciones permitidas.

  > **Importante:** En una regla RBAC, `resources` indica sobre qué objetos puede actuar la identidad y `verbs` define operaciones como get, list, create, update o delete.
  {: .lab-note .important .compact}

  ```bash
  kubectl explain role.rules --recursive
  ```

  > **Salida esperada:** La salida incluye campos como `apiGroups`, `resources`, `resourceNames` y `verbs`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta si el ServiceAccount `default` puede listar Pods en `lab16` para observar cómo `kubectl auth can-i` evalúa permisos efectivos mediante impersonación.

  > **Nota:** La identidad de un ServiceAccount sigue el formato `system:serviceaccount:NAMESPACE:NOMBRE`; este patrón se reutilizará durante los retos.
  {: .lab-note .info .compact}

  ```bash
  kubectl auth can-i list pods --as=system:serviceaccount:lab16:default -n lab16
  ```

  > **Salida esperada:** En un namespace sin permisos adicionales, la respuesta esperada es `no`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: crear una identidad con permisos mínimos — 11 min

A partir de esta tarea comienza la parte no guiada. Deberás construir una identidad de aplicación y conceder únicamente las operaciones requeridas, demostrando que las acciones no solicitadas permanecen denegadas.

### Tarea 2.1. Crear la identidad y su autorización

Analizarás un requerimiento de lectura de Pods y decidirás qué recursos RBAC son necesarios para proporcionar exactamente los privilegios solicitados dentro de `lab16`.

- {% include step_label.html %} Analiza el escenario y determina qué objetos Kubernetes necesitas para crear la identidad `inventory-sa` y concederle únicamente lectura de Pods dentro de `lab16`.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl --help`, `kubectl explain` y generación mediante `--dry-run=client` cuando esté disponible.
  {: .lab-note .important .compact}

  ```text
  Reto de identidad:

  ServiceAccount:
  - Nombre: inventory-sa
  - Namespace: lab16

  Permisos requeridos sobre Pods:
  - get
  - list

  Permisos que NO debe tener:
  - create
  - update
  - patch
  - delete

  Alcance:
  - Únicamente namespace lab16.
  ```

  > **Salida esperada:** Identificas los recursos de identidad y autorización necesarios para conceder exactamente get y list sobre Pods dentro de un único namespace.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta la identidad y las reglas RBAC necesarias, conservando los manifiestos dentro de `workspace/lab16`.

  > **Advertencia:** Evita utilizar ClusterRoleBinding o privilegios amplios para resolver un requerimiento limitado a un solo namespace.
  {: .lab-note .warning .compact}

  ```text
  Implementa ahora la solución.

  No continúes hasta considerar que:
  - inventory-sa existe;
  - puede consultar Pods;
  - no puede modificarlos;
  - los permisos están limitados a lab16.
  ```

  > **Salida esperada:** Existen los objetos necesarios para representar la identidad, sus permisos namespaced y la relación entre ambos.
  {: .lab-note .output .compact}

### Tarea 2.2. Validar mínimo privilegio

Comprobarás de forma explícita tanto los permisos requeridos como aquellos que deben permanecer denegados.

- {% include step_label.html %} Valida las operaciones de lectura requeridas para confirmar que `inventory-sa` puede consultar Pods dentro de `lab16`.

  > **Nota:** Una política de mínimo privilegio debe comprobar primero que la aplicación sí puede realizar las operaciones necesarias para funcionar.
  {: .lab-note .info .compact}

  ```bash
  kubectl auth can-i get pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```
  ```bash
  kubectl auth can-i list pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```

  > **Salida esperada:** Ambos comandos responden `yes`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba operaciones no autorizadas para demostrar que la política no concede capacidades de modificación sobre Pods.

  > **Importante:** Verificar acciones denegadas es tan importante como comprobar las permitidas; una respuesta `yes` indicaría privilegios superiores a los solicitados.
  {: .lab-note .important .compact}

  ```bash
  kubectl auth can-i create pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```
  ```bash
  kubectl auth can-i delete pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```

  > **Salida esperada:** Ambos comandos responden `no`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🚀 Tarea 3. Reto: utilizar el ServiceAccount desde un Pod — 12 min

Asociarás la identidad creada a un workload y comprobarás que Kubernetes registra explícitamente el ServiceAccount solicitado en la especificación del Pod.

### Tarea 3.1. Asociar la identidad al workload

Crearás un Pod persistente que utilice `inventory-sa` en lugar de la identidad `default`, sin recibir el manifiesto de solución.

- {% include step_label.html %} Analiza los requisitos del Pod `inventory-client` y determina qué campo de la especificación debe vincularlo con la identidad creada anteriormente.

  > **Importante:** El Pod no debe utilizar el ServiceAccount `default`; la identidad efectiva debe quedar declarada explícitamente en la especificación.
  {: .lab-note .important .compact}

  ```text
  Reto de workload:

  Pod:
  - Nombre: inventory-client
  - Namespace: lab16
  - Imagen: busybox:1.38.0-musl
  - Debe permanecer Running.
  - Debe utilizar inventory-sa.
  - No debe utilizar el ServiceAccount default.
  ```

  > **Salida esperada:** Identificas cómo asociar `inventory-sa` al Pod desde su especificación.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `inventory-client` y espera hasta que el Pod se encuentre disponible para las validaciones.

  > **Nota:** Conserva el manifiesto local para poder revisar posteriormente cómo quedó declarada la identidad del workload.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora inventory-client.

  No continúes hasta que:
  - el Pod exista;
  - se encuentre Running;
  - utilice inventory-sa.
  ```

  > **Salida esperada:** `pod/inventory-client` existe en `lab16` y permanece en estado `Running`.
  {: .lab-note .output .compact}

### Tarea 3.2. Validar identidad y permisos efectivos

Comprobarás la identidad registrada en el Pod y volverás a evaluar permisos positivos y negativos desde el punto de vista del ServiceAccount utilizado.

- {% include step_label.html %} Consulta el campo `serviceAccountName` del Pod para comprobar que Kubernetes registró la identidad solicitada.

  > **Nota:** Esta comprobación confirma la asociación declarativa entre el workload y el ServiceAccount, independientemente de los permisos concedidos posteriormente mediante RBAC.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod inventory-client -n lab16 -o jsonpath='{.spec.serviceAccountName}{"\n"}'
  ```

  > **Salida esperada:** El comando devuelve `inventory-sa`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba nuevamente que la identidad asociada al Pod conserva capacidad de lectura sobre Pods.

  > **Importante:** Asociar un ServiceAccount a un Pod no crea permisos nuevos; el acceso continúa dependiendo de las reglas RBAC vinculadas a esa identidad.
  {: .lab-note .important .compact}

  ```bash
  kubectl auth can-i list pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```

  > **Salida esperada:** La respuesta es `yes`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Verifica que la misma identidad continúa sin permiso para eliminar Pods después de asociarla al workload.

  > **Advertencia:** La creación del Pod no debe modificar las reglas RBAC. Si aparece `yes`, revisa la política antes de continuar.
  {: .lab-note .warning .compact}

  ```bash
  kubectl auth can-i delete pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```

  > **Salida esperada:** La respuesta es `no`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🛡️ Tarea 4. Reto: corregir y demostrar mínimo privilegio — 11 min

Resolverás un escenario de auditoría donde la identidad debe dejar de consultar Pods y quedar limitada únicamente a operaciones de lectura sobre ConfigMaps. Después demostrarás que no puede acceder a Secrets ni actuar fuera de `lab16`.

### Tarea 4.1. Corregir un exceso de permisos

Modificarás la autorización existente para sustituir los permisos anteriores por el conjunto exacto requerido después de una revisión de seguridad.

- {% include step_label.html %} Analiza el nuevo requerimiento de auditoría y determina qué objeto RBAC debe modificarse para cambiar los permisos efectivos de `inventory-sa` sin sustituir la identidad.

  > **Importante:** El ServiceAccount debe conservarse. La corrección debe realizarse sobre la autorización que define qué recursos y verbos puede utilizar.
  {: .lab-note .important .compact}

  ```text
  Auditoría de seguridad:

  inventory-sa ya no necesita consultar Pods.

  Nuevos permisos requeridos:
  - get configmaps
  - list configmaps

  Debe quedar prohibido:
  - create configmaps
  - update configmaps
  - patch configmaps
  - delete configmaps
  - get secrets
  - list secrets
  - get pods
  - list pods

  Alcance:
  - Únicamente lab16.
  ```

  > **Salida esperada:** Identificas qué regla RBAC debe corregirse para sustituir los permisos anteriores por lectura mínima de ConfigMaps.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta la corrección y conserva `inventory-sa` como la misma identidad utilizada por `inventory-client`.

  > **Advertencia:** No agregues una segunda RoleBinding que deje activos los permisos anteriores. El estado final debe representar únicamente los privilegios solicitados por la auditoría.
  {: .lab-note .warning .compact}

  ```text
  Corrige ahora la autorización.

  No continúes hasta considerar que inventory-sa:
  - solo puede get/list ConfigMaps;
  - ya no puede leer Pods;
  - no puede leer Secrets.
  ```

  > **Salida esperada:** La identidad permanece asociada al workload, pero sus permisos efectivos reflejan el nuevo conjunto mínimo.
  {: .lab-note .output .compact}

### Tarea 4.2. Demostrar el alcance mínimo

Ejecutarás pruebas positivas, negativas y de alcance para demostrar que la política cumple exactamente con el requerimiento.

- {% include step_label.html %} Comprueba que las dos operaciones autorizadas sobre ConfigMaps funcionan correctamente.

  > **Nota:** Estas verificaciones representan la capacidad mínima que la aplicación necesita conservar después de la auditoría.
  {: .lab-note .info .compact}

  ```bash
  kubectl auth can-i get configmaps --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```
  ```bash
  kubectl auth can-i list configmaps --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```

  > **Salida esperada:** Ambos comandos responden `yes`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que operaciones sensibles o de modificación permanecen explícitamente denegadas.

  > **Importante:** El ServiceAccount no debe obtener acceso a Secrets ni capacidad para eliminar ConfigMaps.
  {: .lab-note .important .compact}

  ```bash
  kubectl auth can-i delete configmaps --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```
  ```bash
  kubectl auth can-i get secrets --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```
  ```bash
  kubectl auth can-i list pods --as=system:serviceaccount:lab16:inventory-sa -n lab16
  ```

  > **Salida esperada:** Los tres comandos responden `no`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida que los permisos de `inventory-sa` no se extienden al namespace `default`, demostrando que la autorización permanece limitada a `lab16`.

  > **Advertencia:** Una respuesta `yes` fuera de `lab16` indicaría que utilizaste una vinculación con alcance mayor al solicitado, como un ClusterRoleBinding inapropiado.
  {: .lab-note .warning .compact}

  ```bash
  kubectl auth can-i get configmaps --as=system:serviceaccount:lab16:inventory-sa -n default
  ```

  > **Salida esperada:** La respuesta es `no`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar el entorno de la práctica — 6 min

Esta tarea no forma parte de la evaluación 30/70. Debes ejecutarla únicamente después de terminar todos los retos, comprobar operaciones permitidas y denegadas y confirmar que `inventory-sa` posee únicamente los privilegios solicitados.

### Tarea 5.1. Revisar y retirar los recursos del laboratorio

Realizarás una última inspección de identidad, RBAC y workload, eliminarás el namespace y confirmarás que el clúster quedó limpio mientras los manifiestos locales permanecen disponibles.

- {% include step_label.html %} Revisa una última vez los ServiceAccounts, Roles, RoleBindings y Pods de `lab16` antes de eliminar el escenario.

  > **Nota:** Esta inspección final permite identificar la relación completa entre identidad, autorización y workload antes de destruir los recursos.
  {: .lab-note .info .compact}

  ```bash
  kubectl get serviceaccount,role,rolebinding,pods -n lab16
  ```

  > **Salida esperada:** Se muestran `inventory-sa`, los recursos RBAC creados durante el reto y `inventory-client`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Cuando hayas terminado completamente todas las validaciones, elimina el namespace `lab16` para retirar las identidades, reglas RBAC y Pods creados durante la práctica.

  > **Advertencia:** No ejecutes este paso mientras todavía necesites revisar permisos con `kubectl auth can-i`. La eliminación del namespace destruye todo el escenario RBAC namespaced.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab16 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab16" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace `lab16` ya no existe para confirmar que la limpieza del entorno Kubernetes terminó correctamente.

  > **Importante:** La ausencia de salida es el resultado esperado porque `--ignore-not-found` evita mostrar un error cuando el namespace ya fue eliminado.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab16 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab16`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los manifiestos y archivos locales permanecen dentro del workspace para revisar posteriormente cómo implementaste la solución RBAC.

  > **Nota:** La limpieza debe afectar únicamente a los recursos activos del clúster; conserva `workspace/lab16` como evidencia de la práctica.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio continúa mostrando los archivos locales creados durante los retos.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}