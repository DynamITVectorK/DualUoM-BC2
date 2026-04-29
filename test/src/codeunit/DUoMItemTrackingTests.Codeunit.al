/// <summary>
/// Tests TDD para DUoM Tracking Subscribers (50109) y la integración DUoM
/// con Item Tracking Lines / Tracking Specification (tabla 6500).
///
/// Escenarios cubiertos:
///   T01 — Variable + lote CON ratio → Validate("Lot No.") rellena DUoM Ratio y DUoM Second Qty
///   T02 — Variable + lote SIN ratio → Validate("Lot No.") no modifica DUoM Ratio
///   T03 — Fixed mode + lote CON ratio → Validate("Lot No.") usa ratio fijo (no ratio de lote)
///   T04 — Cambio de Quantity (Base) con DUoM Ratio establecido → DUoM Second Qty recalculada
///   T05 — E2E: compra con lote asignado via Item Tracking → ILE con DUoM Second Qty correcto
///
/// Arquitectura de tests:
///   T01–T04: tests unitarios sobre el buffer Tracking Specification (in-memory, sin Insert).
///            Verifican los suscriptores OnAfterValidateEvent directamente a través del
///            mecanismo estándar de Validate() sobre un registro local.
///   T05:     test de integración E2E usando Purchase Order + Library - Item Tracking.
///            Verifica coherencia entre el ratio de lote y el ILE resultante del posting.
/// </summary>
codeunit 50218 "DUoM Item Tracking Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T01 — Variable + lote CON ratio → DUoM Ratio y DUoM Second Qty pre-rellenados
    //
    // Verifica que, al validar Lot No. en Tracking Specification para un artículo
    // con DUoM Variable y un ratio de lote registrado, el suscriptor rellena
    // DUoM Ratio con el ratio del lote y recalcula DUoM Second Qty correctamente.
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingSpec_Variable_LotWithRatio_DUoMFieldsPreFilled()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio fijo de fallback 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Ratio de lote registrado: 0,38 para (ItemNo, 'LOT-T01')
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT-T01', 0.38);

        // [GIVEN] Tracking Specification con Item No. y Quantity (Base) = 10
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 10;

        // [WHEN] Validate Lot No. = 'LOT-T01'
        TrackingSpec.Validate("Lot No.", 'LOT-T01');

        // [THEN] DUoM Ratio = 0,38 (ratio del lote)
        LibraryAssert.AreEqual(0.38, TrackingSpec."DUoM Ratio",
            'DUoM Ratio debe ser el ratio del lote (0,38).');

        // [THEN] DUoM Second Qty = 10 × 0,38 = 3,8
        LibraryAssert.AreNearlyEqual(3.8, TrackingSpec."DUoM Second Qty", 0.001,
            'DUoM Second Qty debe ser Quantity (Base) × ratio del lote.');
    end;

    // -------------------------------------------------------------------------
    // T02 — Variable + lote SIN ratio → DUoM Ratio sin cambios
    //
    // Verifica que, al validar Lot No. para un lote sin ratio registrado en
    // DUoM Lot Ratio, el suscriptor no modifica los campos DUoM existentes.
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingSpec_Variable_LotWithoutRatio_DUoMRatioUnchanged()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio fijo de fallback 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Lote SIN ratio registrado
        // (no se llama a CreateLotRatio — el lote 'LOT-T02' no existe en DUoM Lot Ratio)

        // [GIVEN] Tracking Specification con ratio preexistente 0,40
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 10;
        TrackingSpec."DUoM Ratio" := 0.40;
        TrackingSpec."DUoM Second Qty" := 4.0;

        // [WHEN] Validate Lot No. = 'LOT-T02' (sin ratio de lote)
        TrackingSpec.Validate("Lot No.", 'LOT-T02');

        // [THEN] DUoM Ratio permanece sin cambios (0,40)
        LibraryAssert.AreEqual(0.40, TrackingSpec."DUoM Ratio",
            'DUoM Ratio debe permanecer sin cambios cuando no hay ratio de lote.');

        // [THEN] DUoM Second Qty permanece sin cambios (4,0)
        LibraryAssert.AreNearlyEqual(4.0, TrackingSpec."DUoM Second Qty", 0.001,
            'DUoM Second Qty debe permanecer sin cambios cuando no hay ratio de lote.');
    end;

    // -------------------------------------------------------------------------
    // T03 — Fixed mode + lote CON ratio → usa ratio fijo (no el ratio de lote)
    //
    // Verifica que en modo Fixed, el suscriptor aplica el ratio fijo del artículo
    // y NO el ratio de lote registrado en DUoM Lot Ratio, incluso si existe.
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingSpec_Fixed_LotWithRatio_UsesFixedRatio()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Fixed (ratio fijo 0,50)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Fixed, 0.50);

        // [GIVEN] Ratio de lote registrado: 0,38 para (ItemNo, 'LOT-T03')
        //         (el ratio de lote NO debe sobreescribir en modo Fixed)
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT-T03', 0.38);

        // [GIVEN] Tracking Specification con Item No. y Quantity (Base) = 20
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 20;

        // [WHEN] Validate Lot No. = 'LOT-T03'
        TrackingSpec.Validate("Lot No.", 'LOT-T03');

        // [THEN] DUoM Ratio = 0,50 (ratio fijo del artículo, NO el 0,38 del lote)
        LibraryAssert.AreEqual(0.50, TrackingSpec."DUoM Ratio",
            'En modo Fixed, DUoM Ratio debe ser el ratio fijo del artículo, no el del lote.');

        // [THEN] DUoM Second Qty = 20 × 0,50 = 10
        LibraryAssert.AreNearlyEqual(10.0, TrackingSpec."DUoM Second Qty", 0.001,
            'En modo Fixed, DUoM Second Qty debe calcularse con el ratio fijo.');
    end;

    // -------------------------------------------------------------------------
    // T04 — Cambio de Quantity (Base) → DUoM Second Qty recalculada automáticamente
    //
    // Verifica que al modificar Quantity (Base) en una línea de Tracking Specification
    // con DUoM Ratio ya establecido, DUoM Second Qty se recalcula automáticamente.
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingSpec_ChangeQtyBase_SecondQtyRecalculated()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio fijo de fallback 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Tracking Specification con DUoM Ratio ya establecido (0,40)
        //         y Quantity (Base) = 10
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 10;
        TrackingSpec."DUoM Ratio" := 0.40;
        TrackingSpec."DUoM Second Qty" := 4.0; // Valor previo coherente con Qty=10

        // [WHEN] Se cambia Quantity (Base) a 15
        TrackingSpec.Validate("Quantity (Base)", 15);

        // [THEN] DUoM Second Qty = 15 × 0,40 = 6,0 (recalculada)
        LibraryAssert.AreNearlyEqual(6.0, TrackingSpec."DUoM Second Qty", 0.001,
            'DUoM Second Qty debe recalcularse con la nueva cantidad.');
    end;

    // -------------------------------------------------------------------------
    // T05 — Coherencia E2E: valor DUoM en Tracking Specification == valor DUoM en ILE
    //
    // Verifica que el valor DUoM Second Qty calculado al validar Lot No. en
    // Tracking Specification es coherente con el DUoM Second Qty resultante en
    // el ILE tras la contabilización con el mismo lote y ratio.
    //
    // Flujo:
    //   1. Validar Lot No. en Tracking Specification → DUoM Second Qty = A
    //   2. Contabilizar IJL con el mismo lote (vía Reservation Entry estándar BC)
    //   3. Verificar que ILE.DUoM Second Qty = A (coherencia entre tracking y posting)
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingSpecAndILE_SameLotRatio_DUoMSecondQtyCoherent()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
        TrackingSpecSecondQty: Decimal;
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio de fallback 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Lot tracking habilitado para el artículo
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Ratio de lote registrado: 0,38 para 'LOT-T05'
        LotNo := 'LOT-T05';
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNo, 0.38);

        // [GIVEN] Tracking Specification con Item No. y Quantity (Base) = 10
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 10;

        // [WHEN] Validate Lot No. = 'LOT-T05' en Tracking Specification (buffer)
        TrackingSpec.Validate("Lot No.", LotNo);

        // [THEN] DUoM Second Qty calculada en Tracking Specification = 10 × 0,38 = 3,8
        TrackingSpecSecondQty := TrackingSpec."DUoM Second Qty";
        LibraryAssert.AreNearlyEqual(3.8, TrackingSpecSecondQty, 0.001,
            'Tracking Specification: DUoM Second Qty debe ser 10 × 0,38 = 3,8.');

        // [WHEN] Contabilizar IJL con el mismo lote (Reservation Entry estándar BC)
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        ItemJnlLine.Modify(true);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNo, 10);
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE DUoM Second Qty == valor calculado en Tracking Specification
        ILE.SetRange("Item No.", Item."No.");
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T05: Se esperaba un ILE tras la contabilización.');
        LibraryAssert.AreNearlyEqual(TrackingSpecSecondQty, ILE."DUoM Second Qty", 0.001,
            'ILE DUoM Second Qty debe ser coherente con el valor calculado en Tracking Specification.');
        LibraryAssert.AreEqual(0.38, ILE."DUoM Ratio",
            'ILE DUoM Ratio debe coincidir con el ratio del lote.');
    end;
}
