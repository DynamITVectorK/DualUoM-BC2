# Normas de desarrollo — DualUoM-BC

Este documento recoge las normas técnicas obligatorias del proyecto **DualUoM-BC**.
Complementa las instrucciones de Copilot en `.github/copilot-instructions.md`.

---

## Norma: filtrado de Item Tracking / Reservation Entry

### Regla obligatoria

Todo filtrado de datos de seguimiento de producto, reservas y especificaciones de tracking
debe usar los métodos estándar de Business Central siempre que existan.

APIs preferidas:

```al
ReservationEntry.SetSourceFilter(...);
TrackingSpecification.SetSourceFilter(...);
```

### Datos persistidos de tracking

Usar `Record "Reservation Entry"` con:

```al
ReservationEntry.SetSourceFilter(
    SourceType: Integer;
    SourceSubtype: Integer;
    SourceID: Code[20];
    SourceRefNo: Integer;
    SetOtherFilters: Boolean);
```

Cuando `SetOtherFilters = true`, el método también filtra:
- `Source Batch Name = ''`
- `Source Prod. Order Line = 0`

Esto garantiza que no se mezclan entradas de lotes de otros documentos o de flujos de producción/almacén.

### Buffers temporales de tracking

Usar `Record "Tracking Specification"` con la misma firma:

```al
TrackingSpecification.SetSourceFilter(
    SourceType: Integer;
    SourceSubtype: Integer;
    SourceID: Code[20];
    SourceRefNo: Integer;
    SetOtherFilters: Boolean);
```

### Tabla de uso recomendado

| Caso | Registro | Método |
|---|---|---|
| Datos persistidos de tracking/reserva | `Record "Reservation Entry"` | `SetSourceFilter(...)` |
| Buffers temporales de tracking/posting/page | `Record "Tracking Specification"` | `SetSourceFilter(...)` |
| Filtros adicionales seguros | Item / Variant / Location / Lot / Serial / Package | Solo después del filtro estándar de origen |

### Ejemplo con Purchase Line — Reservation Entry

```al
local procedure SetPurchLineReservationFilter(
    var ReservationEntry: Record "Reservation Entry";
    PurchaseLine: Record "Purchase Line")
begin
    ReservationEntry.Reset();

    // Filtro estándar de origen BC — filtra Source Type, Subtype, ID, Ref. No.,
    // Source Batch Name (='') y Source Prod. Order Line (=0).
    ReservationEntry.SetSourceFilter(
        Database::"Purchase Line",
        PurchaseLine."Document Type".AsInteger(),
        PurchaseLine."Document No.",
        PurchaseLine."Line No.",
        true);

    // Filtros complementarios seguros (después del filtro de origen):
    ReservationEntry.SetRange("Item No.", PurchaseLine."No.");
    ReservationEntry.SetRange("Variant Code", PurchaseLine."Variant Code");
    ReservationEntry.SetRange("Location Code", PurchaseLine."Location Code");
end;
```

### Ejemplo con Purchase Line — Tracking Specification

```al
local procedure SetPurchLineTrackingSpecFilter(
    var TrackingSpecification: Record "Tracking Specification";
    PurchaseLine: Record "Purchase Line")
begin
    TrackingSpecification.Reset();

    // Filtro estándar de origen BC — igual que para Reservation Entry.
    TrackingSpecification.SetSourceFilter(
        Database::"Purchase Line",
        PurchaseLine."Document Type".AsInteger(),
        PurchaseLine."Document No.",
        PurchaseLine."Line No.",
        true);

    // Filtros complementarios seguros (después del filtro de origen):
    TrackingSpecification.SetRange("Item No.", PurchaseLine."No.");
    TrackingSpecification.SetRange("Variant Code", PurchaseLine."Variant Code");
    TrackingSpecification.SetRange("Location Code", PurchaseLine."Location Code");
end;
```

### Ejemplo con filtro por lote después del filtro de origen

```al
// ✅ CORRECTO — SetSourceFilter primero, Lot No. después
ReservationEntry.SetSourceFilter(
    Database::"Purchase Line",
    PurchaseLine."Document Type".AsInteger(),
    PurchaseLine."Document No.",
    PurchaseLine."Line No.",
    true);
ReservationEntry.SetRange("Lot No.", LotNo);

// ❌ INCORRECTO — solo por lote, sin origen
ReservationEntry.SetRange("Lot No.", LotNo);
```

---

## Norma: ILE ← IJL siempre (DUoM Second Qty)

### Regla obligatoria

`Item Ledger Entry."DUoM Second Qty"` **nunca** se calcula desde campos del ILE.
Siempre debe recibir sus datos del `Item Journal Line` (IJL) mediante asignación directa.

La capa final de propagación (`OnAfterInitItemLedgEntry` y `ILECopyTrackingFromItemJnlLine`)
toma la magnitud del IJL y normaliza el signo contra `ILE.Quantity` usando `DUoM Sign Mgt` (50126).
El signo que venga del IJL es un "mejor intento" upstream; la normalización es la garantía final.
Si el IJL llega con ratio incorrecto, el bug está **upstream** (flujo de compra/venta,
tracking split o undo), no en la capa final.

### `OnAfterInitItemLedgEntry` — copia con normalización de signo (codeunit 50104)

El subscriber `OnAfterInitItemLedgEntry` de `DUoM Inventory Subscribers` (50104) copia
el ratio directamente del IJL y normaliza el signo de `DUoM Second Qty` contra
`NewItemLedgEntry.Quantity` usando `DUoM Sign Mgt`. No recalcula el ratio ni consulta tablas.

```al
// ✅ CORRECTO — OnAfterInitItemLedgEntry (50104)
NewItemLedgEntry."DUoM Ratio" := ItemJournalLine."DUoM Ratio";
NewItemLedgEntry."DUoM Second Qty" := DUoMSignMgt.NormalizeILESign(
    NewItemLedgEntry, ItemJournalLine."DUoM Second Qty");
```

### `ILECopyTrackingFromItemJnlLine` — copia con normalización de signo (codeunit 50110)

Para artículos con Item Tracking (lotes / series), el subscriber
`ILECopyTrackingFromItemJnlLine` en `DUoM Tracking Copy Subscribers` (50110) copia el
ratio del IJL split por lote y normaliza el signo de `DUoM Second Qty` contra
`ItemLedgerEntry.Quantity`. No recalcula ratio, no consulta `DUoM Lot Ratio` (50102).

```al
// ✅ CORRECTO — ILECopyTrackingFromItemJnlLine (50110)
ItemLedgerEntry."DUoM Ratio" := ItemJnlLine."DUoM Ratio";
ItemLedgerEntry."DUoM Second Qty" := DUoMSignMgt.NormalizeILESign(
    ItemLedgerEntry, ItemJnlLine."DUoM Second Qty");
```

### `OnAfterInitValueEntry` — copia con normalización de signo desde IJL (codeunit 50104)

El subscriber `OnAfterInitValueEntry` copia `DUoM Second Qty` desde `ItemJournalLine`
y normaliza el signo contra `ItemLedgEntry.Quantity`. **No** copia desde `ItemLedgEntry`.

```al
// ✅ CORRECTO — OnAfterInitValueEntry (50104): fuente IJL, signo normalizado contra ILE
ValueEntry."DUoM Second Qty" := DUoMSignMgt.NormalizeILESign(
    ItemLedgEntry, ItemJournalLine."DUoM Second Qty");

// ❌ PROHIBIDO — copia desde ILE (ILE no es la fuente final para VE)
ValueEntry."DUoM Second Qty" := ItemLedgEntry."DUoM Second Qty";
```

### Patrones prohibidos

```al
// ❌ PROHIBIDO — calcula desde ILE.Quantity (viola norma ILE←IJL)
ILE."DUoM Second Qty" := IJL.Signed(Abs(ILE.Quantity) * Ratio);

// ❌ PROHIBIDO — calcula desde IJL.Quantity × Ratio al asignar al ILE
ILE."DUoM Second Qty" := IJL.Signed(Abs(IJL.Quantity) * AppliedRatio);

// ❌ PROHIBIDO — calcula desde campos del ILE sin pasar por IJL
ILE."DUoM Second Qty" := Abs(ILE.Quantity) * ILE."DUoM Ratio";

// ❌ PROHIBIDO — Signed() falla en undo/correction entries
ILE."DUoM Second Qty" := ItemJournalLine.Signed(Abs(ItemJournalLine."DUoM Second Qty"));

// ❌ PROHIBIDO — lógica de signo ad-hoc fuera de DUoM Sign Mgt
ILE."DUoM Second Qty" := Abs(ItemJournalLine."DUoM Second Qty");
if NewItemLedgEntry.Quantity < 0 then
    ILE."DUoM Second Qty" := -ILE."DUoM Second Qty";

// ❌ PROHIBIDO — consultar DUoM Lot Ratio en subscribers finales ILE/VE
DUoMLotSubscribers.TryApplyLotRatioToILE(ItemLedgerEntry, ItemJnlLine);
```

### Patrón para flujo de anulación (undo sin trazabilidad)

En el flujo de anulación sin lote, BC no propaga DUoM al IJL (llega con DUoM = 0).
Los subscribers upstream `OnAfterCopyItemJnlLineFromPurchRcpt` y
`OnAfterCopyItemJnlLineFromSalesShpt` en `DUoM Inventory Subscribers` (50104) preparan
el IJL antes del posting. La responsabilidad de cada subscriber es:

- **Guard**: si hay `Lot No.` / `Serial No.`, el flujo de trazabilidad ya pobló los valores
  per-lote desde el ILE original — no sobrescribir.
- Copiar `DUoM Ratio` desde la línea del documento contabilizado.
- Delegar en `DUoM Sign Mgt` para establecer `DUoM Second Qty` con el signo correcto:
  - Undo recepción compra → `DUoMSignMgt.ApplyUndoPurchReceiptSign(PurchRcptLine."DUoM Second Qty")`
  - Undo envío venta → `DUoMSignMgt.ApplyUndoSalesShptSign(SalesShipmentLine."DUoM Second Qty")`

```al
// ✅ CORRECTO — upstream subscriber para undo receipt (sin trazabilidad)
if (ItemJournalLine."Lot No." <> '') or (ItemJournalLine."Serial No." <> '') then
    exit;  // trazabilidad ya pobló los valores per-lote desde el ILE original (50110)
if PurchRcptLine."DUoM Ratio" = 0 then
    exit;  // artículo sin DUoM
ItemJournalLine."DUoM Ratio" := PurchRcptLine."DUoM Ratio";
ItemJournalLine."DUoM Second Qty" := DUoMSignMgt.ApplyUndoPurchReceiptSign(
    PurchRcptLine."DUoM Second Qty");

// ✅ CORRECTO — upstream subscriber para undo shipment (sin trazabilidad)
if (ItemJournalLine."Lot No." <> '') or (ItemJournalLine."Serial No." <> '') then
    exit;
if SalesShipmentLine."DUoM Ratio" = 0 then
    exit;
ItemJournalLine."DUoM Ratio" := SalesShipmentLine."DUoM Ratio";
ItemJournalLine."DUoM Second Qty" := DUoMSignMgt.ApplyUndoSalesShptSign(
    SalesShipmentLine."DUoM Second Qty");
```

### Patrón para flujo de corrección (OnBeforeInsertCorrItemLedgEntry)

`OnAfterInitItemLedgEntry` e `ILECopyTrackingFromItemJnlLine` no pueden determinar el signo
correcto para ILEs de corrección porque `NewItemLedgEntry.Quantity` aún no refleja el signo
definitivo en el momento en que se disparan. El evento `OnBeforeInsertCorrItemLedgEntry` se
dispara justo antes de insertar el ILE de corrección, cuando el ILE original (`OldItemLedgEntry`)
está disponible y el signo está definido.

El signo se calcula delegando en `DUoM Sign Mgt.ApplyCorrectionILESign`.

Cubre todos los escenarios de undo: sin lote, con lote y con múltiples lotes.

```al
// ✅ CORRECTO — OnBeforeInsertCorrItemLedgEntry (50104)
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line",
    'OnBeforeInsertCorrItemLedgEntry', '', false, false)]
local procedure OnBeforeInsertCorrItemLedgEntry(
    var NewItemLedgEntry: Record "Item Ledger Entry";
    var OldItemLedgEntry: Record "Item Ledger Entry";
    var ItemJournalLine: Record "Item Journal Line")
var
    DUoMSignMgt: Codeunit "DUoM Sign Mgt";
begin
    if OldItemLedgEntry."DUoM Ratio" = 0 then
        exit;
    NewItemLedgEntry."DUoM Ratio" := OldItemLedgEntry."DUoM Ratio";
    NewItemLedgEntry."DUoM Second Qty" := DUoMSignMgt.ApplyCorrectionILESign(
        OldItemLedgEntry."DUoM Second Qty");
end;

// ❌ PROHIBIDO — usar Correction como parche en OnAfterInitItemLedgEntry
if ItemJournalLine.Correction then
    NewItemLedgEntry."DUoM Second Qty" := -NewItemLedgEntry."DUoM Second Qty";
```

### Implementación de referencia

Ver codeunit 50104 `DUoM Inventory Subscribers` y codeunit 50110 `DUoM Tracking Copy Subscribers`.
Toda la lógica de signo está centralizada en `DUoM Sign Mgt` (50126).

---

## Norma: gestión centralizada del signo DUoM

### Principio rector

`DUoM Second Qty` debe seguir el signo del movimiento. **Nadie fuera de la codeunit
`DUoM Sign Mgt` (50126) debe decidir si `DUoM Second Qty` va positivo o negativo.**

No existen "excepciones justificadas" permanentes. Cualquier caso especial debe
expresarse a través de un método explícito en `DUoM Sign Mgt`.

### API centralizada — DUoM Sign Mgt (50126)

```al
// 1. Normaliza el signo de DUoM Second Qty siguiendo ILE.Quantity.
// Usar en: OnAfterInitItemLedgEntry, ILECopyTrackingFromItemJnlLine,
//          OnAfterInitValueEntry, ILECopyTrackingFromNewItemJnlLine.
procedure NormalizeILESign(ItemLedgerEntry: Record "Item Ledger Entry"; SecondQty: Decimal): Decimal

// 2. Aplica el signo técnico del movimiento (entrada/salida) a una SecondQty positiva.
// Los datos de usuario se almacenan siempre positivos.
// Usar en: IJLCopyTrackingFromSpec (TrackingSpec → IJL split),
//          ProjectDocumentLineToItemJnlLine (Purchase/Sales Line → IJL).
procedure ApplyMovementSign(ItemJournalLine: Record "Item Journal Line"; SecondQty: Decimal): Decimal

// 3. Calcula DUoM Second Qty para el IJL de una anulación de albarán de compra (siempre negativo).
// Usar en: OnAfterCopyItemJnlLineFromPurchRcpt.
procedure ApplyUndoPurchReceiptSign(OriginalSecondQty: Decimal): Decimal

// 4. Calcula DUoM Second Qty para el IJL de una anulación de albarán de venta (siempre positivo).
// Usar en: OnAfterCopyItemJnlLineFromSalesShpt.
procedure ApplyUndoSalesShptSign(OriginalSecondQty: Decimal): Decimal

// 5. Calcula DUoM Second Qty de un ILE de corrección como negación del ILE original.
// Usar en: OnBeforeInsertCorrItemLedgEntry.
procedure ApplyCorrectionILESign(OldILESecondQty: Decimal): Decimal
```

### Reglas de uso

```al
// ✅ CORRECTO — usar DUoM Sign Mgt para normalizar signo en ILE
DUoMSignMgt.NormalizeILESign(ItemLedgerEntry, ItemJnlLine."DUoM Second Qty");

// ✅ CORRECTO — usar DUoM Sign Mgt para aplicar signo del movimiento al IJL
DUoMSignMgt.ApplyMovementSign(ItemJournalLine, Abs(TrackingSpecification."DUoM Second Qty"));

// ✅ CORRECTO — usar DUoM Sign Mgt para undo receipt
DUoMSignMgt.ApplyUndoPurchReceiptSign(PurchRcptLine."DUoM Second Qty");

// ✅ CORRECTO — usar DUoM Sign Mgt para undo shipment
DUoMSignMgt.ApplyUndoSalesShptSign(SalesShipmentLine."DUoM Second Qty");

// ✅ CORRECTO — usar DUoM Sign Mgt para ILE de corrección
DUoMSignMgt.ApplyCorrectionILESign(OldItemLedgEntry."DUoM Second Qty");

// ❌ PROHIBIDO — lógica local de signo en subscribers
if ItemJournalLine.Quantity < 0 then
    ItemJournalLine."DUoM Second Qty" := -Abs(ItemJournalLine."DUoM Second Qty");

// ❌ PROHIBIDO — signo inline fuera de DUoM Sign Mgt
ItemJournalLine."DUoM Second Qty" := -Abs(PurchRcptLine."DUoM Second Qty");

// ❌ PROHIBIDO — duplicar lógica de signo fuera de DUoM Sign Mgt
local procedure NormalizeSecondQtySignForILE(ILE: Record "Item Ledger Entry"; SecondQty: Decimal): Decimal
begin ...
end;

// ❌ PROHIBIDO — aplicar el signo dos veces (redundante e incoherente)
ItemJournalLine."DUoM Second Qty" := DUoMSignMgt.ApplyMovementSign(IJL, projected);
ItemJournalLine."DUoM Second Qty" := -Abs(ItemJournalLine."DUoM Second Qty"); // ← segunda vez
```

### DUoM Ratio siempre positivo

`DUoM Ratio` representa la relación entre unidades y nunca debe ser negativo. No convertirlo
en negativo en flujos de venta, abono o corrección.

```al
// ✅ CORRECTO
ILE."DUoM Ratio" := IJL."DUoM Ratio";  // Ratio positivo; el signo va en DUoM Second Qty

// ❌ PROHIBIDO
ILE."DUoM Ratio" := -IJL."DUoM Ratio";  // DUoM Ratio nunca negativo
```

---

## Norma: signo técnico en proyección Tracking Specification → IJL split

### Regla obligatoria

`IJLCopyTrackingFromSpec` en `DUoM Tracking Copy Subscribers` (50110) es el único punto
donde se aplica el signo técnico del movimiento al `DUoM Second Qty` del split IJL.

Los datos de usuario (TrackingSpec, ReservEntry) se almacenan **siempre positivos**.
El signo correcto (negativo para salidas/ventas, positivo para entradas/compras)
se determina a partir de `ItemJournalLine."Quantity (Base)"` del split, usando
`DUoM Sign Mgt` (50126) como capa centralizada.

```al
// ✅ CORRECTO — aplicar signo del movimiento al resolver DUoM en el split (via DUoM Sign Mgt)
ItemJournalLine."DUoM Second Qty" := DUoMSignMgt.ApplyMovementSign(
    ItemJournalLine, Abs(TrackingSpecification."DUoM Second Qty"));
```

### AlwaysVariable sin ratio real de tracking/lote

Cuando no existe ningún ratio real disponible para el split de lote
(TrackingSpec.DUoM Ratio = 0, no hay registro en DUoM Lot Ratio, y IJL.DUoM Ratio = 0),
el `DUoM Second Qty` del split IJL debe quedar a **cero**.

No copiar el total de la línea origen a cada split individual sin poder distribuirlo.

```al
// ✅ CORRECTO — resetear a 0 cuando no hay ratio disponible para el split
ItemJournalLine."DUoM Second Qty" := 0;

// ❌ PROHIBIDO — copiar el total de la línea a cada split sin ratio
// (el IJL heredado tiene DUoM Second Qty = total de la línea, no la parte del lote)
// No hacer nada ≠ correcto cuando el split IJL hereda el total del padre.
```

### Patrones prohibidos en IJLCopyTrackingFromSpec

```al
// ❌ PROHIBIDO — copiar DUoM Second Qty del tracking sin aplicar signo del movimiento
ItemJournalLine."DUoM Second Qty" := TrackingSpecification."DUoM Second Qty";

// ❌ PROHIBIDO — ignorar la rama AlwaysVariable sin ratio (no hace nada = hereda el total)
if ItemJournalLine."DUoM Ratio" <> 0 then
    ItemJournalLine."DUoM Second Qty" := ...;
// sin else → el split hereda incorrecto el total de la línea origen
```

---

## Norma: signo DUoM en el buffer de visualización (Tracking Specification)

### Principio rector

El buffer de `Tracking Specification` visible al usuario (página Item Tracking Lines) siempre
almacena `DUoM Second Qty` **con valor positivo**. El signo técnico (negativo para salidas,
positivo para entradas) solo se aplica en la capa de posting, nunca antes.

Este patrón se denomina "patrón piezas": la cantidad de piezas que ve el usuario en pantalla
siempre es positiva, independientemente de si el documento es una compra o una venta.

### Comportamiento en compras vs. ventas

| Capa | Compras | Ventas |
|------|---------|--------|
| Buffer TrackingSpec (pantalla) | +5 | +5 |
| Reservation Entry (BD) | +5 | −5 |
| IJL split por lote (posting) | +5 | −5 |
| ILE (posted) | +5 | −5 |

En ventas, BC almacena internamente `RE."DUoM Second Qty" = −5` (signo técnico negativo).
Cuando BC reconstruye el buffer de visualización desde las Reservation Entries, puede trasladar
ese valor con signo al buffer de TrackingSpec sin pasar por los subscribers de normalización.
Por eso, **todos los subscribers de copia TrackingSpec→TrackingSpec deben aplicar `Abs()`**
para garantizar que el buffer de visualización siempre quede con valores positivos.

### Regla de implementación

```al
// ✅ CORRECTO — subscriber OnAfterCopyTrackingFromTrackingSpec (codeunit 50110)
// Abs() garantiza valor positivo en el buffer de visualización, tanto para compras (+)
// como para ventas (−). El signo de posting se aplica más adelante en IJLCopyTrackingFromSpec.
TrackingSpecification."DUoM Ratio" := Abs(FromTrackingSpecification."DUoM Ratio");
TrackingSpecification."DUoM Second Qty" := Abs(FromTrackingSpecification."DUoM Second Qty");

// ❌ PROHIBIDO — copia directa sin Abs() en el subscriber de buffer TrackingSpec→TrackingSpec
// (ventas mostraría −5 en pantalla en lugar de +5)
TrackingSpecification."DUoM Second Qty" := FromTrackingSpecification."DUoM Second Qty";
```

### Coherencia entre subscribers de copia TrackingSpec

Todos los puntos de copia que afectan al buffer de visualización aplican `Abs()`:

| Evento | Subscriber | Abs() |
|--------|-----------|-------|
| `OnAfterCopyTrackingFromReservEntry` (Table TrackSpec) | `TrackingSpecCopyTrackingFromReservEntry` (50110) | Sí, vía `CopyReservEntryToTrackingSpec` |
| `OnAfterCopyTrackingFromTrackingSpec` (Table TrackSpec) | `TrackingSpecCopyFromTrackingSpec` (50110) | Sí |
| `OnAfterCopyTrackingSpec` (Page 6510) | `CopyTrackingSpecToTrackingSpec` (50125) | Sí |
| `OnAfterFillTrackingSpecBufferFromReservEntry` (Codeunit 6503) | `OnAfterFillTrackingSpecBufferFromReservEntry` (50125) | Sí, vía `CopyReservEntryToTrackingSpec` |

---

## Anti-patrones prohibidos

Los siguientes patrones **no están permitidos** salvo que estén explícitamente justificados
con comentario técnico y revisión en PR.

### Filtro solo por lote (o serie / paquete)

```al
// ❌ PROHIBIDO sin SetSourceFilter previo
ReservationEntry.SetRange("Lot No.", LotNo);
TrackingSpecification.SetRange("Lot No.", LotNo);
```

**Riesgo:** el mismo lote puede existir en otros documentos o líneas.

### Filtro solo por Entry No.

```al
// ❌ PROHIBIDO — Entry No. no es clave funcional estable
ReservationEntry.SetRange("Entry No.", EntryNo);
```

### Filtro manual de origen incompleto

```al
// ❌ PROHIBIDO — faltan Source Subtype, Source Batch Name y Source Prod. Order Line
ReservationEntry.SetRange("Source Type", Database::"Purchase Line");
ReservationEntry.SetRange("Source ID", PurchaseLine."Document No.");
ReservationEntry.SetRange("Source Ref. No.", PurchaseLine."Line No.");
```

**Solución:** reemplazar con `SetSourceFilter(...)`.

---

## Identidad estándar de origen (Source Identity)

Cuando se filtre tracking/reservation, deben respetarse todos los campos de la identidad de origen:

| Campo | Descripción |
|---|---|
| `Source Type` | Tipo de tabla origen (p.ej. `Database::"Purchase Line"` = 39) |
| `Source Subtype` | Subtipo (p.ej. `Document Type.AsInteger()`) |
| `Source ID` | Clave del documento (p.ej. `Document No.`) |
| `Source Batch Name` | Nombre de lote de diario (vacío para documentos de compra/venta) |
| `Source Prod. Order Line` | Línea de orden de producción (0 para documentos de compra/venta) |
| `Source Ref. No.` | Número de línea del documento |

`SetSourceFilter(..., SetOtherFilters: true)` rellena todos estos campos automáticamente.

---

## Norma DUoM asociada

En DualUoM-BC, la línea de documento actúa como **resumen agregado**:

- La fuente de verdad para valores DUoM por lote son las líneas de tracking/reservation.
- No se debe asumir que una línea tiene un único lote.
- Una línea origen puede tener N lotes.
- El cálculo DUoM de una línea origen debe agregarse desde todas las entradas de
  tracking/reservation que pertenezcan a la misma identidad estándar de origen.
- Si se necesita filtrar por lote, primero se aplica el filtro de origen estándar y
  después el filtro por `Lot No.`.

### Jerarquía de fuente de verdad DUoM

```
Item Tracking Lines (TrackingSpec buffer) → realidad por lote durante recepción
    ↓ persistencia estándar BC
Reservation Entry → persistencia por lote después de confirmar
    ↓ buffers de tracking/posting
Item Journal Line → origen DUoM inmediato para contabilización
    ↓ posting
Item Ledger Entry → histórico definitivo
```

---

## Expectativas de tests

Cuando se cambie lógica de filtrado de tracking/reservation, los tests deben cubrir:

- Una línea origen con un lote.
- Una línea origen con varios lotes.
- El mismo `Lot No.` usado en otro documento/línea origen (no debe mezclarse).
- Agregación de DUoM Second Qty y ratio desde todas las líneas de tracking relacionadas.

---

## Cuándo puede mantenerse un filtro manual

Un filtro manual solo puede mantenerse si:

1. No existe método estándar equivalente.
2. Se ha aplicado previamente `SetSourceFilter(...)`.
3. El filtro manual es complementario y no sustituye la identidad de origen.
4. Hay un comentario técnico claro en el código explicando el motivo.
5. Está cubierto por test si afecta lógica funcional.

### Ejemplo aceptable

```al
// Filtro estándar de origen aplicado primero:
ReservationEntry.SetSourceFilter(
    Database::"Purchase Line",
    PurchaseLine."Document Type".AsInteger(),
    PurchaseLine."Document No.",
    PurchaseLine."Line No.",
    true);
// Filtro complementario de lote (después del origen — seguro):
ReservationEntry.SetRange("Lot No.", LotNo);
```

### Ejemplo no aceptable

```al
// Solo lote, sin origen — NUNCA hacer esto:
ReservationEntry.SetRange("Lot No.", LotNo);
```
