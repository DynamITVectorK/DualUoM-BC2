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
son **copias puras**: no calculan ratio, no aplican signo y no consultan tablas externas.
Si el IJL llega con valores DUoM incorrectos, el bug está **upstream** (flujo de compra/venta,
tracking split o undo), no en la capa final.

### `OnAfterInitItemLedgEntry` — asignación pura (codeunit 50104)

El subscriber `OnAfterInitItemLedgEntry` de `DUoM Inventory Subscribers` (50104) es una
**asignación pura**: copia los campos DUoM directamente del IJL al ILE, sin cálculos ni
lógica condicional. La responsabilidad de que el IJL llegue con los valores correctos
(signo incluido) corresponde a los subscribers upstream de cada flujo.

```al
// ✅ CORRECTO — asignación pura en OnAfterInitItemLedgEntry (50104)
NewItemLedgEntry."DUoM Ratio" := ItemJournalLine."DUoM Ratio";
NewItemLedgEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";
```

### `ILECopyTrackingFromItemJnlLine` — asignación pura (codeunit 50110)

Para artículos con Item Tracking (lotes / series), el subscriber
`ILECopyTrackingFromItemJnlLine` en `DUoM Tracking Copy Subscribers` (50110) es también
una **asignación pura**: copia los campos DUoM directamente del IJL split por lote al ILE.
No recalcula ratio, no aplica signo, no consulta `DUoM Lot Ratio` (50102).

```al
// ✅ CORRECTO — asignación pura en ILECopyTrackingFromItemJnlLine (50110)
ItemLedgerEntry."DUoM Ratio" := ItemJnlLine."DUoM Ratio";
ItemLedgerEntry."DUoM Second Qty" := ItemJnlLine."DUoM Second Qty";
```

### `OnAfterInitValueEntry` — asignación pura desde IJL (codeunit 50104)

El subscriber `OnAfterInitValueEntry` copia `DUoM Second Qty` directamente desde
`ItemJournalLine`, **no** desde `ItemLedgEntry`.

```al
// ✅ CORRECTO — copia desde IJL en OnAfterInitValueEntry (50104)
ValueEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";

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

// ❌ PROHIBIDO — lógica de signo o cálculo en los subscribers finales ILE/VE
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
- Establecer `DUoM Second Qty` con el **signo correcto** para el tipo de corrección
  (porque los subscribers finales son copias puras):
  - Undo recepción compra → ILE corrección con Qty < 0 → `IJL.DUoM Second Qty = -Abs(PurchRcptLine.DUoM Second Qty)`
  - Undo envío venta → ILE corrección con Qty > 0 → `IJL.DUoM Second Qty = +Abs(SalesShipmentLine.DUoM Second Qty)`

```al
// ✅ CORRECTO — upstream subscriber para undo receipt (sin trazabilidad)
if (ItemJournalLine."Lot No." <> '') or (ItemJournalLine."Serial No." <> '') then
    exit;  // trazabilidad ya pobló los valores per-lote desde el ILE original (50110)
if PurchRcptLine."DUoM Ratio" = 0 then
    exit;  // artículo sin DUoM
ItemJournalLine."DUoM Ratio" := PurchRcptLine."DUoM Ratio";
ItemJournalLine."DUoM Second Qty" := -Abs(PurchRcptLine."DUoM Second Qty");  // signo negativo

// ✅ CORRECTO — upstream subscriber para undo shipment (sin trazabilidad)
if (ItemJournalLine."Lot No." <> '') or (ItemJournalLine."Serial No." <> '') then
    exit;
if SalesShipmentLine."DUoM Ratio" = 0 then
    exit;
ItemJournalLine."DUoM Ratio" := SalesShipmentLine."DUoM Ratio";
ItemJournalLine."DUoM Second Qty" := Abs(SalesShipmentLine."DUoM Second Qty");  // signo positivo
```

### Implementación de referencia

Ver codeunit 50104 `DUoM Inventory Subscribers` (subscribers `OnAfterInitItemLedgEntry`
y `OnAfterInitValueEntry`) y codeunit 50110 `DUoM Tracking Copy Subscribers`
(subscriber `ILECopyTrackingFromItemJnlLine`) para los patrones de asignación pura.

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
    ↓ sync en OnQueryClosePage
Purchase Line → resumen agregado
    ↓ persiste en OK
Reservation Entry → persistencia por lote después de confirmar
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
