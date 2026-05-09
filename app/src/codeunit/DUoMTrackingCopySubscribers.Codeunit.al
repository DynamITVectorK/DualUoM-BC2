/// <summary>
/// Propaga DUoM Ratio y DUoM Second Qty siguiendo el patrón OnAfterCopyTracking*
/// de Codeunit 6516 "Package Management". Un subscriber por punto de copia entre tablas.
///
/// Cadena Item Tracking Lines — flujo INSERT (usuario cierra Item Tracking Lines):
///   Tracking Specification (buffer Item Tracking Lines)
///     → Table "Reservation Entry" · OnAfterCopyTrackingFromTrackingSpec
///         ↓
///   ReservEntry1 (temporal con DUoM Ratio correcto)
///     → Table "Reservation Entry" · OnAfterCopyTrackingFromReservEntry
///         ↓
///   InsertReservEntry → BD con DUoM Ratio correcto  ✓
///
/// Cadena completa (entradas de lote desde Purchase/Sales con Item Tracking):
///   Reservation Entry
///     → Table "Tracking Specification" · OnAfterCopyTrackingFromReservEntry
///         ↓
///   Tracking Specification (buffer interno BC durante posting)
///     → Table "Item Journal Line" · OnAfterCopyTrackingFromSpec
///         ↓
///   Item Journal Line (split por lote)
///     → Table "Item Ledger Entry" · OnAfterCopyTrackingFromItemJnlLine
///         ↓
///   Item Ledger Entry  ✓
///
/// Cadena directa (ILE from IJL posted directly via IJL with Reservation Entries):
///   Tracking Specification (buffer)
///     → Item Journal Line · OnAfterCopyTrackingFromSpec
///     → Item Ledger Entry · OnAfterCopyTrackingFromItemJnlLine  ✓
///
/// Cadena inversa (salidas aplicadas contra entradas existentes, p.ej. devoluciones):
///   Item Ledger Entry
///     → Table "Item Journal Line" · OnAfterCopyTrackingFromItemLedgEntry
///
/// Signatures verificadas BC 27 / runtime 15:
///   Patrón de referencia: Codeunit 6516 "Package Management" líneas 121, 774, 551, 768.
///   - OnAfterCopyTrackingFromTrackingSpec en Table "Reservation Entry" (337):
///     (var ReservationEntry: Record "Reservation Entry";
///      TrackingSpecification: Record "Tracking Specification")
///     Verificado contra Package Management (6516), ReservationEntryCopyTrackingFromTrackingSpec.
///   - OnAfterCopyTrackingFromReservEntry en Table "Reservation Entry" (337):
///     (var ReservationEntry: Record "Reservation Entry";
///      FromReservationEntry: Record "Reservation Entry")
///     Verificado: patrón idéntico a Package Management para campos extra en ReservEntry.
///   - OnAfterCopyTrackingFromReservEntry en Table "Tracking Specification" (6500):
///     (var TrackingSpecification: Record "Tracking Specification";
///      ReservEntry: Record "Reservation Entry")
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
///
/// Prioridad de ratio en ILECopyTrackingFromItemJnlLine:
///   Item Journal Line es la fuente final de ratio y magnitud DUoM. Este subscriber
///   copia el ratio, no lo recalcula y no consulta DUoM Lot Ratio (50102); solo
///   normaliza el signo de DUoM Second Qty contra ItemLedgerEntry.Quantity.
/// </summary>
codeunit 50110 "DUoM Tracking Copy Subscribers"
{
    Access = Internal;

    // ── Tracking Specification → Reservation Entry ────────────────────────────
    // Publisher: Table "Reservation Entry" (337), evento OnAfterCopyTrackingFromTrackingSpec.
    // Patrón: Codeunit 6516 "Package Management" — ReservationEntryCopyTrackingFromTrackingSpec.
    // Firma BC 27 verificada contra Package Management:
    //   (var ReservationEntry: Record "Reservation Entry"; TrackingSpecification: Record "Tracking Specification")
    // Motivo: BC llama esto al cerrar Item Tracking Lines (Page 6510) para persistir el buffer
    // Tracking Specification hacia Reservation Entry. Sin este subscriber, DUoM Ratio queda a 0
    // en ReservEntry y al reabrir la página las columnas DUoM aparecen vacías.
    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry",
        'OnAfterCopyTrackingFromTrackingSpec', '', false, false)]
    local procedure ReservEntryOnAfterCopyTrackingFromTrackingSpec(
        var ReservationEntry: Record "Reservation Entry";
        TrackingSpecification: Record "Tracking Specification")
    var
        DUoMTrackingPropMgt: Codeunit "DUoM Tracking Prop. Mgt";
    begin
        DUoMTrackingPropMgt.CopyTrackingSpecToReservEntry(TrackingSpecification, ReservationEntry);
    end;

    // ── Reservation Entry → Reservation Entry ─────────────────────────────────
    // Publisher: Table "Reservation Entry" (337), evento OnAfterCopyTrackingFromReservEntry.
    // Firma BC 27 verificada: (var ReservationEntry: Record "Reservation Entry";
    //                          FromReservationEntry: Record "Reservation Entry")
    // Motivo: En el flujo INSERT de Item Tracking Lines, BC crea InsertReservEntry llamando a:
    //   1. ReservEntry1.CopyTrackingFromSpec(OldTrackingSpec)
    //      → dispara OnAfterCopyTrackingFromTrackingSpec en Table "Reservation Entry"
    //      → DUoM Ratio = valor del buffer en ReservEntry1 ✓
    //   2. CreateReservEntry.CreateReservEntryFor(..., ForReservEntry=ReservEntry1)
    //      → internamente: InsertReservEntry.CopyTrackingFromReservEntry(ForReservEntry)
    //      → dispara OnAfterCopyTrackingFromReservEntry (ESTE EVENTO) en Table "Reservation Entry"
    //      → SIN este subscriber, DUoM Ratio = 0 en InsertReservEntry ✗
    //   3. CreateReservEntry.CreateEntry(...) inserta InsertReservEntry en BD con DUoM Ratio = 0
    // Con este subscriber el INSERT final lleva los valores DUoM correctos.
    // Patrón: idéntico al empleado en Package Management (6516) para campos extra.
    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry",
        'OnAfterCopyTrackingFromReservEntry', '', false, false)]
    local procedure ReservEntryOnAfterCopyTrackingFromReservEntry(
        var ReservationEntry: Record "Reservation Entry";
        FromReservationEntry: Record "Reservation Entry")
    begin
        ReservationEntry."DUoM Ratio" := Abs(FromReservationEntry."DUoM Ratio");
        ReservationEntry."DUoM Second Qty" := FromReservationEntry."DUoM Second Qty";
    end;

    // ── Reservation Entry → Tracking Specification buffer ─────────────────────
    // Publisher: Table "Tracking Specification" (6500), evento OnAfterCopyTrackingFromReservEntry.
    // Patrón: Codeunit 6516 "Package Management" línea 121. Firma BC 27 confirmada.
    // Motivo: BC construye el buffer de TrackingSpec desde ReservEntry durante el posting
    // (Purchase/Sales Orders con Item Tracking). Sin este subscriber, DUoM Ratio de
    // ReservEntry no llega al buffer y IJLCopyTrackingFromSpec recibe DUoM Ratio = 0.
    // Guard implícito: si ReservEntry.DUoM Ratio = 0, TrackingSpec.DUoM Ratio queda en 0
    // y IJLCopyTrackingFromSpec no actúa (guard "DUoM Ratio = 0 → exit"). Correcto.
    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification",
        'OnAfterCopyTrackingFromReservEntry', '', false, false)]
    local procedure TrackingSpecCopyTrackingFromReservEntry(
        var TrackingSpecification: Record "Tracking Specification";
        ReservEntry: Record "Reservation Entry")
    var
        DUoMTrackingPropMgt: Codeunit "DUoM Tracking Prop. Mgt";
    begin
        DUoMTrackingPropMgt.CopyReservEntryToTrackingSpec(ReservEntry, TrackingSpecification);
    end;

    // ── Tracking Specification → Item Journal Line ────────────────────────────
    // Publisher: Table "Item Journal Line" (83), evento OnAfterCopyTrackingFromSpec.
    // Patrón: Codeunit 6516 "Package Management" línea 774. Firma BC 27 confirmada.
    // Motivo: BC llama esto al dividir el IJL por lote (TempSplitItemJournalLine).
    //
    // Fuente de verdad DUoM con tracking (prioridad de resolución):
    //   1. TrackingSpec tiene DUoM Ratio ≠ 0 → usar valores del tracking del usuario.
    //   2. DUoM Lot Ratio (50102) tiene ratio para este lote → aplicar ratio de lote.
    //   3. IJL padre tiene DUoM Ratio ≠ 0 → proyectar proporcionalmente con la cantidad del split.
    //   4. Sin ratio disponible (AlwaysVariable sin ratio real) → DUoM Second Qty = 0.
    //
    // Signo técnico: DUoM Second Qty sigue el signo del movimiento (negativo para salidas).
    // El signo se determina desde ItemJournalLine."Quantity (Base)" del split.
    // Las tres fuentes aportan valores positivos (datos de usuario); el signo se aplica aquí.
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line",
        'OnAfterCopyTrackingFromSpec', '', false, false)]
    local procedure IJLCopyTrackingFromSpec(
        var ItemJournalLine: Record "Item Journal Line";
        TrackingSpecification: Record "Tracking Specification")
    var
        DUoMLotSubscribers: Codeunit "DUoM Lot Subscribers";
    begin
        if TrackingSpecification."DUoM Ratio" <> 0 then begin
            // Fuente 1: TrackingSpec tiene ratio validado por el usuario en Item Tracking Lines.
            // Copiar ratio directamente; aplicar signo técnico del movimiento al Second Qty
            // (el dato de usuario se almacena siempre positivo; salidas deben ser negativas).
            ItemJournalLine."DUoM Ratio" := TrackingSpecification."DUoM Ratio";
            ItemJournalLine."DUoM Second Qty" := ApplyMovementSign(
                ItemJournalLine, Abs(TrackingSpecification."DUoM Second Qty"));
            exit;
        end;

        ItemJournalLine."Lot No." := TrackingSpecification."Lot No.";
        if DUoMLotSubscribers.ApplyLotRatioToItemJournalLine(ItemJournalLine) then begin
            // Fuente 2: DUoM Lot Ratio (50102) tiene ratio para este lote.
            // ApplyLotRatioToItemJournalLine establece DUoM Second Qty = Abs(Qty) × Ratio (positivo);
            // aplicar signo técnico del movimiento.
            ItemJournalLine."DUoM Second Qty" := ApplyMovementSign(
                ItemJournalLine, Abs(ItemJournalLine."DUoM Second Qty"));
            exit;
        end;

        // Fuente 3/4: sin ratio en tracking ni en DUoM Lot Ratio.
        if ItemJournalLine."DUoM Ratio" <> 0 then
            // Fuente 3: IJL padre tiene ratio (Variable/Fixed sin tracking específico).
            // Proyectar proporcionalmente con la cantidad real del split y aplicar signo.
            ItemJournalLine."DUoM Second Qty" := ApplyMovementSign(
                ItemJournalLine,
                Abs(TrackingSpecification."Quantity (Base)") * ItemJournalLine."DUoM Ratio")
        else
            // Fuente 4: AlwaysVariable sin ratio real de tracking/lote.
            // No se puede distribuir el total de la línea entre los splits sin ratio.
            // Regla: DUoM Ratio = 0 → DUoM Second Qty = 0.
            ItemJournalLine."DUoM Second Qty" := 0;
    end;

    // Aplica el signo técnico del movimiento a una cantidad DUoM positiva.
    // Las entradas (compras) producen valores positivos; las salidas (ventas) negativos.
    // Lógica idéntica a ApplyItemJnlSign en DUoM Doc Transfer Helper (50105).
    local procedure ApplyMovementSign(ItemJournalLine: Record "Item Journal Line"; SecondQty: Decimal): Decimal
    begin
        if SecondQty = 0 then
            exit(0);
        if ItemJournalLine."Quantity (Base)" < 0 then
            exit(-Abs(SecondQty));
        if ItemJournalLine.Quantity < 0 then
            exit(-Abs(SecondQty));
        exit(Abs(SecondQty));
    end;

    // ── Item Journal Line → Item Ledger Entry ─────────────────────────────────
    // Publisher: Table "Item Ledger Entry" (32), evento OnAfterCopyTrackingFromItemJnlLine.
    // Patrón: Codeunit 6516 "Package Management" línea 551. Firma BC 27 confirmada.
    // Motivo: BC llama esto antes de Insert() del ILE. Copia el ratio DUoM del IJL
    // split por lote al ILE y normaliza DUoM Second Qty contra ItemLedgerEntry.Quantity.
    // No recalcula ratio ni consulta DUoM Lot Ratio (50102); solo garantiza que el signo
    // final sea el del movimiento de inventario que BC va a insertar.
    //
    // Orden de ejecución (BC 27): este evento se dispara DESPUÉS de OnAfterInitItemLedgEntry.
    // Para artículos CON Item Tracking, este subscriber sobreescribe la copia inicial de
    // OnAfterInitItemLedgEntry con los valores específicos del IJL split por lote.
    [EventSubscriber(ObjectType::Table, Database::"Item Ledger Entry",
        'OnAfterCopyTrackingFromItemJnlLine', '', false, false)]
    local procedure ILECopyTrackingFromItemJnlLine(
        var ItemLedgerEntry: Record "Item Ledger Entry";
        ItemJnlLine: Record "Item Journal Line")
    begin
        ItemLedgerEntry."DUoM Ratio" := ItemJnlLine."DUoM Ratio";
        ItemLedgerEntry."DUoM Second Qty" := NormalizeSecondQtySignForILE(
            ItemLedgerEntry, ItemJnlLine."DUoM Second Qty");
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

    // ── Tracking Specification: OnAfterClearTracking ──────────────────────────
    // Publisher: Table "Tracking Specification" (6500)
    // Patrón: Package Management — TrackingSpecificationClearTracking
    // Motivo: BC llama a ClearTracking al reinicializar una línea de tracking.
    //         Sin este subscriber, DUoM Ratio queda con valor residual tras limpiar.
    // Firma BC 27 verificada: (var TrackingSpecification: Record "Tracking Specification")
    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification",
        'OnAfterClearTracking', '', false, false)]
    local procedure TrackingSpecClearTracking(
        var TrackingSpecification: Record "Tracking Specification")
    begin
        TrackingSpecification."DUoM Ratio" := 0;
        TrackingSpecification."DUoM Second Qty" := 0;
    end;

    // ── Tracking Specification: OnAfterSetTrackingBlank ───────────────────────
    // Publisher: Table "Tracking Specification" (6500)
    // Patrón: Package Management — TrackingSpecificationSetTrackingBlank
    // Motivo: BC llama a SetTrackingBlank al blanquear campos de tracking en el buffer.
    //         Sin este subscriber, DUoM Ratio queda con valor residual.
    // Firma BC 27 verificada: (var TrackingSpecification: Record "Tracking Specification")
    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification",
        'OnAfterSetTrackingBlank', '', false, false)]
    local procedure TrackingSpecSetTrackingBlank(
        var TrackingSpecification: Record "Tracking Specification")
    begin
        TrackingSpecification."DUoM Ratio" := 0;
        TrackingSpecification."DUoM Second Qty" := 0;
    end;

    // ── Tracking Specification: OnAfterCopyTrackingFromTrackingSpec ───────────
    // Publisher: Table "Tracking Specification" (6500)
    // Patrón: Package Management — TrackingSpecificationCopyTrackingFromTrackingSpec
    // Motivo: BC llama a CopyTrackingFromTrackingSpec al copiar líneas de tracking
    //         entre buffers. Sin este subscriber, DUoM Ratio no viaja entre buffers.
    // Firma BC 27 verificada:
    //   (var TrackingSpecification: Record "Tracking Specification";
    //    FromTrackingSpecification: Record "Tracking Specification")
    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification",
        'OnAfterCopyTrackingFromTrackingSpec', '', false, false)]
    local procedure TrackingSpecCopyFromTrackingSpec(
        var TrackingSpecification: Record "Tracking Specification";
        FromTrackingSpecification: Record "Tracking Specification")
    begin
        TrackingSpecification."DUoM Ratio" := FromTrackingSpecification."DUoM Ratio";
        TrackingSpecification."DUoM Second Qty" := FromTrackingSpecification."DUoM Second Qty";
    end;

    // ── Tracking Specification: OnAfterCopyTrackingFromItemLedgEntry ──────────
    // Publisher: Table "Tracking Specification" (6500)
    // Patrón: Package Management — TrackingSpecificationCopyTrackingFromItemLedgEntry
    // Motivo: BC construye el buffer TrackingSpec desde ILE en flujos de aplicación
    //         (devoluciones, copia de documento exacta). Sin este subscriber, DUoM Ratio
    //         del ILE de origen no llega al buffer.
    // Firma BC 27 verificada:
    //   (var TrackingSpecification: Record "Tracking Specification";
    //    ItemLedgerEntry: Record "Item Ledger Entry")
    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification",
        'OnAfterCopyTrackingFromItemLedgEntry', '', false, false)]
    local procedure TrackingSpecCopyFromItemLedgEntry(
        var TrackingSpecification: Record "Tracking Specification";
        ItemLedgerEntry: Record "Item Ledger Entry")
    begin
        TrackingSpecification."DUoM Ratio" := ItemLedgerEntry."DUoM Ratio";
        TrackingSpecification."DUoM Second Qty" := ItemLedgerEntry."DUoM Second Qty";
    end;

    // ── Reservation Entry: OnAfterClearTracking ───────────────────────────────
    // Publisher: Table "Reservation Entry" (337)
    // Patrón: Package Management — ReservationEntryClearTracking
    // Motivo: BC llama a ClearTracking al reinicializar una Reservation Entry.
    //         Sin este subscriber, DUoM Ratio queda con valor residual.
    // Firma BC 27 verificada: (var ReservationEntry: Record "Reservation Entry")
    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry",
        'OnAfterClearTracking', '', false, false)]
    local procedure ReservEntryClearTracking(
        var ReservationEntry: Record "Reservation Entry")
    begin
        ReservationEntry."DUoM Ratio" := 0;
        ReservationEntry."DUoM Second Qty" := 0;
    end;

    // ── Reservation Entry: OnAfterClearNewTracking ────────────────────────────
    // Publisher: Table "Reservation Entry" (337)
    // Patrón: Package Management — ReservationEntryClearNewTracking
    // Motivo: BC llama a ClearNewTracking en flujos de reclasificación.
    //         Sin este subscriber, los campos DUoM no se limpian en esos flujos.
    // Firma BC 27 verificada: (var ReservationEntry: Record "Reservation Entry")
    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry",
        'OnAfterClearNewTracking', '', false, false)]
    local procedure ReservEntryClearNewTracking(
        var ReservationEntry: Record "Reservation Entry")
    begin
        ReservationEntry."DUoM Ratio" := 0;
        ReservationEntry."DUoM Second Qty" := 0;
    end;

    // ── Item Ledger Entry: OnAfterCopyTrackingFromNewItemJnlLine ──────────────
    // Publisher: Table "Item Ledger Entry" (32)
    // Patrón: Package Management — ItemLedgerEntryCopyTrackingFromNewItemJnlLine
    // Motivo: BC llama a CopyTrackingFromNewItemJnlLine en flujos de reclasificación
    //         (Transfer, Reclass Journal). Sin este subscriber, el ILE destino no
    //         recibe los campos DUoM del IJL en esos flujos.
    // Firma BC 27 verificada:
    //   (var ItemLedgerEntry: Record "Item Ledger Entry";
    //    ItemJnlLine: Record "Item Journal Line")
    [EventSubscriber(ObjectType::Table, Database::"Item Ledger Entry",
        'OnAfterCopyTrackingFromNewItemJnlLine', '', false, false)]
    local procedure ILECopyTrackingFromNewItemJnlLine(
        var ItemLedgerEntry: Record "Item Ledger Entry";
        ItemJnlLine: Record "Item Journal Line")
    begin
        ItemLedgerEntry."DUoM Ratio" := ItemJnlLine."DUoM Ratio";
        ItemLedgerEntry."DUoM Second Qty" := NormalizeSecondQtySignForILE(
            ItemLedgerEntry, ItemJnlLine."DUoM Second Qty");
    end;

    local procedure NormalizeSecondQtySignForILE(ItemLedgerEntry: Record "Item Ledger Entry"; SecondQty: Decimal): Decimal
    begin
        if SecondQty = 0 then
            exit(0);
        if ItemLedgerEntry.Quantity < 0 then
            exit(-Abs(SecondQty));
        if ItemLedgerEntry.Quantity > 0 then
            exit(Abs(SecondQty));
        exit(SecondQty);
    end;
}
