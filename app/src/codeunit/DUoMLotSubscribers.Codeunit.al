/// <summary>
/// Suscriptores de eventos para la integración DUoM con lotes.
///
/// ARQUITECTURA N:1 — Modelo correcto de Business Central (Issue 20, refactorizado Issue 21):
///   DUoM no asume que 1 línea origen = 1 lote.
///   Una línea de documento BC puede tener N lotes asignados vía Item Tracking.
///   La ratio DUoM real es dato de lote/tracking, no dato de línea.
///   Los campos DUoM de la línea origen son totales agregados o derivados.
///
/// Mecanismo productivo principal — Patrón OnAfterCopyTracking* (Issue 23):
///   El flujo productivo de ILE CON Item Tracking sigue el patrón de Package Management (6516):
///   Tracking Specification → Item Journal Line → Item Ledger Entry.
///   Implementado en DUoM Tracking Copy Subscribers (50110).
///   DUoM Inventory Subscribers (50104) cubre el flujo SIN Item Tracking vía
///   OnAfterInitItemLedgEntry (restaurado en Issue 23, sin llamada a TryApplyLotRatioToILE).
///
/// NOTA — TryApplyLotRatioToILE (ya no se invoca desde el flujo de posting):
///   TryApplyLotRatioToILE ya no se invoca desde ningún subscriber de posting.
///   Se conserva exclusivamente para tests unitarios de bajo nivel (T12 en DUoMLotRatioTests).
///
/// Helper de utilidad (escenarios controlados de un único lote):
///   ApplyLotRatioToItemJournalLine: función pública para uso directo desde tests unitarios
///   de bajo nivel o escenarios donde se garantiza 1 línea = 1 lote (fuera del flujo
///   productivo principal). NO es el mecanismo de producción para N lotes.
///
/// Signatures verificadas BC 27 / runtime 15:
///   - Item Ledger Entry (tabla 32): DUoM Ratio y DUoM Second Qty vía tableextension 50113.
/// </summary>
codeunit 50108 "DUoM Lot Subscribers"
{
    Access = Public;

    /// <summary>
    /// UTILIDAD INTERNA — Escenarios controlados de un único lote.
    /// Aplica el ratio de lote a los campos DUoM de un Item Journal Line cuando
    /// se garantiza que la línea corresponde a exactamente un lote.
    ///
    /// ADVERTENCIA ARQUITECTÓNICA: Este método NO es el mecanismo productivo principal
    /// para la integración DUoM con lotes. En Business Central, una IJL puede tener N
    /// lotes asignados vía Item Tracking. Para el flujo productivo real, la ratio DUoM
    /// se aplica por lote en OnAfterInitItemLedgEntry → TryApplyLotRatioToILE.
    ///
    /// Uso legítimo: tests unitarios de bajo nivel que verifican la lógica interna
    /// del helper (T12 en DUoM Lot Ratio Tests). No usar como sustituto del flujo
    /// de posting estándar con Item Tracking.
    ///
    /// Devuelve true si se encontró y aplicó una ratio de lote; false en caso contrario.
    /// </summary>
    /// <param name="ItemJnlLine">Línea de diario a modificar (var — se sobrescriben DUoM Ratio y DUoM Second Qty).</param>
    procedure ApplyLotRatioToItemJournalLine(var ItemJnlLine: Record "Item Journal Line"): Boolean
    var
        NewRatio: Decimal;
        NewSecondQty: Decimal;
    begin
        if ItemJnlLine."Item No." = '' then
            exit(false);
        if ItemJnlLine."Lot No." = '' then
            exit(false);

        NewRatio := ItemJnlLine."DUoM Ratio";
        NewSecondQty := ItemJnlLine."DUoM Second Qty";

        if not TryApplyLotRatioIfExists(
            ItemJnlLine."Item No.",
            ItemJnlLine."Lot No.",
            ItemJnlLine."Variant Code",
            ItemJnlLine.Quantity,
            NewRatio,
            NewSecondQty)
        then
            exit(false);

        ItemJnlLine."DUoM Ratio" := NewRatio;
        ItemJnlLine."DUoM Second Qty" := NewSecondQty;
        exit(true);
    end;

    /// <summary>
    /// Aplica el ratio de lote específico al Item Ledger Entry durante la contabilización.
    ///
    /// NOTA: ya no es llamado desde el flujo de posting.
    /// El mecanismo productivo es el patrón OnAfterCopyTracking* en
    /// DUoM Tracking Copy Subscribers (50110). Se mantiene para tests de bajo nivel.
    /// </summary>
    /// <param name="ItemLedgEntry">ILE a modificar (var — se sobrescriben los campos DUoM).</param>
    /// <param name="ItemJournalLine">IJL del que se obtiene Item No., Lot No. y Variant Code.</param>
    procedure TryApplyLotRatioToILE(var ItemLedgEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        if ItemJournalLine."Lot No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 ItemJournalLine."Item No.", ItemJournalLine."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        TryApplyLotRatioToRecord(ItemJournalLine."Item No.", ItemJournalLine."Lot No.",
                                 ConversionMode, ItemLedgEntry.Quantity,
                                 ItemLedgEntry."DUoM Ratio", ItemLedgEntry."DUoM Second Qty");
    end;

    /// <summary>
    /// Resuelve el modo de conversión efectivo del artículo y delega a TryApplyLotRatioToRecord.
    /// Devuelve true si se encontró y aplicó una ratio de lote; false en caso contrario.
    /// </summary>
    local procedure TryApplyLotRatioIfExists(ItemNo: Code[20]; LotNo: Code[50]; VariantCode: Code[10]; Quantity: Decimal; var DUoMRatio: Decimal; var DUoMSecondQty: Decimal): Boolean
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        if ItemNo = '' then
            exit(false);
        if LotNo = '' then
            exit(false);
        if not DUoMSetupResolver.GetEffectiveSetup(ItemNo, VariantCode, SecondUoMCode, ConversionMode, FixedRatio) then
            exit(false);
        exit(TryApplyLotRatioToRecord(ItemNo, LotNo, ConversionMode, Quantity, DUoMRatio, DUoMSecondQty));
    end;

    /// <summary>
    /// Sobrescribe DUoM Ratio y DUoM Second Qty si existe un ratio registrado para el lote
    /// y el modo de conversión lo permite (Variable o AlwaysVariable).
    /// Fixed: el ratio fijo siempre prevalece — nunca se sobrescribe.
    /// Devuelve true si se aplicó el ratio de lote; false si no hay ratio o el modo es Fixed.
    /// </summary>
    local procedure TryApplyLotRatioToRecord(ItemNo: Code[20]; LotNo: Code[50]; ConversionMode: Enum "DUoM Conversion Mode"; Quantity: Decimal; var DUoMRatio: Decimal; var DUoMSecondQty: Decimal): Boolean
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        if ConversionMode = ConversionMode::Fixed then
            exit(false); // Modo Fixed: el ratio fijo siempre prevalece
        if not DUoMLotRatio.Get(ItemNo, LotNo) then
            exit(false); // Sin ratio para este lote: sin cambios
        DUoMRatio := DUoMLotRatio."Actual Ratio";
        // Recalcular usando la cantidad absoluta del registro destino
        DUoMSecondQty := Abs(Quantity) * DUoMLotRatio."Actual Ratio";
        exit(true);
    end;
}
