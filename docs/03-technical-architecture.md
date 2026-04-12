# Technical Architecture — DualUoM-BC

## Extension-Only Approach

The solution is delivered exclusively as a **Per-Tenant Extension (PTE)** running on
Business Central SaaS. No base application code is modified. All additions use:

- Table extensions (`tableextension`) to add fields to standard tables
- Page extensions (`pageextension`) to surface new fields on existing pages
- New custom tables and pages for DUoM-specific setup and configuration
- Event subscribers to intercept standard posting, validation and calculation flows
- Codeunits for business logic, entirely independent of the standard code path

This guarantees compatibility with future BC updates and safe uninstallation.

---

## SaaS-Safe Design Principles

| Principle | Rationale |
|---|---|
| No direct table access to internal BC tables via `RecordRef` where avoidable | Fragile against schema changes |
| No `OnBeforeInsert`/`OnBeforeModify` subscribers that throw errors mid-flow | Prefer `OnAfterValidate` and dedicated validation codeunits |
| Para propagar campos de extensión a tablas base en el posting, usar eventos **antes** del Insert (`OnBefore*Insert`) en lugar de `OnAfter*Insert` + `Modify()` | `Modify()` en un subscriber `OnAfter*` requiere permiso `M` del usuario sobre la tabla base (BC SaaS error "Su licencia no le concede Modify en TableData NNN"). El patrón `OnBefore*Insert` + asignación directa de campos es seguro y no requiere permiso adicional. |
| No `BLOB` fields unless unavoidable | Performance and upgrade risk |
| No hardcoded object IDs from the base application | Use `Codeunit.RUN` and `Page.RUN` by name where possible |
| No deprecated BC APIs | Always use current-release patterns |
| No UI-blocking logic in table triggers | Move validation to page/codeunit layer |

---

## Standard-First Philosophy

Before adding any new field, table or logic, consider whether a standard BC mechanism
already covers the need:

- Use existing `Item Unit of Measure` table for fixed ratio base data
- Use existing `Item Tracking` infrastructure for lot linkage (Phase 2)
- Use existing `Warehouse Activity Line` structure for warehouse extensions (Phase 2)
- Only extend or add when standard BC genuinely cannot support the requirement

---

## Object Structure

### Custom Tables

| Object | ID | Purpose |
|---|---|---|
| `DUoM Item Setup` | 50100 | Per-item DUoM configuration (enabled, second UoM, mode, ratio) |

### Table Extensions

| Objeto | ID | Tabla extendida | Propósito |
|---|---|---|---|
| `DUoM Purchase Line Ext` | 50110 | `Purchase Line` | Campos Second Qty y Ratio |
| `DUoM Sales Line Ext` | 50111 | `Sales Line` | Campos Second Qty y Ratio |
| `DUoM Item Journal Line Ext` | 50112 | `Item Journal Line` | Campos Second Qty y Ratio |
| `DUoM Item Ledger Entry Ext` | 50113 | `Item Ledger Entry` | Second Qty y Ratio (contabilizados, inmutables) |
| `DUoM Purch. Rcpt. Line Ext` | 50114 | `Purch. Rcpt. Line` | Second Qty y Ratio propagados desde `Purchase Line` al contabilizar |
| `DUoM Sales Shipment Line Ext` | 50115 | `Sales Shipment Line` | Second Qty y Ratio propagados desde `Sales Line` al contabilizar |
| `DUoM Purch. Inv. Line Ext` | 50116 | `Purch. Inv. Line` | Second Qty y Ratio propagados desde `Purchase Line` al contabilizar factura |
| `DUoM Purch. Cr. Memo Line Ext` | 50117 | `Purch. Cr. Memo Line` | Second Qty y Ratio propagados desde `Purchase Line` al contabilizar abono |
| `DUoM Sales Inv. Line Ext` | 50118 | `Sales Invoice Line` | Second Qty y Ratio propagados desde `Sales Line` al contabilizar factura |
| `DUoM Sales Cr.Memo Line Ext` | 50119 | `Sales Cr.Memo Line` | Second Qty y Ratio propagados desde `Sales Line` al contabilizar abono |

### Page Extensions

| Objeto | ID | Página extendida | Propósito |
|---|---|---|---|
| `DUoM Purchase Order Subform` | 50101 | `Purchase Order Subform` | Muestra Second Qty y Ratio en líneas de pedido de compra |
| `DUoM Sales Order Subform` | 50102 | `Sales Order Subform` | Muestra Second Qty y Ratio en líneas de pedido de venta |
| `DUoM Posted Rcpt. Subform` | 50104 | `Posted Purchase Rcpt. Subform` | Muestra Second Qty y Ratio en líneas de recepción registrada (solo lectura) |
| `DUoM Posted Ship. Subform` | 50105 | `Posted Sales Shpt. Subform` | Muestra Second Qty y Ratio en líneas de envío registrado (solo lectura) |
| `DUoM Pstd Purch Inv Subform` | 50106 | `Posted Purch. Invoice Subform` | Muestra Second Qty y Ratio en líneas de factura de compra registrada (solo lectura) |
| `DUoM Pstd Purch CrM Subform` | 50107 | `Posted Purch. Cr. Memo Subform` | Muestra Second Qty y Ratio en líneas de abono de compra registrado (solo lectura) |
| `DUoM Pstd Sales Inv Subform` | 50108 | `Posted Sales Invoice Subform` | Muestra Second Qty y Ratio en líneas de factura de venta registrada (solo lectura) |
| `DUoM Pstd Sales CrM Subform` | 50109 | `Posted Sales Cr. Memo Subform` | Muestra Second Qty y Ratio en líneas de abono de venta registrado (solo lectura) |

### Codeunits

| Objeto | ID | Propósito |
|---|---|---|
| `DUoM Calc Engine` | 50101 | Cálculo y validación de la segunda cantidad. Incluye `ComputeSecondQtyRounded` con soporte de `Rounding Precision` |
| `DUoM Purchase Subscribers` | 50102 | Subscribers de eventos del flujo de compras |
| `DUoM Sales Subscribers` | 50103 | Subscribers de eventos del flujo de ventas |
| `DUoM Inventory Subscribers` | 50104 | Subscribers para diario de productos / ILE / líneas de documentos registrados |
| `DUoM Doc Transfer Helper` | 50105 | Helper centralizado de copia de campos DUoM entre líneas de documento |
| `DUoM UoM Helper` | 50106 | Helper de UoM: obtiene `Qty. Rounding Precision` de la tabla `Item Unit of Measure` para la segunda UoM del ítem y la aplica al cálculo y validación de `DUoM Second Qty` |

---

## Event-Based Design

All integration with standard BC flows is done via **published integration events**
(`[IntegrationEvent(false, false)]`) and **business events** where available.

Subscriber codeunits are kept small and focused. Each module (Purchase, Sales, Inventory,
Warehouse) has its own subscriber codeunit to limit blast radius of changes.

No subscriber codeunit should contain posting logic. Posting logic lives in dedicated
codeunits called from subscribers.

### Propagación de DUoM a históricos de documentos registrados

Los campos DUoM se propagan a todos los históricos usando **eventos de inicialización de tabla**
de BC 27 (patrón `OnAfterInitFrom*`). Estos eventos se publican en las tablas de destino
y dan acceso al var record ANTES del Insert(), evitando la necesidad de llamar a Modify().

| Flujo | Evento | Publisher | Tabla destino |
|---|---|---|---|
| `Purchase Line` → `Purch. Rcpt. Line` | `OnAfterInitFromPurchLine` | `Table "Purch. Rcpt. Line"` | Recepción registrada |
| `Purchase Line` → `Purch. Inv. Line` | `OnAfterInitFromPurchLine` | `Table "Purch. Inv. Line"` | Factura compra registrada |
| `Purchase Line` → `Purch. Cr. Memo Line` | `OnAfterInitFromPurchLine` | `Table "Purch. Cr. Memo Line"` | Abono compra registrado |
| `Sales Line` → `Sales Shipment Line` | `OnAfterInitFromSalesLine` | `Table "Sales Shipment Line"` | Envío registrado |
| `Sales Line` → `Sales Invoice Line` | `OnAfterInitFromSalesLine` | `Table "Sales Invoice Line"` | Factura venta registrada |
| `Sales Line` → `Sales Cr.Memo Line` | `OnAfterInitFromSalesLine` | `Table "Sales Cr.Memo Line"` | Abono venta registrado |

> **IMPORTANTE:** En los eventos de Sales (`Sales Invoice Line` y `Sales Cr.Memo Line`),
> el parámetro `var` de destino es el **PRIMER** parámetro de la firma, a diferencia de
> los eventos de Purchase donde es el **ÚLTIMO**. Verificar siempre la firma exacta en
> el código fuente BC 27.

Toda la lógica de copia está centralizada en `DUoM Doc Transfer Helper` (50105).
Los subscribers en `DUoM Inventory Subscribers` (50104) son "thin" — sólo validan y delegan.

---

## Testing-First Expectations

- Every codeunit must have a corresponding test codeunit in `test/src/codeunit/`
- Tests use the standard AL testability framework (`Subtype = Test`)
- `Library Assert` (Microsoft) is the only allowed assertion library
- No production code is merged without at least one passing test covering the new behavior
- See `docs/05-testing-strategy.md` for full strategy

---

## Upgrade-Friendly Architecture

- No data migrations in MVP (no data exists yet)
- When data migrations become necessary, use `OnUpgradePerCompany` / `OnInstallAppPerCompany`
  in a dedicated install/upgrade codeunit
- Table extensions fields use `ObsoleteState` appropriately when deprecated
- Never rename or renumber existing published objects — create new ones instead
