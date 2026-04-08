/// <summary>
/// Tests for cascade delete of DUoM Item Setup when an Item is deleted.
/// Verifies referential integrity: no orphaned setup records remain after item deletion.
/// </summary>
codeunit 50203 "DUoM Item Delete Tests"
{
    Subtype = Test;

    // -------------------------------------------------------------------------
    // OnDelete trigger — setup record is removed when item is deleted
    // -------------------------------------------------------------------------

    [Test]
    procedure DeleteItem_WithDUoMSetup_DeletesDUoMSetup()
    var
        Item: Record Item;
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
    begin
        // [GIVEN] An item exists in the database
        ItemNo := 'DEL-TEST-001';
        Item.Init();
        Item."No." := ItemNo;
        Item.Insert(false);

        // [GIVEN] A DUoM Item Setup record exists for that item
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := ItemNo;
        DUoMItemSetup.Insert(false);

        // [WHEN] The item is deleted
        Item.Delete(true);

        // [THEN] The DUoM Item Setup record is also deleted (no orphan)
        LibraryAssert.IsFalse(DUoMItemSetup.Get(ItemNo), 'DUoM Item Setup must be deleted when the Item is deleted.');
    end;

    // -------------------------------------------------------------------------
    // OnDelete trigger — no error when item has no DUoM setup
    // -------------------------------------------------------------------------

    [Test]
    procedure DeleteItem_WithoutDUoMSetup_NoError()
    var
        Item: Record Item;
        LibraryAssert: Codeunit "Library Assert";
        ItemNo: Code[20];
    begin
        // [GIVEN] An item exists with no corresponding DUoM setup record
        ItemNo := 'DEL-TEST-002';
        Item.Init();
        Item."No." := ItemNo;
        Item.Insert(false);

        // [WHEN] The item is deleted
        Item.Delete(true);

        // [THEN] The item no longer exists — deletion succeeded without error
        LibraryAssert.IsFalse(Item.Get(ItemNo), 'Item must no longer exist after deletion.');
    end;
}
