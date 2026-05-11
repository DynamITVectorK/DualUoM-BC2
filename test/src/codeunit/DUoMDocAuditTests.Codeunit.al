/// <summary>
/// Auditoría de cobertura: tests de propagación DUoM hacia documentos registrados
/// y movimientos de valoración (Value Entry). Cubre los huecos identificados en la
/// revisión de cobertura de la issue de auditoría:
///
///   T-AUDIT-01: Purch. Inv. Line conserva DUoM Unit Cost desde Purchase Line.
///   T-AUDIT-02: Purch. Cr. Memo Line conserva DUoM Unit Cost desde Purchase Line.
///   T-AUDIT-03: Sales Cr. Memo Line conserva DUoM Unit Price desde Sales Line.
///   T-AUDIT-04: ILE de abono de compra tiene DUoM Second Qty con signo negativo.
///   T-AUDIT-05: ILE de abono de venta tiene DUoM Second Qty con signo positivo.
///   T-AUDIT-06: Value Entry de abono de compra tiene DUoM Second Qty negativo.
///   T-AUDIT-07: Value Entry de abono de venta tiene DUoM Second Qty positivo.
///
/// Reglas aplicadas:
///   - No se toca WMS, DUoM Inventory ni tracking salvo para preparar datos.
///   - No se reintroduce DUoM Tracking Total.
///   - No se usan eventos de cierre de página.
///   - No se crea sync manual Tracking/Reservation → línea.
///   - DUoM Sign Mgt no se modifica (ningún bug demostrado en esta auditoría).
///
/// Cobertura de no-regresión:
///   Los tests de ILE y Value Entry para compras y ventas normales están en
///   DUoM ILE Integration Tests (50209), DUoM Cost Price Tests (50216) y
///   DUoM Variable Mode Post Tests (50214). Estos tests no se replican aquí.
/// </summary>
codeunit 50229 "DUoM Doc Audit Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T-AUDIT-01 — Purch. Inv. Line: DUoM Unit Cost propagado
    //
    // Hueco identificado: DUoM Inv CrMemo Post Tests (50210) valida DUoM Second Qty
    // y DUoM Ratio en Purch. Inv. Line, pero no DUoM Unit Cost.
    // DUoM Cost Price Tests (50216 T05) valida DUoM Unit Cost solo en Purch. Rcpt. Line.
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchInvLine_DUoMUnitCost_PropagatedFromPurchLine()
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
        // [GIVEN] Artículo con DUoM: modo Fijo, ratio 5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 5);

        // [GIVEN] Pedido de compra 10 uds con DUoM Unit Cost = 50
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Validate("DUoM Unit Cost", 50);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el pedido como recepción + factura
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, true);

        // [THEN] La Purch. Inv. Line conserva DUoM Unit Cost = 50 (propagado desde Purchase Line)
        PurchInvHeader.SetRange("Order No.", PurchHeader."No.");
        LibraryAssert.IsTrue(PurchInvHeader.FindFirst(), 'T-AUDIT-01: Se esperaba una cabecera de factura de compra registrada');
        PurchInvLine.SetRange("Document No.", PurchInvHeader."No.");
        PurchInvLine.SetRange(Type, PurchInvLine.Type::Item);
        LibraryAssert.IsTrue(PurchInvLine.FindFirst(), 'T-AUDIT-01: Se esperaba una línea de factura de compra registrada');
        LibraryAssert.AreEqual(50, PurchInvLine."DUoM Unit Cost",
            'T-AUDIT-01: Purch. Inv. Line DUoM Unit Cost debe ser 50 (propagado desde Purchase Line)');
        LibraryAssert.AreEqual(50, PurchInvLine."DUoM Second Qty",
            'T-AUDIT-01: Purch. Inv. Line DUoM Second Qty debe ser 10 × 5 = 50');
        LibraryAssert.AreEqual(5, PurchInvLine."DUoM Ratio",
            'T-AUDIT-01: Purch. Inv. Line DUoM Ratio debe ser 5');
    end;

    // -------------------------------------------------------------------------
    // T-AUDIT-02 — Purch. Cr. Memo Line: DUoM Unit Cost propagado
    //
    // Hueco identificado: DUoM Inv CrMemo Post Tests (50210) valida DUoM Second Qty
    // y DUoM Ratio en Purch. Cr. Memo Line, pero no DUoM Unit Cost.
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchCrMemoLine_DUoMUnitCost_PropagatedFromPurchLine()
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
        // [GIVEN] Artículo con DUoM: modo Fijo, ratio 5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 5);

        // [GIVEN] Abono de compra 5 uds con DUoM Unit Cost = 50
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::"Credit Memo", Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Validate("DUoM Unit Cost", 50);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el abono de compra
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, true);

        // [THEN] La Purch. Cr. Memo Line conserva DUoM Unit Cost = 50
        PurchCrMemoHdr.SetRange("Pay-to Vendor No.", Vendor."No.");
        LibraryAssert.IsTrue(PurchCrMemoHdr.FindLast(), 'T-AUDIT-02: Se esperaba una cabecera de abono de compra registrado');
        PurchCrMemoLine.SetRange("Document No.", PurchCrMemoHdr."No.");
        PurchCrMemoLine.SetRange(Type, PurchCrMemoLine.Type::Item);
        LibraryAssert.IsTrue(PurchCrMemoLine.FindFirst(), 'T-AUDIT-02: Se esperaba una línea de abono de compra registrado');
        LibraryAssert.AreEqual(50, PurchCrMemoLine."DUoM Unit Cost",
            'T-AUDIT-02: Purch. Cr. Memo Line DUoM Unit Cost debe ser 50 (propagado desde Purchase Line)');
        LibraryAssert.AreEqual(25, PurchCrMemoLine."DUoM Second Qty",
            'T-AUDIT-02: Purch. Cr. Memo Line DUoM Second Qty debe ser 5 × 5 = 25');
        LibraryAssert.AreEqual(5, PurchCrMemoLine."DUoM Ratio",
            'T-AUDIT-02: Purch. Cr. Memo Line DUoM Ratio debe ser 5');
    end;

    // -------------------------------------------------------------------------
    // T-AUDIT-03 — Sales Cr. Memo Line: DUoM Unit Price propagado
    //
    // Hueco identificado: DUoM Inv CrMemo Post Tests (50210) valida DUoM Second Qty
    // y DUoM Ratio en Sales Cr. Memo Line, pero no DUoM Unit Price.
    // DUoM Cost Price Tests (50216 T06) valida DUoM Unit Price en Sales Shipment Line
    // y Sales Invoice Line, pero no en Sales Cr. Memo Line.
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesCrMemoLine_DUoMUnitPrice_PropagatedFromSalesLine()
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
        // [GIVEN] Artículo con DUoM: modo Fijo, ratio 5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 5);

        // [GIVEN] Abono de venta 4 uds con DUoM Unit Price = 100
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::"Credit Memo", Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 4);
        SalesLine.Validate("DUoM Unit Price", 100);
        SalesLine.Modify(true);

        // [WHEN] Se contabiliza el abono de venta
        LibrarySales.PostSalesDocument(SalesHeader, true, true);

        // [THEN] La Sales Cr. Memo Line conserva DUoM Unit Price = 100
        SalesCrMemoHeader.SetRange("Sell-to Customer No.", Customer."No.");
        LibraryAssert.IsTrue(SalesCrMemoHeader.FindLast(), 'T-AUDIT-03: Se esperaba una cabecera de abono de venta registrado');
        SalesCrMemoLine.SetRange("Document No.", SalesCrMemoHeader."No.");
        SalesCrMemoLine.SetRange(Type, SalesCrMemoLine.Type::Item);
        LibraryAssert.IsTrue(SalesCrMemoLine.FindFirst(), 'T-AUDIT-03: Se esperaba una línea de abono de venta registrado');
        LibraryAssert.AreEqual(100, SalesCrMemoLine."DUoM Unit Price",
            'T-AUDIT-03: Sales Cr. Memo Line DUoM Unit Price debe ser 100 (propagado desde Sales Line)');
        LibraryAssert.AreEqual(20, SalesCrMemoLine."DUoM Second Qty",
            'T-AUDIT-03: Sales Cr. Memo Line DUoM Second Qty debe ser 4 × 5 = 20');
        LibraryAssert.AreEqual(5, SalesCrMemoLine."DUoM Ratio",
            'T-AUDIT-03: Sales Cr. Memo Line DUoM Ratio debe ser 5');
    end;

    // -------------------------------------------------------------------------
    // T-AUDIT-04 — ILE de abono de compra: DUoM Second Qty con signo negativo
    //
    // Hueco identificado: DUoM Inv CrMemo Post Tests (50210) valida los campos DUoM
    // en la Purch. Cr. Memo Line (documento histórico), pero no en el ILE resultante.
    //
    // Norma ILE←IJL: OnAfterInitItemLedgEntry usa NormalizeILESign, que toma el signo
    // de ILE.Quantity como fuente de verdad. Para un abono de compra:
    //   ILE.Quantity < 0 (salida de inventario hacia proveedor)
    //   → DUoM Second Qty < 0 (sigue el signo del movimiento)
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchCrMemo_ILE_DUoMSecondQtyIsNegative()
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
        // [GIVEN] Artículo con DUoM: modo Fijo, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Abono de compra 5 uds (DUoM Second Qty = 5 × 0.8 = 4 en la línea)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::"Credit Memo", Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el abono de compra
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, true);

        // [THEN] El ILE resultante tiene DUoM Second Qty negativo (salida de inventario)
        //        y DUoM Ratio positivo (siempre positivo como relación entre unidades)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange(Positive, false);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T-AUDIT-04: Se esperaba un ILE negativo de compra para el abono de compra registrado');
        LibraryAssert.IsTrue(ILE.Quantity < 0,
            'T-AUDIT-04: ILE.Quantity debe ser negativo para un abono de compra');
        LibraryAssert.AreEqual(-4, ILE."DUoM Second Qty",
            'T-AUDIT-04: ILE DUoM Second Qty debe ser -(5 × 0.8) = -4 (signo sigue ILE.Quantity)');
        LibraryAssert.AreEqual(0.8, ILE."DUoM Ratio",
            'T-AUDIT-04: ILE DUoM Ratio debe ser 0.8 (siempre positivo)');
    end;

    // -------------------------------------------------------------------------
    // T-AUDIT-05 — ILE de abono de venta: DUoM Second Qty con signo positivo
    //
    // Hueco identificado: DUoM Inv CrMemo Post Tests (50210) valida los campos DUoM
    // en la Sales Cr. Memo Line, pero no en el ILE resultante.
    //
    // Norma ILE←IJL: OnAfterInitItemLedgEntry usa NormalizeILESign. Para un abono de venta:
    //   ILE.Quantity > 0 (entrada de inventario desde cliente = devolución)
    //   → DUoM Second Qty > 0 (sigue el signo del movimiento)
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesCrMemo_ILE_DUoMSecondQtyIsPositive()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM: modo Fijo, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Abono de venta 5 uds (DUoM Second Qty = 5 × 0.8 = 4 en la línea)
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::"Credit Memo", Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 5);
        SalesLine.Modify(true);

        // [WHEN] Se contabiliza el abono de venta
        LibrarySales.PostSalesDocument(SalesHeader, true, true);

        // [THEN] El ILE resultante tiene DUoM Second Qty positivo (entrada de inventario = devolución cliente)
        //        y DUoM Ratio positivo (siempre positivo como relación entre unidades)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        ILE.SetRange(Positive, true);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T-AUDIT-05: Se esperaba un ILE positivo de venta para el abono de venta registrado');
        LibraryAssert.IsTrue(ILE.Quantity > 0,
            'T-AUDIT-05: ILE.Quantity debe ser positivo para un abono de venta (devolución cliente)');
        LibraryAssert.AreEqual(4, ILE."DUoM Second Qty",
            'T-AUDIT-05: ILE DUoM Second Qty debe ser +(5 × 0.8) = +4 (signo sigue ILE.Quantity)');
        LibraryAssert.AreEqual(0.8, ILE."DUoM Ratio",
            'T-AUDIT-05: ILE DUoM Ratio debe ser 0.8 (siempre positivo)');
    end;

    // -------------------------------------------------------------------------
    // T-AUDIT-06 — Value Entry de abono de compra: DUoM Second Qty negativo
    //
    // Hueco identificado: DUoM Cost Price Tests (50216) valida DUoM Second Qty en
    // Value Entry solo para compras y ventas normales (T07 y T08). Los abonos no
    // están cubiertos.
    //
    // Norma: OnAfterInitValueEntry usa NormalizeILESign contra ItemLedgEntry.Quantity.
    // Para abono de compra: ItemLedgEntry.Quantity < 0 → VE.DUoM Second Qty < 0.
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchCrMemo_ValueEntry_DUoMSecondQtyIsNegative()
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
        // [GIVEN] Artículo con DUoM: modo Fijo, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Abono de compra 5 uds (DUoM Second Qty = 5 × 0.8 = 4 en la línea)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::"Credit Memo", Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza el abono de compra
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, true);

        // [THEN] El Value Entry tiene DUoM Second Qty negativo (coherente con ILE.Quantity < 0)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange(Positive, false);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T-AUDIT-06: Se esperaba un ILE negativo de compra para el abono de compra registrado');
        ValueEntry.SetRange("Item Ledger Entry No.", ILE."Entry No.");
        LibraryAssert.IsTrue(ValueEntry.FindFirst(),
            'T-AUDIT-06: Se esperaba un Value Entry para el ILE de abono de compra');
        LibraryAssert.AreEqual(-4.0, ValueEntry."DUoM Second Qty",
            'T-AUDIT-06: Value Entry DUoM Second Qty debe ser -(5 × 0.8) = -4 (signo sigue ILE.Quantity)');
    end;

    // -------------------------------------------------------------------------
    // T-AUDIT-07 — Value Entry de abono de venta: DUoM Second Qty positivo
    //
    // Hueco identificado: DUoM Cost Price Tests (50216) valida DUoM Second Qty en
    // Value Entry solo para compras y ventas normales. Los abonos no están cubiertos.
    //
    // Norma: OnAfterInitValueEntry usa NormalizeILESign contra ItemLedgEntry.Quantity.
    // Para abono de venta: ItemLedgEntry.Quantity > 0 → VE.DUoM Second Qty > 0.
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesCrMemo_ValueEntry_DUoMSecondQtyIsPositive()
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
        // [GIVEN] Artículo con DUoM: modo Fijo, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Abono de venta 5 uds (DUoM Second Qty = 5 × 0.8 = 4 en la línea)
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::"Credit Memo", Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 5);
        SalesLine.Modify(true);

        // [WHEN] Se contabiliza el abono de venta
        LibrarySales.PostSalesDocument(SalesHeader, true, true);

        // [THEN] El Value Entry tiene DUoM Second Qty positivo (coherente con ILE.Quantity > 0)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        ILE.SetRange(Positive, true);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T-AUDIT-07: Se esperaba un ILE positivo de venta para el abono de venta registrado');
        ValueEntry.SetRange("Item Ledger Entry No.", ILE."Entry No.");
        LibraryAssert.IsTrue(ValueEntry.FindFirst(),
            'T-AUDIT-07: Se esperaba un Value Entry para el ILE de abono de venta');
        LibraryAssert.AreEqual(4.0, ValueEntry."DUoM Second Qty",
            'T-AUDIT-07: Value Entry DUoM Second Qty debe ser +(5 × 0.8) = +4 (signo sigue ILE.Quantity)');
    end;
}
