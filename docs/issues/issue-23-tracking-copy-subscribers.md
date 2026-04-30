# Issue 23 — fix: propagar DUoM Ratio al ILE usando el patrón OnAfterCopyTracking* de BC

## Contexto

La codeunit estándar `Package Management (6516)` define el patrón oficial de BC
para propagar campos de tracking desde `Tracking Specification` hasta
`Item Ledger Entry`. El mecanismo previo (`OnAfterInitItemLedgEntry` + `TryApplyLotRatioToILE`)
usaba el evento de Codeunit y dependía de `DUoM Lot Ratio (50102)` para obtener el ratio
de lote. No funcionaba cuando el usuario introducía el ratio directamente en
`Item Tracking Lines` para un pedido nuevo sin pre-registro en 50102.

## Causa raíz del problema

`DUoMInventorySubscribers` usaba `OnAfterInitItemLedgEntry` (Codeunit 22) como
punto de propagación al ILE. Este evento recibe el IJL total de la línea, no el
split por lote. El subscriber compensaba con `TryApplyLotRatioToILE` que leía
`DUoM Lot Ratio (50102)` — tabla que solo tiene datos si el lote fue recibido
anteriormente. No funcionaba con ratios introducidos directamente en Item Tracking Lines.

## Solución

Reemplazar `OnAfterInitItemLedgEntry` + `TryApplyLotRatioToILE` por tres subscribers
en el nuevo codeunit 50110 `DUoM Tracking Copy Subscribers` que siguen exactamente
el patrón de `Package Management (6516)`:

```
Tracking Specification
  → Table "Item Journal Line" · OnAfterCopyTrackingFromSpec          (línea 774)
      ↓
Item Journal Line
  → Table "Item Ledger Entry" · OnAfterCopyTrackingFromItemJnlLine   (línea 551)
      ↓
Item Ledger Entry  ✓
```

Flujo inverso (salidas aplicadas contra entradas existentes):
```
Item Ledger Entry
  → Table "Item Journal Line" · OnAfterCopyTrackingFromItemLedgEntry (línea 768)
```

## Cambios realizados

### Producción

- **Creado** `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al` (50110)
  con tres subscribers: `IJLCopyTrackingFromSpec`, `ILECopyTrackingFromItemJnlLine`,
  `IJLCopyTrackingFromItemLedgEntry`.

- **Restaurado** subscriber `OnAfterInitItemLedgEntry` en `DUoMInventorySubscribers` (50104),
  simplificado (sin llamada a `TryApplyLotRatioToILE`). Necesario para artículos sin Item
  Tracking donde `OnAfterCopyTrackingFromItemJnlLine` no se dispara.

- **Actualizada** cabecera de `DUoMInventorySubscribers` para documentar los dos mecanismos
  paralelos (SIN y CON Item Tracking).

- **Añadido** comentario NOTA a `TryApplyLotRatioToILE` en `DUoMLotSubscribers` (50108)
  indicando que ya no se llama desde el flujo de posting.

- **Actualizada** cabecera de `DUoMLotSubscribers` para reflejar la nueva arquitectura.

### Tests

- **Añadidos** tests T13 y T14 en `DUoMLotRatioTests.Codeunit.al` (50217):
  - T13: Variable + dos lotes sin pre-registro en 50102 → cada ILE con DUoM Second Qty
    proporcional al ratio del IJL (verifica `ILECopyTrackingFromItemJnlLine`).
  - T14: AlwaysVariable + lote único + ratio manual en IJL sin 50102 → ILE con ratio
    correcto (verifica la rama DUoM Ratio ≠ 0 en `ILECopyTrackingFromItemJnlLine`).

- **Actualizada** cabecera de `DUoMLotRatioTests` para documentar los nuevos tests.

### Documentación

- **Actualizado** `docs/03-technical-architecture.md`:
  - Tabla de codeunits: añadida entrada para codeunit 50110.
  - Tabla de codeunits: actualizada descripción de codeunit 50108.
  - Sección "Modelo 1:N": añadido sub-sección de flujo OnAfterCopyTracking* con
    diagrama de cadena. Historial de decisión ampliado con Issue 23.

## Criterios de aceptación

- [x] Codeunit 50110 `DUoM Tracking Copy Subscribers` creado con 3 subscribers
- [x] `OnAfterInitItemLedgEntry` eliminado de `DUoMInventorySubscribers` (50104)
- [x] Comentario NOTA añadido a `TryApplyLotRatioToILE` en `DUoMLotSubscribers`
- [x] Test T13: dos lotes, sin 50102, DUoM Second Qty proporcional al ratio del IJL
- [x] Test T14: AlwaysVariable, ratio manual, sin 50102, ILE con ratio correcto
- [x] Documentación `docs/03-technical-architecture.md` actualizada
- [ ] CI verde · cero warnings (pendiente validación en entorno BC)

## Impacto en tests existentes

Los tests T04–T10 siguen cubriendo el escenario con `DUoM Lot Ratio (50102)`. Con el
nuevo mecanismo, el ratio de lote llega al ILE via:
1. `DUoMTrackingSubscribers` pre-rellena `Tracking Specification.DUoM Ratio` al
   validar `Lot No.` en Item Tracking Lines (usa 50102 si existe).
2. `IJLCopyTrackingFromSpec` copia de `Tracking Specification` al split IJL.
3. `ILECopyTrackingFromItemJnlLine` copia del IJL al ILE calculando `Abs(ILE.Qty) × ratio`.

## Referencias

- Patrón de referencia: `Package Management (6516)` líneas 551, 768, 774
- Signatures verificadas contra BC 27 / runtime 15
- Issues relacionados: 13, 20, 21, 22

## Etiquetas

`fix` · `ILE` · `Item Tracking` · `lot-ratio` · `OnAfterCopyTracking*` · `posting`
