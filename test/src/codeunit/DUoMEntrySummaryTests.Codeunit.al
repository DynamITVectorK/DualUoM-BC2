/// <summary>
/// Tests TDD para la integración DUoM en Entry Summary (tabla de Item Tracking Summary).
///
/// Escenarios cubiertos:
///   T01 — Validate(Lot No.) aplica ratio de lote y calcula DUoM Second Qty.
///   T02 — Validate(Selected Quantity) recalcula DUoM Second Qty con el ratio actual.
///   T03 — Modo Fixed + Validate(Serial No.) aplica ratio fijo.
///   T04 — Sin contexto resoluble: no falla, no calcula.
///   T05 — PopulateDUoMForEntrySummary en modo Fixed: ratio y segunda cantidad desde disponibilidad.
///   T06 — PopulateDUoMForEntrySummary en modo Variable con ratio de lote: disponibilidad.
///   T07 — PopulateDUoMForEntrySummary: Selected Quantity prevalece sobre disponibilidad.
///   T08 — PopulateDUoMForEntrySummary sin contexto resoluble: no falla, campos en 0.
///   T09 — PopulateDUoMForEntrySummary en modo Variable sin ratio de lote: no falla.
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

    [Test]
    procedure EntrySummary_LoadInitialLine_FixedMode_PopulatesRatioAndAvailableSecondQty()
    var
        Item: Record Item;
        ILE: Record "Item Ledger Entry";
        EntrySummary: Record "Entry Summary";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Fixed con ratio 0.5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Fixed, 0.5);

        // [GIVEN] ILE mínimo para el artículo (contexto resoluble)
        DUoMTestHelpers.CreateMinimalILEForEntrySummaryTest(Item."No.", '', '', ILE);

        // [GIVEN] Entry Summary con cantidad disponible 100 y sin cantidad seleccionada
        EntrySummary.Init();
        EntrySummary."Entry No." := ILE."Entry No.";
        EntrySummary."Table ID" := Database::"Item Ledger Entry";
        EntrySummary."Total Available Quantity" := 100;
        EntrySummary."Selected Quantity" := 0;

        // [WHEN] Se puebla DUoM para la línea (carga inicial de página)
        DUoMEntrySummaryMgt.PopulateDUoMForEntrySummary(EntrySummary);

        // [THEN] Ratio fijo y segunda cantidad basada en disponibilidad
        LibraryAssert.AreEqual(0.5, EntrySummary."DUoM Ratio",
            'T05: DUoM Ratio debe ser el ratio fijo del setup.');
        LibraryAssert.AreNearlyEqual(50, EntrySummary."DUoM Second Qty", 0.001,
            'T05: DUoM Second Qty debe ser Total Available Quantity × Fixed Ratio.');
    end;

    [Test]
    procedure EntrySummary_LoadInitialLine_VariableLotRatio_PopulatesRatioAndAvailableSecondQty()
    var
        Item: Record Item;
        ILE: Record "Item Ledger Entry";
        EntrySummary: Record "Entry Summary";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Variable con ratio de lote 1.3
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT-VAR-01', 1.3);

        // [GIVEN] ILE mínimo para el artículo con el lote (contexto resoluble)
        DUoMTestHelpers.CreateMinimalILEForEntrySummaryTest(Item."No.", '', 'LOT-VAR-01', ILE);

        // [GIVEN] Entry Summary con cantidad disponible 80 y sin cantidad seleccionada
        EntrySummary.Init();
        EntrySummary."Entry No." := ILE."Entry No.";
        EntrySummary."Table ID" := Database::"Item Ledger Entry";
        EntrySummary."Lot No." := 'LOT-VAR-01';
        EntrySummary."Total Available Quantity" := 80;
        EntrySummary."Selected Quantity" := 0;

        // [WHEN] Se puebla DUoM para la línea (carga inicial de página)
        DUoMEntrySummaryMgt.PopulateDUoMForEntrySummary(EntrySummary);

        // [THEN] Ratio de lote y segunda cantidad basada en disponibilidad
        LibraryAssert.AreEqual(1.3, EntrySummary."DUoM Ratio",
            'T06: DUoM Ratio debe ser el ratio del lote.');
        LibraryAssert.AreNearlyEqual(104, EntrySummary."DUoM Second Qty", 0.001,
            'T06: DUoM Second Qty debe ser Total Available Quantity × Lot Ratio.');
    end;

    [Test]
    procedure EntrySummary_SelectedQty_WinsOverAvailableQty_ForSecondQty()
    var
        Item: Record Item;
        ILE: Record "Item Ledger Entry";
        EntrySummary: Record "Entry Summary";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Fixed con ratio 2
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Fixed, 2);

        // [GIVEN] ILE mínimo para el artículo (contexto resoluble)
        DUoMTestHelpers.CreateMinimalILEForEntrySummaryTest(Item."No.", '', '', ILE);

        // [GIVEN] Entry Summary con cantidad disponible 200 y cantidad seleccionada 30
        EntrySummary.Init();
        EntrySummary."Entry No." := ILE."Entry No.";
        EntrySummary."Table ID" := Database::"Item Ledger Entry";
        EntrySummary."Total Available Quantity" := 200;
        EntrySummary."Selected Quantity" := 30;

        // [WHEN] Se puebla DUoM para la línea
        DUoMEntrySummaryMgt.PopulateDUoMForEntrySummary(EntrySummary);

        // [THEN] DUoM Second Qty se calcula sobre la cantidad seleccionada, no la disponible
        LibraryAssert.AreEqual(2, EntrySummary."DUoM Ratio",
            'T07: DUoM Ratio debe ser el ratio fijo del setup.');
        LibraryAssert.AreNearlyEqual(60, EntrySummary."DUoM Second Qty", 0.001,
            'T07: DUoM Second Qty debe ser Selected Quantity × Ratio, no Total Available.');
    end;

    [Test]
    procedure EntrySummary_NoResolvableContext_PopulateDUoM_NoError_FieldsRemainZero()
    var
        EntrySummary: Record "Entry Summary";
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Entry Summary sin contexto resoluble
        EntrySummary.Init();
        EntrySummary."Entry No." := 0;
        EntrySummary."Table ID" := 0;
        EntrySummary."Total Available Quantity" := 50;
        EntrySummary."Selected Quantity" := 0;

        // [WHEN] Se puebla DUoM para la línea — no debe lanzar error
        DUoMEntrySummaryMgt.PopulateDUoMForEntrySummary(EntrySummary);

        // [THEN] DUoM Ratio y DUoM Second Qty permanecen en 0
        LibraryAssert.AreEqual(0, EntrySummary."DUoM Ratio",
            'T08: Sin contexto resoluble DUoM Ratio debe quedar en 0.');
        LibraryAssert.AreEqual(0, EntrySummary."DUoM Second Qty",
            'T08: Sin contexto resoluble DUoM Second Qty debe quedar en 0.');
    end;

    [Test]
    procedure EntrySummary_NoLotRatioInVariableMode_NoError_FieldsRemainZero()
    var
        Item: Record Item;
        ILE: Record "Item Ledger Entry";
        EntrySummary: Record "Entry Summary";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Variable SIN ratio de lote registrado
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] ILE mínimo para el artículo con un lote (contexto resoluble)
        DUoMTestHelpers.CreateMinimalILEForEntrySummaryTest(Item."No.", '', 'LOT-SINRATIO', ILE);

        // [GIVEN] Entry Summary con lote pero sin ratio de lote registrado
        EntrySummary.Init();
        EntrySummary."Entry No." := ILE."Entry No.";
        EntrySummary."Table ID" := Database::"Item Ledger Entry";
        EntrySummary."Lot No." := 'LOT-SINRATIO';
        EntrySummary."Total Available Quantity" := 60;
        EntrySummary."Selected Quantity" := 0;

        // [WHEN] Se puebla DUoM para la línea — no debe lanzar error
        DUoMEntrySummaryMgt.PopulateDUoMForEntrySummary(EntrySummary);

        // [THEN] DUoM Ratio y DUoM Second Qty permanecen en 0 (no hay ratio que aplicar)
        LibraryAssert.AreEqual(0, EntrySummary."DUoM Ratio",
            'T09: En modo Variable sin ratio de lote DUoM Ratio debe quedar en 0.');
        LibraryAssert.AreEqual(0, EntrySummary."DUoM Second Qty",
            'T09: En modo Variable sin ratio de lote DUoM Second Qty debe quedar en 0.');
    end;
}
