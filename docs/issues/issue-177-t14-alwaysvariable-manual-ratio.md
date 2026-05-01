# Issue 177 — Fix T14: AlwaysVariable + ratio manual en IJL → ILE DUoM Second Qty = 25

## Estado: ✅ IMPLEMENTADO

## 1. Problema

El test `T14_AlwaysVar_ManualRatioOnIJL_ILEHasRatio` fallaba con:
- **Esperado:** `ILE."DUoM Second Qty" = 25`
- **Actual:** `ILE."DUoM Second Qty" = 0`

Esto bloqueaba el build/deploy (P1, CI rojo).

### Escenario del test T14

- Artículo en modo `AlwaysVariable` (sin ratio por defecto, sin registro en `DUoM Lot Ratio`)
- IJL para 10 unidades con `DUoM Ratio = 2,5` introducido manualmente
- Un único lote `LOTE-T14` asignado a toda la cantidad
- **Resultado esperado:** `ILE."DUoM Second Qty" = Abs(10) × 2,5 = 25`

## 2. Causa raíz

En `OnAfterInitItemLedgEntry` (`DUoM Inventory Subscribers`, codeunit 50104), existía
una salida anticipada incondicional para todos los casos `AlwaysVariable + Lot No.`,
independientemente de si el IJL tenía o no un ratio manual asignado:

```al
// ❌ Código anterior (incorrecto para T14)
if ItemJournalLine."Lot No." <> '' then
    if DUoMSetupResolver.GetEffectiveSetup(...) then
        if ConversionMode = ConversionMode::AlwaysVariable then
            exit;  // Salía incluso cuando DUoM Ratio = 2,5
```

Esta salida dejaba el ILE con `DUoM Second Qty = 0`. Después, en el flujo BC 27
de lot-tracking, el `ItemJnlLine` que recibe `ILECopyTrackingFromItemJnlLine` (codeunit
50110) es una copia del split por lote cuyos campos de extensión DUoM llegan a 0 (BC no
los replica en el split). Resultado: la guarda `(DUoM Ratio = 0) AND (DUoM Second Qty = 0)`
de ese subscriber salía sin hacer nada y el ILE quedaba en 0.

### Por qué T10 funciona (verificación de regresión)

- T10: `AlwaysVariable + dos lotes + IJL."DUoM Ratio" = 0`
  → La salida anticipada sigue activa porque `DUoM Ratio = 0` → ILE = 0 ✓
- T13: `Variable + dos lotes + IJL."DUoM Ratio" = 1,5` (modo Variable, no AlwaysVariable)
  → La salida anticipada no aplica → ILE se calcula correctamente ✓

## 3. Decisión de política (elegida: Opción B — operativa manual)

Para `AlwaysVariable + Lot No.`:
- Si `IJL."DUoM Ratio" = 0` → ILE."DUoM Second Qty" = 0 (comportamiento conservador, T10)
- Si `IJL."DUoM Ratio" ≠ 0` (ratio introducido manualmente) → ILE."DUoM Second Qty"
  = Abs(ILE.Quantity) × IJL."DUoM Ratio" (cálculo operativo, T14)

Esta política permite que el usuario que introduce explícitamente un ratio en el IJL
(ya sea vía el diario de artículos o la ventana de Item Tracking Lines) obtenga una
segunda cantidad correcta en el ILE. El escenario multi-lote sin ratio (T10) sigue
produciendo 0 para evitar distribuciones ambiguas.

## 4. Cambios realizados

### `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al`

- **Lógica**: Añadida guarda adicional `if ItemJournalLine."DUoM Ratio" = 0 then exit`
  dentro del bloque `AlwaysVariable + Lot`. Cuando el ratio es ≠ 0, el subscriber
  continúa y calcula `ILE."DUoM Second Qty" = Abs(ILE.Quantity) × AppliedRatio`.
- **Comentarios**: Actualizados para reflejar la excepción T14 y la regla
  AlwaysVariable + Lot bifurcada en dos sub-casos.

### `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al`

- **Comentarios**: Actualizado el bloque de prioridad del subscriber
  `ILECopyTrackingFromItemJnlLine` para indicar que T14 es manejado por
  `OnAfterInitItemLedgEntry` (no por este subscriber).

## 5. Tests afectados

| Test | Resultado esperado | Estado |
|------|--------------------|--------|
| T10 `IJLPosting_AlwaysVariable_TwoLots_NoLotRatio_ILESecondQtyIsZero` | ILE = 0 | ✅ Sin cambio |
| T13 `T13_TwoLots_NoLotRatioDB_ProportionalSecondQty` | ILE = 9/6 | ✅ Sin cambio |
| T14 `T14_AlwaysVar_ManualRatioOnIJL_ILEHasRatio` | ILE = 25 | ✅ Corregido |

## 6. Documentación actualizada

- **No applicable** para los documentos de diseño funcional/técnico: el cambio ajusta
  la implementación interna del suscriptor sin alterar el diseño externo documentado.
  El documento `docs/03-technical-architecture.md` refleja correctamente que el flujo
  de tracking CON lotes usa `OnAfterCopyTracking*` + `OnAfterInitItemLedgEntry`.

## Referencias

- Issue: #177
- Tests: `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` — T10, T13, T14
- Código: `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al` líneas 263-272
- Código: `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al` líneas 107-115
