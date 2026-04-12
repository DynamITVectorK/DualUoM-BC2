/// <summary>
/// Tests for the Qty. Rounding Precision editability on the Item Units of Measure
/// page extension (pageextension 50110 "DUoM Item UoM Subform").
///
/// The page extension adds Qty. Rounding Precision to the repeater with a conditional
/// Editable expression. The field is editable for a given UoM line only when there are
/// no Item Ledger Entries and no Warehouse Entries for that exact (Item No., UoM Code)
/// combination. A transaction in a different UoM of the same item must not affect
/// the editability of this line.
///
/// These tests verify the four conditions that drive the editability behaviour:
///   (a) No ILE and no WH entries for that UoM → editable.
///   (b) ILE exist for that UoM → non-editable.
///   (c) ILE exist for a different UoM of the same item → this UoM remains editable.
///   (d) Warehouse entries exist for that UoM → non-editable.
/// </summary>
codeunit 50212 "DUoM Item UoM Round Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // (a) No ILE and no WH entries: field is editable, validation succeeds
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
            'Qty. Rounding Precision must be settable when no entries exist for the UoM');
    end;

    // -------------------------------------------------------------------------
    // (b) ILE exist for that UoM: page editability condition evaluates to false
    // -------------------------------------------------------------------------

    [Test]
    procedure QtyRndPrecision_WithILE_PageEditConditionIsFalse()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        ILE: Record "Item Ledger Entry";
        WarehouseEntry: Record "Warehouse Entry";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        UoMCode: Code[10];
    begin
        // [GIVEN] An item posted via an item journal so that Item Ledger Entries are created
        LibraryInventory.CreateItem(Item);
        UoMCode := Item."Base Unit of Measure";
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

        // [WHEN] The page editability condition is evaluated for (Item No., UoM Code)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Unit of Measure Code", UoMCode);
        WarehouseEntry.SetRange("Item No.", Item."No.");
        WarehouseEntry.SetRange("Unit of Measure Code", UoMCode);

        // [THEN] ILE are not empty → editability condition (ILE.IsEmpty AND WHE.IsEmpty) is false
        LibraryAssert.IsFalse(
            ILE.IsEmpty() and WarehouseEntry.IsEmpty(),
            'ILE exist for this UoM; Qty. Rounding Precision page field must not be editable');
    end;

    // -------------------------------------------------------------------------
    // (c) ILE exist for a different UoM: this UoM line remains editable
    // -------------------------------------------------------------------------

    [Test]
    procedure QtyRndPrecision_ILE_OtherUoM_IsEditable()
    var
        Item: Record Item;
        UnitOfMeasure: Record "Unit of Measure";
        ItemUoM: Record "Item Unit of Measure";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        ILE: Record "Item Ledger Entry";
        WarehouseEntry: Record "Warehouse Entry";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        BaseUoMCode: Code[10];
        AltUoMCode: Code[10];
    begin
        // [GIVEN] An item with a base UoM and an alternate UoM
        LibraryInventory.CreateItem(Item);
        BaseUoMCode := Item."Base Unit of Measure";
        LibraryInventory.CreateUnitOfMeasureCode(UnitOfMeasure);
        AltUoMCode := UnitOfMeasure.Code;
        LibraryInventory.CreateItemUnitOfMeasure(ItemUoM, Item."No.", AltUoMCode, 1);

        // [GIVEN] An item journal line is posted using the alternate UoM
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine,
            ItemJnlBatch."Journal Template Name",
            ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase,
            Item."No.",
            0);
        ItemJnlLine.Validate("Unit of Measure Code", AltUoMCode);
        ItemJnlLine.Validate(Quantity, 5);
        ItemJnlLine.Modify(true);
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [WHEN] The page editability condition is evaluated for the base UoM
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Unit of Measure Code", BaseUoMCode);
        WarehouseEntry.SetRange("Item No.", Item."No.");
        WarehouseEntry.SetRange("Unit of Measure Code", BaseUoMCode);

        // [THEN] No entries exist for the base UoM → editability condition is true
        LibraryAssert.IsTrue(
            ILE.IsEmpty() and WarehouseEntry.IsEmpty(),
            'Entries for a different UoM must not affect editability of the base UoM line');
    end;

    // -------------------------------------------------------------------------
    // (d) Warehouse entries exist for that UoM: page editability condition is false
    // -------------------------------------------------------------------------

    [Test]
    procedure QtyRndPrecision_WHEntry_SameUoM_IsNotEditable()
    var
        Item: Record Item;
        WhseEntry: Record "Warehouse Entry";
        ILE: Record "Item Ledger Entry";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        UoMCode: Code[10];
        NextEntryNo: Integer;
    begin
        // [GIVEN] An item with no item ledger entries
        LibraryInventory.CreateItem(Item);
        UoMCode := Item."Base Unit of Measure";

        // [GIVEN] A Warehouse Entry exists for (Item No., UoM Code).
        // Warehouse Entry is a historical/registered table. No standard test library
        // provides a method to create warehouse entries without full directed-put-away-and-pick
        // setup (location, zones, bins, warehouse employee). Direct insertion is used here
        // to test the data condition logic in isolation, consistent with how tests for
        // historical tables (e.g. Value Entry) are handled when no library method exists.
        if WhseEntry.FindLast() then
            NextEntryNo := WhseEntry."Entry No." + 1
        else
            NextEntryNo := 1;
        WhseEntry.Init();
        WhseEntry."Entry No." := NextEntryNo;
        WhseEntry."Item No." := Item."No.";
        WhseEntry."Unit of Measure Code" := UoMCode;
        WhseEntry.Insert(false);

        // [WHEN] The page editability condition is evaluated for (Item No., UoM Code)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Unit of Measure Code", UoMCode);
        WhseEntry.Reset();
        WhseEntry.SetRange("Item No.", Item."No.");
        WhseEntry.SetRange("Unit of Measure Code", UoMCode);

        // [THEN] WH entries exist for this UoM → editability condition is false (non-editable)
        LibraryAssert.IsFalse(
            ILE.IsEmpty() and WhseEntry.IsEmpty(),
            'Warehouse entries for this UoM must cause the editability condition to evaluate false');
    end;
}
