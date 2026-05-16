/// <summary>
/// Tests TDD para la integración DUoM en Entry Summary (tabla de Item Tracking Summary).
///
/// Escenarios cubiertos:
///   T01 — Validate(Lot No.) aplica ratio de lote y calcula DUoM Second Qty.
///   T02 — Validate(Selected Quantity) recalcula DUoM Second Qty con el ratio actual.
///   T03 — Modo Fixed + Validate(Serial No.) aplica ratio fijo.
/// </summary>
codeunit 50231 "DUoM Entry Summary Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure EntrySummary_Variable_LotValidate_PrefillsDUoMFields()
    var
        Item: Record Item;
        EntrySummary: Record "Entry Summary";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Variable con ratio de lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT-ES-01', 1.2);

        EntrySummary.Init();
        EntrySummary."Item No." := Item."No.";
        EntrySummary."Selected Quantity" := 5;

        // [WHEN] Se valida el lote
        EntrySummary.Validate("Lot No.", 'LOT-ES-01');

        // [THEN] Ratio y segunda cantidad quedan precalculados
        LibraryAssert.AreEqual(1.2, EntrySummary."DUoM Ratio",
            'T01: DUoM Ratio debe ser el ratio configurado para el lote.');
        LibraryAssert.AreNearlyEqual(6, EntrySummary."DUoM Second Qty", 0.001,
            'T01: DUoM Second Qty debe ser Selected Quantity × DUoM Ratio.');
    end;

    [Test]
    procedure EntrySummary_SelectedQtyValidate_RecalculatesSecondQty()
    var
        Item: Record Item;
        EntrySummary: Record "Entry Summary";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Variable con ratio ya asignado
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);

        EntrySummary.Init();
        EntrySummary."Item No." := Item."No.";
        EntrySummary."DUoM Ratio" := 1.5;
        EntrySummary."Selected Quantity" := 2;
        EntrySummary."DUoM Second Qty" := 3;

        // [WHEN] Se cambia la cantidad seleccionada
        EntrySummary.Validate("Selected Quantity", 7);

        // [THEN] Se recalcula DUoM Second Qty
        LibraryAssert.AreNearlyEqual(10.5, EntrySummary."DUoM Second Qty", 0.001,
            'T02: DUoM Second Qty debe recalcularse con la nueva cantidad seleccionada.');
    end;

    [Test]
    procedure EntrySummary_Fixed_SerialValidate_UsesFixedRatio()
    var
        Item: Record Item;
        EntrySummary: Record "Entry Summary";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Fixed
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Fixed, 0.8);

        EntrySummary.Init();
        EntrySummary."Item No." := Item."No.";
        EntrySummary."Selected Quantity" := 10;

        // [WHEN] Se valida un serial en Entry Summary
        EntrySummary.Validate("Serial No.", 'SN-ES-01');

        // [THEN] Se aplica ratio fijo y segunda cantidad recalculada
        LibraryAssert.AreEqual(0.8, EntrySummary."DUoM Ratio",
            'T03: En modo Fixed debe aplicarse el ratio fijo del setup.');
        LibraryAssert.AreNearlyEqual(8, EntrySummary."DUoM Second Qty", 0.001,
            'T03: DUoM Second Qty debe ser Selected Quantity × Fixed Ratio.');
    end;
}
