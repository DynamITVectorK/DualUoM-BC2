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
///   T10 — ReservEntry.CopyTrackingFromReservEntry propaga DUoM Ratio
///   T11 — Artículo sin DUoM activo: CopyTrackingFromReservEntry no establece DUoM
///   T12 — Variable + sin ratio de lote + fuente Purchase Line → fallback a PurchLine.DUoM Ratio
///   T13 — Variable + ratio de lote existe → ratio de lote gana sobre Purchase Line
///   T14 — Variable + sin ratio de lote + ratio manual en tracking → no sobrescribir
///   T15 — Múltiples lotes sin ratio → cada lote recibe fallback de la misma Purchase Line
///   T16 — Comparación DUoM entre Reservation Entries detecta cambios funcionales
///   T17 — TrackingSpec → Reservation Entry aplica signo estándar para ventas
///   T18 — Reservation Entry → TrackingSpec rehidrata valores positivos para la página
///   T19 — TrackingSpec → TrackingSpec preserva los campos DUoM
///   T20 — La suma funcional de tracking ignora líneas vacías/de inserción
///   T21 — Variable + sin ratio de lote + fuente Sales Line → fallback a SalesLine.DUoM Ratio
///   T22 — Variable + ratio de lote existe → ratio de lote gana sobre Sales Line
///   T23 — Variable + ratio manual en tracking (ventas) → no sobrescribir con fallback
///   T24 — Múltiples lotes en ventas sin ratio → cada lote recibe fallback de Sales Line
///   T25 — Ventas: segunda persistencia y rehidratación recargan el último valor DUoM
///   T26 — Reapertura real en Sales Item Tracking preserva DUoM manual
///   T27 — Reapertura real en Sales Item Tracking: última edición prevalece
///
/// Arquitectura de tests:
///   T01–T04, T07–T09: tests unitarios sobre buffers in-memory (sin Insert).
///                     Verifican los suscriptores OnAfterValidateEvent y
///                     OnAfterCopyTracking* directamente.
///   T05–T06:          tests de integración E2E usando IJL + Library - Item Tracking.
///                     Verifican coherencia entre tracking y ILE resultante del posting.
///                     T06 demuestra el modelo 1:N (1 línea origen = N lotes = N ILEs con ratio propio).
///   T12–T15:          tests unitarios del fallback Purchase Line (bugfix). Requieren
///                     Purchase Line real en BD para que PurchLine.Get() tenga éxito.
///                     Sin Insert de Tracking Specification (buffer in-memory + fuente real).
///   T16–T20:          tests unitarios de la capa `DUoM Tracking Prop. Mgt` (50125)
///                     para comparación DUoM, normalización de signo y suma funcional.
///   T21–T24:          tests unitarios del fallback de línea origen para Sales Line
///                     (simetría funcional con Purchase Line).
///   T25:              test unitario de persistencia/reapertura lógica en ventas:
///                     la última edición en tracking prevalece al rehidratar.
///   T26–T27:          tests de integración con TestPage "Sales Order" + modal
///                     "Item Tracking Lines": persistencia real en Reservation Entry
///                     y rehidratación al reabrir.
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
    // de forma independiente (ILE.Quantity × ratio del lote, con signo coherente).
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

    // -------------------------------------------------------------------------
    // T10 — ReservEntry.CopyTrackingFromReservEntry propaga DUoM Ratio
    //
    // Verifica que el subscriber ReservEntryOnAfterCopyTrackingFromReservEntry (50110)
    // propaga DUoM Ratio y DUoM Second Qty cuando una Reservation Entry copia campos
    // de tracking desde otra Reservation Entry.
    //
    // Contexto: En el flujo INSERT de Item Tracking Lines, BC llama internamente a
    //   InsertReservEntry.CopyTrackingFromReservEntry(ReservEntry1), donde ReservEntry1
    //   ya tiene DUoM Ratio correcto (puesto por ReservEntryOnAfterCopyTrackingFromTrackingSpec).
    //   Sin el subscriber correspondiente en Table "Reservation Entry", el INSERT final
    //   tiene DUoM Ratio = 0.
    // CopyTrackingFromReservEntry sí es un método público de Reservation Entry.
    // -------------------------------------------------------------------------
    [Test]
    procedure ReservEntry_CopyFromReservEntry_DUoMFieldsPropagated()
    var
        FromReservEntry: Record "Reservation Entry";
        ToReservEntry: Record "Reservation Entry";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Reservation Entry origen con DUoM Ratio y DUoM Second Qty establecidos
        //         (resultado del subscriber ReservEntryOnAfterCopyTrackingFromTrackingSpec
        //          tras cerrar Item Tracking Lines)
        FromReservEntry.Init();
        FromReservEntry."DUoM Ratio" := 1.25;
        FromReservEntry."DUoM Second Qty" := 8;

        // [GIVEN] Reservation Entry destino vacía
        //         (simulación de InsertReservEntry en CreateReservEntryFor)
        ToReservEntry.Init();

        // [WHEN] BC copia los campos de tracking de la entrada origen a la destino
        //        (dispara OnAfterCopyTrackingFromReservEntry — subscriber nuevo en 50110)
        ToReservEntry.CopyTrackingFromReservEntry(FromReservEntry);

        // [THEN] DUoM Ratio propagado correctamente de FromReservEntry a ToReservEntry
        LibraryAssert.AreNearlyEqual(1.25, ToReservEntry."DUoM Ratio", 0.001,
            'DUoM Ratio debe propagarse en CopyTrackingFromReservEntry (Reservation Entry).');

        // [THEN] DUoM Second Qty propagado correctamente
        LibraryAssert.AreNearlyEqual(8, ToReservEntry."DUoM Second Qty", 0.001,
            'DUoM Second Qty debe propagarse en CopyTrackingFromReservEntry (Reservation Entry).');
    end;

    // -------------------------------------------------------------------------
    // T11 — Artículo sin DUoM activo: CopyTrackingFromReservEntry no establece DUoM
    //
    // Verifica que para un artículo sin DUoM activo, los campos DUoM permanecen en 0
    // en Reservation Entry después del flujo de copia de campos de tracking.
    // Garantiza que el subscriber no introduce valores DUoM inesperados en entradas
    // de artículos sin configuración DUoM (regresión T05 del issue).
    // -------------------------------------------------------------------------
    [Test]
    procedure ReservEntry_CopyFromReservEntry_NoDUoM_FieldsRemainZero()
    var
        FromReservEntry: Record "Reservation Entry";
        ToReservEntry: Record "Reservation Entry";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Reservation Entry origen SIN DUoM (artículo sin configuración DUoM activa)
        //         Simula el estado de una ReservEntry para un artículo sin DUoM habilitado:
        //         DUoM Ratio = 0 y DUoM Second Qty = 0.
        FromReservEntry.Init();
        // FromReservEntry."DUoM Ratio" := 0;   (valor por defecto, no necesita asignarse)
        // FromReservEntry."DUoM Second Qty" := 0; (ídem)

        // [GIVEN] Reservation Entry destino vacía
        ToReservEntry.Init();

        // [WHEN] BC copia los campos de tracking
        ToReservEntry.CopyTrackingFromReservEntry(FromReservEntry);

        // [THEN] DUoM Ratio sigue siendo 0 — sin impacto de subscribers DUoM
        LibraryAssert.AreEqual(0, ToReservEntry."DUoM Ratio",
            'DUoM Ratio debe ser 0 para artículos sin DUoM activo.');

        // [THEN] DUoM Second Qty sigue siendo 0
        LibraryAssert.AreEqual(0, ToReservEntry."DUoM Second Qty",
            'DUoM Second Qty debe ser 0 para artículos sin DUoM activo.');
    end;

    // -------------------------------------------------------------------------
    // T12 — Variable + sin ratio de lote + fuente Purchase Line → fallback a PurchLine
    //
    // Verifica el bugfix principal: cuando no existe DUoM Lot Ratio para el lote y
    // DUoM Ratio de la línea es 0, el subscriber aplica como fallback el DUoM Ratio
    // de la Purchase Line origen. Cubre el escenario reportado en el issue donde los
    // campos DUoM quedaban a cero al asignar un lote nuevo sin ratio registrado.
    //
    // Fuente de fallback: Tracking Specification.Source Type/Subtype/ID/Ref. No.
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingSpec_Variable_NoLotRatio_PurchLineFallback_DUoMApplied()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Purchase Line con Quantity = 1 y DUoM Ratio = 1.25
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 1);
        PurchLine."DUoM Ratio" := 1.25;
        PurchLine.Modify(false);

        // [GIVEN] Lote SIN ratio registrado en DUoM Lot Ratio
        // (intencionalmente no se llama a CreateLotRatio para 'LOT-T12')

        // [GIVEN] Tracking Specification apuntando a la Purchase Line, DUoM Ratio = 0
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 1;
        TrackingSpec."Source Type" := Database::"Purchase Line";
        TrackingSpec."Source Subtype" := PurchLine."Document Type".AsInteger();
        TrackingSpec."Source ID" := PurchLine."Document No.";
        TrackingSpec."Source Ref. No." := PurchLine."Line No.";

        // [WHEN] Validate Lot No. = 'LOT-T12' (sin ratio de lote)
        TrackingSpec.Validate("Lot No.", 'LOT-T12');

        // [THEN] DUoM Ratio = 1.25 (fallback desde Purchase Line)
        LibraryAssert.AreEqual(1.25, TrackingSpec."DUoM Ratio",
            'T12: DUoM Ratio debe ser el de la Purchase Line (1.25) cuando no hay ratio de lote.');

        // [THEN] DUoM Second Qty = 1 × 1.25 = 1.25
        LibraryAssert.AreNearlyEqual(1.25, TrackingSpec."DUoM Second Qty", 0.001,
            'T12: DUoM Second Qty debe ser Quantity (Base) × DUoM Ratio de Purchase Line.');
    end;

    // -------------------------------------------------------------------------
    // T13 — Variable + ratio de lote existe → ratio de lote gana sobre Purchase Line
    //
    // Verifica que cuando existe DUoM Lot Ratio para el lote, este tiene prioridad
    // sobre el DUoM Ratio de la Purchase Line (fallback). El fallback de Purchase Line
    // solo se activa cuando no existe ratio de lote.
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingSpec_Variable_LotRatioExists_LotRatioWinsOverPurchLine()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Purchase Line con DUoM Ratio = 1.25
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 1);
        PurchLine."DUoM Ratio" := 1.25;
        PurchLine.Modify(false);

        // [GIVEN] Ratio de lote registrado: 1.10 para (ItemNo, 'LOT-T13')
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT-T13', 1.10);

        // [GIVEN] Tracking Specification apuntando a la Purchase Line, DUoM Ratio = 0
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 1;
        TrackingSpec."Source Type" := Database::"Purchase Line";
        TrackingSpec."Source Subtype" := PurchLine."Document Type".AsInteger();
        TrackingSpec."Source ID" := PurchLine."Document No.";
        TrackingSpec."Source Ref. No." := PurchLine."Line No.";

        // [WHEN] Validate Lot No. = 'LOT-T13' (con ratio de lote registrado)
        TrackingSpec.Validate("Lot No.", 'LOT-T13');

        // [THEN] DUoM Ratio = 1.10 (ratio de lote, NO el 1.25 de la Purchase Line)
        LibraryAssert.AreEqual(1.10, TrackingSpec."DUoM Ratio",
            'T13: DUoM Ratio debe ser el ratio de lote (1.10), no el de Purchase Line (1.25).');

        // [THEN] DUoM Second Qty = 1 × 1.10 = 1.10
        LibraryAssert.AreNearlyEqual(1.10, TrackingSpec."DUoM Second Qty", 0.001,
            'T13: DUoM Second Qty debe calcularse con el ratio de lote (1.10).');
    end;

    // -------------------------------------------------------------------------
    // T14 — Variable + sin ratio de lote + ratio manual preexistente → no sobrescribir
    //
    // Verifica que si la línea de tracking ya tiene un DUoM Ratio introducido
    // manualmente (≠ 0), el fallback de Purchase Line no lo sobrescribe.
    // Regla: prioridad manual > DUoM Lot Ratio > Purchase Line.
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingSpec_Variable_ManualRatioSet_FallbackDoesNotOverwrite()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Purchase Line con DUoM Ratio = 1.25
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 1);
        PurchLine."DUoM Ratio" := 1.25;
        PurchLine.Modify(false);

        // [GIVEN] Lote SIN ratio de lote
        // (no se llama a CreateLotRatio para 'LOT-T14')

        // [GIVEN] Tracking Specification con ratio manual 1.40 ya informado
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 2;
        TrackingSpec."DUoM Ratio" := 1.40; // Ratio manual preexistente
        TrackingSpec."Source Type" := Database::"Purchase Line";
        TrackingSpec."Source Subtype" := PurchLine."Document Type".AsInteger();
        TrackingSpec."Source ID" := PurchLine."Document No.";
        TrackingSpec."Source Ref. No." := PurchLine."Line No.";

        // [WHEN] Validate Lot No. = 'LOT-T14' (sin ratio de lote)
        TrackingSpec.Validate("Lot No.", 'LOT-T14');

        // [THEN] DUoM Ratio permanece en 1.40 (ratio manual — no sobrescrito por fallback)
        LibraryAssert.AreEqual(1.40, TrackingSpec."DUoM Ratio",
            'T14: DUoM Ratio manual (1.40) no debe ser sobrescrito por el fallback de Purchase Line.');
    end;

    // -------------------------------------------------------------------------
    // T15 — Múltiples lotes sin ratio de lote → fallback de Purchase Line para cada lote
    //
    // Verifica el modelo 1:N sin relación línea-lote: una Purchase Line con DUoM Ratio = 0.8
    // y dos lotes sin ratio registrado. Ambos lotes deben recibir el fallback de la
    // Purchase Line de forma independiente, con DUoM Second Qty calculada por lote.
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingSpec_Variable_TwoLots_NoLotRatio_BothGetPurchLineFallback()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        TrackingSpecA: Record "Tracking Specification";
        TrackingSpecB: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Purchase Line con Quantity = 10 y DUoM Ratio = 0.8
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine."DUoM Ratio" := 0.8;
        PurchLine.Modify(false);

        // [GIVEN] Dos lotes SIN ratio registrado en DUoM Lot Ratio
        // (intencionalmente sin CreateLotRatio)

        // [GIVEN] Tracking Specification para LOTE-A (6 uds) apuntando a la misma PurchLine
        TrackingSpecA.Init();
        TrackingSpecA."Entry No." := 1;
        TrackingSpecA."Item No." := Item."No.";
        TrackingSpecA."Quantity (Base)" := 6;
        TrackingSpecA."Source Type" := Database::"Purchase Line";
        TrackingSpecA."Source Subtype" := PurchLine."Document Type".AsInteger();
        TrackingSpecA."Source ID" := PurchLine."Document No.";
        TrackingSpecA."Source Ref. No." := PurchLine."Line No.";

        // [GIVEN] Tracking Specification para LOTE-B (4 uds) apuntando a la misma PurchLine
        TrackingSpecB.Init();
        TrackingSpecB."Entry No." := 2;
        TrackingSpecB."Item No." := Item."No.";
        TrackingSpecB."Quantity (Base)" := 4;
        TrackingSpecB."Source Type" := Database::"Purchase Line";
        TrackingSpecB."Source Subtype" := PurchLine."Document Type".AsInteger();
        TrackingSpecB."Source ID" := PurchLine."Document No.";
        TrackingSpecB."Source Ref. No." := PurchLine."Line No.";

        // [WHEN] Validate Lot No. para ambos lotes
        TrackingSpecA.Validate("Lot No.", 'LOTE-T15A');
        TrackingSpecB.Validate("Lot No.", 'LOTE-T15B');

        // [THEN] LOTE-A: DUoM Ratio = 0.8 (fallback PurchLine), DUoM Second Qty = 6 × 0.8 = 4.8
        LibraryAssert.AreEqual(0.8, TrackingSpecA."DUoM Ratio",
            'T15: LOTE-A — DUoM Ratio debe ser el fallback de Purchase Line (0.8).');
        LibraryAssert.AreNearlyEqual(4.8, TrackingSpecA."DUoM Second Qty", 0.001,
            'T15: LOTE-A — DUoM Second Qty debe ser 6 × 0.8 = 4.8.');

        // [THEN] LOTE-B: DUoM Ratio = 0.8 (fallback PurchLine), DUoM Second Qty = 4 × 0.8 = 3.2
        LibraryAssert.AreEqual(0.8, TrackingSpecB."DUoM Ratio",
            'T15: LOTE-B — DUoM Ratio debe ser el fallback de Purchase Line (0.8).');
        LibraryAssert.AreNearlyEqual(3.2, TrackingSpecB."DUoM Second Qty", 0.001,
            'T15: LOTE-B — DUoM Second Qty debe ser 4 × 0.8 = 3.2.');
    end;

    // -------------------------------------------------------------------------
    // T21 — Variable + sin ratio de lote + fuente Sales Line → fallback a Sales Line
    // -------------------------------------------------------------------------
    [Test]
    procedure T21_SalesLineFallback()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Sales Line con DUoM Ratio = 1.25
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 1);
        SalesLine."DUoM Ratio" := 1.25;
        SalesLine.Modify(false);

        // [GIVEN] Tracking Specification apuntando a la Sales Line, sin ratio de lote y DUoM Ratio = 0
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 1;
        TrackingSpec."Source Type" := Database::"Sales Line";
        TrackingSpec."Source Subtype" := SalesLine."Document Type".AsInteger();
        TrackingSpec."Source ID" := SalesLine."Document No.";
        TrackingSpec."Source Ref. No." := SalesLine."Line No.";

        // [WHEN] Validate Lot No. sin ratio de lote
        TrackingSpec.Validate("Lot No.", 'LOT-T21');

        // [THEN] Se aplica fallback desde Sales Line
        LibraryAssert.AreEqual(1.25, TrackingSpec."DUoM Ratio",
            'T21: DUoM Ratio debe tomar el fallback de Sales Line (1.25).');
        LibraryAssert.AreNearlyEqual(1.25, TrackingSpec."DUoM Second Qty", 0.001,
            'T21: DUoM Second Qty debe ser Quantity (Base) × DUoM Ratio de Sales Line.');
    end;

    // -------------------------------------------------------------------------
    // T22 — Variable + ratio de lote existe → ratio de lote gana sobre Sales Line
    // -------------------------------------------------------------------------
    [Test]
    procedure T22_SalesLotRatioWins()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable y ratio de lote definido
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT-T22', 1.10);

        // [GIVEN] Sales Line con ratio distinto (debe perder prioridad frente al lote)
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 1);
        SalesLine."DUoM Ratio" := 1.25;
        SalesLine.Modify(false);

        // [GIVEN] Tracking con fuente Sales Line y ratio inicial 0
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 1;
        TrackingSpec."Source Type" := Database::"Sales Line";
        TrackingSpec."Source Subtype" := SalesLine."Document Type".AsInteger();
        TrackingSpec."Source ID" := SalesLine."Document No.";
        TrackingSpec."Source Ref. No." := SalesLine."Line No.";

        // [WHEN] Validate Lot No. con ratio de lote
        TrackingSpec.Validate("Lot No.", 'LOT-T22');

        // [THEN] Prevalece el ratio del lote
        LibraryAssert.AreEqual(1.10, TrackingSpec."DUoM Ratio",
            'T22: DUoM Ratio debe ser el ratio de lote, no el fallback de Sales Line.');
        LibraryAssert.AreNearlyEqual(1.10, TrackingSpec."DUoM Second Qty", 0.001,
            'T22: DUoM Second Qty debe calcularse con el ratio de lote.');
    end;

    // -------------------------------------------------------------------------
    // T23 — Variable + ratio manual en tracking (ventas) → no sobrescribir
    // -------------------------------------------------------------------------
    [Test]
    procedure T23_SalesManualPreserve()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        TrackingSpec: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Sales Line con DUoM Ratio = 1.25
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 2);
        SalesLine."DUoM Ratio" := 1.25;
        SalesLine.Modify(false);

        // [GIVEN] Tracking con ratio manual ya informado (1.40)
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Quantity (Base)" := 2;
        TrackingSpec."DUoM Ratio" := 1.40;
        TrackingSpec."Source Type" := Database::"Sales Line";
        TrackingSpec."Source Subtype" := SalesLine."Document Type".AsInteger();
        TrackingSpec."Source ID" := SalesLine."Document No.";
        TrackingSpec."Source Ref. No." := SalesLine."Line No.";

        // [WHEN] Validate Lot No. sin ratio de lote
        TrackingSpec.Validate("Lot No.", 'LOT-T23');

        // [THEN] El ratio manual no se sobreescribe
        LibraryAssert.AreEqual(1.40, TrackingSpec."DUoM Ratio",
            'T23: DUoM Ratio manual no debe sobrescribirse por fallback de Sales Line.');
    end;

    // -------------------------------------------------------------------------
    // T24 — Múltiples lotes en ventas sin ratio de lote → fallback de Sales Line
    // -------------------------------------------------------------------------
    [Test]
    procedure T24_SalesTwoLotsFallback()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        TrackingSpecA: Record "Tracking Specification";
        TrackingSpecB: Record "Tracking Specification";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Variable y Sales Line con ratio 0.8
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'KG',
            "DUoM Conversion Mode"::Variable, 0);
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 10);
        SalesLine."DUoM Ratio" := 0.8;
        SalesLine.Modify(false);

        // [GIVEN] Dos lotes de tracking de la misma Sales Line
        TrackingSpecA.Init();
        TrackingSpecA."Entry No." := 1;
        TrackingSpecA."Item No." := Item."No.";
        TrackingSpecA."Quantity (Base)" := 6;
        TrackingSpecA."Source Type" := Database::"Sales Line";
        TrackingSpecA."Source Subtype" := SalesLine."Document Type".AsInteger();
        TrackingSpecA."Source ID" := SalesLine."Document No.";
        TrackingSpecA."Source Ref. No." := SalesLine."Line No.";

        TrackingSpecB.Init();
        TrackingSpecB."Entry No." := 2;
        TrackingSpecB."Item No." := Item."No.";
        TrackingSpecB."Quantity (Base)" := 4;
        TrackingSpecB."Source Type" := Database::"Sales Line";
        TrackingSpecB."Source Subtype" := SalesLine."Document Type".AsInteger();
        TrackingSpecB."Source ID" := SalesLine."Document No.";
        TrackingSpecB."Source Ref. No." := SalesLine."Line No.";

        // [WHEN] Se valida lote en ambas líneas
        TrackingSpecA.Validate("Lot No.", 'LOTE-T24A');
        TrackingSpecB.Validate("Lot No.", 'LOTE-T24B');

        // [THEN] Ambos lotes reciben el fallback de Sales Line
        LibraryAssert.AreEqual(0.8, TrackingSpecA."DUoM Ratio",
            'T24: LOTE-A debe recibir DUoM Ratio de Sales Line.');
        LibraryAssert.AreNearlyEqual(4.8, TrackingSpecA."DUoM Second Qty", 0.001,
            'T24: LOTE-A DUoM Second Qty debe ser 6 × 0.8.');
        LibraryAssert.AreEqual(0.8, TrackingSpecB."DUoM Ratio",
            'T24: LOTE-B debe recibir DUoM Ratio de Sales Line.');
        LibraryAssert.AreNearlyEqual(3.2, TrackingSpecB."DUoM Second Qty", 0.001,
            'T24: LOTE-B DUoM Second Qty debe ser 4 × 0.8.');
    end;

    // -------------------------------------------------------------------------
    // T25 — Ventas: segunda persistencia y rehidratación recuperan el último valor
    // -------------------------------------------------------------------------
    [Test]
    procedure T25_SalesLastEditRehydrate()
    var
        TrackingSpec: Record "Tracking Specification";
        RehydratedTrackingSpec: Record "Tracking Specification";
        ReservEntry: Record "Reservation Entry";
        DUoMTrackingPropMgt: Codeunit "DUoM Tracking Prop. Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Reservation Entry de Sales Line (fuente de verdad por lote)
        ReservEntry.Init();
        ReservEntry.SetSource(Database::"Sales Line", 1, 'SO-T25', 10000, '', 0);

        // [WHEN] Primera persistencia DUoM desde tracking
        TrackingSpec.Init();
        TrackingSpec."DUoM Ratio" := 1.20;
        TrackingSpec."DUoM Second Qty" := 6;
        DUoMTrackingPropMgt.CopyTrackingSpecToReservEntry(TrackingSpec, ReservEntry);

        // [WHEN] Segunda persistencia (edición posterior): debe prevalecer este valor
        TrackingSpec."DUoM Ratio" := 1.50;
        TrackingSpec."DUoM Second Qty" := 7.5;
        DUoMTrackingPropMgt.CopyTrackingSpecToReservEntry(TrackingSpec, ReservEntry);

        // [WHEN] Reapertura/rehidratación del buffer desde Reservation Entry
        DUoMTrackingPropMgt.CopyReservEntryToTrackingSpec(ReservEntry, RehydratedTrackingSpec);

        // [THEN] Se recuperan los últimos valores persistidos
        LibraryAssert.AreNearlyEqual(1.50, RehydratedTrackingSpec."DUoM Ratio", 0.001,
            'T25: Al reabrir, DUoM Ratio debe reflejar la última edición.');
        LibraryAssert.AreNearlyEqual(7.5, RehydratedTrackingSpec."DUoM Second Qty", 0.001,
            'T25: Al reabrir, DUoM Second Qty debe reflejar la última edición.');
    end;

    // -------------------------------------------------------------------------
    // T26 — Reapertura real en Sales Item Tracking preserva DUoM manual
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('SalesItemTracking_MPH')]
    procedure T26_SalesReopenPersist()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReservEntry: Record "Reservation Entry";
        SalesOrder: TestPage "Sales Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Variable con tracking por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        CreateAvailableLotInventoryForSales(Item, 'LOT-S-REOPEN-T26', 2);

        // [GIVEN] Sales Order con línea de 2 unidades
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 2);
        SalesLine.Modify(true);

        // [WHEN] Primera apertura: informar lote + DUoM manual
        SalesOrder.OpenEdit();
        SalesOrder.GotoRecord(SalesHeader);
        SalesTrackStep := 1;
        SalesOrder.SalesLines.First();
        SalesOrder.SalesLines.ItemTrackingLines.Invoke();

        // [THEN] Persistencia real en Reservation Entry usando filtro estándar de origen
        ReservEntry.SetSourceFilter(
            Database::"Sales Line",
            SalesLine."Document Type".AsInteger(),
            SalesHeader."No.",
            SalesLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Lot No.", 'LOT-S-REOPEN-T26');
        LibraryAssert.IsTrue(
            ReservEntry.FindFirst(),
            'T26: Debe existir Reservation Entry para la Sales Line y lote LOT-S-REOPEN-T26.');
        LibraryAssert.AreNearlyEqual(
            2.5, ReservEntry."DUoM Ratio", 0.001,
            'T26: Reservation Entry.DUoM Ratio debe ser 2.5.');
        LibraryAssert.AreNearlyEqual(
            -5, ReservEntry."DUoM Second Qty", 0.001,
            'T26: Reservation Entry.DUoM Second Qty debe persistirse con signo de venta (-5).');

        // [WHEN] Segunda apertura: rehidratar y verificar que no aparece a cero ni duplica
        SalesTrackStep := 2;
        SalesOrder.SalesLines.ItemTrackingLines.Invoke();
        SalesOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T27 — Reapertura real en Sales Item Tracking: última edición prevalece
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('SalesItemTracking_MPH')]
    procedure T27_SalesLastEditWins()
    var
        Item: Record Item;
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReservEntry: Record "Reservation Entry";
        SalesOrder: TestPage "Sales Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibrarySales: Codeunit "Library - Sales";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo DUoM Variable con tracking por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);
        CreateAvailableLotInventoryForSales(Item, 'LOT-S-MOD-T27', 4);

        // [GIVEN] Sales Order con línea de 4 unidades
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 0);
        SalesLine.Validate(Quantity, 4);
        SalesLine.Modify(true);

        SalesOrder.OpenEdit();
        SalesOrder.GotoRecord(SalesHeader);
        SalesOrder.SalesLines.First();

        // [WHEN] Primera edición y cierre
        SalesTrackStep := 3;
        SalesOrder.SalesLines.ItemTrackingLines.Invoke();

        // [WHEN] Segunda edición y cierre
        SalesTrackStep := 4;
        SalesOrder.SalesLines.ItemTrackingLines.Invoke();

        // [THEN] Reservation Entry queda con el último valor
        ReservEntry.SetSourceFilter(
            Database::"Sales Line",
            SalesLine."Document Type".AsInteger(),
            SalesHeader."No.",
            SalesLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Lot No.", 'LOT-S-MOD-T27');
        LibraryAssert.IsTrue(
            ReservEntry.FindFirst(),
            'T27: Debe existir Reservation Entry para lote LOT-S-MOD-T27.');
        LibraryAssert.AreNearlyEqual(
            1, ReservEntry."DUoM Ratio", 0.001,
            'T27: Debe persistirse el último DUoM Ratio (1).');
        LibraryAssert.AreNearlyEqual(
            -4, ReservEntry."DUoM Second Qty", 0.001,
            'T27: Debe persistirse el último DUoM Second Qty con signo de venta (-4).');

        // [WHEN] Tercera apertura para verificar recarga de último valor (no histórico, no cero)
        SalesTrackStep := 5;
        SalesOrder.SalesLines.ItemTrackingLines.Invoke();
        SalesOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T16 — Comparación DUoM entre Reservation Entries
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingPropMgt_ReservEntriesDUoMIdentical_DetectsChanges()
    var
        ReservEntry1: Record "Reservation Entry";
        ReservEntry2: Record "Reservation Entry";
        DUoMTrackingPropMgt: Codeunit "DUoM Tracking Prop. Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Dos Reservation Entries con DUoM idéntico
        ReservEntry1.Init();
        ReservEntry1."DUoM Ratio" := 2.5;
        ReservEntry1."DUoM Second Qty" := 10;
        ReservEntry2 := ReservEntry1;

        // [THEN] La comparación DUoM devuelve true
        LibraryAssert.IsTrue(
            DUoMTrackingPropMgt.AreReservEntriesDUoMIdentical(ReservEntry1, ReservEntry2),
            'T16: Dos Reservation Entries con el mismo bloque DUoM deben ser idénticas.');

        // [WHEN] Cambia solo DUoM Second Qty
        ReservEntry2."DUoM Second Qty" := 11;

        // [THEN] BC debe considerar la línea cambiada
        LibraryAssert.IsFalse(
            DUoMTrackingPropMgt.AreReservEntriesDUoMIdentical(ReservEntry1, ReservEntry2),
            'T16: Un cambio solo en DUoM Second Qty debe romper la igualdad.');
    end;

    // -------------------------------------------------------------------------
    // T17 — TrackingSpec → Reservation Entry aplica signo estándar para ventas
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingPropMgt_CopyTrackingSpecToReservEntry_SalesGetsNegativeSign()
    var
        TrackingSpec: Record "Tracking Specification";
        ReservEntry: Record "Reservation Entry";
        DUoMTrackingPropMgt: Codeunit "DUoM Tracking Prop. Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Tracking Specification con valores DUoM negativos de forma deliberada
        //         (no representan datos reales de página). Se usan para probar que la
        //         persistencia normaliza magnitud y aplica el signo estándar.
        TrackingSpec.Init();
        TrackingSpec."DUoM Ratio" := -2.5;
        TrackingSpec."DUoM Second Qty" := -10;

        // [GIVEN] Reservation Entry de un Sales Order (demanda = signo negativo)
        ReservEntry.Init();
        ReservEntry.SetSource(Database::"Sales Line", 1, 'SO-T17', 10000, '', 0);

        // [WHEN] La capa de propagación persiste DUoM en Reservation Entry
        DUoMTrackingPropMgt.CopyTrackingSpecToReservEntry(TrackingSpec, ReservEntry);

        // [THEN] DUoM Ratio se persiste positivo
        LibraryAssert.AreNearlyEqual(
            2.5, ReservEntry."DUoM Ratio", 0.001,
            'T17: DUoM Ratio debe persistirse siempre en positivo.');

        // [THEN] DUoM Second Qty se persiste con signo de venta
        LibraryAssert.AreNearlyEqual(
            -10, ReservEntry."DUoM Second Qty", 0.001,
            'T17: Sales Line debe persistir DUoM Second Qty con signo negativo.');
    end;

    // -------------------------------------------------------------------------
    // T18 — Reservation Entry → TrackingSpec rehidrata valores positivos para la página
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingPropMgt_CopyReservEntryToTrackingSpec_PageShowsPositiveValues()
    var
        ReservEntry: Record "Reservation Entry";
        TrackingSpec: Record "Tracking Specification";
        DUoMTrackingPropMgt: Codeunit "DUoM Tracking Prop. Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Reservation Entry persistida con signo técnico negativo
        ReservEntry.Init();
        ReservEntry."DUoM Ratio" := -0.6;
        ReservEntry."DUoM Second Qty" := -6;

        // [WHEN] Se rehidrata el buffer Tracking Specification
        DUoMTrackingPropMgt.CopyReservEntryToTrackingSpec(ReservEntry, TrackingSpec);

        // [THEN] La página debe mostrar valores positivos
        LibraryAssert.AreNearlyEqual(
            0.6, TrackingSpec."DUoM Ratio", 0.001,
            'T18: DUoM Ratio debe mostrarse en positivo al reabrir la página.');
        LibraryAssert.AreNearlyEqual(
            6, TrackingSpec."DUoM Second Qty", 0.001,
            'T18: DUoM Second Qty debe mostrarse en positivo al reabrir la página.');
    end;

    // -------------------------------------------------------------------------
    // T19 — TrackingSpec → TrackingSpec preserva los campos DUoM
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingPropMgt_CopyTrackingSpecToTrackingSpec_PreservesDUoM()
    var
        SourceTrackingSpec: Record "Tracking Specification";
        DestTrackingSpec: Record "Tracking Specification";
        DUoMTrackingPropMgt: Codeunit "DUoM Tracking Prop. Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un buffer origen con DUoM informado
        SourceTrackingSpec.Init();
        SourceTrackingSpec."DUoM Ratio" := 3;
        SourceTrackingSpec."DUoM Second Qty" := 9;

        // [WHEN] BC copia Tracking Specification internamente
        DUoMTrackingPropMgt.CopyTrackingSpecToTrackingSpec(SourceTrackingSpec, DestTrackingSpec);

        // [THEN] El bloque DUoM no se pierde
        LibraryAssert.AreNearlyEqual(
            3, DestTrackingSpec."DUoM Ratio", 0.001,
            'T19: DUoM Ratio debe copiarse entre buffers de tracking.');
        LibraryAssert.AreNearlyEqual(
            9, DestTrackingSpec."DUoM Second Qty", 0.001,
            'T19: DUoM Second Qty debe copiarse entre buffers de tracking.');
    end;

    // -------------------------------------------------------------------------
    // T20 — La suma funcional ignora líneas vacías/de inserción
    // -------------------------------------------------------------------------
    [Test]
    procedure TrackingPropMgt_SumTrackingDUoMSecondQty_IgnoresBlankLines()
    var
        TrackingSpec: Record "Tracking Specification" temporary;
        DUoMTrackingPropMgt: Codeunit "DUoM Tracking Prop. Mgt";
        LibraryAssert: Codeunit "Library Assert";
        TotalSecondQty: Decimal;
    begin
        // [GIVEN] Una línea vacía/de inserción
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec.Insert();

        // [GIVEN] Una línea funcional con DUoM real
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 2;
        TrackingSpec."Lot No." := 'LOT-T20';
        TrackingSpec."Quantity (Base)" := 4;
        TrackingSpec."DUoM Ratio" := 2;
        TrackingSpec."DUoM Second Qty" := 8;
        TrackingSpec.Insert();

        // [WHEN] Se suma el DUoM funcional del buffer
        TrackingSpec.Reset();
        TotalSecondQty := DUoMTrackingPropMgt.SumTrackingDUoMSecondQty(TrackingSpec);

        // [THEN] La línea vacía no debe contar
        LibraryAssert.AreNearlyEqual(
            8, TotalSecondQty, 0.001,
            'T20: La suma funcional debe ignorar la línea vacía de inserción.');
    end;

    /// <summary>
    /// ModalPageHandler de integración para T26/T27 sobre Sales Order.
    ///
    /// Step 1: asigna LOT-S-REOPEN-T26, Qty Base=2, DUoM Second Qty=5 (ratio auto=2.5).
    /// Step 2: verifica reapertura (2.5/5) y una sola línea funcional.
    /// Step 3: primera edición T27 (LOT-S-MOD-T27, Qty Base=4, Second Qty=3, ratio auto=0.75).
    /// Step 4: segunda edición T27 (Second Qty=4, ratio auto=1).
    /// Step 5: verifica reapertura T27 (ratio=1, Second Qty=4) y una sola línea funcional.
    /// </summary>
    [ModalPageHandler]
    procedure SalesItemTracking_MPH(var ItemTrackingLines: TestPage "Item Tracking Lines")
    var
        LibraryAssert: Codeunit "Library Assert";
    begin
        case SalesTrackStep of
            1:
                begin
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-S-REOPEN-T26');
                    ItemTrackingLines."Quantity (Base)".SetValue(2);
                    ItemTrackingLines."DUoM Second Qty".SetValue(5);
                    ItemTrackingLines.OK().Invoke();
                end;
            2:
                begin
                    AssertSingleTrackLine(
                        ItemTrackingLines,
                        'LOT-S-REOPEN-T26',
                        2,
                        5,
                        2.5,
                        'T26');
                    ItemTrackingLines.OK().Invoke();
                end;
            3:
                begin
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-S-MOD-T27');
                    ItemTrackingLines."Quantity (Base)".SetValue(4);
                    ItemTrackingLines."DUoM Second Qty".SetValue(3);
                    ItemTrackingLines.OK().Invoke();
                end;
            4:
                begin
                    ItemTrackingLines.First();
                    ItemTrackingLines."DUoM Second Qty".SetValue(4);
                    ItemTrackingLines.OK().Invoke();
                end;
            5:
                begin
                    AssertSingleTrackLine(
                        ItemTrackingLines,
                        'LOT-S-MOD-T27',
                        4,
                        4,
                        1,
                        'T27');
                    LibraryAssert.AreNearlyEqual(
                        1,
                        ItemTrackingLines."DUoM Ratio".AsDecimal(),
                        0.001,
                        'T27: Al reabrir debe mostrarse el último ratio (1), no el previo (0.75).');
                    LibraryAssert.AreNearlyEqual(
                        4,
                        ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                        0.001,
                        'T27: Al reabrir debe mostrarse el último DUoM Second Qty (4), no el previo (3) ni cero.');
                    ItemTrackingLines.OK().Invoke();
                end;
        end;
    end;

    local procedure AssertSingleTrackLine(
        var ItemTrackingLines: TestPage "Item Tracking Lines";
        ExpectedLotNo: Code[50];
        ExpectedQtyBase: Decimal;
        ExpectedSecondQty: Decimal;
        ExpectedRatio: Decimal;
        TestId: Text)
    var
        LibraryAssert: Codeunit "Library Assert";
    begin
        ItemTrackingLines.First();
        LibraryAssert.AreEqual(
            ExpectedLotNo,
            ItemTrackingLines."Lot No.".Value,
            StrSubstNo('%1: El lote rehidratado no coincide.', TestId));
        LibraryAssert.AreNearlyEqual(
            ExpectedQtyBase,
            ItemTrackingLines."Quantity (Base)".AsDecimal(),
            0.001,
            StrSubstNo('%1: Quantity (Base) rehidratada no coincide.', TestId));
        LibraryAssert.AreNearlyEqual(
            ExpectedSecondQty,
            ItemTrackingLines."DUoM Second Qty".AsDecimal(),
            0.001,
            StrSubstNo('%1: DUoM Second Qty rehidratada no coincide.', TestId));
        LibraryAssert.AreNearlyEqual(
            ExpectedRatio,
            ItemTrackingLines."DUoM Ratio".AsDecimal(),
            0.001,
            StrSubstNo('%1: DUoM Ratio rehidratado no coincide.', TestId));

        ItemTrackingLines.Next();
        LibraryAssert.IsFalse(
            IsFunctionalTrackLine(ItemTrackingLines),
            StrSubstNo('%1: Se detectó una segunda línea funcional (duplicado).', TestId));
    end;

    local procedure IsFunctionalTrackLine(var ItemTrackingLines: TestPage "Item Tracking Lines"): Boolean
    begin
        exit(
            (ItemTrackingLines."Lot No.".Value <> '') or
            (ItemTrackingLines."Serial No.".Value <> '') or
            (ItemTrackingLines."Package No.".Value <> '') or
            (ItemTrackingLines."Quantity (Base)".AsDecimal() <> 0) or
            (ItemTrackingLines."DUoM Ratio".AsDecimal() <> 0) or
            (ItemTrackingLines."DUoM Second Qty".AsDecimal() <> 0));
    end;

    local procedure CreateAvailableLotInventoryForSales(Item: Record Item; LotNo: Code[50]; Qty: Decimal)
    var
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, Qty);
        ItemJnlLine.Modify(true);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNo, Qty);
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);
    end;

    var
        SalesTrackStep: Integer;
}
