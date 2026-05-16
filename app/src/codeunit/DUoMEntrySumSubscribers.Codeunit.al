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
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        DUoMLotRatio: Record "DUoM Lot Ratio";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        RoundingPrecision: Decimal;
        AppliedRatio: Decimal;
    begin
        if EntrySummary."Item No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 EntrySummary."Item No.", EntrySummary."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        RoundingPrecision := DUoMUoMHelper.GetRoundingPrecisionByUoMCode(
            EntrySummary."Item No.", SecondUoMCode);
        if RoundingPrecision <= 0 then
            RoundingPrecision := 0.00001;

        if ConversionMode = ConversionMode::Fixed then begin
            AppliedRatio := FixedRatio;
            EntrySummary."DUoM Ratio" := AppliedRatio;
            EntrySummary."DUoM Second Qty" := Round(
                Abs(EntrySummary."Selected Quantity") * AppliedRatio,
                RoundingPrecision);
            exit;
        end;

        if EntrySummary."Lot No." = '' then
            exit;
        if not DUoMLotRatio.Get(EntrySummary."Item No.", EntrySummary."Lot No.") then
            exit;

        AppliedRatio := DUoMLotRatio."Actual Ratio";
        EntrySummary."DUoM Ratio" := AppliedRatio;
        EntrySummary."DUoM Second Qty" := Round(
            Abs(EntrySummary."Selected Quantity") * AppliedRatio,
            RoundingPrecision);
    end;

    local procedure RecalcEntrySummarySecondQty(var EntrySummary: Record "Entry Summary")
    var
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        RoundingPrecision: Decimal;
    begin
        if EntrySummary."Item No." = '' then
            exit;
        if EntrySummary."DUoM Ratio" = 0 then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 EntrySummary."Item No.", EntrySummary."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        RoundingPrecision := DUoMUoMHelper.GetRoundingPrecisionByUoMCode(
            EntrySummary."Item No.", SecondUoMCode);
        if RoundingPrecision <= 0 then
            RoundingPrecision := 0.00001;

        EntrySummary."DUoM Second Qty" := Round(
            Abs(EntrySummary."Selected Quantity") * EntrySummary."DUoM Ratio",
            RoundingPrecision);
    end;
}
