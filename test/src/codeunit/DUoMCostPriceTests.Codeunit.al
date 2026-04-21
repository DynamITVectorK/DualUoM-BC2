/// <summary>
/// Tests TDD para el modelo de Coste/Precio en Doble UdM (Issue 12).
/// Verifica que DUoM Unit Cost y DUoM Unit Price se derivan correctamente
/// desde/hacia los campos estándar de BC (Direct Unit Cost / Unit Price),
/// y que DUoM Second Qty se propaga a Value Entry tras la contabilización.
///
/// Tests T01-T08 según la Definition of Done del Issue 12.
/// </summary>
codeunit 50216 "DUoM Cost Price Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T01 — DUoM Unit Price → Unit Price derivado (ratio fijo)
    // -------------------------------------------------------------------------

    [Test]
    procedure T01_DUoMUnitPrice_WithFixedRatio_DerivesUnitPrice()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Item con DUoM: Fixed, ratio 5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 5);

        // [GIVEN] Sales Order line para ese item con ratio ya establecido
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 1);
        SalesLine."DUoM Ratio" := 5;
        SalesLine.Modify(false);

        // [WHEN] Se valida DUoM Unit Price = 10
        SalesLine.Validate("DUoM Unit Price", 10);

        // [THEN] Unit Price = 10 / 5 = 2
        LibraryAssert.AreEqual(2, SalesLine."Unit Price", 'Unit Price debe ser DUoM Unit Price / DUoM Ratio = 10 / 5 = 2');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // T02 — Unit Price modificado → DUoM Unit Price recalculado
    // -------------------------------------------------------------------------

    [Test]
    procedure T02_UnitPriceChanged_WithFixedRatio_RecalcsDUoMUnitPrice()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Item con DUoM: Fixed, ratio 5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 5);

        // [GIVEN] Sales Order line con ratio = 5 pre-establecido
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 1);
        SalesLine."DUoM Ratio" := 5;
        SalesLine.Modify(false);

        // [WHEN] Se modifica Unit Price a 3
        SalesLine.Validate("Unit Price", 3);

        // [THEN] DUoM Unit Price = 3 × 5 = 15
        LibraryAssert.AreEqual(15, SalesLine."DUoM Unit Price", 'DUoM Unit Price debe ser Unit Price × DUoM Ratio = 3 × 5 = 15');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // T03 — DUoM Unit Cost → Direct Unit Cost derivado (ratio fijo)
    // -------------------------------------------------------------------------

    [Test]
    procedure T03_DUoMUnitCost_WithFixedRatio_DerivesDirectUnitCost()
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
        // [GIVEN] Item con DUoM: Fixed, ratio 5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 5);

        // [GIVEN] Purchase Order line para ese item con ratio = 5
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 1);
        PurchLine."DUoM Ratio" := 5;
        PurchLine.Modify(false);

        // [WHEN] Se valida DUoM Unit Cost = 10
        PurchLine.Validate("DUoM Unit Cost", 10);

        // [THEN] Direct Unit Cost = 10 / 5 = 2
        LibraryAssert.AreEqual(2, PurchLine."Direct Unit Cost", 'Direct Unit Cost debe ser DUoM Unit Cost / DUoM Ratio = 10 / 5 = 2');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // T04 — Modo AlwaysVariable (ratio = 0) → no se deriva precio/coste
    // -------------------------------------------------------------------------

    [Test]
    procedure T04_AlwaysVariableMode_RatioZero_NoPriceCostDerivation()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        OriginalDirectUnitCost: Decimal;
    begin
        // [GIVEN] Item con DUoM: AlwaysVariable (ratio = 0)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::AlwaysVariable, 0);

        // [GIVEN] Purchase Order line con ratio = 0
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 1);
        // DUoM Ratio queda en 0 (AlwaysVariable, sin ratio)
        OriginalDirectUnitCost := PurchLine."Direct Unit Cost";

        // [WHEN] Se valida DUoM Unit Cost = 50 con ratio = 0
        PurchLine."DUoM Unit Cost" := 50;
        PurchLine.Validate("DUoM Unit Cost", 50);

        // [THEN] Direct Unit Cost NO cambia (ratio = 0 bloquea la derivación)
        LibraryAssert.AreEqual(OriginalDirectUnitCost, PurchLine."Direct Unit Cost",
            'Direct Unit Cost no debe cambiar cuando DUoM Ratio = 0 (modo AlwaysVariable)');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // T05 — Purchase Order con DUoM Unit Cost → contabilizar → Purch. Rcpt. Line
    // -------------------------------------------------------------------------

    [Test]
    procedure T05_PurchaseOrder_WithDUoMUnitCost_PostedToPurchRcptLine()
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
        // [GIVEN] Item con DUoM: Fixed, ratio 5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 5);

        // [GIVEN] Purchase Order con Qty = 10 y DUoM Unit Cost = 50 (Ratio 5 auto-calculado)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        // Ratio = 5 se auto-calcula. Ahora establecemos DUoM Unit Cost.
        PurchLine.Validate("DUoM Unit Cost", 50);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el pedido (sólo recepción)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] Purch. Rcpt. Line tiene DUoM Unit Cost = 50
        PurchRcptHeader.SetRange("Order No.", PurchHeader."No.");
        LibraryAssert.IsTrue(PurchRcptHeader.FindFirst(), 'Se esperaba una cabecera de recepción de compra contabilizada');
        PurchRcptLine.SetRange("Document No.", PurchRcptHeader."No.");
        PurchRcptLine.SetRange(Type, PurchRcptLine.Type::Item);
        LibraryAssert.IsTrue(PurchRcptLine.FindFirst(), 'Se esperaba una línea de recepción de compra contabilizada');
        LibraryAssert.AreEqual(50, PurchRcptLine."DUoM Unit Cost", 'Purch. Rcpt. Line DUoM Unit Cost debe ser 50');
    end;

    // -------------------------------------------------------------------------
    // T06 — Sales Order con DUoM Unit Price → contabilizar → Ship + Inv Line
    // -------------------------------------------------------------------------

    [Test]
    procedure T06_SalesOrder_WithDUoMUnitPrice_PostedToShipAndInvLine()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesShptHeader: Record "Sales Shipment Header";
        SalesShptLine: Record "Sales Shipment Line";
        SalesInvHeader: Record "Sales Invoice Header";
        SalesInvLine: Record "Sales Invoice Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Item con DUoM: Fixed, ratio 5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 5);

        // [GIVEN] Sales Order con Qty = 4 y DUoM Unit Price = 100 (Ratio 5 auto-calculado)
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 4);
        SalesLine.Validate("DUoM Unit Price", 100);
        SalesLine.Modify(true);

        // [WHEN] Se contabiliza el pedido (envío + factura)
        LibrarySales.PostSalesDocument(SalesHeader, true, true);

        // [THEN] Sales Shipment Line tiene DUoM Unit Price = 100
        SalesShptHeader.SetRange("Order No.", SalesHeader."No.");
        LibraryAssert.IsTrue(SalesShptHeader.FindFirst(), 'Se esperaba una cabecera de envío de venta contabilizado');
        SalesShptLine.SetRange("Document No.", SalesShptHeader."No.");
        SalesShptLine.SetRange(Type, SalesShptLine.Type::Item);
        LibraryAssert.IsTrue(SalesShptLine.FindFirst(), 'Se esperaba una línea de envío de venta contabilizado');
        LibraryAssert.AreEqual(100, SalesShptLine."DUoM Unit Price", 'Sales Shipment Line DUoM Unit Price debe ser 100');

        // [THEN] Sales Invoice Line tiene DUoM Unit Price = 100
        SalesInvHeader.SetRange("Order No.", SalesHeader."No.");
        LibraryAssert.IsTrue(SalesInvHeader.FindFirst(), 'Se esperaba una cabecera de factura de venta contabilizada');
        SalesInvLine.SetRange("Document No.", SalesInvHeader."No.");
        SalesInvLine.SetRange(Type, SalesInvLine.Type::Item);
        LibraryAssert.IsTrue(SalesInvLine.FindFirst(), 'Se esperaba una línea de factura de venta contabilizada');
        LibraryAssert.AreEqual(100, SalesInvLine."DUoM Unit Price", 'Sales Invoice Line DUoM Unit Price debe ser 100');
    end;

    // -------------------------------------------------------------------------
    // T07 — Purchase Order → DUoM Second Qty en Value Entry
    // -------------------------------------------------------------------------

    [Test]
    procedure T07_PurchasePosting_DUoMSecondQtyPropagatedToValueEntry()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Item con DUoM: Fixed, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Purchase Order 10 unidades → DUoM Second Qty = 8
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el pedido (recepción + factura)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, true);

        // [THEN] Value Entry tiene DUoM Second Qty = 8
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un ILE para la compra contabilizada');
        ValueEntry.SetRange("Item Ledger Entry No.", ILE."Entry No.");
        LibraryAssert.IsTrue(ValueEntry.FindFirst(), 'Se esperaba un Value Entry para el ILE de compra');
        LibraryAssert.AreEqual(8, ValueEntry."DUoM Second Qty",
            'Value Entry DUoM Second Qty debe ser 10 × 0.8 = 8 tras la contabilización de compra');
    end;

    // -------------------------------------------------------------------------
    // T08 — Sales Order → DUoM Second Qty en Value Entry
    // -------------------------------------------------------------------------

    [Test]
    procedure T08_SalesPosting_DUoMSecondQtyPropagatedToValueEntry()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ILE: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Item con DUoM: Fixed, ratio 0.8 y stock inicial
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);
        LibraryInventory.CreateItemJournalLineInItemTemplate(Item."No.", '', '', '', 10);

        // [GIVEN] Sales Order 5 unidades → DUoM Second Qty = 4
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 5);
        SalesLine.Modify(true);

        // [WHEN] Se contabiliza el pedido (envío + factura)
        LibrarySales.PostSalesDocument(SalesHeader, true, true);

        // [THEN] Value Entry (venta) tiene DUoM Second Qty = -4 (salida = negativo)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un ILE para la venta contabilizada');
        ValueEntry.SetRange("Item Ledger Entry No.", ILE."Entry No.");
        LibraryAssert.IsTrue(ValueEntry.FindFirst(), 'Se esperaba un Value Entry para el ILE de venta');
        LibraryAssert.AreEqual(-4, ValueEntry."DUoM Second Qty",
            'Value Entry DUoM Second Qty debe ser -(5 × 0.8) = -4 tras la contabilización de venta');
    end;
}
