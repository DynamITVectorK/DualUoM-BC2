# Issue 154 — Fix: ratio real por lote no se aplica al validar Lot No. en Item Journal Line

## Contexto

**Milestone:** Phase 2 — Funcionalidad extendida
**Etiquetas:** `bug`, `regression`, `lot-ratio`, `test`, `BC27`
**Fecha de implementación:** 2026-04-27

---

## Problema

El test `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` (T01, codeunit 50217)
fallaba en CI con el error:

| Test | Error |
|------|-------|
| `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` | `Expected:<0.38> Actual:<0.4>` — el ratio por defecto del artículo (0,40) prevalecía sobre el ratio de lote (0,38) |

El escenario:
- Artículo con DUoM Variable, ratio por defecto `0,40`.
- Lote `LOTE-T01` con ratio registrada `0,38` en `DUoM Lot Ratio`.
- Al validar `"Lot No."` en `Item Journal Line`, el suscriptor encontraba correctamente el ratio
  de lote (`0,38`) pero la llamada posterior a `Rec.Validate("DUoM Ratio", 0.38)` provocaba que
  BC 27 restaurara el valor `0,40` a través de la cadena de validación interna, sin que el valor
  `0,38` llegara a persistirse en el buffer del registro llamante.

---

## Causa raíz

El suscriptor `OnAfterValidateItemJnlLineLotNo` en `DUoMLotSubscribers` (50108) usaba el
siguiente patrón (heredado de Issues 16 y 18):

```al
// ANTES (Issue 18 — Validate, puede restaurar ratio por defecto en BC 27):
ApplyLotRatioIfExists(..., NewRatio, NewSecondQty);
Rec.Validate("DUoM Ratio", NewRatio);   // ← provoca que BC restaure 0,40
Rec."DUoM Second Qty" := NewSecondQty;
```

En BC 27, llamar a `Rec.Validate("DUoM Ratio", ...)` dentro de un suscriptor
`OnAfterValidateEvent` para otro campo ("Lot No.") genera una validación anidada
que puede restaurar el valor del campo al valor por defecto del artículo desde el
setup DUoM, sobrescribiendo el ratio de lote recién calculado.

---

## Corrección aplicada

### `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`

**`OnAfterValidateItemJnlLineLotNo`:**

```al
// ANTES (Issue 18 — Validate, no persiste 0,38 en BC 27):
ApplyLotRatioIfExists(Rec."Item No.", Rec."Lot No.", Rec."Variant Code",
                      Rec.Quantity, NewRatio, NewSecondQty);
Rec.Validate("DUoM Ratio", NewRatio);
Rec."DUoM Second Qty" := NewSecondQty;

// DESPUÉS (Issue 154 — := condicional, solo cuando ratio de lote encontrada):
if TryApplyLotRatioIfExists(
    Rec."Item No.", Rec."Lot No.", Rec."Variant Code",
    Rec.Quantity, NewRatio, NewSecondQty)
then begin
    Rec."DUoM Ratio" := NewRatio;
    Rec."DUoM Second Qty" := NewSecondQty;
end;
```

La asignación directa (`:=`) funciona aquí porque en el flujo del test T01/T11 no existe
`Modify(true)` entre la creación de la línea y la llamada a `Validate("Lot No.")`.

**`ApplyLotRatioIfExists` → `TryApplyLotRatioIfExists`:**

Convertido a función que devuelve `Boolean`:
- `true` si se encontró y aplicó una ratio de lote.
- `false` si Item No. vacío, Lot No. vacío, sin setup efectivo, modo Fixed, o sin ratio registrada.

**`ApplyLotRatioToRecord` → `TryApplyLotRatioToRecord`:**

Convertido a función que devuelve `Boolean`:
- `true` si se aplicó el ratio de lote.
- `false` si modo Fixed o no existe ratio registrada para (ItemNo, LotNo).

**`TryApplyLotRatioToILE`:**

Actualizado para llamar a `TryApplyLotRatioToRecord` (nombre renombrado). Comportamiento
sin cambios (el valor de retorno se ignora en este contexto).

---

### `test/src/codeunit/DUoMLotRatioTests.Codeunit.al`

Añadido nuevo test **T11** `T11_VariableMode_LotWithRatio_DUoMFieldsPreFilled`:

- Verifica la precondición: ratio del lote en BD = 0,38.
- Verifica la precondición: línea con ratio por defecto (0,40) antes de validar el lote.
- Verifica la precondición: DUoM Second Qty = 4,0 antes de validar el lote.
- Verifica que tras `Validate("Lot No.")`, `DUoM Ratio = 0,38`.
- Verifica que tras `Validate("Lot No.")`, `DUoM Second Qty = 3,8`.

Este test es una versión reforzada de T01 que documenta explícitamente la regla funcional
clave: **el ratio de lote prevalece sobre el ratio por defecto del artículo en modo Variable**.

---

## Regla funcional preservada

| Modo | Ratio de lote registrada | Comportamiento |
|------|--------------------------|----------------|
| `Fixed` | — | Ratio fija del artículo. El lote no sobrescribe. |
| `Variable` | Sí | Ratio del lote prevalece. |
| `Variable` | No | Sin cambios. Ratio por defecto del artículo. |
| `AlwaysVariable` | Sí | Ratio del lote prevalece. |
| `AlwaysVariable` | No | Sin cambios. `DUoM Ratio = 0`. |

---

## Criterios de aceptación cumplidos

- [x] Test `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` (T01) → `DUoM Ratio = 0,38`
- [x] Nuevo test `T11_VariableMode_LotWithRatio_DUoMFieldsPreFilled` → `DUoM Ratio = 0,38`
- [x] Tests T02–T10 → sin regresión
- [x] Modo Fixed sigue sin permitir sobrescritura por ratio de lote
- [x] No se cambia el expected del test a `0,4`
- [x] No se desactiva ningún test

---

## Archivos modificados

- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` — corrección subscriber + renombrado helpers
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` — nuevo test T11
- `docs/06-backlog.md` — Issue 154 añadido
- `docs/issues/issue-154-fix-lot-ratio-subscriber-validate.md` — este fichero

---

## Referencias

- Issue 13: Ratio real por lote (implementación original)
- Issue 14: Fix tests IJL con trazabilidad de lotes
- Issue 15: Fix prefill con flujo estándar BC
- Issue 16: Fix precisión decimal tras validar Lot No.
- Issue 17: Fix asignación directa en subscriber de lote
- Issue 18: Fix propagación con Validate (revertido parcialmente en este issue)
- Issue 19: Fix T01 eliminando Modify(true) previo
- Issue 20: Eliminar asunciones 1:1 línea/lote
