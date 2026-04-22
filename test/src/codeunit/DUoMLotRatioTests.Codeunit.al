/// <summary>
/// TDD tests for Issue 13 — DUoM Lot Ratio.
/// Validates that lot-specific actual ratios are correctly stored and
/// automatically proposed on Purchase Lines, Sales Lines and Item Journal Lines
/// when the lot number is validated, respecting the active conversion mode.
///
/// Test coverage:
///   T01 — PurchLine Variable mode: lot with ratio → DUoM Ratio pre-filled, SecondQty recalculated.
///   T02 — PurchLine Variable mode: lot WITHOUT ratio → DUoM Ratio unchanged.
///   T03 — PurchLine Fixed mode:   lot with ratio → DUoM Ratio NOT overwritten.
///   T04 — SalesLine Variable mode: lot with ratio → DUoM Ratio pre-filled, SecondQty recalculated.
///   T05 — ItemJnlLine Variable mode: lot with ratio → DUoM Ratio pre-filled, SecondQty recalculated.
///   T06 — DUoM Lot Ratio table: Actual Ratio ≤ 0 → validation error.
/// </summary>
codeunit 50217 "DUoM Lot Ratio Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // =========================================================================
    // T01 — PurchLine, Variable mode, lot WITH ratio → DUoM Ratio pre-filled
    // =========================================================================

    [Test]
    procedure PurchLine_Variable_LotWithRatio_PreFillsRatioAndSecondQty()
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
        // [GIVEN] An item with DUoM enabled: Variable mode, default ratio 0.5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Variable, 0.5);

        // [GIVEN] A DUoM Lot Ratio record for lot 'LOT001' with actual ratio 0.38
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT001', 0.38);

        // [GIVEN] A purchase order line with Quantity = 10
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 10);

        // [WHEN] Lot No. is validated with 'LOT001'
        PurchLine.Validate("Lot No.", 'LOT001');

        // [THEN] DUoM Ratio is pre-filled with the lot ratio 0.38
        LibraryAssert.AreEqual(0.38, PurchLine."DUoM Ratio",
            'DUoM Ratio must be pre-filled with the lot actual ratio 0.38');

        // [THEN] DUoM Second Qty is recalculated: 10 × 0.38 = 3.8
        LibraryAssert.AreEqual(3.8, PurchLine."DUoM Second Qty",
            'DUoM Second Qty must be recalculated as Qty × lot ratio');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteLotRatioIfExists(Item."No.", 'LOT001');
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // =========================================================================
    // T02 — PurchLine, Variable mode, lot WITHOUT ratio → DUoM Ratio unchanged
    // =========================================================================

    [Test]
    procedure PurchLine_Variable_LotWithoutRatio_DUoMRatioUnchanged()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        InitialRatio: Decimal;
    begin
        // [GIVEN] An item with DUoM enabled: Variable mode, default ratio 0.5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Variable, 0.5);

        // [GIVEN] NO DUoM Lot Ratio exists for lot 'LOTXXX'

        // [GIVEN] A purchase order line with Quantity = 10 (initial ratio applied from setup)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 10);
        InitialRatio := PurchLine."DUoM Ratio";

        // [WHEN] Lot No. is validated with a lot that has no registered ratio
        PurchLine.Validate("Lot No.", 'LOTXXX');

        // [THEN] DUoM Ratio is unchanged (no lot ratio → no update)
        LibraryAssert.AreEqual(InitialRatio, PurchLine."DUoM Ratio",
            'DUoM Ratio must remain unchanged when no lot ratio is registered');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // =========================================================================
    // T03 — PurchLine, Fixed mode, lot WITH ratio → DUoM Ratio NOT overwritten
    // =========================================================================

    [Test]
    procedure PurchLine_Fixed_LotWithRatio_DUoMRatioNotOverwritten()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        FixedRatioValue: Decimal;
    begin
        // [GIVEN] An item with DUoM enabled: Fixed mode, fixed ratio 1.0
        FixedRatioValue := 1.0;
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, FixedRatioValue);

        // [GIVEN] A DUoM Lot Ratio record for lot 'LOT002' with actual ratio 0.41
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT002', 0.41);

        // [GIVEN] A purchase order line with Quantity = 5
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 5);

        // [WHEN] Lot No. is validated with 'LOT002'
        PurchLine.Validate("Lot No.", 'LOT002');

        // [THEN] DUoM Ratio must still be the fixed ratio 1.0 (lot ratio does NOT override Fixed mode)
        LibraryAssert.AreEqual(FixedRatioValue, PurchLine."DUoM Ratio",
            'DUoM Ratio must NOT be overwritten by lot ratio when conversion mode is Fixed');

        // Cleanup
        PurchLine.Delete(false);
        PurchHeader.Delete(false);
        Vendor.Delete(false);
        DUoMTestHelpers.DeleteLotRatioIfExists(Item."No.", 'LOT002');
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // =========================================================================
    // T04 — SalesLine, Variable mode, lot WITH ratio → DUoM Ratio pre-filled
    // =========================================================================

    [Test]
    procedure SalesLine_Variable_LotWithRatio_PreFillsRatioAndSecondQty()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with DUoM enabled: Variable mode, default ratio 0.5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Variable, 0.5);

        // [GIVEN] A DUoM Lot Ratio record for lot 'LOT003' with actual ratio 0.42
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT003', 0.42);

        // [GIVEN] A sales order line with Quantity = 8
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 8);

        // [WHEN] Lot No. is validated with 'LOT003'
        SalesLine.Validate("Lot No.", 'LOT003');

        // [THEN] DUoM Ratio is pre-filled with the lot ratio 0.42
        LibraryAssert.AreEqual(0.42, SalesLine."DUoM Ratio",
            'DUoM Ratio on Sales Line must be pre-filled with the lot actual ratio 0.42');

        // [THEN] DUoM Second Qty is recalculated: 8 × 0.42 = 3.36
        LibraryAssert.AreEqual(3.36, SalesLine."DUoM Second Qty",
            'DUoM Second Qty on Sales Line must be recalculated as Qty × lot ratio');

        // Cleanup
        SalesLine.Delete(false);
        SalesHeader.Delete(false);
        Customer.Delete(false);
        DUoMTestHelpers.DeleteLotRatioIfExists(Item."No.", 'LOT003');
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // =========================================================================
    // T05 — ItemJnlLine, Variable mode, lot WITH ratio → DUoM Ratio pre-filled
    // =========================================================================

    [Test]
    procedure ItemJnlLine_Variable_LotWithRatio_PreFillsRatioAndSecondQty()
    var
        Item: Record Item;
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] An item with DUoM enabled: Variable mode, default ratio 0.5
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG', "DUoM Conversion Mode"::Variable, 0.5);

        // [GIVEN] A DUoM Lot Ratio record for lot 'LOT004' with actual ratio 0.39
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT004', 0.39);

        // [GIVEN] An item journal line for the item with Quantity = 12
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine,
            ItemJnlBatch."Journal Template Name",
            ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase,
            Item."No.",
            12);

        // [WHEN] Lot No. is validated with 'LOT004'
        ItemJnlLine.Validate("Lot No.", 'LOT004');

        // [THEN] DUoM Ratio is pre-filled with the lot ratio 0.39
        LibraryAssert.AreEqual(0.39, ItemJnlLine."DUoM Ratio",
            'DUoM Ratio on Item Journal Line must be pre-filled with the lot actual ratio 0.39');

        // [THEN] DUoM Second Qty is recalculated: 12 × 0.39 = 4.68
        LibraryAssert.AreEqual(4.68, ItemJnlLine."DUoM Second Qty",
            'DUoM Second Qty on Item Journal Line must be recalculated as Qty × lot ratio');

        // Cleanup
        ItemJnlLine.Delete(false);
        ItemJnlBatch.Delete(false);
        ItemJnlTemplate.Delete(false);
        DUoMTestHelpers.DeleteLotRatioIfExists(Item."No.", 'LOT004');
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // =========================================================================
    // T06 — DUoM Lot Ratio table: Actual Ratio ≤ 0 → validation error
    // =========================================================================

    [Test]
    procedure LotRatioTable_ActualRatioZeroOrNegative_ThrowsError()
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A DUoM Lot Ratio record with Actual Ratio = 0
        DUoMLotRatio.Init();
        DUoMLotRatio."Item No." := 'ITEM001';
        DUoMLotRatio."Lot No." := 'LOT005';

        // [WHEN] / [THEN] Validating Actual Ratio = 0 raises an error
        LibraryAssert.IsTrue(
            TryValidateActualRatioZero(DUoMLotRatio),
            'Validating Actual Ratio = 0 must raise an error');

        // [WHEN] / [THEN] Validating Actual Ratio = -1 also raises an error
        LibraryAssert.IsTrue(
            TryValidateActualRatioNegative(DUoMLotRatio),
            'Validating Actual Ratio = -1 must raise an error');
    end;

    [TryFunction]
    local procedure TryValidateActualRatioZero(var DUoMLotRatio: Record "DUoM Lot Ratio"): Boolean
    begin
        DUoMLotRatio.Validate("Actual Ratio", 0);
    end;

    [TryFunction]
    local procedure TryValidateActualRatioNegative(var DUoMLotRatio: Record "DUoM Lot Ratio"): Boolean
    begin
        DUoMLotRatio.Validate("Actual Ratio", -1);
    end;
}
