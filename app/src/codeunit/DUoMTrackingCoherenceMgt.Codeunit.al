/// <summary>
/// Centralized codeunit for validating DUoM coherence between purchase document lines
/// and their associated item tracking (Reservation Entry) data.
///
/// Responsibilities:
///   - Validate a Purchase Line against its tracking entries (Reservation Entries).
///   - Validate the aggregate DUoM total from a Tracking Specification buffer against
///     the source Purchase Line (pre-persist, UI-close validation).
///   - Validate a single Tracking Specification line for ratio/mode coherence.
///   - Calculate DUoM totals from Reservation Entries for a Purchase Line.
///   - Assert mathematical ratio coherence (BaseQty, SecondQty, Ratio) within tolerance.
///   - Apply mode-specific rules: Fixed, Variable, AlwaysVariable.
///   - Centralise error messages so the same checks run from both page (UI feedback)
///     and posting (server-side guard).
///
/// Conventions:
///   DUoM Ratio = DUoM Second Qty / Quantity  (secondary UoM units per primary unit).
///   Example: 5 PCS / 6 KG ≈ 0.8333 PCS/KG.
///   Tolerance for total comparison = rounding precision of the secondary UoM (fallback 0.00001).
///
/// Codeunit IDs confirmed:  50111 (app range 50100–50199).
/// </summary>
codeunit 50111 "DUoM Tracking Coherence Mgt"
{
    Access = Public;

    /// <summary>
    /// Validates that the sum of DUoM Second Qty across all Tracking Specification buffer
    /// records for the same Purchase Line source matches PurchLine."DUoM Second Qty".
    ///
    /// Called from: DUoM Item Tracking Lines pageextension (50112) in OnQueryClosePage
    /// to block page close when the aggregate DUoM tracking total does not match the
    /// source Purchase Line. Uses the live Tracking Specification buffer (temporary table),
    /// not Reservation Entry, so validation occurs BEFORE any data is persisted.
    ///
    /// Steps:
    ///   1. Exit if TrackingSpec source type is not Purchase Line.
    ///   2. Exit if DUoM is not active for the item.
    ///   3. Exit if Purchase Line not found or DUoM Second Qty = 0 on the line.
    ///   4. Sum DUoM Second Qty from all buffer records sharing the same source.
    ///   5. Raise TrackingTotalMismatchErr if difference exceeds rounding precision.
    ///
    /// Note: filters on TrackingSpec are reset at exit (both error and success paths).
    ///
    /// Called from: DUoM Item Tracking Lines (50112) — OnQueryClosePage.
    /// </summary>
    procedure ValidateTrackingSpecBufferForPurchLine(var TrackingSpec: Record "Tracking Specification")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        PurchLine: Record "Purchase Line";
        PurchDocType: Enum "Purchase Document Type";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        TotalSecondQty: Decimal;
        RoundingPrecision: Decimal;
        Difference: Decimal;
        ItemNo: Code[20];
        VariantCode: Code[10];
        SourceSubtype: Integer;
        SourceID: Code[20];
        SourceRefNo: Integer;
    begin
        if TrackingSpec."Source Type" <> Database::"Purchase Line" then
            exit;

        ItemNo := TrackingSpec."Item No.";
        VariantCode := TrackingSpec."Variant Code";
        SourceSubtype := TrackingSpec."Source Subtype";
        SourceID := TrackingSpec."Source ID";
        SourceRefNo := TrackingSpec."Source Ref. No.";

        if ItemNo = '' then
            exit;

        if not DUoMSetupResolver.GetEffectiveSetup(
                 ItemNo, VariantCode, SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        PurchDocType := "Purchase Document Type".FromInteger(SourceSubtype);
        if not PurchLine.Get(PurchDocType, SourceID, SourceRefNo) then
            exit;

        // Only validate when the Purchase Line carries a DUoM Second Qty total.
        // AlwaysVariable lines may have DUoM Second Qty = 0 when the user did not
        // set a line-level total; in that case, skip the aggregate check.
        if PurchLine."DUoM Second Qty" <= 0 then
            exit;

        // Iterate buffer records matching the same source and sum DUoM Second Qty.
        TrackingSpec.Reset();
        TrackingSpec.SetRange("Source Type", Database::"Purchase Line");
        TrackingSpec.SetRange("Source Subtype", SourceSubtype);
        TrackingSpec.SetRange("Source ID", SourceID);
        TrackingSpec.SetRange("Source Ref. No.", SourceRefNo);

        TotalSecondQty := 0;
        if TrackingSpec.FindSet() then
            repeat
                TotalSecondQty += TrackingSpec."DUoM Second Qty";
            until TrackingSpec.Next() = 0;

        // Restore TrackingSpec to no-filter state so the page's standard OK
        // processing (after validation succeeds) is not affected.
        TrackingSpec.Reset();

        RoundingPrecision := GetDUoMRoundingPrecision(ItemNo, SecondUoMCode);
        Difference := Abs(TotalSecondQty - PurchLine."DUoM Second Qty");
        if Difference > RoundingPrecision then
            Error(TrackingTotalMismatchErr,
                PurchLine."Document No.", PurchLine."Line No.",
                PurchLine."DUoM Second Qty", SecondUoMCode,
                TotalSecondQty, Difference);
    end;

    /// <summary>
    /// Validates DUoM coherence for a Purchase Line against all its Reservation Entries.
    ///
    /// Steps:
    ///   1. Exit if DUoM is not active for the item on the line.
    ///   2. Read all positive Reservation Entries for the line and sum up DUoM Second Qty.
    ///   3. If no tracking DUoM data exists (total = 0 and base qty = 0), exit — no lot tracking.
    ///   4. For Fixed and Variable modes: compare tracking total with PurchLine.DUoM Second Qty
    ///      (only when PurchLine.DUoM Second Qty > 0 to support AlwaysVariable where the line
    ///      total may not have been filled by the user).
    ///   5. Validate each Reservation Entry for ratio coherence and mode-specific rules.
    ///
    /// Called from: DUoM Purchase Subscribers (50102) during purchase posting.
    /// </summary>
    procedure ValidatePurchLineTrackingCoherence(PurchLine: Record "Purchase Line")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        ReservEntry: Record "Reservation Entry";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        TotalSecondQty: Decimal;
        TotalBaseQty: Decimal;
        RoundingPrecision: Decimal;
        Difference: Decimal;
    begin
        if PurchLine.Type <> PurchLine.Type::Item then
            exit;
        if PurchLine."No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 PurchLine."No.", PurchLine."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        CalcTrackingDUoMTotalsForPurchLine(PurchLine, TotalSecondQty, TotalBaseQty);

        // No tracking DUoM data — item may not use lot tracking; nothing to validate.
        if (TotalBaseQty = 0) and (TotalSecondQty = 0) then
            exit;

        RoundingPrecision := GetDUoMRoundingPrecision(PurchLine."No.", SecondUoMCode);

        // Total comparison: only when the Purchase Line carries a DUoM total.
        // AlwaysVariable lines may legitimately have DUoM Second Qty = 0 on the line
        // (user did not fill it in; each lot carries its own DUoM data in tracking).
        // When PurchLine.DUoM Second Qty > 0 but TotalSecondQty = 0, the tracking
        // entries exist (TotalBaseQty > 0) but carry no DUoM data — this IS an
        // inconsistency and will be reported (difference = PurchLine.DUoM Second Qty).
        if PurchLine."DUoM Second Qty" > 0 then begin
            Difference := Abs(TotalSecondQty - PurchLine."DUoM Second Qty");
            if Difference > RoundingPrecision then
                Error(TrackingTotalMismatchErr,
                    PurchLine."Document No.", PurchLine."Line No.",
                    PurchLine."DUoM Second Qty", SecondUoMCode,
                    TotalSecondQty, Difference);
        end;

        // Per-entry validation: ratio coherence and mode-specific rules.
        FilterReservEntriesForPurchLine(PurchLine, ReservEntry);
        if ReservEntry.FindSet() then
            repeat
                ValidateReservEntryCoherence(
                    ReservEntry, ConversionMode, FixedRatio,
                    RoundingPrecision, PurchLine."No.");
            until ReservEntry.Next() = 0;
    end;

    /// <summary>
    /// Validates a single Tracking Specification record for DUoM coherence.
    /// Checks ratio against the mode-specific rules (Fixed, Variable, AlwaysVariable)
    /// and verifies the mathematical relationship: DUoM Second Qty ≈ Qty (Base) × DUoM Ratio.
    ///
    /// Called from: DUoM Item Tracking Lines page extension (50112) for UI feedback.
    /// </summary>
    procedure ValidateTrackingSpecLine(TrackingSpec: Record "Tracking Specification")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        RoundingPrecision: Decimal;
    begin
        if TrackingSpec."Item No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 TrackingSpec."Item No.", TrackingSpec."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        RoundingPrecision := GetDUoMRoundingPrecision(TrackingSpec."Item No.", SecondUoMCode);

        if TrackingSpec."DUoM Ratio" = 0 then begin
            // AlwaysVariable requires a ratio whenever there is quantity.
            if ConversionMode = ConversionMode::AlwaysVariable then
                if TrackingSpec."Quantity (Base)" <> 0 then
                    Error(AlwaysVariableMissingRatioErr, TrackingSpec."Item No.", TrackingSpec."Lot No.");
            exit;
        end;

        // Fixed mode: ratio must equal the configured fixed ratio.
        if ConversionMode = ConversionMode::Fixed then
            if Abs(TrackingSpec."DUoM Ratio" - FixedRatio) > 0.00001 then
                Error(FixedRatioMismatchErr,
                    TrackingSpec."Lot No.", TrackingSpec."DUoM Ratio",
                    TrackingSpec."Item No.", FixedRatio);

        // Mathematical coherence: DUoM Second Qty ≈ Qty (Base) × DUoM Ratio.
        if (TrackingSpec."Quantity (Base)" <> 0) and (TrackingSpec."DUoM Second Qty" <> 0) then
            AssertRatioCoherence(
                Abs(TrackingSpec."Quantity (Base)"),
                TrackingSpec."DUoM Second Qty",
                TrackingSpec."DUoM Ratio",
                RoundingPrecision,
                TrackingSpec."Lot No.");
    end;

    /// <summary>
    /// Calculates the sum of DUoM Second Qty and Quantity (Base) from all positive
    /// Reservation Entries linked to the given Purchase Line.
    ///
    /// Reads Reservation Entry (337) filtered by Source Type = Purchase Line,
    /// Source Subtype (Document Type), Source ID (Document No.) and
    /// Source Ref. No. (Line No.), Positive = true.
    /// </summary>
    procedure CalcTrackingDUoMTotalsForPurchLine(
        PurchLine: Record "Purchase Line";
        var TotalSecondQty: Decimal;
        var TotalBaseQty: Decimal)
    var
        ReservEntry: Record "Reservation Entry";
    begin
        TotalSecondQty := 0;
        TotalBaseQty := 0;
        FilterReservEntriesForPurchLine(PurchLine, ReservEntry);
        if ReservEntry.FindSet() then
            repeat
                TotalSecondQty += ReservEntry."DUoM Second Qty";
                TotalBaseQty += ReservEntry."Quantity (Base)";
            until ReservEntry.Next() = 0;
    end;

    /// <summary>
    /// Validates the mathematical coherence of a DUoM triplet (BaseQty, SecondQty, Ratio):
    ///   |BaseQty × Ratio − SecondQty| must be ≤ RoundingPrecision.
    ///
    /// If the tolerance is exceeded, raises an error identifying the lot, the stated ratio
    /// and the expected ratio (SecondQty / BaseQty).
    ///
    /// Skips validation when any of the three values is zero (nothing to assert).
    /// </summary>
    procedure AssertRatioCoherence(
        BaseQty: Decimal;
        SecondQty: Decimal;
        Ratio: Decimal;
        RoundingPrecision: Decimal;
        LotNo: Code[50])
    var
        EffectivePrecision: Decimal;
        ExpectedSecondQty: Decimal;
        ExpectedRatio: Decimal;
    begin
        if (BaseQty = 0) or (SecondQty = 0) or (Ratio = 0) then
            exit;

        EffectivePrecision := RoundingPrecision;
        if EffectivePrecision <= 0 then
            EffectivePrecision := 0.00001;

        ExpectedSecondQty := Round(BaseQty * Ratio, EffectivePrecision);
        if Abs(ExpectedSecondQty - SecondQty) > EffectivePrecision then begin
            ExpectedRatio := GetExpectedRatio(BaseQty, SecondQty);
            Error(RatioIncoherenceErr,
                LotNo, BaseQty, SecondQty, Ratio, ExpectedRatio);
        end;
    end;

    /// <summary>
    /// Returns the Qty. Rounding Precision for the given secondary UoM code on the item.
    /// Falls back to 0.00001 (maximum precision) when the Item Unit of Measure record
    /// does not exist or the code is blank.
    /// </summary>
    procedure GetDUoMRoundingPrecision(ItemNo: Code[20]; SecondUoMCode: Code[10]): Decimal
    var
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        Precision: Decimal;
    begin
        Precision := DUoMUoMHelper.GetRoundingPrecisionByUoMCode(ItemNo, SecondUoMCode);
        if Precision <= 0 then
            Precision := 0.00001;
        exit(Precision);
    end;

    /// <summary>
    /// Returns the expected DUoM Ratio derived from the given BaseQty and SecondQty.
    /// Formula: ExpectedRatio = SecondQty / BaseQty.
    /// Returns 0 when BaseQty = 0 to avoid division by zero.
    /// </summary>
    procedure GetExpectedRatio(BaseQty: Decimal; SecondQty: Decimal): Decimal
    begin
        if BaseQty = 0 then
            exit(0);
        exit(SecondQty / BaseQty);
    end;

    // ── Private helpers ───────────────────────────────────────────────────────

    local procedure FilterReservEntriesForPurchLine(
        PurchLine: Record "Purchase Line";
        var ReservEntry: Record "Reservation Entry")
    begin
        ReservEntry.Reset();
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source Subtype", PurchLine."Document Type".AsInteger());
        ReservEntry.SetRange("Source ID", PurchLine."Document No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange(Positive, true);
    end;

    local procedure ValidateReservEntryCoherence(
        ReservEntry: Record "Reservation Entry";
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        RoundingPrecision: Decimal;
        ItemNo: Code[20])
    begin
        if ReservEntry."DUoM Ratio" = 0 then begin
            // AlwaysVariable requires a ratio whenever there is quantity.
            if ConversionMode = ConversionMode::AlwaysVariable then
                if ReservEntry."Quantity (Base)" <> 0 then
                    Error(AlwaysVariableMissingRatioErr, ItemNo, ReservEntry."Lot No.");
            exit;
        end;

        // Fixed mode: ratio must equal the configured fixed ratio.
        if ConversionMode = ConversionMode::Fixed then
            if Abs(ReservEntry."DUoM Ratio" - FixedRatio) > 0.00001 then
                Error(FixedRatioMismatchErr,
                    ReservEntry."Lot No.", ReservEntry."DUoM Ratio", ItemNo, FixedRatio);

        // Mathematical coherence: DUoM Second Qty ≈ Qty (Base) × DUoM Ratio.
        if (ReservEntry."Quantity (Base)" <> 0) and (ReservEntry."DUoM Second Qty" <> 0) then
            AssertRatioCoherence(
                Abs(ReservEntry."Quantity (Base)"),
                ReservEntry."DUoM Second Qty",
                ReservEntry."DUoM Ratio",
                RoundingPrecision,
                ReservEntry."Lot No.");
    end;

    var
        TrackingTotalMismatchErr: Label 'The DUoM secondary quantity assigned in the tracking lines does not match the DUoM quantity on the purchase line.\\Document: %1\\Line No.: %2\\Purchase Line DUoM Qty: %3 %4\\Tracking DUoM Qty: %5 %4\\Difference: %6 %4',
            Comment = '%1 = Document No., %2 = Line No., %3 = Purchase Line DUoM Second Qty, %4 = Second UoM Code, %5 = Total Tracking DUoM Qty, %6 = Difference';
        RatioIncoherenceErr: Label 'Lot %1 has an inconsistent DUoM ratio.\\Base Qty: %2\\Secondary Qty: %3\\Stated Ratio: %4\\Expected Ratio: %5',
            Comment = '%1 = Lot No., %2 = Base Qty, %3 = Secondary Qty, %4 = Stated Ratio, %5 = Expected Ratio';
        AlwaysVariableMissingRatioErr: Label 'Item %1 requires a variable DUoM ratio per lot, but lot %2 does not have a valid ratio.',
            Comment = '%1 = Item No., %2 = Lot No.';
        FixedRatioMismatchErr: Label 'Lot %1 uses a DUoM ratio (%2) that differs from the fixed ratio configured for item %3 (%4).',
            Comment = '%1 = Lot No., %2 = Actual Ratio, %3 = Item No., %4 = Fixed Ratio';
}
