/// <summary>
/// Event subscribers for the Purchase flow in Dual Unit of Measure.
/// Reacts to Quantity and Variant Code changes on Purchase Lines to auto-compute
/// the secondary quantity via the DUoM Calc Engine, applying the effective DUoM
/// configuration resolved through the Item → Variant hierarchy (DUoM Setup Resolver).
/// </summary>
codeunit 50102 "DUoM Purchase Subscribers"
{
    Access = Internal;

    /// <summary>
    /// When Quantity is validated on a Purchase Line for an item with DUoM enabled,
    /// this subscriber computes and updates DUoM Second Qty using the effective ratio.
    /// The effective setup is resolved via DUoM Setup Resolver, applying the Item → Variant
    /// hierarchy so that variant-level overrides take precedence.
    /// For Fixed mode, the setup ratio is always used (ignoring any stale line value).
    /// For Variable mode, the line's DUoM Ratio is used if already set by the user;
    /// otherwise the setup default is applied.
    /// For AlwaysVariable mode, any stale auto-computed ratio is cleared and the subscriber
    /// exits without computing — the user must enter DUoM Ratio and Second Qty manually.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidatePurchLineQty(var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line")
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
        if ConversionMode = ConversionMode::AlwaysVariable then begin
            // AlwaysVariable: clear any stale auto-computed values; user must enter manually.
            Rec."DUoM Ratio" := 0;
            Rec."DUoM Second Qty" := 0;
            exit;
        end;

        // For Fixed mode, always use the setup ratio (variant-aware via GetEffectiveSetup).
        // For Variable mode, use the line's pre-set ratio if available; otherwise the setup default.
        if ConversionMode = ConversionMode::Fixed then
            EffectiveRatio := FixedRatio
        else begin
            EffectiveRatio := Rec."DUoM Ratio";
            if EffectiveRatio = 0 then
                EffectiveRatio := FixedRatio;
        end;
        if EffectiveRatio <> 0 then
            Rec."DUoM Ratio" := EffectiveRatio;

        Rec."DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQtyRounded(
            Rec.Quantity, EffectiveRatio, ConversionMode,
            DUoMUoMHelper.GetRoundingPrecisionByUoMCode(Rec."No.", SecondUoMCode));
    end;

    /// <summary>
    /// When Variant Code is validated on a Purchase Line for an item with DUoM enabled,
    /// this subscriber resets the DUoM fields and recomputes them using the effective
    /// setup for the new variant. This ensures the correct ratio and secondary quantity
    /// are applied when the variant changes on an existing line.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterValidateEvent', 'Variant Code', false, false)]
    local procedure OnAfterValidatePurchLineVariantCode(var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line")
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
