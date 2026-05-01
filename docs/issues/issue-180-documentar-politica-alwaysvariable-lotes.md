# Issue 180 — Documentar política definitiva AlwaysVariable + lotes en docs troncales

## Estado: ✅ IMPLEMENTADO

## 1. Problema

La decisión técnica establecida en Issue 177 (T10/T14) sobre el comportamiento de
`AlwaysVariable` con lotes no estaba consolidada de forma única en la documentación
troncal. Existía:

- Una descripción parcial en el documento histórico `docs/issues/issue-177-t14-alwaysvariable-manual-ratio.md`.
- Una tabla incompleta en `docs/02-functional-design.md` (faltaba el caso T14).
- Sin referencia en `docs/03-technical-architecture.md`.
- Sin sección específica en `docs/manual-usuario.md`.

El resultado era que QA podía derivar escenarios con ambigüedad, especialmente para el
caso 2 (AlwaysVariable + lote + ratio manual ≠ 0, cubierto por T14).

## 2. Política consolidada

Para `AlwaysVariable + Lot No.`, existen cuatro sub-casos según la disponibilidad de
ratio de lote en `DUoM Lot Ratio` (50102) y ratio manual en `IJL.DUoM Ratio`:

| Caso | `DUoM Lot Ratio` | `IJL.DUoM Ratio` | `Lot No.` | `ILE.DUoM Second Qty` | Test |
|------|------------------|------------------|-----------|------------------------|------|
| 1 | ✅ Existe | — | Cualquiera | `Abs(ILE.Qty) × ratio_lote` | T08–T09 |
| 2 | ❌ No existe | ≠ 0 (manual) | ✅ Asignado | `Abs(ILE.Qty) × ratio_manual` | T14 |
| 3 | ❌ No existe | 0 | ❌ Vacío | `IJL.DUoM Second Qty` (copia directa) | — |
| 4 | ❌ No existe | 0 | ✅ Asignado | `0` (distribución imposible) | T10 |

## 3. Cambios realizados

### `docs/02-functional-design.md`

- **Tabla de comportamiento por modo** expandida: añadida la fila del caso 2 (T14).
  La fila anterior "AlwaysVariable sin ratio de lote, con Lot No." se ha dividido en
  dos sub-casos (con/sin ratio manual).
- **Nueva sección "Política AlwaysVariable + lotes"** con tabla de decisión completa
  (4 casos), rationale por caso e implementación AL de referencia.
- **Sección "Limitación conocida"** aclarada: ahora especifica que sólo aplica al
  caso 4 (sin ratio de lote NI manual + con lote), e incluye las soluciones del caso 2.

### `docs/03-technical-architecture.md`

- **Historial de decisión** actualizado con referencia a Issue 177.
- **Nueva sección "Política AlwaysVariable + lotes — resumen técnico"** añadida tras el
  historial, con tabla de casos, extracto del código AL relevante y referencia a la
  prioridad global de fuentes de ratio.

### `docs/manual-usuario.md`

- **Versión** actualizada a v1.5.
- **Sección 9.2** actualizada: tabla expandida con la fila del caso 2 (ratio manual)
  y enlace a la nueva sección 9.2b.
- **Nueva sección 9.2b** añadida: "AlwaysVariable con ratio manual sin ratio de lote
  (caso avanzado)" con ejemplo operativo, tabla de decisión completa y consejo de uso.
- **Sección 9.5** actualizada: nota sobre AlwaysVariable ahora menciona ambas soluciones
  (registrar ratio de lote o introducir ratio manual).
- **Índice** actualizado con entradas para secciones 9.1, 9.2, 9.2b y 9.3.

## 4. Tests de referencia

| Test | Procedimiento | Escenario | Caso de política |
|------|---------------|-----------|-----------------|
| T10 | `IJLPosting_AlwaysVariable_TwoLots_NoLotRatio_ILESecondQtyIsZero` | AlwaysVariable + 2 lotes + sin ratio | Caso 4 → ILE = 0 |
| T14 | `T14_AlwaysVar_ManualRatioOnIJL_ILEHasRatio` | AlwaysVariable + 1 lote + ratio manual 2,5 | Caso 2 → ILE = 25 |
| T08–T09 | `IJLPosting_*TwoLots*` | Variable + 2 lotes + ratio de lote registrado | Caso 1 → ILE = Abs(Qty) × ratio_lote |

## 5. Verificación de consistencia

La documentación es consistente con el comportamiento AL actual:

- `OnAfterInitItemLedgEntry` (codeunit 50104, líneas 262–291): guarda
  `AlwaysVariable + Lot No. + DUoM Ratio = 0 → exit` implementa el caso 4; la caída
  al cálculo general cuando `DUoM Ratio ≠ 0` implementa el caso 2.
- `ILECopyTrackingFromItemJnlLine` (codeunit 50110, líneas 107–147): prioridad
  `DUoM Lot Ratio > IJL.DUoM Ratio` implementa el caso 1.

## Referencias

- Issue: #180
- Issue relacionado: #177 (`docs/issues/issue-177-t14-alwaysvariable-manual-ratio.md`)
- Documentación actualizada:
  - `docs/02-functional-design.md`
  - `docs/03-technical-architecture.md`
  - `docs/manual-usuario.md`
- Tests: `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` — T10, T14
- Código: `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al` — OnAfterInitItemLedgEntry
- Código: `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al` — ILECopyTrackingFromItemJnlLine
