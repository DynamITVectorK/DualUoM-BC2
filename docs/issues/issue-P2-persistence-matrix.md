# Issue P2 — docs: añadir matriz de persistencia DUoM por flujo y tabla (source of truth)

## Contexto

No existía un documento único que unificara dónde queda cada dato DUoM por flujo
(documentos, tracking, ILE, Value Entry). La persistencia y propagación estaba distribuida
entre varios codeunits y documentos técnicos, dificultando la trazabilidad de discrepancias
por parte de QA y soporte.

La limitación conocida en `Reservation Entry` requería visibilidad explícita en un único
punto de referencia.

## Cambios realizados

### Documentación

**Creado** `docs/10-persistence-matrix.md` — matriz completa de persistencia DUoM con:

1. **Campos DUoM por tabla** (§1): listado de tablas propias y extensiones BC con campos
   DUoM, mutabilidad y propósito de cada una.

2. **Flujos de propagación origen → destino** (§2): diagramas detallados de cada flujo:
   - §2.1 Flujo Compra (Purchase Order): Purchase Line → Purch. Rcpt./Inv./Cr. Memo Line + IJL
   - §2.2 Flujo Venta (Sales Order): Sales Line → Sales Shpt./Inv./Cr. Memo Line + IJL
   - §2.3 IJL → ILE / Value Entry (SIN tracking, CON tracking, flujo inverso)
   - §2.4 Item Tracking Lines UI: Tracking Specification pre-relleno

3. **Fuente de verdad por caso de uso** (§3):
   - Operación (documentos activos)
   - Reporting (documentos registrados)
   - Inventario (ILE)
   - Auditoría contable (Value Entry)
   - Prioridad global de fuentes de ratio al contabilizar

4. **Tabla de propagación entre suscriptores** (§4): 14 pasos de propagación con evento,
   codeunit y campos involucrados para cada tramo.

5. **Limitaciones conocidas** (§5):
   - §5.1 Reservation Entry — propagación DUoM no implementada en BC 27 (AL0282)
   - §5.2 Tracking Specification — buffer transitorios
   - §5.3 AlwaysVariable + lote sin ratio → ILE = 0 (intencionado)

6. **Cobertura de tests por área** (§6): tabla con codeunits de test y tests clave por área.

7. **Diagrama ASCII resumen** (§7): visión completa del flujo de persistencia de un vistazo.

8. **Referencias** (§8): enlace a documentos relacionados.

**Actualizado** `docs/03-technical-architecture.md`: añadido enlace a `docs/10-persistence-matrix.md`
en la sección de propagación de DUoM.

**Actualizado** `docs/06-backlog.md`: issue marcado como completado.

## Criterios de aceptación

- [x] Matriz completa y fácil de consultar.
- [x] QA/soporte pueden trazar discrepancias de datos sin ambigüedad.
- [x] Limitaciones conocidas visibles en un único punto.
- [x] Cada sección enlaza con los tests relevantes.

## Documentación afectada

- **Creado:** `docs/10-persistence-matrix.md`
- **Actualizado:** `docs/03-technical-architecture.md` — enlace a la nueva matriz
- **Actualizado:** `docs/06-backlog.md` — issue P2 marcado como completado

## Referencias

- `app/src/tableextension/DUoMReservationEntryExt.TableExt.al` — limitación Reservation Entry
- `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al` — suscriptores flujo compra/venta/IJL
- `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al` — patrón OnAfterCopyTracking*
- `app/src/codeunit/DUoMTrackingSubscribers.Codeunit.al` — pre-relleno Item Tracking Lines
- `docs/issues/issue-22-item-tracking-lines-duom.md` — §13 limitación Reservation Entry
- `docs/issues/issue-23-tracking-copy-subscribers.md` — patrón de propagación al ILE

## Etiquetas

`documentation` · `phase-2` · `persistence` · `source-of-truth` · `known-limitations`
