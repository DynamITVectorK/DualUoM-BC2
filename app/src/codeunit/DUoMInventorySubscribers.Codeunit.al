/// <summary>
/// Event subscribers for the Inventory flow (Item Journal and Item Ledger Entry)
/// in Dual Unit of Measure.
///
/// Propagation strategy for posted document lines (BC 27 / runtime 15):
///   - Purchase Line → Purch. Rcpt. Line:
///     Subscriber to OnAfterInitFromPurchLine on Table "Purch. Rcpt. Line".
///     Signature verified against microsoft/bc-w1 PurchRcptLine.Table.al.
///   - Purchase Line → Purch. Inv. Line:
///     Subscriber to OnAfterInitFromPurchLine on Table "Purch. Inv. Line".
///     Signature verified against microsoft/bc-w1 PurchInvLine.Table.al.
///   - Purchase Line → Purch. Cr. Memo Line:
///     Subscriber to OnAfterInitFromPurchLine on Table "Purch. Cr. Memo Line".
///     Signature verified against microsoft/bc-w1 PurchCrMemoLine.Table.al.
///   - Sales Line → Sales Shipment Line:
///     Subscriber to OnAfterInitFromSalesLine on Table "Sales Shipment Line".
///     Signature verified against microsoft/bc-w1 SalesShipmentLine.Table.al.
///   - Sales Line → Sales Invoice Line:
///     Subscriber to OnAfterInitFromSalesLine on Table "Sales Invoice Line".
///     Signature verified against microsoft/bc-w1 SalesInvoiceLine.Table.al.
///     NOTE: var SalesInvLine is the FIRST parameter (unlike Purchase pattern).
///   - Sales Line → Sales Cr.Memo Line:
///     Subscriber to OnAfterInitFromSalesLine on Table "Sales Cr.Memo Line".
///     Signature verified against microsoft/bc-w1 SalesCrMemoLine.Table.al.
///     NOTE: var SalesCrMemoLine is the FIRST parameter (unlike Purchase pattern).
///   The actual field-copy logic is centralized in DUoM Doc Transfer Helper (50105).
///
/// Propagation strategy for ILE:
///   Two parallel mechanisms cover both paths.
///
///   SIN Item Tracking (artículos sin lotes / sin trazabilidad activa):
///     Purch.-Post OnBeforeItemJnlPostLine → Purchase Line → IJL  (Qty ya asignada)
///     Sales-Post OnPostItemJnlLineOnAfterCopyDocumentFields → Sales Line → IJL  (Qty ya asignada)
///     OnAfterCopyItemJnlLineFromPurchRcpt / OnAfterCopyItemJnlLineFromSalesShpt → flujo undo
///     OnAfterInitItemLedgEntry → ILE ← IJL  (ratio + DUoM Second Qty con signo normalizado)
///     Este subscriber siempre se dispara, con o sin tracking activo.
///
///   CON Item Tracking (por lote, BC llama CopyTrackingFromItemJnlLine solo cuando hay Lot/Serial):
///     ReservEntry → TrackingSpec (OnAfterCopyTrackingFromReservEntry, codeunit 50110)
///     OnAfterCopyTrackingFromSpec → TrackingSpec → IJL  (refinamiento por lote)
///     OnAfterInitItemLedgEntry → ILE ← IJL  (ratio + DUoM Second Qty con signo normalizado)
///     OnAfterCopyTrackingFromItemJnlLine → IJL → ILE  (codeunit 50110, ratio + signo normalizado)
///     Orden garantizado BC 27: OnAfterInitItemLedgEntry se ejecuta ANTES de
///     ILECopyTrackingFromItemJnlLine.
///
///   NORMA FINAL: Item Journal Line es la fuente de ratio y magnitud DUoM para Item Ledger Entry
///   y Value Entry, pero el signo final de DUoM Second Qty se normaliza contra ILE.Quantity.
///   Los subscribers de esta capa no recalculan ratio ni consultan tablas.
///
/// Estrategia de propagación para Value Entry:
///   OnAfterInitValueEntry en Codeunit "Item Jnl.-Post Line" (BC 27 / runtime 15)
///   copia la magnitud DUoM Second Qty desde Item Journal Line al nuevo Value Entry
///   antes de Insert() y normaliza el signo contra ItemLedgEntry.Quantity.
///   Firma verificada: (var ValueEntry; var ItemJournalLine; var ValueEntryNo; var ItemLedgEntry).
/// </summary>
codeunit 50104 "DUoM Inventory Subscribers"
{
    Access = Internal;

    /// <summary>
    /// Reacts to Quantity changes on Item Journal Lines for items with DUoM enabled.
    /// Auto-computes DUoM Second Qty from the effective ratio, applying the
    /// Item → Variant hierarchy via DUoM Setup Resolver.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidateItemJnlLineQty(var Rec: Record "Item Journal Line"; var xRec: Record "Item Journal Line")
    var
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        EffectiveRatio: Decimal;
    begin
        if Rec."Item No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(Rec."Item No.", Rec."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        if ConversionMode = ConversionMode::AlwaysVariable then
            exit;

        EffectiveRatio := Rec."DUoM Ratio";
        if EffectiveRatio = 0 then begin
            EffectiveRatio := FixedRatio;
            if EffectiveRatio <> 0 then
                Rec."DUoM Ratio" := EffectiveRatio;
        end;

        Rec."DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQty(Rec.Quantity, EffectiveRatio, ConversionMode);
    end;

    /// <summary>
    /// Durante el registro de compras, proyecta los campos DUoM de la Purchase Line
    /// al Item Journal Line justo antes de que se ejecute RunItemJnlPostLine.
    ///
    /// Publisher: Codeunit "Purch.-Post" (90), evento OnBeforeItemJnlPostLine.
    /// Motivo: OnBeforeItemJnlPostLine se dispara DESPUÉS de que BC asigna
    ///   ItemJnlLine.Quantity := QtyToBeReceived y ItemJnlLine."Quantity (Base)" := QtyToBeReceivedBase.
    ///   El evento anterior OnPostItemJnlLineOnAfterCopyDocumentFields se dispara
    ///   ANTES de esa asignación, por lo que la cantidad de posting era siempre 0
    ///   y CalcProjectedSecondQty devolvía 0 (bug de proyección).
    /// Firma BC 27 confirmada: (var ItemJournalLine; PurchaseLine; PurchaseHeader; CommitIsSupressed;
    ///   var IsHandled; WhseReceiptHeader; WhseShipmentHeader;
    ///   TempItemChargeAssignmentPurch temp; TempWarehouseReceiptHeader temp;
    ///   PurchInvHeader; PurchCrMemoHeader)
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforeItemJnlPostLine', '', false, false)]
    local procedure OnPurchPostCopyDocFieldsToItemJnlLine(var ItemJournalLine: Record "Item Journal Line"; PurchaseLine: Record "Purchase Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.ProjectPurchLineToItemJnlLine(PurchaseLine, ItemJournalLine);
    end;

    /// <summary>
    /// Durante el registro de ventas, proyecta los campos DUoM de la Sales Line
    /// al Item Journal Line justo antes de que se ejecute RunItemJnlPostLine.
    ///
    /// Publisher: Codeunit "Sales-Post" (80), evento OnPostItemJnlLineOnAfterCopyDocumentFields.
    /// Motivo: en Sales-Post, este evento se dispara DESPUÉS de que BC asigna
    ///   ItemJnlLine.Quantity := -QtyToBeShipped y ItemJnlLine."Quantity (Base)" := -QtyToBeShippedBase.
    ///   Por tanto, la cantidad de posting ya tiene el signo técnico de salida negativo,
    ///   y ApplyItemJnlSign produce correctamente DUoM Second Qty negativo en el IJL.
    /// Firma BC 27 confirmada: (var ItemJournalLine; SalesLine; WarehouseReceiptHeader; WarehouseShipmentHeader)
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnPostItemJnlLineOnAfterCopyDocumentFields', '', false, false)]
    local procedure OnSalesPostCopyDocFieldsToItemJnlLine(var ItemJournalLine: Record "Item Journal Line"; SalesLine: Record "Sales Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.ProjectSalesLineToItemJnlLine(SalesLine, ItemJournalLine);
    end;

    /// <summary>
    /// Durante la anulación de un albarán de compra (Undo Purchase Receipt), copia los
    /// campos DUoM desde la Purch. Rcpt. Line al Item Journal Line antes del posting.
    ///
    /// Responsabilidad: preparar el IJL con DUoM Ratio y DUoM Second Qty correctos para
    /// artículos SIN trazabilidad de lote/serie. Para artículos CON trazabilidad, el flujo
    /// OnAfterCopyTrackingFromItemLedgEntry (codeunit 50110) ya popula los valores per-lote
    /// desde el ILE original; el guard en este subscriber evita sobrescribir esos valores.
    ///
    /// Para artículos sin tracking se preasigna el signo esperado en el IJL; la capa ILE
    /// lo vuelve a normalizar contra NewItemLedgEntry.Quantity como garantía final.
    ///
    /// Publisher: Codeunit "Undo Purchase Receipt Line".
    /// Evento: OnAfterCopyItemJnlLineFromPurchRcpt.
    /// Motivo: único punto donde el IJL está disponible junto a la PurchRcptLine
    ///         antes de la contabilización del asiento de corrección.
    /// Firma verificada en BC 27 / runtime 15 (UndoPurchaseReceiptLine.Codeunit.al).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Undo Purchase Receipt Line",
        'OnAfterCopyItemJnlLineFromPurchRcpt', '', false, false)]
    local procedure OnAfterCopyItemJnlLineFromPurchRcpt(
        var ItemJournalLine: Record "Item Journal Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        var PurchRcptLine: Record "Purch. Rcpt. Line";
        var WhseUndoQty: Codeunit "Whse. Undo Quantity";
        var ItemLedgEntryNo: Integer;
        var NextLineNo: Integer;
        var TempWhseJnlLine: Record "Warehouse Journal Line" temporary;
        var TempGlobalItemLedgerEntry: Record "Item Ledger Entry" temporary;
        var TempGlobalItemEntryRelation: Record "Item Entry Relation" temporary;
        var IsHandled: Boolean)
    begin
        // Guard: en el flujo undo con trazabilidad de lote/serie, BC llama
        // CopyTrackingFromItemLedgEntry antes de este evento, lo que dispara
        // IJLCopyTrackingFromItemLedgEntry (50110) y popula los valores DUoM per-lote
        // directamente del ILE original. Verificar el Lot No. / Serial No. es más
        // explícito y robusto que inferirlo del estado del campo DUoM Ratio.
        if (ItemJournalLine."Lot No." <> '') or (ItemJournalLine."Serial No." <> '') then
            exit;
        if PurchRcptLine."DUoM Ratio" = 0 then
            exit;
        ItemJournalLine."DUoM Ratio" := PurchRcptLine."DUoM Ratio";
        // La corrección invierte la recepción original (Qty > 0) → ILE corrección con Qty < 0.
        // OnAfterInitItemLedgEntry (50104) normaliza de nuevo contra el signo real del ILE.
        ItemJournalLine."DUoM Second Qty" := -Abs(PurchRcptLine."DUoM Second Qty");
    end;

    /// <summary>
    /// Durante la anulación de un albarán de venta (Undo Sales Shipment), copia los
    /// campos DUoM desde la Sales Shipment Line al Item Journal Line antes del posting.
    ///
    /// Responsabilidad: preparar el IJL con DUoM Ratio y DUoM Second Qty correctos para
    /// artículos SIN trazabilidad de lote/serie. Para artículos CON trazabilidad, el flujo
    /// OnAfterCopyTrackingFromItemLedgEntry (codeunit 50110) ya popula los valores per-lote
    /// desde el ILE original; el guard en este subscriber evita sobrescribir esos valores.
    ///
    /// Para artículos sin tracking se preasigna el signo esperado en el IJL; la capa ILE
    /// lo vuelve a normalizar contra NewItemLedgEntry.Quantity como garantía final.
    ///
    /// Publisher: Codeunit "Undo Sales Shipment Line".
    /// Evento: OnAfterCopyItemJnlLineFromSalesShpt.
    /// Motivo: único punto donde el IJL está disponible junto a la SalesShipmentLine
    ///         antes de la contabilización del asiento de corrección.
    /// Firma verificada en BC 27 / runtime 15 (UndoSalesShipmentLine.Codeunit.al).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Undo Sales Shipment Line",
        'OnAfterCopyItemJnlLineFromSalesShpt', '', false, false)]
    local procedure OnAfterCopyItemJnlLineFromSalesShpt(
        var ItemJournalLine: Record "Item Journal Line";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesShipmentLine: Record "Sales Shipment Line";
        var TempWhseJnlLine: Record "Warehouse Journal Line" temporary;
        var WhseUndoQty: Codeunit "Whse. Undo Quantity";
        var ItemLedgEntryNo: Integer;
        var NextLineNo: Integer;
        var TempGlobalItemLedgerEntry: Record "Item Ledger Entry" temporary;
        var TempGlobalItemEntryRelation: Record "Item Entry Relation" temporary;
        var IsHandled: Boolean)
    begin
        // Guard: en el flujo undo con trazabilidad de lote/serie, BC llama
        // CopyTrackingFromItemLedgEntry antes de este evento, lo que dispara
        // IJLCopyTrackingFromItemLedgEntry (50110) y popula los valores DUoM per-lote
        // directamente del ILE original. Verificar el Lot No. / Serial No. es más
        // explícito y robusto que inferirlo del estado del campo DUoM Ratio.
        if (ItemJournalLine."Lot No." <> '') or (ItemJournalLine."Serial No." <> '') then
            exit;
        if SalesShipmentLine."DUoM Ratio" = 0 then
            exit;
        ItemJournalLine."DUoM Ratio" := SalesShipmentLine."DUoM Ratio";
        // La corrección invierte el envío original (Qty < 0) → ILE corrección con Qty > 0.
        // OnAfterInitItemLedgEntry (50104) normaliza de nuevo contra el signo real del ILE.
        ItemJournalLine."DUoM Second Qty" := Abs(SalesShipmentLine."DUoM Second Qty");
    end;

    /// <summary>
    /// Durante la contabilización de compra, copia los campos DUoM desde la Purchase Line
    /// a la Purch. Rcpt. Line en el momento de la inicialización del registro de destino.
    /// Evento: OnAfterInitFromPurchLine en la tabla "Purch. Rcpt. Line" (BC 27 / runtime 15).
    /// Firma verificada en microsoft/bc-w1: PurchRcptLine.Table.al, procedure InitFromPurchLine.
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Purch. Rcpt. Line", 'OnAfterInitFromPurchLine', '', false, false)]
    local procedure OnAfterInitFromPurchLine(PurchRcptHeader: Record "Purch. Rcpt. Header"; PurchLine: Record "Purchase Line"; var PurchRcptLine: Record "Purch. Rcpt. Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromPurchLineToPurchRcptLine(PurchLine, PurchRcptLine);
    end;

    /// <summary>
    /// Durante la contabilización de venta, copia los campos DUoM desde la Sales Line
    /// a la Sales Shipment Line en el momento de la inicialización del registro de destino.
    /// Evento: OnAfterInitFromSalesLine en la tabla "Sales Shipment Line" (BC 27 / runtime 15).
    /// Firma verificada en microsoft/bc-w1: SalesShipmentLine.Table.al, procedure InitFromSalesLine.
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Sales Shipment Line", 'OnAfterInitFromSalesLine', '', false, false)]
    local procedure OnAfterInitFromSalesLine(SalesShptHeader: Record "Sales Shipment Header"; SalesLine: Record "Sales Line"; var SalesShptLine: Record "Sales Shipment Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromSalesLineToShipLine(SalesLine, SalesShptLine);
    end;

    /// <summary>
    /// Durante la contabilización de compra como factura, copia los campos DUoM desde la
    /// Purchase Line a la Purch. Inv. Line en el momento de la inicialización del registro.
    /// Evento: OnAfterInitFromPurchLine en la tabla "Purch. Inv. Line" (BC 27 / runtime 15).
    /// Publisher: Table "Purch. Inv. Line", evento elegido porque es la inicialización
    /// estándar de la línea de factura registrada desde la línea de compra origen.
    /// Firma verificada en FBakkensen/bc-w1: PurchInvLine.Table.al, procedure InitFromPurchLine
    /// → OnAfterInitFromPurchLine(PurchInvHeader, PurchLine, Rec).
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Purch. Inv. Line", 'OnAfterInitFromPurchLine', '', false, false)]
    local procedure OnAfterInitFromPurchInvLine(PurchInvHeader: Record "Purch. Inv. Header"; PurchLine: Record "Purchase Line"; var PurchInvLine: Record "Purch. Inv. Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromPurchLineToPurchInvLine(PurchLine, PurchInvLine);
    end;

    /// <summary>
    /// Durante la contabilización de un abono de compra, copia los campos DUoM desde la
    /// Purchase Line a la Purch. Cr. Memo Line en el momento de la inicialización del registro.
    /// Evento: OnAfterInitFromPurchLine en la tabla "Purch. Cr. Memo Line" (BC 27 / runtime 15).
    /// Publisher: Table "Purch. Cr. Memo Line", evento elegido porque es la inicialización
    /// estándar de la línea de abono registrado desde la línea de compra origen.
    /// Firma verificada en FBakkensen/bc-w1: PurchCrMemoLine.Table.al, procedure InitFromPurchLine
    /// → OnAfterInitFromPurchLine(PurchCrMemoHdr, PurchLine, Rec).
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Purch. Cr. Memo Line", 'OnAfterInitFromPurchLine', '', false, false)]
    local procedure OnAfterInitFromPurchCrMemoLine(PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr."; PurchLine: Record "Purchase Line"; var PurchCrMemoLine: Record "Purch. Cr. Memo Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromPurchLineToPurchCrMemoLine(PurchLine, PurchCrMemoLine);
    end;

    /// <summary>
    /// Durante la contabilización de venta como factura, copia los campos DUoM desde la
    /// Sales Line a la Sales Invoice Line en el momento de la inicialización del registro.
    /// Evento: OnAfterInitFromSalesLine en la tabla "Sales Invoice Line" (BC 27 / runtime 15).
    /// Publisher: Table "Sales Invoice Line", evento elegido porque es la inicialización
    /// estándar de la línea de factura registrada desde la línea de venta origen.
    /// Firma verificada en FBakkensen/bc-w1: SalesInvoiceLine.Table.al, procedure InitFromSalesLine
    /// → OnAfterInitFromSalesLine(var SalesInvLine, SalesInvHeader, SalesLine).
    /// IMPORTANTE: el parámetro var es el PRIMERO en Sales (distinto del patrón Purchase).
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Sales Invoice Line", 'OnAfterInitFromSalesLine', '', false, false)]
    local procedure OnAfterInitFromSalesInvLine(var SalesInvLine: Record "Sales Invoice Line"; SalesInvHeader: Record "Sales Invoice Header"; SalesLine: Record "Sales Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromSalesLineToSalesInvLine(SalesLine, SalesInvLine);
    end;

    /// <summary>
    /// Durante la contabilización de un abono de venta, copia los campos DUoM desde la
    /// Sales Line a la Sales Cr.Memo Line en el momento de la inicialización del registro.
    /// Evento: OnAfterInitFromSalesLine en la tabla "Sales Cr.Memo Line" (BC 27 / runtime 15).
    /// Publisher: Table "Sales Cr.Memo Line", evento elegido porque es la inicialización
    /// estándar de la línea de abono registrado desde la línea de venta origen.
    /// Firma verificada en FBakkensen/bc-w1: SalesCrMemoLine.Table.al, procedure InitFromSalesLine
    /// → OnAfterInitFromSalesLine(var SalesCrMemoLine, SalesCrMemoHeader, SalesLine).
    /// IMPORTANTE: el parámetro var es el PRIMERO en Sales (distinto del patrón Purchase).
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Sales Cr.Memo Line", 'OnAfterInitFromSalesLine', '', false, false)]
    local procedure OnAfterInitFromSalesCrMemoLine(var SalesCrMemoLine: Record "Sales Cr.Memo Line"; SalesCrMemoHeader: Record "Sales Cr.Memo Header"; SalesLine: Record "Sales Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromSalesLineToSalesCrMemoLine(SalesLine, SalesCrMemoLine);
    end;

    /// <summary>
    /// Propaga los campos DUoM desde Item Journal Line hacia Item Ledger Entry.
    /// Copia el ratio desde la Item Journal Line y normaliza el signo de DUoM Second Qty
    /// contra NewItemLedgEntry.Quantity, que es la verdad final del movimiento.
    /// La Item Journal Line debe llegar ya preparada por los flujos upstream:
    /// Purchase/Sales posting, tracking split, undo o diarios.
    ///
    /// Este subscriber cubre el flujo SIN Item Tracking (artículos sin lotes):
    ///   OnAfterCopyTrackingFromItemJnlLine (codeunit 50110) no se dispara cuando
    ///   BC no llama CopyTrackingFromItemJnlLine() porque no hay tracking activo.
    ///
    /// Para artículos CON Item Tracking (Lot No. / Serial No.):
    ///   ILECopyTrackingFromItemJnlLine (codeunit 50110) se dispara después de este
    ///   subscriber y sobreescribe con la copia pura desde el IJL split por lote.
    ///
    /// Publisher: Codeunit "Item Jnl.-Post Line", evento OnAfterInitItemLedgEntry.
    /// Firma verificada en BC 27 / runtime 15 (ItemJnlPostLine.Codeunit.al).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', false, false)]
    local procedure OnAfterInitItemLedgEntry(var NewItemLedgEntry: Record "Item Ledger Entry"; var ItemJournalLine: Record "Item Journal Line"; var ItemLedgEntryNo: Integer)
    begin
        NewItemLedgEntry."DUoM Ratio" := ItemJournalLine."DUoM Ratio";
        NewItemLedgEntry."DUoM Second Qty" := NormalizeSecondQtySignForILE(
            NewItemLedgEntry, ItemJournalLine."DUoM Second Qty");
    end;

    /// <summary>
    /// Propaga DUoM Second Qty desde Item Journal Line hacia Value Entry.
    /// La fuente de magnitud para Value Entry es Item Journal Line, pero el signo se
    /// normaliza contra ItemLedgEntry.Quantity para mantener coherencia con el ILE.
    ///
    /// Publisher: Codeunit "Item Jnl.-Post Line", evento OnAfterInitValueEntry.
    /// Firma verificada en BC 27 / runtime 15 (ItemJnlPostLine.Codeunit.al):
    ///   OnAfterInitValueEntry(var ValueEntry; var ItemJnlLine; var ValueEntryNo; var ItemLedgEntry).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitValueEntry', '', false, false)]
    local procedure OnAfterInitValueEntry(var ValueEntry: Record "Value Entry"; var ItemJournalLine: Record "Item Journal Line"; var ValueEntryNo: Integer; var ItemLedgEntry: Record "Item Ledger Entry")
    begin
        ValueEntry."DUoM Second Qty" := NormalizeSecondQtySignForILE(
            ItemLedgEntry, ItemJournalLine."DUoM Second Qty");
    end;

    local procedure NormalizeSecondQtySignForILE(ItemLedgerEntry: Record "Item Ledger Entry"; SecondQty: Decimal): Decimal
    begin
        if SecondQty = 0 then
            exit(0);
        if ItemLedgerEntry.Quantity < 0 then
            exit(-Abs(SecondQty));
        if ItemLedgerEntry.Quantity > 0 then
            exit(Abs(SecondQty));
        exit(SecondQty);
    end;
}
