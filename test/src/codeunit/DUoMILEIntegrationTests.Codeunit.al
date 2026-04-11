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
        // Note: DUoM Second Qty is copied from Sales Line (positive value) without sign adjustment
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
}
