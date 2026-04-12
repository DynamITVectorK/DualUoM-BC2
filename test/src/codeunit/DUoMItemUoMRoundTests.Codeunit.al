/// <summary>
/// Tests for the Qty. Rounding Precision editability on the Item Units of Measure
/// page extension (pageextension 50110 "DUoM Item UoM Subform").
///
/// The page extension adds Qty. Rounding Precision to the repeater with a conditional
/// Editable expression: the field is editable only when no Item Ledger Entries exist
/// for the item (ILE.IsEmpty() = true for the given Item No.).
///
/// These tests verify the two conditions that drive the editability behaviour:
///   1. No ILE exist → Qty. Rounding Precision can be set on Item Unit of Measure.
///   2. ILE exist after posting → the data condition used by the page evaluates to
///      "not editable" (ILE.IsEmpty() returns false).
/// </summary>
codeunit 50212 "DUoM Item UoM Round Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // No ILE: Qty. Rounding Precision can be validated (field is editable)
    // -------------------------------------------------------------------------

    [Test]
    procedure QtyRndPrecision_NoILE_ValidationSucceeds()
    var
        Item: Record Item;
        ItemUoM: Record "Item Unit of Measure";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with no item ledger entries
        LibraryInventory.CreateItem(Item);

        // [GIVEN] The item's base unit of measure record exists
        ItemUoM.Get(Item."No.", Item."Base Unit of Measure");

        // [WHEN] Qty. Rounding Precision is validated on the Item Unit of Measure record
        ItemUoM.Validate("Qty. Rounding Precision", 0.01);

        // [THEN] No error is raised and the value is stored on the record
        LibraryAssert.AreEqual(
            0.01,
            ItemUoM."Qty. Rounding Precision",
            'Qty. Rounding Precision must be settable when no ILE exist for the item');
    end;

    // -------------------------------------------------------------------------
    // ILE exist after posting: page editability condition evaluates to false
    // -------------------------------------------------------------------------

    [Test]
    procedure QtyRndPrecision_WithILE_PageEditConditionIsFalse()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        ILE: Record "Item Ledger Entry";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item posted via an item journal so that Item Ledger Entries are created
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine,
            ItemJnlBatch."Journal Template Name",
            ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase,
            Item."No.",
            0);
        ItemJnlLine.Validate(Quantity, 5);
        ItemJnlLine.Modify(true);
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [WHEN] The page editability condition is evaluated for this item
        ILE.SetRange("Item No.", Item."No.");

        // [THEN] ILE are not empty, so the page editability condition is false
        // (IsQtyRndPrecisionEditable = ILE.IsEmpty() evaluates to false)
        LibraryAssert.IsFalse(
            ILE.IsEmpty(),
            'Item Ledger Entries must exist after posting; Qty. Rounding Precision page field must not be editable');
    end;
}
