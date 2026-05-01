# Scope & MVP — DualUoM-BC

## MVP (Phase 1) ✅ COMPLETADO

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
- **Lot-specific ratio** — ratio real por lote almacenado en `DUoM Lot Ratio` (tabla 50102);
  se pre-rellena automáticamente al asignar un lote en Item Tracking Lines y se aplica
  por ILE durante la contabilización mediante el patrón `OnAfterCopyTracking*`
  (codeunit 50110). Ver `docs/02-functional-design.md` — sección "Lot-Specific Real Ratio"
  y `docs/03-technical-architecture.md` — sección "Modelo 1:N" para el diseño completo.
- **Automated Tests** — unit + integration tests for all of the above

> **Limitación conocida (BC 27):** Los campos DUoM en `Reservation Entry` (tabla 337)
> están definidos (tableextension 50123) pero no se rellenan automáticamente desde
> `Tracking Specification` porque el evento `OnAfterCopyTrackingFromTrackingSpec` de BC 27
> no expone un parámetro `var Rec` modificable (AL0282). El ratio de lote llega
> correctamente al `Item Ledger Entry` mediante la cadena
> `Tracking Specification → Item Journal Line → Item Ledger Entry`.

### MVP success criteria

- An item with DUoM enabled can be purchased with both quantities visible and posted
- An item with DUoM enabled can be sold with both quantities visible and posted
- Item ledger entries carry the correct second quantity and ratio
- Items with lot-specific ratios post the correct per-lot DUoM Second Qty to each ILE
- All tests pass in CI

---

## Phase 2

- Physical inventory with second quantity
- Warehouse receipts and shipments with second quantity
- Directed put-away and pick with second quantity
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
