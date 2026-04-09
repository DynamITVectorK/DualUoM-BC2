/// <summary>
/// Event subscribers for the Inventory flow (Item Journal and Item Ledger Entry)
/// in Dual Unit of Measure.
///
/// Propagation strategy for ILE:
///   1. For Item Journal postings (manual): DUoM fields are read directly from the
///      Item Journal Line parameter passed to OnAfterInsertItemLedgEntry.
///   2. For Purchase Receipt postings: the ILE Document Type is "Purchase Receipt";
///      the Purch. Rcpt. Line is used to trace back to the original Purchase Line,
///      from which the DUoM fields are copied.
///   3. For Sales Shipment postings: the ILE Document Type is "Sales Shipment";
///      the Sales Shipment Line is used to trace back to the original Sales Line.
///
/// This approach avoids global state and works within the same posting transaction.
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
    /// After an Item Ledger Entry is inserted, propagates DUoM fields from the source
    /// document (Purchase Line or Sales Line via posted lines) or from the Item Journal Line.
    /// Uses Document Type on the ILE to determine the source and performs a safe Get()
    /// to retrieve the original line — exits gracefully if the lookup fails.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInsertItemLedgEntry', '', false, false)]
    local procedure OnAfterInsertItemLedgEntry(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
        SalesShipmentLine: Record "Sales Shipment Line";
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        DUoMSecondQty: Decimal;
        DUoMRatio: Decimal;
        HasDUoM: Boolean;
    begin
        // Priority 1: Item Journal Line DUoM fields (covers manual item journal postings)
        if (ItemJournalLine."DUoM Second Qty" <> 0) or (ItemJournalLine."DUoM Ratio" <> 0) then begin
            DUoMSecondQty := ItemJournalLine."DUoM Second Qty";
            DUoMRatio := ItemJournalLine."DUoM Ratio";
            HasDUoM := true;
        end;

        // Priority 2: Trace through posted receipt/shipment lines to original order lines
        if not HasDUoM then
            case ItemLedgerEntry."Document Type" of
                ItemLedgerEntry."Document Type"::"Purchase Receipt":
                    if PurchRcptLine.Get(ItemLedgerEntry."Document No.", ItemLedgerEntry."Document Line No.") then
                        if PurchaseLine.Get(PurchaseLine."Document Type"::Order,
                                            PurchRcptLine."Order No.",
                                            PurchRcptLine."Order Line No.") then begin
                            DUoMSecondQty := PurchaseLine."DUoM Second Qty";
                            DUoMRatio := PurchaseLine."DUoM Ratio";
                            HasDUoM := true;
                        end;
                ItemLedgerEntry."Document Type"::"Sales Shipment":
                    if SalesShipmentLine.Get(ItemLedgerEntry."Document No.", ItemLedgerEntry."Document Line No.") then
                        if SalesLine.Get(SalesLine."Document Type"::Order,
                                         SalesShipmentLine."Order No.",
                                         SalesShipmentLine."Order Line No.") then begin
                            DUoMSecondQty := SalesLine."DUoM Second Qty";
                            DUoMRatio := SalesLine."DUoM Ratio";
                            HasDUoM := true;
                        end;
            end;

        if not HasDUoM then
            exit;
        if (DUoMSecondQty = 0) and (DUoMRatio = 0) then
            exit;

        ItemLedgerEntry."DUoM Second Qty" := DUoMSecondQty;
        ItemLedgerEntry."DUoM Ratio" := DUoMRatio;
        ItemLedgerEntry.Modify();
    end;
}
