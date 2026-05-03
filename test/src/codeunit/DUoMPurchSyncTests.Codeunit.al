/// <summary>
/// Tests TDD para la sincronización DUoM desde Item Tracking Lines hacia la línea
/// de pedido de compra (Purchase Line).
///
/// Escenarios cubiertos:
///   T-SYNC-01: Variable — piezas reales en tracking recalculan ratio y sincronizan línea
///              7 KG con 11 PCS → DUoM Ratio = 11/7 ≈ 1.571 → Purchase Line actualizada.
///
///   T-SYNC-02: AlwaysVariable — piezas reales calculan ratio y sincronizan línea
///              Igual que Variable pero con modo AlwaysVariable.
///
///   T-SYNC-03: Fixed — piezas distintas al ratio fijo bloquean con error
///              DUoM Ratio fijo = 1.25, usuario informa 11 PCS para 7 KG →
///              error de incoherencia (|7×1.25 − 11| > tolerancia).
///
///   T-SYNC-04: Variable, varios lotes — Purchase Line recibe el total agregado
///              LOTE-A: 4 KG / 6 PCS (ratio 1.5)
///              LOTE-B: 6 KG / 8 PCS (ratio 1.333...)
///              Purchase Line: 14 PCS, ratio agregado = 1.4
///
///   T-SYNC-05: Variable E2E — flujo completo desde tracking hasta ILE
///              7 KG + 11 PCS → ratio 11/7 → ILE contiene valores reales
///
/// Diseño de la sincronización:
///   DUoM Second Qty.OnValidate (pageextension 50112)
///     → NormalizeTrackingDUoMSecondQty (DUoM Tracking Coherence Mgt, 50111)
///       → Variable/AlwaysVariable: DUoM Ratio := DUoM Second Qty / Qty (Base)
///     → ValidateTrackingSpecLine (50111) — coherencia post-normalización
///
///   OnQueryClosePage (OK/LookupOK):
///     → SyncPurchLineFromTrackingBuffer (50111)
///       → PurchLine.DUoM Second Qty := SUM(tracking.DUoM Second Qty)
///       → PurchLine.DUoM Ratio := Total / TotalBase
///     → ValidateTrackingSpecBufferForPurchLine (50111) — sanity check
/// </summary>
codeunit 50224 "DUoM Purch Sync Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T-SYNC-01 — Variable: piezas reales recalculan ratio y sincronizan Purchase Line
    //
    // Caso del issue: pedido 7 KG, sin piezas previas. Usuario informa 11 piezas
    // en Item Tracking Lines durante la recepción. El sistema recalcula el ratio
    // real del lote y actualiza la Purchase Line como resumen agregado.
    //
    // Purchase Line: Qty = 7 KG / DUoM Second Qty = 0 / DUoM Ratio = 0
    // Tracking: Lot BV / Qty (Base) = 7 / DUoM Second Qty = 11
    // Resultado esperado:
    //   Tracking: DUoM Ratio = 11/7 ≈ 1.571
    //   Purchase Line: DUoM Second Qty = 11, DUoM Ratio ≈ 1.571
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_Sync_MPH')]
    procedure PurchaseVariable_TrackingPiecesUpdateRatioAndPurchaseLine()
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
        ExpectedRatio: Decimal;
    begin
        // [GIVEN] Artículo inventariable con DUoM Variable, ratio inicial 0 y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        ExpectedRatio := 11 / 7;

        // [GIVEN] Purchase Order con una línea: 7 KG / DUoM Second Qty = 0 / DUoM Ratio = 0
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 7);
        PurchLine.Modify(true);

        // Verificar estado inicial: DUoM Second Qty = 0 (piezas desconocidas al pedir)
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", PurchLine."Line No.");
        LibraryAssert.AreEqual(0, PurchLine."DUoM Second Qty",
            'T-SYNC-01 GIVEN: PurchLine.DUoM Second Qty debe ser 0 (sin piezas conocidas al pedir).');

        // [WHEN] El usuario abre Item Tracking Lines durante la recepción,
        //        asigna lote BV con 7 KG e informa 11 piezas reales (HandlerStep = 1)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 1;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] Sin error — modo Variable permite informar piezas reales distintas al ratio estimado

        // [THEN] La línea de tracking tiene el ratio real calculado = 11/7
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source ID", PurchHeader."No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange("Lot No.", 'BV');
        ReservEntry.SetRange(Positive, true);
        LibraryAssert.IsTrue(ReservEntry.FindFirst(),
            'T-SYNC-01: Debe existir ReservEntry para el lote BV.');
        LibraryAssert.AreNearlyEqual(
            ExpectedRatio, ReservEntry."DUoM Ratio", 0.00001,
            'T-SYNC-01: DUoM Ratio de tracking debe ser 11/7 (ratio real del lote BV).');
        LibraryAssert.AreNearlyEqual(
            11, ReservEntry."DUoM Second Qty", 0.001,
            'T-SYNC-01: DUoM Second Qty de tracking debe ser 11 (piezas reales informadas).');

        // [THEN] La Purchase Line queda sincronizada como resumen agregado del tracking
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", PurchLine."Line No.");
        LibraryAssert.AreNearlyEqual(
            11, PurchLine."DUoM Second Qty", 0.001,
            'T-SYNC-01: PurchLine.DUoM Second Qty debe ser 11 (piezas reales sincronizadas).');
        LibraryAssert.AreNearlyEqual(
            ExpectedRatio, PurchLine."DUoM Ratio", 0.00001,
            'T-SYNC-01: PurchLine.DUoM Ratio debe ser 11/7 (ratio real sincronizado).');
    end;

    // -------------------------------------------------------------------------
    // T-SYNC-02 — AlwaysVariable: piezas reales calculan ratio y sincronizan línea
    //
    // AlwaysVariable exige que los datos sean completos (ratio ≠ 0) al cerrar/postear.
    // Cuando el usuario informa piezas reales en tracking, el ratio se calcula
    // automáticamente y la Purchase Line queda sincronizada.
    //
    // Purchase Line: Qty = 7 / DUoM Second Qty = 0 / DUoM Ratio = 0
    // Tracking: Lot BV / Qty (Base) = 7 / DUoM Second Qty = 11
    // Resultado esperado: DUoM Ratio = 11/7, Purchase Line sincronizada.
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_Sync_MPH')]
    procedure PurchaseAlwaysVariable_TrackingPiecesCalculateRatioAndSyncLine()
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
        ExpectedRatio: Decimal;
    begin
        // [GIVEN] Artículo con DUoM AlwaysVariable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        ExpectedRatio := 11 / 7;

        // [GIVEN] Purchase Order con línea: Qty = 7 / DUoM Second Qty = 0 / DUoM Ratio = 0
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 7);
        PurchLine.Modify(true);

        // [WHEN] El usuario informa 11 piezas reales en Item Tracking Lines (HandlerStep = 1)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 1;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] Sin error — AlwaysVariable permite informar piezas reales cuando ratio se calcula

        // [THEN] La línea de tracking tiene ratio real = 11/7
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source ID", PurchHeader."No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange("Lot No.", 'BV');
        ReservEntry.SetRange(Positive, true);
        LibraryAssert.IsTrue(ReservEntry.FindFirst(),
            'T-SYNC-02: Debe existir ReservEntry para el lote BV.');
        LibraryAssert.AreNearlyEqual(
            ExpectedRatio, ReservEntry."DUoM Ratio", 0.00001,
            'T-SYNC-02: DUoM Ratio de tracking debe ser 11/7 (calculado desde piezas reales).');

        // [THEN] Purchase Line sincronizada como resumen agregado
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", PurchLine."Line No.");
        LibraryAssert.AreNearlyEqual(
            11, PurchLine."DUoM Second Qty", 0.001,
            'T-SYNC-02: PurchLine.DUoM Second Qty debe ser 11 (piezas reales sincronizadas).');
        LibraryAssert.AreNearlyEqual(
            ExpectedRatio, PurchLine."DUoM Ratio", 0.00001,
            'T-SYNC-02: PurchLine.DUoM Ratio debe ser 11/7 (ratio real sincronizado).');
    end;

    // -------------------------------------------------------------------------
    // T-SYNC-03 — Fixed: piezas distintas al ratio fijo bloquean con error
    //
    // En modo Fixed el ratio es invariable. Si el usuario intenta informar
    // 11 piezas para 7 KG con ratio fijo 1.25, el sistema bloquea porque
    // |7 × 1.25 − 11| = 2.25 > tolerancia.
    //
    // Purchase Line: Qty = 7 / Ratio fijo = 1.25 / DUoM Second Qty = 8.75
    // Tracking: Lot BV / Qty (Base) = 7 / DUoM Second Qty = 11 (incorrecto)
    // Resultado esperado: error bloqueante.
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_Sync_MPH')]
    procedure PurchaseFixed_TrackingPiecesDifferentFromFixedRatioRaisesError()
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
        // [GIVEN] Artículo con DUoM Fixed (ratio fijo = 1.25) y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1.25);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Order con línea: Qty = 7 KG
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 7);
        PurchLine.Modify(true);

        // [WHEN] El usuario intenta informar 11 piezas para 7 KG en Item Tracking Lines
        //        (ratio fijo = 1.25 → expected = 8.75 ≠ 11 → HandlerStep = 2)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 2;
        PurchaseOrder.PurchLines.First();

        // [THEN] Error bloqueante — Fixed mode no permite ratio diferente al configurado
        asserterror PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        LibraryAssert.ExpectedError('has an inconsistent DUoM ratio');
        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-SYNC-04 — Variable, varios lotes: Purchase Line recibe el total agregado
    //
    // Con múltiples lotes, cada lote retiene su ratio real propio.
    // La Purchase Line se actualiza con el total agregado de piezas y el ratio medio.
    //
    // Purchase Line: Qty = 10 KG / DUoM Second Qty = 0 / DUoM Ratio = 0
    // Tracking:
    //   LOTE-A: Qty (Base) = 4 / DUoM Second Qty = 6 → ratio = 1.5
    //   LOTE-B: Qty (Base) = 6 / DUoM Second Qty = 8 → ratio = 8/6 ≈ 1.333
    // Resultado esperado:
    //   LOTE-A ratio = 1.5
    //   LOTE-B ratio = 8/6 ≈ 1.333
    //   Purchase Line: DUoM Second Qty = 14, DUoM Ratio = 14/10 = 1.4
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_Sync_MPH')]
    procedure PurchaseVariable_MultipleLots_UpdatePurchaseLineWithAggregateRatio()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntryA: Record "Reservation Entry";
        ReservEntryB: Record "Reservation Entry";
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

        // [GIVEN] Purchase Order con línea: 10 KG / DUoM Second Qty = 0 / DUoM Ratio = 0
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] Se informan dos lotes con piezas reales en Item Tracking Lines (HandlerStep = 3)
        //   LOTE-A: 4 KG → 6 PCS (ratio real = 1.5)
        //   LOTE-B: 6 KG → 8 PCS (ratio real = 8/6 ≈ 1.333)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 3;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] LOTE-A tiene ratio real = 1.5
        ReservEntryA.SetRange("Item No.", Item."No.");
        ReservEntryA.SetRange("Source Type", Database::"Purchase Line");
        ReservEntryA.SetRange("Source ID", PurchHeader."No.");
        ReservEntryA.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntryA.SetRange("Lot No.", 'LOTE-A');
        ReservEntryA.SetRange(Positive, true);
        LibraryAssert.IsTrue(ReservEntryA.FindFirst(),
            'T-SYNC-04: Debe existir ReservEntry para LOTE-A.');
        LibraryAssert.AreNearlyEqual(
            1.5, ReservEntryA."DUoM Ratio", 0.001,
            'T-SYNC-04: LOTE-A DUoM Ratio debe ser 6/4 = 1.5.');
        LibraryAssert.AreNearlyEqual(
            6, ReservEntryA."DUoM Second Qty", 0.001,
            'T-SYNC-04: LOTE-A DUoM Second Qty debe ser 6 (piezas reales).');

        // [THEN] LOTE-B tiene ratio real = 8/6 ≈ 1.333
        ReservEntryB.SetRange("Item No.", Item."No.");
        ReservEntryB.SetRange("Source Type", Database::"Purchase Line");
        ReservEntryB.SetRange("Source ID", PurchHeader."No.");
        ReservEntryB.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntryB.SetRange("Lot No.", 'LOTE-B');
        ReservEntryB.SetRange(Positive, true);
        LibraryAssert.IsTrue(ReservEntryB.FindFirst(),
            'T-SYNC-04: Debe existir ReservEntry para LOTE-B.');
        LibraryAssert.AreNearlyEqual(
            8 / 6, ReservEntryB."DUoM Ratio", 0.001,
            'T-SYNC-04: LOTE-B DUoM Ratio debe ser 8/6 ≈ 1.333.');
        LibraryAssert.AreNearlyEqual(
            8, ReservEntryB."DUoM Second Qty", 0.001,
            'T-SYNC-04: LOTE-B DUoM Second Qty debe ser 8 (piezas reales).');

        // [THEN] Purchase Line tiene el total agregado: 14 PCS, ratio = 14/10 = 1.4
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", PurchLine."Line No.");
        LibraryAssert.AreNearlyEqual(
            14, PurchLine."DUoM Second Qty", 0.001,
            'T-SYNC-04: PurchLine.DUoM Second Qty debe ser 14 (6 + 8, suma de los dos lotes).');
        LibraryAssert.AreNearlyEqual(
            1.4, PurchLine."DUoM Ratio", 0.001,
            'T-SYNC-04: PurchLine.DUoM Ratio debe ser 14/10 = 1.4 (ratio agregado).');
    end;

    // -------------------------------------------------------------------------
    // T-SYNC-05 — Variable E2E: flujo completo desde tracking hasta ILE
    //
    // Verifica que el flujo real de recepción queda completamente registrado:
    //   1. Usuario informa piezas reales en tracking → ratio real calculado.
    //   2. Purchase Line sincronizada.
    //   3. Al registrar, los valores reales se propagan al ILE.
    //
    // Purchase Line: Qty = 7 KG / DUoM Second Qty = 0 / DUoM Ratio = 0
    // Tracking: Lot BV / 7 KG / 11 PCS → ratio = 11/7 ≈ 1.571
    // Posting → ILE: Qty = 7, DUoM Second Qty = 11, DUoM Ratio = 11/7, Lot = BV
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_Sync_MPH')]
    procedure PurchaseVariable_PostReceipt_ILEUsesTrackingRealDUoM()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        ExpectedRatio: Decimal;
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio inicial 0) y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        ExpectedRatio := 11 / 7;

        // [GIVEN] Purchase Order: 7 KG / DUoM Second Qty = 0 (piezas desconocidas al pedir)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 7);
        PurchLine.Modify(true);

        // [WHEN] El usuario abre Item Tracking Lines, asigna lote BV con 7 KG
        //        e informa 11 piezas reales durante la recepción (HandlerStep = 1)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 1;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // Purchase Line sincronizada (verificación intermedia)
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", PurchLine."Line No.");
        LibraryAssert.AreNearlyEqual(
            11, PurchLine."DUoM Second Qty", 0.001,
            'T-SYNC-05: PurchLine debe quedar sincronizada con 11 piezas antes del posting.');

        // [WHEN] Se registra la recepción del pedido de compra
        PurchHeader.Get(PurchHeader."Document Type", PurchHeader."No.");
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] El ILE del lote BV contiene los valores DUoM reales de la recepción
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange("Lot No.", 'BV');
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T-SYNC-05: Debe existir un ILE para la recepción del lote BV.');
        LibraryAssert.AreNearlyEqual(
            7, ILE.Quantity, 0.001,
            'T-SYNC-05: ILE.Quantity debe ser 7 KG.');
        LibraryAssert.AreNearlyEqual(
            11, ILE."DUoM Second Qty", 0.001,
            'T-SYNC-05: ILE.DUoM Second Qty debe ser 11 (piezas reales del lote BV).');
        LibraryAssert.AreNearlyEqual(
            ExpectedRatio, ILE."DUoM Ratio", 0.00001,
            'T-SYNC-05: ILE.DUoM Ratio debe ser 11/7 ≈ 1.571 (ratio real del lote BV).');
    end;

    /// <summary>
    /// ModalPageHandler para Item Tracking Lines — utilizado por los tests T-SYNC-01..05.
    ///
    ///   HandlerStep = 1 (T-SYNC-01, T-SYNC-02, T-SYNC-05):
    ///     Un lote BV con 7 KG y 11 piezas reales.
    ///     NormalizeTrackingDUoMSecondQty recalcula DUoM Ratio = 11/7 ≈ 1.571.
    ///     OK cierra la página — SyncPurchLineFromTrackingBuffer actualiza Purchase Line.
    ///
    ///   HandlerStep = 2 (T-SYNC-03):
    ///     Artículo Fixed (ratio 1.25). Un lote BV con 7 KG y 11 piezas.
    ///     El subscriber auto-asigna DUoM Ratio = 1.25 al validar el lote.
    ///     SetValue("DUoM Second Qty", 11) → ValidateTrackingSpecLine lanza error
    ///     porque |7×1.25 − 11| = 2.25 > tolerancia (Fixed mode, sin normalización).
    ///
    ///   HandlerStep = 3 (T-SYNC-04):
    ///     Dos lotes con piezas reales distintas:
    ///       LOTE-A: 4 KG / 6 PCS → ratio = 1.5
    ///       LOTE-B: 6 KG / 8 PCS → ratio = 8/6 ≈ 1.333
    ///     NormalizeTrackingDUoMSecondQty recalcula cada ratio individualmente.
    ///     OK cierra la página — PurchLine se sincroniza con total = 14 PCS, ratio = 1.4.
    /// </summary>
    [ModalPageHandler]
    procedure ItemTrackingLines_Sync_MPH(
        var ItemTrackingLines: TestPage "Item Tracking Lines")
    begin
        case HandlerStep of
            1:
                begin
                    // T-SYNC-01/02/05: Un lote BV con 7 KG y 11 piezas reales
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('BV');
                    // Sin ratio registrado ni fallback en PurchLine → DUoM Ratio queda en 0
                    ItemTrackingLines."Quantity (Base)".SetValue(7);
                    // NormalizeTrackingDUoMSecondQty: DUoM Ratio = 11/7 ≈ 1.571
                    ItemTrackingLines."DUoM Second Qty".SetValue(11);
                    // OK cierra la página — sync Purchase Line
                    ItemTrackingLines.OK().Invoke();
                end;
            2:
                begin
                    // T-SYNC-03: Fixed mode — 11 piezas para 7 KG con ratio fijo 1.25 → error
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('BV');
                    // Subscriber auto-asigna DUoM Ratio = 1.25 (ratio fijo)
                    ItemTrackingLines."Quantity (Base)".SetValue(7);
                    // ValidateTrackingSpecLine: |7×1.25 − 11| = 2.25 > tolerancia → error
                    ItemTrackingLines."DUoM Second Qty".SetValue(11);
                end;
            3:
                begin
                    // T-SYNC-04: Dos lotes con piezas reales distintas
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOTE-A');
                    ItemTrackingLines."Quantity (Base)".SetValue(4);
                    // NormalizeTrackingDUoMSecondQty: DUoM Ratio = 6/4 = 1.5
                    ItemTrackingLines."DUoM Second Qty".SetValue(6);

                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOTE-B');
                    ItemTrackingLines."Quantity (Base)".SetValue(6);
                    // NormalizeTrackingDUoMSecondQty: DUoM Ratio = 8/6 ≈ 1.333
                    ItemTrackingLines."DUoM Second Qty".SetValue(8);

                    // OK cierra — PurchLine: 14 PCS, ratio = 14/10 = 1.4
                    ItemTrackingLines.OK().Invoke();
                end;
        end;
    end;

    var
        HandlerStep: Integer;
}
