# Issue 20 — Eliminar asunciones 1:1 línea/lote y adaptar DUoM al modelo estándar de Item Tracking de BC

## Contexto

**Milestone:** Phase 2 — Funcionalidad extendida
**Etiquetas:** `refactor`, `architecture`, `lot-ratio`, `multi-lot`, `item-tracking`, `BC27`
**Fecha de implementación:** 2026-04-27

---

## Problema

La implementación anterior de DUoM contenía una asunción incorrecta: que una línea origen
de Business Central (Purchase Line, Sales Line, Item Journal Line) equivale siempre a un
único lote. Esto es incorrecto en Business Central.

En BC, una única línea origen puede dividirse en múltiples lotes mediante Item Tracking:

```text
Línea de Diario de Producto:
- Cantidad = 10 KG
- DUoM Second Qty = total (dato agregado de la línea)

Seguimiento de producto (Reservation Entries):
- LOTE-A = 4 KG → ILE-A con DUoM Second Qty = 4 × ratio-A
- LOTE-B = 6 KG → ILE-B con DUoM Second Qty = 6 × ratio-B
```

### Bug específico corregido

En `OnAfterInitItemLedgEntry` (codeunit 50104 `DUoM Inventory Subscribers`), el bloque de
fallback para AlwaysVariable (DUoM Ratio = 0) copiaba `ItemJournalLine."DUoM Second Qty"`
directamente al ILE, sin distinción entre escenario de un lote o multi-lote:

```al
// ANTES — incorrecto para multi-lote:
else
    NewItemLedgEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";
```

En un escenario multi-lote con AlwaysVariable y sin ratio de lote:
- `ItemJournalLine."DUoM Second Qty"` = total de la línea (p.ej. 8 PCS para 10 KG)
- `ItemJournalLine."Lot No."` = lote específico del ILE (p.ej. "LOTE-A", 4 KG)
- Resultado incorrecto: ILE-A recibía 8 PCS (el total), en lugar de 0 o un valor proporcional

---

## Auditoría de asunciones 1:1

Se auditó todo el repositorio buscando patrones que impliquen 1 línea = 1 lote:

| Componente | Evaluación | Decisión |
|---|---|---|
| `OnAfterInitItemLedgEntry` — rama `DUoM Ratio ≠ 0` | ✅ CORRECTO: usa `Abs(ILE.Quantity) × DUoM Ratio` (proporcional al lote) | Sin cambios |
| `OnAfterInitItemLedgEntry` — rama `DUoM Ratio = 0`, `Lot No. = ''` | ✅ CORRECTO: sin lote asignado, es escenario sin trazabilidad, copia válida | Sin cambios |
| `OnAfterInitItemLedgEntry` — rama `DUoM Ratio = 0`, `Lot No. ≠ ''` | ❌ BUG: copiaba total de línea a cada ILE en multi-lote | **CORREGIDO** |
| `TryApplyLotRatioToILE` — lógica de ratio de lote | ✅ CORRECTO: opera sobre el ILE específico con su Lot No. | Sin cambios |
| `OnAfterValidateItemJnlLineLotNo` — pre-relleno IJL | ✅ CORRECTO: aplica ratio de lote al IJL cuando el usuario asigna Lot No. | Sin cambios |
| `OnPurchPostCopyDocFieldsToItemJnlLine` | ✅ ACEPTABLE: copia ratio genérico de la línea de compra al IJL. El override por lote ocurre en `TryApplyLotRatioToILE`. | Sin cambios |
| `OnSalesPostCopyDocFieldsToItemJnlLine` | ✅ ACEPTABLE: mismo razonamiento que compras | Sin cambios |
| Tests T01–T07 | ✅ CORRECTOS: T05 usa dos líneas IJL separadas (documentado y válido para su escenario) | Comentarios actualizados |
| Tests T08–T10 | ❌ AUSENTES: no existía test para el verdadero escenario 1:N (una línea, N lotes) | **AÑADIDOS** |

---

## Corrección aplicada

### `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al`

**En `OnAfterInitItemLedgEntry`:**

```al
// ANTES — incorrecto para multi-lote AlwaysVariable sin ratio de lote:
if ItemJournalLine."DUoM Ratio" <> 0 then
    NewItemLedgEntry."DUoM Second Qty" := Abs(NewItemLedgEntry.Quantity) * ItemJournalLine."DUoM Ratio"
else
    NewItemLedgEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";

// DESPUÉS — correcto, distingue entre escenario con y sin Lot No.:
if ItemJournalLine."DUoM Ratio" <> 0 then
    NewItemLedgEntry."DUoM Second Qty" := Abs(NewItemLedgEntry.Quantity) * ItemJournalLine."DUoM Ratio"
else
    if ItemJournalLine."Lot No." = '' then
        NewItemLedgEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";
    // else: AlwaysVariable + Lot No. asignado + sin ratio de lote → ILE queda a 0
```

**Razonamiento:**
- `Lot No. = ''`: no hay trazabilidad de lote activa. La copia directa del total es correcta (escenario de lote único implícito o sin trazabilidad).
- `Lot No. ≠ ''` + `DUoM Ratio = 0` + sin ratio en `DUoM Lot Ratio`: no es posible distribuir el total de la línea entre los lotes sin un ratio de distribución. El ILE queda a 0.
- Si hay ratio de lote en `DUoM Lot Ratio` (50102): `TryApplyLotRatioToILE` (llamada inmediatamente después) calcula y asigna el valor correcto.

---

## Nuevos tests

### T08 — Una línea IJL con dos lotes vía Item Tracking → cada ILE tiene su ratio

**Escenario:** UNA sola línea IJL para 10 unidades. DOS lotes asignados a la misma línea
(LOTE-T08A: 4 uds, LOTE-T08B: 6 uds) usando `DUoMTestHelpers.AssignLotToItemJnlLine`
llamado dos veces sobre el mismo `ItemJnlLine`.

**Diferencia con T05:** T05 usa DOS líneas IJL separadas (una por lote). T08 verifica el
verdadero escenario 1:N de BC, equivalente al que ocurre en Purchase/Sales Orders cuando
el usuario asigna N lotes en Item Tracking Lines desde una única línea de pedido.

**Verificación:**
- ILE para LOTE-T08A: `DUoM Ratio = 0.38`, `DUoM Second Qty = 1.52` (4 × 0.38)
- ILE para LOTE-T08B: `DUoM Ratio = 0.41`, `DUoM Second Qty = 2.46` (6 × 0.41)

### T09 — Suma de DUoM Second Qty de ILEs = total esperado

**Escenario:** mismo que T08 pero verificando la coherencia del agregado.

**Verificación:** suma de `DUoM Second Qty` de todos los ILEs = 3.98 (1.52 + 2.46).

### T10 — AlwaysVariable + multi-lote sin ratio de lote → ILE DUoM Second Qty = 0

**Escenario:** UNA línea IJL, modo AlwaysVariable, `DUoM Second Qty = 8` (entrada manual),
DOS lotes asignados SIN ratio en `DUoM Lot Ratio`.

**Verificación (comportamiento CORRECTO tras Issue 20):**
- ILE LOTE-T10A: `DUoM Second Qty = 0`
- ILE LOTE-T10B: `DUoM Second Qty = 0`

**Comportamiento INCORRECTO anterior (eliminado):**
- Cada ILE recibía `DUoM Second Qty = 8` (el total de la línea), lo que era claramente erróneo.

---

## Limitación conocida documentada

Para el escenario **AlwaysVariable + multi-lote sin ratio de lote**:

- El sistema no puede distribuir automáticamente el total de DUoM Second Qty entre los lotes.
- Los ILEs quedan con `DUoM Second Qty = 0`.
- **Solución recomendada al usuario:** registrar el ratio de lote en `DUoM Lot Ratio` (50102)
  para cada lote del artículo, o usar modo Variable con un ratio por defecto.

Esta limitación está preferiblemente a datos incorrectos en los registros contables.

---

## Documentación actualizada

| Documento | Cambio |
|---|---|
| `docs/02-functional-design.md` | Nueva sección "Regla de diseño: línea origen como agregado — modelo 1:N"; tabla de comportamiento por modo ampliada; sección "Limitación conocida: AlwaysVariable + multi-lote sin ratio de lote" |
| `docs/03-technical-architecture.md` | Corregida nota errónea "PHASE 2 — PENDIENTE" en `DUoM Lot Ratio` (50102); nueva sección "Modelo 1:N — Línea origen como agregado" con principios y restricciones de diseño |
| `docs/06-backlog.md` | Issue 13 actualizado (tests T01–T10); Issue 20 añadido como ✅ IMPLEMENTADO; Phase 3 actualizado (multi-lote resuelto) |

---

## Criterios de aceptación

- [x] Se ha auditado todo el repositorio buscando asunciones 1:1 entre línea y lote.
- [x] Se ha identificado y corregido el bug de `OnAfterInitItemLedgEntry` (AlwaysVariable + multi-lote).
- [x] Ninguna lógica de negocio asume que una línea origen tiene un único lote.
- [x] Test T08: una sola línea IJL con dos lotes vía Item Tracking → ILEs con ratios correctos.
- [x] Test T09: suma de DUoM Second Qty de ILEs = total esperado.
- [x] Test T10: AlwaysVariable + multi-lote sin ratio de lote → ILE DUoM Second Qty = 0 (no copia incorrecta del total).
- [x] Tests T01–T07 sin regresión.
- [x] Documentación actualizada con el modelo 1:N y la limitación conocida de AlwaysVariable.
- [x] No existe inserción manual de `Reservation Entry` que salte la lógica estándar de BC.

## Archivos modificados

- `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al` — corrección `OnAfterInitItemLedgEntry`
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` — 3 nuevos tests (T08–T10), comentarios actualizados
- `docs/02-functional-design.md` — modelo 1:N y limitación AlwaysVariable
- `docs/03-technical-architecture.md` — sección 1:N, corrección stale note
- `docs/06-backlog.md` — Issue 20 añadido, Phase 3 actualizado
- `docs/issues/issue-20-multilot-1n-refactor.md` — este documento

## Referencias

- Issue 13: `docs/issues/issue-13-lot-ratio.md`, `docs/issues/issue-13-lot-tracking-integration.md`
- `app/src/codeunit/DUoMInventorySubscribers.Codeunit.al` (codeunit 50104)
- `app/src/codeunit/DUoMLotSubscribers.Codeunit.al` (codeunit 50108)
- `test/src/codeunit/DUoMLotRatioTests.Codeunit.al` (codeunit 50217)

## Etiquetas

`refactor` · `architecture` · `lot-ratio` · `multi-lot` · `item-tracking` · `BC27` · `bug`
