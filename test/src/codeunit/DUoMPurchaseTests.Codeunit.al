/// <summary>
/// Tests for the DUoM Purchase flow — field extensions on Purchase Line and
/// the DUoM Purchase Subscribers (Codeunit 50102) auto-compute logic.
/// </summary>
codeunit 50205 "DUoM Purchase Tests"
{
    Subtype = Test;

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
        DUoMItemSetup: Record "DUoM Item Setup";
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with DUoM setup: Fixed conversion mode, ratio 0.8
        LibraryInventory.CreateItem(Item);

        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := Item."No.";
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::Fixed;
        DUoMItemSetup."Fixed Ratio" := 0.8;
        DUoMItemSetup.Insert(false);

        // [GIVEN] A Vendor and a Purchase Header and Line for that item
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchaseHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
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
        DUoMItemSetup.Delete(false);
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate → no DUoM computation for non-item lines
    // -------------------------------------------------------------------------

    [Test]
    procedure PurchaseLine_ValidateQty_NonItemType_NoDUoMCompute()
    var
        PurchLine: Record "Purchase Line";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A Purchase Line of type G/L Account (not Item) — in-memory only
        PurchLine.Init();
        PurchLine.Type := PurchLine.Type::"G/L Account";

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
        DUoMItemSetup: Record "DUoM Item Setup";
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with DUoM setup: Always Variable conversion mode
        LibraryInventory.CreateItem(Item);

        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := Item."No.";
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::AlwaysVariable;
        DUoMItemSetup.Insert(false);

        // [GIVEN] A Vendor and Purchase Header for that item
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchaseHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);

        // [WHEN] Quantity is validated
        PurchLine.Validate(Quantity, 10);

        // [THEN] DUoM Second Qty remains 0 — always variable requires manual entry
        LibraryAssert.AreEqual(0, PurchLine."DUoM Second Qty", 'AlwaysVariable mode must not auto-compute DUoM Second Qty');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMItemSetup.Delete(false);
        Item.Delete(false);
    end;
}
