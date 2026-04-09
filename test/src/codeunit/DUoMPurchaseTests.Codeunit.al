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
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
    begin
        // [GIVEN] An item with DUoM setup: Fixed conversion mode, ratio 0.8
        ItemNo := 'PURCH-DUOM-01';
        Item.Init();
        Item."No." := ItemNo;
        Item."Base Unit of Measure" := 'KG';
        Item.Insert(false);

        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := ItemNo;
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::Fixed;
        DUoMItemSetup."Fixed Ratio" := 0.8;
        DUoMItemSetup.Insert(false);

        // [GIVEN] A Vendor and a Purchase Header and Line for that item
        Vendor.Init();
        Vendor."No." := 'PURCH-VEND-01';
        Vendor.Insert(false);

        PurchHeader.Init();
        PurchHeader."Document Type" := PurchHeader."Document Type"::Order;
        PurchHeader."No." := 'PURCH-TEST-01';
        PurchHeader."Buy-from Vendor No." := Vendor."No.";
        PurchHeader.Insert(false);

        PurchLine.Init();
        PurchLine."Document Type" := PurchHeader."Document Type";
        PurchLine."Document No." := PurchHeader."No.";
        PurchLine."Line No." := 10000;
        PurchLine.Type := PurchLine.Type::Item;
        PurchLine."No." := ItemNo;
        PurchLine.Insert(false);

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
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        Vendor: Record Vendor;
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A Vendor and a Purchase Line of type G/L Account (not Item)
        Vendor.Init();
        Vendor."No." := 'PURCH-VEND-02';
        Vendor.Insert(false);

        PurchHeader.Init();
        PurchHeader."Document Type" := PurchHeader."Document Type"::Order;
        PurchHeader."No." := 'PURCH-TEST-02';
        PurchHeader."Buy-from Vendor No." := Vendor."No.";
        PurchHeader.Insert(false);

        PurchLine.Init();
        PurchLine."Document Type" := PurchHeader."Document Type";
        PurchLine."Document No." := PurchHeader."No.";
        PurchLine."Line No." := 10000;
        PurchLine.Type := PurchLine.Type::"G/L Account";
        PurchLine.Insert(false);

        // [WHEN] Quantity is validated
        PurchLine.Validate(Quantity, 5);

        // [THEN] DUoM fields remain zero — no DUoM computation for non-item lines
        LibraryAssert.AreEqual(0, PurchLine."DUoM Second Qty", 'Non-item line must not compute DUoM Second Qty');
        LibraryAssert.AreEqual(0, PurchLine."DUoM Ratio", 'Non-item line must not set DUoM Ratio');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
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
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
    begin
        // [GIVEN] An item with DUoM setup: Always Variable conversion mode
        ItemNo := 'PURCH-DUOM-AV';
        Item.Init();
        Item."No." := ItemNo;
        Item."Base Unit of Measure" := 'KG';
        Item.Insert(false);

        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := ItemNo;
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::AlwaysVariable;
        DUoMItemSetup.Insert(false);

        // [GIVEN] A Vendor and Purchase Header for that item
        Vendor.Init();
        Vendor."No." := 'PURCH-VEND-AV';
        Vendor.Insert(false);

        PurchHeader.Init();
        PurchHeader."Document Type" := PurchHeader."Document Type"::Order;
        PurchHeader."No." := 'PURCH-TEST-AV';
        PurchHeader."Buy-from Vendor No." := Vendor."No.";
        PurchHeader.Insert(false);

        PurchLine.Init();
        PurchLine."Document Type" := PurchHeader."Document Type";
        PurchLine."Document No." := PurchHeader."No.";
        PurchLine."Line No." := 10000;
        PurchLine.Type := PurchLine.Type::Item;
        PurchLine."No." := ItemNo;
        PurchLine.Insert(false);

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
