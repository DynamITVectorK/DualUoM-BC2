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
