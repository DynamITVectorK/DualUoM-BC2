/// <summary>
/// Integration tests end-to-end para el flujo de contabilización DUoM.
/// Verifica que los campos DUoM Second Qty y DUoM Ratio se propagan correctamente
/// desde las líneas de pedido hasta los documentos contabilizados y los
/// movimientos de producto (ILE) en una contabilización real de BC.
///
/// Cumple los requisitos de cierre de Phase 1 definidos en docs/05-testing-strategy.md:
///   4. Purchase posting — ILE contains correct second qty after posting a purchase receipt
///   5. Sales posting — ILE contains correct second qty after posting a sales shipment
///   6. Item journal posting — ILE contains correct second qty after posting an item journal line
/// </summary>
codeunit 50209 "DUoM ILE Integration Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // Purchase posting → ILE contains DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchasePosting_FixedMode_ILEHasDUoMFields()
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
        // [GIVEN] An item with DUoM setup: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] A purchase order for 10 units (DUoM Second Qty = 8, Ratio = 0.8 auto-computed)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] The purchase order is posted (Receive only)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] The resulting ILE contains the correct DUoM fields
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un Item Ledger Entry para la recepción de compra contabilizada');
        LibraryAssert.AreEqual(8, ILE."DUoM Second Qty", 'ILE DUoM Second Qty must be 10 × 0.8 = 8 after purchase posting');
        LibraryAssert.AreEqual(0.8, ILE."DUoM Ratio", 'ILE DUoM Ratio must be 0.8 after purchase posting');
    end;

    // -------------------------------------------------------------------------
    // Purchase posting → Purch. Rcpt. Line contains DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchasePosting_FixedMode_PurchRcptLineHasDUoMFields()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with DUoM setup: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] A purchase order for 10 units (DUoM Second Qty = 8, Ratio = 0.8 auto-computed)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] The purchase order is posted (Receive only)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] The resulting Purch. Rcpt. Line contains the correct DUoM fields
        PurchRcptHeader.SetRange("Order No.", PurchHeader."No.");
        LibraryAssert.IsTrue(PurchRcptHeader.FindFirst(), 'Se esperaba una cabecera de recepción de compra contabilizada');
        PurchRcptLine.SetRange("Document No.", PurchRcptHeader."No.");
        PurchRcptLine.SetRange(Type, PurchRcptLine.Type::Item);
        LibraryAssert.IsTrue(PurchRcptLine.FindFirst(), 'Se esperaba una línea de recepción de compra contabilizada');
        LibraryAssert.AreEqual(8, PurchRcptLine."DUoM Second Qty", 'Purch. Rcpt. Line DUoM Second Qty must be 10 × 0.8 = 8');
        LibraryAssert.AreEqual(0.8, PurchRcptLine."DUoM Ratio", 'Purch. Rcpt. Line DUoM Ratio must be 0.8');
    end;

    // -------------------------------------------------------------------------
    // Sales posting → ILE contains DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesPosting_FixedMode_ILEHasDUoMFields()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        Customer: Record Customer;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with DUoM setup: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Inventory is created via a purchase receipt (100 units)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 100);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [GIVEN] A sales order for 10 units (DUoM Second Qty = 8, Ratio = 0.8 auto-computed)
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 10);
        SalesLine.Modify(true);

        // [WHEN] The sales order is posted (Ship only)
        LibrarySales.PostSalesDocument(SalesHeader, true, false);

        // [THEN] The resulting Sale ILE contains the correct DUoM fields
        // DUoM Second Qty = Abs(ILE.Quantity) x DUoM Ratio = 10 x 0.8 = 8
        // ILE.Quantity es negativo en ventas; se usa Abs() para el recálculo.
        // El valor coincide con Sales Line pero la fuente es el recálculo, no la copia directa.
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un Item Ledger Entry de venta tras la contabilización del pedido de venta');
        LibraryAssert.AreEqual(8, ILE."DUoM Second Qty", 'ILE DUoM Second Qty must be 8 (copied from Sales Line) after sales posting');
        LibraryAssert.AreEqual(0.8, ILE."DUoM Ratio", 'ILE DUoM Ratio must be 0.8 after sales posting');
    end;

    // -------------------------------------------------------------------------
    // Sales posting → Sales Shipment Line contains DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesPosting_FixedMode_SalesShipmentLineHasDUoMFields()
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
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with DUoM setup: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Inventory is created via a purchase receipt (100 units)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 100);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [GIVEN] A sales order for 10 units (DUoM Second Qty = 8, Ratio = 0.8 auto-computed)
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 10);
        SalesLine.Modify(true);

        // [WHEN] The sales order is posted (Ship only)
        LibrarySales.PostSalesDocument(SalesHeader, true, false);

        // [THEN] The resulting Sales Shipment Line contains the correct DUoM fields
        SalesShipmentHeader.SetRange("Order No.", SalesHeader."No.");
        LibraryAssert.IsTrue(SalesShipmentHeader.FindFirst(), 'Se esperaba una cabecera de envío de venta contabilizada');
        SalesShipmentLine.SetRange("Document No.", SalesShipmentHeader."No.");
        SalesShipmentLine.SetRange(Type, SalesShipmentLine.Type::Item);
        LibraryAssert.IsTrue(SalesShipmentLine.FindFirst(), 'Se esperaba una línea de envío de venta contabilizada');
        LibraryAssert.AreEqual(8, SalesShipmentLine."DUoM Second Qty", 'Sales Shipment Line DUoM Second Qty must be 10 × 0.8 = 8');
        LibraryAssert.AreEqual(0.8, SalesShipmentLine."DUoM Ratio", 'Sales Shipment Line DUoM Ratio must be 0.8');
    end;

    // -------------------------------------------------------------------------
    // Item Journal posting → ILE contains DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure ItemJournalPosting_FixedMode_ILEHasDUoMFields()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with DUoM setup: Fixed mode, ratio 2
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 2);

        // [GIVEN] An Item Journal Line for 5 units (DUoM Second Qty = 10, Ratio = 2 auto-computed)
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine,
            ItemJnlBatch."Journal Template Name",
            ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase,
            Item."No.",
            0);
        ItemJnlLine.Validate(Quantity, 5);
        ItemJnlLine.Modify(true);

        // [WHEN] The item journal line is posted
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] The resulting ILE contains the correct DUoM fields
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un Item Ledger Entry tras la contabilización del diario de almacén');
        LibraryAssert.AreEqual(10, ILE."DUoM Second Qty", 'ILE DUoM Second Qty must be 5 × 2 = 10 after item journal posting');
        LibraryAssert.AreEqual(2, ILE."DUoM Ratio", 'ILE DUoM Ratio must be 2 after item journal posting');
    end;

    // -------------------------------------------------------------------------
    // Purchase posting without DUoM → ILE fields remain zero
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchasePosting_DUoMDisabled_ILEFieldsAreZero()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with NO DUoM setup (standard item)
        LibraryInventory.CreateItem(Item);

        // [GIVEN] A purchase order for 10 units
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 10);

        // [WHEN] The purchase order is posted (Receive only)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] The resulting ILE has zero DUoM fields — no DUoM configured for the item
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un Item Ledger Entry para el artículo sin configuración DUoM');
        LibraryAssert.AreEqual(0, ILE."DUoM Second Qty", 'ILE DUoM Second Qty must be 0 for an item without DUoM setup');
        LibraryAssert.AreEqual(0, ILE."DUoM Ratio", 'ILE DUoM Ratio must be 0 for an item without DUoM setup');
    end;

    // -------------------------------------------------------------------------
    // TEST 1 — Variable sin lotes, compra → ILE
    // Verifica que el modo Variable propaga DUoM Ratio y DUoM Second Qty al ILE
    // mediante el flujo estándar sin Item Tracking.
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchasePosting_VariableMode_ILEHasDUoMFields()
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
        // [GIVEN] Artículo modo Variable, ratio por defecto 1.5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 1.5);

        // [GIVEN] Pedido de compra 10 uds; DUoM Ratio = 1.5 autocomputado en la línea
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order,
            Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader,
            PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] Se registra (solo recepción)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] ILE: DUoM Ratio = 1.5 · DUoM Second Qty = 15
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T1: Se esperaba un ILE de compra para modo Variable sin lotes');
        LibraryAssert.AreNearlyEqual(1.5, ILE."DUoM Ratio", 0.001,
            'T1: ILE DUoM Ratio debe ser 1.5 (modo Variable)');
        LibraryAssert.AreNearlyEqual(15, ILE."DUoM Second Qty", 0.001,
            'T1: ILE DUoM Second Qty debe ser 10 × 1.5 = 15');
    end;

    // -------------------------------------------------------------------------
    // TEST 2 — AlwaysVariable sin lotes, compra → ILE
    // Verifica que los valores DUoM introducidos manualmente en AlwaysVariable
    // se propagan correctamente al ILE.
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchasePosting_AlwaysVarMode_ILEHasDUoMFields()
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
        // [GIVEN] Artículo modo AlwaysVariable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::AlwaysVariable, 0);

        // [GIVEN] Pedido de compra 10 uds; DUoM Ratio = 1.8 introducido manualmente
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order,
            Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader,
            PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine."DUoM Ratio" := 1.8;
        PurchLine."DUoM Second Qty" := 18;
        PurchLine.Modify(true);

        // [WHEN] Se registra (solo recepción)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] ILE: DUoM Ratio = 1.8 · DUoM Second Qty = 18
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T2: Se esperaba un ILE de compra para modo AlwaysVariable');
        LibraryAssert.AreNearlyEqual(1.8, ILE."DUoM Ratio", 0.001,
            'T2: ILE DUoM Ratio debe ser 1.8 (introducido manualmente)');
        LibraryAssert.AreNearlyEqual(18, ILE."DUoM Second Qty", 0.001,
            'T2: ILE DUoM Second Qty = Abs(10) × 1.8 = 18');
    end;

    // -------------------------------------------------------------------------
    // TEST 3 — Variable sin lotes, venta → ILE
    // Verifica que DUoM Second Qty se recalcula con Abs(ILE.Quantity) × Ratio
    // (ILE.Quantity es negativo en ventas).
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesPosting_VariableMode_ILEHasDUoMFields()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        Customer: Record Customer;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo modo Variable, ratio 1.5; stock creado via Purchase Order
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 1.5);

        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order,
            Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader,
            PurchLine.Type::Item, Item."No.", 100);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [GIVEN] Pedido de venta 10 uds; DUoM Ratio = 1.5 autocomputado en la línea
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order,
            Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader,
            SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 10);
        SalesLine.Modify(true);

        // [WHEN] Se registra (solo envío)
        LibrarySales.PostSalesDocument(SalesHeader, true, false);

        // [THEN] ILE Sale: DUoM Ratio = 1.5 · DUoM Second Qty = Abs(ILE.Quantity) × 1.5 = 15
        // NOTA: DUoM Second Qty se recalcula con Abs(ILE.Quantity) × Ratio, no se copia
        // de Sales Line. ILE.Quantity es negativo en ventas.
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T3: Se esperaba un ILE de venta para modo Variable');
        LibraryAssert.AreNearlyEqual(1.5, ILE."DUoM Ratio", 0.001,
            'T3: ILE Sale DUoM Ratio debe ser 1.5 (modo Variable)');
        LibraryAssert.AreNearlyEqual(15, ILE."DUoM Second Qty", 0.001,
            'T3: ILE Sale DUoM Second Qty = Abs(−10) × 1.5 = 15');
    end;

    // -------------------------------------------------------------------------
    // TEST 4 — Fixed, un lote desde Purchase Order → ILE
    // Verifica que el ratio fijo se propaga correctamente al ILE cuando hay
    // Item Tracking asignado en el pedido de compra.
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLotPosting_FixedMode_ILEHasDUoMFields()
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
        LotNo: Code[50];
    begin
        // [GIVEN] Artículo modo Fixed, ratio 0.8; Item Tracking Code con lotes habilitado
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Fixed, 0.8);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNo := 'LOT-ILE4';

        // [GIVEN] Pedido de compra 10 uds; un lote asignado en Item Tracking Lines
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order,
            Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader,
            PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNo, 10, 0.8);

        // [WHEN] Se registra (solo recepción)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] ILE Lote: DUoM Ratio = 0.8 · DUoM Second Qty = 10 × 0.8 = 8
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange("Lot No.", LotNo);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T4: Se esperaba un ILE de compra para el lote LOT-ILE4');
        LibraryAssert.AreNearlyEqual(0.8, ILE."DUoM Ratio", 0.001,
            'T4: ILE DUoM Ratio debe ser 0.8 (modo Fixed)');
        LibraryAssert.AreNearlyEqual(8, ILE."DUoM Second Qty", 0.001,
            'T4: ILE DUoM Second Qty = 10 × 0.8 = 8');
    end;

    // -------------------------------------------------------------------------
    // TEST 5 — Variable, dos lotes desde Purchase Order, ratios distintos → dos ILEs
    // Verifica la cadena ReservEntry → TrackingSpec (OnAfterCopyTrackingFromReservEntry)
    // → IJL (OnAfterCopyTrackingFromSpec) → ILE (ILECopyTrackingFromItemJnlLine).
    // El ratio de cada lote viene de Reservation Entry (escrito por
    // AssignLotWithDUoMRatioToPurchLine), NO de DUoM Lot Ratio (50102).
    // No se pre-registran ratios en DUoM Lot Ratio.
    // Si este test pasa con DUoM Lot Ratio vacío, la cadena de tracking es correcta.
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseTwoLots_VarMode_EachILEHasLotRatio()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        DUoMLotRatioRec: Record "DUoM Lot Ratio";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        LotNoA: Code[50];
        LotNoB: Code[50];
    begin
        // [GIVEN] Artículo modo Variable sin ratio fijo; Item Tracking habilitado
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNoA := 'LOT-ILE5A';
        LotNoB := 'LOT-ILE5B';

        // [GIVEN] DUoM Lot Ratio (50102) vacío para ambos lotes
        LibraryAssert.IsFalse(DUoMLotRatioRec.Get(Item."No.", LotNoA),
            'T5: DUoM Lot Ratio NO debe existir para Lote A');
        LibraryAssert.IsFalse(DUoMLotRatioRec.Get(Item."No.", LotNoB),
            'T5: DUoM Lot Ratio NO debe existir para Lote B');

        // [GIVEN] Pedido de compra 10 uds; dos lotes con ratios distintos en tracking
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order,
            Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader,
            PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);
        // Lote A: 6 uds · DUoM Ratio = 1.2 (introducido en tracking)
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNoA, 6, 1.2);
        // Lote B: 4 uds · DUoM Ratio = 1.8 (introducido en tracking)
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNoB, 4, 1.8);

        // [WHEN] Se registra (solo recepción)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] ILE Lote A: DUoM Ratio = 1.2 · DUoM Second Qty = 6 × 1.2 = 7.2
        // (6 uds Lote A con ratio 1.2 — diferente base y ratio que Lote B)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange("Lot No.", LotNoA);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T5: Se esperaba un ILE de compra para Lote A');
        LibraryAssert.AreNearlyEqual(1.2, ILE."DUoM Ratio", 0.001,
            'T5: ILE Lote A DUoM Ratio debe ser 1.2');
        LibraryAssert.AreNearlyEqual(7.2, ILE."DUoM Second Qty", 0.001,
            'T5: ILE Lote A DUoM Second Qty = 6 × 1.2 = 7.2');

        // [THEN] ILE Lote B: DUoM Ratio = 1.8 · DUoM Second Qty = 4 × 1.8 = 7.2
        // (4 uds Lote B con ratio 1.8 — coincide numéricamente con Lote A pero
        //  base y ratio son distintos: verifica que cada ILE usa su propio ratio)
        ILE.SetRange("Lot No.", LotNoB);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T5: Se esperaba un ILE de compra para Lote B');
        LibraryAssert.AreNearlyEqual(1.8, ILE."DUoM Ratio", 0.001,
            'T5: ILE Lote B DUoM Ratio debe ser 1.8');
        LibraryAssert.AreNearlyEqual(7.2, ILE."DUoM Second Qty", 0.001,
            'T5: ILE Lote B DUoM Second Qty = 4 × 1.8 = 7.2');
    end;

    // -------------------------------------------------------------------------
    // TEST UNITARIO HELPER — AssignLotWithDUoMRatioToPurchLine (sustituto de
    // AssignLotWithDUoMRatio_WritesTrackingSpec, eliminado en Issue 24)
    //
    // Verifica el contrato actual del helper:
    //   1. Escribe DUoM Ratio y DUoM Second Qty en la Reservation Entry.
    //   2. NO inserta ningún registro en Tracking Specification.
    //
    // El segundo assert es la comprobación anti-regresión clave: garantiza que
    // el helper no vuelva a insertar en TrackingSpec (lo que causaba colisiones
    // de Entry No. en PurchaseTwoLots — Issue 24).
    // -------------------------------------------------------------------------

    [Test]
    procedure AssignLotWithDUoMRatio_WritesReservEntry_NoTrackingSpec()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        // [GIVEN] Artículo con DUoM Variable habilitado; lot tracking activo
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNo := 'LOT-UNIT-T';

        // [GIVEN] Pedido de compra con una línea de 10 unidades
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order,
            Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader,
            PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] Se asigna un lote con DUoM Ratio a la Purchase Line
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNo, 10, 1.5);

        // [THEN] Existe una Reservation Entry con DUoM Ratio y DUoM Second Qty correctos
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Lot No.", LotNo);
        LibraryAssert.IsTrue(ReservEntry.FindFirst(),
            'Se esperaba una Reservation Entry para el lote asignado con DUoM Ratio');
        LibraryAssert.AreNearlyEqual(1.5, ReservEntry."DUoM Ratio", 0.001,
            'Reservation Entry: DUoM Ratio debe ser 1.5');
        LibraryAssert.AreNearlyEqual(15, ReservEntry."DUoM Second Qty", 0.001,
            'Reservation Entry: DUoM Second Qty debe ser 10 × 1.5 = 15');

        // [THEN] NO existe ningún registro en Tracking Specification para ese lote.
        // Anti-regresión Issue 24: el helper no debe insertar en TrackingSpec
        // (causaba colisiones de Entry No. al llamarse dos veces — PurchaseTwoLots).
        // BC construye el buffer de TrackingSpec internamente desde ReservEntry.
        TrackingSpec.SetRange("Item No.", Item."No.");
        TrackingSpec.SetRange("Lot No.", LotNo);
        LibraryAssert.IsFalse(TrackingSpec.FindFirst(),
            'NO debe existir Tracking Specification para el lote (el helper no debe insertar en TrackingSpec)');
    end;

    // -------------------------------------------------------------------------
    // TEST 6 (= T03 del issue: SalesLine_ItemTracking_DUoMValuesFromReservEntryOnPost)
    //
    // Verifica que la cadena Item Tracking en Sales Order propaga DUoM Ratio
    // correctamente desde Reservation Entry hasta el ILE de salida:
    //   ReservEntry (Positive=false, DUoM=1.25)
    //     → TrackingSpec (OnAfterCopyTrackingFromReservEntry en 50110)
    //     → IJL split (OnAfterCopyTrackingFromSpec en 50110)
    //     → ILE venta (OnAfterCopyTrackingFromItemJnlLine en 50110)
    //
    // Preparación:
    //   1. Crear inventario vía Purchase Order con lote + DUoM = 1.25
    //   2. Crear Sales Order con ReservEntry outbound para ese lote + DUoM = 1.25
    //   3. Contabilizar Sales Order (solo envío)
    //   4. Verificar ILE de venta tiene DUoM Ratio = 1.25 · DUoM Second Qty = 5 × 1.25
    // -------------------------------------------------------------------------
    [Test]
    procedure SalesLine_ItemTracking_DUoMValuesFromReservEntryOnPost()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        Customer: Record Customer;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        // [GIVEN] Artículo modo Variable, sin ratio fijo; Item Tracking habilitado
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNo := 'LOT-ILE6';

        // [GIVEN] Inventario creado vía Purchase Order: 10 uds · lote LOT-ILE6 · DUoM = 1.25
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order,
            Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader,
            PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNo, 10, 1.25);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [GIVEN] Pedido de venta: 5 uds con lote LOT-ILE6 · DUoM = 1.25
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order,
            Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item,
            Item."No.", 0);
        SalesLine.Validate(Quantity, 5);
        SalesLine.Modify(true);
        DUoMTestHelpers.AssignLotWithDUoMRatioToSalesLine(SalesLine, LotNo, 5, 1.25);

        // [WHEN] Se registra el pedido de venta (solo envío)
        LibrarySales.PostSalesDocument(SalesHeader, true, false);

        // [THEN] ILE de venta: DUoM Ratio = 1.25 · DUoM Second Qty = 5 × 1.25 = 6.25
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        ILE.SetRange("Lot No.", LotNo);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T03: Se esperaba un ILE de venta para el lote LOT-ILE6.');
        LibraryAssert.AreNearlyEqual(1.25, ILE."DUoM Ratio", 0.001,
            'T03: ILE venta DUoM Ratio debe ser 1.25.');
        LibraryAssert.AreNearlyEqual(6.25, ILE."DUoM Second Qty", 0.001,
            'T03: ILE venta DUoM Second Qty = 5 × 1.25 = 6.25.');
    end;

}
