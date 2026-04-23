# Issue 16 — Regresión: DUoM Ratio pierde precisión decimal tras validar Lot No.

## Contexto

Tras el fix de Issue 15 (`DUoMLotSubscribers.Codeunit.al`), el test
`IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` (T01) seguía fallando:

- **Valor esperado:** `DUoM Ratio = 0.38` (ratio específico del lote LOTE-T01)
- **Valor devuelto:** `0.4` (el ratio por defecto del artículo, 0.40)

El síntoma se leía como "redondeo a 1 decimal" porque `0.40` se muestra como `0.4`
al eliminar el cero final, pero la causa raíz era diferente: el ratio correcto (0.38)
nunca llegaba a propagarse al registro llamante.

## Causa raíz

En `OnAfterValidateItemJnlLineLotNo`, el fix de Issue 15 usaba:

```al
Rec."DUoM Ratio" := NewRatio;   // 0.38 — NO propagaba
Rec."DUoM Second Qty" := NewSecondQty;
```

En BC AL, la asignación directa (`:=`) a un campo de `tableextension` dentro de un
suscriptor de evento (`[EventSubscriber]`) **no garantiza la propagación de vuelta**
al registro del código llamante. El valor se escribe en el buffer local del suscriptor,
pero la variable `ItemJnlLine` del test sigue viendo el valor anterior (0.40).

Por eso el test veía `0.4` (= 0.40, el ratio por defecto del artículo) en lugar de
`0.38` (el ratio específico del lote).

## Corrección aplicada

Cambio en `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`,
procedimiento `OnAfterValidateItemJnlLineLotNo`:

```al
// ANTES (Issue 15 — no propagaba el ratio):
Rec."DUoM Ratio" := NewRatio;
Rec."DUoM Second Qty" := NewSecondQty;

// DESPUÉS (Issue 16 — propagación correcta):
Rec.Validate("DUoM Ratio", NewRatio);
Rec."DUoM Second Qty" := NewSecondQty;
```

`Rec.Validate("DUoM Ratio", NewRatio)` garantiza dos cosas:
1. **Propagación correcta** del valor al registro llamante (mecanismo de validación BC).
2. **Recálculo automático de `DUoM Second Qty`** mediante el trigger `OnValidate` del
   campo, que usa `ComputeSecondQtyRounded` con la precisión de redondeo de la UoM
   secundaria del artículo. Esto evita cualquier pérdida de decimales en la segunda
   cantidad.

La asignación explícita `Rec."DUoM Second Qty" := NewSecondQty` se conserva como
respaldo para el caso `AlwaysVariable`, donde el trigger `OnValidate` del ratio sale
anticipadamente sin recalcular `DUoM Second Qty`.

## Criterios de aceptación

- [x] Test T01 `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` → `DUoM Ratio = 0.38`
- [x] Test T01 → `DUoM Second Qty ≈ 3.8`
- [x] Test T02 `IJL_VariableMode_LotWithoutRatio_DUoMRatioUnchanged` → sin regresión
- [x] Test T03 `IJL_FixedMode_LotWithRatio_DUoMRatioNotOverridden` → sin regresión
- [x] Tests T04-T07 (contabilización e ILE) → sin regresión

## Archivos modificados

- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` — cambio `:=` → `Validate` en suscriptor de lote

## Referencias

- Issue 13: diseño inicial de DUoM Lot Subscribers
- Issue 15: primer intento de fix de propagación (variables locales + `:=`)
- `docs/issues/issue-15-fix-lot-ratio-prefill-standard-bc-flow.md`

## Etiquetas

`bug` · `regression` · `lot-ratio` · `event-subscriber` · `BC27`
