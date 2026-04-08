# Vision — DualUoM-BC

## Project Objective

Build a **Dual Unit of Measure (DUoM)** Business Central SaaS extension that allows items to
carry two independent quantities simultaneously throughout the full document, entry and
warehouse lifecycle — without modifying the standard BC application.

## Business Need

Many industries (food, chemicals, agriculture, metals) trade goods measured in two distinct
units at the same time. A batch of lettuce may be:

- purchased as **10 KG** (weight — invoiced and costed)
- received as **8 pcs** (pieces — picked, counted and tracked)

Both quantities are legally and operationally relevant. Neither can be derived reliably from
the other using a fixed ratio, because the real conversion varies by lot.

Standard BC supports a single alternate UoM (the `Qty. per Unit of Measure` factor on the
Item Unit of Measure table), but this covers only a fixed, item-level ratio. It cannot:

- store a variable ratio per transaction or per lot
- carry a second quantity independently through all document lines and ledger entries
- enforce per-lot ratio tracking for traceability

## Why Standard BC UoM Is Insufficient

| Requirement | Standard BC | DUoM Extension |
|---|---|---|
| Fixed ratio between two UoMs | ✔ Item UoM table | ✔ reused |
| Variable ratio per transaction | ✗ | ✔ DUoM field on lines |
| Always-variable (ratio never fixed) | ✗ | ✔ item setup flag |
| Per-lot real ratio | ✗ | ✔ lot-level ratio field |
| Second qty on document lines | ✗ | ✔ table extension |
| Second qty on value/item ledger entries | ✗ | ✔ table extension |
| Warehouse pick/put-away with two qtys | ✗ | ✔ warehouse extension |

## Target Modules

- **Purchasing** — purchase orders, receipts, invoices, credit memos
- **Sales** — sales orders, shipments, invoices, credit memos, return orders
- **Inventory** — item ledger entries, value entries, item journals, physical inventory
- **Warehouse** — warehouse receipts, shipments, put-away, pick, warehouse entries

## Exclusions

The following BC modules are **permanently out of scope** for this project:

- Manufacturing (production orders, routings, output)
- Projects (job planning lines, job ledger entries)
- Service Management (service orders, service items)

Scale integration (automatic weight capture from hardware) is also out of scope for all phases.
