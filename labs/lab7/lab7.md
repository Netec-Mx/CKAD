---
layout: lab
title: "Práctica 7: Personalización con Kustomize"
permalink: /lab7/lab7/
images_base: /labs/lab7/img
duration: "55 minutos"
objective:
  - Administrar variantes de configuración Kubernetes mediante Kustomize, construyendo una base reutilizable y overlays para diferentes ambientes, aplicando transformaciones sobre nombres, namespaces, labels, réplicas, imágenes y ConfigMaps sin duplicar manifiestos completos.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 3 Construcción y ejecución de una aplicación en Pod.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Tener kubectl instalado con soporte integrado para Kustomize.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica utilizarás Kustomize desde kubectl para administrar una aplicación Kubernetes sin duplicar manifiestos entre ambientes. Construirás una base con Deployment y Service, generarás configuración mediante configMapGenerator y crearás overlays independientes para desarrollo y producción. Validarás las transformaciones antes de aplicarlas al clúster y cerrarás con un reto parcialmente guiado en el que deberás construir una nueva personalización utilizando únicamente requisitos y criterios de validación.
slug: lab7
lab_number: 7
final_result: >
  Al finalizar habrás construido una estructura Kustomize compuesta por una base reutilizable y overlays para distintos ambientes, generado ConfigMaps, aplicado prefijos, namespaces, labels, réplicas e imágenes sin modificar los recursos originales y utilizado kubectl kustomize y kubectl apply -k para renderizar y desplegar configuraciones. Además, habrás resuelto un reto de consolidación sin recibir los comandos de implementación, validando por tu cuenta que el estado final cumple los requisitos indicados.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - La práctica utiliza la integración de Kustomize incluida en kubectl; no es necesario instalar el binario kustomize por separado.
  - Puedes consultar la versión de Kustomize integrada ejecutando kubectl version --client.
  - La estructura utilizada separa recursos base y overlays para evitar duplicar manifiestos completos entre ambientes.
  - La Tarea 5 representa el 20 por ciento de la práctica en formato reto; conserva los pasos visuales de Jekyll, pero no proporciona los comandos de implementación.
references:
  - text: Administración declarativa de objetos Kubernetes con Kustomize
    url: https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
  - text: Referencia oficial de kubectl kustomize
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_kustomize/
  - text: Proyecto oficial Kustomize
    url: https://github.com/kubernetes-sigs/kustomize
prev: /lab6/lab6/
next: /lab8/lab8/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar el workspace y reconocer Kustomize — 8 min

Prepararás la estructura local utilizada durante la práctica y comprobarás que la versión de kubectl instalada incorpora Kustomize. Después crearás los namespaces que permitirán desplegar las variantes de desarrollo y producción de forma aislada.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el workspace de Lab 7, validarás el contexto Kubernetes y comprobarás desde kubectl la versión de Kustomize disponible antes de generar cualquier personalización.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea la estructura inicial `workspace/lab7` y accede a ella; permanecerás en este directorio durante el resto de la práctica salvo que un comando cambie temporalmente de ruta.

  > **Nota:** Dentro de este workspace separarás una configuración `base` de los directorios `overlays/dev` y `overlays/prod`.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab7/{base,overlays/dev,overlays/prod} && cd workspace/lab7 && pwd
  ```

  > **Salida esperada:** La ruta termina en `/ckad-labs/workspace/lab7` y existen los directorios `base`, `overlays/dev` y `overlays/prod`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que kubectl continúa apuntando al clúster `kind-ckad` antes de desplegar recursos desde las personalizaciones.

  > **Importante:** Todos los recursos de esta práctica deben crearse en el clúster local `ckad`; no continúes si el contexto activo es diferente.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la versión del cliente kubectl y verifica que muestra también una versión integrada de Kustomize.

  > **Nota:** Kustomize forma parte de kubectl desde Kubernetes 1.14 y puede utilizarse mediante `kubectl kustomize` y `kubectl apply -k`.
  {: .lab-note .info .compact}

  ```bash
  kubectl version --client
  ```

  > **Salida esperada:** Se muestran `Client Version` y una línea `Kustomize Version` sin errores.
  {: .lab-note .output .compact}

### Tarea 1.2. Preparar los namespaces de los ambientes

Crearás namespaces separados para desarrollo y producción y comprobarás que ambos existen antes de comenzar a renderizar las personalizaciones.

- {% include step_label.html %} Crea los namespaces `lab7-dev` y `lab7-prod` para mantener aisladas las variantes que desplegarás posteriormente.

  > **Importante:** Los overlays cambiarán el namespace de los recursos, pero Kustomize no crea automáticamente un Namespace que no esté definido como recurso; por eso se preparan previamente.
  {: .lab-note .important .compact}

  ```bash
  kubectl create namespace lab7-dev
  ```
  ```bash
  kubectl create namespace lab7-prod
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab7-dev created` y `namespace/lab7-prod created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta ambos namespaces mediante un selector de nombre para comprobar que Kubernetes los registró correctamente.

  > **Nota:** Esta validación evita descubrir más adelante que un overlay apunta a un namespace inexistente.
  {: .lab-note .info .compact}

  ```bash
  kubectl get namespace lab7-dev lab7-prod
  ```

  > **Salida esperada:** Ambos namespaces aparecen con estado `Active`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la ayuda integrada de `kubectl kustomize` para identificar que el comando construye recursos desde un directorio que contiene `kustomization.yaml`.

  > **Nota:** Durante un examen práctico, `--help` permite recuperar rápidamente la sintaxis sin depender de memorizar cada opción.
  {: .lab-note .info .compact}

  ```bash
  kubectl kustomize --help | head -n 20
  ```

  > **Salida esperada:** Se muestra la descripción de `kubectl kustomize` y su sintaxis para construir recursos desde un directorio o URL.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🧱 Tarea 2. Construir una base reutilizable — 10 min

Crearás una configuración base formada por un Deployment, un Service y un ConfigMap generado por Kustomize. Esta base contendrá únicamente propiedades comunes y servirá como origen para las personalizaciones de desarrollo y producción.

### Tarea 2.1. Crear los recursos base de la aplicación

Definirás un Deployment y un Service sin incorporar todavía detalles específicos de ambiente, permitiendo que los overlays modifiquen posteriormente la configuración necesaria.

- {% include step_label.html %} Crea `base/deployment.yaml` con un Deployment denominado `web` de una réplica y una variable de entorno obtenida desde un ConfigMap.

  > **Nota:** La base representa el estado común de la aplicación. Evita agregar aquí nombres o configuraciones exclusivas de desarrollo o producción.
  {: .lab-note .info .compact}

  ```bash
  cat > base/deployment.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: web
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: web
    template:
      metadata:
        labels:
          app: web
      spec:
        containers:
          - name: web
            image: nginx:1.31.4-alpine3.24-slim
            imagePullPolicy: IfNotPresent
            ports:
              - containerPort: 80
            env:
              - name: APP_MODE
                valueFrom:
                  configMapKeyRef:
                    name: web-config
                    key: APP_MODE
  EOF
  ```

  > **Salida esperada:** Se crea `base/deployment.yaml` con el Deployment `web`, una réplica y referencia al ConfigMap `web-config`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `base/service.yaml` para exponer los Pods con label `app=web` mediante un Service de tipo ClusterIP.

  > **Importante:** El selector del Service debe coincidir con los labels del Pod template; de lo contrario el Service no tendrá endpoints válidos.
  {: .lab-note .important .compact}

  ```bash
  cat > base/service.yaml <<'EOF'
  apiVersion: v1
  kind: Service
  metadata:
    name: web
  spec:
    type: ClusterIP
    selector:
      app: web
    ports:
      - port: 80
        targetPort: 80
  EOF
  ```

  > **Salida esperada:** Se crea `base/service.yaml` con el Service `web` y selector `app: web`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa los recursos base antes de incorporarlos a Kustomize para confirmar nombres, labels, imagen y puertos.

  > **Advertencia:** Corrige cualquier inconsistencia de labels antes de continuar; los overlays heredan los recursos base y pueden propagar errores a todos los ambientes.
  {: .lab-note .warning .compact}

  ```bash
  grep -E 'kind:|name:|replicas:|image:|app:|port:|targetPort:' base/deployment.yaml base/service.yaml
  ```

  > **Salida esperada:** Se identifican un Deployment y un Service denominados `web`, el label `app: web`, la réplica inicial, la imagen NGINX y el puerto 80.
  {: .lab-note .output .compact}

### Tarea 2.2. Crear la kustomization base

Registrarás los manifiestos comunes y utilizarás `configMapGenerator` para producir configuración sin mantener manualmente un manifiesto ConfigMap independiente.

- {% include step_label.html %} Crea `base/kustomization.yaml` registrando Deployment y Service como recursos de la base.

  > **Nota:** `kustomization.yaml` describe cómo debe construirse la salida final; los archivos listados en `resources` continúan siendo manifiestos Kubernetes normales.
  {: .lab-note .info .compact}

  ```bash
  cat > base/kustomization.yaml <<'EOF'
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - deployment.yaml
    - service.yaml
  EOF
  ```

  > **Salida esperada:** Se crea `base/kustomization.yaml` con dos recursos declarados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega un `configMapGenerator` denominado `web-config` con el valor base `APP_MODE=base`.

  > **Importante:** Kustomize genera por defecto un sufijo hash para ConfigMaps y actualiza las referencias conocidas al nombre generado.
  {: .lab-note .important .compact}

  ```bash
  cat >> base/kustomization.yaml <<'EOF'
  configMapGenerator:
    - name: web-config
      literals:
        - APP_MODE=base
  EOF
  ```

  > **Salida esperada:** La kustomization contiene un generador denominado `web-config` con el literal `APP_MODE=base`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Renderiza la base sin aplicarla al clúster y revisa los tipos de objetos y nombres producidos por Kustomize.

  > **Nota:** `kubectl kustomize` genera YAML en la salida estándar, lo que permite inspeccionar el resultado antes de realizar cualquier cambio en Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  kubectl kustomize base | grep -E '^(kind:|  name: web|  name: web-config)'
  ```

  > **Salida esperada:** Se identifican un ConfigMap con sufijo hash, un Service `web` y un Deployment `web`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🧪 Tarea 3. Crear y desplegar el overlay de desarrollo — 10 min

Crearás un overlay de desarrollo que reutilice completamente la base y aplique transformaciones para namespace, prefijo, labels, réplicas y configuración. Después renderizarás el resultado y lo desplegarás mediante `kubectl apply -k`.

### Tarea 3.1. Definir la personalización de desarrollo

Construirás `overlays/dev/kustomization.yaml` referenciando la base y aplicando propiedades específicas del ambiente sin editar los archivos originales.

- {% include step_label.html %} Crea la kustomization de desarrollo referenciando `../../base`, asignando el namespace `lab7-dev` y el prefijo `dev-` a los nombres generados.

  > **Nota:** Un overlay reutiliza recursos existentes y expresa únicamente las diferencias necesarias para un ambiente concreto.
  {: .lab-note .info .compact}

  ```bash
  cat > overlays/dev/kustomization.yaml <<'EOF'
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - ../../base
  namespace: lab7-dev
  namePrefix: dev-
  EOF
  ```

  > **Salida esperada:** Se crea la kustomization de desarrollo con referencia a la base, namespace `lab7-dev` y prefijo `dev-`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega una transformación de labels para identificar todos los recursos de desarrollo mediante `environment=dev`.

  > **Importante:** La sintaxis moderna `labels` permite controlar la propagación de labels y evita depender del campo legado `commonLabels`.
  {: .lab-note .important .compact}

  ```bash
  cat >> overlays/dev/kustomization.yaml <<'EOF'
  labels:
    - pairs:
        environment: dev
      includeSelectors: true
  EOF
  ```

  > **Salida esperada:** El overlay contiene el label `environment: dev` y habilita su incorporación en selectores.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega una transformación de réplicas para ejecutar dos instancias del Deployment `web` en desarrollo.

  > **Nota:** La transformación `replicas` identifica el recurso por su nombre original en la base y modifica la cantidad sin editar `deployment.yaml`.
  {: .lab-note .info .compact}

  ```bash
  cat >> overlays/dev/kustomization.yaml <<'EOF'
  replicas:
    - name: web
      count: 2
  EOF
  ```

  > **Salida esperada:** `overlays/dev/kustomization.yaml` contiene `count: 2` para el recurso `web`.
  {: .lab-note .output .compact}

### Tarea 3.2. Renderizar y desplegar desarrollo

Inspeccionarás el YAML transformado, aplicarás directamente el directorio mediante `-k` y validarás que los nombres y réplicas coinciden con la configuración esperada.

- {% include step_label.html %} Renderiza el overlay de desarrollo y guarda temporalmente su salida para comprobar namespace, prefijo, labels y réplicas antes del despliegue.

  > **Importante:** Renderizar primero permite detectar transformaciones inesperadas antes de que la configuración llegue al API Server.
  {: .lab-note .important .compact}

  ```bash
  kubectl kustomize overlays/dev > dev-rendered.yaml
  ```
  ```bash
  grep -E 'namespace: lab7-dev|name: dev-|environment: dev|replicas: 2' dev-rendered.yaml
  ```

  > **Salida esperada:** La salida contiene recursos con prefijo `dev-`, namespace `lab7-dev`, label `environment: dev` y `replicas: 2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el overlay directamente mediante `kubectl apply -k` y espera hasta que el Deployment transformado se encuentre disponible.

  > **Nota:** `kubectl apply -k` construye la personalización y envía el resultado al API Server sin necesidad de aplicar el archivo renderizado manualmente.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -k overlays/dev
  ```
  ```bash
  kubectl rollout status deployment/dev-web -n lab7-dev --timeout=60s
  ```

  > **Salida esperada:** Kubernetes crea los recursos de desarrollo y el Deployment `dev-web` completa correctamente su rollout.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los recursos creados y comprueba que existen dos Pods asociados al Deployment de desarrollo.

  > **Advertencia:** Si el Service no encuentra endpoints, revisa primero los labels y selectores renderizados antes de modificar manualmente los objetos activos.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get deployment,pods,service,configmap -n lab7-dev -l environment=dev
  ```

  > **Salida esperada:** Se muestra `dev-web`, dos Pods Ready, el Service correspondiente y los recursos etiquetados con `environment=dev`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🚀 Tarea 4. Crear una variante de producción — 11 min

Construirás un segundo overlay reutilizando la misma base, pero con un namespace, prefijo, número de réplicas y tag de imagen diferentes. Compararás ambas salidas para comprobar que una única base puede producir estados finales distintos.

### Tarea 4.1. Definir las transformaciones de producción

Crearás la personalización de producción y utilizarás las transformaciones `labels`, `replicas` e `images` para modificar el resultado sin tocar los manifiestos base.

- {% include step_label.html %} Crea `overlays/prod/kustomization.yaml` referenciando la misma base y aplica el namespace `lab7-prod` junto con el prefijo `prod-`.

  > **Nota:** Desarrollo y producción comparten exactamente los mismos manifiestos base; las diferencias permanecen encapsuladas en cada overlay.
  {: .lab-note .info .compact}

  ```bash
  cat > overlays/prod/kustomization.yaml <<'EOF'
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - ../../base
  namespace: lab7-prod
  namePrefix: prod-
  labels:
    - pairs:
        environment: prod
      includeSelectors: true
  EOF
  ```

  > **Salida esperada:** Se crea el overlay de producción con namespace `lab7-prod`, prefijo `prod-` y label `environment=prod`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Configura producción con tres réplicas del Deployment `web` para diferenciar su capacidad respecto al ambiente de desarrollo.

  > **Importante:** El nombre utilizado en la transformación continúa siendo `web`, porque Kustomize aplica la transformación antes de producir el nombre final `prod-web`.
  {: .lab-note .important .compact}

  ```bash
  cat >> overlays/prod/kustomization.yaml <<'EOF'
  replicas:
    - name: web
      count: 3
  EOF
  ```

  > **Salida esperada:** El overlay de producción contiene `count: 3` para el Deployment `web`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega una transformación `images` para sustituir el tag de NGINX utilizado por la base sin modificar directamente `base/deployment.yaml`.

  > **Nota:** La transformación de imágenes permite que cada overlay controle versiones diferentes del mismo contenedor manteniendo una única definición base.
  {: .lab-note .info .compact}

  ```bash
  cat >> overlays/prod/kustomization.yaml <<'EOF'
  images:
    - name: nginx
      newTag: 1.31.4-alpine3.24-slim
  EOF
  ```

  > **Salida esperada:** El overlay contiene una transformación `images` para la imagen `nginx`.
  {: .lab-note .output .compact}

### Tarea 4.2. Comparar y desplegar producción

Renderizarás el overlay de producción, compararás sus propiedades principales contra desarrollo y finalmente desplegarás la variante en su namespace independiente.

- {% include step_label.html %} Renderiza la configuración de producción y comprueba que Kustomize genera nombres, namespace, labels y réplicas específicos del ambiente.

  > **Importante:** La salida renderizada debe revisarse antes del despliegue para confirmar que las transformaciones no afectan accidentalmente la base ni el overlay de desarrollo.
  {: .lab-note .important .compact}

  ```bash
  kubectl kustomize overlays/prod > prod-rendered.yaml
  ```
  ```bash
  grep -E 'namespace: lab7-prod|name: prod-|environment: prod|replicas: 3|image: nginx:' prod-rendered.yaml
  ```

  > **Salida esperada:** Se identifican recursos con prefijo `prod-`, namespace `lab7-prod`, label `environment=prod`, tres réplicas y la imagen NGINX configurada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Compara los valores principales renderizados para desarrollo y producción sin editar ninguno de los manifiestos base.

  > **Nota:** La comparación debe evidenciar que una misma base produce configuraciones finales diferentes mediante overlays independientes.
  {: .lab-note .info .compact}

  ```bash
  printf '%s\n' '--- DEV ---'
  grep -E 'namespace: lab7-dev|name: dev-web|replicas: 2|environment: dev' dev-rendered.yaml
  ```
  ```bash
  printf '%s\n' '--- PROD ---'
  grep -E 'namespace: lab7-prod|name: prod-web|replicas: 3|environment: prod' prod-rendered.yaml
  ```

  > **Salida esperada:** Las secciones DEV y PROD muestran diferencias de namespace, prefijo, label y número de réplicas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el overlay de producción y valida que el Deployment resultante alcance disponibilidad con tres réplicas.

  > **Advertencia:** Aplica el directorio `overlays/prod`; no apliques `prod-rendered.yaml` si quieres mantener durante la práctica el flujo operativo basado directamente en Kustomize.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply -k overlays/prod
  kubectl rollout status deployment/prod-web -n lab7-prod --timeout=60s
  ```
  ```bash
  kubectl get deployment,pods,service -n lab7-prod -l environment=prod
  ```

  > **Salida esperada:** `prod-web` completa el rollout y aparecen tres Pods Ready en `lab7-prod`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🎯 Tarea 5. Reto de consolidación con Kustomize — 16 min

Resolverás una personalización adicional sin recibir los comandos de implementación. Deberás reutilizar la base existente, elegir las transformaciones adecuadas, renderizar tu solución y corregirla hasta satisfacer todos los criterios indicados.

### Tarea 5.1. Construir el overlay del reto

Prepararás un nuevo ambiente denominado `qa`. Los pasos indican objetivos y criterios, pero la construcción de la solución queda bajo tu responsabilidad.

- {% include step_label.html %} Prepara el espacio de trabajo del reto y analiza la base existente antes de decidir qué elementos debe contener el nuevo overlay `qa`.

  > **Importante:** A partir de este punto no se proporcionan los comandos de implementación. Puedes utilizar `kubectl --help`, `kubectl explain`, `kubectl kustomize` y los archivos creados previamente como referencia.
  {: .lab-note .important .compact}

  ```bash
  mkdir -p overlays/qa
  ls -R base overlays
  ```

  > **Salida esperada:** Existe `overlays/qa` y puedes identificar la base y los overlays creados durante las tareas guiadas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Construye por tu cuenta `overlays/qa/kustomization.yaml` reutilizando la base y cumpliendo todos los requisitos funcionales del ambiente QA.

  > **Nota:** No copies un manifiesto Deployment o Service completo dentro del overlay. El objetivo del reto es demostrar que puedes reutilizar la base y expresar únicamente las diferencias.
  {: .lab-note .info .compact}

  ```text
  Requisitos del overlay QA:

  - Reutilizar ../../base.
  - Namespace final: lab7-qa.
  - Prefijo de nombres: qa-
  - Label: environment=qa.
  - El label debe propagarse a los selectores.
  - Deployment web con 2 réplicas.
  - No modificar ningún archivo dentro de base/.
  ```

  > **Salida esperada:** Existe `overlays/qa/kustomization.yaml` y contiene únicamente la personalización necesaria para satisfacer los requisitos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Renderiza tu overlay QA y corrige la solución hasta que el YAML generado cumpla todos los criterios indicados antes de intentar desplegarlo.

  > **Advertencia:** No evalúes tu solución únicamente porque `kubectl kustomize` no produzca errores; revisa también nombres, namespace, labels, selectores y réplicas.
  {: .lab-note .warning .compact}

  ```bash
  kubectl kustomize overlays/qa > qa-rendered.yaml
  grep -E 'namespace: lab7-qa|name: qa-|environment: qa|replicas: 2' qa-rendered.yaml
  ```

  > **Salida esperada:** La salida renderizada contiene namespace `lab7-qa`, nombres con prefijo `qa-`, label `environment=qa` y dos réplicas para el Deployment.
  {: .lab-note .output .compact}

### Tarea 5.2. Desplegar y validar el reto

Crearás el namespace requerido, desplegarás tu propia personalización y comprobarás el estado final. Si alguna validación falla, deberás localizar el problema dentro de tu overlay y corregirlo sin modificar la base.

- {% include step_label.html %} Prepara el namespace requerido y despliega el overlay QA utilizando el mecanismo de Kustomize que consideres apropiado.

  > **Importante:** El estado final debe proceder de `overlays/qa`; no crees manualmente Deployment, Service o ConfigMap con comandos independientes para evitar resolver el reto fuera de Kustomize.
  {: .lab-note .important .compact}

  ```text
  Estado requerido después del despliegue:

  - Namespace lab7-qa existente.
  - Deployment qa-web disponible.
  - 2 réplicas Ready.
  - Service qa-web existente.
  - ConfigMap generado por Kustomize.
  - Recursos identificados con environment=qa.
  ```

  > **Salida esperada:** El overlay QA se encuentra aplicado en el clúster y los recursos solicitados existen dentro de `lab7-qa`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta las comprobaciones de evaluación y corrige tu overlay si alguno de los criterios todavía no se cumple.

  > **Nota:** Este paso proporciona únicamente comandos de validación. La forma de corregir una condición fallida continúa siendo parte del reto.
  {: .lab-note .info .compact}

  ```bash
  kubectl get deployment qa-web -n lab7-qa
  kubectl get pods -n lab7-qa -l environment=qa
  kubectl get service qa-web -n lab7-qa
  kubectl get configmap -n lab7-qa
  kubectl get deployment qa-web -n lab7-qa -o jsonpath='Replicas={.spec.replicas}{"\n"}'
  ```

  > **Salida esperada:** `qa-web` existe con dos réplicas, sus Pods están Ready, el Service y ConfigMap existen y los recursos pueden localizarse mediante `environment=qa`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Conserva los archivos locales del reto y elimina los recursos desplegados por los tres ambientes para devolver el clúster a un estado limpio.

  > **Advertencia:** Elimina únicamente los namespaces utilizados en esta práctica. Los directorios `base` y `overlays` deben conservarse dentro de `workspace/lab7` para revisión posterior.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab7-dev lab7-prod lab7-qa --ignore-not-found --wait=true
  ```
  ```bash
  kubectl get namespace lab7-dev lab7-prod lab7-qa --ignore-not-found
  ```

  > **Salida esperada:** Los namespaces `lab7-dev`, `lab7-prod` y `lab7-qa` dejan de existir y los archivos Kustomize permanecen en el workspace local.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}