/// <summary>
/// Tests TDD para la propagación de campos DUoM en anulaciones de albaranes
/// contabilizados de compra y venta.
///
/// Escenarios cubiertos:
///
///   T-UNDO-01: Anulación albarán compra sin trazabilidad de lote.
///              Verifica que los movimientos de corrección reciben DUoM Ratio
///              y DUoM Second Qty con signo contrario al movimiento original.
///              (Flujo crítico: IJL de anulación llega con DUoM = 0; el fix
///              recupera el ratio mediante Applies-to Entry → ILE original.)
///
///   T-UNDO-02: Anulación albarán compra con un lote y DUoM Variable.
///              Verifica que el DUoM Ratio del lote se propaga correctamente
///              al ILE de corrección con signo negativo (Qty < 0).
///
///   T-UNDO-03: Anulación albarán compra multi-lote (2 lotes, ratios distintos).
///              Verifica que la suma de DUoM Second Qty de los ILEs de corrección
///              es igual con signo contrario a la suma de los ILEs originales.
///              (Criterio de aceptación central del issue.)
///
///   T-UNDO-04: Anulación albarán venta sin trazabilidad de lote.
///              Verifica que los ILEs de corrección (Qty > 0) reciben DUoM Ratio
///              y DUoM Second Qty con signo positivo (contrario al ILE de venta).
///
///   T-UNDO-05: Anulación albarán venta con un lote y DUoM Variable.
///              Verifica que el DUoM Ratio del lote se propaga al ILE de
///              corrección con signo positivo.
///
/// Criterios de aceptación verificados:
///   - ILE de corrección: DUoM Ratio = ratio del movimiento original (≠ 0).
///   - ILE de corrección: DUoM Second Qty = ILE.Quantity × DUoM Ratio (con signo).
///   - Suma(ILE corrección Second Qty) = −Suma(ILE originales Second Qty).
///   - No regresión en trazabilidad por lote.
///
/// Convenciones de test:
///   - Patrón [GIVEN] / [WHEN] / [THEN].
///   - LibraryPurchase, LibrarySales, LibraryInventory, LibraryAssert según norma.
///   - Anulación via CODEUNIT.Run("Undo Purchase Receipt Line" / "Undo Sales Shipment Line").
/// </summary>
codeunit 50227 "DUoM Undo Rcpt Shpt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    local procedure Initialize()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        if IsInitialized then
            exit;

        if not DUoMItemSetup.Get('DUOM-TEST-SEED') then begin
            DUoMItemSetup.Init();
            DUoMItemSetup."Item No." := 'DUOM-TEST-SEED';
            DUoMItemSetup.Insert();
        end;

        IsInitialized := true;
    end;

    // -------------------------------------------------------------------------
    // T-UNDO-01 — Anulación albarán compra sin lote
    //
    // Escenario: artículo con DUoM Fixed (ratio = 0.8), pedido de compra de 10 uds
    // sin trazabilidad de lote. Tras registrar la recepción y anularla:
    //   ILE original:    Qty = +10, DUoM Ratio = 0.8, DUoM Second Qty = +8
    //   ILE corrección:  Qty = -10, DUoM Ratio = 0.8, DUoM Second Qty = -8
    //
    // Causa raíz cubierta: flujo Undo Purchase Receipt sin lote → IJL.Applies-to Entry
    // → OnAfterInitItemLedgEntry recupera ratio del ILE original.
    // -------------------------------------------------------------------------
    [Test]
    procedure UndoPurchaseReceipt_NoLot_CorrILEHasDUoMFields()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        Initialize();

        // [GIVEN] Artículo con DUoM Fixed, ratio = 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Pedido de compra de 10 uds, registrado (solo recepción)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [WHEN] Se anula el albarán de compra contabilizado
        PurchRcptHeader.SetRange("Order No.", PurchHeader."No.");
        LibraryAssert.IsTrue(PurchRcptHeader.FindFirst(), 'T-UNDO-01: Se esperaba albarán contabilizado');
        PurchRcptLine.SetRange("Document No.", PurchRcptHeader."No.");
        LibraryAssert.IsTrue(PurchRcptLine.FindFirst(), 'T-UNDO-01: Se esperaba línea de albarán');
        CODEUNIT.Run(CODEUNIT::"Undo Purchase Receipt Line", PurchRcptLine);

        // [THEN] ILE original: Qty = +10, DUoM Ratio = 0.8, DUoM Second Qty = +8
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange(Correction, false);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T-UNDO-01: ILE original no encontrado');
        LibraryAssert.AreNearlyEqual(0.8, ILE."DUoM Ratio", 0.001,
            'T-UNDO-01: ILE original DUoM Ratio debe ser 0.8');
        LibraryAssert.AreNearlyEqual(8, ILE."DUoM Second Qty", 0.001,
            'T-UNDO-01: ILE original DUoM Second Qty = +10 × 0.8 = +8');

        // [THEN] ILE corrección: Qty = -10, DUoM Ratio = 0.8, DUoM Second Qty = -8
        ILE.SetRange(Correction, true);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T-UNDO-01: ILE corrección no encontrado');
        LibraryAssert.AreNearlyEqual(0.8, ILE."DUoM Ratio", 0.001,
            'T-UNDO-01: ILE corrección DUoM Ratio debe ser 0.8 (recuperado via Applies-to Entry)');
        LibraryAssert.AreNearlyEqual(-8, ILE."DUoM Second Qty", 0.001,
            'T-UNDO-01: ILE corrección DUoM Second Qty = -10 × 0.8 = -8 (signo contrario)');
    end;

    // -------------------------------------------------------------------------
    // T-UNDO-02 — Anulación albarán compra con un lote
    //
    // Escenario: artículo con DUoM Variable, lote único con ratio = 0.8, 10 uds.
    // Tras registrar la recepción y anularla:
    //   ILE original:    Qty = +10, DUoM Ratio = 0.8, DUoM Second Qty = +8
    //   ILE corrección:  Qty = -10, DUoM Ratio = 0.8, DUoM Second Qty = -8
    //
    // Flujo con trazabilidad: TrackSpec → IJL → ILE vía OnAfterCopyTracking*.
    // -------------------------------------------------------------------------
    [Test]
    procedure UndoPurchaseReceipt_OneLot_CorrILEHasDUoMFields()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        Initialize();

        // [GIVEN] Artículo con DUoM Variable, lot tracking activo
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNo := 'LOT-UNDO-02';

        // [GIVEN] Pedido de compra: 10 uds · lote LOT-UNDO-02 · DUoM Ratio = 0.8
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNo, 10, 0.8);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [WHEN] Se anula el albarán de compra contabilizado
        PurchRcptHeader.SetRange("Order No.", PurchHeader."No.");
        LibraryAssert.IsTrue(PurchRcptHeader.FindFirst(), 'T-UNDO-02: Se esperaba albarán contabilizado');
        PurchRcptLine.SetRange("Document No.", PurchRcptHeader."No.");
        LibraryAssert.IsTrue(PurchRcptLine.FindFirst(), 'T-UNDO-02: Se esperaba línea de albarán');
        CODEUNIT.Run(CODEUNIT::"Undo Purchase Receipt Line", PurchRcptLine);

        // [THEN] ILE original: Qty = +10, DUoM Ratio = 0.8, DUoM Second Qty = +8
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange("Lot No.", LotNo);
        ILE.SetRange(Correction, false);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T-UNDO-02: ILE original no encontrado');
        LibraryAssert.AreNearlyEqual(0.8, ILE."DUoM Ratio", 0.001,
            'T-UNDO-02: ILE original DUoM Ratio debe ser 0.8');
        LibraryAssert.AreNearlyEqual(8, ILE."DUoM Second Qty", 0.001,
            'T-UNDO-02: ILE original DUoM Second Qty = +10 × 0.8 = +8');

        // [THEN] ILE corrección: Qty = -10, DUoM Ratio = 0.8, DUoM Second Qty = -8
        ILE.SetRange(Correction, true);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T-UNDO-02: ILE corrección no encontrado');
        LibraryAssert.AreNearlyEqual(0.8, ILE."DUoM Ratio", 0.001,
            'T-UNDO-02: ILE corrección DUoM Ratio debe ser 0.8');
        LibraryAssert.AreNearlyEqual(-8, ILE."DUoM Second Qty", 0.001,
            'T-UNDO-02: ILE corrección DUoM Second Qty = -10 × 0.8 = -8 (signo contrario)');
    end;

    // -------------------------------------------------------------------------
    // T-UNDO-03 — Anulación albarán compra multi-lote (criterio de aceptación clave)
    //
    // Escenario: 2 lotes con ratios distintos (A: 6 uds × 1.2 = 7.2; B: 4 uds × 1.8 = 7.2).
    // Suma original = +14.4; suma corrección = -14.4; total neto = 0.
    //
    // Verifica: Suma(ILE corrección Second Qty) = −Suma(ILE originales Second Qty).
    // -------------------------------------------------------------------------
    [Test]
    procedure UndoPurchaseReceipt_TwoLots_SumOfCorrILEIsOppositeSign()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        LotNoA: Code[50];
        LotNoB: Code[50];
        OriginalSum: Decimal;
        CorrectionSum: Decimal;
    begin
        Initialize();

        // [GIVEN] Artículo con DUoM Variable, lot tracking activo
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNoA := 'LOT-UNDO-03A';
        LotNoB := 'LOT-UNDO-03B';

        // [GIVEN] PO: Lote A = 6 uds × ratio 1.2; Lote B = 4 uds × ratio 1.8
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNoA, 6, 1.2);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNoB, 4, 1.8);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [WHEN] Se anula el albarán de compra contabilizado
        PurchRcptHeader.SetRange("Order No.", PurchHeader."No.");
        LibraryAssert.IsTrue(PurchRcptHeader.FindFirst(), 'T-UNDO-03: Se esperaba albarán contabilizado');
        PurchRcptLine.SetRange("Document No.", PurchRcptHeader."No.");
        LibraryAssert.IsTrue(PurchRcptLine.FindFirst(), 'T-UNDO-03: Se esperaba línea de albarán');
        CODEUNIT.Run(CODEUNIT::"Undo Purchase Receipt Line", PurchRcptLine);

        // [THEN] Suma de DUoM Second Qty de ILEs originales = +14.4
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange(Correction, false);
        OriginalSum := 0;
        if ILE.FindSet() then
            repeat
                OriginalSum += ILE."DUoM Second Qty";
            until ILE.Next() = 0;
        LibraryAssert.AreNearlyEqual(14.4, OriginalSum, 0.001,
            'T-UNDO-03: Suma ILEs originales = 6×1.2 + 4×1.8 = 7.2 + 7.2 = 14.4');

        // [THEN] Suma de DUoM Second Qty de ILEs corrección = -14.4 (signo contrario)
        ILE.SetRange(Correction, true);
        CorrectionSum := 0;
        if ILE.FindSet() then
            repeat
                CorrectionSum += ILE."DUoM Second Qty";
            until ILE.Next() = 0;
        LibraryAssert.AreNearlyEqual(-14.4, CorrectionSum, 0.001,
            'T-UNDO-03: Suma ILEs corrección = -(6×1.2 + 4×1.8) = -14.4 (signo contrario)');

        // [THEN] Suma total neta = 0 (anulación completa)
        LibraryAssert.AreNearlyEqual(0, OriginalSum + CorrectionSum, 0.001,
            'T-UNDO-03: Suma total neta DUoM Second Qty debe ser 0 tras la anulación');
    end;

    // -------------------------------------------------------------------------
    // T-UNDO-04 — Anulación albarán venta sin lote
    //
    // Escenario: artículo con DUoM Fixed (ratio = 0.8), venta de 10 uds.
    // Tras registrar el envío y anularlo:
    //   ILE original (venta):    Qty = -10, DUoM Second Qty = -8
    //   ILE corrección (undo):   Qty = +10, DUoM Second Qty = +8 (signo contrario)
    // -------------------------------------------------------------------------
    [Test]
    procedure UndoSalesShipment_NoLot_CorrILEHasDUoMFields()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        Customer: Record Customer;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentLine: Record "Sales Shipment Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        Initialize();

        // [GIVEN] Artículo con DUoM Fixed, ratio = 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Inventario de 100 uds vía pedido de compra
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 100);
        PurchLine.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [GIVEN] Pedido de venta de 10 uds, registrado (solo envío)
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 10);
        SalesLine.Modify(true);
        LibrarySales.PostSalesDocument(SalesHeader, true, false);

        // [WHEN] Se anula el albarán de venta contabilizado
        SalesShipmentHeader.SetRange("Order No.", SalesHeader."No.");
        LibraryAssert.IsTrue(SalesShipmentHeader.FindFirst(), 'T-UNDO-04: Se esperaba albarán venta');
        SalesShipmentLine.SetRange("Document No.", SalesShipmentHeader."No.");
        SalesShipmentLine.SetRange(Type, SalesShipmentLine.Type::Item);
        LibraryAssert.IsTrue(SalesShipmentLine.FindFirst(), 'T-UNDO-04: Se esperaba línea albarán venta');
        CODEUNIT.Run(CODEUNIT::"Undo Sales Shipment Line", SalesShipmentLine);

        // [THEN] ILE original (venta): Qty = -10, DUoM Second Qty = -8
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        ILE.SetRange(Correction, false);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T-UNDO-04: ILE original de venta no encontrado');
        LibraryAssert.AreNearlyEqual(0.8, ILE."DUoM Ratio", 0.001,
            'T-UNDO-04: ILE venta original DUoM Ratio debe ser 0.8');
        LibraryAssert.AreNearlyEqual(-8, ILE."DUoM Second Qty", 0.001,
            'T-UNDO-04: ILE venta original DUoM Second Qty = -10 × 0.8 = -8');

        // [THEN] ILE corrección (undo venta): Qty = +10, DUoM Second Qty = +8
        ILE.SetRange(Correction, true);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T-UNDO-04: ILE corrección venta no encontrado');
        LibraryAssert.AreNearlyEqual(0.8, ILE."DUoM Ratio", 0.001,
            'T-UNDO-04: ILE corrección venta DUoM Ratio debe ser 0.8');
        LibraryAssert.AreNearlyEqual(8, ILE."DUoM Second Qty", 0.001,
            'T-UNDO-04: ILE corrección venta DUoM Second Qty = +10 × 0.8 = +8 (signo contrario a ILE venta)');
    end;

    // -------------------------------------------------------------------------
    // T-UNDO-05 — Anulación albarán venta con lote
    //
    // Escenario: artículo con DUoM Variable, lote único con ratio = 1.25, 5 uds.
    // Tras registrar el envío y anularlo:
    //   ILE original (venta):    Qty = -5,  DUoM Second Qty = -6.25
    //   ILE corrección (undo):   Qty = +5,  DUoM Second Qty = +6.25
    // -------------------------------------------------------------------------
    [Test]
    procedure UndoSalesShipment_OneLot_CorrILEHasDUoMFields()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        Customer: Record Customer;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentLine: Record "Sales Shipment Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        Initialize();

        // [GIVEN] Artículo con DUoM Variable, lot tracking activo
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNo := 'LOT-UNDO-05';

        // [GIVEN] Inventario: 10 uds · lote LOT-UNDO-05 · DUoM Ratio = 1.25 (via PO)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNo, 10, 1.25);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [GIVEN] Pedido de venta: 5 uds · lote LOT-UNDO-05 · DUoM Ratio = 1.25
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 5);
        SalesLine.Modify(true);
        DUoMTestHelpers.AssignLotWithDUoMRatioToSalesLine(SalesLine, LotNo, 5, 1.25);
        LibrarySales.PostSalesDocument(SalesHeader, true, false);

        // [WHEN] Se anula el albarán de venta contabilizado
        SalesShipmentHeader.SetRange("Order No.", SalesHeader."No.");
        LibraryAssert.IsTrue(SalesShipmentHeader.FindFirst(), 'T-UNDO-05: Se esperaba albarán venta');
        SalesShipmentLine.SetRange("Document No.", SalesShipmentHeader."No.");
        SalesShipmentLine.SetRange(Type, SalesShipmentLine.Type::Item);
        LibraryAssert.IsTrue(SalesShipmentLine.FindFirst(), 'T-UNDO-05: Se esperaba línea albarán venta');
        CODEUNIT.Run(CODEUNIT::"Undo Sales Shipment Line", SalesShipmentLine);

        // [THEN] ILE original (venta): Qty = -5, DUoM Ratio = 1.25, Second Qty = -6.25
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        ILE.SetRange("Lot No.", LotNo);
        ILE.SetRange(Correction, false);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T-UNDO-05: ILE venta original no encontrado');
        LibraryAssert.AreNearlyEqual(1.25, ILE."DUoM Ratio", 0.001,
            'T-UNDO-05: ILE venta original DUoM Ratio debe ser 1.25');
        LibraryAssert.AreNearlyEqual(-6.25, ILE."DUoM Second Qty", 0.001,
            'T-UNDO-05: ILE venta original DUoM Second Qty = -5 × 1.25 = -6.25');

        // [THEN] ILE corrección (undo venta): Qty = +5, DUoM Ratio = 1.25, Second Qty = +6.25
        ILE.SetRange(Correction, true);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T-UNDO-05: ILE corrección venta no encontrado');
        LibraryAssert.AreNearlyEqual(1.25, ILE."DUoM Ratio", 0.001,
            'T-UNDO-05: ILE corrección venta DUoM Ratio debe ser 1.25');
        LibraryAssert.AreNearlyEqual(6.25, ILE."DUoM Second Qty", 0.001,
            'T-UNDO-05: ILE corrección venta DUoM Second Qty = +5 × 1.25 = +6.25 (signo contrario)');
    end;

    var
        IsInitialized: Boolean;
}
