/// <summary>
/// Tests TDD para DUoM Tracking Coherence Mgt (50111).
///
/// Cubre los 11 escenarios de prueba definidos en el issue de validación de coherencia
/// DUoM entre Purchase Line e Item Tracking Lines:
///
///   T01 — Dos lotes coherentes → no hay error (suma DUoM = línea)
///   T02 — Suma DUoM inferior a la línea → error
///   T03 — Suma DUoM superior a la línea → error
///   T04 — Ratio incoherente en un lote → error
///   T05 — Modo Fixed con ratio distinto al configurado → error
///   T06 — Modo Variable con ratios distintos por lote y suma correcta → sin error
///   T07 — Modo AlwaysVariable con ratio cero en lote → error
///   T08 — AssertRatioCoherence: coherencia matemática correcta → sin error
///   T09 — AssertRatioCoherence: incoherencia matemática → error con ratio esperado
///   T10 — Redondeo dentro de tolerancia → sin error
///   T11 — Redondeo fuera de tolerancia → error
///
/// Arquitectura de tests:
///   T01–T03, T06: tests de integración con Purchase Line + Reservation Entries.
///                 Crean infraestructura DB (item, vendor, purch header/line, reserv. entries)
///                 y llaman directamente a ValidatePurchLineTrackingCoherence.
///   T04, T08–T09: tests unitarios sobre AssertRatioCoherence (método público).
///   T05, T07:     tests unitarios sobre ValidateTrackingSpecLine con buffer in-memory.
///   T10–T11:      tests sobre CalcTrackingDUoMTotalsForPurchLine + total comparison
///                 con Reservation Entries y diferencias controladas.
///
/// Usa estrictamente las librerías estándar de test BC 27:
///   LibraryInventory (Library - Inventory)
///   LibraryPurchase  (Library - Purchase)
///   LibraryAssert    (Library Assert)
/// </summary>
codeunit 50220 "DUoM Tracking Coherence Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T01 — Dos lotes coherentes: suma DUoM = línea → sin error
    //
    // Escenario: Purchase Line 10 KG / 8 PCS con dos lotes LOTE-A (6 KG / 5 PCS)
    // y LOTE-B (4 KG / 3 PCS). La suma 5 + 3 = 8 coincide con la línea.
    // -------------------------------------------------------------------------
    [Test]
    procedure ValidatePurchLine_TwoCoherentLots_NoError()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Variable, ratio fijo de fallback 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] Purchase Line: 10 KG / 8 PCS
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine."DUoM Second Qty" := 8;
        PurchLine.Modify(false);

        // [GIVEN] Dos Reservation Entries: LOTE-A (6 KG / 5 PCS) y LOTE-B (4 KG / 3 PCS)
        // Ratio LOTE-A = 5/6 ≈ 0.8333; Ratio LOTE-B = 3/4 = 0.75
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-A', 6, 5 / 6);
        SetDUoMSecondQtyOnLastReservEntry(Item."No.", 'LOTE-A', 5);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-B', 4, 3 / 4);
        SetDUoMSecondQtyOnLastReservEntry(Item."No.", 'LOTE-B', 3);

        // [WHEN] Se valida la coherencia DUoM
        // [THEN] No hay error — suma 5 + 3 = 8 = PurchLine.DUoM Second Qty
        DUoMCoherenceMgt.ValidatePurchLineTrackingCoherence(PurchLine);
        LibraryAssert.IsTrue(true, 'T01: No debe producirse error con dos lotes coherentes (suma = 8).');
    end;

    // -------------------------------------------------------------------------
    // T02 — Suma DUoM inferior a la línea → error
    //
    // LOTE-A (6 KG / 5 PCS) + LOTE-B (4 KG / 2 PCS) = 7 PCS ≠ 8 PCS
    // -------------------------------------------------------------------------
    [Test]
    procedure ValidatePurchLine_TrackingTotalLow_Error()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] Purchase Line: 10 KG / 8 PCS
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine."DUoM Second Qty" := 8;
        PurchLine.Modify(false);

        // [GIVEN] Tracking con suma = 7 PCS (inferior a 8)
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-A', 6, 5 / 6);
        SetDUoMSecondQtyOnLastReservEntry(Item."No.", 'LOTE-A', 5);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-B', 4, 2 / 4);
        SetDUoMSecondQtyOnLastReservEntry(Item."No.", 'LOTE-B', 2);

        // [WHEN] / [THEN] Error porque suma (7) < línea (8)
        asserterror DUoMCoherenceMgt.ValidatePurchLineTrackingCoherence(PurchLine);
    end;

    // -------------------------------------------------------------------------
    // T03 — Suma DUoM superior a la línea → error
    //
    // LOTE-A (6 KG / 5 PCS) + LOTE-B (4 KG / 4 PCS) = 9 PCS ≠ 8 PCS
    // -------------------------------------------------------------------------
    [Test]
    procedure ValidatePurchLine_TrackingTotalHigh_Error()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] Purchase Line: 10 KG / 8 PCS
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine."DUoM Second Qty" := 8;
        PurchLine.Modify(false);

        // [GIVEN] Tracking con suma = 9 PCS (superior a 8)
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-A', 6, 5 / 6);
        SetDUoMSecondQtyOnLastReservEntry(Item."No.", 'LOTE-A', 5);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-B', 4, 4 / 4);
        SetDUoMSecondQtyOnLastReservEntry(Item."No.", 'LOTE-B', 4);

        // [WHEN] / [THEN] Error porque suma (9) > línea (8)
        asserterror DUoMCoherenceMgt.ValidatePurchLineTrackingCoherence(PurchLine);
    end;

    // -------------------------------------------------------------------------
    // T04 — Ratio incoherente en un lote → error
    //
    // LOTE-A con 6 KG / 5 PCS pero ratio informado = 1.0 (esperado ≈ 0.833)
    // -------------------------------------------------------------------------
    [Test]
    procedure AssertRatioCoherence_IncorrectRatio_Error()
    var
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] BaseQty = 6, SecondQty = 5, Ratio = 1.0 (incorrecto — esperado 5/6 ≈ 0.8333)
        // [WHEN] / [THEN] Error: |6 × 1.0 − 5| = 1 >> 0.00001
        asserterror DUoMCoherenceMgt.AssertRatioCoherence(6, 5, 1.0, 0.00001, 'LOTE-A');
    end;

    // -------------------------------------------------------------------------
    // T05 — Modo Fixed con ratio distinto al configurado → error
    //
    // Artículo Fixed ratio = 0.8; TrackingSpec con DUoM Ratio = 0.9
    // -------------------------------------------------------------------------
    [Test]
    procedure ValidateTrackingSpecLine_FixedMode_WrongRatio_Error()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Fixed, ratio fijo = 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] TrackingSpec con DUoM Ratio = 0.9 (distinto del ratio fijo 0.8)
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Lot No." := 'LOTE-T05';
        TrackingSpec."Quantity (Base)" := 10;
        TrackingSpec."DUoM Ratio" := 0.9;
        TrackingSpec."DUoM Second Qty" := 9;

        // [WHEN] / [THEN] Error porque ratio (0.9) ≠ ratio fijo (0.8)
        asserterror DUoMCoherenceMgt.ValidateTrackingSpecLine(TrackingSpec);
    end;

    // -------------------------------------------------------------------------
    // T06 — Modo Variable con ratios distintos por lote y suma correcta → sin error
    //
    // LOTE-A: 6 KG / 5 PCS (ratio 0.8333); LOTE-B: 4 KG / 3 PCS (ratio 0.75)
    // Suma = 8 PCS = PurchLine. Ratios diferentes por lote permitidos en Variable.
    // -------------------------------------------------------------------------
    [Test]
    procedure ValidatePurchLine_VariableMode_DifferentRatiosPerLot_SumCorrect_NoError()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] Purchase Line: 10 KG / 8 PCS
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine."DUoM Second Qty" := 8;
        PurchLine.Modify(false);

        // [GIVEN] Dos lotes con ratios distintos pero suma correcta
        // LOTE-A: 6 KG / 5 PCS (ratio = 5/6 ≈ 0.8333)
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-A', 6, 5 / 6);
        SetDUoMSecondQtyOnLastReservEntry(Item."No.", 'LOTE-A', 5);
        // LOTE-B: 4 KG / 3 PCS (ratio = 3/4 = 0.75)
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-B', 4, 3 / 4);
        SetDUoMSecondQtyOnLastReservEntry(Item."No.", 'LOTE-B', 3);

        // [WHEN] Se valida la coherencia DUoM
        // [THEN] Sin error — Variable permite ratios distintos por lote; suma 5+3=8 ✓
        DUoMCoherenceMgt.ValidatePurchLineTrackingCoherence(PurchLine);
        LibraryAssert.IsTrue(true, 'T06: Variable permite ratios distintos por lote; suma total correcta.');
    end;

    // -------------------------------------------------------------------------
    // T07 — Modo AlwaysVariable con ratio cero en lote y cantidad > 0 → error
    // -------------------------------------------------------------------------
    [Test]
    procedure ValidateTrackingSpecLine_AlwaysVariable_ZeroRatio_Error()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM AlwaysVariable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);

        // [GIVEN] TrackingSpec con DUoM Ratio = 0 y Quantity (Base) > 0
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Lot No." := 'LOTE-T07';
        TrackingSpec."Quantity (Base)" := 10;
        TrackingSpec."DUoM Ratio" := 0;
        TrackingSpec."DUoM Second Qty" := 0;

        // [WHEN] / [THEN] Error: AlwaysVariable exige ratio válido cuando hay cantidad
        asserterror DUoMCoherenceMgt.ValidateTrackingSpecLine(TrackingSpec);
    end;

    // -------------------------------------------------------------------------
    // T08 — AssertRatioCoherence: valores coherentes → sin error
    //
    // BaseQty=6, SecondQty=5, Ratio=5/6 — matemáticamente correcto
    // -------------------------------------------------------------------------
    [Test]
    procedure AssertRatioCoherence_CoherentValues_NoError()
    var
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] BaseQty=6, SecondQty=5, Ratio=5/6 (correcto: 6 × (5/6) = 5)
        // [WHEN] Se llama a AssertRatioCoherence
        DUoMCoherenceMgt.AssertRatioCoherence(6, 5, 5 / 6, 0.00001, 'LOTE-T08');
        // [THEN] Sin error
        LibraryAssert.IsTrue(true, 'T08: Valores coherentes no deben generar error.');
    end;

    // -------------------------------------------------------------------------
    // T09 — AssertRatioCoherence: incoherencia matemática → error con ratio esperado
    //
    // BaseQty=10, SecondQty=8, Ratio=1.0 (esperado 0.8) → error
    // -------------------------------------------------------------------------
    [Test]
    procedure AssertRatioCoherence_Incoherent_ErrorWithExpectedRatio()
    var
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] BaseQty=10, SecondQty=8, Ratio=1.0 (incorrecto — esperado 0.8)
        // [WHEN] / [THEN] Error: |10 × 1.0 − 8| = 2 >> 0.00001
        asserterror DUoMCoherenceMgt.AssertRatioCoherence(10, 8, 1.0, 0.00001, 'LOTE-T09');
    end;

    // -------------------------------------------------------------------------
    // T10 — Redondeo dentro de tolerancia → sin error
    //
    // PurchLine.DUoM Second Qty = 8; Tracking total = 8.000005 (dif < 0.00001)
    // -------------------------------------------------------------------------
    [Test]
    procedure ValidatePurchLine_RoundingWithinTolerance_NoError()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Variable (sin Item Unit of Measure → precision = 0.00001)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] Purchase Line: DUoM Second Qty = 8 exacto
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine."DUoM Second Qty" := 8;
        PurchLine.Modify(false);

        // [GIVEN] Un lote con DUoM Second Qty = 8.000005 (diferencia 0.000005 < 0.00001)
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-T10', 10, 0.8000005);
        SetDUoMSecondQtyOnLastReservEntry(Item."No.", 'LOTE-T10', 8.000005);

        // [WHEN] Se valida la coherencia DUoM
        // [THEN] Sin error — diferencia 0.000005 está dentro de la tolerancia 0.00001
        DUoMCoherenceMgt.ValidatePurchLineTrackingCoherence(PurchLine);
        LibraryAssert.IsTrue(true, 'T10: Diferencia dentro de tolerancia no debe generar error.');
    end;

    // -------------------------------------------------------------------------
    // T11 — Redondeo fuera de tolerancia → error
    //
    // PurchLine.DUoM Second Qty = 8; Tracking total = 8.001 (dif > 0.00001)
    // -------------------------------------------------------------------------
    [Test]
    procedure ValidatePurchLine_RoundingOutsideTolerance_Error()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Variable (sin Item Unit of Measure → precision = 0.00001)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] Purchase Line: DUoM Second Qty = 8 exacto
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine."DUoM Second Qty" := 8;
        PurchLine.Modify(false);

        // [GIVEN] Un lote con DUoM Second Qty = 8.001 (diferencia 0.001 >> 0.00001)
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, 'LOTE-T11', 10, 0.8001);
        SetDUoMSecondQtyOnLastReservEntry(Item."No.", 'LOTE-T11', 8.001);

        // [WHEN] / [THEN] Error porque diferencia (0.001) > tolerancia (0.00001)
        asserterror DUoMCoherenceMgt.ValidatePurchLineTrackingCoherence(PurchLine);
    end;

    // ── Helpers privados ─────────────────────────────────────────────────────

    /// <summary>
    /// Sobrescribe DUoM Second Qty en la última Reservation Entry insertada para el lote indicado.
    /// Permite configurar deliberadamente estados incoherentes (p. ej. suma de lotes ≠ línea)
    /// que son necesarios en los tests negativos T02 y T03 sin depender del valor calculado
    /// automáticamente por AssignLotWithDUoMRatioToPurchLine (Qty × Ratio), que puede diferir
    /// del entero exacto que el test quiere provocar como error.
    /// </summary>
    local procedure SetDUoMSecondQtyOnLastReservEntry(
        ItemNo: Code[20];
        LotNo: Code[50];
        SecondQty: Decimal)
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetRange("Item No.", ItemNo);
        ReservEntry.SetRange("Lot No.", LotNo);
        ReservEntry.SetRange(Positive, true);
        if ReservEntry.FindLast() then begin
            ReservEntry."DUoM Second Qty" := SecondQty;
            ReservEntry.Modify(false);
        end;
    end;
}
