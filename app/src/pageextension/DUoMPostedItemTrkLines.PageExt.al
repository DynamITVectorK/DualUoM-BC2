/// <summary>
/// Extends Posted Item Tracking Lines (Page 6511) to display the DUoM fields
/// already persisted in Item Ledger Entry at posting time.
/// No calculation is performed — values are read directly from Rec.
/// SourceTable confirmed: Item Ledger Entry (32).
/// Pattern: identical to pageextension 50111 "DUoM Item Ledger Entry".
/// </summary>
pageextension 50124 "DUoM Posted Item Trk. Lines" extends "Posted Item Tracking Lines"
{
    layout
    {
        addafter(Quantity)
        {
            field("DUoM Second Qty"; Rec."DUoM Second Qty")
            {
                ApplicationArea = All;
                CaptionClass = DUoMSecondQtyCaption;
                Editable = false;
                ToolTip = 'Specifies the secondary quantity stored when this item ledger entry was posted.', Comment = 'ToolTip for DUoM Second Qty on Posted Item Tracking Lines; no placeholders.';
            }
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the conversion ratio stored when this item ledger entry was posted.', Comment = 'ToolTip for DUoM Ratio on Posted Item Tracking Lines; no placeholders.';
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        DUoMSecondQtyCaption := '3,' + DUoMSecondQtyDefaultLbl;
        if Rec."Item No." <> '' then
            if DUoMItemSetup.Get(Rec."Item No.") then
                if DUoMItemSetup."Dual UoM Enabled" then
                    if DUoMItemSetup."Second UoM Code" <> '' then
                        DUoMSecondQtyCaption := '3,' + DUoMItemSetup."Second UoM Code";
    end;

    var
        DUoMSecondQtyCaption: Text[30];
        DUoMSecondQtyDefaultLbl: Label 'DUoM Second Qty', Comment = 'Default column caption when no second UoM code is available; no placeholders.';
}
