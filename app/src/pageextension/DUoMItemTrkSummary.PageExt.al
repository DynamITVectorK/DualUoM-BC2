/// <summary>
/// Extiende Item Tracking Summary ("Seg. productos - Selec. movs.") para mostrar
/// campos DUoM en la selección de movimientos y el total de segunda cantidad seleccionada.
/// </summary>
pageextension 50130 "DUoM Item Trk Summary" extends "Item Tracking Summary"
{
    layout
    {
        addafter("Selected Quantity")
        {
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the conversion ratio for this selected lot/serial movement line.', Comment = 'ToolTip for DUoM Ratio field in Item Tracking Summary; no placeholders.';
            }
            field("DUoM Second Qty"; Rec."DUoM Second Qty")
            {
                ApplicationArea = All;
                CaptionClass = DUoMSecondQtyCaption;
                Editable = false;
                ToolTip = 'Specifies the secondary quantity for this selected lot/serial movement line.', Comment = 'ToolTip for DUoM Second Qty field in Item Tracking Summary; no placeholders.';
            }
            field(DUoMDiagTableID; Rec."Table ID")
            {
                ApplicationArea = All;
                Visible = false;
            }
            field(DUoMDiagEntryNo; Rec."Entry No.")
            {
                ApplicationArea = All;
                Visible = false;
            }
            field(DUoMDiagTotalQty; Rec."Total Quantity")
            {
                ApplicationArea = All;
                Visible = false;
            }
            field(DUoMDiagSerialNo; Rec."Serial No.")
            {
                ApplicationArea = All;
                Visible = false;
            }
        }
        addlast(content)
        {
            group(DUoMSummary)
            {
                Caption = 'Dual UoM', Comment = 'Caption for DUoM summary group in Item Tracking Summary; no placeholders.';

                field(DUoMTotalSelectedSecondQty; DUoMTotalSelectedSecondQty)
                {
                    ApplicationArea = All;
                    CaptionClass = DUoMTotalSecondQtyCaption;
                    Editable = false;
                    ToolTip = 'Specifies the total secondary quantity currently selected across all movement lines.', Comment = 'ToolTip for DUoM selected total field in Item Tracking Summary; no placeholders.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
    begin
        DUoMEntrySummaryMgt.PopulateDUoMForEntrySummary(Rec);
    end;

    trigger OnAfterGetCurrRecord()
    var
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
    begin
        DUoMEntrySummaryMgt.PopulateDUoMForEntrySummary(Rec);
        RefreshCaptionsAndTotals();
    end;

    local procedure RefreshCaptionsAndTotals()
    begin
        UpdateSecondQtyCaption();
        UpdateSelectedSecondQtyTotal();
    end;

    local procedure UpdateSecondQtyCaption()
    var
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
        DUoMItemSetup: Record "DUoM Item Setup";
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
        ItemNo: Code[20];
        VariantCode: Code[10];
        SecondUoMCode: Code[10];
    begin
        DUoMSecondQtyCaption := '3,' + DUoMSecondQtyDefaultLbl;
        DUoMTotalSecondQtyCaption := '3,' + DUoMTotalSecondQtyDefaultLbl;

        if not DUoMEntrySummaryMgt.TryResolveItemContext(Rec, ItemNo, VariantCode) then
            exit;
        if not DUoMItemSetup.Get(ItemNo) then
            exit;
        if not DUoMItemSetup."Dual UoM Enabled" then
            exit;

        if (VariantCode <> '') and DUoMVariantSetup.Get(ItemNo, VariantCode) then
            SecondUoMCode := DUoMVariantSetup."Second UoM Code"
        else
            SecondUoMCode := DUoMItemSetup."Second UoM Code";

        if SecondUoMCode = '' then
            exit;

        DUoMSecondQtyCaption := '3,' + SecondUoMCode;
        DUoMTotalSecondQtyCaption := '3,' + DUoMTotalSecondQtyDefaultLbl + ' (' + SecondUoMCode + ')';
    end;

    local procedure UpdateSelectedSecondQtyTotal()
    var
        EntrySummary: Record "Entry Summary";
    begin
        DUoMTotalSelectedSecondQty := 0;
        EntrySummary.Copy(Rec, true);
        EntrySummary.Reset();
        if not EntrySummary.FindSet() then
            exit;

        repeat
            if EntrySummary."Selected Quantity" <> 0 then
                // En UI el total seleccionado se muestra como magnitud funcional,
                // independientemente del signo técnico interno del buffer.
                DUoMTotalSelectedSecondQty += Abs(EntrySummary."DUoM Second Qty");
        until EntrySummary.Next() = 0;
    end;

    var
        DUoMSecondQtyCaption: Text[30];
        DUoMTotalSecondQtyCaption: Text[80];
        DUoMTotalSelectedSecondQty: Decimal;
        DUoMSecondQtyDefaultLbl: Label 'DUoM Second Qty', Comment = 'Default caption for DUoM Second Qty in Item Tracking Summary when second UoM code is unavailable; no placeholders.';
        DUoMTotalSecondQtyDefaultLbl: Label 'DUoM Total Selected Qty', Comment = 'Default caption for DUoM selected total in Item Tracking Summary; no placeholders.';
}
