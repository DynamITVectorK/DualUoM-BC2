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

| Field | Type | Purpose |
|---|---|---|
| `Item No.` | Code[20] PK | Links to `Item`; defines setup scope |
| `Dual UoM Enabled` | Boolean | Master switch; clearing this resets all other fields |
| `Second UoM Code` | Code[10] | The secondary UoM (e.g. PCS when base is KG) |
| `Conversion Mode` | Enum `DUoM Conversion Mode` | Fixed / Variable / Always Variable |
| `Fixed Ratio` | Decimal(0:5) | Ratio when mode is Fixed or Variable; cleared for Always Variable |

---

## Enum: DUoM Conversion Mode

| Value | Meaning |
|---|---|
| Fixed | Ratio is constant; stored in `Fixed Ratio` field; derived automatically |
| Variable | Default ratio in `Fixed Ratio`; user can override per document line |
| Always Variable | No default ratio; user must enter manually on every document line |

---

## Validation Rules

| Rule | Enforcement point |
|---|---|
| If DUoM disabled → Second UoM Code, Conversion Mode, Fixed Ratio are cleared | `Dual UoM Enabled` OnValidate trigger |
| If DUoM enabled → Second UoM Code must be set | `ValidateSetup()` procedure |
| Second UoM Code ≠ Item base UoM | `Second UoM Code` OnValidate trigger + `ValidateSetup()` |
| If Fixed mode → Fixed Ratio > 0 | `ValidateSetup()` procedure |
| Switching from Fixed to Variable/Always Variable → Fixed Ratio cleared | `Conversion Mode` OnValidate trigger |

`ValidateSetup()` is a public procedure intended for use by document/posting flows
(future issues) to assert setup consistency before using DUoM data.

---

## Future Extensibility

- **Lot-specific ratios (Phase 2)**: will be stored in a separate table keyed by
  `(Item No., Lot No.)` — no changes needed to `DUoM Item Setup`.
- **Warehouse fields (Phase 2)**: additional boolean flags (e.g. `Track in WMS`)
  can be added to `DUoM Item Setup` as new fields without breaking existing data.
- **Document propagation**: document line codeunits will call `DUoM Item Setup.Get()`
  to retrieve the conversion mode and ratio — the table key design supports this.
- **Mass update tooling**: a future issue can add a report/page to bulk-enable DUoM
  for multiple items without changing the table structure.
