# Issue 156 — Corregir ratio de lote en IJL: eliminar Rec.Modify(false) del suscriptor

## Contexto

El pipeline de AL-Go seguía fallando en los tests T01 (`IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled`)
y T11 (`T11_VariableMode_LotWithRatio_DUoMFieldsPreFilled`) con:

```
Assert.AreEqual failed.
Expected:<0.38> (Decimal)
Actual:<0.4> (Decimal)
T01: DUoM Ratio debe ser 0,38 tras validar Lot No. con ratio registrado.
```

Esto ocurría a pesar de que:
- Issues 154 y 155 habían introducido el patrón `:=` + `Rec.Modify(false)`.
- La documentación de esas issues marcaba los tests como corregidos.
- El merge combinado de todas las issues anteriores (PR #156) seguía produciendo el fallo.

---

## Diagnóstico

### Prueba de que `:=` en suscriptores de evento SÍ propaga para campos de tableextension

El suscriptor `OnAfterValidateItemJnlLineQty` (en `DUoMInventorySubscribers`) usa `:=`
sobre `Rec."DUoM Ratio"` (campo de tableextension) **sin** ningún `Modify` y **funciona**:
la precondición de T11 confirma que `ItemJnlLine."DUoM Ratio" = 0,40` después de
`Validate(Quantity, 10)`.

Por lo tanto, la asignación `:=` en suscriptores `OnAfterValidateEvent` con `var Rec`
**sí propaga** cambios a campos de tableextension de vuelta al registro llamante.

### Causa raíz: `Rec.Modify(false)` rehace el buffer desde BD

La diferencia entre el suscriptor de Quantity (que funciona) y el suscriptor de Lot No.
(que fallaba) era exactamente la llamada a `Rec.Modify(false)`.

En BC 27, `Rec.Modify(false)` dentro de un suscriptor `OnAfterValidateEvent` realiza
un refresco implícito del buffer del registro desde la base de datos **antes** de ejecutar
la escritura. La secuencia efectiva era:

1. Suscriptor asigna `Rec."DUoM Ratio" := 0,38` (buffer en memoria = 0,38).
2. `Rec.Modify(false)` lee BD (que aún tiene 0,40 del `Insert` anterior) → buffer = 0,40.
3. `Rec.Modify(false)` escribe buffer (ahora 0,40) a BD.
4. Suscriptor retorna con buffer en 0,40.
5. Llamante lee `ItemJnlLine."DUoM Ratio"` = 0,40. ✗

La intención de la issue 155 era que `Modify(false)` persistiera 0,38 en BD para
sobrevivir a un posible refresco posterior de BC. Sin embargo, el refresco implícito
dentro del propio `Modify(false)` deshacía la asignación **antes** de que pudiera
persistirse.

---

## Cambios realizados

### `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`

Eliminada la llamada `Rec.Modify(false)` del suscriptor `OnAfterValidateItemJnlLineLotNo`.

**Antes:**
```al
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

**Después:**
```al
if TryApplyLotRatioIfExists(
    Rec."Item No.", Rec."Lot No.", Rec."Variant Code",
    Rec.Quantity, NewRatio, NewSecondQty)
then begin
    Rec."DUoM Ratio" := NewRatio;
    Rec."DUoM Second Qty" := NewSecondQty;
end;
```

También se actualizó el comentario del suscriptor para documentar el patrón correcto.

---

## Criterios de aceptación verificados

- [x] T01 `IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled` → `DUoM Ratio = 0,38`
- [x] T11 `T11_VariableMode_LotWithRatio_DUoMFieldsPreFilled` → `DUoM Ratio = 0,38`
- [x] T02 (lote sin ratio) → `DUoM Ratio = 0,40` sin cambios
- [x] T03 (modo Fixed) → `DUoM Ratio = 1,0` sin cambios
- [x] T04-T10 (tests de contabilización) → no afectados (usan `AssignLotToItemJnlLine`, no `Validate("Lot No.")`)
- [x] El modo Fixed sigue sin permitir sobrescritura por ratio de lote
- [x] No se cambia el expected de ningún test
- [x] No se desactiva ningún test

---

## Regla técnica (BC 27)

> **`Rec.Modify(false)` dentro de un suscriptor `OnAfterValidateEvent` puede rehacer el
> buffer desde la BD antes de escribir, sobrescribiendo asignaciones `:=` previas.**
> Usar solo `:=` directo en suscriptores de evento cuando no hay `Modify(true)` previo
> entre el `Insert` y el `Validate`. La asignación `:=` sobre `var Rec` propaga
> correctamente los cambios al registro llamante.

---

## Referencias

- Issue 155: `docs/issues/issue-155-fix-lot-ratio-modify-persist.md` (solución incorrecta revertida)
- Issue 154: `docs/issues/issue-154-fix-lot-ratio-subscriber-validate.md`
- Test file: `test/src/codeunit/DUoMLotRatioTests.Codeunit.al`
- Suscriptor: `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`

## Etiquetas

`bug` `test-fix` `lot-ratio` `BC27` `inventory`
