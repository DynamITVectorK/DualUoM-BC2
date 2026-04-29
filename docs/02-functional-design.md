# Functional Design — DualUoM-BC

## Item DUoM Setup

Each item that participates in dual UoM requires the following configuration:

| Field | Description |
|---|---|
| `Dual UoM Enabled` | Boolean — master switch; activates DUoM for this item |
| `Second UoM Code` | The second unit of measure code (e.g. PCS while base is KG) |
| `Conversion Mode` | Fixed / Variable / Always-Variable (see below) |
| `Fixed Ratio` | Used only when Conversion Mode = Fixed or Variable (default ratio) |

This setup is stored in the dedicated table `DUoM Item Setup` (50100) linked by item
number (Option B design). The base `Item` table is not extended with DUoM configuration
fields; a cascade-delete trigger on `Item` (tableextension 50100) removes the DUoM
setup when an item is deleted. See `docs/04-item-setup-model.md` for the full design rationale.

---

## Item Variant Setup — Override por Variante

Cuando un artículo tiene variantes y cada variante requiere una configuración DUoM
diferente, se puede crear un registro de override en la tabla `DUoM Item Variant Setup`
(50101), con clave primaria `(Item No., Variant Code)`.

### Campos del override de variante

| Field | Description |
|---|---|
| `Item No.` | Clave — artículo al que pertenece la variante |
| `Variant Code` | Clave — variante del artículo |
| `Second UoM Code` | Override de la segunda UdM. Si se deja en blanco se hereda del artículo. |
| `Conversion Mode` | Override del modo de conversión. Si no se establece se usa el del artículo. |
| `Fixed Ratio` | Override del ratio por defecto. Si se deja a cero se usa el del artículo. |

> **Regla clave:** `Dual UoM Enabled` vive **únicamente** en `DUoM Item Setup` (50100).
> Una variante **no puede activar DUoM** si el artículo base no lo tiene habilitado.

### Jerarquía de configuración: Artículo → Variante

La resolución efectiva de configuración DUoM la centraliza el codeunit
`DUoM Setup Resolver` (50107), siguiendo este orden:

```
1. Comprobar DUoM Item Setup (50100) para el artículo.
   Si no existe registro o Dual UoM Enabled = false → DUoM desactivado.
2. Si VariantCode no está vacío, comprobar DUoM Item Variant Setup (50101)
   para el par (ItemNo, VariantCode).
   Si existe registro → usar sus campos (Second UoM Code, Conversion Mode, Fixed Ratio).
3. En caso contrario → usar los campos de nivel artículo de DUoM Item Setup.
```

Todos los suscriptores de eventos y triggers de tabla deben llamar a
`DUoM Setup Resolver.GetEffectiveSetup(ItemNo, VariantCode, ...)` para obtener la
configuración efectiva. Las lecturas directas de `DUoM Item Setup` solo son aceptables
en contextos donde no existe variante (páginas de configuración, flujos solo-artículo).

### Cambio de variante en línea de documento

Cuando el usuario cambia el `Variant Code` en una línea de pedido de compra o venta que
ya tiene una cantidad introducida:

1. Los campos DUoM (`DUoM Second Qty`, `DUoM Ratio`) se resetean a cero.
2. El sistema aplica la configuración DUoM efectiva de la nueva variante mediante el resolver.
3. Si el modo de la nueva variante es Fijo o Variable, `DUoM Second Qty` se **recalcula
   automáticamente** con el ratio efectivo y la cantidad principal ya introducida.
4. Si el modo es AlwaysVariable, `DUoM Second Qty` queda a cero y el usuario debe
   introducirlo manualmente.

### Borrado en cascada

Al eliminar una variante del artículo, el trigger `OnDelete` de la tableextension
`DUoM Item Variant Ext` (50120) borra automáticamente el registro de override DUoM
correspondiente, evitando huérfanos en `DUoM Item Variant Setup`.

### ¿Cuándo usar overrides de variante?

Use la configuración por variante cuando distintas variantes del mismo artículo requieran:

- Una **segunda unidad de medida** diferente (ej. variante ROMANA se mide en PCS, variante
  TROCEADA en BOLSAS).
- Un **ratio de conversión** diferente (ej. variante estándar 1,25 KG/PCS, variante premium 1,05 KG/PCS).
- Un **modo de conversión** diferente (ej. variante estándar en modo Fijo, variante premium en Variable).

Si todas las variantes del artículo comparten la misma configuración DUoM, **no es necesario**
crear ningún override de variante.

---

## Lot-Specific Real Ratio (Issue 13)

### Motivación funcional

En sectores agroalimentarios y similares, el ratio KG/PCS varía por lote de recepción.
Por ejemplo, un lote de lechugas Romanas puede pesar 0,38 kg/unidad mientras que otro
lote del mismo artículo pesa 0,41 kg/unidad. Registrar este ratio medido en el momento
de la recepción y reutilizarlo en todas las transacciones posteriores del lote evita
tener que introducirlo manualmente cada vez.

### Tabla `DUoM Lot Ratio` (50102)

| Field | Type | Purpose |
|---|---|---|
| `Item No.` | Code[20] PK | Artículo al que pertenece el ratio |
| `Lot No.` | Code[50] PK | Número de lote |
| `Actual Ratio` | Decimal(0:5) | Ratio real medido (KG/PCS u otra combinación). Debe ser > 0. |
| `Description` | Text[100] | Descripción opcional (comentario o referencia del lote) |

La validación `OnValidate` del campo `Actual Ratio` impide valores ≤ 0.

### Nota: Multi-Lote y Item Tracking — Diseño implementado (Issue 13, rediseño 2026-04-22)

**Hallazgo arquitectónico:** En Business Central 27, `Lot No.` **no es un campo directo**
en `Purchase Line` (tabla 39) ni en `Sales Line` (tabla 37). Los lotes se gestionan a través
de la infraestructura estándar de trazabilidad:

- **`Reservation Entry` (tabla 337):** almacenamiento persistente de asignaciones de lote.
- **Página `Item Tracking Lines` (6510):** UI donde el usuario asigna N lotes por línea.
- **Flujo de contabilización:** BC crea un ILE por lote; en `OnAfterInitItemLedgEntry`
  el `ItemJournalLine` tiene `Lot No.` y `Quantity` específicos del lote.

El único caso donde `Lot No.` **sí** es campo directo es `Item Journal Line` (tabla 83).

### Regla de diseño: línea origen como agregado — modelo 1:N (Issue 20, refactorizado Issue 21)

**DUoM no asume que 1 línea origen = 1 lote.**

El modelo correcto de Business Central es:

```
1 línea origen (Purchase Line, Sales Line, Item Journal Line) = N asignaciones de lote
```

- Los campos DUoM de la **línea origen** son **totales agregados**.
- Cada **ILE por lote** contiene la segunda cantidad y el ratio **específicos de ese lote**.
- El **total DUoM de la línea** debe ser coherente con la suma de las cantidades DUoM
  de todos los ILEs generados para esa línea.
- **`Item Journal Line`."Lot No." no es la fuente de verdad de la ratio DUoM por lote.**
  La ratio real por lote se almacena en `DUoM Lot Ratio` (50102) y se aplica a nivel de ILE.

### Flujo de integración implementado (mecanismo productivo único)

```
Purchase/Sales Line o IJL con N lotes vía Item Tracking:
  Usuario asigna N lotes en "Item Tracking Lines" (estándar BC)
  → Lotes persisten en Reservation Entry (flujo estándar, sin intervención DUoM)
  → Al contabilizar: BC divide la línea por lote y crea un ILE por lote
  → Para cada ILE: OnAfterInitItemLedgEntry(NewILE, ItemJnlLine, ...)
    - ItemJnlLine.Lot No. = lote específico del ILE
    - ItemJnlLine.Quantity = cantidad del lote (no el total de la línea)
    - DUoM Ratio: copiado desde IJL (ratio del documento, puede ser ratio genérico)
    - DUoM Second Qty: Abs(ILE.Quantity) × DUoM Ratio (proporcional al lote)
    - TryApplyLotRatioToILE: si lote tiene ratio en DUoM Lot Ratio y modo ≠ Fixed →
        ILE.DUoM Ratio = LotActualRatio
        ILE.DUoM Second Qty = Abs(ILE.Quantity) × LotActualRatio
```

> **Nota Issue 21:** El subscriber `OnAfterValidateEvent[Lot No.]` en `Item Journal Line`
> (que pre-rellenaba DUoM Ratio/Second Qty al validar Lot No.) fue eliminado porque asumía
> incorrectamente que 1 línea = 1 lote. El mecanismo productivo principal es el flujo de
> posting descrito arriba (TryApplyLotRatioToILE en OnAfterInitItemLedgEntry).

### Comportamiento por modo de conversión

| Modo | Comportamiento al contabilizar con Lot No. |
|------|---------------------------------------------|
| Fixed | Ratio de lote NO aplicado. El ratio fijo siempre prevalece. |
| Variable | Si existe ratio de lote → sobrescribe DUoM Ratio + recalcula DUoM Second Qty |
| AlwaysVariable + ratio de lote | Si existe ratio de lote → sobrescribe DUoM Ratio + recalcula DUoM Second Qty |
| AlwaysVariable sin ratio de lote, sin Lot No. | Copia DUoM Second Qty directamente desde IJL (flujo sin trazabilidad de lote) |
| AlwaysVariable sin ratio de lote, con Lot No. | ILE DUoM Second Qty = 0. Ver limitación conocida. |

### Limitación conocida: AlwaysVariable + multi-lote sin ratio de lote

Cuando se contabiliza con modo AlwaysVariable, asignación de N lotes y **sin** ratio
de lote registrado en `DUoM Lot Ratio` (50102):

- La cantidad DUoM de la línea origen fue introducida manualmente por el usuario como total.
- Al dividir la línea por lotes, no es posible distribuir automáticamente el total entre
  los lotes sin un ratio de lote que proporcione la regla de distribución.
- **Resultado:** el ILE de cada lote queda con `DUoM Second Qty = 0`.
- **Solución recomendada:** registrar el ratio de lote en `DUoM Lot Ratio` para el artículo
  y los lotes correspondientes, o usar el modo Variable con un ratio por defecto.

Esta limitación está documentada y es preferible a copiar incorrectamente el total de la
línea a cada ILE (que era el comportamiento anterior, eliminado en Issue 20).

---

## Conversion Modes

### Fixed

The ratio between the two units is constant across all transactions and lots.

```
Second Qty = First Qty × Fixed Ratio
```

Example: 1 box always contains exactly 12 pieces.

### Variable

The system proposes a default ratio (from the item setup), but the user can override it
per document line. The override is stored on the line and propagated to entries.

Example: A KG/pcs ratio of ~1.25 KG/pcs is the default, but the actual weight
of the batch on this receipt is 1.31 KG/pcs, so the user adjusts the field.

### Always-Variable

No default ratio is provided. The user must enter the second quantity manually on
every document line. The system never derives it automatically.

Example: Fresh produce sold by weight but counted by piece — each shipment differs.

---

## Rounding Precision

When the second Unit of Measure is discrete (e.g. PCS, BOX, PALLET), fractional
quantities such as 11.5 PCS are physically meaningless. Business Central stores a
`Qty. Rounding Precision` field on each `Item Unit of Measure` record that defines the
minimum unit step for that item/UoM combination (e.g. `1` for PCS, `0.001` for KG).

The DualUoM extension reads this field to ensure `DUoM Second Qty` is always
rounded to a physically valid value:

| Scenario | Second UoM | Rounding Precision | Qty | Ratio | Result |
|---|---|---|---|---|---|
| Auto-calculate Fixed | PCS | 1 | 10 | 1.15 | **12** |
| Auto-calculate Fixed | KG | 0.001 | 10 | 1.15 | **11.5** |
| Manual entry | PCS | 1 | — | — | 11.5 entered → stored as **12** |
| No setup (fallback) | any | 0 | 10 | 1.15 | **11.5** (no rounding) |

Rounding is applied in two places:

1. **Auto-calculation** — `DUoM Calc Engine.ComputeSecondQtyRounded` rounds the
   computed result before storing it on the document line.
2. **Manual entry** — the `OnValidate` trigger of the `DUoM Second Qty` field in
   `Purchase Line`, `Sales Line` and `Item Journal Line` rounds the user-entered value
   using the same precision.

El codeunit `DUoM UoM Helper` (50106) centraliza la consulta de la precisión de redondeo.
Expone dos métodos:

- `GetSecondUoMRoundingPrecision(ItemNo)` — para contextos sin variante; lee
  `ItemUnitOfMeasure."Qty. Rounding Precision"` usando el `Second UoM Code` del artículo.
- `GetRoundingPrecisionByUoMCode(ItemNo, SecondUoMCode)` — para contextos con variante;
  recibe el código UoM ya resuelto por `DUoM Setup Resolver` y busca directamente en
  `Item Unit of Measure` para el par `(ItemNo, SecondUoMCode)`.

Ambos métodos devuelven `0` como fallback cuando no existe el registro de
`Item Unit of Measure`. Cuando la precisión es `0`, se aplica internamente un fallback de
`0.00001` para preservar el comportamiento sin truncación.

> **Note:** `DecimalPlaces = 0:5` on the field definition is intentionally kept unchanged.
> Rounding is a logical constraint, not a storage constraint. High-precision intermediate
> values for continuous UoMs (KG, LT) remain fully representable.

---

## Second Quantity Propagation

The second quantity must be visible and editable (subject to conversion mode) at:

1. **Purchase Order Line** — entered or derived at order time
2. **Purchase Receipt Line** — confirmed or adjusted at receipt
3. **Item Ledger Entry** — posted from the receipt; immutable after posting
4. **Sales Order Line** — entered or derived at order entry
5. **Sales Shipment Line** — confirmed at shipment
6. **Item Journal Line** — entered manually for adjustments

For full traceability, the second quantity and conversion ratio are also preserved on all
posted historical document lines (read-only, copied from the source line at posting time):

7. **Purchase Invoice Line** — propagated from the `Purchase Line` when posting as invoice
8. **Purchase Cr. Memo Line** — propagated from the `Purchase Line` when posting a credit memo
9. **Sales Invoice Line** — propagated from the `Sales Line` when posting as invoice
10. **Sales Cr.Memo Line** — propagated from the `Sales Line` when posting a credit memo

In all cases, the ratio used at posting time is stored alongside the quantity so that
historical analysis is possible without recalculation.

---

## Lot-Specific Real Ratio

When item tracking by lot is active, the real conversion ratio for a given lot can
differ from the default. The actual weighed ratio is:

- entered by the user at receipt (warehouse or purchase)
- stored against the lot number (Item Tracking extension)
- used as the default for all subsequent transactions involving that lot

This is a Phase 2 feature. In MVP, the ratio is stored on the document line only.

---

## Expected Impact Across Modules

### Purchasing

- Purchase order lines and receipt lines get a `Second Qty` and `Second UoM Code` field
- Posting propagates second qty to Item Ledger Entry
- Purchase invoice line shows second qty (read-only from receipt, adjustable on direct invoices)

### Sales

- Sales order lines and shipment lines get a `Second Qty` field
- Picking (basic warehouse) deducts based on primary qty; second qty is informational
- Invoice line shows second qty from shipment

### Inventory

- Item journal lines get a `Second Qty` field
- Item ledger entries record second qty for all relevant entry types
- Physical inventory counts support second qty entry

### Warehouse (Phase 2)

- Warehouse receipt and shipment lines get `Second Qty`
- Directed pick/put-away lines get `Second Qty` for double-checking
- Warehouse entries record second qty

---

## Precio/Coste en la Segunda Unidad de Medida (Issue 12)

### Motivación

En negocios donde la facturación se realiza en la segunda UdM (p. ej., se factura por kg
cuando la unidad de compra es una caja), el usuario necesita introducir el precio en la
segunda UdM y que el sistema derive automáticamente el precio estándar de BC.

### Campo `DUoM Unit Price` en líneas de venta

El campo `DUoM Unit Price` almacena el precio unitario expresado en la segunda unidad de medida.

**Derivación bidireccional:**
- Usuario introduce `DUoM Unit Price` con `DUoM Ratio ≠ 0` → el sistema calcula:
  `Unit Price = DUoM Unit Price / DUoM Ratio`
- Usuario cambia `Unit Price` estándar con `DUoM Ratio ≠ 0` → el sistema recalcula:
  `DUoM Unit Price = Unit Price × DUoM Ratio`
- Si `DUoM Ratio = 0` (modo AlwaysVariable sin ratio establecido), no se produce derivación.

### Campo `DUoM Unit Cost` en líneas de compra

El campo `DUoM Unit Cost` almacena el coste unitario expresado en la segunda unidad de medida.

**Derivación bidireccional:**
- Usuario introduce `DUoM Unit Cost` con `DUoM Ratio ≠ 0` → el sistema calcula:
  `Direct Unit Cost = DUoM Unit Cost / DUoM Ratio`
- Usuario cambia `Direct Unit Cost` estándar con `DUoM Ratio ≠ 0` → el sistema recalcula:
  `DUoM Unit Cost = Direct Unit Cost × DUoM Ratio`

### Propagación a documentos históricos

Los campos `DUoM Unit Price` y `DUoM Unit Cost` se propagan automáticamente a los
documentos históricos correspondientes en el momento del registro:
- Compras: `Purch. Rcpt. Line`, `Purch. Inv. Line`, `Purch. Cr. Memo Line`
- Ventas: `Sales Shipment Line`, `Sales Invoice Line`, `Sales Cr.Memo Line`

Los valores en documentos registrados son inmutables.

### `DUoM Second Qty` en `Value Entry`

La tableextension `DUoM Value Entry Ext` (50121) añade el campo `DUoM Second Qty`
a la tabla `Value Entry` de BC. Este campo se propaga desde el `Item Journal Line`
en el evento `OnAfterInitValueEntry` de `Codeunit "Item Jnl.-Post Line"` — sin Modify().

Esto permite la trazabilidad contable completa: para cada entrada de valor generada
durante la contabilización, se registra también la cantidad en la segunda unidad de medida.
