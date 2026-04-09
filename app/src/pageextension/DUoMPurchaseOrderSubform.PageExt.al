/// <summary>
/// Extends the Purchase Order Subform page to display the Dual Unit of Measure fields
/// (DUoM Second Qty and DUoM Ratio) on each purchase line.
/// DUoM Ratio is editable to allow per-line override in Variable conversion mode.
/// DUoM Second Qty is read-only when the item uses Fixed or Variable mode (computed
/// automatically); editable when the item uses Always Variable mode.
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
                ToolTip = 'Specifies the secondary quantity for this purchase line in the second unit of measure.';
            }
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the conversion ratio for this purchase line. Overrides the item default when the item uses Variable conversion mode.';
            }
        }
    }
}
