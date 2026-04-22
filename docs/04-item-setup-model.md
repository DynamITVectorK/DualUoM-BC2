# DUoM Item Setup — Data Model Design Note

## Decision: Option B — Dedicated Setup Table

The DUoM item setup is stored in a dedicated table (`DUoM Item Setup`, ID 50100)
keyed by `Item No.`, rather than extending the `Item` table directly.

---

## Rationale

### Why not Option A (Item table extension)?

Extending `Item` directly would pollute the most-used table in BC with DUoM fields
that are irrelevant for the majority of items. It also creates a tighter coupling
that makes removal or refactoring harder, and increases upgrade-time risk (any
schema change to Item is BC's responsibility and can block extension upgrades).

### Why not Option C (hybrid)?

A hybrid approach adds complexity: a flag on `Item` for enablement plus a
separate table for details. The flag on `Item` gives minimal benefit (quick
filter without join) but adds maintenance overhead if the setup table is queried
anyway. Given that BC performance at this scale is not a concern, the extra join
is acceptable and keeping all DUoM setup in one place is cleaner.

### Why Option B?

- **Clean base**: the Item table is unchanged. Upgrade safety is maximised.
- **Absence = not configured**: a missing `DUoM Item Setup` record means no DUoM
  for that item — no null-flag fields to check across all items.
- **Single source of truth**: all DUoM item configuration lives in one table with
  a clear primary key.
- **Extensible**: adding future fields (lot tracking linkage, warehouse-specific
  flags, costing fields) does not require additional Item table extensions.
- **SaaS safe**: follows the *dedicated extension table* pattern recommended for
  PTE extensions that attach complex configuration to standard entities.

---

## Table Structure

### `DUoM Item Setup` (50100) — Item-level configuration

| Field | Type | Purpose |
|---|---|---|
| `Item No.` | Code[20] PK | Links to `Item`; defines setup scope |
| `Dual UoM Enabled` | Boolean | Master switch; clearing this resets all other fields |
| `Second UoM Code` | Code[10] | The secondary UoM (e.g. PCS when base is KG) |
| `Conversion Mode` | Enum `DUoM Conversion Mode` | Fixed / Variable / Always Variable |
| `Fixed Ratio` | Decimal(0:5) | Ratio when mode is Fixed or Variable; cleared for Always Variable |

---

## Variant-Level Override Table

### `DUoM Item Variant Setup` (50101) — Optional variant override

When Item Variants require a different DUoM configuration from the item default,
an optional override record can be stored in this table.

**Design principle:** the item-level setup is the master configuration.
A variant record only exists when at least one field should differ from the item.
When no variant record exists, the item setup is used as-is.

| Field | Type | Purpose |
|---|---|---|
| `Item No.` | Code[20] PK | Links to `Item` |
| `Variant Code` | Code[10] PK | Links to `Item Variant` |
| `Second UoM Code` | Code[10] | Override for secondary UoM code |
| `Conversion Mode` | Enum `DUoM Conversion Mode` | Override for conversion mode |
| `Fixed Ratio` | Decimal(0:5) | Override for the fixed/default ratio |

**Important:** `Dual UoM Enabled` lives only on the item setup — a variant
cannot independently enable DUoM if the item has it disabled.

---

## Lot-Level Ratio Table (Issue 13)

### `DUoM Lot Ratio` (50102) — Ratio real medido por lote

| Field | Type | Purpose |
|---|---|---|
| `Item No.` | Code[20] PK | Links to `Item` |
| `Lot No.` | Code[50] PK | Número de lote |
| `Actual Ratio` | Decimal(0:5) | Ratio real medido (> 0 obligatorio) |
| `Description` | Text[100] | Descripción o comentario opcional |

**Design principle:** El ratio de lote solo aplica en los modos Variable y AlwaysVariable.
En modo Fixed, el ratio de configuración siempre prevalece.

---

## Configuration Hierarchy: Item → Variant → Lot

Resolved by `DUoM Setup Resolver` (codeunit 50107) for Item/Variant level,
and by `DUoM Lot Subscribers` (codeunit 50108) for the Lot level:

```
1. Check DUoM Item Setup (50100) for the item.
   If not found or Dual UoM Enabled = false → DUoM is OFF.
2. If VariantCode is not empty, check DUoM Item Variant Setup (50101).
   If a record exists → use its fields (Second UoM Code, Conversion Mode, Fixed Ratio).
3. Otherwise → use the item-level fields from DUoM Item Setup.
4. When Lot No. is validated on an Item Journal Line (Variable / AlwaysVariable only):
   Check DUoM Lot Ratio (50102) for (Item No., Lot No.).
   If a record exists → overwrite DUoM Ratio with the actual lot ratio and recalculate DUoM Second Qty.
   Fixed mode: lot ratio is NEVER applied.
5. When posting creates an ILE (OnAfterInitItemLedgEntry):
   DUoM Inventory Subscribers (50104) calls TryApplyLotRatioToILE from DUoM Lot Subscribers (50108).
   ILE.DUoM Second Qty = Abs(ILE.Quantity) × ILE.DUoM Ratio (proportional per lot).
   If lot has a registered ratio and mode ≠ Fixed → ILE.DUoM Ratio overridden with lot ratio.
```

---

## Enum: DUoM Conversion Mode

| Value | Meaning |
|---|---|
| Fixed | Ratio is constant; stored in `Fixed Ratio` field; derived automatically |
| Variable | Default ratio in `Fixed Ratio`; user can override per document line |
| Always Variable | No default ratio; user must enter manually on every document line |

---

## Validation Rules

### Item Setup (`DUoM Item Setup`)

| Rule | Enforcement point |
|---|---|
| If DUoM disabled → Second UoM Code, Conversion Mode, Fixed Ratio are cleared | `Dual UoM Enabled` OnValidate trigger |
| If DUoM enabled → Second UoM Code must be set | `ValidateSetup()` procedure |
| Second UoM Code ≠ Item base UoM | `Second UoM Code` OnValidate trigger + `ValidateSetup()` |
| If Fixed mode → Fixed Ratio > 0 | `ValidateSetup()` procedure |
| Switching from Fixed to Variable/Always Variable → Fixed Ratio cleared | `Conversion Mode` OnValidate trigger |

### Variant Setup (`DUoM Item Variant Setup`)

| Rule | Enforcement point |
|---|---|
| Second UoM Code ≠ Item base UoM (when specified) | `Second UoM Code` OnValidate trigger |
| Setting Conversion Mode to AlwaysVariable → Fixed Ratio cleared | `Conversion Mode` OnValidate trigger |
| Deleting an Item Variant → cascade-deletes the variant setup | `Item Variant` OnDelete trigger (tableextension 50120) |

---

## Future Extensibility

- **Warehouse fields (Phase 2)**: additional boolean flags can be added to
  `DUoM Item Setup` as new fields without breaking existing data.
- **Document propagation**: all document line logic uses `DUoM Setup Resolver`
  (codeunit 50107) to retrieve effective setup — adding new hierarchy levels
  only requires updating the resolver, not all callers.
- **Mass update tooling**: a future issue can add a report/page to bulk-enable DUoM
  for multiple items without changing the table structure.
