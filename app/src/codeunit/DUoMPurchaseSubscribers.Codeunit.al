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
    begin
        RecalculatePurchaseLineDUoM(Rec, false);
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
    begin
        RecalculatePurchaseLineDUoM(Rec, true);
    end;

    // Publisher: Table "Purchase Line" (39), event OnAfterValidateEvent, field "No.".
    // Motivo: al cambiar el artículo, DUoM Ratio y DUoM Second Qty deben recalcularse
    // en entrada de datos para que la línea quede coherente antes del posting.
    // Firma BC 27 validada: (var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line").
    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterValidateEvent', 'No.', false, false)]
    local procedure OnAfterValidatePurchLineNo(var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line")
    begin
        RecalculatePurchaseLineDUoM(Rec, true);
    end;

    // Publisher: Table "Purchase Line" (39), event OnAfterValidateEvent, field "Unit of Measure Code".
    // Motivo: cambios de UoM pueden alterar la cantidad efectiva de línea; se recalcula DUoM
    // para mantener fuente de verdad coherente en la propia línea documental.
    // Firma BC 27 validada: (var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line").
    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterValidateEvent', 'Unit of Measure Code', false, false)]
    local procedure OnAfterValidatePurchLineUoMCode(var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line")
    begin
        RecalculatePurchaseLineDUoM(Rec, true);
    end;

    local procedure RecalculatePurchaseLineDUoM(var PurchLine: Record "Purchase Line"; ResetCurrentDUoM: Boolean)
    var
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        EffectiveRatio: Decimal;
    begin
        if PurchLine.Type <> PurchLine.Type::Item then
            exit;
        if PurchLine."No." = '' then
            exit;
        if ResetCurrentDUoM then begin
            PurchLine."DUoM Ratio" := 0;
            PurchLine."DUoM Second Qty" := 0;
        end;

        if not DUoMSetupResolver.GetEffectiveSetup(PurchLine."No.", PurchLine."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        if ConversionMode = ConversionMode::AlwaysVariable then
            exit;

        if ConversionMode = ConversionMode::Fixed then
            EffectiveRatio := FixedRatio
        else begin
            EffectiveRatio := PurchLine."DUoM Ratio";
            if EffectiveRatio = 0 then
                EffectiveRatio := FixedRatio;
        end;

        if EffectiveRatio <> 0 then
            PurchLine."DUoM Ratio" := EffectiveRatio;
        PurchLine."DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQtyRounded(
            PurchLine.Quantity, EffectiveRatio, ConversionMode,
            DUoMUoMHelper.GetRoundingPrecisionByUoMCode(PurchLine."No.", SecondUoMCode));
    end;
}
