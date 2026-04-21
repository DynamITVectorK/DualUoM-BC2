/// <summary>
/// Extiende la tabla Sales Line con campos de Unidad de Medida Dual.
/// DUoM Second Qty almacena la cantidad secundaria calculada o introducida por el usuario.
/// DUoM Ratio almacena la proporción de conversión utilizada en esta línea concreta.
/// DUoM Unit Price almacena el precio unitario expresado en la segunda unidad de medida.
/// El trigger OnValidate de DUoM Ratio recalcula inmediatamente la cantidad secundaria,
/// usando la configuración efectiva de DUoM resuelta mediante la jerarquía Item → Variante.
/// El trigger OnValidate de DUoM Unit Price deriva Unit Price cuando la proporción ≠ 0.
/// El trigger OnAfterValidate de Unit Price recalcula DUoM Unit Price.
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
