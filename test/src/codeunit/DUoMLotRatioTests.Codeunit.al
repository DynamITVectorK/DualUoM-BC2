/// <summary>
/// Tests TDD para DUoM Lot Subscribers (50108) y la integración con Item Tracking BC 27.
///
/// Cubre los requisitos funcionales de Issue 13 (rediseño Phase 2) e Issue 20 (multi-lote):
///   T01 — IJL, modo Variable, lote CON ratio → DUoM Ratio y Second Qty pre-rellenados
///   T02 — IJL, modo Variable, lote SIN ratio → DUoM Ratio sin cambios
///   T03 — IJL, modo Fixed, lote CON ratio    → DUoM Ratio NO sobreescrito (ratio fijo)
///   T04 — Contabilización IJL, lote único, modo Variable → ILE con ratio de lote
///   T05 — Contabilización IJL, dos líneas distintas con lotes distintos → cada ILE con su ratio
///   T06 — Contabilización IJL, salida con lote → ILE Abs(Qty) × ratio de lote
///   T07 — DUoM Lot Ratio: Actual Ratio ≤ 0 → error de validación
///   T08 — UNA línea IJL con DOS lotes vía Item Tracking → cada ILE con su ratio de lote ✓ Crítico
///          Escenario 1:N real: una línea origen = N asignaciones de lote = N ILEs
///   T09 — UNA línea IJL con DOS lotes vía Item Tracking → suma de DUoM Second Qty = total esperado
///   T10 — AlwaysVariable + multi-lote SIN ratio de lote → ILE DUoM Second Qty = 0 (no copia total)
///
/// MODELO 1:N — Línea origen como agregado (Issue 20):
///   Una línea de documento BC puede tener N asignaciones de lote vía Item Tracking.
///   Los campos DUoM de la línea origen son TOTALES AGREGADOS.
///   Cada ILE generado por lote debe tener su DUoM Second Qty y DUoM Ratio propios.
///   DUoM no puede asumir que 1 línea = 1 lote.
///
/// DIFERENCIA T05 vs T08:
///   T05 usa DOS líneas IJL separadas (una por lote) en el mismo batch → dos ILEs.
///        Verifica el comportamiento cuando cada lote viene en su propia línea de diario.
///   T08 usa UNA sola línea IJL con DOS lotes asignados vía Item Tracking (Reservation Entries).
///        Verifica el verdadero escenario 1:N de Business Central: una línea = N lotes.
///        Es el escenario que ocurre en Purchase/Sales Orders con Item Tracking.
///
/// NOTA SOBRE T04-T06 (Caso A vs Caso B):
///   Los tests T04-T06 verifican el comportamiento de OnAfterInitItemLedgEntry +
///   TryApplyLotRatioToILE mediante contabilización de diario de artículos (Caso A).
///   El seguimiento de lote se asigna mediante Reservation Entries (AssignLotToItemJnlLine),
///   que es el mecanismo estándar de BC 27 para ítems con "Lot Specific Tracking" activo.
///   El escenario Caso B (Purchase/Sales Order con múltiples lotes vía Item Tracking)
///   se basa en el mismo mecanismo subyacente (OnAfterInitItemLedgEntry) y queda cubierto
///   funcionalmente por estos tests. En ambos casos, TryApplyLotRatioToILE sobrescribe
///   el ratio del ILE con el ratio de lote específico registrado en DUoM Lot Ratio.
///   Ambos flujos convergen en el mismo resultado final.
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

        // [GIVEN] Item Tracking Code con seguimiento de lotes asignado al artículo.
        // Necesario para que BC 27 procese las Reservation Entries de lote al contabilizar
        // y para que TryApplyLotRatioToILE reciba el Lot No. correcto en el IJL interno.
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] IJL para 10 unidades; el seguimiento de lote se asigna vía Reservation Entry.
        // No se usa Validate("Lot No.") directo: con "Lot Specific Tracking" activo, BC 27
        // requiere Reservation Entry para que la contabilización sea válida.
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        ItemJnlLine.Modify(true);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNo, 10);

        // [WHEN] Se contabiliza el diario
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE: DUoM Ratio = 0,38 (ratio de lote)
        // Con Reservation Entry activa, BC popula ILE."Lot No." = LotNo al contabilizar;
        // la búsqueda por Item No. también es válida (único ILE del artículo).
        ILE.SetRange("Item No.", Item."No.");
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T04: Se esperaba un ILE para el artículo contabilizado');
        LibraryAssert.AreEqual(0.38, ILE."DUoM Ratio",
            'T04: ILE DUoM Ratio debe ser el ratio del lote (0,38)');

        // [THEN] ILE: DUoM Second Qty = Abs(10) × 0,38 = 3,8
        LibraryAssert.AreNearlyEqual(3.8, ILE."DUoM Second Qty", 0.001,
            'T04: ILE DUoM Second Qty debe ser 10 × 0,38 = 3,8');
    end;

    // -------------------------------------------------------------------------
    // T05 — Dos líneas IJL separadas con lotes distintos → cada ILE con su ratio
    //
    // Verifica que OnAfterInitItemLedgEntry + TryApplyLotRatioToILE produce ILEs
    // con el ratio correcto para cada lote cuando se contabilizan múltiples líneas
    // de diario (DOS LÍNEAS, cada una con su propio Lot No. y cantidad).
    //
    // NOTA: Este test usa DOS líneas IJL separadas (una por lote). Para el escenario
    // de UNA sola línea con dos lotes vía Item Tracking (el verdadero caso 1:N de BC),
    // ver T08 (IJLPosting_OneLine_TwoLotsTracking_EachILEHasLotRatio).
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

        // [GIVEN] Item Tracking Code con seguimiento de lotes asignado al artículo.
        // Necesario para que BC 27 procese las Reservation Entries de cada lote al
        // contabilizar y para que TryApplyLotRatioToILE aplique el ratio específico
        // de cada lote a su ILE.
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] IJL Lote A: 6 unidades; seguimiento de lote asignado vía Reservation Entry
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLineA, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLineA.Validate(Quantity, 6);
        ItemJnlLineA.Modify(true);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLineA, LotNoA, 6);

        // [GIVEN] IJL Lote B: 4 unidades (misma plantilla y lote, misma contabilización)
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLineB, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLineB.Validate(Quantity, 4);
        ItemJnlLineB.Modify(true);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLineB, LotNoB, 4);

        // [WHEN] Se contabilizan ambas líneas
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE Lote A: DUoM Ratio = 0,38; DUoM Second Qty = 6 × 0,38 = 2,28
        // Con Reservation Entries activas, BC popula ILE."Lot No." para cada lote.
        // Se identifica el ILE por la cantidad (6 uds para Lote A, 4 uds para Lote B).
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange(Quantity, 6);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T05: Se esperaba ILE para Lote A (6 uds)');
        LibraryAssert.AreEqual(0.38, ILE."DUoM Ratio",
            'T05: ILE Lote A — DUoM Ratio debe ser 0,38');
        LibraryAssert.AreNearlyEqual(2.28, ILE."DUoM Second Qty", 0.001,
            'T05: ILE Lote A — DUoM Second Qty debe ser 6 × 0,38 = 2,28');

        // [THEN] ILE Lote B: DUoM Ratio = 0,41; DUoM Second Qty = 4 × 0,41 = 1,64
        ILE.SetRange(Quantity, 4);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T05: Se esperaba ILE para Lote B (4 uds)');
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

        // [GIVEN] Item Tracking Code con seguimiento de lotes asignado al artículo.
        // Necesario para que BC 27 procese las Reservation Entries de lote al contabilizar
        // y para que TryApplyLotRatioToILE pueda aplicar el ratio de lote al ILE.
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Recepción previa: 100 unidades del mismo lote (para tener inventario)
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLinePurch, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLinePurch.Validate(Quantity, 100);
        ItemJnlLinePurch.Modify(true);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLinePurch, LotNo, 100);
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [GIVEN] IJL de salida: 10 unidades del mismo lote; trazabilidad vía Reservation Entry
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLineSale, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Sale, Item."No.", 0);
        ItemJnlLineSale.Validate(Quantity, 10);
        ItemJnlLineSale.Modify(true);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLineSale, LotNo, 10);

        // [WHEN] Se contabiliza la salida
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE de venta: DUoM Ratio = 0,42 (ratio del lote)
        // Con Reservation Entry activa, BC popula ILE."Lot No." = LotNo al contabilizar;
        // la búsqueda por Item No. + Entry Type identifica unívocamente la salida.
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T06: Se esperaba ILE de salida para el artículo');
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
    procedure LotRatioValidation_ZeroActualRatio_Error()
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
    procedure LotRatioValidation_NegativeActualRatio_Error()
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

    // -------------------------------------------------------------------------
    // T08 — UNA sola línea IJL con DOS lotes vía Item Tracking → cada ILE tiene
    //        su ratio de lote específico. ✓ Crítico — Modelo 1:N (Issue 20)
    //
    // Escenario real de Business Central: una única línea de diario de artículos
    // tiene DOS asignaciones de lote (via Reservation Entries), creadas con
    // AssignLotToItemJnlLine llamado dos veces sobre la MISMA línea.
    // Al contabilizar, BC crea un ILE por cada lote.
    // DUoM debe asignar el ratio de lote correcto a cada ILE de forma independiente.
    //
    // Diferencia clave con T05: T05 usa dos líneas IJL separadas (una por lote).
    // T08 usa UNA sola línea para 10 unidades, con 4 unidades asignadas a LOTE-T08A
    // y 6 unidades a LOTE-T08B. Este es el escenario 1:N real de BC.
    // -------------------------------------------------------------------------

    [Test]
    procedure IJLPosting_OneLine_TwoLotsTracking_EachILEHasLotRatio()
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
        // [GIVEN] Artículo con DUoM Variable (ratio por defecto 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Dos lotes con ratios distintos: A = 0,38 (4 uds); B = 0,41 (6 uds)
        LotNoA := 'LOTE-T08A';
        LotNoB := 'LOTE-T08B';
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNoA, 0.38);
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNoB, 0.41);

        // [GIVEN] Item Tracking Code con seguimiento de lotes asignado al artículo.
        // Necesario para que BC 27 procese las Reservation Entries de cada lote al
        // contabilizar y para que TryApplyLotRatioToILE aplique el ratio específico.
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] UNA sola línea IJL para 10 unidades (cantidad total/agregada)
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        ItemJnlLine.Modify(true);

        // [GIVEN] Asignar DOS lotes a la MISMA línea IJL mediante Item Tracking.
        // Este es el verdadero modelo 1:N de BC: 1 línea → N lotes.
        // LOTE-T08A: 4 unidades; LOTE-T08B: 6 unidades. Suma = 10 = total de la línea.
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNoA, 4);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNoB, 6);

        // [WHEN] Se contabiliza la única línea del batch
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE para LOTE-T08A: DUoM Ratio = 0,38; DUoM Second Qty = 4 × 0,38 = 1,52
        // La búsqueda por Lot No. identifica unívocamente el ILE de cada lote.
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Lot No.", LotNoA);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T08: Se esperaba ILE para LOTE-T08A');
        LibraryAssert.AreEqual(0.38, ILE."DUoM Ratio",
            'T08: ILE LOTE-T08A — DUoM Ratio debe ser el ratio de lote (0,38)');
        LibraryAssert.AreNearlyEqual(1.52, ILE."DUoM Second Qty", 0.001,
            'T08: ILE LOTE-T08A — DUoM Second Qty debe ser 4 × 0,38 = 1,52');

        // [THEN] ILE para LOTE-T08B: DUoM Ratio = 0,41; DUoM Second Qty = 6 × 0,41 = 2,46
        ILE.SetRange("Lot No.", LotNoB);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T08: Se esperaba ILE para LOTE-T08B');
        LibraryAssert.AreEqual(0.41, ILE."DUoM Ratio",
            'T08: ILE LOTE-T08B — DUoM Ratio debe ser el ratio de lote (0,41)');
        LibraryAssert.AreNearlyEqual(2.46, ILE."DUoM Second Qty", 0.001,
            'T08: ILE LOTE-T08B — DUoM Second Qty debe ser 6 × 0,41 = 2,46');
    end;

    // -------------------------------------------------------------------------
    // T09 — UNA línea IJL con DOS lotes → suma de DUoM Second Qty de todos los ILEs
    //        es coherente con el total esperado (1,52 + 2,46 = 3,98). Modelo 1:N.
    //
    // Verifica que el modelo 1:N es coherente: la suma de los valores DUoM a nivel
    // de lote/tracking (ILEs) refleja correctamente el total de la línea origen.
    // -------------------------------------------------------------------------

    [Test]
    procedure IJLPosting_OneLine_TwoLots_TotalDUoMEqualsSum()
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
        TotalDUoMSecondQty: Decimal;
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio por defecto 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Dos lotes: A = 0,38 (4 uds); B = 0,41 (6 uds)
        // Total esperado DUoM: 4 × 0,38 + 6 × 0,41 = 1,52 + 2,46 = 3,98
        LotNoA := 'LOTE-T09A';
        LotNoB := 'LOTE-T09B';
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNoA, 0.38);
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNoB, 0.41);

        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] UNA línea IJL para 10 unidades con dos lotes asignados
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        ItemJnlLine.Modify(true);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNoA, 4);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNoB, 6);

        // [WHEN] Se contabiliza
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] Suma de DUoM Second Qty de todos los ILEs del artículo = 3,98
        // El modelo 1:N garantiza que la suma de las cantidades DUoM por lote
        // es coherente con el total esperado (aunque no es el mismo que el del IJL origen,
        // ya que cada lote tiene su propio ratio específico).
        ILE.SetRange("Item No.", Item."No.");
        TotalDUoMSecondQty := 0;
        if ILE.FindSet() then
            repeat
                TotalDUoMSecondQty += ILE."DUoM Second Qty";
            until ILE.Next() = 0;
        LibraryAssert.AreNearlyEqual(3.98, TotalDUoMSecondQty, 0.001,
            'T09: Suma total DUoM Second Qty de ILEs debe ser 4×0,38 + 6×0,41 = 1,52 + 2,46 = 3,98');
    end;

    // -------------------------------------------------------------------------
    // T10 — AlwaysVariable + UNA línea IJL con DOS lotes SIN ratio de lote →
    //        ILE DUoM Second Qty = 0 (no se copia el total de la línea a cada ILE)
    //
    // Verifica que la corrección de Issue 20 funciona correctamente:
    // En modo AlwaysVariable sin ratio de lote, el total de DUoM Second Qty de la línea
    // origen NO puede distribuirse entre los lotes sin información adicional.
    // El ILE DUoM Second Qty queda en 0 en lugar de copiar incorrectamente el total.
    //
    // Comportamiento ANTERIOR (incorrecto): Cada ILE recibía DUoM Second Qty = 8 (el total).
    // Comportamiento CORRECTO (Issue 20): ILE DUoM Second Qty = 0 cuando Lot No. está asignado
    // pero DUoM Ratio = 0 y no existe ratio de lote en DUoM Lot Ratio.
    // -------------------------------------------------------------------------

    [Test]
    procedure IJLPosting_AlwaysVariable_TwoLots_NoLotRatio_ILESecondQtyIsZero()
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
        // [GIVEN] Artículo con DUoM AlwaysVariable (sin ratio por defecto, DUoM Ratio = 0)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);

        // [GIVEN] DOS lotes SIN ratio registrado en DUoM Lot Ratio
        // (el usuario no ha registrado ratios de lote para este artículo)
        LotNoA := 'LOTE-T10A';
        LotNoB := 'LOTE-T10B';

        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] UNA línea IJL para 10 unidades con DUoM Second Qty = 8 introducida manualmente
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        // En modo AlwaysVariable, el usuario introduce DUoM Second Qty = 8 (total de la línea)
        ItemJnlLine."DUoM Second Qty" := 8;
        ItemJnlLine.Modify(true);

        // [GIVEN] Dos lotes asignados a la misma línea (modelo 1:N): 4 uds LOTE-A + 6 uds LOTE-B
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNoA, 4);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNoB, 6);

        // [WHEN] Se contabiliza
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE para LOTE-T10A: DUoM Second Qty = 0
        // Con la corrección de Issue 20, el total de la línea (8) NO se copia a cada ILE
        // cuando hay Lot No. asignado y DUoM Ratio = 0 sin ratio de lote.
        // El valor incorrecto anterior (8 en cada ILE) queda eliminado.
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Lot No.", LotNoA);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T10: Se esperaba ILE para LOTE-T10A');
        LibraryAssert.AreEqual(0, ILE."DUoM Second Qty",
            'T10: ILE LOTE-T10A — DUoM Second Qty debe ser 0 (AlwaysVariable sin ratio de lote)');

        // [THEN] ILE para LOTE-T10B: DUoM Second Qty = 0
        ILE.SetRange("Lot No.", LotNoB);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T10: Se esperaba ILE para LOTE-T10B');
        LibraryAssert.AreEqual(0, ILE."DUoM Second Qty",
            'T10: ILE LOTE-T10B — DUoM Second Qty debe ser 0 (AlwaysVariable sin ratio de lote)');
    end;
}
