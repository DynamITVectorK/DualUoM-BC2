/// <summary>
/// Extends the Sales Order Subform page to display the Dual Unit of Measure fields
/// (DUoM Second Qty and DUoM Ratio) on each sales line.
/// DUoM Second Qty is read-only in Fixed and Variable modes (computed automatically by the
/// subscriber on Quantity validation); it becomes editable only in AlwaysVariable mode,
/// where the user must enter the secondary quantity manually.
/// DUoM Ratio is always editable to allow per-line override in Variable mode.
/// </summary>
pageextension 50102 "DUoM Sales Order Subform" extends "Sales Order Subform"
{
    layout
    {
        addafter(Quantity)
        {
            field("DUoM Second Qty"; Rec."DUoM Second Qty")
            {
                ApplicationArea = All;
                Editable = IsDUoMSecondQtyEditable;
                ToolTip = DUoMSecondQtySalesToolTipLbl;
            }
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                ToolTip = DUoMRatioSalesToolTipLbl;
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
        DUoMSecondQtySalesToolTipLbl: Label 'Specifies the secondary quantity for this sales line in the second unit of measure. Computed automatically in Fixed and Variable modes; enter manually in Always Variable mode.', Comment = 'ToolTip for DUoM Second Qty field on Sales Order Subform; no placeholders.';
        DUoMRatioSalesToolTipLbl: Label 'Specifies the conversion ratio for this sales line. Overrides the item default when the item uses Variable conversion mode.', Comment = 'ToolTip for DUoM Ratio field on Sales Order Subform; no placeholders.';
}
