/// <summary>
/// Tests for the DUoM Purchase flow — field extensions on Purchase Line and
/// the DUoM Purchase Subscribers (Codeunit 50102) auto-compute logic.
/// </summary>
codeunit 50205 "DUoM Purchase Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // DUoM fields exist on Purchase Line and can be set and read
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_DUoMFields_ExistAndCanBeSet()
    var
        PurchLine: Record "Purchase Line";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A Purchase Line record initialised in memory
        PurchLine.Init();

        // [WHEN] DUoM fields are assigned directly
        PurchLine."DUoM Second Qty" := 8;
        PurchLine."DUoM Ratio" := 0.8;

        // [THEN] The values can be read back from the record
        LibraryAssert.AreEqual(8, PurchLine."DUoM Second Qty", 'DUoM Second Qty must be readable from Purchase Line');
        LibraryAssert.AreEqual(0.8, PurchLine."DUoM Ratio", 'DUoM Ratio must be readable from Purchase Line');
    end;

    // -------------------------------------------------------------------------
    // DUoM fields default to zero on a new Purchase Line
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_DUoMFields_DefaultToZero()
    var
        PurchLine: Record "Purchase Line";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A freshly initialised Purchase Line
        PurchLine.Init();

        // [THEN] DUoM fields default to zero
        LibraryAssert.AreEqual(0, PurchLine."DUoM Second Qty", 'DUoM Second Qty must default to 0');
        LibraryAssert.AreEqual(0, PurchLine."DUoM Ratio", 'DUoM Ratio must default to 0');
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate → DUoM Second Qty computed for Fixed mode
    // Tests that the event subscriber fires and delegates to the Calc Engine.
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ValidateQty_FixedMode_ComputesSecondQty()
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
        // [GIVEN] An item with DUoM setup: Fixed conversion mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] A Vendor and a Purchase Header and Line for that item
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);

        // [WHEN] Quantity is validated to 10 (triggers OnAfterValidateEvent subscriber)
        PurchLine.Validate(Quantity, 10);

        // [THEN] DUoM Second Qty = 10 × 0.8 = 8 (the lettuce scenario)
        LibraryAssert.AreEqual(8, PurchLine."DUoM Second Qty", 'DUoM Second Qty should be 10 × 0.8 = 8 after Quantity validate');
        LibraryAssert.AreEqual(0.8, PurchLine."DUoM Ratio", 'DUoM Ratio should be auto-populated from item setup');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate → no DUoM computation for non-item lines
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ValidateQty_NonItemType_NoDUoMCompute()
    var
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A Purchase Header providing valid document context
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");

        // [GIVEN] A Purchase Line of type blank (not Item) with valid document linkage
        PurchLine.Init();
        PurchLine."Document Type" := PurchHeader."Document Type";
        PurchLine."Document No." := PurchHeader."No.";
        PurchLine."Line No." := 10000;
        PurchLine.Type := PurchLine.Type::" ";

        // [WHEN] Quantity is validated
        PurchLine.Validate(Quantity, 5);

        // [THEN] DUoM fields remain zero — no DUoM computation for non-item lines
        LibraryAssert.AreEqual(0, PurchLine."DUoM Second Qty", 'Non-item line must not compute DUoM Second Qty');
        LibraryAssert.AreEqual(0, PurchLine."DUoM Ratio", 'Non-item line must not set DUoM Ratio');
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate for AlwaysVariable → no auto-compute
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ValidateQty_AlwaysVariableMode_NoDUoMAutoCompute()
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
        // [GIVEN] An item with DUoM setup: Always Variable conversion mode
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);

        // [GIVEN] A Vendor and Purchase Header for that item
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);

        // [WHEN] Quantity is validated
        PurchLine.Validate(Quantity, 10);

        // [THEN] DUoM Second Qty remains 0 — always variable requires manual entry
        LibraryAssert.AreEqual(0, PurchLine."DUoM Second Qty", 'AlwaysVariable mode must not auto-compute DUoM Second Qty');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate in Variable mode → uses item default ratio
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ValidateQty_VariableMode_ComputesSecondQty()
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
        // [GIVEN] An item with DUoM setup: Variable conversion mode, Fixed Ratio 0.8 as default
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] A Vendor and a Purchase Header and Line for that item
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);

        // [WHEN] Quantity is validated to 10 (no line ratio pre-set → uses item default 0.8)
        PurchLine.Validate(Quantity, 10);

        // [THEN] DUoM Second Qty = 10 × 0.8 = 8 (item default ratio applied)
        LibraryAssert.AreEqual(8, PurchLine."DUoM Second Qty", 'Variable mode must compute DUoM Second Qty using item default ratio');
        LibraryAssert.AreEqual(0.8, PurchLine."DUoM Ratio", 'Variable mode must populate DUoM Ratio from item Fixed Ratio default');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate in Variable mode → pre-set line ratio wins
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ValidateQty_VariableMode_LineRatioOverridesItemDefault()
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
        // [GIVEN] An item with DUoM setup: Variable conversion mode, Fixed Ratio 0.8 as default
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.8);

        // [GIVEN] A Vendor and a Purchase Header and Line for that item
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);

        // [GIVEN] A per-line ratio of 1.5 is set before validating Quantity
        PurchLine."DUoM Ratio" := 1.5;

        // [WHEN] Quantity is validated to 10 (line ratio 1.5 must override item default 0.8)
        PurchLine.Validate(Quantity, 10);

        // [THEN] DUoM Second Qty = 10 × 1.5 = 15 (line ratio used, not item default)
        LibraryAssert.AreEqual(15, PurchLine."DUoM Second Qty", 'Variable mode must use the pre-set line ratio, not the item default');
        LibraryAssert.AreEqual(1.5, PurchLine."DUoM Ratio", 'DUoM Ratio must remain the pre-set line value after Quantity validation');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // OnValidate DUoM Ratio → recomputes DUoM Second Qty from current Quantity
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ValidateDUoMRatio_RecomputesSecondQty()
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
        // [GIVEN] An item with DUoM setup: Fixed conversion mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] A Vendor, a Purchase Header and Line; Quantity validated to 10 → SecondQty = 8
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);

        // [WHEN] DUoM Ratio is validated to 1.5 (new per-line ratio)
        PurchLine.Validate("DUoM Ratio", 1.5);

        // [THEN] DUoM Second Qty = 10 × 1.5 = 15 (recomputed with the new ratio)
        LibraryAssert.AreEqual(15, PurchLine."DUoM Second Qty", 'OnValidate DUoM Ratio must recompute DUoM Second Qty with the new ratio');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Integration: Quantity validate with discrete UoM → DUoM Second Qty rounded
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ValidateQty_DiscreteUoM_SecondQtyIsRounded()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        UnitOfMeasure: Record "Unit of Measure";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
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

        // [GIVEN] A Vendor and Purchase Order line for that item
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);

        // [WHEN] Quantity is validated to 10 → raw result would be 10 × 1.15 = 11.5
        PurchLine.Validate(Quantity, 10);

        // [THEN] DUoM Second Qty = 12 (11.5 rounded to precision 1)
        LibraryAssert.AreEqual(12, PurchLine."DUoM Second Qty",
            'Discrete UoM: DUoM Second Qty must be rounded to 12 (not 11.5) after Quantity validate');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;
}
