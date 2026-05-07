/// <summary>
/// Tests for the DUoM Sales flow — field extensions on Sales Line and
/// the DUoM Sales Subscribers (Codeunit 50103) auto-compute logic.
/// </summary>
codeunit 50206 "DUoM Sales Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // DUoM fields exist on Sales Line and can be set and read
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_DUoMFields_ExistAndCanBeSet()
    var
        SalesLine: Record "Sales Line";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A Sales Line record initialised in memory
        SalesLine.Init();

        // [WHEN] DUoM fields are assigned directly
        SalesLine."DUoM Second Qty" := 5;
        SalesLine."DUoM Ratio" := 1.25;

        // [THEN] The values can be read back from the record
        LibraryAssert.AreEqual(5, SalesLine."DUoM Second Qty", 'DUoM Second Qty must be readable from Sales Line');
        LibraryAssert.AreEqual(1.25, SalesLine."DUoM Ratio", 'DUoM Ratio must be readable from Sales Line');
    end;

    // -------------------------------------------------------------------------
    // DUoM fields default to zero on a new Sales Line
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_DUoMFields_DefaultToZero()
    var
        SalesLine: Record "Sales Line";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A freshly initialised Sales Line
        SalesLine.Init();

        // [THEN] DUoM fields default to zero
        LibraryAssert.AreEqual(0, SalesLine."DUoM Second Qty", 'DUoM Second Qty must default to 0');
        LibraryAssert.AreEqual(0, SalesLine."DUoM Ratio", 'DUoM Ratio must default to 0');
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate → DUoM Second Qty computed for Fixed mode
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_ValidateQty_FixedMode_ComputesSecondQty()
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
        // [GIVEN] An item with DUoM setup: Fixed conversion mode, ratio 1.25
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 1.25);

        // [GIVEN] A Customer, a Sales Header and Line for that item
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);

        // [WHEN] Quantity is validated to 8
        SalesLine.Validate(Quantity, 8);

        // [THEN] DUoM Second Qty = 8 × 1.25 = 10
        LibraryAssert.AreEqual(10, SalesLine."DUoM Second Qty", 'DUoM Second Qty should be 8 × 1.25 = 10 after Quantity validate');
        LibraryAssert.AreEqual(1.25, SalesLine."DUoM Ratio", 'DUoM Ratio should be auto-populated from item setup');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate for AlwaysVariable → no auto-compute
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_ValidateQty_AlwaysVariableMode_NoDUoMAutoCompute()
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
        // [GIVEN] An item with DUoM setup: Always Variable mode
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::AlwaysVariable, 0);

        // [GIVEN] A Customer, a Sales Header and Line for that item
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);

        // [WHEN] Quantity is validated
        SalesLine.Validate(Quantity, 5);

        // [THEN] DUoM Second Qty remains 0 — AlwaysVariable requires manual entry
        LibraryAssert.AreEqual(0, SalesLine."DUoM Second Qty", 'AlwaysVariable mode must not auto-compute DUoM Second Qty on Sales Line');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate in Variable mode → uses item default ratio
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_ValidateQty_VariableMode_ComputesSecondQty()
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
        // [GIVEN] An item with DUoM setup: Variable conversion mode, Fixed Ratio 1.25 as default
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Variable, 1.25);

        // [GIVEN] A Customer, a Sales Header and Line for that item
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);

        // [WHEN] Quantity is validated to 8 (no line ratio pre-set → uses item default 1.25)
        SalesLine.Validate(Quantity, 8);

        // [THEN] DUoM Second Qty = 8 × 1.25 = 10 (item default ratio applied)
        LibraryAssert.AreEqual(10, SalesLine."DUoM Second Qty", 'Variable mode must compute DUoM Second Qty using item default ratio');
        LibraryAssert.AreEqual(1.25, SalesLine."DUoM Ratio", 'Variable mode must populate DUoM Ratio from item Fixed Ratio default');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate in Variable mode → pre-set line ratio wins
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_ValidateQty_VariableMode_LineRatioOverridesItemDefault()
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
        // [GIVEN] An item with DUoM setup: Variable conversion mode, Fixed Ratio 1.25 as default
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Variable, 1.25);

        // [GIVEN] A Customer, a Sales Header and Line for that item
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);

        // [GIVEN] A per-line ratio of 2 is set before validating Quantity
        SalesLine."DUoM Ratio" := 2;

        // [WHEN] Quantity is validated to 8 (line ratio 2 must override item default 1.25)
        SalesLine.Validate(Quantity, 8);

        // [THEN] DUoM Second Qty = 8 × 2 = 16 (line ratio used, not item default)
        LibraryAssert.AreEqual(16, SalesLine."DUoM Second Qty", 'Variable mode must use the pre-set line ratio, not the item default');
        LibraryAssert.AreEqual(2, SalesLine."DUoM Ratio", 'DUoM Ratio must remain the pre-set line value after Quantity validation');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // OnValidate DUoM Ratio → recomputes DUoM Second Qty from current Quantity
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_ValidateDUoMRatio_RecomputesSecondQty()
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
        // [GIVEN] An item with DUoM setup: Fixed conversion mode, ratio 1.25
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 1.25);

        // [GIVEN] A Customer, a Sales Header and Line; Quantity validated to 8 → SecondQty = 10
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 8);

        // [WHEN] DUoM Ratio is validated to 2 (new per-line ratio)
        SalesLine.Validate("DUoM Ratio", 2);

        // [THEN] DUoM Second Qty = 8 × 2 = 16 (recomputed with the new ratio)
        LibraryAssert.AreEqual(16, SalesLine."DUoM Second Qty", 'OnValidate DUoM Ratio must recompute DUoM Second Qty with the new ratio');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Integration: Quantity validate with discrete UoM → DUoM Second Qty rounded
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_ValidateQty_DiscreteUoM_SecondQtyIsRounded()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        UnitOfMeasure: Record "Unit of Measure";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
        UoMCode: Code[10];
    begin
        // [GIVEN] A Unit of Measure code (discrete, e.g. pieces)
        LibraryInventory.CreateUnitOfMeasureCode(UnitOfMeasure);
        UoMCode := UnitOfMeasure.Code;

        // [GIVEN] An item with an Item Unit of Measure that has Qty. Rounding Precision = 1
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemUnitOfMeasure(ItemUnitOfMeasure, Item."No.", UoMCode, 1);
        ItemUnitOfMeasure."Qty. Rounding Precision" := 1;
        ItemUnitOfMeasure.Modify(false);

        // [GIVEN] DUoM setup: Fixed conversion mode, ratio 1.15, second UoM = discrete
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, UoMCode, "DUoM Conversion Mode"::Fixed, 1.15);

        // [GIVEN] A Customer and Sales Order line for that item
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);

        // [WHEN] Quantity is validated to 10 → raw result would be 10 × 1.15 = 11.5
        SalesLine.Validate(Quantity, 10);

        // [THEN] DUoM Second Qty = 12 (11.5 rounded to precision 1)
        LibraryAssert.AreEqual(12, SalesLine."DUoM Second Qty",
            'Discrete UoM: DUoM Second Qty must be rounded to 12 (not 11.5) after Quantity validate');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    [Test]
    procedure SalesLine_AlwaysVariable_ManualSecondQtyPreservedOnQtyChange()
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
        // [GIVEN] Item en AlwaysVariable y línea con DUoM manual informado por usuario
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 5);
        SalesLine.Validate("DUoM Ratio", 1.2);
        SalesLine.Validate("DUoM Second Qty", 6);

        // [WHEN] cambia Quantity
        SalesLine.Validate(Quantity, 10);

        // [THEN] el valor manual no se pisa automáticamente
        LibraryAssert.AreEqual(1.2, SalesLine."DUoM Ratio", 'AlwaysVariable: el ratio manual no debe resetearse al cambiar Quantity');
        LibraryAssert.AreEqual(6, SalesLine."DUoM Second Qty", 'AlwaysVariable: DUoM Second Qty manual no debe recalcularse al cambiar Quantity');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    [Test]
    procedure SalesLine_ValidateNo_RecomputesDUoMFromNewItem()
    var
        ItemA: Record Item;
        ItemB: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Dos artículos Fixed con ratios distintos
        LibraryInventory.CreateItem(ItemA);
        LibraryInventory.CreateItem(ItemB);
        DUoMTestHelpers.CreateItemSetup(ItemA."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1.25);
        DUoMTestHelpers.CreateItemSetup(ItemB."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 2);
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemA."No.", 8);
        SalesLine.Validate(Quantity, 8);

        // [WHEN] se valida "No." con el segundo artículo
        SalesLine.Validate("No.", ItemB."No.");

        // [THEN] la línea recalcula DUoM con la configuración efectiva del nuevo artículo
        LibraryAssert.AreEqual(2, SalesLine."DUoM Ratio", 'Al cambiar No. debe aplicarse el ratio del nuevo artículo');
        LibraryAssert.AreEqual(16, SalesLine."DUoM Second Qty", 'Al cambiar No. debe recalcularse DUoM Second Qty con la cantidad actual');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(ItemA."No.");
        DUoMTestHelpers.DeleteItemSetupIfExists(ItemB."No.");
        ItemA.Delete(false);
        ItemB.Delete(false);
    end;
}
