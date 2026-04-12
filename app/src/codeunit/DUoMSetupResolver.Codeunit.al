/// <summary>
/// Centralises the resolution of the effective DUoM configuration for a given
/// (Item No., Variant Code) combination, implementing the hierarchy:
///
///   1. Item-level setup (DUoM Item Setup, table 50100) is the master switch.
///      If the item has no DUoM setup record, or DUoM is disabled, DUoM is off.
///
///   2. If VariantCode is non-blank and a DUoM Item Variant Setup record exists
///      for (ItemNo, VariantCode), the variant fields (Second UoM Code,
///      Conversion Mode, Fixed Ratio) override the item-level values.
///
///   3. Otherwise the item-level fields are used as-is.
///
/// Usage:
///   if not DUoMSetupResolver.GetEffectiveSetup(ItemNo, VariantCode,
///       SecondUoMCode, ConversionMode, FixedRatio) then exit;
/// </summary>
codeunit 50107 "DUoM Setup Resolver"
{
    Access = Internal;

    /// <summary>
    /// Resolves the effective DUoM setup for the given item and variant combination.
    /// Returns TRUE when DUoM is active and populates the out-parameters.
    /// Returns FALSE when the item has no DUoM setup or DUoM is disabled — in that
    /// case the out-parameters are left at their caller-initialised values.
    /// </summary>
    /// <param name="ItemNo">Item number to resolve.</param>
    /// <param name="VariantCode">Variant code; pass empty string when there is none.</param>
    /// <param name="SecondUoMCode">Receives the effective secondary UoM code.</param>
    /// <param name="ConversionMode">Receives the effective conversion mode.</param>
    /// <param name="FixedRatio">Receives the effective fixed ratio (0 for AlwaysVariable).</param>
    /// <returns>True when DUoM is enabled for the item; false otherwise.</returns>
    procedure GetEffectiveSetup(
        ItemNo: Code[20];
        VariantCode: Code[10];
        var SecondUoMCode: Code[10];
        var ConversionMode: Enum "DUoM Conversion Mode";
        var FixedRatio: Decimal): Boolean
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
    begin
        // Item-level setup is the master switch — no record or disabled means DUoM off.
        if not DUoMItemSetup.Get(ItemNo) then
            exit(false);
        if not DUoMItemSetup."Dual UoM Enabled" then
            exit(false);

        // Variant override takes precedence when a record exists for this variant.
        if (VariantCode <> '') and DUoMVariantSetup.Get(ItemNo, VariantCode) then begin
            SecondUoMCode := DUoMVariantSetup."Second UoM Code";
            ConversionMode := DUoMVariantSetup."Conversion Mode";
            FixedRatio := DUoMVariantSetup."Fixed Ratio";
        end else begin
            // Fall back to item-level setup.
            SecondUoMCode := DUoMItemSetup."Second UoM Code";
            ConversionMode := DUoMItemSetup."Conversion Mode";
            FixedRatio := DUoMItemSetup."Fixed Ratio";
        end;

        exit(true);
    end;
}
