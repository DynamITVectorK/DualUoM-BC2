# fix/test: persistencia DUoM en Item Tracking Lines de pedido de compra

## Estado

**Estado:** ✅ IMPLEMENTADO — 2026-05-02

---

## Objetivo

Implementar un test automatizado AL que reproduzca el flujo real de usuario para verificar
que los campos DUoM introducidos en `Item Tracking Lines` desde un pedido de compra:

- se guardan correctamente en base de datos (Reservation Entry),
- se asocian al lote correcto,
- se mantienen ligados a la línea de compra,
- y vuelven a mostrarse al reabrir la página.

---

## Objetos creados

| Objeto | Tipo | ID | Archivo |
|--------|------|----|---------|
| `DUoM Purch Tracking Persist` | test codeunit | 50219 | `test/src/codeunit/DUoMPurchTrackingPersistTests.Codeunit.al` |

---

## Test implementado

### T-PERSIST-01 — `PurchLine_ItemTracking_DUoMValuesPersistAfterCloseAndReopen`

**Codeunit:** 50219 `DUoM Purch Tracking Persist`

**Handler:** `ItemTrackingLines_AssignAndVerify_MPH` (ModalPageHandler, 2 pasos)

**Escenario:**

```gherkin
Given un pedido de compra con una línea de artículo con seguimiento por lote
And el artículo tiene DUoM activo en modo AlwaysVariable
When el usuario abre Item Tracking Lines desde la línea de compra
And introduce Lot No. = 'LOT-DUOM-001'
And introduce Quantity (Base) = 10
And introduce DUoM Ratio = 1.25
And introduce DUoM Second Qty = 8
And acepta la página (OK)
Then existe una Reservation Entry vinculada a la Purchase Line con los valores DUoM
When el usuario vuelve a abrir Item Tracking Lines desde la misma línea
Then los valores DUoM aparecen cargados en la página (Lot No., DUoM Ratio, DUoM Second Qty)
```

**Valores de referencia:**

| Campo | Valor |
|-------|-------|
| Quantity | 10 |
| Lot No. | LOT-DUOM-001 |
| DUoM Ratio | 1.25 |
| DUoM Second Qty | 8 (manual, no calculado) |

Los valores DUoM Ratio = 1.25 y DUoM Second Qty = 8 son independientes (modo AlwaysVariable).
El trigger `OnValidate` de `DUoM Ratio` en `DUoMTrackingSpecExt` hace `exit` sin recalcular
`DUoM Second Qty` en modo AlwaysVariable, por lo que ambos valores se almacenan tal cual.

---

## Arquitectura cubierta

### Flujo de persistencia (al cerrar Item Tracking Lines)

```
TrackingSpec buffer (con DUoM Ratio=1.25, DUoM Second Qty=8)
→ OK pressed
→ ReservEntry.CopyTrackingFromTrackingSpec(TrackSpec)
→ OnAfterCopyTrackingFromTrackingSpec (codeunit 50110)
    ↓ ReservEntry."DUoM Ratio"      := 1.25
    ↓ ReservEntry."DUoM Second Qty" := 8
→ ReservEntry.Insert()
```

**Subscriber:** `ReservEntryOnAfterCopyTrackingFromTrackingSpec` en codeunit 50110
(`DUoM Tracking Copy Subs`). Firma verificada contra BC 27 / Package Management (6516).

### Flujo de recarga (al reabrir Item Tracking Lines)

```
ReservEntry (Source = Purchase Line, Lot = LOT-DUOM-001, DUoM Ratio=1.25, DUoM Second Qty=8)
→ TrackSpec.CopyTrackingFromReservEntry(ReservEntry)
→ OnAfterCopyTrackingFromReservEntry (codeunit 50110)
    ↓ TrackSpec."DUoM Ratio"      := 1.25
    ↓ TrackSpec."DUoM Second Qty" := 8  (sin recálculo — asignación directa :=)
→ Página muestra valores correctos
```

**Subscribers:** `TrackingSpecCopyTrackingFromReservEntry` y
`TrackingSpecOnAfterInitFromReservEntry` en codeunit 50110.

### Enlace Purchase Line → Reservation Entry

```
ReservEntry."Source Type"    = Database::"Purchase Line" (38)
ReservEntry."Source Subtype" = PurchLine."Document Type".AsInteger()
ReservEntry."Source ID"      = PurchHeader."No."
ReservEntry."Source Ref. No." = PurchLine."Line No."
ReservEntry."Lot No."        = 'LOT-DUOM-001'
```

---

## Decisiones de implementación

### 1. Modo AlwaysVariable

Se usa modo `AlwaysVariable` (no Fixed ni Variable) porque:
- El usuario introduce `DUoM Ratio` y `DUoM Second Qty` de forma totalmente independiente.
- En modo AlwaysVariable, el trigger `OnValidate` de `DUoM Ratio` en `DUoMTrackingSpecExt`
  hace `exit` sin recalcular `DUoM Second Qty`. Esto es correcto por diseño.
- Los valores DUoM Ratio = 1.25 y DUoM Second Qty = 8 (no matemáticamente consistentes)
  se conservan tal cual, verificando que el sistema almacena exactamente lo que el usuario introduce.

### 2. TestPage + ModalPageHandler

Se usa `TestPage "Purchase Order"` + `ModalPageHandler` siguiendo la instrucción de la issue.
La apertura de `Item Tracking Lines` se hace via `PurchaseOrder.PurchLines."Item Tracking Lines".Invoke()`.

El handler usa `HandlerStep` (variable global de codeunit) para distinguir la primera apertura
(asignar) de la segunda apertura (verificar). Este patrón es nuevo en este proyecto.

### 3. No creación manual de Reservation Entries

El test NO crea `Reservation Entry` manualmente. Las entradas son creadas por BC al cerrar
`Item Tracking Lines` (OK pressed). El test solo verifica que las entradas creadas contienen
los campos DUoM correctos.

### 4. Validación en BD y en página

El test valida en dos niveles:
1. **BD real:** `Reservation Entry` tiene `DUoM Ratio = 1.25` y `DUoM Second Qty = 8`.
2. **Página:** al reabrir `Item Tracking Lines`, los campos muestran los mismos valores.

Esto verifica tanto la persistencia (save path) como la recarga (reload path).

### 5. Modelo 1:N respetado

El test asigna 1 lote a 1 línea. La arquitectura es 1:N (N lotes por línea de compra).
No se introduce ninguna relación 1:1 artificial entre línea y lote.

---

## Nombres de página/acción/campo verificados

| Objeto | Nombre en BC 27 |
|--------|----------------|
| TestPage | `"Purchase Order"` |
| Subpágina de líneas | `PurchLines` (control Name en la página 44) |
| Acción de apertura | `"Item Tracking Lines"` |
| ModalPage | `"Item Tracking Lines"` (página 6510) |
| Campo lote | `"Lot No."` |
| Campo cantidad | `"Quantity (Base)"` |
| Campo DUoM Ratio | `"DUoM Ratio"` (extensión 50122) |
| Campo DUoM Second Qty | `"DUoM Second Qty"` (extensión 50122) |

Los nombres `PurchLines` y `"Item Tracking Lines"` siguen las convenciones estándar BC 27.
Verificar contra BC 27 Symbol Reference en caso de cambio de versión.

---

## Documentación actualizada

- `docs/03-technical-architecture.md`: añadida sección "Persistencia DUoM en Item Tracking Lines"
  con los flujos de save/reload, enlace Purchase Line → ReservEntry, y restricciones.
- `docs/06-backlog.md`: issue marcada como completada.
- `.github/copilot-instructions.md`: **no requiere cambio** — la arquitectura documentada
  en esta issue ya estaba parcialmente descrita en la sección de propagation patterns.

---

## Tests relacionados

| Test | Codeunit | Qué cubre |
|------|---------|-----------|
| T-PERSIST-01 | 50219 | Flujo completo Purchase Order → ITL → OK → reabrir → verificar (nuevo) |
| T08 | 50218 | ReservEntry acepta DUoM Ratio desde TrackSpec (contrato de campos) |
| T09 | 50218 | Round-trip ReservEntry → TrackSpec conserva DUoM Ratio |
| T05 | 50218 | Coherencia E2E TrackSpec → ILE con lote (integración) |
| T06 | 50218 | Modelo 1:N: una IJL, dos lotes, cada ILE con su ratio |
