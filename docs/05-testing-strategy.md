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

## Core Business Scenarios (Must Be Covered Before Broadening Scope)

The following scenarios must have passing tests before any Phase 2 work starts:

1. **Fixed conversion** — second qty computed correctly from first qty and ratio
2. **Variable conversion** — user can override default ratio; stored correctly
3. **Always-variable conversion** — second qty accepted as manual input only
4. **Purchase posting** — ILE contains correct second qty after posting a purchase receipt
5. **Sales posting** — ILE contains correct second qty after posting a sales shipment
6. **Item journal posting** — ILE contains correct second qty after posting an item journal line
7. **DUoM disabled item** — no DUoM fields affect standard posting flow

---

## CI Validation

- All tests run via AL-Go on `windows-latest` runner using BC Docker container
- `TestResults.xml` must be present and green for a run to be considered passing
- Workflows use `workflow_dispatch` only — see `docs/ci-cost-decisions.md`
- No test may be skipped or commented out to make CI pass
