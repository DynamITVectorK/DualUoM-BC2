# Issue 203 — DUoM WMS readiness (Warehouse Receipt/Shipment + tracking)

## Objetivo
Definir e implementar la propagación DUoM en flujos warehouse para no perder datos por lote al pasar de tracking a documentos WMS.

## Problema actual
- No hay cobertura DUoM explícita en `Warehouse Receipt Line` y `Warehouse Shipment Line`.
- Riesgo alto en ubicaciones con Directed Put-away & Pick.

## Alcance
1. Diseñar mapa de objetos/eventos WMS donde deben viajar DUoM Ratio/Second Qty.
2. Crear table/page extensions necesarias para warehouse docs.
3. Validar compatibilidad con Location/Zone/Bin y escenarios de múltiples lotes.
4. Mantener compatibilidad SaaS y extensibilidad AL-Go.

## Criterios de aceptación
- DUoM por lote no se pierde en receipt/shipment con tracking.
- Escenarios con bins/zones conservan ratio por lote al contabilizar.
- Sin customizaciones OnPrem ni modificación de objetos base.

## Tests requeridos
- Escenario warehouse receipt con 2 lotes y ratios distintas.
- Escenario warehouse shipment con 2 lotes y ratios distintas.
- Validación E2E hasta ILE por lote.

## Dependencias
- Issue 202 para consistencia de posting.
- Issue 204 para cobertura automatizada.
