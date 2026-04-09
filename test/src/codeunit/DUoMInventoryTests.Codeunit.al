/// <summary>
/// Tests for the DUoM Inventory flow — field extensions on Item Journal Line
/// and Item Ledger Entry, and the DUoM Inventory Subscribers (Codeunit 50104)
/// auto-compute logic on Item Journal Lines.
/// ILE posting propagation is validated by functional CI tests that post documents.
/// </summary>
codeunit 50207 "DUoM Inventory Tests"
{
    Subtype = Test;

    // -------------------------------------------------------------------------
    // Item Journal Line: DUoM fields exist and can be set
    // -------------------------------------------------------------------------

    [Test]
    procedure ItemJournalLine_DUoMFields_ExistAndCanBeSet()
    var
        ItemJnlLine: Record "Item Journal Line";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An Item Journal Line record initialised in memory
        ItemJnlLine.Init();

        // [WHEN] DUoM fields are assigned directly
        ItemJnlLine."DUoM Second Qty" := 12;
        ItemJnlLine."DUoM Ratio" := 1.5;

        // [THEN] The values can be read back
        LibraryAssert.AreEqual(12, ItemJnlLine."DUoM Second Qty", 'DUoM Second Qty must be readable from Item Journal Line');
        LibraryAssert.AreEqual(1.5, ItemJnlLine."DUoM Ratio", 'DUoM Ratio must be readable from Item Journal Line');
    end;

    // -------------------------------------------------------------------------
    // Item Journal Line: DUoM fields default to zero
    // -------------------------------------------------------------------------

    [Test]
    procedure ItemJournalLine_DUoMFields_DefaultToZero()
    var
        ItemJnlLine: Record "Item Journal Line";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A freshly initialised Item Journal Line
        ItemJnlLine.Init();

        // [THEN] DUoM fields default to zero
        LibraryAssert.AreEqual(0, ItemJnlLine."DUoM Second Qty", 'DUoM Second Qty must default to 0 on Item Journal Line');
        LibraryAssert.AreEqual(0, ItemJnlLine."DUoM Ratio", 'DUoM Ratio must default to 0 on Item Journal Line');
    end;

    // -------------------------------------------------------------------------
    // Item Ledger Entry: DUoM fields exist and can be set
    // -------------------------------------------------------------------------

    [Test]
    procedure ItemLedgerEntry_DUoMFields_ExistAndCanBeSet()
    var
        ILE: Record "Item Ledger Entry";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An Item Ledger Entry record initialised in memory
        ILE.Init();

        // [WHEN] DUoM fields are assigned directly
        ILE."DUoM Second Qty" := 20;
        ILE."DUoM Ratio" := 2;

        // [THEN] The values can be read back
        LibraryAssert.AreEqual(20, ILE."DUoM Second Qty", 'DUoM Second Qty must be readable from Item Ledger Entry');
        LibraryAssert.AreEqual(2, ILE."DUoM Ratio", 'DUoM Ratio must be readable from Item Ledger Entry');
    end;

    // -------------------------------------------------------------------------
    // Item Ledger Entry: DUoM fields default to zero
    // -------------------------------------------------------------------------

    [Test]
    procedure ItemLedgerEntry_DUoMFields_DefaultToZero()
    var
        ILE: Record "Item Ledger Entry";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A freshly initialised Item Ledger Entry
        ILE.Init();

        // [THEN] DUoM fields default to zero
        LibraryAssert.AreEqual(0, ILE."DUoM Second Qty", 'DUoM Second Qty must default to 0 on Item Ledger Entry');
        LibraryAssert.AreEqual(0, ILE."DUoM Ratio", 'DUoM Ratio must default to 0 on Item Ledger Entry');
    end;

    // -------------------------------------------------------------------------
    // Subscriber: Item Journal Line Quantity validate → DUoM Second Qty computed
    // -------------------------------------------------------------------------

    [Test]
    procedure ItemJournalLine_ValidateQty_FixedMode_ComputesSecondQty()
    var
        Item: Record Item;
        DUoMItemSetup: Record "DUoM Item Setup";
        ItemJnlLine: Record "Item Journal Line";
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
    begin
        // [GIVEN] An item with DUoM setup: Fixed mode, ratio 2
        ItemNo := 'INV-DUOM-01';
        Item.Init();
        Item."No." := ItemNo;
        Item."Base Unit of Measure" := 'KG';
        Item.Insert(false);

        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := ItemNo;
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::Fixed;
        DUoMItemSetup."Fixed Ratio" := 2;
        DUoMItemSetup.Insert(false);

        // [GIVEN] An Item Journal Line for that item
        ItemJnlLine.Init();
        ItemJnlLine."Journal Template Name" := '';
        ItemJnlLine."Journal Batch Name" := '';
        ItemJnlLine."Line No." := 10000;
        ItemJnlLine."Item No." := ItemNo;
        ItemJnlLine.Insert(false);

        // [WHEN] Quantity is validated to 5
        ItemJnlLine.Validate(Quantity, 5);

        // [THEN] DUoM Second Qty = 5 × 2 = 10
        LibraryAssert.AreEqual(10, ItemJnlLine."DUoM Second Qty", 'DUoM Second Qty should be 5 × 2 = 10 for Item Journal Line');
        LibraryAssert.AreEqual(2, ItemJnlLine."DUoM Ratio", 'DUoM Ratio should be auto-populated from item setup on Item Journal Line');

        // Cleanup
        ItemJnlLine.Delete(false);
        DUoMItemSetup.Delete(false);
        Item.Delete(false);
    end;
}
