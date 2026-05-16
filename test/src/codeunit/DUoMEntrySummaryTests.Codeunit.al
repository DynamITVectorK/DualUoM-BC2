/// <summary>
/// Tests TDD para la integración DUoM en Entry Summary (tabla de Item Tracking Summary).
///
/// Escenarios cubiertos:
///   T01 — Validate(Lot No.) aplica ratio de lote y calcula DUoM Second Qty.
///   T02 — Validate(Selected Quantity) recalcula DUoM Second Qty con el ratio actual.
///   T03 — Modo Fixed + Validate(Serial No.) aplica ratio fijo.
///   T04 — Sin contexto resoluble: no falla, no calcula.
///
/// Modelo real (BC 27):
///   Entry Summary no tiene campos "Item No." ni "Variant Code".
///   El contexto de artículo se resuelve mediante DUoM Entry Summary Mgt. (50132),
///   que usa Table ID + Entry No. para buscar en Item Ledger Entry o Reservation Entry.
///   Los tests usan CreateMinimalILEForEntrySummaryTest para crear el ILE necesario.
/// </summary>
codeunit 50231 "DUoM Entry Summary Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure EntrySummary_Variable_LotValidate_PrefillsDUoMFields()
    var
        Item: Record Item;
        ILE: Record "Item Ledger Entry";
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

        // [GIVEN] ILE mínimo para el artículo, con el lote asignado (contexto resoluble)
        DUoMTestHelpers.CreateMinimalILEForEntrySummaryTest(Item."No.", '', 'LOT-ES-01', ILE);

        // [GIVEN] Entry Summary apuntando al ILE (Table ID + Entry No. como FK real)
        EntrySummary.Init();
        EntrySummary."Entry No." := ILE."Entry No.";
        EntrySummary."Table ID" := Database::"Item Ledger Entry";
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
        ILE: Record "Item Ledger Entry";
        EntrySummary: Record "Entry Summary";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Variable con ratio ya asignado
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] ILE mínimo para el artículo (contexto resoluble)
        DUoMTestHelpers.CreateMinimalILEForEntrySummaryTest(Item."No.", '', '', ILE);

        // [GIVEN] Entry Summary apuntando al ILE con ratio preexistente
        EntrySummary.Init();
        EntrySummary."Entry No." := ILE."Entry No.";
        EntrySummary."Table ID" := Database::"Item Ledger Entry";
        EntrySummary."DUoM Ratio" := 1.5;
        EntrySummary."Selected Quantity" := 2;
        EntrySummary."DUoM Second Qty" := 3;
        // Entry Summary."Selected Quantity" ejecuta validación estándar y no permite seleccionar
        // más cantidad que la disponible. El test debe preparar el buffer estándar antes de
        // validar el campo para que también se dispare el subscriber DUoM real.
        EntrySummary."Total Available Quantity" := 10;

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
        ILE: Record "Item Ledger Entry";
        EntrySummary: Record "Entry Summary";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Fixed
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] ILE mínimo para el artículo (contexto resoluble)
        DUoMTestHelpers.CreateMinimalILEForEntrySummaryTest(Item."No.", '', '', ILE);

        // [GIVEN] Entry Summary apuntando al ILE
        EntrySummary.Init();
        EntrySummary."Entry No." := ILE."Entry No.";
        EntrySummary."Table ID" := Database::"Item Ledger Entry";
        EntrySummary."Selected Quantity" := 10;

        // [WHEN] Se valida un serial en Entry Summary
        EntrySummary.Validate("Serial No.", 'SN-ES-01');

        // [THEN] Se aplica ratio fijo y segunda cantidad recalculada
        LibraryAssert.AreEqual(0.8, EntrySummary."DUoM Ratio",
            'T03: En modo Fixed debe aplicarse el ratio fijo del setup.');
        LibraryAssert.AreNearlyEqual(8, EntrySummary."DUoM Second Qty", 0.001,
            'T03: DUoM Second Qty debe ser Selected Quantity × Fixed Ratio.');
    end;

    [Test]
    procedure EntrySummary_NoResolvableContext_NoCalculationNoError()
    var
        EntrySummary: Record "Entry Summary";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Entry Summary sin contexto resoluble (Table ID = 0, Entry No. = 0)
        EntrySummary.Init();
        EntrySummary."Entry No." := 0;
        EntrySummary."Table ID" := 0;
        EntrySummary."Selected Quantity" := 5;

        // [WHEN] Se valida el lote sin contexto resoluble — no debe lanzar error
        EntrySummary.Validate("Lot No.", 'LOT-NO-CONTEXT');

        // [THEN] DUoM Ratio y DUoM Second Qty permanecen en 0 (sin cálculo)
        LibraryAssert.AreEqual(0, EntrySummary."DUoM Ratio",
            'T04: Sin contexto resoluble DUoM Ratio debe quedar en 0.');
        LibraryAssert.AreEqual(0, EntrySummary."DUoM Second Qty",
            'T04: Sin contexto resoluble DUoM Second Qty debe quedar en 0.');
    end;
}
