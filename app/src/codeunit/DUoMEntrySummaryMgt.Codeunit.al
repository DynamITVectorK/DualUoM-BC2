/// <summary>
/// Gestión centralizada del contexto de artículo/variante en Entry Summary.
/// Resuelve Item No. y Variant Code desde la tabla origen real del buffer,
/// usando Table ID + Entry No. como referencia hacia Item Ledger Entry
/// o Reservation Entry.
///
/// Motivo: Entry Summary (tabla 338) no contiene campos "Item No." ni "Variant Code"
/// en BC 27. La información de artículo debe obtenerse desde el origen real:
///   - Table ID = 32 (Item Ledger Entry): Entry No. = ILE Entry No. → Get directo.
///   - Table ID = 337 (Reservation Entry): Entry No. filtra por RE → FindFirst.
///   - Table ID = "Tracking Specification": Entry No. filtra por Tracking Spec → FindFirst.
///
/// PopulateDUoMForEntrySummary rellena DUoM Ratio y DUoM Second Qty durante la
/// carga inicial del buffer de la página Item Tracking Summary, usando Total Available
/// Quantity como base cuando Selected Quantity = 0.
/// </summary>
codeunit 50132 "DUoM Entry Summary Mgt."
{
    Access = Public;

    /// <summary>
    /// Intenta resolver el contexto de artículo/variante desde un Entry Summary.
    /// Devuelve true si puede determinar un Item No. fiable; false en caso contrario.
    /// No provoca errores si el origen no es compatible o no es DUoM.
    ///
    /// Implementación:
    ///   - Table ID 32 (Item Ledger Entry): Get por Entry No. (Entry No. = ILE Entry No.).
    ///   - Table ID 337 (Reservation Entry): FindFirst filtrado por Entry No.
    ///   - Table ID "Tracking Specification": FindFirst filtrado por Entry No.
    ///   - Si lo anterior no resuelve, intenta fallback read-only por ILE abierto/remanente
    ///     filtrado por lote/serie y solo acepta contexto único Item+Variante.
    ///   - Otros casos: devuelve false.
    /// </summary>
    procedure TryResolveItemContext(
        EntrySummary: Record "Entry Summary";
        var ItemNo: Code[20];
        var VariantCode: Code[10]
    ): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        TrackingSpecification: Record "Tracking Specification";
    begin
        ItemNo := '';
        VariantCode := '';

        if EntrySummary."Entry No." <> 0 then
            case EntrySummary."Table ID" of
                Database::"Item Ledger Entry":
                    begin
                        if ItemLedgerEntry.Get(EntrySummary."Entry No.") then begin
                            ItemNo := ItemLedgerEntry."Item No.";
                            VariantCode := ItemLedgerEntry."Variant Code";
                            exit(true);
                        end;
                    end;
                Database::"Reservation Entry":
                    begin
                        ReservationEntry.SetRange("Entry No.", EntrySummary."Entry No.");
                        if ReservationEntry.FindFirst() then begin
                            ItemNo := ReservationEntry."Item No.";
                            VariantCode := ReservationEntry."Variant Code";
                            exit(true);
                        end;
                    end;
                Database::"Tracking Specification":
                    begin
                        TrackingSpecification.SetRange("Entry No.", EntrySummary."Entry No.");
                        if TrackingSpecification.FindFirst() then begin
                            ItemNo := TrackingSpecification."Item No.";
                            VariantCode := TrackingSpecification."Variant Code";
                            exit(true);
                        end;
                    end;
            end;

        exit(TryResolveFromUniqueOpenILE(EntrySummary, ItemNo, VariantCode));
    end;

    local procedure TryResolveFromUniqueOpenILE(
        EntrySummary: Record "Entry Summary";
        var ItemNo: Code[20];
        var VariantCode: Code[10]
    ): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        CandidateItemNo: Code[20];
        CandidateVariantCode: Code[10];
        FoundCandidate: Boolean;
    begin
        if (EntrySummary."Lot No." = '') and (EntrySummary."Serial No." = '') then
            exit(false);

        if EntrySummary."Lot No." <> '' then
            ItemLedgerEntry.SetRange("Lot No.", EntrySummary."Lot No.");
        if EntrySummary."Serial No." <> '' then
            ItemLedgerEntry.SetRange("Serial No.", EntrySummary."Serial No.");
        ItemLedgerEntry.SetRange(Open, true);
        ItemLedgerEntry.SetFilter("Remaining Quantity", '<>%1', 0);

        if not ItemLedgerEntry.FindSet() then
            exit(false);

        repeat
            if not FoundCandidate then begin
                CandidateItemNo := ItemLedgerEntry."Item No.";
                CandidateVariantCode := ItemLedgerEntry."Variant Code";
                FoundCandidate := true;
            end else
                if (CandidateItemNo <> ItemLedgerEntry."Item No.") or
                   (CandidateVariantCode <> ItemLedgerEntry."Variant Code")
                then
                    exit(false);
        until ItemLedgerEntry.Next() = 0;

        ItemNo := CandidateItemNo;
        VariantCode := CandidateVariantCode;
        exit(true);
    end;

    /// <summary>
    /// Rellena DUoM Ratio y DUoM Second Qty para una línea de Entry Summary.
    /// Diseñado para ser llamado durante la carga inicial de la página Item Tracking Summary.
    ///
    /// Comportamiento:
    ///   - Resuelve Item No. y Variant Code mediante TryResolveItemContext.
    ///   - Obtiene el setup efectivo (modo, ratio fijo) con DUoM Setup Resolver.
    ///   - En modo Fixed: usa Fixed Ratio directamente.
    ///   - En modo Variable / AlwaysVariable: busca DUoM Lot Ratio por lote.
    ///   - Si Selected Quantity <> 0: calcula DUoM Second Qty desde Abs(Selected Quantity).
    ///   - Si Selected Quantity = 0: calcula DUoM Second Qty desde Total Available Quantity.
    ///   - No lanza error si no hay contexto, setup o ratio de lote.
    ///   - Idempotente: llamar varias veces produce el mismo resultado.
    /// </summary>
    procedure PopulateDUoMForEntrySummary(var EntrySummary: Record "Entry Summary")
    var
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
        if not TryResolveItemContext(EntrySummary, ItemNo, VariantCode) then
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
                GetBaseQtyForSecondCalc(EntrySummary) * AppliedRatio,
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
            GetBaseQtyForSecondCalc(EntrySummary) * AppliedRatio,
            RoundingPrecision);
    end;

    local procedure GetBaseQtyForSecondCalc(EntrySummary: Record "Entry Summary"): Decimal
    begin
        if EntrySummary."Selected Quantity" <> 0 then
            exit(Abs(EntrySummary."Selected Quantity"));
        exit(Abs(EntrySummary."Total Available Quantity"));
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
