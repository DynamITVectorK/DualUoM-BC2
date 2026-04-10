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
  Translations/
    DualUoM-BC.en-US.xlf   English reference translation file
    DualUoM-BC.es-ES.xlf   Spanish translation file

test/         Test extension
  app.json    Test app manifest (depends on app/)
  src/
    codeunit/     AL test codeunits (testability framework)
    permissionset/ AL test permission sets (mandatory — see "Permission set rule")

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
  07-localization.md        XLF workflow, terminology glossary, translation rules
  ci-cost-decisions.md      CI cost-saving choices
```

## Idioma del proyecto

El idioma oficial del proyecto es el **español**. Toda documentación nueva, comentarios en issues/PRs, mensajes de commit y respuestas del agente Copilot deben escribirse en español. La documentación ya existente escrita en otro idioma no requiere ser retrotraducida salvo que se modifique de forma sustancial.

Los identificadores AL (nombres de objetos, campos, procedimientos, variables) y las APIs de Business Central permanecen en inglés, siguiendo las convenciones de la plataforma.

> Esta regla no afecta al contenido de los archivos XLF ni a las cadenas de origen (`<source>`) en los archivos de traducción, que siempre deben mantenerse en inglés como idioma de referencia (en-US).

---

## AL coding conventions

- Object ID range: **50100–50199** (app), **50200–50299** (tests)
- Follow Microsoft AL coding guidelines and PascalCase naming
- Every new AL feature must have a corresponding test codeunit in `test/src/codeunit/`
- Use `PerTenantExtensionCop`, `CodeCop`, and `UICop` analysers — zero warnings policy
- Use `NoImplicitWith` — never rely on implicit `with` scoping
- Modules in scope: Sales, Purchase, Inventory, Warehouse
- Modules **out of scope**: Manufacturing, Projects, Service

## Localization rule (mandatory)

Every user-facing text in the extension **must** be translation-ready. The supported languages are **English (en-US)** and **Spanish (es-ES)**.

- Declare all user-visible strings (captions, tooltips, errors, confirmations, notifications, enum values) as `Label` variables or `Caption`/`ToolTip` properties — never as hardcoded string literals.
- Every `Label` declaration **must** include a `Comment` property that describes placeholders (e.g. `Comment = '%1 = Item No.'`) or states `'Validation error; no placeholders.'` when there are none.
- The `TranslationFile` feature is enabled in `app.json`. Translation files live in `app/Translations/`:
  - `DualUoM-BC.en-US.xlf` — English reference
  - `DualUoM-BC.es-ES.xlf` — Spanish translations
- **Whenever** a caption, tooltip, label, error, confirmation, notification, or enum value is added or changed, **both** XLF files must be updated in the same PR.
- A feature is **not considered done** until all new or modified user-visible strings appear (translated) in both XLF files.
- See `docs/07-localization.md` for the full XLF workflow, terminology glossary, and examples.

## Permission set rule (mandatory)

Any new table or other securable object that requires permission coverage **must** be accompanied by a corresponding permission set update in the **same issue/PR**. Specifically:

- Every new `table` object must have a matching `tabledata` entry (RIMD or appropriate subset) in a `permissionset` object under `app/src/permissionset/`.
- The permission set file must follow the naming convention `<Name>.PermissionSet.al` and use the project ID range (50100–50199).
- The project-wide permission set is `permissionset 50100 "DUoM - All"` (`app/src/permissionset/DUoMAll.PermissionSet.al`). Add new table entries there; create additional permission sets only if different access levels are needed.
- Failure to include this causes build error `PTE0004` — a zero-tolerance policy applies.

### Test app permission set (mandatory)

The test app **must** maintain its own permission set file at `test/src/permissionset/DUoMTestAll.PermissionSet.al` (`permissionset 50200 "DUoM - Test All"`).

**Every time** a new extension table is added to the production app:

1. Add a `tabledata ... = RIMD` entry to `app/src/permissionset/DUoMAll.PermissionSet.al` (production app).
2. **Also** add the same `tabledata ... = RIMD` entry to `test/src/permissionset/DUoMTestAll.PermissionSet.al` (test app).

**Why both?** The test app runs under its own app context. When test code inserts directly into an extension table *or* calls a production codeunit that inserts (indirect insert), both operations require the test app's own permission set to declare the corresponding table permission.

**Never use** the `Permissions` property on codeunit objects. This is deprecated (AL0246) and does **not** cover indirect inserts (when a test codeunit calls a production codeunit that writes to the table). Always use a `permissionset` object instead.

```al
// ✅ CORRECTO — test/src/permissionset/DUoMTestAll.PermissionSet.al
permissionset 50200 "DUoM - Test All"
{
    Assignable = true;
    Caption = 'DualUoM - Test All';

    Permissions =
        tabledata "DUoM Item Setup" = RIMD;
        // Añadir aquí cada nueva tabla de extensión
}

// ❌ PROHIBIDO — Permissions property en codeunit (AL0246, no cubre IndirectInsert)
codeunit 50202 "DUoM Item Card Opening Tests"
{
    Subtype = Test;
    Permissions = tabledata "DUoM Item Setup" = RIMD;  // <- NUNCA HACER ESTO
    ...
}
```

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

## AL Test Data Creation — Mandatory Standard

Never use manual `Init()` + `Insert(false)` to create test records.
Always use Microsoft's standard AL test libraries:

| Entity            | Library call                                      |
|-------------------|---------------------------------------------------|
| Item              | `LibraryInventory.CreateItem(Item)`               |
| Vendor            | `LibraryPurchase.CreateVendor(Vendor)`            |
| Customer          | `LibrarySales.CreateCustomer(Customer)`           |
| Purchase Header   | `LibraryPurchase.CreatePurchaseHeader(...)`       |
| Purchase Line     | `LibraryPurchase.CreatePurchaseLine(...)`         |
| Sales Header      | `LibrarySales.CreateSalesHeader(...)`             |
| Sales Line        | `LibrarySales.CreateSalesLine(...)`               |
| Item Journal Line | `LibraryInventory.CreateItemJournalLine(...)`     |

Declare the library codeunit variables as:
```al
LibraryInventory: Codeunit "Library - Inventory";
LibraryPurchase:  Codeunit "Library - Purchase";
LibrarySales:     Codeunit "Library - Sales";
```

`Init()` without `Insert()` remains valid for purely in-memory records that are never persisted to the database (e.g. testing field validation logic in isolation).

This rule applies to ALL test codeunits in the project without exception.

## CI/CD — cost-first approach

Every workflow file uses **only** `workflow_dispatch:` trigger.
See `docs/ci-cost-decisions.md` for the full rationale.

Do NOT add automatic triggers (`push:`, `pull_request:`, `schedule:`) to any workflow.
