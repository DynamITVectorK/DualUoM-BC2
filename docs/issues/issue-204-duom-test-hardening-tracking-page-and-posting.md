# Issue 204 — Hardening de tests DUoM (Page 6510 + posting multilot)

## Objetivo
Construir una suite de pruebas AL suficiente para sostener la funcionalidad DUoM desde la page de tracking hasta destino (IJL/ILE/WMS).

## Alcance
1. Tests de visibilidad UI en Page 6510 (columnas DUoM presentes).
2. Tests funcionales en Tracking Specification (`Lot No.`, `Quantity (Base)`).
3. Tests integración compra/diario multilot con ratios diferentes.
4. Tests de posting: 1 ILE por lote con ratio correcta.
5. Tests negativos AlwaysVariable cuando falte ratio por lote.
6. Tests de compliance: no creación manual de Reservation Entry.

## Criterios de aceptación
- Suite ejecuta en CI (AL-Go) y cubre happy paths + negativos.
- Evidencia explícita de modelo 1:N (línea origen -> N lotes).
- Cobertura mínima definida y documentada en estrategia de testing.

## Librerías estándar a priorizar
- `Library Assert`
- `Library - Inventory`
- `Library - Item Tracking` (si disponible)

## Entregables
- Nuevas codeunits de test o ampliación de las existentes.
- Actualización de `docs/05-testing-strategy.md` y backlog.
