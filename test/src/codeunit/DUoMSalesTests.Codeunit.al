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
}
