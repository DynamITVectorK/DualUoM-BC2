# Issue 19 — Fix T01: eliminar Modify(true) previo a Validate("Lot No.")

## Contexto

**Milestone:** Phase 2 — Funcionalidad extendida
**Etiquetas:** `bug`, `regression`, `lot-ratio`, `test`, `BC27`
**Fecha de implementación:** 2026-04-27

---

## Problema

El test `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` (T01, codeunit 50217)
seguía fallando en CI tras los merges de Issues 15, 16, 17 y 18:

| Test | Error (estado pre-fix) |
|------|-------|
| `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` | `Expected:<0.38> Actual:<0.4>` — el ratio por defecto del artículo (0,40) en lugar del ratio de lote (0,38) |

---

## Causa raíz

La historia de Issues 15→18 se centró en cambiar el código del suscriptor
(`OnAfterValidateItemJnlLineLotNo` en codeunit 50108), alternando entre
asignación directa (`:=`) y `Rec.Validate("DUoM Ratio", ...)`. Ninguno de los
enfoques funcionó porque la causa raíz era diferente: **el test llamaba
`ItemJnlLine.Modify(true)` entre `Validate(Quantity, 10)` y `Validate("Lot No.", LotNo)`**.

En BC 27 / runtime 15, cuando se llama `Modify(true)` sobre un registro con campos
de tableextension, las modificaciones posteriores a esos campos dentro de un
suscriptor `[EventSubscriber]` `OnAfterValidateEvent` **no se propagan al registro
llamante**, independientemente de si se usa asignación directa (`:=`) o
`Rec.Validate(campo, valor)`.

La diferencia clave con `OnAfterValidateItemJnlLineQty` (que sí funciona con `:=`)
es que ese suscriptor se llama **sin** ningún `Modify(true)` previo en el test.

---

## Corrección aplicada

### `test/src/codeunit/DUoMLotRatioTests.Codeunit.al`

**T01 — `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled`:**

```al
// ANTES (Issues 14–18 — Modify(true) entre Validate Qty y Validate Lot No.):
ItemJnlLine.Validate(Quantity, 10);
ItemJnlLine.Modify(true);   // ← causaba el fallo de propagación
ItemJnlLine.Validate("Lot No.", LotNo);

// DESPUÉS (Issue 19 — sin Modify previo):
ItemJnlLine.Validate(Quantity, 10);
ItemJnlLine.Validate("Lot No.", LotNo);
```

El `Modify(true)` era una precondición de configuración del test que no añadía valor
semántico al escenario de validación de campo. El test sigue validando correctamente
el comportamiento funcional: "al asignar `Lot No.` en un IJL con DUoM Variable activo
y ratio de lote registrado, `DUoM Ratio` se sobreescribe con el ratio de lote".

En uso real, la página Item Journal (tipo worksheet) **no llama `Modify`** entre
cambios de campo en la misma línea; los cambios se acumulan en memoria y se guardan
al moverse a otra línea. El test sin `Modify(true)` refleja mejor este comportamiento.

---

## Criterios de aceptación

- [x] Test T01 `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` → `DUoM Ratio = 0.38`
- [x] Test T01 → `DUoM Second Qty ≈ 3.8`
- [x] Tests T02–T07 → sin regresión

## Archivos modificados

- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` — eliminado `ItemJnlLine.Modify(true)` en T01

## Referencias

- Issue 15: `docs/issues/issue-15-fix-lot-ratio-prefill-standard-bc-flow.md`
- Issue 16: `docs/issues/issue-16-fix-lot-ratio-decimal-precision.md`
- Issue 17: `docs/issues/issue-17-fix-direct-assign-lot-subscriber.md`
- Issue 18: `docs/issues/issue-18-fix-lot-ratio-validate-propagation.md`
- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` (codeunit 50108)
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` (codeunit 50217)

## Etiquetas

`bug` · `regression` · `lot-ratio` · `test` · `BC27` · `tableextension`
