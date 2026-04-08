# DualUoM-BC

**Dual Unit of Measure extension for Microsoft Dynamics 365 Business Central SaaS.**

## What This Is

A Per-Tenant Extension (PTE) that enables items to carry two independent quantities
simultaneously through purchasing, sales, inventory and warehouse flows.

**Example:** 10 KG of lettuce received as 8 pieces. Both quantities are stored, posted
and tracked — even when the ratio varies by lot.

## Tech Stack

- Language: **AL**
- Platform: **Business Central SaaS** (BC 27 / runtime 15)
- CI/CD: **AL-Go for GitHub** (manual `workflow_dispatch` triggers only)
- Testing: **AL Testability Framework** — TDD mandatory

## Quick Links

| Document | Description |
|---|---|
| [Vision](docs/00-vision.md) | Project objective, business need, target modules |
| [Scope & MVP](docs/01-scope-mvp.md) | What is in MVP, Phase 2, and out of scope |
| [Functional Design](docs/02-functional-design.md) | Item setup, conversion modes, propagation |
| [Technical Architecture](docs/03-technical-architecture.md) | Extension design, events, SaaS principles |
| [Testing Strategy](docs/05-testing-strategy.md) | TDD rules, test types, CI validation |
| [Backlog](docs/06-backlog.md) | Ordered delivery backlog |
| [CI Cost Decisions](docs/ci-cost-decisions.md) | Why CI is configured the way it is |

## Modules in Scope

- Purchasing · Sales · Inventory · Warehouse

## Modules Out of Scope

- Manufacturing · Projects · Service Management

## Object ID Ranges

| Extension | Range |
|---|---|
| App (`app/`) | 50100 – 50199 |
| Tests (`test/`) | 50200 – 50299 |
