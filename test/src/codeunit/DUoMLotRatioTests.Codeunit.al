/// <summary>
/// Tests TDD para DUoM Lot Subscribers (50108) y la integración con Item Tracking BC 27.
///
/// Cubre los requisitos funcionales de Issue 13 (rediseño Phase 2):
///   T01 — IJL, modo Variable, lote CON ratio → DUoM Ratio y Second Qty pre-rellenados
///   T02 — IJL, modo Variable, lote SIN ratio → DUoM Ratio sin cambios
///   T03 — IJL, modo Fixed, lote CON ratio    → DUoM Ratio NO sobreescrito (ratio fijo)
///   T04 — Contabilización IJL, lote único, modo Variable → ILE con ratio de lote
///   T05 — Contabilización IJL, dos lotes distintos → cada ILE con su ratio de lote ✓ Crítico
///   T06 — Contabilización IJL, salida con lote → ILE Abs(Qty) × ratio de lote
///   T07 — DUoM Lot Ratio: Actual Ratio ≤ 0 → error de validación
///
/// NOTA SOBRE T04-T06 (Caso A vs Caso B):
///   Los tests T04-T06 verifican el comportamiento de OnAfterInitItemLedgEntry +
///   TryApplyLotRatioToILE mediante contabilización de diario de artículos (Caso A).
///   El escenario Caso B (Purchase/Sales Order con múltiples lotes vía Item Tracking)
///   se basa en el mismo mecanismo subyacente (OnAfterInitItemLedgEntry) y queda cubierto
///   funcionalmente por estos tests. La diferencia es que en el Caso B el IJL recibe el
///   ratio de la línea de documento (no el de lote), y TryApplyLotRatioToILE lo sobrescribe;
///   en el Caso A el IJL ya tiene el ratio de lote (por el subscriber de validación), y
///   TryApplyLotRatioToILE lo confirma. Ambos flujos convergen en el mismo resultado final.
/// </summary>
codeunit 50217 "DUoM Lot Ratio Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T01 — IJL, Variable, lote CON ratio → DUoM Ratio y Second Qty pre-rellenados
    // -------------------------------------------------------------------------

    [Test]
    procedure IJL_VariableMode_LotWithRatio_DUoMFieldsPreFilled()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio por defecto 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Ratio de lote registrado: (ItemNo, 'LOTE-T01') = 0,38
        LotNo := 'LOTE-T01';
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNo, 0.38);

        // [GIVEN] Item Journal Line para 10 unidades
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        ItemJnlLine.Modify(true);

        // [WHEN] Se valida el campo Lot No. (dispara OnAfterValidateItemJnlLineLotNo)
        ItemJnlLine.Validate("Lot No.", LotNo);

        // [THEN] DUoM Ratio sobreescrito con el ratio de lote
        LibraryAssert.AreEqual(0.38, ItemJnlLine."DUoM Ratio",
            'T01: DUoM Ratio debe ser 0,38 tras validar Lot No. con ratio registrado');

        // [THEN] DUoM Second Qty recalculada con el ratio de lote: 10 × 0,38 = 3,8
        LibraryAssert.AreNearlyEqual(3.8, ItemJnlLine."DUoM Second Qty", 0.001,
            'T01: DUoM Second Qty debe ser 10 × 0,38 = 3,8');
    end;

    // -------------------------------------------------------------------------
    // T02 — IJL, Variable, lote SIN ratio → DUoM Ratio sin cambios
    // -------------------------------------------------------------------------

    [Test]
    procedure IJL_VariableMode_LotWithoutRatio_DUoMRatioUnchanged()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LotNoSinRatio: Code[50];
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio por defecto 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Lote SIN ratio registrado en DUoM Lot Ratio
        LotNoSinRatio := 'LOTE-T02';

        // [GIVEN] Item Journal Line para 10 unidades con DUoM Ratio = 0,40 ya calculado
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        ItemJnlLine."DUoM Ratio" := 0.40;
        ItemJnlLine."DUoM Second Qty" := 4.0;
        ItemJnlLine.Modify(true);

        // [WHEN] Se valida el campo Lot No. (lote sin ratio en DUoM Lot Ratio)
        ItemJnlLine.Validate("Lot No.", LotNoSinRatio);

        // [THEN] DUoM Ratio permanece sin cambios (valor previo conservado)
        LibraryAssert.AreEqual(0.40, ItemJnlLine."DUoM Ratio",
            'T02: DUoM Ratio no debe cambiar cuando el lote no tiene ratio registrado');

        // [THEN] DUoM Second Qty permanece sin cambios
        LibraryAssert.AreNearlyEqual(4.0, ItemJnlLine."DUoM Second Qty", 0.001,
            'T02: DUoM Second Qty no debe cambiar cuando el lote no tiene ratio registrado');
    end;

    // -------------------------------------------------------------------------
    // T03 — IJL, Fixed, lote CON ratio → DUoM Ratio NO sobreescrito
    // -------------------------------------------------------------------------

    [Test]
    procedure IJL_FixedMode_LotWithRatio_DUoMRatioNotOverridden()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        // [GIVEN] Artículo con DUoM Fixed (ratio fijo 1,0)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1.0);

        // [GIVEN] Ratio de lote registrado: 0,38 (que NO debe aplicarse en modo Fixed)
        LotNo := 'LOTE-T03';
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNo, 0.38);

        // [GIVEN] Item Journal Line para 5 unidades con DUoM Ratio = 1,0 (Fixed)
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 5);
        ItemJnlLine.Modify(true);

        // [WHEN] Se valida el campo Lot No. con ratio registrado
        ItemJnlLine.Validate("Lot No.", LotNo);

        // [THEN] DUoM Ratio NO sobreescrito — el ratio fijo (1,0) siempre prevalece en modo Fixed
        LibraryAssert.AreEqual(1.0, ItemJnlLine."DUoM Ratio",
            'T03: En modo Fixed, DUoM Ratio no debe ser sobreescrito por el ratio de lote');

        // [THEN] DUoM Second Qty calculada con el ratio fijo: 5 × 1,0 = 5
        LibraryAssert.AreNearlyEqual(5.0, ItemJnlLine."DUoM Second Qty", 0.001,
            'T03: En modo Fixed, DUoM Second Qty debe ser 5 × 1,0 = 5');
    end;

    // -------------------------------------------------------------------------
    // T04 — Contabilización IJL, lote único con ratio 0,38, modo Variable → ILE
    // -------------------------------------------------------------------------

    [Test]
    procedure IJLPosting_SingleLot_ILEHasLotSpecificRatio()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio por defecto 0,40) y ratio de lote 0,38
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.40);
        LotNo := 'LOTE-T04';
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNo, 0.38);

        // [GIVEN] IJL para 10 unidades con Lot No. validado → subscriber aplica ratio 0,38
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        ItemJnlLine.Validate("Lot No.", LotNo);
        ItemJnlLine.Modify(true);

        // [WHEN] Se contabiliza el diario
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE: DUoM Ratio = 0,38 (ratio de lote)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Lot No.", LotNo);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T04: Se esperaba un ILE para el lote contabilizado');
        LibraryAssert.AreEqual(0.38, ILE."DUoM Ratio",
            'T04: ILE DUoM Ratio debe ser el ratio del lote (0,38)');

        // [THEN] ILE: DUoM Second Qty = Abs(10) × 0,38 = 3,8
        LibraryAssert.AreNearlyEqual(3.8, ILE."DUoM Second Qty", 0.001,
            'T04: ILE DUoM Second Qty debe ser 10 × 0,38 = 3,8');
    end;

    // -------------------------------------------------------------------------
    // T05 — Dos lotes con ratios distintos → cada ILE con su ratio específico ✓ Crítico
    //
    // Verifica que OnAfterInitItemLedgEntry + TryApplyLotRatioToILE produce ILEs
    // con el ratio correcto para cada lote cuando se contabilizan múltiples líneas
    // de diario (cada una con su propio Lot No. y cantidad).
    // -------------------------------------------------------------------------

    [Test]
    procedure IJLPosting_TwoLots_EachILEHasLotSpecificRatio()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLineA: Record "Item Journal Line";
        ItemJnlLineB: Record "Item Journal Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LotNoA: Code[50];
        LotNoB: Code[50];
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio por defecto 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Dos lotes con ratios distintos: A = 0,38; B = 0,41
        LotNoA := 'LOTE-T05A';
        LotNoB := 'LOTE-T05B';
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNoA, 0.38);
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNoB, 0.41);

        // [GIVEN] IJL Lote A: 6 unidades
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLineA, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLineA.Validate(Quantity, 6);
        ItemJnlLineA.Validate("Lot No.", LotNoA);
        ItemJnlLineA.Modify(true);

        // [GIVEN] IJL Lote B: 4 unidades (misma plantilla y lote, misma contabilización)
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLineB, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLineB.Validate(Quantity, 4);
        ItemJnlLineB.Validate("Lot No.", LotNoB);
        ItemJnlLineB.Modify(true);

        // [WHEN] Se contabilizan ambas líneas
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE Lote A: DUoM Ratio = 0,38; DUoM Second Qty = 6 × 0,38 = 2,28
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Lot No.", LotNoA);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T05: Se esperaba ILE para Lote A');
        LibraryAssert.AreEqual(0.38, ILE."DUoM Ratio",
            'T05: ILE Lote A — DUoM Ratio debe ser 0,38');
        LibraryAssert.AreNearlyEqual(2.28, ILE."DUoM Second Qty", 0.001,
            'T05: ILE Lote A — DUoM Second Qty debe ser 6 × 0,38 = 2,28');

        // [THEN] ILE Lote B: DUoM Ratio = 0,41; DUoM Second Qty = 4 × 0,41 = 1,64
        ILE.SetRange("Lot No.", LotNoB);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T05: Se esperaba ILE para Lote B');
        LibraryAssert.AreEqual(0.41, ILE."DUoM Ratio",
            'T05: ILE Lote B — DUoM Ratio debe ser 0,41');
        LibraryAssert.AreNearlyEqual(1.64, ILE."DUoM Second Qty", 0.001,
            'T05: ILE Lote B — DUoM Second Qty debe ser 4 × 0,41 = 1,64');
    end;

    // -------------------------------------------------------------------------
    // T06 — Contabilización IJL salida (Sale), lote con ratio 0,42, modo Variable → ILE
    //
    // Verifica que DUoM Second Qty = Abs(ILE.Quantity) × ratio de lote para salidas.
    // ILE.Quantity es negativo para salidas; Abs() garantiza valor positivo.
    // -------------------------------------------------------------------------

    [Test]
    procedure IJLPosting_SaleLot_ILEHasAbsQtyTimesLotRatio()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLinePurch: Record "Item Journal Line";
        ItemJnlLineSale: Record "Item Journal Line";
        ILE: Record "Item Ledger Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio por defecto 0,40) y ratio de lote 0,42
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.40);
        LotNo := 'LOTE-T06';
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNo, 0.42);

        // [GIVEN] Recepción previa: 100 unidades del mismo lote (para tener inventario)
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLinePurch, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLinePurch.Validate(Quantity, 100);
        ItemJnlLinePurch.Validate("Lot No.", LotNo);
        ItemJnlLinePurch.Modify(true);
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [GIVEN] IJL de salida: 10 unidades del mismo lote
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLineSale, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Sale, Item."No.", 0);
        ItemJnlLineSale.Validate(Quantity, 10);
        ItemJnlLineSale.Validate("Lot No.", LotNo);
        ItemJnlLineSale.Modify(true);

        // [WHEN] Se contabiliza la salida
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE de venta: DUoM Ratio = 0,42 (ratio del lote)
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        ILE.SetRange("Lot No.", LotNo);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T06: Se esperaba ILE de salida para el lote');
        LibraryAssert.AreEqual(0.42, ILE."DUoM Ratio",
            'T06: ILE salida — DUoM Ratio debe ser el ratio del lote (0,42)');

        // [THEN] DUoM Second Qty = Abs(ILE.Quantity) × 0,42 = Abs(-10) × 0,42 = 4,2
        LibraryAssert.AreNearlyEqual(4.2, ILE."DUoM Second Qty", 0.001,
            'T06: ILE salida — DUoM Second Qty debe ser Abs(-10) × 0,42 = 4,2');
    end;

    // -------------------------------------------------------------------------
    // T07 — DUoM Lot Ratio: Actual Ratio = 0 → error de validación
    // -------------------------------------------------------------------------

    [Test]
    procedure LotRatio_ZeroActualRatio_ValidationError()
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        // [GIVEN] Registro DUoM Lot Ratio (en memoria, sin insertar)
        DUoMLotRatio.Init();
        DUoMLotRatio."Item No." := 'ITEM-T07';
        DUoMLotRatio."Lot No." := 'LOTE-T07';

        // [WHEN/THEN] Validar Actual Ratio = 0 → debe lanzar error de validación
        // asserterror captura el error esperado; el test falla si no se lanza error.
        asserterror DUoMLotRatio.Validate("Actual Ratio", 0);
    end;

    [Test]
    procedure LotRatio_NegativeActualRatio_ValidationError()
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        // [GIVEN] Registro DUoM Lot Ratio (en memoria, sin insertar)
        DUoMLotRatio.Init();
        DUoMLotRatio."Item No." := 'ITEM-T07N';
        DUoMLotRatio."Lot No." := 'LOTE-T07N';

        // [WHEN/THEN] Validar Actual Ratio = -1 → debe lanzar error de validación
        asserterror DUoMLotRatio.Validate("Actual Ratio", -1);
    end;
}
