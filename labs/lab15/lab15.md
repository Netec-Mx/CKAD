---
layout: lab
title: "Práctica 15: Manejo de información sensible con Secrets"
permalink: /lab15/lab15/
images_base: /labs/lab15/img
duration: "45 minutos"
objective:
  - Crear y administrar Secrets para separar información sensible de los manifiestos de aplicación, consumir claves mediante secretKeyRef y envFrom, montar credenciales como archivos dentro de contenedores y analizar cómo se comportan las actualizaciones según el mecanismo de consumo utilizado.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Haber completado la Práctica 14 Configuración de aplicaciones con ConfigMaps.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica utilizarás Secrets para externalizar credenciales y otros valores sensibles que no deben quedar escritos directamente dentro de los manifiestos de aplicación. Crearás Secrets desde literales, revisarás la diferencia entre data y stringData, consumirás valores mediante referencias individuales y envFrom y después resolverás retos donde deberás inyectar credenciales y montar secretos como archivos. También compararás el comportamiento de una actualización cuando el Secret se consume como variable de entorno y cuando se proyecta como volumen.
slug: lab15
lab_number: 15
final_result: >
  Al finalizar habrás creado y utilizado Secrets desde diferentes fuentes, comprendido que los valores de data se representan en base64 pero que base64 no equivale a cifrado, consumido credenciales mediante secretKeyRef y envFrom y montado un Secret como volumen dentro de un contenedor. También habrás resuelto escenarios de actualización sin exponer innecesariamente valores sensibles y limpiado el namespace únicamente después de completar todos los retos.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza busybox:1.38.0-musl para los contenedores de validación.
  - Los valores almacenados en Secret.data se representan en base64; base64 no debe interpretarse como cifrado.
  - Durante las validaciones se evita imprimir contraseñas completas cuando no es necesario.
  - Los valores consumidos como variables de entorno se leen cuando inicia el contenedor y no cambian dentro del proceso existente únicamente porque el Secret sea actualizado.
  - Los Secrets montados como volumen pueden actualizar su contenido proyectado con el tiempo, aunque el cambio no debe considerarse instantáneo.
  - Los primeros 12 pasos son guiados y los siguientes 12 pasos corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 50/50.
references:
  - text: Secrets en Kubernetes
    url: https://kubernetes.io/docs/concepts/configuration/secret/
  - text: Distribuir credenciales de forma segura mediante Secrets
    url: https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/
  - text: Referencia oficial de kubectl create secret generic
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret_generic/
  - text: Volúmenes Secret
    url: https://kubernetes.io/docs/concepts/storage/volumes/#secret
prev: /lab14/lab14/
next: /lab16/lab16/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y comprender Secrets — 7 min

Prepararás el workspace y el namespace de la práctica y revisarás la estructura del recurso Secret. El objetivo es comprender cómo Kubernetes separa información sensible de otros manifiestos y cómo representa sus valores dentro de la API.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, validarás el contexto activo y prepararás un namespace aislado donde se crearán todos los Secrets y workloads de esta práctica.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab15` y accede a él para mantener separados los manifiestos y archivos utilizados durante esta práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab15`; los archivos locales se conservarán al finalizar como material de repaso.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab15 && cd workspace/lab15
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab15`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo para confirmar que kubectl continúa conectado al clúster local utilizado por el curso.

  > **Importante:** El valor esperado es `kind-ckad`. No continúes si kubectl apunta a un contexto diferente.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab15` para aislar los Secrets y aplicaciones del resto de los laboratorios.

  > **Advertencia:** Si `lab15` ya existe por una ejecución anterior, revisa su contenido antes de continuar para evitar reutilizar credenciales antiguas.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab15
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab15 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Explorar la estructura de Secret

Consultarás el esquema del recurso y generarás un ejemplo local para reconocer cómo Kubernetes representa claves sensibles dentro del API Server.

- {% include step_label.html %} Consulta la definición del recurso Secret para identificar sus campos principales y confirmar que pertenece a la API core `v1`.

  > **Nota:** Secret permite separar credenciales y otros valores sensibles de la configuración normal de una aplicación.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain secret
  ```

  > **Salida esperada:** kubectl muestra `KIND: Secret`, `VERSION: v1` y los campos principales del recurso.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los campos `data` y `stringData` para distinguir entre valores representados en base64 y texto que Kubernetes convierte al almacenar el Secret.

  > **Importante:** `data` utiliza valores base64 y `stringData` acepta texto sin codificar en el manifiesto. Ninguno de los dos conceptos convierte base64 en un mecanismo de cifrado.
  {: .lab-note .important .compact}

  ```bash
  kubectl explain secret.data
  ```
  ```bash
  kubectl explain secret.stringData
  ```

  > **Salida esperada:** kubectl describe ambos campos y muestra que `data` contiene valores codificados y `stringData` acepta strings.
  {: .lab-note .output .compact}

- {% include step_label.html %} Genera localmente un Secret de ejemplo mediante `--dry-run=client` para observar cómo un valor literal aparece representado dentro de `data`.

  > **Advertencia:** El valor mostrado en `data` está codificado en base64 y puede recuperarse fácilmente; no lo interpretes como información cifrada.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create secret generic demo-secret -n lab15 --from-literal=USERNAME=demo --dry-run=client -o yaml
  ```

  > **Salida esperada:** La salida YAML contiene `kind: Secret`, `metadata.name: demo-secret` y una clave `USERNAME` dentro de `data`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🔐 Tarea 2. Crear y consumir Secrets — 11 min

Crearás un Secret desde literales y lo consumirás desde un Deployment mediante una referencia individual y `envFrom`. También comprobarás cómo recuperar una clave codificada para entender qué información almacena realmente Kubernetes.

### Tarea 2.1. Crear y revisar un Secret

Crearás credenciales simples, inspeccionarás su representación dentro de Kubernetes y decodificarás únicamente una clave no crítica para demostrar la relación entre el valor original y base64.

- {% include step_label.html %} Crea `db-secret` con un usuario y una contraseña utilizando literales, manteniendo las credenciales fuera del manifiesto del Deployment.

  > **Nota:** `kubectl create secret generic` permite construir un Secret desde literales, archivos u otras fuentes sin escribir manualmente valores base64.
  {: .lab-note .info .compact}

  ```bash
  kubectl create secret generic db-secret -n lab15 --from-literal=DB_USER=appuser --from-literal=DB_PASSWORD=Lab15-Secret-2026
  ```

  > **Salida esperada:** Kubernetes responde `secret/db-secret created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el Secret en YAML para identificar sus claves y observar que los valores aparecen representados dentro de `data`.

  > **Importante:** Evita copiar o compartir la salida de Secrets reales. En este laboratorio las credenciales son artificiales y se utilizan únicamente con fines didácticos.
  {: .lab-note .important .compact}

  ```bash
  kubectl get secret db-secret -n lab15 -o yaml
  ```

  > **Salida esperada:** La salida contiene las claves `DB_USER` y `DB_PASSWORD` dentro de `data`, además de `type: Opaque`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Decodifica únicamente `DB_USER` para comprobar que base64 permite recuperar directamente el valor original almacenado.

  > **Advertencia:** No utilices este procedimiento para imprimir contraseñas reales durante validaciones rutinarias. Aquí se decodifica solo el usuario para demostrar el concepto.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get secret db-secret -n lab15 -o jsonpath='{.data.DB_USER}' | base64 --decode
  ```

  > **Salida esperada:** El comando muestra `appuser`.
  {: .lab-note .output .compact}

### Tarea 2.2. Consumir el Secret desde un Deployment

Crearás una aplicación que obtiene una credencial mediante `secretKeyRef` e importa el resto de las claves mediante `envFrom`, evitando que los valores sensibles aparezcan directamente dentro del Pod template.

- {% include step_label.html %} Crea `secret-app.yaml` con un Deployment que obtenga `DB_USER` mediante `secretKeyRef` y cargue las claves restantes desde `db-secret` mediante `envFrom`.

  > **Nota:** `secretKeyRef` permite seleccionar una clave concreta, mientras `envFrom.secretRef` importa todas las claves válidas del Secret como variables de entorno.
  {: .lab-note .info .compact}

  ```bash
  cat > secret-app.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: secret-app
    namespace: lab15
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: secret-app
    template:
      metadata:
        labels:
          app: secret-app
      spec:
        containers:
          - name: app
            image: busybox:1.38.0-musl
            command:
              - sh
              - -c
              - 'while true; do sleep 3600; done'
            env:
              - name: APPLICATION_DB_USER
                valueFrom:
                  secretKeyRef:
                    name: db-secret
                    key: DB_USER
            envFrom:
              - secretRef:
                  name: db-secret
  EOF
  ```

  > **Salida esperada:** Se crea `secret-app.yaml` con referencias a `db-secret` y sin escribir directamente las credenciales dentro de la especificación del contenedor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el Deployment para crear un contenedor que lea el Secret al momento de iniciar.

  > **Importante:** Una referencia obligatoria a un Secret inexistente impide que el contenedor inicie correctamente; por eso `db-secret` fue creado antes del Deployment.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f secret-app.yaml
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/secret-app created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida que las variables estén definidas dentro del contenedor sin imprimir la contraseña completa.

  > **Nota:** La comprobación confirma el uso del Secret minimizando la exposición innecesaria de información sensible en la terminal.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec deployment/secret-app -n lab15 -- sh -c 'echo "APPLICATION_DB_USER=$APPLICATION_DB_USER"; echo "DB_USER=$DB_USER"; test -n "$DB_PASSWORD" && echo "DB_PASSWORD=defined"'
  ```

  > **Salida esperada:** Se muestran `APPLICATION_DB_USER=appuser`, `DB_USER=appuser` y `DB_PASSWORD=defined`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🎯 Tarea 3. Reto: inyectar credenciales en una aplicación — 9 min

A partir de esta tarea comienza la parte no guiada. Deberás crear credenciales y conectarlas con un Deployment sin exponer sus valores directamente dentro de la especificación del contenedor.

### Tarea 3.1. Preparar las credenciales de Payments

Interpretarás los requisitos y elegirás cómo construir el Secret y cómo suministrar sus claves a una aplicación con dos réplicas.

- {% include step_label.html %} Analiza el escenario y determina qué recursos y referencias necesitas para proporcionar las credenciales solicitadas a la aplicación Payments.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl --help`, `kubectl explain` y generación mediante `--dry-run=client`.
  {: .lab-note .important .compact}

  ```text
  Reto 1:

  Secret:
  - Nombre: payments-secret
  - Namespace: lab15
  - DB_USER=payments
  - DB_PASSWORD=Payments-2026
  - DB_HOST=db.internal

  Deployment:
  - Nombre: payments
  - Namespace: lab15
  - Réplicas: 2
  - Imagen: busybox:1.38.0-musl
  - El contenedor debe permanecer ejecutándose.
  - Las tres variables deben provenir del Secret.
  - No escribas los valores directamente dentro del contenedor.
  ```

  > **Salida esperada:** Identificas que necesitas crear `payments-secret` y hacer que el Deployment consuma sus claves desde Kubernetes.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `payments-secret` y el Deployment `payments`, respetando todos los requisitos sin imprimir las credenciales durante la creación.

  > **Nota:** Puedes utilizar referencias individuales o `envFrom`; el mecanismo elegido forma parte de tu estrategia de resolución.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora la solución.

  No continúes hasta considerar satisfechos:
  - payments-secret existente;
  - payments con 2 réplicas;
  - Pods Ready;
  - credenciales obtenidas desde Secret.
  ```

  > **Salida esperada:** Existen `secret/payments-secret` y `deployment/payments`, y el Deployment alcanza dos réplicas disponibles.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida que el Secret y el Deployment existen sin mostrar los valores almacenados en las credenciales.

  > **Advertencia:** No utilices `-o yaml` sobre el Secret durante esta validación; únicamente necesitas confirmar su existencia y cantidad de claves.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get secret payments-secret -n lab15
  kubectl get deployment payments -n lab15
  ```

  > **Salida esperada:** `payments-secret` existe y `payments` muestra `2/2` réplicas disponibles.
  {: .lab-note .output .compact}

### Tarea 3.2. Validar y actualizar credenciales

Comprobarás que las variables están definidas, actualizarás una contraseña y deberás decidir cómo hacer que los contenedores adopten el nuevo valor sin reconstruir la imagen.

- {% include step_label.html %} Comprueba dentro del Deployment que las variables requeridas están disponibles evitando revelar el contenido completo de `DB_PASSWORD`.

  > **Nota:** La validación funcional puede confirmar presencia y valores no sensibles sin imprimir una contraseña en claro.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec deployment/payments -n lab15 -- sh -c 'echo "DB_USER=$DB_USER"; echo "DB_HOST=$DB_HOST"; test -n "$DB_PASSWORD" && echo "DB_PASSWORD=defined"'
  ```

  > **Salida esperada:** Se muestran `DB_USER=payments`, `DB_HOST=db.internal` y `DB_PASSWORD=defined`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Actualiza por tu cuenta la contraseña almacenada en `payments-secret` y determina qué debe ocurrir para que los procesos existentes adopten el nuevo valor como variable de entorno.

  > **Importante:** Modificar un Secret no cambia las variables ya cargadas dentro de un proceso en ejecución. Debes aplicar una acción apropiada sobre el workload para que nuevos contenedores vuelvan a leer el Secret.
  {: .lab-note .important .compact}

  ```text
  Cambio solicitado:

  payments-secret:
  DB_PASSWORD=Payments-2026-Rotated

  Restricciones:
  - No elimines payments-secret.
  - No cambies la imagen.
  - No escribas la contraseña directamente en el Deployment.
  - El resultado final debe utilizar el nuevo Secret.
  ```

  > **Salida esperada:** El Secret contiene la nueva contraseña y determinas cómo renovar los contenedores para que vuelvan a leerla.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida que los Pods actuales fueron recreados como parte de la rotación y que la contraseña continúa estando definida sin mostrarla.

  > **Advertencia:** Si los Pods conservan su antigüedad original, revisa si realmente fueron recreados después de actualizar el Secret.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get pods -n lab15 -l app=payments
  ```

  > **Salida esperada:** Se muestran dos Pods Ready correspondientes al Deployment `payments`, recreados después de la rotación del Secret.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 📁 Tarea 4. Reto: montar y actualizar Secrets como archivos — 11 min

Resolverás un escenario donde la aplicación necesita credenciales como archivos dentro del filesystem. Después actualizarás el Secret y observarás el comportamiento de la proyección montada como volumen.

### Tarea 4.1. Montar credenciales como volumen

Crearás un Secret y un Deployment sin comandos de implementación proporcionados, seleccionando el mecanismo correcto para presentar cada clave como un archivo.

- {% include step_label.html %} Analiza el escenario y determina cómo proyectar las claves `username` y `password` dentro de la ruta `/etc/credentials`.

  > **Importante:** Las credenciales deben provenir directamente de un volumen Secret; no deben escribirse mediante comandos de inicio ni almacenarse dentro de la imagen.
  {: .lab-note .important .compact}

  ```text
  Reto 2:

  Secret:
  - Nombre: file-secret
  - username=fileuser
  - password=FileSecret-2026

  Deployment:
  - Nombre: secret-reader
  - Namespace: lab15
  - Réplicas: 1
  - Imagen: busybox:1.38.0-musl
  - El contenedor debe permanecer ejecutándose.
  - Ruta de montaje: /etc/credentials
  - Deben existir:
      /etc/credentials/username
      /etc/credentials/password
  ```

  > **Salida esperada:** Identificas que necesitas un volumen de tipo Secret y un volumeMount dentro del contenedor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `file-secret` y `secret-reader` cumpliendo la ruta y los archivos solicitados.

  > **Nota:** Kubernetes proyecta cada clave del Secret como un archivo dentro del directorio montado, salvo que se configure un mapeo más específico.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora la solución.

  No continúes hasta considerar satisfechos:
  - file-secret existente;
  - secret-reader disponible;
  - archivos username y password presentes.
  ```

  > **Salida esperada:** Existe `file-secret`, el Deployment está disponible y ambos archivos se encuentran en `/etc/credentials`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida la existencia de los archivos y muestra únicamente el usuario, evitando imprimir el contenido completo de la contraseña.

  > **Advertencia:** No ejecutes `cat /etc/credentials/password` durante la validación rutinaria. Basta con comprobar que el archivo existe y contiene datos.
  {: .lab-note .warning .compact}

  ```bash
  kubectl exec deployment/secret-reader -n lab15 -- sh -c 'echo -n "username="; cat /etc/credentials/username; echo; test -s /etc/credentials/password && echo "password=defined"'
  ```

  > **Salida esperada:** Se muestra `username=fileuser` y `password=defined`.
  {: .lab-note .output .compact}

### Tarea 4.2. Actualizar la proyección del Secret

Modificarás la credencial almacenada sin recrear inicialmente el Pod y observarás cómo un Secret montado como volumen puede reflejar cambios de forma eventual.

- {% include step_label.html %} Actualiza por tu cuenta la contraseña almacenada en `file-secret` manteniendo el mismo nombre del Secret y sin eliminar inicialmente `secret-reader`.

  > **Nota:** Una proyección Secret montada como volumen puede actualizar su contenido con el tiempo. Esto difiere de una variable de entorno, cuyo valor queda establecido al iniciar el contenedor.
  {: .lab-note .info .compact}

  ```text
  Cambio solicitado:

  file-secret:
  password=FileSecret-2026-Rotated

  Restricciones:
  - Conserva el mismo Secret.
  - No elimines inicialmente el Pod.
  - No cambies la imagen.
  ```

  > **Salida esperada:** `file-secret` almacena la contraseña rotada mientras `secret-reader` continúa ejecutándose.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba periódicamente que el archivo de contraseña continúa existiendo y observa su momento de modificación sin mostrar el valor sensible.

  > **Importante:** La actualización del volumen es eventual y no debe considerarse instantánea. Además, una aplicación real tendría que volver a leer el archivo para adoptar el nuevo contenido.
  {: .lab-note .important .compact}

  ```bash
  kubectl exec deployment/secret-reader -n lab15 -- sh -c 'ls -l /etc/credentials/password; test -s /etc/credentials/password && echo "password=defined"'
  ```

  > **Salida esperada:** El archivo continúa presente y con contenido; la proyección puede reflejar posteriormente la versión actualizada del Secret.
  {: .lab-note .output .compact}

- {% include step_label.html %} Realiza la validación final de los retos comprobando los Secrets y Deployments antes de pasar a la limpieza.

  > **Advertencia:** No continúes con la Tarea 5 si necesitas corregir referencias, volúmenes, rutas o rotaciones. La limpieza eliminará todo el escenario activo.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get secret,deployment,pods -n lab15
  ```

  > **Salida esperada:** Se muestran `db-secret`, `payments-secret`, `file-secret`, `secret-app`, `payments` y `secret-reader`, con los Deployments disponibles.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar el entorno de la práctica — 7 min

Esta tarea no forma parte de la evaluación 50/50. Debes ejecutarla únicamente después de terminar los retos, validar el consumo mediante variables de entorno, comprobar los archivos montados y finalizar las rotaciones de credenciales.

### Tarea 5.1. Revisar y retirar los recursos del laboratorio

Realizarás una última inspección, eliminarás el namespace completo y confirmarás que Kubernetes retiró los Secrets y workloads mientras los archivos locales permanecen disponibles.

- {% include step_label.html %} Revisa una última vez los recursos existentes en `lab15` antes de eliminarlos para identificar todo lo que será retirado durante la limpieza.

  > **Nota:** Esta comprobación final permite relacionar los Secrets con los Deployments y Pods que los consumieron antes de destruir el escenario.
  {: .lab-note .info .compact}

  ```bash
  kubectl get secret,deployment,pods -n lab15
  ```

  > **Salida esperada:** Se muestran los Secrets y workloads utilizados durante la sección guiada y los retos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Cuando hayas terminado completamente la práctica, elimina el namespace `lab15` para retirar Secrets, Deployments y Pods creados durante el laboratorio.

  > **Advertencia:** No ejecutes este paso antes de terminar todas las validaciones. Eliminar el namespace destruye todos los recursos namespaced utilizados durante la práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab15 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab15" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace `lab15` ya no existe para confirmar que la limpieza de recursos Kubernetes terminó correctamente.

  > **Importante:** La ausencia de salida indica que `--ignore-not-found` no encontró el namespace, que es el resultado esperado después de eliminarlo.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab15 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab15`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los archivos locales de la práctica permanecen en el workspace para revisión posterior.

  > **Nota:** La limpieza del clúster no debe eliminar `workspace/lab15`; conserva manifiestos y archivos locales como material de estudio.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio continúa mostrando archivos locales como `secret-app.yaml` y cualquier manifiesto creado durante los retos.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}