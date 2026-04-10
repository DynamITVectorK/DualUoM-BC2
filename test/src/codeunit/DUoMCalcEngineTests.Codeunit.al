/// <summary>
/// Unit tests for the DUoM Calc Engine (Codeunit 50101).
/// Covers all conversion modes, edge cases, and error conditions.
/// </summary>
codeunit 50204 "DUoM Calc Engine Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // Fixed mode — valid input → product
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_FixedMode_ValidInput_ReturnsProduct()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] FirstQty = 10, Ratio = 0.8, Mode = Fixed
        // [WHEN] ComputeSecondQty is called
        Result := CalcEngine.ComputeSecondQty(10, 0.8, "DUoM Conversion Mode"::Fixed);

        // [THEN] Result = 10 × 0.8 = 8 (the lettuce example: 10 KG → 8 pieces)
        LibraryAssert.AreEqual(8, Result, 'Fixed mode: 10 KG × 0.8 ratio should yield 8 pieces');
    end;

    // -------------------------------------------------------------------------
    // Fixed mode — zero ratio → error
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_FixedMode_ZeroRatio_Error()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Mode = Fixed, Ratio = 0
        // [WHEN] ComputeSecondQty is called
        asserterror CalcEngine.ComputeSecondQty(10, 0, "DUoM Conversion Mode"::Fixed);

        // [THEN] An error about zero ratio in Fixed mode is raised
        LibraryAssert.ExpectedError('Ratio must be greater than zero when Conversion Mode is Fixed');
    end;

    // -------------------------------------------------------------------------
    // Fixed mode — negative ratio → error
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_FixedMode_NegativeRatio_Error()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Mode = Fixed, Ratio = -1
        // [WHEN] ComputeSecondQty is called
        asserterror CalcEngine.ComputeSecondQty(10, -1, "DUoM Conversion Mode"::Fixed);

        // [THEN] An error about zero ratio in Fixed mode is raised (negative also fails the > 0 check)
        LibraryAssert.ExpectedError('Ratio must be greater than zero when Conversion Mode is Fixed');
    end;

    // -------------------------------------------------------------------------
    // Fixed mode — negative quantity → error
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_FixedMode_NegativeQty_Error()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] FirstQty = -5, Mode = Fixed, Ratio = 1
        // [WHEN] ComputeSecondQty is called
        asserterror CalcEngine.ComputeSecondQty(-5, 1, "DUoM Conversion Mode"::Fixed);

        // [THEN] An error about negative quantity is raised
        LibraryAssert.ExpectedError('Quantity cannot be negative');
    end;

    // -------------------------------------------------------------------------
    // Fixed mode — zero quantity → result is zero (not an error)
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_FixedMode_ZeroQty_ReturnsZero()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] FirstQty = 0, Mode = Fixed, Ratio = 1.25
        // [WHEN] ComputeSecondQty is called
        Result := CalcEngine.ComputeSecondQty(0, 1.25, "DUoM Conversion Mode"::Fixed);

        // [THEN] Result = 0 × 1.25 = 0 — zero quantity is valid
        LibraryAssert.AreEqual(0, Result, 'Fixed mode: zero quantity should yield zero second qty');
    end;

    // -------------------------------------------------------------------------
    // Fixed mode — fractional ratio → correct decimal result
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_FixedMode_FractionalRatio_ReturnsCorrectValue()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] FirstQty = 3, Ratio = 1.33333, Mode = Fixed
        // [WHEN] ComputeSecondQty is called
        Result := CalcEngine.ComputeSecondQty(3, 1.33333, "DUoM Conversion Mode"::Fixed);

        // [THEN] Result = 3 × 1.33333 = 3.99999
        LibraryAssert.AreEqual(3.99999, Result, 'Fixed mode: fractional ratio should produce correct decimal result');
    end;

    // -------------------------------------------------------------------------
    // Variable mode — positive ratio → product
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_VariableMode_PositiveRatio_ReturnsProduct()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] FirstQty = 5, Ratio = 2, Mode = Variable
        // [WHEN] ComputeSecondQty is called
        Result := CalcEngine.ComputeSecondQty(5, 2, "DUoM Conversion Mode"::Variable);

        // [THEN] Result = 5 × 2 = 10
        LibraryAssert.AreEqual(10, Result, 'Variable mode with positive ratio should yield the product');
    end;

    // -------------------------------------------------------------------------
    // Variable mode — zero ratio → zero (not an error; no default set yet)
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_VariableMode_ZeroRatio_ReturnsZero()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] FirstQty = 10, Ratio = 0, Mode = Variable
        // [WHEN] ComputeSecondQty is called
        Result := CalcEngine.ComputeSecondQty(10, 0, "DUoM Conversion Mode"::Variable);

        // [THEN] Result = 0 — Variable mode with no ratio is valid (user may enter manually)
        LibraryAssert.AreEqual(0, Result, 'Variable mode with zero ratio should yield zero without error');
    end;

    // -------------------------------------------------------------------------
    // Variable mode — negative ratio → error
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_VariableMode_NegativeRatio_Error()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] FirstQty = 10, Ratio = -0.5, Mode = Variable
        // [WHEN] ComputeSecondQty is called
        asserterror CalcEngine.ComputeSecondQty(10, -0.5, "DUoM Conversion Mode"::Variable);

        // [THEN] An error about negative ratio is raised
        LibraryAssert.ExpectedError('Ratio cannot be negative');
    end;

    // -------------------------------------------------------------------------
    // Variable mode — negative quantity → error
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_VariableMode_NegativeQty_Error()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] FirstQty = -1, Mode = Variable, Ratio = 1.5
        // [WHEN] ComputeSecondQty is called
        asserterror CalcEngine.ComputeSecondQty(-1, 1.5, "DUoM Conversion Mode"::Variable);

        // [THEN] Negative quantity error is raised before ratio check
        LibraryAssert.ExpectedError('Quantity cannot be negative');
    end;

    // -------------------------------------------------------------------------
    // Always Variable mode — always returns zero regardless of inputs
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_AlwaysVariable_ReturnsZero()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] FirstQty = 100, Ratio = 5, Mode = AlwaysVariable
        // [WHEN] ComputeSecondQty is called
        Result := CalcEngine.ComputeSecondQty(100, 5, "DUoM Conversion Mode"::AlwaysVariable);

        // [THEN] Result = 0 — the engine never computes for AlwaysVariable mode
        LibraryAssert.AreEqual(0, Result, 'AlwaysVariable mode should always return 0 regardless of inputs');
    end;

    // -------------------------------------------------------------------------
    // Always Variable mode — zero ratio and zero qty also returns zero
    // -------------------------------------------------------------------------

    [Test]
    procedure ComputeSecondQty_AlwaysVariable_ZeroInputs_ReturnsZero()
    var
        CalcEngine: Codeunit "DUoM Calc Engine";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] FirstQty = 0, Ratio = 0, Mode = AlwaysVariable
        // [WHEN] ComputeSecondQty is called
        Result := CalcEngine.ComputeSecondQty(0, 0, "DUoM Conversion Mode"::AlwaysVariable);

        // [THEN] Result = 0 — AlwaysVariable always returns zero
        LibraryAssert.AreEqual(0, Result, 'AlwaysVariable with zero inputs should return zero without error');
    end;
}
