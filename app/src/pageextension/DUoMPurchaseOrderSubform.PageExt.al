/// <summary>
/// Extends the Purchase Order Subform page to display the Dual Unit of Measure fields
/// (DUoM Second Qty and DUoM Ratio) on each purchase line.
/// DUoM Second Qty is read-only in Fixed and Variable modes (computed automatically by the
/// subscriber on Quantity validation); it becomes editable only in AlwaysVariable mode,
/// where the user must enter the secondary quantity manually.
/// DUoM Ratio is always editable to allow per-line override in Variable mode.
/// </summary>
pageextension 50101 "DUoM Purchase Order Subform" extends "Purchase Order Subform"
{
    layout
    {
        addafter(Quantity)
        {
            field("DUoM Second Qty"; Rec."DUoM Second Qty")
            {
                ApplicationArea = All;
                Editable = false;
                Editable = IsDUoMSecondQtyEditable;
                ToolTip = DUoMSecondQtyPurchToolTipLbl;
            }
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                ToolTip = DUoMRatioPurchToolTipLbl;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        IsDUoMSecondQtyEditable := false;
        if Rec.Type = Rec.Type::Item then
            if DUoMItemSetup.Get(Rec."No.") then
                if DUoMItemSetup."Dual UoM Enabled" then
                    IsDUoMSecondQtyEditable :=
                        DUoMItemSetup."Conversion Mode" = DUoMItemSetup."Conversion Mode"::AlwaysVariable;
    end;

    var
        IsDUoMSecondQtyEditable: Boolean;
        DUoMSecondQtyPurchToolTipLbl: Label 'Specifies the secondary quantity for this purchase line in the second unit of measure. Computed automatically in Fixed and Variable modes; enter manually in Always Variable mode.', Comment = 'ToolTip for DUoM Second Qty field on Purchase Order Subform; no placeholders.';
        DUoMRatioPurchToolTipLbl: Label 'Specifies the conversion ratio for this purchase line. Overrides the item default when the item uses Variable conversion mode.', Comment = 'ToolTip for DUoM Ratio field on Purchase Order Subform; no placeholders.';
}
