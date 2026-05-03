# fix: persistir y recargar DUoM por lote al reabrir Item Tracking Lines

## Estado

**Estado:** ✅ IMPLEMENTADO — 2026-05-03

---

## Objetivo

Implementar tests de regresión automatizados que cubran el flujo completo de
persistencia y recarga de campos DUoM por lote en Item Tracking Lines:

```
Al cerrar Item Tracking Lines:
  Tracking Specification temporal DUoM
    → Reservation Entry persistente DUoM
    → agregado de Purchase Line

Al abrir de nuevo Item Tracking Lines:
  Reservation Entry persistente DUoM
    → Tracking Specification temporal DUoM
```

---

## Diagnóstico de la implementación existente

Al auditar el repositorio se comprobó que **la implementación bidireccional ya existía** en
codeunit 50110 `DUoM Tracking Copy Subscribers`, implementada en issues anteriores:
- Issue 190: suscriptores para TrackingSpec → ReservEntry (pasos de inserción)
- Issue P3: test T-PERSIST-01 para AlwaysVariable con un lote

Sin embargo:
1. **La documentación `docs/10-persistence-matrix.md` era incorrecta** — §5.1 decía que
   la propagación a Reservation Entry "no está implementada", cuando sí lo estaba.
2. **No existían tests para multi-lote** (ratios distintos por lote).
3. **No existían tests para el modo Variable** (vs AlwaysVariable que ya cubría T-PERSIST-01).
4. **No existían tests para recepción parcial** (Qty. to Receive < Quantity).
5. **No existía test de regresión para duplicados** en Tracking Specification.

---

## Objetos modificados

| Objeto | Tipo | ID | Acción | Archivo |
|--------|------|----|--------|---------|
| `DUoM Purch Tracking Persist` | test codeunit | 50219 | Ampliado | `test/src/codeunit/DUoMPurchTrackingPersistTests.Codeunit.al` |
| `10-persistence-matrix.md` | docs | — | Actualizado | `docs/10-persistence-matrix.md` |

---

## Tests añadidos

### T-REOPEN-01 — `PurchLotTracking_ReopenItemTracking_PreservesDUoMForSingleLot`

**Modo:** Variable
**Escenario:** Un lote `LOT-REOPEN-T1` con 2 KG / 5 PIEZAS.

```
[GIVEN] Artículo DUoM Variable, lot tracking, PO línea 2 unidades
[WHEN] Abrir Item Tracking Lines → asignar LOT-REOPEN-T1, qty=2, DUoM Second Qty=5
       (NormalizeTrackingDUoMSecondQty auto-calcula DUoM Ratio = 2.5)
[THEN] PurchLine.DUoM Second Qty = 5, DUoM Ratio = 2.5
[THEN] ReservEntry para LOT-REOPEN-T1 tiene DUoM Ratio = 2.5, DUoM Second Qty = 5
[WHEN] Reabrir Item Tracking Lines
[THEN] LOT-REOPEN-T1 muestra DUoM Second Qty = 5, DUoM Ratio = 2.5
```

### T-REOPEN-02 — `PurchLotTracking_ReopenItemTracking_PreservesDifferentLotRatios`

**Modo:** Variable
**Escenario:** Dos lotes con ratios distintos (3 y 2).

```
[GIVEN] Artículo DUoM Variable, lot tracking, PO línea 2 unidades
[WHEN] Asignar LOT-MULTI-A (1KG/3PZ/ratio=3) y LOT-MULTI-B (1KG/2PZ/ratio=2)
[THEN] PurchLine.DUoM Second Qty = 5, DUoM Ratio = 2.5 (ponderado)
[THEN] ReservEntry LOT-MULTI-A tiene DUoM Ratio = 3 (no el agregado 2.5)
[THEN] ReservEntry LOT-MULTI-B tiene DUoM Ratio = 2 (no el agregado 2.5)
[WHEN] Reabrir Item Tracking Lines
[THEN] LOT-MULTI-A muestra ratio = 3, LOT-MULTI-B muestra ratio = 2
```

### T-REOPEN-03 — `PurchLotTracking_ReopenItemTracking_DoesNotOverwriteLotDUoMFromPurchaseLineAggregate`

**Modo:** Variable
**Escenario:** Verifica explícitamente que el ratio agregado de PurchLine (2.5) NO se
copia a los lotes individuales al reabrir.

```
[THEN] PurchLine.DUoM Ratio = 2.5 (confirma que el agregado existe)
[THEN] Al reabrir: LOT-MULTI-A tiene ratio ≠ 2.5 (= 3), LOT-MULTI-B tiene ratio ≠ 2.5 (= 2)
```

### T-REOPEN-04 — `PurchLotTracking_PartialReceipt_ReopenItemTracking_PreservesDUoMForQtyToHandle`

**Modo:** Variable
**Escenario:** PO de 10 unidades, Qty. to Receive = 2.

```
[GIVEN] PurchLine.Quantity = 10, PurchLine."Qty. to Receive" = 2
[WHEN] Asignar LOT-PARTIAL-T4 (2KG/5PZ) para las 2 unidades a manipular
[THEN] La validación NO bloquea por los 10 KG completos
[THEN] PurchLine.DUoM Second Qty = 5, DUoM Ratio = 2.5
[WHEN] Reabrir Item Tracking Lines
[THEN] LOT-PARTIAL-T4 muestra DUoM Second Qty = 5, DUoM Ratio = 2.5
```

### T-REOPEN-05 — `PurchLotTracking_ReopenItemTracking_DoesNotCreateDuplicateTrackingSpecification`

**Modo:** Variable
**Escenario:** Verifica que reabrir Item Tracking Lines no causa duplicados.

```
[WHEN] Asignar LOT-REOPEN-T1, cerrar, reabrir
[THEN] La página abre sin error "record already exists"
[THEN] Exactamente 1 línea en Item Tracking Lines (no duplicados)
```

---

## Handler steps añadidos al ModalPageHandler

| Step | Usado por | Descripción |
|------|-----------|-------------|
| 7 | T-REOPEN-01, T-REOPEN-05 | Asigna LOT-REOPEN-T1 (2KG/5PZ, Variable) |
| 8 | T-REOPEN-01 | Verifica LOT-REOPEN-T1 (DUoM Second Qty=5, Ratio=2.5) |
| 9 | T-REOPEN-02, T-REOPEN-03 | Asigna LOT-MULTI-A (1KG/3PZ) y LOT-MULTI-B (1KG/2PZ) |
| 10 | T-REOPEN-02, T-REOPEN-03 | Verifica per-lot ratios (3 y 2, no el agregado 2.5) |
| 11 | T-REOPEN-04 | Asigna LOT-PARTIAL-T4 (2KG/5PZ, recepción parcial) |
| 12 | T-REOPEN-04 | Verifica LOT-PARTIAL-T4 (DUoM Second Qty=5, Ratio=2.5) |
| 13 | T-REOPEN-05 | Verifica exactamente 1 línea, sin duplicados |

---

## Eventos estándar usados (BC 27 / runtime 15)

### Escritura: Tracking Specification → Reservation Entry

**Evento:** `OnAfterCopyTrackingFromTrackingSpec` en `Table "Reservation Entry"` (337)

**Suscriptor:** `ReservEntryOnAfterCopyTrackingFromTrackingSpec` en codeunit 50110

**Firma verificada BC 27:**
```al
[EventSubscriber(ObjectType::Table, Database::"Reservation Entry",
    'OnAfterCopyTrackingFromTrackingSpec', '', false, false)]
local procedure ReservEntryOnAfterCopyTrackingFromTrackingSpec(
    var ReservationEntry: Record "Reservation Entry";
    TrackingSpecification: Record "Tracking Specification")
```

**Por qué este evento:** Se dispara cuando `Reservation Entry.CopyTrackingFromSpec()` es
llamado, que ocurre al cerrar Item Tracking Lines y aceptar con OK.

### Cadena de inserción: Reservation Entry → Reservation Entry

**Evento:** `OnAfterCopyTrackingFromReservEntry` en `Table "Reservation Entry"` (337)

**Suscriptor:** `ReservEntryOnAfterCopyTrackingFromReservEntry` en codeunit 50110

**Por qué este evento:** BC usa `CreateReservEntry` internamente que llama a
`InsertReservEntry.CopyTrackingFromReservEntry(ForReservEntry)`. Sin este suscriptor, el
registro final en BD tendría DUoM Ratio = 0.

### Recarga: Reservation Entry → Tracking Specification

**Evento:** `OnAfterCopyTrackingFromReservEntry` en `Table "Tracking Specification"` (6500)

**Suscriptor:** `TrackingSpecCopyTrackingFromReservEntry` en codeunit 50110

**Por qué este evento:** Se dispara cuando BC reconstruye el buffer de `Tracking Specification`
desde `Reservation Entry` al abrir Item Tracking Lines. Este es el mecanismo que garantiza
que los valores DUoM se recuperen por lote y no desde el agregado de `Purchase Line`.

---

## Documentación actualizada

- `docs/10-persistence-matrix.md`:
  - §1.2: Reservation Entry: "⚠️ NO propagados" → "✅ Persistidos y propagados"
  - §2.4: Reescrito para reflejar el flujo bidireccional completo
  - §4: Tabla de propagación: pasos 9a/9b/9c con distinción entre los tres eventos
  - §5.1: "Limitación conocida" → "Implementado" con descripción del mecanismo
  - §5.2: Actualizado para reflejar que TrackingSpec persiste vía ReservEntry

---

## Notas de implementación

- No se crearon ni modificaron objetos AL de producción — todos los suscriptores
  necesarios ya estaban implementados en codeunit 50110.
- Los tests añadidos son tests de **regresión** que documentan el comportamiento esperado
  y protegen contra regresiones futuras.
- El handler step 10 usa verificación order-independent: si el primer lote es LOT-MULTI-A,
  verifica ratio=3; si es LOT-MULTI-B, verifica ratio=2. Esto protege contra variaciones
  en el orden de las líneas en el buffer de Tracking Specification.
