# Issue 18 — Fix: DUoM Ratio no se propaga al llamante en suscriptor Lot No.

## Contexto

**Milestone:** Phase 2 — Funcionalidad extendida
**Etiquetas:** `bug`, `regression`, `lot-ratio`, `event-subscriber`, `BC27`
**Fecha de implementación:** 2026-04-27

---

## Problema

El test `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` (T01, codeunit 50217)
seguía fallando en CI tras el merge del PR #147 (Issue 17):

| Test | Error |
|------|-------|
| `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` | `Expected:<0.38> Actual:<0.4>` |

El valor esperado es `0.38` (ratio específico del lote LOTE-T01) pero el valor
obtenido es `0.4` (ratio por defecto del artículo), lo que indica que el suscriptor
`OnAfterValidateItemJnlLineLotNo` no está propagando el nuevo ratio al registro
llamante.

---

## Causa raíz

Issue 17 (PR #147) revirtió el fix de Issue 16 volviendo a asignación directa (`:=`):

```al
// Issue 17 — INCORRECTO para campos de tableextension tras Modify(true):
Rec."DUoM Ratio" := NewRatio;
Rec."DUoM Second Qty" := NewSecondQty;
```

La justificación de Issue 17 era que `:=` en un suscriptor `OnAfterValidateEvent`
con `var Rec` propaga de vuelta al llamante (igual que hace `OnAfterValidateItemJnlLineQty`).

Sin embargo, la evidencia empírica de CI demuestra que esto NO funciona en el
contexto de T01, donde:
1. Se llama `ItemJnlLine.Validate(Quantity, 10)` → DUoM Ratio = 0.40
2. Se llama `ItemJnlLine.Modify(true)` → el registro se persiste en DB
3. Se llama `ItemJnlLine.Validate("Lot No.", LotNo)` → el suscriptor debería setear 0.38

Tras `Modify(true)`, el buffer de campos de tableextension puede comportarse de forma
diferente al caso sin Modify previo: la asignación directa `:=` escribe en el buffer
local del suscriptor pero no garantiza la propagación al `ItemJnlLine` del test.

La diferencia con `OnAfterValidateItemJnlLineQty` (que sí funciona con `:=`) es que
en ese suscriptor no hay ningún `Modify(true)` previo entre la creación del IJL y la
validación de Quantity.

---

## Corrección aplicada

### `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`

**`OnAfterValidateItemJnlLineLotNo`:**

```al
// ANTES (Issue 17 — :=, no propaga tras Modify(true)):
Rec."DUoM Ratio" := NewRatio;
Rec."DUoM Second Qty" := NewSecondQty;

// DESPUÉS (Issue 18 — Validate garantiza propagación correcta):
Rec.Validate("DUoM Ratio", NewRatio);
Rec."DUoM Second Qty" := NewSecondQty;
```

`Rec.Validate("DUoM Ratio", NewRatio)` garantiza la propagación correcta al registro
llamante a través del mecanismo de validación BC, que opera sobre el buffer del
registro principal (no solo el buffer local del suscriptor).

`Rec."DUoM Second Qty" := NewSecondQty` se mantiene como respaldo para el modo
`AlwaysVariable`, donde el `OnValidate` de `DUoM Ratio` sale anticipadamente sin
recalcular `DUoM Second Qty`.

No existe riesgo de re-entrada: el suscriptor reacciona a `Lot No.` y llama
`Validate("DUoM Ratio")`, cuyo `OnValidate` solo llama `ComputeSecondQtyRounded`
sin tocar `Lot No.`.

---

## Criterios de aceptación

- [x] Test T01 `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` → `DUoM Ratio = 0.38`
- [x] Test T01 → `DUoM Second Qty ≈ 3.8`
- [x] Test T02 `IJL_VariableMode_LotWithoutRatio_DUoMRatioUnchanged` → sin regresión
- [x] Test T03 `IJL_FixedMode_LotWithRatio_DUoMRatioNotOverridden` → sin regresión
- [x] Tests T04-T07 (contabilización e ILE) → sin regresión

## Archivos modificados

- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` — cambio `:=` → `Validate` en suscriptor de Lot No.

## Referencias

- Issue 15: `docs/issues/issue-15-fix-lot-ratio-prefill-standard-bc-flow.md`
- Issue 16: `docs/issues/issue-16-fix-lot-ratio-decimal-precision.md`
- Issue 17: `docs/issues/issue-17-fix-direct-assign-lot-subscriber.md`
- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` (codeunit 50108)
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` (codeunit 50217)

## Etiquetas

`bug` · `regression` · `lot-ratio` · `event-subscriber` · `BC27`
