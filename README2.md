# Certified Kubernetes Application Developer

Este curso prepara al participante para cubrir de forma integral los temas requeridos por la certificación Certified Kubernetes Application Developer - CKAD, con un enfoque práctico orientado al diseño, despliegue, configuración, mantenimiento y depuración de aplicaciones sobre Kubernetes. Durante el curso, el participante trabajará con Pods, Deployments, Jobs, CronJobs, Helm, Kustomize, ConfigMaps, Secrets, ServiceAccounts, RBAC básico, recursos, SecurityContexts, probes, logs, Services, Ingress y NetworkPolicies.

Adicionalmente, se incorpora una introducción aplicada a Argo CD, Crossplane y Kafka para que el participante reconozca cómo estas tecnologías se integran en plataformas Kubernetes modernas. El alcance de estos temas es introductorio y práctico: se revisan conceptos clave, casos de uso y ejercicios guiados, sin profundizar en operación avanzada, alta disponibilidad, seguridad empresarial, tuning o arquitectura productiva.

## Estructura

- `CapituloXX/README.md`: guía de laboratorio por capítulo.

## Lista de laboratorios

### Capítulo 1

- [Preparación del entorno CKAD](Capitulo01/README.md#preparación-del-entorno-ckad)
  - Descripción: Preparar el entorno de trabajo para los ejercicios CKAD y dejar disponible la operación básica sobre Kubernetes requerida en el capítulo.
  - Duración estimada: 45 min
- [Gestión básica con kubectl y YAML](Capitulo01/README.md#gestión-básica-con-kubectl-y-yaml)
  - Descripción: Gestionar recursos básicos de Kubernetes mediante kubectl y manifiestos YAML, utilizando los fundamentos operativos revisados en el capítulo.
  - Duración estimada: 45 min

### Capítulo 2

- [Construcción y ejecución de una aplicación en Pod](Capitulo02/README.md#construcción-y-ejecución-de-una-aplicación-en-pod)
  - Descripción: Construir y ejecutar una aplicación dentro de un Pod, aplicando imágenes, comandos, argumentos y variables de entorno revisados en el capítulo.
  - Duración estimada: 45 min
- [Diseño de Pod con init container](Capitulo02/README.md#diseño-de-pod-con-init-container)
  - Descripción: Diseñar un Pod que incorpore un init container para preparar una condición o recurso requerido antes de iniciar el contenedor principal.
  - Duración estimada: 45 min
- [Diseño de Pod con patrón sidecar](Capitulo02/README.md#diseño-de-pod-con-patrón-sidecar)
  - Descripción: Diseñar un Pod multi-contenedor que aplique el patrón sidecar y la coordinación básica entre contenedores.
  - Duración estimada: 50 min
- [Uso de volúmenes efímeros y persistentes](Capitulo02/README.md#uso-de-volúmenes-efímeros-y-persistentes)
  - Descripción: Configurar y utilizar volúmenes efímeros y persistentes en aplicaciones, incluyendo emptyDir, PV y PVC.
  - Duración estimada: 65 min
- [Personalización con Kustomize](Capitulo02/README.md#personalización-con-kustomize)
  - Descripción: Personalizar manifiestos de Kubernetes con Kustomize a partir de los conceptos esenciales revisados en el capítulo.
  - Duración estimada: 55 min

### Capítulo 3

- [Despliegue de aplicación con Deployment](Capitulo03/README.md#despliegue-de-aplicación-con-deployment)
  - Descripción: Desplegar una aplicación utilizando un Deployment y su relación con ReplicaSet como base del workload.
  - Duración estimada: 45 min
- [Rolling update y rollback](Capitulo03/README.md#rolling-update-y-rollback)
  - Descripción: Ejecutar una actualización rolling y un rollback sobre una aplicación desplegada en Kubernetes.
  - Duración estimada: 45 min
- [Jobs y CronJobs](Capitulo03/README.md#jobs-y-cronjobs)
  - Descripción: Configurar y ejecutar cargas de trabajo mediante Jobs y CronJobs de acuerdo con su propósito operativo.
  - Duración estimada: 40 min
- [Estrategia blue/green](Capitulo03/README.md#estrategia-bluegreen)
  - Descripción: Implementar una estrategia de despliegue blue/green utilizando primitivas de Kubernetes.
  - Duración estimada: 40 min
- [Estrategia canary](Capitulo03/README.md#estrategia-canary)
  - Descripción: Implementar una estrategia de despliegue canary utilizando primitivas de Kubernetes.
  - Duración estimada: 40 min
- [Despliegue con Helm](Capitulo03/README.md#despliegue-con-helm)
  - Descripción: Desplegar una aplicación con Helm utilizando instalación, values y personalización básica.
  - Duración estimada: 45 min

### Capítulo 4

- [Configuración de aplicaciones con ConfigMaps](Capitulo04/README.md#configuración-de-aplicaciones-con-configmaps)
  - Descripción: Configurar una aplicación con ConfigMaps y consumir la configuración mediante variables de entorno o archivos.
  - Duración estimada: 45 min
- [Manejo de información sensible con Secrets](Capitulo04/README.md#manejo-de-información-sensible-con-secrets)
  - Descripción: Configurar y consumir información sensible mediante Secrets de Kubernetes de acuerdo con el contenido del capítulo.
  - Duración estimada: 45 min
- [ServiceAccount y permisos mínimos](Capitulo04/README.md#serviceaccount-y-permisos-mínimos)
  - Descripción: Configurar una ServiceAccount y permisos RBAC básicos con el criterio de permisos mínimos para una aplicación.
  - Duración estimada: 50 min
- [Control de recursos de aplicaciones](Capitulo04/README.md#control-de-recursos-de-aplicaciones)
  - Descripción: Aplicar requests, limits, ResourceQuota y LimitRange para controlar el consumo de recursos de aplicaciones.
  - Duración estimada: 55 min
- [Endurecimiento básico de Pods](Capitulo04/README.md#endurecimiento-básico-de-pods)
  - Descripción: Aplicar controles básicos de endurecimiento de Pods mediante SecurityContext, ejecución no root, filesystem de solo lectura y capabilities.
  - Duración estimada: 70 min
- [Consumo básico de CRD desde kubectl](Capitulo04/README.md#consumo-básico-de-crd-desde-kubectl)
  - Descripción: Consumir de forma básica un recurso definido mediante CRD usando kubectl desde la perspectiva del desarrollador.
  - Duración estimada: 35 min

### Capítulo 5

- [Implementación de probes](Capitulo05/README.md#implementación-de-probes)
  - Descripción: Implementar probes readiness, liveness y startup para validar salud y disponibilidad de aplicaciones.
  - Duración estimada: 40 min
- [Análisis de logs y eventos](Capitulo05/README.md#análisis-de-logs-y-eventos)
  - Descripción: Analizar logs y eventos de Pods y contenedores para identificar información relevante de operación y diagnóstico.
  - Duración estimada: 40 min
- [Depuración de aplicaciones fallidas](Capitulo05/README.md#depuración-de-aplicaciones-fallidas)
  - Descripción: Depurar aplicaciones fallidas mediante el análisis de Pods, Deployments, imágenes, configuración, volúmenes y acceso.
  - Duración estimada: 70 min
- [Monitoreo básico de recursos](Capitulo05/README.md#monitoreo-básico-de-recursos)
  - Descripción: Monitorear recursos de Kubernetes con kubectl top y las métricas disponibles en el entorno.
  - Duración estimada: 35 min

### Capítulo 6

- [Exposición interna con Service ClusterIP](Capitulo06/README.md#exposición-interna-con-service-clusterip)
  - Descripción: Exponer una aplicación internamente mediante un Service de tipo ClusterIP y validar su acceso dentro del clúster.
  - Duración estimada: 35 min
- [Exposición externa básica](Capitulo06/README.md#exposición-externa-básica)
  - Descripción: Configurar una exposición externa básica de una aplicación usando los tipos de Service revisados en el capítulo.
  - Duración estimada: 30 min
- [Publicación con Ingress](Capitulo06/README.md#publicación-con-ingress)
  - Descripción: Publicar una aplicación mediante Ingress utilizando reglas de host, path y exposición HTTP.
  - Duración estimada: 45 min
- [Restricción de tráfico con NetworkPolicy](Capitulo06/README.md#restricción-de-tráfico-con-networkpolicy)
  - Descripción: Aplicar una NetworkPolicy para restringir tráfico ingress o egress y establecer aislamiento básico entre Pods.
  - Duración estimada: 50 min
- [Troubleshooting de conectividad](Capitulo06/README.md#troubleshooting-de-conectividad)
  - Descripción: Diagnosticar problemas de conectividad relacionados con Services, endpoints, DNS, Ingress y políticas de red.
  - Duración estimada: 30 min

### Capítulo 7

- [Publicar una aplicación con Argo CD usando manifiestos Kubernetes](Capitulo07/README.md#publicar-una-aplicación-con-argo-cd-usando-manifiestos-kubernetes)
  - Descripción: Publicar una aplicación con Argo CD a partir de manifiestos Kubernetes y validar conceptos esenciales de GitOps, sync, health y drift.
  - Duración estimada: 55 min
- [Consumir un recurso gestionado con Crossplane de forma básica](Capitulo07/README.md#consumir-un-recurso-gestionado-con-crossplane-de-forma-básica)
  - Descripción: Consumir de forma básica un recurso gestionado con Crossplane y validar su estado desde Kubernetes mediante sus APIs declarativas.
  - Duración estimada: 45 min
- [Desplegar Kafka básico y validar producer/consumer](Capitulo07/README.md#desplegar-kafka-básico-y-validar-producerconsumer)
  - Descripción: Desplegar una configuración básica de Kafka en Kubernetes y validar la comunicación entre producer y consumer.
  - Duración estimada: 60 min
- [Mini-proyecto integrador CKAD + Argo CD + Kafka + Crossplane](Capitulo07/README.md#mini-proyecto-integrador-ckad-argo-cd-kafka-crossplane)
  - Descripción: Integrar conocimientos CKAD con Argo CD, Kafka y Crossplane en un mini-proyecto práctico que combine los componentes introductorios revisados en el capítulo.
  - Duración estimada: 35 min

## Flujo de colaboración

- Trabajar en `changes_course`.
- Crear Pull Request hacia `main`.
- Merge por `Squash and merge`.
