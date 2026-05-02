/// <summary>
/// Procedimientos auxiliares compartidos para los codeunits de test DUoM.
/// Proporciona factorías de datos para crear y limpiar registros DUoM Item Setup (50100)
/// y DUoM Item Variant Setup (50101) durante los tests, sin dependencia de tablas
/// del sistema como Access Control.
/// </summary>
codeunit 50208 "DUoM Test Helpers"
{
    /// <summary>
    /// Crea e inserta un registro DUoM Item Setup con los valores indicados.
    /// Devuelve el registro insertado para su uso inmediato en el test.
    /// </summary>
    procedure CreateItemSetup(
        ItemNo: Code[20];
        Enabled: Boolean;
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal): Record "DUoM Item Setup"
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := ItemNo;
        DUoMItemSetup."Dual UoM Enabled" := Enabled;
        DUoMItemSetup."Second UoM Code" := SecondUoMCode;
        DUoMItemSetup."Conversion Mode" := ConversionMode;
        DUoMItemSetup."Fixed Ratio" := FixedRatio;
        DUoMItemSetup.Insert(false);
        exit(DUoMItemSetup);
    end;

    /// <summary>
    /// Elimina el registro DUoM Item Setup del ítem indicado si existe.
    /// No produce error si el registro no existe.
    /// </summary>
    procedure DeleteItemSetupIfExists(ItemNo: Code[20])
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        if DUoMItemSetup.Get(ItemNo) then
            DUoMItemSetup.Delete(false);
    end;

    /// <summary>
    /// Crea e inserta un registro DUoM Item Variant Setup para la variante indicada.
    /// Devuelve el registro insertado para su uso inmediato en el test.
    /// </summary>
    procedure CreateVariantSetup(
        ItemNo: Code[20];
        VariantCode: Code[10];
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal): Record "DUoM Item Variant Setup"
    var
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
    begin
        DUoMVariantSetup.Init();
        DUoMVariantSetup."Item No." := ItemNo;
        DUoMVariantSetup."Variant Code" := VariantCode;
        DUoMVariantSetup."Second UoM Code" := SecondUoMCode;
        DUoMVariantSetup."Conversion Mode" := ConversionMode;
        DUoMVariantSetup."Fixed Ratio" := FixedRatio;
        DUoMVariantSetup.Insert(false);
        exit(DUoMVariantSetup);
    end;

    /// <summary>
    /// Elimina el registro DUoM Item Variant Setup para la variante indicada si existe.
    /// No produce error si el registro no existe.
    /// </summary>
    procedure DeleteVariantSetupIfExists(ItemNo: Code[20]; VariantCode: Code[10])
    var
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
    begin
        if DUoMVariantSetup.Get(ItemNo, VariantCode) then
            DUoMVariantSetup.Delete(false);
    end;

    /// <summary>
    /// Crea e inserta un registro DUoM Lot Ratio para el par (ItemNo, LotNo).
    /// Devuelve el registro insertado para su uso inmediato en el test.
    /// </summary>
    procedure CreateLotRatio(
        ItemNo: Code[20];
        LotNo: Code[50];
        ActualRatio: Decimal): Record "DUoM Lot Ratio"
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        DUoMLotRatio.Init();
        DUoMLotRatio."Item No." := ItemNo;
        DUoMLotRatio."Lot No." := LotNo;
        DUoMLotRatio."Actual Ratio" := ActualRatio;
        DUoMLotRatio.Insert(false);
        exit(DUoMLotRatio);
    end;

    /// <summary>
    /// Elimina el registro DUoM Lot Ratio para el par (ItemNo, LotNo) si existe.
    /// No produce error si el registro no existe.
    /// </summary>
    procedure DeleteLotRatioIfExists(ItemNo: Code[20]; LotNo: Code[50])
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        if DUoMLotRatio.Get(ItemNo, LotNo) then
            DUoMLotRatio.Delete(false);
    end;

    /// <summary>
    /// Asigna un Item Tracking Code con seguimiento de lotes al artículo indicado.
    /// Necesario para que BC 27 exija y procese el seguimiento de lote al contabilizar
    /// un Item Journal Line.
    ///
    /// Usa Library - Item Tracking (Tests-TestLibraries):
    ///   LibraryItemTracking.CreateItemTrackingCode(ItemTrackingCode, false, true)
    ///   crea un código con "Lot Specific Tracking" = true mediante el flujo estándar BC.
    ///   Cada llamada genera un código único con nombre aleatorio — patrón estándar BC
    ///   (los tests en bc-w1 / ALAppExtensions siguen esta misma convención). El código
    ///   queda en la transacción del test y se descarta con el rollback de TestIsolation.
    /// </summary>
    procedure EnableLotTrackingOnItem(var Item: Record Item)
    var
        ItemTrackingCode: Record "Item Tracking Code";
        LibraryItemTracking: Codeunit "Library - Item Tracking";
    begin
        LibraryItemTracking.CreateItemTrackingCode(ItemTrackingCode, false, true);
        Item.Validate("Item Tracking Code", ItemTrackingCode.Code);
        Item.Modify(true);
    end;

    /// <summary>
    /// Asigna seguimiento de lote a una Item Journal Line usando el flujo estándar BC 27.
    ///
    /// Usa Library - Item Tracking (Tests-TestLibraries):
    ///   LibraryItemTracking.CreateItemJournalLineItemTracking(ReservEntry, ItemJnlLine, SerialNo, LotNo, Qty)
    ///   crea la Reservation Entry (Surplus) a través del mismo mecanismo interno que BC
    ///   usa cuando se abren las Item Tracking Lines desde el diario.
    ///
    /// Convención de cantidad:
    ///   Qty debe ser POSITIVA y coincidir con la cantidad de la línea de diario.
    ///   La librería aplica el signo correcto automáticamente según Entry Type:
    ///   Purchase → +Qty en Reservation Entry; Sale → −Qty en Reservation Entry.
    ///   (Internamente: ItemJournalLine.Signed(Qty) determina el signo.)
    ///
    /// Parámetros:
    ///   ItemJnlLine — La línea de diario a la que asignar la trazabilidad de lote.
    ///   LotNo       — El número de lote a asignar.
    ///   Qty         — Cantidad positiva (user-facing), igual a ItemJnlLine.Quantity.
    /// </summary>
    procedure AssignLotToItemJnlLine(var ItemJnlLine: Record "Item Journal Line"; LotNo: Code[50]; Qty: Decimal)
    var
        LibraryItemTracking: Codeunit "Library - Item Tracking";
        ReservEntry: Record "Reservation Entry";
    begin
        LibraryItemTracking.CreateItemJournalLineItemTracking(ReservEntry, ItemJnlLine, '', LotNo, Qty);
    end;

    /// <summary>
    /// Crea una variante de artículo con el código específico indicado.
    /// Usa Library - Inventory.CreateItemVariant internamente (norma del proyecto)
    /// y después renombra al código deseado para mantener semántica de negocio
    /// determinista en los tests DUoM (p.ej. 'ROMANA', 'ICEBERG', 'GRANEL').
    /// Se justifica un helper propio porque LibraryInventory.CreateItemVariant genera
    /// un código aleatorio, pero los tests de variantes DUoM requieren códigos
    /// específicos con semántica funcional.
    /// </summary>
    procedure CreateItemVariantWithCode(ItemNo: Code[20]; VariantCode: Code[10]; var ItemVariant: Record "Item Variant")
    var
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        LibraryInventory.CreateItemVariant(ItemVariant, ItemNo);
        ItemVariant.Rename(ItemNo, VariantCode);
    end;

    /// <summary>
    /// Asigna un lote a una Purchase Line y escribe DUoM Ratio en la
    /// Reservation Entry correspondiente.
    ///
    /// Crea una Reservation Entry (como AssignLotToItemJnlLine para Item Journal
    /// Lines) con DUoM Ratio incluido, para que el mecanismo
    /// OnAfterCopyTrackingFromReservEntry → OnAfterCopyTrackingFromSpec
    /// lo propague al ILE durante la contabilización del pedido de compra.
    ///
    /// Justificación de implementación directa:
    ///   LibraryItemTracking.CreatePurchaseOrderItemTracking no existe en
    ///   Tests-TestLibraries 27.0.0.0; se opera directamente sobre
    ///   Reservation Entry.
    ///
    /// NOTA: No insertar en Tracking Specification desde tests.
    ///   BC construye ese buffer internamente desde Reservation Entry durante el
    ///   posting. El subscriber TrackingSpecCopyTrackingFromReservEntry (50110)
    ///   transporta DUoM Ratio de ReservEntry al buffer de TrackingSpec.
    ///   Insertar manualmente en TrackingSpec causa colisiones de Entry No.
    ///
    /// Parámetros:
    ///   PurchLine  — Purchase Line a la que asignar la trazabilidad de lote.
    ///   LotNo      — Número de lote a asignar.
    ///   Qty        — Cantidad positiva (inbound).
    ///   DUoMRatio  — Ratio DUoM a registrar en Reservation Entry.
    /// </summary>
    procedure AssignLotWithDUoMRatioToPurchLine(
        var PurchLine: Record "Purchase Line";
        LotNo: Code[50];
        Qty: Decimal;
        DUoMRatio: Decimal)
    var
        ReservEntry: Record "Reservation Entry";
        NextEntryNo: Integer;
    begin
        // Paso 1: Reservation Entry — asignación de lote con DUoM Ratio para que BC
        // reconozca el tracking durante el posting del pedido de compra y
        // TrackingSpecCopyTrackingFromReservEntry propague el ratio al buffer TrackingSpec.
        ReservEntry.LockTable();
        if ReservEntry.FindLast() then
            NextEntryNo := ReservEntry."Entry No." + 1
        else
            NextEntryNo := 1;
        ReservEntry.Init();
        ReservEntry."Entry No." := NextEntryNo;
        ReservEntry.Positive := true;
        ReservEntry."Item No." := PurchLine."No.";
        ReservEntry."Variant Code" := PurchLine."Variant Code";
        ReservEntry."Location Code" := PurchLine."Location Code";
        ReservEntry."Lot No." := LotNo;
        ReservEntry."Quantity (Base)" := Qty;
        ReservEntry."Qty. to Handle (Base)" := Qty;
        ReservEntry."Qty. to Invoice (Base)" := Qty;
        ReservEntry."Source Type" := Database::"Purchase Line";
        ReservEntry."Source Subtype" := PurchLine."Document Type".AsInteger();
        ReservEntry."Source ID" := PurchLine."Document No.";
        ReservEntry."Source Batch Name" := '';
        ReservEntry."Source Prod. Order Line" := 0;
        ReservEntry."Source Ref. No." := PurchLine."Line No.";
        ReservEntry."Reservation Status" := ReservEntry."Reservation Status"::Surplus;
        ReservEntry."DUoM Ratio" := DUoMRatio;
        ReservEntry."DUoM Second Qty" := Qty * DUoMRatio;
        ReservEntry.Insert(true);
    end;

    /// <summary>
    /// Asigna un lote a una Sales Line y escribe DUoM Ratio en la
    /// Reservation Entry correspondiente (entrada saliente / outbound).
    ///
    /// Análogo a AssignLotWithDUoMRatioToPurchLine pero para Sales Lines.
    /// Crea una Reservation Entry negativa (salida) con DUoM Ratio incluido.
    ///
    /// Parámetros:
    ///   SalesLine  — La línea de venta a la que asignar la trazabilidad de lote.
    ///   LotNo      — Número de lote a asignar.
    ///   Qty        — Cantidad positiva (user-facing); la ReservEntry almacena -Qty.
    ///   DUoMRatio  — Ratio DUoM a registrar en Reservation Entry.
    /// </summary>
    procedure AssignLotWithDUoMRatioToSalesLine(
        var SalesLine: Record "Sales Line";
        LotNo: Code[50];
        Qty: Decimal;
        DUoMRatio: Decimal)
    var
        ReservEntry: Record "Reservation Entry";
        NextEntryNo: Integer;
    begin
        ReservEntry.LockTable();
        if ReservEntry.FindLast() then
            NextEntryNo := ReservEntry."Entry No." + 1
        else
            NextEntryNo := 1;
        ReservEntry.Init();
        ReservEntry."Entry No." := NextEntryNo;
        ReservEntry.Positive := false;
        ReservEntry."Item No." := SalesLine."No.";
        ReservEntry."Variant Code" := SalesLine."Variant Code";
        ReservEntry."Location Code" := SalesLine."Location Code";
        ReservEntry."Lot No." := LotNo;
        ReservEntry."Quantity (Base)" := -Qty;
        ReservEntry."Qty. to Handle (Base)" := -Qty;
        ReservEntry."Qty. to Invoice (Base)" := -Qty;
        ReservEntry."Source Type" := Database::"Sales Line";
        ReservEntry."Source Subtype" := SalesLine."Document Type".AsInteger();
        ReservEntry."Source ID" := SalesLine."Document No.";
        ReservEntry."Source Batch Name" := '';
        ReservEntry."Source Prod. Order Line" := 0;
        ReservEntry."Source Ref. No." := SalesLine."Line No.";
        ReservEntry."Reservation Status" := ReservEntry."Reservation Status"::Surplus;
        ReservEntry."DUoM Ratio" := DUoMRatio;
        ReservEntry."DUoM Second Qty" := Qty * DUoMRatio;
        ReservEntry.Insert(true);
    end;
}
