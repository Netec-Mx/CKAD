---
layout: lab
title: "Práctica 14: Configuración de aplicaciones con ConfigMaps"
permalink: /lab14/lab14/
images_base: /labs/lab14/img
duration: "45 minutos"
objective:
  - Crear y administrar ConfigMaps para externalizar configuración no sensible, consumir claves como variables de entorno mediante configMapKeyRef y envFrom, montar archivos de configuración como volúmenes y analizar cómo se comportan las actualizaciones según el mecanismo utilizado por la aplicación.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica utilizarás ConfigMaps para separar la configuración no sensible del contenedor y reutilizarla entre aplicaciones. Crearás ConfigMaps desde literales y archivos, consumirás valores mediante referencias individuales y envFrom, y después resolverás retos donde deberás elegir por tu cuenta cómo proporcionar variables y archivos de configuración. También observarás la diferencia entre actualizar un ConfigMap utilizado como variable de entorno y actualizar uno proyectado como volumen antes de limpiar el entorno.
slug: lab14
lab_number: 14
final_result: >
  Al finalizar habrás creado ConfigMaps desde diferentes fuentes, consumido claves individuales y grupos completos como variables de entorno, montado un archivo de configuración dentro de un contenedor mediante volumen y comprobado cómo cambian las aplicaciones cuando se actualiza la configuración externa. También habrás resuelto la mitad de la práctica en formato reto, decidiendo por tu cuenta qué mecanismo de ConfigMap utilizar según el requerimiento solicitado.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza busybox:1.38.0-musl para los contenedores de validación y nginx:1.31.4-alpine3.24-slim cuando se requiere un Deployment de larga duración.
  - ConfigMap debe utilizarse únicamente para configuración no sensible; credenciales, tokens y otros datos sensibles corresponden a Secret.
  - Los valores consumidos como variables de entorno se leen cuando inicia el contenedor y no cambian dentro del proceso existente únicamente porque el ConfigMap sea actualizado.
  - Los ConfigMaps montados como volumen pueden actualizar su contenido proyectado con el tiempo, pero la actualización no debe considerarse instantánea.
  - Los primeros 12 pasos son guiados y los siguientes 12 pasos corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 50/50.
references:
  - text: ConfigMaps en Kubernetes
    url: https://kubernetes.io/docs/concepts/configuration/configmap/
  - text: Configurar un Pod mediante ConfigMap
    url: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/
  - text: Referencia oficial de kubectl create configmap
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_configmap/
  - text: Volúmenes ConfigMap
    url: https://kubernetes.io/docs/concepts/storage/volumes/#configmap
prev: /lab13/lab13/
next: /lab15/lab15/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y comprender ConfigMaps — 7 min

Prepararás el workspace y el namespace del laboratorio y revisarás la estructura del recurso ConfigMap. El objetivo es comprender qué tipo de información almacena, cómo se representa en YAML y por qué debe reservarse para configuración no sensible.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, comprobarás el contexto Kubernetes y prepararás el namespace donde se almacenarán todos los ConfigMaps y workloads de esta práctica.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab14` y accede a él para mantener separados los manifiestos y archivos de configuración utilizados durante esta práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab14`; los archivos locales se conservarán al finalizar como material de repaso.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab14 && cd workspace/lab14
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab14`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo para confirmar que kubectl continúa conectado al clúster local utilizado por el curso.

  > **Importante:** El valor esperado es `kind-ckad`. No continúes si aparece un contexto diferente.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab14` para aislar la configuración y las aplicaciones de esta práctica respecto al resto de los laboratorios.

  > **Advertencia:** Si `lab14` ya existe por una ejecución anterior, revisa su contenido antes de continuar para evitar reutilizar accidentalmente ConfigMaps antiguos.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab14
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab14 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Explorar la estructura de ConfigMap

Consultarás el esquema del recurso y generarás un ejemplo local para reconocer cómo Kubernetes representa claves y valores antes de crear configuración real en el clúster.

- {% include step_label.html %} Consulta la definición del recurso ConfigMap para identificar sus campos principales y confirmar que pertenece a la API core `v1`.

  > **Nota:** ConfigMap almacena datos de configuración no confidenciales que pueden ser consumidos por Pods sin incorporarlos directamente en una imagen de contenedor.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain configmap
  ```

  > **Salida esperada:** kubectl muestra `KIND: ConfigMap`, `VERSION: v1` y los campos principales del recurso.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta específicamente los campos `data` y `binaryData` para distinguir configuración textual de contenido representado como datos binarios.

  > **Importante:** En esta práctica trabajarás con `data`, donde claves y valores se almacenan como texto; `binaryData` existe para contenido que no se representa adecuadamente como cadenas UTF-8.
  {: .lab-note .important .compact}

  ```bash
  kubectl explain configmap.data
  ```
  ```bash
  kubectl explain configmap.binaryData
  ```

  > **Salida esperada:** kubectl describe ambos campos y muestra que `data` contiene pares clave-valor de tipo string.
  {: .lab-note .output .compact}

- {% include step_label.html %} Genera localmente un ConfigMap de ejemplo mediante `--dry-run=client` para observar cómo un literal se transforma en YAML sin crear todavía el recurso.

  > **Nota:** La generación declarativa permite obtener rápidamente una estructura válida que después puede guardarse, revisarse o reutilizarse.
  {: .lab-note .info .compact}

  ```bash
  kubectl create configmap demo-config -n lab14 --from-literal=APP_ENV=development --dry-run=client -o yaml
  ```

  > **Salida esperada:** La salida YAML contiene `kind: ConfigMap`, `metadata.name: demo-config` y `data.APP_ENV: development`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## ⚙️ Tarea 2. Crear y consumir ConfigMaps — 11 min

Crearás configuración mediante literales y archivos y después la consumirás desde un Deployment utilizando referencias individuales y `envFrom`. Esta sección muestra cómo separar valores de configuración del manifiesto principal de una aplicación.

### Tarea 2.1. Crear ConfigMaps desde literales y archivos

Construirás dos ConfigMaps utilizando fuentes diferentes para comprobar que Kubernetes puede almacenar tanto pares clave-valor simples como contenido proveniente de archivos existentes.

- {% include step_label.html %} Crea `app-config` con los valores `APP_ENV=development` y `LOG_LEVEL=info` utilizando literales proporcionados directamente desde kubectl.

  > **Nota:** `--from-literal` resulta útil para valores pequeños y puntuales que no necesitan mantenerse previamente dentro de un archivo.
  {: .lab-note .info .compact}

  ```bash
  kubectl create configmap app-config -n lab14 --from-literal=APP_ENV=development --from-literal=LOG_LEVEL=info
  ```

  > **Salida esperada:** Kubernetes responde `configmap/app-config created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el archivo local `app.properties` con una configuración sencilla que posteriormente se almacenará completa dentro de otro ConfigMap.

  > **Importante:** Cuando se utiliza `--from-file`, el nombre del archivo puede convertirse en la clave del ConfigMap y su contenido completo se almacena como valor.
  {: .lab-note .important .compact}

  ```bash
  cat > app.properties <<'EOF'
  feature.enabled=true
  timeout.seconds=30
  message=Configuracion desde archivo
  EOF
  ```

  > **Salida esperada:** Se crea `app.properties` con tres propiedades de configuración.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `file-config` utilizando `app.properties` como fuente para almacenar el archivo dentro del ConfigMap.

  > **Nota:** Este patrón resulta útil cuando una aplicación espera consumir archivos completos en lugar de variables individuales.
  {: .lab-note .info .compact}

  ```bash
  kubectl create configmap file-config -n lab14 --from-file=app.properties
  ```

  > **Salida esperada:** Kubernetes responde `configmap/file-config created`.
  {: .lab-note .output .compact}

### Tarea 2.2. Consumir configuración como variables de entorno

Crearás un Deployment que obtenga una clave mediante `configMapKeyRef` y posteriormente agregarás todas las claves del ConfigMap mediante `envFrom`, comprobando los valores dentro del contenedor.

- {% include step_label.html %} Crea `env-app.yaml` con un Deployment que obtenga `APP_ENV` mediante una referencia individual a la clave correspondiente de `app-config`.

  > **Nota:** `configMapKeyRef` permite mapear una clave concreta del ConfigMap hacia una variable con el nombre que defina el contenedor.
  {: .lab-note .info .compact}

  ```bash
  cat > env-app.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: env-app
    namespace: lab14
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: env-app
    template:
      metadata:
        labels:
          app: env-app
      spec:
        containers:
          - name: app
            image: busybox:1.38.0-musl
            command:
              - sh
              - -c
              - 'while true; do sleep 3600; done'
            env:
              - name: APPLICATION_ENV
                valueFrom:
                  configMapKeyRef:
                    name: app-config
                    key: APP_ENV
            envFrom:
              - configMapRef:
                  name: app-config
  EOF
  ```

  > **Salida esperada:** Se crea `env-app.yaml` con una referencia individual `configMapKeyRef` y una referencia completa mediante `envFrom`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el Deployment para iniciar un Pod que reciba la configuración desde `app-config` al momento de crear su contenedor.

  > **Importante:** El ConfigMap debe existir antes de que el Pod intente utilizar una referencia obligatoria; si falta, el contenedor no podrá iniciar correctamente.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f env-app.yaml
  ```

  > **Salida esperada:** Kubernetes responde `deployment.apps/env-app created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta las variables dentro del contenedor para comprobar simultáneamente la referencia individual y las claves importadas mediante `envFrom`.

  > **Nota:** `APPLICATION_ENV` proviene de `configMapKeyRef`, mientras `APP_ENV` y `LOG_LEVEL` conservan directamente los nombres de las claves importadas mediante `envFrom`.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec deployment/env-app -n lab14 -- sh -c 'echo "APPLICATION_ENV=$APPLICATION_ENV"; echo "APP_ENV=$APP_ENV"; echo "LOG_LEVEL=$LOG_LEVEL"'
  ```

  > **Salida esperada:** Se muestran `APPLICATION_ENV=development`, `APP_ENV=development` y `LOG_LEVEL=info`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🎯 Tarea 3. Reto: configurar una aplicación mediante variables — 9 min

A partir de esta tarea comienza la parte no guiada. Deberás construir una nueva configuración y conectarla con una aplicación sin escribir directamente los valores dentro de la especificación del contenedor.

### Tarea 3.1. Crear la configuración del API

Interpretarás los requisitos, decidirás cómo crear el ConfigMap y modificarás la aplicación para que toda su configuración sea obtenida de forma externa.

- {% include step_label.html %} Analiza el escenario y determina qué objetos y referencias necesitas para proporcionar configuración externa a la aplicación `api`.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Puedes utilizar `kubectl --help`, `kubectl explain` y generación mediante `--dry-run=client`.
  {: .lab-note .important .compact}

  ```text
  Reto 1:

  ConfigMap:
  - Nombre: api-config
  - Namespace: lab14
  - APP_ENV=production
  - LOG_LEVEL=warning
  - FEATURE_X=true

  Deployment:
  - Nombre: api
  - Namespace: lab14
  - Réplicas: 2
  - Imagen: busybox:1.38.0-musl
  - El contenedor debe permanecer ejecutándose.
  - Las tres variables deben provenir de api-config.
  - No escribas directamente esos valores dentro del contenedor.
  ```

  > **Salida esperada:** Identificas que debes crear un ConfigMap y hacer que el Deployment consuma sus claves como variables de entorno.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta el ConfigMap `api-config` y el Deployment `api` cumpliendo todos los requisitos del escenario.

  > **Nota:** Puedes elegir entre referencias individuales o `envFrom` siempre que los valores provengan realmente del ConfigMap y el estado final cumpla el requerimiento.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora la solución.

  No continúes hasta considerar satisfechos:
  - api-config existente;
  - api con 2 réplicas;
  - Pods Ready;
  - variables obtenidas desde ConfigMap.
  ```

  > **Salida esperada:** Existen `configmap/api-config` y `deployment/api`, y el Deployment alcanza dos réplicas disponibles.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida los recursos creados y corrige cualquier discrepancia antes de revisar las variables dentro del contenedor.

  > **Advertencia:** La existencia del ConfigMap no demuestra que el Deployment lo esté consumiendo; verifica también el manifiesto activo si la validación posterior falla.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get configmap api-config -n lab14
  kubectl get deployment api -n lab14
  ```

  > **Salida esperada:** `api-config` existe y `api` muestra `2/2` réplicas disponibles.
  {: .lab-note .output .compact}

### Tarea 3.2. Validar y actualizar variables de entorno

Comprobarás los valores reales dentro del proceso, actualizarás el ConfigMap y deberás determinar por qué los contenedores existentes no adoptan automáticamente el nuevo valor.

- {% include step_label.html %} Consulta desde uno de los Pods del Deployment `api` las tres variables solicitadas para verificar que la aplicación realmente consume el ConfigMap.

  > **Nota:** Este paso valida el comportamiento efectivo del contenedor, no únicamente la presencia de claves dentro del objeto ConfigMap.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec deployment/api -n lab14 -- sh -c 'echo "APP_ENV=$APP_ENV"; echo "LOG_LEVEL=$LOG_LEVEL"; echo "FEATURE_X=$FEATURE_X"'
  ```

  > **Salida esperada:** Se muestran `APP_ENV=production`, `LOG_LEVEL=warning` y `FEATURE_X=true`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Actualiza por tu cuenta `LOG_LEVEL` de `warning` a `debug` dentro de `api-config` sin eliminar el ConfigMap ni reconstruir la imagen del contenedor.

  > **Importante:** Después de actualizar el ConfigMap, los procesos ya iniciados no reciben automáticamente nuevos valores de variables de entorno. Debes identificar qué acción sobre el workload hace que nuevos contenedores vuelvan a leer la configuración.
  {: .lab-note .important .compact}

  ```text
  Cambio solicitado:

  api-config:
  LOG_LEVEL=debug

  Restricciones:
  - No elimines api-config.
  - No cambies la imagen.
  - No escribas LOG_LEVEL directamente en el Deployment.
  - El resultado final debe mostrar LOG_LEVEL=debug dentro de los Pods.
  ```

  > **Salida esperada:** El ConfigMap contiene `LOG_LEVEL=debug` y determinas cómo hacer que la aplicación adopte el nuevo valor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el valor final dentro del Deployment después de aplicar por tu cuenta la acción necesaria para que los nuevos contenedores vuelvan a leer la configuración.

  > **Advertencia:** Si todavía aparece `warning`, revisa si estás consultando un Pod anterior o si el workload aún no ha recreado sus contenedores.
  {: .lab-note .warning .compact}

  ```bash
  kubectl exec deployment/api -n lab14 -- sh -c 'echo "LOG_LEVEL=$LOG_LEVEL"'
  ```

  > **Salida esperada:** El contenedor consultado muestra `LOG_LEVEL=debug`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 📄 Tarea 4. Reto: montar y actualizar configuración como archivo — 11 min

Resolverás un escenario donde la aplicación necesita un archivo completo en una ruta específica. Después actualizarás el ConfigMap y observarás cómo una proyección montada como volumen puede reflejar cambios sin reconstruir la imagen del contenedor.

### Tarea 4.1. Montar un ConfigMap como volumen

Crearás la configuración y el Deployment sin comandos de implementación proporcionados, seleccionando el mecanismo correcto para presentar una clave del ConfigMap como archivo dentro del contenedor.

- {% include step_label.html %} Analiza el escenario y determina cómo representar `config.properties` dentro de un ConfigMap y cómo proyectarlo en la ruta solicitada por la aplicación.

  > **Importante:** El contenido del archivo no debe escribirse dentro de la imagen ni mediante un comando de inicio; debe proceder directamente de un ConfigMap montado como volumen.
  {: .lab-note .important .compact}

  ```text
  Reto 2:

  ConfigMap:
  - Nombre: reader-config
  - Debe contener una clave llamada config.properties.
  - Contenido inicial:
      mode=standard
      retries=3

  Deployment:
  - Nombre: config-reader
  - Namespace: lab14
  - Réplicas: 1
  - Imagen: busybox:1.38.0-musl
  - El contenedor debe permanecer ejecutándose.
  - El archivo debe estar disponible como:
      /etc/app/config.properties
  ```

  > **Salida esperada:** Identificas que necesitas un volumen ConfigMap y un volumeMount que presente la clave como archivo dentro del contenedor.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta `reader-config` y `config-reader` cumpliendo la ruta y el contenido solicitados.

  > **Nota:** Puedes construir el ConfigMap desde un archivo local o mediante YAML; el método de creación forma parte de tu estrategia de resolución.
  {: .lab-note .info .compact}

  ```text
  Implementa ahora la solución.

  No continúes hasta considerar satisfechos:
  - ConfigMap reader-config;
  - Deployment config-reader;
  - Pod Ready;
  - archivo montado en /etc/app/config.properties.
  ```

  > **Salida esperada:** Existe `reader-config`, el Deployment está disponible y el archivo se encuentra proyectado en la ruta indicada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Lee el archivo desde el contenedor para confirmar que su contenido procede del ConfigMap y que fue montado exactamente en la ruta requerida.

  > **Advertencia:** Si el archivo no existe, revisa por tu cuenta la relación entre `volumes`, `volumeMounts`, nombre del ConfigMap y ruta de montaje.
  {: .lab-note .warning .compact}

  ```bash
  kubectl exec deployment/config-reader -n lab14 -- cat /etc/app/config.properties
  ```

  > **Salida esperada:** Se muestran `mode=standard` y `retries=3`.
  {: .lab-note .output .compact}

### Tarea 4.2. Actualizar la configuración proyectada

Modificarás el ConfigMap sin recrear inicialmente el Pod y comprobarás que los volúmenes ConfigMap tienen un comportamiento diferente al de las variables de entorno leídas al arranque.

- {% include step_label.html %} Actualiza por tu cuenta el contenido de `reader-config` para cambiar `mode=standard` por `mode=maintenance`, manteniendo el resto de la configuración.

  > **Nota:** A diferencia de las variables de entorno, una proyección ConfigMap montada como volumen puede actualizarse posteriormente en el filesystem del contenedor; el cambio puede tardar y no debe considerarse instantáneo.
  {: .lab-note .info .compact}

  ```text
  Cambio solicitado:

  config.properties debe quedar:
  mode=maintenance
  retries=3

  No elimines inicialmente el Pod config-reader.
  ```

  > **Salida esperada:** El ConfigMap almacena la nueva versión de `config.properties` con `mode=maintenance`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta periódicamente el archivo montado hasta observar la nueva configuración o hasta determinar que todavía se encuentra en proceso de actualización.

  > **Importante:** Kubernetes actualiza las proyecciones de ConfigMap de forma eventual. La aplicación también debe volver a leer el archivo para aprovechar el cambio; montar el volumen no obliga a un proceso a recargar su configuración interna.
  {: .lab-note .important .compact}

  ```bash
  kubectl exec deployment/config-reader -n lab14 -- cat /etc/app/config.properties
  ```

  > **Salida esperada:** Después de la actualización eventual del volumen, el archivo muestra `mode=maintenance` y `retries=3`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Realiza la validación final de los dos retos comprobando que existen los ConfigMaps y Deployments requeridos antes de pasar a la limpieza.

  > **Advertencia:** No continúes con la Tarea 5 mientras necesites corregir variables, volúmenes, rutas o contenido. La limpieza eliminará todo el escenario activo.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get configmap,deployment,pods -n lab14
  ```

  > **Salida esperada:** Se muestran `app-config`, `file-config`, `api-config`, `reader-config`, `env-app`, `api` y `config-reader`, con los Deployments disponibles.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar el entorno de la práctica — 7 min

Esta tarea no forma parte de la evaluación 50/50. Debes ejecutarla únicamente después de terminar los retos, comprobar las variables de entorno, validar la configuración montada como archivo y confirmar que ya no necesitas conservar los recursos activos.

### Tarea 5.1. Revisar y retirar los recursos del laboratorio

Realizarás una última inspección, eliminarás el namespace completo y comprobarás que los recursos Kubernetes desaparecieron mientras los archivos locales permanecen disponibles para repaso.

- {% include step_label.html %} Revisa una última vez los recursos existentes en `lab14` antes de eliminarlos para identificar todo lo que será retirado durante la limpieza.

  > **Nota:** Esta comprobación final permite relacionar los ConfigMaps creados con los Deployments y Pods que los consumieron antes de destruir el escenario.
  {: .lab-note .info .compact}

  ```bash
  kubectl get configmap,deployment,pods -n lab14
  ```

  > **Salida esperada:** Se muestran los ConfigMaps y workloads utilizados durante las secciones guiadas y los retos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Cuando hayas terminado completamente la práctica, elimina el namespace `lab14` para retirar todos los ConfigMaps y workloads creados durante el laboratorio.

  > **Advertencia:** No ejecutes este paso antes de terminar las validaciones. Eliminar el namespace destruye todos los recursos namespaced de la práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab14 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab14" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el namespace `lab14` ya no existe para confirmar que la limpieza de recursos Kubernetes terminó correctamente.

  > **Importante:** La ausencia de salida indica que `--ignore-not-found` no encontró el namespace, que es precisamente el resultado esperado después de eliminarlo.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab14 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab14`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que los archivos locales creados durante la práctica permanecen disponibles dentro del workspace para revisión posterior.

  > **Nota:** La limpieza del clúster no debe eliminar `workspace/lab14`; los manifiestos y archivos son parte del material de estudio local.
  {: .lab-note .info .compact}

  ```bash
  ls -la
  ```

  > **Salida esperada:** El directorio continúa mostrando archivos locales como `app.properties` y `env-app.yaml`, además de cualquier manifiesto creado durante los retos.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}