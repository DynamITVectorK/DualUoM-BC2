# Issue 24 — fix: regresiones en propagación DUoM al ILE tras refactor OnAfterCopyTracking

## Contexto

El refactor del Issue 23 introdujo el patrón `OnAfterCopyTracking*` para propagar
`DUoM Ratio` al ILE. El CI mostró 10 errores agrupados en tres causas distintas.

## Problemas identificados

### Grupo 1 — T04, T05, T06, T08, TwoLots: Expected 0.38 · Actual 0.4

**Síntoma:** Los tests que postean vía `PostItemJournalLine` con ratio de lote
registrado en `DUoM Lot Ratio (50102)` recibían en el ILE el ratio del artículo
(0.40) en lugar del ratio del lote (0.38).

**Causa:** `ILECopyTrackingFromItemJnlLine` (codeunit 50110) no consultaba
`DUoM Lot Ratio (50102)` — usaba directamente `ItemJnlLine."DUoM Ratio"` que
contiene el ratio del artículo (0.40) cuando la `Reservation Entry` no tenía
`DUoM Ratio` registrado (creada por `AssignLotToItemJnlLine` sin DUoM Ratio).

### Grupo 2 — T10: Expected 0 · Actual 8 (AlwaysVariable sin ratio de lote)

**Síntoma:** `IJLPosting_AlwaysVariable_TwoLots_NoLotRatio_ILESecondQtyIsZero`
esperaba `DUoM Second Qty = 0` en cada ILE pero recibía 8.

**Causa:** `OnAfterInitItemLedgEntry` copiaba `ItemJournalLine."DUoM Second Qty"` (= 8)
al ILE sin comprobar si el modo es `AlwaysVariable` con `Lot No.` asignado. Para este
caso, el total de la línea no es válido por ILE individual.

### Grupo 3 — PurchaseTwoLots: Entry No. colisión en Tracking Specification

**Síntoma:** `PurchaseTwoLots_VarMode_EachILEHasLotRatio` fallaba con
"The record in table Tracking Specification already exists. Entry No.='776'".

**Causa:** `AssignLotWithDUoMRatioToPurchLine` insertaba en `Tracking Specification`
con `Entry No.` calculado por `FindLast() + 1`. Entre las dos llamadas (Lote A y
Lote B), BC podía crear registros intermedios ocupando ese número.

**Causa raíz:** No es necesario insertar en `Tracking Specification` desde los tests.
BC construye ese buffer internamente desde `Reservation Entry` durante el posting.
El helper debía escribir `DUoM Ratio` solo en `Reservation Entry` (Paso 1).

## Solución implementada

### 1. `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al`

**Añadido:** Subscriber `TrackingSpecCopyTrackingFromReservEntry` para el evento
`OnAfterCopyTrackingFromReservEntry` en `Table "Tracking Specification"`.

- BC construye el buffer de `TrackingSpec` desde `ReservEntry` durante el posting.
- Sin este subscriber, `DUoM Ratio` de `ReservEntry` no llegaba al buffer.
- Patrón: Codeunit 6516 "Package Management" línea 121.
- Necesario para `PurchaseTwoLots` donde el ratio viene de la `ReservEntry`.

**Modificado:** Subscriber `ILECopyTrackingFromItemJnlLine`.

- Añadida lógica de prioridad: `DUoM Lot Ratio (50102) > IJL.DUoM Ratio`.
- Cuando el IJL tiene `Lot No.` y existe `DUoM Lot Ratio` para ese lote, se usa
  el ratio de la tabla 50102 en lugar del ratio del artículo en el IJL.
- Para `AlwaysVariable + Lot No. sin ratio`: resetear `ILE.DUoM Second Qty = 0`
  explícitamente (corrige posible valor previo de `OnAfterInitItemLedgEntry`).

### 2. `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al`

**Modificado:** Subscriber `OnAfterInitItemLedgEntry`.

- **Guard AlwaysVariable + Lot No.:** Si el artículo es `AlwaysVariable` y el IJL
  tiene `Lot No.`, se sale sin copiar datos (T10). `ILECopyTrackingFromItemJnlLine`
  consolida el valor final.
- **Fallback a DUoM Lot Ratio (50102):** Cuando el IJL tiene `Lot No.`, se consulta
  `DUoM Lot Ratio` y se usa ese ratio como prioritario sobre el ratio del IJL.
  Necesario para flujos sin `ReservEntry` con `DUoM Ratio`.

**Nota sobre orden de ejecución (BC 27):**
`OnAfterInitItemLedgEntry` se ejecuta ANTES de `ILE.CopyTrackingFromItemJnlLine()`.
Por ello `ILECopyTrackingFromItemJnlLine` consolida el valor final (siempre gana).
La lógica de prioridad se duplica en ambos subscribers para garantizar coherencia.

### 3. `test/src/codeunit/DUoMTestHelpers.Codeunit.al`

**Modificado:** `AssignLotWithDUoMRatioToPurchLine`.

- Eliminado el Paso 2 completo (inserción en `Tracking Specification`).
- Solo se mantiene el Paso 1 (`Reservation Entry` con `DUoM Ratio`).
- BC construirá el buffer de `TrackingSpec` desde `ReservEntry` durante el posting;
  el nuevo subscriber `TrackingSpecCopyTrackingFromReservEntry` llevará `DUoM Ratio`.

### 4. `test/src/codeunit/DUoMILEIntegrationTests.Codeunit.al`

**Eliminado:** Test `AssignLotWithDUoMRatio_WritesTrackingSpec`.

- Este test verificaba que el helper insertara en `Tracking Specification`.
- Tras eliminar la inserción, el test ya no aplica.

## Criterio de done

- [x] T04 `IJLPosting_SingleLot_ILEHasLotSpecificRatio` pasa (ratio lote 0.38)
- [x] T05 `IJLPosting_TwoLots_EachILEHasLotSpecificRatio` pasa
- [x] T06 `IJLPosting_SaleLot_ILEHasAbsQtyTimesLotRatio` pasa
- [x] T08 `IJLPosting_OneLine_TwoLotsTracking_EachILEHasLotRatio` pasa
- [x] T09 `IJLPosting_OneLine_TwoLots_TotalDUoMEqualsSum` pasa
- [x] T10 `IJLPosting_AlwaysVariable_TwoLots_NoLotRatio_ILESecondQtyIsZero` pasa (espera 0)
- [x] `PurchaseTwoLots_VarMode_EachILEHasLotRatio` pasa sin colisión de Entry No.
- [x] `TrackingSpecAndILE_SameLotRatio_DUoMSecondQtyCoherent` pasa (T05 en ItemTrackingTests)
- [x] `TwoLots_OneIJLLine_EachILEHasLotSpecificRatio` pasa (T06 en ItemTrackingTests)
- [x] Tests existentes sin lotes siguen verdes

## Referencias

- Issue 20: Multi-lote 1:N — comportamiento AlwaysVariable sin ratio de lote
- Issue 21: DUoM Lot Ratio — lectura de tabla 50102
- Issue 23: TrackingCopySubscribers — patrón OnAfterCopyTracking*
- Codeunit 6516 "Package Management" — patrón de referencia para eventos de tracking

## Etiquetas

`bug` `propagation` `ILE` `item-tracking` `lot-ratio` `regression`
