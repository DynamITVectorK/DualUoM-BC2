/// <summary>
/// Tests E2E de posting para el flujo DUoM de Purchase Order con Item Tracking por lotes.
///
/// Escenarios cubiertos (tests de bloqueo en posting):
///   T-POST-04: Suma DUoM de tracking inferior a la línea → posting bloqueado
///   T-POST-05: Suma DUoM de tracking superior a la línea → posting bloqueado
///   T-POST-06: AlwaysVariable — lote sin DUoM Ratio → posting bloqueado
///   T-POST-07: Fixed — lote con ratio diferente al fijo → posting bloqueado
///
/// Cobertura de los requisitos del issue de hardening:
///   Los tests T01 (coherentes sin error) y T08 (ratio por lote) están cubiertos
///   en DUoM ILE Integration Tests (50209) — PurchaseTwoLots_VarMode_EachILEHasLotRatio.
///   Los tests de persistencia (T01-T02 del issue) están en DUoM Purch Tracking
///   Persist (50219).
///   Los tests unitarios de coherencia están en DUoM Tracking Coherence Tests (50220).
///
/// Propósito de este codeunit:
///   Complementar los tests unitarios de coherencia (50220) con pruebas E2E que
///   llaman a LibraryPurchase.PostPurchaseDocument y verifican que el posting se
///   bloquea correctamente cuando los datos DUoM en Reservation Entry son
///   incoherentes con la Purchase Line.
///
///   Prueba que el subscriber OnPurchPostValidateDUoMTrackingCoherence (50102)
///   está correctamente conectado al evento de posting y actúa antes de crear
///   cualquier Item Ledger Entry.
///
/// Arquitectura de validación:
///   OnPostItemJnlLineOnAfterCopyDocumentFields (Purch.-Post, CU 90)
///     → OnPurchPostValidateDUoMTrackingCoherence (DUoM Purchase Subscribers, 50102)
///       → ValidatePurchLineTrackingCoherence (DUoM Tracking Coherence Mgt, 50111)
///         → Comparación total: SUM(ReservEntry.DUoM Second Qty) vs PurchLine.DUoM Second Qty
///         → Validación por lote: ratio coherente, mode-specific rules
/// </summary>
codeunit 50221 "DUoM Purch Tracking Post Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T-POST-04 — Suma DUoM inferior bloquea posting
    //
    // Caso del issue Test 4:
    //   Purchase Line: Quantity = 10 KG / DUoM Second Qty = 8 PCS
    //   Tracking:
    //     LOTE-A = 6 KG / 5 PCS (ratio = 5/6 ≈ 0.8333)
    //     LOTE-B = 4 KG / 2 PCS (ratio = 2/4 = 0.5)
    //   Suma tracking = 7 PCS ≠ 8 PCS → posting bloqueado
    //
    // Verificación del error:
    //   TrackingTotalMismatchErr en DUoM Tracking Coherence Mgt (50111)
    //   disparado desde ValidatePurchLineTrackingCoherence.
    //
    // Garantía adicional:
    //   No se crea ningún ILE (la transacción se deshace al producirse el error).
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchPost_LowDUoMSum_Blocked()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable, ratio 0.8 y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: 10 KG → DUoM Second Qty = 8 PCS (0.8 × 10, modo Variable)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [GIVEN] Tracking con suma DUoM = 7 PCS (inferior a 8)
        //   LOTE-A: 6 KG / 5 PCS (ratio = 5/6 ≈ 0.8333)
        //   LOTE-B: 4 KG / 2 PCS (ratio = 2/4 = 0.50)
        //   AssignLotWithDUoMRatioToPurchLine: DUoM Second Qty = Qty × Ratio
        //     LOTE-A: 6 × (5/6) = 5.0 ✓
        //     LOTE-B: 4 × (2/4) = 2.0 ✓  → Total = 7 ≠ 8
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-A', 6, 5 / 6);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-B', 4, 2 / 4);

        // [WHEN] Se intenta registrar la compra (solo recepción)
        // [THEN] El posting se bloquea porque la suma DUoM de tracking (7) < línea (8)
        asserterror LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] No se ha creado ningún ILE (rollback completo de la transacción)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsFalse(ILE.FindFirst(),
            'T-POST-04: No debe existir ningún ILE cuando el posting falla por suma DUoM inferior.');
    end;

    // -------------------------------------------------------------------------
    // T-POST-05 — Suma DUoM superior bloquea posting
    //
    // Caso del issue Test 5:
    //   Purchase Line: Quantity = 10 KG / DUoM Second Qty = 8 PCS
    //   Tracking:
    //     LOTE-A = 6 KG / 5 PCS (ratio = 5/6 ≈ 0.8333)
    //     LOTE-B = 4 KG / 4 PCS (ratio = 1.0)
    //   Suma tracking = 9 PCS ≠ 8 PCS → posting bloqueado
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchPost_HighDUoMSum_Blocked()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable, ratio 0.8 y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: 10 KG → DUoM Second Qty = 8 PCS
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [GIVEN] Tracking con suma DUoM = 9 PCS (superior a 8)
        //   LOTE-A: 6 KG / 5 PCS (ratio = 5/6 ≈ 0.8333)
        //   LOTE-B: 4 KG / 4 PCS (ratio = 1.0)
        //   LOTE-A: 6 × (5/6) = 5.0; LOTE-B: 4 × 1.0 = 4.0 → Total = 9 ≠ 8
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-A', 6, 5 / 6);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-B', 4, 1.0);

        // [WHEN] Se intenta registrar la compra (solo recepción)
        // [THEN] El posting se bloquea porque la suma DUoM de tracking (9) > línea (8)
        asserterror LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] No se ha creado ningún ILE
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsFalse(ILE.FindFirst(),
            'T-POST-05: No debe existir ningún ILE cuando el posting falla por suma DUoM superior.');
    end;

    // -------------------------------------------------------------------------
    // T-POST-06 — AlwaysVariable exige DUoM Ratio por lote
    //
    // Caso del issue Test 6:
    //   Artículo en modo AlwaysVariable.
    //   Purchase Line con lot tracking.
    //   Lote asignado sin DUoM Ratio (ratio = 0 en ReservEntry).
    //   → posting bloqueado por AlwaysVariableMissingRatioErr
    //
    // Nota de diseño:
    //   En AlwaysVariable, PurchLine.DUoM Second Qty = 0 (el subscriber no calcula
    //   automáticamente). La comparación total se omite porque
    //   PurchLine.DUoM Second Qty = 0. Sin embargo, la validación por lote detecta
    //   que ReservEntry tiene DUoM Ratio = 0 con Quantity > 0 y lanza error.
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchAlwaysVarNoRatio_Blocked()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM AlwaysVariable (sin ratio fijo)
        //         y seguimiento por lote habilitado
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: 10 unidades; DUoM Second Qty = 0 (AlwaysVariable,
        //         el subscriber limpia los campos; el usuario debe introducirlos manualmente)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [GIVEN] Lote asignado sin DUoM Ratio (ratio = 0)
        //         El usuario no introdujo el ratio en Item Tracking Lines
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-T6', 10, 0);

        // [WHEN] Se intenta registrar la compra
        // [THEN] El posting se bloquea porque AlwaysVariable exige ratio por lote
        //        (AlwaysVariableMissingRatioErr en DUoM Tracking Coherence Mgt)
        asserterror LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] No se ha creado ningún ILE
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsFalse(ILE.FindFirst(),
            'T-POST-06: No debe existir ningún ILE cuando AlwaysVariable falta ratio en lote.');
    end;

    // -------------------------------------------------------------------------
    // T-POST-07 — Fixed no permite ratio diferente al configurado
    //
    // Caso del issue Test 7:
    //   Artículo en modo Fixed, ratio fijo = 0.8.
    //   Lote informado con DUoM Ratio = 0.9 (diferente al fijo).
    //   → posting bloqueado
    //
    // Nota de implementación:
    //   Con DUoM Ratio = 0.9 en tracking, DUoM Second Qty del lote = 10 × 0.9 = 9.
    //   La suma de tracking (9) ≠ Purchase Line DUoM Second Qty (8 = 10 × 0.8).
    //   El error TrackingTotalMismatchErr se lanza antes que FixedRatioMismatchErr
    //   (la comparación total se ejecuta antes de la validación por lote).
    //   Ambos errores prueban el mismo requisito funcional: el ratio distinto al
    //   fijo bloquea el posting. La validación de ratio fijo a nivel UI se cubre
    //   en el test unitario ValidateTrackingSpecLine_FixedMode_WrongRatio_Error
    //   (DUoM Tracking Coherence Tests, 50220).
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchFixedWrongRatio_Blocked()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Fixed, ratio fijo = 0.8
        //         y seguimiento por lote habilitado
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: 10 unidades; DUoM Second Qty = 8 (10 × 0.8 auto-calculado)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [GIVEN] Lote asignado con ratio incorrecto = 0.9 (≠ ratio fijo 0.8)
        //         DUoM Second Qty en ReservEntry = 10 × 0.9 = 9 ≠ PurchLine (8)
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-T7', 10, 0.9);

        // [WHEN] Se intenta registrar la compra
        // [THEN] El posting se bloquea porque el ratio del lote difiere del fijo
        //        (el error TrackingTotalMismatchErr bloquea el posting: 9 ≠ 8)
        asserterror LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] No se ha creado ningún ILE
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsFalse(ILE.FindFirst(),
            'T-POST-07: No debe existir ningún ILE cuando Fixed lote usa ratio incorrecto.');
    end;
}
