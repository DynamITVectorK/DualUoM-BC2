/// <summary>
/// Capa centralizada para la propagación DUoM en tracking.
///
/// Principios:
///   - Reservation Entry es la fuente de verdad per-lote mientras el documento está vivo.
///   - Tracking Specification es un buffer temporal de edición/visualización.
///   - DUoM Second Qty se muestra siempre en positivo en la página.
///   - DUoM Second Qty se persiste en Reservation Entry con el signo estándar de
///     Create Reserv. Entry.SignFactor(...).
///   - DUoM Ratio se persiste y visualiza siempre en positivo.
/// </summary>
codeunit 50125 "DUoM Tracking Prop. Mgt"
{
    Access = Public;

    // Publisher: Page "Item Tracking Lines" (6510), Event: OnAfterEntriesAreIdentical.
    // Motivo: incluir campos DUoM en la comparación para que BC detecte cambios aunque
    // lote/cantidad estándar no cambien. Firma validada contra BC 27 BaseApp.
    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnAfterEntriesAreIdentical', '', false, false)]
    local procedure OnAfterEntriesAreIdentical(
        ReservEntry1: Record "Reservation Entry";
        ReservEntry2: Record "Reservation Entry";
        var IdenticalArray: array[2] of Boolean)
    begin
        // BC reserva el índice 2 para que extensiones comparen sus campos adicionales
        // sin alterar la semántica estándar del índice 1.
        IdenticalArray[2] := AreReservEntriesDUoMIdentical(ReservEntry1, ReservEntry2);
    end;

    // Publisher: Page "Item Tracking Lines" (6510), Event: OnAfterMoveFields.
    // Motivo: normalizar DUoM al mover el buffer visible hacia Reservation Entry.
    // Firma validada contra BC 27 BaseApp.
    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnAfterMoveFields', '', false, false)]
    local procedure OnAfterMoveFields(
        var TrkgSpec: Record "Tracking Specification";
        var ReservEntry: Record "Reservation Entry")
    begin
        CopyTrackingSpecToReservEntry(TrkgSpec, ReservEntry);
    end;

    // Publisher: Page "Item Tracking Lines" (6510), Event: OnAfterCopyTrackingSpec.
    // Motivo: evitar pérdida de campos DUoM cuando BC copia buffers internos de tracking.
    // Firma validada contra BC 27 BaseApp.
    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnAfterCopyTrackingSpec', '', false, false)]
    local procedure OnAfterCopyTrackingSpec(
        var SourceTrackingSpec: Record "Tracking Specification";
        var DestTrkgSpec: Record "Tracking Specification")
    begin
        CopyTrackingSpecToTrackingSpec(SourceTrackingSpec, DestTrkgSpec);
    end;

    // Publisher: Codeunit "Create Reservation Entry" (99000830), Event: OnCreateReservEntryExtraFields.
    // Motivo: asegurar que el INSERT final de Reservation Entry conserve DUoM con el patrón
    // estándar de signo. Firma validada contra BC 27 BaseApp.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Reserv. Entry", 'OnCreateReservEntryExtraFields', '', false, false)]
    local procedure OnCreateReservEntryExtraFields(
        var InsertReservEntry: Record "Reservation Entry";
        OldTrackingSpecification: Record "Tracking Specification";
        NewTrackingSpecification: Record "Tracking Specification")
    begin
        if IsFunctionalTrackingLine(NewTrackingSpecification) then begin
            CopyTrackingSpecToReservEntry(NewTrackingSpecification, InsertReservEntry);
            exit;
        end;

        CopyTrackingSpecToReservEntry(OldTrackingSpecification, InsertReservEntry);
    end;

    // Publisher: Codeunit "Item Tracking Doc. Management" (6503), Event:
    // OnAfterFillTrackingSpecBufferFromReservEntry.
    // Motivo: reconstruir el buffer visible desde Reservation Entry al reabrir tracking.
    // Firma validada contra BC 27 BaseApp.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Doc. Management", 'OnAfterFillTrackingSpecBufferFromReservEntry', '', false, false)]
    local procedure OnAfterFillTrackingSpecBufferFromReservEntry(
        var TempTrackingSpecification: Record "Tracking Specification" temporary;
        var ReservationEntry: Record "Reservation Entry")
    begin
        CopyReservEntryToTrackingSpec(ReservationEntry, TempTrackingSpecification);
        if TempTrackingSpecification."Entry No." <> 0 then
            TempTrackingSpecification.Modify(false);
    end;

    // Publisher: Codeunit "Item Tracking Doc. Management" (6503), Event:
    // OnAfterFillTrackingSpecBufferFromTrackingEntries.
    // Motivo: preservar DUoM cuando BC rellena el buffer desde otros tracking entries.
    // Firma validada contra BC 27 BaseApp.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Doc. Management", 'OnAfterFillTrackingSpecBufferFromTrackingEntries', '', false, false)]
    local procedure OnAfterFillTrackingSpecBufferFromTrackingEntries(
        var TempTrackingSpecification: Record "Tracking Specification" temporary;
        var TrackingSpecification: Record "Tracking Specification")
    begin
        CopyTrackingSpecToTrackingSpec(TrackingSpecification, TempTrackingSpecification);
        if TempTrackingSpecification."Entry No." <> 0 then
            TempTrackingSpecification.Modify(false);
    end;

    procedure ValidateTrackingBeforeClose(var TrackingSpecification: Record "Tracking Specification")
    var
        DUoMTrackingCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        DUoMTrackingCoherenceMgt.ValidateTrackingSpecBufferEachLine(TrackingSpecification);

        if TrackingSpecification."Source Type" = Database::"Purchase Line" then begin
            DUoMTrackingCoherenceMgt.SyncPurchLineFromTrackingBuffer(TrackingSpecification);
            DUoMTrackingCoherenceMgt.ValidateTrackingSpecBufferForPurchLine(TrackingSpecification);
        end;

        DUoMTrackingCoherenceMgt.PersistDUoMToReservEntries(TrackingSpecification);
    end;

    procedure AreReservEntriesDUoMIdentical(
        ReservEntry1: Record "Reservation Entry";
        ReservEntry2: Record "Reservation Entry"): Boolean
    begin
        exit(
            (ReservEntry1."DUoM Second Qty" = ReservEntry2."DUoM Second Qty") and
            (ReservEntry1."DUoM Ratio" = ReservEntry2."DUoM Ratio"));
    end;

    procedure CopyTrackingSpecToReservEntry(
        TrackingSpecification: Record "Tracking Specification";
        var ReservationEntry: Record "Reservation Entry")
    begin
        ReservationEntry."DUoM Ratio" := Abs(TrackingSpecification."DUoM Ratio");
        ReservationEntry."DUoM Second Qty" := NormalizeSecondQtyForReservEntry(
            TrackingSpecification, ReservationEntry);
    end;

    procedure CopyReservEntryToTrackingSpec(
        ReservationEntry: Record "Reservation Entry";
        var TrackingSpecification: Record "Tracking Specification")
    begin
        TrackingSpecification."DUoM Ratio" := Abs(ReservationEntry."DUoM Ratio");
        TrackingSpecification."DUoM Second Qty" := NormalizeSecondQtyForPage(
            ReservationEntry."DUoM Second Qty");
    end;

    procedure CopyTrackingSpecToTrackingSpec(
        SourceTrackingSpec: Record "Tracking Specification";
        var DestTrackingSpec: Record "Tracking Specification")
    begin
        DestTrackingSpec."DUoM Ratio" := Abs(SourceTrackingSpec."DUoM Ratio");
        DestTrackingSpec."DUoM Second Qty" := NormalizeSecondQtyForPage(
            SourceTrackingSpec."DUoM Second Qty");
    end;

    procedure IsFunctionalTrackingLine(TrackingSpec: Record "Tracking Specification"): Boolean
    begin
        exit(
            (TrackingSpec."Lot No." <> '') or
            (TrackingSpec."Serial No." <> '') or
            (TrackingSpec."Package No." <> '') or
            (TrackingSpec."Quantity (Base)" <> 0) or
            (TrackingSpec."DUoM Second Qty" <> 0) or
            (TrackingSpec."DUoM Ratio" <> 0));
    end;

    procedure NormalizeSecondQtyForPage(SecondQty: Decimal): Decimal
    begin
        exit(Abs(SecondQty));
    end;

    procedure NormalizeSecondQtyForReservEntry(
        TrackingSpecification: Record "Tracking Specification";
        ReservationEntry: Record "Reservation Entry"): Decimal
    begin
        exit(GetReservEntrySignFactor(ReservationEntry) * Abs(TrackingSpecification."DUoM Second Qty"));
    end;

    procedure SumTrackingDUoMSecondQty(var TrackingSpecification: Record "Tracking Specification"): Decimal
    var
        LocalTrackingSpecification: Record "Tracking Specification" temporary;
        TotalSecondQty: Decimal;
    begin
        LocalTrackingSpecification.Copy(TrackingSpecification, true);
        LocalTrackingSpecification.Reset();
        if not LocalTrackingSpecification.FindSet() then
            exit(0);

        repeat
            if IsFunctionalTrackingLine(LocalTrackingSpecification) then
                TotalSecondQty += NormalizeSecondQtyForPage(LocalTrackingSpecification."DUoM Second Qty");
        until LocalTrackingSpecification.Next() = 0;

        exit(TotalSecondQty);
    end;

    local procedure GetReservEntrySignFactor(ReservationEntry: Record "Reservation Entry"): Integer
    var
        CreateReservEntry: Codeunit "Create Reserv. Entry";
    begin
        // Source Type = 0 implica un buffer/intercambio sin origen documental resuelto.
        // En ese caso no existe SignFactor estándar disponible y se asume signo positivo.
        if ReservationEntry."Source Type" = 0 then
            exit(1);

        exit(CreateReservEntry.SignFactor(ReservationEntry));
    end;
}
