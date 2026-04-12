/// <summary>
/// Core calculation engine for Dual Unit of Measure conversions.
/// Provides a single deterministic function for computing the second quantity
/// given a primary (first) quantity, a conversion ratio, and a conversion mode.
/// This codeunit contains no global state and is safe to call from any context.
/// </summary>
codeunit 50101 "DUoM Calc Engine"
{
    Access = Public;

    /// <summary>
    /// Computes the second (secondary) quantity from the primary quantity and ratio.
    /// Behaviour varies by Conversion Mode:
    ///   Fixed         – SecondQty = FirstQty × Ratio; error if Ratio ≤ 0 or FirstQty &lt; 0.
    ///   Variable      – SecondQty = FirstQty × Ratio when Ratio > 0; 0 when Ratio = 0;
    ///                   error if Ratio &lt; 0 or FirstQty &lt; 0.
    ///   AlwaysVariable – Returns 0; the user enters the value manually on each document line.
    /// </summary>
    /// <param name="FirstQty">The primary quantity (must be ≥ 0).</param>
    /// <param name="Ratio">The conversion ratio (constraints depend on Mode).</param>
    /// <param name="Mode">The conversion mode that determines the computation rules.</param>
    /// <returns>The computed secondary quantity, or 0 for AlwaysVariable mode.</returns>
    procedure ComputeSecondQty(FirstQty: Decimal; Ratio: Decimal; Mode: Enum "DUoM Conversion Mode"): Decimal
    begin
        if FirstQty < 0 then
            Error(NegativeQtyErr);

        case Mode of
            Mode::Fixed:
                begin
                    if Ratio <= 0 then
                        Error(ZeroRatioFixedErr);
                    exit(FirstQty * Ratio);
                end;
            Mode::Variable:
                begin
                    if Ratio < 0 then
                        Error(NegativeRatioVariableErr);
                    if Ratio = 0 then
                        exit(0);
                    exit(FirstQty * Ratio);
                end;
            Mode::AlwaysVariable:
                // User enters the second quantity manually on each line; engine returns 0.
                exit(0);
            else
                // Guard against future enum values added by other extensions.
                Error(UnsupportedModeErr, Mode);
        end;
    end;

    /// <summary>
    /// Same as ComputeSecondQty but applies Round() using the secondary UoM rounding precision.
    /// When RoundingPrecision = 0, a fallback of 0.00001 is used (maximum precision),
    /// which reproduces the unrounded behaviour of ComputeSecondQty.
    /// For AlwaysVariable mode the result is always 0 and no rounding is applied.
    /// </summary>
    /// <param name="FirstQty">The primary quantity (must be ≥ 0).</param>
    /// <param name="Ratio">The conversion ratio (constraints depend on Mode).</param>
    /// <param name="Mode">The conversion mode that determines the computation rules.</param>
    /// <param name="RoundingPrecision">The Rounding Precision of the secondary UoM (0 = fallback to 0.00001).</param>
    /// <returns>The rounded secondary quantity, or 0 for AlwaysVariable mode.</returns>
    procedure ComputeSecondQtyRounded(FirstQty: Decimal; Ratio: Decimal;
        Mode: Enum "DUoM Conversion Mode"; RoundingPrecision: Decimal): Decimal
    var
        Result: Decimal;
        EffectivePrecision: Decimal;
    begin
        Result := ComputeSecondQty(FirstQty, Ratio, Mode);
        if Mode = Mode::AlwaysVariable then
            exit(Result);
        EffectivePrecision := RoundingPrecision;
        if EffectivePrecision <= 0 then
            EffectivePrecision := 0.00001;
        exit(Round(Result, EffectivePrecision));
    end;

    var
        NegativeQtyErr: Label 'Quantity cannot be negative.', Comment = 'Validation error; no placeholders.';
        ZeroRatioFixedErr: Label 'Ratio must be greater than zero when Conversion Mode is Fixed.', Comment = 'Validation error; no placeholders.';
        NegativeRatioVariableErr: Label 'Ratio cannot be negative.', Comment = 'Validation error; no placeholders.';
        UnsupportedModeErr: Label 'Conversion Mode %1 is not supported by the DUoM Calc Engine.', Comment = '%1 = Conversion Mode value';
}
