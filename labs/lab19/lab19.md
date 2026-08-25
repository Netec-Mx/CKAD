---
layout: lab
title: "Práctica 19: Consumo básico de CRD desde kubectl"
permalink: /lab19/lab19/
images_base: /labs/lab19/img
duration: "35 minutos"
objective:
  - Descubrir un CustomResourceDefinition instalado en Kubernetes, consultar el esquema publicado por el API Server, crear y modificar Custom Resources con kubectl y diferenciar el ciclo de vida de un CRD cluster-scoped de las instancias namespaced que define.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado prácticas previas de creación, consulta y modificación declarativa de recursos Kubernetes.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica trabajarás con un tipo de recurso que no forma parte de la API estándar de Kubernetes. La sección guiada instalará un CustomResourceDefinition didáctico denominado AppConfig. A partir de ese momento deberás descubrir su API group, versión, nombres, alcance y esquema mediante kubectl, crear instancias namespaced, consultar sus campos y actualizarlas sin recibir los comandos de implementación. El reto final simula llegar a un clúster donde el recurso existe pero no dispones de documentación externa.
slug: lab19
lab_number: 19
final_result: >
  Al finalizar habrás instalado un CRD proporcionado por el laboratorio, descubierto el nuevo recurso mediante la API de Kubernetes, consultado su esquema con kubectl explain, creado y modificado instancias AppConfig y reconstruido un Custom Resource únicamente a partir del descubrimiento del clúster. También habrás diferenciado que los AppConfig de esta práctica son namespaced mientras que el CustomResourceDefinition que define su tipo es cluster-scoped.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - La práctica utiliza apiextensions.k8s.io/v1 y un esquema OpenAPI v3 estructural para el CRD.
  - El CRD didáctico define el recurso AppConfig dentro del API group training.ckad.io y la versión v1.
  - AppConfig utiliza scope Namespaced, por lo que sus instancias pertenecen a namespaces. El objeto CustomResourceDefinition es cluster-scoped.
  - El objetivo es consumir y descubrir un CRD existente; no desarrollar un controller u operator.
  - Los primeros 6 pasos son guiados y los siguientes 14 corresponden al reto. Los 4 pasos finales de limpieza no forman parte de la proporción 30/70.
references:
  - text: Custom Resources
    url: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
  - text: Extend the Kubernetes API with CustomResourceDefinitions
    url: https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/
  - text: Referencia de CustomResourceDefinition v1
    url: https://kubernetes.io/docs/reference/kubernetes-api/extend-resources/custom-resource-definition-v1/
  - text: Referencia oficial de kubectl explain
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_explain/
  - text: Referencia oficial de kubectl api-resources
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_api-resources/
prev: /lab18/lab18/
next: /lab20/lab20/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar e instalar el CRD proporcionado — 8 min

Prepararás el workspace y el namespace del laboratorio y registrarás en el API Server un nuevo tipo de recurso denominado `AppConfig`. El CRD se entrega completamente definido porque el objetivo de la práctica es aprender a consumir recursos personalizados, no diseñar extensiones de API.

### Tarea 1.1. Preparar el entorno de trabajo

Crearás el directorio local, confirmarás el contexto activo y prepararás el namespace donde posteriormente existirán las instancias del recurso personalizado.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab19` y accede a él para almacenar el CRD y los Custom Resources creados durante la práctica.

  > **Nota:** A partir de este paso permanecerás en `ckad-labs/workspace/lab19`; los archivos locales se conservarán después de limpiar los recursos del clúster.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab19 && cd workspace/lab19
  ```

  > **Salida esperada:** La terminal queda ubicada dentro del directorio `ckad-labs/workspace/lab19`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el contexto activo para confirmar que el CRD se registrará únicamente en el clúster local utilizado por el curso.

  > **Importante:** El valor esperado es `kind-ckad`. Un CRD tiene alcance de clúster, por lo que debes evitar crearlo accidentalmente en otro entorno.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab19`, que será utilizado por las instancias namespaced de `AppConfig` durante los retos.

  > **Nota:** El namespace no contiene al CRD. Únicamente contendrá los Custom Resources porque el CRD se registra a nivel de clúster.
  {: .lab-note .info .compact}

  ```bash
  kubectl create namespace lab19
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab19 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Registrar AppConfig en la API de Kubernetes

Crearás el manifiesto proporcionado, lo aplicarás al clúster y esperarás hasta que Kubernetes confirme que el nuevo tipo de recurso quedó establecido.

- {% include step_label.html %} Crea `appconfig-crd.yaml` con el CRD proporcionado, que define el recurso `AppConfig`, su short name `acfg` y tres campos de configuración dentro de `spec`.

  > **Importante:** No necesitas memorizar este manifiesto. Observa que el nombre del CRD combina el plural y el API group, mientras el esquema describe los campos que posteriormente podrás descubrir con kubectl.
  {: .lab-note .important .compact}

  ```bash
  cat > appconfig-crd.yaml <<'EOF'
  apiVersion: apiextensions.k8s.io/v1
  kind: CustomResourceDefinition
  metadata:
    name: appconfigs.training.ckad.io
  spec:
    group: training.ckad.io
    scope: Namespaced
    names:
      plural: appconfigs
      singular: appconfig
      kind: AppConfig
      shortNames:
        - acfg
    versions:
      - name: v1
        served: true
        storage: true
        schema:
          openAPIV3Schema:
            type: object
            properties:
              spec:
                type: object
                required:
                  - replicas
                  - environment
                  - featureEnabled
                properties:
                  replicas:
                    type: integer
                    minimum: 1
                    maximum: 10
                  environment:
                    type: string
                    enum:
                      - development
                      - staging
                      - production
                  featureEnabled:
                    type: boolean
        additionalPrinterColumns:
          - name: Environment
            type: string
            jsonPath: .spec.environment
          - name: Replicas
            type: integer
            jsonPath: .spec.replicas
  EOF
  ```

  > **Salida esperada:** Se crea `appconfig-crd.yaml` con API group `training.ckad.io`, versión `v1`, scope `Namespaced` y kind `AppConfig`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el CRD para solicitar al API Server que registre el nuevo tipo de recurso personalizado.

  > **Advertencia:** Un CRD modifica los recursos disponibles para todo el clúster. En esta práctica se utiliza un API group didáctico específico para evitar colisiones con extensiones reales.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply -f appconfig-crd.yaml
  ```

  > **Salida esperada:** Kubernetes responde `customresourcedefinition.apiextensions.k8s.io/appconfigs.training.ckad.io created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que el CRD alcance la condición `Established` antes de intentar descubrir o crear instancias del nuevo recurso.

  > **Nota:** El API Server necesita registrar el nuevo endpoint de recurso. Esperar explícitamente evita comenzar los retos mientras el CRD todavía se está estableciendo.
  {: .lab-note .info .compact}

  ```bash
  kubectl wait --for=condition=Established crd/appconfigs.training.ckad.io --timeout=30s
  ```

  > **Salida esperada:** kubectl confirma `customresourcedefinition.apiextensions.k8s.io/appconfigs.training.ckad.io condition met`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🎯 Tarea 2. Reto: descubrir y crear un Custom Resource — 7 min

A partir de esta tarea comienza la parte no guiada. El CRD ya existe, pero deberás utilizar las capacidades de descubrimiento de Kubernetes para determinar cómo se llama el recurso, qué API utiliza y qué campos admite antes de crear su primera instancia.

### Tarea 2.1. Descubrir la API y el esquema de AppConfig

Utilizarás únicamente información disponible desde el clúster para reconstruir los datos necesarios del recurso personalizado.

- {% include step_label.html %} Descubre el recurso recién registrado y determina su nombre plural, API group, kind, short name y si su alcance es namespaced o cluster-scoped.

  > **Importante:** No consultes documentación externa ni abras todavía el manifiesto del CRD. El objetivo es obtener esta información desde los mecanismos de descubrimiento del API Server.
  {: .lab-note .important .compact}

  ```text
  Información que debes descubrir:

  - API group
  - versión
  - kind
  - plural
  - short name
  - scope
  ```

  > **Salida esperada:** Determinas que el recurso es `AppConfig`, pertenece a `training.ckad.io/v1`, utiliza plural `appconfigs`, short name `acfg` y tiene alcance namespaced.
  {: .lab-note .output .compact}

- {% include step_label.html %} Descubre el esquema de `spec` y determina los tres campos admitidos, sus tipos y las restricciones que Kubernetes aplicará al crear instancias.

  > **Nota:** El esquema OpenAPI publicado por el CRD puede ser consumido por `kubectl explain`; utiliza las herramientas del clúster para descubrir la estructura sin copiar el CRD.
  {: .lab-note .info .compact}

  ```text
  Debes identificar dentro de spec:

  - nombre de cada campo;
  - tipo;
  - valores o límites permitidos;
  - campos requeridos.
  ```

  > **Salida esperada:** Identificas `replicas` como integer entre 1 y 10, `environment` como string limitado a development, staging o production, y `featureEnabled` como boolean.
  {: .lab-note .output .compact}

### Tarea 2.2. Crear y consultar la primera instancia

Construirás un Custom Resource válido utilizando únicamente el esquema descubierto y después comprobarás que kubectl puede tratarlo como cualquier otro recurso de la API.

- {% include step_label.html %} Crea por tu cuenta una instancia `AppConfig` denominada `frontend` dentro de `lab19` utilizando exactamente los valores requeridos.

  > **Advertencia:** No modifiques el CRD para adaptar el reto. Tu instancia debe respetar el esquema que ya está registrado en el API Server.
  {: .lab-note .warning .compact}

  ```text
  Custom Resource requerido:

  Nombre: frontend
  Namespace: lab19

  spec:
  - replicas: 3
  - environment: production
  - featureEnabled: true
  ```

  > **Salida esperada:** Existe un `AppConfig` denominado `frontend` en el namespace `lab19` con los tres valores solicitados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta las instancias de AppConfig para verificar que Kubernetes reconoce `frontend` y utiliza las columnas adicionales definidas por el CRD.

  > **Nota:** Una vez registrado el CRD, kubectl puede consultar sus instancias mediante el nombre del recurso, igual que ocurre con recursos integrados como Pods o Deployments.
  {: .lab-note .info .compact}

  ```bash
  kubectl get appconfigs -n lab19
  ```

  > **Salida esperada:** Se muestra `frontend`, con `Environment` igual a `production` y `Replicas` igual a `3`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🧩 Tarea 3. Reto: inspeccionar y modificar Custom Resources — 8 min

Trabajarás sobre la instancia existente para extraer información concreta y modificar su estado deseado. Deberás elegir por tu cuenta entre las técnicas de consulta y actualización que ya conoces de kubectl.

### Tarea 3.1. Consultar información específica de frontend

Extraerás metadata y campos personalizados sin depender del archivo local utilizado para crear el recurso.

- {% include step_label.html %} Determina cómo consultar el objeto activo y extrae su `apiVersion`, `kind`, namespace y los tres valores almacenados dentro de `spec`.

  > **Importante:** La fuente de verdad para esta validación es el objeto almacenado en Kubernetes. Puedes elegir YAML, JSON o consultas estructuradas según consideres más eficiente.
  {: .lab-note .important .compact}

  ```text
  Obtén desde el clúster:

  - apiVersion
  - kind
  - namespace
  - spec.replicas
  - spec.environment
  - spec.featureEnabled
  ```

  > **Salida esperada:** Confirmas `training.ckad.io/v1`, `AppConfig`, namespace `lab19`, replicas `3`, environment `production` y featureEnabled `true`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el valor de `spec.environment` mediante una consulta directa para demostrar que los campos personalizados también pueden recuperarse con JSONPath.

  > **Nota:** Los Custom Resources conservan la misma estructura general `apiVersion`, `kind`, `metadata` y `spec`, por lo que las técnicas habituales de salida de kubectl siguen siendo aplicables.
  {: .lab-note .info .compact}

  ```bash
  kubectl get appconfig frontend -n lab19 -o jsonpath='{.spec.environment}{"\n"}'
  ```

  > **Salida esperada:** El comando devuelve `production`.
  {: .lab-note .output .compact}

### Tarea 3.2. Actualizar frontend

Modificarás varios campos del Custom Resource sin cambiar su identidad ni recrear el CRD.

- {% include step_label.html %} Analiza el nuevo estado requerido para `frontend` y determina qué campos de `spec` deben cambiar mientras nombre, namespace, API group y kind permanecen intactos.

  > **Nota:** Puedes decidir si utilizar edición, patch o un flujo declarativo. La técnica elegida debe producir exactamente el estado solicitado.
  {: .lab-note .info .compact}

  ```text
  Nuevo estado de frontend:

  replicas: 5
  environment: staging
  featureEnabled: false
  ```

  > **Salida esperada:** Identificas los tres campos de `spec` que deben actualizarse sin modificar la identidad del objeto.
  {: .lab-note .output .compact}

- {% include step_label.html %} Implementa por tu cuenta la actualización de `frontend` utilizando una técnica válida de kubectl y conserva el Custom Resource existente.

  > **Advertencia:** No elimines y vuelvas a crear el CRD. La operación debe actuar sobre la instancia `frontend`, no sobre la definición del tipo.
  {: .lab-note .warning .compact}

  ```text
  Actualiza ahora frontend.

  Estado requerido:
  - mismo nombre;
  - mismo namespace;
  - mismas API y kind;
  - replicas=5;
  - environment=staging;
  - featureEnabled=false.
  ```

  > **Salida esperada:** `frontend` permanece existente y contiene el nuevo estado solicitado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida mediante una consulta estructurada que los tres campos quedaron actualizados correctamente.

  > **Importante:** No continúes si alguno de los valores todavía corresponde al estado anterior.
  {: .lab-note .important .compact}

  ```bash
  kubectl get appconfig frontend -n lab19 -o jsonpath='Replicas={.spec.replicas} Environment={.spec.environment} FeatureEnabled={.spec.featureEnabled}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Replicas=5 Environment=staging FeatureEnabled=false`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🧭 Tarea 4. Reto: resolver mediante descubrimiento autónomo — 7 min

Simularás llegar a un clúster donde sabes que existe un tipo personalizado denominado AppConfig, pero no dispones de su manifiesto ni de documentación externa. Deberás reconstruir lo necesario desde el API Server y crear una segunda instancia.

### Tarea 4.1. Reconstruir la definición desde el clúster

Volverás a descubrir los datos esenciales del recurso, esta vez sin utilizar como referencia los archivos locales creados previamente.

- {% include step_label.html %} Determina nuevamente API group, versión, plural, short name y alcance utilizando únicamente información ofrecida por el clúster.

  > **Advertencia:** Para este reto no consultes `appconfig-crd.yaml` ni el manifiesto utilizado para crear `frontend`. El objetivo es practicar descubrimiento en un entorno desconocido.
  {: .lab-note .warning .compact}

  ```text
  Sin consultar archivos locales, recupera:

  - API group
  - versión
  - plural
  - short name
  - scope
  ```

  > **Salida esperada:** Reconstruyes correctamente los datos publicados para AppConfig desde la API de Kubernetes.
  {: .lab-note .output .compact}

- {% include step_label.html %} Reconstruye el esquema necesario para crear una instancia válida y confirma qué valores son aceptados para `environment`.

  > **Nota:** En un clúster real, esta capacidad permite trabajar con recursos instalados por operadores o plataformas aunque no conozcas previamente su estructura.
  {: .lab-note .info .compact}

  ```text
  Determina desde Kubernetes:

  - campos requeridos dentro de spec;
  - tipo de cada campo;
  - valores válidos de environment;
  - rango permitido para replicas.
  ```

  > **Salida esperada:** Obtienes nuevamente la estructura completa necesaria para crear un AppConfig válido.
  {: .lab-note .output .compact}

### Tarea 4.2. Crear backend únicamente desde descubrimiento

Aplicarás la información recuperada para crear una segunda instancia sin copiar el manifiesto de `frontend`.

- {% include step_label.html %} Crea por tu cuenta `backend` utilizando exclusivamente la información que acabas de descubrir desde Kubernetes.

  > **Importante:** No reutilices ni copies el manifiesto de `frontend`. Construye el nuevo recurso a partir de API discovery y schema discovery.
  {: .lab-note .important .compact}

  ```text
  Nuevo AppConfig:

  Nombre: backend
  Namespace: lab19

  spec:
  - replicas: 2
  - environment: development
  - featureEnabled: true
  ```

  > **Salida esperada:** Existe `AppConfig/backend` en `lab19` con los valores solicitados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta ambas instancias mediante el short name del recurso para demostrar que el alias publicado por el CRD también puede utilizarse desde kubectl.

  > **Nota:** Los short names son parte de la información publicada para el recurso y pueden reducir el tiempo necesario para consultas frecuentes.
  {: .lab-note .info .compact}

  ```bash
  kubectl get acfg -n lab19
  ```

  > **Salida esperada:** Se muestran `frontend` y `backend`; frontend presenta `staging` y `5`, mientras backend presenta `development` y `2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Realiza una validación final de los Custom Resources antes de la limpieza, comprobando sus tres campos de configuración en una sola consulta.

  > **Advertencia:** La siguiente tarea eliminará las instancias y posteriormente el CRD. Verifica ahora el estado final si necesitas conservar evidencia del reto.
  {: .lab-note .warning .compact}

  ```bash
  kubectl get appconfigs -n lab19 -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,ENVIRONMENT:.spec.environment,FEATURE:.spec.featureEnabled'
  ```

  > **Salida esperada:** `frontend` muestra `5`, `staging`, `false`; `backend` muestra `2`, `development`, `true`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🧹 Tarea 5. Limpiar Custom Resources y CRD — 5 min

Esta tarea no forma parte de la evaluación 30/70. Debes ejecutarla únicamente después de completar todos los retos y recordar que eliminar el namespace retira las instancias namespaced, pero no elimina el CRD cluster-scoped.

### Tarea 5.1. Retirar las instancias y la extensión de API

Revisarás el estado final, eliminarás las instancias mediante el namespace y retirarás explícitamente el CRD para devolver el clúster a su estado anterior.

- {% include step_label.html %} Revisa una última vez las instancias `AppConfig` antes de comenzar la limpieza para confirmar qué objetos namespaced serán eliminados.

  > **Nota:** `frontend` y `backend` pertenecen a `lab19`; el CRD `appconfigs.training.ckad.io` no pertenece a ese namespace.
  {: .lab-note .info .compact}

  ```bash
  kubectl get appconfigs -n lab19
  ```

  > **Salida esperada:** Se muestran las instancias `frontend` y `backend`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab19` para retirar las instancias namespaced del recurso personalizado.

  > **Importante:** Eliminar el namespace elimina los Custom Resources que contiene, pero el tipo `AppConfig` seguirá registrado porque su CRD tiene alcance de clúster.
  {: .lab-note .important .compact}

  ```bash
  kubectl delete namespace lab19 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab19" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el CRD `appconfigs.training.ckad.io` después de confirmar que ya no necesitas conservar el tipo personalizado en el clúster.

  > **Advertencia:** Eliminar un CRD elimina el endpoint de API y también provoca la eliminación de los Custom Resources almacenados para ese tipo. Hazlo únicamente al finalizar completamente la práctica.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete crd appconfigs.training.ckad.io
  ```

  > **Salida esperada:** Kubernetes responde `customresourcedefinition.apiextensions.k8s.io "appconfigs.training.ckad.io" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba por separado que ni el namespace ni el CRD continúan presentes y conserva los manifiestos locales para revisión posterior.

  > **Nota:** Las dos consultas deben quedar sin resultados para los objetos eliminados. Los archivos de `workspace/lab19` permanecen disponibles localmente.
  {: .lab-note .info .compact}

  ```bash
  kubectl get namespace lab19 --ignore-not-found
  kubectl get crd appconfigs.training.ckad.io --ignore-not-found
  ```

  > **Salida esperada:** Ninguno de los comandos muestra recursos; `lab19` y `appconfigs.training.ckad.io` ya no existen en el clúster.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}