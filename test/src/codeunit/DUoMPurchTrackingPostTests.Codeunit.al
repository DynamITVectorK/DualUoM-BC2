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
        LibraryAssert.ExpectedError('does not match the DUoM quantity on the purchase line');

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
        LibraryAssert.ExpectedError('does not match the DUoM quantity on the purchase line');

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
        LibraryAssert.ExpectedError('requires a variable DUoM ratio per lot');

        // [THEN] No se ha creado ningún ILE
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsFalse(ILE.FindFirst(),
            'T-POST-06: No debe existir ningún ILE cuando AlwaysVariable falta ratio en lote.');
    end;

    // -------------------------------------------------------------------------
    // T-POST-07 — Fixed modo con ratio incorrecto: suma total mismatch bloquea
    //
    // Artículo en modo Fixed, ratio fijo = 0.8.
    // Lote informado con DUoM Ratio = 0.9 → DUoM Second Qty = 9 ≠ PurchLine (8).
    // El posting se bloquea por TrackingTotalMismatchErr (suma 9 ≠ 8).
    //
    // Nota: este test cubre el escenario donde el ratio incorrecto también produce
    // un total mismatch. Para el caso donde el total coincide pero el ratio fijo
    // sigue siendo incorrecto, ver PurchFixed_TotalOK_WrongRatioBlocked (T-POST-07B).
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchFixed_TotalMismatch_Blocked()
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
        // [THEN] El posting se bloquea porque la suma DUoM (9) ≠ línea (8)
        asserterror LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);
        LibraryAssert.ExpectedError('does not match the DUoM quantity on the purchase line');

        // [THEN] No se ha creado ningún ILE
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsFalse(ILE.FindFirst(),
            'T-POST-07: No debe existir ningún ILE cuando Fixed lote usa ratio incorrecto.');
    end;

    // -------------------------------------------------------------------------
    // T-POST-07B — Fixed modo: suma total OK pero ratio del lote incorrecto → bloqueo
    //
    // Complemento de PurchFixedWrongRatio_Blocked. Aísla específicamente la regla
    // FixedRatioMismatchErr en el subscriber de posting:
    //
    //   Purchase Line: 10 KG / 8 PCS (DUoM Ratio = 0.8, Fixed)
    //   Tracking lot:  10 KG / DUoM Ratio = 0.9 / DUoM Second Qty = 8
    //
    //   Comprobación de total: 8 == 8 → PASA (no TrackingTotalMismatchErr)
    //   Comprobación por lote: |0.9 − 0.8| = 0.1 > 0.00001 → FixedRatioMismatchErr
    //
    // El DUoM Second Qty del lote se sobrescribe a 8 después de crear la
    // Reservation Entry (que por defecto sería 10 × 0.9 = 9), de modo que la
    // suma total coincida con la línea y solo la regla de ratio fijo actúe.
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchFixed_TotalOK_WrongRatioBlocked()
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
        //         Inicialmente: DUoM Second Qty = 10 × 0.9 = 9
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-T7B', 10, 0.9);

        // [GIVEN] Se sobrescribe DUoM Second Qty a 8 para que la suma total coincida
        //         con la Purchase Line (8 == 8) y la comprobación de total pase.
        //         Así sólo la regla de ratio fijo actúa durante el posting.
        OverrideDUoMSecondQtyOnReservEntry(PurchLine, 'LOTE-T7B', 8);

        // [GIVEN] Se verifica que la sobrescritura se aplicó correctamente
        //         (si no, el test probaría un escenario diferente al pretendido)
        VerifyReservEntryDUoMSecondQty(PurchLine, 'LOTE-T7B', 8, LibraryAssert);

        // [WHEN] Se intenta registrar la compra
        // [THEN] El posting se bloquea por FixedRatioMismatchErr:
        //         suma total = 8 == línea → comprobación de total PASA
        //         ratio del lote 0.9 ≠ ratio fijo 0.8 → FixedRatioMismatchErr
        asserterror LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);
        LibraryAssert.ExpectedError('differs from the fixed ratio configured for item');

        // [THEN] No se ha creado ningún ILE
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsFalse(ILE.FindFirst(),
            'T-POST-07B: No debe existir ningún ILE cuando Fixed lote usa ratio incorrecto (suma total OK).');
    end;

    // ── Helpers privados ─────────────────────────────────────────────────────

    /// <summary>
    /// Sobrescribe DUoM Second Qty en la Reservation Entry positiva del lote
    /// asociada a la Purchase Line indicada. Filtra por todos los campos Source
    /// para garantizar que se modifica exactamente la entrada vinculada a la línea
    /// bajo prueba. Necesario para aislar la regla FixedRatioMismatchErr cuando el
    /// total coincide pero el ratio del lote es incorrecto.
    /// Lanza error si no existe ninguna Reservation Entry para la línea y lote.
    /// </summary>
    local procedure OverrideDUoMSecondQtyOnReservEntry(
        PurchLine: Record "Purchase Line";
        LotNo: Code[50];
        SecondQty: Decimal)
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source Subtype", PurchLine."Document Type".AsInteger());
        ReservEntry.SetRange("Source ID", PurchLine."Document No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange("Item No.", PurchLine."No.");
        ReservEntry.SetRange("Lot No.", LotNo);
        ReservEntry.SetRange(Positive, true);
        if not ReservEntry.FindLast() then
            Error('OverrideDUoMSecondQtyOnReservEntry: no Reservation Entry found for Document %1 Line %2, Lot %3.',
                PurchLine."Document No.", PurchLine."Line No.", LotNo);
        ReservEntry."DUoM Second Qty" := SecondQty;
        ReservEntry.Modify(false);
    end;

    /// <summary>
    /// Verifica que la Reservation Entry positiva del lote asociada a la Purchase
    /// Line indicada tiene DUoM Second Qty igual al valor esperado. Filtra por todos
    /// los campos Source para garantizar que se lee exactamente la entrada vinculada
    /// a la línea bajo prueba.
    /// </summary>
    local procedure VerifyReservEntryDUoMSecondQty(
        PurchLine: Record "Purchase Line";
        LotNo: Code[50];
        ExpectedSecondQty: Decimal;
        var LibraryAssert: Codeunit "Library Assert")
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source Subtype", PurchLine."Document Type".AsInteger());
        ReservEntry.SetRange("Source ID", PurchLine."Document No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange("Item No.", PurchLine."No.");
        ReservEntry.SetRange("Lot No.", LotNo);
        ReservEntry.SetRange(Positive, true);
        LibraryAssert.IsTrue(ReservEntry.FindLast(),
            'VerifyReservEntryDUoMSecondQty: debe existir Reservation Entry para el lote ' + LotNo);
        LibraryAssert.AreNearlyEqual(
            ExpectedSecondQty, ReservEntry."DUoM Second Qty", 0.001,
            'Reservation Entry DUoM Second Qty debe ser ' + Format(ExpectedSecondQty) +
            ' tras la sobrescritura (lote ' + LotNo + ').');
    end;
}
