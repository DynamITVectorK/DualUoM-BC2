/// <summary>
/// Event subscribers for Dual Unit of Measure lot-ratio auto-fill.
/// When a Lot No. is validated on a Purchase Line, Sales Line or Item Journal Line
/// for an item with DUoM enabled, this codeunit looks up the DUoM Lot Ratio record
/// and – depending on the conversion mode – pre-fills DUoM Ratio and recalculates
/// DUoM Second Qty on that line.
///
/// Behaviour by conversion mode (RT-02):
///   Fixed         – lot ratio is NEVER applied; the fixed setup ratio always prevails.
///   Variable      – if a lot ratio exists, DUoM Ratio and DUoM Second Qty are updated.
///   AlwaysVariable – if a lot ratio exists, DUoM Ratio is pre-filled as an editable
///                   suggestion; DUoM Second Qty is recalculated (returns 0 for this
///                   mode, user enters it manually).
///
/// Signature verification note (RT-01):
///   The "Lot No." field exists directly on Purchase Line (table 39), Sales Line (table 37)
///   and Item Journal Line (table 83) in BC 27 / runtime 15. These fields are part of the
///   standard item-tracking-by-lot functionality and are available for OnAfterValidateEvent
///   subscribers. Confirmed against BC 27 standard table definitions.
/// </summary>
codeunit 50108 "DUoM Lot Subscribers"
{
    Access = Internal;

    // =========================================================================
    // Purchase Line — Lot No. validate
    // Publisher: Table "Purchase Line" (39), Event: OnAfterValidateEvent, Field: Lot No.
    // Chosen because this is the standard integration point for field-level
    // validation events on Purchase Line in BC 27 (runtime 15).
    // Signature verified: var Rec, var xRec are the standard thin-subscriber
    // parameters for table OnAfterValidateEvent.
    // =========================================================================

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterValidateEvent', 'Lot No.', false, false)]
    local procedure OnAfterValidatePurchLineLotNo(var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        if Rec.Type <> Rec.Type::Item then
            exit;
        if Rec."No." = '' then
            exit;
        if Rec."Lot No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(Rec."No.", Rec."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        ApplyLotRatioIfExists(Rec."No.", Rec."Lot No.", ConversionMode, Rec."DUoM Ratio", Rec."DUoM Second Qty", Rec.Quantity, SecondUoMCode);
    end;

    // =========================================================================
    // Sales Line — Lot No. validate
    // Publisher: Table "Sales Line" (37), Event: OnAfterValidateEvent, Field: Lot No.
    // Chosen for the same reason as the Purchase Line subscriber above.
    // Signature verified: same thin-subscriber pattern as for Purchase Line.
    // =========================================================================

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'Lot No.', false, false)]
    local procedure OnAfterValidateSalesLineLotNo(var Rec: Record "Sales Line"; var xRec: Record "Sales Line")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        if Rec.Type <> Rec.Type::Item then
            exit;
        if Rec."No." = '' then
            exit;
        if Rec."Lot No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(Rec."No.", Rec."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        ApplyLotRatioIfExists(Rec."No.", Rec."Lot No.", ConversionMode, Rec."DUoM Ratio", Rec."DUoM Second Qty", Rec.Quantity, SecondUoMCode);
    end;

    // =========================================================================
    // Item Journal Line — Lot No. validate
    // Publisher: Table "Item Journal Line" (83), Event: OnAfterValidateEvent, Field: Lot No.
    // "Lot No." is a direct field on Item Journal Line (table 83) in BC 27.
    // Chosen to cover manual inventory adjustments and journal postings.
    // Signature verified: var Rec, var xRec thin-subscriber pattern.
    // =========================================================================

    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterValidateEvent', 'Lot No.', false, false)]
    local procedure OnAfterValidateItemJnlLineLotNo(var Rec: Record "Item Journal Line"; var xRec: Record "Item Journal Line")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
    begin
        if Rec."Item No." = '' then
            exit;
        if Rec."Lot No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(Rec."Item No.", Rec."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        ApplyLotRatioIfExists(Rec."Item No.", Rec."Lot No.", ConversionMode, Rec."DUoM Ratio", Rec."DUoM Second Qty", Rec.Quantity, SecondUoMCode);
    end;

    // =========================================================================
    // Centralized helper — applies lot ratio when applicable (RT-02)
    // =========================================================================

    /// <summary>
    /// Looks up the DUoM Lot Ratio for (ItemNo, LotNo) and, if found, updates
    /// DUoMRatio and recalculates DUoMSecondQty according to the conversion mode.
    ///   Fixed:         exits immediately — lot ratio never overrides the fixed ratio.
    ///   Variable:      applies the lot ratio and recalculates DUoM Second Qty.
    ///   AlwaysVariable: pre-fills DUoM Ratio as an editable suggestion;
    ///                   DUoM Second Qty stays 0 (user enters it manually).
    /// If no DUoM Lot Ratio record exists for the (ItemNo, LotNo) pair, the method
    /// exits without modifying DUoMRatio or DUoMSecondQty (RF-02).
    /// </summary>
    local procedure ApplyLotRatioIfExists(
        ItemNo: Code[20];
        LotNo: Code[50];
        ConversionMode: Enum "DUoM Conversion Mode";
        var DUoMRatio: Decimal;
        var DUoMSecondQty: Decimal;
        Quantity: Decimal;
        SecondUoMCode: Code[10])
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
    begin
        // RF-06: Fixed mode — lot ratio never overrides the fixed setup ratio.
        if ConversionMode = ConversionMode::Fixed then
            exit;

        // RF-03 / RF-04 / RF-05: if no lot ratio record exists, leave unchanged.
        if not DUoMLotRatio.Get(ItemNo, LotNo) then
            exit;

        // RF-03/04/05/07: apply the lot ratio and recalculate second qty.
        DUoMRatio := DUoMLotRatio."Actual Ratio";
        DUoMSecondQty := DUoMCalcEngine.ComputeSecondQtyRounded(
            Quantity, DUoMRatio, ConversionMode,
            DUoMUoMHelper.GetRoundingPrecisionByUoMCode(ItemNo, SecondUoMCode));
    end;
}
