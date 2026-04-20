/// <summary>
/// Tests de integración para los modos de conversión Variable y AlwaysVariable
/// a lo largo del flujo completo de contabilización.
/// Verifica que los campos DUoM Second Qty y DUoM Ratio se propagan correctamente
/// desde las líneas de pedido hasta los movimientos de producto (ILE) cuando el
/// artículo usa modo Variable (con ratio por defecto del artículo o sobreescrito
/// en línea) o AlwaysVariable (con valores introducidos manualmente).
///
/// Complementa los tests de modo Fixed existentes en DUoM ILE Integration Tests
/// (codeunit 50209), cerrando el gap P0-02 identificado en docs/TestCoverageAudit.md.
/// </summary>
codeunit 50214 "DUoM Variable Mode Post Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // Modo Variable — compra contabilizada → ILE contiene campos DUoM
    // Usa el ratio por defecto del artículo cuando no hay ratio en la línea
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchPost_VariableMode_DefaultRatio_ILEHasDUoMFields()
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
        // [GIVEN] Un artículo con configuración DUoM: modo Variable, ratio por defecto 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] Un pedido de compra de 10 unidades; sin ratio en línea → se aplica el ratio por defecto 0.8
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el pedido de compra (solo recepción)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] El ILE resultante contiene los campos DUoM correctos del modo Variable
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un ILE para la recepción en modo Variable (ratio por defecto)');
        LibraryAssert.AreEqual(8, ILE."DUoM Second Qty", 'Modo Variable ILE: DUoM Second Qty debe ser 10 × 0.8 = 8');
        LibraryAssert.AreEqual(0.8, ILE."DUoM Ratio", 'Modo Variable ILE: DUoM Ratio debe ser 0.8 tras la contabilización');
    end;

    // -------------------------------------------------------------------------
    // Modo Variable — compra con ratio sobreescrito en línea → ILE usa ratio de línea
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchPost_VariableMode_OverriddenRatio_ILEHasLineRatio()
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
        // [GIVEN] Un artículo con configuración DUoM: modo Variable, ratio por defecto 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] Un pedido de compra de 10 unidades; DUoM Ratio sobreescrito a 0.9 en la línea
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Validate("DUoM Ratio", 0.9);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el pedido de compra (solo recepción)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] El ILE usa el ratio de la línea (0.9), no el ratio por defecto del artículo (0.8)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un ILE para la recepción con ratio sobreescrito en modo Variable');
        LibraryAssert.AreEqual(9, ILE."DUoM Second Qty", 'Modo Variable ILE: ratio sobreescrito 0.9 → DUoM Second Qty = 10 × 0.9 = 9');
        LibraryAssert.AreEqual(0.9, ILE."DUoM Ratio", 'Modo Variable ILE: el ratio 0.9 de la línea debe conservarse en el ILE');
    end;

    // -------------------------------------------------------------------------
    // Modo AlwaysVariable — compra con valores DUoM introducidos manualmente
    // → ILE contiene los valores manuales
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchPost_AlwaysVarMode_ManualValues_ILEHasManualValues()
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
        // [GIVEN] Un artículo con configuración DUoM: modo AlwaysVariable (el motor siempre devuelve 0)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);

        // [GIVEN] Un pedido de compra de 10 unidades; el usuario introduce manualmente DUoM Second Qty = 7 y Ratio = 0.7
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        // AlwaysVariable no autocompleta; el usuario introduce los valores directamente
        PurchLine."DUoM Second Qty" := 7;
        PurchLine."DUoM Ratio" := 0.7;
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el pedido de compra (solo recepción)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] El ILE contiene los valores DUoM introducidos manualmente
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un ILE para la recepción en modo AlwaysVariable');
        LibraryAssert.AreEqual(7, ILE."DUoM Second Qty", 'AlwaysVariable ILE: DUoM Second Qty = 7 introducido manualmente debe aparecer en el ILE');
        LibraryAssert.AreEqual(0.7, ILE."DUoM Ratio", 'AlwaysVariable ILE: Ratio = 0.7 introducido manualmente debe conservarse en el ILE');
    end;

    // -------------------------------------------------------------------------
    // Modo Variable — venta contabilizada → ILE contiene campos DUoM
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesPost_VariableMode_DefaultRatio_ILEHasDUoMFields()
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
        // [GIVEN] Un artículo con configuración DUoM: modo Variable, ratio por defecto 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] Inventario creado mediante una recepción de compra (100 unidades)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 100);
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [GIVEN] Un pedido de venta de 10 unidades; modo Variable aplica ratio por defecto 0.8
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 10);
        SalesLine.Modify(true);

        // [WHEN] Se contabiliza el pedido de venta (solo envío)
        LibrarySales.PostSalesDocument(SalesHeader, true, false);

        // [THEN] El ILE de venta contiene los campos DUoM correctos del modo Variable
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'Se esperaba un ILE de venta tras la contabilización en modo Variable');
        LibraryAssert.AreEqual(8, ILE."DUoM Second Qty", 'Modo Variable venta ILE: DUoM Second Qty debe ser 10 × 0.8 = 8');
        LibraryAssert.AreEqual(0.8, ILE."DUoM Ratio", 'Modo Variable venta ILE: DUoM Ratio debe ser 0.8 tras la contabilización');
    end;
}
