/// <summary>
/// Centralized codeunit for validating DUoM coherence between purchase document lines
/// and their associated item tracking (Reservation Entry) data.
///
/// Responsibilities:
///   - Normalize DUoM Ratio from DUoM Second Qty/Quantity (Base) in Variable/AlwaysVariable modes
///     (NormalizeTrackingDUoMSecondQty / NormalizeTrackingQuantityBase) — called on
///     DUoM Second Qty.OnValidate and Quantity (Base).OnAfterValidate.
///   - Validate each functional line in the Tracking Specification buffer for per-lot
///     ratio coherence (ValidateTrackingSpecBufferEachLine) — can be called directly from
///     production code or tests. Empty/insertion lines are skipped.
///   - Validate the aggregate DUoM total from a Tracking Specification buffer against
///     the source Purchase Line.
///   - Validate a Purchase Line against its tracking entries (Reservation Entries).
///   - Validate a single Tracking Specification line for ratio/mode coherence.
///   - Calculate DUoM totals from Reservation Entries for a Purchase Line.
///   - Assert mathematical ratio coherence (BaseQty, SecondQty, Ratio) within tolerance.
///   - Apply mode-specific rules: Fixed, Variable, AlwaysVariable.
///   - Centralise error messages so the same checks run from both page (UI feedback)
///     and posting (server-side guard).
///
/// Source of truth hierarchy:
///   Item Tracking Lines (TrackingSpec buffer) = per-lot reality during reception.
///   Reservation Entry = per-lot persistence after OK (standard BC tracking events).
///   Item Ledger Entry = historical truth after posting.
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
    /// Uses the live Tracking Specification buffer (temporary table), not Reservation Entry,
    /// so validation occurs before any data is persisted.
    ///
    /// Steps:
    ///   1. Exit if TrackingSpec source type is not Purchase Line.
    ///   2. Exit if DUoM is not active for the item.
    ///   3. Exit if Purchase Line not found or DUoM Second Qty = 0 on the line.
    ///   4. Sum DUoM Second Qty from all buffer records sharing the same source.
    ///   5. Raise TrackingTotalMismatchErr if difference exceeds rounding precision.
    ///
    /// Cursor safety: iteration uses a LOCAL COPY of TrackingSpec (via Copy(Rec, true))
    /// that shares the same temp-table data with an independent cursor. This prevents
    /// Reset()/FindSet()/Next() from modifying the page's Rec cursor and causing
    /// duplicate tracking entries on reopen.
    ///
    /// Can be called from: production code, posting guards, or unit tests.
    /// </summary>
    procedure ValidateTrackingSpecBufferForPurchLine(var TrackingSpec: Record "Tracking Specification")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        LocalTrackingSpec: Record "Tracking Specification" temporary;
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

        // Use a LOCAL COPY of TrackingSpec with the same shared temp-table data but
        // an independent cursor. This avoids calling Reset()/FindSet()/Next() on the
        // page's Rec (= TrackingSpec), which would interfere with BC's standard
        // Item Tracking Lines close mechanism and create duplicate tracking entries.
        // SetSourceFilter uses the standard BC source identity (Type, Subtype, ID,
        // Ref. No., Batch Name='', Prod. Order Line=0) to avoid mixing entries
        // from other documents. See docs/development/coding-standards.md.
        LocalTrackingSpec.Copy(TrackingSpec, true);
        LocalTrackingSpec.Reset();
        LocalTrackingSpec.SetSourceFilter(
            Database::"Purchase Line", SourceSubtype, SourceID, SourceRefNo, true);

        TotalSecondQty := 0;
        if LocalTrackingSpec.FindSet() then
            repeat
                TotalSecondQty += LocalTrackingSpec."DUoM Second Qty";
            until LocalTrackingSpec.Next() = 0;

        RoundingPrecision := GetDUoMRoundingPrecision(ItemNo, SecondUoMCode);
        Difference := Abs(TotalSecondQty - PurchLine."DUoM Second Qty");
        if Difference > RoundingPrecision then
            Error(TrackingTotalMismatchErr,
                PurchLine."Document No.", PurchLine."Line No.",
                PurchLine."DUoM Second Qty", SecondUoMCode,
                TotalSecondQty, Difference, PurchLineTxt);
    end;

    /// <summary>
    /// Validates that the sum of DUoM Second Qty across all Tracking Specification buffer
    /// records for the same Sales Line source matches SalesLine."DUoM Second Qty".
    ///
    /// Uses absolute quantities because Sales tracking persistence may use technical signs
    /// in intermediate buffers while users always edit/display positive DUoM values.
    /// </summary>
    procedure ValidateTrackingSpecBufferForSalesLine(TrackingSpec: Record "Tracking Specification")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        LocalTrackingSpec: Record "Tracking Specification" temporary;
        SalesLine: Record "Sales Line";
        SalesDocType: Enum "Sales Document Type";
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
        LineSecondQty: Decimal;
    begin
        if TrackingSpec."Source Type" <> Database::"Sales Line" then
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

        SalesDocType := Enum::"Sales Document Type".FromInteger(SourceSubtype);
        if not SalesLine.Get(SalesDocType, SourceID, SourceRefNo) then
            exit;

        LineSecondQty := Abs(SalesLine."DUoM Second Qty");
        if LineSecondQty <= 0 then
            exit;

        // Use shared temp-table data with an independent cursor to avoid mutating
        // the caller cursor while still validating the same in-memory buffer.
        LocalTrackingSpec.Copy(TrackingSpec, true);
        LocalTrackingSpec.Reset();
        LocalTrackingSpec.SetSourceFilter(
            Database::"Sales Line", SourceSubtype, SourceID, SourceRefNo, true);

        TotalSecondQty := 0;
        if LocalTrackingSpec.FindSet() then
            repeat
                if IsFunctionalTrackingLine(LocalTrackingSpec) then
                    TotalSecondQty += Abs(LocalTrackingSpec."DUoM Second Qty");
            until LocalTrackingSpec.Next() = 0;

        RoundingPrecision := GetDUoMRoundingPrecision(ItemNo, SecondUoMCode);
        Difference := Abs(TotalSecondQty - LineSecondQty);
        if Difference > RoundingPrecision then
            Error(TrackingTotalMismatchErr,
                SalesLine."Document No.", SalesLine."Line No.",
                LineSecondQty, SecondUoMCode,
                TotalSecondQty, Difference, SalesLineTxt);
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
                    TotalSecondQty, Difference, PurchLineTxt);
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
    /// Validates DUoM coherence for a Sales Line against all its Reservation Entries.
    /// Uses absolute totals and signs to compare the functional user quantity.
    ///
    /// Called from: DUoM Sales Subscribers (50103) during sales posting.
    /// </summary>
    procedure ValidateSalesLineTrackingCoherence(SalesLine: Record "Sales Line")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        ReservEntry: Record "Reservation Entry";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        TotalSecondQty: Decimal;
        TotalBaseQty: Decimal;
        RoundingPrecision: Decimal;
        Difference: Decimal;
        LineSecondQty: Decimal;
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit;
        if SalesLine."No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 SalesLine."No.", SalesLine."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        CalcTrackingDUoMTotalsForSalesLine(SalesLine, TotalSecondQty, TotalBaseQty);
        if (TotalBaseQty = 0) and (TotalSecondQty = 0) then
            exit;

        RoundingPrecision := GetDUoMRoundingPrecision(SalesLine."No.", SecondUoMCode);
        LineSecondQty := Abs(SalesLine."DUoM Second Qty");
        if LineSecondQty > 0 then begin
            Difference := Abs(TotalSecondQty - LineSecondQty);
            if Difference > RoundingPrecision then
                Error(TrackingTotalMismatchErr,
                    SalesLine."Document No.", SalesLine."Line No.",
                    LineSecondQty, SecondUoMCode,
                    TotalSecondQty, Difference, SalesLineTxt);
        end;

        FilterReservEntriesForSalesLine(SalesLine, ReservEntry);
        if ReservEntry.FindSet() then
            repeat
                ValidateSalesReservEntryCoherence(
                    ReservEntry, ConversionMode, FixedRatio,
                    RoundingPrecision, SalesLine."No.");
            until ReservEntry.Next() = 0;
    end;

    /// <summary>
    /// Normalizes DUoM Ratio on a Tracking Specification line when DUoM Second Qty changes.
    ///
    /// In Variable and AlwaysVariable modes: recalculates DUoM Ratio from the entered
    /// secondary quantity using the formula:
    ///   DUoM Ratio := DUoM Second Qty / Abs(Quantity (Base))
    ///
    /// This allows users to inform real pieces during reception without knowing the ratio
    /// in advance. The ratio is derived from the actual measurement on receipt.
    ///
    /// Does nothing in Fixed mode (ratio is fixed and cannot be recalculated from qty).
    /// Does nothing if Quantity (Base) = 0 or DUoM Second Qty = 0 (nothing to derive from).
    /// Does nothing if DUoM is not active for the item.
    ///
    /// Called from: DUoM Item Tracking Lines pageextension (50112) on DUoM Second Qty.OnValidate,
    ///              before ValidateTrackingSpecLine, so validation sees the recalculated ratio.
    /// </summary>
    procedure NormalizeTrackingDUoMSecondQty(var TrackingSpec: Record "Tracking Specification")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        if TrackingSpec."Item No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 TrackingSpec."Item No.", TrackingSpec."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        // Fixed mode: ratio is set by the item configuration, not derived from qty.
        if ConversionMode = ConversionMode::Fixed then
            exit;
        // Nothing to derive from if either qty is zero.
        if TrackingSpec."Quantity (Base)" = 0 then
            exit;
        if TrackingSpec."DUoM Second Qty" = 0 then
            exit;
        // Variable / AlwaysVariable: derive ratio from the real secondary quantity.
        TrackingSpec."DUoM Ratio" := GetExpectedRatio(
            Abs(TrackingSpec."Quantity (Base)"),
            TrackingSpec."DUoM Second Qty");
    end;

    /// <summary>
    /// Normalizes DUoM Ratio on a Tracking Specification line when Quantity (Base) changes.
    ///
    /// In Variable and AlwaysVariable modes: recalculates DUoM Ratio from current
    /// secondary quantity using the formula:
    ///   DUoM Ratio := DUoM Second Qty / Abs(Quantity (Base))
    ///
    /// Does nothing in Fixed mode (ratio is fixed and cannot be recalculated from qty).
    /// Does nothing if Quantity (Base) = 0 or DUoM Second Qty = 0 (nothing to derive from).
    /// Does nothing if DUoM is not active for the item.
    ///
    /// Called from: DUoM Item Tracking Lines pageextension (50112) on
    ///              Quantity (Base).OnAfterValidate, before ValidateTrackingSpecLine.
    /// </summary>
    procedure NormalizeTrackingQuantityBase(var TrackingSpec: Record "Tracking Specification")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        if TrackingSpec."Item No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(
                 TrackingSpec."Item No.", TrackingSpec."Variant Code",
                 SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        if ConversionMode = ConversionMode::Fixed then
            exit;
        if TrackingSpec."Quantity (Base)" = 0 then
            exit;
        if TrackingSpec."DUoM Second Qty" = 0 then
            exit;

        TrackingSpec."DUoM Ratio" := GetExpectedRatio(
            Abs(TrackingSpec."Quantity (Base)"),
            TrackingSpec."DUoM Second Qty");
    end;

    /// <summary>
    /// Validates each functional Tracking Specification line in the buffer for
    /// per-lot DUoM ratio coherence by calling ValidateTrackingSpecLine on every
    /// line that is considered "functional" (has at least one meaningful value).
    ///
    /// Empty/insertion lines (all key fields empty or zero) are silently skipped
    /// so that TestPage insertion rows and page navigation artefacts do not trigger
    /// false-positive validation errors.
    ///
    /// The server-side posting guard (ValidatePurchLineTrackingCoherence, called from
    /// DUoM Purchase Subscribers 50102) remains as a second safety barrier for data
    /// that may arrive via code paths that bypass the Item Tracking Lines UI.
    ///
    /// Cursor safety: iteration uses a LOCAL COPY of TrackingSpec (via Copy(Rec, true))
    /// to avoid modifying the page's Rec cursor.  See docs/development/coding-standards.md.
    ///
    /// Can be called from: production code, posting guards, or unit tests.
    /// </summary>
    procedure ValidateTrackingSpecBufferEachLine(var TrackingSpec: Record "Tracking Specification")
    var
        LocalTrackingSpec: Record "Tracking Specification" temporary;
    begin
        LocalTrackingSpec.Copy(TrackingSpec, true);
        LocalTrackingSpec.Reset();
        if LocalTrackingSpec.FindSet() then
            repeat
                if IsFunctionalTrackingLine(LocalTrackingSpec) then
                    ValidateTrackingSpecLine(LocalTrackingSpec);
            until LocalTrackingSpec.Next() = 0;
    end;

    /// <summary>
    /// Light-weight validation for field-level editing in Item Tracking Lines.
    /// Called from Quantity (Base).OnAfterValidate to provide immediate feedback
    /// without blocking states that are valid during intermediate editing.
    ///
    /// Key difference from ValidateTrackingSpecLine (strict):
    ///   Does NOT raise AlwaysVariableMissingRatioErr when DUoM Second Qty = 0.
    ///   An incomplete line (Qty Base filled but DUoM Second Qty not yet entered)
    ///   is a valid intermediate state during UI editing. The strict validation
    ///   (ValidateTrackingSpecLine) runs at close (ValidateTrackingSpecBufferEachLine)
    ///   and at posting, where incomplete lines are blocked.
    ///
    /// Validates:
    ///   - Fixed ratio mismatch, only when a ratio is already present.
    ///   - Mathematical coherence (Qty × Ratio = Second Qty), only when all three values
    ///     are non-zero.
    ///
    /// Called from: DUoM Item Tracking Lines page extension (50112) on
    ///              Quantity (Base).OnAfterValidate.
    /// </summary>
    procedure ValidateTrackingSpecLineForFieldEdit(TrackingSpec: Record "Tracking Specification")
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

        // If DUoM Ratio is not yet set, allow as intermediate state during editing.
        // Do not enforce AlwaysVariable missing-ratio rule at this point — the user
        // may not have entered DUoM Second Qty yet.
        if TrackingSpec."DUoM Ratio" = 0 then
            exit;

        RoundingPrecision := GetDUoMRoundingPrecision(TrackingSpec."Item No.", SecondUoMCode);

        // Fixed mode: ratio must equal the configured fixed ratio.
        if ConversionMode = ConversionMode::Fixed then
            if Abs(TrackingSpec."DUoM Ratio" - FixedRatio) > 0.00001 then
                Error(FixedRatioMismatchErr,
                    TrackingSpec."Lot No.", TrackingSpec."DUoM Ratio",
                    TrackingSpec."Item No.", FixedRatio);

        // Mathematical coherence: DUoM Second Qty ≈ Qty (Base) × DUoM Ratio.
        // Only validate when all three values are present to allow intermediate editing states.
        if (TrackingSpec."Quantity (Base)" <> 0) and (TrackingSpec."DUoM Second Qty" <> 0) then
            AssertRatioCoherence(
                Abs(TrackingSpec."Quantity (Base)"),
                TrackingSpec."DUoM Second Qty",
                TrackingSpec."DUoM Ratio",
                RoundingPrecision,
                TrackingSpec."Lot No.");
    end;

    /// <summary>
    /// Validates a single Tracking Specification record for DUoM coherence.
    /// Checks ratio against the mode-specific rules (Fixed, Variable, AlwaysVariable)
    /// and verifies the mathematical relationship: DUoM Second Qty ≈ Qty (Base) × DUoM Ratio.
    ///
    /// Called from: DUoM Item Tracking Lines page extension (50112) for UI feedback.
    /// Note: for Variable and AlwaysVariable modes, NormalizeTrackingDUoMSecondQty should
    /// be called BEFORE this procedure when DUoM Second Qty changes, so that the ratio is
    /// already recalculated and the coherence check sees consistent values.
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
        // SetSourceFilter applies the complete standard BC source identity:
        // Source Type, Source Subtype, Source ID, Source Ref. No.,
        // Source Batch Name (='') and Source Prod. Order Line (=0).
        // This prevents including entries from other documents that share the
        // same lot number. See docs/development/coding-standards.md.
        ReservEntry.SetSourceFilter(
            Database::"Purchase Line",
            PurchLine."Document Type".AsInteger(),
            PurchLine."Document No.",
            PurchLine."Line No.",
            true);
        ReservEntry.SetRange(Positive, true);
    end;

    local procedure FilterReservEntriesForSalesLine(
        SalesLine: Record "Sales Line";
        var ReservEntry: Record "Reservation Entry")
    begin
        ReservEntry.Reset();
        ReservEntry.SetSourceFilter(
            Database::"Sales Line",
            SalesLine."Document Type".AsInteger(),
            SalesLine."Document No.",
            SalesLine."Line No.",
            true);
        ReservEntry.SetRange(Positive, false);
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

    local procedure ValidateSalesReservEntryCoherence(
        ReservEntry: Record "Reservation Entry";
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        RoundingPrecision: Decimal;
        ItemNo: Code[20])
    begin
        if ReservEntry."DUoM Ratio" = 0 then begin
            if ConversionMode = ConversionMode::AlwaysVariable then
                if ReservEntry."Quantity (Base)" <> 0 then
                    Error(AlwaysVariableMissingRatioErr, ItemNo, ReservEntry."Lot No.");
            exit;
        end;

        if ConversionMode = ConversionMode::Fixed then
            if Abs(ReservEntry."DUoM Ratio" - FixedRatio) > 0.00001 then
                Error(FixedRatioMismatchErr,
                    ReservEntry."Lot No.", ReservEntry."DUoM Ratio", ItemNo, FixedRatio);

        if (ReservEntry."Quantity (Base)" <> 0) and (ReservEntry."DUoM Second Qty" <> 0) then
            AssertRatioCoherence(
                Abs(ReservEntry."Quantity (Base)"),
                Abs(ReservEntry."DUoM Second Qty"),
                ReservEntry."DUoM Ratio",
                RoundingPrecision,
                ReservEntry."Lot No.");
    end;

    local procedure CalcTrackingDUoMTotalsForSalesLine(
        SalesLine: Record "Sales Line";
        var TotalSecondQty: Decimal;
        var TotalBaseQty: Decimal)
    var
        ReservEntry: Record "Reservation Entry";
    begin
        TotalSecondQty := 0;
        TotalBaseQty := 0;
        FilterReservEntriesForSalesLine(SalesLine, ReservEntry);
        if ReservEntry.FindSet() then
            repeat
                TotalSecondQty += Abs(ReservEntry."DUoM Second Qty");
                TotalBaseQty += Abs(ReservEntry."Quantity (Base)");
            until ReservEntry.Next() = 0;
    end;

    /// <summary>
    /// Returns true when the Tracking Specification line has at least one meaningful
    /// value (Lot No., Serial No., Package No., Quantity (Base), DUoM Second Qty, or
    /// DUoM Ratio is non-empty/non-zero).
    ///
    /// Empty/insertion lines — rows visible in the TestPage or the standard page
    /// during editing but not yet filled in — have all these fields empty or zero
    /// and are therefore not functional.  They must be silently skipped during
    /// aggregate validation to avoid false-positive DUoM coherence errors.
    /// </summary>
    local procedure IsFunctionalTrackingLine(TrackingSpec: Record "Tracking Specification"): Boolean
    var
        DUoMTrackingPropMgt: Codeunit "DUoM Tracking Prop. Mgt";
    begin
        exit(DUoMTrackingPropMgt.IsFunctionalTrackingLine(TrackingSpec));
    end;

    var
        TrackingTotalMismatchErr: Label 'The DUoM secondary quantity assigned in the tracking lines does not match the DUoM quantity on the %7.\\Document: %1\\Line No.: %2\\%7 DUoM Qty: %3 %4\\Tracking DUoM Qty: %5 %4\\Difference: %6 %4',
            Comment = '%1 = Document No., %2 = Line No., %3 = Source Line DUoM Second Qty (abs), %4 = Second UoM Code, %5 = Total Tracking DUoM Qty (abs), %6 = Difference, %7 = Source line caption (purchase line / sales line)';
        RatioIncoherenceErr: Label 'Lot %1 has an inconsistent DUoM ratio.\\Base Qty: %2\\Secondary Qty: %3\\Stated Ratio: %4\\Expected Ratio: %5',
            Comment = '%1 = Lot No., %2 = Base Qty, %3 = Secondary Qty, %4 = Stated Ratio, %5 = Expected Ratio';
        AlwaysVariableMissingRatioErr: Label 'Item %1 requires a variable DUoM ratio per lot, but lot %2 does not have a valid ratio.',
            Comment = '%1 = Item No., %2 = Lot No.';
        FixedRatioMismatchErr: Label 'Lot %1 uses a DUoM ratio (%2) that differs from the fixed ratio configured for item %3 (%4).',
            Comment = '%1 = Lot No., %2 = Actual Ratio, %3 = Item No., %4 = Fixed Ratio';
        PurchLineTxt: Label 'purchase line',
            Comment = 'Caption used in DUoM coherence total mismatch errors for purchase source lines; no placeholders.';
        SalesLineTxt: Label 'sales line',
            Comment = 'Caption used in DUoM coherence total mismatch errors for sales source lines; no placeholders.';
}
