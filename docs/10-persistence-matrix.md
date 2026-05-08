# Matriz de Persistencia DUoM — Fuente de Verdad

> **Propósito:** Este documento centraliza en un único punto toda la información sobre dónde
> y cómo persiste cada dato DUoM: por tabla, por flujo (compra / venta / diario / tracking)
> y por caso de uso (operación / reporting / auditoría). Permite a QA y soporte trazar
> cualquier discrepancia de datos sin ambigüedad.

---

## 1. Campos DUoM por tabla

### 1.1 Tablas propias de la extensión

| Tabla | ID | Campos DUoM | Propósito |
|-------|----|-------------|-----------|
| `DUoM Item Setup` | 50100 | `Dual UoM Enabled`, `Second UoM Code`, `Conversion Mode`, `Fixed Ratio` | Configuración maestra por artículo (interruptor principal + parámetros por defecto) |
| `DUoM Item Variant Setup` | 50101 | `Second UoM Code`, `Conversion Mode`, `Fixed Ratio` | Override opcional por variante; hereda del artículo si el campo está en blanco/cero |
| `DUoM Lot Ratio` | 50102 | `Item No.`, `Lot No.`, `Actual Ratio` | Ratio real medido por lote; fuente de configuración para el flujo de Item Tracking |

### 1.2 Extensiones sobre tablas estándar BC

| Tabla BC (ID) | Ext. ID | Campos DUoM | Mutabilidad | Propósito |
|---------------|---------|-------------|-------------|-----------|
| `Purchase Line` (39) | 50110 | `DUoM Second Qty`, `DUoM Ratio`, `DUoM Unit Cost` | Mutable — documento abierto | Datos DUoM de la línea de pedido de compra en curso |
| `Sales Line` (37) | 50111 | `DUoM Second Qty`, `DUoM Ratio`, `DUoM Unit Price` | Mutable — documento abierto | Datos DUoM de la línea de pedido de venta en curso |
| `Item Journal Line` (83) | 50112 | `DUoM Second Qty`, `DUoM Ratio` | Mutable — antes de contabilizar | Buffer intermedio de posting; refleja los valores de la línea origen |
| `Item Ledger Entry` (32) | 50113 | `DUoM Second Qty`, `DUoM Ratio` | **Inmutable** — contabilizado | Registro definitivo de inventario DUoM por movimiento |
| `Purch. Rcpt. Line` (121) | 50114 | `DUoM Second Qty`, `DUoM Ratio`, `DUoM Unit Cost` | **Inmutable** — contabilizado | Histórico de recepción de compra |
| `Sales Shipment Line` (111) | 50115 | `DUoM Second Qty`, `DUoM Ratio`, `DUoM Unit Price` | **Inmutable** — contabilizado | Histórico de envío de venta |
| `Purch. Inv. Line` (123) | 50116 | `DUoM Second Qty`, `DUoM Ratio`, `DUoM Unit Cost` | **Inmutable** — contabilizado | Histórico de factura de compra |
| `Purch. Cr. Memo Line` (125) | 50117 | `DUoM Second Qty`, `DUoM Ratio`, `DUoM Unit Cost` | **Inmutable** — contabilizado | Histórico de abono de compra |
| `Sales Invoice Line` (113) | 50118 | `DUoM Second Qty`, `DUoM Ratio`, `DUoM Unit Price` | **Inmutable** — contabilizado | Histórico de factura de venta |
| `Sales Cr.Memo Line` (115) | 50119 | `DUoM Second Qty`, `DUoM Ratio`, `DUoM Unit Price` | **Inmutable** — contabilizado | Histórico de abono de venta |
| `Value Entry` (5802) | 50121 | `DUoM Second Qty` | **Inmutable** — contabilizado | Trazabilidad contable de la cantidad secundaria por asiento de valoración |
| `Tracking Specification` (6500) | 50122 | `DUoM Second Qty`, `DUoM Ratio` | **Transient** — buffer de sesión | Buffer de Item Tracking Lines; datos temporales durante edición activa |
| `Reservation Entry` (337) | 50123 | `DUoM Second Qty`, `DUoM Ratio` | ✅ Persistidos y propagados (ver §2.4) | Persistencia DUoM por lote; fuente de verdad del detalle por lote al reabrir Item Tracking Lines |

---

## 2. Flujos de propagación: origen → destino

### 2.1 Flujo Compra (Purchase Order)

```
[1] Usuario introduce Purchase Line
    ├── Validate Quantity  → DUoM Calc Engine recalcula DUoM Second Qty (modos Fixed/Variable)
    │                         Suscriptor: DUoM Purchase Subscribers (50102)
    └── Validate Variant Code → reset + recálculo via DUoM Setup Resolver (50107)

[2] Contabilizar pedido de compra (Post)
    │
    ├── Purchase Line ──[OnAfterInitFromPurchLine]──► Purch. Rcpt. Line
    │                    Suscriptor: DUoM Inventory Subscribers (50104)
    │                    Helper: DUoM Doc Transfer Helper (50105)
    │                    Campos copiados: DUoM Second Qty, DUoM Ratio, DUoM Unit Cost
    │
    ├── Purchase Line ──[OnAfterInitFromPurchLine]──► Purch. Inv. Line
    │                    (mismos suscriptor y helper)
    │
    ├── Purchase Line ──[OnPostItemJnlLineOnAfterCopyDocumentFields]──► Item Journal Line
    │                    Suscriptor: DUoM Inventory Subscribers (50104)
    │                    Campos copiados: DUoM Second Qty, DUoM Ratio
    │
    └── Item Journal Line ──► Item Ledger Entry  (ver §2.3)
                          └──► Value Entry       (ver §2.3)

[3] Contabilizar abono de compra (Post Credit Memo)
    └── Purchase Line ──[OnAfterInitFromPurchLine]──► Purch. Cr. Memo Line
                         Suscriptor: DUoM Inventory Subscribers (50104)
                         Helper: DUoM Doc Transfer Helper (50105)
```

**Tests de cobertura:** `DUoMPurchaseTests` (50203), `DUoMILEIntegrationTests` (50209),
`DUoMCostPriceTests` (50205), `DUoMInvCrMemoPostTests` (50215).

---

### 2.2 Flujo Venta (Sales Order)

```
[1] Usuario introduce Sales Line
    ├── Validate Quantity  → DUoM Calc Engine recalcula DUoM Second Qty (modos Fixed/Variable)
    │                         Suscriptor: DUoM Sales Subscribers (50103)
    └── Validate Variant Code → reset + recálculo via DUoM Setup Resolver (50107)

[2] Contabilizar pedido de venta (Post)
    │
    ├── Sales Line ──[OnAfterInitFromSalesLine]──► Sales Shipment Line
    │                Suscriptor: DUoM Inventory Subscribers (50104)
    │                Helper: DUoM Doc Transfer Helper (50105)
    │                Campos copiados: DUoM Second Qty, DUoM Ratio, DUoM Unit Price
    │
    ├── Sales Line ──[OnAfterInitFromSalesLine]──► Sales Invoice Line
    │                (mismos suscriptor y helper)
    │
    ├── Sales Line ──[OnPostItemJnlLineOnAfterCopyDocumentFields]──► Item Journal Line
    │                Suscriptor: DUoM Inventory Subscribers (50104)
    │                Campos copiados: DUoM Second Qty, DUoM Ratio
    │
    └── Item Journal Line ──► Item Ledger Entry  (ver §2.3)
                          └──► Value Entry       (ver §2.3)

[3] Contabilizar abono de venta (Post Credit Memo)
    └── Sales Line ──[OnAfterInitFromSalesLine]──► Sales Cr.Memo Line
                     Suscriptor: DUoM Inventory Subscribers (50104)
                     Helper: DUoM Doc Transfer Helper (50105)
```

**Tests de cobertura:** `DUoMSalesTests` (50206), `DUoMILEIntegrationTests` (50209),
`DUoMCostPriceTests` (50205), `DUoMInvCrMemoPostTests` (50215).

---

### 2.3 Flujo Item Journal Line → ILE / Value Entry

Esta sección detalla la propagación final al `Item Ledger Entry` y al `Value Entry` desde
el `Item Journal Line`. Se aplica tanto en el flujo de compra/venta (donde el IJL es
construido por BC desde la línea de documento) como en el flujo directo de diario.

#### 2.3.1 SIN Item Tracking (artículos sin lote / sin trazabilidad activa)

```
Item Journal Line
  ──[OnAfterInitItemLedgEntry]──► Item Ledger Entry
     Suscriptor: DUoM Inventory Subscribers (50104)
     Lógica de prioridad:
       1. AlwaysVariable + Lot No. + DUoM Ratio = 0 → ILE.DUoM Second Qty = 0 (T10)
       2. DUoM Lot Ratio (50102) existe para el lote → AppliedRatio = ratio del lote
       3. Sin ratio de lote → AppliedRatio = IJL.DUoM Ratio
       ILE.DUoM Second Qty = Abs(ILE.Quantity) × AppliedRatio
       Caso especial (ratio = 0, sin lote): ILE.DUoM Second Qty = IJL.DUoM Second Qty

Item Journal Line
  ──[OnAfterInitValueEntry]──► Value Entry
     Suscriptor: DUoM Inventory Subscribers (50104)
     Lógica: ValueEntry.DUoM Second Qty = Abs(IJL.DUoM Second Qty)
             (negativo para salidas: signo del ILE.Quantity)
```

#### 2.3.2 CON Item Tracking (artículos con lote — patrón Package Management 6516)

```
Reservation Entry (con DUoM Ratio pre-registrado)
  ──[OnAfterCopyTrackingFromReservEntry]──► Tracking Specification (buffer)
     Suscriptor: DUoM Tracking Copy Subscribers (50110)
     Campos copiados: DUoM Ratio, DUoM Second Qty

Tracking Specification (buffer, por lote)
  ──[OnAfterCopyTrackingFromSpec]──► Item Journal Line (split por lote)
     Suscriptor: DUoM Tracking Copy Subscribers (50110)
     Guard: si TrackingSpec.DUoM Ratio = 0, no sobrescribe el ratio existente en IJL

Item Journal Line (split por lote)
  ──[OnAfterCopyTrackingFromItemJnlLine]──► Item Ledger Entry
     Suscriptor: DUoM Tracking Copy Subscribers (50110)
     Lógica de prioridad:
       1. DUoM Lot Ratio (50102) > IJL.DUoM Ratio
       2. ILE.DUoM Second Qty = Abs(ILE.Quantity) × AppliedRatio
       3. AlwaysVariable + Lot No. sin ratio → ILE.DUoM Second Qty = 0 (T10)
```

**Orden de ejecución en BC 27:** `OnAfterInitItemLedgEntry` se dispara **antes** de
`OnAfterCopyTrackingFromItemJnlLine`. Cuando hay Item Tracking, el segundo subscriber
consolida el valor final en el ILE, sobrescribiendo el valor provisional del primero.

#### 2.3.3 Flujo inverso — devoluciones

```
Item Ledger Entry (entrada de origen)
  ──[OnAfterCopyTrackingFromItemLedgEntry]──► Item Journal Line
     Suscriptor: DUoM Tracking Copy Subscribers (50110)
     Lógica: IJL.DUoM Ratio = ILE.DUoM Ratio
             IJL.DUoM Second Qty = ILE.DUoM Second Qty
```

**Tests de cobertura:** `DUoMLotRatioTests` (50217), `DUoMItemTrackingTests` (50216),
`DUoMVarModePostTests` (50218), `DUoMILEIntegrationTests` (50209).

---

### 2.4 Flujo Item Tracking Lines (UI)

```
[1] Usuario abre Item Tracking Lines — recarga desde Reservation Entry

    BC reconstruye el buffer Tracking Specification desde Reservation Entry:
      Reservation Entry
        ──[OnAfterCopyTrackingFromReservEntry]──► Tracking Specification (buffer)
           Suscriptor: DUoM Tracking Copy Subscribers (50110)
           Campos copiados: DUoM Ratio, DUoM Second Qty
           Guard: si ReservEntry.DUoM Ratio = 0 → TrackingSpec.DUoM Ratio queda 0

    Validate Lot No. en Tracking Specification
      ──[OnAfterValidateEvent 'Lot No.']──► ApplyLotRatioToTrackingSpec
         Suscriptor: DUoM Tracking Subscribers (50109)
         Modo Fixed:            DUoM Ratio = Fixed Ratio del artículo/variante
         Modo Variable/AlwaysVariable:
           Si existe DUoM Lot Ratio (50102) para el lote:
             DUoM Ratio = DUoM Lot Ratio."Actual Ratio"
             DUoM Second Qty = Round(Abs(Qty) × ratio, RoundingPrecision)
           Si NO existe y DUoM Ratio = 0:
             TryApplyPurchLineFallback (usa ratio de PurchLine como inicial)
           Si NO existe y DUoM Ratio ≠ 0:
             Ningún cambio (el valor ya cargado de ReservEntry se mantiene)

    Validate Quantity (Base) en Tracking Specification
      ──[OnAfterValidateEvent 'Quantity (Base)']──► RecalcTrackingSpecSecondQty
         Suscriptor: DUoM Tracking Subscribers (50109)
         Guard: DUoM Ratio = 0 → salida anticipada
         DUoM Second Qty = Round(Abs(Qty) × DUoM Ratio, RoundingPrecision)

    Validate DUoM Second Qty en Tracking Specification (UI del usuario)
      ──[OnValidate en DUoM Tracking Spec Ext (50122)]──► recálculo de DUoM Ratio
         Solo modos Variable/AlwaysVariable (Fixed: salida anticipada)
         NormalizeTrackingDUoMSecondQty: DUoM Ratio = DUoM Second Qty / Qty (Base)

    Validate DUoM Ratio en Tracking Specification
      ──[OnValidate en DUoM Tracking Spec Ext (50122)]──► recálculo inmediato
         Solo modos Fixed/Variable (AlwaysVariable: salida anticipada)

[2] Al confirmar Item Tracking Lines (OK), BC persiste en Reservation Entry

    Tracking Specification (buffer, por lote)
      ──[OnAfterCopyTrackingFromTrackingSpec]──► ReservEntry1 (copia temporal)
         Suscriptor: DUoM Tracking Copy Subscribers (50110)
         Campos copiados: DUoM Ratio, DUoM Second Qty

    ReservEntry1 (con DUoM Ratio correcto)
      ──[OnAfterCopyTrackingFromReservEntry]──► InsertReservEntry (final)
         Suscriptor: DUoM Tracking Copy Subscribers (50110)
         Necesario porque BC usa un segundo CopyTracking interno en CreateReservEntry

    InsertReservEntry se escribe en BD con DUoM Ratio y DUoM Second Qty correctos ✓

[3] SyncPurchLineFromTrackingBuffer (en OnQueryClosePage del pageextension 50112)

    Tracking Specification buffer → Purchase Line (agregado)
      Suscriptor/helper: DUoM Tracking Coherence Mgt (50111)
      Purchase Line.DUoM Second Qty = SUM(TrackingSpec.DUoM Second Qty)
      Purchase Line.DUoM Ratio = Total Second Qty / Total Qty (Base) [ratio ponderado]

    Regla de fuente de verdad:
      Reservation Entry (por lote) = DETALLE DUoM
      Purchase Line = AGREGADO DUoM (resumen de todos los lotes)
      No copiar ratio de Purchase Line a tracking individual si ya existe DUoM en ReservEntry
```

**Tests de cobertura:** `DUoMPurchTrackingPersistTests` (50219) — T-PERSIST-01 a T-PERSIST-05,
T-REOPEN-01 a T-REOPEN-05.

---

## 3. Fuente de verdad por caso de uso

### 3.1 Operación — documento en curso

| Escenario | Fuente de verdad | Tabla |
|-----------|-----------------|-------|
| Segunda cantidad en pedido de compra activo | `Purchase Line."DUoM Second Qty"` | 39 (ext. 50110) |
| Ratio en pedido de compra activo | `Purchase Line."DUoM Ratio"` | 39 (ext. 50110) |
| Coste unitario DUoM en compra activa | `Purchase Line."DUoM Unit Cost"` | 39 (ext. 50110) |
| Segunda cantidad en pedido de venta activo | `Sales Line."DUoM Second Qty"` | 37 (ext. 50111) |
| Ratio en pedido de venta activo | `Sales Line."DUoM Ratio"` | 37 (ext. 50111) |
| Precio unitario DUoM en venta activa | `Sales Line."DUoM Unit Price"` | 37 (ext. 50111) |
| Segunda cantidad al introducir lote en tracking | `Tracking Specification."DUoM Second Qty"` | 6500 (ext. 50122) |
| Ratio al introducir lote en tracking | `Tracking Specification."DUoM Ratio"` | 6500 (ext. 50122) |

### 3.2 Reporting e históricos — documentos registrados

| Escenario | Fuente de verdad | Tabla |
|-----------|-----------------|-------|
| Cantidad secundaria recibida en compra | `Purch. Rcpt. Line."DUoM Second Qty"` | 121 (ext. 50114) |
| Coste unitario DUoM en recepción registrada | `Purch. Rcpt. Line."DUoM Unit Cost"` | 121 (ext. 50114) |
| Cantidad secundaria en envío de venta registrado | `Sales Shipment Line."DUoM Second Qty"` | 111 (ext. 50115) |
| Precio unitario DUoM en envío registrado | `Sales Shipment Line."DUoM Unit Price"` | 111 (ext. 50115) |
| Cantidad secundaria en factura de compra registrada | `Purch. Inv. Line."DUoM Second Qty"` | 123 (ext. 50116) |
| Cantidad secundaria en factura de venta registrada | `Sales Invoice Line."DUoM Second Qty"` | 113 (ext. 50118) |
| Cantidad secundaria en abono de compra registrado | `Purch. Cr. Memo Line."DUoM Second Qty"` | 125 (ext. 50117) |
| Cantidad secundaria en abono de venta registrado | `Sales Cr.Memo Line."DUoM Second Qty"` | 115 (ext. 50119) |

> **Nota de consistencia:** los valores en los documentos registrados son copia directa de
> la línea origen al momento de la contabilización. No se recalculan. Si el usuario modificó
> `DUoM Second Qty` manualmente antes de contabilizar, el histórico refleja ese valor.

### 3.3 Inventario — movimientos de producto

| Escenario | Fuente de verdad | Tabla |
|-----------|-----------------|-------|
| Segunda cantidad real contabilizada por movimiento | `Item Ledger Entry."DUoM Second Qty"` | 32 (ext. 50113) |
| Ratio DUoM real por movimiento | `Item Ledger Entry."DUoM Ratio"` | 32 (ext. 50113) |
| Segunda cantidad en movimiento con lote específico | `Item Ledger Entry."DUoM Second Qty"` filtrado por `Lot No.` | 32 (ext. 50113) |
| Suma de segunda cantidad en stock | `SUM(ILE."DUoM Second Qty")` donde `ILE."Remaining Quantity" > 0` | 32 (ext. 50113) |

> **Regla de diseño:** `ILE."DUoM Second Qty" = Abs(ILE.Quantity) × ILE."DUoM Ratio"`.
> En multi-lote, **no usar** `Purchase Line."DUoM Second Qty"` como total acumulado del ILE;
> sumar los ILEs individuales. Ver modelo 1:N en `docs/03-technical-architecture.md`.

### 3.4 Auditoría y trazabilidad contable

| Escenario | Fuente de verdad | Tabla |
|-----------|-----------------|-------|
| Cantidad secundaria por asiento contable | `Value Entry."DUoM Second Qty"` | 5802 (ext. 50121) |
| Ratio DUoM real por lote (referencia) | `DUoM Lot Ratio."Actual Ratio"` | 50102 |
| Ratio DUoM configurado por artículo | `DUoM Item Setup."Fixed Ratio"` (modo Fixed/Variable) | 50100 |
| Ratio DUoM configurado por variante | `DUoM Item Variant Setup."Fixed Ratio"` (override) | 50101 |

### 3.5 Prioridad global de fuentes de ratio al contabilizar

```
DUoM Lot Ratio (50102) — ratio real medido por lote
   > IJL.DUoM Ratio (campo directo) — ratio del lote desde TrackingSpec o del artículo
   > sin ratio (= 0)
```

Esta prioridad se aplica en:
- `OnAfterInitItemLedgEntry` (codeunit 50104) — flujo SIN Item Tracking
- `ILECopyTrackingFromItemJnlLine` (codeunit 50110) — flujo CON Item Tracking

---

## 4. Propagación entre suscriptores: resumen técnico

| Paso | Origen | Destino | Evento | Codeunit | Campos |
|------|--------|---------|--------|----------|--------|
| 1 | `Purchase Line` | `Purch. Rcpt. Line` | `OnAfterInitFromPurchLine` (Table 121) | 50104 | Second Qty, Ratio, Unit Cost |
| 2 | `Purchase Line` | `Purch. Inv. Line` | `OnAfterInitFromPurchLine` (Table 123) | 50104 | Second Qty, Ratio, Unit Cost |
| 3 | `Purchase Line` | `Purch. Cr. Memo Line` | `OnAfterInitFromPurchLine` (Table 125) | 50104 | Second Qty, Ratio, Unit Cost |
| 4 | `Sales Line` | `Sales Shipment Line` | `OnAfterInitFromSalesLine` (Table 111) | 50104 | Second Qty, Ratio, Unit Price |
| 5 | `Sales Line` | `Sales Invoice Line` | `OnAfterInitFromSalesLine` (Table 113) | 50104 | Second Qty, Ratio, Unit Price |
| 6 | `Sales Line` | `Sales Cr.Memo Line` | `OnAfterInitFromSalesLine` (Table 115) | 50104 | Second Qty, Ratio, Unit Price |
| 7 | `Purchase Line` | `Item Journal Line` | `OnPostItemJnlLineOnAfterCopyDocumentFields` (Cunit Purch.-Post) | 50104 | Second Qty, Ratio |
| 8 | `Sales Line` | `Item Journal Line` | `OnPostItemJnlLineOnAfterCopyDocumentFields` (Cunit Sales-Post) | 50104 | Second Qty, Ratio |
| 9a | `Tracking Specification` | `Reservation Entry` | `OnAfterCopyTrackingFromTrackingSpec` (Table 337) | 50110 | Ratio, Second Qty |
| 9b | `Reservation Entry` (origen) | `Reservation Entry` (destino) | `OnAfterCopyTrackingFromReservEntry` (Table 337) | 50110 | Ratio, Second Qty |
| 9c | `Reservation Entry` | `Tracking Specification` | `OnAfterCopyTrackingFromReservEntry` (Table 6500) | 50110 | Ratio, Second Qty |
| 10 | `Tracking Specification` | `Item Journal Line` | `OnAfterCopyTrackingFromSpec` (Table 83) | 50110 | Ratio, Second Qty |
| 11 | `Item Journal Line` | `Item Ledger Entry` | `OnAfterCopyTrackingFromItemJnlLine` (Table 32) | 50110 | Ratio, Second Qty |
| 12 | `Item Journal Line` | `Item Ledger Entry` | `OnAfterInitItemLedgEntry` (Cunit Item Jnl.-Post Line) | 50104 | Ratio, Second Qty |
| 13 | `Item Journal Line` | `Value Entry` | `OnAfterInitValueEntry` (Cunit Item Jnl.-Post Line) | 50104 | Second Qty |
| 14 | `Item Ledger Entry` | `Item Journal Line` | `OnAfterCopyTrackingFromItemLedgEntry` (Table 83) | 50110 | Ratio, Second Qty |

> **Pasos 9a/9b/9c:** El paso 9a escribe DUoM desde el buffer de TrackingSpec en ReservEntry
> cuando el usuario confirma Item Tracking Lines. El paso 9b propaga entre los dos niveles
> de ReservEntry que BC usa internamente al insertar (ReservEntry1 → InsertReservEntry).
> El paso 9c recarga los valores DUoM desde ReservEntry al buffer de TrackingSpec al reabrir
> Item Tracking Lines o durante el posting.

> **Pasos 11 y 12 coexisten.** El paso 12 (`OnAfterInitItemLedgEntry`) se ejecuta primero
> y establece un valor provisional. El paso 11 (`ILECopyTrackingFromItemJnlLine`) se ejecuta
> después cuando hay Item Tracking activo y consolida el valor final con ratio de lote.

---

## 5. Comportamiento DUoM en Item Tracking por lote

### 5.1 Reservation Entry — propagación DUoM implementada

**Estado:** ✅ Implementado — codeunit 50110 `DUoM Tracking Copy Subscribers` (persistencia/rehidratación estándar)
                              + validaciones/sync documental en codeunit 50111 `DUoM Tracking Coherence Mgt`.

**Descripción:** Los campos `DUoM Second Qty` y `DUoM Ratio` en `Reservation Entry` (337)
se propagan automáticamente mediante cuatro mecanismos:

1. **TrackingSpec → ReservEntry** (`OnAfterCopyTrackingFromTrackingSpec` en Table 337) [50110]:
   Al cerrar Item Tracking Lines con OK por primera vez, copia DUoM Ratio y DUoM Second Qty
   desde el buffer de `Tracking Specification` hacia la primera `Reservation Entry`.

2. **ReservEntry → ReservEntry** (`OnAfterCopyTrackingFromReservEntry` en Table 337) [50110]:
   BC usa un segundo nivel de copia interna al insertar (`CreateReservEntry`). Este suscriptor
   propaga los valores DUoM al registro final que se escribe en la base de datos.

3. **Cierre estándar sin persistencia manual en OnQueryClosePage**:
   En segunda edición o ediciones sucesivas, la extensión no ejecuta `Modify(false)` manual
   sobre `Reservation Entry` desde `OnQueryClosePage` para evitar conflictos de concurrencia.
   La persistencia DUoM se mantiene por eventos estándar de tracking.

4. **ReservEntry → TrackingSpec (recarga)** (`OnAfterCopyTrackingFromReservEntry` en Table 6500) [50110]:
   Al reabrir Item Tracking Lines, BC reconstruye el buffer `Tracking Specification` desde
   `Reservation Entry`. Este suscriptor recarga DUoM Ratio y DUoM Second Qty por lote desde
   `Reservation Entry`, garantizando que los valores introducidos manualmente se preserven
   sin recalcular desde `Purchase Line` ni desde `DUoM Lot Ratio`.

**Regla de fuente de verdad por lote:**
```
Si Reservation Entry tiene DUoM Ratio ≠ 0:
    Tracking Specification carga DUoM desde Reservation Entry (detalle por lote)
Si Reservation Entry tiene DUoM Ratio = 0:
    Si existe DUoM Lot Ratio (50102): aplica ratio registrado
    Si no existe: TryApplyPurchLineFallback (valor inicial desde Purchase Line)
```

**Tests de cobertura:** `DUoMPurchTrackingPersistTests` (50219) — T-PERSIST-01 a T-PERSIST-05,
T-REOPEN-01 a T-REOPEN-08 (T-REOPEN-07/08 cubren específicamente el Modify path).

**Referencias:**
- `app/src/codeunit/DUoMTrackingCopySubscribers.Codeunit.al` — suscriptores completos con
  firmas verificadas BC 27 / runtime 15
- `app/src/codeunit/DUoMTrackingCoherenceMgt.Codeunit.al` — validaciones/sync de cierre
- `docs/issues/issue-190-fix-duom-ratio-reserventry-copy-tracking.md` — decisión inicial
- `docs/issues/issue-P3-purch-tracking-persist-regression.md` — implementación T-PERSIST-01

---

### 5.2 Tracking Specification — datos transitorios (buffer de sesión)

**Tabla afectada:** `Tracking Specification` (6500), tableextension 50122.

**Descripción:** `Tracking Specification` es un buffer de sesión en BC. Los datos DUoM
(`DUoM Second Qty`, `DUoM Ratio`) que se cargan al abrir Item Tracking Lines provienen
de `Reservation Entry` (paso 9c en §4). Se trabaja con ellos durante la edición activa
y se persisten de vuelta en `Reservation Entry` al confirmar con OK (pasos 9a y 9b en §4).

**Flujo completo:**
```
Abrir Item Tracking Lines:
  Reservation Entry → Tracking Specification (recarga DUoM por lote)

Editar en Item Tracking Lines:
  Tracking Specification buffer (per-lot DUoM)

Cerrar con OK (primera edición — Insert path):
  Tracking Specification → Reservation Entry (persiste DUoM por lote)
    vía OnAfterCopyTrackingFromTrackingSpec + OnAfterCopyTrackingFromReservEntry (50110)

Cerrar con OK (segunda edición o sucesivas):
  Validación/sync agregado en OnQueryClosePage (50112/50125)
  Persistencia DUoM por eventos estándar de tracking
  Reservation Entry → Purchase Line (agrega: SUM de lotes → ratio ponderado)
```

**Implicación:** `Purchase Line."DUoM Ratio"` es el **ratio ponderado agregado** de todos
los lotes. No debe usarse para reconstruir el detalle por lote al reabrir Item Tracking Lines.
La fuente de verdad por lote es siempre `Reservation Entry`.

---

### 5.3 AlwaysVariable + lote sin ratio registrado → ILE = 0

**Descripción:** En modo `AlwaysVariable`, cuando se contabiliza un lote para el que
no existe entrada en `DUoM Lot Ratio` (50102) ni ratio manual en la IJL,
`ILE."DUoM Second Qty"` se establece a 0 intencionalmente (ver T10).

**Justificación:** En `AlwaysVariable`, el ratio es variable por naturaleza. Sin un ratio
conocido para el lote específico, distribuir el total de la línea entre ILEs individuales
generaría datos incorrectos. Se prefiere 0 explícito para visibilidad.

**Workaround:** registrar el ratio en `DUoM Lot Ratio` antes de contabilizar, o introducirlo
manualmente en la línea de Item Tracking (`DUoM Ratio` editable en Item Tracking Lines).

**Tests:** `DUoMLotRatioTests` — T10.

---

## 6. Cobertura de tests por área

| Área | Codeunit de test | ID | Tests clave |
|------|------------------|----|-------------|
| Motor de cálculo DUoM | `DUoMCalcEngineTests` | 50204 | Modos Fixed, Variable, AlwaysVariable, valores límite |
| Flujo Purchase + ILE | `DUoMPurchaseTests` | 50203 | Propagación a Purch. Rcpt. Line, validación Quantity/Ratio |
| Flujo Sales + ILE | `DUoMSalesTests` | 50206 | Propagación a Sales Shipment Line, validación Quantity/Ratio |
| Integración ILE | `DUoMILEIntegrationTests` | 50209 | ILE.DUoM Second Qty, ILE.DUoM Ratio por flujo |
| Posting Variable/AlwaysVariable | `DUoMVarModePostTests` | 50218 | T04–T14 (ratio lote, multi-lote, AlwaysVariable) |
| Ratio por lote | `DUoMLotRatioTests` | 50217 | DUoM Lot Ratio CRUD, aplicación en IJL y ILE |
| Item Tracking Lines | `DUoMItemTrackingTests` | 50216 | Pre-relleno en TrackingSpec, propagación al ILE con tracking |
| Coste/Precio DUoM | `DUoMCostPriceTests` | 50205 | DUoM Unit Cost, DUoM Unit Price, derivación |
| Facturas/Abonos | `DUoMInvCrMemoPostTests` | 50215 | Propagación a Purch. Inv. Line, Sales Cr.Memo Line, etc. |
| Variantes | `DUoMVariantTests` | 50213 | Override de variante, jerarquía Item→Variant |
| Redondeo UdM | `DUoMItemUoMRoundTests` | 50210 | Qty. Rounding Precision en segunda UdM |

---

## 7. Diagrama resumen de persistencia

```
                    ┌──────────────────────────────────────────────────┐
                    │           CONFIGURACIÓN (setup maestro)           │
                    │  DUoM Item Setup (50100)                          │
                    │  DUoM Item Variant Setup (50101)                  │
                    │  DUoM Lot Ratio (50102) ◄─── fuente de ratio lote │
                    └──────────────────────────────────────────────────┘
                                         │
              ┌──────────────────────────┼──────────────────────────┐
              │ FLUJO COMPRA             │                           │ FLUJO VENTA
              ▼                         │                           ▼
    Purchase Line (39)                  │               Sales Line (37)
    [DUoM Qty, Ratio, Cost]             │               [DUoM Qty, Ratio, Price]
         │                              │                       │
    ┌────┴────┐                         │                  ┌────┴────┐
    │ Post    │                         │                  │ Post    │
    └────┬────┘                         │                  └────┬────┘
         │                              │                       │
    ┌────▼───────────────────┐          │          ┌────────────▼────┐
    │ Purch. Rcpt. Line      │          │          │ Sales Shpt. Line │
    │ Purch. Inv. Line       │          │          │ Sales Inv. Line  │
    │ Purch. Cr. Memo Line   │          │          │ Sales CrMemo Line│
    │ [Qty, Ratio, Cost]     │          │          │ [Qty, Ratio, Price]│
    └────────────────────────┘          │          └─────────────────┘
                              ┌─────────▼──────────┐
                              │ Item Journal Line   │
                              │ [DUoM Qty, Ratio]   │
                              │ (buffer de posting) │
                              └─────────┬──────────┘
                                        │
                    ┌───────────────────┼──────────────────┐
                    │                   │                   │
                    ▼                   ▼                   ▼
        Item Ledger Entry        Value Entry        (Reservation Entry)
        [DUoM Qty, Ratio]       [DUoM Qty]          ⚠️ campos definidos
        INMUTABLE               INMUTABLE               NO propagados
        (fuente de verdad       (fuente de verdad       (limitación BC 27)
         inventario)             auditoría)

                    ▲
                    │  CON Item Tracking
         Tracking Specification (buffer transient)
         [DUoM Qty, Ratio] ──► solo durante la sesión de edición
```

---

## 8. Referencias

| Documento | Contenido relacionado |
|-----------|----------------------|
| `docs/02-functional-design.md` | Modos de conversión, política AlwaysVariable + lotes |
| `docs/03-technical-architecture.md` | Diseño técnico, codeunits, patrón OnAfterCopyTracking* |
| `docs/04-item-setup-model.md` | Modelo de configuración DUoM Item Setup |
| `docs/issues/issue-22-item-tracking-lines-duom.md` | Item Tracking Lines DUoM — decisiones y limitación Reservation Entry |
| `docs/issues/issue-23-tracking-copy-subscribers.md` | Patrón OnAfterCopyTracking* para propagación al ILE |
| `docs/issues/issue-24-fix-ile-regression-tracking-refactor.md` | Fix regresiones ILE tras refactor |
