/// <summary>
/// Event subscribers for the Inventory flow (Item Journal and Item Ledger Entry)
/// in Dual Unit of Measure.
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
    /// During Purchase posting, copies DUoM fields from the Purchase Line to the
    /// Purch. Rcpt. Line so that the posted receipt document contains the original
    /// DUoM data alongside the standard quantity.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnAfterInsertReceiptLine', '', false, false)]
    local procedure OnAfterInsertReceiptLine(var PurchRcptLine: Record "Purch. Rcpt. Line"; PurchLine: Record "Purchase Line")
    begin
        if (PurchLine."DUoM Second Qty" = 0) and (PurchLine."DUoM Ratio" = 0) then
            exit;
        PurchRcptLine."DUoM Second Qty" := PurchLine."DUoM Second Qty";
        PurchRcptLine."DUoM Ratio" := PurchLine."DUoM Ratio";
        PurchRcptLine.Modify(false);
    end;

    /// <summary>
    /// During Sales posting, copies DUoM fields from the Sales Line to the
    /// Sales Shipment Line so that the posted shipment document contains the original
    /// DUoM data alongside the standard quantity.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterInsertShipmentLine', '', false, false)]
    local procedure OnAfterInsertShipmentLine(var SalesShipmentLine: Record "Sales Shipment Line"; SalesLine: Record "Sales Line")
    begin
        if (SalesLine."DUoM Second Qty" = 0) and (SalesLine."DUoM Ratio" = 0) then
            exit;
        SalesShipmentLine."DUoM Second Qty" := SalesLine."DUoM Second Qty";
        SalesShipmentLine."DUoM Ratio" := SalesLine."DUoM Ratio";
        SalesShipmentLine.Modify(false);
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
