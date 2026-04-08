# Backlog — DualUoM-BC

Este es el backlog ordenado propuesto para una entrega controlada e incremental.
Cada elemento está definido para poder ser implementado en un único issue enfocado por GitHub Copilot.

---

## Fase 1 — MVP

### Issue 1 — Base de gobernanza del proyecto *(este issue)*

Crear la base de documentación: visión, alcance, diseño funcional, arquitectura, estrategia de pruebas,
backlog. Actualizar README e instrucciones de copilot.

### Issue 2 — Motor de cálculo DUoM

Crear el codeunit `DUoM Calc Engine` (ID 50101) con:
- Función `ComputeSecondQty(FirstQty, Ratio, Mode)`
- Validación de entrada (la cantidad debe ser no negativa, el ratio debe ser positivo para Fixed/Variable)
- Pruebas unitarias cubriendo los modos Fixed, Variable, Always-Variable y casos extremos (cantidad cero, redondeo)

**Entregables:** `DualUoMCalcEngine.Codeunit.al`, `DualUoMCalcEngineTests.Codeunit.al`

### Issue 3 — Tabla y página de configuración DUoM del artículo

Crear la tabla `DUoM Item Setup` (ID 50100) vinculada a `Item`:
- Campos: `Item No.`, `Dual UoM Enabled`, `Second UoM Code`, `Conversion Mode` (enum),
  `Fixed Ratio`
- Crear página de configuración (ID 50100)
- Crear extensión de página en la ficha de artículo para abrir la página de configuración
- Pruebas unitarias para las reglas de validación de configuración

**Entregables:** `DUoMItemSetup.Table.al`, `DUoMConversionMode.Enum.al`,
`DUoMItemSetup.Page.al`, `ItemCard.PageExt.al`, `DUoMItemSetupTests.Codeunit.al`

### Issue 4 — Campos DUoM en líneas de compra

Extender `Purchase Line` con los campos `DUoM Second Qty` y `DUoM Ratio` (extensión de tabla).
Extender la subpágina de líneas de pedido de compra para mostrar los campos.
Conectar `OnAfterValidate` en `Quantity` para llamar al motor de cálculo para la derivación automática.
Pruebas de integración: crear una línea de pedido de compra, verificar que se calcula la segunda cantidad.

**Entregables:** `DUoMPurchaseLine.TableExt.al`, `DUoMPurchaseOrderSubform.PageExt.al`,
`DUoMPurchaseSubscribers.Codeunit.al`, `DUoMPurchaseTests.Codeunit.al`

### Issue 5 — Contabilización de compras — Segunda cantidad en ILE

Suscribirse a los eventos de contabilización de recepciones de compra para propagar `DUoM Second Qty` y
`DUoM Ratio` desde `Purchase Line` a `Item Ledger Entry` (extensión de tabla en ILE).
Pruebas de integración: contabilizar una recepción de compra, verificar los campos ILE.

**Entregables:** `DUoMItemLedgerEntry.TableExt.al`, actualizar `DUoMPurchaseSubscribers`,
actualizar `DUoMPurchaseTests`

### Issue 6 — Campos DUoM en líneas de venta

Extender `Sales Line` con los campos `DUoM Second Qty` y `DUoM Ratio`.
Extender la subpágina de líneas de pedido de venta para mostrar los campos.
Conectar `OnAfterValidate` en `Quantity`.
Pruebas de integración.

**Entregables:** `DUoMSalesLine.TableExt.al`, `DUoMSalesOrderSubform.PageExt.al`,
`DUoMSalesSubscribers.Codeunit.al`, `DUoMSalesTests.Codeunit.al`

### Issue 7 — Contabilización de ventas — Segunda cantidad en ILE

Suscribirse a los eventos de contabilización de envíos de venta para propagar los campos DUoM al ILE.
Pruebas de integración: contabilizar un envío de venta, verificar los campos ILE.

**Entregables:** actualizar `DUoMSalesSubscribers`, actualizar `DUoMSalesTests`

### Issue 8 — Campos DUoM en diario de artículos y contabilización

Extender `Item Journal Line` con los campos DUoM.
Suscribirse a la contabilización del diario de artículos para propagar al ILE.
Pruebas de integración: contabilizar una línea de diario de artículos, verificar los campos ILE.

**Entregables:** `DUoMItemJournalLine.TableExt.al`, `DUoMInventorySubscribers.Codeunit.al`,
`DUoMInventoryTests.Codeunit.al`

---

## Fase 2

### Issue 9 — Ratio real específico por lote

Almacenar el ratio real por lote en las líneas de seguimiento de artículos.
Rellenar previamente el ratio DUoM en las líneas de documento cuando se selecciona un lote.
Pruebas: asignar un lote, verificar el relleno previo del ratio.

### Issue 10 — Campos DUoM en recepciones y envíos de almacén

Extender la línea de recepción de almacén y la línea de envío de almacén.
Propagar al asiento de almacén y al ILE en la contabilización.

### Issue 11 — Campos DUoM en put-away y picking dirigido

Extender la línea de actividad de almacén para almacén dirigido.
Mostrar la segunda cantidad en los documentos de put-away y picking.

### Issue 12 — DUoM en inventario físico

Extender el diario de inventario físico para soportar el recuento de segunda cantidad.

### Issue 13 — Extensiones de informes

Añadir columnas de segunda cantidad a los informes estándar clave (recepción de compra, envío de venta,
valoración de inventario) usando extensiones de informes.

---

## Fase 3 / Posterior

- Soporte DUoM en pedidos de transferencia (Issue 14+)
- Soporte DUoM en pedidos de devolución (Issue 15+)
- Soporte DUoM en pedidos de ensamblado (si alguna vez está en el alcance)

---

## Notas

- Los issues deben implementarse en orden; los posteriores dependen de los anteriores.
- Cada issue debe incluir pruebas antes de considerarse terminado.
- El codeunit `DualUoM Pipeline Check` (ID 50100) y su prueba (ID 50200) son
  temporales y se eliminarán cuando se fusione el Issue 2 (Motor de cálculo). El codeunit del motor de
  cálculo usa el ID 50101 y su prueba usa el 50203 (50201 y 50202 ya están
  usados por `DUoM Item Setup Tests` y `DUoM Item Card Opening Tests`).
