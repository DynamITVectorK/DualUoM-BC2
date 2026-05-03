# Issue 201 — DUoM en Page 6510: anclaje correcto y visibilidad funcional

## Objetivo
Garantizar que los campos `DUoM Ratio` y `DUoM Second Qty` se muestran en el repeater/control correcto de la página estándar **6510 Item Tracking Lines** en todos los contextos relevantes.

## Problema actual
- Existe `pageextension` para 6510, pero el anclaje actual (`addafter("Quantity (Base)")`) puede no coincidir con el control visible en determinados contextos.
- Resultado percibido por usuario: columnas no visibles o visibles sin contexto esperado.

## Alcance
1. Verificar en símbolos BC27 el nombre exacto del repeater/control de Page 6510.
2. Reanclar campos DUoM en el contenedor correcto.
3. Revisar que no exista personalización/visibilidad condicional que oculte columnas.
4. Validar comportamiento en compra, venta y diario de producto con tracking.

## Criterios de aceptación
- Los campos DUoM son visibles en la cuadrícula de tracking esperada.
- El usuario puede editar ratio/second qty cuando aplique.
- No se rompe la UX estándar de Item Tracking Lines.

## Tests requeridos
- Test UI/Page: apertura de Item Tracking Lines y presencia de columnas DUoM.
- Test regresión: campos siguen visibles tras validación de `Lot No.` y cambio de `Quantity (Base)`.

## Dependencias
- Símbolos BC27.
- Issue 204 (suite de tests) para cobertura automatizada final.
