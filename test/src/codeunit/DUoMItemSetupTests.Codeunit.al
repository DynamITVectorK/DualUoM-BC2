/// <summary>
/// Tests for DUoM Item Setup validation logic (Table 50100 "DUoM Item Setup").
/// All tests operate on in-memory records or temporary inserts and validate
/// the core business rules for the item-level DUoM configuration.
/// </summary>
codeunit 50201 "DUoM Item Setup Tests"
{
    Subtype = Test;

    // -------------------------------------------------------------------------
    // ValidateSetup() — disabled item
    // -------------------------------------------------------------------------

    [Test]
    procedure ValidateSetup_DUoMDisabled_NoError()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A DUoM Item Setup record with DUoM disabled
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := 'TEST-DISABLED';
        DUoMItemSetup."Dual UoM Enabled" := false;

        // [WHEN] ValidateSetup is called
        DUoMItemSetup.ValidateSetup();

        // [THEN] No error is raised — disabled items are always valid at setup level
        LibraryAssert.IsTrue(true, 'ValidateSetup should not raise an error for disabled DUoM');
    end;

    // -------------------------------------------------------------------------
    // ValidateSetup() — missing Second UoM Code
    // -------------------------------------------------------------------------

    [Test]
    procedure ValidateSetup_EnabledWithoutSecondUoM_Error()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] DUoM enabled but Second UoM Code is empty
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := 'TEST-NOUOM';
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := '';

        // [WHEN] ValidateSetup is called
        asserterror DUoMItemSetup.ValidateSetup();

        // [THEN] An error about missing Second UoM Code is raised
        LibraryAssert.ExpectedError('Second UoM Code must be specified when Dual UoM is enabled');
    end;

    // -------------------------------------------------------------------------
    // ValidateSetup() — Fixed conversion mode without ratio
    // -------------------------------------------------------------------------

    [Test]
    procedure ValidateSetup_FixedModeZeroRatio_Error()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] DUoM enabled, Fixed conversion mode, Fixed Ratio = 0
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := 'TEST-FIXED0';
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::Fixed;
        DUoMItemSetup."Fixed Ratio" := 0;

        // [WHEN] ValidateSetup is called
        asserterror DUoMItemSetup.ValidateSetup();

        // [THEN] An error about the missing Fixed Ratio is raised
        LibraryAssert.ExpectedError('Fixed Ratio must be greater than zero when Conversion Mode is Fixed');
    end;

    // -------------------------------------------------------------------------
    // ValidateSetup() — Variable conversion without ratio is valid
    // -------------------------------------------------------------------------

    [Test]
    procedure ValidateSetup_VariableModeNoRatio_NoError()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] DUoM enabled with Variable conversion and no Fixed Ratio
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := 'TEST-VAR';
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::Variable;
        DUoMItemSetup."Fixed Ratio" := 0;

        // [WHEN] ValidateSetup is called
        DUoMItemSetup.ValidateSetup();

        // [THEN] No error — Variable conversion does not require a fixed ratio
        LibraryAssert.IsTrue(true, 'Variable conversion with no fixed ratio should be valid');
    end;

    // -------------------------------------------------------------------------
    // ValidateSetup() — Always Variable conversion is valid without ratio
    // -------------------------------------------------------------------------

    [Test]
    procedure ValidateSetup_AlwaysVariableModeNoRatio_NoError()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] DUoM enabled with Always Variable conversion and no Fixed Ratio
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := 'TEST-ALWAYSVAR';
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::AlwaysVariable;
        DUoMItemSetup."Fixed Ratio" := 0;

        // [WHEN] ValidateSetup is called
        DUoMItemSetup.ValidateSetup();

        // [THEN] No error — Always Variable conversion requires no ratio at item level
        LibraryAssert.IsTrue(true, 'Always Variable conversion with no fixed ratio should be valid');
    end;

    // -------------------------------------------------------------------------
    // Validate trigger: disabling DUoM clears dependent fields
    // -------------------------------------------------------------------------

    [Test]
    procedure Validate_DUoMDisabled_ClearsSecondUoMAndRatio()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A setup with DUoM enabled, a Second UoM Code, and a Fixed Ratio
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := 'TEST-CLEAR';
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::Fixed;
        DUoMItemSetup."Fixed Ratio" := 1.25;

        // [WHEN] Dual UoM Enabled is set to false via Validate
        DUoMItemSetup.Validate("Dual UoM Enabled", false);

        // [THEN] Second UoM Code and Fixed Ratio are cleared; Conversion Mode is reset
        LibraryAssert.AreEqual('', DUoMItemSetup."Second UoM Code", 'Second UoM Code must be cleared when DUoM is disabled');
        LibraryAssert.AreEqual(0, DUoMItemSetup."Fixed Ratio", 'Fixed Ratio must be cleared when DUoM is disabled');
        LibraryAssert.AreEqual(DUoMItemSetup."Conversion Mode"::Fixed, DUoMItemSetup."Conversion Mode", 'Conversion Mode must reset to Fixed when DUoM is disabled');
    end;

    // -------------------------------------------------------------------------
    // Validate trigger: switching to Variable clears Fixed Ratio
    // -------------------------------------------------------------------------

    [Test]
    procedure Validate_ConversionModeToVariable_ClearsFixedRatio()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A setup with Fixed conversion mode and a non-zero Fixed Ratio
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := 'TEST-TOVAR';
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::Fixed;
        DUoMItemSetup."Fixed Ratio" := 2.5;

        // [WHEN] Conversion Mode is changed to Variable via Validate
        DUoMItemSetup.Validate("Conversion Mode", DUoMItemSetup."Conversion Mode"::Variable);

        // [THEN] Fixed Ratio is cleared
        LibraryAssert.AreEqual(0, DUoMItemSetup."Fixed Ratio", 'Fixed Ratio must be cleared when switching to Variable mode');
    end;

    // -------------------------------------------------------------------------
    // Validate trigger: switching to Always Variable clears Fixed Ratio
    // -------------------------------------------------------------------------

    [Test]
    procedure Validate_ConversionModeToAlwaysVariable_ClearsFixedRatio()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] A setup with Fixed conversion mode and a non-zero Fixed Ratio
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := 'TEST-TOALWAYSVAR';
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::Fixed;
        DUoMItemSetup."Fixed Ratio" := 2.5;

        // [WHEN] Conversion Mode is changed to Always Variable via Validate
        DUoMItemSetup.Validate("Conversion Mode", DUoMItemSetup."Conversion Mode"::AlwaysVariable);

        // [THEN] Fixed Ratio is cleared
        LibraryAssert.AreEqual(0, DUoMItemSetup."Fixed Ratio", 'Fixed Ratio must be cleared when switching to Always Variable mode');
    end;

    // -------------------------------------------------------------------------
    // ValidateSetup() — Fixed conversion with a valid positive ratio passes
    // -------------------------------------------------------------------------

    [Test]
    procedure ValidateSetup_FixedModeWithPositiveRatio_NoError()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] DUoM enabled with Fixed conversion and a positive ratio
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := 'TEST-FIXEDOK';
        DUoMItemSetup."Dual UoM Enabled" := true;
        DUoMItemSetup."Second UoM Code" := 'PCS';
        DUoMItemSetup."Conversion Mode" := DUoMItemSetup."Conversion Mode"::Fixed;
        DUoMItemSetup."Fixed Ratio" := 1.25;

        // [WHEN] ValidateSetup is called
        DUoMItemSetup.ValidateSetup();

        // [THEN] No error is raised — the setup is complete and consistent
        LibraryAssert.IsTrue(true, 'Fixed conversion with a positive ratio should be valid');
    end;
}
