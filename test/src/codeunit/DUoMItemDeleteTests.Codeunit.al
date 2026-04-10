/// <summary>
/// Tests for cascade delete of DUoM Item Setup when an Item is deleted.
/// Verifies referential integrity: no orphaned setup records remain after item deletion.
/// </summary>
codeunit 50203 "DUoM Item Delete Tests"
{
    Subtype = Test;
    Permissions = tabledata "DUoM Item Setup" = RIMD;

    // -------------------------------------------------------------------------
    // OnDelete trigger — setup record is removed when item is deleted
    // -------------------------------------------------------------------------

    [Test]
    procedure DeleteItem_WithDUoMSetup_DeletesDUoMSetup()
    var
        Item: Record Item;
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item exists in the database
        LibraryInventory.CreateItem(Item);

        // [GIVEN] A DUoM Item Setup record exists for that item
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := Item."No.";
        DUoMItemSetup.Insert(false);

        // [WHEN] The item is deleted
        Item.Delete(true);

        // [THEN] The DUoM Item Setup record is also deleted (no orphan)
        LibraryAssert.IsFalse(DUoMItemSetup.Get(Item."No."), 'DUoM Item Setup must be deleted when the Item is deleted.');
    end;

    // -------------------------------------------------------------------------
    // OnDelete trigger — no error when item has no DUoM setup
    // -------------------------------------------------------------------------

    [Test]
    procedure DeleteItem_WithoutDUoMSetup_NoError()
    var
        Item: Record Item;
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item exists with no corresponding DUoM setup record
        LibraryInventory.CreateItem(Item);

        // [WHEN] The item is deleted
        Item.Delete(true);

        // [THEN] The item no longer exists — deletion succeeded without error
        LibraryAssert.IsFalse(Item.Get(Item."No."), 'Item must no longer exist after deletion.');
    end;
}
