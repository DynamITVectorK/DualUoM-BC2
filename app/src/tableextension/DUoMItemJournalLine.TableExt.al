/// <summary>
/// Extends the Item Journal Line table with Dual Unit of Measure fields.
/// DUoM Second Qty holds the secondary quantity for manual item journal entries
/// and serves as the propagation vehicle between purchase/sales lines and ILE during posting.
/// DUoM Ratio holds the conversion ratio used on this journal line.
/// </summary>
tableextension 50112 "DUoM Item Journal Line Ext" extends "Item Journal Line"
{
    fields
    {
        field(50100; "DUoM Second Qty"; Decimal)
        {
            Caption = 'DUoM Second Qty';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
        field(50101; "DUoM Ratio"; Decimal)
        {
            Caption = 'DUoM Ratio';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                DUoMCalcEngine: Codeunit "DUoM Calc Engine";
                DUoMItemSetup: Record "DUoM Item Setup";
                Mode: Enum "DUoM Conversion Mode";
            begin
                if Rec."Item No." = '' then
                    exit;
                if not DUoMItemSetup.Get(Rec."Item No.") then
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
