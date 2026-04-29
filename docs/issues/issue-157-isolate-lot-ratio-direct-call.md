# Issue 157 — Aislar y corregir fallo de aplicación de ratio DUoM por lote al validar Lot No. en Item Journal Line

## Contexto

El test T11 (`T11_VariableMode_LotWithRatio_DUoMFieldsPreFilled`, codeunit 50217)
sigue fallando en CI con:

```
Expected: 0.38
Actual:   0.4
```

Pese a los fixes de los issues 154, 155, 156, no ha sido posible determinar si el fallo
reside en la lógica interna de aplicación del ratio o en el disparo / propagación del evento
`OnAfterValidateEvent[Lot No.]`, porque ambas rutas estaban fusionadas en el mismo flujo.

---

## Problema

`DUoMLotSubscribers` (codeunit 50108) tenía `Access = Internal`, lo que impedía llamar
a sus métodos directamente desde el app de tests. Toda la lógica de aplicación de ratio
estaba embebida en el subscriber, sin separación entre:

1. La lógica de cálculo (¿qué ratio aplicar?).
2. El mecanismo de disparo (evento `OnAfterValidateEvent`).

Sin esta separación, no es posible determinar cuál de las dos rutas falla.

---

## Cambios realizados

### `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`

- **`Access = Internal` → `Access = Public`**: permite que el app de tests llame directamente
  a `ApplyLotRatioToItemJournalLine`.

- **Nueva función pública `ApplyLotRatioToItemJournalLine`**: encapsula toda la lógica de
  aplicación de ratio de lote sobre un `Item Journal Line`. Devuelve `Boolean`:
  - `true` si se encontró y aplicó la ratio de lote.
  - `false` si `Item No.` o `Lot No.` están vacíos, o si no existe ratio registrada para el lote.

- **`OnAfterValidateItemJnlLineLotNo` refactorizado**: el subscriber ahora solo delega en
  `ApplyLotRatioToItemJournalLine(Rec)`, eliminando la lógica duplicada.

### `test/src/codeunit/DUoMLotRatioTests.Codeunit.al`

- **T11 actualizado**: añadido assert de que `"Lot No."` queda informado en la línea tras
  `Validate("Lot No.", LotNo)`, para distinguir si el problema es la propagación del campo
  o la lógica de cálculo.

- **Nuevo test T12 (`T12_VariableMode_DirectCall_ApplyLotRatioToItemJnlLine`)**: llama
  directamente a `DUoMLotSubscribers.ApplyLotRatioToItemJournalLine(ItemJnlLine)` sin pasar
  por el evento, para aislar la lógica interna del mecanismo de evento.

### `docs/03-technical-architecture.md`

- Actualizada la descripción de `DUoM Lot Subscribers` (50108) para documentar
  `ApplyLotRatioToItemJournalLine` como método público y el patrón de delegación.

---

## Interpretación de resultados

```text
Si T12 falla → el problema está en TryApplyLotRatioIfExists, TryApplyLotRatioToRecord,
               GetEffectiveSetup o DUoMLotRatio.Get (lógica interna).

Si T12 pasa pero T11 falla:
  → Si "Lot No." no queda informado: BC borra el campo durante la validación
    (item con Lot Specific Tracking activo sin Reservation Entry).
  → Si "Lot No." queda informado pero DUoM Ratio = 0,4: el subscriber no propaga
    los cambios de campos de tableextension al registro llamante.

Si ambos pasan → la lógica y el evento funcionan correctamente.
```

---

## Criterios de aceptación

- [x] Existe función pública `ApplyLotRatioToItemJournalLine(var ItemJnlLine): Boolean`.
- [x] El subscriber `OnAfterValidateItemJnlLineLotNo` delega en esa función.
- [x] Existe test T12 de llamada directa a `ApplyLotRatioToItemJournalLine`.
- [x] T11 incluye assert de que `"Lot No."` queda informado tras `Validate("Lot No.")`.
- [x] T11 mantiene expected `DUoM Ratio = 0,38` y `DUoM Second Qty = 3,8`.
- [x] `DUoMLotSubscribers` tiene `Access = Public`.

---

## Archivos modificados

- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al`
- `docs/03-technical-architecture.md`
- `docs/issues/issue-157-isolate-lot-ratio-direct-call.md` (este fichero)

---

## Referencias

- Issue 154 — fix subscriber validate (origen del fallo T01/T11)
- Issue 155 — fix Modify persist (intento con Modify(false))
- Issue 156 — fix remove Modify (vuelta a := directo)
- Docs: `docs/03-technical-architecture.md`, `docs/05-testing-strategy.md`

---

**Etiquetas:** `bug`, `tests`, `lot-ratio`, `tdd`, `BC27`
