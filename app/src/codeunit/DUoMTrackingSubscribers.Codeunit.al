/// <summary>
/// Suscriptores de eventos para la integración DUoM con Item Tracking Lines.
///
/// Reacciona a la validación de Lot No. y Quantity (Base) en Tracking Specification
/// para auto-rellenar DUoM Ratio y recalcular DUoM Second Qty en el buffer de
/// Item Tracking Lines (tabla 6500).
///
/// Comportamiento por modo:
///   Fixed:             DUoM Ratio = Fixed Ratio del artículo/variante. El ratio de
///                      lote registrado en DUoM Lot Ratio (50102) NO sobreescribe.
///   Variable:          Prioridad de ratio:
///                        1. Ratio manual ya informado en Tracking Specification (≠ 0).
///                        2. DUoM Lot Ratio para Item/Lot si existe.
///                        3. DUoM Ratio de la Purchase Line origen (fallback) si DUoM Ratio = 0.
///                        4. Sin cambios si no hay ratio disponible.
///   AlwaysVariable:    Misma prioridad que Variable.
///
/// Patrón thin subscriber: los suscriptores validan condiciones de salida rápida
/// y delegan la lógica al helper centralizado (ApplyLotRatioToTrackingSpec,
/// RecalcTrackingSpecSecondQty). No hay lógica de negocio directamente en el suscriptor.
///
/// Signatures verificadas BC 27 / runtime 15:
///   - Tracking Specification (tabla 6500): OnAfterValidateEvent para Lot No. y
///     Quantity (Base) confirmados como eventos de campo directo en la tabla.
/// </summary>
codeunit 50109 "DUoM Tracking Subscribers"
{
    Access = Internal;

    // Publisher: Table "Tracking Specification" (6500), Event: OnAfterValidateEvent, Field: Lot No.
    // Verificado contra BC 27 Symbol Reference — 2026-04-29
    // Motivo: pre-rellenar DUoM Ratio al asignar lote en Item Tracking Lines
    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification",
                     'OnAfterValidateEvent', 'Lot No.', false, false)]
    local procedure OnAfterValidateTrackingSpecLotNo(
        var Rec: Record "Tracking Specification";
        var xRec: Record "Tracking Specification")
    begin
        if Rec."Item No." = '' then
            exit;
        if Rec."Lot No." = '' then
            exit;
        ApplyLotRatioToTrackingSpec(Rec);
    end;

    // Publisher: Table "Tracking Specification" (6500), Event: OnAfterValidateEvent, Field: Quantity (Base)
    // Verificado contra BC 27 Symbol Reference — 2026-04-29
    // Motivo: recalcular DUoM Second Qty cuando cambia la cantidad del lote
    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification",
                     'OnAfterValidateEvent', 'Quantity (Base)', false, false)]
    local procedure OnAfterValidateTrackingSpecQtyBase(
        var Rec: Record "Tracking Specification";
        var xRec: Record "Tracking Specification")
    begin
        if Rec."Item No." = '' then
            exit;
        if Rec."DUoM Ratio" = 0 then
            exit;
        RecalcTrackingSpecSecondQty(Rec);
    end;

    /// <summary>
    /// Aplica la ratio DUoM correspondiente a los campos del Tracking Specification.
    /// En modo Fixed: aplica el ratio fijo del artículo/variante.
    /// En modo Variable/AlwaysVariable: aplica el ratio del lote si existe en DUoM Lot Ratio;
    /// si no existe, usa el ratio de la Purchase Line origen como fallback cuando DUoM Ratio = 0;
    /// si tampoco hay Purchase Line con ratio, deja los campos DUoM sin cambios.
    /// </summary>
    local procedure ApplyLotRatioToTrackingSpec(var TrackingSpec: Record "Tracking Specification")
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
        if not DUoMSetupResolver.GetEffectiveSetup(
                 TrackingSpec."Item No.", TrackingSpec."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        RoundingPrecision := DUoMUoMHelper.GetRoundingPrecisionByUoMCode(
            TrackingSpec."Item No.", SecondUoMCode);
        if RoundingPrecision <= 0 then
            RoundingPrecision := 0.00001;

        if ConversionMode = ConversionMode::Fixed then begin
            // Modo Fixed: siempre usa el ratio fijo; el ratio de lote no aplica.
            AppliedRatio := FixedRatio;
            TrackingSpec."DUoM Ratio" := AppliedRatio;
            TrackingSpec."DUoM Second Qty" := Round(
                Abs(TrackingSpec."Quantity (Base)") * AppliedRatio, RoundingPrecision);
            exit;
        end;

        // Variable / AlwaysVariable: aplica el ratio del lote si existe.
        if not DUoMLotRatio.Get(TrackingSpec."Item No.", TrackingSpec."Lot No.") then begin
            // Sin ratio de lote para esta combinación artículo/lote:
            // - Si ya hay un ratio manual en la línea (≠ 0), no sobrescribir.
            // - Si DUoM Ratio = 0, intentar fallback desde la Purchase Line origen.
            if TrackingSpec."DUoM Ratio" = 0 then
                TryApplyPurchLineFallback(TrackingSpec, RoundingPrecision);
            exit;
        end;

        AppliedRatio := DUoMLotRatio."Actual Ratio";
        TrackingSpec."DUoM Ratio" := AppliedRatio;
        TrackingSpec."DUoM Second Qty" := Round(
            Abs(TrackingSpec."Quantity (Base)") * AppliedRatio, RoundingPrecision);
    end;

    /// <summary>
    /// Recalcula DUoM Second Qty usando el DUoM Ratio ya establecido en la línea de tracking.
    /// Llamado cuando cambia Quantity (Base) y DUoM Ratio ya está fijado.
    /// </summary>
    local procedure RecalcTrackingSpecSecondQty(var TrackingSpec: Record "Tracking Specification")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        RoundingPrecision: Decimal;
    begin
        if not DUoMSetupResolver.GetEffectiveSetup(
                 TrackingSpec."Item No.", TrackingSpec."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        RoundingPrecision := DUoMUoMHelper.GetRoundingPrecisionByUoMCode(
            TrackingSpec."Item No.", SecondUoMCode);
        if RoundingPrecision <= 0 then
            RoundingPrecision := 0.00001;

        TrackingSpec."DUoM Second Qty" := Round(
            Abs(TrackingSpec."Quantity (Base)") * TrackingSpec."DUoM Ratio", RoundingPrecision);
    end;

    /// <summary>
    /// Fallback: aplica el DUoM Ratio de la Purchase Line origen cuando no existe
    /// ratio de lote en DUoM Lot Ratio y DUoM Ratio de la línea de tracking es cero.
    ///
    /// Solo aplica cuando:
    ///   1. Source Type de la Tracking Specification es Purchase Line.
    ///   2. La Purchase Line origen existe en base de datos y tiene DUoM Ratio > 0.
    ///   3. DUoM Ratio en la Tracking Specification es 0 (sin ratio manual ni de lote previo).
    ///
    /// Prioridad de ratio: manual (≠ 0) > DUoM Lot Ratio > Purchase Line (este procedimiento).
    /// Publisher: invocado desde ApplyLotRatioToTrackingSpec al validar Lot No.
    /// Firma verificada: Purchase Line.Get(DocType, DocNo, LineNo) — BC 27 / runtime 15.
    /// </summary>
    local procedure TryApplyPurchLineFallback(
        var TrackingSpec: Record "Tracking Specification";
        RoundingPrecision: Decimal)
    var
        PurchLine: Record "Purchase Line";
    begin
        // Solo aplica cuando la fuente es una Purchase Line
        if TrackingSpec."Source Type" <> Database::"Purchase Line" then
            exit;

        // Intentar recuperar la Purchase Line origen por su clave primaria
        if not PurchLine.Get(
                "Purchase Document Type".FromInteger(TrackingSpec."Source Subtype"),
                TrackingSpec."Source ID",
                TrackingSpec."Source Ref. No.") then
            exit;

        // Si la Purchase Line no tiene ratio DUoM, no hay fallback disponible
        if PurchLine."DUoM Ratio" = 0 then
            exit;

        // Aplicar ratio de la Purchase Line como fallback
        TrackingSpec."DUoM Ratio" := PurchLine."DUoM Ratio";
        TrackingSpec."DUoM Second Qty" := Round(
            Abs(TrackingSpec."Quantity (Base)") * PurchLine."DUoM Ratio",
            RoundingPrecision);
    end;
}
