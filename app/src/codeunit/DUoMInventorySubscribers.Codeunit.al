/// <summary>
/// Event subscribers for the Inventory flow (Item Journal and Item Ledger Entry)
/// in Dual Unit of Measure.
///
/// Propagation strategy for posted document lines (BC 27 / runtime 15):
///   - Purchase Line → Purch. Rcpt. Line:
///     Subscriber to OnAfterInitFromPurchLine on Table "Purch. Rcpt. Line".
///     This is the standard initialization event called by Purch.-Post when building
///     the posted receipt line from the source purchase line. Signature verified against
///     microsoft/bc-w1 PurchRcptLine.Table.al.
///   - Sales Line → Sales Shipment Line:
///     Subscriber to OnAfterInitFromSalesLine on Table "Sales Shipment Line".
///     This is the standard initialization event called by Sales-Post when building
///     the posted shipment line from the source sales line. Signature verified against
///     microsoft/bc-w1 SalesShipmentLine.Table.al.
///   The actual field-copy logic is centralized in DUoM Doc Transfer Helper (50105).
///
/// Propagation strategy for ILE:
///   DUoM fields are populated on the Item Journal Line upstream:
///   - For Purchase posting: OnPostItemJnlLineOnAfterCopyDocumentFields (Purch.-Post)
///     copies DUoM fields from Purchase Line to Item Journal Line.
///   - For Sales posting: OnPostItemJnlLineOnAfterCopyDocumentFields (Sales-Post)
///     copies DUoM fields from Sales Line to Item Journal Line.
///   - For manual Item Journal postings: OnAfterValidateItemJnlLineQty auto-computes
///     DUoM fields when Quantity is validated through the UI.
///   OnAfterInitItemLedgEntry then copies the DUoM fields from the Item Journal Line
///   to the new ILE before Insert() — no Modify() call is needed.
/// </summary>
codeunit 50104 "DUoM Inventory Subscribers"
{
    Access = Internal;

    /// <summary>
    /// Reacts to Quantity changes on Item Journal Lines for items with DUoM enabled.
    /// Auto-computes DUoM Second Qty from the effective ratio (line ratio or item default).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidateItemJnlLineQty(var Rec: Record "Item Journal Line"; var xRec: Record "Item Journal Line")
    var
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
        DUoMItemSetup: Record "DUoM Item Setup";
        EffectiveRatio: Decimal;
    begin
        if Rec."Item No." = '' then
            exit;
        if not DUoMItemSetup.Get(Rec."Item No.") then
            exit;
        if not DUoMItemSetup."Dual UoM Enabled" then
            exit;
        if DUoMItemSetup."Conversion Mode" = DUoMItemSetup."Conversion Mode"::AlwaysVariable then
            exit;

        EffectiveRatio := Rec."DUoM Ratio";
        if EffectiveRatio = 0 then begin
            EffectiveRatio := DUoMItemSetup."Fixed Ratio";
            if EffectiveRatio <> 0 then
                Rec."DUoM Ratio" := EffectiveRatio;
        end;

        Rec."DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQty(Rec.Quantity, EffectiveRatio, DUoMItemSetup."Conversion Mode");
    end;

    /// <summary>
    /// During Purchase posting, copies DUoM fields from the Purchase Line to the
    /// Item Journal Line before it is posted, so that OnAfterInitItemLedgEntry
    /// can transfer them to the ILE without needing a Modify() call.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnPostItemJnlLineOnAfterCopyDocumentFields', '', false, false)]
    local procedure OnPurchPostCopyDocFieldsToItemJnlLine(var ItemJournalLine: Record "Item Journal Line"; PurchaseLine: Record "Purchase Line")
    begin
        ItemJournalLine."DUoM Second Qty" := PurchaseLine."DUoM Second Qty";
        ItemJournalLine."DUoM Ratio" := PurchaseLine."DUoM Ratio";
    end;

    /// <summary>
    /// During Sales posting, copies DUoM fields from the Sales Line to the
    /// Item Journal Line before it is posted, so that OnAfterInitItemLedgEntry
    /// can transfer them to the ILE without needing a Modify() call.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnPostItemJnlLineOnAfterCopyDocumentFields', '', false, false)]
    local procedure OnSalesPostCopyDocFieldsToItemJnlLine(var ItemJournalLine: Record "Item Journal Line"; SalesLine: Record "Sales Line")
    begin
        ItemJournalLine."DUoM Second Qty" := SalesLine."DUoM Second Qty";
        ItemJournalLine."DUoM Ratio" := SalesLine."DUoM Ratio";
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
    /// Initialises DUoM fields on the new Item Ledger Entry from the Item Journal Line
    /// before the ILE is inserted — no Modify() call is needed.
    /// Covers both Purchase/Sales posting paths (fields propagated via
    /// OnPostItemJnlLineOnAfterCopyDocumentFields) and manual Item Journal postings
    /// (fields populated by OnAfterValidateItemJnlLineQty).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', false, false)]
    local procedure OnAfterInitItemLedgEntry(var NewItemLedgEntry: Record "Item Ledger Entry"; var ItemJournalLine: Record "Item Journal Line"; var ItemLedgEntryNo: Integer)
    begin
        // Exit only when BOTH fields are zero — cases where one field is zero
        // (e.g., AlwaysVariable with no ratio, or Fixed mode with zero posted quantity
        // but a valid ratio) are correctly propagated.
        if (ItemJournalLine."DUoM Second Qty" = 0) and (ItemJournalLine."DUoM Ratio" = 0) then
            exit;
        NewItemLedgEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";
        NewItemLedgEntry."DUoM Ratio" := ItemJournalLine."DUoM Ratio";
    end;
}
