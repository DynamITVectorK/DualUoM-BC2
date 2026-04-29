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
///   Variable:          DUoM Ratio = ratio del lote si existe en DUoM Lot Ratio;
///                      si no existe, DUoM Ratio permanece sin cambios.
///   AlwaysVariable:    DUoM Ratio = ratio del lote si existe en DUoM Lot Ratio;
///                      si no existe, DUoM Ratio permanece sin cambios.
///
/// Patrón thin subscriber: los suscriptores validan condiciones de salida rápida
/// y delegan la lógica al helper centralizado (ApplyLotRatioToTrackingSpec,
/// RecalcTrackingSpecSecondQty). No hay lógica de negocio directamente en el suscriptor.
///
/// Propagación a Reservation Entry (RF-04):
///   La propagación directa desde Tracking Specification hacia Reservation Entry no se
///   implementa en este issue por falta de un evento seguro con los parámetros necesarios
///   en BC 27. Los campos DUoM en Reservation Entry quedan como limitación conocida y
///   serán abordados en una tarea futura N-lotes. La ratio real por lote se aplica
///   al ILE durante el posting vía TryApplyLotRatioToILE (DUoM Lot Subscribers, 50108).
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

    // Publisher: Table "Reservation Entry" (337), Event: OnAfterCopyTrackingFromTrackingSpec
    // Verificado contra BC 27 Symbol Reference — 2026-04-29
    // Motivo: propagar DUoM Second Qty y DUoM Ratio desde el buffer Tracking Specification
    // (tabla 6500) a la Reservation Entry persistida (tabla 337) en el momento en que
    // Item Tracking Lines confirma el volcado. El evento se publica en el procedimiento
    // ReservationEntry.CopyTrackingFromSpec(TrackingSpecification), que es el mecanismo
    // estándar BC para transferir datos de tracking del buffer al registro persistido.
    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry",
                     'OnAfterCopyTrackingFromTrackingSpec', '', false, false)]
    local procedure OnAfterCopyTrackingFromTrackingSpec(
        var ReservEntry: Record "Reservation Entry";
        TrackingSpecification: Record "Tracking Specification")
    begin
        ReservEntry."DUoM Second Qty" := TrackingSpecification."DUoM Second Qty";
        ReservEntry."DUoM Ratio" := TrackingSpecification."DUoM Ratio";
    end;

    /// <summary>
    /// Aplica la ratio DUoM correspondiente a los campos del Tracking Specification.
    /// En modo Fixed: aplica el ratio fijo del artículo/variante.
    /// En modo Variable/AlwaysVariable: aplica el ratio del lote si existe en DUoM Lot Ratio;
    /// si no existe, deja los campos DUoM sin cambios.
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
        if not DUoMLotRatio.Get(TrackingSpec."Item No.", TrackingSpec."Lot No.") then
            exit; // Sin ratio para este lote — campos DUoM sin cambios (T02).

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
}
