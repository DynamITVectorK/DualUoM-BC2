# DUoM Item Tracking Lines Technical Analysis

## 1. Executive summary

- Los campos DUoM **sí existen** en los objetos clave de línea y posting (Purchase Line, Sales Line, Item Journal Line, Tracking Specification, Reservation Entry, Item Ledger Entry y líneas históricas de compra/venta), y existe tabla propia de ratio por lote (`DUoM Lot Ratio`).
- El motivo más probable de que “no aparezcan” en Item Tracking Lines no es ausencia de campos en `Tracking Specification`, sino un problema de **anclaje de layout en pageextension**: actualmente se usa `addafter("Quantity (Base)")`; si ese control no está en el repeater visible en el contexto real de ejecución, los campos pueden no renderizarse donde el usuario espera.
- La arquitectura actual ya reconoce el modelo correcto **1 línea origen = N lotes** y evita, en gran parte, la suposición 1:1, especialmente en la cadena `Tracking Specification -> Item Journal Line -> Item Ledger Entry`.
- Hay un gap para WMS avanzado: no hay extensiones DUoM en Warehouse Receipt/Shipment Line y no se ha cerrado la estrategia end-to-end para tracking en documentos warehouse.

## 2. Root cause hypothesis

Hipótesis principal (prioridad alta):
1. Los campos DUoM están en tabla 6500 (`Tracking Specification`) y existe una `pageextension` de la página 6510, pero el `addafter("Quantity (Base)")` puede no estar apuntando al control correcto del repeater en la variante de página que el usuario abre (o no en el contenedor esperado).
2. Si el control target no coincide exactamente con el control de la vista activa, los campos pueden no verse aunque compilen.
3. En paralelo, si el usuario espera visibilidad en un flujo warehouse específico, el origen puede ser funcional (flujo/objeto distinto) y no solo visual.

Hipótesis secundaria:
- La propagación DUoM desde `Reservation Entry` a `Tracking Specification` depende de eventos estándar y del momento de copia; en determinados flujos puede llegar ratio `0` y verse columnas vacías. Esto no impide que las columnas existan, pero sí que parezcan “no funcionando”.


## 2.1 Respuesta directa: por qué no aparecen correctamente informados al abrir la página

- **Sí aparecen como columnas (cuando el layout las renderiza), pero pueden abrirse sin valor** porque el valor DUoM por lote se calcula/copia al validar tracking (`Lot No.`, `Quantity (Base)` y cadena `OnAfterCopyTracking*`). Si el lote no tiene ratio registrada o el flujo no ha copiado todavía desde reservation/tracking, se verá `DUoM Ratio = 0` y `DUoM Second Qty = 0`.
- Además, existe riesgo de **anclaje de control** en la `pageextension` (`addafter("Quantity (Base)")`): si no apunta al repeater/control exacto del contexto activo, el usuario puede percibir que “no aparecen” o que aparecen fuera del bloque esperado.

## 2.2 Respuesta directa: ¿se han hecho tests?

- **Sí**: existen tests AL de tracking y multilot en `DUoM Item Tracking Tests` (T01–T07), incluyendo:
  - prefill de ratio por lote al validar `Lot No.`,
  - recálculo con `Quantity (Base)`,
  - E2E tracking→posting→ILE,
  - escenario explícito `1 línea = N lotes` con ratios distintas por lote.
- **No** hay evidencia en este repositorio de un test UI automatizado que valide directamente la visibilidad de columnas en la Page 6510 (solo lógica y posting).

## 3. Current implementation findings

### 3.1 Cobertura de campos DUoM por tabla solicitada

**Sí existen DUoM fields:**
- Purchase Line (`DUoM Purchase Line Ext`).
- Sales Line (`DUoM Sales Line Ext`).
- Item Journal Line (`DUoM Item Journal Line Ext`).
- Tracking Specification (`DUoM Tracking Spec Ext`).
- Reservation Entry (`DUoM Reservation Entry Ext`).
- Item Ledger Entry (`DUoM Item Ledger Entry Ext`).
- Históricos de compras: Purch. Rcpt. Line, Purch. Inv. Line, Purch. Cr. Memo Line.
- Históricos de ventas: Sales Shipment Line, Sales Invoice Line, Sales Cr.Memo Line.
- Tabla propia de ratio por lote: `DUoM Lot Ratio`.

**No encontrados (gap actual):**
- Extensiones DUoM para `Warehouse Receipt Line` y `Warehouse Shipment Line`.

### 3.2 Página estándar 6510 “Item Tracking Lines”

- Existe `pageextension 50112 "DUoM Item Tracking Lines" extends "Item Tracking Lines"`.
- Añade campos `DUoM Ratio` y `DUoM Second Qty` con `addafter("Quantity (Base)")`.
- No hay señales de `Visible = false` ni ocultación condicional que explique desaparición permanente.
- Conclusión: el riesgo está en **ubicación/layout target** más que en visibilidad explícita.

### 3.3 Table 336/6500 “Tracking Specification”

- Existe tableextension con ambos campos DUoM.
- Incluye trigger `OnValidate` en `DUoM Ratio` con recálculo de `DUoM Second Qty` (excepto lógica especial `AlwaysVariable`).
- Si estos campos no existieran en 6500, la página 6510 (que trabaja con tracking spec) no podría bindear datos por línea de tracking; por eso su presencia es condición necesaria para mostrar/editar DUoM por lote.

### 3.4 Table 337 “Reservation Entry”

- Existen campos DUoM, pero la propia solución documenta que la propagación automática total está limitada por firma de evento en BC27 para ciertos puntos (sin `var Rec` modificable en uno de los eventos mencionados en comentarios).
- Sí hay subscriber estándar útil: `TrackingSpecification.OnAfterCopyTrackingFromReservEntry`, donde se copian DUoM Ratio/Second Qty de Reservation a Tracking Spec.
- Recomendación: mantener patrón estándar por eventos de copia tracking; **no crear Reservation Entry manualmente**.

### 3.5 Flujo posting y split por lote

La solución implementa el patrón correcto de BC:
- `Tracking Specification -> Item Journal Line` (`OnAfterCopyTrackingFromSpec`).
- `Item Journal Line -> Item Ledger Entry` (`OnAfterCopyTrackingFromItemJnlLine`).
- Además fallback en `OnAfterInitItemLedgEntry` de `Item Jnl.-Post Line`.

Esto apunta a modelo N-lotes. También se documenta prioridad de ratio de lote sobre ratio de línea en varios puntos.

## 4. Missing fields or missing page extensions

1. **No falta pageextension** para 6510: ya existe.
2. **No faltan campos** en `Tracking Specification` para renderizar columnas.
3. **Sí faltan extensiones warehouse** (`Warehouse Receipt Line`, `Warehouse Shipment Line`) para cobertura funcional integral WMS.
4. Posible causa de UI: target de `addafter("Quantity (Base)")` no alineado con el control real/repeater visible en todos los contextos.

## 5. Required Business Central objects

Para cerrar correctamente el alcance SaaS sin tocar base objects:
- Mantener/ajustar:
  - `tableextension` sobre `Tracking Specification`.
  - `pageextension` sobre `Item Tracking Lines` (revisar anclaje exacto de control en símbolos).
  - `tableextension` sobre `Reservation Entry`.
  - Subscribers en eventos `OnAfterCopyTracking*`.
- Añadir en siguiente fase (WMS):
  - `tableextension` para `Warehouse Receipt Line`.
  - `tableextension` para `Warehouse Shipment Line`.
  - (si procede) `pageextension` de subforms warehouse para captura/visualización.

## 6. Required events and extension points

Priorizar eventos estándar ya usados por BC tracking framework:
- `Tracking Specification`.`OnAfterCopyTrackingFromReservEntry`.
- `Item Journal Line`.`OnAfterCopyTrackingFromSpec`.
- `Item Ledger Entry`.`OnAfterCopyTrackingFromItemJnlLine`.
- `Item Journal Line`.`OnAfterCopyTrackingFromItemLedgEntry`.
- `Item Jnl.-Post Line`.`OnAfterInitItemLedgEntry` (fallback/control adicional).

Para UI tracking:
- Eventos de validación en tabla `Tracking Specification` (`Lot No.`, `Quantity (Base)`) para recálculo por lote.

## 7. Data propagation design

Diseño recomendado (coherente con lo existente):
1. Captura ratio real en **tracking line** (no en línea origen).
2. Copia estándar de tracking data vía `OnAfterCopyTracking*` durante split.
3. Cada split IJL conserva ratio de su lote.
4. Cada ILE toma ratio de su lote (o fallback controlado).
5. Línea origen conserva rol agregado/documental (nunca fuente única para N lotes).

Regla obligatoria:
- `1 Source Line = N Tracking Lines = N Split Item Journal Lines = N Item Ledger Entries`.

## 8. Posting impact

- Riesgo actual identificado: aún existen puntos que copian DUoM desde Purchase/Sales Line a IJL al inicio del posting. Eso es válido como valor inicial/agregado, pero debe ser siempre sobreescrito/refinado por tracking en flujos con lotes.
- Buenas señales: subscribers de tracking copy ya contemplan refinamiento por lote y prioridad de ratio por lote.
- Punto a validar en pruebas: que no quede ningún flujo donde ratio de línea origen se “clone ciego” a todos los lotes cuando sí hay ratios distintos por lote.

## 9. Warehouse/WMS impact

Compatibilidad objetivo (receipt, shipment, location, zone, bin, Directed Put-away & Pick):
- Si la captura DUoM por lote se concentra en Item Tracking Lines, el diseño es conceptualmente correcto.
- Pero en WMS avanzado hay riesgo de huecos si warehouse docs/lines no transportan DUoM en pasos intermedios.
- Riesgos principales:
  1. Desalineación entre captura en tracking y documentos warehouse.
  2. Pérdida de ratio al pasar por picks/movements si no hay campos/extensiones en objetos warehouse implicados.
  3. Escenarios bin/zone con múltiples lotes en una misma actividad requieren pruebas específicas de conservación por lote.

## 10. Test plan

Plan AL tests (priorizando libraries estándar BC):
1. **Schema/metadata tests**
   - Verificar que `Tracking Specification` tiene `DUoM Ratio` y `DUoM Second Qty`.
2. **UI/page tests Item Tracking Lines**
   - Verificar que los campos están en Page 6510 y visibles en repeater esperado.
3. **Purchase multilot test**
   - Línea compra 10 KG.
   - Lote A/B con ratios distintos.
   - Confirmar split/propagación por lote y no copia ciega.
4. **Item Journal multilot test**
   - Mismo patrón con dos lotes y ratios distintos.
5. **Posting outcome tests**
   - 1 ILE por lote con ratio DUoM correcta por lote.
6. **Negative rule test (AlwaysVariable)**
   - Bloquear posting cuando falte ratio por lote en modo always-variable.
7. **Compliance test**
   - Asegurar que no se crean reservas manualmente fuera de APIs/eventos estándar.

Libraries sugeridas: `Library Assert`, `Library - Inventory` y libraries estándar de posting/tracking disponibles en entorno de test.

## 11. Documentation updates required

Actualizar al menos:
- `docs/03-technical-architecture.md`
- `docs/05-testing-strategy.md`
- `docs/06-backlog.md`
- `docs/09-wms-advanced-design.md`
- issue docs de lot ratio/tracking ya existentes (especialmente `issue-22`, `issue-20`, `issue-21`, `issue-P2-wms-advanced-blueprint`).

Mensaje clave obligatorio en documentación:
- La línea origen es agregada.
- La ratio real DUoM pertenece al lote/tracking line.
- No existe relación 1:1 línea documental-lote.

## 12. Recommended implementation plan

Fase 1 (rápida, alta prioridad):
1. Verificar en símbolos/base app el **nombre exacto** del repeater/control de Page 6510 y recolocar los campos DUoM en ese contenedor exacto si procede.
2. Añadir tests de UI/page para evitar regresión de visibilidad.

Fase 2 (robustez posting):
3. Endurecer tests de no-copia-ciega con casos N lotes en compra y diario.
4. Verificar rutas fallback donde todavía entra ratio de línea origen.

Fase 3 (WMS):
5. Diseñar mapa de propagación DUoM en warehouse advanced (receipt/shipment/activity/pick/put-away) antes de codificar.

## 13. Risks and open questions

- ¿El usuario reporta “no aparecen” en todos los contextos o solo en alguno (compra/venta/warehouse/journal)?
- ¿La sesión usa personalización de página que mueve/oculta columnas?
- ¿El problema es ausencia visual de columna o columna visible pero vacía (ratio=0)?
- ¿Qué flujos exactos WMS deben entrar en MVP vs P2?

## 14. Proposed follow-up implementation task

**Siguiente tarea recomendada (sin implementarla aún):**

> “Corregir la extensión de Page 6510 Item Tracking Lines para anclar DUoM Ratio y DUoM Second Qty al repeater/control exacto validado en símbolos BC27, y añadir tests AL de visibilidad + posting multilot (compra y diario) que prueben explícitamente que 1 línea origen se divide en N lotes con ratios DUoM independientes.”
