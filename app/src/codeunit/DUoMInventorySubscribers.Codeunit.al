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
///     OnPostItemJnlLineOnAfterCopyDocumentFields → Purchase/Sales Line → IJL  (ya existe)
///     OnAfterCopyItemJnlLineFromPurchRcpt / OnAfterCopyItemJnlLineFromSalesShpt → flujo undo
///     OnAfterInitItemLedgEntry → ILE ← IJL  (copia pura de campos DUoM)
///     Este subscriber siempre se dispara, con o sin tracking activo.
///
///   CON Item Tracking (por lote, BC llama CopyTrackingFromItemJnlLine solo cuando hay Lot/Serial):
///     ReservEntry → TrackingSpec (OnAfterCopyTrackingFromReservEntry, codeunit 50110)
///     OnAfterCopyTrackingFromSpec → TrackingSpec → IJL  (refinamiento por lote)
///     OnAfterInitItemLedgEntry → ILE ← IJL  (copia pura de campos DUoM)
///     OnAfterCopyTrackingFromItemJnlLine → IJL → ILE  (codeunit 50110, copia pura)
///     Orden garantizado BC 27: OnAfterInitItemLedgEntry se ejecuta ANTES de
///     ILECopyTrackingFromItemJnlLine.
///
///   NORMA FINAL: Item Journal Line es la fuente final para Item Ledger Entry y Value Entry.
///   OnAfterInitItemLedgEntry y OnAfterInitValueEntry son copias puras desde Item Journal Line.
///   Si Item Journal Line llega con DUoM incorrecto, el bug está upstream.
///   Los subscribers de esta capa no calculan ratio, no aplican signo ni consultan tablas.
///
/// Estrategia de propagación para Value Entry:
///   OnAfterInitValueEntry en Codeunit "Item Jnl.-Post Line" (BC 27 / runtime 15)
///   copia DUoM Second Qty directamente desde Item Journal Line al nuevo Value Entry
///   antes de Insert() — no se copia desde Item Ledger Entry.
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
    /// During Purchase posting, copies DUoM fields from the Purchase Line to the
    /// Item Journal Line before it is posted, so that DUoM Tracking Copy Subscribers
    /// (50110) can transfer them to the ILE via OnAfterCopyTrackingFromItemJnlLine.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnPostItemJnlLineOnAfterCopyDocumentFields', '', false, false)]
    local procedure OnPurchPostCopyDocFieldsToItemJnlLine(var ItemJournalLine: Record "Item Journal Line"; PurchaseLine: Record "Purchase Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.ProjectPurchLineToItemJnlLine(PurchaseLine, ItemJournalLine);
    end;

    /// <summary>
    /// During Sales posting, copies DUoM fields from the Sales Line to the
    /// Item Journal Line before it is posted, so that DUoM Tracking Copy Subscribers
    /// (50110) can transfer them to the ILE via OnAfterCopyTrackingFromItemJnlLine.
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
    /// El IJL debe llegar con el signo correcto porque OnAfterInitItemLedgEntry (50104)
    /// es una copia pura: no aplica signo ni normaliza. El signo negativo indica que
    /// la corrección invierte la recepción original (ILE corrección con Qty < 0).
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
        // OnAfterInitItemLedgEntry (50104) es copia pura; el IJL debe llegar con el signo correcto.
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
    /// El IJL debe llegar con el signo correcto porque OnAfterInitItemLedgEntry (50104)
    /// es una copia pura: no aplica signo ni normaliza. El signo positivo indica que
    /// la corrección invierte el envío original (ILE corrección con Qty > 0).
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
        // OnAfterInitItemLedgEntry (50104) es copia pura; el IJL debe llegar con el signo correcto.
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
    /// Este subscriber no calcula ratio, no aplica signo y no recupera datos de otras tablas.
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
        NewItemLedgEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";
    end;

    /// <summary>
    /// Propaga DUoM Second Qty desde Item Journal Line hacia Value Entry.
    /// La fuente final de DUoM para Value Entry es Item Journal Line.
    /// No copiar desde Item Ledger Entry ni recalcular signo en este evento.
    ///
    /// Publisher: Codeunit "Item Jnl.-Post Line", evento OnAfterInitValueEntry.
    /// Firma verificada en BC 27 / runtime 15 (ItemJnlPostLine.Codeunit.al):
    ///   OnAfterInitValueEntry(var ValueEntry; var ItemJnlLine; var ValueEntryNo; var ItemLedgEntry).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitValueEntry', '', false, false)]
    local procedure OnAfterInitValueEntry(var ValueEntry: Record "Value Entry"; var ItemJournalLine: Record "Item Journal Line"; var ValueEntryNo: Integer; var ItemLedgEntry: Record "Item Ledger Entry")
    begin
        ValueEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";
    end;
}
