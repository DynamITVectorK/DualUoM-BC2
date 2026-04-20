/// <summary>
/// Tests for the DUoM Item Variant support — DUoM Setup Resolver hierarchy
/// (Item → Variant) and auto-compute logic on Purchase/Sales Lines when
/// Variant Code is set or changed.
/// </summary>
codeunit 50211 "DUoM Variant Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // Resolver: item with DUoM enabled but no variant setup → uses item setup
    // -------------------------------------------------------------------------

    [Test]
    procedure Resolver_NoVariantSetup_UsesItemSetup()
    var
        Item: Record Item;
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        Result: Boolean;
    begin
        // [GIVEN] An item with DUoM setup: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [WHEN] Resolver is called without a variant code
        Result := DUoMSetupResolver.GetEffectiveSetup(Item."No.", '', SecondUoMCode, ConversionMode, FixedRatio);

        // [THEN] Returns true and uses item-level setup values
        LibraryAssert.IsTrue(Result, 'Resolver must return true when item DUoM is enabled');
        LibraryAssert.AreEqual('PCS', SecondUoMCode, 'Second UoM Code must come from item setup');
        LibraryAssert.AreEqual("DUoM Conversion Mode"::Fixed, ConversionMode, 'Conversion Mode must come from item setup');
        LibraryAssert.AreEqual(0.8, FixedRatio, 'Fixed Ratio must come from item setup');

        // Cleanup
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Resolver: item with DUoM enabled + variant setup → uses variant override
    // -------------------------------------------------------------------------

    [Test]
    procedure Resolver_VariantSetupExists_UsesVariantOverride()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        Result: Boolean;
    begin
        // [GIVEN] An item with DUoM setup: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] An item variant ROMANA with DUoM override: Variable mode, ratio 1.2, KG
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ROMANA', ItemVariant);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'ROMANA', 'KG', "DUoM Conversion Mode"::Variable, 1.2);

        // [WHEN] Resolver is called with variant code ROMANA
        Result := DUoMSetupResolver.GetEffectiveSetup(Item."No.", 'ROMANA', SecondUoMCode, ConversionMode, FixedRatio);

        // [THEN] Returns true and uses variant-level override values
        LibraryAssert.IsTrue(Result, 'Resolver must return true for item with variant override');
        LibraryAssert.AreEqual('KG', SecondUoMCode, 'Second UoM Code must come from variant setup');
        LibraryAssert.AreEqual("DUoM Conversion Mode"::Variable, ConversionMode, 'Conversion Mode must come from variant setup');
        LibraryAssert.AreEqual(1.2, FixedRatio, 'Fixed Ratio must come from variant setup');

        // Cleanup
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'ROMANA');
        ItemVariant.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Resolver: item with DUoM enabled + variant code BUT no variant setup
    // → falls back to item setup
    // -------------------------------------------------------------------------

    [Test]
    procedure Resolver_VariantCodeButNoVariantSetup_FallsBackToItem()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        Result: Boolean;
    begin
        // [GIVEN] An item with DUoM setup: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] An item variant ICEBERG with no DUoM override
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ICEBERG', ItemVariant);

        // [WHEN] Resolver is called with variant code ICEBERG (no variant setup exists)
        Result := DUoMSetupResolver.GetEffectiveSetup(Item."No.", 'ICEBERG', SecondUoMCode, ConversionMode, FixedRatio);

        // [THEN] Returns true and falls back to item-level setup
        LibraryAssert.IsTrue(Result, 'Resolver must return true when falling back to item setup');
        LibraryAssert.AreEqual('PCS', SecondUoMCode, 'Second UoM Code must fall back to item setup');
        LibraryAssert.AreEqual(0.8, FixedRatio, 'Fixed Ratio must fall back to item setup');

        // Cleanup
        ItemVariant.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Resolver: item without DUoM enabled → returns false
    // -------------------------------------------------------------------------

    [Test]
    procedure Resolver_DUoMDisabled_ReturnsFalse()
    var
        Item: Record Item;
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        // [GIVEN] An item with DUoM setup where DUoM is DISABLED
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", false, '', "DUoM Conversion Mode"::Fixed, 0);

        // [WHEN] Resolver is called
        // [THEN] Returns false (DUoM disabled at item level)
        LibraryAssert.IsFalse(
            DUoMSetupResolver.GetEffectiveSetup(Item."No.", '', SecondUoMCode, ConversionMode, FixedRatio),
            'Resolver must return false when DUoM is disabled');

        // Cleanup
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Resolver: item with no DUoM setup at all → returns false
    // -------------------------------------------------------------------------

    [Test]
    procedure Resolver_NoItemSetup_ReturnsFalse()
    var
        Item: Record Item;
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        // [GIVEN] An item with no DUoM setup record
        LibraryInventory.CreateItem(Item);

        // [WHEN] Resolver is called
        // [THEN] Returns false (no setup at all)
        LibraryAssert.IsFalse(
            DUoMSetupResolver.GetEffectiveSetup(Item."No.", '', SecondUoMCode, ConversionMode, FixedRatio),
            'Resolver must return false when no item DUoM setup exists');

        // Cleanup
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Purchase Line: Quantity validate uses variant override ratio
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ValidateQty_WithVariantSetup_UsesVariantRatio()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with item-level DUoM: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Variant ROMANA with override: Fixed mode, ratio 1.5
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ROMANA', ItemVariant);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'ROMANA', 'PCS', "DUoM Conversion Mode"::Fixed, 1.5);

        // [GIVEN] A purchase line for the item with variant ROMANA
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate("Variant Code", 'ROMANA');

        // [WHEN] Quantity is validated to 10
        PurchLine.Validate(Quantity, 10);

        // [THEN] DUoM Second Qty = 10 × 1.5 = 15 (variant ratio used, not item ratio 0.8)
        LibraryAssert.AreEqual(15, PurchLine."DUoM Second Qty",
            'Must use variant override ratio 1.5, not item ratio 0.8');
        LibraryAssert.AreEqual(1.5, PurchLine."DUoM Ratio",
            'DUoM Ratio must be populated from variant setup');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'ROMANA');
        ItemVariant.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Purchase Line: Variant Code validate → resets and recomputes DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ValidateVariantCode_ResetsDUoMAndRecomputes()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with item-level DUoM: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Variant ROMANA with override: Fixed mode, ratio 1.5
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ROMANA', ItemVariant);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'ROMANA', 'PCS', "DUoM Conversion Mode"::Fixed, 1.5);

        // [GIVEN] A purchase line for the item with Quantity = 10 (item setup ratio 0.8 → SecondQty = 8)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        LibraryAssert.AreEqual(8, PurchLine."DUoM Second Qty", 'Initial SecondQty should use item ratio 0.8');

        // [WHEN] Variant Code is validated to ROMANA
        PurchLine.Validate("Variant Code", 'ROMANA');

        // [THEN] DUoM Ratio reset and recomputed using variant ratio 1.5 → SecondQty = 15
        LibraryAssert.AreEqual(1.5, PurchLine."DUoM Ratio",
            'DUoM Ratio must be updated to variant ratio after Variant Code change');
        LibraryAssert.AreEqual(15, PurchLine."DUoM Second Qty",
            'DUoM Second Qty must be recomputed using variant ratio 1.5 after Variant Code change');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'ROMANA');
        ItemVariant.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Sales Line: Quantity validate uses variant override ratio
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_ValidateQty_WithVariantSetup_UsesVariantRatio()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with item-level DUoM: Fixed mode, ratio 1.25
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 1.25);

        // [GIVEN] Variant ICEBERG with override: Fixed mode, ratio 0.9
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ICEBERG', ItemVariant);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'ICEBERG', 'KG', "DUoM Conversion Mode"::Fixed, 0.9);

        // [GIVEN] A sales line for the item with variant ICEBERG
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate("Variant Code", 'ICEBERG');

        // [WHEN] Quantity is validated to 8
        SalesLine.Validate(Quantity, 8);

        // [THEN] DUoM Second Qty = 8 × 0.9 = 7.2 (variant ratio used, not item ratio 1.25)
        LibraryAssert.AreEqual(7.2, SalesLine."DUoM Second Qty",
            'Must use variant override ratio 0.9, not item ratio 1.25');
        LibraryAssert.AreEqual(0.9, SalesLine."DUoM Ratio",
            'DUoM Ratio must be populated from variant setup');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'ICEBERG');
        ItemVariant.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Sales Line: Variant Code validate → resets and recomputes DUoM fields
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_ValidateVariantCode_ResetsDUoMAndRecomputes()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with item-level DUoM: Fixed mode, ratio 1.25
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 1.25);

        // [GIVEN] Variant ICEBERG with override: Fixed mode, ratio 0.9
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ICEBERG', ItemVariant);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'ICEBERG', 'KG', "DUoM Conversion Mode"::Fixed, 0.9);

        // [GIVEN] A sales line with Quantity = 8 (item ratio 1.25 → SecondQty = 10)
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 8);
        LibraryAssert.AreEqual(10, SalesLine."DUoM Second Qty", 'Initial SecondQty should use item ratio 1.25');

        // [WHEN] Variant Code is validated to ICEBERG
        SalesLine.Validate("Variant Code", 'ICEBERG');

        // [THEN] DUoM Ratio reset and recomputed using variant ratio 0.9 → SecondQty = 7.2
        LibraryAssert.AreEqual(0.9, SalesLine."DUoM Ratio",
            'DUoM Ratio must be updated to variant ratio after Variant Code change');
        LibraryAssert.AreEqual(7.2, SalesLine."DUoM Second Qty",
            'DUoM Second Qty must be recomputed using variant ratio 0.9 after Variant Code change');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'ICEBERG');
        ItemVariant.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Variant cascade delete: deleting variant also deletes its DUoM setup
    // -------------------------------------------------------------------------

    [Test]
    procedure ItemVariantDelete_CascadeDeletesVariantSetup()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with a variant ROMANA and a DUoM variant setup
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ROMANA', ItemVariant);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'ROMANA', 'PCS', "DUoM Conversion Mode"::Fixed, 1.5);

        // [WHEN] The variant is deleted
        ItemVariant.Delete(true);

        // [THEN] The DUoM variant setup is also deleted (cascade)
        LibraryAssert.IsFalse(DUoMVariantSetup.Get(Item."No.", 'ROMANA'),
            'DUoM Variant Setup must be cascade-deleted when the Item Variant is deleted');

        // Cleanup
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Purchase Line: AlwaysVariable variant → no auto-compute (fields stay zero)
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_AlwaysVariableVariant_SkipsAutoCompute()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with item-level DUoM: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Variant FRESCA with AlwaysVariable override (no default ratio)
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'FRESCA', ItemVariant);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'FRESCA', 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);

        // [GIVEN] A purchase line for the item with variant FRESCA
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate("Variant Code", 'FRESCA');

        // [WHEN] Quantity is validated to 10
        PurchLine.Validate(Quantity, 10);

        // [THEN] DUoM Second Qty stays at zero (AlwaysVariable = user enters manually)
        LibraryAssert.AreEqual(0, PurchLine."DUoM Second Qty",
            'AlwaysVariable variant must leave Second Qty at zero for manual entry');
        LibraryAssert.AreEqual(0, PurchLine."DUoM Ratio",
            'AlwaysVariable variant must leave Ratio at zero');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'FRESCA');
        ItemVariant.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Purchase Line: switching between two variants recomputes correctly
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_SwitchBetweenTwoVariants_RecomputesCorrectly()
    var
        Item: Record Item;
        ItemVariantRomana: Record "Item Variant";
        ItemVariantIceberg: Record "Item Variant";
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with item-level DUoM: Fixed mode, ratio 1.0
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1.0);

        // [GIVEN] Variant ROMANA with ratio 1.5
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ROMANA', ItemVariantRomana);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'ROMANA', 'PCS', "DUoM Conversion Mode"::Fixed, 1.5);

        // [GIVEN] Variant ICEBERG with ratio 0.9
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ICEBERG', ItemVariantIceberg);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'ICEBERG', 'PCS', "DUoM Conversion Mode"::Fixed, 0.9);

        // [GIVEN] A purchase line with variant ROMANA, Quantity = 10 → SecondQty = 15
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate("Variant Code", 'ROMANA');
        PurchLine.Validate(Quantity, 10);
        LibraryAssert.AreEqual(15, PurchLine."DUoM Second Qty", 'ROMANA: SecondQty must be 15');

        // [WHEN] Variant Code is switched to ICEBERG
        PurchLine.Validate("Variant Code", 'ICEBERG');

        // [THEN] DUoM fields reset and recomputed for ICEBERG ratio 0.9 → SecondQty = 9
        LibraryAssert.AreEqual(0.9, PurchLine."DUoM Ratio",
            'After switch to ICEBERG, Ratio must be 0.9');
        LibraryAssert.AreEqual(9, PurchLine."DUoM Second Qty",
            'After switch to ICEBERG, SecondQty must be 9 (10 × 0.9)');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'ROMANA');
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'ICEBERG');
        ItemVariantRomana.Delete(false);
        ItemVariantIceberg.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Purchase Line: clearing variant code falls back to item ratio
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ClearVariantCode_FallsBackToItemRatio()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with item-level DUoM: Fixed mode, ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);

        // [GIVEN] Variant ROMANA with override ratio 1.5
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'ROMANA', ItemVariant);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'ROMANA', 'PCS', "DUoM Conversion Mode"::Fixed, 1.5);

        // [GIVEN] A purchase line with variant ROMANA, Quantity = 10 → SecondQty = 15
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate("Variant Code", 'ROMANA');
        PurchLine.Validate(Quantity, 10);
        LibraryAssert.AreEqual(15, PurchLine."DUoM Second Qty", 'ROMANA: SecondQty must be 15');

        // [WHEN] Variant Code is cleared (blank)
        PurchLine.Validate("Variant Code", '');

        // [THEN] DUoM recalculated using item ratio 0.8 → SecondQty = 8
        LibraryAssert.AreEqual(0.8, PurchLine."DUoM Ratio",
            'After clearing variant, Ratio must fall back to item ratio 0.8');
        LibraryAssert.AreEqual(8, PurchLine."DUoM Second Qty",
            'After clearing variant, SecondQty must be 8 (10 × 0.8)');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'ROMANA');
        ItemVariant.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Backward compatibility: item without variant code works as before
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_NoVariantCode_BackwardCompatible()
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
        // [GIVEN] An item with item-level DUoM: Fixed mode, ratio 2.5
        // No variant setup exists at all
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 2.5);

        // [GIVEN] A purchase line without any variant code
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);

        // [WHEN] Quantity is validated to 4
        PurchLine.Validate(Quantity, 4);

        // [THEN] DUoM Second Qty = 4 × 2.5 = 10 (item setup used directly, unchanged)
        LibraryAssert.AreEqual(10, PurchLine."DUoM Second Qty",
            'Without variant code, item ratio must be used: 4 × 2.5 = 10');
        LibraryAssert.AreEqual(2.5, PurchLine."DUoM Ratio",
            'DUoM Ratio must equal item Fixed Ratio when no variant code is present');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Sales Line: AlwaysVariable variant → no auto-compute (fields stay zero)
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_AlwaysVariableVariant_SkipsAutoCompute()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with item-level DUoM: Fixed mode, ratio 1.25
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 1.25);

        // [GIVEN] Variant GRANEL with AlwaysVariable override
        DUoMTestHelpers.CreateItemVariantWithCode(Item."No.", 'GRANEL', ItemVariant);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'GRANEL', 'KG', "DUoM Conversion Mode"::AlwaysVariable, 0);

        // [GIVEN] A sales line for the item with variant GRANEL
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate("Variant Code", 'GRANEL');

        // [WHEN] Quantity is validated to 6
        SalesLine.Validate(Quantity, 6);

        // [THEN] DUoM Second Qty stays at zero (user must enter manually)
        LibraryAssert.AreEqual(0, SalesLine."DUoM Second Qty",
            'AlwaysVariable variant must leave Second Qty at zero for manual entry');
        LibraryAssert.AreEqual(0, SalesLine."DUoM Ratio",
            'AlwaysVariable variant must leave Ratio at zero');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'GRANEL');
        ItemVariant.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;
}
