# Solución del reto — Práctica 10: Jobs y CronJobs

## Alcance

Este solucionario cubre únicamente el reto de consolidación de la Práctica 10.

El objetivo es demostrar dominio sobre:

- `Job`
- `completions`
- `parallelism`
- reintentos y finalización
- `CronJob`
- creación de Jobs desde un CronJob
- validación del estado `Complete`

---

## Solución del reto

### Paso 1. Crear un Job con varias ejecuciones

Crea `challenge-job.yaml`:

```bash
cat > challenge-job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: challenge-job
  namespace: lab10
spec:
  completions: 4
  parallelism: 2
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: worker
          image: busybox:1.38.0-musl
          command:
            - sh
            - -c
            - echo "Procesando trabajo"; sleep 5; echo "Trabajo finalizado"
  backoffLimit: 2
EOF
```

**Resultado esperado:** se crea el manifiesto de un Job con cuatro completions y paralelismo de dos Pods.

---

### Paso 2. Aplicar el Job

```bash
kubectl apply -f challenge-job.yaml
```

**Resultado esperado:**

```text
job.batch/challenge-job created
```

---

### Paso 3. Observar su ejecución

```bash
kubectl get pods -n lab10 -l job-name=challenge-job -w
```

**Resultado esperado:** se observan Pods ejecutándose en grupos de hasta dos en paralelo.

Finaliza la observación con `Ctrl+C` cuando todos terminen.

---

### Paso 4. Esperar la finalización

```bash
kubectl wait job/challenge-job -n lab10 --for=condition=Complete --timeout=120s
```

**Resultado esperado:** el Job alcanza condición `Complete`.

---

### Paso 5. Validar completions

```bash
kubectl get job challenge-job -n lab10
```

**Resultado esperado:** el Job muestra `4/4` completions.

---

## Crear el CronJob del reto

### Paso 6. Crear `challenge-cronjob.yaml`

```bash
cat > challenge-cronjob.yaml <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: challenge-cron
  namespace: lab10
spec:
  schedule: "*/2 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: task
              image: busybox:1.38.0-musl
              command:
                - sh
                - -c
                - date; echo "Ejecución programada completada"
EOF
```

**Resultado esperado:** se crea un CronJob programado cada dos minutos.

---

### Paso 7. Aplicar el CronJob

```bash
kubectl apply -f challenge-cronjob.yaml
```

**Resultado esperado:**

```text
cronjob.batch/challenge-cron created
```

---

### Paso 8. Validar la programación

```bash
kubectl get cronjob challenge-cron -n lab10
```

**Resultado esperado:** aparece el CronJob y la columna `SCHEDULE` muestra:

```text
*/2 * * * *
```

---

### Paso 9. Crear una ejecución manual desde el CronJob

Para no depender de esperar dos minutos:

```bash
kubectl create job --from=cronjob/challenge-cron challenge-cron-manual -n lab10
```

**Resultado esperado:**

```text
job.batch/challenge-cron-manual created
```

---

### Paso 10. Esperar su finalización

```bash
kubectl wait job/challenge-cron-manual -n lab10 --for=condition=Complete --timeout=60s
```

**Resultado esperado:** el Job manual alcanza condición `Complete`.

---

### Paso 11. Consultar los logs

```bash
kubectl logs job/challenge-cron-manual -n lab10
```

**Resultado esperado:** aparecen la fecha/hora y el mensaje:

```text
Ejecución programada completada
```

---

## Validación final

```bash
kubectl get job challenge-job challenge-cron-manual -n lab10
```

```bash
kubectl get cronjob challenge-cron -n lab10
```

El reto queda resuelto cuando:

- `challenge-job` completa 4 ejecuciones.
- nunca ejecuta más de 2 Pods simultáneamente.
- `challenge-cron` queda programado.
- se crea correctamente un Job a partir del CronJob.
- el Job manual termina con `Complete`.

---

## Limpieza

```bash
kubectl delete namespace lab10 --wait=true
```

**Resultado esperado:** el namespace `lab10` es eliminado.

---

## Resumen

```text
Job
 ├── completions: 4
 └── parallelism: 2

CronJob
 └── crea Jobs según schedule
```

La clave es distinguir que un `Job` representa trabajo finito, mientras que un `CronJob` crea Jobs según una programación.
