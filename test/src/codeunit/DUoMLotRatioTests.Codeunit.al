/// <summary>
/// Tests TDD para DUoM Lot Subscribers (50108) y la integración con Item Tracking BC 27.
///
/// ARQUITECTURA N:1 (Issue 21 — Refactorización):
///   DUoM no asume que 1 línea origen = 1 lote.
///   El subscriber OnAfterValidateEvent[Lot No.] en Item Journal Line ha sido ELIMINADO
///   porque asumía incorrectamente que 1 línea = 1 lote = 1 ratio DUoM.
///   La ratio real por lote se aplica vía el patrón OnAfterCopyTracking* (Issue 23):
///   Tracking Specification → IJL (OnAfterCopyTrackingFromSpec) →
///   ILE (OnAfterCopyTrackingFromItemJnlLine). Codeunit 50110.
///
/// Tests de posting (mecanismo productivo principal):
///   T04 — Contabilización IJL, lote único, modo Variable → ILE con ratio de lote
///   T05 — Contabilización IJL, dos líneas distintas con lotes distintos → cada ILE con su ratio
///   T06 — Contabilización IJL, salida con lote → ILE Abs(Qty) × ratio de lote
///   T07 — DUoM Lot Ratio: Actual Ratio ≤ 0 → error de validación
///   T08 — UNA línea IJL con DOS lotes vía Item Tracking → cada ILE con su ratio de lote ✓ Crítico
///          Escenario 1:N real: una línea origen = N asignaciones de lote = N ILEs
///   T09 — UNA línea IJL con DOS lotes vía Item Tracking → suma de DUoM Second Qty = total esperado
///   T10 — AlwaysVariable + multi-lote SIN ratio de lote → ILE DUoM Second Qty = 0 (no copia total)
///
/// Tests mecanismo OnAfterCopyTracking* sin pre-registro en DUoM Lot Ratio (Issue 23):
///   T13 — Variable + dos lotes sin pre-registro en 50102 → cada ILE proporcional al ratio del IJL
///          Verifica que ILECopyTrackingFromItemJnlLine calcula Abs(ILE.Qty) × IJL.DUoM Ratio
///          por lote sin necesitar TryApplyLotRatioToILE ni DUoM Lot Ratio (50102).
///   T14 — AlwaysVariable + lote único + ratio manual en IJL sin 50102 → ILE con ratio correcto
///          Verifica la rama DUoM Ratio ≠ 0 en ILECopyTrackingFromItemJnlLine.
///
/// Tests de regresión de diseño (verifican que Validate("Lot No.") NO modifica campos DUoM):
///   T02 — IJL, Variable, lote SIN ratio: Validate("Lot No.") no modifica DUoM Ratio
///   T03 — IJL, Fixed, lote CON ratio: Validate("Lot No.") no modifica DUoM Ratio (no hay subscriber)
///
/// Test unitario de bajo nivel (helper interno):
///   T12 — Llamada directa a ApplyLotRatioToItemJournalLine (helper de un único lote)
///         Verifica la lógica interna del helper en escenarios controlados.
///         "Lot No." := directo (no Validate) — solo válido para tests de helper, no para BC real.
///
/// ELIMINADOS (Issue 21 — premisa 1:1 inválida):
///   T01 — IJL, Variable, lote CON ratio → DUoM Ratio y Second Qty pre-rellenados
///          Eliminado: dependía del subscriber OnAfterValidateEvent[Lot No.] que asumía 1 línea = 1 lote.
///   T11 — IJL, Variable, lote CON ratio + precondiciones reforzadas
///          Eliminado: mismo problema arquitectónico que T01.
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
/// </summary>
codeunit 50217 "DUoM Lot Ratio Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T02 — IJL, Variable, lote SIN ratio → Validate("Lot No.") no cambia DUoM Ratio
    //
    // Test de regresión de diseño (Issue 21):
    // Verifica que, tras eliminar el subscriber OnAfterValidateEvent[Lot No.],
    // validar el número de lote en una IJL no interfiere con los campos DUoM.
    // El valor de DUoM Ratio establecido previamente (ratio por defecto) permanece
    // sin cambios, lo que es el comportamiento correcto para el modelo 1:N.
    // La ratio real por lote se aplica en posting a nivel de ILE (T04–T10).
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

        // [WHEN] Se valida el campo Lot No. — sin subscriber DUoM activo (eliminado en Issue 21)
        ItemJnlLine.Validate("Lot No.", LotNoSinRatio);

        // [THEN] DUoM Ratio permanece sin cambios (el subscriber fue eliminado en Issue 21)
        // La ratio real por lote se aplica en posting a nivel de ILE (ver T04–T10).
        LibraryAssert.AreEqual(0.40, ItemJnlLine."DUoM Ratio",
            'T02: DUoM Ratio no debe cambiar al validar Lot No. (subscriber eliminado, modelo 1:N)');

        // [THEN] DUoM Second Qty permanece sin cambios
        LibraryAssert.AreNearlyEqual(4.0, ItemJnlLine."DUoM Second Qty", 0.001,
            'T02: DUoM Second Qty no debe cambiar al validar Lot No. (subscriber eliminado, modelo 1:N)');
    end;

    // -------------------------------------------------------------------------
    // T03 — IJL, Fixed, lote CON ratio → Validate("Lot No.") no cambia DUoM Ratio
    //
    // Test de regresión de diseño (Issue 21):
    // Verifica que, en modo Fixed, validar el número de lote no interfiere con
    // los campos DUoM. El ratio fijo (1,0) permanece inalterado porque no hay
    // subscriber activo. En el flujo de posting, TryApplyLotRatioToILE tampoco
    // aplica el ratio de lote en modo Fixed (el ratio fijo siempre prevalece).
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

        // [WHEN] Se valida el campo Lot No. — sin subscriber DUoM activo (eliminado en Issue 21)
        ItemJnlLine.Validate("Lot No.", LotNo);

        // [THEN] DUoM Ratio NO sobreescrito — el ratio fijo (1,0) permanece inalterado
        // (subscriber eliminado; en posting, TryApplyLotRatioToILE tampoco aplica en modo Fixed)
        LibraryAssert.AreEqual(1.0, ItemJnlLine."DUoM Ratio",
            'T03: En modo Fixed, DUoM Ratio no debe cambiar al validar Lot No.');

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

    // -------------------------------------------------------------------------
    // T12 — Test unitario de bajo nivel: llamada directa a ApplyLotRatioToItemJournalLine
    //
    // CLASIFICACIÓN: test unitario de helper interno (no es un escenario BC de integración real).
    //
    // Verifica la lógica interna del helper ApplyLotRatioToItemJournalLine en un
    // escenario controlado de un único lote:
    //   - El helper busca en DUoM Lot Ratio(Item No., Lot No.) y aplica la ratio.
    //   - El resultado es correcto cuando se llama directamente sobre un IJL.
    //
    // NOTA sobre "Lot No." := LotNo (asignación directa, no Validate):
    //   Esta asignación directa es válida aquí porque el test verifica la lógica
    //   INTERNA del helper, no el flujo BC estándar de Item Tracking.
    //   En un flujo BC real con artículos de trazabilidad de lote, los lotes se
    //   asignan mediante Reservation Entries (ver T04–T10).
    //   Usar Validate("Lot No.") con trazabilidad activa puede borrar el campo si
    //   no existe Reservation Entry (comportamiento estándar de BC 27).
    //
    // El mecanismo productivo para aplicar ratios de lote es ILECopyTrackingFromItemJnlLine
    // en DUoM Tracking Copy Subscribers (50110) (ver T04–T10, T13–T14).
    // -------------------------------------------------------------------------

    [Test]
    procedure T12_VariableMode_DirectCall_ApplyLotRatioToItemJournalLine()
    var
        Item: Record Item;
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLine: Record "Item Journal Line";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        DUoMLotSubscribers: Codeunit "DUoM Lot Subscribers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LotNo: Code[50];
    begin
        // [GIVEN] Artículo con DUoM Variable (ratio por defecto 0,40)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0.40);

        // [GIVEN] Ratio de lote registrado: (ItemNo, 'LOTE-T12') = 0,38
        LotNo := 'LOTE-T12';
        DUoMTestHelpers.CreateLotRatio(Item."No.", LotNo, 0.38);

        // [GIVEN] Item Journal Line para 10 unidades con DUoM Ratio = 0,40 ya calculado
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        // Asignación directa (no Validate) — válido aquí porque se prueba el helper directamente,
        // no el flujo de Item Tracking estándar de BC. Ver comentario en la cabecera de T12.
        ItemJnlLine."Lot No." := LotNo;

        // [WHEN] Se llama directamente al helper ApplyLotRatioToItemJournalLine (sin evento BC)
        DUoMLotSubscribers.ApplyLotRatioToItemJournalLine(ItemJnlLine);

        // [THEN] El helper aplica la ratio real del lote registrada en DUoM Lot Ratio
        LibraryAssert.AreNearlyEqual(0.38, ItemJnlLine."DUoM Ratio", 0.00001,
            'T12: ApplyLotRatioToItemJournalLine debe aplicar la ratio del lote (0,38).');

        // [THEN] DUoM Second Qty recalculada con el ratio de lote: 10 × 0,38 = 3,8
        LibraryAssert.AreNearlyEqual(3.8, ItemJnlLine."DUoM Second Qty", 0.001,
            'T12: ApplyLotRatioToItemJournalLine debe recalcular DUoM Second Qty (10 × 0,38 = 3,8).');
    end;

    // -------------------------------------------------------------------------
    // T13 — Variable + DOS lotes sin pre-registro en DUoM Lot Ratio (50102)
    //        → cada ILE con DUoM Second Qty proporcional al ratio del IJL.
    //
    // Verifica que el mecanismo OnAfterCopyTracking* (Issue 23) calcula correctamente
    // Abs(ILE.Quantity) × IJL.DUoM Ratio para cada lote sin necesitar DUoM Lot Ratio (50102).
    //
    // El ratio del IJL proviene de OnAfterValidateItemJnlLineQty (ratio por defecto del artículo).
    // IJLCopyTrackingFromSpec no sobrescribe porque TrackingSpec.DUoM Ratio = 0 (sin 50102).
    // ILECopyTrackingFromItemJnlLine usa el ratio heredado del IJL original para cada split.
    // -------------------------------------------------------------------------

    [Test]
    procedure T13_TwoLots_NoLotRatioDB_ProportionalSecondQty()
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
        // [GIVEN] Artículo con DUoM Variable, ratio por defecto 1,5 — SIN registro en 50102 para ambos lotes
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 1.5);

        // [GIVEN] DOS lotes definidos solo en trazabilidad — Tabla 50102 vacía para ambos
        LotNoA := 'LOTE-T13A';
        LotNoB := 'LOTE-T13B';

        // [GIVEN] Item Tracking Code con seguimiento de lotes asignado al artículo
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] UNA línea IJL para 10 unidades
        // Validate(Quantity) → OnAfterValidateItemJnlLineQty → IJL.DUoM Ratio = 1,5
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);
        ItemJnlLine.Modify(true);

        // [GIVEN] Asignar DOS lotes a la MISMA línea: A = 6 uds; B = 4 uds (modelo 1:N)
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNoA, 6);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNoB, 4);

        // [WHEN] Se contabiliza
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE Lote A: DUoM Ratio = 1,5 (del IJL); DUoM Second Qty = 6 × 1,5 = 9,0
        // El nuevo mecanismo calcula Abs(ILE.Quantity) × IJL.DUoM Ratio (no copia el total).
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Lot No.", LotNoA);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T13: Se esperaba ILE para LOTE-T13A');
        LibraryAssert.AreEqual(1.5, ILE."DUoM Ratio",
            'T13: ILE LOTE-T13A — DUoM Ratio debe ser 1,5 (ratio del IJL, sin 50102)');
        LibraryAssert.AreNearlyEqual(9.0, ILE."DUoM Second Qty", 0.001,
            'T13: ILE LOTE-T13A — DUoM Second Qty debe ser 6 × 1,5 = 9,0');

        // [THEN] ILE Lote B: DUoM Ratio = 1,5; DUoM Second Qty = 4 × 1,5 = 6,0
        ILE.SetRange("Lot No.", LotNoB);
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T13: Se esperaba ILE para LOTE-T13B');
        LibraryAssert.AreEqual(1.5, ILE."DUoM Ratio",
            'T13: ILE LOTE-T13B — DUoM Ratio debe ser 1,5 (ratio del IJL, sin 50102)');
        LibraryAssert.AreNearlyEqual(6.0, ILE."DUoM Second Qty", 0.001,
            'T13: ILE LOTE-T13B — DUoM Second Qty debe ser 4 × 1,5 = 6,0');
    end;

    // -------------------------------------------------------------------------
    // T14 — AlwaysVariable + lote único + ratio manual en IJL (sin 50102)
    //        → ILE con DUoM Ratio = ratio manual; DUoM Second Qty = Abs(Qty) × ratio.
    //
    // Verifica que ILECopyTrackingFromItemJnlLine (Issue 23) propaga correctamente
    // un DUoM Ratio introducido manualmente en el IJL para AlwaysVariable cuando:
    //   - No existe registro en DUoM Lot Ratio (50102)
    //   - El ratio viene directamente del campo DUoM Ratio del IJL (asignación directa)
    //
    // Simula el escenario donde el usuario introduce DUoM Ratio = 2,5 directamente
    // en el formulario de diario (o en Item Tracking Lines) para un lote nuevo.
    // -------------------------------------------------------------------------

    [Test]
    procedure T14_AlwaysVar_ManualRatioOnIJL_ILEHasRatio()
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
        // [GIVEN] Artículo con DUoM AlwaysVariable — SIN ratio por defecto, SIN registro en 50102
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);

        // [GIVEN] Lote único sin ratio pre-registrado en DUoM Lot Ratio (50102)
        LotNo := 'LOTE-T14';

        // [GIVEN] Item Tracking Code con seguimiento de lotes
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] IJL para 10 unidades; AlwaysVariable → OnAfterValidateItemJnlLineQty no actúa
        LibraryInventory.CreateItemJournalTemplate(ItemJnlTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJnlBatch, ItemJnlTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJnlLine, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name,
            "Item Ledger Entry Type"::Purchase, Item."No.", 0);
        ItemJnlLine.Validate(Quantity, 10);

        // [GIVEN] El usuario introduce manualmente DUoM Ratio = 2,5 en el IJL
        // (simula la entrada directa en el formulario de diario o en Item Tracking Lines)
        ItemJnlLine."DUoM Ratio" := 2.5;
        ItemJnlLine."DUoM Second Qty" := 25; // 10 × 2,5
        ItemJnlLine.Modify(true);
        DUoMTestHelpers.AssignLotToItemJnlLine(ItemJnlLine, LotNo, 10);

        // [WHEN] Se contabiliza
        LibraryInventory.PostItemJournalLine(ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);

        // [THEN] ILE: DUoM Ratio = 2,5 (propagado desde IJL por ILECopyTrackingFromItemJnlLine)
        ILE.SetRange("Item No.", Item."No.");
        LibraryAssert.IsTrue(ILE.FindFirst(), 'T14: Se esperaba un ILE para el artículo contabilizado');
        LibraryAssert.AreEqual(2.5, ILE."DUoM Ratio",
            'T14: ILE — DUoM Ratio debe ser 2,5 (ratio manual del IJL, sin 50102)');

        // [THEN] ILE: DUoM Second Qty = Abs(10) × 2,5 = 25
        // ILECopyTrackingFromItemJnlLine calcula Abs(ILE.Quantity) × DUoM Ratio (no copia el total del IJL).
        LibraryAssert.AreNearlyEqual(25.0, ILE."DUoM Second Qty", 0.001,
            'T14: ILE — DUoM Second Qty debe ser Abs(10) × 2,5 = 25');
    end;
}

