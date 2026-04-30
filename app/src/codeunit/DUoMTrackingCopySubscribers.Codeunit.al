/// <summary>
/// Propaga DUoM Ratio y DUoM Second Qty siguiendo el patrón OnAfterCopyTracking*
/// de Codeunit 6516 "Package Management". Un subscriber por punto de copia entre tablas.
///
/// Cadena directa (entradas de lote):
///   Tracking Specification
///     → Table "Item Journal Line" · OnAfterCopyTrackingFromSpec
///         ↓
///   Item Journal Line
///     → Table "Item Ledger Entry" · OnAfterCopyTrackingFromItemJnlLine
///         ↓
///   Item Ledger Entry  ✓
///
/// Cadena inversa (salidas aplicadas contra entradas existentes, p.ej. devoluciones):
///   Item Ledger Entry
///     → Table "Item Journal Line" · OnAfterCopyTrackingFromItemLedgEntry
///
/// Signatures verificadas BC 27 / runtime 15:
///   Patrón de referencia: Codeunit 6516 "Package Management" líneas 774, 551, 768.
///   - OnAfterCopyTrackingFromSpec en Table "Item Journal Line" (83):
///     (var ItemJournalLine: Record "Item Journal Line";
///      TrackingSpecification: Record "Tracking Specification")
///   - OnAfterCopyTrackingFromItemJnlLine en Table "Item Ledger Entry" (32):
///     (var ItemLedgerEntry: Record "Item Ledger Entry";
///      ItemJnlLine: Record "Item Journal Line")
///   - OnAfterCopyTrackingFromItemLedgEntry en Table "Item Journal Line" (83):
///     (var ItemJournalLine: Record "Item Journal Line";
///      ItemLedgEntry: Record "Item Ledger Entry")
///
/// Relación con otros subscribers:
///   OnPurchPostCopyDocFieldsToItemJnlLine y OnSalesPostCopyDocFieldsToItemJnlLine
///   (en DUoM Inventory Subscribers, 50104) establecen DUoM Ratio y DUoM Second Qty
///   en el IJL desde la línea de documento. Este codeunit refina esos valores a nivel
///   de lote específico cuando el Tracking Specification aporta un ratio distinto.
/// </summary>
codeunit 50110 "DUoM Tracking Copy Subscribers"
{
    Access = Internal;

    // ── Tracking Specification → Item Journal Line ────────────────────────────
    // Publisher: Table "Item Journal Line" (83), evento OnAfterCopyTrackingFromSpec.
    // Patrón: Codeunit 6516 "Package Management" línea 774. Firma BC 27 confirmada.
    // Motivo: BC llama esto al dividir el IJL por lote. TrackingSpecification es el del
    // lote específico. DUoM Ratio del lote llega al IJL sin ningún FindFirst().
    // Guard: sin ratio en TrackingSpec, se sale sin sobrescribir el ratio que ya propagó
    // OnPurchPostCopyDocFieldsToItemJnlLine desde Purchase Line (flujo sin Item Tracking
    // o lote sin ratio DUoM registrado).
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line",
        'OnAfterCopyTrackingFromSpec', '', false, false)]
    local procedure IJLCopyTrackingFromSpec(
        var ItemJournalLine: Record "Item Journal Line";
        TrackingSpecification: Record "Tracking Specification")
    begin
        if TrackingSpecification."DUoM Ratio" = 0 then
            exit;
        ItemJournalLine."DUoM Ratio" := TrackingSpecification."DUoM Ratio";
        ItemJournalLine."DUoM Second Qty" := TrackingSpecification."DUoM Second Qty";
    end;

    // ── Item Journal Line → Item Ledger Entry ─────────────────────────────────
    // Publisher: Table "Item Ledger Entry" (32), evento OnAfterCopyTrackingFromItemJnlLine.
    // Patrón: Codeunit 6516 "Package Management" línea 551. Firma BC 27 confirmada.
    // Motivo: BC llama esto antes de Insert() del ILE. ILE.Quantity ya está asignada.
    // Recalcular DUoM Second Qty con Abs(ILE.Quantity) garantiza la cantidad exacta
    // del lote (no proporcional de la línea total).
    // Guard para AlwaysVariable sin ratio y con Lot No.: no copiar el total de la línea
    // IJL a cada ILE individual (el total no es válido por lote). ILE queda en 0.
    // Esto preserva el comportamiento de Issue 20 (T10).
    [EventSubscriber(ObjectType::Table, Database::"Item Ledger Entry",
        'OnAfterCopyTrackingFromItemJnlLine', '', false, false)]
    local procedure ILECopyTrackingFromItemJnlLine(
        var ItemLedgerEntry: Record "Item Ledger Entry";
        ItemJnlLine: Record "Item Journal Line")
    begin
        if (ItemJnlLine."DUoM Ratio" = 0) and (ItemJnlLine."DUoM Second Qty" = 0) then
            exit;
        ItemLedgerEntry."DUoM Ratio" := ItemJnlLine."DUoM Ratio";
        if ItemJnlLine."DUoM Ratio" <> 0 then
            // Recalcular con la cantidad exacta del ILE (lote), no la cantidad total del IJL.
            ItemLedgerEntry."DUoM Second Qty" :=
                Abs(ItemLedgerEntry.Quantity) * ItemJnlLine."DUoM Ratio"
        else
            // AlwaysVariable sin ratio: copia directa solo cuando no hay Lot No. asignado
            // (flujo sin trazabilidad de lote, IJL de línea única).
            // Con Lot No. (multi-lote), el total de la línea no es válido por ILE individual;
            // ILE.DUoM Second Qty queda en 0. Ver Issue 20 (T10).
            if ItemJnlLine."Lot No." = '' then
                ItemLedgerEntry."DUoM Second Qty" := ItemJnlLine."DUoM Second Qty";
    end;

    // ── Item Ledger Entry → Item Journal Line (flujo inverso) ─────────────────
    // Publisher: Table "Item Journal Line" (83), evento OnAfterCopyTrackingFromItemLedgEntry.
    // Patrón: Codeunit 6516 "Package Management" línea 768. Firma BC 27 confirmada.
    // Motivo: usado en salidas aplicadas contra entradas existentes (p.ej. devoluciones).
    // La ratio y cantidad del ILE de origen se copian al IJL para mantener trazabilidad.
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line",
        'OnAfterCopyTrackingFromItemLedgEntry', '', false, false)]
    local procedure IJLCopyTrackingFromItemLedgEntry(
        var ItemJournalLine: Record "Item Journal Line";
        ItemLedgEntry: Record "Item Ledger Entry")
    begin
        ItemJournalLine."DUoM Ratio" := ItemLedgEntry."DUoM Ratio";
        ItemJournalLine."DUoM Second Qty" := ItemLedgEntry."DUoM Second Qty";
    end;
}
