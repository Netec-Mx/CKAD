---
layout: lab
title: "Práctica 32: Mini-proyecto integrador CKAD + Argo CD + Kafka + Crossplane"
permalink: /lab32/lab32/
images_base: /labs/lab32/img
duration: "35 minutos"
objective:
  - Integrar Kubernetes, Argo CD, Strimzi Kafka y Crossplane en un flujo GitOps completo donde Git define infraestructura cloud, mensajería y workloads, Argo CD sincroniza los recursos, Crossplane crea una VPC en AWS y una aplicación Kubernetes produce y consume eventos mediante Kafka.
prerequisites:
  - Haber completado la Práctica 29 Publicar una aplicación con Argo CD usando manifiestos Kubernetes.
  - Haber completado la Práctica 30 Consumir un recurso gestionado con Crossplane de forma básica.
  - Haber completado la Práctica 31 Desplegar Kafka básico y validar producer/consumer.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Mantener Argo CD instalado en el namespace argocd.
  - Mantener Crossplane y provider-aws-ec2 instalados y configurados.
  - Mantener Strimzi Cluster Operator instalado en el namespace kafka.
  - Disponer de credenciales AWS válidas y AWS CLI funcional.
  - Disponer de una cuenta GitHub autenticada.
introduction:
  - En este mini-proyecto construirás CKAD Order Platform mediante GitOps. Crearás un repositorio con dos capas declarativas. La capa infra contendrá una VPC administrada por Crossplane y un clúster Kafka administrado por Strimzi. La capa app contendrá un Deployment consumer con initContainer y un Job producer. Argo CD sincronizará ambas capas desde GitHub. Después comprobarás que los pedidos enviados por el Job llegan al consumer a través de Kafka, validarás la VPC real en AWS y publicarás un segundo Job desde Git para observar un nuevo ciclo OutOfSync y Sync.
slug: lab32
lab_number: 32
final_result: >
  Al finalizar habrás integrado GitHub, Argo CD, Kubernetes, Strimzi, Kafka, Crossplane y AWS en un único flujo declarativo. Argo CD habrá creado recursos personalizados de infraestructura y mensajería, Crossplane habrá reconciliado una VPC real en AWS, Strimzi habrá reconciliado Kafka y el Topic orders, y workloads Kubernetes habrán producido y consumido eventos. Finalmente habrás ejecutado un cambio GitOps adicional y eliminado de forma controlada los recursos administrados.
notes:
  - Esta práctica es 100% guiada.
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se reutilizan Argo CD v3.5.0, Crossplane v2.3.4, provider-aws-ec2 v2.7.1, Strimzi 1.1.0 y Kafka 4.3.0 instalados previamente.
  - La VPC utiliza el CIDR 10.32.0.0/16 en us-west-2 y debe eliminarse durante la limpieza.
  - El clúster Kafka utiliza un solo nodo KRaft con almacenamiento efímero; no representa una arquitectura de producción.
  - Argo CD utiliza dos Applications para separar infraestructura de aplicación.
  - El consumer utiliza un initContainer para esperar a que el bootstrap Service de Kafka esté disponible antes de iniciar el proceso principal.
  - El producer se implementa como Job para representar una carga finita de eventos.
  - El segundo cambio GitOps agrega un Job nuevo en lugar de modificar el Job existente, porque varios campos del Pod template de un Job son inmutables.
  - Nunca publiques credenciales AWS en GitHub.
references:
  - text: Argo CD Getting Started
    url: https://argo-cd.readthedocs.io/en/latest/getting_started/
  - text: Crossplane Managed Resources
    url: https://docs.crossplane.io/v2.3/managed-resources/managed-resources/
  - text: Upbound Provider AWS EC2
    url: https://marketplace.upbound.io/providers/upbound/provider-aws-ec2/latest
  - text: Strimzi Documentation
    url: https://strimzi.io/docs/operators/latest/
  - text: Kubernetes Jobs
    url: https://kubernetes.io/docs/concepts/workloads/controllers/job/
prev: /lab31/lab31/
next: /lab1/lab1/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta los comandos desde **Git Bash**. Los pasos que indiquen GitHub, Argo CD o AWS Management Console se realizan desde el navegador. No elimines infraestructura manualmente en AWS antes de la fase de limpieza porque Crossplane debe administrar su ciclo de vida.
{: .lab-note .info .compact}

## 🧭 Tarea 1. Preparar el proyecto integrador

Prepararás el entorno local, comprobarás que los tres operadores continúan disponibles y crearás el repositorio que funcionará como fuente de verdad.

### Tarea 1.1. Validar el entorno

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el workspace de la práctica y accede a él.

  > **Nota:** El repositorio GitHub del mini-proyecto se clonará dentro de este directorio.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab32 && cd workspace/lab32
  ```

  > **Salida esperada:** La terminal queda ubicada en `ckad-labs/workspace/lab32`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que kubectl continúa utilizando el clúster principal del curso.

  > **Importante:** El contexto esperado es `kind-ckad`.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba en una sola lectura que Argo CD, Crossplane y Strimzi siguen ejecutándose en sus namespaces.

  > **Importante:** Los tres componentes fueron instalados en prácticas anteriores y deben estar saludables antes de construir la integración.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n argocd
  ```
  ```bash
  kubectl get pods -n crossplane-system
  ```
  ```bash
  kubectl get pods -n kafka
  ```

  > **Salida esperada:** Los Pods principales de Argo CD, Crossplane y `strimzi-cluster-operator` aparecen Running y Ready.
  {: .lab-note .output .compact}

### Tarea 1.2. Crear el repositorio GitOps

- {% include step_label.html %} Crea en GitHub un repositorio público denominado `ckad-integrador-lab32` e inicialízalo con README.

  > **Nota:** El repositorio público permite que Argo CD lo lea sin configurar credenciales de repositorio adicionales.
  {: .lab-note .info .compact}

  ```text
  GitHub:
  1. Selecciona + → New repository.
  2. Repository name: ckad-integrador-lab32
  3. Visibility: Public
  4. Add a README file: activado
  ```

- {% include step_label.html %} Selecciona **Create repository**.

  > **Salida esperada:** GitHub abre `ckad-integrador-lab32` y muestra `README.md`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Clona el repositorio creado y entra al directorio local.

  > **Advertencia:** Sustituye `USUARIO` por tu nombre real de usuario de GitHub.
  {: .lab-note .warning .compact}

  ```bash
  git clone https://github.com/USUARIO/ckad-integrador-lab32.git
  ```
  ```bash
  cd ckad-integrador-lab32
  ```

  > **Salida esperada:** La terminal queda dentro del repositorio clonado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea los directorios `infra` y `app` para separar infraestructura de workloads.

  > **Importante:** Esta separación permitirá utilizar dos Applications de Argo CD con ciclos de sincronización independientes.
  {: .lab-note .important .compact}

  ```bash
  mkdir infra app
  ```

  > **Salida esperada:** Existen los directorios `infra/` y `app/`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## ☁️ Tarea 2. Definir infraestructura declarativa

Crearás los manifiestos que Argo CD entregará a Crossplane y Strimzi.

### Tarea 2.1. Definir la VPC administrada por Crossplane

- {% include step_label.html %} Crea el namespace `lab32-infra` donde residirá el Managed Resource de Crossplane.

  > **Nota:** El namespace se prepara fuera de Git para simplificar la eliminación ordenada de la VPC durante la limpieza.
  {: .lab-note .info .compact}

  ```bash
  kubectl create namespace lab32-infra
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab32-infra created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `infra/vpc.yaml` para declarar una VPC real en AWS mediante Crossplane.

  > **Importante:** El recurso referencia el `ClusterProviderConfig default` creado en la práctica anterior; el YAML no contiene credenciales.
  {: .lab-note .important .compact}

  ```bash
  cat > infra/vpc.yaml <<'EOF'
  apiVersion: ec2.aws.m.upbound.io/v1beta1
  kind: VPC
  metadata:
    name: ckad-integrador-lab32
    namespace: lab32-infra
  spec:
    forProvider:
      region: us-west-2
      cidrBlock: 10.32.0.0/16
      enableDnsSupport: true
      enableDnsHostnames: true
      tags:
        Name: ckad-integrador-lab32
        ManagedBy: Crossplane-ArgoCD
    providerConfigRef:
      name: default
      kind: ClusterProviderConfig
  EOF
  ```

  > **Salida esperada:** Se crea `infra/vpc.yaml` con CIDR `10.32.0.0/16`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el manifiesto de VPC sin crear todavía infraestructura AWS.

  > **Advertencia:** No ejecutes un apply real; Argo CD debe ser quien entregue este recurso a Kubernetes.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply --dry-run=client -f infra/vpc.yaml
  ```

  > **Salida esperada:** Kubernetes valida el recurso VPC en modo dry-run.
  {: .lab-note .output .compact}

### Tarea 2.2. Definir Kafka y el Topic

- {% include step_label.html %} Crea `infra/kafka-nodepool.yaml` con un nodo KRaft de doble rol.

  > **Advertencia:** El almacenamiento efímero se utiliza exclusivamente para este laboratorio.
  {: .lab-note .warning .compact}

  ```bash
  cat > infra/kafka-nodepool.yaml <<'EOF'
  apiVersion: kafka.strimzi.io/v1
  kind: KafkaNodePool
  metadata:
    name: lab32-dual-role
    namespace: kafka
    labels:
      strimzi.io/cluster: lab32-kafka
  spec:
    replicas: 1
    roles:
      - controller
      - broker
    storage:
      type: ephemeral
  EOF
  ```

  > **Salida esperada:** Se crea el KafkaNodePool para `lab32-kafka`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `infra/kafka.yaml` con Kafka 4.3.0 y listener interno plain.

  > **Importante:** Los factores de replicación se mantienen en `1` porque el clúster dispone de un único broker.
  {: .lab-note .important .compact}

  ```bash
  cat > infra/kafka.yaml <<'EOF'
  apiVersion: kafka.strimzi.io/v1
  kind: Kafka
  metadata:
    name: lab32-kafka
    namespace: kafka
  spec:
    kafka:
      version: 4.3.0
      metadataVersion: 4.3-IV0
      listeners:
        - name: plain
          port: 9092
          type: internal
          tls: false
      config:
        offsets.topic.replication.factor: 1
        transaction.state.log.replication.factor: 1
        transaction.state.log.min.isr: 1
        default.replication.factor: 1
        min.insync.replicas: 1
    entityOperator:
      topicOperator: {}
      userOperator: {}
  EOF
  ```

  > **Salida esperada:** Se crea `infra/kafka.yaml`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `infra/topic.yaml` para el Topic `orders` con tres particiones.

  > **Nota:** El Topic será el canal entre el Job producer y el Deployment consumer.
  {: .lab-note .info .compact}

  ```bash
  cat > infra/topic.yaml <<'EOF'
  apiVersion: kafka.strimzi.io/v1
  kind: KafkaTopic
  metadata:
    name: orders
    namespace: kafka
    labels:
      strimzi.io/cluster: lab32-kafka
  spec:
    partitions: 3
    replicas: 1
  EOF
  ```

  > **Salida esperada:** Se crea `infra/topic.yaml` con tres particiones y una réplica.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🧩 Tarea 3. Definir la aplicación producer/consumer

Construirás recursos Kubernetes que utilicen Kafka sin necesidad de crear imágenes propias.

### Tarea 3.1. Crear el consumer

- {% include step_label.html %} Crea `app/namespace.yaml` para declarar el namespace de aplicación mediante Git.

  > **Nota:** A diferencia del namespace de infraestructura, `lab32-app` sí formará parte de los recursos administrados por Argo CD.
  {: .lab-note .info .compact}

  ```bash
  cat > app/namespace.yaml <<'EOF'
  apiVersion: v1
  kind: Namespace
  metadata:
    name: lab32-app
  EOF
  ```

  > **Salida esperada:** Se crea `app/namespace.yaml`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `app/consumer.yaml` con un Deployment que espere a Kafka mediante initContainer.

  > **Importante:** El initContainer evita iniciar el consumer antes de que el bootstrap Service de Kafka acepte conexiones.
  {: .lab-note .important .compact}

  ```bash
  cat > app/consumer.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: orders-consumer
    namespace: lab32-app
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: orders-consumer
    template:
      metadata:
        labels:
          app: orders-consumer
      spec:
        initContainers:
          - name: wait-for-kafka
            image: busybox:1.38.0-musl
            command:
              - sh
              - -c
              - until nc -z lab32-kafka-kafka-bootstrap.kafka.svc.cluster.local 9092; do echo waiting-for-kafka; sleep 2; done
        containers:
          - name: consumer
            image: quay.io/strimzi/kafka:1.1.0-kafka-4.3.0
            command:
              - bin/kafka-console-consumer.sh
            args:
              - --bootstrap-server
              - lab32-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
              - --topic
              - orders
              - --group
              - lab32-workers
              - --from-beginning
  EOF
  ```

  > **Salida esperada:** Se crea un Deployment con initContainer y consumer group `lab32-workers`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el manifiesto del consumer mediante dry-run.

  > **Nota:** Esta comprobación detecta errores estructurales antes de publicar el repositorio.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply --dry-run=client -f app/consumer.yaml
  ```

  > **Salida esperada:** Kubernetes valida el Deployment sin crearlo.
  {: .lab-note .output .compact}

### Tarea 3.2. Crear el producer inicial

- {% include step_label.html %} Crea `app/producer-job.yaml` con un Job que publique cinco pedidos.

  > **Importante:** El Job representa una carga finita; al terminar queda en estado Complete y puede revisarse como evidencia.
  {: .lab-note .important .compact}

  ```bash
  cat > app/producer-job.yaml <<'EOF'
  apiVersion: batch/v1
  kind: Job
  metadata:
    name: orders-producer-v1
    namespace: lab32-app
  spec:
    template:
      spec:
        restartPolicy: Never
        containers:
          - name: producer
            image: quay.io/strimzi/kafka:1.1.0-kafka-4.3.0
            command:
              - /bin/bash
              - -c
            args:
              - |
                printf '%s\n' \
                  'order-2001,product=laptop,quantity=1' \
                  'order-2002,product=monitor,quantity=2' \
                  'order-2003,product=keyboard,quantity=1' \
                  'order-2004,product=mouse,quantity=3' \
                  'order-2005,product=headset,quantity=1' |
                bin/kafka-console-producer.sh \
                  --bootstrap-server lab32-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092 \
                  --topic orders
    backoffLimit: 3
  EOF
  ```

  > **Salida esperada:** Se crea `app/producer-job.yaml` con cinco eventos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el Job en modo dry-run.

  > **Nota:** Todavía no debe existir ningún Job `orders-producer-v1` dentro del clúster.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply --dry-run=client -f app/producer-job.yaml
  ```

  > **Salida esperada:** Kubernetes valida el Job sin ejecutarlo.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa la estructura completa del proyecto antes de versionarlo.

  > **Importante:** Debes disponer de cuatro archivos en `infra` y tres en `app`.
  {: .lab-note .important .compact}

  ```bash
  find infra app -maxdepth 1 -type f -print
  ```

  > **Salida esperada:** Se muestran los manifiestos de VPC, KafkaNodePool, Kafka, Topic, Namespace, consumer y producer.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🌿 Tarea 4. Publicar el proyecto en GitHub

Versionarás la definición completa para convertir GitHub en la fuente declarativa utilizada por Argo CD.

### Tarea 4.1. Preparar staging

- {% include step_label.html %} Revisa los archivos nuevos con `git status`.

  > **Nota:** Los directorios `infra` y `app` deben aparecer como contenido todavía no versionado.
  {: .lab-note .info .compact}

  ```bash
  git status
  ```

  > **Salida esperada:** Git muestra los manifiestos como cambios no rastreados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega únicamente los directorios declarativos al staging area.

  > **Importante:** No agregues archivos de credenciales AWS ni contenido de `$HOME/.aws`.
  {: .lab-note .important .compact}

  ```bash
  git add infra app
  ```

  > **Salida esperada:** El comando finaliza sin errores.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el staging antes de crear el commit.

  > **Nota:** Esta revisión evita publicar archivos no deseados.
  {: .lab-note .info .compact}

  ```bash
  git status
  ```

  > **Salida esperada:** Los siete manifiestos aparecen bajo `Changes to be committed`.
  {: .lab-note .output .compact}

### Tarea 4.2. Publicar el estado deseado

- {% include step_label.html %} Crea el commit inicial del mini-proyecto.

  > **Importante:** Este commit representa el estado deseado inicial de infraestructura y aplicación.
  {: .lab-note .important .compact}

  ```bash
  git commit -m "Add integrated GitOps platform"
  ```

  > **Salida esperada:** Git crea un commit con los manifiestos del proyecto.
  {: .lab-note .output .compact}

- {% include step_label.html %} Publica el commit en GitHub.

  > **Nota:** Argo CD podrá leer los directorios inmediatamente después de que el push termine.
  {: .lab-note .info .compact}

  ```bash
  git push origin main
  ```

  > **Salida esperada:** La rama remota `main` se actualiza correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Actualiza GitHub y confirma que `infra/` y `app/` están visibles.

  > **Importante:** No continúes si falta alguno de los manifiestos.
  {: .lab-note .important .compact}

  ```text
  GitHub:
  1. Abre ckad-integrador-lab32.
  2. Comprueba infra/.
  3. Comprueba app/.
  ```

  > **Salida esperada:** GitHub muestra los siete manifiestos publicados.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🚀 Tarea 5. Sincronizar la infraestructura con Argo CD

Crearás la primera Application para entregar a Kubernetes los recursos que posteriormente reconciliarán Crossplane y Strimzi.

### Tarea 5.1. Crear lab32-infra

- {% include step_label.html %} Recupera la contraseña inicial del usuario `admin` y consérvala temporalmente para iniciar sesión.

  > **Advertencia:** La contraseña es sensible. No la publiques en Git, capturas compartidas ni documentos del curso.
  {: .lab-note .warning .compact}

  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
  ```

  > **Salida esperada:** Se muestra una contraseña temporal en texto legible.
  {: .lab-note .output .compact}

- {% include step_label.html %} Accede a Argo CD mediante el port-forward local utilizado en la práctica 29.

  > **Nota:** Si el port-forward anterior ya no está activo, inicia uno nuevo en otra terminal.
  {: .lab-note .info .compact}

  ```bash
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  ```

  > **Salida esperada:** La terminal muestra forwarding activo hacia `127.0.0.1:8080`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Desde la interfaz inicia la creación de la Application `lab32-infra`.

  > **Importante:** Esta Application administrará únicamente el directorio `infra`.
  {: .lab-note .important .compact}

  - Argo CD:
  ```text
  https://localhost:8080
  ```
  ```text
  → Applications
  → NEW APP
  ```

  > **Salida esperada:** Se abre el formulario de nueva Application.
  {: .lab-note .output .compact}

- {% include step_label.html %} Configura y crea `lab32-infra` apuntando al directorio `infra`.

  > **Importante:** Sustituye `USUARIO` por tu usuario real de GitHub.
  {: .lab-note .important .compact}

  ```text
  Application Name: lab32-infra
  Project Name: default
  Sync Policy: Manual

  Repository URL:
  https://github.com/USUARIO/ckad-integrador-lab32.git

  Revision: HEAD
  Path: infra

  Cluster URL:
  https://kubernetes.default.svc

  Namespace:
  kafka
  ```

- {% include step_label.html %} Selecciona **CREATE**.

  > **Salida esperada:** `lab32-infra` aparece inicialmente `OutOfSync`.
  {: .lab-note .output .compact}

### Tarea 5.2. Sincronizar y esperar operadores

- {% include step_label.html %} Ejecuta Sync sobre `lab32-infra`.

  > **Nota:** Argo CD creará CRs; después Crossplane y Strimzi realizarán reconciliaciones adicionales.
  {: .lab-note .info .compact}

  ```text
  Argo CD:
  lab32-infra
  → SYNC
  → SYNCHRONIZE
  ```

  > **Salida esperada:** Argo CD inicia la sincronización de VPC, KafkaNodePool, Kafka y KafkaTopic.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que el clúster Kafka administrado por Strimzi quede Ready.

  > **Importante:** El producer y consumer dependen de este servicio; no continúes si Kafka todavía no está disponible.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait kafka/lab32-kafka -n kafka --for=condition=Ready --timeout=300s
  ```

  > **Salida esperada:** `lab32-kafka` alcanza la condición Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que la VPC administrada por Crossplane alcance Ready.

  > **Advertencia:** Este paso crea infraestructura real en AWS y puede tardar varios segundos.
  {: .lab-note .warning .compact}

  ```bash
  kubectl wait vpc/ckad-integrador-lab32 -n lab32-infra --for=condition=Ready --timeout=300s
  ```

  > **Salida esperada:** Crossplane reporta la VPC como Ready.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 📦 Tarea 6. Sincronizar la aplicación con Argo CD

Crearás una segunda Application que administrará exclusivamente los workloads CKAD del proyecto.

### Tarea 6.1. Crear lab32-app

- {% include step_label.html %} Regresa a Applications e inicia la creación de `lab32-app`.

  > **Nota:** Separar aplicación e infraestructura permite sincronizarlas y eliminarlas de forma independiente.
  {: .lab-note .info .compact}

  ```text
  Argo CD:
  Applications
  → NEW APP
  ```

  > **Salida esperada:** Se abre un nuevo formulario de Application.
  {: .lab-note .output .compact}

- {% include step_label.html %} Configura `lab32-app` para leer exclusivamente el directorio `app`.

  > **Importante:** Utiliza el mismo repositorio pero cambia el `Path`.
  {: .lab-note .important .compact}

  ```text
  Application Name: lab32-app
  Project Name: default
  Sync Policy: Manual

  Repository URL:
  https://github.com/USUARIO/ckad-integrador-lab32.git

  Revision: HEAD
  Path: app

  Cluster URL:
  https://kubernetes.default.svc

  Namespace:
  lab32-app
  ```

  > **Salida esperada:** El formulario contiene el repositorio y path correctos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea la Application `lab32-app`.

  > **Nota:** Argo CD detectará Namespace, Deployment y Job como recursos deseados.
  {: .lab-note .info .compact}

- {% include step_label.html %} Da clic en **CREATE**

  > **Salida esperada:** `lab32-app` aparece inicialmente `OutOfSync`.
  {: .lab-note .output .compact}

### Tarea 6.2. Sincronizar workloads

- {% include step_label.html %} Ejecuta Sync sobre `lab32-app`.

  > **Importante:** La infraestructura ya está Ready, por lo que el initContainer debería encontrar Kafka disponible.
  {: .lab-note .important .compact}

  ```text
  Argo CD:
  lab32-app
  → SYNC
  → SYNCHRONIZE
  ```

  > **Salida esperada:** Argo CD comienza a crear Namespace, Deployment y Job.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que el Deployment consumer complete su rollout.

  > **Nota:** El Pod primero ejecutará `wait-for-kafka` y posteriormente iniciará el container consumer.
  {: .lab-note .info .compact}

  ```bash
  kubectl rollout status deployment/orders-consumer -n lab32-app --timeout=180s
  ```

  > **Salida esperada:** El Deployment `orders-consumer` queda disponible.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que el Job producer finalice.

  > **Importante:** `Complete` confirma que los cinco eventos fueron enviados sin que el proceso terminara con error.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait job/orders-producer-v1 -n lab32-app --for=condition=Complete --timeout=180s
  ```

  > **Salida esperada:** El Job `orders-producer-v1` alcanza condición Complete.
  {: .lab-note .output .compact}

{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

{% include support-prompt.html task="tarea6" %}

---

## 🔎 Tarea 7. Validar el flujo integral

Comprobarás cada tramo de la arquitectura desde Kubernetes hasta Kafka y AWS.

### Tarea 7.1. Validar producer y consumer

- {% include step_label.html %} Comprueba el estado del Job producer.

  > **Nota:** Un Job completado representa una ejecución finita exitosa.
  {: .lab-note .info .compact}

  ```bash
  kubectl get job orders-producer-v1 -n lab32-app
  ```

  > **Salida esperada:** `orders-producer-v1` muestra una ejecución completada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el Pod del consumer y su estado de readiness.

  > **Importante:** El consumer debe permanecer Running porque continúa escuchando eventos nuevos.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n lab32-app -l app=orders-consumer
  ```

  > **Salida esperada:** El Pod `orders-consumer` aparece Running y Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Lee los logs del consumer y confirma los cinco pedidos publicados por el Job.

  > **Importante:** El orden global puede variar entre particiones; valida la presencia de los cinco IDs.
  {: .lab-note .important .compact}

  ```bash
  kubectl logs deployment/orders-consumer -n lab32-app
  ```

  > **Salida esperada:** Se observan `order-2001`, `order-2002`, `order-2003`, `order-2004` y `order-2005`.
  {: .lab-note .output .compact}

### Tarea 7.2. Validar Crossplane y AWS

- {% include step_label.html %} Obtén el ID externo asignado por AWS a la VPC creada desde Git.

  > **Nota:** Esta relación demuestra la cadena Git → Argo CD → Crossplane → AWS.
  {: .lab-note .info .compact}

  ```bash
  VPC_ID=$(kubectl get vpc ckad-integrador-lab32 -n lab32-infra -o jsonpath='{.status.atProvider.id}')
  echo "$VPC_ID"
  ```

  > **Salida esperada:** Se imprime un identificador con formato `vpc-...`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la VPC directamente en AWS mediante AWS CLI.

  > **Importante:** La VPC real debe conservar CIDR `10.32.0.0/16` y el tag del mini-proyecto.
  {: .lab-note .important .compact}

  ```bash
  aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region us-west-2
  ```

  > **Salida esperada:** AWS devuelve la VPC con CIDR `10.32.0.0/16`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba desde Argo CD que las dos Applications están sincronizadas y saludables.

  > **Nota:** Argo CD es la capa declarativa común que integra los recursos Kubernetes y los CR de ambos operadores.
  {: .lab-note .info .compact}

  ```text
  Argo CD:
  Applications

  Comprueba:
  lab32-infra → Synced
  lab32-app   → Synced
  ```

  > **Salida esperada:** Ambas Applications aparecen sincronizadas; los recursos compatibles con health assessment muestran estado saludable.
  {: .lab-note .output .compact}

{% capture r7 %}{{ results[6] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r7 %}

{% include support-prompt.html task="tarea7" %}

---

## 🔁 Tarea 8. Ejecutar un cambio GitOps adicional

Agregarás un segundo producer como un recurso nuevo para demostrar otro ciclo Git → OutOfSync → Sync → Kafka → consumer.

### Tarea 8.1. Crear y publicar producer v2

- {% include step_label.html %} Crea `app/producer-job-v2.yaml` con un Job nuevo que publique `order-2006`.

  > **Importante:** Se crea un Job con nombre nuevo porque el Pod template de un Job existente contiene campos inmutables.
  {: .lab-note .important .compact}

  ```bash
  cat > app/producer-job-v2.yaml <<'EOF'
  apiVersion: batch/v1
  kind: Job
  metadata:
    name: orders-producer-v2
    namespace: lab32-app
  spec:
    template:
      spec:
        restartPolicy: Never
        containers:
          - name: producer
            image: quay.io/strimzi/kafka:1.1.0-kafka-4.3.0
            command:
              - /bin/bash
              - -c
            args:
              - |
                printf '%s\n' 'order-2006,product=webcam,quantity=2' |
                bin/kafka-console-producer.sh \
                  --bootstrap-server lab32-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092 \
                  --topic orders
    backoffLimit: 3
  EOF
  ```

  > **Salida esperada:** Se crea `app/producer-job-v2.yaml`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega el nuevo Job al staging area.

  > **Nota:** Únicamente se versionará el nuevo manifiesto.
  {: .lab-note .info .compact}

  ```bash
  git add app/producer-job-v2.yaml
  ```

  > **Salida esperada:** El archivo queda preparado para commit.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea un commit para el nuevo evento.

  > **Importante:** El commit representa un cambio en el estado deseado de la Application.
  {: .lab-note .important .compact}

  ```bash
  git commit -m "Add second orders producer"
  ```

  > **Salida esperada:** Git crea un nuevo commit.
  {: .lab-note .output .compact}

### Tarea 8.2. Detectar y reconciliar el cambio

- {% include step_label.html %} Publica el commit en GitHub.

  > **Nota:** Kubernetes todavía no contiene `orders-producer-v2` inmediatamente después del push.
  {: .lab-note .info .compact}

  ```bash
  git push origin main
  ```

  > **Salida esperada:** GitHub recibe el nuevo manifiesto.
  {: .lab-note .output .compact}

- {% include step_label.html %} Actualiza `lab32-app` en Argo CD hasta observar `OutOfSync`.

  > **Importante:** Este estado demuestra que Git contiene un recurso que aún no existe en Kubernetes.
  {: .lab-note .important .compact}

  ```text
  Argo CD:
  lab32-app
  → REFRESH

  Comprueba:
  Sync Status: OutOfSync
  ```

  > **Salida esperada:** Argo CD detecta `orders-producer-v2` como diferencia pendiente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Sincroniza `lab32-app` y valida que el consumer reciba `order-2006`.

  > **Nota:** El consumer continúa activo desde la sincronización inicial, por lo que debe recibir el nuevo evento sin ser recreado.
  {: .lab-note .info .compact}

  ```bash
  kubectl wait job/orders-producer-v2 -n lab32-app --for=condition=Complete --timeout=180s
  ```
  ```bash
  kubectl logs deployment/orders-consumer -n lab32-app
  ```

  > **Salida esperada:** El Job v2 termina y los logs del consumer contienen `order-2006,product=webcam,quantity=2`.
  {: .lab-note .output .compact}

{% capture r8 %}{{ results[7] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r8 %}

{% include support-prompt.html task="tarea8" %}

---

## 🧹 Tarea 9. Ejecutar limpieza integral

Eliminarás primero la capa de aplicación y después la infraestructura para permitir que Crossplane complete correctamente la eliminación de AWS.

### Tarea 9.1. Eliminar las Applications

- {% include step_label.html %} Elimina `lab32-app` desde Argo CD utilizando Cascade.

  > **Advertencia:** Elimina primero la aplicación para detener producer y consumer antes de retirar Kafka.
  {: .lab-note .warning .compact}

  ```text
  Argo CD:
  Applications
  → lab32-app
  → DELETE
  → Cascade habilitado
  → confirma la eliminación
  ```

  > **Salida esperada:** Argo CD elimina Deployment y Jobs administrados por `lab32-app`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina `lab32-infra` desde Argo CD utilizando Cascade.

  > **Advertencia:** Esta acción solicita también la eliminación de la VPC real mediante Crossplane.
  {: .lab-note .warning .compact}

  ```text
  Argo CD:
  Applications
  → lab32-infra
  → DELETE
  → Cascade habilitado
  → confirma la eliminación
  ```

  > **Salida esperada:** Argo CD inicia la eliminación de KafkaTopic, Kafka, KafkaNodePool y VPC.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que el Managed Resource VPC desaparezca de Kubernetes.

  > **Importante:** El finalizer de Crossplane puede mantener el objeto durante unos segundos mientras elimina la VPC externa.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait --for=delete vpc/ckad-integrador-lab32 -n lab32-infra --timeout=300s
  ```

  > **Salida esperada:** Kubernetes confirma que el recurso VPC fue eliminado.
  {: .lab-note .output .compact}

### Tarea 9.2. Verificar AWS y conservar operadores

- {% include step_label.html %} Comprueba en AWS que el identificador de VPC guardado ya no existe.

  > **Importante:** Esta comprobación evita dejar infraestructura cloud activa después de terminar el laboratorio.
  {: .lab-note .important .compact}

  ```bash
  aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region us-west-2
  ```

  > **Salida esperada:** AWS devuelve un error indicando que el VPC ID ya no existe o no puede encontrarse.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que Argo CD, Crossplane y Strimzi permanecen operativos para conservar la plataforma base.

  > **Nota:** El mini-proyecto se elimina, pero los tres operadores permanecen como infraestructura compartida del clúster.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n argocd
  ```
  ```bash
  kubectl get pods -n crossplane-system
  ```
  ```bash
  kubectl get pods -n kafka
  ```

  > **Salida esperada:** Los componentes principales de Argo CD, Crossplane y Strimzi continúan Running.
  {: .lab-note .output .compact}

{% capture r9 %}{{ results[8] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r9 %}

{% include support-prompt.html task="tarea9" %}