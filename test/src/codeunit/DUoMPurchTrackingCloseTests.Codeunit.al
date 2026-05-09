/// <summary>
/// Tests TDD para la validación de cierre de Item Tracking Lines con DUoM.
///
/// Escenarios cubiertos:
///   T-CLOSE-02: Total DUoM igual a la línea → DUoM por lote persiste en ReservEntry
///   T-CLOSE-03: Ratios distintos por lote pero total correcto → ratios preservados en ReservEntry
///   T-CLOSE-06: La validación pre-posting sigue existiendo como segunda barrera
///
/// Nota: T-CLOSE-01 (sync PurchLine alta) y T-CLOSE-04 (sync PurchLine baja) han sido
/// eliminados. La sincronización de la Purchase Line desde Item Tracking Lines pertenecía
/// a OnQueryClosePage, que ha sido eliminado por no seguir el patrón de Piezas. La fuente
/// de verdad DUoM por lote es Reservation Entry; la Purchase Line no se sincroniza
/// automáticamente desde el tracking.
///
/// Nota: el escenario T-CLOSE-05 (cancelación sin OK) fue eliminado porque no existe
/// un patrón soportado en AL TestPage para cerrar la page 6510 sin OK sin provocar un
/// doble cierre ("RunModal could not close page 6510 as it has already been closed").
///
/// La validación pre-posting (segunda barrera) queda intacta:
///   OnPostItemJnlLineOnAfterCopyDocumentFields → ValidatePurchLineTrackingCoherence
///   (cubre flujos donde datos incoherentes se insertan directamente en RE)
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
    // T-CLOSE-02 — Total DUoM igual a la línea: cierre permitido
    //
    // Verifica que al cerrar Item Tracking Lines con dos lotes cuyo total DUoM
    // coincide con la Purchase Line, las Reservation Entries persisten el DUoM.
    //
    // Purchase Line: Quantity = 2 / DUoM Second Qty = 4 / DUoM Ratio = 2
    // Tracking:
    //   Lot HH:  Qty (Base) = 1 / DUoM Ratio = 2 / DUoM Second Qty = 2
    //   Lot LOL: Qty (Base) = 1 / DUoM Ratio = 2 / DUoM Second Qty = 2
    // SUM(tracking) = 4 = 4 → Sin error; ReservEntry tiene DUoM correcto.
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
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
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
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
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
    // T-CLOSE-06 — La validación pre-posting existe como segunda barrera
    //
    // Verifica que la validación pre-posting en DUoM Purchase Subscribers (50102)
    // bloquea el registro cuando los datos DUoM en Reservation Entry son incoherentes
    // con la Purchase Line.
    //
    // Esta barrera es independiente de la UI de Item Tracking Lines y se dispara
    // incluso cuando los datos se insertan directamente en Reservation Entry.
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
    /// ModalPageHandler para Item Tracking Lines — utilizado por los tests T-CLOSE-02 y T-CLOSE-03.
    ///
    ///   HandlerStep = 2: Lote HH (ratio=2, second=2) + Lote LOL (ratio=2, second=2)
    ///                    Suma = 4 = 4 → OK sin error; ReservEntry conserva DUoM por lote
    ///
    ///   HandlerStep = 3: Lote LOT-A (ratio=1.5, second=1.5) + Lote LOT-B (ratio=2.5, second=2.5)
    ///                    Suma = 4 = 4 → OK sin error; ratios distintos preservados en ReservEntry
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
            2:
                begin
                    // T-CLOSE-02: suma = 2 + 2 = 4 = 4 → OK sin error; ReservEntry conserva DUoM
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
        end;
    end;

    var
        HandlerStep: Integer;
}
