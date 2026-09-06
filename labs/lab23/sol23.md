# Solución del reto — Práctica 23: Monitoreo básico de recursos

## Alcance

Este solucionario cubre únicamente los retos de la Práctica 23.

El objetivo es interpretar consumo observado con `kubectl top` y relacionarlo con:

- `requests`
- `limits`
- CPU
- memoria
- carga real de los Pods
- diferencias entre configuración declarativa y uso observado

> Importante: `kubectl top` muestra consumo observado. `requests` y `limits` son valores declarativos y se consultan desde el Pod o Deployment.

---

## Reto 1. Identificar carga de CPU

### Paso 1. Consultar el consumo de los Pods

```bash
kubectl top pods -n lab23
```

**Resultado esperado:** aparecen los Pods del laboratorio con consumo de CPU y memoria.

Busca el Pod `cpu-load`.

---

### Paso 2. Consultar sus requests y limits

```bash
kubectl get pod cpu-load -n lab23 -o jsonpath='CPU request={.spec.containers[0].resources.requests.cpu} CPU limit={.spec.containers[0].resources.limits.cpu}{"\n"}'
```

**Resultado esperado:**

```text
CPU request=100m CPU limit=500m
```

---

### Paso 3. Comparar uso contra configuración

```bash
kubectl top pod cpu-load -n lab23
```

Interpreta:

```text
Uso observado      -> kubectl top
Request            -> 100m
Limit              -> 500m
```

El reto queda resuelto si identificas que el consumo de CPU puede superar el `request` sin que eso implique error, siempre que el scheduler haya podido ubicar el Pod y el uso permanezca dentro de los mecanismos de control aplicables.

---

## Reto 2. Analizar memoria

### Paso 4. Consultar el Pod `memory-load`

```bash
kubectl top pod memory-load -n lab23
```

### Paso 5. Consultar requests y limits

```bash
kubectl get pod memory-load -n lab23 -o jsonpath='Memory request={.spec.containers[0].resources.requests.memory} Memory limit={.spec.containers[0].resources.limits.memory}{"\n"}'
```

**Resultado esperado:**

```text
Memory request=64Mi Memory limit=256Mi
```

---

### Paso 6. Interpretar el resultado

El proceso consume aproximadamente 120 MiB.

Por tanto:

```text
Request: 64Mi
Uso aproximado: ~120Mi
Limit: 256Mi
```

La interpretación correcta es:

- el Pod puede usar más memoria que su `request`;
- aún está por debajo del `limit`;
- no debe marcarse como falla únicamente por superar el request;
- un `OOMKilled` sería evidencia de presión por encima del límite efectivo del contenedor.

---

## Reto 3. Identificar el mayor consumidor

### Paso 7. Ordenar por CPU

```bash
kubectl top pods -n lab23 --sort-by=cpu
```

**Resultado esperado:** `cpu-load` aparece entre los mayores consumidores de CPU.

---

### Paso 8. Ordenar por memoria

```bash
kubectl top pods -n lab23 --sort-by=memory
```

**Resultado esperado:** `memory-load` aparece entre los mayores consumidores de memoria.

---

## Reto 4. Concluir correctamente

La conclusión esperada debe distinguir:

```text
kubectl top
    ↓
uso observado

requests / limits
    ↓
configuración declarativa
```

No debes interpretar un valor alto como falla por sí mismo.

Debes correlacionar:

```text
uso
+ request
+ limit
+ estado del Pod
+ eventos
```

---

## Validación final

```bash
kubectl top nodes
```

```bash
kubectl top pods -n lab23
```

```bash
kubectl get pods -n lab23
```

El reto está resuelto cuando:

- identificas el Pod con mayor CPU;
- identificas el Pod con mayor memoria;
- comparas consumo contra requests y limits;
- no confundes request con consumo real;
- no interpretas uso elevado como error sin evidencia adicional.

---

## Limpieza

Elimina únicamente el namespace del laboratorio:

```bash
kubectl delete namespace lab23 --wait=true
```

**Importante:** Metrics Server permanece instalado porque forma parte de la infraestructura compartida del clúster.
