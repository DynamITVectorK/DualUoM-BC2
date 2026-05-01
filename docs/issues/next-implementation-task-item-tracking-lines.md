# Next Implementation Task — DUoM Item Tracking Lines

## Objetivo
Corregir la visibilidad/poblado de campos DUoM en la página estándar **6510 Item Tracking Lines** y cubrirlo con tests automatizados AL.

## Alcance técnico (SaaS, sin modificar base app)
1. Verificar en símbolos BC el **control exacto** (repeater/part) de Page 6510 donde deben anclarse los campos.
2. Ajustar `pageextension 50112 "DUoM Item Tracking Lines"` para insertar `DUoM Ratio` y `DUoM Second Qty` en ese control exacto.
3. Mantener lógica por lote en `Tracking Specification` y cadena estándar `OnAfterCopyTracking*`.
4. No crear `Reservation Entry` manualmente; usar únicamente patrón estándar de eventos/API.

## Criterios de aceptación
- Los campos DUoM son visibles en la UI de Item Tracking Lines en el repeater correcto.
- En lotes con ratio registrada, los campos quedan informados correctamente al validar tracking.
- En modo AlwaysVariable, posting bloquea cuando falta ratio por lote (según política vigente).
- No existe copia ciega de ratio de línea origen a todos los lotes cuando hay ratios distintas.

## Plan de tests AL (mínimo)
1. **Page/UI test**: columnas DUoM visibles en Page 6510 (control correcto).
2. **Purchase multilot**: una línea, dos lotes, ratios distintas.
3. **Item Journal multilot**: una línea, dos lotes, ratios distintas.
4. **Posting**: un ILE por lote con ratio correcta por lote.
5. **Negative AlwaysVariable**: error si falta ratio por lote.
6. **Compliance**: sin creación manual de `Reservation Entry` fuera de patrón estándar.

## Dependencias recomendadas
- `Library Assert`
- `Library - Inventory`
- `Library - Item Tracking` (si está disponible en el entorno)

## Definition of Done
- Código AL + tests en verde en pipeline AL-Go.
- Documentación actualizada en:
  - `docs/03-technical-architecture.md`
  - `docs/05-testing-strategy.md`
  - `docs/06-backlog.md`
  - `docs/09-wms-advanced-design.md`
