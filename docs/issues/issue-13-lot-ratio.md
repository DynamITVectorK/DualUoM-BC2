# Issue 13 — DualUoM: Ratio Real por Lote (`DUoM Lot Ratio`)

## Contexto

**Issue:** #13
**Milestone:** Phase 2 — Funcionalidad extendida
**Etiquetas:** `enhancement`, `phase-2`, `lot-tracking`, `tdd`, `al`
**Fecha de implementación:** 2026-04-22

---

## Problema

En sectores agroalimentarios y similares, el ratio de conversión KG/PCS varía por lote
de recepción. Por ejemplo, un lote de lechugas Romanas puede pesar 0,38 kg/unidad
mientras que otro lote del mismo artículo pesa 0,41 kg/unidad. Sin soporte para ratios
por lote, el usuario debe introducir el ratio manualmente en cada línea de documento,
lo que es propenso a errores y poco eficiente.

---

## Cambios realizados

### Nuevos objetos

| Objeto | ID | Descripción |
|--------|----|-------------|
| `DUoM Lot Ratio` (table) | 50102 | Tabla de ratios reales por lote `(Item No., Lot No.)` |
| `DUoM Lot Ratio List` (page) | 50102 | Página de lista para mantenimiento de ratios por lote |
| `DUoM Lot Subscribers` (codeunit) | 50108 | Suscriptores para pre-rellenado automático al validar `Lot No.` |
| `DUoM Lot Ratio Tests` (test codeunit) | 50217 | 6 tests TDD que cubren los escenarios requeridos |

### Objetos modificados

| Objeto | Cambio |
|--------|--------|
| `DUoM Item Setup` (page 50100) | Acción `DUoM Lot Ratios` añadida → abre lista filtrada por artículo |
| `DUoM - All` (permissionset 50100) | `tabledata "DUoM Lot Ratio" = RIMD` añadido |
| `DUoM - Test All` (permissionset 50200) | `tabledata "DUoM Lot Ratio" = RIMD` añadido |
| `DUoM Test Helpers` (codeunit 50208) | Métodos `CreateLotRatio` y `DeleteLotRatioIfExists` añadidos |
| `DualUoM-BC.en-US.xlf` | Trans-units Issue 13 añadidos (IDs pendientes verificación .g.xlf) |
| `DualUoM-BC.es-ES.xlf` | Traducciones al español añadidas |

### Documentación actualizada

| Documento | Cambio |
|-----------|--------|
| `docs/02-functional-design.md` | Sección "Lot-Specific Real Ratio" añadida con jerarquía completa |
| `docs/03-technical-architecture.md` | Objetos 50102 (tabla, página) y 50108 (codeunit) añadidos |
| `docs/04-item-setup-model.md` | Jerarquía Item → Variante → Lote documentada; tabla DUoM Lot Ratio añadida |
| `docs/06-backlog.md` | Issue 13 marcado ✅ IMPLEMENTADO |
| `docs/TestCoverageAudit.md` | DUoM Lot Ratio (50102) y DUoM Lot Subscribers (50108) en inventario y matriz |

---

## Diseño implementado

### Tabla `DUoM Lot Ratio` (50102)

```al
table 50102 "DUoM Lot Ratio"
{
    // PK: (Item No., Lot No.)
    // Campos: Actual Ratio (Decimal, 0:5, > 0), Description (Text[100])
    // Validación: Actual Ratio ≤ 0 → error ErrActualRatioMustBePositiveLbl
}
```

### Jerarquía de resolución completa

```
1. DUoM Item Setup (50100)     → master switch (Dual UoM Enabled)
2. DUoM Item Variant Setup (50101) → override por variante (opcional)
3. DUoM Lot Ratio (50102)      → ratio real por lote (solo Variable/AlwaysVariable)
```

### Comportamiento por modo de conversión

| Modo | Comportamiento al validar Lot No. |
|------|-----------------------------------|
| Fixed | Ratio de lote NO aplicado. El ratio fijo siempre prevalece. |
| Variable | Si existe ratio de lote → sobreescribe DUoM Ratio + recalcula DUoM Second Qty |
| AlwaysVariable | Si existe ratio de lote → sobreescribe DUoM Ratio (como sugerencia editable) |

### Suscriptores (`DUoM Lot Subscribers`, codeunit 50108)

- `OnAfterValidateEvent` en `Lot No.` de `Purchase Line`
- `OnAfterValidateEvent` en `Lot No.` de `Sales Line`
- `OnAfterValidateEvent` en `Lot No.` de `Item Journal Line`
- Todos delegan a `ApplyLotRatioIfExists` (procedimiento local centralizado)

**Nota sobre firma BC 27:** El campo `Lot No.` existe como campo directo en `Purchase Line`
(tabla 39), `Sales Line` (tabla 37) e `Item Journal Line` (tabla 83) en BC 27 / runtime 15.
Ver comentario en el codeunit para la justificación completa.

---

## Tests implementados (codeunit 50217)

| Test | Escenario | Resultado esperado |
|------|-----------|-------------------|
| T01 | PurchLine, Variable, lote CON ratio (0.38) | DUoM Ratio = 0.38; DUoM Second Qty = Qty × 0.38 |
| T02 | PurchLine, Variable, lote SIN ratio | DUoM Ratio sin cambios |
| T03 | PurchLine, Fixed, lote CON ratio | DUoM Ratio = ratio fijo (1.0); lote ignorado |
| T04 | SalesLine, Variable, lote CON ratio (0.42) | DUoM Ratio = 0.42; DUoM Second Qty recalculada |
| T05 | ItemJnlLine, Variable, lote CON ratio (0.39) | DUoM Ratio = 0.39; DUoM Second Qty recalculada |
| T06 | Validar Actual Ratio = 0 ó -1 | Error de validación |

---

## Criterios de aceptación

- [x] Tabla `DUoM Lot Ratio` (50102) creada con validación de `Actual Ratio > 0`
- [x] Página `DUoM Lot Ratio List` (50102) creada y filtrable por artículo
- [x] Acción `DUoM Lot Ratios` en `DUoM Item Setup` (50100)
- [x] Pre-rellenado automático en `Purchase Line`, `Sales Line` e `Item Journal Line`
- [x] Modo Fixed: ratio de lote nunca sobreescribe
- [x] Modo Variable/AlwaysVariable: ratio de lote sobreescribe si existe
- [x] Permission sets actualizados en app y test
- [x] Tests TDD (6 tests) en codeunit 50217
- [x] XLF en-US y es-ES con nuevas cadenas
- [x] Documentación completa

---

## Referencias

- Issue de diseño original: `docs/06-backlog.md` sección Issue 13
- Diseño funcional: `docs/02-functional-design.md` → "Lot-Specific Real Ratio"
- Arquitectura técnica: `docs/03-technical-architecture.md` → Object Structure
- Modelo de datos: `docs/04-item-setup-model.md` → Configuration Hierarchy
- Cobertura de tests: `docs/TestCoverageAudit.md`
