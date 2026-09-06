# Solución del reto — Práctica 13: Despliegue con Helm

## Alcance

Este solucionario cubre únicamente el reto de consolidación de Helm.

El objetivo es utilizar un Chart para:

- desplegar una aplicación;
- modificar valores;
- realizar un upgrade;
- provocar una actualización defectuosa;
- revisar el historial;
- ejecutar rollback;
- validar recuperación.

---

## Solución del reto

### Paso 1. Validar el Chart

Desde el directorio del Chart:

```bash
helm lint .
```

**Resultado esperado:**

```text
1 chart(s) linted, 0 chart(s) failed
```

---

### Paso 2. Renderizar antes de instalar

```bash
helm template challenge-release . -n lab13
```

**Resultado esperado:** Helm genera manifiestos Kubernetes sin errores de renderizado.

---

### Paso 3. Instalar el release

```bash
helm upgrade --install challenge-release . -n lab13 --create-namespace
```

**Resultado esperado:** el release queda desplegado.

---

### Paso 4. Validar el estado

```bash
helm status challenge-release -n lab13
```

**Resultado esperado:** `STATUS: deployed`.

---

## Ejecutar un upgrade

### Paso 5. Modificar valores

Ejemplo de valores:

```yaml
replicaCount: 3

image:
  repository: nginx
  tag: 1.31.4-alpine3.24-slim

service:
  port: 8080
```

Guarda los cambios en `values.yaml`.

---

### Paso 6. Aplicar el upgrade

```bash
helm upgrade challenge-release . -n lab13
```

**Resultado esperado:** Helm crea una nueva revisión.

---

### Paso 7. Validar Kubernetes

```bash
kubectl get deployment,service,pods -n lab13
```

**Resultado esperado:**

- 3 réplicas disponibles.
- Service con puerto 8080.
- Pods Running.

---

### Paso 8. Revisar historial

```bash
helm history challenge-release -n lab13
```

**Resultado esperado:** aparecen al menos dos revisiones.

---

## Simular un upgrade defectuoso

### Paso 9. Configurar una imagen inexistente

Modifica temporalmente `values.yaml`:

```yaml
image:
  repository: nginx
  tag: lab13-image-does-not-exist
```

---

### Paso 10. Ejecutar upgrade

```bash
helm upgrade challenge-release . -n lab13
```

**Resultado esperado:** Helm registra una nueva revisión, aunque los Pods pueden entrar en `ImagePullBackOff`.

---

### Paso 11. Confirmar el problema

```bash
kubectl get pods -n lab13
```

**Resultado esperado:** algún Pod de la revisión defectuosa presenta `ErrImagePull` o `ImagePullBackOff`.

---

## Recuperar mediante rollback

### Paso 12. Revisar revisiones

```bash
helm history challenge-release -n lab13
```

Identifica la revisión funcional inmediatamente anterior.

---

### Paso 13. Ejecutar rollback

Sustituye `REVISION` por el número funcional:

```bash
helm rollback challenge-release REVISION -n lab13
```

**Resultado esperado:** Helm crea una nueva revisión basada en la versión anterior.

---

### Paso 14. Validar recuperación

```bash
kubectl rollout status deployment/challenge-release -n lab13 --timeout=60s
```

Si el nombre del Deployment generado por tu Chart difiere, usa el nombre real mostrado por `kubectl get deployment -n lab13`.

---

### Paso 15. Confirmar historial final

```bash
helm history challenge-release -n lab13
```

**Resultado esperado:** se conserva el historial, incluida la revisión defectuosa y la revisión creada por el rollback.

---

## Validación final

El reto queda resuelto cuando:

- el release se instala correctamente;
- un upgrade modifica el estado desplegado;
- una imagen inválida provoca un despliegue defectuoso;
- `helm history` conserva revisiones;
- `helm rollback` recupera una revisión funcional;
- los Pods vuelven a `Running`.

---

## Limpieza

```bash
helm uninstall challenge-release -n lab13
```

```bash
kubectl delete namespace lab13 --ignore-not-found --wait=true
```

---

## Resumen

```text
Chart
  ↓
helm install
  ↓
Revision 1
  ↓
helm upgrade
  ↓
Revision 2
  ↓
upgrade defectuoso
  ↓
Revision 3
  ↓
helm rollback
  ↓
Revision 4 basada en revisión funcional
```

Helm no solo instala recursos: también mantiene historial del release y permite recuperar revisiones anteriores.
