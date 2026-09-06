---
layout: lab
title: "Práctica 31: Desplegar Kafka básico y validar producer/consumer"
permalink: /lab31/lab31/
images_base: /labs/lab31/img
duration: "60 minutos"
objective:
  - Desplegar Apache Kafka sobre Kubernetes mediante Strimzi, crear un Topic administrado, producir y consumir mensajes y validar el comportamiento básico de particiones y Consumer Groups.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Disponer de conexión a Internet para descargar Strimzi y las imágenes de Kafka.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica realizarás un flujo completamente guiado para desplegar Kafka 4.3.0 mediante Strimzi 1.1.0. Instalarás el Cluster Operator, crearás un clúster Kafka KRaft de un nodo con almacenamiento efímero, crearás un Topic de tres particiones, enviarás mensajes desde un producer y los consumirás desde uno o más consumers. Finalmente observarás un Consumer Group y la distribución de particiones antes de retirar el clúster Kafka y conservar Strimzi como infraestructura compartida.
slug: lab31
lab_number: 31
final_result: >
  Al finalizar habrás instalado Strimzi, desplegado un clúster Kafka básico en modo KRaft, creado un KafkaTopic de tres particiones, producido mensajes de negocio, consumido esos mensajes desde el inicio y en tiempo real y observado un Consumer Group con dos miembros. También habrás eliminado los recursos Kafka conservando el Cluster Operator para reutilización posterior.
notes:
  - Esta práctica es 100% guiada.
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza Strimzi 1.1.0, compatible oficialmente con Kubernetes 1.30 a 1.36.
  - Se utiliza Apache Kafka 4.3.0, soportado oficialmente por Strimzi 1.1.0.
  - Kafka se despliega en modo KRaft; no se utiliza ZooKeeper.
  - Se usa un solo nodo con roles controller y broker porque el objetivo es aprendizaje local, no alta disponibilidad.
  - El almacenamiento es efímero y puede perder datos si el Pod Kafka se reemplaza; no es apropiado para producción.
  - El Topic orders utiliza tres particiones y replication factor 1 debido a que existe un solo broker.
  - Los comandos producer y consumer utilizan la imagen oficial quay.io/strimzi/kafka:1.1.0-kafka-4.3.0.
  - El orden de mensajes está garantizado dentro de una partición, no globalmente entre todas las particiones.
  - Strimzi permanece instalado al finalizar como infraestructura compartida.
references:
  - text: Strimzi Downloads and Supported Versions
    url: https://strimzi.io/downloads/
  - text: Strimzi Quickstart
    url: https://strimzi.io/quickstarts/
  - text: Strimzi Deploying and Managing
    url: https://strimzi.io/docs/operators/latest/deploying
  - text: Strimzi KafkaTopic
    url: https://strimzi.io/docs/operators/latest/deploying#assembly-using-the-topic-operator-str
prev: /lab30/lab30/
next: /lab32/lab32/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Algunos pasos de producer y consumer requieren mantener una terminal interactiva abierta; cuando sea necesario, el paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🧭 Tarea 1. Preparar el entorno y comprender el flujo Kafka — 7 min

Prepararás el workspace, comprobarás el contexto y establecerás los conceptos mínimos que utilizarás durante toda la práctica.

### Tarea 1.1. Preparar workspace y namespace

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el workspace de la práctica y accede a él.

  > **Nota:** Aquí conservarás los manifiestos de Strimzi, Kafka y KafkaTopic.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab31 && cd workspace/lab31
  ```

  > **Salida esperada:** La terminal queda ubicada en `ckad-labs/workspace/lab31`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que kubectl apunta al clúster principal del curso.

  > **Importante:** El contexto esperado es `kind-ckad`.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `kafka` donde residirán el operator y los recursos Kafka.

  > **Advertencia:** Si el namespace ya existe, revisa sus recursos antes de continuar para evitar mezclar una instalación anterior.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace kafka
  ```

  > **Salida esperada:** Kubernetes responde `namespace/kafka created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Identificar los componentes principales

- {% include step_label.html %} Revisa el flujo lógico que utilizarás para publicar y consumir eventos.

  > **Nota:** Kafka desacopla al productor del consumidor mediante Topics.
  {: .lab-note .info .compact}

  ```text
  Producer
     ↓
  Topic
     ↓
  Partitions
     ↓
  Consumer
  ```

  > **Salida esperada:** Identificas Producer como emisor, Topic como flujo lógico, Partition como unidad de paralelismo y Consumer como lector.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa la función de un Consumer Group antes de ejecutar consumidores concurrentes.

  > **Importante:** Dentro de un mismo Consumer Group una partición solo puede asignarse a un miembro a la vez.
  {: .lab-note .important .compact}

  ```text
  orders
  ├── partition 0 ──► consumer A
  ├── partition 1 ──► consumer B
  └── partition 2 ──► consumer A o B
  ```

  > **Salida esperada:** Comprendes que el grupo distribuye particiones entre sus miembros para paralelizar el consumo.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que todavía no existen recursos Strimzi dentro del namespace.

  > **Nota:** Esta línea base permitirá distinguir claramente qué recursos aparecen después de instalar el operator.
  {: .lab-note .info .compact}

  ```bash
  kubectl get all -n kafka
  ```

  > **Salida esperada:** No se muestran workloads de Strimzi ni Kafka.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## ⚙️ Tarea 2. Instalar Strimzi Cluster Operator — 8 min

Instalarás el operador que amplía la API de Kubernetes con recursos Kafka y que posteriormente reconciliará el clúster.

### Tarea 2.1. Instalar el operator

- {% include step_label.html %} Aplica el manifiesto oficial de instalación de Strimzi en el namespace `kafka`.

  > **Importante:** A la fecha de esta práctica el canal estable corresponde a Strimzi 1.1.0. El manifiesto instala CRDs, RBAC y el Cluster Operator.
  {: .lab-note .important .compact}

  ```bash
  kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
  ```

  > **Salida esperada:** Kubernetes crea los CRDs, Roles, RoleBindings, ServiceAccounts y el Deployment del Cluster Operator.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que el Deployment `strimzi-cluster-operator` complete su rollout.

  > **Nota:** El operator debe estar disponible antes de crear recursos `Kafka`.
  {: .lab-note .info .compact}

  ```bash
  kubectl rollout status deployment/strimzi-cluster-operator -n kafka --timeout=180s
  ```

  > **Salida esperada:** El rollout finaliza correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el Pod del Cluster Operator.

  > **Importante:** No continúes si el Pod permanece en `CrashLoopBackOff` o `ImagePullBackOff`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n kafka
  ```

  > **Salida esperada:** `strimzi-cluster-operator` aparece Running y Ready.
  {: .lab-note .output .compact}

### Tarea 2.2. Validar las APIs instaladas

- {% include step_label.html %} Comprueba que Kubernetes registró los CRDs principales de Strimzi.

  > **Nota:** Los CRDs extienden la API de Kubernetes con objetos especializados.
  {: .lab-note .info .compact}

  ```bash
  kubectl get crd | grep kafka.strimzi.io
  ```

  > **Salida esperada:** Se muestran CRDs como `kafkas.kafka.strimzi.io`, `kafkanodepools.kafka.strimzi.io` y `kafkatopics.kafka.strimzi.io`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que `Kafka` está disponible como recurso de la API.

  > **Importante:** El recurso `Kafka` representa la configuración deseada del clúster, no un broker individual.
  {: .lab-note .important .compact}

  ```bash
  kubectl api-resources | grep -E '^kafkas[[:space:]]'
  ```

  > **Salida esperada:** Se muestra el recurso namespaced `Kafka` del grupo `kafka.strimzi.io`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que `KafkaTopic` también está disponible.

  > **Nota:** El Topic Operator observará estos objetos y mantendrá los Topics correspondientes dentro de Kafka.
  {: .lab-note .info .compact}

  ```bash
  kubectl api-resources | grep -E '^kafkatopics[[:space:]]'
  ```

  > **Salida esperada:** Se muestra el recurso namespaced `KafkaTopic`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🚀 Tarea 3. Desplegar un clúster Kafka básico — 9 min

Crearás un nodo KRaft con roles controller y broker y un clúster Kafka 4.3.0 de laboratorio.

### Tarea 3.1. Crear los manifiestos Kafka

- {% include step_label.html %} Crea `kafka-nodepool.yaml` con un solo nodo de doble rol y almacenamiento efímero.

  > **Advertencia:** El almacenamiento efímero es adecuado únicamente para laboratorio; perderá datos si el Pod es reemplazado.
  {: .lab-note .warning .compact}

  ```bash
  cat > kafka-nodepool.yaml <<'EOF'
  apiVersion: kafka.strimzi.io/v1
  kind: KafkaNodePool
  metadata:
    name: dual-role
    namespace: kafka
    labels:
      strimzi.io/cluster: ckad-kafka
  spec:
    replicas: 1
    roles:
      - controller
      - broker
    storage:
      type: ephemeral
  EOF
  ```

  > **Salida esperada:** Se crea `kafka-nodepool.yaml` con un nodo controller/broker.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `kafka.yaml` utilizando Kafka 4.3.0, listener interno sin TLS y factores de replicación compatibles con un solo broker.

  > **Importante:** Los valores de replicación en `1` son deliberados porque este laboratorio utiliza un único broker.
  {: .lab-note .important .compact}

  ```bash
  cat > kafka.yaml <<'EOF'
  apiVersion: kafka.strimzi.io/v1
  kind: Kafka
  metadata:
    name: ckad-kafka
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

  > **Salida esperada:** Se crea `kafka.yaml` con Kafka 4.3.0 y Entity Operator habilitado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica primero el KafkaNodePool para declarar la capacidad del clúster.

  > **Nota:** La label `strimzi.io/cluster: ckad-kafka` asocia el NodePool con el recurso Kafka que crearás después.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f kafka-nodepool.yaml
  ```

  > **Salida esperada:** Kubernetes crea `kafkanodepool.kafka.strimzi.io/dual-role`.
  {: .lab-note .output .compact}

### Tarea 3.2. Crear y validar Kafka

- {% include step_label.html %} Aplica el recurso `Kafka` para iniciar la reconciliación del clúster.

  > **Importante:** Strimzi creará los Pods, Services, Secrets y componentes auxiliares necesarios.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f kafka.yaml
  ```

  > **Salida esperada:** Kubernetes crea `kafka.kafka.strimzi.io/ckad-kafka`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que Strimzi reporte el clúster Kafka como Ready.

  > **Nota:** La primera descarga de imágenes puede tardar más que las reconciliaciones posteriores.
  {: .lab-note .info .compact}

  ```bash
  kubectl wait kafka/ckad-kafka -n kafka --for=condition=Ready --timeout=300s
  ```

  > **Salida esperada:** Kubernetes confirma que `ckad-kafka` alcanzó la condición Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba los Pods creados por Strimzi.

  > **Importante:** Debes distinguir el Pod Kafka del Entity Operator y del Cluster Operator.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n kafka
  ```

  > **Salida esperada:** Se muestran el broker/controller Kafka, Entity Operator y Cluster Operator en estado Running.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🧵 Tarea 4. Crear y analizar un Topic — 6 min

Crearás `orders` con tres particiones para utilizarlo durante las pruebas de producer, consumer y Consumer Group.

### Tarea 4.1. Crear el KafkaTopic

- {% include step_label.html %} Comprueba el Service bootstrap interno creado para los clientes Kafka.

  > **Nota:** Producers y consumers utilizarán `ckad-kafka-kafka-bootstrap:9092` dentro del namespace.
  {: .lab-note .info .compact}

  ```bash
  kubectl get service ckad-kafka-kafka-bootstrap -n kafka
  ```

  > **Salida esperada:** Se muestra el Service bootstrap con el puerto interno de Kafka.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `topic.yaml` con tres particiones y replication factor 1.

  > **Importante:** La label `strimzi.io/cluster` permite al Topic Operator asociar el recurso con `ckad-kafka`.
  {: .lab-note .important .compact}

  ```bash
  cat > topic.yaml <<'EOF'
  apiVersion: kafka.strimzi.io/v1
  kind: KafkaTopic
  metadata:
    name: orders
    namespace: kafka
    labels:
      strimzi.io/cluster: ckad-kafka
  spec:
    partitions: 3
    replicas: 1
  EOF
  ```

  > **Salida esperada:** Se crea `topic.yaml` con tres particiones.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el KafkaTopic para solicitar su creación dentro de Kafka.

  > **Nota:** El Topic Operator traduce el objeto Kubernetes a un Topic real del broker.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f topic.yaml
  ```

  > **Salida esperada:** Kubernetes crea `kafkatopic.kafka.strimzi.io/orders`.
  {: .lab-note .output .compact}

### Tarea 4.2. Validar el Topic

- {% include step_label.html %} Espera a que el Topic alcance estado Ready.

  > **Importante:** No inicies producers hasta confirmar que el Topic fue reconciliado.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait kafkatopic/orders -n kafka --for=condition=Ready --timeout=120s
  ```

  > **Salida esperada:** El Topic `orders` alcanza la condición Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba particiones y replication factor desde Kubernetes.

  > **Nota:** Tres particiones permiten demostrar paralelismo aunque todas residan en un único broker.
  {: .lab-note .info .compact}

  ```bash
  kubectl get kafkatopic orders -n kafka -o wide
  ```

  > **Salida esperada:** `orders` muestra 3 particiones, replication factor 1 y estado Ready.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 📤 Tarea 5. Producir mensajes — 7 min

Utilizarás las herramientas Kafka incluidas en la imagen oficial de Strimzi para publicar eventos en `orders`.

### Tarea 5.1. Preparar el producer

- {% include step_label.html %} Comprueba nuevamente el endpoint bootstrap antes de abrir el producer interactivo.

  > **Importante:** La conexión utilizará el listener interno plain sobre el puerto 9092.
  {: .lab-note .important .compact}

  ```bash
  kubectl get endpointslices -n kafka -l kubernetes.io/service-name=ckad-kafka-kafka-bootstrap
  ```

  > **Salida esperada:** El EndpointSlice contiene un backend para el Service bootstrap.
  {: .lab-note .output .compact}

- {% include step_label.html %} Abre un producer interactivo utilizando la imagen Strimzi correspondiente a Kafka 4.3.0.

  > **Nota:** Mantén esta terminal abierta hasta completar los siguientes mensajes.
  {: .lab-note .info .compact}

  ```bash
  kubectl -n kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:1.1.0-kafka-4.3.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server ckad-kafka-kafka-bootstrap:9092 --topic orders
  ```

  > **Salida esperada:** Se abre el producer y queda esperando líneas de entrada; si no aparece el cursor, presiona Enter una vez.
  {: .lab-note .output .compact}

- {% include step_label.html %} Envía el primer evento de pedido desde la sesión interactiva.

  > **Importante:** Cada línea confirmada con Enter se publica como un record independiente.
  {: .lab-note .important .compact}

  ```text
  order-1001,product=laptop,quantity=1
  ```

  > **Salida esperada:** El producer acepta la línea sin mostrar error.
  {: .lab-note .output .compact}

### Tarea 5.2. Completar la carga inicial

- {% include step_label.html %} Envía un segundo pedido.

  > **Nota:** Los records sin key pueden distribuirse entre las particiones disponibles.
  {: .lab-note .info .compact}

  ```text
  order-1002,product=monitor,quantity=2
  ```

  > **Salida esperada:** El producer acepta el segundo record.
  {: .lab-note .output .compact}

- {% include step_label.html %} Envía un tercer pedido.

  > **Nota:** El contenido representa datos simples de negocio para facilitar su identificación durante el consumo.
  {: .lab-note .info .compact}

  ```text
  order-1003,product=keyboard,quantity=1
  ```

  > **Salida esperada:** El producer acepta el tercer record.
  {: .lab-note .output .compact}

- {% include step_label.html %} Finaliza el producer con `Ctrl+C` después de enviar los mensajes.

  > **Importante:** La opción `--rm=true` elimina el Pod temporal cuando termina el proceso.
  {: .lab-note .important .compact}

  ```text
  Presiona:
  Ctrl+C
  ```

  > **Salida esperada:** La sesión del producer termina y el Pod temporal es eliminado.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 📥 Tarea 6. Consumir mensajes — 7 min

Leerás los mensajes existentes y después observarás un nuevo evento en tiempo real.

### Tarea 6.1. Consumir desde el inicio

- {% include step_label.html %} Abre un consumer que lea `orders` desde el principio del Topic.

  > **Nota:** `--from-beginning` permite recuperar records existentes cuando el consumer no posee offsets previos.
  {: .lab-note .info .compact}

  ```bash
  kubectl -n kafka run kafka-consumer -ti --image=quay.io/strimzi/kafka:1.1.0-kafka-4.3.0 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server ckad-kafka-kafka-bootstrap:9092 --topic orders --from-beginning
  ```

  > **Salida esperada:** Aparecen los tres pedidos enviados anteriormente y el consumer queda esperando nuevos records.
  {: .lab-note .output .compact}

- {% include step_label.html %} Identifica en la salida los tres IDs de pedido originales.

  > **Importante:** El orden global entre distintas particiones no debe asumirse; verifica presencia, no una secuencia absoluta.
  {: .lab-note .important .compact}

  ```text
  Debes localizar:
  order-1001
  order-1002
  order-1003
  ```

  > **Salida esperada:** Los tres records están presentes en la salida del consumer.
  {: .lab-note .output .compact}

- {% include step_label.html %} Mantén el consumer activo y abre una segunda terminal Git Bash para producir un evento nuevo.

  > **Nota:** La primera terminal debe permanecer ejecutando el consumer.
  {: .lab-note .info .compact}

  ```text
  Abre una segunda terminal Git Bash.
  Mantén la terminal del consumer sin cerrar.
  ```

  > **Salida esperada:** Dispones de una terminal con consumer activo y otra libre para producir.
  {: .lab-note .output .compact}

### Tarea 6.2. Validar consumo en tiempo real

- {% include step_label.html %} Desde la segunda terminal inicia un producer nuevo para el mismo Topic.

  > **Importante:** Utiliza el mismo bootstrap Service y el Topic `orders`.
  {: .lab-note .important .compact}

  ```bash
  kubectl -n kafka run kafka-producer-live -ti --image=quay.io/strimzi/kafka:1.1.0-kafka-4.3.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server ckad-kafka-kafka-bootstrap:9092 --topic orders
  ```

  > **Salida esperada:** El producer queda listo para recibir texto.
  {: .lab-note .output .compact}

- {% include step_label.html %} Publica un pedido adicional desde el producer activo.

  > **Nota:** El objetivo es observar la propagación del record mientras el consumer permanece conectado.
  {: .lab-note .info .compact}

  ```text
  order-1004,product=mouse,quantity=3
  ```

  > **Salida esperada:** La terminal del consumer muestra `order-1004` poco después de publicarlo.
  {: .lab-note .output .compact}

- {% include step_label.html %} Finaliza ambos procesos interactivos mediante `Ctrl+C`.

  > **Importante:** Termina primero el producer y después el consumer para dejar libres los nombres de Pods temporales.
  {: .lab-note .important .compact}

  ```text
  Producer:
  Ctrl+C

  Consumer:
  Ctrl+C
  ```

  > **Salida esperada:** Ambos Pods temporales son eliminados.
  {: .lab-note .output .compact}

{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

{% include support-prompt.html task="tarea6" %}

---

## 👥 Tarea 7. Validar particiones y Consumer Group — 10 min

Examinarás las tres particiones y ejecutarás dos consumers dentro del mismo grupo para observar la asignación de trabajo.

### Tarea 7.1. Inspeccionar particiones

- {% include step_label.html %} Ejecuta `kafka-topics.sh` desde un Pod temporal para describir el Topic `orders`.

  > **Nota:** Esta herramienta consulta directamente los metadatos Kafka y complementa la vista del KafkaTopic.
  {: .lab-note .info .compact}

  ```bash
  kubectl -n kafka run kafka-topics-cli --rm -i --restart=Never --image=quay.io/strimzi/kafka:1.1.0-kafka-4.3.0 -- bin/kafka-topics.sh --bootstrap-server ckad-kafka-kafka-bootstrap:9092 --describe --topic orders
  ```

  > **Salida esperada:** Se muestra `PartitionCount: 3` y tres entradas de partición.
  {: .lab-note .output .compact}

- {% include step_label.html %} Identifica las particiones 0, 1 y 2 en la salida.

  > **Importante:** Las tres particiones pueden tener el mismo Leader porque el laboratorio utiliza un solo broker.
  {: .lab-note .important .compact}

  ```text
  Busca:
  Partition: 0
  Partition: 1
  Partition: 2
  ```

  > **Salida esperada:** Confirmas que `orders` posee exactamente tres particiones.
  {: .lab-note .output .compact}

- {% include step_label.html %} Relaciona el replication factor del Topic con la cantidad de brokers disponibles.

  > **Nota:** Con un solo broker el replication factor 1 evita solicitar réplicas imposibles de distribuir.
  {: .lab-note .info .compact}

  ```text
  Laboratorio:
  Brokers: 1
  Replication factor: 1
  Partitions: 3
  ```

  > **Salida esperada:** Comprendes que particiones y réplicas representan conceptos diferentes.
  {: .lab-note .output .compact}

### Tarea 7.2. Crear y observar un Consumer Group

- {% include step_label.html %} Abre una terminal y ejecuta el primer consumer del grupo `orders-workers`.

  > **Importante:** Mantén esta terminal abierta mientras agregas el segundo miembro.
  {: .lab-note .important .compact}

  ```bash
  kubectl -n kafka run orders-worker-a -ti --image=quay.io/strimzi/kafka:1.1.0-kafka-4.3.0 --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server ckad-kafka-kafka-bootstrap:9092 --topic orders --group orders-workers
  ```

  > **Salida esperada:** `orders-worker-a` se conecta al Topic y permanece esperando records nuevos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Abre otra terminal y ejecuta el segundo consumer dentro del mismo grupo.

  > **Nota:** Kafka realizará un rebalance para repartir las tres particiones entre ambos consumidores.
  {: .lab-note .info .compact}

  ```bash
  kubectl -n kafka run orders-worker-b -ti --image=quay.io/strimzi/kafka:1.1.0-kafka-4.3.0 --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server ckad-kafka-kafka-bootstrap:9092 --topic orders --group orders-workers
  ```

  > **Salida esperada:** `orders-worker-b` se une al grupo y ambos consumers permanecen activos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Desde una tercera terminal describe el Consumer Group y observa la asignación de particiones.

  > **Importante:** Debes observar tres filas de partición repartidas entre los dos `CONSUMER-ID`.
  {: .lab-note .important .compact}

  ```bash
  kubectl -n kafka run kafka-groups-cli --rm -i --restart=Never --image=quay.io/strimzi/kafka:1.1.0-kafka-4.3.0 -- bin/kafka-consumer-groups.sh --bootstrap-server ckad-kafka-kafka-bootstrap:9092 --describe --group orders-workers
  ```

  > **Salida esperada:** El grupo `orders-workers` muestra las particiones 0, 1 y 2 asignadas entre dos miembros activos.
  {: .lab-note .output .compact}

{% capture r7 %}{{ results[6] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r7 %}

{% include support-prompt.html task="tarea7" %}

---

## 🧹 Tarea 8. Limpiar Kafka y conservar Strimzi — 6 min

Cerrarás los consumers, eliminarás Topic y clúster Kafka y comprobarás que el Cluster Operator permanece disponible.

### Tarea 8.1. Retirar consumidores y recursos Kafka

- {% include step_label.html %} Finaliza los dos consumers activos con `Ctrl+C`.

  > **Nota:** Los Pods no utilizan `--rm`, por lo que posteriormente los retirarás explícitamente.
  {: .lab-note .info .compact}

  ```text
  orders-worker-a:
  Ctrl+C

  orders-worker-b:
  Ctrl+C
  ```

  > **Salida esperada:** Ambos procesos consumer terminan.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina los Pods temporales de los dos miembros del Consumer Group.

  > **Importante:** Esto retira los clientes sin afectar el Topic ni el broker.
  {: .lab-note .important .compact}

  ```bash
  kubectl delete pod orders-worker-a orders-worker-b -n kafka --ignore-not-found
  ```

  > **Salida esperada:** Kubernetes elimina ambos Pods o indica que ya no existen.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el KafkaTopic `orders`.

  > **Advertencia:** Al eliminar el KafkaTopic, el Topic Operator elimina también el Topic administrado dentro de Kafka.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete -f topic.yaml
  ```

  > **Salida esperada:** Kubernetes confirma la eliminación de `orders`.
  {: .lab-note .output .compact}

### Tarea 8.2. Eliminar el clúster y validar cierre

- {% include step_label.html %} Elimina el recurso Kafka para retirar el broker y Entity Operator.

  > **Importante:** Conserva el Cluster Operator; únicamente se elimina el clúster Kafka de la práctica.
  {: .lab-note .important .compact}

  ```bash
  kubectl delete -f kafka.yaml
  ```

  > **Salida esperada:** Kubernetes inicia la eliminación de `ckad-kafka` y sus recursos administrados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el KafkaNodePool y comprueba que Strimzi continúa operativo.

  > **Nota:** El namespace `kafka` permanece porque contiene el Cluster Operator reutilizable.
  {: .lab-note .info .compact}

  ```bash
  kubectl delete -f kafka-nodepool.yaml
  ```

  > **Salida esperada:** El KafkaNodePool es eliminado; `strimzi-cluster-operator` continúa instalado en el namespace `kafka`.
  {: .lab-note .output .compact}

{% capture r8 %}{{ results[7] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r8 %}

{% include support-prompt.html task="tarea8" %}