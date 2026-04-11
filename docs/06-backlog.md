# Backlog — DualUoM-BC

This is the proposed ordered backlog for controlled, incremental delivery.
Each item is scoped to be implementable in a single focused issue by GitHub Copilot.

---

## Phase 1 — MVP

### Issue 1 — Project Governance Baseline *(this issue)*

Create documentation baseline: vision, scope, functional design, architecture, testing
strategy, backlog. Update README and copilot-instructions.

### Issue 2 — DUoM Calculation Engine ✅ IMPLEMENTADO

Create `DUoM Calc Engine` codeunit (ID 50101) with:
- `ComputeSecondQty(FirstQty, Ratio, Mode)` function
- Input validation (qty must be non-negative, ratio must be positive for Fixed/Variable)
- Unit tests covering Fixed, Variable, Always-Variable modes and edge cases (zero qty, rounding)

**Deliverables:** `DUoMCalcEngine.Codeunit.al` (50101), `DUoMCalcEngineTests.Codeunit.al` (50204)
Codeunit temporal `DualUoM Pipeline Check` (50100) y su test (50200) eliminados.

### Issue 3 — Item DUoM Setup Table and Page

Create `DUoM Item Setup` table (ID 50100) linked to `Item`:
- Fields: `Item No.`, `Dual UoM Enabled`, `Second UoM Code`, `Conversion Mode` (enum),
  `Fixed Ratio`
- Create setup page (ID 50100)
- Create page extension on Item Card to open the setup page
- Unit tests for setup validation rules

**Deliverables:** `DUoMItemSetup.Table.al`, `DUoMConversionMode.Enum.al`,
`DUoMItemSetup.Page.al`, `ItemCard.PageExt.al`, `DUoMItemSetupTests.Codeunit.al`

### Issue 4 — Purchase Line DUoM Fields ✅ IMPLEMENTADO

Extend `Purchase Line` with `DUoM Second Qty` and `DUoM Ratio` fields (table extension).
Extend Purchase Order Line subpage to show the fields.
Wire `OnAfterValidate` on `Quantity` to call the Calc Engine for auto-derivation.
Integration tests: create a purchase order line, verify second qty is computed.

**Deliverables:** `DUoMPurchaseLine.TableExt.al` (50110), `DUoMPurchaseOrderSubform.PageExt.al` (50101),
`DUoMPurchaseSubscribers.Codeunit.al` (50102), `DUoMPurchaseTests.Codeunit.al` (50205)

### Issue 5 — Purchase Posting — ILE Second Qty ✅ IMPLEMENTADO

Subscribe to purchase receipt posting events to propagate `DUoM Second Qty` and
`DUoM Ratio` from `Purchase Line` to `Item Ledger Entry` (table extension on ILE).
Propagation via `OnAfterInsertItemLedgEntry` en Codeunit 22, trazando desde ILE
a través de `Purch. Rcpt. Line` hasta la `Purchase Line` original.

**Deliverables:** `DUoMItemLedgerEntry.TableExt.al` (50113), `DUoMInventorySubscribers.Codeunit.al` (50104)

### Issue 6 — Sales Line DUoM Fields ✅ IMPLEMENTADO

Extend `Sales Line` with `DUoM Second Qty` and `DUoM Ratio` fields.
Extend Sales Order Line subpage to show the fields.
Wire `OnAfterValidate` on `Quantity`.
Integration tests.

**Deliverables:** `DUoMSalesLine.TableExt.al` (50111), `DUoMSalesOrderSubform.PageExt.al` (50102),
`DUoMSalesSubscribers.Codeunit.al` (50103), `DUoMSalesTests.Codeunit.al` (50206)

### Issue 7 — Sales Posting — ILE Second Qty ✅ IMPLEMENTADO

Subscribe to sales shipment posting events to propagate DUoM fields to ILE.
Propagación via `OnAfterInsertItemLedgEntry` trazando a través de `Sales Shipment Line`
hasta la `Sales Line` original (implementado en `DUoMInventorySubscribers`).

**Deliverables:** incluido en `DUoMInventorySubscribers.Codeunit.al` (50104)

### Issue 8 — Item Journal DUoM Fields and Posting ✅ IMPLEMENTADO

Extend `Item Journal Line` with DUoM fields.
Subscribe to item journal posting to propagate to ILE.
Integration tests: verify ILE fields exist and can hold DUoM data.

**Deliverables:** `DUoMItemJournalLine.TableExt.al` (50112), `DUoMInventoryTests.Codeunit.al` (50207)

### Issue 9 — Campos DUoM en líneas de documentos registrados + tests E2E Phase 1 ✅ IMPLEMENTADO

Añadir campos `DUoM Second Qty` y `DUoM Ratio` a las tablas `Purch. Rcpt. Line` y
`Sales Shipment Line` mediante nuevas table extensions. Suscribirse a los eventos
`OnAfterPurchRcptLineInsert` (Purch.-Post) y `OnAfterInsertShipmentLine` (Sales-Post) para
propagar los valores desde las líneas de pedido origen. Ampliar las páginas de subformulario
de recepción y envío registrados para mostrar los campos (solo lectura). Añadir tests de
integración E2E que cubran el ciclo completo de contabilización (compra, venta, diario de
productos) y verifiquen la propagación hasta ILE.

**Deliverables:**
- `DUoMPurchRcptLine.TableExt.al` (50114), `DUoMSalesShipmentLine.TableExt.al` (50115)
- Subscribers en `DUoMInventorySubscribers.Codeunit.al` (50104): `OnAfterPurchRcptLineInsert`, `OnAfterInsertShipmentLine`
- `DUoMPostedPurchRcptSubform.PageExt.al` (50104) extiende `Posted Purchase Rcpt. Subform`, `DUoMPostedSalesShipSubform.PageExt.al` (50105) extiende `Posted Sales Shpt. Subform`
- `DUoMILEIntegrationTests.Codeunit.al` (50209) — 6 tests E2E

---

## Phase 2

### Issue 10 — Lot-Specific Real Ratio

Store the actual ratio per lot on Item Tracking Lines.
Pre-fill the DUoM Ratio on document lines when a lot is selected.
Tests: assign a lot, verify ratio pre-fill.

### Issue 11 — Warehouse Receipt and Shipment DUoM Fields

Extend Warehouse Receipt Line and Warehouse Shipment Line.
Propagate to Warehouse Entry and ILE at posting.

### Issue 12 — Directed Put-Away and Pick DUoM Fields

Extend Warehouse Activity Line for directed warehouse.
Show second qty on put-away and pick documents.

### Issue 13 — Physical Inventory DUoM

Extend physical inventory journal to support second qty counting.

### Issue 14 — Reporting Extensions

Add second qty columns to key standard reports (purchase receipt, sales shipment,
inventory valuation) using report extensions.

---

## Phase 3 / Later

- Transfer order DUoM support (Issue 15+)
- Return order DUoM support (Issue 16+)
- Assembly order DUoM support (if ever in scope)

---

## Notes

- Issues should be implemented in order; later issues depend on earlier ones.
- Each issue must include tests before it can be considered done.
- ~~The `DualUoM Pipeline Check` codeunit (ID 50100) and its test (ID 50200) are
  temporary and will be deleted when Issue 2 (Calc Engine) is merged.~~ ✅ Eliminados.
- El Calc Engine usa ID 50101; los tests del Calc Engine usan ID 50204.
  Los IDs 50201–50203 están ya usados por `DUoM Item Setup Tests`,
  `DUoM Item Card Opening Tests` y `DUoM Item Delete Tests`.
- **Localización Phase 1 (Issues 2–9):** ✅ Todos los trans-units de los nuevos objetos
  (Codeunit 50101, PageExtensions 50101/50102/50104/50105, TableExtensions 50114/50115)
  están en ambos XLF con IDs verificados mediante `LanguageFileUtilities.GetNameHash`
  del compilador AL (runtime 15).
- Los IDs de test codeunit usados en Phase 1: 50201–50208 (codeunits de test unitarios
  e integración) y 50209 (`DUoM ILE Integration Tests`, tests E2E de contabilización).
