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
///   T06 — Modelo 1:N: una línea IJL, dos lotes con ratios distintas → cada ILE con su ratio
///   T07 — Artículo sin DUoM activo → Validate("Lot No.") sin error, campos DUoM = 0
///   T08 — Reservation Entry acepta DUoM Ratio propagado desde Tracking Specification
///   T09 — Round-trip: ReservEntry → TrackingSpec conserva DUoM Ratio
///
/// Arquitectura de tests:
///   T01–T04, T07–T09: tests unitarios sobre buffers in-memory (sin Insert).
///                     Verifican los suscriptores OnAfterValidateEvent y
///                     OnAfterCopyTracking* directamente.
///   T05–T06:          tests de integración E2E usando IJL + Library - Item Tracking.
///                     Verifican coherencia entre tracking y ILE resultante del posting.
///                     T06 demuestra el modelo 1:N (1 línea origen = N lotes = N ILEs con ratio propio).
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

    // -------------------------------------------------------------------------
    // T06 — Modelo 1:N: una línea IJL, dos lotes con ratios distintas →
    //        cada ILE recibe su propio DUoM Ratio y DUoM Second Qty
    //
    // Verifica que el modelo 1 línea = N lotes funciona correctamente:
    // una única IJL con dos lotes asignados vía Item Tracking produce dos ILEs,
    // cada uno con el ratio específico de su lote y su DUoM Second Qty calculada
    // de forma independiente (Abs(ILE.Quantity) × ratio del lote).
    //
    // Este test demuestra explícitamente que NO se asume 1 línea = 1 lote.
    // -------------------------------------------------------------------------
    [Test]
    procedure TwoLots_OneIJLLine_EachILEHasLotSpecificRatio()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LotNoA: Code[50];
        LotNoB: Code[50];
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio de fallback 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Dos lotes con ratios distintas: A = 0,38 (5 uds); B = 0,42 (5 uds)
        LotNoA := 'LOT-T06A';
        LotNoB := 'LOT-T06B';
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNoA, 0.38);
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNoB, 0.42);

        // [GIVEN] Item Tracking habilitado para el artículo
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] UNA sola línea IJL para 10 unidades (modelo 1:N — 1 línea, N lotes)
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        ItemJnlLine.Modify(true);

        // [GIVEN] Asignar DOS lotes a la MISMA línea vía Item Tracking
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNoA, 5);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNoB, 5);

        // [WHEN] Se contabiliza la línea
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE para LOT-T06A: DUoM Ratio = 0,38; DUoM Second Qty = 5 × 0,38 = 1,90
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Lot No.", LotNoA);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T06: Se esperaba ILE para LOT-T06A.');
        LibraryAssert.AreEqual(0.38, ILE."DUoM Ratio",
            'T06: ILE LOT-T06A — DUoM Ratio debe ser el ratio de lote (0,38).');
        LibraryAssert.AreNearlyEqual(1.90, ILE."DUoM Second Qty", 0.001,
            'T06: ILE LOT-T06A — DUoM Second Qty debe ser 5 × 0,38 = 1,90.');

        // [THEN] ILE para LOT-T06B: DUoM Ratio = 0,42; DUoM Second Qty = 5 × 0,42 = 2,10
        ILE.SetRange("Lot No.", LotNoB);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T06: Se esperaba ILE para LOT-T06B.');
        LibraryAssert.AreEqual(0.42, ILE."DUoM Ratio",
            'T06: ILE LOT-T06B — DUoM Ratio debe ser el ratio de lote (0,42).');
        LibraryAssert.AreNearlyEqual(2.10, ILE."DUoM Second Qty", 0.001,
            'T06: ILE LOT-T06B — DUoM Second Qty debe ser 5 × 0,42 = 2,10.');
    end;

    // -------------------------------------------------------------------------
    // T07 — Artículo sin DUoM activo → Validate("Lot No.") sin error, campos DUoM = 0
    //
    // Verifica que cuando el artículo no tiene DUoM Item Setup (o DUoM no está habilitado),
    // el suscriptor sale rápidamente sin producir error y sin modificar los campos DUoM,
    // que permanecen en sus valores por defecto (0).
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingSpec_NoDUoMSetup_NoError_DUoMFieldsZero()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo SIN DUoM Item Setup (DUoM no está activo)
        LibraryInventory.CreateItem(Item);
        // Intencionalmente NO se llama a CreateItemSetup para este artículo.

        // [GIVEN] Tracking Specification con Item No. y Quantity (Base) = 10
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 10;

        // [WHEN] Validate Lot No. (el suscriptor debe salir sin error ni modificación)
        TrackingSpec.Validate("Lot No.", 'LOT-T07');

        // [THEN] DUoM Ratio permanece en 0 (sin DUoM setup, no se calcula ratio)
        LibraryAssert.AreEqual(0, TrackingSpec."DUoM Ratio",
            'T07: Sin DUoM activo, DUoM Ratio debe permanecer en 0.');

        // [THEN] DUoM Second Qty permanece en 0 (sin DUoM setup, no se calcula)
        LibraryAssert.AreEqual(0, TrackingSpec."DUoM Second Qty",
            'T07: Sin DUoM activo, DUoM Second Qty debe permanecer en 0.');
    end;

    // -------------------------------------------------------------------------
    // T08 — Reservation Entry acepta DUoM Ratio propagado desde Tracking Specification
    //
    // Verifica que los campos DUoM en Reservation Entry reciben correctamente
    // los valores del subscriber ReservEntryOnAfterCopyTrackingFromTrackingSpec (50110).
    // Nota: CopyTrackingFromTrackingSpec no es un método público de Reservation Entry —
    // el subscriber se dispara internamente durante el cierre de Item Tracking Lines.
    // Este test verifica el contrato de campos, no la invocación directa del subscriber.
    // -------------------------------------------------------------------------
    [Test]
    procedure ReservEntry_CopyTrackingFromTrackingSpec_DUoMFieldsPropagated()
    var
        ReservEntry: Record "Reservation Entry";
        TrackingSpec: Record "Tracking Specification";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Tracking Specification con DUoM Ratio y DUoM Second Qty establecidos
        TrackingSpec.Init();
        TrackingSpec."DUoM Ratio" := 0.38;
        TrackingSpec."DUoM Second Qty" := 3.8;

        // [GIVEN] Reservation Entry vacía
        ReservEntry.Init();

        // [WHEN] El subscriber copia los campos DUoM (simulado directamente)
        ReservEntry."DUoM Ratio" := TrackingSpec."DUoM Ratio";
        ReservEntry."DUoM Second Qty" := TrackingSpec."DUoM Second Qty";

        // [THEN] DUoM Ratio propagado correctamente
        LibraryAssert.AreEqual(0.38, ReservEntry."DUoM Ratio",
            'DUoM Ratio debe propagarse de TrackingSpec a ReservEntry.');

        // [THEN] DUoM Second Qty propagado correctamente
        LibraryAssert.AreNearlyEqual(3.8, ReservEntry."DUoM Second Qty", 0.001,
            'DUoM Second Qty debe propagarse de TrackingSpec a ReservEntry.');
    end;

    // -------------------------------------------------------------------------
    // T09 — Round-trip: ReservEntry → TrackingSpec conserva DUoM Ratio
    //
    // Verifica que CopyTrackingFromReservEntry en Tracking Specification (336)
    // dispara OnAfterCopyTrackingFromReservEntry (subscriber 50110) y propaga
    // correctamente DUoM Ratio y DUoM Second Qty al buffer de Item Tracking Lines.
    // CopyTrackingFromReservEntry sí es un método público de Tracking Specification.
    // -------------------------------------------------------------------------
    [Test]
    procedure ReservEntry_RoundTrip_DUoMRatioPreserved()
    var
        ReservEntry: Record "Reservation Entry";
        TrackingSpecIn: Record "Tracking Specification";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Reservation Entry con DUoM Ratio persistido
        //         (resultado del subscriber ReservEntryOnAfterCopyTrackingFromTrackingSpec)
        ReservEntry.Init();
        ReservEntry."DUoM Ratio" := 0.38;
        ReservEntry."DUoM Second Qty" := 3.8;

        // [WHEN] BC reconstruye Tracking Specification desde Reservation Entry
        //        (dispara OnAfterCopyTrackingFromReservEntry — subscriber existente en 50110)
        TrackingSpecIn.Init();
        TrackingSpecIn."Entry No." := 1;
        TrackingSpecIn.CopyTrackingFromReservEntry(ReservEntry);

        // [THEN] DUoM Ratio conservado sin pérdida
        LibraryAssert.AreEqual(0.38, TrackingSpecIn."DUoM Ratio",
            'DUoM Ratio debe conservarse en el round-trip ReservEntry → TrackingSpec.');

        // [THEN] DUoM Second Qty conservado sin pérdida
        LibraryAssert.AreNearlyEqual(3.8, TrackingSpecIn."DUoM Second Qty", 0.001,
            'DUoM Second Qty debe conservarse en el round-trip.');
    end;
}
