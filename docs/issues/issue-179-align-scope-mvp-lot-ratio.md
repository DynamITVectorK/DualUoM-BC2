# Issue 179 — docs: alinear docs/01-scope-mvp.md con estado real de lotes DUoM

## Contexto

`docs/01-scope-mvp.md` marcaba el ratio por lote como "Phase 2 pendiente" cuando la
funcionalidad ya había sido completamente implementada en las Issues 13, 20, 21, 22 y 23.
Esto creaba una contradicción entre la documentación de alcance y el estado real del código.

El pipeline completo de lotes DUoM está implementado a través de:
- `DUoM Lot Ratio` (tabla 50102) — almacenamiento del ratio real por lote
- `DUoM Tracking Subscribers` (codeunit 50109) — pre-relleno en Item Tracking Lines
- `DUoM Tracking Copy Subscribers` (codeunit 50110) — propagación
  `Tracking Specification → Item Journal Line → Item Ledger Entry`
- `DUoM Reservation Entry Ext` (tableextension 50123) — campos definidos, con limitación
  conocida de BC 27 (ver más abajo)

## Problema

- `docs/01-scope-mvp.md` Phase 2 incluía: *"Lot-specific real ratio (second qty per lot
  stored on Item Tracking)"* — funcionalidad que ya está implementada.
- `docs/02-functional-design.md` sección "Flujo de integración implementado" seguía
  describiendo el mecanismo obsoleto (`TryApplyLotRatioToILE` en `OnAfterInitItemLedgEntry`)
  en lugar del mecanismo actual (`OnAfterCopyTracking*`, codeunit 50110, Issue 23).
- `docs/03-technical-architecture.md` mencionaba Item Tracking como "Phase 2" en la
  sección Standard-First Philosophy.

## Cambios realizados

### `docs/01-scope-mvp.md`

- Marcado como **✅ COMPLETADO** en el encabezado de Phase 1.
- Añadido "**Lot-specific ratio**" al listado "In scope for MVP" con descripción del
  mecanismo implementado y enlaces cruzados a `02-functional-design.md` y
  `03-technical-architecture.md`.
- Añadida nota de **limitación conocida (BC 27)**: los campos DUoM en `Reservation Entry`
  están definidos pero no se rellenan automáticamente porque el evento
  `OnAfterCopyTrackingFromTrackingSpec` no expone un parámetro `var Rec` modificable
  (AL0282). El ratio de lote llega correctamente al ILE mediante la cadena
  `Tracking Specification → Item Journal Line → Item Ledger Entry`.
- Añadido criterio de éxito MVP: *"Items with lot-specific ratios post the correct
  per-lot DUoM Second Qty to each ILE"*.
- Eliminado de Phase 2: *"Lot-specific real ratio (second qty per lot stored on Item Tracking)"*.

### `docs/02-functional-design.md`

- Sección "Flujo de integración implementado": actualizada del mecanismo obsoleto
  (`TryApplyLotRatioToILE`) al mecanismo actual (`OnAfterCopyTracking*`, codeunit 50110).
  Añadida referencia a Issues 21–23 y enlace a `docs/03-technical-architecture.md`.
- Sección "Ratio real por lote — Resumen para módulo Inventario": actualizada para
  referenciar codeunit 50109 y codeunit 50110 como mecanismos actuales en lugar de
  `TryApplyLotRatioToILE`.

### `docs/03-technical-architecture.md`

- Standard-First Philosophy: corregida referencia *"(Phase 2)"* por
  *"(implemented in Phase 1 — Issues 13, 20, 21, 22, 23)"* para la integración
  con `Item Tracking`.

## Criterios de aceptación

- [x] `docs/01-scope-mvp.md` no contradice el estado real del código
- [x] No quedan referencias a "pendiente" para lotes ya implementados
- [x] Limitación BC 27 (Reservation Entry) documentada explícitamente en scope
- [x] Flujo de integración en `docs/02-functional-design.md` actualizado al mecanismo Issue 23
- [x] Referencias "Phase 2" corregidas en `docs/03-technical-architecture.md`
- [x] Consistencia verificada con README.md (sin cambios necesarios — enlace al scope doc correcto)

## Documentación actualizada

- `docs/01-scope-mvp.md` — sección MVP ampliada con lot-specific ratio
- `docs/02-functional-design.md` — sección "Flujo de integración" y "Resumen módulo Inventario"
- `docs/03-technical-architecture.md` — sección Standard-First Philosophy

## Referencias

- Issue 13: implementación inicial `DUoM Lot Ratio`
- Issue 20: consolidación modelo 1:N
- Issue 21: eliminación subscriber `OnAfterValidateEvent[Lot No.]`
- Issue 22: integración con Item Tracking Lines UI (`DUoM Tracking Subscribers`)
- Issue 23: patrón `OnAfterCopyTracking*` en `DUoM Tracking Copy Subscribers`
- `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al` — implementación principal
- `app/src/tableextension/DUoMReservationEntryExt.TableExt.al` — limitación BC 27

## Etiquetas

`docs` · `scope` · `lot-ratio` · `alineacion` · `phase-1`
