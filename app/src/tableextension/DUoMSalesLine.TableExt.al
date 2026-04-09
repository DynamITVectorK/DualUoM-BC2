/// <summary>
/// Extends the Sales Line table with Dual Unit of Measure fields.
/// DUoM Second Qty holds the computed or user-entered secondary quantity.
/// DUoM Ratio holds the conversion ratio used on this specific line.
/// The OnValidate trigger on DUoM Ratio recomputes the secondary quantity immediately.
/// </summary>
tableextension 50111 "DUoM Sales Line Ext" extends "Sales Line"
{
    fields
    {
        field(50100; "DUoM Second Qty"; Decimal)
        {
            Caption = 'DUoM Second Qty';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the secondary quantity in the second unit of measure for this sales line.';
        }
        field(50101; "DUoM Ratio"; Decimal)
        {
            Caption = 'DUoM Ratio';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the conversion ratio used on this line (1 base UoM unit = DUoM Ratio second UoM units). Overrides the item default in Variable mode.';

            trigger OnValidate()
            var
                DUoMCalcEngine: Codeunit "DUoM Calc Engine";
                DUoMItemSetup: Record "DUoM Item Setup";
                Mode: Enum "DUoM Conversion Mode";
            begin
                if Rec.Type <> Rec.Type::Item then
                    exit;
                if not DUoMItemSetup.Get(Rec."No.") then
                    exit;
                if not DUoMItemSetup."Dual UoM Enabled" then
                    exit;
                Mode := DUoMItemSetup."Conversion Mode";
                if Mode = Mode::AlwaysVariable then
                    exit;
                "DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQty(Rec.Quantity, "DUoM Ratio", Mode);
            end;
        }
    }
}
