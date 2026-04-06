# DualUoM-BC — Copilot Instructions

## Project purpose

This repository contains the **DualUoM-BC** Business Central SaaS extension.
The goal is to add dual unit of measure (UoM) support to all BC modules
**except** Manufacturing, Projects and Service.

Tech stack: AL · AL-Go for GitHub · Business Central SaaS (latest) · TDD

## Repository layout

```
app/          Main extension (PTE)
  app.json    Extension manifest — platform 25, runtime 13, target Cloud
  src/
    enum/             AL enum objects
    table/            AL table objects
    tableextension/   AL tableextension objects
    codeunit/         AL codeunit objects
    page/             AL page objects
    pageextension/    AL pageextension objects
    report/           AL report objects
  .vscode/
    launch.json       Local dev launch config
    settings.json     AL code-analysis settings

test/         Test extension
  app.json    Test app manifest (depends on app/)
  src/
    codeunit/ AL test codeunits (testability framework)

.github/
  AL-Go-Settings.json   Repository-level AL-Go configuration
  workflows/            GitHub Actions — ALL manual (workflow_dispatch) only
  copilot-instructions.md  (this file)

docs/
  ci-cost-decisions.md  Explanation of every CI cost-saving choice
```

## AL coding conventions

- Object ID range: **50000–50099** (app), **50100–50199** (tests)
- Follow Microsoft AL coding guidelines and PascalCase naming
- Every new AL feature must have a corresponding test codeunit in `test/src/codeunit/`
- Use `PerTenantExtensionCop`, `CodeCop`, and `UICop` analysers — zero warnings policy
- Modules in scope: Sales, Purchase, Inventory, Warehouse
- Modules **out of scope**: Manufacturing, Projects, Service

## CI/CD — cost-first approach

Every workflow file uses **only** `workflow_dispatch:` trigger.
See `docs/ci-cost-decisions.md` for the full rationale.

Do NOT add automatic triggers (`push:`, `pull_request:`, `schedule:`) to any workflow.
