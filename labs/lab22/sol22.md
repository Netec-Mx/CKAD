# Solución del reto — Práctica 22: Depuración de aplicaciones fallidas

## Alcance

Este solucionario cubre los escenarios de reto de troubleshooting.

Método recomendado:

```text
Síntoma
  ↓
get
  ↓
describe / events / logs
  ↓
causa raíz
  ↓
corrección mínima
  ↓
validación
```

---

# Reto 1. Imagen inexistente

## Paso 1. Observar el frontend

```bash
kubectl get pods -n lab22
```

Busca un Pod del frontend en `ErrImagePull` o `ImagePullBackOff`.

## Paso 2. Revisar eventos

```bash
kubectl describe pod -n lab22 -l app=frontend
```

La causa esperada es una imagen inexistente.

## Paso 3. Corregir la imagen

```bash
kubectl set image deployment/frontend nginx=nginx:1.31.4-alpine3.24-slim -n lab22
```

## Paso 4. Validar

```bash
kubectl rollout status deployment/frontend -n lab22 --timeout=60s
```

---

# Reto 2. Proceso que reinicia

## Paso 5. Observar `worker`

```bash
kubectl get pods -n lab22 -l app=worker
```

## Paso 6. Consultar logs

```bash
kubectl logs deployment/worker -n lab22
```

## Paso 7. Consultar logs anteriores

```bash
kubectl logs deployment/worker -n lab22 --previous
```

La evidencia esperada incluye:

```text
ERROR queue configuration invalid
```

## Paso 8. Corregir el comando

La solución mínima es sustituir el proceso defectuoso por uno estable.

```bash
kubectl patch deployment worker -n lab22 --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/command","value":["sh","-c","echo worker-ready; sleep 3600"]}]'
```

## Paso 9. Validar estabilidad

```bash
kubectl rollout status deployment/worker -n lab22 --timeout=60s
```

---

# Reto 3. ConfigMap con clave incorrecta

El Pod espera:

```text
APP_ENVIRONMENT
```

pero el ConfigMap proporciona:

```text
APP_ENV
```

## Paso 10. Inspeccionar Deployment y ConfigMap

```bash
kubectl get deployment config-api -n lab22 -o yaml
```

```bash
kubectl get configmap -n lab22 -o yaml
```

## Paso 11. Corregir la referencia

Ajusta el `configMapKeyRef.key` del Deployment para utilizar la clave realmente existente:

```bash
kubectl patch deployment config-api -n lab22 --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/configMapKeyRef/key","value":"APP_ENV"}]'
```

## Paso 12. Validar

```bash
kubectl rollout status deployment/config-api -n lab22 --timeout=60s
```

---

# Reto 4. Readiness defectuosa

## Paso 13. Observar `web-health`

```bash
kubectl get pods -n lab22 -l app=web-health
```

El Pod puede estar `Running` pero `0/1 Ready`.

## Paso 14. Revisar la probe

```bash
kubectl describe pod -n lab22 -l app=web-health
```

La ruta defectuosa es `/healthz`.

## Paso 15. Corregir a `/`

```bash
kubectl patch deployment web-health -n lab22 --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```

## Paso 16. Validar Ready

```bash
kubectl rollout status deployment/web-health -n lab22 --timeout=60s
```

---

# Reto 5. Aplicación multicapa sin conectividad

El backend tiene Pods con:

```text
app=backend
```

pero el Service utiliza:

```text
app=backend-api
```

## Paso 17. Revisar Service

```bash
kubectl get service backend -n lab22 -o yaml
```

## Paso 18. Revisar Pods

```bash
kubectl get pods -n lab22 --show-labels
```

## Paso 19. Revisar EndpointSlices

```bash
kubectl get endpointslices -n lab22 -l kubernetes.io/service-name=backend
```

**Resultado esperado:** el Service no tiene backends Ready útiles porque el selector no coincide.

## Paso 20. Corregir selector

```bash
kubectl patch service backend -n lab22 -p '{"spec":{"selector":{"app":"backend"}}}'
```

## Paso 21. Validar EndpointSlices

```bash
kubectl get endpointslices -n lab22 -l kubernetes.io/service-name=backend
```

Ahora deben aparecer los Pods backend.

## Paso 22. Probar conectividad

Desde el cliente creado por la práctica:

```bash
kubectl exec -n lab22 deploy/frontend -- wget -qO- http://backend
```

Si el recurso cliente tiene otro nombre, utiliza el Pod/Deployment definido en tu práctica.

---

# Validación final

El reto está resuelto cuando:

- frontend deja de presentar ImagePullBackOff;
- worker deja de reiniciarse;
- config-api carga correctamente la configuración;
- web-health está Running y Ready;
- backend Service dispone de endpoints;
- la comunicación multicapa funciona.

---

## Limpieza

```bash
kubectl delete namespace lab22 --wait=true
```

Conserva los manifiestos locales en `workspace/lab22`.
