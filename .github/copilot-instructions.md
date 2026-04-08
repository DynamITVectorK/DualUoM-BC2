# DualUoM-BC — Copilot Instructions

## Project purpose

This repository contains the **DualUoM-BC** Business Central SaaS extension.
The goal is to add dual unit of measure (UoM) support to all BC modules
**except** Manufacturing, Projects and Service.

Business example: purchase 10 KG of lettuce received as 8 pieces. Both quantities must
be stored, posted and tracked, with support for variable and lot-specific ratios.

Tech stack: AL · AL-Go for GitHub · Business Central SaaS (BC 27 / runtime 15) · TDD

## Repository layout

```
app/          Main extension (PTE)
  app.json    Extension manifest — platform 27, runtime 15, target Cloud
  src/
    enum/             AL enum objects
    table/            AL table objects
    tableextension/   AL tableextension objects
    codeunit/         AL codeunit objects
    page/             AL page objects
    pageextension/    AL pageextension objects
    permissionset/    AL permissionset objects
    report/           AL report objects

test/         Test extension
  app.json    Test app manifest (depends on app/)
  src/
    codeunit/ AL test codeunits (testability framework)

.github/
  AL-Go-Settings.json   Repository-level AL-Go configuration
  workflows/            GitHub Actions — ALL manual (workflow_dispatch) only
  copilot-instructions.md  (this file)

docs/
  00-vision.md              Project objective, business need, target modules
  01-scope-mvp.md           MVP vs later phases vs out of scope
  02-functional-design.md   Conversion modes, propagation, lot ratios
  03-technical-architecture.md  Extension design, events, SaaS principles
  05-testing-strategy.md    TDD rules, test types, CI validation
  06-backlog.md             Ordered delivery backlog
  ci-cost-decisions.md      CI cost-saving choices
```

## AL coding conventions

- Object ID range: **50100–50199** (app), **50200–50299** (tests)
- Follow Microsoft AL coding guidelines and PascalCase naming
- Every new AL feature must have a corresponding test codeunit in `test/src/codeunit/`
- Use `PerTenantExtensionCop`, `CodeCop`, and `UICop` analysers — zero warnings policy
- Use `NoImplicitWith` — never rely on implicit `with` scoping
- Modules in scope: Sales, Purchase, Inventory, Warehouse
- Modules **out of scope**: Manufacturing, Projects, Service

## Permission set rule (mandatory)

Any new table or other securable object that requires permission coverage **must** be accompanied by a corresponding permission set update in the **same issue/PR**. Specifically:

- Every new `table` object must have a matching `tabledata` entry (RIMD or appropriate subset) in a `permissionset` object under `app/src/permissionset/`.
- The permission set file must follow the naming convention `<Name>.PermissionSet.al` and use the project ID range (50100–50199).
- The project-wide permission set is `permissionset 50100 "DUoM - All"` (`app/src/permissionset/DUoMAll.PermissionSet.al`). Add new table entries there; create additional permission sets only if different access levels are needed.
- Failure to include this causes build error `PTE0004` — a zero-tolerance policy applies.

## Business Central SaaS constraints

- Extension-only: no base app modifications, no direct SQL, no RPC
- All standard BC integration must go through published integration events
- No intrusive patterns: no global state, no `OnBeforeInsert` that blocks posting flows
- No deprecated APIs — always use current BC 27 patterns
- SaaS deployments are cloud-only; no OnPrem-specific code
- Do not assume access to Docker or file system at runtime

## Delivery rules

- Implement only what the current issue explicitly requires — no speculative scope
- Every issue must include passing automated tests before it is considered done
- Follow the backlog order in `docs/06-backlog.md` — later issues depend on earlier ones
- Do not implement warehouse or lot logic until the relevant Phase 2 issues are opened
- Do not implement costing or value entry logic unless explicitly scoped

## Testing rules

- TDD is mandatory: write a failing test first, then the production code
- Test codeunits use `Subtype = Test` and `[Test]` attribute per procedure
- Use the `// [GIVEN] / [WHEN] / [THEN]` comment pattern
- Use `Library Assert` (Microsoft) for all assertions
- No test may be skipped or disabled to make CI pass

## CI/CD — cost-first approach

Every workflow file uses **only** `workflow_dispatch:` trigger.
See `docs/ci-cost-decisions.md` for the full rationale.

Do NOT add automatic triggers (`push:`, `pull_request:`, `schedule:`) to any workflow.
