/// <summary>
/// Extends the Sales Line table with Dual Unit of Measure fields.
/// DUoM Second Qty holds the computed or user-entered secondary quantity.
/// DUoM Ratio holds the conversion ratio used on this specific line.
/// DUoM Unit Price holds the unit price expressed in the second unit of measure.
/// The OnValidate trigger on DUoM Ratio recomputes the secondary quantity immediately,
/// using the effective DUoM setup resolved through the Item → Variant hierarchy.
/// The OnValidate trigger on DUoM Unit Price derives Unit Price when ratio ≠ 0.
/// The OnAfterValidate trigger on Unit Price recalculates DUoM Unit Price.
/// </summary>
tableextension 50111 "DUoM Sales Line Ext" extends "Sales Line"
{
    fields
    {
        field(50100; "DUoM Second Qty"; Decimal)
        {
            Caption = 'DUoM Second Qty', Comment = 'Caption for DUoM Second Qty field; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
                DUoMUoMHelper: Codeunit "DUoM UoM Helper";
                SecondUoMCode: Code[10];
                ConversionMode: Enum "DUoM Conversion Mode";
                FixedRatio: Decimal;
                RoundingPrecision: Decimal;
            begin
                if Rec.Type <> Rec.Type::Item then
                    exit;
                if not DUoMSetupResolver.GetEffectiveSetup(Rec."No.", Rec."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
                    exit;
                RoundingPrecision := DUoMUoMHelper.GetRoundingPrecisionByUoMCode(Rec."No.", SecondUoMCode);
                if RoundingPrecision > 0 then
                    "DUoM Second Qty" := Round("DUoM Second Qty", RoundingPrecision);
            end;
        }
        field(50101; "DUoM Ratio"; Decimal)
        {
            Caption = 'DUoM Ratio', Comment = 'Caption for DUoM Ratio field; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                DUoMCalcEngine: Codeunit "DUoM Calc Engine";
                DUoMUoMHelper: Codeunit "DUoM UoM Helper";
                DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
                SecondUoMCode: Code[10];
                Mode: Enum "DUoM Conversion Mode";
                FixedRatio: Decimal;
            begin
                if Rec.Type <> Rec.Type::Item then
                    exit;
                if not DUoMSetupResolver.GetEffectiveSetup(Rec."No.", Rec."Variant Code", SecondUoMCode, Mode, FixedRatio) then
                    exit;
                if Mode = Mode::AlwaysVariable then
                    exit;
                "DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQtyRounded(
                    Rec.Quantity, "DUoM Ratio", Mode,
                    DUoMUoMHelper.GetRoundingPrecisionByUoMCode(Rec."No.", SecondUoMCode));
            end;
        }
        field(50102; "DUoM Unit Price"; Decimal)
        {
            Caption = 'DUoM Unit Price', Comment = 'Caption for DUoM Unit Price field; no placeholders.';
            DecimalPlaces = 2 : 5;
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if Rec.Type <> Rec.Type::Item then
                    exit;
                if "DUoM Ratio" = 0 then
                    exit;
                Rec.Validate("Unit Price", "DUoM Unit Price" / "DUoM Ratio");
            end;
        }
        modify("Unit Price")
        {
            trigger OnAfterValidate()
            begin
                if Rec.Type <> Rec.Type::Item then
                    exit;
                if "DUoM Ratio" = 0 then
                    exit;
                "DUoM Unit Price" := Rec."Unit Price" * "DUoM Ratio";
            end;
        }
    }
}
