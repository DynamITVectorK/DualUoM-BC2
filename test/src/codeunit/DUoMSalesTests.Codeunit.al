/// <summary>
/// Tests for the DUoM Sales flow — field extensions on Sales Line and
/// the DUoM Sales Subscribers (Codeunit 50103) auto-compute logic.
/// </summary>
codeunit 50206 "DUoM Sales Tests"
{
    Subtype = Test;

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
        DUoMItemSetup: Record "DUoM Item Setup";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
    begin
        // [GIVEN] An item with DUoM setup: Fixed conversion mode, ratio 1.25
        ItemNo := 'SALES-DUOM-01';
        Item.Init();
        Item."No." := ItemNo;
        Item."Base Unit of Measure" := 'PCS';
        Item.Insert(false);

        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := ItemNo;
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'KG';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::Fixed;
        DUoMItemSetup."Fixed Ratio" := 1.25;
        DUoMItemSetup.Insert(false);

        // [GIVEN] A Sales Header and Line for that item
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader."No." := 'SALES-TEST-01';
        SalesHeader.Insert(false);

        SalesLine.Init();
        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := 10000;
        SalesLine.Type := SalesLine.Type::Item;
        SalesLine."No." := ItemNo;
        SalesLine.Insert(false);

        // [WHEN] Quantity is validated to 8
        SalesLine.Validate(Quantity, 8);

        // [THEN] DUoM Second Qty = 8 × 1.25 = 10
        LibraryAssert.AreEqual(10, SalesLine."DUoM Second Qty", 'DUoM Second Qty should be 8 × 1.25 = 10 after Quantity validate');
        LibraryAssert.AreEqual(1.25, SalesLine."DUoM Ratio", 'DUoM Ratio should be auto-populated from item setup');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        DUoMItemSetup.Delete(false);
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Quantity validate for AlwaysVariable → no auto-compute
    // -------------------------------------------------------------------------

    [Test]
    procedure SalesLine_ValidateQty_AlwaysVariableMode_NoDUoMAutoCompute()
    var
        Item: Record Item;
        DUoMItemSetup: Record "DUoM Item Setup";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
    begin
        // [GIVEN] An item with DUoM setup: Always Variable mode
        ItemNo := 'SALES-DUOM-AV';
        Item.Init();
        Item."No." := ItemNo;
        Item."Base Unit of Measure" := 'PCS';
        Item.Insert(false);

        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := ItemNo;
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'KG';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::AlwaysVariable;
        DUoMItemSetup.Insert(false);

        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader."No." := 'SALES-TEST-AV';
        SalesHeader.Insert(false);

        SalesLine.Init();
        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := 10000;
        SalesLine.Type := SalesLine.Type::Item;
        SalesLine."No." := ItemNo;
        SalesLine.Insert(false);

        // [WHEN] Quantity is validated
        SalesLine.Validate(Quantity, 5);

        // [THEN] DUoM Second Qty remains 0 — AlwaysVariable requires manual entry
        LibraryAssert.AreEqual(0, SalesLine."DUoM Second Qty", 'AlwaysVariable mode must not auto-compute DUoM Second Qty on Sales Line');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        DUoMItemSetup.Delete(false);
        Item.Delete(false);
    end;
}
