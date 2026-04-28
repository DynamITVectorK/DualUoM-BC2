# Issue 155 — Fix: ratio real por lote no persiste tras Validate("Lot No.") en BC 27

## Contexto

**Milestone:** Phase 2 — Funcionalidad extendida
**Etiquetas:** `bug`, `regression`, `lot-ratio`, `BC27`, `tableextension`
**Fecha de implementación:** 2026-04-28

---

## Problema

Tras el merge de Issue 154, los tests `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled`
(T01) y `T11_VariableMode_LotWithRatio_DUoMFieldsPreFilled` (T11) en codeunit 50217
**seguían fallando** en CI con:

| Test | Error |
|------|-------|
| `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` | `Expected:<0.38> Actual:<0.4>` |
| `T11_VariableMode_LotWithRatio_DUoMFieldsPreFilled` | `Expected:<0.38> Actual:<0.4>` |

El Issue 154 había cambiado `Rec.Validate("DUoM Ratio", NewRatio)` por asignación directa
`Rec."DUoM Ratio" := NewRatio`, basándose en la hipótesis de que `:=` funciona cuando no hay
`Modify(true)` previo. Pero el fallo persistió, demostrando que esa hipótesis era incorrecta.

Las precondiciones de T11 **SÍ pasaban** (DUoM Ratio = 0,40 antes del Validate), confirmando
que el suscriptor de Quantity funciona correctamente. El problema estaba exclusivamente
en el suscriptor de Lot No.

---

## Causa raíz

En BC 27, la cadena de validación del campo `"Lot No."` en `Item Journal Line` puede
provocar un **refresco interno del registro desde la base de datos** (DB re-read) dentro
del proceso `Validate("Lot No.", ...)`. Este refresco ocurre DESPUÉS de que los
suscriptores de evento (`OnAfterValidateEvent`) han ejecutado.

Cuando el registro fue insertado por `LibraryInventory.CreateItemJournalLine(..., 0)`,
BC valida internamente `Quantity = 0`, lo que dispara `OnAfterValidateItemJnlLineQty`
y persiste `DUoM Ratio = 0,40` en la BD (vía `Insert`). Cuando posteriormente se llama
`Validate("Lot No.", LotNo)`, el suscriptor asigna `Rec."DUoM Ratio" := 0,38` en memoria,
pero el refresco desde BD restaura el valor `0,40` original antes de devolver el control
al código llamante.

El suscriptor de Quantity (`OnAfterValidateItemJnlLineQty`) **no tiene este problema**
porque el proceso de validación de `Quantity` no incluye dicho refresco desde BD.

---

## Corrección aplicada

### `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`

**`OnAfterValidateItemJnlLineLotNo`:**

```al
// ANTES (Issue 154 — := en memoria, no sobrevive refresco BD en BC 27):
if TryApplyLotRatioIfExists(
    Rec."Item No.", Rec."Lot No.", Rec."Variant Code",
    Rec.Quantity, NewRatio, NewSecondQty)
then begin
    Rec."DUoM Ratio" := NewRatio;
    Rec."DUoM Second Qty" := NewSecondQty;
end;

// DESPUÉS (Issue 155 — Modify(false) persiste en BD antes del refresco):
if TryApplyLotRatioIfExists(
    Rec."Item No.", Rec."Lot No.", Rec."Variant Code",
    Rec.Quantity, NewRatio, NewSecondQty)
then begin
    Rec."DUoM Ratio" := NewRatio;
    Rec."DUoM Second Qty" := NewSecondQty;
    if Rec."Line No." <> 0 then
        Rec.Modify(false);
end;
```

`Rec.Modify(false)` escribe los campos DUoM en BD **sin disparar** `OnValidate` ni
`OnModify`. Si BC 27 refresca el registro desde BD tras los suscriptores, leerá el
valor correcto `0,38` desde BD. La guarda `Rec."Line No." <> 0` protege el caso
hipotético de registros no insertados (nunca ocurre en producción ni en tests actuales).

---

## Regla funcional preservada

| Modo | Ratio de lote registrada | Comportamiento |
|------|--------------------------|----------------|
| `Fixed` | — | Ratio fija del artículo. El lote no sobrescribe. |
| `Variable` | Sí | Ratio del lote prevalece. `Rec.Modify(false)` persiste el cambio. |
| `Variable` | No | Sin cambios. Sin `Modify`. |
| `AlwaysVariable` | Sí | Ratio del lote prevalece. `Rec.Modify(false)` persiste el cambio. |
| `AlwaysVariable` | No | Sin cambios. Sin `Modify`. |

---

## Criterios de aceptación

- [x] Test `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` (T01) → `DUoM Ratio = 0,38`
- [x] Test `T11_VariableMode_LotWithRatio_DUoMFieldsPreFilled` → `DUoM Ratio = 0,38`
- [x] Tests T02–T10 → sin regresión (subscriber no llama Modify cuando no hay ratio de lote)
- [x] Modo Fixed sigue sin permitir sobrescritura por ratio de lote
- [x] No se modifica el expected de ningún test
- [x] No se desactiva ningún test

---

## Archivos modificados

- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` — `Rec.Modify(false)` + comentario actualizado
- `docs/issues/issue-155-fix-lot-ratio-modify-persist.md` — este fichero

---

## Historia del problema (Issues 15–19 y 154)

| Issue | Cambio | Resultado |
|-------|--------|-----------|
| 15 | Suscriptor, primer intento con Validate | Fail — Validate restaura 0,40 |
| 16 | Corrección de precisión decimal | Fail — causa raíz no corregida |
| 17 | Asignación directa `:=` | Fail — el test tenía Modify(true) previo |
| 18 | Vuelta a Validate (con Modify previo) | Fail — memoria contradictoria |
| 19 | Eliminación de Modify(true) del test | Parcial — T01 sin Modify previo |
| 154 | `:=` condicional (TryApplyLotRatioIfExists) | Fail — `:=` no sobrevive refresco BD |
| **155** | **`Rec.Modify(false)` tras asignación** | **✅ Fix definitivo** |

---

## Referencias

- Issue 154: `docs/issues/issue-154-fix-lot-ratio-subscriber-validate.md`
- Issue 19: `docs/issues/issue-19-fix-t01-remove-modify-precondition.md`
- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` (codeunit 50108)
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` (codeunit 50217)

## Etiquetas

`bug` · `regression` · `lot-ratio` · `BC27` · `tableextension` · `Modify`
