---
layout: lab
title: "Práctica 6: Uso de volúmenes efímeros y persistentes"
permalink: /lab6/lab6/
images_base: /labs/lab6/img
duration: "65 minutos"
objective:
  - Diferenciar y utilizar almacenamiento efímero y persistente en Kubernetes mediante emptyDir, PersistentVolume y PersistentVolumeClaim, comprobando el ciclo de vida de los datos, el binding entre recursos y la persistencia de información después de eliminar y recrear Pods.
prerequisites:
  - Haber completado la Práctica 5 Diseño de Pod con patrón sidecar.
  - Disponer del clúster kind denominado ckad con un nodo Control Plane y dos Worker Nodes en estado Ready.
  - Tener kubectl configurado con el contexto kind-ckad y Docker Desktop operativo.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica compararás directamente el ciclo de vida de un volumen efímero emptyDir con el de almacenamiento persistente administrado mediante PersistentVolume y PersistentVolumeClaim. Primero comprobarás que los datos almacenados en emptyDir desaparecen al eliminar el Pod. Después prepararás almacenamiento local estático en un nodo kind, crearás un PV y un PVC, escribirás información desde un Pod y demostrarás que un segundo Pod puede recuperar los mismos datos después de eliminar el primero. Finalmente observarás el efecto de la política Retain y limpiarás de forma controlada todos los recursos utilizados.
slug: lab6
lab_number: 6
final_result: >
  Al finalizar habrás demostrado experimentalmente la diferencia entre almacenamiento efímero y persistente en Kubernetes. Habrás creado y utilizado un volumen emptyDir asociado al ciclo de vida de un Pod, preparado un PersistentVolume local estático con nodeAffinity, enlazado un PersistentVolumeClaim con dicho volumen, escrito datos desde un primer Pod, eliminado ese Pod y recuperado la información desde un segundo Pod. También habrás observado el estado Released producido por la política Retain antes de limpiar todos los recursos de almacenamiento utilizados.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y la práctica comienza desde la raíz local de ckad-labs.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y fue creado con kind durante la Práctica 1.
  - El almacenamiento persistente de esta práctica utiliza un volumen local estático asociado al nodo ckad-worker; no requiere instalar un provisioner ni un StorageClass dinámico.
  - Los volúmenes local requieren nodeAffinity para que Kubernetes conozca el nodo que contiene físicamente los datos.
  - La política persistentVolumeReclaimPolicy se establece en Retain para observar que eliminar el PVC no elimina automáticamente el PersistentVolume ni sus datos.
  - Los archivos YAML creados dentro de workspace/lab6 permanecen únicamente en la estación local del participante.
references:
  - text: Volúmenes en Kubernetes
    url: https://kubernetes.io/docs/concepts/storage/volumes/
  - text: Volúmenes efímeros en Kubernetes
    url: https://kubernetes.io/docs/concepts/storage/ephemeral-volumes/
  - text: Persistent Volumes y PersistentVolumeClaims
    url: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
  - text: StorageClasses en Kubernetes
    url: https://kubernetes.io/docs/concepts/storage/storage-classes/
prev: /lab5/lab5/
next: /lab7/lab7/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos de esta práctica desde **Git Bash**. Inicia ubicado en la raíz local de `ckad-labs`; cuando una tarea requiera cambiar de directorio, el propio paso lo indicará explícitamente.
{: .lab-note .info .compact}

## 🔎 Tarea 1. Preparar y explorar el almacenamiento del clúster — 7 min

Prepararás un workspace exclusivo y un namespace para la práctica. Después explorarás los recursos de almacenamiento que expone la API de Kubernetes y comprobarás si el clúster dispone de StorageClasses antes de construir los escenarios efímero y persistente.

### Tarea 1.1. Preparar el workspace y el namespace

Crearás el directorio local donde conservarás los manifiestos, validarás el contexto activo y aislarás los recursos namespaced dentro de `lab6`.

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el directorio `workspace/lab6` y accede a él; a partir de este paso permanecerás ubicado en `ckad-labs/workspace/lab6` durante el resto de la práctica.

  > **Nota:** Mantener un workspace independiente evita mezclar manifiestos de otras prácticas y permite conservar localmente los archivos creados durante el laboratorio.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab6 && cd workspace/lab6 && pwd
  ```

  > **Salida esperada:** La ruta mostrada termina en `/ckad-labs/workspace/lab6`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que kubectl continúa utilizando el contexto `kind-ckad` antes de crear recursos de almacenamiento en el clúster.

  > **Importante:** Todos los comandos de esta práctica deben ejecutarse contra el clúster `ckad`. Si aparece otro contexto, selecciónalo explícitamente antes de continuar.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Verifica que los tres nodos del clúster se encuentran disponibles antes de trabajar con almacenamiento asociado a nodos.

  > **Importante:** El escenario persistente utilizará específicamente `ckad-worker`. Si alguno de los nodos aparece `NotReady`, corrige el estado del clúster antes de continuar.
  {: .lab-note .important .compact}

  ```bash
  kubectl get nodes
  ```

  > **Salida esperada:** `ckad-control-plane`, `ckad-worker` y `ckad-worker2` aparecen en estado `Ready`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab6` para aislar los Pods y el PersistentVolumeClaim utilizados durante la práctica.

  > **Advertencia:** Los PersistentVolumes son recursos de alcance de clúster y no pertenecen a un namespace; por ello deberás eliminarlos explícitamente durante la limpieza final.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab6
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab6 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Explorar los recursos de almacenamiento disponibles

Consultarás los tipos de recurso relacionados con almacenamiento, revisarás las StorageClasses existentes y utilizarás la ayuda integrada para identificar la estructura de un volumen `emptyDir`.

- {% include step_label.html %} Consulta los recursos de la API relacionados con PersistentVolumes, PersistentVolumeClaims y StorageClasses para identificar sus nombres cortos, versiones y alcance.

  > **Nota:** `pv` y `storageclass` son recursos de alcance de clúster, mientras que `pvc` pertenece a un namespace.
  {: .lab-note .info .compact}

  ```bash
  kubectl api-resources | grep -E '^(persistentvolumeclaims|persistentvolumes|storageclasses)'
  ```

  > **Salida esperada:** Se muestran entradas para `persistentvolumeclaims`, `persistentvolumes` y `storageclasses` con sus respectivos nombres cortos y alcance.
  {: .lab-note .output .compact}

- {% include step_label.html %} Lista las StorageClasses existentes para comprobar qué mecanismos de aprovisionamiento están disponibles en el clúster kind actual.

  > **Importante:** Esta práctica no depende de que exista una StorageClass predeterminada. El PV se creará estáticamente para garantizar el mismo comportamiento en todos los entornos del curso.
  {: .lab-note .important .compact}

  ```bash
  kubectl get storageclass
  ```

  > **Salida esperada:** Kubernetes muestra las StorageClasses disponibles o el mensaje `No resources found` si el clúster no tiene ninguna configurada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta la definición de `emptyDir` desde el esquema del API Server para revisar sus propiedades antes de utilizarlo en un Pod.

  > **Nota:** `emptyDir` se declara dentro de `spec.volumes` del Pod y su ciclo de vida está asociado al Pod que lo contiene.
  {: .lab-note .info .compact}

  ```bash
  kubectl explain pod.spec.volumes.emptyDir
  ```

  > **Salida esperada:** kubectl muestra la descripción del volumen `emptyDir` y sus campos configurables.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 💨 Tarea 2. Comprobar el ciclo de vida de un volumen emptyDir — 11 min

Crearás un Pod con almacenamiento efímero `emptyDir`, escribirás información en el volumen y demostrarás que esos datos existen mientras vive el Pod. Después eliminarás y recrearás el objeto para comprobar que el contenido anterior ya no está disponible.

### Tarea 2.1. Crear y utilizar un volumen efímero

Definirás un Pod basado en BusyBox con un volumen `emptyDir` montado en `/data`, validarás el manifiesto y ejecutarás el workload dentro del namespace `lab6`.

- {% include step_label.html %} Crea el manifiesto `ephemeral-pod.yaml` con un Pod que monte un volumen `emptyDir` denominado `temp-data` en el directorio `/data`.

  > **Nota:** El proceso `sleep` mantiene el contenedor activo para que puedas escribir y consultar archivos manualmente durante la prueba.
  {: .lab-note .info .compact}

  ```bash
  cat > ephemeral-pod.yaml <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: ephemeral-demo
    namespace: lab6
  spec:
    containers:
      - name: app
        image: busybox:1.38.0-musl
        imagePullPolicy: IfNotPresent
        command: ["sh", "-c", "sleep 3600"]
        volumeMounts:
          - name: temp-data
            mountPath: /data
    volumes:
      - name: temp-data
        emptyDir: {}
  EOF
  ```

  > **Salida esperada:** Se crea `ephemeral-pod.yaml` con un volumen `temp-data` de tipo `emptyDir` y su montaje en `/data`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el manifiesto contra el API Server sin crear todavía el Pod para detectar errores de esquema o indentación.

  > **Importante:** La validación server-side permite comprobar el objeto usando el esquema real del clúster antes de modificar su estado.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply --dry-run=server -f ephemeral-pod.yaml
  ```

  > **Salida esperada:** Kubernetes responde con un resultado equivalente a `pod/ephemeral-demo created (server dry run)`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el manifiesto para crear el Pod `ephemeral-demo` con el volumen `emptyDir` definido.

  > **Nota:** En este paso únicamente crearás el recurso. La condición de disponibilidad se comprobará por separado para distinguir claramente creación y validación.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f ephemeral-pod.yaml
  ```

  > **Salida esperada:** Kubernetes responde `pod/ephemeral-demo created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que `ephemeral-demo` alcance la condición `Ready` antes de escribir datos en el volumen.

  > **Advertencia:** No continúes si el Pod no alcanza `Ready`; utiliza `kubectl describe pod ephemeral-demo -n lab6` para diagnosticar el problema antes de realizar la prueba de almacenamiento.
  {: .lab-note .warning .compact}

  ```bash
  kubectl wait --for=condition=Ready pod/ephemeral-demo -n lab6 --timeout=60s
  ```

  > **Salida esperada:** kubectl informa `pod/ephemeral-demo condition met`.
  {: .lab-note .output .compact}

### Tarea 2.2. Demostrar que los datos desaparecen con el Pod

Escribirás un archivo dentro de `emptyDir`, eliminarás el Pod completo y crearás una nueva instancia desde el mismo manifiesto para verificar que el volumen nuevo comienza vacío.

- {% include step_label.html %} Escribe un archivo denominado `session.txt` dentro del volumen `emptyDir` para almacenar un dato de prueba asociado a la vida del Pod.

  > **Nota:** El archivo se almacena en `emptyDir`, no en la capa de imagen del contenedor, y permanece disponible mientras el Pod continúe existiendo.
  {: .lab-note .info .compact}

  ```bash
  MSYS_NO_PATHCONV=1 kubectl exec -n lab6 ephemeral-demo -- sh -c 'echo "datos-efimeros-lab6" > /data/session.txt'
  ```

  > **Salida esperada:** El comando finaliza sin errores y crea `/data/session.txt` dentro del volumen.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el archivo recién creado para comprobar que el dato se encuentra disponible mientras el Pod y su `emptyDir` continúan existiendo.

  > **Importante:** `MSYS_NO_PATHCONV=1` evita que Git Bash convierta la ruta Linux `/data/session.txt` en una ruta de Windows antes de enviarla al contenedor.
  {: .lab-note .important .compact}

  ```bash
  MSYS_NO_PATHCONV=1 kubectl exec -n lab6 ephemeral-demo -- cat /data/session.txt
  ```

  > **Salida esperada:** Se muestra exactamente `datos-efimeros-lab6`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina completamente el Pod `ephemeral-demo` para terminar también el ciclo de vida del volumen `emptyDir` asociado a esa instancia.

  > **Advertencia:** Reiniciar solamente el proceso del contenedor no demuestra la pérdida del volumen; debes eliminar el objeto Pod completo para que Kubernetes destruya su `emptyDir`.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete pod ephemeral-demo -n lab6 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `pod "ephemeral-demo" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Recrea el Pod `ephemeral-demo` utilizando exactamente el mismo manifiesto empleado anteriormente.

  > **Nota:** Aunque el Pod conserva el mismo nombre y definición, Kubernetes crea una nueva instancia y un nuevo volumen `emptyDir`.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f ephemeral-pod.yaml
  ```

  > **Salida esperada:** Kubernetes responde `pod/ephemeral-demo created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que la nueva instancia del Pod alcance la condición `Ready` antes de revisar el contenido del volumen.

  > **Importante:** Esta comprobación evita consultar el filesystem mientras el contenedor todavía está iniciando.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait --for=condition=Ready pod/ephemeral-demo -n lab6 --timeout=60s
  ```

  > **Salida esperada:** kubectl informa `pod/ephemeral-demo condition met`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que `session.txt` ya no existe dentro del nuevo volumen `emptyDir`.

  > **Importante:** El nuevo Pod tiene la misma definición y el mismo nombre, pero recibió un `emptyDir` nuevo y vacío. `MSYS_NO_PATHCONV=1` evita conversiones de rutas Linux realizadas por Git Bash.
  {: .lab-note .important .compact}

  ```bash
  MSYS_NO_PATHCONV=1 kubectl exec -n lab6 ephemeral-demo -- sh -c 'if [ -f /data/session.txt ]; then cat /data/session.txt; else echo "session.txt no existe"; fi'
  ```

  > **Salida esperada:** Se muestra `session.txt no existe`, demostrando que los datos anteriores eran efímeros.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 💾 Tarea 3. Crear un PersistentVolume y un PersistentVolumeClaim — 16 min

Prepararás un directorio persistente dentro del nodo `ckad-worker` y lo representarás como un PersistentVolume local estático. Después crearás un PersistentVolumeClaim que solicitará explícitamente ese volumen y comprobarás que ambos recursos quedan enlazados.

### Tarea 3.1. Preparar el almacenamiento local y crear el PersistentVolume

Crearás físicamente el directorio dentro del nodo kind, definirás un PV de tipo `local` con `nodeAffinity` y verificarás su disponibilidad antes de crear el claim.

- {% include step_label.html %} Crea el directorio `/mnt/lab6-data` dentro del nodo `ckad-worker`, que actuará como almacenamiento físico para el PersistentVolume de esta práctica.

  > **Importante:** Los nodos de kind son contenedores Docker. El directorio se crea dentro de `ckad-worker` y permanecerá mientras ese nodo kind exista.
  {: .lab-note .important .compact}

  ```bash
  MSYS_NO_PATHCONV=1 docker exec ckad-worker mkdir -p /mnt/lab6-data
  ```

  > **Salida esperada:** El comando finaliza sin errores y el directorio queda creado dentro de `ckad-worker`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `pv.yaml` con un PersistentVolume local de 100 MiB, acceso `ReadWriteOnce`, política `Retain` y afinidad obligatoria hacia `ckad-worker`.

  > **Nota:** Los volúmenes `local` requieren `nodeAffinity` para que el scheduler conozca el nodo que contiene físicamente el directorio asociado.
  {: .lab-note .info .compact}

  ```bash
  cat > pv.yaml <<'EOF'
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: lab6-pv
  spec:
    capacity:
      storage: 100Mi
    volumeMode: Filesystem
    accessModes:
      - ReadWriteOnce
    persistentVolumeReclaimPolicy: Retain
    storageClassName: ""
    local:
      path: /mnt/lab6-data
    nodeAffinity:
      required:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                  - ckad-worker
  EOF
  ```

  > **Salida esperada:** Se crea `pv.yaml` con un volumen local asociado explícitamente al nodo `ckad-worker`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el PersistentVolume mediante dry-run server-side para comprobar la estructura y los campos utilizados antes de registrarlo en el clúster.

  > **Advertencia:** No elimines `nodeAffinity`. Kubernetes requiere afinidad de nodo cuando se utilizan volúmenes de tipo `local`.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply --dry-run=server -f pv.yaml
  ```

  > **Salida esperada:** Kubernetes responde con un resultado equivalente a `persistentvolume/lab6-pv created (server dry run)`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el PersistentVolume `lab6-pv` a partir del manifiesto validado.

  > **Nota:** El PV es un recurso de alcance de clúster y quedará disponible para claims compatibles.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f pv.yaml
  ```

  > **Salida esperada:** Kubernetes responde `persistentvolume/lab6-pv created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa la capacidad, modo de acceso, política de reclaim y estado inicial del PersistentVolume.

  > **Importante:** Antes de existir un claim compatible, el PV debe encontrarse normalmente en fase `Available`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pv lab6-pv
  ```

  > **Salida esperada:** `lab6-pv` aparece con capacidad `100Mi`, acceso `RWO`, política `Retain` y estado `Available`.
  {: .lab-note .output .compact}

### Tarea 3.2. Crear y enlazar el PersistentVolumeClaim

Definirás un PVC namespaced que solicite 50 MiB y apunte explícitamente al PV preparado. Después validarás, aplicarás e inspeccionarás el binding entre ambos recursos.

- {% include step_label.html %} Crea `pvc.yaml` solicitando 50 MiB con acceso `ReadWriteOnce` y especificando `lab6-pv` como volumen objetivo.

  > **Importante:** `storageClassName: ""` indica que el claim no solicita aprovisionamiento mediante una StorageClass y permite utilizar el PV estático sin clase creado en esta práctica.
  {: .lab-note .important .compact}

  ```bash
  cat > pvc.yaml <<'EOF'
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: lab6-pvc
    namespace: lab6
  spec:
    accessModes:
      - ReadWriteOnce
    storageClassName: ""
    volumeName: lab6-pv
    resources:
      requests:
        storage: 50Mi
  EOF
  ```

  > **Salida esperada:** Se crea `pvc.yaml` con el claim `lab6-pvc` asociado explícitamente a `lab6-pv`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida el PersistentVolumeClaim contra el API Server sin modificar todavía el estado del clúster.

  > **Nota:** El PVC solicita menos capacidad que la ofrecida por el PV y utiliza el mismo modo de acceso, por lo que ambos recursos son compatibles.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply --dry-run=server -f pvc.yaml
  ```

  > **Salida esperada:** Kubernetes responde con un resultado equivalente a `persistentvolumeclaim/lab6-pvc created (server dry run)`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el PersistentVolumeClaim `lab6-pvc` a partir del manifiesto validado.

  > **Nota:** El claim solicita explícitamente `lab6-pv`, por lo que Kubernetes intentará enlazar ambos recursos inmediatamente después de su creación.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f pvc.yaml
  ```

  > **Salida esperada:** Kubernetes responde `persistentvolumeclaim/lab6-pvc created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que Kubernetes complete el enlace del claim con `lab6-pv`.

  > **Advertencia:** Si el PVC permanece `Pending`, revisa que `storageClassName`, `volumeName`, capacidad y `accessModes` coincidan con el PersistentVolume.
  {: .lab-note .warning .compact}

  ```bash
  kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/lab6-pvc -n lab6 --timeout=60s
  ```

  > **Salida esperada:** kubectl confirma que `lab6-pvc` alcanzó la fase `Bound`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el PersistentVolume para verificar que quedó enlazado al claim creado en el namespace `lab6`.

  > **Importante:** El PV debe mostrar un claim con formato `lab6/lab6-pvc`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pv lab6-pv
  ```

  > **Salida esperada:** `lab6-pv` aparece `Bound` y referencia `lab6/lab6-pvc`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el PersistentVolumeClaim para confirmar que Kubernetes le asignó `lab6-pv`.

  > **Nota:** El PVC debe indicar `lab6-pv` en la columna `VOLUME`.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pvc lab6-pvc -n lab6
  ```

  > **Salida esperada:** `lab6-pvc` aparece `Bound` y muestra `lab6-pv` como volumen asignado.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🔁 Tarea 4. Consumir el PVC y demostrar persistencia entre Pods — 18 min

Crearás un primer Pod que monte el PersistentVolumeClaim y escriba un archivo en el almacenamiento. Después eliminarás únicamente ese Pod, crearás una segunda instancia usando el mismo PVC y comprobarás que el archivo continúa disponible.

### Tarea 4.1. Escribir datos persistentes desde el primer Pod

Definirás `persistent-a.yaml`, crearás el Pod y escribirás un archivo de prueba dentro del volumen montado para disponer de información que deberá sobrevivir a la eliminación del workload.

- {% include step_label.html %} Crea `persistent-a.yaml` con un Pod denominado `persistent-a` que monte `lab6-pvc` en `/data`.

  > **Nota:** El Pod no conoce directamente al PersistentVolume; consume almacenamiento a través del PersistentVolumeClaim.
  {: .lab-note .info .compact}

  ```bash
  cat > persistent-a.yaml <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: persistent-a
    namespace: lab6
  spec:
    containers:
      - name: app
        image: busybox:1.38.0-musl
        imagePullPolicy: IfNotPresent
        command: ["sh", "-c", "sleep 3600"]
        volumeMounts:
          - name: persistent-data
            mountPath: /data
    volumes:
      - name: persistent-data
        persistentVolumeClaim:
          claimName: lab6-pvc
  EOF
  ```

  > **Salida esperada:** Se crea `persistent-a.yaml` y el volumen del Pod referencia `claimName: lab6-pvc`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el Pod `persistent-a` utilizando el PersistentVolumeClaim definido en el manifiesto.

  > **Nota:** En este paso únicamente se crea el recurso; la condición `Ready` se comprobará por separado.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f persistent-a.yaml
  ```

  > **Salida esperada:** Kubernetes responde `pod/persistent-a created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que `persistent-a` alcance la condición `Ready`.

  > **Importante:** Debido a la `nodeAffinity` del PV, Kubernetes debe programar este Pod en `ckad-worker`, donde existe `/mnt/lab6-data`.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait --for=condition=Ready pod/persistent-a -n lab6 --timeout=60s
  ```

  > **Salida esperada:** kubectl informa `pod/persistent-a condition met`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma el nodo asignado al Pod para verificar que el scheduler respetó la afinidad definida por el PersistentVolume local.

  > **Nota:** El scheduler utiliza la afinidad del PV para evitar que un Pod consumidor sea enviado a un nodo donde el volumen local no existe.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod persistent-a -n lab6 -o wide
  ```

  > **Salida esperada:** La columna `NODE` muestra `ckad-worker`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Escribe un archivo persistente dentro de `/data` para establecer la información que deberá recuperar un segundo Pod.

  > **Importante:** El archivo se almacena físicamente en el volumen local asociado al PV y no en el filesystem efímero propio del contenedor. `MSYS_NO_PATHCONV=1` evita que Git Bash convierta la ruta Linux.
  {: .lab-note .important .compact}

  ```bash
  MSYS_NO_PATHCONV=1 kubectl exec -n lab6 persistent-a -- sh -c 'echo "datos-persistentes-lab6" > /data/persistent.txt'
  ```

  > **Salida esperada:** El comando finaliza sin errores y crea `/data/persistent.txt`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el contenido del archivo persistente para confirmar que la escritura se realizó correctamente antes de eliminar el primer Pod.

  > **Nota:** Esta lectura establece el valor de referencia que posteriormente deberá recuperar `persistent-b`.
  {: .lab-note .info .compact}

  ```bash
  MSYS_NO_PATHCONV=1 kubectl exec -n lab6 persistent-a -- cat /data/persistent.txt
  ```

  > **Salida esperada:** Se muestra exactamente `datos-persistentes-lab6`.
  {: .lab-note .output .compact}

### Tarea 4.2. Eliminar el primer Pod y recuperar los datos desde otro

Eliminarás `persistent-a` sin tocar el PVC ni el PV, comprobarás que el binding permanece y desplegarás `persistent-b` utilizando el mismo claim para recuperar el archivo almacenado anteriormente.

- {% include step_label.html %} Elimina únicamente el Pod `persistent-a`, manteniendo intactos el PVC y el PersistentVolume.

  > **Advertencia:** No utilices todavía `kubectl delete -f pvc.yaml` ni elimines `lab6-pv`; hacerlo rompería deliberadamente la relación de almacenamiento que necesitamos comprobar.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete pod persistent-a -n lab6 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `pod "persistent-a" deleted`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el PersistentVolumeClaim continúa enlazado después de eliminar el Pod consumidor.

  > **Importante:** La vida del claim es independiente de la vida del Pod que lo utiliza.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pvc lab6-pvc -n lab6
  ```

  > **Salida esperada:** `lab6-pvc` continúa en estado `Bound`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el PersistentVolume también permanece enlazado después de eliminar `persistent-a`.

  > **Nota:** El PV continúa asociado al claim aunque en este momento no exista ningún Pod consumidor.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pv lab6-pv
  ```

  > **Salida esperada:** `lab6-pv` continúa en estado `Bound`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Genera `persistent-b.yaml` a partir del manifiesto anterior cambiando únicamente el nombre del Pod para reutilizar exactamente el mismo PersistentVolumeClaim.

  > **Nota:** El segundo Pod representa un workload nuevo; compartir el mismo PVC permite comprobar si los datos persisten independientemente del Pod original.
  {: .lab-note .info .compact}

  ```bash
  sed 's/name: persistent-a/name: persistent-b/' persistent-a.yaml > persistent-b.yaml
  ```

  > **Salida esperada:** Se crea `persistent-b.yaml` con `metadata.name: persistent-b` y conserva `claimName: lab6-pvc`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `persistent-b` utilizando el mismo PersistentVolumeClaim empleado por el primer Pod.

  > **Nota:** El nuevo Pod representa una instancia distinta que reutilizará el almacenamiento ya enlazado mediante `lab6-pvc`.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f persistent-b.yaml
  ```

  > **Salida esperada:** Kubernetes responde `pod/persistent-b created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que `persistent-b` alcance la condición `Ready` antes de consultar el almacenamiento montado.

  > **Importante:** El Pod debe quedar programado en `ckad-worker` por la afinidad del volumen local.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait --for=condition=Ready pod/persistent-b -n lab6 --timeout=60s
  ```

  > **Salida esperada:** kubectl informa `pod/persistent-b condition met`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Lee desde `persistent-b` el archivo escrito originalmente por `persistent-a` para demostrar la persistencia de los datos.

  > **Importante:** Si el archivo aparece, habrás demostrado que el dato pertenece al almacenamiento persistente y no al ciclo de vida del primer Pod.
  {: .lab-note .important .compact}

  ```bash
  MSYS_NO_PATHCONV=1 kubectl exec -n lab6 persistent-b -- cat /data/persistent.txt
  ```

  > **Salida esperada:** Se muestra exactamente `datos-persistentes-lab6`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## ✅ Tarea 5. Comparar ciclos de vida y limpiar el almacenamiento — 13 min

Consolidarás la diferencia entre almacenamiento efímero y persistente utilizando consultas directas al clúster. Después eliminarás el consumidor, el claim y finalmente el PV, observando antes el efecto de la política `Retain`.

### Tarea 5.1. Comparar el estado de los recursos de almacenamiento

Consultarás la configuración efectiva del Pod persistente y extraerás propiedades del PV y PVC para relacionar volumen, claim, nodo y política de recuperación.

- {% include step_label.html %} Consulta los Pods que continúan activos al final de las pruebas funcionales.

  > **Nota:** `ephemeral-demo` contiene `emptyDir` dentro de su propia especificación, mientras que `persistent-b` consume almacenamiento mediante un PVC independiente.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pods -n lab6
  ```

  > **Salida esperada:** Se muestran `ephemeral-demo` y `persistent-b` en el namespace `lab6`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el PersistentVolumeClaim utilizado por el Pod persistente para comprobar que continúa enlazado.

  > **Importante:** El PVC debe permanecer `Bound` mientras todavía exista la relación con `lab6-pv`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pvc -n lab6
  ```

  > **Salida esperada:** `lab6-pvc` aparece en estado `Bound`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el PersistentVolume antes de iniciar la limpieza para confirmar que también continúa enlazado.

  > **Nota:** El PV es un recurso de alcance de clúster y permanecerá fuera del namespace `lab6`.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pv lab6-pv
  ```

  > **Salida esperada:** `lab6-pv` aparece en estado `Bound`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Extrae mediante JSONPath el volumen utilizado por `ephemeral-demo` para identificar la definición inline `emptyDir`.

  > **Importante:** `emptyDir` forma parte directamente de la especificación del Pod y no existe como recurso independiente.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pod ephemeral-demo -n lab6 -o jsonpath='EphemeralVolume={.spec.volumes[0].name} emptyDir={.spec.volumes[0].emptyDir}{"\n"}'
  ```

  > **Salida esperada:** La consulta identifica `temp-data` como el volumen `emptyDir` del Pod.
  {: .lab-note .output .compact}

- {% include step_label.html %} Extrae mediante JSONPath la referencia utilizada por `persistent-b` para comprobar que consume almacenamiento mediante `lab6-pvc`.

  > **Nota:** `persistentVolumeClaim.claimName` referencia un objeto independiente administrado por Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod persistent-b -n lab6 -o jsonpath='PersistentVolume={.spec.volumes[0].name} Claim={.spec.volumes[0].persistentVolumeClaim.claimName}{"\n"}'
  ```

  > **Salida esperada:** La consulta muestra `Claim=lab6-pvc`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta las propiedades clave del PersistentVolume para comprobar su capacidad, política `Retain` y nodo asociado antes de iniciar la limpieza.

  > **Nota:** Estas propiedades explican por qué el dato ha sobrevivido al reemplazo del Pod y qué ocurrirá cuando el claim sea eliminado.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pv lab6-pv -o jsonpath='Capacity={.spec.capacity.storage} ReclaimPolicy={.spec.persistentVolumeReclaimPolicy} Node={.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]} Phase={.status.phase}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Capacity=100Mi ReclaimPolicy=Retain Node=ckad-worker Phase=Bound`.
  {: .lab-note .output .compact}

### Tarea 5.2. Observar Retain y limpiar los recursos

Eliminarás primero los Pods consumidores, después el PersistentVolumeClaim y observarás que el PV queda retenido. Finalmente eliminarás el PersistentVolume, el directorio físico y el namespace del laboratorio.

- {% include step_label.html %} Elimina los dos Pods activos de la práctica sin eliminar todavía el PersistentVolumeClaim.

  > **Advertencia:** Este paso elimina `ephemeral-demo` y `persistent-b`. Verifica los nombres antes de ejecutar el comando para no afectar workloads de otras prácticas.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete pod ephemeral-demo persistent-b -n lab6 --wait=true
  ```

  > **Salida esperada:** Kubernetes confirma la eliminación de ambos Pods.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina `lab6-pvc` para liberar la relación del claim con el PersistentVolume.

  > **Importante:** `Retain` evita que Kubernetes elimine automáticamente el PV y el almacenamiento subyacente cuando desaparece el claim.
  {: .lab-note .important .compact}

  ```bash
  kubectl delete pvc lab6-pvc -n lab6 --wait=true
  ```

  > **Salida esperada:** Kubernetes confirma la eliminación de `lab6-pvc`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que `lab6-pv` alcance la fase `Released` después de eliminar el claim.

  > **Nota:** La transición demuestra que el PV ya no está enlazado a un PVC activo, pero permanece en el clúster por su política `Retain`.
  {: .lab-note .info .compact}

  ```bash
  kubectl wait --for=jsonpath='{.status.phase}'=Released pv/lab6-pv --timeout=60s
  ```

  > **Salida esperada:** kubectl confirma que la fase del PersistentVolume es `Released`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta el PersistentVolume retenido para observar su estado antes de eliminarlo manualmente.

  > **Importante:** El PV debe continuar existiendo aunque el PVC ya haya sido eliminado.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pv lab6-pv
  ```

  > **Salida esperada:** `lab6-pv` permanece en el clúster con fase `Released`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina manualmente el PersistentVolume retenido una vez completada la observación de la política `Retain`.

  > **Nota:** Debido a la política `Retain`, la eliminación del PVC no eliminó este recurso automáticamente.
  {: .lab-note .info .compact}

  ```bash
  kubectl delete pv lab6-pv
  ```

  > **Salida esperada:** Kubernetes confirma la eliminación de `lab6-pv`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Borra el directorio físico utilizado como almacenamiento local dentro de `ckad-worker`.

  > **Advertencia:** El borrado de `/mnt/lab6-data` destruye definitivamente los datos persistentes de este laboratorio. `MSYS_NO_PATHCONV=1` evita que Git Bash convierta la ruta Linux antes de enviarla al nodo kind.
  {: .lab-note .warning .compact}

  ```bash
  MSYS_NO_PATHCONV=1 docker exec ckad-worker rm -rf /mnt/lab6-data
  ```

  > **Salida esperada:** El comando finaliza sin errores y `/mnt/lab6-data` deja de existir dentro de `ckad-worker`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace `lab6` para retirar los recursos namespaced restantes y finalizar la práctica.

  > **Importante:** Este paso no elimina recursos de otras prácticas ni destruye el clúster `ckad`.
  {: .lab-note .important .compact}

  ```bash
  kubectl delete namespace lab6 --wait=true
  ```

  > **Salida esperada:** Kubernetes responde `namespace "lab6" deleted`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}