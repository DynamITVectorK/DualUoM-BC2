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
    /// The effective setup is resolved via DUoM Setup Resolver, applying the Item → Variant
    /// hierarchy so that variant-level overrides take precedence.
    /// For Fixed mode, the setup ratio is always used (ignoring any stale line value).
    /// For Variable mode, the line's DUoM Ratio is used if already set by the user;
    /// otherwise the setup default is applied.
    /// For AlwaysVariable mode, any stale auto-computed ratio is cleared and the subscriber
    /// exits without computing — the user must enter DUoM Ratio and Second Qty manually.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidateSalesLineQty(var Rec: Record "Sales Line"; var xRec: Record "Sales Line")
    begin
        RecalculateSalesLineDUoM(Rec, false);
    end;

    /// <summary>
    /// When Variant Code is validated on a Sales Line for an item with DUoM enabled,
    /// this subscriber resets the DUoM fields and recomputes them using the effective
    /// setup for the new variant. This ensures the correct ratio and secondary quantity
    /// are applied when the variant changes on an existing line.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'Variant Code', false, false)]
    local procedure OnAfterValidateSalesLineVariantCode(var Rec: Record "Sales Line"; var xRec: Record "Sales Line")
    begin
        RecalculateSalesLineDUoM(Rec, true);
    end;

    // Publisher: Table "Sales Line" (37), event OnAfterValidateEvent, field "No.".
    // Motivo: al cambiar el artículo, DUoM Ratio y DUoM Second Qty deben recalcularse
    // en entrada de datos para preservar coherencia de la fuente de verdad documental.
    // Firma BC 27 validada: (var Rec: Record "Sales Line"; var xRec: Record "Sales Line").
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'No.', false, false)]
    local procedure OnAfterValidateSalesLineNo(var Rec: Record "Sales Line"; var xRec: Record "Sales Line")
    begin
        RecalculateSalesLineDUoM(Rec, true);
    end;

    // Publisher: Table "Sales Line" (37), event OnAfterValidateEvent, field "Unit of Measure Code".
    // Motivo: cambios de UoM pueden alterar la cantidad efectiva; se recalcula DUoM
    // en la línea para que el posting no tenga que reconstruir lógica de negocio.
    // Firma BC 27 validada: (var Rec: Record "Sales Line"; var xRec: Record "Sales Line").
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'Unit of Measure Code', false, false)]
    local procedure OnAfterValidateSalesLineUoMCode(var Rec: Record "Sales Line"; var xRec: Record "Sales Line")
    begin
        RecalculateSalesLineDUoM(Rec, true);
    end;

    /// <summary>
    /// Server-side DUoM coherence validation before posting.
    ///
    /// Publisher:  Codeunit "Sales-Post" (80), event OnPostItemJnlLineOnAfterCopyDocumentFields.
    /// Motivo:     Se ejecuta durante posting cuando Reservation Entry de tracking ya existe
    ///             y antes de crear ILE/Value Entry, permitiendo bloquear incoherencias.
    /// Firma BC 27 verificada: (var ItemJournalLine: Record "Item Journal Line";
    ///                          SalesLine: Record "Sales Line").
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post",
        'OnPostItemJnlLineOnAfterCopyDocumentFields', '', false, false)]
    local procedure OnSalesPostValidateDUoMTrackingCoherence(
        var ItemJournalLine: Record "Item Journal Line";
        SalesLine: Record "Sales Line")
    var
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        DUoMCoherenceMgt.ValidateSalesLineTrackingCoherence(SalesLine);
    end;

    local procedure RecalculateSalesLineDUoM(var SalesLine: Record "Sales Line"; ResetCurrentDUoM: Boolean)
    var
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        EffectiveRatio: Decimal;
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit;
        if SalesLine."No." = '' then
            exit;
        if ResetCurrentDUoM then begin
            SalesLine."DUoM Ratio" := 0;
            SalesLine."DUoM Second Qty" := 0;
        end;

        if not DUoMSetupResolver.GetEffectiveSetup(SalesLine."No.", SalesLine."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        if ConversionMode = ConversionMode::AlwaysVariable then
            exit;

        if ConversionMode = ConversionMode::Fixed then
            EffectiveRatio := FixedRatio
        else begin
            EffectiveRatio := SalesLine."DUoM Ratio";
            if EffectiveRatio = 0 then
                EffectiveRatio := FixedRatio;
        end;

        if EffectiveRatio <> 0 then
            SalesLine."DUoM Ratio" := EffectiveRatio;
        SalesLine."DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQtyRounded(
            SalesLine.Quantity, EffectiveRatio, ConversionMode,
            DUoMUoMHelper.GetRoundingPrecisionByUoMCode(SalesLine."No.", SecondUoMCode));
    end;
}
