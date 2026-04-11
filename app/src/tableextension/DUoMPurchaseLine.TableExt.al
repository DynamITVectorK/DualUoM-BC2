/// <summary>
/// Extends the Purchase Line table with Dual Unit of Measure fields.
/// DUoM Second Qty holds the computed or user-entered secondary quantity.
/// DUoM Ratio holds the conversion ratio used on this specific line, which may
/// differ from the item-level default in Variable conversion mode.
/// The OnValidate trigger on DUoM Ratio recomputes the secondary quantity immediately.
/// </summary>
tableextension 50110 "DUoM Purchase Line Ext" extends "Purchase Line"
{
    fields
    {
        field(50100; "DUoM Second Qty"; Decimal)
        {
            Caption = 'DUoM Second Qty', Comment = 'Caption for DUoM Second Qty field; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
        field(50101; "DUoM Ratio"; Decimal)
        {
            Caption = 'DUoM Ratio', Comment = 'Caption for DUoM Ratio field; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;

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
