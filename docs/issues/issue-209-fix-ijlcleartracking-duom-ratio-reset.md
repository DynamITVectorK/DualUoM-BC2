# Issue 209 — Fix: IJLClearTracking borraba DUoM Ratio en IJL → regresión sistémica

## Estado: ✅ IMPLEMENTADO

## 1. Problema

Múltiples tests de posting y de validación fallaban con `Actual:<0>` para `DUoM Ratio`:

| Test | Esperado | Actual |
|------|----------|--------|
| T02 `IJL_VariableMode_LotWithoutRatio_DUoMRatioUnchanged` | 0.40 | 0 |
| T03 `IJL_FixedMode_LotWithRatio_DUoMRatioNotOverridden` | 1.0 | 0 |
| T04 `IJLPosting_SingleLot_ILEHasLotSpecificRatio` | 0.38 | 0 |
| T05 `IJLPosting_TwoLots_EachILEHasLotSpecificRatio` | 0.38 | 0 |
| T06 `IJLPosting_SaleLot_ILEHasAbsQtyTimesLotRatio` | 0.42 | 0 |
| T08 `IJLPosting_OneLine_TwoLotsTracking_EachILEHasLotRatio` | 0.38 | 0 |
| T09 `IJLPosting_OneLine_TwoLots_TotalDUoMEqualsSum` | 3.98 | 0 |
| T13 `T13_TwoLots_NoLotRatioDB_ProportionalSecondQty` | 1.5 | 0 |
| T14 `T14_AlwaysVar_ManualRatioOnIJL_ILEHasRatio` | 2.5 | 0 |

El patrón `Actual:<0>` en todos los tests indicaba un fallo sistémico, no un caso aislado.

## 2. Causa raíz

El PR #203 ("completar patrón OnAfterCopyTracking* — Issue 25") añadió un subscriber
`IJLClearTracking` en `DUoMTrackingCopySubscribers.Codeunit.al` que limpiaba
`DUoM Ratio := 0` y `DUoM Second Qty := 0` en `Item Journal Line` cuando BC llamaba
al evento `OnAfterClearTracking`:

```al
// ❌ SUBSCRIBER PROBLEMÁTICO — eliminado en Issue 209
[EventSubscriber(ObjectType::Table, Database::"Item Journal Line",
    'OnAfterClearTracking', '', false, false)]
local procedure IJLClearTracking(
    var ItemJournalLine: Record "Item Journal Line")
begin
    ItemJournalLine."DUoM Ratio" := 0;
    ItemJournalLine."DUoM Second Qty" := 0;
end;
```

BC llama a `Item Journal Line.ClearTracking()` en **dos contextos críticos**:

1. **Durante `Validate("Lot No.")`**: BC limpia los campos de trazabilidad anteriores
   antes de asignar el nuevo número de lote. Esto borraría el `DUoM Ratio` previamente
   establecido, rompiendo T02 y T03.

2. **Durante el split de posting con Item Tracking**: BC crea una copia del IJL original
   para cada lote, llama `ClearTracking()` para limpiar identificadores de trazabilidad
   antes de llamar `CopyTrackingFromSpec`. Esto borraba `DUoM Ratio` y `DUoM Second Qty`
   ANTES de que los subscribers `OnAfterInitItemLedgEntry` e
   `ILECopyTrackingFromItemJnlLine` pudieran usarlos.

### Cadena de fallo (posting con Item Tracking, ejemplo T04)

```
1. IJL.Validate(Quantity, 10) → OnAfterValidateItemJnlLineQty → IJL.DUoM Ratio=0.40
2. AssignLotToItemJnlLine → crea ReservEntry (DUoM Ratio=0 por library estándar)
3. Posting split por lote:
   a. BC crea copia del IJL (DUoM Ratio=0.40)
   b. BC llama IJL.ClearTracking() → IJLClearTracking fires → DUoM Ratio=0 ← BUG
   c. BC llama IJL.CopyTrackingFromSpec(TrackingSpec)
      TrackingSpec.DUoM Ratio=0 (de ReservEntry que tiene 0)
      → IJLCopyTrackingFromSpec exits (guarda: TrackingSpec.DUoM Ratio=0)
      → IJL.DUoM Ratio sigue en 0
   d. ILE se crea con: IJL.DUoM Ratio=0, IJL.DUoM Second Qty=0
      → OnAfterInitItemLedgEntry: guarda (0,0) → exit inmediato
      → ILECopyTrackingFromItemJnlLine: guarda (0,0) → exit inmediato
      → ILE.DUoM Ratio = 0 ❌
```

### Por qué la guarda `(DUoM Ratio=0) AND (DUoM Second Qty=0)` es crítica

Ambos subscribers de ILE (`OnAfterInitItemLedgEntry` y `ILECopyTrackingFromItemJnlLine`)
comparten la misma guarda de salida anticipada:

```al
if (ItemJournalLine."DUoM Ratio" = 0) and (ItemJournalLine."DUoM Second Qty" = 0) then
    exit;
```

`IJLClearTracking` ponía AMBOS campos a 0 simultáneamente, activando esta guarda en
los dos subscribers → ILE quedaba con DUoM Ratio=0 sin posibilidad de corrección.

## 3. Decisión de diseño

`DUoM Ratio` y `DUoM Second Qty` en `Item Journal Line` son **campos económicos de negocio**,
NO identificadores de trazabilidad. La distinción es fundamental:

- `Lot No.`, `Serial No.`, `Package No.` son identificadores de trazabilidad → se deben
  limpiar cuando `ClearTracking()` se llama (para evitar confusión entre lotes).
- `DUoM Ratio`, `DUoM Second Qty` son cantidades derivadas del artículo/lote → deben
  **persistir** a través de la limpieza de identificadores para que el mecanismo de
  propagación `IJL → ILE` pueda funcionar.

El patrón `Package Management (6516)` limpia `Package No.` en `ClearTracking` porque es
un identificador. DUoM Ratio no es un identificador y no debe limpiarse en ese evento.

## 4. Cambio realizado

### `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al`

**Eliminado** el subscriber `IJLClearTracking` (`OnAfterClearTracking` en
`Table "Item Journal Line"`). Los demás subscribers de Clear/Blank para
`Tracking Specification` y `Reservation Entry` se mantienen inalterados
(esos sí son identificadores de trazabilidad).

### `docs/03-technical-architecture.md`

**Actualizado** la sección "Issue 25" en el historial de decisión para documentar la
excepción deliberada: `OnAfterClearTracking` en `Item Journal Line` **no** se implementa
porque causaría borrado de `DUoM Ratio` en momentos críticos del flujo de posting.

## 5. Tests afectados

| Test | Resultado | Estado |
|------|-----------|--------|
| T02 `IJL_VariableMode_LotWithoutRatio_DUoMRatioUnchanged` | DUoM Ratio=0.40 | ✅ Corregido |
| T03 `IJL_FixedMode_LotWithRatio_DUoMRatioNotOverridden` | DUoM Ratio=1.0 | ✅ Corregido |
| T04 `IJLPosting_SingleLot_ILEHasLotSpecificRatio` | DUoM Ratio=0.38 | ✅ Corregido |
| T05 `IJLPosting_TwoLots_EachILEHasLotSpecificRatio` | DUoM Ratio=0.38/0.41 | ✅ Corregido |
| T06 `IJLPosting_SaleLot_ILEHasAbsQtyTimesLotRatio` | DUoM Ratio=0.42 | ✅ Corregido |
| T08 `IJLPosting_OneLine_TwoLotsTracking_EachILEHasLotRatio` | DUoM Ratio=0.38 | ✅ Corregido |
| T09 `IJLPosting_OneLine_TwoLots_TotalDUoMEqualsSum` | Total=3.98 | ✅ Corregido |
| T13 `T13_TwoLots_NoLotRatioDB_ProportionalSecondQty` | DUoM Ratio=1.5 | ✅ Corregido |
| T14 `T14_AlwaysVar_ManualRatioOnIJL_ILEHasRatio` | DUoM Ratio=2.5 | ✅ Corregido |
| T10 `IJLPosting_AlwaysVariable_TwoLots_NoLotRatio_ILESecondQtyIsZero` | ILE=0 | ✅ Sin regresión |

## 6. Documentación actualizada

- `docs/03-technical-architecture.md` — sección "Historial de decisión", punto Issue 25:
  añadida excepción deliberada y su justificación.

## Referencias

- Issue: #209
- PR que introdujo la regresión: #203
- Tests: `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` — T02–T14
- Código: `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al`
