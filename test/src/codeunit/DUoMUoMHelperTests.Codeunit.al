/// <summary>
/// Tests unitarios para DUoM UoM Helper (Codeunit 50106).
/// Verifica los métodos GetSecondUoMRoundingPrecision y
/// GetRoundingPrecisionByUoMCode bajo todos los escenarios de
/// configuración relevantes: item sin setup, setup con UoM vacío,
/// setup con UoM que no tiene Item Unit of Measure, y setup completo
/// y válido que devuelve la precisión configurada.
/// </summary>
codeunit 50213 "DUoM UoM Helper Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // =========================================================================
    // GetSecondUoMRoundingPrecision
    // =========================================================================

    // -------------------------------------------------------------------------
    // Item sin DUoM Item Setup → devuelve 0
    // -------------------------------------------------------------------------

    [Test]
    procedure GetSecondUoMRndPrec_NoSetup_ReturnsZero()
    var
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        Item: Record Item;
    begin
        // [GIVEN] Un artículo sin registro DUoM Item Setup
        LibraryInventory.CreateItem(Item);

        // [WHEN] Se llama a GetSecondUoMRoundingPrecision
        // [THEN] Devuelve 0 — no existe configuración DUoM para el artículo
        LibraryAssert.AreEqual(
            0,
            DUoMUoMHelper.GetSecondUoMRoundingPrecision(Item."No."),
            'Debe devolver 0 cuando no existe DUoM Item Setup para el artículo');

        // Cleanup
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Setup existe pero Second UoM Code está vacío → devuelve 0
    // -------------------------------------------------------------------------

    [Test]
    procedure GetSecondUoMRndPrec_BlankSecondUoM_ReturnsZero()
    var
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        Item: Record Item;
    begin
        // [GIVEN] Un artículo con DUoM Item Setup donde Second UoM Code está vacío
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, '', "DUoM Conversion Mode"::Fixed, 1);

        // [WHEN] Se llama a GetSecondUoMRoundingPrecision
        // [THEN] Devuelve 0 — no hay UoM secundaria configurada
        LibraryAssert.AreEqual(
            0,
            DUoMUoMHelper.GetSecondUoMRoundingPrecision(Item."No."),
            'Debe devolver 0 cuando Second UoM Code está vacío en DUoM Item Setup');

        // Cleanup
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Setup apunta a UoM sin registro Item Unit of Measure → devuelve 0
    // -------------------------------------------------------------------------

    [Test]
    procedure GetSecondUoMRndPrec_NoItemUoMRecord_ReturnsZero()
    var
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        Item: Record Item;
    begin
        // [GIVEN] Un artículo con DUoM Item Setup apuntando a 'GHOST' (código inexistente en Item UoM)
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'GHOST', "DUoM Conversion Mode"::Fixed, 1);

        // [WHEN] Se llama a GetSecondUoMRoundingPrecision
        // [THEN] Devuelve 0 — no existe Item Unit of Measure para (Item, 'GHOST')
        LibraryAssert.AreEqual(
            0,
            DUoMUoMHelper.GetSecondUoMRoundingPrecision(Item."No."),
            'Debe devolver 0 cuando no existe Item Unit of Measure para la UoM secundaria configurada');

        // Cleanup
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Setup válido con Item Unit of Measure configurado → devuelve la precisión
    // -------------------------------------------------------------------------

    [Test]
    procedure GetSecondUoMRndPrec_ValidSetup_ReturnsPrecision()
    var
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        Item: Record Item;
        UnitOfMeasure: Record "Unit of Measure";
        ItemUoM: Record "Item Unit of Measure";
        UoMCode: Code[10];
    begin
        // [GIVEN] Un artículo con una UoM secundaria con Qty. Rounding Precision = 1
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateUnitOfMeasureCode(UnitOfMeasure);
        UoMCode := UnitOfMeasure.Code;
        LibraryInventory.CreateItemUnitOfMeasure(ItemUoM, Item."No.", UoMCode, 1);
        ItemUoM."Qty. Rounding Precision" := 1;
        ItemUoM.Modify(false);

        // [GIVEN] DUoM Item Setup apuntando a esa UoM secundaria
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, UoMCode, "DUoM Conversion Mode"::Fixed, 1);

        // [WHEN] Se llama a GetSecondUoMRoundingPrecision
        // [THEN] Devuelve 1 — la precisión de redondeo del registro Item Unit of Measure
        LibraryAssert.AreEqual(
            1,
            DUoMUoMHelper.GetSecondUoMRoundingPrecision(Item."No."),
            'Debe devolver la Qty. Rounding Precision configurada en Item Unit of Measure');

        // Cleanup
        DUoMTestHelpers.DeleteItemSetupIfExists(Item."No.");
        Item.Delete(false);
    end;

    // =========================================================================
    // GetRoundingPrecisionByUoMCode
    // =========================================================================

    // -------------------------------------------------------------------------
    // Código de UoM vacío → devuelve 0
    // -------------------------------------------------------------------------

    [Test]
    procedure GetRndPrecByUoMCode_BlankCode_ReturnsZero()
    var
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        Item: Record Item;
    begin
        // [GIVEN] Un artículo cualquiera
        LibraryInventory.CreateItem(Item);

        // [WHEN] Se llama a GetRoundingPrecisionByUoMCode con código vacío
        // [THEN] Devuelve 0 — el código vacío provoca salida anticipada
        LibraryAssert.AreEqual(
            0,
            DUoMUoMHelper.GetRoundingPrecisionByUoMCode(Item."No.", ''),
            'Debe devolver 0 cuando SecondUoMCode está vacío');

        // Cleanup
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Código de UoM dado sin registro Item Unit of Measure → devuelve 0
    // -------------------------------------------------------------------------

    [Test]
    procedure GetRndPrecByUoMCode_NoItemUoM_ReturnsZero()
    var
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        Item: Record Item;
    begin
        // [GIVEN] Un artículo sin el código de UoM 'GHOST' registrado en Item Unit of Measure
        LibraryInventory.CreateItem(Item);

        // [WHEN] Se llama a GetRoundingPrecisionByUoMCode con 'GHOST'
        // [THEN] Devuelve 0 — no existe registro Item Unit of Measure para ese código
        LibraryAssert.AreEqual(
            0,
            DUoMUoMHelper.GetRoundingPrecisionByUoMCode(Item."No.", 'GHOST'),
            'Debe devolver 0 cuando no existe Item Unit of Measure para el código dado');

        // Cleanup
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // Artículo y código de UoM válidos → devuelve la precisión configurada
    // -------------------------------------------------------------------------

    [Test]
    procedure GetRndPrecByUoMCode_ValidUoM_ReturnsPrecision()
    var
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        Item: Record Item;
        UnitOfMeasure: Record "Unit of Measure";
        ItemUoM: Record "Item Unit of Measure";
        UoMCode: Code[10];
    begin
        // [GIVEN] Un artículo con un Item Unit of Measure con Qty. Rounding Precision = 0.01
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateUnitOfMeasureCode(UnitOfMeasure);
        UoMCode := UnitOfMeasure.Code;
        LibraryInventory.CreateItemUnitOfMeasure(ItemUoM, Item."No.", UoMCode, 1);
        ItemUoM."Qty. Rounding Precision" := 0.01;
        ItemUoM.Modify(false);

        // [WHEN] Se llama a GetRoundingPrecisionByUoMCode con el código de UoM válido
        // [THEN] Devuelve 0.01 — la precisión de redondeo del registro Item Unit of Measure
        LibraryAssert.AreEqual(
            0.01,
            DUoMUoMHelper.GetRoundingPrecisionByUoMCode(Item."No.", UoMCode),
            'Debe devolver 0.01 — la Qty. Rounding Precision del registro Item Unit of Measure');

        // Cleanup
        Item.Delete(false);
    end;
}
