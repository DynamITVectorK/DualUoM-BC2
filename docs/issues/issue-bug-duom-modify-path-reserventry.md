# fix: DUoM fields lost on second edit of Item Tracking Lines — Modify path

## Resumen del problema

Cuando el usuario modificaba valores DUoM (`DUoM Ratio`, `DUoM Second Qty`) en
`Item Tracking Lines` en una **segunda apertura** (ya existía `Reservation Entry` para ese
lote), los cambios no se persistían. Al reabrir de nuevo, el sistema mostraba los valores
de la primera edición.

## Causa raíz

BC usa dos paths distintos al cerrar `Item Tracking Lines` con OK:

| Situación | Path BC | Evento DUoM |
|-----------|---------|-------------|
| Primera edición (RE no existe) | Insert vía `CreateReservEntry` → `CopyTrackingFromSpec` | `OnAfterCopyTrackingFromTrackingSpec` ✅ |
| Segunda edición (RE ya existe) | Modify directo sobre el registro existente | ❌ Sin evento de copia |

El subscriber `ReservEntryOnAfterCopyTrackingFromTrackingSpec` (codeunit 50110) solo cubre
el path Insert. El path Modify no disparaba ningún evento que copiara los campos DUoM desde
el buffer `Tracking Specification` hacia la `Reservation Entry` existente.

## Solución implementada

### 1. `app/src/codeunit/DUoMTrackingCoherenceMgt.Codeunit.al` (50111)

**Añadido:** Nuevo método público `PersistDUoMToReservEntries(var TrackingSpec)`.

- Itera el buffer `Tracking Specification` (mediante LocalTrackingSpec.Copy para cursor safety).
- Para cada línea funcional con `Lot No. ≠ ''`, busca las `Reservation Entry` positivas
  vinculadas al mismo origen + lote usando `SetSourceFilter` estándar.
- Si `DUoM Ratio` o `DUoM Second Qty` difieren, actualiza la RE con `Modify(false)`.
- No-op si Source Type ≠ Purchase Line o DUoM no está activo para el artículo.

### 2. `app/src/pageextension/DUoMItemTrackingLines.PageExt.al` (50112)

**Actualizado:** `OnQueryClosePage` — añadida la llamada a `PersistDUoMToReservEntries(Rec)`
después de todas las validaciones y sincronizaciones, inmediatamente antes de `exit(true)`.

Orden de llamadas en `OnQueryClosePage`:
1. `ValidateTrackingSpecBufferEachLine` — validación per-lot (barrera temprana, puede Error)
2. `SyncPurchLineFromTrackingBuffer` — PurchLine = SUM agregado del buffer
3. `ValidateTrackingSpecBufferForPurchLine` — sanity check agregado
4. `PersistDUoMToReservEntries` ← **NUEVO** — Modify path: actualiza RE existentes

### 3. Tests en codeunit 50219 `DUoM Purch Tracking Persist`

**Añadidos:**

- `T-REOPEN-07` `PurchLotTracking_SecondEdit_Variable_PersistsDUoMModify`:
  - Artículo Variable, lote `LOT-MODIFY-T7V`, qty = 4
  - Primera edición: `DUoM Second Qty = 8` → ratio auto = 2.0
  - Segunda edición: `DUoM Second Qty = 10` → ratio auto = 2.5
  - Tercera apertura: verifica ratio = 2.5 y second qty = 10 ✓

- `T-REOPEN-08` `PurchLotTracking_SecondEdit_AlwaysVariable_PersistsDUoMModify`:
  - Artículo AlwaysVariable, lote `LOT-MODIFY-T8AV`, qty = 10
  - Primera edición: `DUoM Ratio = 0.8`, `DUoM Second Qty = 8`
  - Segunda edición: `DUoM Second Qty = 6` → ratio auto = 0.6
  - Tercera apertura: verifica ratio = 0.6 y second qty = 6 ✓

**Actualizados:**
- Handler MPH `ItemTrackingLines_AssignAndVerify_MPH`: pasos 15–20 añadidos.
- Summary de la codeunit: T-REOPEN-07/08 añadidos a la lista de escenarios.

## Documentación actualizada

- `docs/03-technical-architecture.md`: añadida sección "path Modify" con diagrama del flujo.
- `docs/10-persistence-matrix.md` §5.1: nuevo mecanismo 3 (`PersistDUoMToReservEntries`)
  documentado; §5.2 actualizado con los dos sub-paths del cierre con OK.

## Módulos fuera de alcance

- **Fixed mode:** el ratio viene del setup; `ValidateTrackingSpecLine` bloquea antes de
  persistir si el usuario modifica el ratio. No afectado.
- **Path de posting (ILE):** la cadena `ReservEntry → TrackingSpec → IJL → ILE` ya funciona
  desde que ReservEntry tiene los valores correctos. No requiere cambios.
