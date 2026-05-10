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
        // DUoM Second Qty = ILE.Quantity x DUoM Ratio = -10 x 0.8 = -8
        // ILE.Quantity es negativo en ventas; DUoM Second Qty sigue el signo de ILE.Quantity
        // para coherencia con el estándar BC (movimientos de reversión con signo contrario).
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un Item Ledger Entry de venta tras la contabilización del pedido de venta');
        LibraryAssert.AreEqual(-8, ILE."DUoM Second Qty", 'ILE DUoM Second Qty must be -8 (ILE.Quantity × DUoM Ratio = -10 × 0.8) after sales posting');
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
            'T2: ILE DUoM Second Qty = 10 × 1.8 = 18');
    end;

    // -------------------------------------------------------------------------
    // TEST 3 — Variable sin lotes, venta → ILE
    // Verifica que DUoM Second Qty = ILE.Quantity × Ratio (signo coherente con ILE.Quantity).
    // ILE.Quantity es negativo en ventas → DUoM Second Qty negativo.
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

        // [THEN] ILE Sale: DUoM Ratio = 1.5 · DUoM Second Qty = ILE.Quantity × 1.5 = -15
        // ILE.Quantity es negativo en ventas; DUoM Second Qty toma signo negativo
        // para coherencia con el estándar BC.
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T3: Se esperaba un ILE de venta para modo Variable');
        LibraryAssert.AreNearlyEqual(1.5, ILE."DUoM Ratio", 0.001,
            'T3: ILE Sale DUoM Ratio debe ser 1.5 (modo Variable)');
        LibraryAssert.AreNearlyEqual(-15, ILE."DUoM Second Qty", 0.001,
            'T3: ILE Sale DUoM Second Qty = ILE.Quantity × 1.5 = -10 × 1.5 = -15');
    end;

    [Test]
    procedure PurchasePosting_PartialReceive_ProjectsProportionalDUoMToILE()
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
        // [GIVEN] Artículo modo Fixed con DUoM documental ya validado en la Purchase Line
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Validate("Qty. to Receive", 5);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza una recepción parcial
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] El IJL/ILE proyecta proporcionalmente 4 y la línea documental no se corrige
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un ILE para la recepción parcial de compra');
        LibraryAssert.AreEqual(4, ILE."DUoM Second Qty", 'Recepción parcial: DUoM Second Qty debe prorratearse de 8 a 4');
        LibraryAssert.AreEqual(0.8, ILE."DUoM Ratio", 'Recepción parcial: DUoM Ratio debe conservar el valor documental');

        PurchLine.Get(PurchLine."Document Type", PurchLine."Document No.", PurchLine."Line No.");
        LibraryAssert.AreEqual(8, PurchLine."DUoM Second Qty", 'La Purchase Line no debe modificarse durante el posting parcial');
        LibraryAssert.AreEqual(0.8, PurchLine."DUoM Ratio", 'La Purchase Line debe conservar su ratio documental');
    end;

    [Test]
    procedure SalesPosting_PartialShip_ProjectsSignedProportionalDUoMToILE()
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
        // [GIVEN] Stock disponible y una Sales Line con DUoM documental positivo ya validado
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 100);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 10);
        SalesLine.Validate("Qty. to Ship", 5);
        SalesLine.Modify(true);

        // [WHEN] Se contabiliza un envío parcial
        LibrarySales.PostSalesDocument(SalesHeader, true, false);

        // [THEN] El IJL/ILE aplica signo técnico de salida y prorratea a -4
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un ILE para el envío parcial de venta');
        LibraryAssert.AreEqual(-4, ILE."DUoM Second Qty", 'Envío parcial: DUoM Second Qty debe prorratearse y salir con signo negativo');
        LibraryAssert.AreEqual(0.8, ILE."DUoM Ratio", 'Envío parcial: DUoM Ratio debe conservar el valor documental');

        SalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        LibraryAssert.AreEqual(8, SalesLine."DUoM Second Qty", 'La Sales Line no debe modificarse durante el posting parcial');
        LibraryAssert.AreEqual(0.8, SalesLine."DUoM Ratio", 'La Sales Line debe conservar su ratio documental');
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
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
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
        // Note: filtering only by Item No. + Lot No. is acceptable here because we are
        // verifying absence of records created by the helper in an isolated test transaction
        // where no other documents share this item. SetSourceFilter is not required for
        // absence checks when test isolation guarantees uniqueness.
        // See docs/development/coding-standards.md.
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

        // [THEN] ILE de venta: DUoM Ratio = 1.25 · DUoM Second Qty = -5 × 1.25 = -6.25
        // DUoM Second Qty sigue el signo de ILE.Quantity (negativo en ventas).
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        ILE.SetRange("Lot No.", LotNo);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T03: Se esperaba un ILE de venta para el lote LOT-ILE6.');
        LibraryAssert.AreNearlyEqual(1.25, ILE."DUoM Ratio", 0.001,
            'T03: ILE venta DUoM Ratio debe ser 1.25.');
        LibraryAssert.AreNearlyEqual(-6.25, ILE."DUoM Second Qty", 0.001,
            'T03: ILE venta DUoM Second Qty = ILE.Quantity × 1.25 = -5 × 1.25 = -6.25.');
    end;

    [Test]
    procedure Regression_SalesTwoLots_SumsToILEAndInventory()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        Customer: Record Customer;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReservEntry: Record "Reservation Entry";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
        LotNoA: Code[50];
        LotNoB: Code[50];
        AggregatedReservSecondQty: Decimal;
        AggregatedILESecondQty: Decimal;
    begin
        // [GIVEN] Stock previo con 2 lotes y DUoM total = 8 (3 + 5)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNoA := 'LOT-SALE-2A';
        LotNoB := 'LOT-SALE-2B';

        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNoA, 5, 0.6);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNoB, 5, 1.0);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [GIVEN] Sales Line con DUoM total y tracking de dos lotes
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 10);
        SalesLine.Modify(true);
        DUoMTestHelpers.AssignLotWithDUoMRatioToSalesLine(SalesLine, LotNoA, 5, 0.6);
        DUoMTestHelpers.AssignLotWithDUoMRatioToSalesLine(SalesLine, LotNoB, 5, 1.0);

        SalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.");
        LibraryAssert.AreNearlyEqual(8, SalesLine."DUoM Second Qty", 0.001,
            'Regresión venta 2 lotes: Sales Line.DUoM Second Qty debe mantenerse en 8.');

        // [THEN] SUM(Reservation Entry.DUoM Second Qty) es coherente con la línea
        ReservEntry.SetSourceFilter(
            Database::"Sales Line",
            SalesLine."Document Type".AsInteger(),
            SalesHeader."No.",
            SalesLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange(Positive, false);
        ReservEntry.SetFilter("Lot No.", '<>%1', '');
        LibraryAssert.IsTrue(ReservEntry.FindSet(),
            'Regresión venta 2 lotes: Deben existir Reservation Entry salientes.');
        repeat
            AggregatedReservSecondQty += ReservEntry."DUoM Second Qty";
        until ReservEntry.Next() = 0;
        LibraryAssert.AreNearlyEqual(8, Abs(AggregatedReservSecondQty), 0.001,
            'Regresión venta 2 lotes: SUM(Reservation Entry.DUoM Second Qty) debe ser coherente con 8.');

        // [WHEN] Se contabiliza el envío
        LibrarySales.PostSalesDocument(SalesHeader, true, false);

        // [THEN] Se generan ILE por lote y la suma DUoM es -8 (salida)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        ILE.SetRange("Lot No.", LotNoA);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'Regresión venta 2 lotes: Debe existir ILE de venta para lote A.');
        ILE.SetRange("Lot No.", LotNoB);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'Regresión venta 2 lotes: Debe existir ILE de venta para lote B.');

        ILE.SetFilter("Lot No.", '%1|%2', LotNoA, LotNoB);
        if ILE.FindSet() then
            repeat
                AggregatedILESecondQty += ILE."DUoM Second Qty";
            until ILE.Next() = 0;
        LibraryAssert.AreNearlyEqual(-8, AggregatedILESecondQty, 0.001,
            'Regresión venta 2 lotes: SUM(ILE.DUoM Second Qty) debe ser -8.');

        Item.Get(Item."No.");
        Item.CalcFields("DUoM Inventory");
        LibraryAssert.AreNearlyEqual(0, Item."DUoM Inventory", 0.001,
            'Regresión venta 2 lotes: DUoM Inventory debe quedar en 0 tras compra(+8) y venta(-8).');
    end;

    [Test]
    procedure Regression_PurchaseOneLot_LineReservILEInventory_Coherent()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        // [GIVEN] Purchase Line con DUoM Second Qty total y tracking de un lote coherente
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNo := 'LOT-REG-1';

        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNo, 10, 0.8);

        // [THEN] Purchase Line mantiene el total DUoM y Reservation Entry conserva desglose
        PurchLine.Get(PurchLine."Document Type", PurchLine."Document No.", PurchLine."Line No.");
        LibraryAssert.AreNearlyEqual(8, PurchLine."DUoM Second Qty", 0.001,
            'Regresión 1 lote: Purchase Line.DUoM Second Qty debe mantenerse en 8.');

        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Lot No.", LotNo);
        LibraryAssert.IsTrue(ReservEntry.FindFirst(),
            'Regresión 1 lote: Debe existir Reservation Entry para el lote asignado.');
        LibraryAssert.AreNearlyEqual(8, ReservEntry."DUoM Second Qty", 0.001,
            'Regresión 1 lote: Reservation Entry.DUoM Second Qty debe ser 8.');

        // [WHEN] Se registra la recepción
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] ILE recibe DUoM correctamente y DUoM Inventory refleja el stock registrado
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange("Lot No.", LotNo);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'Regresión 1 lote: Debe existir ILE de compra para el lote.');
        LibraryAssert.AreNearlyEqual(0.8, ILE."DUoM Ratio", 0.001,
            'Regresión 1 lote: ILE.DUoM Ratio debe ser 0.8.');
        LibraryAssert.AreNearlyEqual(8, ILE."DUoM Second Qty", 0.001,
            'Regresión 1 lote: ILE.DUoM Second Qty debe ser 8.');

        Item.Get(Item."No.");
        Item.CalcFields("DUoM Inventory");
        LibraryAssert.AreNearlyEqual(8, Item."DUoM Inventory", 0.001,
            'Regresión 1 lote: DUoM Inventory debe ser 8.');
    end;

    [Test]
    procedure Regression_PurchaseTwoLots_SumsToLineILEAndInventory()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        LotNoA: Code[50];
        LotNoB: Code[50];
        AggregatedReservSecondQty: Decimal;
        AggregatedILESecondQty: Decimal;
    begin
        // [GIVEN] Purchase Line DUoM Second Qty = 8 y dos lotes con desglose 3 + 5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNoA := 'LOT-REG-2A';
        LotNoB := 'LOT-REG-2B';

        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // Lote A = 3 (5 × 0.6), Lote B = 5 (5 × 1.0), SUM = 8
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNoA, 5, 0.6);
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNoB, 5, 1.0);

        PurchLine.Get(PurchLine."Document Type", PurchLine."Document No.", PurchLine."Line No.");
        LibraryAssert.AreNearlyEqual(8, PurchLine."DUoM Second Qty", 0.001,
            'Regresión 2 lotes: Purchase Line.DUoM Second Qty debe mantenerse en 8.');

        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange(Positive, true);
        LibraryAssert.IsTrue(ReservEntry.FindSet(),
            'Regresión 2 lotes: Deben existir Reservation Entry positivas.');
        repeat
            AggregatedReservSecondQty += ReservEntry."DUoM Second Qty";
        until ReservEntry.Next() = 0;
        LibraryAssert.AreNearlyEqual(8, AggregatedReservSecondQty, 0.001,
            'Regresión 2 lotes: SUM(Reservation Entry.DUoM Second Qty) debe ser 8.');

        // [WHEN] Se registra la recepción
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] Se crean ILE por lote y su suma DUoM también es 8
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange("Lot No.", LotNoA);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'Regresión 2 lotes: Debe existir ILE para el lote A.');

        ILE.SetRange("Lot No.", LotNoB);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'Regresión 2 lotes: Debe existir ILE para el lote B.');

        ILE.SetRange("Lot No.");
        if ILE.FindSet() then
            repeat
                AggregatedILESecondQty += ILE."DUoM Second Qty";
            until ILE.Next() = 0;
        LibraryAssert.AreNearlyEqual(8, AggregatedILESecondQty, 0.001,
            'Regresión 2 lotes: SUM(ILE.DUoM Second Qty) debe ser 8.');

        Item.Get(Item."No.");
        Item.CalcFields("DUoM Inventory");
        LibraryAssert.AreNearlyEqual(8, Item."DUoM Inventory", 0.001,
            'Regresión 2 lotes: DUoM Inventory debe ser 8.');
    end;

    [Test]
    procedure DUoMInventory_PurchasePosting_IncreasesStock()
    var
        Item: Record Item;
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM con ratio fijo 1 y una compra registrada de 8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1);
        PostPurchaseOrder(Item."No.", 8, '', '', WorkDate());

        // [WHEN] Se calcula el FlowField DUoM Inventory
        Item.Get(Item."No.");
        Item.CalcFields("DUoM Inventory");

        // [THEN] DUoM Inventory refleja la suma en ILE
        LibraryAssert.AreEqual(8, Item."DUoM Inventory", 'DUoM Inventory debe ser 8 tras la compra registrada');
    end;

    [Test]
    procedure DUoMInventory_PurchaseAndSale_NetStock()
    var
        Item: Record Item;
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM con una compra (+8) y una venta (-3)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1);
        PostPurchaseOrder(Item."No.", 8, '', '', WorkDate());
        PostSalesOrder(Item."No.", 3, '', '', WorkDate());

        // [WHEN] Se calcula el FlowField DUoM Inventory
        Item.Get(Item."No.");
        Item.CalcFields("DUoM Inventory");

        // [THEN] DUoM Inventory refleja el neto registrado
        LibraryAssert.AreEqual(5, Item."DUoM Inventory", 'DUoM Inventory debe reflejar el neto 8 - 3 = 5');
    end;

    [Test]
    procedure DUoMInventory_LocationFilter_Applies()
    var
        Item: Record Item;
        LocationBlue: Record Location;
        LocationRed: Record Location;
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM con movimientos en dos ubicaciones
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1);
        LibraryWarehouse.CreateLocation(LocationBlue);
        LibraryWarehouse.CreateLocation(LocationRed);
        DUoMTestHelpers.EnsureInventoryPostingSetupForLocation(Item, LocationBlue.Code);
        DUoMTestHelpers.EnsureInventoryPostingSetupForLocation(Item, LocationRed.Code);
        PostPurchaseOrder(Item."No.", 8, LocationBlue.Code, '', WorkDate());
        PostPurchaseOrder(Item."No.", 5, LocationRed.Code, '', WorkDate());

        // [WHEN] Se calcula DUoM Inventory filtrando por ubicación
        Item.Get(Item."No.");
        Item.SetRange("Location Filter", LocationBlue.Code);
        Item.CalcFields("DUoM Inventory");

        // [THEN] Solo se incluye la ubicación filtrada
        LibraryAssert.AreEqual(8, Item."DUoM Inventory", 'DUoM Inventory debe incluir solo la ubicación filtrada');
    end;

    [Test]
    procedure DUoMInventory_VariantAndDateFilters_Apply()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        FirstPostingDate: Date;
        SecondPostingDate: Date;
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM con dos variantes y fechas distintas
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1);
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ROMANA', ItemVariant);
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ICEBERG', ItemVariant);
        FirstPostingDate := DMY2Date(1, 1, 2026);
        SecondPostingDate := DMY2Date(15, 1, 2026);
        PostPurchaseOrder(Item."No.", 8, '', 'ROMANA', FirstPostingDate);
        PostPurchaseOrder(Item."No.", 5, '', 'ICEBERG', SecondPostingDate);

        // [WHEN] Se calcula DUoM Inventory filtrando por variante y fecha
        Item.Get(Item."No.");
        Item.SetRange("Variant Filter", 'ROMANA');
        Item.SetRange("Date Filter", 0D, FirstPostingDate);
        Item.CalcFields("DUoM Inventory");

        // [THEN] Solo se incluye el movimiento de la variante/fecha filtradas
        LibraryAssert.AreEqual(8, Item."DUoM Inventory", 'DUoM Inventory debe respetar Variant Filter y Date Filter');
    end;

    [Test]
    procedure DUoMInventory_EqualsManualILESum_WithSameFilters()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        LocationBlue: Record Location;
        FlowFieldInventory: Decimal;
        ManualInventory: Decimal;
        CutoffDate: Date;
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM con múltiples movimientos y filtros combinados
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1);
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ROMANA', ItemVariant);
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ICEBERG', ItemVariant);
        LibraryWarehouse.CreateLocation(LocationBlue);
        CutoffDate := DMY2Date(1, 2, 2026);
        DUoMTestHelpers.EnsureInventoryPostingSetupForLocation(Item, LocationBlue.Code);
        PostPurchaseOrder(Item."No.", 8, LocationBlue.Code, 'ROMANA', DMY2Date(1, 1, 2026));
        PostPurchaseOrder(Item."No.", 5, LocationBlue.Code, 'ICEBERG', DMY2Date(15, 1, 2026));
        PostPurchaseOrder(Item."No.", 3, '', 'ROMANA', DMY2Date(1, 3, 2026));

        // [WHEN] Se calcula DUoM Inventory y la suma manual de ILE con los mismos filtros
        Item.Get(Item."No.");
        Item.SetRange("Location Filter", LocationBlue.Code);
        Item.SetRange("Variant Filter", 'ROMANA');
        Item.SetRange("Date Filter", 0D, CutoffDate);
        Item.CalcFields("DUoM Inventory");
        FlowFieldInventory := Item."DUoM Inventory";
        ManualInventory := SumILESecondQty(Item."No.", LocationBlue.Code, 'ROMANA', 0D, CutoffDate);

        // [THEN] Ambos importes coinciden
        LibraryAssert.AreEqual(ManualInventory, FlowFieldInventory, 'DUoM Inventory debe coincidir con SUM(ILE.DUoM Second Qty) con los mismos filtros');
    end;

    local procedure PostPurchaseOrder(ItemNo: Code[20]; LineQuantity: Decimal; LocationCode: Code[10]; VariantCode: Code[10]; PostingDate: Date)
    var
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        LibraryPurchase: Codeunit "Library - Purchase";
    begin
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        PurchHeader.Validate("Posting Date", PostingDate);
        PurchHeader.Modify(true);

        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, ItemNo, 0);
        if VariantCode <> '' then
            PurchLine.Validate("Variant Code", VariantCode);
        if LocationCode <> '' then
            PurchLine.Validate("Location Code", LocationCode);
        PurchLine.Validate(Quantity, LineQuantity);
        PurchLine.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);
    end;

    local procedure PostSalesOrder(ItemNo: Code[20]; LineQuantity: Decimal; LocationCode: Code[10]; VariantCode: Code[10]; PostingDate: Date)
    var
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        LibrarySales: Codeunit "Library - Sales";
    begin
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        SalesHeader.Validate("Posting Date", PostingDate);
        SalesHeader.Modify(true);

        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, 0);
        if VariantCode <> '' then
            SalesLine.Validate("Variant Code", VariantCode);
        if LocationCode <> '' then
            SalesLine.Validate("Location Code", LocationCode);
        SalesLine.Validate(Quantity, LineQuantity);
        SalesLine.Modify(true);
        LibrarySales.PostSalesDocument(SalesHeader, true, false);
    end;

    local procedure SumILESecondQty(ItemNo: Code[20]; LocationCode: Code[10]; VariantCode: Code[10]; DateFrom: Date; DateTo: Date): Decimal
    var
        ItemLedgEntry: Record "Item Ledger Entry";
        TotalSecondQty: Decimal;
    begin
        ItemLedgEntry.SetRange("Item No.", ItemNo);
        if LocationCode <> '' then
            ItemLedgEntry.SetRange("Location Code", LocationCode);
        if VariantCode <> '' then
            ItemLedgEntry.SetRange("Variant Code", VariantCode);
        ItemLedgEntry.SetRange("Posting Date", DateFrom, DateTo);

        if ItemLedgEntry.FindSet() then
            repeat
                TotalSecondQty += ItemLedgEntry."DUoM Second Qty";
            until ItemLedgEntry.Next() = 0;

        exit(TotalSecondQty);
    end;

}
