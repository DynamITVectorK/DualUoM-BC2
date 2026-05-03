/// <summary>
/// Tests para verificar que los campos DUoM persisten en Item Ledger Entry
/// tras la contabilización y quedan disponibles para la página
/// Posted Item Tracking Lines (Page 6511), cuya SourceTable es Item Ledger Entry (32).
///
/// pageextension 50124 "DUoM Posted Item Trk. Lines" muestra directamente los valores
/// del ILE — no recalcula nada. Estos tests verifican que esos valores existen y son
/// correctos tras la contabilización.
///
/// Escenarios cubiertos:
///   T1: PostedItemTrkLines_ShowsPersistedRatioAndSecondQty
///       — PO modo Fixed, lote, ratio 0.5 → ILE persiste DUoM Ratio = 0.5 y
///         DUoM Second Qty = 5 exactamente como escribió el subscriber de posting.
///   T2: PostedItemTrkLines_ItemWithoutDUoMSetup_FieldsAreZero
///       — Artículo sin DUoM Item Setup → ILE tiene DUoM Ratio = 0 y
///         DUoM Second Qty = 0; sin error de runtime.
/// </summary>
codeunit 50224 "DUoM Pstd Item Trk. Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T1 — Contabilización con lote y DUoM Fixed → ILE persiste ratio y qty
    //
    // Arrange: artículo Fixed ratio 0.5 con lote; PO qty = 10; tracking asignado
    //          con AssignLotWithDUoMRatioToPurchLine (ratio = 0.5, qty = 10).
    //   PurchLine.DUoM Second Qty = 10 × 0.5 = 5 (calculado por subscriber).
    //   ReservEntry.DUoM Second Qty = 10 × 0.5 = 5 (coincide → posting válido).
    // Act:  PostPurchaseDocument (Receive = true, Invoice = false).
    // Assert: ILE."DUoM Ratio" = 0.5, ILE."DUoM Second Qty" = 5.
    // -------------------------------------------------------------------------

    [Test]
    procedure PostedItemTrkLines_ShowsPersistedRatioAndSecondQty()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        // [GIVEN] Artículo modo Fixed, ratio 0.5, con seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS',
            "DUoM Conversion Mode"::Fixed, 0.5);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        LotNo := 'LOT-TRK1';

        // [GIVEN] Pedido de compra: 10 uds → DUoM Second Qty = 10 × 0.5 = 5
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [GIVEN] Lote asignado con DUoM Ratio = 0.5 y DUoM Second Qty = 5 en tracking
        DUoMTestHelpers.AssignLotWithDUoMRatioToPurchLine(PurchLine, LotNo, 10, 0.5);

        // [WHEN] Se contabiliza la recepción
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] El ILE contiene exactamente los valores persistidos por el subscriber
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange("Lot No.", LotNo);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T1: Se esperaba un ILE de compra para el lote LOT-TRK1');
        LibraryAssert.AreNearlyEqual(0.5, ILE."DUoM Ratio", 0.001,
            'T1: ILE."DUoM Ratio" debe ser 0.5 (modo Fixed, ratio configurado)');
        LibraryAssert.AreNearlyEqual(5, ILE."DUoM Second Qty", 0.001,
            'T1: ILE."DUoM Second Qty" debe ser 10 × 0.5 = 5');
    end;

    // -------------------------------------------------------------------------
    // T2 — Artículo sin DUoM Item Setup → ILE no tiene datos DUoM, sin error
    //
    // Arrange: artículo sin DUoM Item Setup (DeleteItemSetupIfExists precaución).
    //          PO simple qty = 5; sin lot tracking.
    // Act:  PostPurchaseDocument (Receive = true, Invoice = false).
    // Assert: ILE."DUoM Ratio" = 0, ILE."DUoM Second Qty" = 0; sin error de runtime.
    // -------------------------------------------------------------------------

    [Test]
    procedure PostedItemTrkLines_ItemWithoutDUoMSetup_FieldsAreZero()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo sin DUoM Item Setup
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");

        // [GIVEN] Pedido de compra: 5 uds; sin tracking de lote
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Modify(true);

        // [WHEN] Se contabiliza la recepción (sin error esperado)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] El ILE existe y sus campos DUoM son 0 (artículo no configurado)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T2: Se esperaba un ILE de compra para artículo sin DUoM');
        LibraryAssert.AreEqual(0, ILE."DUoM Ratio",
            'T2: ILE."DUoM Ratio" debe ser 0 para artículo sin DUoM setup');
        LibraryAssert.AreEqual(0, ILE."DUoM Second Qty",
            'T2: ILE."DUoM Second Qty" debe ser 0 para artículo sin DUoM setup');
    end;
}
