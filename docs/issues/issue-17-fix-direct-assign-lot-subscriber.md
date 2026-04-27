# Issue 17 — Corrección: asignación directa (:=) en suscriptor de Lot No.

## Contexto

**Issue:** #17 — Regresión introducida por Issue 16 (Validate → `:=`)
**Milestone:** Phase 2 — Funcionalidad extendida
**Etiquetas:** `bug`, `regression`, `lot-ratio`, `event-subscriber`, `BC27`
**Fecha de implementación:** 2026-04-24

---

## Problema

El fix de Issue 16 cambió `OnAfterValidateItemJnlLineLotNo` para usar
`Rec.Validate("DUoM Ratio", NewRatio)` en lugar de asignación directa,
basándose en la premisa de que la asignación directa (`:=`) no propagaba
el valor al registro llamante dentro de un event subscriber.

Sin embargo, esto contradice el comportamiento del suscriptor ya existente
`OnAfterValidateItemJnlLineQty` (en `DUoMInventorySubscribers`, codeunit 50104),
que usa asignación directa (`:=`) y funciona correctamente.

El uso de `Rec.Validate("DUoM Ratio", NewRatio)` dentro de `OnAfterValidateEvent`
puede provocar re-entrada (re-entrancy) en la cadena de validación del campo,
causando comportamiento no determinista según el contexto de llamada en BC 27.

---

## Causa raíz

La premisa del Issue 16 era incorrecta:

- En BC AL, cuando un event subscriber recibe `var Rec: Record "..."`, `Rec`
  **sí** está pasado por referencia. La asignación directa `Rec."campo" := valor`
  **sí propaga** el valor al registro en el código llamante.

- El problema original (Issue 15) no era la asignación directa per se, sino que los
  campos de tableextension se pasaban directamente como parámetros `var Decimal` a
  procedimientos helper auxiliares (cadena de var-params anidados). Eso sí impedía
  la propagación.

- El patrón correcto (y consistente con `OnAfterValidateItemJnlLineQty`) es:
  1. Leer el valor actual en variables locales.
  2. Pasar las variables locales al helper.
  3. Asignar directamente a `Rec."campo" := varLocal` tras la llamada.

---

## Corrección aplicada

### `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`

**`OnAfterValidateItemJnlLineLotNo`:**

```al
// ANTES (Issue 16 — Validate, potencial re-entrancy):
Rec.Validate("DUoM Ratio", NewRatio);
Rec."DUoM Second Qty" := NewSecondQty;

// DESPUÉS (Issue 17 — asignación directa, patrón estándar AL):
Rec."DUoM Ratio" := NewRatio;
Rec."DUoM Second Qty" := NewSecondQty;
```

Este patrón es idéntico al que usa `OnAfterValidateItemJnlLineQty` en
`DUoMInventorySubscribers` (codeunit 50104), que funciona correctamente
para los campos `DUoM Ratio` y `DUoM Second Qty`.

---

## Documentación del flujo estándar BC reutilizado

| Elemento | Detalle |
|----------|---------|
| **Evento publisher** | `OnAfterValidateEvent['Lot No.']` en `Table "Item Journal Line"` (tabla 83) |
| **Punto de integración** | El suscriptor `OnAfterValidateItemJnlLineLotNo` reacciona al evento estándar de validación del campo `Lot No.` |
| **Patrón AL estándar** | Variables locales + asignación directa `:=` a `Rec`, igual que `OnAfterValidateItemJnlLineQty` |
| **Flujo BC preservado** | BC gestiona la validación del campo `Lot No.`; el suscriptor DUoM actúa después del procesamiento estándar |

---

## Criterios de aceptación

> **NOTA:** Los criterios marcados a continuación no se cumplieron. El PR #147 introdujo
> una regresión: la asignación directa (`:=`) no propaga el valor de campos de
> tableextension tras una llamada previa a `Modify(true)`. El fix correcto se implementó
> en Issue 18 (`docs/issues/issue-18-fix-lot-ratio-validate-propagation.md`).

- [ ] Test T01 `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` → `DUoM Ratio = 0.38`
- [ ] Test T01 → `DUoM Second Qty ≈ 3.8`
- [x] Test T02 `IJL_VariableMode_LotWithoutRatio_DUoMRatioUnchanged` → sin regresión
- [x] Test T03 `IJL_FixedMode_LotWithRatio_DUoMRatioNotOverridden` → sin regresión
- [x] Tests T04-T07 (contabilización e ILE) → sin regresión
- [x] Patrón consistente con `OnAfterValidateItemJnlLineQty` (asignación directa)

## Archivos modificados

- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` — cambio `Validate()` → `:=` en suscriptor de Lot No.

## Referencias

- Issue 15: `docs/issues/issue-15-fix-lot-ratio-prefill-standard-bc-flow.md`
- Issue 16: `docs/issues/issue-16-fix-lot-ratio-decimal-precision.md`
- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` (codeunit 50108)
- `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al` (codeunit 50104, patrón de referencia)
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` (codeunit 50217)
