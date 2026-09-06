# Solución del reto — Práctica 26: Publicación con Ingress

## Alcance

Este solucionario cubre los retos de la Práctica 26 relacionados con:

- Ingress
- host routing
- path routing
- Traefik
- Gateway API
- `Gateway`
- `HTTPRoute`

Se asume que Traefik y los CRDs de Gateway API ya fueron instalados por la práctica.

---

## Reto 1. Publicar por host con Ingress

### Paso 1. Crear un Ingress para `web`

```bash
cat > web-ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: lab26
spec:
  ingressClassName: traefik
  rules:
    - host: web.lab26.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
EOF
```

```bash
kubectl apply -f web-ingress.yaml
```

---

### Paso 2. Validar el Ingress

```bash
kubectl get ingress web -n lab26
```

---

### Paso 3. Probar por host desde la red kind

Asumiendo Traefik publicado por NodePort 30084:

```bash
docker run --rm --network kind busybox:1.38.0-musl wget -qO- --header='Host: web.lab26.local' http://ckad-control-plane:30084/
```

**Resultado esperado:** responde el backend `web`.

---

## Reto 2. Routing por paths

Se requiere:

```text
apps.lab26.local/
apps.lab26.local/api
```

---

### Paso 4. Crear Ingress con dos paths

```bash
cat > apps-ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: apps
  namespace: lab26
spec:
  ingressClassName: traefik
  rules:
    - host: apps.lab26.local
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
EOF
```

```bash
kubectl apply -f apps-ingress.yaml
```

---

### Paso 5. Probar frontend

```bash
docker run --rm --network kind busybox:1.38.0-musl wget -qO- --header='Host: apps.lab26.local' http://ckad-control-plane:30084/
```

---

### Paso 6. Probar API

```bash
docker run --rm --network kind busybox:1.38.0-musl wget -qO- --header='Host: apps.lab26.local' http://ckad-control-plane:30084/api
```

**Resultado esperado:** cada path llega a su backend correspondiente.

> No se requiere un rewrite propietario. El backend API debe poder responder al path `/api`.

---

## Reto 3. Migrar a Gateway API

### Paso 7. Consultar GatewayClass disponible

```bash
kubectl get gatewayclass
```

Identifica el nombre real administrado por Traefik.

Si en tu instalación aparece:

```text
traefik
```

puedes utilizarlo directamente.

---

### Paso 8. Crear Gateway

```bash
cat > gateway.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: lab26-gateway
  namespace: lab26
spec:
  gatewayClassName: traefik
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: apps-gw.lab26.local
EOF
```

```bash
kubectl apply -f gateway.yaml
```

---

### Paso 9. Crear HTTPRoute

```bash
cat > route.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: apps
  namespace: lab26
spec:
  parentRefs:
    - name: lab26-gateway
  hostnames:
    - apps-gw.lab26.local
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: api
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: frontend
          port: 80
EOF
```

```bash
kubectl apply -f route.yaml
```

---

### Paso 10. Validar estado

```bash
kubectl get gateway,httproute -n lab26
```

```bash
kubectl describe httproute apps -n lab26
```

Busca condiciones aceptadas por el controlador.

---

## Validación final

El reto queda resuelto cuando:

- Ingress enruta por host;
- Ingress enruta por paths;
- Traefik atiende las reglas;
- Gateway API dispone de `Gateway` y `HTTPRoute`;
- la nueva ruta puede expresar el mismo patrón de publicación;
- comprendes que Ingress permanece estable pero congelado, mientras Gateway API es la API extensible para nuevas capacidades.

---

## Limpieza

Elimina solo los recursos del laboratorio:

```bash
kubectl delete namespace lab26 --wait=true
```

**Importante:** Traefik y los CRDs de Gateway API permanecen instalados como infraestructura compartida.
