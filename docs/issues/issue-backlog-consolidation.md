# [P1] Consolidar backlog vigente y archivar contenido histórico contradictorio

> **Estado:** ✅ COMPLETADO

## 1. Problema

Mezcla de contenido histórico y operativo en la documentación del proyecto que inducía
confusión en la priorización del equipo:

- `docs/06-backlog.md` contenía un bloque `> **Siguiente issue recomendado:**` desactualizado
  (apuntaba a Issue 12, que ya estaba completado junto con Issues 13, 20–24, 154, 171).
- `docs/issues/next-task-issue.md` estaba marcado como documento histórico en su cabecera,
  pero en el cuerpo afirmaba que Issue 13 estaba `❌ pendiente`, contradiciendo la realidad.

## 2. Cambios realizados

### `docs/06-backlog.md`

- Añadida sección **"Estado vigente (fuente de verdad)"** al inicio del documento, con:
  - Tabla de todos los issues completados (Phase 1 + Phase 2 hasta la fecha).
  - Bloque destacado con el próximo issue pendiente (Issue 14).
  - Tabla resumen de issues pendientes ordenados por prioridad.
- Eliminado el bloque `> **Siguiente issue recomendado:** Issue 12 ...` que estaba obsoleto.
- Simplificado el encabezado: eliminada la marca de fecha `> **Estado actualizado:** 2026-04-20`.

### `docs/issues/next-task-issue.md`

- Corregida la línea contradictoria:
  `❌ pendiente — ningún objeto DUoM Lot Ratio existe todavía`
  → `✅ COMPLETADO — DUoM Lot Ratio (50102), DUoM Lot Subscribers (50108), ...`
- Actualizado el bloque de advertencia histórico para mencionar los Issues 22–24 y 154
  también completados, y apuntar a la nueva sección "Estado vigente" del backlog.

## 3. Criterios de aceptación verificados

- [x] Existe una única lista de prioridades vigente en `docs/06-backlog.md` (sección
      "Estado vigente (fuente de verdad)").
- [x] Los documentos históricos están claramente señalizados y no contradicen el estado actual.
- [x] El "next issue" real (Issue 14) es inequívoco: aparece en la sección "Estado vigente"
      del backlog y en el banner de `next-task-issue.md`.

## 4. Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `docs/06-backlog.md` | Nueva sección "Estado vigente"; eliminado bloque obsoleto |
| `docs/issues/next-task-issue.md` | Corregida afirmación operativa contradictoria |
| `docs/issues/issue-backlog-consolidation.md` | Este fichero (documentación del cambio) |

## 5. Documentación afectada

No aplicable — este issue es exclusivamente de mantenimiento documental.
