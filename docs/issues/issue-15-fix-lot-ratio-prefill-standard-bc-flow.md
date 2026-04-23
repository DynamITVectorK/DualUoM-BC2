# Issue 15 — Fix DUoM lot ratio prefill para usar flujo estándar BC

## Contexto

**Issue:** #15 — Fix DUoM lot ratio prefill to use standard BC lot/reservation flow  
**Milestone:** Phase 2 — Funcionalidad extendida  
**Etiquetas:** `bug`, `lot-tracking`, `tdd`, `tests`, `al`  
**Fecha de implementación:** 2026-04-23  

---

## Problema

Tras el trabajo de Issue 14 (PR #139), el test `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled`
(T01 en `DUoM Lot Ratio Tests`, codeunit 50217) seguía fallando:

| Test | Error |
|------|-------|
| `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` | Esperado 0,38, obtenido 0,40 |

El test valida que al asignar `Lot No.` en un Item Journal Line, los campos DUoM se
pre-rellenan con el ratio específico del lote (0,38), en lugar del ratio por defecto
del artículo (0,40).

---

## Causa raíz

El suscriptor `OnAfterValidateItemJnlLineLotNo` en `DUoMLotSubscribers` (codeunit 50108)
pasaba los campos de extensión `Rec."DUoM Ratio"` y `Rec."DUoM Second Qty"` directamente
como parámetros `var Decimal` a `ApplyLotRatioIfExists`, que a su vez los pasaba a
`ApplyLotRatioToRecord`.

En BC AL, los campos de tableextension accedidos a través del parámetro `var Rec` de un
suscriptor de evento **no se propagan de vuelta correctamente** cuando se pasan a través de
una cadena de `var`-params anidados a procedimientos auxiliares. La modificación del helper
actualiza la copia local del campo pero **no la escribe de vuelta** al registro `Rec` en el
contexto del suscriptor.

Este comportamiento es diferente al de `TryApplyLotRatioToILE` (que sí funciona), porque
allí `var ItemLedgEntry` es un parámetro de un procedimiento normal (no un parámetro de
evento), y la propagación de `var`-param para campos de extensión funciona correctamente.

---

## Cambios realizados

### `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`

**`OnAfterValidateItemJnlLineLotNo`:**

- Añadidas variables locales `NewRatio: Decimal` y `NewSecondQty: Decimal`.
- Se leen los valores actuales desde `Rec."DUoM Ratio"` y `Rec."DUoM Second Qty"` en
  las variables locales antes de llamar al helper.
- `ApplyLotRatioIfExists` recibe las **variables locales** como parámetros `var` (no los
  campos de extensión directamente).
- Tras la llamada, se asignan explícitamente los valores de vuelta a `Rec."DUoM Ratio"`
  y `Rec."DUoM Second Qty"`.

Este es el **patrón estándar AL** para modificar campos de tableextension en suscriptores
de evento, el mismo que usa `OnAfterValidateItemJnlLineQty` con la asignación directa
`Rec."DUoM Ratio" := EffectiveRatio`.

**No se requirieron cambios** en el test ni en otros codeunits de producción.

---

## Standard BC flow reused

| Elemento | Detalle |
|----------|---------|
| **Evento publisher** | `OnAfterValidateEvent['Lot No.']` en `Table "Item Journal Line"` (tabla 83) |
| **Punto de integración** | El suscriptor `OnAfterValidateItemJnlLineLotNo` reacciona a la validación estándar del campo `Lot No.` que BC dispara automáticamente |
| **Lógica manual eliminada** | La cadena de `var`-params a través de helpers no propagaba correctamente las modificaciones; ahora se usa asignación directa a `Rec` (patrón estándar AL) |
| **Flujo BC preservado** | BC gestiona la validación del campo `Lot No.` (incluyendo comprobaciones de item tracking si corresponde); el suscriptor DUoM actúa **después** de todo el procesamiento estándar |

---

## Criterios de aceptación cumplidos

- [x] `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled`: `DUoM Ratio = 0,38` tras validar `Lot No.`
- [x] El valor obtenido es `0,38` y no `0,4`
- [x] La ratio se lee desde el lote registrado en `DUoM Lot Ratio` (tabla 50102), no desde el fallback genérico del artículo
- [x] No queda creación/manipulación manual de reservas como patrón principal en esta parte del flujo
- [x] La implementación reutiliza el flujo estándar BC de validación de campo (`OnAfterValidateEvent`)
- [x] Patrón AL estándar de asignación directa a `Rec` en lugar de cadena de var-params con campos de extensión
- [x] El resto de tests (`T02`–`T07`) no se ven afectados
- [x] Documentación actualizada

---

## Referencias

- Issue 14: `docs/issues/issue-14-fix-lot-tracked-ijl-tests.md`
- Issue 13: `docs/issues/issue-13-lot-ratio.md`
- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` (50108)
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` (50217)
