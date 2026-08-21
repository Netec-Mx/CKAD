---
layout: lab
title: "Práctica 4: Diseño de Pod con init container"
permalink: /lab4/lab4/
images_base: /labs/lab4/img
duration: "45 minutos"
objective:
  - Diseñar, desplegar y diagnosticar un Pod que utilice un init container para preparar contenido antes del inicio del contenedor principal, compartiendo datos mediante un volumen emptyDir y comprobando el orden de inicialización, los logs, el acceso a la aplicación y el comportamiento ante fallos controlados.
prerequisites:
  - Haber completado la Práctica 1 Preparación del entorno CKAD.
  - Haber completado la Práctica 2 Gestión básica con kubectl y YAML.
  - Haber completado la Práctica 3 Construcción y ejecución de una aplicación en Pod.
  - Disponer del clúster kind denominado ckad con el contexto kubectl kind-ckad activo.
  - Trabajar desde Visual Studio Code utilizando Git Bash dentro del directorio local ckad-labs.
introduction:
  - En esta práctica diseñarás un Pod que necesita ejecutar una tarea de inicialización antes de iniciar su aplicación principal. Un init container basado en BusyBox generará contenido dentro de un volumen emptyDir y, solamente después de completar correctamente su trabajo, Kubernetes iniciará un contenedor NGINX que montará el mismo volumen y servirá el archivo generado. Posteriormente provocarás un fallo controlado para observar cómo Kubernetes bloquea el inicio del contenedor principal hasta que la inicialización finaliza correctamente.
slug: lab4
lab_number: 4
final_result: >
  Al finalizar habrás creado un Pod con un init container y un contenedor principal que comparten un volumen emptyDir, comprobado que la inicialización ocurre antes del arranque de la aplicación, consultado de forma independiente los logs y estados de ambos contenedores, validado mediante HTTP el archivo generado durante la inicialización y diagnosticado un escenario de fallo controlado en el que el contenedor principal permanece bloqueado hasta que el init container vuelve a finalizar satisfactoriamente.
notes:
  - Los comandos están diseñados para ejecutarse desde Git Bash en Windows y asumen que el participante comienza desde la raíz de ckad-labs.
  - El init container utiliza busybox:1.38.0-musl y el contenedor principal nginx:1.31.4-alpine3.24-slim para mantener versiones explícitas y reproducibles.
  - El volumen emptyDir existe únicamente durante la vida del Pod; sus datos desaparecen cuando el Pod es eliminado.
  - No se utilizan imágenes personalizadas ni registries externos en esta práctica.
  - Los archivos YAML creados en workspace/lab4 permanecen únicamente en la estación local del participante.
references:
  - text: Conceptos oficiales de Init Containers
    url: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/
  - text: Configurar la inicialización de un Pod
    url: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-initialization/
  - text: Volúmenes Kubernetes y emptyDir
    url: https://kubernetes.io/docs/concepts/storage/volumes/
  - text: Depurar Init Containers
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-init-containers/
  - text: Referencia oficial de kubectl logs
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/
prev: /lab3/lab3/
next: /lab5/lab5/
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 🔎 Tarea 1. Preparar el escenario y el volumen compartido — 6 min

Prepararás un workspace exclusivo y un namespace para aislar los recursos del laboratorio. Después crearás una primera estructura YAML que permita identificar el volumen efímero que compartirán el init container y el contenedor principal.

### Tarea 1.1. Preparar el workspace y el namespace

Crearás el directorio local de trabajo, confirmarás que kubectl apunta al clúster correcto y crearás un namespace independiente para evitar mezclar recursos con otras prácticas.

- {% include step_label.html %} Crea el directorio local `workspace/lab4`, accede a él y confirma la ruta desde la que trabajarás durante toda la práctica.

  > **Nota:** Los manifiestos generados en `workspace/lab4` permanecerán únicamente en tu estación local y podrán utilizarse posteriormente como material de repaso.
  {: .lab-note .info .compact}

  ```bash
  mkdir -p workspace/lab4 && cd workspace/lab4 && pwd
  ```

  > **Salida esperada:** La ruta mostrada termina en `/ckad-labs/workspace/lab4`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Comprueba que el contexto activo sigue siendo `kind-ckad` antes de crear cualquier recurso nuevo en Kubernetes.

  > **Importante:** Todos los comandos de esta práctica deben ejecutarse contra el clúster `ckad`. Si aparece otro contexto, selecciónalo explícitamente antes de continuar.
  {: .lab-note .important .compact}

  ```bash
  kubectl config current-context
  ```

  > **Salida esperada:** El comando devuelve exactamente `kind-ckad`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Crea el namespace `lab4` para aislar el Pod y los objetos utilizados durante el ejercicio.

  > **Advertencia:** Si el namespace ya existe debido a una ejecución anterior incompleta, elimínalo primero o revisa sus recursos antes de reutilizarlo.
  {: .lab-note .warning .compact}

  ```bash
  kubectl create namespace lab4
  ```

  > **Salida esperada:** Kubernetes responde `namespace/lab4 created`.
  {: .lab-note .output .compact}

### Tarea 1.2. Definir la base del Pod y el volumen emptyDir

Crearás un manifiesto inicial con metadatos, un volumen `emptyDir` y la estructura mínima necesaria para compartir archivos entre contenedores que pertenecen al mismo Pod.

- {% include step_label.html %} Crea el archivo `init-web.yaml` con la definición básica del Pod y un volumen `emptyDir` denominado `web-content`.

  > **Nota:** Un volumen `emptyDir` comienza vacío cuando el Pod es asignado a un nodo y puede ser montado por varios contenedores del mismo Pod.
  {: .lab-note .info .compact}

  ```bash
  cat > init-web.yaml <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: init-web
    namespace: lab4
    labels:
      app: init-web
  spec:
    volumes:
      - name: web-content
        emptyDir: {}
  EOF
  ```

  > **Salida esperada:** Se crea `init-web.yaml` sin errores y contiene la definición del volumen `web-content`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta mediante `kubectl explain` la definición del campo `spec.volumes.emptyDir` para relacionar el YAML con el esquema oficial del API Server.

  > **Importante:** Utilizar `kubectl explain` durante el diseño ayuda a verificar nombres y estructuras sin depender de memorizar cada campo del manifiesto.
  {: .lab-note .important .compact}

  ```bash
  kubectl explain pod.spec.volumes.emptyDir
  ```

  > **Salida esperada:** kubectl muestra el tipo y la descripción del volumen `emptyDir`, incluyendo que su vida está asociada al Pod.
  {: .lab-note .output .compact}

- {% include step_label.html %} Revisa el archivo con números de línea y confirma que `volumes` se encuentra dentro de `spec` y que `emptyDir` pertenece al volumen `web-content`.

  > **Advertencia:** YAML depende de la indentación. Un desplazamiento incorrecto puede convertir el documento en una estructura distinta o provocar un error de validación.
  {: .lab-note .warning .compact}

  ```bash
  cat -n init-web.yaml
  ```

  > **Salida esperada:** Se visualizan `apiVersion`, `kind`, `metadata`, `spec`, `volumes`, `name: web-content` y `emptyDir: {}` con indentación coherente.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🧩 Tarea 2. Diseñar el Pod con init container — 10 min

Completarás el manifiesto incorporando un init container que escribirá contenido HTML dentro del volumen compartido y un contenedor NGINX que montará el mismo volumen como raíz de documentos. Finalmente validarás la sintaxis antes de crear el Pod.

### Tarea 2.1. Definir el init container

Agregarás un init container basado en BusyBox cuya única responsabilidad será preparar el archivo que posteriormente consumirá la aplicación principal.

- {% include step_label.html %} Agrega al manifiesto la sección `initContainers` con un contenedor denominado `init-content` que utilice `busybox:1.38.0-musl`.

  > **Nota:** Los init containers se ejecutan antes que los contenedores normales y deben finalizar correctamente para que Kubernetes continúe con el arranque del Pod.
  {: .lab-note .info .compact}

  ```bash
  cat >> init-web.yaml <<'EOF'
    initContainers:
      - name: init-content
        image: busybox:1.38.0-musl
        imagePullPolicy: IfNotPresent
  EOF
  ```

  > **Salida esperada:** `init-web.yaml` incorpora una sección `initContainers` con el contenedor `init-content`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Define el comando del init container para generar un archivo HTML y registrar mensajes visibles posteriormente mediante `kubectl logs`.

  > **Importante:** El comando utiliza `/bin/sh -c` para ejecutar varias instrucciones dentro del contenedor y finaliza con código cero cuando todas se completan correctamente.
  {: .lab-note .important .compact}

  ```bash
  cat >> init-web.yaml <<'EOF'
        command:
          - /bin/sh
          - -c
          - |
            echo "Inicializando contenido..."
            cat > /work-dir/index.html <<'HTML'
            <!DOCTYPE html>
            <html lang="es">
            <head><meta charset="UTF-8"><title>CKAD Lab 4</title></head>
            <body>
              <h1>CKAD Lab 4</h1>
              <p>Contenido preparado por init-content</p>
              <p>Estado: initialization completed</p>
            </body>
            </html>
            HTML
            echo "Archivo generado correctamente."
  EOF
  ```

  > **Salida esperada:** El manifiesto contiene un bloque `command` que escribe `/work-dir/index.html` y genera dos mensajes de inicialización.
  {: .lab-note .output .compact}

- {% include step_label.html %} Monta el volumen `web-content` en `/work-dir` dentro del init container para que el archivo generado permanezca accesible al contenedor principal.

  > **Advertencia:** El nombre del `volumeMount` debe coincidir exactamente con `web-content`; un nombre diferente provoca que Kubernetes rechace el Pod durante la validación.
  {: .lab-note .warning .compact}

  ```bash
  cat >> init-web.yaml <<'EOF'
        volumeMounts:
          - name: web-content
            mountPath: /work-dir
  EOF
  ```

  > **Salida esperada:** El init container contiene un `volumeMount` llamado `web-content` montado en `/work-dir`.
  {: .lab-note .output .compact}

### Tarea 2.2. Definir el contenedor principal y validar YAML

Agregarás el contenedor NGINX, montarás el mismo volumen en su directorio de contenido estático y comprobarás que el manifiesto completo sea aceptado por el API Server.

- {% include step_label.html %} Agrega el contenedor principal `web` basado en NGINX y define explícitamente el puerto HTTP utilizado por la aplicación.

  > **Nota:** El contenedor principal no genera el archivo HTML; únicamente servirá el contenido que haya preparado previamente el init container.
  {: .lab-note .info .compact}

  ```bash
  cat >> init-web.yaml <<'EOF'
    containers:
      - name: web
        image: nginx:1.31.4-alpine3.24-slim
        imagePullPolicy: IfNotPresent
        ports:
          - containerPort: 80
  EOF
  ```

  > **Salida esperada:** Se incorpora el contenedor `web` con la imagen NGINX y `containerPort: 80`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Monta `web-content` en `/usr/share/nginx/html` para que NGINX utilice como contenido web el archivo creado durante la inicialización.

  > **Importante:** Ambos contenedores montan el mismo volumen con nombres idénticos aunque utilicen rutas diferentes; eso permite compartir los mismos datos dentro del Pod.
  {: .lab-note .important .compact}

  ```bash
  cat >> init-web.yaml <<'EOF'
        volumeMounts:
          - name: web-content
            mountPath: /usr/share/nginx/html
  EOF
  ```

  > **Salida esperada:** El contenedor `web` monta `web-content` en `/usr/share/nginx/html`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Solicita al API Server una validación en modo dry-run antes de crear el Pod para detectar errores de esquema, nombres o estructura YAML.

  > **Advertencia:** No continúes si Kubernetes devuelve un error. Corrige el manifiesto antes de aplicar el recurso real.
  {: .lab-note .warning .compact}

  ```bash
  kubectl apply --dry-run=server -f init-web.yaml
  ```

  > **Salida esperada:** Kubernetes responde con un resultado equivalente a `pod/init-web created (server dry run)` sin crear todavía el Pod.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🚀 Tarea 3. Desplegar y observar la inicialización — 9 min

Crearás el Pod y observarás cómo Kubernetes ejecuta primero el init container. Después comprobarás el estado final y utilizarás `describe` y `logs` para distinguir claramente la inicialización del contenedor principal.

### Tarea 3.1. Crear y observar el Pod

Aplicarás el manifiesto y revisarás inmediatamente sus estados para identificar la transición desde la inicialización hasta la ejecución normal.

- {% include step_label.html %} Aplica el manifiesto para crear el Pod `init-web` dentro del namespace `lab4`.

  > **Nota:** Kubernetes comenzará por ejecutar `init-content`; el contenedor NGINX no debe iniciar hasta que la inicialización termine satisfactoriamente.
  {: .lab-note .info .compact}

  ```bash
  kubectl apply -f init-web.yaml
  ```

  > **Salida esperada:** Kubernetes responde `pod/init-web created`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta repetidamente el estado del Pod durante unos segundos para intentar observar la transición de inicialización antes de que el contenedor principal quede disponible.

  > **Importante:** La inicialización puede terminar muy rápido. Dependiendo del equipo podrías observar `Init:0/1`, `PodInitializing` o directamente `Running`.
  {: .lab-note .important .compact}

  ```bash
  for i in {1..8}; do kubectl get pod init-web -n lab4 --no-headers; sleep 1; done
  ```

  > **Salida esperada:** Se muestran varios estados consecutivos del Pod; finalmente debe alcanzar `Running` con `1/1` contenedores Ready.
  {: .lab-note .output .compact}

- {% include step_label.html %} Espera explícitamente la condición `Ready` para confirmar que el init container terminó y que Kubernetes inició correctamente el contenedor principal.

  > **Advertencia:** Si se alcanza el timeout, no elimines inmediatamente el Pod; utiliza los comandos de diagnóstico de la siguiente subtarea.
  {: .lab-note .warning .compact}

  ```bash
  kubectl wait --for=condition=Ready pod/init-web -n lab4 --timeout=60s
  ```

  > **Salida esperada:** kubectl responde `pod/init-web condition met`.
  {: .lab-note .output .compact}

### Tarea 3.2. Inspeccionar estados y logs del init container

Revisarás la descripción del Pod y consultarás directamente los logs del init container para demostrar que su ejecución ocurrió antes del proceso NGINX.

- {% include step_label.html %} Examina el Pod mediante `kubectl describe` y localiza las secciones `Init Containers`, `Containers`, `Conditions` y `Events`.

  > **Nota:** `describe` combina información de configuración, estado y eventos, por lo que resulta especialmente útil para analizar problemas de inicialización.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe pod init-web -n lab4
  ```

  > **Salida esperada:** La sección `Init Containers` muestra `init-content` como terminado exitosamente y la sección `Containers` muestra `web` ejecutándose.
  {: .lab-note .output .compact}

- {% include step_label.html %} Extrae mediante JSONPath la razón y el código de salida del init container para confirmar programáticamente que terminó con éxito.

  > **Importante:** Un init container exitoso debe finalizar con código `0`; Kubernetes conserva esa información dentro de `status.initContainerStatuses`.
  {: .lab-note .important .compact}

  ```bash
  kubectl get pod init-web -n lab4 -o jsonpath='Reason={.status.initContainerStatuses[0].state.terminated.reason} ExitCode={.status.initContainerStatuses[0].state.terminated.exitCode}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Reason=Completed ExitCode=0`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta específicamente los logs de `init-content` para comprobar las acciones realizadas durante la inicialización.

  > **Nota:** Cuando un Pod contiene varios contenedores, la opción `-c` permite seleccionar exactamente qué contenedor debe proporcionar los logs.
  {: .lab-note .info .compact}

  ```bash
  kubectl logs init-web -n lab4 -c init-content
  ```

  > **Salida esperada:** Se muestran `Inicializando contenido...` y `Archivo generado correctamente.`.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🌐 Tarea 4. Validar datos compartidos y acceso a la aplicación — 8 min

Comprobarás desde el contenedor principal que el archivo generado por el init container está disponible en el volumen compartido. Después accederás a NGINX mediante port-forward y revisarás sus logs para validar la cadena completa de ejecución.

### Tarea 4.1. Verificar el contenido compartido

Inspeccionarás el volumen desde el contenedor NGINX y comprobarás que la información servida por la aplicación fue creada durante la fase de inicialización.

- {% include step_label.html %} Lista el directorio `/usr/share/nginx/html` dentro del contenedor principal para confirmar que el volumen contiene el archivo creado previamente.

  > **Nota:** Aunque el init container montó el volumen en `/work-dir`, NGINX observa los mismos datos mediante un punto de montaje diferente.
  {: .lab-note .info .compact}

  ```bash
  kubectl exec -n lab4 init-web -c web -- ls -l /usr/share/nginx/html
  ```

  > **Salida esperada:** Se muestra el archivo `index.html` dentro del directorio de contenido de NGINX.
  {: .lab-note .output .compact}

- {% include step_label.html %} Lee directamente el archivo desde el contenedor principal y verifica que contiene el texto generado por `init-content`.

  > **Importante:** Esta comprobación demuestra que el intercambio ocurre mediante el volumen y no porque la imagen NGINX contenga originalmente el archivo personalizado.
  {: .lab-note .important .compact}

  ```bash
  kubectl exec -n lab4 init-web -c web -- cat /usr/share/nginx/html/index.html
  ```

  > **Salida esperada:** El HTML contiene `CKAD Lab 4`, `Contenido preparado por init-content` y `Estado: initialization completed`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los mounts registrados en el Pod para identificar desde Kubernetes el nombre y la ruta del volumen utilizado por el contenedor principal.

  > **Nota:** JSONPath permite extraer campos concretos del manifiesto activo y comprobar la configuración sin recorrer manualmente todo el YAML.
  {: .lab-note .info .compact}

  ```bash
  kubectl get pod init-web -n lab4 -o jsonpath='Volume={.spec.containers[0].volumeMounts[0].name} MountPath={.spec.containers[0].volumeMounts[0].mountPath}{"\n"}'
  ```

  > **Salida esperada:** Se muestra `Volume=web-content MountPath=/usr/share/nginx/html`.
  {: .lab-note .output .compact}

### Tarea 4.2. Acceder a NGINX y revisar logs

Crearás un túnel temporal hacia el Pod, consultarás la página desde Windows y confirmarás posteriormente que NGINX registró la petición HTTP recibida.

- {% include step_label.html %} Inicia un port-forward en segundo plano desde el puerto local 8080 hacia el puerto 80 del Pod y registra su PID para poder finalizarlo de forma controlada.

  > **Importante:** El proceso debe mantenerse activo mientras realizas la petición HTTP. El PID se guarda únicamente para detener este túnel concreto.
  {: .lab-note .important .compact}

  ```bash
  kubectl port-forward pod/init-web 8080:80 -n lab4 > port-forward.log 2>&1 & echo $! > port-forward.pid
  ```

  > **Salida esperada:** Git Bash recupera el prompt y se crean `port-forward.log` y `port-forward.pid`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Accede mediante `curl` a la aplicación servida desde Kubernetes y finaliza el proceso de port-forward cuando recibas la respuesta.

  > **Nota:** Esta prueba recorre el túnel de kubectl hasta el puerto 80 del contenedor NGINX dentro del Pod.
  {: .lab-note .info .compact}

  ```bash
  sleep 2 && curl -s http://localhost:8080 && kill "$(cat port-forward.pid)"
  ```

  > **Salida esperada:** Se devuelve el HTML generado por el init container, incluyendo `Contenido preparado por init-content`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los logs del contenedor `web` y filtra las solicitudes GET para confirmar que NGINX recibió la petición realizada desde tu estación.

  > **Advertencia:** Especifica `-c web`; sin seleccionar el contenedor podrías obtener resultados ambiguos en Pods con más de un contenedor definido.
  {: .lab-note .warning .compact}

  ```bash
  kubectl logs init-web -n lab4 -c web | grep 'GET /'
  ```

  > **Salida esperada:** Aparece una entrada de acceso HTTP correspondiente a `GET /` con una respuesta satisfactoria, normalmente código `200`.
  {: .lab-note .output .compact}

{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🛠️ Tarea 5. Provocar, diagnosticar y corregir un fallo de inicialización — 12 min

Crearás deliberadamente una variante defectuosa del manifiesto para observar qué ocurre cuando un init container no puede finalizar correctamente. Después utilizarás estado, eventos y logs para diagnosticar el problema, corregirás la configuración y dejarás el clúster limpio.

### Tarea 5.1. Introducir un fallo controlado

Guardarás una copia funcional, modificarás temporalmente el comando del init container y recrearás el Pod para comprobar que Kubernetes evita iniciar NGINX mientras la inicialización falla.

- {% include step_label.html %} Conserva una copia del manifiesto funcional denominada `init-web-working.yaml` antes de introducir el error controlado.

  > **Nota:** Mantener una versión conocida como correcta permite comparar y recuperar rápidamente el estado original después del ejercicio de troubleshooting.
  {: .lab-note .info .compact}

  ```bash
  cp init-web.yaml init-web-working.yaml
  ```

  > **Salida esperada:** Se crea `init-web-working.yaml` sin modificar el manifiesto original.
  {: .lab-note .output .compact}

- {% include step_label.html %} Inserta `exit 1` después del primer mensaje del init container para provocar deliberadamente una terminación no exitosa.

  > **Advertencia:** Este fallo es intencional y debe realizarse únicamente sobre la copia de trabajo de esta práctica. Kubernetes reintentará el init container mientras continúe devolviendo código distinto de cero.
  {: .lab-note .warning .compact}

  ```bash
  sed -i '/echo "Inicializando contenido..."/a\          exit 1' init-web.yaml
  ```

  > **Salida esperada:** `init-web.yaml` contiene ahora una línea `exit 1` dentro del bloque de comandos de `init-content`.
  {: .lab-note .output .compact}

- {% include step_label.html %} Elimina el Pod funcional, créalo nuevamente con la configuración defectuosa y espera unos segundos para permitir que Kubernetes registre varios intentos de inicialización.

  > **Importante:** El contenedor principal `web` no debe iniciar mientras `init-content` continúe fallando; este comportamiento garantiza que las precondiciones del Pod se cumplan antes de iniciar la aplicación.
  {: .lab-note .important .compact}

  ```bash
  kubectl delete pod init-web -n lab4 --wait=true && kubectl apply -f init-web.yaml && sleep 8 && kubectl get pod init-web -n lab4
  ```

  > **Salida esperada:** El Pod permanece en un estado de inicialización con un valor semejante a `Init:Error` o `Init:CrashLoopBackOff` en lugar de alcanzar `Running`.
  {: .lab-note .output .compact}

### Tarea 5.2. Diagnosticar, reparar y limpiar

Analizarás el fallo utilizando tres fuentes de evidencia, restaurarás el manifiesto funcional y verificarás nuevamente el Pod antes de eliminar todos los recursos activos del laboratorio.

- {% include step_label.html %} Consulta el estado de los contenedores y los eventos recientes para confirmar que el problema se origina específicamente en `init-content`.

  > **Nota:** En troubleshooting conviene combinar estado y eventos: uno indica qué está ocurriendo y el otro aporta contexto sobre intentos, reinicios y decisiones de Kubernetes.
  {: .lab-note .info .compact}

  ```bash
  kubectl describe pod init-web -n lab4
  ```

  > **Salida esperada:** `Init Containers` muestra terminaciones fallidas o reinicios para `init-content`, mientras `web` todavía no aparece iniciado normalmente.
  {: .lab-note .output .compact}

- {% include step_label.html %} Consulta los logs actuales y anteriores del init container para identificar el punto exacto donde termina la inicialización defectuosa.

  > **Importante:** `--previous` permite recuperar los logs de la instancia anterior del contenedor cuando Kubernetes ya realizó un reinicio; resulta muy útil durante estados de tipo CrashLoopBackOff.
  {: .lab-note .important .compact}

  ```bash
  kubectl logs init-web -n lab4 -c init-content --previous 2>/dev/null || kubectl logs init-web -n lab4 -c init-content
  ```

  > **Salida esperada:** Los logs muestran `Inicializando contenido...` pero no `Archivo generado correctamente.`, confirmando que el proceso finaliza antes de completar su trabajo.
  {: .lab-note .output .compact}

- {% include step_label.html %} Restaura el manifiesto funcional, recrea el Pod, espera hasta que esté Ready, confirma el resultado y elimina finalmente el namespace `lab4`.

  > **Advertencia:** La limpieza elimina únicamente recursos Kubernetes del laboratorio. Conserva `init-web.yaml` e `init-web-working.yaml` en tu workspace local para revisión posterior.
  {: .lab-note .warning .compact}

  ```bash
  cp init-web-working.yaml init-web.yaml && kubectl delete pod init-web -n lab4 --wait=true && kubectl apply -f init-web.yaml && kubectl wait --for=condition=Ready pod/init-web -n lab4 --timeout=60s && kubectl get pod init-web -n lab4 && kubectl delete namespace lab4 --wait=true
  ```

  > **Salida esperada:** El Pod restaurado alcanza `Running` con `1/1` Ready y posteriormente Kubernetes responde `namespace "lab4" deleted`.
  {: .lab-note .output .compact}

{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}