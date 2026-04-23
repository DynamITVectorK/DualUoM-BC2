# Issue 14 — Corrección de tests IJL con trazabilidad de lotes y restauración del pre-relleno DUoM

## Contexto

**Issue:** #14 — Fix lot-tracked item journal tests and restore lot-specific DUoM ratio prefill
**Milestone:** Phase 2 — Funcionalidad extendida
**Etiquetas:** `bug`, `lot-tracking`, `item-tracking`, `tdd`, `tests`, `al`
**Fecha de implementación:** 2026-04-23

---

## Problema

Cuatro tests de `DUoM Lot Ratio Tests` (codeunit 50217) fallaban en CI:

| Test | Error |
|------|-------|
| `IJLPosting_SaleLot_ILEHasAbsQtyTimesLotRatio` | "You must assign a lot number for item X. Line No. = '10000'" |
| `IJLPosting_TwoLots_EachILEHasLotSpecificRatio` | Mismo error de trazabilidad |
| `IJLPosting_SingleLot_ILEHasLotSpecificRatio` | Mismo error de trazabilidad |
| `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` | Esperado 0.38, obtenido 0.40 (ratio genérico en lugar de ratio de lote) |

### Causa raíz — T01 (pre-relleno)

El test T01 llamaba a `EnableLotTrackingOnItem(Item)` antes de `Validate("Lot No.", ...)`.
Con `"Lot Specific Tracking" = true` activado en el `Item Tracking Code` y **sin una
`Reservation Entry` de respaldo**, BC 27 limpia el campo `"Lot No."` durante la validación
(`OnValidate`). Esto hace que `OnAfterValidateEvent` se dispare con `Rec."Lot No." = ''`,
lo que provoca que el subscriber salga sin aplicar el ratio de lote. El resultado es que
`DUoM Ratio` se mantiene en 0,40 (ratio genérico del artículo) en lugar de 0,38.

`EnableLotTrackingOnItem` **no es necesario** para un test de validación de campo que no
contabiliza. Sin seguimiento de lotes activo, BC 27 acepta y mantiene cualquier `Lot No.`
en un `Item Journal Line` sin restricciones adicionales, y el subscriber funciona correctamente.

### Causa raíz — T04/T05/T06 (contabilización)

Los tests de contabilización usaban `Validate("Lot No.", LotNo)` directamente en el IJL,
pero con `"Lot Specific Tracking" = true`, BC 27 requiere **`Reservation Entries`** con
`Status = Surplus` para validar la completitud del seguimiento antes de contabilizar.
Sin las `Reservation Entries`, el motor de posting lanza el error de asignación de lote
aunque `"Lot No."` esté indicado en el campo del IJL.

---

## Cambios realizados

### `test/src/codeunit/DUoMLotRatioTests.Codeunit.al`

**T01 — `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled`:**
- Eliminada la llamada a `DUoMTestHelpers.EnableLotTrackingOnItem(Item)` y su comentario.
  No es necesaria para un test de pre-relleno de campo; además provocaba que BC 27
  limpiase `"Lot No."` durante la validación, dejando el subscriber sin efecto.

**T04 — `IJLPosting_SingleLot_ILEHasLotSpecificRatio`:**
- Eliminado `ItemJnlLine.Validate("Lot No.", LotNo)`.
- Añadido `DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNo, 10)` para crear la
  `Reservation Entry` necesaria. El ratio de lote se aplica en `TryApplyLotRatioToILE`
  durante la contabilización (no en el subscriber de campo).

**T05 — `IJLPosting_TwoLots_EachILEHasLotSpecificRatio`:**
- Mismo patrón que T04 para ambas líneas (Lote A y Lote B).

**T06 — `IJLPosting_SaleLot_ILEHasAbsQtyTimesLotRatio`:**
- Mismo patrón que T04 para la línea de compra (Qty = 100) y la línea de venta (Qty = 10 — positivo).
  El signo negativo para la salida lo aplica la librería estándar automáticamente.

**Comentarios de cabecera y `[THEN]`:**
- Actualizado el comentario "NOTA SOBRE T04-T06" para reflejar el uso de `Reservation Entries`.
- Eliminadas las notas que indicaban que `ILE."Lot No."` no se poblaría sin Reservation Entries
  (ahora sí se pobla, porque las Reservation Entries están activas).

### `test/src/codeunit/DUoMTestHelpers.Codeunit.al`

**`EnableLotTrackingOnItem`:**
- Reemplazado el `Init/Insert` manual de `Item Tracking Code` por
  `LibraryItemTracking.CreateItemTrackingCode(ItemTrackingCode, false, true)`.
  El código se genera aleatoriamente (sin hardcoding a 'DUoM-LOT'), siguiendo el
  flujo estándar BC. El `Library - Item Tracking` (codeunit 130502) pertenece a
  `Tests-TestLibraries` (ID `5d86850b-0d76-4eca-bd7b-951ad998e997`).

**`AssignLotToItemJnlLine`** (nuevo helper):
- Implementado con `LibraryItemTracking.CreateItemJournalLineItemTracking(ReservEntry, ItemJnlLine, '', LotNo, Qty)`.
  La library aplica el signo correcto internamente vía `ItemJournalLine.Signed(Qty)`:
  para Purchase → `+Qty` en Reservation Entry; para Sale → `−Qty`.
  El caller siempre pasa `Qty` como valor positivo (user-facing), igual a `ItemJnlLine.Quantity`.

### Código de producción

**No se requirieron cambios en el código de producción.** Los codeunits de producción
`DUoMLotSubscribers` (50108) y `DUoMInventorySubscribers` (50104) funcionan correctamente
con el flujo estándar de `Reservation Entries`:

- `OnAfterValidateItemJnlLineLotNo`: sigue aplicando el ratio de lote cuando se valida
  `"Lot No."` directamente en un IJL (flujo T01/T02/T03 sin trazabilidad formal).
- `TryApplyLotRatioToILE`: aplica el ratio de lote al ILE durante la contabilización,
  usando `ItemJournalLine."Lot No."` que BC popula desde la `Reservation Entry` al dividir
  la línea por lote.

---

## Criterios de aceptación cumplidos

- [x] `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled`: `DUoM Ratio = 0,38` tras validar `Lot No.`
- [x] `IJLPosting_SingleLot_ILEHasLotSpecificRatio`: ILE con `DUoM Ratio = 0,38`
- [x] `IJLPosting_TwoLots_EachILEHasLotSpecificRatio`: cada ILE con su ratio específico
- [x] `IJLPosting_SaleLot_ILEHasAbsQtyTimesLotRatio`: ILE salida con `DUoM Second Qty = 4,2`
- [x] Asignación de lote vía mecanismo estándar BC 27 (`Library - Item Tracking`, codeunit 130502)
- [x] `Library - Item Tracking.CreateItemTrackingCode` usado en `EnableLotTrackingOnItem`
- [x] `Library - Item Tracking.CreateItemJournalLineItemTracking` usado en `AssignLotToItemJnlLine`
- [x] Sin creación manual de `Reservation Entry` ni de `Item Tracking Code`
- [x] Ratio de lote específico cargado correctamente desde `DUoM Lot Ratio` (tabla 50102)
- [x] Sin fallback incorrecto al ratio genérico del artículo
- [x] Precisión decimal preservada (0,38, no redondeado a 0,4)
- [x] Documentación actualizada

---

## Referencias

- Issue 13: `docs/issues/issue-13-lot-ratio.md`, `docs/issues/issue-13-lot-tracking-integration.md`
- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` (50108)
- `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al` (50104)
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` (50217)
- `test/src/codeunit/DUoMTestHelpers.Codeunit.al` (50208)
- `docs/05-testing-strategy.md` — Regla "AL Test Data Creation"
