/// <summary>
/// Event subscribers for the Purchase flow in Dual Unit of Measure.
/// Reacts to Quantity changes on Purchase Lines to auto-compute the secondary
/// quantity via the DUoM Calc Engine, using the item's DUoM setup as the source
/// for the default conversion ratio.
/// </summary>
codeunit 50102 "DUoM Purchase Subscribers"
{
    Access = Internal;

    /// <summary>
    /// When Quantity is validated on a Purchase Line for an item with DUoM enabled,
    /// this subscriber computes and updates DUoM Second Qty using the effective ratio.
    /// The effective ratio is the line's DUoM Ratio if set, otherwise the item's Fixed Ratio.
    /// For AlwaysVariable mode, the subscriber exits without computing (user enters manually).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidatePurchLineQty(var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line")
    var
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        DUoMItemSetup: Record "DUoM Item Setup";
        EffectiveRatio: Decimal;
    begin
        if Rec.Type <> Rec.Type::Item then
            exit;
        if Rec."No." = '' then
            exit;
        if not DUoMItemSetup.Get(Rec."No.") then
            exit;
        if not DUoMItemSetup."Dual UoM Enabled" then
            exit;
        if DUoMItemSetup."Conversion Mode" = DUoMItemSetup."Conversion Mode"::AlwaysVariable then
            exit;

        // Use the line's ratio if already set; otherwise default from item setup
        EffectiveRatio := Rec."DUoM Ratio";
        if EffectiveRatio = 0 then begin
            EffectiveRatio := DUoMItemSetup."Fixed Ratio";
            if EffectiveRatio <> 0 then
                Rec."DUoM Ratio" := EffectiveRatio;
        end;

        Rec."DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQtyRounded(
            Rec.Quantity, EffectiveRatio, DUoMItemSetup."Conversion Mode",
            DUoMUoMHelper.GetSecondUoMRoundingPrecision(Rec."No."));
    end;
}
