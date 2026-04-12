# Functional Design — DualUoM-BC

## Item DUoM Setup

Each item that participates in dual UoM requires the following configuration:

| Field | Description |
|---|---|
| `Dual UoM Enabled` | Boolean — activates DUoM for this item |
| `Second UoM Code` | The second unit of measure code (e.g. PCS while base is KG) |
| `Conversion Mode` | Fixed / Variable / Always-Variable (see below) |
| `Fixed Ratio` | Used only when Conversion Mode = Fixed |

This setup is stored on the item itself (table extension on `Item`) or on a dedicated
DUoM Item Setup table linked by item number. The exact design is decided at implementation
time; the functional intent is item-level configuration.

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
`Rounding Precision` field on each `Unit of Measure` record that defines the minimum
unit step (e.g. `1` for PCS, `0.001` for KG).

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

The `DUoM UoM Helper` codeunit (50106) centralises the precision lookup:
`GetSecondUoMRoundingPrecision(ItemNo)` reads `UnitOfMeasure."Rounding Precision"` for
the item's configured second UoM and returns `0` as fallback when no setup exists.
When the precision is `0` (older BC records), a fallback of `0.00001` is used internally
to preserve the current unrounded behaviour without truncation.

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
