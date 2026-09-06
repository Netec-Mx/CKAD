---
layout: lab
title: "Práctica 30: Consumir un recurso gestionado con Crossplane de forma básica"
permalink: /lab30/lab30/
images_base: /labs/lab30/img
duration: "45 minutos"
objective:
  - Consumir un recurso administrado de AWS mediante Crossplane, instalando Crossplane y el Provider AWS EC2, configurando autenticación, creando una VPC, modificando su estado deseado y validando la reconciliación y eliminación desde Kubernetes.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Disponer de Helm 3.2 o posterior.
  - Disponer de AWS CLI instalado.
  - Disponer de una cuenta AWS o credenciales de laboratorio con permisos para crear, consultar, modificar, etiquetar y eliminar una VPC.
  - Disponer de acceso a Internet para descargar Crossplane y el Provider AWS EC2.
  - Trabajar desde Visual Studio Code dentro del directorio local ckad-labs.
introduction:
  - En esta práctica realizarás un flujo completamente guiado con Crossplane y AWS. Instalarás Crossplane v2.3.4, instalarás el Provider AWS EC2 v2.7.1, entregarás credenciales mediante un Secret y un ClusterProviderConfig y crearás una VPC real en AWS desde un recurso Kubernetes. Después cambiarás enableDnsHostnames de false a true para observar reconciliación declarativa y, finalmente, eliminarás el recurso Kubernetes para comprobar que Crossplane elimina también la VPC administrada en AWS.
slug: lab30
lab_number: 30
final_result: >
  Al finalizar habrás utilizado Kubernetes como plano de control para crear una VPC real en AWS mediante Crossplane, observado condiciones de sincronización y estado externo, modificado una propiedad mutable de la VPC y validado que Crossplane reconcilia el cambio en AWS. También habrás eliminado la VPC desde Kubernetes y confirmado que la infraestructura cloud fue retirada.
notes:
  - Esta práctica es 100% guiada.
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows.
  - El clúster de referencia utiliza Kubernetes 1.36.1 y el contexto kubectl kind-ckad.
  - Se utiliza Crossplane v2.3.4 y Upbound provider-aws-ec2 v2.7.1.
  - Crossplane v2 utiliza Managed Resources namespaced; la VPC se creará dentro del namespace lab30.
  - El recurso utilizado es ec2.aws.m.upbound.io/v1beta1 VPC.
  - La VPC utiliza el CIDR 10.30.0.0/16 y la región us-west-2.
  - El cambio demostrativo modifica enableDnsHostnames de false a true; no se intenta cambiar el CIDR de la VPC.
  - No se crean subnets, Internet Gateway, NAT Gateway ni instancias para mantener el objetivo centrado en el flujo de Crossplane.
  - Nunca publiques credenciales AWS en Git, ConfigMap, Markdown, capturas ni repositorios.
  - No utilices access keys del usuario root de AWS.
  - La eliminación de la VPC es obligatoria al final para evitar dejar infraestructura cloud activa.
references:
  - text: Crossplane Installation
    url: https://docs.crossplane.io/latest/get-started/install/
  - text: Crossplane Managed Resources
    url: https://docs.crossplane.io/v2.3/managed-resources/managed-resources/
  - text: Crossplane Get Started with Managed Resources
    url: https://docs.crossplane.io/latest/get-started/get-started-with-managed-resources/
  - text: Upbound Provider AWS EC2
    url: https://marketplace.upbound.io/providers/upbound/provider-aws-ec2/latest
  - text: AWS VPC Documentation
    url: https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html
prev: /lab29/lab29/
next: /lab31/lab31/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

> **Nota:** Ejecuta todos los comandos desde **Git Bash**. Los pasos que indiquen AWS Management Console se realizan desde el navegador. Esta práctica crea una VPC real en AWS; completa obligatoriamente la limpieza final.
{: .lab-note .info .compact}

## ☁️ Tarea 1. Preparar AWS y las herramientas — 6 min

Validarás el entorno local, el clúster Kubernetes y la identidad AWS antes de instalar componentes con alcance de clúster.

### Tarea 1.1. Preparar workspace y contexto

- {% include step_label.html %} Desde la raíz local de `ckad-labs`, crea el workspace de la práctica y accede a él.

  > **Nota:** Aquí conservarás los manifiestos de Crossplane, ProviderConfig y VPC.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab30 && cd workspace/lab30
  ```

  > **Salida esperada:** La terminal queda ubicada en `ckad-labs/workspace/lab30`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Confirma que kubectl utiliza el clúster principal `kind-ckad`.

  > **Advertencia:** Crossplane instala CRDs y recursos con alcance de clúster; evita instalarlo en un contexto diferente.
  {: .lab-note .warning .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que Helm está instalado antes de utilizar el método oficial de instalación de Crossplane.

  > **Importante:** Crossplane requiere Helm 3.2 o posterior para este procedimiento.
  {: .lab-note .important .compact}

  ```bash
  helm version
  ```

  > **Salida esperada:** Helm devuelve información de una versión 3.2 o posterior.
  {: .lab-note .output .compact}

### Tarea 1.2. Validar acceso a AWS

- {% include step_label.html %} Comprueba que AWS CLI está disponible desde Git Bash.

  > **Nota:** AWS CLI se utilizará para verificar la identidad, obtener el ID real de la VPC y comprobar cambios efectuados por Crossplane.
  {: .lab-note .info .compact}

  ```bash
  aws --version
  ```

  > **Salida esperada:** AWS CLI muestra su versión instalada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inicia sesión en AWS Management Console o crea una cuenta si todavía no dispones de una.

  > **Advertencia:** Para laboratorios utiliza un usuario o rol de práctica. No generes access keys para el usuario root de AWS.
  {: .lab-note .warning .compact}

  ```text
  Navegador:
  1. Abre https://aws.amazon.com/
  2. Selecciona Sign in to the Console si ya tienes cuenta.
  3. Si no tienes cuenta, selecciona Create an AWS Account y completa el proceso.
  4. Accede con el usuario o rol autorizado para el laboratorio.
  ```

  > **Salida esperada:** Puedes acceder a AWS Management Console con una identidad autorizada.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba desde AWS CLI qué identidad está activa.

  > **Importante:** Si el comando falla, configura primero las credenciales entregadas para el laboratorio mediante `aws configure` antes de continuar.
  {: .lab-note .important .compact}

  ```bash
  aws sts get-caller-identity
  ```

  > **Salida esperada:** Se devuelve un JSON con `UserId`, `Account` y `Arn`.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## ⚙️ Tarea 2. Instalar Crossplane — 7 min

Instalarás Crossplane mediante Helm y validarás sus componentes principales.

### Tarea 2.1. Preparar el repositorio Helm

- {% include step_label.html %} Agrega el repositorio estable oficial de Crossplane a Helm.

  > **Nota:** El repositorio estable evita utilizar builds de desarrollo del canal master.
  {: .lab-note .info .compact}

  ```bash
  helm repo add crossplane-stable https://charts.crossplane.io/stable
  ```

  > **Salida esperada:** Helm confirma que `crossplane-stable` fue agregado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Actualiza el índice local de repositorios Helm.

  > **Importante:** Esto permite resolver correctamente la versión fijada del chart.
  {: .lab-note .important .compact}

  ```bash
  helm repo update
  ```

  > **Salida esperada:** Helm finaliza la actualización de repositorios sin errores.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el chart de Crossplane está disponible antes de instalarlo.

  > **Nota:** La consulta permite verificar conectividad con el repositorio y evitar iniciar una instalación con un índice incompleto.
  {: .lab-note .info .compact}

  ```bash
  helm search repo crossplane-stable/crossplane --versions | head
  ```

  > **Salida esperada:** Se muestran versiones disponibles del chart `crossplane-stable/crossplane`.
  {: .lab-note .output .compact}

### Tarea 2.2. Instalar y validar Crossplane

- {% include step_label.html %} Instala Crossplane v2.3.4 en el namespace `crossplane-system`.

  > **Importante:** Se fija la versión para que todos los participantes utilicen el mismo comportamiento durante la práctica.
  {: .lab-note .important .compact}

  ```bash
  helm upgrade --install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace --version 2.3.4
  ```

  > **Salida esperada:** Helm confirma la instalación o actualización del release `crossplane`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera a que el Deployment principal de Crossplane esté disponible.

  > **Nota:** No instales providers hasta que el plano de control de Crossplane esté operativo.
  {: .lab-note .info .compact}

  ```bash
  kubectl rollout status deployment/crossplane -n crossplane-system --timeout=180s
  ```

  > **Salida esperada:** El rollout de `crossplane` finaliza correctamente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba los Pods instalados en `crossplane-system`.

  > **Importante:** Los componentes principales deben encontrarse Running y Ready.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pods -n crossplane-system
  ```

  > **Salida esperada:** Se muestran los Pods de Crossplane, incluidos `crossplane` y `crossplane-rbac-manager`, en estado Running.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 📦 Tarea 3. Instalar el Provider AWS EC2 — 5 min

Agregarás el provider especializado que instala los Managed Resources necesarios para administrar VPC y otros recursos EC2.

### Tarea 3.1. Crear e instalar el Provider

- {% include step_label.html %} Crea el manifiesto `provider-aws-ec2.yaml` fijando el paquete Upbound AWS EC2 v2.7.1.

  > **Nota:** Se utiliza el provider especializado EC2 en lugar de instalar APIs de AWS que no son necesarias para esta práctica.
  {: .lab-note .info .compact}

  ```bash
  cat > provider-aws-ec2.yaml <<'EOF_PROVIDER'
  apiVersion: pkg.crossplane.io/v1
  kind: Provider
  metadata:
    name: provider-aws-ec2
  spec:
    package: xpkg.upbound.io/upbound/provider-aws-ec2:v2.7.1
  EOF_PROVIDER
  ```

  > **Salida esperada:** Se crea `provider-aws-ec2.yaml`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el manifiesto para solicitar la instalación del provider.

  > **Importante:** Crossplane descargará el paquete y creará dinámicamente los controladores y CRDs del provider.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f provider-aws-ec2.yaml
  ```

  > **Salida esperada:** Kubernetes responde `provider.pkg.crossplane.io/provider-aws-ec2 created` o `configured`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera hasta que el Provider indique que se encuentra saludable.

  > **Nota:** La instalación puede tardar varios segundos mientras se descargan imágenes y registran CRDs.
  {: .lab-note .info .compact}

  ```bash
  kubectl wait provider/provider-aws-ec2 --for=condition=Healthy --timeout=180s
  ```

  > **Salida esperada:** El Provider alcanza la condición `Healthy`.
  {: .lab-note .output .compact}

### Tarea 3.2. Validar la API de VPC

- {% include step_label.html %} Comprueba el estado del provider desde Crossplane.

  > **Importante:** `INSTALLED=True` y `HEALTHY=True` indican que el paquete está listo para reconciliar recursos.
  {: .lab-note .important .compact}

  ```bash
  kubectl get providers
  ```

  > **Salida esperada:** `provider-aws-ec2` aparece instalado y saludable.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que Kubernetes reconoce el recurso namespaced `VPC`.

  > **Nota:** Crossplane v2 permite crear Managed Resources AWS dentro de namespaces.
  {: .lab-note .info .compact}

  ```bash
  kubectl api-resources | grep -i 'vpc'
  ```

  > **Salida esperada:** Se muestra el recurso `VPC` asociado al grupo `ec2.aws.m.upbound.io`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🔐 Tarea 4. Configurar credenciales AWS — 7 min

Entregarás las credenciales locales al provider mediante un Secret y un ClusterProviderConfig sin incluir secretos dentro de los manifiestos.

### Tarea 4.1. Preparar las credenciales locales

- {% include step_label.html %} Comprueba que existe el archivo local de credenciales utilizado por AWS CLI.

  > **Advertencia:** No muestres el contenido con `cat`; únicamente verificarás que el archivo exista.
  {: .lab-note .warning .compact}

  ```bash
  test -f ~/.aws/credentials && echo "AWS credentials file found"
  ```

  > **Salida esperada:** Se muestra `AWS credentials file found`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Si aún no configuraste AWS CLI, registra las credenciales autorizadas del laboratorio.

  > **Advertencia:** Introduce únicamente credenciales temporales o de un usuario/rol de laboratorio. Nunca utilices credenciales root.
  {: .lab-note .warning .compact}

  ```bash
  aws configure
  ```

  > **Salida esperada:** AWS CLI solicita Access Key ID, Secret Access Key, región predeterminada y formato; utiliza `us-west-2` como región.
  {: .lab-note .output .compact}

- {% include step_label.html %} Valida nuevamente la identidad después de configurar AWS CLI.

  > **Importante:** Crossplane utilizará estas mismas credenciales a través del Secret que crearás posteriormente.
  {: .lab-note .important .compact}

  ```bash
  aws sts get-caller-identity
  ```

  > **Salida esperada:** AWS devuelve la identidad autorizada sin errores de autenticación.
  {: .lab-note .output .compact}

### Tarea 4.2. Crear Secret y ClusterProviderConfig

- {% include step_label.html %} Crea un Secret Kubernetes a partir del archivo local de credenciales AWS.

  > **Advertencia:** El Secret contiene material sensible. No lo exportes a YAML ni lo agregues a Git.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create secret generic aws-secret -n crossplane-system --from-file=creds=$HOME/.aws/credentials
  ```

  > **Salida esperada:** Kubernetes responde `secret/aws-secret created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `providerconfig.yaml` para indicar al provider dónde leer sus credenciales.

  > **Nota:** `ClusterProviderConfig` permite utilizar la misma configuración desde Managed Resources ubicados en distintos namespaces.
  {: .lab-note .info .compact}

  ```bash
  cat > providerconfig.yaml <<'EOF_PROVIDERCONFIG'
  apiVersion: aws.m.upbound.io/v1beta1
  kind: ClusterProviderConfig
  metadata:
    name: default
  spec:
    credentials:
      source: Secret
      secretRef:
        namespace: crossplane-system
        name: aws-secret
        key: creds
  EOF_PROVIDERCONFIG
  ```

  > **Salida esperada:** Se crea `providerconfig.yaml` sin contener valores de Access Key ni Secret Access Key.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica el ClusterProviderConfig para habilitar autenticación del provider hacia AWS.

  > **Importante:** El provider utilizará esta referencia al reconciliar la VPC.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f providerconfig.yaml
  ```

  > **Salida esperada:** Kubernetes crea `clusterproviderconfig.aws.m.upbound.io/default`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🌐 Tarea 5. Crear una VPC administrada — 7 min

Crearás el Managed Resource VPC en Kubernetes y observarás cómo Crossplane crea la infraestructura correspondiente en AWS.

### Tarea 5.1. Crear el manifiesto VPC

- {% include step_label.html %} Crea el namespace `lab30` para alojar el Managed Resource namespaced.

  > **Nota:** En Crossplane v2 los Managed Resources AWS pueden residir dentro de namespaces.
  {: .lab-note .info .compact}

  ```bash
  kubectl create namespace lab30
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab30 created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea `vpc.yaml` con el estado deseado inicial de la VPC.

  > **Importante:** `enableDnsHostnames` comienza en `false` porque posteriormente será la propiedad utilizada para demostrar reconciliación.
  {: .lab-note .important .compact}

  ```bash
  cat > vpc.yaml <<'EOF_VPC'
  apiVersion: ec2.aws.m.upbound.io/v1beta1
  kind: VPC
  metadata:
    name: ckad-crossplane-lab30
    namespace: lab30
  spec:
    forProvider:
      region: us-west-2
      cidrBlock: 10.30.0.0/16
      enableDnsSupport: true
      enableDnsHostnames: false
      tags:
        Name: ckad-crossplane-lab30
        ManagedBy: Crossplane
    providerConfigRef:
      name: default
      kind: ClusterProviderConfig
  EOF_VPC
  ```

  > **Salida esperada:** Se crea `vpc.yaml` con CIDR `10.30.0.0/16`, DNS support habilitado y DNS hostnames deshabilitado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa el manifiesto antes de solicitar la creación del recurso cloud.

  > **Advertencia:** A partir del siguiente paso Crossplane realizará llamadas reales a AWS.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply --dry-run=client -f vpc.yaml
  ```

  > **Salida esperada:** Kubernetes valida el recurso VPC en modo dry-run sin crear infraestructura en AWS.
  {: .lab-note .output .compact}

### Tarea 5.2. Crear y observar reconciliación

- {% include step_label.html %} Aplica `vpc.yaml` para crear el Managed Resource.

  > **Importante:** No crees la VPC manualmente desde AWS Console; Crossplane debe ser su controlador.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f vpc.yaml
  ```

  > **Salida esperada:** Kubernetes responde que `vpc.ec2.aws.m.upbound.io/ckad-crossplane-lab30` fue creado.
  {: .lab-note .output .compact}

- {% include step_label.html %} Observa el estado del Managed Resource mientras Crossplane reconcilia AWS.

  > **Nota:** Durante los primeros segundos `READY` puede permanecer en `False` hasta finalizar la creación externa.
  {: .lab-note .info .compact}

  ```bash
  kubectl get vpc -n lab30
  ```

  > **Salida esperada:** Se muestra `ckad-crossplane-lab30` y, al completar la reconciliación, las condiciones indican sincronización y disponibilidad.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera explícitamente a que la VPC alcance la condición Ready.

  > **Importante:** No continúes con modificaciones mientras la creación inicial siga pendiente.
  {: .lab-note .important .compact}

  ```bash
  kubectl wait vpc/ckad-crossplane-lab30 -n lab30 --for=condition=Ready --timeout=180s
  ```

  > **Salida esperada:** Kubernetes confirma que la condición `Ready` fue alcanzada.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🔄 Tarea 6. Modificar y reconciliar la VPC — 5 min

Cambiarás el estado deseado desde Kubernetes y comprobarás que Crossplane actualiza la misma VPC en AWS.

### Tarea 6.1. Cambiar el estado deseado

- {% include step_label.html %} Modifica `enableDnsHostnames` de `false` a `true` sin cambiar el CIDR ni recrear el recurso.

  > **Nota:** Se utiliza una propiedad mutable para demostrar actualización in-place de la VPC.
  {: .lab-note .info .compact}

  ```bash
  sed -i 's/enableDnsHostnames: false/enableDnsHostnames: true/' vpc.yaml
  ```

  > **Salida esperada:** `vpc.yaml` contiene `enableDnsHostnames: true`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Aplica nuevamente el mismo manifiesto para actualizar el estado deseado.

  > **Importante:** Crossplane comparará el estado declarado con el observado en AWS y ejecutará la modificación necesaria.
  {: .lab-note .important .compact}

  ```bash
  kubectl apply -f vpc.yaml
  ```

  > **Salida esperada:** Kubernetes responde que la VPC fue `configured`.
  {: .lab-note .output .compact}

### Tarea 6.2. Validar la reconciliación en AWS

- {% include step_label.html %} Obtén desde el status de Crossplane el identificador externo asignado por AWS a la VPC.

  > **Nota:** `metadata.name` identifica el objeto Kubernetes; AWS utiliza un identificador externo como `vpc-xxxxxxxx`.
  {: .lab-note .info .compact}

  ```bash
  VPC_ID=$(kubectl get vpc ckad-crossplane-lab30 -n lab30 -o jsonpath='{.status.atProvider.id}')
  echo "$VPC_ID"
  ```

  > **Salida esperada:** Se imprime un identificador AWS con formato similar a `vpc-0123456789abcdef0`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta directamente AWS para verificar el nuevo valor de DNS hostnames.

  > **Importante:** Esta comprobación demuestra que el cambio realizado en Kubernetes fue reconciliado hacia AWS.
  {: .lab-note .important .compact}

  ```bash
  aws ec2 describe-vpc-attribute --vpc-id "$VPC_ID" --attribute enableDnsHostnames --region us-west-2
  ```

  > **Salida esperada:** AWS devuelve `EnableDnsHostnames` con `Value: true`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el Managed Resource vuelve a mostrar condiciones saludables después de la actualización.

  > **Nota:** Crossplane mantiene un ciclo continuo de observación y reconciliación sobre el recurso externo.
  {: .lab-note .info .compact}

  ```bash
  kubectl get vpc ckad-crossplane-lab30 -n lab30
  ```

  > **Salida esperada:** La VPC vuelve a mostrarse sincronizada y Ready.
  {: .lab-note .output .compact}

{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

{% include support-prompt.html task="tarea6" %}

---

## 🔍 Tarea 7. Comparar estado deseado y observado — 4 min

Relacionarás la especificación Kubernetes con la VPC real y con el estado observado por Crossplane.

### Tarea 7.1. Validar desde AWS

- {% include step_label.html %} Consulta la VPC real mediante AWS CLI utilizando el identificador obtenido anteriormente.

  > **Importante:** Esta consulta valida que el recurso externo existe fuera del clúster Kubernetes.
  {: .lab-note .important .compact}

  ```bash
  aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region us-west-2
  ```

  > **Salida esperada:** AWS devuelve la VPC con CIDR `10.30.0.0/16` y sus tags.
  {: .lab-note .output .compact}

- {% include step_label.html %} Abre Amazon VPC en AWS Management Console y localiza la VPC mediante el tag Name.

  > **Nota:** La consola ofrece una segunda evidencia visual de que la infraestructura fue creada por Crossplane.
  {: .lab-note .info .compact}

  ```text
  AWS Management Console:
  1. Busca VPC.
  2. Abre Your VPCs.
  3. Localiza ckad-crossplane-lab30.
  4. Confirma IPv4 CIDR 10.30.0.0/16.
  ```

  > **Salida esperada:** La VPC aparece en AWS Console con el nombre `ckad-crossplane-lab30`.
  {: .lab-note .output .compact}

### Tarea 7.2. Interpretar el Managed Resource

- {% include step_label.html %} Consulta el YAML completo del Managed Resource para distinguir `spec` de `status`.

  > **Importante:** `spec` representa el estado deseado y `status` contiene información observada sobre el recurso externo.
  {: .lab-note .important .compact}

  ```bash
  kubectl get vpc ckad-crossplane-lab30 -n lab30 -o yaml
  ```

  > **Salida esperada:** Se observan `spec.forProvider`, `status.atProvider` y `status.conditions`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Describe la VPC para revisar condiciones y eventos de reconciliación de forma resumida.

  > **Nota:** La descripción permite relacionar eventos del controlador con el ciclo de vida del recurso externo.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe vpc ckad-crossplane-lab30 -n lab30
  ```

  > **Salida esperada:** Se muestran condiciones de sincronización/disponibilidad y eventos asociados a la VPC administrada.
  {: .lab-note .output .compact}

{% capture r7 %}{{ results[6] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r7 %}

{% include support-prompt.html task="tarea7" %}

---

## 🧹 Tarea 8. Eliminar la VPC y limpiar — 4 min

Eliminarás primero el Managed Resource y comprobarás que Crossplane también elimina la VPC real antes de retirar los recursos locales de la práctica.

### Tarea 8.1. Eliminar el recurso administrado

- {% include step_label.html %} Elimina la VPC mediante su manifiesto Kubernetes.

  > **Advertencia:** No elimines primero la VPC desde AWS Console; Crossplane debe procesar su eliminación para demostrar el ciclo de vida completo.
  {: .lab-note .warning .compact}

  ```bash
  kubectl delete -f vpc.yaml
  ```

  > **Salida esperada:** Kubernetes inicia la eliminación de `ckad-crossplane-lab30`; el comando puede esperar mientras Crossplane elimina el recurso externo.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el Managed Resource ya no existe en el namespace `lab30`.

  > **Importante:** La eliminación puede tardar unos segundos porque el finalizer espera la operación de AWS.
  {: .lab-note .important .compact}

  ```bash
  kubectl get vpc ckad-crossplane-lab30 -n lab30 --ignore-not-found
  ```

  > **Salida esperada:** No se muestra la VPC de Crossplane.
  {: .lab-note .output .compact}

### Tarea 8.2. Validar AWS y conservar Crossplane

- {% include step_label.html %} Consulta AWS con el ID guardado para comprobar que la VPC fue eliminada realmente.

  > **Importante:** Esta validación evita dejar infraestructura del laboratorio activa en la cuenta AWS.
  {: .lab-note .important .compact}

  ```bash
  aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region us-west-2
  ```

  > **Salida esperada:** AWS devuelve un error indicando que el VPC ID no existe o no puede encontrarse.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el namespace del laboratorio y confirma que Crossplane permanece disponible como infraestructura compartida.

  > **Nota:** No elimines `crossplane-system`, el Provider AWS EC2 ni el ClusterProviderConfig; pueden reutilizarse en ejercicios posteriores.
  {: .lab-note .info .compact}

  ```bash
  kubectl delete namespace lab30 --wait=true
  ```
  ```bash
  kubectl get pods -n crossplane-system
  ```

  > **Salida esperada:** `lab30` es eliminado y los Pods de Crossplane continúan Running en `crossplane-system`.
  {: .lab-note .output .compact}

{% capture r8 %}{{ results[7] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r8 %}

{% include support-prompt.html task="tarea8" %}