#!/usr/bin/env bash
# ------------------------------------------------------------
# Script: create_labs.sh
# Descripción:
#   - Crea la estructura base de prácticas Jekyll en labs/labN/.
#   - Crea automáticamente la carpeta img de cada práctica.
#   - Genera el archivo labN.md con la plantilla actualizada.
#   - Configura prev/next de forma automática.
#   - No sobrescribe prácticas existentes.
#
# Uso:
#   1) Dar permisos de ejecución (solo la primera vez):
#        chmod +x scripts/create_labs.sh
#
#   2) Crear, por ejemplo, 5 prácticas:
#        ./scripts/create_labs.sh 5
# ------------------------------------------------------------

set -euo pipefail

ROOT_DIR="labs"
TOTAL_LABS="${1:-}"

if [[ -z "${TOTAL_LABS}" ]]; then
  echo "Uso: $0 <numero_de_labs>"
  echo "Ejemplo: $0 5"
  exit 1
fi

if ! [[ "${TOTAL_LABS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: <numero_de_labs> debe ser un entero mayor que 0."
  exit 1
fi

mkdir -p "${ROOT_DIR}"

for i in $(seq 1 "${TOTAL_LABS}"); do
  LAB_DIR="${ROOT_DIR}/lab${i}"
  IMG_DIR="${LAB_DIR}/img"
  MD_FILE="${LAB_DIR}/lab${i}.md"

  if [[ "${i}" -eq 1 ]]; then
    PREV_PATH="/"
  else
    PREV_NUM=$((i - 1))
    PREV_PATH="/lab${PREV_NUM}/lab${PREV_NUM}/"
  fi

  if [[ "${i}" -eq "${TOTAL_LABS}" ]]; then
    NEXT_PATH="/"
  else
    NEXT_NUM=$((i + 1))
    NEXT_PATH="/lab${NEXT_NUM}/lab${NEXT_NUM}/"
  fi

  echo "Creando estructura para ${LAB_DIR}..."
  mkdir -p "${IMG_DIR}"

  if [[ -f "${MD_FILE}" ]]; then
    echo "  -> ${MD_FILE} ya existe, se deja sin cambios."
    continue
  fi

  cat > "${MD_FILE}" <<EOF
---
layout: lab
title: "Práctica ${i}: CAMBIAR_AQUI_NOMBRE_DE_LA_PRACTICA"
permalink: /lab${i}/lab${i}/
images_base: /labs/lab${i}/img
duration: "## minutos"
objective:
  - OBJETIVO_DE_LA_PRACTICA
prerequisites:
  - PREREQUISITO_1
  - PREREQUISITO_2
  - PREREQUISITO_3
  - PREREQUISITO_4
  - PREREQUISITO_X
introduction:
  - INTRODUCCION_DE_LA_PRACTICA_BREVE_RESUMEN_EN_UN_SOLO_PARRAFO_RECOMENDADO
slug: lab${i}
lab_number: ${i}
final_result: >
  RESULTADO_FINAL_ESPERADO_DE_LA_PRACTICA_EN_UN_SOLO_PARRAFO_RECOMENDADO
notes:
  - NOTAS_CONSIDERACIONES_ADICIONALES
  - NOTAS_CONSIDERACIONES_ADICIONALES
references:
  - text: DESCRIPCION_DEL_LINK_DE_REFERENCIA
    url: https://developer.hashicorp.com/terraform
  - text: DESCRIPCION_DEL_LINK_DE_REFERENCIA
    url: https://learn.microsoft.com/es-es/cli/azure/
prev: ${PREV_PATH}
next: ${NEXT_PATH}
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 🔎 Tarea 1. NOMBRE DE LA TAREA — ## min

<!-- DESCRIPCION DE LA TAREA: RECOMENDADO 200-250 CARACTERES -->
DESCRIPCION_DE_LA_TAREA.

### Tarea 1.1. NOMBRE DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- {% include step_label.html %} DESCRIPCION_DEL_PASO_1.

  > **Nota:** NOTA_GENERAL_DEL_PASO.
  {: .lab-note .info .compact}

  {% include step_image.html %}

  \`\`\`bash
  CODIGO_DEL_PASO_1
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_1.
  {: .lab-note .output .compact}

- {% include step_label.html %} DESCRIPCION_DEL_PASO_2.

  > **Importante:** CONSIDERACION_IMPORTANTE_DEL_PASO.
  {: .lab-note .important .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_2
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_2.
  {: .lab-note .output .compact}

### Tarea 1.2. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- {% include step_label.html %} DESCRIPCION_DEL_PASO_3.

  > **Advertencia:** ADVERTENCIA_DEL_PASO.
  {: .lab-note .warning .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_3
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_3.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## ☁️ Tarea 2. NOMBRE DE LA TAREA — ## min

<!-- DESCRIPCION DE LA TAREA: RECOMENDADO 200-250 CARACTERES -->
DESCRIPCION_DE_LA_TAREA.

### Tarea 2.1. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- {% include step_label.html %} DESCRIPCION_DEL_PASO_1.

  > **Nota:** NOTA_GENERAL_DEL_PASO.
  {: .lab-note .info .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_1
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_1.
  {: .lab-note .output .compact}

- {% include step_label.html %} DESCRIPCION_DEL_PASO_2.

  > **Importante:** CONSIDERACION_IMPORTANTE_DEL_PASO.
  {: .lab-note .important .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_2
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_2.
  {: .lab-note .output .compact}

### Tarea 2.2. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- {% include step_label.html %} DESCRIPCION_DEL_PASO_3.

  > **Advertencia:** ADVERTENCIA_DEL_PASO.
  {: .lab-note .warning .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_3
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_3.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🚀 Tarea 3. NOMBRE DE LA TAREA — ## min

<!-- DESCRIPCION DE LA TAREA: RECOMENDADO 200-250 CARACTERES -->
DESCRIPCION_DE_LA_TAREA.

### Tarea 3.1. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- {% include step_label.html %} DESCRIPCION_DEL_PASO_1.

  > **Nota:** NOTA_GENERAL_DEL_PASO.
  {: .lab-note .info .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_1
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_1.
  {: .lab-note .output .compact}

- {% include step_label.html %} DESCRIPCION_DEL_PASO_2.

  > **Importante:** CONSIDERACION_IMPORTANTE_DEL_PASO.
  {: .lab-note .important .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_2
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_2.
  {: .lab-note .output .compact}

### Tarea 3.2. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- {% include step_label.html %} DESCRIPCION_DEL_PASO_3.

  > **Advertencia:** ADVERTENCIA_DEL_PASO.
  {: .lab-note .warning .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_3
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_3.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

<!--
NOTAS DE USO DE LA PLANTILLA

1. Cada paso debe tener una descripción clara.
2. Cada paso debe incluir al menos una Nota, Importante o Advertencia cuando aplique.
3. Cada paso con comando debe tener su propio bloque de código.
4. Cada paso debe incluir una Salida esperada usando:
     {: .lab-note .output .compact}
5. Para agregar más tareas:
     - Duplica una sección TAREA.
     - Ajusta el número de tarea y subtareas.
     - Ajusta results[N] usando índice base 0.
     - Ajusta support-prompt.html task="tareaN".
6. Si una práctica no utiliza imágenes, elimina:
     {% include step_image.html %}
-->
EOF

  echo "  -> Creado ${MD_FILE}"
done

echo
echo "Listo. Se generaron las prácticas en ${ROOT_DIR}/"
