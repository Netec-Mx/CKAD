---
layout: lab
title: "Práctica 29: Publicar una aplicación con Argo CD usando manifiestos Kubernetes"
permalink: /lab29/lab29/
images_base: /labs/lab29/img
duration: "55 minutos"
objective:
  - Publicar una aplicación Kubernetes mediante un flujo GitOps completo con GitHub y Argo CD, desde la creación del repositorio y los manifiestos hasta la sincronización, validación y actualización de una versión administrada desde Git.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 8 Despliegue de aplicación con Deployment.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Disponer de Git instalado.
  - Disponer de acceso a un navegador web.
  - Disponer de conexión a Internet para GitHub y para descargar los manifiestos oficiales de Argo CD.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica realizarás un flujo GitOps completamente guiado. Crearás o iniciarás sesión en GitHub, crearás un repositorio público, escribirás una pequeña aplicación basada en NGINX y manifiestos Kubernetes, publicarás los archivos en Git, instalarás Argo CD v3.5.0, accederás a su interfaz, crearás una Application y sincronizarás el estado deseado. Finalmente modificarás la versión de la página desde Git, observarás el estado OutOfSync y volverás a sincronizar para demostrar la convergencia de Git hacia Kubernetes.
slug: lab29
lab_number: 29
final_result: >
  Al finalizar habrás creado un repositorio GitHub utilizado como fuente declarativa, instalado Argo CD v3.5.0 en Kubernetes, publicado una aplicación NGINX mediante ConfigMap, Deployment y Service, sincronizado esos recursos desde Git y demostrado un ciclo GitOps completo al cambiar la aplicación de v1 a v2 mediante commit, push, detección OutOfSync y nueva sincronización.
notes:
  - Esta práctica es 100% guiada.
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - La práctica utiliza Argo CD v3.5.0, versión probada con Kubernetes 1.36.
  - La instalación utiliza server-side apply porque las CRDs de Argo CD pueden superar el límite de anotación utilizado por client-side apply.
  - El repositorio GitHub se crea como público para que Argo CD pueda leerlo sin introducir credenciales de repositorio, SSH keys o tokens.
  - La aplicación utiliza nginx:1.31.4-alpine3.24-slim y un ConfigMap que monta index.html para mostrar una versión visible.
  - La primera sincronización es manual para que puedas observar explícitamente el estado OutOfSync antes de aplicar cambios.
  - Argo CD permanece instalado al finalizar como infraestructura compartida del clúster.
references:
  - text: Argo CD Getting Started
    url: https://argo-cd.readthedocs.io/en/latest/getting_started/
  - text: Argo CD Installation
    url: https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/
  - text: Try Argo CD Locally
    url: https://argo-cd.readthedocs.io/en/stable/try_argo_cd_locally/
  - text: Argo CD v3.5.0
    url: https://github.com/argoproj/argo-cd/releases/tag/v3.5.0
  - text: GitHub Create a Repository
    url: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository
prev: /lab28/lab28/
next: /lab30/lab30/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta los comandos de terminal desde **Git Bash**. Los pasos que indiquen GitHub o Argo CD Web UI se realizan desde el navegador. Cada cambio importante se valida antes de continuar.
{: .lab-note .info .compact}

## 🧭 Tarea 1. Preparar GitHub y el repositorio — 7 min

Crearás o utilizarás una cuenta GitHub, prepararás el repositorio remoto y lo clonarás dentro del workspace de la práctica.

### Tarea 1.1. Preparar Git y GitHub

- {% include step_label.html %} Comprueba que Git está instalado y disponible desde Git Bash.

  > **Importante:** No continúes si el comando no devuelve una versión válida de Git.
  {: .lab-note .important .compact}

  ```bash
  git --version
  ```

  > **Salida esperada:** Se muestra una versión instalada de Git.
  {: .lab-note .output .compact}

- {% include step_label.html %} Abre GitHub en el navegador y crea una cuenta si todavía no dispones de una.

  > **Nota:** Si ya tienes cuenta, continúa directamente con el siguiente paso.
  {: .lab-note .info .compact}

  ```text
  Navegador:
  1. Abre https://github.com
  2. Selecciona Sign up si no tienes cuenta.
  3. Completa correo, contraseña, nombre de usuario y verificación.
  ```

  > **Salida esperada:** Dispones de una cuenta GitHub activa.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inicia sesión en GitHub y confirma que puedes acceder a la página principal de tu cuenta.

  > **Importante:** Debes permanecer autenticado porque crearás y revisarás el repositorio desde la interfaz web.
  {: .lab-note .important .compact}

  ```text
  Navegador:
  1. Selecciona Sign in.
  2. Introduce tus credenciales.
  3. Completa cualquier verificación adicional solicitada.
  ```

  > **Salida esperada:** GitHub muestra tu sesión autenticada.
  {: .lab-note .output .compact}

### Tarea 1.2. Crear y clonar el repositorio

- {% include step_label.html %} Desde GitHub crea un repositorio nuevo denominado `ckad-argocd-lab29`.

  > **Nota:** El repositorio será la fuente declarativa que Argo CD observará durante la práctica.
  {: .lab-note .info .compact}

  ```text
  GitHub:
  1. Selecciona el botón + de la barra superior.
  2. Selecciona New repository.
  3. Repository name: ckad-argocd-lab29
  ```

  > **Salida esperada:** Se muestra el formulario de creación con el nombre `ckad-argocd-lab29`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Configura el repositorio como público, inicialízalo con README y créalo.

  > **Importante:** Public permite que Argo CD lea el repositorio sin configurar credenciales adicionales.
  {: .lab-note .important .compact}

  ```text
  GitHub:
  - Visibility: Public
  - Add a README file: activado
  - Selecciona Create repository
  ```

  > **Salida esperada:** GitHub abre el nuevo repositorio y muestra `README.md`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el workspace y clona el repositorio utilizando su URL HTTPS.

  > **Advertencia:** Sustituye `USUARIO` por tu nombre real de usuario de GitHub.
  {: .lab-note .warning .compact}

  ```bash
  mkdir -p workspace/lab29
  cd workspace/lab29
  ```
  ```bash
  git clone https://github.com/USUARIO/ckad-argocd-lab29.git
  cd ckad-argocd-lab29
  ```

  > **Salida esperada:** El repositorio queda clonado y la terminal se encuentra dentro de `workspace/lab29/ckad-argocd-lab29`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🧩 Tarea 2. Crear la aplicación Kubernetes — 7 min

Construirás una aplicación pequeña basada en NGINX y tres manifiestos: ConfigMap, Deployment y Service.

### Tarea 2.1. Crear los manifiestos principales

- {% include step_label.html %} Crea el directorio `manifests` que Argo CD utilizará posteriormente como `path` del repositorio.

  > **Nota:** Mantener los manifiestos en un directorio dedicado facilita que Argo CD limite el alcance de la Application.
  {: .lab-note .info .compact}

  ```bash
  mkdir manifests
  ```

  > **Salida esperada:** Existe el directorio `manifests`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `configmap.yaml` con la página HTML inicial `v1`.

  > **Importante:** El contenido visible permitirá comprobar fácilmente cuándo Kubernetes converge a una nueva versión administrada desde Git.
  {: .lab-note .important .compact}

  ```bash
  cat > manifests/configmap.yaml <<'EOF'
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: ckad-gitops-demo-html
  data:
    index.html: |
      <!doctype html>
      <html>
        <body>
          <h1>CKAD GitOps Demo</h1>
          <p>Version: v1</p>
          <p>Managed by Argo CD</p>
        </body>
      </html>
  EOF
  ```

  > **Salida esperada:** Se crea `manifests/configmap.yaml`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `deployment.yaml` con dos réplicas NGINX y monta el ConfigMap como contenido web.

  > **Nota:** La aplicación no requiere build ni registry; el foco permanece en Git, Kubernetes y Argo CD.
  {: .lab-note .info .compact}

  ```bash
  cat > manifests/deployment.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: ckad-gitops-demo
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: ckad-gitops-demo
    template:
      metadata:
        labels:
          app: ckad-gitops-demo
      spec:
        containers:
          - name: nginx
            image: nginx:1.31.4-alpine3.24-slim
            ports:
              - containerPort: 80
            volumeMounts:
              - name: html
                mountPath: /usr/share/nginx/html
        volumes:
          - name: html
            configMap:
              name: ckad-gitops-demo-html
  EOF
  ```

  > **Salida esperada:** Se crea `manifests/deployment.yaml` con dos réplicas y el volumen ConfigMap.
  {: .lab-note .output .compact}

### Tarea 2.2. Completar y validar los manifiestos

- {% include step_label.html %} Crea `service.yaml` para exponer internamente el Deployment mediante ClusterIP.

  > **Importante:** Argo CD administrará este Service junto con el resto de recursos declarados en Git.
  {: .lab-note .important .compact}

  ```bash
  cat > manifests/service.yaml <<'EOF'
  apiVersion: v1
  kind: Service
  metadata:
    name: ckad-gitops-demo
  spec:
    selector:
      app: ckad-gitops-demo
    ports:
      - port: 80
        targetPort: 80
  EOF
  ```

  > **Salida esperada:** Se crea `manifests/service.yaml`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida la sintaxis básica de los manifiestos mediante dry-run sin desplegarlos todavía.

  > **Importante:** No ejecutes un apply real. Queremos que Argo CD sea quien cree posteriormente los recursos.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply --dry-run=client -f manifests/
  ```

  > **Salida esperada:** ConfigMap, Deployment y Service aparecen como `created (dry run)`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa los archivos creados antes de versionarlos.

  > **Nota:** Debes tener exactamente tres manifiestos dentro del directorio de aplicación.
  {: .lab-note .info .compact}

  ```bash
  ls -la manifests
  ```

  > **Salida esperada:** Se muestran `configmap.yaml`, `deployment.yaml` y `service.yaml`.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🌿 Tarea 3. Versionar y publicar los manifiestos — 6 min

Prepararás los cambios, crearás el commit inicial y los publicarás en GitHub.

### Tarea 3.1. Preparar el commit

- {% include step_label.html %} Revisa el estado del repositorio para identificar los archivos nuevos todavía no versionados.

  > **Nota:** Git debe mostrar el directorio `manifests/` como contenido nuevo.
  {: .lab-note .info .compact}

  ```bash
  git status
  ```

  > **Salida esperada:** Los manifiestos aparecen como archivos no rastreados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega el directorio `manifests` al staging area.

  > **Importante:** `git add` prepara el contenido para el siguiente commit; todavía no lo publica en GitHub.
  {: .lab-note .important .compact}

  ```bash
  git add manifests
  ```

  > **Salida esperada:** El comando finaliza sin errores.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que los tres archivos se encuentran preparados para commit.

  > **Nota:** Deben aparecer bajo `Changes to be committed`.
  {: .lab-note .info .compact}

  ```bash
  git status
  ```

  > **Salida esperada:** Los tres manifiestos aparecen en staging.
  {: .lab-note .output .compact}

### Tarea 3.2. Crear commit y publicar

- {% include step_label.html %} Crea el commit inicial de la aplicación Kubernetes.

  > **Importante:** El commit representa una versión concreta del estado deseado que Argo CD podrá comparar contra el clúster.
  {: .lab-note .important .compact}

  ```bash
  git commit -m "Add Kubernetes manifests for Argo CD"
  ```

  > **Salida esperada:** Git crea un nuevo commit con los tres manifiestos.
  {: .lab-note .output .compact}

- {% include step_label.html %} Publica el commit en la rama `main` del repositorio remoto.

  > **Advertencia:** Git Credential Manager puede abrir el navegador durante el primer push para autenticar tu cuenta de GitHub.
  {: .lab-note .warning .compact}

  ```bash
  git push origin main
  ```

  > **Salida esperada:** Git confirma que la rama `main` fue actualizada en `origin`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Actualiza la página del repositorio en GitHub y comprueba que el directorio `manifests` contiene los tres YAML.

  > **Nota:** Esta comprobación confirma que GitHub ya contiene el estado declarativo que Argo CD consumirá.
  {: .lab-note .info .compact}

  ```text
  GitHub:
  1. Abre ckad-argocd-lab29.
  2. Abre manifests.
  3. Comprueba configmap.yaml, deployment.yaml y service.yaml.
  ```

  > **Salida esperada:** Los tres manifiestos son visibles desde GitHub.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🚀 Tarea 4. Instalar Argo CD — 10 min

Instalarás Argo CD v3.5.0 paso a paso y comprobarás cada componente antes de intentar acceder a la interfaz.

### Tarea 4.1. Instalar los componentes

- {% include step_label.html %} Confirma nuevamente que el contexto activo es `kind-ckad`.

  > **Advertencia:** La instalación crea CRDs, ClusterRoles y otros recursos de alcance de clúster; evita instalar Argo CD en un contexto incorrecto.
  {: .lab-note .warning .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace dedicado `argocd`.

  > **Nota:** La instalación estándar utiliza este namespace para los componentes principales de Argo CD.
  {: .lab-note .info .compact}

  ```bash
  kubectl create namespace argocd
  ```

  > **Salida esperada:** Kubernetes responde `namespace/argocd created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Instala Argo CD v3.5.0 desde su manifiesto oficial utilizando server-side apply.

  > **Importante:** `--server-side --force-conflicts` evita el problema de tamaño de anotaciones de CRDs y sigue la recomendación actual de instalación.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.0/manifests/install.yaml
  ```

  > **Salida esperada:** Kubernetes crea o configura los CRDs, Deployments, StatefulSets, Services, RBAC y demás recursos de Argo CD.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que los recursos principales de Argo CD fueron creados en el namespace correcto.

  > **Nota:** Todavía pueden existir Pods en proceso de inicialización; en el siguiente paso esperarás su disponibilidad.
  {: .lab-note .info .compact}

  ```bash
  kubectl get all -n argocd
  ```

  > **Salida esperada:** Se muestran los Pods, Services, Deployments y StatefulSet de Argo CD.
  {: .lab-note .output .compact}

### Tarea 4.2. Esperar y validar la instalación

- {% include step_label.html %} Espera a que `argocd-server` complete su rollout.

  > **Importante:** La interfaz no estará disponible hasta que el API server de Argo CD se encuentre listo.
  {: .lab-note .important .compact}

  ```bash
  kubectl rollout status deployment/argocd-server -n argocd --timeout=180s
  ```

  > **Salida esperada:** El rollout de `argocd-server` finaliza correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que `argocd-repo-server` complete su rollout.

  > **Nota:** Repo Server es responsable de recuperar y procesar el contenido de los repositorios declarativos.
  {: .lab-note .info .compact}

  ```bash
  kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=180s
  ```

  > **Salida esperada:** El rollout de `argocd-repo-server` finaliza correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que los Pods principales de Argo CD están en estado Running.

  > **Importante:** No continúes si existen componentes esenciales en `CrashLoopBackOff` o `ImagePullBackOff`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n argocd
  ```

  > **Salida esperada:** Los Pods principales aparecen Running y Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el CRD `applications.argoproj.io` quedó registrado.

  > **Nota:** Una Application de Argo CD es un recurso Kubernetes personalizado definido por este CRD.
  {: .lab-note .info .compact}

  ```bash
  kubectl get crd applications.argoproj.io
  ```

  > **Salida esperada:** Kubernetes muestra el CRD `applications.argoproj.io`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🔐 Tarea 5. Acceder a Argo CD y crear la Application — 7 min

Obtendrás las credenciales iniciales, abrirás la interfaz local y registrarás la aplicación GitOps.

### Tarea 5.1. Preparar el acceso

- {% include step_label.html %} Recupera la contraseña inicial del usuario `admin` y consérvala temporalmente para iniciar sesión.

  > **Advertencia:** La contraseña es sensible. No la publiques en Git, capturas compartidas ni documentos del curso.
  {: .lab-note .warning .compact}

  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
  ```

  > **Salida esperada:** Se muestra una contraseña temporal en texto legible.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba el Service `argocd-server` antes de abrir el acceso local.

  > **Nota:** No cambiaremos el tipo del Service porque `port-forward` es suficiente para este entorno de laboratorio.
  {: .lab-note .info .compact}

  ```bash
  kubectl get service argocd-server -n argocd
  ```

  > **Salida esperada:** Se muestra `argocd-server` con sus puertos disponibles.
  {: .lab-note .output .compact}

- {% include step_label.html %} Abre una segunda terminal Git Bash e inicia un port-forward hacia el API server de Argo CD.

  > **Importante:** Mantén esta terminal abierta durante los pasos de interfaz Web. No la reutilices para otros comandos.
  {: .lab-note .important .compact}

  ```bash
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  ```

  > **Salida esperada:** La terminal muestra `Forwarding from 127.0.0.1:8080 -> 8080` o un mensaje equivalente de forwarding activo.
  {: .lab-note .output .compact}

### Tarea 5.2. Iniciar sesión y crear la Application

- {% include step_label.html %} Abre la interfaz de Argo CD en el navegador e inicia sesión con `admin`.

  > **Advertencia:** El navegador puede advertir sobre un certificado TLS local. Continúa únicamente porque estás accediendo al port-forward local de tu propio clúster.
  {: .lab-note .warning .compact}

  ```text
  Navegador:
  1. Abre https://localhost:8080
  2. Username: admin
  3. Password: utiliza la contraseña recuperada
  4. Selecciona Sign In
  ```

  > **Salida esperada:** Se muestra la página Applications de Argo CD.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inicia la creación de una nueva Application desde la interfaz.

  > **Nota:** La Application representa la relación declarativa entre un origen Git y un destino Kubernetes.
  {: .lab-note .info .compact}

  ```text
  Argo CD:
  Applications
  → NEW APP
  ```

  > **Salida esperada:** Se abre el formulario de creación de Application.
  {: .lab-note .output .compact}

- {% include step_label.html %} Completa los campos de origen y destino de `ckad-gitops-demo` y crea la Application.

  > **Importante:** Sustituye `USUARIO` por tu usuario real de GitHub y mantén Sync Policy en Manual para observar OutOfSync explícitamente.
  {: .lab-note .important .compact}

  ```text
  GENERAL
  Application Name: ckad-gitops-demo
  Project Name: default
  Sync Policy: Manual

  SOURCE
  Repository URL: https://github.com/USUARIO/ckad-argocd-lab29.git
  Revision: HEAD
  Path: manifests

  DESTINATION
  Cluster URL: https://kubernetes.default.svc
  Namespace: lab29-app

  SYNC OPTIONS
  Create Namespace: Auto-Create Namespace

  Selecciona CREATE
  ```

  > **Salida esperada:** La Application `ckad-gitops-demo` aparece en Argo CD, normalmente con estado inicial `OutOfSync`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🔄 Tarea 6. Sincronizar y validar la aplicación — 6 min

Realizarás la primera sincronización y comprobarás que Argo CD, y no un apply manual, creó los recursos de la aplicación.

### Tarea 6.1. Sincronizar

- {% include step_label.html %} Abre `ckad-gitops-demo` y observa los recursos que Argo CD detectó en Git.

  > **Nota:** Antes del primer Sync, Git contiene el estado deseado pero Kubernetes todavía no posee los recursos de la aplicación.
  {: .lab-note .info .compact}

  ```text
  Argo CD:
  Applications
  → ckad-gitops-demo
  ```

  > **Salida esperada:** Se visualizan ConfigMap, Deployment y Service como recursos administrados por la Application.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inicia manualmente la sincronización de la Application.

  > **Importante:** Esta acción ordena a Argo CD reconciliar el estado del clúster con el contenido actual de Git.
  {: .lab-note .important .compact}

  ```text
  Argo CD:
  SYNC
  ```

  > **Salida esperada:** Se abre el panel de sincronización con los recursos seleccionados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma la operación de sincronización.

  > **Nota:** No modifiques las opciones adicionales para esta primera práctica.
  {: .lab-note .info .compact}

  ```text
  Argo CD:
  Selecciona SYNCHRONIZE
  ```

  > **Salida esperada:** Argo CD inicia la operación de Sync.
  {: .lab-note .output .compact}

### Tarea 6.2. Validar Kubernetes y la aplicación

- {% include step_label.html %} Espera a que Argo CD muestre la Application como `Synced` y `Healthy`.

  > **Importante:** Ambos estados son distintos: Sync compara estado deseado contra Git y Health evalúa el estado de los recursos desplegados.
  {: .lab-note .important .compact}

  ```text
  Estado esperado:
  Sync Status: Synced
  Health Status: Healthy
  ```

  > **Salida esperada:** La Application aparece `Synced` y `Healthy`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba desde kubectl que el namespace y los recursos fueron creados por la sincronización.

  > **Nota:** No ejecutaste `kubectl apply -f manifests`; esta es la evidencia de que Argo CD realizó el deployment.
  {: .lab-note .info .compact}

  ```bash
  kubectl get all -n lab29-app
  ```

  > **Salida esperada:** Se muestran Deployment, dos Pods Ready y Service `ckad-gitops-demo`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta una prueba HTTP desde un Pod temporal para comprobar la versión inicial de la página.

  > **Importante:** La respuesta debe proceder del Service administrado por Argo CD.
  {: .lab-note .important .compact}

  ```bash
  kubectl run lab29-test -n lab29-app --rm -i --restart=Never --image=busybox:1.38.0-musl -- wget -qO- http://ckad-gitops-demo
  ```

  > **Salida esperada:** El HTML contiene `CKAD GitOps Demo`, `Version: v1` y `Managed by Argo CD`.
  {: .lab-note .output .compact}

{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

{% include support-prompt.html task="tarea6" %}

---

## 🔁 Tarea 7. Ejecutar un cambio GitOps de v1 a v2 — 8 min

Modificarás exclusivamente Git, publicarás el cambio y observarás cómo Argo CD detecta drift antes de volver a sincronizar.

### Tarea 7.1. Modificar y publicar Git

- {% include step_label.html %} Cambia en `configmap.yaml` la versión visible de `v1` a `v2`.

  > **Importante:** No edites directamente el ConfigMap del clúster. Git debe seguir siendo la fuente de verdad.
  {: .lab-note .important .compact}

  ```bash
  sed -i 's#<p>Version: v1</p>#<p>Version: v2</p>#' manifests/configmap.yaml
  ```

  > **Salida esperada:** `manifests/configmap.yaml` contiene ahora `Version: v2`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Agrega el ConfigMap modificado al staging area.

  > **Nota:** Esta acción prepara únicamente el cambio de versión.
  {: .lab-note .info .compact}

  ```bash
  git add manifests/configmap.yaml
  ```

  > **Salida esperada:** El archivo queda preparado para commit.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea un commit para la versión `v2`.

  > **Importante:** El nuevo commit representa el siguiente estado deseado de la aplicación.
  {: .lab-note .important .compact}

  ```bash
  git commit -m "Update GitOps demo to v2"
  ```

  > **Salida esperada:** Git crea un nuevo commit con la modificación de `configmap.yaml`.
  {: .lab-note .output .compact}

### Tarea 7.2. Observar OutOfSync y converger

- {% include step_label.html %} Publica el nuevo commit en GitHub.

  > **Nota:** Hasta este punto Kubernetes continúa sirviendo v1 porque todavía no has sincronizado el nuevo estado.
  {: .lab-note .info .compact}

  ```bash
  git push origin main
  ```

  > **Salida esperada:** GitHub recibe el commit de actualización a v2.
  {: .lab-note .output .compact}

- {% include step_label.html %} Regresa a Argo CD y espera o actualiza la Application hasta observar `OutOfSync`.

  > **Importante:** Este estado demuestra que Git cambió mientras el clúster conserva temporalmente una versión diferente.
  {: .lab-note .important .compact}

  ```text
  Argo CD:
  Applications
  → ckad-gitops-demo
  → REFRESH si es necesario

  Observa:
  Sync Status: OutOfSync
  ```

  > **Salida esperada:** La Application cambia a `OutOfSync`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Ejecuta nuevamente Sync y valida que la aplicación converja a la versión `v2`.

  > **Importante:** Argo CD debe aplicar el nuevo ConfigMap y mantener la Application en estado administrado desde Git.
  {: .lab-note .important .compact}

  ```bash
  kubectl run lab29-test-v2 -n lab29-app --rm -i --restart=Never --image=busybox:1.38.0-musl -- wget -qO- http://ckad-gitops-demo
  ```

  > **Salida esperada:** Después del Sync, la respuesta contiene `Version: v2` y Argo CD vuelve a mostrar `Synced` y `Healthy`.
  {: .lab-note .output .compact}

{% capture r7 %}{{ results[6] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r7 %}

{% include support-prompt.html task="tarea7" %}

---

## 🧹 Tarea 8. Limpiar la aplicación y conservar Argo CD — 4 min

Eliminarás únicamente la Application y sus recursos administrados. Argo CD y el repositorio GitHub permanecerán disponibles para futuras prácticas.

### Tarea 8.1. Eliminar la Application

- {% include step_label.html %} Desde Argo CD elimina `ckad-gitops-demo` utilizando eliminación en cascada.

  > **Advertencia:** Cascade elimina los recursos administrados por la Application. No elimines el namespace `argocd`.
  {: .lab-note .warning .compact}

  ```text
  Argo CD:
  Applications
  → ckad-gitops-demo
  → DELETE
  → confirma el nombre solicitado
  → mantén Cascade habilitado
  → confirma eliminación
  ```

  > **Salida esperada:** `ckad-gitops-demo` desaparece de la lista de Applications y Argo CD comienza a retirar sus recursos administrados.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba desde kubectl que los recursos de la aplicación ya no permanecen activos.

  > **Nota:** El namespace puede desaparecer si fue creado y administrado como parte de la sincronización; si permanece vacío, no afecta la instalación de Argo CD.
  {: .lab-note .info .compact}

  ```bash
  kubectl get all -n lab29-app --ignore-not-found
  ```

  > **Salida esperada:** No se muestran workloads activos de `ckad-gitops-demo`.
  {: .lab-note .output .compact}

### Tarea 8.2. Conservar infraestructura y repositorio

- {% include step_label.html %} Comprueba que Argo CD continúa operativo después de eliminar la aplicación.

  > **Importante:** Argo CD se conserva como infraestructura compartida del clúster para ejercicios posteriores.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n argocd
  ```

  > **Salida esperada:** Los Pods principales de Argo CD continúan Running.
  {: .lab-note .output .compact}

- {% include step_label.html %} Verifica que el repositorio local conserva los manifiestos y los commits utilizados durante el ciclo GitOps.

  > **Nota:** No elimines el repositorio GitHub; queda como evidencia y material de estudio.
  {: .lab-note .info .compact}

  ```bash
  git log --oneline --max-count=3
  ```

  > **Salida esperada:** Se observan al menos el commit inicial de los manifiestos y el commit de actualización a v2.
  {: .lab-note .output .compact}

{% capture r8 %}{{ results[7] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r8 %}

{% include support-prompt.html task="tarea8" %}