# Patrón DUoM por lote — Equivalencia con Piezas

## 1. Flujo DUoM por lote

El campo `DUoM Second Qty` (y `DUoM Ratio`) sigue exactamente el mismo camino que
`ABP No. of pieces` en el add-on de Piezas:

```
Item Tracking Lines
  → Tracking Specification (buffer temporal de edición)
  → Reservation Entry (persistencia por lote, documento vivo)
  → Temp Tracking Specification / Temp Global Record Set
  → Temp Split Item Journal Line
  → Item Journal Line
  → Item Ledger Entry
  → Posted / Warehouse entries cuando aplique
```

No existe ningún paso adicional fuera de este flujo estándar.

---

## 2. Equivalencia Piezas → DUoM

| Piezas | DualUoM |
|---|---|
| `ABP No. of pieces` | `DUoM Second Qty` |
| piezas por lote | segunda cantidad por lote |
| signo mediante `SignFactor` | signo mediante `SignFactor` |
| comparación en `OnAfterEntriesAreIdentical` | comparación DUoM en `OnAfterEntriesAreIdentical` |
| copia en `OnAfterMoveFields` | copia DUoM en `OnAfterMoveFields` |
| copia en `OnCreateReservEntryExtraFields` | copia DUoM en `OnCreateReservEntryExtraFields` |
| copia en `OnAfterCopyTrackingSpec` | copia DUoM en `OnAfterCopyTrackingSpec` |
| propagación a split de diario | propagación DUoM a split de diario |
| corrección invierte signo del ILE original | DUoM invierte signo del ILE original |

Campos DUoM implicados: `DUoM Second Qty`, `DUoM Ratio`.

---

## 3. Eventos permitidos (patrón base)

Cada subscriber incluye el comentario de arquitectura con la justificación de por qué
ese punto del patrón Piezas existe y qué test lo protege.

| Evento | Objeto publisher | Propósito |
|---|---|---|
| `OnAfterEntriesAreIdentical` | Page `"Item Tracking Lines"` | Detectar cambios DUoM aunque lote/cantidad no cambien |
| `OnAfterMoveFields` | Page `"Item Tracking Lines"` | Copiar DUoM de TrackingSpec a ReservEntry con signo correcto |
| `OnCreateReservEntryExtraFields` | Codeunit `"Create Reserv. Entry"` | Garantizar DUoM en INSERT final de ReservEntry |
| `OnAfterCopyTrackingSpec` | Page `"Item Tracking Lines"` | Preservar DUoM al copiar buffers internos |
| `OnAfterFillTrackingSpecBufferFromReservEntry` | Codeunit `"Item Tracking Doc. Management"` | Reconstruir buffer visible desde ReservEntry al reabrir |
| `OnAfterFillTrackingSpecBufferFromTrackingEntries` | Codeunit `"Item Tracking Doc. Management"` | Preservar DUoM desde tracking entries existentes |
| `OnAfterCopyTrackingFromReservEntry` | Table `"Tracking Specification"` | Copiar DUoM de ReservEntry al buffer de tracking |
| `OnAfterSetupTempSplitItemJnlLineSetQty` | Codeunit `"Item Jnl.-Post Line"` | Propagar DUoM por lote al split de IJL |
| `OnBeforeInsertCorrItemLedgEntry` | Codeunit `"Item Jnl.-Post Line"` | Invertir DUoM del ILE original en correcciones/undo |
| `OnTransferItemLedgToTempRecOnBeforeInsert` | Codeunit `"Item Tracking Data Collection"` | Copiar DUoM del ILE al temp record set de tracking |

Implementación de referencia: codeunit 50125 `"DUoM Tracking Prop. Mgt"` y
codeunit 50110 `"DUoM Tracking Copy Subscribers"`.

---

## 4. Eventos prohibidos

Queda **estrictamente prohibido** usar cualquiera de estos eventos para lógica DUoM de
`Item Tracking Lines`:

```
OnQueryClosePage
OnQueryClosePageEvent
OnBeforeClosePage
```

**Motivo:** estos eventos no forman parte del patrón DUoM aceptado para gestión de lotes.
La validación y persistencia deben resolverse dentro del flujo estándar
`Tracking Specification → Reservation Entry → Item Journal Line → Item Ledger Entry`.

Usar eventos de cierre para DUoM introduce los siguientes riesgos:
- Error de concurrencia de BC al modificar `Reservation Entry` durante el cierre de la página.
- Duplicados funcionales de tracking al iterar el cursor de `Rec` en `OnQueryClosePage`.
- Datos DUoM incorrectos al reabrirse la página (values from previous RE, not buffer).
- Dependencia de la UI que no existe en flows de posting directo o inserción por código.

---

## 5. Regla de signo

El signo de `DUoM Second Qty` en `Reservation Entry` sigue el patrón Piezas: se aplica
`Create Reserv. Entry.SignFactor(...)` en `OnAfterMoveFields` y
`OnCreateReservEntryExtraFields`.

En `Item Ledger Entry`:
- Compra: `DUoM Second Qty` es **positivo**.
- Venta: `DUoM Second Qty` es **negativo**.
- Corrección/undo: `NewILE."DUoM Second Qty" := -OldILE."DUoM Second Qty"`.

La responsabilidad de preparar el `Item Journal Line` con el signo correcto recae en los
subscribers **upstream** de cada flujo (ver `docs/development/coding-standards.md`,
sección "Norma: ILE ← IJL siempre").

---

## 6. Regla de reapertura

Al reabrir `Item Tracking Lines`:

1. BC llama `"Item Tracking Doc. Management".FillTrackingSpecBuffer(...)`.
2. El subscriber `OnAfterFillTrackingSpecBufferFromReservEntry` copia `DUoM Ratio` y
   `DUoM Second Qty` desde `Reservation Entry` al buffer temporal.
3. El subscriber `OnAfterCopyTrackingFromReservEntry` en `Table "Tracking Specification"`
   copia los campos DUoM cuando BC hace `CopyTrackingFromReservEntry`.
4. La página muestra los valores reales persistidos, sin cálculo ni reconstrucción.

**Resultado:** cerrar → reabrir → ver los mismos `DUoM Second Qty` / `DUoM Ratio` reales.
Sin duplicados. Sin líneas fantasma. Sin valores antiguos. Sin ceros indebidos.

---

## 7. Regla de posting por lote

Cuando un documento tiene N lotes:

```
1 Purchase Line con N Reservation Entries
→ posting split el Item Journal Line en N splits (1 por lote)
→ cada split recibe DUoM del lote correspondiente (no el DUoM total de la línea)
→ cada Item Ledger Entry tiene el DUoM de su lote
```

El subscriber `OnAfterSetupTempSplitItemJnlLineSetQty` implementa este comportamiento:
cada split IJL recibe su `DUoM Second Qty` y `DUoM Ratio` desde `TempTrackingSpecification`,
no del IJL padre.

**Prohibido:** copiar el DUoM total de la línea original a todos los lotes.

---

## 8. Riesgos de usar eventos de cierre

| Riesgo | Descripción |
|---|---|
| Error de concurrencia | `"Another user has modified the item tracking data"` al modificar `Reservation Entry` en `OnQueryClosePage` |
| Duplicados de tracking | Iterar `Rec` en `OnQueryClosePage` mueve el cursor de la página y duplica `Tracking Specification` / `Reservation Entry` |
| Datos incorrectos al reabrir | Los valores de `Reservation Entry` muestran la sesión anterior, no el buffer modificado |
| Bypass del flujo estándar | Los datos insertados por código sin pasar por la UI no disparan `OnQueryClosePage` |
| Fragilidad de versión | BC puede cambiar el contrato de `OnQueryClosePage` entre versiones |

---

## 9. Tests que protegen el patrón

| Test | Codeunit | Escenario |
|---|---|---|
| `T-PERSIST-01` | 50219 | AlwaysVariable — cerrar/reabrir conserva DUoM |
| `T-REOPEN-01` | 50219 | Variable — un lote persiste DUoM al reabrir |
| `T-REOPEN-02` | 50219 | Variable — dos lotes con ratios distintos se preservan |
| `T-REOPEN-05` | 50219 | Reabrir no crea Tracking Spec duplicadas |
| `T-REOPEN-06` | 50219 | Dos cierres consecutivos no duplican el tracking |
| `T-REOPEN-07` | 50219 | Segunda edición persiste DUoM modificado (Variable) |
| `T-REOPEN-08` | 50219 | Segunda edición persiste DUoM modificado (AlwaysVariable) |
| `T-CLOSE-02` | 50222 | Dos lotes con total igual → ReservEntry conserva DUoM |
| `T-CLOSE-03` | 50222 | Ratios distintos por lote preservados en ReservEntry |
| `T-CLOSE-06` | 50222 | Validación pre-posting sigue bloqueando datos incoherentes |
| `T-SYNC-01` | 50225 | Variable — piezas reales persisten en ReservEntry |
| `T-SYNC-02` | 50225 | AlwaysVariable — piezas reales persisten en ReservEntry |
| `T-SYNC-03` | 50225 | Fixed — ratio incorrecto bloqueado inline |
| `T-SYNC-04` | 50225 | Varios lotes — cada ReservEntry retiene su ratio real |
| `T-SYNC-05` | 50225 | E2E — tracking real propagado a ILE |
| `T-RATIO-02` | 50226 | ValidateTrackingSpecBufferEachLine bloquea ratio incoherente |
| `T-RATIO-03` | 50226 | Segunda barrera (pre-posting) sigue bloqueando |
| `DUoMLotPostingTests` | 50228 | Posting con lote — ILE tiene DUoM correcto por lote |
| `DUoMLotRatioTests` | 50230 | Split IJL por lote — cada ILE tiene DUoM de su lote |
| `DUoMUndoRcptShptTests` | 50231 | Undo — DUoM invertido en corrección |

**Criterio de revisión del PR:**

> ¿Este código existe porque Piezas necesita un punto equivalente para mover piezas por lote?

Si la respuesta es **no**, el código no debe estar.
