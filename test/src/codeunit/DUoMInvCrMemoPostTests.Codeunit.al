/// <summary>
/// Tests de integración para la propagación DUoM a históricos de facturas y abonos
/// de compra y venta. Verifica que los campos DUoM Second Qty y DUoM Ratio se
/// copian correctamente desde las líneas de pedido a los documentos históricos
/// registrados durante la contabilización real de BC.
///
/// Cubre los requisitos de la issue "Propagar y conservar DUoM en históricos de
/// facturas y abonos de ventas y compras":
///   - Purch. Inv. Line conserva la información DUoM esperada
///   - Purch. Cr. Memo Line conserva la información DUoM esperada
///   - Sales Invoice Line conserva la información DUoM esperada
///   - Sales Cr.Memo Line conserva la información DUoM esperada
/// </summary>
codeunit 50210 "DUoM Inv CrMemo Post Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // Purchase Order → Posted Invoice → Purch. Inv. Line contains DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchInvoice_FixedMode_InvLineHasDUoMFields()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchInvLine: Record "Purch. Inv. Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo con configuración DUoM: modo Fijo, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Un pedido de compra para 10 unidades (DUoM Second Qty = 8, Ratio = 0.8)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el pedido de compra como Recepción + Factura
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, true);

        // [THEN] La Purch. Inv. Line resultante contiene los campos DUoM correctos
        PurchInvHeader.SetRange("Order No.", PurchHeader."No.");
        LibraryAssert.IsTrue(PurchInvHeader.FindFirst(), 'Se esperaba una cabecera de factura de compra registrada');
        PurchInvLine.SetRange("Document No.", PurchInvHeader."No.");
        PurchInvLine.SetRange(Type, PurchInvLine.Type::Item);
        LibraryAssert.IsTrue(PurchInvLine.FindFirst(), 'Se esperaba una línea de factura de compra registrada');
        LibraryAssert.AreEqual(8, PurchInvLine."DUoM Second Qty", 'Purch. Inv. Line DUoM Second Qty debe ser 10 × 0.8 = 8');
        LibraryAssert.AreEqual(0.8, PurchInvLine."DUoM Ratio", 'Purch. Inv. Line DUoM Ratio debe ser 0.8');
    end;

    // -------------------------------------------------------------------------
    // Purchase Credit Memo → Purch. Cr. Memo Line contains DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchCrMemo_FixedMode_CrMemoLineHasDUoMFields()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        PurchCrMemoLine: Record "Purch. Cr. Memo Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo con configuración DUoM: modo Fijo, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Un abono de compra para 5 unidades (DUoM Second Qty = 4, Ratio = 0.8)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::"Credit Memo", Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el abono de compra
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, true);

        // [THEN] La Purch. Cr. Memo Line resultante contiene los campos DUoM correctos
        PurchCrMemoHdr.SetRange("Pay-to Vendor No.", Vendor."No.");
        LibraryAssert.IsTrue(PurchCrMemoHdr.FindLast(), 'Se esperaba una cabecera de abono de compra registrado');
        PurchCrMemoLine.SetRange("Document No.", PurchCrMemoHdr."No.");
        PurchCrMemoLine.SetRange(Type, PurchCrMemoLine.Type::Item);
        LibraryAssert.IsTrue(PurchCrMemoLine.FindFirst(), 'Se esperaba una línea de abono de compra registrado');
        LibraryAssert.AreEqual(4, PurchCrMemoLine."DUoM Second Qty", 'Purch. Cr. Memo Line DUoM Second Qty debe ser 5 × 0.8 = 4');
        LibraryAssert.AreEqual(0.8, PurchCrMemoLine."DUoM Ratio", 'Purch. Cr. Memo Line DUoM Ratio debe ser 0.8');
    end;

    // -------------------------------------------------------------------------
    // Sales Order → Posted Invoice → Sales Invoice Line contains DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesInvoice_FixedMode_InvLineHasDUoMFields()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        Customer: Record Customer;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesInvHeader: Record "Sales Invoice Header";
        SalesInvLine: Record "Sales Invoice Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo con configuración DUoM: modo Fijo, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Se crea inventario mediante una recepción de compra (100 unidades)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 100);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [GIVEN] Un pedido de venta para 10 unidades (DUoM Second Qty = 8, Ratio = 0.8)
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 10);
        SalesLine.Modify(true);

        // [WHEN] Se contabiliza el pedido de venta como Envío + Factura
        LibrarySales.PostSalesDocument(SalesHeader, true, true);

        // [THEN] La Sales Invoice Line resultante contiene los campos DUoM correctos
        SalesInvHeader.SetRange("Order No.", SalesHeader."No.");
        LibraryAssert.IsTrue(SalesInvHeader.FindFirst(), 'Se esperaba una cabecera de factura de venta registrada');
        SalesInvLine.SetRange("Document No.", SalesInvHeader."No.");
        SalesInvLine.SetRange(Type, SalesInvLine.Type::Item);
        LibraryAssert.IsTrue(SalesInvLine.FindFirst(), 'Se esperaba una línea de factura de venta registrada');
        LibraryAssert.AreEqual(8, SalesInvLine."DUoM Second Qty", 'Sales Invoice Line DUoM Second Qty debe ser 10 × 0.8 = 8');
        LibraryAssert.AreEqual(0.8, SalesInvLine."DUoM Ratio", 'Sales Invoice Line DUoM Ratio debe ser 0.8');
    end;

    // -------------------------------------------------------------------------
    // Sales Credit Memo → Sales Cr.Memo Line contains DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesCrMemo_FixedMode_CrMemoLineHasDUoMFields()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo con configuración DUoM: modo Fijo, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Un abono de venta para 5 unidades (DUoM Second Qty = 4, Ratio = 0.8)
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::"Credit Memo", Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 5);
        SalesLine.Modify(true);

        // [WHEN] Se contabiliza el abono de venta
        LibrarySales.PostSalesDocument(SalesHeader, true, true);

        // [THEN] La Sales Cr.Memo Line resultante contiene los campos DUoM correctos
        SalesCrMemoHeader.SetRange("Sell-to Customer No.", Customer."No.");
        LibraryAssert.IsTrue(SalesCrMemoHeader.FindLast(), 'Se esperaba una cabecera de abono de venta registrado');
        SalesCrMemoLine.SetRange("Document No.", SalesCrMemoHeader."No.");
        SalesCrMemoLine.SetRange(Type, SalesCrMemoLine.Type::Item);
        LibraryAssert.IsTrue(SalesCrMemoLine.FindFirst(), 'Se esperaba una línea de abono de venta registrado');
        LibraryAssert.AreEqual(4, SalesCrMemoLine."DUoM Second Qty", 'Sales Cr.Memo Line DUoM Second Qty debe ser 5 × 0.8 = 4');
        LibraryAssert.AreEqual(0.8, SalesCrMemoLine."DUoM Ratio", 'Sales Cr.Memo Line DUoM Ratio debe ser 0.8');
    end;

    // -------------------------------------------------------------------------
    // Purchase Invoice without DUoM → Purch. Inv. Line fields remain zero
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchInvoice_DUoMDisabled_InvLineFieldsAreZero()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchInvLine: Record "Purch. Inv. Line";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo sin configuración DUoM
        LibraryInventory.CreateItem(Item);

        // [GIVEN] Un pedido de compra para 10 unidades
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 10);

        // [WHEN] Se contabiliza el pedido de compra como Recepción + Factura
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, true);

        // [THEN] La Purch. Inv. Line tiene campos DUoM en cero — artículo sin DUoM
        PurchInvHeader.SetRange("Order No.", PurchHeader."No.");
        LibraryAssert.IsTrue(PurchInvHeader.FindFirst(), 'Se esperaba una cabecera de factura de compra registrada');
        PurchInvLine.SetRange("Document No.", PurchInvHeader."No.");
        PurchInvLine.SetRange(Type, PurchInvLine.Type::Item);
        LibraryAssert.IsTrue(PurchInvLine.FindFirst(), 'Se esperaba una línea de factura de compra registrada');
        LibraryAssert.AreEqual(0, PurchInvLine."DUoM Second Qty", 'Purch. Inv. Line DUoM Second Qty debe ser 0 sin configuración DUoM');
        LibraryAssert.AreEqual(0, PurchInvLine."DUoM Ratio", 'Purch. Inv. Line DUoM Ratio debe ser 0 sin configuración DUoM');
    end;
}
