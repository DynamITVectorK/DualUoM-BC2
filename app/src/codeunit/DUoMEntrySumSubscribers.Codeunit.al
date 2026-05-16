/// <summary>
/// Suscriptores DUoM para Entry Summary usados por la página Item Tracking Summary.
/// Pre-rellena ratio por lote y recalcula cantidad secundaria al cambiar cantidad seleccionada.
/// </summary>
codeunit 50131 "DUoM Entry Sum Subscribers"
{
    Access = Internal;

    // Publisher: Table "Entry Summary" (338), Event: OnAfterValidateEvent, Field: Lot No.
    // Motivo: aplicar ratio DUoM por lote en la selección de movimientos.
    // Firma validada contra BC 27 Symbol Reference — 2026-05-16.
    [EventSubscriber(ObjectType::Table, Database::"Entry Summary", 'OnAfterValidateEvent', 'Lot No.', false, false)]
    local procedure OnAfterValidateEntrySummaryLotNo(var Rec: Record "Entry Summary"; var xRec: Record "Entry Summary")
    begin
        ApplyRatioToEntrySummary(Rec);
    end;

    // Publisher: Table "Entry Summary" (338), Event: OnAfterValidateEvent, Field: Serial No.
    // Motivo: recalcular ratio/cantidad DUoM cuando la selección se hace por serie.
    // Firma validada contra BC 27 Symbol Reference — 2026-05-16.
    [EventSubscriber(ObjectType::Table, Database::"Entry Summary", 'OnAfterValidateEvent', 'Serial No.', false, false)]
    local procedure OnAfterValidateEntrySummarySerialNo(var Rec: Record "Entry Summary"; var xRec: Record "Entry Summary")
    begin
        ApplyRatioToEntrySummary(Rec);
    end;

    // Publisher: Table "Entry Summary" (338), Event: OnAfterValidateEvent, Field: Selected Quantity
    // Motivo: mantener DUoM Second Qty coherente con la cantidad base seleccionada.
    // Firma validada contra BC 27 Symbol Reference — 2026-05-16.
    [EventSubscriber(ObjectType::Table, Database::"Entry Summary", 'OnAfterValidateEvent', 'Selected Quantity', false, false)]
    local procedure OnAfterValidateEntrySummarySelectedQty(var Rec: Record "Entry Summary"; var xRec: Record "Entry Summary")
    begin
        RecalcEntrySummarySecondQty(Rec);
    end;

    local procedure ApplyRatioToEntrySummary(var EntrySummary: Record "Entry Summary")
    var
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        DUoMLotRatio: Record "DUoM Lot Ratio";
        ItemNo: Code[20];
        VariantCode: Code[10];
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        RoundingPrecision: Decimal;
        AppliedRatio: Decimal;
    begin
        if not DUoMEntrySummaryMgt.TryResolveItemContext(EntrySummary, ItemNo, VariantCode) then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 ItemNo, VariantCode,
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        RoundingPrecision := GetEffectiveRoundingPrecision(ItemNo, SecondUoMCode);

        if ConversionMode = ConversionMode::Fixed then begin
            AppliedRatio := FixedRatio;
            EntrySummary."DUoM Ratio" := AppliedRatio;
            EntrySummary."DUoM Second Qty" := Round(
                GetSelectedQtyMagnitude(EntrySummary) * AppliedRatio,
                RoundingPrecision);
            exit;
        end;

        if EntrySummary."Lot No." = '' then
            exit;
        if not DUoMLotRatio.Get(ItemNo, EntrySummary."Lot No.") then
            exit;

        AppliedRatio := DUoMLotRatio."Actual Ratio";
        EntrySummary."DUoM Ratio" := AppliedRatio;
        EntrySummary."DUoM Second Qty" := Round(
            GetSelectedQtyMagnitude(EntrySummary) * AppliedRatio,
            RoundingPrecision);
    end;

    local procedure RecalcEntrySummarySecondQty(var EntrySummary: Record "Entry Summary")
    var
        DUoMEntrySummaryMgt: Codeunit "DUoM Entry Summary Mgt.";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        ItemNo: Code[20];
        VariantCode: Code[10];
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        RoundingPrecision: Decimal;
    begin
        if not DUoMEntrySummaryMgt.TryResolveItemContext(EntrySummary, ItemNo, VariantCode) then
            exit;
        if EntrySummary."DUoM Ratio" = 0 then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 ItemNo, VariantCode,
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        RoundingPrecision := GetEffectiveRoundingPrecision(ItemNo, SecondUoMCode);

        // En modo Fixed, garantizar coherencia del ratio antes de recalcular.
        if ConversionMode = ConversionMode::Fixed then
            EntrySummary."DUoM Ratio" := FixedRatio;

        EntrySummary."DUoM Second Qty" := Round(
            GetSelectedQtyMagnitude(EntrySummary) * EntrySummary."DUoM Ratio",
            RoundingPrecision);
    end;

    local procedure GetSelectedQtyMagnitude(EntrySummary: Record "Entry Summary"): Decimal
    begin
        exit(Abs(EntrySummary."Selected Quantity"));
    end;

    local procedure GetEffectiveRoundingPrecision(ItemNo: Code[20]; SecondUoMCode: Code[10]): Decimal
    var
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        RoundingPrecision: Decimal;
    begin
        RoundingPrecision := DUoMUoMHelper.GetRoundingPrecisionByUoMCode(ItemNo, SecondUoMCode);
        if RoundingPrecision <= 0 then
            exit(GetDefaultRoundingPrecision());
        exit(RoundingPrecision);
    end;

    local procedure GetDefaultRoundingPrecision(): Decimal
    begin
        exit(0.00001);
    end;
}
