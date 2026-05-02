/// <summary>
/// Event subscribers for the Purchase flow in Dual Unit of Measure.
/// Reacts to Quantity and Variant Code changes on Purchase Lines to auto-compute
/// the secondary quantity via the DUoM Calc Engine, applying the effective DUoM
/// configuration resolved through the Item → Variant hierarchy (DUoM Setup Resolver).
///
/// Also provides a pre-posting server-side validation guard via
/// OnPostItemJnlLineOnAfterCopyDocumentFields in Codeunit "Purch.-Post" (90):
///   Before the Item Journal Line is processed and any Item Ledger Entry is created,
///   DUoM Tracking Coherence Mgt (50111) verifies that Reservation Entries for the
///   Purchase Line are coherent with the line's DUoM data.
///   Subscriber chosen: OnPostItemJnlLineOnAfterCopyDocumentFields fires once per
///   Purchase Line when the IJL is prepared — Reservation Entries are already in DB
///   (created when the user assigned lots via Item Tracking Lines) and the ILE has
///   not been created yet, making this the ideal server-side validation point.
///   Firma BC 27 verificada: (var ItemJournalLine, PurchaseLine: Record "Purchase Line").
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
    /// Server-side DUoM coherence validation before posting.
    ///
    /// Publisher:  Codeunit "Purch.-Post" (90), event OnPostItemJnlLineOnAfterCopyDocumentFields.
    /// Motivo:     Fires once per Purchase Line when the Item Journal Line fields are copied
    ///             from the Purchase Line — Reservation Entries are already in the database
    ///             (assigned during Item Tracking Lines) and no ILE has been created yet.
    ///             This is the ideal point to validate DUoM coherence server-side.
    /// Firma BC 27 verificada: (var ItemJournalLine: Record "Item Journal Line";
    ///                          PurchaseLine: Record "Purchase Line").
    ///             Confirmed against existing use of the same event in DUoM Inventory
    ///             Subscribers (50104) — OnPurchPostCopyDocFieldsToItemJnlLine.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post",
        'OnPostItemJnlLineOnAfterCopyDocumentFields', '', false, false)]
    local procedure OnPurchPostValidateDUoMTrackingCoherence(
        var ItemJournalLine: Record "Item Journal Line";
        PurchaseLine: Record "Purchase Line")
    var
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        DUoMCoherenceMgt.ValidatePurchLineTrackingCoherence(PurchaseLine);
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
