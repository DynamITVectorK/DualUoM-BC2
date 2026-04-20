# Testing Strategy — DualUoM-BC

## Mandatory TDD

Test-Driven Development is **mandatory** for this project. No production AL code is
written without a failing test that defines the expected behavior first.

Workflow for every new feature:

1. Write a test codeunit with one or more `[Test]` procedures that fail
2. Write the minimum production code to make the tests pass
3. Refactor if needed, keeping all tests green
4. Open the PR — CI must show green `TestResults.xml` before merge is considered

---

## Test Types

### Unit Tests

- Test individual codeunit procedures in isolation
- No dependency on BC document posting flows where avoidable
- Fast, deterministic, no external state
- Example: `DUoM Calc Engine Tests` verifying that `ComputeSecondQty` returns the
  correct value for each conversion mode with boundary inputs

### Integration Tests

- Test a complete document flow from creation through posting
- Verify that `Item Ledger Entry` contains the expected second quantity after posting
- Use BC standard library helpers (`Library - Purchase`, `Library - Sales`, etc.) where
  available in the test app
- Acceptable to be slower; run as part of full CI only

### Regression Tests

- Added whenever a bug is fixed
- Named to reference the issue that caused the bug
- Must stay in the test suite permanently

---

## Test Codeunit Conventions

- One test codeunit per production codeunit (minimum)
- Object IDs in range **50200–50299**
- Use `[Test]` attribute on every test procedure
- Use `[HandlerFunctions(...)]` and modal page handlers for UI-triggered flows
- Use the `// [GIVEN] / [WHEN] / [THEN]` comment pattern in every test procedure
- Use `Library Assert` (`Codeunit "Library Assert"`) for all assertions — no custom assert helpers

---

## Norma de creación de datos de test (obligatoria)

En el código de tests, **si existe un helper estándar de Microsoft `Library - *` que cubra
razonablemente el caso, debe usarse ese helper** en lugar de implementar lógica manual o un
helper propio equivalente. Nunca usar `Init()` + `Insert(false)` manual sobre tablas estándar
de BC cuando existe un helper de librería equivalente.

### Jerarquía de decisión

1. **Primero**: usar helper estándar `Library - *`.
2. **Si no existe helper estándar suficiente**: usar helper propio reutilizable del proyecto (`DUoM Test Helpers`, codeunit 50208).
3. **Si tampoco existe helper propio**: crear uno nuevo en la capa de tests, nunca en la app productiva.
4. **Toda excepción** debe quedar justificada en comentario en el propio código.

### Helpers disponibles

| Entity              | Helper recomendado                                            |
|---------------------|---------------------------------------------------------------|
| Item                | `LibraryInventory.CreateItem(Item)`                          |
| Item Variant (auto) | `LibraryInventory.CreateItemVariant(ItemVariant, ItemNo)`    |
| Item Variant (code) | `DUoMTestHelpers.CreateItemVariantWithCode(ItemNo, Code, ItemVariant)` |
| Vendor              | `LibraryPurchase.CreateVendor(Vendor)`                       |
| Customer            | `LibrarySales.CreateCustomer(Customer)`                      |
| Purchase Header     | `LibraryPurchase.CreatePurchaseHeader(...)`                  |
| Purchase Line       | `LibraryPurchase.CreatePurchaseLine(...)`                    |
| Sales Header        | `LibrarySales.CreateSalesHeader(...)`                        |
| Sales Line          | `LibrarySales.CreateSalesLine(...)`                          |
| Item Journal Line   | `LibraryInventory.CreateItemJournalLine(...)`                |
| DUoM Item Setup     | `DUoMTestHelpers.CreateItemSetup(...)`                       |
| DUoM Variant Setup  | `DUoMTestHelpers.CreateVariantSetup(...)`                    |

### Excepciones justificadas (documentadas en código)

- `Init()` sin `Insert()` es válido para registros puramente en memoria (p.ej. test de validación de campos en aislamiento).
- `WhseEntry.Init()` + `Insert(false)` es aceptable para crear entradas de almacén en tests de condición de editabilidad, porque no existe helper estándar sin configuración completa de almacén. Debe documentarse en comentario en el test.
- `DUoMTestHelpers.CreateItemVariantWithCode` usa `LibraryInventory.CreateItemVariant` internamente y después renombra al código específico. Se justifica porque los tests DUoM requieren códigos con semántica de negocio determinista (`'ROMANA'`, `'ICEBERG'`, `'GRANEL'`).
- Los helpers propios `DUoMTestHelpers.CreateItemSetup` y `CreateVariantSetup` crean registros de tablas propias de la extensión sin equivalente estándar de Microsoft.

---

Example structure:

```al
codeunit 50201 "DUoM Calc Engine Tests"
{
    Subtype = Test;

    [Test]
    procedure ComputeSecondQty_Fixed_ReturnsProduct()
    var
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with fixed conversion ratio 1.25
        // [WHEN] ComputeSecondQty is called with Qty = 10
        // [THEN] Result is 12.5
        LibraryAssert.AreEqual(12.5, ComputeFixed(10, 1.25), 'Fixed ratio calculation failed');
    end;
}
```

---

## Permisos en el app de test (obligatorio)

El app de test corre bajo su propio contexto de aplicación. Cualquier codeunit de test que acceda a una tabla de extensión — ya sea insertando directamente o llamando a una codeunit de producción que inserta — necesita que el **app de test** tenga el permiso correspondiente declarado en su propio permission set.

### Regla

**Nunca uses** la propiedad `Permissions` en objetos codeunit. Está deprecada (diagnóstico AL0246) y además **no cubre los accesos indirectos** (`IndirectInsert`, `IndirectModify`, etc.): cuando un test llama a una codeunit de producción que escribe en una tabla, BC evalúa los permisos del caller (el app de test), no los del callee.

**Siempre usa** el permission set centralizado del app de test: `test/src/permissionset/DUoMTestAll.PermissionSet.al`.

### Proceso al añadir una nueva tabla de extensión

Cuando se crea una nueva tabla en `app/src/table/`, el mismo PR **debe**:

1. Añadir `tabledata "<NombreTabla>" = RIMD;` en `app/src/permissionset/DUoMAll.PermissionSet.al`.
2. Añadir `tabledata "<NombreTabla>" = RIMD;` en `test/src/permissionset/DUoMTestAll.PermissionSet.al`.

Si se omite el paso 2, los tests que toquen esa tabla fallarán en CI con el error:
```
Sorry, the current permissions prevented the action.
(TableData <ID> <NombreTabla> IndirectInsert: DualUoM-BC.Test)
```

### Ejemplo correcto

```al
// ✅ app/src/permissionset/DUoMAll.PermissionSet.al
permissionset 50100 "DUoM - All"
{
    Assignable = true;
    Caption = 'DualUoM - All';
    Permissions =
        tabledata "DUoM Item Setup" = RIMD;
        // + nuevas tablas aquí
}

// ✅ test/src/permissionset/DUoMTestAll.PermissionSet.al
permissionset 50200 "DUoM - Test All"
{
    Assignable = true;
    Caption = 'DualUoM - Test All';
    Permissions =
        tabledata "DUoM Item Setup" = RIMD;
        // + las mismas tablas que en DUoM - All
}

// ❌ PROHIBIDO — deprecated AL0246, no cubre IndirectInsert
codeunit 50202 "DUoM Item Card Opening Tests"
{
    Subtype = Test;
    Permissions = tabledata "DUoM Item Setup" = RIMD;  // NUNCA USAR
    ...
}
```

---

## Core Business Scenarios (Must Be Covered Before Broadening Scope)

The following scenarios must have passing tests before any Phase 2 work starts:

1. **Fixed conversion** — second qty computed correctly from first qty and ratio
2. **Variable conversion** — user can override default ratio; stored correctly
3. **Always-variable conversion** — second qty accepted as manual input only
4. **Purchase posting** — ILE contains correct second qty after posting a purchase receipt
5. **Sales posting** — ILE contains correct second qty after posting a sales shipment
6. **Item journal posting** — ILE contains correct second qty after posting an item journal line
7. **DUoM disabled item** — no DUoM fields affect standard posting flow
8. **Purchase invoice/credit memo posting** — `Purch. Inv. Line` and `Purch. Cr. Memo Line` contain correct DUoM fields after posting
9. **Sales invoice/credit memo posting** — `Sales Invoice Line` and `Sales Cr.Memo Line` contain correct DUoM fields after posting
10. **Variant override — resolver hierarchy** — when a variant has a setup record in `DUoM Item Variant Setup`, `GetEffectiveSetup` returns the variant's fields instead of the item defaults
11. **Variant override — fallback to item** — when no variant setup record exists, `GetEffectiveSetup` returns the item-level fields
12. **Variant Code change on purchase line** — changing `Variant Code` on a purchase line with an existing quantity resets and recomputes `DUoM Second Qty` using the new variant's effective setup
13. **Variant Code change on sales line** — same behavior as scenario 12 for sales lines

---

## CI Validation

- All tests run via AL-Go on `windows-latest` runner using BC Docker container
- `TestResults.xml` must be present and green for a run to be considered passing
- Workflows use `workflow_dispatch` only — see `docs/ci-cost-decisions.md`
- No test may be skipped or commented out to make CI pass
