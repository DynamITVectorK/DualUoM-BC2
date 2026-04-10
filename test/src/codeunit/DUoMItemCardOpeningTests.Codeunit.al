/// <summary>
/// Tests for the DUoM Item Setup opening flow from the Item Card.
/// Validates that GetOrCreate always returns a persisted setup record with
/// the correct Item No., creates one when absent, and never produces duplicates.
/// </summary>
codeunit 50202 "DUoM Item Card Opening Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // GetOrCreate — existing setup is returned unchanged
    // -------------------------------------------------------------------------

    [Test]
    procedure GetOrCreate_ExistingSetup_ReturnsExistingRecord()
    var
        DUoMItemSetup2: Record "DUoM Item Setup";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
    begin
        // [GIVEN] A DUoM setup record already exists for an item
        ItemNo := 'GOCT-001';
        DUoMTestHelpers.CreateItemSetup(ItemNo, true, '', "DUoM Conversion Mode"::Fixed, 0);

        // [WHEN] GetOrCreate is called for the same item
        DUoMItemSetup2.GetOrCreate(ItemNo);

        // [THEN] The existing record is returned with the correct Item No. and values intact
        LibraryAssert.AreEqual(ItemNo, DUoMItemSetup2."Item No.", 'GetOrCreate must return the existing record with the correct Item No.');
        LibraryAssert.IsTrue(DUoMItemSetup2."Dual UoM Enabled", 'GetOrCreate must not overwrite the existing Dual UoM Enabled value.');

        // Cleanup
        DUoMTestHelpers.DeleteItemSetupIfExists(ItemNo);
    end;

    // -------------------------------------------------------------------------
    // GetOrCreate — missing setup is auto-created with correct Item No.
    // -------------------------------------------------------------------------

    [Test]
    procedure GetOrCreate_NoExistingSetup_CreatesRecordWithCorrectItemNo()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
    begin
        // [GIVEN] No DUoM setup exists for the item
        ItemNo := 'GOCT-002';

        // [WHEN] GetOrCreate is called
        DUoMItemSetup.GetOrCreate(ItemNo);

        // [THEN] The returned record has the correct Item No.
        LibraryAssert.AreEqual(ItemNo, DUoMItemSetup."Item No.", 'GetOrCreate must create a record with the correct Item No.');

        // [THEN] The record is persisted in the database
        LibraryAssert.IsTrue(DUoMItemSetup.Get(ItemNo), 'GetOrCreate must persist the new setup record.');

        // Cleanup
        DUoMTestHelpers.DeleteItemSetupIfExists(ItemNo);
    end;

    // -------------------------------------------------------------------------
    // GetOrCreate — repeated calls do not create duplicate records
    // -------------------------------------------------------------------------

    [Test]
    procedure GetOrCreate_CalledTwice_NoDuplicateRecords()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
        RecordCount: Integer;
    begin
        // [GIVEN] No DUoM setup exists for the item
        ItemNo := 'GOCT-003';

        // [WHEN] GetOrCreate is called twice for the same item
        DUoMItemSetup.GetOrCreate(ItemNo);
        Clear(DUoMItemSetup);
        DUoMItemSetup.GetOrCreate(ItemNo);

        // [THEN] Only one record exists for the item
        DUoMItemSetup.SetRange("Item No.", ItemNo);
        RecordCount := DUoMItemSetup.Count();
        LibraryAssert.AreEqual(1, RecordCount, 'GetOrCreate must not create duplicate setup records for the same item.');

        // Cleanup
        DUoMTestHelpers.DeleteItemSetupIfExists(ItemNo);
    end;

    // -------------------------------------------------------------------------
    // GetOrCreate — Item No. is never blank after the call
    // -------------------------------------------------------------------------

    [Test]
    procedure GetOrCreate_ItemNoIsNeverBlank()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
    begin
        // [GIVEN] No DUoM setup exists for the item
        ItemNo := 'GOCT-004';

        // [WHEN] GetOrCreate is called
        DUoMItemSetup.GetOrCreate(ItemNo);

        // [THEN] Item No. is populated and never blank
        LibraryAssert.AreNotEqual('', DUoMItemSetup."Item No.", 'Item No. must never be blank after GetOrCreate.');

        // Cleanup
        DUoMTestHelpers.DeleteItemSetupIfExists(ItemNo);
    end;
}
