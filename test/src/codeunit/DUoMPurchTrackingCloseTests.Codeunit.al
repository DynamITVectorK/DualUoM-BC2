/// <summary>
/// Tests TDD para la validación de cierre de Item Tracking Lines con DUoM (Issue close-validation).
///
/// Escenarios cubiertos:
///   T-CLOSE-01: Total DUoM superior a la línea → cierre con OK bloqueado (suma=5, línea=4)
///   T-CLOSE-02: Total DUoM igual a la línea → cierre con OK permitido (suma=4, línea=4)
///   T-CLOSE-03: Ratios distintos por lote pero total correcto → cierre permitido
///   T-CLOSE-04: Total DUoM inferior a la línea → cierre con OK bloqueado (suma=3, línea=4)
///   T-CLOSE-05: Cancelación no bloquea aunque el total DUoM sea incorrecto
///   T-CLOSE-06: La validación pre-posting sigue existiendo como segunda barrera
///
/// Diseño de la validación:
///   OnQueryClosePage (DUoM Item Tracking Lines, 50112)
///     → ValidateTrackingSpecBufferForPurchLine (DUoM Tracking Coherence Mgt, 50111)
///       → SUM(TrackingSpec.DUoM Second Qty) vs PurchLine.DUoM Second Qty
///       → TrackingTotalMismatchErr si diferencia > precisión de redondeo
///
/// La validación pre-posting (segunda barrera) queda intacta:
///   OnPostItemJnlLineOnAfterCopyDocumentFields → ValidatePurchLineTrackingCoherence
///
/// Convención de ratios:
///   DUoM Second Qty = Quantity (Base) × DUoM Ratio
///
/// Notas sobre el modo Variable con fallback de Purchase Line:
///   En modo Variable sin DUoM Lot Ratio registrado, el subscriber OnAfterValidateTrackingSpecLotNo
///   aplica el DUoM Ratio de la Purchase Line como fallback al validar el Lot No.
///   Por eso en los tests que necesitan un ratio distinto al de la Purchase Line,
///   se invalida el DUoM Ratio explícitamente después de validar el Lot No.
/// </summary>
codeunit 50222 "DUoM Purch Track Close Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T-CLOSE-01 — Total DUoM superior a la línea: cierre bloqueado
    //
    // Caso reproducido manualmente en el issue.
    //
    // Purchase Line: Quantity = 2 / DUoM Second Qty = 4 / DUoM Ratio = 2
    // Tracking:
    //   Lot HH:  Qty (Base) = 1 / DUoM Ratio = 2 / DUoM Second Qty = 2
    //   Lot LOL: Qty (Base) = 1 / DUoM Ratio = 3 / DUoM Second Qty = 3
    // SUM(tracking) = 5 ≠ 4 → Error al cerrar con OK
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_CloseTest_MPH')]
    procedure CloseOK_DUoMTotalHigh_Blocked()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 2 / DUoM Second Qty = 4 (ratio 2)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Validate("DUoM Ratio", 2);   // DUoM Second Qty = 2 × 2 = 4
        PurchLine.Modify(true);

        // [WHEN] El usuario abre Item Tracking Lines con dos lotes (suma DUoM = 5)
        //        y trata de cerrar con OK (HandlerStep = 1)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 1;
        PurchaseOrder.PurchLines.First();

        // [THEN] Error: la suma DUoM (2+3=5) no coincide con la línea (4)
        asserterror PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        LibraryAssert.ExpectedError('does not match the DUoM quantity on the purchase line');
        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-CLOSE-02 — Total DUoM igual a la línea: cierre permitido
    //
    // Purchase Line: Quantity = 2 / DUoM Second Qty = 4 / DUoM Ratio = 2
    // Tracking:
    //   Lot HH:  Qty (Base) = 1 / DUoM Ratio = 2 / DUoM Second Qty = 2
    //   Lot LOL: Qty (Base) = 1 / DUoM Ratio = 2 / DUoM Second Qty = 2
    // SUM(tracking) = 4 = 4 → Sin error
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_CloseTest_MPH')]
    procedure CloseOK_DUoMTotalMatch_Allowed()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        TotalSecondQty: Decimal;
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 2 / DUoM Second Qty = 4 (ratio 2)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Validate("DUoM Ratio", 2);   // DUoM Second Qty = 4
        PurchLine.Modify(true);

        // [WHEN] El usuario abre Item Tracking Lines con dos lotes (suma DUoM = 4 = 4)
        //        y cierra con OK (HandlerStep = 2)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 2;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] La página se cierra sin error
        // [THEN] Las Reservation Entries tienen suma DUoM Second Qty = 4
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source ID", PurchHeader."No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange(Positive, true);
        LibraryAssert.IsTrue(ReservEntry.FindSet(),
            'T-CLOSE-02: Deben existir Reservation Entries tras cerrar con OK.');
        repeat
            TotalSecondQty += ReservEntry."DUoM Second Qty";
        until ReservEntry.Next() = 0;
        LibraryAssert.AreNearlyEqual(
            4, TotalSecondQty, 0.001,
            'T-CLOSE-02: SUM(ReservEntry.DUoM Second Qty) debe ser 4.');
    end;

    // -------------------------------------------------------------------------
    // T-CLOSE-03 — Ratios distintos por lote pero total correcto: cierre permitido
    //
    // Verifica que el sistema permite ratios distintos por lote mientras
    // la suma total coincida con la Purchase Line. No se exige ratio uniforme.
    //
    // Purchase Line: Quantity = 2 / DUoM Second Qty = 4
    // Tracking:
    //   Lot A: Qty (Base) = 1 / DUoM Ratio = 1.5 / DUoM Second Qty = 1.5
    //   Lot B: Qty (Base) = 1 / DUoM Ratio = 2.5 / DUoM Second Qty = 2.5
    // SUM(tracking) = 4 = 4 → Sin error; ratios distintos preservados
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_CloseTest_MPH')]
    procedure CloseOK_DiffRatiosCorrectTotal_Allowed()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        TotalSecondQty: Decimal;
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 2 / DUoM Second Qty = 4 (ratio 2)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Validate("DUoM Ratio", 2);   // DUoM Second Qty = 4
        PurchLine.Modify(true);

        // [WHEN] Lote A (ratio 1.5, second=1.5) + Lote B (ratio 2.5, second=2.5)
        //        Suma = 4 = Purchase Line DUoM Second Qty (HandlerStep = 3)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 3;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] Sin error — la suma total es correcta
        // [THEN] Cada Reservation Entry preserva su ratio real (no ratio medio)
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source ID", PurchHeader."No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange(Positive, true);
        LibraryAssert.IsTrue(ReservEntry.FindSet(),
            'T-CLOSE-03: Deben existir Reservation Entries con ratios distintos.');
        repeat
            TotalSecondQty += ReservEntry."DUoM Second Qty";
        until ReservEntry.Next() = 0;
        LibraryAssert.AreNearlyEqual(
            4, TotalSecondQty, 0.001,
            'T-CLOSE-03: SUM(ReservEntry.DUoM Second Qty) debe ser 4 con ratios distintos.');
    end;

    // -------------------------------------------------------------------------
    // T-CLOSE-04 — Total DUoM inferior a la línea: cierre bloqueado
    //
    // Purchase Line: Quantity = 2 / DUoM Second Qty = 4 / DUoM Ratio = 2
    // Tracking:
    //   Lot HH:  Qty (Base) = 1 / DUoM Ratio = 2 / DUoM Second Qty = 2
    //   Lot LOL: Qty (Base) = 1 / DUoM Ratio = 1 / DUoM Second Qty = 1
    // SUM(tracking) = 3 ≠ 4 → Error al cerrar con OK
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_CloseTest_MPH')]
    procedure CloseOK_DUoMTotalLow_Blocked()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 2 / DUoM Second Qty = 4 (ratio 2)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Validate("DUoM Ratio", 2);   // DUoM Second Qty = 4
        PurchLine.Modify(true);

        // [WHEN] El usuario abre Item Tracking Lines con dos lotes (suma DUoM = 3 < 4)
        //        y trata de cerrar con OK (HandlerStep = 4)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 4;
        PurchaseOrder.PurchLines.First();

        // [THEN] Error: la suma DUoM (2+1=3) no coincide con la línea (4)
        asserterror PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        LibraryAssert.ExpectedError('does not match the DUoM quantity on the purchase line');
        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-CLOSE-05 — Cancelación no bloquea aunque el total DUoM sea incorrecto
    //
    // Verifica que OnQueryClosePage con CloseAction = Cancel no ejecuta la
    // validación DUoM. Los datos incoherentes introducidos no se persisten.
    //
    // Purchase Line: Quantity = 2 / DUoM Second Qty = 4
    // Tracking introducido (incoherente): HH = 2, LOL = 3 → suma = 5
    // Acción: Cancel → sin error, sin ReservEntry creada
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_CloseTest_MPH')]
    procedure CloseCancel_DUoMIncoherent_NoBlock()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 2 / DUoM Second Qty = 4 (ratio 2)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Validate("DUoM Ratio", 2);   // DUoM Second Qty = 4
        PurchLine.Modify(true);

        // [WHEN] El usuario introduce lotes incoherentes (suma=5) pero cancela (HandlerStep = 5)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 5;
        PurchaseOrder.PurchLines.First();
        // Sin asserterror: la cancelación no debe producir error
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] No se creó ninguna Reservation Entry (los cambios se descartaron)
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source ID", PurchHeader."No.");
        LibraryAssert.IsFalse(ReservEntry.FindFirst(),
            'T-CLOSE-05: No debe existir ReservEntry tras cancelar Item Tracking Lines.');
    end;

    // -------------------------------------------------------------------------
    // T-CLOSE-06 — La validación pre-posting sigue funcionando como segunda barrera
    //
    // Verifica que la validación agregada en OnQueryClosePage no sustituye la
    // validación pre-posting en DUoM Purchase Subscribers (50102).
    //
    // Escenario: datos incoherentes introducidos directamente en Reservation Entry
    // (sin pasar por Item Tracking Lines UI). El posting debe seguir siendo bloqueado.
    //
    // Purchase Line: Quantity = 2 / DUoM Second Qty = 4 (ratio 2)
    // Reservation Entry directa (bypass UI):
    //   LOTE-HH:  Qty = 1 / DUoM Ratio = 2 / DUoM Second Qty = 2
    //   LOTE-LOL: Qty = 1 / DUoM Ratio = 3 / DUoM Second Qty = 3
    // SUM(tracking) = 5 ≠ 4 → Posting bloqueado
    // -------------------------------------------------------------------------
    [Test]
    procedure PrePosting_DUoMIncoherent_StillBlocked()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable, ratio = 2, seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 2);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 2 / DUoM Second Qty = 4 (ratio 2)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Modify(true);

        // [GIVEN] Reservation Entries con DUoM incoherente insertadas directamente (bypass UI)
        //   LOTE-HH:  1 × 2 = 2 ✓ (individualmente coherente)
        //   LOTE-LOL: 1 × 3 = 3 ✓ (individualmente coherente)
        //   SUM = 5 ≠ 4 (incoherente con la Purchase Line)
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-HH', 1, 2);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-LOL', 1, 3);

        // [WHEN] Se intenta registrar la compra
        // [THEN] El posting sigue siendo bloqueado por la validación pre-posting
        //        (segunda barrera — independiente de la validación de cierre de página)
        asserterror LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);
        LibraryAssert.ExpectedError('does not match the DUoM quantity on the purchase line');
    end;

    /// <summary>
    /// ModalPageHandler para Item Tracking Lines — utilizado por los tests T-CLOSE-01..05.
    ///
    ///   HandlerStep = 1: Lote HH (ratio=2, second=2) + Lote LOL (ratio=3, second=3)
    ///                    Suma = 5 ≠ 4 → al invocar OK provoca error de validación DUoM
    ///
    ///   HandlerStep = 2: Lote HH (ratio=2, second=2) + Lote LOL (ratio=2, second=2)
    ///                    Suma = 4 = 4 → OK sin error
    ///
    ///   HandlerStep = 3: Lote LOT-A (ratio=1.5, second=1.5) + Lote LOT-B (ratio=2.5, second=2.5)
    ///                    Suma = 4 = 4 → OK sin error; ratios distintos preservados
    ///
    ///   HandlerStep = 4: Lote HH (ratio=2, second=2) + Lote LOL (ratio=1, second=1)
    ///                    Suma = 3 ≠ 4 → al invocar OK provoca error de validación DUoM
    ///
    ///   HandlerStep = 5: Lote HH (ratio=2) + Lote LOL (ratio=3) → suma incoherente
    ///                    pero se cierra la página sin OK → sin error, sin persistencia
    ///
    /// Notas:
    ///   - En modo Variable sin DUoM Lot Ratio registrado, el subscriber aplica el
    ///     DUoM Ratio de la Purchase Line (=2) como fallback al validar Lot No.
    ///     Para ratios distintos al fallback, se sobreescribe DUoM Ratio explícitamente.
    ///   - SetValue("DUoM Ratio", x) provoca el trigger OnValidate de la tabla
    ///     DUoM Tracking Spec Ext que auto-calcula DUoM Second Qty = Qty × x (Variable mode).
    /// </summary>
    [ModalPageHandler]
    procedure ItemTrackingLines_CloseTest_MPH(
        var ItemTrackingLines: TestPage "Item Tracking Lines")
    begin
        case HandlerStep of
            1:
                begin
                    // T-CLOSE-01: suma = 2 + 3 = 5 ≠ 4 → OK provoca error
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('HH');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    // Fallback DUoM Ratio = 2 (desde PurchLine) → DUoM Second Qty = 2 ✓
                    // No es necesario sobrescribir el ratio para HH en este paso
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOL');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    // Sobrescribir el fallback (2) con ratio 3 para que second=3
                    ItemTrackingLines."DUoM Ratio".SetValue(3);
                    // DUoM Second Qty auto-calculado = 1 × 3 = 3 (Variable mode)
                    ItemTrackingLines.OK().Invoke();   // Provoca error de validación
                end;
            2:
                begin
                    // T-CLOSE-02: suma = 2 + 2 = 4 = 4 → OK sin error
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('HH');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    // Fallback DUoM Ratio = 2 → DUoM Second Qty = 2 ✓
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOL');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    // Fallback DUoM Ratio = 2 → DUoM Second Qty = 2 ✓
                    ItemTrackingLines.OK().Invoke();
                end;
            3:
                begin
                    // T-CLOSE-03: suma = 1.5 + 2.5 = 4 = 4 → OK sin error; ratios distintos
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-A');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    ItemTrackingLines."DUoM Ratio".SetValue(1.5);
                    // DUoM Second Qty = 1 × 1.5 = 1.5 (auto-calculado en Variable mode)
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-B');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    ItemTrackingLines."DUoM Ratio".SetValue(2.5);
                    // DUoM Second Qty = 1 × 2.5 = 2.5 (auto-calculado en Variable mode)
                    ItemTrackingLines.OK().Invoke();
                end;
            4:
                begin
                    // T-CLOSE-04: suma = 2 + 1 = 3 ≠ 4 → OK provoca error
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('HH');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    // Fallback DUoM Ratio = 2 → DUoM Second Qty = 2 ✓
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOL');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    // Sobrescribir fallback con ratio 1 → DUoM Second Qty = 1
                    ItemTrackingLines."DUoM Ratio".SetValue(1);
                    ItemTrackingLines.OK().Invoke();   // Provoca error de validación
                end;
            5:
                begin
                    // T-CLOSE-05: datos incoherentes (suma=5) pero se cancela → sin error
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('HH');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    // Fallback DUoM Ratio = 2 → DUoM Second Qty = 2
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOL');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    ItemTrackingLines."DUoM Ratio".SetValue(3);
                    // DUoM Second Qty = 3; suma total = 5 ≠ 4 pero...
                    ItemTrackingLines.Close();              // Cierre sin OK: no ejecuta validación DUoM
                end;
        end;
    end;

    var
        HandlerStep: Integer;
}
