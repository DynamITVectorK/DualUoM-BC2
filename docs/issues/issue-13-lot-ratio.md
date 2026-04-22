# Issue 13 — DualUoM: Ratio Real por Lote con Item Tracking (`DUoM Lot Ratio`)

## Contexto

**Issue:** #13 (rediseño Phase 2)
**Milestone:** Phase 2 — Funcionalidad extendida
**Etiquetas:** `enhancement`, `phase-2`, `lot-tracking`, `item-tracking`, `tdd`, `al`
**Fecha de implementación:** 2026-04-22

---

## Problema

En sectores agroalimentarios y similares, el ratio de conversión KG/PCS varía por lote
de recepción. Por ejemplo, un lote de lechugas Romanas puede pesar 0,38 kg/unidad
mientras que otro lote del mismo artículo pesa 0,41 kg/unidad.

### Hallazgo arquitectónico crítico

> **`Lot No.` NO es un campo directo en `Purchase Line` (tabla 39) ni en `Sales Line`
> (tabla 37) en BC 27 / runtime 15.** Solo es campo directo en `Item Journal Line` (tabla 83).

El diseño anterior (PR anterior, 2026-04-22 primer intento) subscribía eventos en
`Purchase Line` y `Sales Line` para el campo `Lot No.` — esos eventos no existen en BC 27.
Este PR implementa el diseño correcto basado en `Item Journal Line` y `OnAfterInitItemLedgEntry`.

### Bug existente corregido (multi-lote)

El suscriptor anterior `OnAfterInitItemLedgEntry` en `DUoM Inventory Subscribers` (50104)
copiaba `DUoM Second Qty` **total** de la línea al ILE. Con múltiples lotes, cada ILE
recibía la segunda cantidad total en lugar de la parte proporcional. Corregido.

---

## Cambios realizados

### Nuevos objetos

| Objeto | ID | Descripción |
|--------|----|-------------|
| `DUoM Lot Subscribers` (codeunit) | 50108 | Suscriptor IJL `Lot No.` + método `TryApplyLotRatioToILE` |
| `DUoM Lot Ratio Tests` (test codeunit) | 50217 | 7 tests TDD (T01–T07) |

### Objetos modificados

| Objeto | Cambio |
|--------|--------|
| `DUoM Inventory Subscribers` (cu 50104) | `OnAfterInitItemLedgEntry` refactorizado: recálculo proporcional + llamada a `TryApplyLotRatioToILE` |

### Objetos sin cambios (ya existían)

| Objeto | Estado |
|--------|--------|
| `DUoM Lot Ratio` (table 50102) | ✅ Sin cambios de estructura |
| `DUoM Lot Ratio List` (page 50102) | ✅ Sin cambios |
| Permission sets (50100, 50200) | ✅ Ya incluían `DUoM Lot Ratio = RIMD` |
| XLF translations | No applicable — sin nuevos Labels en el codeunit 50108 |

---

## Diseño implementado

### Flujo de integración

```
Caso A — Item Journal Line (Lot No. campo directo):
  Usuario valida Lot No. en IJL
  → OnAfterValidateEvent[Lot No.] en Table "Item Journal Line"
  → DUoM Lot Subscribers (50108): busca DUoM Lot Ratio(Item No., Lot No.)
  → Si existe y modo ≠ Fixed: sobreescribe DUoM Ratio + recalcula DUoM Second Qty

Caso B — Purchase/Sales Line (N lotes vía Item Tracking):
  Usuario asigna N lotes en "Item Tracking Lines" (flujo estándar BC)
  → Al contabilizar: BC crea un ILE por lote, cada uno con Lot No. propio en el IJL
  → OnAfterInitItemLedgEntry(NewILE, ItemJnlLine, ...)
    1. DUoM Ratio = IJL."DUoM Ratio" (ratio del documento)
    2. DUoM Second Qty = Abs(ILE.Quantity) × DUoM Ratio (proporcional al lote)
    3. TryApplyLotRatioToILE: si lote tiene ratio y modo ≠ Fixed →
         ILE.DUoM Ratio = LotActualRatio
         ILE.DUoM Second Qty = Abs(ILE.Quantity) × LotActualRatio
```

### Jerarquía de resolución completa

```
1. DUoM Item Setup (50100)          → master switch (Dual UoM Enabled)
2. DUoM Item Variant Setup (50101)  → override por variante (opcional)
3. DUoM Lot Ratio (50102)           → ratio real por lote (Variable/AlwaysVariable)
                                        Se aplica en ILE (vía OnAfterInitItemLedgEntry)
                                        y en IJL (vía OnAfterValidateEvent[Lot No.])
```

### Localización

**Not applicable.** El codeunit 50108 (`DUoM Lot Subscribers`) no añade ningún `Label`
nuevo. La única cadena de usuario visible relacionada con lotes (`ErrActualRatioMustBePositiveLbl`)
ya existe en `DUoM Lot Ratio` (tabla 50102, implementada en el PR original de Issue 13 MVP).
Por lo tanto, no se requieren cambios en los ficheros XLF.

---

## Tests implementados (codeunit 50217)

| Test | Escenario | Resultado esperado |
|------|-----------|-------------------|
| T01 | IJL, Variable, lote CON ratio (0,38) | DUoM Ratio = 0,38; Second Qty = Qty × 0,38 |
| T02 | IJL, Variable, lote SIN ratio | DUoM Ratio sin cambios (valor previo conservado) |
| T03 | IJL, Fixed, lote CON ratio | DUoM Ratio = ratio fijo (1,0); lote ignorado |
| T04 | IJL posting, lote con ratio 0,38, Variable | ILE.DUoM Ratio = 0,38; Second Qty = 10 × 0,38 = 3,8 |
| T05 | IJL posting, dos lotes (A=6uds/0,38; B=4uds/0,41) ✓ Crítico | ILE-A: 0,38/2,28; ILE-B: 0,41/1,64 |
| T06 | IJL posting salida, lote con ratio 0,42 | ILE.DUoM Second Qty = Abs(-10) × 0,42 = 4,2 |
| T07a | Actual Ratio = 0 → error validación | asserterror captura el error |
| T07b | Actual Ratio = -1 → error validación | asserterror captura el error |

---

## Criterios de aceptación

- [x] Codeunit `DUoM Lot Subscribers` (50108) creado con suscriptor IJL Lot No.
- [x] Método público `TryApplyLotRatioToILE` implementado
- [x] `OnAfterInitItemLedgEntry` en 50104 refactorizado: recálculo proporcional
- [x] Modo Fixed: ratio de lote nunca sobreescribe
- [x] Modo Variable/AlwaysVariable: ratio de lote sobreescribe si existe
- [x] Tests T01–T07 en codeunit 50217
- [x] Documentación actualizada: 02, 03, 04, 06 docs
- [x] Localización: Not applicable (sin nuevos Labels)

---

## Referencias

- Diseño funcional: `docs/02-functional-design.md` → "Lot-Specific Real Ratio"
- Arquitectura técnica: `docs/03-technical-architecture.md` → Object Structure
- Modelo de datos: `docs/04-item-setup-model.md` → Configuration Hierarchy
- Backlog: `docs/06-backlog.md` → Issue 13 marcado ✅ IMPLEMENTADO
- Cobertura de tests: `docs/TestCoverageAudit.md`

