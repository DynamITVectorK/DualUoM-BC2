/// <summary>
/// Extends the Tracking Specification table (6500) with Dual Unit of Measure fields.
/// DUoM Second Qty holds the secondary quantity for this tracking entry, e.g. the
/// number of pieces (PCS) for a lot measured in KG as the primary unit.
/// DUoM Ratio holds the conversion ratio for this specific lot tracking entry and
/// determines how the secondary quantity is derived from the base quantity.
/// These fields are visible in Item Tracking Lines and provide the DUoM data for
/// lot-specific quantity assignments at document entry time.
///
/// Signatures verificadas BC 27 / runtime 15:
///   - Tracking Specification (table 6500): campos Lot No., Quantity (Base),
///     Item No., Variant Code confirmados como campos directos de la tabla.
/// </summary>
tableextension 50122 "DUoM Tracking Spec Ext" extends "Tracking Specification"
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
                DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
                DUoMUoMHelper: Codeunit "DUoM UoM Helper";
                SecondUoMCode: Code[10];
                Mode: Enum "DUoM Conversion Mode";
                FixedRatio: Decimal;
                RoundingPrecision: Decimal;
            begin
                if Rec."Item No." = '' then
                    exit;
                if not DUoMSetupResolver.GetEffectiveSetup(
                         Rec."Item No.", Rec."Variant Code",
                         SecondUoMCode, Mode, FixedRatio) then
                    exit;
                if Mode = Mode::AlwaysVariable then
                    // AlwaysVariable: este trigger genérico de DUoM Ratio no recalcula DUoM Second Qty,
                    // ya que en este modo el subscriber OnAfterValidateEvent 'Lot No.' aplica el ratio
                    // del lote automáticamente si existe en DUoM Lot Ratio, y el usuario puede además
                    // introducir DUoM Second Qty manualmente en la línea de tracking.
                    // Si el usuario edita DUoM Ratio directamente, el subscriber de 'Lot No.' no se activa;
                    // el recálculo manual queda a cargo del subscriber de 'Quantity (Base)'.
                    exit;
                RoundingPrecision := DUoMUoMHelper.GetRoundingPrecisionByUoMCode(
                    Rec."Item No.", SecondUoMCode);
                "DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQtyRounded(
                    Abs(Rec."Quantity (Base)"), "DUoM Ratio", Mode, RoundingPrecision);
            end;
        }
    }
}
