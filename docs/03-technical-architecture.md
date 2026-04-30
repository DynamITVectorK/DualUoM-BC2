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
| Para propagar campos de extensión a tablas base en el posting, usar **eventos de inicialización de tabla** (`OnAfterInit*`) en lugar de `OnAfter*Insert` + `Modify()` | `Modify()` en un subscriber `OnAfter*Insert` requiere permiso `M` del usuario sobre la tabla base (BC SaaS error "Su licencia no le concede Modify en TableData NNN"). Los eventos `OnAfterInitFrom*` publicados por las tablas de destino (p. ej. `OnAfterInitFromPurchLine` en `Table "Purch. Rcpt. Line"`) exponen el `var` record ANTES del `Insert()`, permitiendo asignación directa de campos sin ningún permiso adicional. |
| **No llamar a `Rec.Modify(false)` dentro de un suscriptor `OnAfterValidateEvent`** para persistir campos de tableextension | En BC 27, `Rec.Modify(false)` dentro de un suscriptor `OnAfterValidateEvent` realiza un refresco implícito del buffer del registro desde la BD **antes** de escribir. Esto sobrescribe las asignaciones `:=` previas con los valores almacenados en BD, deshaciendo el cambio deseado. Usar únicamente `:=` directo sobre `var Rec` — la propagación al registro llamante funciona correctamente a través del parámetro `var`. |
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
| `DUoM Item Variant Setup` | 50101 | Optional per-variant DUoM override (Second UoM Code, Conversion Mode, Fixed Ratio). Absent = inherit from item. |
| `DUoM Lot Ratio` | 50102 | Almacena el ratio real medido por lote. Para artículos con trazabilidad de lote, la segunda cantidad y el ratio DUoM se persisten en el ILE de cada lote al contabilizar. Implementado en Issue 13; model 1:N consolidado en Issue 20. |

### Custom Pages

| Object | ID | Purpose |
|---|---|---|
| `DUoM Item Setup` | 50100 | Card page for item-level DUoM configuration |
| `DUoM Variant Setup List` | 50101 | List page for per-variant DUoM overrides; opened from Item Card filtered to current item |
| `DUoM Lot Ratio List` | 50102 | List page for lot-specific actual ratios; accessible standalone or filtered by item from `DUoM Item Setup` action |

### Table Extensions

| Objeto | ID | Tabla extendida | Propósito |
|---|---|---|---|
| `Item.TableExt` | 50100 | `Item` | Cascade-delete del registro DUoM Item Setup al borrar el artículo |
| `DUoM Purchase Line Ext` | 50110 | `Purchase Line` | Campos Second Qty, Ratio y Unit Cost |
| `DUoM Sales Line Ext` | 50111 | `Sales Line` | Campos Second Qty, Ratio y Unit Price |
| `DUoM Item Journal Line Ext` | 50112 | `Item Journal Line` | Campos Second Qty y Ratio |
| `DUoM Item Ledger Entry Ext` | 50113 | `Item Ledger Entry` | Second Qty y Ratio (contabilizados, inmutables) |
| `DUoM Purch. Rcpt. Line Ext` | 50114 | `Purch. Rcpt. Line` | Second Qty, Ratio y Unit Cost propagados desde `Purchase Line` al contabilizar |
| `DUoM Sales Shipment Line Ext` | 50115 | `Sales Shipment Line` | Second Qty, Ratio y Unit Price propagados desde `Sales Line` al contabilizar |
| `DUoM Purch. Inv. Line Ext` | 50116 | `Purch. Inv. Line` | Second Qty, Ratio y Unit Cost propagados desde `Purchase Line` al contabilizar factura |
| `DUoM Purch. Cr. Memo Line Ext` | 50117 | `Purch. Cr. Memo Line` | Second Qty, Ratio y Unit Cost propagados desde `Purchase Line` al contabilizar abono |
| `DUoM Sales Inv. Line Ext` | 50118 | `Sales Invoice Line` | Second Qty, Ratio y Unit Price propagados desde `Sales Line` al contabilizar factura |
| `DUoM Sales Cr.Memo Line Ext` | 50119 | `Sales Cr.Memo Line` | Second Qty, Ratio y Unit Price propagados desde `Sales Line` al contabilizar abono |
| `DUoM Item Variant Ext` | 50120 | `Item Variant` | Cascade-delete del override DUoM de la variante al borrarla |
| `DUoM Value Entry Ext` | 50121 | `Value Entry` | DUoM Second Qty para trazabilidad contable completa (Issue 12) |
| `DUoM Tracking Spec Ext` | 50122 | `Tracking Specification` | Campos DUoM Second Qty y Ratio en el buffer de Item Tracking Lines; pre-relleno al validar Lot No. (Issue 22) |
| `DUoM Reservation Entry Ext` | 50123 | `Reservation Entry` | Campos DUoM Second Qty y Ratio reservados para uso futuro. La propagación automática desde `Tracking Specification` no se implementa en BC 27 porque el evento `OnAfterCopyTrackingFromTrackingSpec` no expone un parámetro `var Rec` modificable (AL0282 — limitación conocida, tarea futura N-lotes) |

### Page Extensions

| Objeto | ID | Página extendida | Propósito |
|---|---|---|---|
| `DUoM Item Card Ext` | 50100 | `Item Card` | Acciones de navegación: DUoM Setup y DUoM Variant Overrides |
| `DUoM Purchase Order Subform` | 50101 | `Purchase Order Subform` | Muestra Second Qty, Ratio y Unit Cost en líneas de pedido de compra |
| `DUoM Sales Order Subform` | 50102 | `Sales Order Subform` | Muestra Second Qty, Ratio y Unit Price en líneas de pedido de venta |
| `DUoM Item Journal Ext` | 50103 | `Item Journal` | Muestra Second Qty y Ratio en líneas del diario de productos |
| `DUoM Posted Rcpt. Subform` | 50104 | `Posted Purchase Rcpt. Subform` | Muestra Second Qty, Ratio y Unit Cost en líneas de recepción registrada (solo lectura) |
| `DUoM Posted Ship. Subform` | 50105 | `Posted Sales Shpt. Subform` | Muestra Second Qty, Ratio y Unit Price en líneas de envío registrado (solo lectura) |
| `DUoM Pstd Purch Inv Subform` | 50106 | `Posted Purch. Invoice Subform` | Muestra Second Qty, Ratio y Unit Cost en líneas de factura de compra registrada (solo lectura) |
| `DUoM Pstd Purch CrM Subform` | 50107 | `Posted Purch. Cr. Memo Subform` | Muestra Second Qty, Ratio y Unit Cost en líneas de abono de compra registrado (solo lectura) |
| `DUoM Pstd Sales Inv Subform` | 50108 | `Posted Sales Invoice Subform` | Muestra Second Qty, Ratio y Unit Price en líneas de factura de venta registrada (solo lectura) |
| `DUoM Pstd Sales CrM Subform` | 50109 | `Posted Sales Cr. Memo Subform` | Muestra Second Qty, Ratio y Unit Price en líneas de abono de venta registrado (solo lectura) |
| `DUoM Item UoM Subform` | 50110 | `Item Units of Measure` | Añade `Qty. Rounding Precision` al repeater; editable solo si no existen ILE ni Warehouse Entry para esa UdM |
| `DUoM Item Tracking Lines` | 50112 | `Item Tracking Lines` | Muestra DUoM Ratio y DUoM Second Qty en el repeater de seguimiento de lotes (Issue 22) |

### Codeunits

| Objeto | ID | Propósito |
|---|---|---|
| `DUoM Calc Engine` | 50101 | Cálculo y validación de la segunda cantidad. Incluye `ComputeSecondQtyRounded` con soporte de `Rounding Precision` |
| `DUoM Purchase Subscribers` | 50102 | Subscribers de eventos del flujo de compras (Quantity y Variant Code en Purchase Line) |
| `DUoM Sales Subscribers` | 50103 | Subscribers de eventos del flujo de ventas (Quantity y Variant Code en Sales Line) |
| `DUoM Inventory Subscribers` | 50104 | Subscribers para diario de productos / ILE / líneas de documentos registrados |
| `DUoM Doc Transfer Helper` | 50105 | Helper centralizado de copia de campos DUoM entre líneas de documento |
| `DUoM UoM Helper` | 50106 | Helper de UoM: `GetSecondUoMRoundingPrecision(ItemNo)` y `GetRoundingPrecisionByUoMCode(ItemNo, SecondUoMCode)` para obtener `Qty. Rounding Precision` de la tabla `Item Unit of Measure` |
| `DUoM Setup Resolver` | 50107 | Centraliza la resolución jerárquica Item → Variante de la configuración DUoM efectiva. Todos los suscriptores y triggers deben llamar a `GetEffectiveSetup(ItemNo, VariantCode, ...)` |
| `DUoM Lot Subscribers` | 50108 | Utilidades para integración DUoM con lotes. Método público `TryApplyLotRatioToILE` conservado para tests unitarios de bajo nivel (ya no se invoca desde el flujo de posting). Helper interno `ApplyLotRatioToItemJournalLine` para escenarios controlados de un único lote (uso en tests unitarios de bajo nivel). El subscriber `OnAfterValidateEvent[Lot No.]` en `Item Journal Line` fue **eliminado** (Issue 21) por asumir incorrectamente 1 línea = 1 lote. |
| `DUoM Tracking Subscribers` | 50109 | Suscriptores de eventos `OnAfterValidateEvent` para `Lot No.` y `Quantity (Base)` en `Tracking Specification` (6500). Pre-rellena DUoM Ratio y DUoM Second Qty al asignar un lote en Item Tracking Lines. Modo Fixed: usa ratio fijo; Variable/AlwaysVariable: aplica ratio de lote de `DUoM Lot Ratio` si existe. La propagación a `Reservation Entry` (337) NO se implementa porque `OnAfterCopyTrackingFromTrackingSpec` no expone `var Rec` modificable en BC 27 (AL0282 — limitación conocida, tarea futura N-lotes). (Issue 22) |
| `DUoM Tracking Copy Subs` | 50110 | Propaga DUoM Ratio y DUoM Second Qty siguiendo el patrón `OnAfterCopyTracking*` de `Codeunit 6516 "Package Management"`. Cadena directa: `Tracking Specification` → `Item Journal Line` (`OnAfterCopyTrackingFromSpec`) → `Item Ledger Entry` (`OnAfterCopyTrackingFromItemJnlLine`). Cadena inversa: `Item Ledger Entry` → `Item Journal Line` (`OnAfterCopyTrackingFromItemLedgEntry`). Reemplaza `OnAfterInitItemLedgEntry` + `TryApplyLotRatioToILE`. Signatures verificadas contra `Package Management (6516)` BC 27. (Issue 23) |

---

## Modelo 1:N — Línea origen como agregado (Issue 20, refactorizado Issues 21, 23)

**DUoM nunca asume que 1 línea de documento BC equivale a 1 lote.** El modelo correcto es:

```
Línea origen (Purchase Line, Sales Line, IJL)  →  N lotes (vía Item Tracking)
                 ↓ cantidad total (agregado)          ↓ ILE por lote
                 ↓ DUoM Second Qty total         ↓ DUoM Second Qty por lote
                                                  ↓ DUoM Ratio por lote
```

### Flujo de propagación al ILE (mecanismos paralelos, Issue 23)

Dos mecanismos paralelos cubren los dos paths de posting:

**SIN Item Tracking** (artículos sin lotes):
```
IJL (DUoM Ratio del artículo/variante)
  → Codeunit "Item Jnl.-Post Line" · OnAfterInitItemLedgEntry   [50104]
      ↓ ILE.DUoM Ratio = IJL.DUoM Ratio
      ↓ ILE.DUoM Second Qty = Abs(ILE.Quantity) × Ratio  (o IJL.DUoM Second Qty si ratio = 0)
Item Ledger Entry  ✓
```

**CON Item Tracking** (por lote — patrón de `Package Management (6516)`):
```
Tracking Specification (con DUoM Ratio del lote)
  → Table "Item Journal Line" · OnAfterCopyTrackingFromSpec      [50110]
      ↓ IJL.DUoM Ratio = ratio del lote (si TrackingSpec.DUoM Ratio ≠ 0)
Item Journal Line
  → Table "Item Ledger Entry" · OnAfterCopyTrackingFromItemJnlLine [50110]
      ↓ ILE.DUoM Ratio = IJL.DUoM Ratio
      ↓ ILE.DUoM Second Qty = Abs(ILE.Quantity) × IJL.DUoM Ratio
Item Ledger Entry  ✓
```

Los dos paths coexisten sin conflicto: cuando hay Item Tracking activo, `OnAfterInitItemLedgEntry`
copia primero los valores del IJL original; después `ILECopyTrackingFromItemJnlLine` sobrescribe
con el ratio específico del lote (más preciso). La sobreescritura posterior siempre prevalece.

`DUoM Lot Ratio (50102)` ya no interviene directamente en el posting. Sigue siendo la
fuente para pre-rellenar el DUoM Ratio en la UI de `Item Tracking Lines` (via `DUoM Tracking
Subscribers`, codeunit 50109) al asignar un lote en recepciones posteriores.

### Principios de implementación

- La **línea origen** mantiene información DUoM como **total agregado**.
- El **ILE por lote** contiene la segunda cantidad y el ratio propios de ese lote.
- El posting calcula `ILE.DUoM Second Qty = Abs(ILE.Quantity) × DUoM Ratio` para garantizar
  el valor correcto por lote, independientemente del número de lotes de la línea origen.
- Si el `Tracking Specification` del lote aporta un ratio (via `IJLCopyTrackingFromSpec`),
  sobrescribe el ratio genérico de la línea. Si no (TrackingSpec.DUoM Ratio = 0), el split
  IJL hereda el ratio genérico de la línea origen.
- La suma de `DUoM Second Qty` de todos los ILEs de una línea refleja el total DUoM real.

### Restricción de diseño

- No se debe acceder a datos DUoM de lote a través de un único `FindFirst()` sobre
  `Reservation Entry` desde lógica de línea origen — puede haber N entradas.
- No se debe asumir que `ItemJournalLine."DUoM Second Qty"` en eventos de posting
  es la cantidad correcta para el ILE: en multi-lote, es el total de la línea, no el del lote.
- La distribución correcta de DUoM entre lotes usa `Abs(ILE.Quantity) × DUoM Ratio`
  calculado en `ILECopyTrackingFromItemJnlLine` (codeunit 50110).
- **`Item Journal Line`."Lot No." no es la fuente de verdad de la ratio DUoM por lote.**
  Usar `Validate("Lot No.")` en IJL como mecanismo para pre-rellenar DUoM es incorrecto
  porque asume 1 línea = 1 lote. La fuente de verdad real es el `Tracking Specification`
  del lote específico durante el split de posting (ver `IJLCopyTrackingFromSpec`).

### Historial de decisión

- **Issue 13:** implementación inicial con `OnAfterInitItemLedgEntry` + `TryApplyLotRatioToILE`.
- **Issue 20:** consolidación del modelo 1:N; corrección del bug de copia en AlwaysVariable.
- **Issue 21:** eliminación del subscriber `OnAfterValidateEvent[Lot No.]` porque asumía
  1 línea = 1 lote. El mecanismo productivo principal pasó a ser `OnAfterInitItemLedgEntry`.
- **Issue 23:** añadido patrón `OnAfterCopyTracking*` de `Package Management (6516)` (codeunit
  50110) para el flujo CON Item Tracking. `OnAfterInitItemLedgEntry` restaurado simplificado
  (sin `TryApplyLotRatioToILE`) para el flujo SIN Item Tracking.

## Resolución de configuración por variante

### DUoM Setup Resolver (codeunit 50107)

El `DUoM Setup Resolver` es el punto único de entrada para obtener la configuración DUoM
efectiva de cualquier combinación `(Item No., Variant Code)`. Implementa la jerarquía:

```
Item Setup (master switch) → Variant Override → Item defaults
```

**Firma del método principal:**

```al
procedure GetEffectiveSetup(
    ItemNo: Code[20];
    VariantCode: Code[10];
    var SecondUoMCode: Code[10];
    var ConversionMode: Enum "DUoM Conversion Mode";
    var FixedRatio: Decimal): Boolean
```

- Devuelve `true` cuando DUoM está activo y rellena los parámetros de salida.
- Devuelve `false` si el artículo no tiene setup DUoM o `Dual UoM Enabled = false`.
- Cuando `VariantCode` no está vacío y existe un registro en `DUoM Item Variant Setup`
  para `(ItemNo, VariantCode)`, los campos del override de variante prevalecen.
- En caso contrario, se usan los campos de nivel artículo de `DUoM Item Setup`.

**Regla de uso:** todos los suscriptores y triggers que necesiten la configuración DUoM
deben llamar a este método. Las lecturas directas de `DUoM Item Setup` son admisibles
solo en páginas de configuración o en contextos donde la variante no existe.

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
