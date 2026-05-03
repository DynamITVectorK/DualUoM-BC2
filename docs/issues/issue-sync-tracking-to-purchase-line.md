# Issue: Sincronización DUoM desde Item Tracking Lines hacia Purchase Line

## Resumen

Implementa el flujo funcional estándar donde:

1. El usuario crea un pedido de compra con cantidad base conocida.
2. La cantidad secundaria DUoM puede estar inicialmente en cero (piezas desconocidas al pedir).
3. Durante la recepción, el usuario abre **Item Tracking Lines**.
4. El usuario asigna lote(s) e informa las piezas reales por lote.
5. El sistema recalcula el ratio real de cada lote (`DUoM Ratio = DUoM Second Qty / Qty (Base)`).
6. Al aceptar/cerrar la página, el sistema sincroniza la `Purchase Line` como resumen agregado.
7. Al registrar, los valores reales DUoM se propagan correctamente a ILE y `Purch. Rcpt. Line`.

---

## Problema previo

La validación anterior comparaba el total de tracking con `PurchLine."DUoM Second Qty"` y
bloqueaba el cierre de **Item Tracking Lines** si los totales diferían. Esto impedía el caso
real más habitual: el usuario crea el pedido sin piezas conocidas (DUoM Second Qty = 0),
informa las piezas reales durante la recepción, y el sistema debía actualizar —no bloquear.

---

## Cambios implementados

### `DUoMTrackingCoherenceMgt` (codeunit 50111)

**Nuevo método: `NormalizeTrackingDUoMSecondQty(var TrackingSpec: Record "Tracking Specification")`**

- Modos Variable/AlwaysVariable: recalcula `DUoM Ratio := DUoM Second Qty / Abs(Qty (Base))`
  cuando el usuario informa la cantidad secundaria real.
- Modo Fixed: no hace nada (el ratio es fijo e inmutable).
- No-op si Qty (Base) = 0 o DUoM Second Qty = 0.
- Llamado desde `DUoM Item Tracking Lines` (50112) en `DUoM Second Qty.OnValidate`,
  ANTES de `ValidateTrackingSpecLine`.

**Nuevo método: `SyncPurchLineFromTrackingBuffer(var TrackingSpec: Record "Tracking Specification")`**

- Suma `DUoM Second Qty` y `Qty (Base)` de todos los registros del buffer para el mismo origen.
- Actualiza la `Purchase Line`:
  - `DUoM Second Qty := SUM(tracking.DUoM Second Qty)`
  - `DUoM Ratio := TotalSecondQty / TotalBaseQty`
- Usa `PurchLine.Modify(false)` para persistir sin disparar triggers estándar.
- No-op si Source Type ≠ Purchase Line, DUoM no activo, o Purchase Line no encontrada.
- Llamado desde `DUoM Item Tracking Lines` (50112) en `OnQueryClosePage` ANTES de la
  validación de sanity check.

### `DUoMItemTrackingLines` (pageextension 50112)

**`DUoM Second Qty.OnValidate`** actualizado:
- Llama a `NormalizeTrackingDUoMSecondQty(Rec)` primero (recalcula ratio).
- Luego llama a `ValidateTrackingSpecLine(Rec)` (coherencia post-normalización).

**`OnQueryClosePage`** actualizado:
1. `SyncPurchLineFromTrackingBuffer(Rec)` — actualiza Purchase Line con el agregado real.
2. `ValidateTrackingSpecBufferForPurchLine(Rec)` — sanity check (siempre pasa tras sync).

---

## Fuente de verdad por nivel

| Nivel | Rol funcional |
|---|---|
| `Tracking Specification` (buffer en Item Tracking Lines) | Fuente de verdad operativa por lote durante la recepción |
| `Reservation Entry` | Persistencia por lote tras cerrar Item Tracking Lines |
| `Purchase Line` | Resumen agregado sincronizado desde tracking al cerrar |
| `Item Ledger Entry` | Verdad histórica contabilizada |
| `Posted Purchase Rcpt. Line` | Histórico documental de la recepción |

---

## Reglas de validación por modo

### Fixed
- `NormalizeTrackingDUoMSecondQty` no actúa.
- `ValidateTrackingSpecLine` valida coherencia `|Qty × Ratio - SecondQty| ≤ precision`.
- Si el usuario introduce piezas distintas a `Qty × RatioFijo` → error bloqueante.

### Variable
- `NormalizeTrackingDUoMSecondQty` recalcula `DUoM Ratio = DUoM Second Qty / Qty (Base)`.
- `ValidateTrackingSpecLine` valida coherencia post-normalización (siempre pasa tras recálculo).
- El usuario puede informar cualquier cantidad real de piezas → ratio se adapta.

### AlwaysVariable
- Igual que Variable para la recepción con piezas reales.
- `ValidateTrackingSpecLine` bloquea si `DUoM Ratio = 0` con `Qty (Base) ≠ 0`
  (el usuario debe informar piezas antes de aceptar).

---

## Arquitectura de dos barreras (sin cambios)

| Barrera | Dónde | Cuándo | Datos usados |
|---|---|---|---|
| 1.ª barrera (UI) | `OnQueryClosePage` de `DUoM Item Tracking Lines` | Al cerrar con OK/LookupOK | Buffer `Tracking Specification` (pre-persist) |
| 2.ª barrera (server) | `OnPostItemJnlLineOnAfterCopyDocumentFields` de `DUoM Purchase Subscribers` | Justo antes de crear el ILE | `Reservation Entry` persistida |

La 2.ª barrera sigue siendo necesaria para cubrir flujos donde la 1.ª no se ejecutó
(inserción directa en `Reservation Entry` sin pasar por la UI, integraciones, API, etc.).

---

## Tests implementados

### Nuevos — `DUoM Purch Sync Tests` (codeunit 50224)

| Test | Escenario |
|---|---|
| `PurchaseVariable_TrackingPiecesUpdateRatioAndPurchaseLine` | Variable: 7 KG + 11 PCS → ratio = 11/7, Purchase Line sincronizada |
| `PurchaseAlwaysVariable_TrackingPiecesCalculateRatioAndSyncLine` | AlwaysVariable: mismo flujo |
| `PurchaseFixed_TrackingPiecesDifferentFromFixedRatioRaisesError` | Fixed: 11 PCS para 7 KG con ratio 1.25 → error |
| `PurchaseVariable_MultipleLots_UpdatePurchaseLineWithAggregateRatio` | Dos lotes, ratios distintos, Purchase Line con total agregado |
| `PurchaseVariable_PostReceipt_ILEUsesTrackingRealDUoM` | E2E: piezas reales en tracking → ILE con valores reales |

### Actualizados — `DUoM Purch Track Close Tests` (codeunit 50222)

| Test | Cambio |
|---|---|
| `CloseOK_DUoMTotalHigh_SyncsToPurchLine` (ex. `_Blocked`) | Ahora verifica sync en lugar de error |
| `CloseOK_DUoMTotalLow_SyncsToPurchLine` (ex. `_Blocked`) | Ahora verifica sync en lugar de error |
| `PrePosting_DUoMIncoherent_StillBlocked` | Sin cambios (segunda barrera, sigue bloqueando) |

### Actualizados — `DUoM Purch Track Val Tests` (codeunit 50223 approx.)

| Test | Cambio |
|---|---|
| `ValidateDUoMSecondQty_AlwaysVar_CalculatesRatio` (ex. `_ZeroRatio_Blocked`) | Verifica recálculo de ratio |
| `ValidateDUoMSecondQty_Variable_RecalculatesRatio` (ex. `_Incoherent_Blocked`) | Verifica recálculo de ratio |

---

## Nota sobre recepción parcial

El sync refleja únicamente las cantidades del buffer de tracking de la sesión actual,
que representan la porción "a manejar/recibir" en esa sesión. En recepciones parciales
sucesivas, cada sesión sincronizará su propia porción. La semántica exacta de
`PurchLine."DUoM Second Qty"` en escenarios de múltiples recepciones parciales queda
documentada como trabajo futuro (pendiente diseño de campos separados ordered/received).
