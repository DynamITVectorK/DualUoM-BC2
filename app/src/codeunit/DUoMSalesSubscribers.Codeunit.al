/// <summary>
/// Event subscribers for the Sales flow in Dual Unit of Measure.
/// Reacts to Quantity and Variant Code changes on Sales Lines to auto-compute
/// the secondary quantity via the DUoM Calc Engine, applying the effective DUoM
/// configuration resolved through the Item → Variant hierarchy (DUoM Setup Resolver).
/// </summary>
codeunit 50103 "DUoM Sales Subscribers"
{
    Access = Internal;

    /// <summary>
    /// When Quantity is validated on a Sales Line for an item with DUoM enabled,
    /// this subscriber computes and updates DUoM Second Qty using the effective ratio.
    /// The effective setup is resolved via DUoM Setup Resolver, which applies the
    /// Item → Variant hierarchy. The effective ratio is the line's DUoM Ratio if
    /// already set, otherwise the resolved Fixed Ratio from setup.
    /// For AlwaysVariable mode, the subscriber exits without computing (user enters manually).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidateSalesLineQty(var Rec: Record "Sales Line"; var xRec: Record "Sales Line")
    var
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        EffectiveRatio: Decimal;
    begin
        if Rec.Type <> Rec.Type::Item then
            exit;
        if Rec."No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(Rec."No.", Rec."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        if ConversionMode = ConversionMode::AlwaysVariable then
            exit;

        // Use the line's ratio if already set; otherwise default from effective setup.
        EffectiveRatio := Rec."DUoM Ratio";
        if EffectiveRatio = 0 then begin
            EffectiveRatio := FixedRatio;
            if EffectiveRatio <> 0 then
                Rec."DUoM Ratio" := EffectiveRatio;
        end;

        Rec."DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQtyRounded(
            Rec.Quantity, EffectiveRatio, ConversionMode,
            DUoMUoMHelper.GetRoundingPrecisionByUoMCode(Rec."No.", SecondUoMCode));
    end;

    /// <summary>
    /// When Variant Code is validated on a Sales Line for an item with DUoM enabled,
    /// this subscriber resets the DUoM fields and recomputes them using the effective
    /// setup for the new variant. This ensures the correct ratio and secondary quantity
    /// are applied when the variant changes on an existing line.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'Variant Code', false, false)]
    local procedure OnAfterValidateSalesLineVariantCode(var Rec: Record "Sales Line"; var xRec: Record "Sales Line")
    var
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        if Rec.Type <> Rec.Type::Item then
            exit;
        if Rec."No." = '' then
            exit;

        // Reset DUoM fields before recomputing for the new variant.
        Rec."DUoM Ratio" := 0;
        Rec."DUoM Second Qty" := 0;

        if not DUoMSetupResolver.GetEffectiveSetup(Rec."No.", Rec."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        if ConversionMode = ConversionMode::AlwaysVariable then
            exit;

        if FixedRatio <> 0 then
            Rec."DUoM Ratio" := FixedRatio;

        Rec."DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQtyRounded(
            Rec.Quantity, FixedRatio, ConversionMode,
            DUoMUoMHelper.GetRoundingPrecisionByUoMCode(Rec."No.", SecondUoMCode));
    end;
}
