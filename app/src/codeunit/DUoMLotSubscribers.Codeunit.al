/// <summary>
/// Suscriptores de eventos para la integración DUoM con lotes.
///
/// Caso A — Item Journal Line (Lot No. es campo directo en tabla 83):
///   Suscriptor OnAfterValidateEvent[Lot No.] en Table "Item Journal Line".
///   Cuando el usuario valida Lot No. en un IJL, pre-rellena DUoM Ratio y
///   DUoM Second Qty desde DUoM Lot Ratio (50102) si existe registro para
///   (Item No., Lot No.) y el modo de conversión no es Fixed.
///
/// Caso B — Purchase/Sales Line (N lotes vía Item Tracking, Lot No. no es campo
///   directo en tabla 39/37 en BC 27):
///   La asignación de lotes persiste en Reservation Entry (flujo estándar).
///   Al contabilizar, BC crea un ILE por lote con Lot No. específico en el IJL.
///   DUoM Inventory Subscribers (50104) llama a TryApplyLotRatioToILE desde
///   OnAfterInitItemLedgEntry para aplicar el ratio de lote al ILE.
///
/// Signatures verificadas BC 27 / runtime 15:
///   - Item Journal Line (tabla 83): Lot No. (field 5407) es campo directo.
///   - Item Ledger Entry (tabla 32): DUoM Ratio y DUoM Second Qty vía tableextension 50113.
/// </summary>
codeunit 50108 "DUoM Lot Subscribers"
{
    Access = Internal;

    /// <summary>
    /// Pre-rellena DUoM Ratio y DUoM Second Qty en un Item Journal Line cuando el
    /// usuario valida el campo Lot No.
    /// Publisher: Table "Item Journal Line" (tabla 83), campo Lot No. (field 5407).
    /// Evento elegido: OnAfterValidateEvent, porque Lot No. ES campo directo en IJL
    /// (a diferencia de Purchase Line y Sales Line donde no es campo directo en BC 27).
    /// Firma verificada: BC 27 / runtime 15 — Item Journal Line tiene Lot No. como campo propio.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterValidateEvent', 'Lot No.', false, false)]
    local procedure OnAfterValidateItemJnlLineLotNo(var Rec: Record "Item Journal Line"; var xRec: Record "Item Journal Line")
    begin
        ApplyLotRatioIfExists(Rec."Item No.", Rec."Lot No.", Rec."Variant Code",
                              Rec.Quantity, Rec."DUoM Ratio", Rec."DUoM Second Qty");
    end;

    /// <summary>
    /// Aplica el ratio de lote específico al Item Ledger Entry durante la contabilización.
    /// Llamado desde DUoM Inventory Subscribers (50104) en OnAfterInitItemLedgEntry
    /// para sobrescribir DUoM Ratio y DUoM Second Qty con el ratio real del lote.
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
        ApplyLotRatioToRecord(ItemJournalLine."Item No.", ItemJournalLine."Lot No.",
                              ConversionMode, ItemLedgEntry.Quantity,
                              ItemLedgEntry."DUoM Ratio", ItemLedgEntry."DUoM Second Qty");
    end;

    /// <summary>
    /// Resuelve el modo de conversión efectivo del artículo y delega a ApplyLotRatioToRecord.
    /// </summary>
    local procedure ApplyLotRatioIfExists(ItemNo: Code[20]; LotNo: Code[50]; VariantCode: Code[10]; Quantity: Decimal; var DUoMRatio: Decimal; var DUoMSecondQty: Decimal)
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        if ItemNo = '' then
            exit;
        if LotNo = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(ItemNo, VariantCode, SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        ApplyLotRatioToRecord(ItemNo, LotNo, ConversionMode, Quantity, DUoMRatio, DUoMSecondQty);
    end;

    /// <summary>
    /// Sobrescribe DUoM Ratio y DUoM Second Qty si existe un ratio registrado para el lote
    /// y el modo de conversión lo permite (Variable o AlwaysVariable).
    /// Fixed: el ratio fijo siempre prevalece — nunca se sobrescribe.
    /// </summary>
    local procedure ApplyLotRatioToRecord(ItemNo: Code[20]; LotNo: Code[50]; ConversionMode: Enum "DUoM Conversion Mode"; Quantity: Decimal; var DUoMRatio: Decimal; var DUoMSecondQty: Decimal)
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        if ConversionMode = ConversionMode::Fixed then
            exit; // Modo Fixed: el ratio fijo siempre prevalece
        if not DUoMLotRatio.Get(ItemNo, LotNo) then
            exit; // Sin ratio para este lote: sin cambios
        DUoMRatio := DUoMLotRatio."Actual Ratio";
        // Recalcular usando la cantidad absoluta del registro destino
        DUoMSecondQty := Abs(Quantity) * DUoMLotRatio."Actual Ratio";
    end;
}
