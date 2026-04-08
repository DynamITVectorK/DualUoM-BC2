# Scope & MVP — DualUoM-BC

## MVP (Phase 1)

The MVP delivers the minimum working set required to purchase, receive, sell and ship
an item using two units of measure with a variable conversion ratio.

### In scope for MVP

- **Item DUoM Setup** — per-item flag to enable DUoM, choice of conversion mode
  (fixed / variable / always-variable), second UoM code
- **Calculation Engine** — codeunit to compute and validate second quantity from first
  quantity using the active conversion mode
- **Purchase Lines** — second quantity field on purchase order lines and receipt lines
- **Item Ledger Entries** — second quantity and ratio persisted on item ledger entries
- **Sales Lines** — second quantity field on sales order lines and shipment lines
- **Inventory Journal** — second quantity field on item journal lines
- **Basic Posting Validation** — ensure second quantity is present when DUoM is enabled
  before posting
- **Automated Tests** — unit + integration tests for all of the above

### MVP success criteria

- An item with DUoM enabled can be purchased with both quantities visible and posted
- An item with DUoM enabled can be sold with both quantities visible and posted
- Item ledger entries carry the correct second quantity and ratio
- All tests pass in CI

---

## Phase 2

- Lot-specific real ratio (second qty per lot stored on Item Tracking)
- Physical inventory with second quantity
- Warehouse receipts and shipments with second quantity
- Directed put-away and pick with second quantity
- Value entry propagation (for costing accuracy)
- Reporting extensions (second qty columns on standard reports)

---

## Phase 3 / Later

- Transfer orders with second quantity
- Return orders (purchase and sales) with second quantity
- Assembly (if ever added to scope)
- Intercompany flows

---

## Permanently Out of Scope

- Manufacturing (production orders, output journal, capacity)
- Projects (job planning, job ledger)
- Service Management (service orders)
- Scale / hardware integration
- Multi-language translation (translation file feature is enabled but not a delivery goal)
- E-Document / EDI mapping for second quantity
