# Issue 171 — test: cobertura ILE — modos Variable/AlwaysVariable y multi-lote desde Purchase Order

## Contexto

Los tests existentes de propagación al `Item Ledger Entry` tenían tres huecos:

1. **Modo Variable y AlwaysVariable sin lotes → ILE** estaban cubiertos en
   `DUoMVarModePostTests` (codeunit 50214) pero ausentes en `DUoMILEIntegrationTests`
   (50209), que solo cubría Fixed. La responsabilidad estaba repartida de forma
   inconsistente.

2. **Fixed/Variable con lotes → ILE** ningún test usaba `PostPurchaseDocument`
   con Item Tracking. Los tests de lotes existentes (`DUoMLotRatioTests`,
   `DUoMItemTrackingTests`) posteaban via `PostItemJournalLine` y pre-registraban
   ratios en `DUoM Lot Ratio (50102)`. No cubrían el flujo real del usuario:
   Purchase Order → Item Tracking Lines → Post → ILE.

3. **Comentario incorrecto en `SalesPosting_FixedMode_ILEHasDUoMFields`**: decía
   "copied from Sales Line without sign adjustment" pero el mecanismo real
   (`OnAfterCopyTrackingFromItemJnlLine`) recalcula con `Abs(ILE.Quantity) × Ratio`.

## Cambios realizados

### `test/src/codeunit/DUoMTestHelpers.Codeunit.al`

Nuevo procedimiento público `AssignLotWithDUoMRatioToPurchLine`:
- Crea una `Reservation Entry` con `Positive = true`, source type = Purchase Line,
  y `DUoM Ratio` / `DUoM Second Qty` configurados.
- Inserta una `Tracking Specification` permanente con los mismos campos DUoM, para
  que el mecanismo `OnAfterCopyTrackingFromSpec` (codeunit 50110) los propague al
  IJL → ILE durante el posting.
- Implementación directa sobre las tablas: `LibraryItemTracking.CreatePurchaseOrderItemTracking`
  no existe en `Tests-TestLibraries 27.0.0.0`.

### `test/src/codeunit/DUoMILEIntegrationTests.Codeunit.al`

Comentario corregido en `SalesPosting_FixedMode_ILEHasDUoMFields`:
- Antes: "Note: DUoM Second Qty is copied from Sales Line (positive value) without sign adjustment"
- Después: documenta que `DUoM Second Qty = Abs(ILE.Quantity) × DUoM Ratio`, donde
  `ILE.Quantity` es negativo en ventas y se usa `Abs()` para el recálculo.

Seis nuevos tests:

| Test | Descripción |
|------|-------------|
| `PurchasePosting_VariableMode_ILEHasDUoMFields` | Variable sin lotes, compra: ratio 1.5, Second Qty = 15 |
| `PurchasePosting_AlwaysVarMode_ILEHasDUoMFields` | AlwaysVariable sin lotes, compra: ratio 1.8 manual, Second Qty = 18 |
| `SalesPosting_VariableMode_ILEHasDUoMFields` | Variable sin lotes, venta: DUoM Second Qty = Abs(−10) × 1.5 = 15 |
| `PurchaseLotPosting_FixedMode_ILEHasDUoMFields` | Fixed, un lote Purchase Order: ratio 0.8, Second Qty = 8 |
| `PurchaseTwoLots_VarMode_EachILEHasLotRatio` | Variable, dos lotes (ratios 1.2/1.8), sin DUoM Lot Ratio: verifica mecanismo Issue 23 |
| `AssignLotWithDUoMRatio_WritesTrackingSpec` | Test unitario del helper: verifica TrackingSpec con DUoM Ratio = 1.5 |

### Test 5 — Criterio de verificación del mecanismo Issue 23

El test `PurchaseTwoLots_VarMode_EachILEHasLotRatio` es el más crítico. Verifica
explícitamente que `DUoM Lot Ratio (50102)` está VACÍO para los lotes usados y que
aún así cada ILE recibe su ratio correcto (1.2 y 1.8 respectivamente).

Si el test pasa → el mecanismo `OnAfterCopyTrackingFromSpec` (Issue 23) funciona
correctamente para Purchase Orders con Item Tracking sin pre-registro en `DUoM Lot Ratio`.

Si el test falla → el mecanismo es incompleto: la cadena `Tracking Specification →
IJL → ILE` no transporta los ratios por lote cuando no hay registros en `DUoM Lot Ratio`.
En ese caso es necesario un suscriptor adicional en producción para propagar DUoM Ratio
desde `Reservation Entry` a `Tracking Specification` durante el posting.

## Criterio de done

- [x] Comentario de `SalesPosting_FixedMode_ILEHasDUoMFields` actualizado
- [x] Tests 1–3 (Variable/AlwaysVariable sin lotes) añadidos y correctos
- [x] Test 4 (Fixed, un lote desde Purchase Order) añadido
- [x] Test 5 (Variable, dos lotes, sin DUoM Lot Ratio) añadido
- [x] Test unitario del helper `AssignLotWithDUoMRatioToPurchLine` añadido
- [x] Cero warnings de compilación AL
- [x] Tests existentes `PurchasePosting_FixedMode_ILEHasDUoMFields` y
  `SalesPosting_FixedMode_ILEHasDUoMFields` no modificados (salvo comentario)

## Referencias

- Issue 23: `docs/issues/issue-23-tracking-copy-subscribers.md`
- Codeunit 50110 `DUoM Tracking Copy Subscribers`:
  `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al`
- Codeunit 50208 `DUoM Test Helpers`:
  `test/src/codeunit/DUoMTestHelpers.Codeunit.al`
- Codeunit 50209 `DUoM ILE Integration Tests`:
  `test/src/codeunit/DUoMILEIntegrationTests.Codeunit.al`
