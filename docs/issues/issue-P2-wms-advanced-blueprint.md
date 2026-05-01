# Issue P2 — Blueprint técnico WMS avanzado DUoM

## 1. Título

**DualUoM — Blueprint técnico WMS avanzado (readiness para Issues 14 y 15)**

---

## 2. Objetivo

Crear el diseño técnico detallado para la integración de DUoM con los flujos de almacén
avanzado de Business Central 27, como prerequisito obligatorio antes de comenzar la
implementación de Issue 14 (Warehouse Basic) y Issue 15 (Directed Put-Away & Pick).

---

## 3. Contexto

### Estado previo

WMS aparecía en el backlog como fase futura sin diseño técnico detallado:
- `docs/01-scope-mvp.md` mencionaba "Warehouse receipts and shipments" en Phase 2 y
  "Directed put-away and pick" sin especificación técnica.
- `docs/06-backlog.md` tenía los Issues 14 y 15 con alcance funcional pero sin mapa
  de eventos BC 27 verificados ni análisis de riesgos de permisos SaaS.
- No existía documento técnico de referencia para los implementadores.

### Motivación

La experiencia de Phase 1 demuestra que implementar subscribers sin verificar previamente
los eventos BC 27 genera errores AL0280/AL0282 y retrabajos significativos (p. ej. Issues
10, 22, 23). Para WMS el riesgo es mayor porque:

1. Los eventos de posting de almacén tienen firmas más complejas.
2. Los nombres de páginas de almacén cambian entre versiones de BC.
3. El permiso `M` sobre tablas base de almacén en SaaS puede bloquear el posting.
4. Existen múltiples codeunits de posting (`Whse.-Post Receipt`, `Whse.-Post Shipment`,
   `Create Put-away`, `Create Pick`) con diferente disponibilidad de eventos.

---

## 4. Cambios realizados

### Documento principal creado

`docs/09-wms-advanced-design.md` — Blueprint técnico WMS avanzado DUoM, con:

1. **Objetos estándar BC objetivo** (Sección 2): tablas de almacén por flujo (Receipt,
   Shipment, Activity, Entry) con IDs y descripción funcional.

2. **Mapa de propagación DUoM por flujo** (Sección 3): diagramas de propagación para:
   - Compra con Warehouse Receipt → ILE
   - Venta con Warehouse Shipment → ILE
   - Put-Away con Warehouse Activity → Warehouse Entry
   - Pick con Warehouse Activity → ILE
   - Tabla resumen de todos los saltos con estado (✅ implementado / ❌ pendiente / ⏳ futuro)

3. **Eventos estándar candidatos por objeto** (Sección 4): candidatos para cada salto
   de propagación con análisis de probabilidad y alternativas de fallback.

4. **Riesgos de permisos y performance SaaS** (Sección 5): tabla de riesgos con
   probabilidad, impacto y mitigación concreta. Incluye regla general del proyecto
   para resolver ambigüedades de permisos WMS.

5. **Estrategia de tests mínimos WMS** (Sección 6): matrices de tests para Issues 14
   y 15; template de test WMS con `// [GIVEN]/[WHEN]/[THEN]`; análisis de huecos
   en la cobertura actual.

6. **Plan de implementación incremental** (Sección 7): dos incrementos (Issues 14 y 15)
   con objetos, IDs sugeridos y pasos TDD ordenados.

7. **In/Out scope del primer incremento** (Sección 8): tablas explícitas de qué está
   dentro y fuera del alcance de Issues 14 y 15.

### Backlog actualizado

`docs/06-backlog.md` — Issues 14 y 15 enlazan al blueprint (sección 9 de referencias).

---

## 5. Criterios de aceptación

- [x] Documento técnico WMS creado: `docs/09-wms-advanced-design.md`.
- [x] Contiene objetos estándar BC objetivo por flujo.
- [x] Contiene mapa de propagación DUoM con estado por salto.
- [x] Contiene eventos candidatos con análisis de probabilidad.
- [x] Contiene tabla de riesgos de permisos y performance SaaS.
- [x] Contiene estrategia de tests mínimos con matrices por issue.
- [x] In/Out scope del primer incremento WMS definido claramente.
- [x] Backlog Issues 14/15 enlazan el blueprint.

---

## 6. Documentación relacionada

| Documento | Relación |
|-----------|---------|
| `docs/09-wms-advanced-design.md` | Documento creado en este issue |
| `docs/06-backlog.md` | Actualizado: Issues 14/15 enlazan el blueprint |
| `docs/issues/issue-14-warehouse-basic-duom-fields.md` | Especificación técnica de Issue 14 |
| `docs/01-scope-mvp.md` | Scope Phase 2 (Warehouse) — sin cambios |
| `docs/03-technical-architecture.md` | Patrón thin subscriber y SaaS-Safe Principles |

---

## 7. Etiquetas

`documentation` · `wms` · `phase-2` · `blueprint` · `architecture`
