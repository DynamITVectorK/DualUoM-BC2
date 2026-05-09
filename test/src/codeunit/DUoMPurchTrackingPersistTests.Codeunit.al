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
///   T-REOPEN-01: Variable — un lote 2 KG / 5 PIEZAS / ratio 2.5 se persiste y recarga
///   T-REOPEN-02: Variable — dos lotes con ratios distintos (3 y 2) se preservan al reabrir
///   T-REOPEN-03: Variable — el ratio agregado de PurchLine (2.5) no sobreescribe
///                los ratios individuales de cada lote al reabrir
///   T-REOPEN-04: Variable — recepción parcial (2 de 10 unidades): DUoM del lote
///                a manipular se persiste y recarga; validación no exige DUoM para el total
///   T-REOPEN-05: Regression — reabrir Item Tracking Lines no crea Tracking Spec duplicadas
///   T-REOPEN-06: Regression — dos cierres consecutivos no duplican el tracking
///                (triple apertura: asignar → verificar → verificar con valores DUoM)
///   T-REOPEN-07: Variable — segunda edición de Item Tracking Lines persiste DUoM modificado
///                (Modify path: ReservEntry existente actualiza DUoM Ratio e DUoM Second Qty)
///   T-REOPEN-08: AlwaysVariable — segunda edición persiste DUoM modificado
///                (Modify path via flujo estándar de tracking: OnAfterMoveFields → RE actualizada)
///
/// Arquitectura cubierta:
///   - Persistencia al cerrar (Insert): TrackingSpec buffer → ReservEntry1 (CopyTrackingFromSpec)
///     → InsertReservEntry (CopyTrackingFromReservEntry) → BD
///     vía OnAfterCopyTrackingFromTrackingSpec y OnAfterCopyTrackingFromReservEntry (50110)
///   - Persistencia al cerrar (Modify): ReservEntry existente actualizada desde buffer
///     vía flujo estándar de tracking (OnAfterMoveFields, OnCreateReservEntryExtraFields)
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
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
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
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
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
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
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
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
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

    // =========================================================================
    // Nuevos tests del issue: persistir y recargar DUoM por lote al reabrir
    // Item Tracking Lines (Variable/AlwaysVariable, multi-lote, recepción parcial)
    // =========================================================================

    // -------------------------------------------------------------------------
    // T-REOPEN-01 — Un lote: DUoM Variable se persiste y recarga correctamente
    //
    // Verifica el flujo descrito en el issue para el caso de un único lote:
    //   Tracking buffer → Reservation Entry → recarga → Tracking buffer
    //
    // Valores de referencia:
    //   Artículo: DUoM Variable, seguimiento por lote habilitado
    //   Pedido: Cantidad = 2
    //   Lote: LOT-REOPEN-T1 · DUoM Second Qty = 5 · DUoM Ratio = 2.5 (= 5 / 2)
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLotTracking_ReopenItemTracking_PreservesDUoMForSingleLot()
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
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con línea de 2 unidades
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Modify(true);

        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);

        // [WHEN] Primera apertura de Item Tracking Lines (HandlerStep = 7):
        //        asignar LOT-REOPEN-T1, Qty = 2, DUoM Second Qty = 5
        //        NormalizeTrackingDUoMSecondQty auto-calcula DUoM Ratio = 5 / 2 = 2.5
        HandlerStep := 7;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [THEN] Reservation Entry tiene DUoM Second Qty = 5 y DUoM Ratio = 2.5
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Lot No.", 'LOT-REOPEN-T1');
        LibraryAssert.IsTrue(
            ReservEntry.FindFirst(),
            'T-REOPEN-01: Debe existir Reservation Entry para LOT-REOPEN-T1.');
        LibraryAssert.AreNearlyEqual(
            2.5, ReservEntry."DUoM Ratio", 0.001,
            'T-REOPEN-01: ReservEntry.DUoM Ratio debe ser 2.5.');
        LibraryAssert.AreNearlyEqual(
            5, ReservEntry."DUoM Second Qty", 0.001,
            'T-REOPEN-01: ReservEntry.DUoM Second Qty debe ser 5.');

        // [WHEN] El usuario vuelve a abrir Item Tracking Lines (HandlerStep = 8):
        //        verifica que DUoM Second Qty = 5 y DUoM Ratio = 2.5 se recargan
        //        desde Reservation Entry (no desde PurchLine ni recalculado)
        HandlerStep := 8;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-REOPEN-02 — Dos lotes con ratios distintos: ambos se preservan al reabrir
    //
    // Verifica que con dos lotes que tienen ratios DUoM distintos:
    //   1. Reservation Entry persiste cada ratio por lote.
    //   2. Al reabrir Item Tracking Lines, cada lote conserva su ratio individual.
    //
    // Valores de referencia:
    //   LOTE-A: 1 KG · 3 PIEZAS · ratio = 3
    //   LOTE-B: 1 KG · 2 PIEZAS · ratio = 2
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLotTracking_ReopenItemTracking_PreservesDifferentLotRatios()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntryA: Record "Reservation Entry";
        ReservEntryB: Record "Reservation Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con línea de 2 unidades
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Modify(true);

        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);

        // [WHEN] Primera apertura (HandlerStep = 9): asignar dos lotes con ratios distintos
        //        LOT-MULTI-A: 1 KG / 3 PIEZAS → ratio auto = 3 / 1 = 3
        //        LOT-MULTI-B: 1 KG / 2 PIEZAS → ratio auto = 2 / 1 = 2
        HandlerStep := 9;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [THEN] Reservation Entry de LOT-MULTI-A tiene ratio 3
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntryA.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntryA.SetRange("Item No.", Item."No.");
        ReservEntryA.SetRange("Lot No.", 'LOT-MULTI-A');
        LibraryAssert.IsTrue(
            ReservEntryA.FindFirst(),
            'T-REOPEN-02: Debe existir Reservation Entry para LOT-MULTI-A.');
        LibraryAssert.AreNearlyEqual(
            3, ReservEntryA."DUoM Ratio", 0.001,
            'T-REOPEN-02: ReservEntry.DUoM Ratio de LOT-MULTI-A debe ser 3.');
        LibraryAssert.AreNearlyEqual(
            3, ReservEntryA."DUoM Second Qty", 0.001,
            'T-REOPEN-02: ReservEntry.DUoM Second Qty de LOT-MULTI-A debe ser 3.');

        // [THEN] Reservation Entry de LOT-MULTI-B tiene ratio 2
        ReservEntryB.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntryB.SetRange("Item No.", Item."No.");
        ReservEntryB.SetRange("Lot No.", 'LOT-MULTI-B');
        LibraryAssert.IsTrue(
            ReservEntryB.FindFirst(),
            'T-REOPEN-02: Debe existir Reservation Entry para LOT-MULTI-B.');
        LibraryAssert.AreNearlyEqual(
            2, ReservEntryB."DUoM Ratio", 0.001,
            'T-REOPEN-02: ReservEntry.DUoM Ratio de LOT-MULTI-B debe ser 2.');
        LibraryAssert.AreNearlyEqual(
            2, ReservEntryB."DUoM Second Qty", 0.001,
            'T-REOPEN-02: ReservEntry.DUoM Second Qty de LOT-MULTI-B debe ser 2.');

        // [WHEN] Segunda apertura (HandlerStep = 10): verificar que cada lote
        //        muestra su propio ratio recargado desde Reservation Entry
        HandlerStep := 10;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-REOPEN-03 — Reapertura no sobreescribe ratios por lote
    //
    // Verifica explícitamente la regla: al reabrir Item Tracking Lines,
    // el ratio de cada lote debe provenir de Reservation Entry (detalle),
    // sin depender de agregados en Purchase Line.
    //
    // Mismos valores de referencia que T-REOPEN-02:
    //   LOTE-A: ratio 3, LOTE-B: ratio 2
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLotTracking_ReopenItemTracking_DoesNotOverwriteLotDUoMFromPurchaseLineAggregate()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntryA: Record "Reservation Entry";
        ReservEntryB: Record "Reservation Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con línea de 2 unidades
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Modify(true);

        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);

        // [WHEN] Primera apertura (HandlerStep = 9): asignar dos lotes con ratios distintos
        HandlerStep := 9;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [THEN] Reservation Entry conserva el detalle DUoM por lote antes del reopen
        PurchLine.Get(PurchHeader."Document Type", PurchHeader."No.", PurchLine."Line No.");
        ReservEntryA.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntryA.SetRange("Item No.", Item."No.");
        ReservEntryA.SetRange("Lot No.", 'LOT-MULTI-A');
        LibraryAssert.IsTrue(
            ReservEntryA.FindFirst(),
            'T-REOPEN-03: Debe existir Reservation Entry para LOT-MULTI-A.');
        LibraryAssert.AreNearlyEqual(
            3, ReservEntryA."DUoM Ratio", 0.001,
            'T-REOPEN-03: ReservEntry.DUoM Ratio de LOT-MULTI-A debe ser 3.');

        ReservEntryB.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntryB.SetRange("Item No.", Item."No.");
        ReservEntryB.SetRange("Lot No.", 'LOT-MULTI-B');
        LibraryAssert.IsTrue(
            ReservEntryB.FindFirst(),
            'T-REOPEN-03: Debe existir Reservation Entry para LOT-MULTI-B.');
        LibraryAssert.AreNearlyEqual(
            2, ReservEntryB."DUoM Ratio", 0.001,
            'T-REOPEN-03: ReservEntry.DUoM Ratio de LOT-MULTI-B debe ser 2.');

        // [WHEN] Segunda apertura (HandlerStep = 10): verificar que los ratios por lote
        //        se recuperan de Reservation Entry
        // El handler verifica: LOT-MULTI-A → ratio 3 (≠ 2.5) y LOT-MULTI-B → ratio 2 (≠ 2.5)
        HandlerStep := 10;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-REOPEN-04 — Recepción parcial: DUoM de la cantidad a manipular se preserva
    //
    // Verifica que con un pedido de 10 unidades donde solo se reciben 2 ahora,
    // el tracking DUoM para esas 2 unidades se persiste y se recarga correctamente.
    //
    // Regla funcional: la validación no exige DUoM para las 10 unidades completas
    // si el estándar BC solo está manipulando 2 unidades (Qty. to Receive = 2).
    //
    // Valores de referencia:
    //   Pedido: Quantity = 10, Qty. to Receive = 2
    //   Lote: LOT-PARTIAL-T4 · Qty = 2 · DUoM Second Qty = 5 · DUoM Ratio = 2.5
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLotTracking_PartialReceipt_ReopenItemTracking_PreservesDUoMForQtyToHandle()
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
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con línea de 10 unidades, Qty. to Receive = 2
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Validate("Qty. to Receive", 2);
        PurchLine.Modify(true);

        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);

        // [WHEN] Primera apertura (HandlerStep = 11): asignar LOT-PARTIAL-T4
        //        Qty = 2 (= Qty. to Receive), DUoM Second Qty = 5 → ratio auto = 2.5
        HandlerStep := 11;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [THEN] Reservation Entry tiene DUoM valores para las 2 unidades rastreadas
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Lot No.", 'LOT-PARTIAL-T4');
        LibraryAssert.IsTrue(
            ReservEntry.FindFirst(),
            'T-REOPEN-04: Debe existir Reservation Entry para LOT-PARTIAL-T4.');
        LibraryAssert.AreNearlyEqual(
            2.5, ReservEntry."DUoM Ratio", 0.001,
            'T-REOPEN-04: ReservEntry.DUoM Ratio debe ser 2.5.');
        LibraryAssert.AreNearlyEqual(
            5, ReservEntry."DUoM Second Qty", 0.001,
            'T-REOPEN-04: ReservEntry.DUoM Second Qty debe ser 5.');

        // [WHEN] Segunda apertura (HandlerStep = 12): verificar que LOT-PARTIAL-T4
        //        recarga DUoM Second Qty = 5 y DUoM Ratio = 2.5 desde Reservation Entry
        HandlerStep := 12;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-REOPEN-05 — Regression: reabrir Item Tracking Lines no crea duplicados
    //
    // Verifica que la solución de persistencia DUoM no introduce errores del tipo:
    //   "The record in table Tracking Specification already exists.
    //    Identification fields and values: Entry No.='...'"
    //
    // Prueba: cerrar y reabrir Item Tracking Lines muestra exactamente 1 línea
    // por lote asignado, sin registros duplicados en el buffer temporal.
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLotTracking_ReopenItemTracking_DoesNotCreateDuplicateTrackingSpecification()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con línea de 2 unidades
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Modify(true);

        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);

        // [WHEN] Primera apertura (HandlerStep = 7): asignar LOT-REOPEN-T1
        //        (reutiliza el mismo handler que T-REOPEN-01)
        HandlerStep := 7;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [WHEN] Segunda apertura (HandlerStep = 13): verificar que la página abre
        //        sin error "record already exists" y muestra exactamente 1 línea
        HandlerStep := 13;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        PurchaseOrder.Close();
    end;

    // T-REOPEN-06 — Regresión: dos cierres consecutivos no duplican el tracking
    //
    // Extiende T-REOPEN-05 con una tercera apertura para garantizar que la
    // idempotencia se mantiene independientemente del número de reaperturas.
    //
    // Valores de referencia:
    //   Artículo: DUoM Variable, seguimiento por lote habilitado
    //   Lote: LOT-REOPEN-T1 · DUoM Second Qty = 5 · DUoM Ratio = 2.5 (= 5 / 2)
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLotTracking_ReopenItemTrackingTwice_DoesNotDuplicateTrackingSpecification()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con línea de 2 unidades
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 2);
        PurchLine.Modify(true);

        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);

        // [WHEN] Primera apertura: asignar LOT-REOPEN-T1 (HandlerStep = 7)
        HandlerStep := 7;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [WHEN] Segunda apertura: verificar que no hay duplicados (HandlerStep = 13)
        HandlerStep := 13;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [WHEN] Tercera apertura: verificar que DUoM sigue correcto y no hay duplicados
        //        (HandlerStep = 14)
        // [THEN] La página muestra exactamente 1 línea con LOT-REOPEN-T1
        // [THEN] DUoM Second Qty = 5 y DUoM Ratio = 2.5 se conservan tras dos cierres
        HandlerStep := 14;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-REOPEN-07 — Variable: segunda edición de Item Tracking Lines persiste DUoM modificado
    //
    // Verifica que cuando el usuario modifica DUoM Second Qty en una SEGUNDA apertura
    // de Item Tracking Lines (cuando ya existe una Reservation Entry para el lote),
    // los nuevos valores DUoM (Ratio y Second Qty) se persisten correctamente en
    // Reservation Entry y se recuperan al reabrir por tercera vez.
    //
    // Esto cubre el MODIFY PATH: el flujo estándar de tracking (OnAfterMoveFields,
    // OnCreateReservEntryExtraFields) actualiza la RE existente desde el buffer.
    //
    // Valores de referencia:
    //   Artículo: DUoM Variable, seguimiento por lote habilitado
    //   Lote: LOT-MODIFY-T7V
    //   Primera edición:  Qty Base = 4, DUoM Second Qty = 3  → DUoM Ratio = 0.75
    //   Segunda edición:  Qty Base = 4, DUoM Second Qty = 4  → DUoM Ratio = 1
    //   Tercera apertura: Qty Base = 4, DUoM Ratio = 1, DUoM Second Qty = 4 ✓
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLotTracking_SecondEdit_Variable_PersistsDUoMModify()
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
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con línea de 5 unidades
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Modify(true);

        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);

        // [WHEN] Primera apertura (HandlerStep = 15): asignar LOT-MODIFY-T7V
        //        Qty Base = 4, DUoM Second Qty = 3 → Ratio = 0.75
        HandlerStep := 15;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [THEN] Tras primera edición: Reservation Entry tiene DUoM Ratio = 0.75
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Lot No.", 'LOT-MODIFY-T7V');
        LibraryAssert.IsTrue(
            ReservEntry.FindFirst(),
            'T-REOPEN-07: Debe existir RE para LOT-MODIFY-T7V tras primera edición.');
        LibraryAssert.AreNearlyEqual(
            0.75, ReservEntry."DUoM Ratio", 0.001,
            'T-REOPEN-07: RE.DUoM Ratio debe ser 0.75 tras primera edición.');
        LibraryAssert.AreNearlyEqual(
            3, ReservEntry."DUoM Second Qty", 0.001,
            'T-REOPEN-07: RE.DUoM Second Qty debe ser 3 tras primera edición.');
        LibraryAssert.AreNearlyEqual(
            4, ReservEntry."Quantity (Base)", 0.001,
            'T-REOPEN-07: RE.Quantity (Base) debe ser 4 tras primera edición.');

        // [WHEN] Segunda apertura (HandlerStep = 16): modificar solo DUoM Second Qty = 4
        //        Mantiene Qty Base real (= 4) y recalcula DUoM Ratio = 4 / 4 = 1
        HandlerStep := 16;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [THEN] Tras segunda edición: Reservation Entry actualizada con DUoM Ratio = 1
        //        (Modify path via flujo estándar de tracking: OnAfterMoveFields → RE actualizada)
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Lot No.", 'LOT-MODIFY-T7V');
        LibraryAssert.IsTrue(
            ReservEntry.FindFirst(),
            'T-REOPEN-07: Debe existir RE para LOT-MODIFY-T7V tras segunda edición.');
        LibraryAssert.AreNearlyEqual(
            1, ReservEntry."DUoM Ratio", 0.001,
            'T-REOPEN-07: RE.DUoM Ratio debe ser 1 tras segunda edición (Modify path).');
        LibraryAssert.AreNearlyEqual(
            4, ReservEntry."DUoM Second Qty", 0.001,
            'T-REOPEN-07: RE.DUoM Second Qty debe ser 4 tras segunda edición (Modify path).');
        LibraryAssert.AreNearlyEqual(
            4, ReservEntry."Quantity (Base)", 0.001,
            'T-REOPEN-07: RE.Quantity (Base) debe ser 4 tras segunda edición (Modify path).');

        // [WHEN] Tercera apertura (HandlerStep = 17): verificar que los valores actualizados
        //        se recargan correctamente desde Reservation Entry al buffer
        HandlerStep := 17;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-REOPEN-08 — AlwaysVariable: segunda edición de Item Tracking Lines persiste DUoM
    //
    // Verifica el mismo Modify path que T-REOPEN-07 pero en modo AlwaysVariable,
    // donde el usuario introduce DUoM Ratio y DUoM Second Qty de forma independiente.
    //
    // Valores de referencia:
    //   Artículo: DUoM AlwaysVariable, seguimiento por lote habilitado
    //   Lote: LOT-MODIFY-T8AV
    //   Primera edición:  Qty Base = 4, DUoM Ratio = 0.75, DUoM Second Qty = 3
    //   Segunda edición:  Qty Base = 4, DUoM Second Qty = 4 → DUoM Ratio = 1
    //   Tercera apertura: Qty Base = 4, DUoM Ratio = 1, DUoM Second Qty = 4 ✓
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLotTracking_SecondEdit_AlwaysVariable_PersistsDUoMModify()
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
        // [GIVEN] Artículo con DUoM AlwaysVariable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con línea de 5 unidades
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Modify(true);

        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);

        // [WHEN] Primera apertura (HandlerStep = 18): asignar LOT-MODIFY-T8AV
        //        Qty Base = 4, DUoM Ratio = 0.75, DUoM Second Qty = 3 (introducidos manualmente)
        HandlerStep := 18;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [THEN] Tras primera edición: Reservation Entry tiene DUoM Ratio = 0.75
        // SetSourceFilter applies the complete standard BC source identity.
        // See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Lot No.", 'LOT-MODIFY-T8AV');
        LibraryAssert.IsTrue(
            ReservEntry.FindFirst(),
            'T-REOPEN-08: Debe existir RE para LOT-MODIFY-T8AV tras primera edición.');
        LibraryAssert.AreNearlyEqual(
            0.75, ReservEntry."DUoM Ratio", 0.001,
            'T-REOPEN-08: RE.DUoM Ratio debe ser 0.75 tras primera edición.');
        LibraryAssert.AreNearlyEqual(
            3, ReservEntry."DUoM Second Qty", 0.001,
            'T-REOPEN-08: RE.DUoM Second Qty debe ser 3 tras primera edición.');
        LibraryAssert.AreNearlyEqual(
            4, ReservEntry."Quantity (Base)", 0.001,
            'T-REOPEN-08: RE.Quantity (Base) debe ser 4 tras primera edición.');

        // [WHEN] Segunda apertura (HandlerStep = 19): modificar solo DUoM Second Qty = 4
        //        Mantiene Qty Base real (= 4) y recalcula DUoM Ratio = 4 / 4 = 1
        HandlerStep := 19;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        // [THEN] Tras segunda edición: Reservation Entry actualizada con DUoM Ratio = 1
        //        (Modify path via flujo estándar de tracking: OnAfterMoveFields → RE actualizada)
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchHeader."No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange("Lot No.", 'LOT-MODIFY-T8AV');
        LibraryAssert.IsTrue(
            ReservEntry.FindFirst(),
            'T-REOPEN-08: Debe existir RE para LOT-MODIFY-T8AV tras segunda edición.');
        LibraryAssert.AreNearlyEqual(
            1, ReservEntry."DUoM Ratio", 0.001,
            'T-REOPEN-08: RE.DUoM Ratio debe ser 1 tras segunda edición (Modify path).');
        LibraryAssert.AreNearlyEqual(
            4, ReservEntry."DUoM Second Qty", 0.001,
            'T-REOPEN-08: RE.DUoM Second Qty debe ser 4 tras segunda edición (Modify path).');
        LibraryAssert.AreNearlyEqual(
            4, ReservEntry."Quantity (Base)", 0.001,
            'T-REOPEN-08: RE.Quantity (Base) debe ser 4 tras segunda edición (Modify path).');

        // [WHEN] Tercera apertura (HandlerStep = 20): verificar que los valores actualizados
        //        se recargan correctamente desde Reservation Entry al buffer
        HandlerStep := 20;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-REOPEN-09 — Variable: posting usa ratio recalculado tras editar Quantity (Base)
    //
    // Verifica que, tras una segunda edición en Item Tracking Lines donde se modifica
    // DUoM Second Qty de una línea existente, el posting de recepción
    // genera ILE con los valores recalculados por lote.
    //
    // Referencia:
    //   Primera edición: LOT-MODIFY-T7V → Base 4, Second 3, Ratio 0.75
    //   Segunda edición: LOT-MODIFY-T7V → Base 4, Second 4, Ratio 1
    //   Posting: ILE debe quedar con Base 4, Second 4, Ratio 1
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_AssignAndVerify_MPH')]
    procedure PurchLotTracking_SecondEdit_Variable_PostingUsesRecalculatedRatio()
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
        // [GIVEN] Artículo DUoM Variable con seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Pedido de compra con línea de 5 unidades
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Modify(true);

        // [WHEN] Primera y segunda edición de Item Tracking Lines sobre la misma línea/lote
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        PurchaseOrder.PurchLines.First();
        HandlerStep := 15;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        HandlerStep := 16;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [WHEN] Se contabiliza la recepción
        LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);

        // [THEN] El ILE conserva los valores recalculados por lote
        ILE.SetRange("Item No.", Item."No.");
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        ILE.SetRange("Lot No.", 'LOT-MODIFY-T7V');
        LibraryAssert.IsTrue(ILE.FindFirst(),
            'T-REOPEN-09: Debe existir ILE para LOT-MODIFY-T7V tras contabilizar.');
        LibraryAssert.AreNearlyEqual(
            4, ILE.Quantity, 0.001,
            'T-REOPEN-09: ILE.Quantity debe ser 4.');
        LibraryAssert.AreNearlyEqual(
            4, ILE."DUoM Second Qty", 0.001,
            'T-REOPEN-09: ILE.DUoM Second Qty debe ser 4 tras segunda edición.');
        LibraryAssert.AreNearlyEqual(
            1, ILE."DUoM Ratio", 0.001,
            'T-REOPEN-09: ILE.DUoM Ratio debe ser 1 tras segunda edición.');
    end;

    /// <summary>
    /// ModalPageHandler para Item Tracking Lines — usado en veinte pasos:
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
    ///   HandlerStep = 7: asigna lote LOT-REOPEN-T1, qty = 2, DUoM Second Qty = 5.
    ///                    NormalizeTrackingDUoMSecondQty auto-calcula DUoM Ratio = 2.5.
    ///                    Modo Variable. Usado en T-REOPEN-01, T-REOPEN-05 y T-REOPEN-06.
    ///   HandlerStep = 8: verifica recarga de LOT-REOPEN-T1 con DUoM Second Qty = 5
    ///                    y DUoM Ratio = 2.5 al reabrir. Usado en T-REOPEN-01.
    ///   HandlerStep = 9: asigna dos lotes LOT-MULTI-A (1 KG / 3 PIEZAS) y
    ///                    LOT-MULTI-B (1 KG / 2 PIEZAS). Ratios auto-calculados: 3 y 2.
    ///                    Modo Variable. Usado en T-REOPEN-02 y T-REOPEN-03.
    ///   HandlerStep = 10: verifica que al reabrir LOT-MULTI-A tiene ratio = 3
    ///                     y LOT-MULTI-B tiene ratio = 2 (no el agregado 2.5 de PurchLine).
    ///   HandlerStep = 11: asigna lote LOT-PARTIAL-T4 (qty = 2 / 5 PIEZAS) para
    ///                     escenario de recepción parcial. Ratio auto = 2.5.
    ///                     Usado en T-REOPEN-04.
    ///   HandlerStep = 12: verifica recarga de LOT-PARTIAL-T4 (DUoM Second Qty = 5,
    ///                     DUoM Ratio = 2.5) al reabrir. Usado en T-REOPEN-04.
    ///   HandlerStep = 13: verifica que solo existe 1 línea de tracking al reabrir
    ///                     (sin duplicados). Si existe una segunda línea, el Error captura
    ///                     sus datos (Lot No., Qty Base, DUoM Ratio, DUoM Second Qty)
    ///                     para diagnóstico. Usado en T-REOPEN-05 y T-REOPEN-06.
    ///   HandlerStep = 14: verifica que al reabrir (tercera vez) solo existe 1 línea,
    ///                     y que DUoM Second Qty = 5 y DUoM Ratio = 2.5 siguen correctos.
    ///                     Usado en T-REOPEN-06.
    ///   HandlerStep = 15: primera edición T-REOPEN-07 (Variable). Asigna LOT-MODIFY-T7V,
    ///                     qty = 4, DUoM Second Qty = 3 → DUoM Ratio auto = 0.75.
    ///   HandlerStep = 16: segunda edición T-REOPEN-07 (Variable). Mantiene Quantity (Base)
    ///                     en 4 y modifica DUoM Second Qty a 4 → DUoM Ratio auto = 1.
    ///                     Modify path via flujo estándar de tracking.
    ///   HandlerStep = 17: tercera apertura T-REOPEN-07. Verifica Qty Base = 4,
    ///                     DUoM Ratio = 1 y DUoM Second Qty = 4 recargados.
    ///   HandlerStep = 18: primera edición T-REOPEN-08 (AlwaysVariable). Asigna
    ///                     LOT-MODIFY-T8AV, qty = 4, DUoM Ratio = 0.75, DUoM Second Qty = 3.
    ///   HandlerStep = 19: segunda edición T-REOPEN-08 (AlwaysVariable). Mantiene
    ///                     Quantity (Base) en 4 y modifica DUoM Second Qty a 4 → DUoM Ratio auto = 1.
    ///                     Modify path via flujo estándar de tracking.
    ///   HandlerStep = 20: tercera apertura T-REOPEN-08. Verifica Qty Base = 4,
    ///                     DUoM Ratio = 1 y DUoM Second Qty = 4 recargados.
    ///
    /// DUoM Ratio = 0.8 en modo AlwaysVariable: el trigger OnValidate de DUoM Ratio
    /// en DUoMTrackingSpecExt NO recalcula DUoM Second Qty (exit explícito para AlwaysVariable),
    /// por lo que DUoM Second Qty = 8 se mantiene como valor manual independiente.
    ///
    /// Verificación en pasos 2, 6, 8, 10, 12, 14, 17, 20: los valores recargados son los
    /// persistidos en ReservEntry (copia directa sin OnValidate, sin recálculo en carga).
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
            7:
                begin
                    // T-REOPEN-01 / T-REOPEN-05: Asignar un lote en modo Variable
                    // NormalizeTrackingDUoMSecondQty auto-calcula DUoM Ratio = 5 / 2 = 2.5
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-REOPEN-T1');
                    ItemTrackingLines."Quantity (Base)".SetValue(2);
                    ItemTrackingLines."DUoM Second Qty".SetValue(5);
                    ItemTrackingLines.OK().Invoke();
                end;
            8:
                begin
                    // T-REOPEN-01: Verificar que LOT-REOPEN-T1 se recarga con los valores correctos
                    // DUoM Second Qty = 5 y DUoM Ratio = 2.5 deben provenir de Reservation Entry
                    ItemTrackingLines.First();
                    LibraryAssert.AreEqual(
                        'LOT-REOPEN-T1',
                        ItemTrackingLines."Lot No.".Value,
                        'T-REOPEN-01: Lot No. debe ser LOT-REOPEN-T1 al reabrir.');
                    LibraryAssert.AreNearlyEqual(
                        5,
                        ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                        0.001,
                        'T-REOPEN-01: DUoM Second Qty debe ser 5 al reabrir (desde ReservEntry).');
                    LibraryAssert.AreNearlyEqual(
                        2.5,
                        ItemTrackingLines."DUoM Ratio".AsDecimal(),
                        0.001,
                        'T-REOPEN-01: DUoM Ratio debe ser 2.5 al reabrir (desde ReservEntry, no recalculado).');
                    ItemTrackingLines.OK().Invoke();
                end;
            9:
                begin
                    // T-REOPEN-02 / T-REOPEN-03: Asignar dos lotes con ratios distintos
                    // NormalizeTrackingDUoMSecondQty auto-calcula: LOTE-A ratio = 3 / 1 = 3
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-MULTI-A');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    ItemTrackingLines."DUoM Second Qty".SetValue(3);
                    // NormalizeTrackingDUoMSecondQty auto-calcula: LOTE-B ratio = 2 / 1 = 2
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-MULTI-B');
                    ItemTrackingLines."Quantity (Base)".SetValue(1);
                    ItemTrackingLines."DUoM Second Qty".SetValue(2);
                    ItemTrackingLines.OK().Invoke();
                end;
            10:
                begin
                    // T-REOPEN-02 / T-REOPEN-03: Verificar ratios por lote al reabrir
                    // Cada lote debe mostrar su propio ratio (3 y 2), no el agregado 2.5
                    // Recorremos en orden de inserción (LOT-MULTI-A primero, LOT-MULTI-B después)
                    // Si el orden varía, verificamos por Lot No. en cada posición.
                    ItemTrackingLines.First();
                    if ItemTrackingLines."Lot No.".Value = 'LOT-MULTI-A' then begin
                        LibraryAssert.AreNearlyEqual(
                            3,
                            ItemTrackingLines."DUoM Ratio".AsDecimal(),
                            0.001,
                            'T-REOPEN-02/03: LOT-MULTI-A debe tener DUoM Ratio = 3 al reabrir (no el agregado 2.5).');
                        LibraryAssert.AreNearlyEqual(
                            3,
                            ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                            0.001,
                            'T-REOPEN-02/03: LOT-MULTI-A debe tener DUoM Second Qty = 3 al reabrir.');
                    end else begin
                        LibraryAssert.AreEqual(
                            'LOT-MULTI-B',
                            ItemTrackingLines."Lot No.".Value,
                            'T-REOPEN-02/03: Primera línea debe ser LOT-MULTI-A o LOT-MULTI-B.');
                        LibraryAssert.AreNearlyEqual(
                            2,
                            ItemTrackingLines."DUoM Ratio".AsDecimal(),
                            0.001,
                            'T-REOPEN-02/03: LOT-MULTI-B debe tener DUoM Ratio = 2 al reabrir (no el agregado 2.5).');
                    end;
                    ItemTrackingLines.Next();
                    if ItemTrackingLines."Lot No.".Value = 'LOT-MULTI-B' then begin
                        LibraryAssert.AreNearlyEqual(
                            2,
                            ItemTrackingLines."DUoM Ratio".AsDecimal(),
                            0.001,
                            'T-REOPEN-02/03: LOT-MULTI-B debe tener DUoM Ratio = 2 al reabrir (no el agregado 2.5).');
                        LibraryAssert.AreNearlyEqual(
                            2,
                            ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                            0.001,
                            'T-REOPEN-02/03: LOT-MULTI-B debe tener DUoM Second Qty = 2 al reabrir.');
                    end else begin
                        LibraryAssert.AreEqual(
                            'LOT-MULTI-A',
                            ItemTrackingLines."Lot No.".Value,
                            'T-REOPEN-02/03: Segunda línea debe ser LOT-MULTI-A o LOT-MULTI-B.');
                        LibraryAssert.AreNearlyEqual(
                            3,
                            ItemTrackingLines."DUoM Ratio".AsDecimal(),
                            0.001,
                            'T-REOPEN-02/03: LOT-MULTI-A debe tener DUoM Ratio = 3 al reabrir (no el agregado 2.5).');
                    end;
                    ItemTrackingLines.OK().Invoke();
                end;
            11:
                begin
                    // T-REOPEN-04: Asignar lote para recepción parcial (2 de 10 unidades)
                    // NormalizeTrackingDUoMSecondQty auto-calcula DUoM Ratio = 5 / 2 = 2.5
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-PARTIAL-T4');
                    ItemTrackingLines."Quantity (Base)".SetValue(2);
                    ItemTrackingLines."DUoM Second Qty".SetValue(5);
                    ItemTrackingLines.OK().Invoke();
                end;
            12:
                begin
                    // T-REOPEN-04: Verificar recarga en recepción parcial
                    // LOT-PARTIAL-T4 debe mostrar DUoM Second Qty = 5 y DUoM Ratio = 2.5
                    ItemTrackingLines.First();
                    LibraryAssert.AreEqual(
                        'LOT-PARTIAL-T4',
                        ItemTrackingLines."Lot No.".Value,
                        'T-REOPEN-04: Lot No. debe ser LOT-PARTIAL-T4 al reabrir (recepción parcial).');
                    LibraryAssert.AreNearlyEqual(
                        5,
                        ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                        0.001,
                        'T-REOPEN-04: DUoM Second Qty debe ser 5 al reabrir (recepción parcial).');
                    LibraryAssert.AreNearlyEqual(
                        2.5,
                        ItemTrackingLines."DUoM Ratio".AsDecimal(),
                        0.001,
                        'T-REOPEN-04: DUoM Ratio debe ser 2.5 al reabrir (recepción parcial).');
                    ItemTrackingLines.OK().Invoke();
                end;
            13:
                begin
                    // T-REOPEN-05: Verificar que no se han creado líneas funcionales duplicadas.
                    // El TestPage estándar puede exponer una línea vacía/de inserción.
                    // Esa línea no debe contarse como duplicado funcional.
                    AssertSingleFunctionalTrackingLine(
                        ItemTrackingLines,
                        'LOT-REOPEN-T1',
                        2,
                        5,
                        2.5,
                        'T-REOPEN-05');
                    ItemTrackingLines.OK().Invoke();
                end;
            14:
                begin
                    // T-REOPEN-06: Tercera apertura — verificar que DUoM sigue correcto
                    // y que no se han generado duplicados funcionales tras dos cierres consecutivos.
                    AssertSingleFunctionalTrackingLine(
                        ItemTrackingLines,
                        'LOT-REOPEN-T1',
                        2,
                        5,
                        2.5,
                        'T-REOPEN-06');
                    ItemTrackingLines.OK().Invoke();
                end;
            15:
                begin
                    // T-REOPEN-07: Primera edición — asignar lote en modo Variable
                    // NormalizeTrackingDUoMSecondQty auto-calcula DUoM Ratio = 3 / 4 = 0.75
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-MODIFY-T7V');
                    ItemTrackingLines."Quantity (Base)".SetValue(4);
                    ItemTrackingLines."DUoM Second Qty".SetValue(3);
                    ItemTrackingLines.OK().Invoke();
                end;
            16:
                begin
                    // T-REOPEN-07: Segunda edición — mantener Qty Base en 4 y modificar DUoM Second Qty a 4
                    // NormalizeTrackingDUoMSecondQty recalcula DUoM Ratio = 4 / 4 = 1
                    ItemTrackingLines.First();
                    ItemTrackingLines."DUoM Second Qty".SetValue(4);
                    ItemTrackingLines.OK().Invoke();
                end;
            17:
                begin
                    // T-REOPEN-07: Tercera apertura — verificar Qty Base = 4, DUoM Ratio = 1
                    // y DUoM Second Qty = 4 recargados desde Reservation Entry actualizada
                    ItemTrackingLines.First();
                    LibraryAssert.AreEqual(
                        'LOT-MODIFY-T7V',
                        ItemTrackingLines."Lot No.".Value,
                        'T-REOPEN-07: Lot No. debe ser LOT-MODIFY-T7V al reabrir.');
                    LibraryAssert.AreNearlyEqual(
                        4,
                        ItemTrackingLines."Quantity (Base)".AsDecimal(),
                        0.001,
                        'T-REOPEN-07: Quantity (Base) debe ser 4 al reabrir (Modify path persistido).');
                    LibraryAssert.AreNearlyEqual(
                        1,
                        ItemTrackingLines."DUoM Ratio".AsDecimal(),
                        0.001,
                        'T-REOPEN-07: DUoM Ratio debe ser 1 al reabrir (Modify path persistido).');
                    LibraryAssert.AreNearlyEqual(
                        4,
                        ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                        0.001,
                        'T-REOPEN-07: DUoM Second Qty debe ser 4 al reabrir (Modify path persistido).');
                    ItemTrackingLines.OK().Invoke();
                end;
            18:
                begin
                    // T-REOPEN-08: Primera edición — asignar lote en modo AlwaysVariable
                    // DUoM Ratio = 0.75 y DUoM Second Qty = 3 introducidos manualmente
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-MODIFY-T8AV');
                    ItemTrackingLines."Quantity (Base)".SetValue(4);
                    ItemTrackingLines."DUoM Ratio".SetValue(0.75);
                    ItemTrackingLines."DUoM Second Qty".SetValue(3);
                    ItemTrackingLines.OK().Invoke();
                end;
            19:
                begin
                    // T-REOPEN-08: Segunda edición — mantener Qty Base en 4 y modificar DUoM Second Qty a 4
                    // NormalizeTrackingDUoMSecondQty recalcula DUoM Ratio = 4 / 4 = 1
                    ItemTrackingLines.First();
                    ItemTrackingLines."DUoM Second Qty".SetValue(4);
                    ItemTrackingLines.OK().Invoke();
                end;
            20:
                begin
                    // T-REOPEN-08: Tercera apertura — verificar Qty Base = 4, DUoM Ratio = 1 y
                    // DUoM Second Qty = 4 recargados desde Reservation Entry actualizada
                    ItemTrackingLines.First();
                    LibraryAssert.AreEqual(
                        'LOT-MODIFY-T8AV',
                        ItemTrackingLines."Lot No.".Value,
                        'T-REOPEN-08: Lot No. debe ser LOT-MODIFY-T8AV al reabrir.');
                    LibraryAssert.AreNearlyEqual(
                        4,
                        ItemTrackingLines."Quantity (Base)".AsDecimal(),
                        0.001,
                        'T-REOPEN-08: Quantity (Base) debe ser 4 al reabrir (Modify path persistido).');
                    LibraryAssert.AreNearlyEqual(
                        1,
                        ItemTrackingLines."DUoM Ratio".AsDecimal(),
                        0.001,
                        'T-REOPEN-08: DUoM Ratio debe ser 1 al reabrir (Modify path persistido).');
                    LibraryAssert.AreNearlyEqual(
                        4,
                        ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                        0.001,
                        'T-REOPEN-08: DUoM Second Qty debe ser 4 al reabrir (Modify path persistido).');
                    ItemTrackingLines.OK().Invoke();
                end;
        end;
    end;

    /// <summary>
    /// Devuelve true si la línea actual del TestPage contiene datos funcionales de tracking.
    /// Una línea completamente vacía/cero (línea de inserción del TestPage estándar)
    /// no debe tratarse como duplicado funcional.
    /// </summary>
    local procedure IsFunctionalTrackingLine(var ItemTrackingLines: TestPage "Item Tracking Lines"): Boolean
    begin
        exit(
            (ItemTrackingLines."Lot No.".Value <> '') or
            (ItemTrackingLines."Quantity (Base)".AsDecimal() <> 0) or
            (ItemTrackingLines."DUoM Ratio".AsDecimal() <> 0) or
            (ItemTrackingLines."DUoM Second Qty".AsDecimal() <> 0));
    end;

    /// <summary>
    /// Valida que existe exactamente una línea funcional para el lote esperado
    /// y que no existen otras líneas funcionales de tracking.
    /// Ignora líneas vacías/de inserción visibles en el TestPage estándar.
    /// </summary>
    local procedure AssertSingleFunctionalTrackingLine(
        var ItemTrackingLines: TestPage "Item Tracking Lines";
        ExpectedLotNo: Code[50];
        ExpectedQtyBase: Decimal;
        ExpectedSecondQty: Decimal;
        ExpectedRatio: Decimal;
        TestContext: Text)
    var
        LibraryAssert: Codeunit "Library Assert";
        ExpectedLotFunctionalCount: Integer;
        OtherFunctionalCount: Integer;
    begin
        ItemTrackingLines.First();

        repeat
            if IsFunctionalTrackingLine(ItemTrackingLines) then begin
                if ItemTrackingLines."Lot No.".Value = ExpectedLotNo then begin
                    ExpectedLotFunctionalCount += 1;

                    LibraryAssert.AreNearlyEqual(
                        ExpectedQtyBase,
                        ItemTrackingLines."Quantity (Base)".AsDecimal(),
                        0.001,
                        TestContext + ': Quantity (Base) incorrecta.');

                    LibraryAssert.AreNearlyEqual(
                        ExpectedSecondQty,
                        ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                        0.001,
                        TestContext + ': DUoM Second Qty incorrecta.');

                    LibraryAssert.AreNearlyEqual(
                        ExpectedRatio,
                        ItemTrackingLines."DUoM Ratio".AsDecimal(),
                        0.001,
                        TestContext + ': DUoM Ratio incorrecto.');
                end else
                    OtherFunctionalCount += 1;
            end;
        until not ItemTrackingLines.Next();

        LibraryAssert.AreEqual(
            1,
            ExpectedLotFunctionalCount,
            TestContext + ': debe existir exactamente 1 línea funcional para el lote esperado.');

        LibraryAssert.AreEqual(
            0,
            OtherFunctionalCount,
            TestContext + ': no deben existir otras líneas funcionales de tracking.');
    end;

    var
        HandlerStep: Integer;
}
