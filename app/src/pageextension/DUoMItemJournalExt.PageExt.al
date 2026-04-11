/// <summary>
/// Extends the Item Journal page to display the Dual Unit of Measure fields
/// (DUoM Second Qty and DUoM Ratio) on each item journal line.
/// DUoM Second Qty is read-only in Fixed and Variable modes (computed automatically by the
/// subscriber on Quantity validation); it becomes editable only in AlwaysVariable mode,
/// where the user must enter the secondary quantity manually.
/// DUoM Ratio is always editable to allow per-line override in Variable mode.
/// </summary>
pageextension 50103 "DUoM Item Journal Ext" extends "Item Journal"
{
    layout
    {
        addafter(Quantity)
        {
            field("DUoM Second Qty"; Rec."DUoM Second Qty")
            {
                ApplicationArea = All;
                Editable = IsDUoMSecondQtyEditable;
                ToolTip = 'Specifies the secondary quantity for this journal line in the second unit of measure. Computed automatically in Fixed and Variable modes; enter manually in Always Variable mode.', Comment = 'ToolTip for DUoM Second Qty field on Item Journal; no placeholders.';
            }
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the conversion ratio for this journal line. Overrides the item default when the item uses Variable conversion mode.', Comment = 'ToolTip for DUoM Ratio field on Item Journal; no placeholders.';
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        IsDUoMSecondQtyEditable := false;
        if Rec."Item No." <> '' then
            if DUoMItemSetup.Get(Rec."Item No.") then
                if DUoMItemSetup."Dual UoM Enabled" then
                    IsDUoMSecondQtyEditable :=
                        DUoMItemSetup."Conversion Mode" = DUoMItemSetup."Conversion Mode"::AlwaysVariable;
    end;

    var
        IsDUoMSecondQtyEditable: Boolean;
}
