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
///   T10 — Integración con ILE real de posting: poblamiento DUoM desde stock registrado.
///   T11 — UI real: apertura de Item Tracking Summary desde Item Tracking Lines (Select Entries).
///
/// Modelo real (BC 27):
///   Entry Summary no tiene campos "Item No." ni "Variant Code".
///   El contexto de artículo se resuelve mediante DUoM Entry Summary Mgt. (50132),
///   que usa Table ID + Entry No. para buscar en Item Ledger Entry,
///   Reservation Entry o Tracking Specification.
///   Los tests usan CreateMinimalILEForEntrySummaryTest para crear el ILE necesario.
///
/// Nota TestPage:
///   El flujo UI estándar BC 27 queda validado en T11:
///   "Sales Order" -> "Item Tracking Lines" -> acción "Select Entries" -> modal
///   "Item Tracking Summary" (TestPage + ModalPageHandler).
///   Además de la cobertura de buffer, el codeunit cubre el render real de DUoM Ratio
///   y DUoM Second Qty en la página de selección de movimientos.
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

    [Test]
    procedure EntrySummary_Integration_PostedStock_PopulatesDUoM()
    var
        Item: Record Item;
        ILE: Record "Item Ledger Entry";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        EntrySummary: Record "Entry Summary";
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
        PostedQty: Decimal;
    begin
        // T10 — Integración con ILE real de posting.
        //
        // Valida el camino completo del mecanismo de población DUoM para la carga
        // inicial de Item Tracking Summary:
        //   1. Artículo DUoM Variable + seguimiento de lote habilitado.
        //   2. Stock creado vía diario de artículos (ILE real, Entry Type = Positive Adjmt.).
        //   3. Entry Summary construido con Table ID = 32 y Entry No. = ILE."Entry No.",
        //      que es el mismo formato que Codeunit "Item Tracking Management" usa cuando
        //      construye el buffer para la página "Item Tracking Summary".
        //   4. PopulateDUoMForEntrySummary (invocado por OnAfterGetRecord) popula
        //      DUoM Ratio y DUoM Second Qty correctamente.
        //
        // Ver codeunit header para la nota sobre la limitación de TestPage.

        // [GIVEN] Artículo DUoM Variable con seguimiento de lote y ratio de lote registrado
        LotNo := 'LOT-INTG-T10';
        PostedQty := 100;

        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNo, 1.5);

        // [GIVEN] Stock del artículo con el lote, creado mediante posting real de diario
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine,
            ItemJnlBatch."Journal Template Name",
            ItemJnlBatch.Name,
            "Item Ledger Entry Type"::"Positive Adjmt.",
            Item."No.",
            PostedQty);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNo, PostedQty);
        LibraryInventory.PostItemJournalLine(
            ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [GIVEN] ILE real creado por el posting
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Lot No.", LotNo);
        ILE.SetRange("Entry Type", ILE."Entry Type"::"Positive Adjmt.");
        LibraryAssert.IsTrue(
            ILE.FindFirst(),
            'T10: Debe existir un ILE para el stock registrado.');

        // [GIVEN] Entry Summary con Table ID = 32 y Entry No. = ILE."Entry No."
        // Este es el formato que usa el buffer estándar de "Item Tracking Summary":
        //   Table ID = Database::"Item Ledger Entry"  (= 32)
        //   Entry No. = Entry No. del ILE representativo del lote
        // (Ver codeunit header para la nota sobre TestPage y la limitación de símbolo.)
        EntrySummary.Init();
        EntrySummary."Table ID" := Database::"Item Ledger Entry";
        EntrySummary."Entry No." := ILE."Entry No.";
        EntrySummary."Lot No." := LotNo;
        EntrySummary."Total Available Quantity" := PostedQty;
        EntrySummary."Selected Quantity" := 0;

        // [WHEN] Se ejecuta la lógica de OnAfterGetRecord (carga inicial de página)
        DUoMEntrySummaryMgt.PopulateDUoMForEntrySummary(EntrySummary);

        // [THEN] DUoM Ratio y DUoM Second Qty quedan poblados desde el ILE real
        LibraryAssert.AreNearlyEqual(
            1.5, EntrySummary."DUoM Ratio", 0.001,
            'T10: DUoM Ratio debe ser el ratio del lote registrado (1.5).');
        LibraryAssert.AreNearlyEqual(
            150, EntrySummary."DUoM Second Qty", 0.001,
            'T10: DUoM Second Qty debe ser Total Available Quantity × DUoM Ratio (100 × 1.5 = 150).');
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLines_OpenSelectEntries_MPH,ItemTrackingSummary_VerifyDUoM_MPH')]
    procedure ItemTrackingSummary_PageOpen_ShowsDUoMFieldsPopulated()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesOrder: TestPage "Sales Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
        PostedQty: Decimal;
        ExpectedRatio: Decimal;
    begin
        // [GIVEN] Artículo DUoM Variable con tracking por lote y ratio de lote real
        LotNo := 'LOT-UI-T11';
        PostedQty := 100;
        ExpectedRatio := 1.5;

        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNo, ExpectedRatio);
        CreateAvailableLotInventoryForSales(Item, LotNo, PostedQty);

        // [GIVEN] Pedido de venta para abrir el flujo estándar de Select Entries
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(
            SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(
            SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 10);
        SalesLine.Modify(true);

        UITestExpectedLotNo := LotNo;
        UITestExpectedRatio := ExpectedRatio;
        UITestSummaryWasOpened := false;

        // [WHEN] Se abre Item Tracking Lines y se invoca Select Entries (modal summary real)
        SalesOrder.OpenEdit();
        SalesOrder.GotoRecord(SalesHeader);
        SalesOrder.SalesLines.First();
        SalesOrder.SalesLines.ItemTrackingLines.Invoke();
        SalesOrder.Close();

        // [THEN] El modal Item Tracking Summary se abrió y se validó en su handler
        LibraryAssert.IsTrue(
            UITestSummaryWasOpened,
            'T11: Debe abrirse Item Tracking Summary al invocar Select Entries.');
    end;

    local procedure CreateAvailableLotInventoryForSales(var Item: Record Item; LotNo: Code[50]; Qty: Decimal)
    var
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine,
            ItemJnlBatch."Journal Template Name",
            ItemJnlBatch.Name,
            "Item Ledger Entry Type"::"Positive Adjmt.",
            Item."No.",
            Qty);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNo, Qty);
        LibraryInventory.PostItemJournalLine(
            ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);
    end;

    [ModalPageHandler]
    procedure ItemTrackingLines_OpenSelectEntries_MPH(
        var ItemTrackingLines: TestPage "Item Tracking Lines")
    begin
        ItemTrackingLines."Select Entries".Invoke();
        ItemTrackingLines.Cancel().Invoke();
    end;

    [ModalPageHandler]
    procedure ItemTrackingSummary_VerifyDUoM_MPH(
        var ItemTrackingSummary: TestPage "Item Tracking Summary")
    var
        EntrySummary: Record "Entry Summary";
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
        LibraryAssert: Codeunit "Library Assert";
        TableId: Integer;
        EntryNo: Integer;
        SelectedQty: Decimal;
        AvailableQty: Decimal;
        TotalQty: Decimal;
        Ratio: Decimal;
        SecondQty: Decimal;
        ContextResolved: Boolean;
        ResolvedItemNo: Code[20];
        ResolvedVariantCode: Code[10];
        SerialNo: Code[50];
        DiagnosticMessage: Text;
        ExpectedSecondQty: Decimal;
    begin
        UITestSummaryWasOpened := true;
        SelectSummaryLineByLot(ItemTrackingSummary, UITestExpectedLotNo, 'T11');

        TableId := ItemTrackingSummary.DUoMDiagTableID.AsInteger();
        EntryNo := ItemTrackingSummary.DUoMDiagEntryNo.AsInteger();
        SelectedQty := ItemTrackingSummary."Selected Quantity".AsDecimal();
        AvailableQty := ItemTrackingSummary."Total Available Quantity".AsDecimal();
        TotalQty := ItemTrackingSummary.DUoMDiagTotalQty.AsDecimal();
        Ratio := ItemTrackingSummary."DUoM Ratio".AsDecimal();
        SecondQty := ItemTrackingSummary."DUoM Second Qty".AsDecimal();
        SerialNo := CopyStr(ItemTrackingSummary.DUoMDiagSerialNo.Value, 1, MaxStrLen(SerialNo));

        EntrySummary.Init();
        EntrySummary."Table ID" := TableId;
        EntrySummary."Entry No." := EntryNo;
        ContextResolved := DUoMEntrySummaryMgt.TryResolveItemContext(
            EntrySummary, ResolvedItemNo, ResolvedVariantCode);
        DiagnosticMessage := BuildT11DiagnosticMessage(
            ItemTrackingSummary."Lot No.".Value,
            SerialNo,
            TableId,
            EntryNo,
            SelectedQty,
            AvailableQty,
            TotalQty,
            Ratio,
            SecondQty,
            ContextResolved,
            ResolvedItemNo,
            ResolvedVariantCode);

        LibraryAssert.AreEqual(
            UITestExpectedLotNo,
            ItemTrackingSummary."Lot No.".Value,
            'T11: Debe existir la línea del lote esperado en Item Tracking Summary.');
        LibraryAssert.IsTrue(
            Ratio > 0,
            DiagnosticMessage);
        LibraryAssert.IsTrue(
            ContextResolved,
            DiagnosticMessage);
        LibraryAssert.AreNearlyEqual(
            UITestExpectedRatio, Ratio, 0.001,
            'T11: DUoM Ratio debe coincidir con el ratio de lote configurado.');

        if SelectedQty <> 0 then
            ExpectedSecondQty := Abs(SelectedQty) * Ratio
        else
            ExpectedSecondQty := AvailableQty * Ratio;

        LibraryAssert.AreNearlyEqual(
            ExpectedSecondQty, SecondQty, 0.001,
            'T11: DUoM Second Qty debe calcularse sobre Selected Quantity si existe; si no, sobre Total Available Quantity.');

        ItemTrackingSummary.Cancel().Invoke();
    end;

    local procedure SelectSummaryLineByLot(var ItemTrackingSummary: TestPage "Item Tracking Summary"; ExpectedLotNo: Code[50]; TestId: Text)
    var
        LibraryAssert: Codeunit "Library Assert";
        Found: Boolean;
        HasNext: Boolean;
    begin
        HasNext := true;
        ItemTrackingSummary.First();
        repeat
            if ItemTrackingSummary."Lot No.".Value = ExpectedLotNo then
                begin
                    Found := true;
                    HasNext := false;
                end
            else
                HasNext := ItemTrackingSummary.Next();
        until not HasNext;

        LibraryAssert.IsTrue(
            Found,
            StrSubstNo('%1: No se encontró la línea del lote %2 en Item Tracking Summary.', TestId, ExpectedLotNo));
    end;

    local procedure BuildT11DiagnosticMessage(
        LotNo: Code[50];
        SerialNo: Code[50];
        TableId: Integer;
        EntryNo: Integer;
        SelectedQty: Decimal;
        AvailableQty: Decimal;
        TotalQty: Decimal;
        Ratio: Decimal;
        SecondQty: Decimal;
        ContextResolved: Boolean;
        ResolvedItemNo: Code[20];
        ResolvedVariantCode: Code[10]): Text
    begin
        exit(StrSubstNo(
            'T11 diagnóstico Entry Summary: Lot=%1; Serial=%2; Table ID=%3; Entry No.=%4; Selected Quantity=%5; Total Available Quantity=%6; Total Quantity=%7; DUoM Ratio=%8; DUoM Second Qty=%9; TryResolveItemContext=%10; Item No.=%11; Variant Code=%12.',
            LotNo, SerialNo, TableId, EntryNo, SelectedQty, AvailableQty, TotalQty,
            Ratio, SecondQty, Format(ContextResolved), ResolvedItemNo, ResolvedVariantCode));
    end;

    var
        UITestExpectedLotNo: Code[50];
        UITestExpectedRatio: Decimal;
        UITestSummaryWasOpened: Boolean;
}
