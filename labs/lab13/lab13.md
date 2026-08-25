---
layout: lab
title: "Práctica 13: Despliegue con Helm"
permalink: /lab13/lab13/
images_base: /labs/lab13/img
duration: "45 minutos"
objective:
  - Crear un chart Helm mínimo y reutilizable, renderizar sus templates, instalar una release en Kubernetes, personalizarla mediante values, ejecutar upgrades, consultar su historial de revisiones y recuperar una versión funcional mediante rollback.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Haber completado la Práctica 9 Rolling update y rollback.
  - Disponer de Helm instalado y accesible desde Git Bash.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica utilizarás Helm como capa de empaquetado y administración sobre recursos Kubernetes. Construirás de forma guiada un chart mínimo compuesto por metadata, valores y templates para un Deployment y un Service, lo renderizarás antes de instalarlo y crearás una release funcional. En la segunda mitad resolverás retos de personalización, upgrade, diagnóstico e historial hasta recuperar una revisión estable mediante rollback, manteniendo separados los conceptos de chart, release y recursos Kubernetes.
slug: lab13
lab_number: 13
final_result: >
  Al finalizar habrás construido un chart Helm funcional, renderizado sus templates con valores configurables, instalado una release y comprobado los recursos Kubernetes generados. También habrás actualizado la release sin reinstalarla, consultado sus revisiones, provocado una actualización defectuosa, identificado una revisión funcional y ejecutado un rollback que queda registrado como una nueva revisión. Finalmente habrás desinstalado la release y limpiado el namespace únicamente después de completar todos los retos.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - El chart se construye manualmente para mantener una estructura mínima, controlada y reproducible independientemente de cambios en el scaffolding generado por helm create.
  - Se utiliza nginx:1.31.4-alpine3.24-slim como imagen inicial de la aplicación.
  - Un chart es el paquete de templates y valores; una release es una instancia instalada de ese chart dentro de Kubernetes.
  - Los primeros 12 pasos son guiados y los siguientes 12 pasos corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 50/50.
references:
  - text: Charts en Helm
    url: https://helm.sh/docs/topics/charts/
  - text: Templates y values en Helm
    url: https://helm.sh/docs/chart_template_guide/values_files/
  - text: Referencia de helm install
    url: https://helm.sh/docs/helm/helm_install/
  - text: Referencia de helm upgrade
    url: https://helm.sh/docs/helm/helm_upgrade/
  - text: Referencia de helm rollback
    url: https://helm.sh/docs/helm/helm_rollback/
prev: /lab12/lab12/
next: /lab14/lab14/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y comprender la estructura de Helm — 7 min

Prepararás el workspace y el namespace de la práctica, validarás que Helm está disponible y crearás la estructura mínima de un chart. El objetivo es diferenciar desde el inicio el paquete reutilizable denominado chart de la instancia instalada que Helm registra como release.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, comprobarás que kubectl apunta al clúster correcto y prepararás un namespace aislado donde posteriormente se instalará la release.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab13` y accede a él para mantener separados el chart y los archivos de valores utilizados en esta práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab13`; los archivos locales se conservarán después de limpiar la release y el namespace.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab13 && cd workspace/lab13
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab13`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo de kubectl para asegurarte de que la release se instalará exclusivamente en el clúster local del curso.

  > **Importante:** El contexto esperado es `kind-ckad`. Helm utiliza el mismo kubeconfig que kubectl, por lo que un contexto incorrecto también afectaría las operaciones de Helm.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab13` que contendrá la release y todos los recursos Kubernetes generados a partir del chart.

  > **Advertencia:** Si `lab13` ya existe por una ejecución anterior, revisa su contenido antes de continuar para evitar confundir releases o recursos antiguos con los resultados actuales.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab13
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab13 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Reconocer Helm y preparar el chart

Validarás el cliente Helm, distinguirás sus conceptos principales y crearás la estructura de directorios donde se almacenarán metadata, valores y templates.

- {% include step_label.html %} Consulta la versión de Helm disponible para confirmar que el cliente puede ejecutarse correctamente antes de construir o instalar charts.

  > **Nota:** La práctica utiliza comandos básicos de administración de charts y releases disponibles en las versiones actuales de Helm.
  {: .lab-note .info .compact}

  ```bash
  helm version
  ```

  > **Salida esperada:** Helm muestra información de versión sin errores de ejecución.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la ayuda general de Helm para reconocer las operaciones relacionadas con instalación, actualización, historial, rollback y desinstalación de releases.

  > **Importante:** Durante ejercicios prácticos, `helm --help` y la ayuda específica de cada subcomando permiten recuperar sintaxis sin depender únicamente de memoria.
  {: .lab-note .important .compact}

  ```bash
  helm --help
  ```

  > **Salida esperada:** La ayuda incluye comandos como `install`, `upgrade`, `history`, `rollback`, `status`, `template` y `uninstall`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea la estructura mínima del chart `web-chart`, separando templates de los archivos principales que Helm espera encontrar en la raíz del paquete.

  > **Nota:** `Chart.yaml` contendrá metadata, `values.yaml` almacenará valores predeterminados y `templates/` contendrá los manifiestos parametrizados que Helm renderizará.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p web-chart/templates
  ```

  > **Salida esperada:** Existe el directorio `web-chart/templates` preparado para recibir los archivos del chart.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 📦 Tarea 2. Construir e instalar una release — 11 min

Construirás de forma guiada un chart mínimo con valores reutilizables y dos templates Kubernetes. Después renderizarás el resultado localmente y lo instalarás como una release, comprobando que Helm transforma las plantillas en recursos reales dentro del namespace.

### Tarea 2.1. Construir metadata, values y templates

Crearás los cuatro archivos esenciales del ejemplo y utilizarás objetos predefinidos de Helm como `.Release.Name`, además de valores personalizados obtenidos desde `.Values`.

- {% include step_label.html %} Crea `Chart.yaml` con la metadata mínima requerida para identificar el chart y su versión de paquete.

  > **Nota:** `version` identifica la versión del chart, mientras `appVersion` puede documentar la versión de la aplicación empaquetada; no deben confundirse con la revisión de una release instalada.
  {: .lab-note .info .compact}

  ```bash
  cat > web-chart/Chart.yaml <<'EOF_CHART'
  apiVersion: v2
  name: web-chart
  description: Chart mínimo para la Práctica 13
  type: application
  version: 0.1.0
  appVersion: "1.31.4"
  EOF_CHART
  ```

  > **Salida esperada:** Se crea `web-chart/Chart.yaml` con nombre `web-chart` y versión `0.1.0`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `values.yaml` con los valores predeterminados que controlarán réplicas, imagen y propiedades del Service sin codificarlos directamente en los templates.

  > **Importante:** Los valores se concentran fuera de los manifiestos para permitir que una misma plantilla produzca configuraciones diferentes durante una instalación o un upgrade.
  {: .lab-note .important .compact}

  ```bash
  cat > web-chart/values.yaml <<'EOF_VALUES'
  replicaCount: 2

  image:
    repository: nginx
    tag: 1.31.4-alpine3.24-slim
    pullPolicy: IfNotPresent

  service:
    type: ClusterIP
    port: 80
  EOF_VALUES
  ```

  > **Salida esperada:** Se crea `web-chart/values.yaml` con dos réplicas, la imagen NGINX inicial y un Service ClusterIP en el puerto 80.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el template `deployment.yaml` utilizando el nombre de la release y los valores configurables para generar el Deployment de la aplicación.

  > **Nota:** `.Release.Name` cambia según la instancia instalada y `.Values` obtiene configuración desde los valores del chart o desde overrides proporcionados por el usuario.
  {: .lab-note .info .compact}

  {%raw%}
  ```bash
  cat > web-chart/templates/deployment.yaml <<'EOF_DEPLOY'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: {{ .Release.Name }}-web
    labels:
      app.kubernetes.io/name: {{ .Chart.Name }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  spec:
    replicas: {{ .Values.replicaCount }}
    selector:
      matchLabels:
        app.kubernetes.io/name: {{ .Chart.Name }}
        app.kubernetes.io/instance: {{ .Release.Name }}
    template:
      metadata:
        labels:
          app.kubernetes.io/name: {{ .Chart.Name }}
          app.kubernetes.io/instance: {{ .Release.Name }}
      spec:
        containers:
          - name: nginx
            image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
            imagePullPolicy: {{ .Values.image.pullPolicy }}
            ports:
              - containerPort: 80
  EOF_DEPLOY
  ```
  {%endraw%}

  > **Salida esperada:** Se crea un template de Deployment parametrizado mediante `.Release`, `.Chart` y `.Values`.
  {: .lab-note .output .compact}

### Tarea 2.2. Completar, renderizar e instalar el chart

Agregarás el template del Service, renderizarás la salida para inspeccionar el YAML resultante y finalmente instalarás el chart bajo una release con nombre estable.

- {% include step_label.html %} Crea el template `service.yaml` utilizando los mismos labels de la release para conectar el Service con los Pods generados por el Deployment.

  > **Importante:** El selector del Service utiliza los mismos valores de `name` e `instance` que la plantilla del Pod; esto evita que una release seleccione accidentalmente Pods pertenecientes a otra instalación del mismo chart.
  {: .lab-note .important .compact}

  {%raw%}
  ```bash
  cat > web-chart/templates/service.yaml <<'EOF_SERVICE'
  apiVersion: v1
  kind: Service
  metadata:
    name: {{ .Release.Name }}-web
    labels:
      app.kubernetes.io/name: {{ .Chart.Name }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  spec:
    type: {{ .Values.service.type }}
    selector:
      app.kubernetes.io/name: {{ .Chart.Name }}
      app.kubernetes.io/instance: {{ .Release.Name }}
    ports:
      - port: {{ .Values.service.port }}
        targetPort: 80
  EOF_SERVICE
  ```
  {%endraw%}

  > **Salida esperada:** Se crea un template de Service cuyo tipo y puerto provienen de `values.yaml`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Renderiza el chart localmente como si la release se llamara `web-release` para comprobar el YAML que Helm generaría antes de modificar el clúster.

  > **Nota:** `helm template` ejecuta el motor de templates y muestra los manifiestos resultantes sin instalar la release, lo que permite detectar errores de sintaxis o valores antes del despliegue.
  {: .lab-note .info .compact}

  ```bash
  helm template web-release ./web-chart --namespace lab13
  ```

  > **Salida esperada:** Helm genera un Service y un Deployment denominados `web-release-web`, con dos réplicas y sin errores de renderizado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Instala el chart bajo la release `web-release` dentro de `lab13`, convirtiendo los templates renderizados en recursos administrados por Helm.

  > **Importante:** El nombre `web-release` identifica la instancia instalada. Posteriores operaciones de upgrade, history, rollback y uninstall se realizarán sobre esta release.
  {: .lab-note .important .compact}

  ```bash
  helm install web-release ./web-chart -n lab13
  ```

  > **Salida esperada:** Helm muestra `NAME: web-release`, `NAMESPACE: lab13` y un estado de instalación satisfactorio.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🚀 Tarea 3. Reto: personalizar y actualizar la release — 9 min

A partir de esta tarea comienza la parte no guiada. Deberás modificar la configuración de una release existente sin eliminarla ni reinstalarla. Los pasos proporcionan requisitos y comandos de validación, pero la estrategia concreta de upgrade queda bajo tu responsabilidad.

### Tarea 3.1. Aplicar una nueva configuración mediante upgrade

Analizarás una solicitud de cambio, decidirás cómo proporcionar valores diferentes al chart y actualizarás la release conservando su nombre e historial.

- {% include step_label.html %} Analiza el requerimiento de actualización e identifica qué valores del chart deben cambiar sin editar los templates de Deployment o Service.

  > **Importante:** Desde este punto no se proporcionan comandos de implementación. Puedes utilizar `helm --help`, archivos adicionales de values o overrides de línea de comandos según consideres apropiado.
  {: .lab-note .important .compact}

  ```text
  Reto de upgrade:

  Actualiza la release web-release para cumplir:

  - Mantener el mismo chart.
  - Mantener el nombre web-release.
  - replicaCount: 3
  - service.type: ClusterIP
  - service.port: 8080
  - image.repository: nginx
  - image.tag: 1.31.4-alpine3.24
  - No desinstales la release.
  - No edites los templates para introducir estos valores.
  ```

  > **Salida esperada:** Identificas que la personalización debe suministrarse mediante valores y aplicarse como una actualización de la release existente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta la actualización y espera hasta considerar que la nueva configuración está desplegada correctamente.

  > **Nota:** Puedes crear un archivo de values específico para el upgrade o proporcionar overrides desde Helm; la elección forma parte del reto.
  {: .lab-note .info .compact}

  ```text
  Ejecuta ahora el upgrade.

  No continúes hasta considerar satisfechos:
  - 3 réplicas;
  - imagen solicitada;
  - Service ClusterIP;
  - puerto 8080;
  - misma release web-release.
  ```

  > **Salida esperada:** `web-release` permanece instalada y contiene una nueva configuración correspondiente al upgrade.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el estado de la release para comprobar que Helm continúa administrándola después de la actualización.

  > **Advertencia:** No des por correcto el reto únicamente porque existan Pods. Debes comprobar que la misma release permanece registrada y que corresponde al chart esperado.
  {: .lab-note .warning .compact}

  ```bash
  helm status web-release -n lab13
  ```

  > **Salida esperada:** Helm muestra `web-release` en `lab13` con estado `deployed`.
  {: .lab-note .output .compact}

### Tarea 3.2. Validar la nueva revisión

Examinarás el historial, los valores efectivos y los recursos Kubernetes para relacionar la operación de upgrade con una nueva revisión de la release.

- {% include step_label.html %} Consulta el historial de `web-release` para comprobar que la actualización quedó registrada como una revisión adicional.

  > **Nota:** Helm conserva revisiones de la release; la instalación inicial y el upgrade deben aparecer como entradas diferentes en el historial.
  {: .lab-note .info .compact}

  ```bash
  helm history web-release -n lab13
  ```

  > **Salida esperada:** Se muestran al menos las revisiones `1` y `2`, con la revisión más reciente asociada al upgrade.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los valores proporcionados por el usuario a la release para comprobar qué overrides fueron aplicados sobre los valores predeterminados del chart.

  > **Importante:** `helm get values` ayuda a diferenciar los valores configurados durante la instalación o upgrade de los defaults almacenados en `values.yaml`.
  {: .lab-note .important .compact}

  ```bash
  helm get values web-release -n lab13
  ```

  > **Salida esperada:** La salida refleja los valores personalizados utilizados durante el upgrade, incluyendo las propiedades modificadas.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida en Kubernetes que el Deployment y el Service generados por Helm reflejan el estado solicitado en el reto.

  > **Advertencia:** Si réplicas, imagen o puerto no coinciden, corrige la release mediante Helm; no edites directamente los recursos Kubernetes administrados por la release.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get deployment,service -n lab13
  ```

  > **Salida esperada:** `web-release-web` existe como Deployment con tres réplicas disponibles y como Service con puerto `8080`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🛠️ Tarea 4. Reto: diagnosticar una revisión defectuosa y ejecutar rollback — 11 min

Provocarás deliberadamente una revisión con una imagen inexistente, utilizarás Helm y Kubernetes para analizar el estado y recuperarás una revisión funcional sin desinstalar la release. El reto termina comprobando que el rollback queda registrado como una nueva revisión.

### Tarea 4.1. Generar y diagnosticar una revisión defectuosa

Crearás por tu cuenta una actualización incorrecta y observarás la diferencia entre el historial que mantiene Helm y el estado real de los Pods administrados por Kubernetes.

- {% include step_label.html %} Analiza el incidente que debes reproducir y determina cómo crear una nueva revisión de la release sin eliminar su historial anterior.

  > **Importante:** La actualización defectuosa debe conservarse temporalmente para diagnóstico. No utilices una estrategia que elimine la release ni borre sus revisiones.
  {: .lab-note .important .compact}

  ```text
  Incidente a reproducir:

  Genera una nueva revisión de web-release con:
  - image.repository: nginx
  - image.tag: lab13-image-does-not-exist
  - Mantén los demás valores funcionales actuales.
  - No desinstales web-release.
  - No uses una operación que borre automáticamente la revisión fallida.
  ```

  > **Salida esperada:** Identificas cómo realizar una actualización que conserve la release y produzca una revisión adicional con la imagen inválida.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta la actualización defectuosa y permite que Kubernetes intente crear Pods con la imagen inexistente.

  > **Advertencia:** El error es deliberado. No corrijas todavía el tag y no elimines los Pods manualmente; necesitas conservar el estado para diagnosticarlo.
  {: .lab-note .warning .compact}

  ```text
  Ejecuta ahora la actualización defectuosa.

  Conserva la release y observa el workload antes
  de intentar cualquier recuperación.
  ```

  > **Salida esperada:** La release registra una nueva revisión y Kubernetes intenta desplegar Pods utilizando la imagen inválida.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inspecciona los Pods administrados por la release para confirmar que la revisión defectuosa no logra completar correctamente el despliegue.

  > **Nota:** Un upgrade puede quedar registrado por Helm aunque el workload presente posteriormente errores de ejecución; por eso es necesario validar también el estado de Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab13
  ```

  > **Salida esperada:** Al menos un Pod de `web-release-web` muestra un estado relacionado con error de descarga de imagen, como `ErrImagePull` o `ImagePullBackOff`.
  {: .lab-note .output .compact}

### Tarea 4.2. Recuperar la última revisión funcional

Utilizarás el historial para seleccionar una revisión estable, ejecutarás la recuperación sin comandos proporcionados y comprobarás que Helm registra el rollback como una nueva revisión en lugar de borrar la historia anterior.

- {% include step_label.html %} Consulta el historial y determina qué revisión anterior corresponde al último estado funcional que cumplía los requisitos del upgrade.

  > **Importante:** No asumas que la revisión inmediatamente anterior es correcta sin revisar el historial y recordar qué configuración fue validada en la Tarea 3.
  {: .lab-note .important .compact}

  ```bash
  helm history web-release -n lab13
  ```

  > **Salida esperada:** El historial muestra la instalación, el upgrade funcional y la revisión defectuosa, permitiéndote identificar qué revisión debes recuperar.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta por tu cuenta el rollback hacia la revisión funcional identificada y espera hasta considerar que los recursos volvieron a un estado estable.

  > **Nota:** La recuperación debe realizarse mediante Helm para mantener coherente el historial de la release; no corrijas directamente el Deployment con kubectl.
  {: .lab-note .info .compact}

  ```text
  Recupera ahora la última revisión funcional.

  Antes de continuar comprueba por tu cuenta:
  - release web-release existente;
  - 3 réplicas disponibles;
  - imagen funcional restaurada;
  - Service en puerto 8080.
  ```

  > **Salida esperada:** La release vuelve a producir un Deployment funcional y conserva el nombre `web-release`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta nuevamente el historial para validar que la operación de rollback quedó registrada como una revisión nueva.

  > **Importante:** Helm no convierte una revisión antigua en la revisión actual borrando las posteriores; el rollback genera una nueva entrada que reutiliza la configuración de la revisión seleccionada.
  {: .lab-note .important .compact}

  ```bash
  helm history web-release -n lab13
  ```

  > **Salida esperada:** Aparece una revisión adicional posterior a la defectuosa y su descripción indica una operación de rollback o recuperación.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar la release y el entorno — 7 min

Esta tarea no forma parte de la evaluación 50/50. Debes ejecutarla únicamente cuando hayas terminado completamente los retos, revisado el historial, comprobado el upgrade, diagnosticado la revisión defectuosa y validado el rollback.

### Tarea 5.1. Desinstalar la release y retirar el namespace

Separarás la eliminación administrada por Helm de la eliminación del namespace para comprobar claramente qué recursos pertenecían a la release y confirmar después que el entorno Kubernetes quedó limpio.

- {% include step_label.html %} Cuando hayas terminado todas las validaciones del reto, desinstala `web-release` para que Helm retire los recursos Kubernetes administrados por esa release.

  > **Advertencia:** No ejecutes este paso mientras todavía necesites revisar `helm history`, `helm status` o los recursos desplegados. La desinstalación elimina la release del entorno activo.
  {: .lab-note .warning .compact}

  ```bash
  helm uninstall web-release -n lab13
  ```

  > **Salida esperada:** Helm confirma que `release "web-release" uninstalled`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta las releases del namespace para confirmar que `web-release` ya no aparece como una instalación activa.

  > **Nota:** Esta validación distingue la desinstalación de Helm de la limpieza posterior del namespace.
  {: .lab-note .info .compact}

  ```bash
  helm list -n lab13
  ```

  > **Salida esperada:** La lista no contiene ninguna release denominada `web-release`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab13` después de comprobar que la release fue desinstalada correctamente.

  > **Advertencia:** Esta operación elimina cualquier recurso namespaced residual que pudiera permanecer fuera de la administración de la release.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete namespace lab13 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab13" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que `lab13` ya no existe para confirmar la limpieza final del clúster antes de continuar con la siguiente práctica.

  > **Importante:** Conserva `workspace/lab13`, el directorio `web-chart` y cualquier archivo de values creado durante los retos; únicamente deben eliminarse los recursos activos.
  {: .lab-note .important .compact}

  ```bash
  kubectl get namespace lab13 --ignore-not-found
  ```

  > **Salida esperada:** El comando no muestra ningún namespace denominado `lab13`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}