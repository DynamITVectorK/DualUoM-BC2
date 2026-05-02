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
- Use existing `Item Tracking` infrastructure for lot linkage (implemented in Phase 1 — Issues 13, 20, 21, 22, 23)
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
| `DUoM Reservation Entry Ext` | 50123 | `Reservation Entry` | Campos DUoM Second Qty y Ratio. La propagación desde `Tracking Specification` al cerrar Item Tracking Lines se implementa en `DUoM Tracking Copy Subs` (50110) vía `OnAfterCopyTrackingFromTrackingSpec`. Al reabrir la página, los valores se recargan vía `OnAfterCopyTrackingFromReservEntry` (Issue 190) |

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
| `DUoM Tracking Subscribers` | 50109 | Suscriptores de eventos `OnAfterValidateEvent` para `Lot No.` y `Quantity (Base)` en `Tracking Specification` (6500). Pre-rellena DUoM Ratio y DUoM Second Qty al asignar un lote en Item Tracking Lines. Modo Fixed: usa ratio fijo; Variable/AlwaysVariable: aplica ratio de lote de `DUoM Lot Ratio` si existe. (Issue 22) |
| `DUoM Tracking Copy Subs` | 50110 | Propaga DUoM Ratio y DUoM Second Qty siguiendo el patrón `OnAfterCopyTracking*` de `Codeunit 6516 "Package Management"`. Cadena directa: `Tracking Specification` → `Item Journal Line` (`OnAfterCopyTrackingFromSpec`) → `Item Ledger Entry` (`OnAfterCopyTrackingFromItemJnlLine`). Cadena inversa: `Item Ledger Entry` → `Item Journal Line` (`OnAfterCopyTrackingFromItemLedgEntry`). **Persistencia de Item Tracking Lines:** `Tracking Specification` buffer → `Reservation Entry` vía `OnAfterCopyTrackingFromTrackingSpec` (al cerrar la página). Recarga: `Reservation Entry` → `Tracking Specification` buffer vía `OnAfterCopyTrackingFromReservEntry` (al reabrir la página). Reemplaza `OnAfterInitItemLedgEntry` + `TryApplyLotRatioToILE`. Signatures verificadas contra `Package Management (6516)` BC 27. (Issues 23, 190) |

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
- **Issue 177:** política AlwaysVariable + lotes bifurcada en cuatro sub-casos. Ver sección
  siguiente.
- **Issue 190:** implementada propagación DUoM de `Tracking Specification` a `Reservation Entry`
  vía `OnAfterCopyTrackingFromTrackingSpec` (verificado en BC 27 — el evento SÍ expone
  `var ReservationEntry` modificable, contrariamente a lo documentado en Issue 22).
- **Bug fix (tracking flow):** añadido subscriber `OnAfterCopyTrackingFromReservEntry` en
  Table "Reservation Entry" (337) para completar el Paso 2 del INSERT de Item Tracking Lines.
  Sin este subscriber, `InsertReservEntry.CopyTrackingFromReservEntry(ReservEntry1)` (llamado
  internamente por `CreateReservEntryFor`) no propagaba DUoM Ratio, dejando la ReservEntry
  final insertada con `DUoM Ratio = 0` aunque `ReservEntry1` ya tuviera el valor correcto.
  Patrón: idéntico al de `Package Management (6516)` para campos extra en Reservation Entry.
  Corrige el test `T-PERSIST-01` (era el único test fallando de 135).

---

## Persistencia DUoM en Item Tracking Lines (Issues 22, 190)

### Flujo de persistencia al cerrar la página

Cuando el usuario acepta (OK) la página `Item Tracking Lines` (6510) desde un pedido de compra,
BC transfiere el buffer `Tracking Specification` a `Reservation Entry` en **dos pasos internos**:

```
Usuario informa Lot No. + DUoM Ratio + DUoM Second Qty en buffer TrackingSpec
→ OK
→ BC (RegisterChange::Insert):
   PASO 1: ReservEntry1.CopyTrackingFromSpec(OldTrackingSpec)
   → Evento: Table "Reservation Entry" · OnAfterCopyTrackingFromTrackingSpec         [50110]
        ↓ ReservEntry1."DUoM Ratio"      := TrackSpec."DUoM Ratio"
        ↓ ReservEntry1."DUoM Second Qty" := TrackSpec."DUoM Second Qty"

   PASO 2: CreateReservEntry.CreateReservEntryFor(..., ForReservEntry=ReservEntry1)
           → internamente: InsertReservEntry.CopyTrackingFromReservEntry(ReservEntry1)
   → Evento: Table "Reservation Entry" · OnAfterCopyTrackingFromReservEntry          [50110]
        ↓ InsertReservEntry."DUoM Ratio"      := ReservEntry1."DUoM Ratio"
        ↓ InsertReservEntry."DUoM Second Qty" := ReservEntry1."DUoM Second Qty"

   PASO 3: CreateReservEntry.CreateEntry(...) → InsertReservEntry.Insert()
Reservation Entry (tabla 337) ← fuente de verdad persistente por lote
```

> **Nota de diseño:** El Paso 2 era el eslabón faltante (bug). Sin el subscriber
> `OnAfterCopyTrackingFromReservEntry` en Table "Reservation Entry", `InsertReservEntry`
> quedaba con `DUoM Ratio = 0` aunque `ReservEntry1` ya lo tuviera correcto del Paso 1.
> La corrección se implementa en el PR que cierra el issue de bug (tracking flow).

### Flujo de recarga al reabrir la página

Cuando el usuario vuelve a abrir `Item Tracking Lines` desde la misma línea de compra,
BC reconstruye el buffer `Tracking Specification` desde las `Reservation Entry` existentes:

```
BC: por cada ReservEntry de la línea, llama TrackSpec.CopyTrackingFromReservEntry(ReservEntry)
→ Evento: Table "Tracking Specification" · OnAfterCopyTrackingFromReservEntry           [50110]
     ↓ TrackSpec."DUoM Ratio"      := ReservEntry."DUoM Ratio"
     ↓ TrackSpec."DUoM Second Qty" := ReservEntry."DUoM Second Qty"

→ Página muestra valores DUoM recargados sin recálculo (asignación directa :=)
```

**Clave:** la recarga usa `:=` directo (sin `Validate`), por lo que **no se dispara** el
trigger `OnValidate` de `DUoM Ratio` en `DUoMTrackingSpecExt`. Los valores persisted se
muestran tal cual, sin recalcular `DUoM Second Qty`. Esto permite que valores manuales
no consistentes con `Qty × Ratio` se conserven fielmente.

### Enlace línea de compra → Reservation Entry

La `Reservation Entry` generada al cerrar Item Tracking Lines queda vinculada a la
`Purchase Line` mediante los campos estándar de BC:

| Campo en Reservation Entry | Valor |
|---|---|
| `Source Type` | `Database::"Purchase Line"` (38) |
| `Source Subtype` | `PurchLine."Document Type".AsInteger()` |
| `Source ID` | `PurchHeader."No."` |
| `Source Ref. No.` | `PurchLine."Line No."` |
| `Lot No.` | Lote introducido en Item Tracking Lines |

### Modo AlwaysVariable en Item Tracking Lines

En modo `AlwaysVariable`, el trigger `OnValidate` de `DUoM Ratio` en `DUoMTrackingSpecExt`
(tableextension 50122) hace `exit` sin recalcular `DUoM Second Qty`. Esto permite que
el usuario introduzca ambos valores de forma totalmente independiente en la página.
El subscriber `OnAfterValidateEvent["Quantity (Base)"]` (codeunit 50109) sí recalcula
`DUoM Second Qty` cuando la cantidad cambia, pero solo si `DUoM Ratio ≠ 0`.

### Test de regresión

El flujo completo queda cubierto por cuatro tests en codeunit 50219 `DUoM Purch Tracking Persist`:

| Test | Escenario |
|------|-----------|
| `T-PERSIST-01` `PurchLine_ItemTracking_DUoMValuesPersistAfterCloseAndReopen` | AlwaysVariable — cerrar/reabrir Item Tracking Lines conserva DUoM en ReservEntry |
| `T-PERSIST-02` `PurchLine_ItemTracking_DUoMRatioPropagatedToILEOnPost` | AlwaysVariable — contabilizar PO con tracking → ILE tiene DUoM Ratio correcto |
| `T-PERSIST-03` `ItemTracking_ModifyLotRatio_UpdatesReservEntry` | Variable — asignar lote con ratio registrado auto-asigna DUoM Ratio en ReservEntry |
| `T-PERSIST-04` `ItemTracking_NoImpactOnItemsWithoutDUoM` | Sin DUoM — Item Tracking Lines no introduce DUoM en ReservEntry |

Los tests T-PERSIST-01 y T-PERSIST-02 validan específicamente el Paso 2 (el eslabón reparado)
al combinar la apertura de Item Tracking Lines vía TestPage con verificación de ReservEntry/ILE.

### Restricciones para no romper el Item Tracking estándar

1. **No crear `Reservation Entry` ni `Tracking Specification` manualmente en producción**
   si existe API o evento BC estándar (el patrón `CopyTrackingFromTrackingSpec` es el camino).
2. **No llamar a `Validate` en la cadena de carga** (`OnAfterCopyTrackingFromReservEntry`):
   usar solo `:=` directo para evitar recálculos no deseados.
3. **No asumir 1 Reservation Entry por Purchase Line**: puede haber N entradas (una por lote).
4. **Los subscribers de DUoM en Item Tracking Lines son ligeros**: solo copian campos;
   no contienen lógica de negocio ni llamadas a codeunits complejos.



### Política AlwaysVariable + lotes — resumen técnico (Issue 177)

La lógica de `OnAfterInitItemLedgEntry` (codeunit 50104) implementa cuatro sub-casos
según la presencia de ratio de lote en `DUoM Lot Ratio` (50102), ratio manual en
`IJL.DUoM Ratio` y asignación de lote:

| Caso | `DUoM Lot Ratio` (50102) | `IJL.DUoM Ratio` | `IJL.Lot No.` | `ILE.DUoM Second Qty` | Test |
|------|--------------------------|------------------|----------------|------------------------|------|
| 1 | ✅ Existe | — | Cualquiera | `Abs(ILE.Qty) × ratio_lote` | T08–T09 |
| 2 | ❌ No existe | ≠ 0 (manual) | ✅ Asignado | `Abs(ILE.Qty) × ratio_manual` | T14 |
| 3 | ❌ No existe | 0 | ❌ Vacío | `IJL.DUoM Second Qty` (copia) | — |
| 4 | ❌ No existe | 0 | ✅ Asignado | `0` (distribución imposible) | T10 |

**Guarda en `OnAfterInitItemLedgEntry`** que diferencia los casos 3/4 del caso 2:

```al
// Caso 4: AlwaysVariable + Lot No. + DUoM Ratio = 0 → ILE = 0 (salida anticipada)
// Caso 2: si DUoM Ratio ≠ 0, pasa al cálculo general → ILE = Abs(Qty) × Ratio
if ItemJournalLine."Lot No." <> '' then
    if DUoMSetupResolver.GetEffectiveSetup(
           ItemJournalLine."Item No.", ItemJournalLine."Variant Code",
           SecondUoMCode, ConversionMode, FixedRatio) then
        if ConversionMode = ConversionMode::AlwaysVariable then
            if ItemJournalLine."DUoM Ratio" = 0 then
                exit;
```

La prioridad global de fuentes de ratio (todos los modos) es:
```
DUoM Lot Ratio (50102) > IJL.DUoM Ratio (campo directo) > sin ratio (= 0)
```

Ver `docs/02-functional-design.md` — sección "Política AlwaysVariable + lotes" para
la descripción funcional completa con rationale por caso.

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

> **Referencia completa:** para la matriz detallada de todos los flujos de propagación
> (origen → destino por tabla), campos DUoM persistidos, fuente de verdad por caso de uso
> y limitaciones conocidas, ver **`docs/10-persistence-matrix.md`**.

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
