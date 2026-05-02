/// <summary>
/// Test de regresión para validar la persistencia de campos DUoM introducidos
/// desde la página Item Tracking Lines en un pedido de compra con seguimiento por lote.
///
/// Escenario cubierto (flujo real de usuario):
///   Purchase Order → Purchase Line → Item Tracking Lines
///   → usuario informa lote + DUoM Ratio + DUoM Second Qty
///   → OK
///   → persistencia real en Reservation Entry
///   → reabrir Item Tracking Lines
///   → valores DUoM visibles de nuevo
///
/// Arquitectura cubierta:
///   - Persistencia al cerrar: TrackingSpec buffer → Reservation Entry
///     vía OnAfterCopyTrackingFromTrackingSpec (DUoM Tracking Copy Subscribers, 50110)
///   - Recarga al reabrir: Reservation Entry → TrackingSpec buffer
///     vía OnAfterCopyTrackingFromReservEntry o OnAfterInitFromReservEntry (50110)
///
/// Modo de conversión: AlwaysVariable (el usuario introduce DUoM Second Qty y DUoM Ratio
/// de forma independiente en la línea de tracking; el trigger de DUoM Ratio no
/// recalcula DUoM Second Qty en este modo, según DUoMTrackingSpecExt.TableExt.al).
///
/// Modelo 1:N respetado: el test asigna 1 lote a 1 línea de compra; la arquitectura
/// es extensible a N lotes sin ninguna relación 1:1 artificial entre línea y lote.
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
    //   DUoM Ratio: 1.25 (introducido manualmente; no recalcula en AlwaysVariable)
    //   DUoM Second Qty: 8 (introducido manualmente e independiente)
    //
    // Primera apertura (HandlerStep = 1):
    //   - Introduce Lot No. = 'LOT-DUOM-001', Qty = 10
    //   - Introduce DUoM Ratio = 1.25 y DUoM Second Qty = 8
    //   - Acepta con OK
    //
    // Validación de persistencia en BD:
    //   - Reservation Entry vinculada a la Purchase Line con:
    //       Lot No. = 'LOT-DUOM-001'
    //       DUoM Ratio = 1.25
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
            1.25, ReservEntry."DUoM Ratio", 0.001,
            'DUoM Ratio debe ser 1.25 en Reservation Entry tras cerrar Item Tracking Lines.');
        LibraryAssert.AreNearlyEqual(
            8, ReservEntry."DUoM Second Qty", 0.001,
            'DUoM Second Qty debe ser 8 en Reservation Entry tras cerrar Item Tracking Lines.');

        // [WHEN] Segunda apertura de Item Tracking Lines: el usuario vuelve a abrir
        //        la página para verificar que los valores DUoM siguen presentes (HandlerStep = 2)
        HandlerStep := 2;
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();

        PurchaseOrder.Close();
    end;

    /// <summary>
    /// ModalPageHandler para Item Tracking Lines — usado en dos pasos:
    ///
    ///   HandlerStep = 1: simula que el usuario introduce lote y valores DUoM.
    ///   HandlerStep = 2: verifica que los valores DUoM se han recargado correctamente
    ///                    desde Reservation Entry al reabrir la página.
    ///
    /// DUoM Ratio = 1.25 en modo AlwaysVariable: el trigger OnValidate de DUoM Ratio
    /// en DUoMTrackingSpecExt NO recalcula DUoM Second Qty (exit explícito para AlwaysVariable),
    /// por lo que DUoM Second Qty = 8 se mantiene como valor manual independiente.
    ///
    /// Verificación en paso 2: los valores recargados son los persistidos en ReservEntry
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
                    // Modo AlwaysVariable: DUoM Ratio = 1.25 no recalcula DUoM Second Qty
                    ItemTrackingLines."DUoM Ratio".SetValue(1.25);
                    // Valor manual independiente (no calculado automáticamente)
                    ItemTrackingLines."DUoM Second Qty".SetValue(8);
                    ItemTrackingLines.OK().Invoke();
                end;
            2:
                begin
                    // Segunda apertura: verificar que los valores DUoM se recargan
                    // desde Reservation Entry via OnAfterCopyTrackingFromReservEntry
                    // o OnAfterInitFromReservEntry (codeunit 50110)
                    ItemTrackingLines.First();
                    LibraryAssert.AreEqual(
                        'LOT-DUOM-001',
                        ItemTrackingLines."Lot No.".Value,
                        'Lot No. debe seguir siendo LOT-DUOM-001 al reabrir Item Tracking Lines.');
                    LibraryAssert.AreNearlyEqual(
                        1.25,
                        ItemTrackingLines."DUoM Ratio".AsDecimal(),
                        0.001,
                        'DUoM Ratio debe ser 1.25 al reabrir Item Tracking Lines.');
                    LibraryAssert.AreNearlyEqual(
                        8,
                        ItemTrackingLines."DUoM Second Qty".AsDecimal(),
                        0.001,
                        'DUoM Second Qty debe ser 8 al reabrir Item Tracking Lines.');
                    ItemTrackingLines.OK().Invoke();
                end;
        end;
    end;

    var
        HandlerStep: Integer;
}
