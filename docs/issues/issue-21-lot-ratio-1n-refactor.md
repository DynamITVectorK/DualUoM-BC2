# Issue 21 — Refactorizar DUoM Lot Ratio: eliminar asunción incorrecta 1 línea = 1 lote

## Contexto

La lógica previa de DUoM por lote contenía un subscriber de evento que asumía
implícitamente el modelo incorrecto:

```
1 línea de diario = 1 lote = 1 ratio DUoM
```

Concretamente, el codeunit `DUoM Lot Subscribers` (50108) incluía:

```al
[EventSubscriber(ObjectType::Table, Database::"Item Journal Line",
                 'OnAfterValidateEvent', 'Lot No.', false, false)]
local procedure OnAfterValidateItemJnlLineLotNo(...)
begin
    ApplyLotRatioToItemJournalLine(Rec);
end;
```

Este subscriber buscaba el ratio DUoM al validar `"Lot No."` en un `Item Journal Line` y
pre-rellenaba `DUoM Ratio` y `DUoM Second Qty`. Esta premisa **no es correcta en
Business Central**:

- Una línea de documento puede tener **N lotes** asignados vía Item Tracking.
- `"Item Journal Line"."Lot No."` **no es la fuente de verdad** de la ratio DUoM por lote.
- El modelo correcto es: `1 línea = N lotes = N ratios reales por lote`.

Los tests `T01` y `T11` en `DUoM Lot Ratio Tests` (codeunit 50217) validaban este
comportamiento inválido y fallaban de forma intermitente en CI porque BC 27 puede borrar
el campo `"Lot No."` de un IJL al validarlo si no existe `Reservation Entry` para el lote.

---

## Problema

1. **Subscriber inválido:** `OnAfterValidateItemJnlLineLotNo` asumía 1 línea = 1 lote.
2. **Tests inválidos:** T01 y T11 dependían de `Validate("Lot No.")` como mecanismo de
   aplicación de ratio DUoM, lo cual no representa el flujo real de BC con Item Tracking.
3. **CI rojo:** T11 fallaba con `Expected:<0.38> Actual:<0.4>` porque BC 27 restauraba
   el ratio por defecto al validar el lote sin una Reservation Entry activa.

---

## Cambios realizados

### 1. `app/src/codeunit/DUoMLotSubscribers.Codeunit.al`

- **Eliminado:** subscriber `OnAfterValidateItemJnlLineLotNo` (el que llamaba a
  `ApplyLotRatioToItemJournalLine` al validar `"Lot No."` en IJL).
- **Conservado:** método público `ApplyLotRatioToItemJournalLine` — ahora claramente
  documentado como utilidad interna para escenarios controlados de un único lote
  (uso legítimo: tests unitarios de helper, NOT flujo productivo principal).
- **Conservado:** `TryApplyLotRatioToILE` — mecanismo productivo principal correcto
  (llamado desde `DUoMInventorySubscribers` en `OnAfterInitItemLedgEntry`).
- **Actualizados:** comentarios de la cabecera del codeunit para reflejar la arquitectura
  correcta N:1 y documentar la eliminación del subscriber.

### 2. `test/src/codeunit/DUoMLotRatioTests.Codeunit.al`

- **Eliminados:** T01 (`IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled`) y T11
  (`T11_VariableMode_LotWithRatio_DUoMFieldsPreFilled`) — ambos dependían del subscriber
  eliminado y asumían la premisa inválida 1 línea = 1 lote.
- **Actualizados (regresión de diseño):** T02 y T03 — comentarios actualizados para
  documentar que verifican que `Validate("Lot No.")` NO interfiere con campos DUoM
  (comportamiento correcto tras eliminar el subscriber).
- **Reclasificado:** T12 — claramente marcado como test unitario de bajo nivel del helper
  `ApplyLotRatioToItemJournalLine`, no como escenario BC de integración real.
- **Conservados sin cambios:** T04–T10, T07 — tests de posting con Reservation Entries;
  representan el mecanismo productivo correcto.
- **Actualizada:** cabecera del codeunit con el nuevo índice de tests y la arquitectura N:1.

### 3. `docs/02-functional-design.md`

- Eliminado "Caso A" del flujo de integración (el que describía el subscriber eliminado).
- Actualizada "Regla de diseño: línea origen como agregado" para reflejar que
  `Item Journal Line."Lot No."` no es la fuente de verdad.
- Añadida nota explícita sobre la eliminación del subscriber en Issue 21.

### 4. `docs/03-technical-architecture.md`

- Actualizada la descripción de `DUoM Lot Subscribers` (50108) en la tabla de codeunits.
- Añadida subsección "Historial de decisión" en el modelo 1:N con las referencias a
  los issues 13, 20 y 21.
- Añadida restricción de diseño explícita sobre `Item Journal Line."Lot No."`.

### 5. `docs/06-backlog.md`

- Añadido este issue (Issue 21) como completado.
- Añadida tarea futura "Arquitectura DUoM por lote sobre Item Tracking (N lotes reales)".

---

## Criterios de aceptación verificados

- [x] No queda lógica productiva que asuma que una línea tiene exactamente un lote.
- [x] No queda lógica productiva que trate `"Item Journal Line"."Lot No."` como fuente
      definitiva de la ratio DUoM por lote.
- [x] Los tests T01 y T11 (basados en 1 línea = 1 lote) han sido eliminados.
- [x] T12 está explícitamente marcado como test unitario de helper, no como escenario de
      integración real con Business Central.
- [x] Ningún test fuerza `ItemJnlLine."Lot No." := LotNo` como escenario válido de
      integración (T12 lo usa únicamente para probar el helper directamente).
- [x] La documentación indica claramente que la ratio DUoM real debe gestionarse a nivel
      lote/tracking/ILE.
- [x] Existe una tarea de backlog para diseñar la arquitectura correcta N-lotes.
- [x] No se introduce manipulación manual de `Reservation Entry` o `Tracking Specification`.
- [x] Los tests válidos existentes (T02–T10, T12) siguen pasando.
- [x] No se cambian expected values solo para ocultar el problema arquitectónico.
- [x] La solución queda alineada con Business Central SaaS.

---

## Archivos modificados

- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` — subscriber eliminado, comentarios actualizados
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` — T01 y T11 eliminados; T02, T03, T12 actualizados
- `docs/02-functional-design.md` — flujo de integración actualizado
- `docs/03-technical-architecture.md` — descripción 50108 y sección modelo 1:N actualizadas
- `docs/06-backlog.md` — Issue 21 añadido; tarea futura N-lotes añadida
- `docs/issues/issue-21-lot-ratio-1n-refactor.md` — este fichero

---

## Referencias

- Issue 13: implementación original del subscriber y DUoM Lot Ratio.
- Issue 20: consolidación del modelo 1:N; corrección del bug de copia en AlwaysVariable.
- Issue 154–157: histórico de intentos de hacer funcionar el subscriber en BC 27.
- `docs/03-technical-architecture.md`: sección "Modelo 1:N" para el diseño definitivo.
- `docs/06-backlog.md`: tarea futura para arquitectura N-lotes con Item Tracking.

---

## Etiquetas

`architecture` `refactor` `lot-tracking` `tests` `1-n-model`
