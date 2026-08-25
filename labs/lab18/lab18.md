---
layout: lab
title: "Práctica 18: Endurecimiento básico de Pods"
permalink: /lab18/lab18/
images_base: /labs/lab18/img
duration: "70 minutos"
objective:
  - Aplicar controles básicos de endurecimiento a Pods mediante securityContext, ejecución como usuario no root, bloqueo de escalación de privilegios, eliminación de Linux capabilities, filesystem raíz de solo lectura, almacenamiento temporal escribible y seccomp RuntimeDefault.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Haber completado la Práctica 16 ServiceAccount y permisos mínimos.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica aplicarás controles de seguridad directamente sobre Pods y contenedores. Primero revisarás de forma guiada la diferencia entre el securityContext del Pod y el del contenedor y construirás un ejemplo que se ejecute como usuario no root. Después resolverás retos donde deberás impedir escalación de privilegios, eliminar capabilities, utilizar un filesystem raíz de solo lectura, proporcionar una ruta temporal escribible mediante emptyDir y aplicar seccomp RuntimeDefault. Finalmente auditarás y corregirás un manifiesto deliberadamente inseguro.
slug: lab18
lab_number: 18
final_result: >
  Al finalizar habrás endurecido Pods mediante una identidad no root, bloqueo de escalación de privilegios, eliminación de capabilities, filesystem raíz de solo lectura y seccomp RuntimeDefault. También habrás comprobado que una aplicación con root filesystem de solo lectura puede conservar rutas específicas de escritura mediante volúmenes, y habrás auditado y corregido un Pod inseguro hasta cumplir un conjunto completo de controles básicos de mínimo privilegio.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza busybox:1.38.0-musl como imagen de referencia para mantener las pruebas ligeras y reproducibles.
  - securityContext puede configurarse a nivel de Pod y de contenedor; algunos campos solo existen o resultan relevantes en uno de esos niveles.
  - runAsNonRoot evita que Kubernetes inicie el contenedor como UID 0 cuando puede determinar que la configuración incumple ese requisito.
  - allowPrivilegeEscalation controla si un proceso puede obtener más privilegios que su proceso padre.
  - capabilities.drop con ALL reduce privilegios del proceso eliminando las Linux capabilities heredadas.
  - readOnlyRootFilesystem protege el filesystem raíz del contenedor, mientras volúmenes como emptyDir pueden proporcionar rutas específicas de escritura.
  - seccompProfile con RuntimeDefault solicita el perfil seccomp predeterminado proporcionado por el runtime.
  - Los primeros 9 pasos son guiados y los siguientes 21 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 30/70.
references:
  - text: Security Context para Pods y Containers
    url: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
  - text: Pod Security Standards
    url: https://kubernetes.io/docs/concepts/security/pod-security-standards/
  - text: Restringir el perfil seccomp de un contenedor
    url: https://kubernetes.io/docs/tutorials/security/seccomp/
  - text: Linux kernel security constraints for Pods and containers
    url: https://kubernetes.io/docs/concepts/security/linux-kernel-security-constraints/
prev: /lab17/lab17/
next: /lab19/lab19/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Comprender y aplicar controles básicos de seguridad — 14 min

Prepararás el workspace y el namespace, revisarás los dos niveles de `securityContext` y construirás un Pod guiado que se ejecute con una identidad no root. Esta será la única tarea completamente guiada.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, confirmarás el contexto activo y prepararás el namespace donde se ejecutarán todos los escenarios de hardening.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab18` y accede a él para almacenar los manifiestos y evidencias generados durante la práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab18`; los archivos locales se conservarán al terminar la limpieza del clúster.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab18 && cd workspace/lab18
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab18`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo para asegurarte de que los Pods de seguridad se crearán en el clúster local utilizado por el curso.

  > **Importante:** El contexto esperado es `kind-ckad`. No continúes si aparece un contexto diferente.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab18` para aislar los Pods endurecidos y los escenarios deliberadamente inseguros utilizados durante la práctica.

  > **Advertencia:** Si `lab18` ya existe, revisa primero sus Pods para evitar que recursos anteriores alteren las validaciones.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab18
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab18 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Explorar securityContext

Revisarás qué controles se configuran a nivel de Pod y cuáles pertenecen al contenedor antes de comenzar a modificar workloads.

- {% include step_label.html %} Consulta el `securityContext` del Pod para identificar controles de identidad y perfiles de seguridad aplicables de forma común a sus contenedores.

  > **Nota:** A nivel de Pod puedes encontrar campos como `runAsUser`, `runAsGroup`, `runAsNonRoot` y `seccompProfile`.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain pod.spec.securityContext --recursive
  ```

  > **Salida esperada:** La salida incluye campos de identidad, grupos y `seccompProfile`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el `securityContext` del contenedor para localizar controles específicos como escalación de privilegios, capabilities y filesystem raíz de solo lectura.

  > **Importante:** No todos los campos disponibles a nivel de contenedor existen en el `securityContext` del Pod; identifica el nivel correcto antes de editar un manifiesto.
  {: .lab-note .important .compact}

  ```bash
  kubectl explain pod.spec.containers.securityContext --recursive
  ```

  > **Salida esperada:** La salida incluye `allowPrivilegeEscalation`, `capabilities`, `privileged`, `readOnlyRootFilesystem`, `runAsNonRoot` y `runAsUser`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta específicamente `seccompProfile` para reconocer el campo `type` y los perfiles que Kubernetes permite declarar.

  > **Nota:** En esta práctica utilizarás `RuntimeDefault`, que solicita el perfil seccomp predeterminado proporcionado por el runtime del nodo.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain pod.spec.securityContext.seccompProfile
  ```

  > **Salida esperada:** kubectl muestra el campo `type` y describe opciones como `RuntimeDefault`, `Localhost` y `Unconfined`.
  {: .lab-note .output .compact}

### Tarea 1.3. Ejecutar un Pod como usuario no root

Construirás un ejemplo mínimo con identidad explícita y escalación de privilegios deshabilitada y después comprobarás el UID efectivo desde el contenedor.

- {% include step_label.html %} Crea `nonroot-demo.yaml` con un Pod que se ejecute como UID `1000`, GID `3000`, exija una identidad no root y bloquee la escalación de privilegios del contenedor.

  > **Importante:** Declarar `runAsNonRoot: true` expresa la intención de impedir UID 0, mientras `runAsUser` y `runAsGroup` fijan la identidad que utilizará el proceso.
  {: .lab-note .important .compact}

  ```bash
  cat > nonroot-demo.yaml <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: nonroot-demo
    namespace: lab18
  spec:
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      runAsGroup: 3000
    containers:
      - name: app
        image: busybox:1.38.0-musl
        command:
          - sh
          - -c
          - 'sleep 3600'
        securityContext:
          allowPrivilegeEscalation: false
  EOF
  ```

  > **Salida esperada:** Se crea `nonroot-demo.yaml` con identidad no root a nivel de Pod y escalación bloqueada a nivel de contenedor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el manifiesto para comprobar que la imagen puede ejecutarse correctamente con la identidad definida.

  > **Advertencia:** Algunas imágenes requieren privilegios o usuarios concretos. Si una imagen no funciona como non-root, el problema puede estar en la propia imagen y no en la sintaxis de Kubernetes.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply -f nonroot-demo.yaml
  ```

  > **Salida esperada:** Kubernetes responde `pod/nonroot-demo created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la identidad efectiva dentro del contenedor para demostrar que el proceso no se está ejecutando como root.

  > **Nota:** La validación dentro del contenedor confirma el comportamiento real y complementa la inspección declarativa del manifiesto.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec nonroot-demo -n lab18 -- id
  ```

  > **Salida esperada:** La salida muestra `uid=1000` y `gid=3000`; el proceso no utiliza UID 0.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🛡️ Tarea 2. Reto: ejecutar una aplicación sin privilegios — 17 min

A partir de esta tarea comienza la parte no guiada. Deberás construir un Pod con identidad explícita y posteriormente reforzarlo para impedir privilegios adicionales sin recibir los comandos de implementación.

### Tarea 2.1. Aplicar una identidad no root

Interpretarás los requisitos de identidad y decidirás qué campos deben declararse para garantizar que el proceso utilice los UID y GID solicitados.

- {% include step_label.html %} Analiza el escenario de `api-secure` y determina qué controles necesitas para garantizar que el proceso se ejecute con la identidad solicitada.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl explain`, `kubectl --help` y los ejemplos guiados como referencia.
  {: .lab-note .important .compact}

  ```text
  Reto de identidad:

  Pod:
  - Nombre: api-secure
  - Namespace: lab18
  - Imagen: busybox:1.38.0-musl
  - Debe permanecer Running.

  Identidad:
  - UID efectivo: 10001
  - GID efectivo: 3000
  - No debe ejecutarse como root.
  ```

  > **Salida esperada:** Identificas los campos necesarios para declarar UID, GID y ejecución obligatoria como usuario no root.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `api-secure` y espera hasta que el Pod quede disponible para validación.

  > **Nota:** Conserva el manifiesto local; será ampliado en la siguiente subtarea con controles adicionales.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora api-secure.

  No continúes hasta que:
  - el Pod exista;
  - esté Running;
  - use UID 10001;
  - use GID 3000.
  ```

  > **Salida esperada:** `pod/api-secure` existe y permanece en estado `Running`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba desde el contenedor que la identidad efectiva coincide con los requisitos del reto.

  > **Advertencia:** Un Pod `Running` no demuestra por sí solo que esté endurecido; valida también la identidad efectiva del proceso.
  {: .lab-note .warning .compact}

  ```bash
  kubectl exec api-secure -n lab18 -- id
  ```

  > **Salida esperada:** La salida muestra UID `10001`, GID `3000` y no utiliza UID 0.
  {: .lab-note .output .compact}

### Tarea 2.2. Impedir escalación y ejecución privilegiada

Reforzarás el Pod existente para impedir que el proceso eleve privilegios y para declarar explícitamente que el contenedor no debe ejecutarse en modo privileged.

- {% include step_label.html %} Analiza la nueva exigencia de seguridad e identifica qué propiedades faltan en el `securityContext` del contenedor.

  > **Importante:** Mantén la identidad del reto anterior; esta subtarea agrega restricciones y no debe eliminar los controles ya implementados.
  {: .lab-note .important .compact}

  ```text
  Nueva revisión de seguridad:

  api-secure debe conservar:
  - UID 10001
  - GID 3000
  - ejecución no root

  Y debe cumplir además:
  - allowPrivilegeEscalation=false
  - privileged=false
  ```

  > **Salida esperada:** Identificas los dos controles adicionales que deben quedar declarados a nivel de contenedor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Actualiza por tu cuenta el manifiesto y recrea el Pod con los controles adicionales sin cambiar su nombre ni su imagen.

  > **Advertencia:** Algunos campos de un Pod no pueden modificarse directamente después de su creación. Si necesitas recrearlo, conserva el manifiesto como fuente del estado deseado.
  {: .lab-note .warning .compact}

  ```text
  Aplica ahora el endurecimiento adicional.

  Estado final requerido:
  - Pod api-secure Running
  - non-root
  - privileged=false
  - allowPrivilegeEscalation=false
  ```

  > **Salida esperada:** `api-secure` vuelve a quedar `Running` con los controles adicionales declarados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el `securityContext` activo del contenedor para comprobar que Kubernetes almacenó las restricciones solicitadas.

  > **Nota:** Esta validación inspecciona el objeto activo y evita depender únicamente del archivo local.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod api-secure -n lab18 -o jsonpath='{.spec.containers[0].securityContext}{"\n"}'
  ```

  > **Salida esperada:** La salida incluye `allowPrivilegeEscalation:false` y `privileged:false`, además de cualquier control de contenedor que hayas definido.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba nuevamente la identidad dentro del contenedor después de aplicar las restricciones para confirmar que el hardening no alteró el UID ni el GID requeridos.

  > **Importante:** Un cambio de seguridad correcto debe conservar simultáneamente funcionalidad e identidad.
  {: .lab-note .important .compact}

  ```bash
  kubectl exec api-secure -n lab18 -- id
  ```

  > **Salida esperada:** El proceso continúa ejecutándose con UID `10001` y GID `3000`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🔒 Tarea 3. Reto: reducir capabilities y proteger el filesystem — 17 min

Continuarás endureciendo el workload mediante eliminación de Linux capabilities, root filesystem de solo lectura, una ruta temporal escribible y el perfil seccomp predeterminado del runtime.

### Tarea 3.1. Eliminar Linux capabilities

Aplicarás el principio de mínimo privilegio retirando todas las capabilities del contenedor cuando la aplicación no requiere ninguna de ellas.

- {% include step_label.html %} Analiza el requerimiento de capabilities y determina cómo declarar que el contenedor debe iniciar sin ninguna capability adicional disponible.

  > **Nota:** Las Linux capabilities dividen privilegios tradicionalmente asociados a root en capacidades más específicas; eliminar las que no se necesitan reduce superficie de ataque.
  {: .lab-note .info .compact}

  ```text
  Auditoría de capabilities:

  api-secure no necesita ninguna Linux capability.

  Requisito:
  - eliminar todas las capabilities mediante securityContext;
  - conservar todos los controles implementados anteriormente.
  ```

  > **Salida esperada:** Identificas cómo expresar la eliminación completa de capabilities en el contexto de seguridad del contenedor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta la reducción de capabilities y deja nuevamente el Pod disponible.

  > **Importante:** No sustituyas `api-secure` por otro workload; continúa endureciendo el mismo manifiesto acumulativamente.
  {: .lab-note .important .compact}

  ```text
  Actualiza api-secure.

  Estado requerido:
  - Pod Running
  - identidad no root
  - sin escalación de privilegios
  - no privileged
  - todas las capabilities eliminadas
  ```

  > **Salida esperada:** `api-secure` vuelve a estar `Running` después de aplicar la nueva restricción.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona la configuración activa de capabilities para demostrar que el contenedor solicita eliminar todas ellas.

  > **Advertencia:** La validación debe revisar el manifiesto activo; no asumas que la configuración local fue aplicada correctamente.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get pod api-secure -n lab18 -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop}{"\n"}'
  ```

  > **Salida esperada:** La salida contiene `ALL`.
  {: .lab-note .output .compact}

### Tarea 3.2. Aplicar root filesystem de solo lectura y seccomp

Modificarás el Pod para proteger el filesystem raíz sin impedir que la aplicación escriba en `/tmp`, utilizando un volumen efímero como área explícitamente escribible.

- {% include step_label.html %} Analiza el nuevo requisito y determina cómo combinar un root filesystem de solo lectura con una ruta `/tmp` escribible y un perfil seccomp `RuntimeDefault`.

  > **Importante:** `readOnlyRootFilesystem` no obliga a que todas las rutas sean de solo lectura. Un volumen montado sobre una ruta concreta puede proporcionar almacenamiento escribible separado del filesystem de la imagen.
  {: .lab-note .important .compact}

  ```text
  Hardening adicional:

  api-secure debe cumplir:
  - root filesystem de solo lectura;
  - /tmp debe seguir siendo escribible;
  - /tmp debe provenir de un volumen emptyDir;
  - seccompProfile.type=RuntimeDefault;
  - conservar todos los controles anteriores.
  ```

  > **Salida esperada:** Identificas que necesitas combinar securityContext, un volumen `emptyDir` y su correspondiente `volumeMount`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta la protección del filesystem, la ruta temporal escribible y seccomp, y deja el Pod nuevamente en estado `Running`.

  > **Advertencia:** Si el comando de inicio o la aplicación intenta escribir en otra ruta del root filesystem, el Pod puede fallar. La única escritura necesaria en este escenario debe realizarse bajo `/tmp`.
  {: .lab-note .warning .compact}

  ```text
  Aplica ahora el hardening.

  Antes de continuar:
  - api-secure debe estar Running;
  - /tmp debe estar montado desde emptyDir;
  - root filesystem debe ser read-only;
  - seccomp debe ser RuntimeDefault.
  ```

  > **Salida esperada:** `api-secure` queda disponible con todos los controles acumulados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que `/tmp` continúa permitiendo escritura mediante el volumen dedicado.

  > **Nota:** Esta prueba demuestra que es posible limitar el filesystem raíz y proporcionar únicamente los puntos de escritura que la aplicación realmente necesita.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec api-secure -n lab18 -- sh -c 'echo "ok" > /tmp/write-test && cat /tmp/write-test'
  ```

  > **Salida esperada:** El comando muestra `ok`, confirmando que `/tmp` es escribible.
  {: .lab-note .output .compact}

- {% include step_label.html %} Intenta crear un archivo fuera del volumen escribible para comprobar que el root filesystem protegido rechaza la operación.

  > **Advertencia:** El error exacto puede variar según la ruta y la imagen, pero la escritura fuera de `/tmp` no debe completarse correctamente.
  {: .lab-note .warning .compact}

  ```bash
  kubectl exec api-secure -n lab18 -- sh -c 'touch /hardening-test 2>&1 || true'
  ```

  > **Salida esperada:** La operación es rechazada y `/hardening-test` no se crea.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🧪 Tarea 4. Reto: auditar y corregir un Pod inseguro — 16 min

Recibirás un manifiesto deliberadamente inseguro. Deberás identificar sus problemas, diseñar una corrección y demostrar que el estado final cumple todos los requisitos sin recibir la solución de implementación.

### Tarea 4.1. Auditar el manifiesto inseguro

Crearás únicamente el archivo inicial proporcionado por el laboratorio y analizarás sus controles antes de intentar corregirlo.

- {% include step_label.html %} Crea el archivo inicial `legacy-api.yaml` exactamente como se proporciona para disponer de un workload deliberadamente inseguro que será objeto de la auditoría.

  > **Advertencia:** Este manifiesto contiene configuraciones inseguras de forma intencional. No lo utilices como plantilla para workloads reales.
  {: .lab-note .warning .compact}

  ```bash
  cat > legacy-api.yaml <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: legacy-api
    namespace: lab18
  spec:
    containers:
      - name: app
        image: busybox:1.38.0-musl
        command:
          - sh
          - -c
          - 'sleep 3600'
        securityContext:
          privileged: true
          allowPrivilegeEscalation: true
          runAsUser: 0
  EOF
  ```

  > **Salida esperada:** Se crea `legacy-api.yaml` con un contenedor configurado deliberadamente con privilegios elevados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona el manifiesto e identifica por tu cuenta todas las decisiones contrarias al principio de mínimo privilegio, incluyendo controles ausentes que ya utilizaste en las tareas anteriores.

  > **Importante:** No te limites a localizar valores `true` o UID 0; compara el manifiesto completo contra el conjunto de controles que una aplicación endurecida debería declarar.
  {: .lab-note .important .compact}

  ```bash
  cat legacy-api.yaml
  ```

  > **Salida esperada:** Identificas ejecución como root, modo privileged, escalación permitida y ausencia de controles como drop de capabilities, root filesystem read-only y seccomp.
  {: .lab-note .output .compact}

- {% include step_label.html %} Diseña la corrección utilizando únicamente el estado final requerido y determina qué partes del manifiesto deben modificarse o agregarse.

  > **Nota:** Este paso evalúa tu capacidad para transformar requisitos de seguridad en una especificación Kubernetes antes de ejecutar cambios.
  {: .lab-note .info .compact}

  ```text
  Estado final requerido para legacy-api:

  - UID: 10001
  - GID: 3000
  - runAsNonRoot=true
  - privileged=false
  - allowPrivilegeEscalation=false
  - drop ALL capabilities
  - readOnlyRootFilesystem=true
  - /tmp escribible mediante emptyDir
  - seccompProfile.type=RuntimeDefault
  - Pod Running
  ```

  > **Salida esperada:** Tienes identificados los controles de Pod, contenedor, volumen y montaje necesarios para cumplir el estado final.
  {: .lab-note .output .compact}

### Tarea 4.2. Corregir y demostrar el endurecimiento integral

Aplicarás la corrección por tu cuenta y realizarás varias validaciones independientes para demostrar identidad, filesystem, seccomp y restricciones del contenedor.

- {% include step_label.html %} Corrige `legacy-api.yaml` por tu cuenta, aplica el manifiesto y deja el Pod en estado `Running` con todos los controles solicitados.

  > **Advertencia:** No elimines requisitos para lograr que el Pod inicie. El objetivo es que funcionalidad y hardening se cumplan simultáneamente.
  {: .lab-note .warning .compact}

  ```text
  Implementa ahora la corrección integral.

  No continúes hasta que:
  - legacy-api esté Running;
  - todos los controles solicitados estén declarados.
  ```

  > **Salida esperada:** `pod/legacy-api` está `Running` con el manifiesto endurecido.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida la identidad efectiva dentro de `legacy-api` para demostrar que la corrección eliminó la ejecución como root.

  > **Nota:** El proceso debe utilizar exactamente el UID y GID solicitados por la auditoría.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec legacy-api -n lab18 -- id
  ```

  > **Salida esperada:** La salida muestra UID `10001` y GID `3000`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que `/tmp` es escribible pero una ruta del root filesystem no admite la creación de archivos.

  > **Importante:** Esta validación demuestra que el filesystem de solo lectura no impide proporcionar almacenamiento temporal controlado mediante un volumen.
  {: .lab-note .important .compact}

  ```bash
  kubectl exec legacy-api -n lab18 -- sh -c 'echo "ok" > /tmp/allowed && cat /tmp/allowed; touch /blocked 2>&1 || true'
  ```

  > **Salida esperada:** Se muestra `ok` para `/tmp/allowed` y la escritura de `/blocked` es rechazada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona el objeto activo para demostrar que los controles esenciales de contenedor y el perfil seccomp están presentes antes de dar por terminado el reto.

  > **Advertencia:** No continúes a la limpieza si algún control solicitado falta en el objeto activo, aunque el Pod esté `Running`.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get pod legacy-api -n lab18 -o jsonpath='NonRoot={.spec.securityContext.runAsNonRoot} UID={.spec.securityContext.runAsUser} GID={.spec.securityContext.runAsGroup} Seccomp={.spec.securityContext.seccompProfile.type} Privileged={.spec.containers[0].securityContext.privileged} Escalation={.spec.containers[0].securityContext.allowPrivilegeEscalation} ReadOnly={.spec.containers[0].securityContext.readOnlyRootFilesystem} Drop={.spec.containers[0].securityContext.capabilities.drop}{"\n"}'
  ```

  > **Salida esperada:** La salida refleja `NonRoot=true`, UID `10001`, GID `3000`, `Seccomp=RuntimeDefault`, `Privileged=false`, `Escalation=false`, `ReadOnly=true` y `Drop=[ALL]`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar el entorno de la práctica — 6 min

Esta tarea no forma parte de la evaluación 30/70. Ejecútala únicamente después de completar todos los retos, validar ambos Pods endurecidos y confirmar que ya no necesitas conservar el escenario activo.

### Tarea 5.1. Revisar y retirar los recursos del laboratorio

Realizarás una última inspección, eliminarás el namespace completo y comprobarás que Kubernetes retiró los Pods mientras los manifiestos locales permanecen disponibles para repaso.

- {% include step_label.html %} Revisa una última vez los Pods de `lab18` antes de destruir el escenario para confirmar que terminaste las validaciones de hardening.

  > **Nota:** Debes haber revisado especialmente `api-secure` y `legacy-api` antes de continuar con la limpieza.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab18
  ```

  > **Salida esperada:** Se muestran los Pods utilizados durante la práctica y sus estados actuales.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab18` únicamente después de concluir todos los retos y validaciones.

  > **Advertencia:** La eliminación del namespace destruye el escenario activo y ya no podrás inspeccionar los `securityContext` de los Pods.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab18 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab18" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace ya no existe para confirmar que la limpieza de recursos Kubernetes terminó correctamente.

  > **Importante:** La ausencia de salida es el resultado esperado debido al uso de `--ignore-not-found`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab18 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab18`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los manifiestos locales permanecen en el workspace para comparar posteriormente las versiones iniciales y endurecidas.

  > **Nota:** La limpieza afecta únicamente al clúster; conserva `workspace/lab18` como evidencia y material de estudio.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio continúa mostrando archivos como `nonroot-demo.yaml`, `legacy-api.yaml` y los manifiestos creados durante los retos.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}