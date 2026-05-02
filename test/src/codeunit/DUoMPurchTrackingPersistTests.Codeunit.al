/// <summary>
/// Tests de regresión e integración para la persistencia y propagación de campos DUoM
/// en el flujo de Item Tracking Lines (Purchase Order con seguimiento por lote).
///
/// Escenarios cubiertos:
///   T-PERSIST-01: AlwaysVariable — cerrar/reabrir Item Tracking Lines conserva DUoM
///   T-PERSIST-02: AlwaysVariable — contabilizar PO con tracking → ILE tiene DUoM Ratio
///   T-PERSIST-03: Variable — asignar lote con ratio registrado auto-asigna DUoM Ratio
///                 (= ItemTracking_ModifyLotRatio_UpdatesReservEntry, T04 del issue)
///   T-PERSIST-04: Sin DUoM — Item Tracking Lines no introduce DUoM en ReservEntry
///                 (= ItemTracking_NoImpactOnItemsWithoutDUoM, T05 del issue)
///   T-PERSIST-05: Variable — asignar lote SIN ratio, fallback desde Purchase Line →
///                 ReservEntry queda con DUoM Ratio de PurchLine; cerrar/reabrir conserva
///
/// Arquitectura cubierta:
///   - Persistencia al cerrar: TrackingSpec buffer → ReservEntry1 (CopyTrackingFromSpec)
///     → InsertReservEntry (CopyTrackingFromReservEntry) → BD
///     vía OnAfterCopyTrackingFromTrackingSpec y OnAfterCopyTrackingFromReservEntry (50110)
///   - Recarga al reabrir: Reservation Entry → TrackingSpec buffer
///     vía OnAfterCopyTrackingFromReservEntry en Table "Tracking Specification" (50110)
///
/// Nombres verificados contra convenciones estándar BC 27:
///   - TestPage "Purchase Order": subpágina PurchLines, acción "Item Tracking Lines"
///   - ModalPageHandler: TestPage "Item Tracking Lines"
///   - Campos en Item Tracking Lines: "Lot No.", "Quantity (Base)",
///     "DUoM Ratio", "DUoM Second Qty"
/// </summary>
codeunit 50219 "DUoM Purch Tracking Persist"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T-PERSIST-01 — Persistencia DUoM al cerrar/reabrir Item Tracking Lines
    //
    // Verifica que los valores DUoM (DUoM Ratio y DUoM Second Qty) introducidos
    // manualmente en Item Tracking Lines desde un pedido de compra con artículo
    // en modo AlwaysVariable + seguimiento por lote se persisten correctamente
    // en Reservation Entry y se recargan al reabrir la página.
    //
    // Valores de referencia:
    //   Artículo: DUoM AlwaysVariable, seguimiento por lote habilitado
    //   Cantidad base: 10
    //   Lote: LOT-DUOM-001
    //   DUoM Ratio: 0.8 (= 8 / 10; introducido manualmente; no recalcula en AlwaysVariable)
    //   DUoM Second Qty: 8 (introducido manualmente e independiente)
    //
    // Primera apertura (HandlerStep = 1):
    //   - Introduce Lot No. = 'LOT-DUOM-001', Qty = 10
    //   - Introduce DUoM Ratio = 0.8 y DUoM Second Qty = 8
    //   - Acepta con OK
    //
    // Validación de persistencia en BD:
    //   - Reservation Entry vinculada a la Purchase Line con:
    //       Lot No. = 'LOT-DUOM-001'
    //       DUoM Ratio = 0.8
    //       DUoM Second Qty = 8
    //
    // Segunda apertura (HandlerStep = 2):
    //   - Verifica que Lot No., DUoM Ratio y DUoM Second Qty se recargan
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLine_ItemTracking_DUoMValuesPersistAfterCloseAndReopen()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM activo en modo AlwaysVariable y seguimiento por lote
        //         AlwaysVariable: DUoM Ratio no recalcula DUoM Second Qty automáticamente
        //         en el trigger de tabla, el usuario introduce ambos valores de forma
        //         independiente en cada línea de tracking.
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con una línea de 10 unidades del artículo
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] El usuario abre el pedido de compra en la TestPage
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);

        // [WHEN] Primera apertura de Item Tracking Lines: el usuario introduce
        //        lote, cantidad y valores DUoM (HandlerStep = 1)
        HandlerStep := 1;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [THEN] Los valores DUoM quedan persistidos en Reservation Entry
        //        vinculada a la línea de compra y al lote LOT-DUOM-001
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source ID", PurchHeader."No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange("Lot No.", 'LOT-DUOM-001');
        LibraryAssert.IsTrue(
            ReservEntry.FindFirst(),
            'Debe existir una Reservation Entry vinculada a la línea de compra y lote LOT-DUOM-001.');
        LibraryAssert.AreNearlyEqual(
            0.8, ReservEntry."DUoM Ratio", 0.001,
            'DUoM Ratio debe ser 0.8 en Reservation Entry tras cerrar Item Tracking Lines.');
        LibraryAssert.AreNearlyEqual(
            8, ReservEntry."DUoM Second Qty", 0.001,
            'DUoM Second Qty debe ser 8 en Reservation Entry tras cerrar Item Tracking Lines.');

        // [WHEN] Segunda apertura de Item Tracking Lines: el usuario vuelve a abrir
        //        la página para verificar que los valores DUoM siguen presentes (HandlerStep = 2)
        HandlerStep := 2;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-PERSIST-02 (= T02 del issue)
    // PurchLine_ItemTracking_DUoMRatioPropagatedToILEOnPost
    //
    // Verifica el flujo E2E completo desde Item Tracking Lines hasta el ILE:
    //   Item Tracking Lines → ReservEntry (vía nuestro fix en 50110)
    //   → TrackingSpec buffer → Item Journal Line → Item Ledger Entry
    //
    // Este test es el único que valida la CADENA COMPLETA comenzando desde la UI
    // (no desde AssignLotWithDUoMRatioToPurchLine que crea la ReservEntry directamente).
    // Complementa los TEST 4/5 de DUoMILEIntegrationTests que usan el helper directo.
    //
    // Valores de referencia:
    //   Artículo: DUoM AlwaysVariable, seguimiento por lote habilitado
    //   Lote: LOT-DUOM-001 · DUoM Ratio = 0.8 (= 8 / 10; introducido manualmente en T-PERSIST-01)
    //   Tras contabilizar: ILE.DUoM Ratio = 0.8 · ILE.DUoM Second Qty = 8
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLine_ItemTracking_DUoMRatioPropagatedToILEOnPost()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ILE: Record "Item Ledger Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM activo en modo AlwaysVariable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con una línea de 10 unidades del artículo
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] El usuario abre el pedido de compra y asigna lote + DUoM Ratio = 0.8
        //        (HandlerStep = 1: introduce lote, DUoM Ratio = 0.8, DUoM Second Qty = 8)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 1;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [WHEN] Se contabiliza el pedido de compra (recepción)
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] ILE creado con DUoM Ratio = 0.8 y DUoM Second Qty = 8
        //        La cadena ReservEntry → TrackingSpec → IJL → ILE propaga el ratio
        //        gracias al subscriber ReservEntryOnAfterCopyTrackingFromReservEntry (50110)
        //        que completa el eslabón faltante en el flujo INSERT de Item Tracking Lines.
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange("Lot No.", 'LOT-DUOM-001');
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T02: Debe existir un ILE de compra para el lote LOT-DUOM-001.');
        LibraryAssert.AreNearlyEqual(
            0.8, ILE."DUoM Ratio", 0.001,
            'T02: ILE.DUoM Ratio debe ser 0.8 tras contabilizar el pedido de compra con tracking.');
        LibraryAssert.AreNearlyEqual(
            8, ILE."DUoM Second Qty", 0.001,
            'T02: ILE.DUoM Second Qty = 8 (propagado desde Item Tracking Lines).');
    end;

    // -------------------------------------------------------------------------
    // T-PERSIST-03 (= T04 del issue: ItemTracking_ModifyLotRatio_UpdatesReservEntry)
    //
    // Verifica que al asignar un lote con ratio registrado en DUoM Lot Ratio (50102)
    // en modo Variable, el ratio de lote se propaga automáticamente al buffer de
    // Tracking Specification (vía OnAfterValidateTrackingSpecLotNo en 50109) y
    // de ahí a Reservation Entry (vía ReservEntryOnAfterCopyTrackingFromReservEntry en 50110).
    //
    // "Modificar el ratio": el lote tiene registrado un ratio = 1.5 distinto del ratio
    // por defecto (0) del artículo. El subscriber aplica ("modifica") ese ratio al
    // asignar el lote en Item Tracking Lines.
    //
    // Valores de referencia:
    //   Artículo: DUoM Variable, sin ratio fijo
    //   Lote: LOT-PERSIST03 · ratio registrado en DUoM Lot Ratio = 1.5
    //   Cantidad: 8
    //   Tras cerrar: ReservEntry.DUoM Ratio = 1.5 · DUoM Second Qty = 8 × 1.5 = 12
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure ItemTracking_ModifyLotRatio_UpdatesReservEntry()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable (sin ratio fijo) y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'KG', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Ratio de lote registrado: 1.5 para (Item."No.", 'LOT-PERSIST03')
        DUoMTestHelpers.CreateLotRatio(Item."No.", 'LOT-PERSIST03', 1.5);

        // [GIVEN] Pedido de compra con una línea de 8 unidades del artículo
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 8);
        PurchLine.Modify(true);

        // [WHEN] El usuario abre Item Tracking Lines y asigna el lote LOT-PERSIST03
        //        (HandlerStep = 3: introduce lote; el subscriber auto-asigna DUoM Ratio = 1.5)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 3;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] ReservEntry tiene DUoM Ratio = 1.5 (ratio de lote auto-asignado)
        //        y DUoM Second Qty = 8 × 1.5 = 12
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source ID", PurchHeader."No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange("Lot No.", 'LOT-PERSIST03');
        LibraryAssert.IsTrue(ReservEntry.FindFirst(),
            'T04: Debe existir una Reservation Entry para el lote LOT-PERSIST03.');
        LibraryAssert.AreNearlyEqual(
            1.5, ReservEntry."DUoM Ratio", 0.001,
            'T04: DUoM Ratio debe ser 1.5 (ratio del lote auto-asignado por el subscriber).');
        LibraryAssert.AreNearlyEqual(
            12, ReservEntry."DUoM Second Qty", 0.001,
            'T04: DUoM Second Qty debe ser 8 × 1.5 = 12.');
    end;

    // -------------------------------------------------------------------------
    // T-PERSIST-04 (= T05 del issue: ItemTracking_NoImpactOnItemsWithoutDUoM)
    //
    // Verifica que para un artículo SIN DUoM activo, el flujo estándar de Item
    // Tracking Lines no introduce valores DUoM en Reservation Entry.
    // Los campos DUoM deben ser 0 en ReservEntry tras cerrar Item Tracking Lines.
    //
    // Garantía de no regresión: los subscribers DUoM no deben interferir con
    // artículos que no tienen configuración DUoM habilitada.
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure ItemTracking_NoImpactOnItemsWithoutDUoM()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo SIN DUoM activo pero CON seguimiento por lote
        //         (sin llamada a CreateItemSetup → DUoM Item Setup no existe)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con una línea de 5 unidades del artículo
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Modify(true);

        // [WHEN] El usuario abre Item Tracking Lines y asigna un lote
        //        (HandlerStep = 4: introduce lote LOT-T05, qty = 5; sin DUoM)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 4;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] ReservEntry existe pero con DUoM Ratio = 0 y DUoM Second Qty = 0
        //        Los subscribers DUoM no interfieren con artículos sin DUoM configurado
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source ID", PurchHeader."No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange("Lot No.", 'LOT-T05');
        LibraryAssert.IsTrue(ReservEntry.FindFirst(),
            'T05: Debe existir una Reservation Entry para el lote LOT-T05.');
        LibraryAssert.AreEqual(
            0, ReservEntry."DUoM Ratio",
            'T05: DUoM Ratio debe ser 0 para artículos sin DUoM activo.');
        LibraryAssert.AreEqual(
            0, ReservEntry."DUoM Second Qty",
            'T05: DUoM Second Qty debe ser 0 para artículos sin DUoM activo.');
    end;

    // -------------------------------------------------------------------------
    // T-PERSIST-05 — Fallback desde Purchase Line: ReservEntry persiste y se recarga
    //
    // Verifica el bugfix del issue: cuando no existe DUoM Lot Ratio para el lote,
    // el subscriber OnAfterValidateTrackingSpecLotNo (50109) aplica el DUoM Ratio
    // de la Purchase Line origen como fallback. Verifica que:
    //   1. Tras cerrar Item Tracking Lines: ReservEntry.DUoM Ratio = PurchLine.DUoM Ratio
    //   2. Al reabrir Item Tracking Lines: los valores DUoM se recuperan desde ReservEntry
    //
    // Valores de referencia:
    //   Artículo: DUoM Variable, sin ratio fijo
    //   Purchase Line: Quantity = 1, DUoM Ratio = 1.25
    //   Lote: LOT-FALLBACK01 · sin DUoM Lot Ratio registrado
    //   Tras cerrar: ReservEntry.DUoM Ratio = 1.25 · DUoM Second Qty = 1 × 1.25 = 1.25
    //   Al reabrir: mismos valores visibles en Item Tracking Lines
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure ItemTracking_PurchLineFallback_DUoMAppliedAndPersisted()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable (sin ratio fijo) y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'KG', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con una línea de 1 unidad y DUoM Ratio = 1.25
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 1);
        PurchLine."DUoM Ratio" := 1.25;
        PurchLine.Modify(false);

        // [GIVEN] Lote LOT-FALLBACK01 SIN ratio registrado en DUoM Lot Ratio
        // (intencionalmente sin CreateLotRatio)

        // [WHEN] Primera apertura de Item Tracking Lines: asignar lote y cantidad
        //        (HandlerStep = 5: introduce LOT-FALLBACK01 y qty=1;
        //         el subscriber auto-asigna DUoM Ratio = 1.25 desde Purchase Line)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 5;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] ReservEntry tiene DUoM Ratio = 1.25 (fallback desde Purchase Line)
        //        y DUoM Second Qty = 1 × 1.25 = 1.25
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source ID", PurchHeader."No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange("Lot No.", 'LOT-FALLBACK01');
        LibraryAssert.IsTrue(ReservEntry.FindFirst(),
            'T-P05: Debe existir una Reservation Entry para LOT-FALLBACK01.');
        LibraryAssert.AreNearlyEqual(
            1.25, ReservEntry."DUoM Ratio", 0.001,
            'T-P05: DUoM Ratio debe ser 1.25 (fallback desde Purchase Line).');
        LibraryAssert.AreNearlyEqual(
            1.25, ReservEntry."DUoM Second Qty", 0.001,
            'T-P05: DUoM Second Qty debe ser 1 × 1.25 = 1.25.');

        // [WHEN] Segunda apertura de Item Tracking Lines: verificar recarga desde ReservEntry
        //        (HandlerStep = 6: verifica que DUoM Ratio = 1.25 y DUoM Second Qty = 1.25)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 6;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();
    end;

    /// <summary>
    /// ModalPageHandler para Item Tracking Lines — usado en seis pasos:
    ///
    ///   HandlerStep = 1: simula que el usuario introduce lote y valores DUoM manualmente.
    ///                    Lote: LOT-DUOM-001 · DUoM Ratio = 0.8 (= 8/10) · DUoM Second Qty = 8
    ///                    Modo AlwaysVariable: DUoM Ratio no recalcula DUoM Second Qty.
    ///   HandlerStep = 2: verifica que los valores DUoM se han recargado correctamente
    ///                    desde Reservation Entry al reabrir la página.
    ///   HandlerStep = 3: asigna lote LOT-PERSIST03 (ratio 1.5 registrado en DUoM Lot Ratio).
    ///                    El subscriber OnAfterValidateTrackingSpecLotNo (50109) auto-asigna
    ///                    DUoM Ratio = 1.5 al validar el lote. Modo Variable.
    ///   HandlerStep = 4: asigna lote LOT-T05 sin valores DUoM (artículo sin DUoM activo).
    ///                    DUoM Ratio y DUoM Second Qty deben ser 0.
    ///   HandlerStep = 5: asigna lote LOT-FALLBACK01 (sin DUoM Lot Ratio). El subscriber
    ///                    aplica fallback desde Purchase Line: DUoM Ratio = 1.25.
    ///                    Modo Variable. DUoM Second Qty = 1 × 1.25 = 1.25.
    ///   HandlerStep = 6: verifica recarga de DUoM Ratio = 1.25 y DUoM Second Qty = 1.25
    ///                    al reabrir Item Tracking Lines (desde Reservation Entry).
    ///
    /// DUoM Ratio = 0.8 en modo AlwaysVariable: el trigger OnValidate de DUoM Ratio
    /// en DUoMTrackingSpecExt NO recalcula DUoM Second Qty (exit explícito para AlwaysVariable),
    /// por lo que DUoM Second Qty = 8 se mantiene como valor manual independiente.
    ///
    /// Verificación en paso 2 y 6: los valores recargados son los persistidos en ReservEntry
    /// (copia directa sin OnValidate, por lo que no hay recálculo en carga).
    /// </summary>
    [ModalPageHandler]
    procedure ItemTrackingLines_AssignAndVerify_MPH(
        var ItemTrackingLines: TestPage "Item Tracking Lines")
    var
        LibraryAssert: Codeunit "Library Assert";
    begin
        case HandlerStep of
            1:
                begin
                    // Primera apertura: introducir lote y valores DUoM en nueva línea
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-DUOM-001');
                    ItemTrackingLines."Quantity (Base)".SetValue(10);
                    // Modo AlwaysVariable: DUoM Ratio = 0.8 (= 8/10) no recalcula DUoM Second Qty
                    ItemTrackingLines."DUoM Ratio".SetValue(0.8);
                    // Valor manual independiente (no calculado automáticamente)
                    ItemTrackingLines."DUoM Second Qty".SetValue(8);
                    ItemTrackingLines.OK().Invoke();
                end;
            2:
                begin
                    // Segunda apertura: verificar que los valores DUoM se recargan
                    // desde Reservation Entry via OnAfterCopyTrackingFromReservEntry (codeunit 50110)
                    ItemTrackingLines.First();
                    LibraryAssert.AreEqual(
                        'LOT-DUOM-001',
                        ItemTrackingLines."Lot No.".Value,
                        'Lot No. debe seguir siendo LOT-DUOM-001 al reabrir Item Tracking Lines.');
                    LibraryAssert.AreNearlyEqual(
                        0.8,
                        ItemTrackingLines."DUoM Ratio".AsDecimal(),
                        0.001,
                        'DUoM Ratio debe ser 0.8 al reabrir Item Tracking Lines.');
                    LibraryAssert.AreNearlyEqual(
                        8,
                        ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                        0.001,
                        'DUoM Second Qty debe ser 8 al reabrir Item Tracking Lines.');
                    ItemTrackingLines.OK().Invoke();
                end;
            3:
                begin
                    // Paso 3: asignar lote con ratio registrado en DUoM Lot Ratio
                    // El subscriber OnAfterValidateTrackingSpecLotNo (50109) auto-asigna
                    // DUoM Ratio = 1.5 al validar el lote LOT-PERSIST03.
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-PERSIST03');
                    ItemTrackingLines."Quantity (Base)".SetValue(8);
                    ItemTrackingLines.OK().Invoke();
                end;
            4:
                begin
                    // Paso 4: asignar lote para artículo sin DUoM activo
                    // No se introducen valores DUoM — los campos deben quedar en 0
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-T05');
                    ItemTrackingLines."Quantity (Base)".SetValue(5);
                    ItemTrackingLines.OK().Invoke();
                end;
            5:
                begin
                    // Paso 5: asignar lote SIN ratio de lote (fallback desde Purchase Line)
                    // El subscriber OnAfterValidateTrackingSpecLotNo (50109) aplica
                    // DUoM Ratio = 1.25 desde Purchase Line al no encontrar DUoM Lot Ratio.
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-FALLBACK01');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    ItemTrackingLines.OK().Invoke();
                end;
            6:
                begin
                    // Paso 6: verificar recarga de DUoM Ratio = 1.25 tras reabrir
                    // Los valores deben provenir de Reservation Entry (persistidos en paso 5)
                    ItemTrackingLines.First();
                    LibraryAssert.AreEqual(
                        'LOT-FALLBACK01',
                        ItemTrackingLines."Lot No.".Value,
                        'T-P05: Lot No. debe ser LOT-FALLBACK01 al reabrir.');
                    LibraryAssert.AreNearlyEqual(
                        1.25,
                        ItemTrackingLines."DUoM Ratio".AsDecimal(),
                        0.001,
                        'T-P05: DUoM Ratio debe ser 1.25 al reabrir (fallback desde PurchLine persistido).');
                    LibraryAssert.AreNearlyEqual(
                        1.25,
                        ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                        0.001,
                        'T-P05: DUoM Second Qty debe ser 1.25 al reabrir.');
                    ItemTrackingLines.OK().Invoke();
                end;
        end;
    end;

    var
        HandlerStep: Integer;
}
