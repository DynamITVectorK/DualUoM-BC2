/// <summary>
/// Extends the Item Ledger Entries page to display the Dual Unit of Measure fields
/// (DUoM Second Qty and DUoM Ratio) on each item ledger entry.
/// Both fields are read-only; item ledger entries are immutable after posting.
/// DUoM Second Qty shows the second unit of measure code as the column caption when available.
/// </summary>
pageextension 50111 "DUoM Item Ledger Entry" extends "Item Ledger Entries"
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
                ToolTip = 'Specifies the secondary quantity for this item ledger entry in the second unit of measure.', Comment = 'ToolTip for DUoM Second Qty field on Item Ledger Entries page; no placeholders.';
            }
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the conversion ratio used for this item ledger entry.', Comment = 'ToolTip for DUoM Ratio field on Item Ledger Entries page; no placeholders.';
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
        DUoMSecondQtyDefaultLbl: Label 'DUoM Second Qty', Comment = 'Default column caption for DUoM Second Qty when no second unit of measure code is available; no placeholders.';
}
