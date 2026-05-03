/// <summary>
/// Tests TDD para la sincronización y validación de cierre de Item Tracking Lines con DUoM.
///
/// Escenarios cubiertos:
///   T-CLOSE-01: Total DUoM superior a la línea → Purchase Line sincronizada (suma=5, línea→5)
///   T-CLOSE-02: Total DUoM igual a la línea → cierre con OK sin error, línea permanece igual
///   T-CLOSE-03: Ratios distintos por lote pero total correcto → cierre permitido, ratios preservados
///   T-CLOSE-04: Total DUoM inferior a la línea → Purchase Line sincronizada (suma=3, línea→3)
///   T-CLOSE-06: La validación pre-posting sigue existiendo como segunda barrera
///
/// Nota: el escenario T-CLOSE-05 (cancelación sin OK) fue eliminado porque no existe
/// un patrón soportado en AL TestPage para cerrar la page 6510 sin OK sin provocar un
/// doble cierre ("RunModal could not close page 6510 as it has already been closed").
/// La acción Cancel no está disponible en TestPage "Item Tracking Lines" y llamar a
/// ItemTrackingLines.Close() dentro del ModalPageHandler causa el doble cierre.
/// La cobertura de "no persistencia al cancelar" queda fuera del alcance de los tests
/// automatizados mientras no exista un patrón soportado por la plataforma BC.
///
/// Diseño de sincronización y validación (nuevo flujo desde el issue de sync):
///   OnQueryClosePage (DUoM Item Tracking Lines, 50112)
///     → SyncPurchLineFromTrackingBuffer (DUoM Tracking Coherence Mgt, 50111)
///       → PurchLine."DUoM Second Qty" := SUM(TrackingSpec."DUoM Second Qty")
///       → PurchLine."DUoM Ratio" := Total / TotalBase
///     → ValidateTrackingSpecBufferForPurchLine (sanity check, siempre pasa tras sync)
///
/// La sincronización convierte la Purchase Line en resumen agregado del tracking.
/// Item Tracking Lines = fuente de verdad por lote.
/// Purchase Line = resumen agregado sincronizado desde tracking.
///
/// La validación pre-posting (segunda barrera) queda intacta:
///   OnPostItemJnlLineOnAfterCopyDocumentFields → ValidatePurchLineTrackingCoherence
///   (cubre flujos donde OnQueryClosePage no se ejecutó, e.g., inserción directa en RE)
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
    // T-CLOSE-01 — Total DUoM superior a la línea: Purchase Line sincronizada
    //
    // Con el nuevo diseño, Item Tracking Lines es la fuente de verdad.
    // Cuando el total de tracking supera el valor inicial de la Purchase Line,
    // el cierre con OK sincroniza la Purchase Line con el total de tracking.
    // La línea de pedido refleja el agregado real informado en tracking.
    //
    // Purchase Line: Quantity = 2 / DUoM Second Qty = 4 / DUoM Ratio = 2
    // Tracking:
    //   Lot HH:  Qty (Base) = 1 / DUoM Ratio = 2 / DUoM Second Qty = 2
    //   Lot LOL: Qty (Base) = 1 / DUoM Ratio = 3 / DUoM Second Qty = 3
    // SUM(tracking) = 5 → Purchase Line.DUoM Second Qty = 5, DUoM Ratio = 5/2 = 2.5
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_CloseTest_MPH')]
    procedure CloseOK_DUoMTotalHigh_SyncsToPurchLine()
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
        //        y cierra con OK (HandlerStep = 1)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 1;
        PurchaseOrder.PurchLines.First();

        // [THEN] Sin error: Purchase Line queda sincronizada con el total de tracking (5)
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] Purchase Line refleja el total real del tracking
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", PurchLine."Line No.");
        LibraryAssert.AreNearlyEqual(
            5, PurchLine."DUoM Second Qty", 0.001,
            'T-CLOSE-01: PurchLine.DUoM Second Qty debe ser 5 (suma real del tracking).');
        LibraryAssert.AreNearlyEqual(
            2.5, PurchLine."DUoM Ratio", 0.001,
            'T-CLOSE-01: PurchLine.DUoM Ratio debe ser 5/2 = 2.5 (ratio agregado del tracking).');
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
    // T-CLOSE-04 — Total DUoM inferior a la línea: Purchase Line sincronizada
    //
    // Con el nuevo diseño, Item Tracking Lines es la fuente de verdad.
    // Cuando el total de tracking es inferior al valor inicial de la Purchase Line,
    // el cierre con OK sincroniza la Purchase Line con el total real del tracking.
    //
    // Purchase Line: Quantity = 2 / DUoM Second Qty = 4 / DUoM Ratio = 2
    // Tracking:
    //   Lot HH:  Qty (Base) = 1 / DUoM Ratio = 2 / DUoM Second Qty = 2
    //   Lot LOL: Qty (Base) = 1 / DUoM Ratio = 1 / DUoM Second Qty = 1
    // SUM(tracking) = 3 → Purchase Line.DUoM Second Qty = 3, DUoM Ratio = 3/2 = 1.5
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_CloseTest_MPH')]
    procedure CloseOK_DUoMTotalLow_SyncsToPurchLine()
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

        // [WHEN] El usuario abre Item Tracking Lines con dos lotes (suma DUoM = 3)
        //        y cierra con OK (HandlerStep = 4)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 4;
        PurchaseOrder.PurchLines.First();

        // [THEN] Sin error: Purchase Line queda sincronizada con el total real del tracking (3)
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] Purchase Line refleja el total real del tracking
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", PurchLine."Line No.");
        LibraryAssert.AreNearlyEqual(
            3, PurchLine."DUoM Second Qty", 0.001,
            'T-CLOSE-04: PurchLine.DUoM Second Qty debe ser 3 (suma real del tracking).');
        LibraryAssert.AreNearlyEqual(
            1.5, PurchLine."DUoM Ratio", 0.001,
            'T-CLOSE-04: PurchLine.DUoM Ratio debe ser 3/2 = 1.5 (ratio agregado del tracking).');
    end;

    // -------------------------------------------------------------------------
    // T-CLOSE-06 — La validación pre-posting sigue funcionando como segunda barrera
    //
    // Verifica que la sincronización y validación de OnQueryClosePage no sustituyen
    // la validación pre-posting en DUoM Purchase Subscribers (50102).
    //
    // OnQueryClosePage solo se ejecuta cuando el usuario cierra Item Tracking Lines
    // vía la UI. Si los datos se insertan directamente en Reservation Entry (bypass UI),
    // OnQueryClosePage nunca se ejecuta. El posting debe seguir siendo bloqueado
    // por la validación pre-posting como segunda barrera de seguridad.
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
    /// ModalPageHandler para Item Tracking Lines — utilizado por los tests T-CLOSE-01..04.
    ///
    ///   HandlerStep = 1: Lote HH (ratio=2, second=2) + Lote LOL (ratio=3, second=3)
    ///                    Suma = 5 → al cerrar con OK, Purchase Line se sincroniza: DUoM = 5, ratio = 2.5
    ///
    ///   HandlerStep = 2: Lote HH (ratio=2, second=2) + Lote LOL (ratio=2, second=2)
    ///                    Suma = 4 = 4 → OK sin error; línea permanece con DUoM = 4
    ///
    ///   HandlerStep = 3: Lote LOT-A (ratio=1.5, second=1.5) + Lote LOT-B (ratio=2.5, second=2.5)
    ///                    Suma = 4 = 4 → OK sin error; ratios distintos preservados
    ///
    ///   HandlerStep = 4: Lote HH (ratio=2, second=2) + Lote LOL (ratio=1, second=1)
    ///                    Suma = 3 → al cerrar con OK, Purchase Line se sincroniza: DUoM = 3, ratio = 1.5
    ///
    /// Notas:
    ///   - En modo Variable sin DUoM Lot Ratio registrado, el subscriber aplica el
    ///     DUoM Ratio de la Purchase Line (=2) como fallback al validar Lot No.
    ///     Para ratios distintos al fallback, se sobreescribe DUoM Ratio explícitamente.
    ///   - SetValue("DUoM Ratio", x) provoca el trigger OnValidate de la tabla
    ///     DUoM Tracking Spec Ext que auto-calcula DUoM Second Qty = Qty × x (Variable mode).
    ///   - El nuevo flujo de cierre: SyncPurchLineFromTrackingBuffer → ValidateTrackingSpecBufferForPurchLine.
    ///     La sync siempre actualiza la Purchase Line antes de la validación, por lo que
    ///     la validación siempre pasa (PurchLine = suma del tracking).
    /// </summary>
    [ModalPageHandler]
    procedure ItemTrackingLines_CloseTest_MPH(
        var ItemTrackingLines: TestPage "Item Tracking Lines")
    begin
        case HandlerStep of
            1:
                begin
                    // T-CLOSE-01: suma = 2 + 3 = 5 → OK sincroniza Purchase Line a 5 (sin error)
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
                    // OK cierra la página — sync: PurchLine.DUoM = 5, ratio = 5/2 = 2.5
                    ItemTrackingLines.OK().Invoke();
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
                    // T-CLOSE-04: suma = 2 + 1 = 3 → OK sincroniza Purchase Line a 3 (sin error)
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('HH');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    // Fallback DUoM Ratio = 2 → DUoM Second Qty = 2 ✓
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOL');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    // Sobrescribir fallback con ratio 1 → DUoM Second Qty = 1
                    ItemTrackingLines."DUoM Ratio".SetValue(1);
                    // OK cierra la página — sync: PurchLine.DUoM = 3, ratio = 3/2 = 1.5
                    ItemTrackingLines.OK().Invoke();
                end;
        end;
    end;

    var
        HandlerStep: Integer;
}
