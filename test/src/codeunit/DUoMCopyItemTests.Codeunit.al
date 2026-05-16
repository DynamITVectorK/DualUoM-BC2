/// <summary>
/// Tests para la copia de configuración DUoM durante el proceso de copia de artículo.
/// Valida que DUoM Copy Item Mgt. (50128) propaga correctamente los datos maestros
/// DUoM del artículo origen al artículo destino y excluye datos transaccionales.
///
/// Sección T-COPYITEM-01..06: tests unitarios que llaman directamente a CopyDUoMSetup
/// para verificar el comportamiento de la codeunit de forma aislada.
///
/// Sección T-COPYITEM-INT-01..03: tests de integración que invocan el flujo estándar de
/// Business Central (SetCopyItemBuffer + DoCopyItem en Codeunit::"Copy Item") para
/// probar que el suscriptor OnAfterCopyItemHandler se dispara correctamente y propaga
/// los datos DUoM a través del evento estándar OnAfterCopyItem.
/// </summary>
codeunit 50230 "DUoM Copy Item Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T-COPYITEM-01 — Copia de artículo con DUoM Fixed
    // -------------------------------------------------------------------------

    [Test]
    procedure CopyDUoMSetup_FixedMode_CopiesItemSetupToTarget()
    var
        SourceItem: Record Item;
        TargetItem: Record Item;
        TargetSetup: Record "DUoM Item Setup";
        DUoMCopyItemMgt: Codeunit "DUoM Copy Item Mgt.";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo origen con DUoM habilitado, modo Fixed y ratio 1.25
        LibraryInventory.CreateItem(SourceItem);
        DUoMTestHelpers.CreateItemSetup(SourceItem."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1.25);

        // [GIVEN] Un artículo destino sin configuración DUoM
        LibraryInventory.CreateItem(TargetItem);

        // [WHEN] Se copia la configuración DUoM
        DUoMCopyItemMgt.CopyDUoMSetup(SourceItem."No.", TargetItem."No.");

        // [THEN] El artículo destino tiene la misma configuración DUoM Fixed
        LibraryAssert.IsTrue(TargetSetup.Get(TargetItem."No."), 'DUoM Item Setup debe existir en el artículo destino.');
        LibraryAssert.IsTrue(TargetSetup."Dual UoM Enabled", 'Dual UoM Enabled debe ser true en destino.');
        LibraryAssert.AreEqual('PCS', TargetSetup."Second UoM Code", 'Second UoM Code debe copiarse al destino.');
        LibraryAssert.AreEqual("DUoM Conversion Mode"::Fixed, TargetSetup."Conversion Mode", 'Conversion Mode Fixed debe copiarse al destino.');
        LibraryAssert.AreEqual(1.25, TargetSetup."Fixed Ratio", 'Fixed Ratio debe copiarse al destino.');
    end;

    // -------------------------------------------------------------------------
    // T-COPYITEM-02 — Copia de artículo con DUoM Variable
    // -------------------------------------------------------------------------

    [Test]
    procedure CopyDUoMSetup_VariableMode_CopiesSetupAndDoesNotCopyLotRatios()
    var
        SourceItem: Record Item;
        TargetItem: Record Item;
        TargetSetup: Record "DUoM Item Setup";
        DUoMLotRatio: Record "DUoM Lot Ratio";
        DUoMCopyItemMgt: Codeunit "DUoM Copy Item Mgt.";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo origen con DUoM habilitado, modo Variable, ratio 0.9
        LibraryInventory.CreateItem(SourceItem);
        DUoMTestHelpers.CreateItemSetup(SourceItem."No.", true, 'KG', "DUoM Conversion Mode"::Variable, 0.9);

        // [GIVEN] Un lote con ratio real en el artículo origen
        DUoMTestHelpers.CreateLotRatio(SourceItem."No.", 'LOT001', 0.83);

        // [GIVEN] Un artículo destino sin configuración DUoM
        LibraryInventory.CreateItem(TargetItem);

        // [WHEN] Se copia la configuración DUoM
        DUoMCopyItemMgt.CopyDUoMSetup(SourceItem."No.", TargetItem."No.");

        // [THEN] El artículo destino conserva el modo Variable
        LibraryAssert.IsTrue(TargetSetup.Get(TargetItem."No."), 'DUoM Item Setup debe existir en el artículo destino.');
        LibraryAssert.AreEqual("DUoM Conversion Mode"::Variable, TargetSetup."Conversion Mode", 'Conversion Mode Variable debe copiarse al destino.');

        // [THEN] No se copian los ratios reales por lote al artículo destino
        DUoMLotRatio.SetRange("Item No.", TargetItem."No.");
        LibraryAssert.IsTrue(DUoMLotRatio.IsEmpty(), 'DUoM Lot Ratio no debe copiarse al artículo destino.');
    end;

    // -------------------------------------------------------------------------
    // T-COPYITEM-03 — Copia de DUoM Item Variant Setup
    // -------------------------------------------------------------------------

    [Test]
    procedure CopyDUoMSetup_WithVariants_CopiesVariantSetupToExistingVariants()
    var
        SourceItem: Record Item;
        TargetItem: Record Item;
        SourceVariant: Record "Item Variant";
        TargetVariant: Record "Item Variant";
        TargetVariantSetup: Record "DUoM Item Variant Setup";
        DUoMCopyItemMgt: Codeunit "DUoM Copy Item Mgt.";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo origen con DUoM habilitado y una variante con anulación
        LibraryInventory.CreateItem(SourceItem);
        DUoMTestHelpers.CreateItemSetup(SourceItem."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1.0);
        DUoMTestHelpers.CreateItemVariantWithCode(SourceItem."No.", 'ROMANA', SourceVariant);
        DUoMTestHelpers.CreateVariantSetup(SourceItem."No.", 'ROMANA', 'KG', "DUoM Conversion Mode"::Variable, 1.5);

        // [GIVEN] Un artículo destino con la misma variante ROMANA (ya copiada por el estándar)
        LibraryInventory.CreateItem(TargetItem);
        DUoMTestHelpers.CreateItemVariantWithCode(TargetItem."No.", 'ROMANA', TargetVariant);

        // [WHEN] Se copia la configuración DUoM
        DUoMCopyItemMgt.CopyDUoMSetup(SourceItem."No.", TargetItem."No.");

        // [THEN] La variante del artículo destino tiene la configuración DUoM copiada
        LibraryAssert.IsTrue(
            TargetVariantSetup.Get(TargetItem."No.", 'ROMANA'),
            'DUoM Item Variant Setup debe existir en el artículo destino para ROMANA.');
        LibraryAssert.AreEqual('KG', TargetVariantSetup."Second UoM Code", 'Second UoM Code de variante debe copiarse.');
        LibraryAssert.AreEqual("DUoM Conversion Mode"::Variable, TargetVariantSetup."Conversion Mode", 'Conversion Mode de variante debe copiarse.');
        LibraryAssert.AreEqual(1.5, TargetVariantSetup."Fixed Ratio", 'Fixed Ratio de variante debe copiarse.');
    end;

    // -------------------------------------------------------------------------
    // T-COPYITEM-04 — No copiar variante si no existe en destino
    // -------------------------------------------------------------------------

    [Test]
    procedure CopyDUoMSetup_VariantNotInTarget_SkipsVariantSetup()
    var
        SourceItem: Record Item;
        TargetItem: Record Item;
        SourceVariant: Record "Item Variant";
        TargetVariantSetup: Record "DUoM Item Variant Setup";
        DUoMCopyItemMgt: Codeunit "DUoM Copy Item Mgt.";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo origen con variante ROMANA y configuración DUoM de variante
        LibraryInventory.CreateItem(SourceItem);
        DUoMTestHelpers.CreateItemSetup(SourceItem."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1.0);
        DUoMTestHelpers.CreateItemVariantWithCode(SourceItem."No.", 'ROMANA', SourceVariant);
        DUoMTestHelpers.CreateVariantSetup(SourceItem."No.", 'ROMANA', 'KG', "DUoM Conversion Mode"::Variable, 1.5);

        // [GIVEN] Un artículo destino SIN la variante ROMANA
        LibraryInventory.CreateItem(TargetItem);

        // [WHEN] Se copia la configuración DUoM
        DUoMCopyItemMgt.CopyDUoMSetup(SourceItem."No.", TargetItem."No.");

        // [THEN] No se crea ningún DUoM Item Variant Setup en el artículo destino
        TargetVariantSetup.SetRange("Item No.", TargetItem."No.");
        LibraryAssert.IsTrue(
            TargetVariantSetup.IsEmpty(),
            'No debe crearse DUoM Item Variant Setup para variantes inexistentes en el destino.');
    end;

    // -------------------------------------------------------------------------
    // T-COPYITEM-05 — Idempotencia: no duplicados al copiar dos veces
    // -------------------------------------------------------------------------

    [Test]
    procedure CopyDUoMSetup_CalledTwice_UpdatesWithoutDuplicates()
    var
        SourceItem: Record Item;
        TargetItem: Record Item;
        TargetSetup: Record "DUoM Item Setup";
        DUoMCopyItemMgt: Codeunit "DUoM Copy Item Mgt.";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        SetupCount: Integer;
    begin
        // [GIVEN] Un artículo origen con DUoM Fixed, ratio 2.0
        LibraryInventory.CreateItem(SourceItem);
        DUoMTestHelpers.CreateItemSetup(SourceItem."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 2.0);

        // [GIVEN] Un artículo destino sin configuración DUoM
        LibraryInventory.CreateItem(TargetItem);

        // [WHEN] Se copia la configuración DUoM dos veces seguidas
        DUoMCopyItemMgt.CopyDUoMSetup(SourceItem."No.", TargetItem."No.");
        DUoMCopyItemMgt.CopyDUoMSetup(SourceItem."No.", TargetItem."No.");

        // [THEN] Solo existe un registro DUoM Item Setup para el artículo destino
        TargetSetup.SetRange("Item No.", TargetItem."No.");
        SetupCount := TargetSetup.Count();
        LibraryAssert.AreEqual(1, SetupCount, 'Solo debe existir un registro DUoM Item Setup en el destino.');

        // [THEN] Los valores son coherentes con el origen
        LibraryAssert.IsTrue(TargetSetup.Get(TargetItem."No."), 'DUoM Item Setup debe existir en el artículo destino.');
        LibraryAssert.AreEqual(2.0, TargetSetup."Fixed Ratio", 'Fixed Ratio debe conservar el valor del origen tras doble copia.');
    end;

    // -------------------------------------------------------------------------
    // T-COPYITEM-06 — Sin configuración DUoM en origen: no se crea nada en destino
    // -------------------------------------------------------------------------

    [Test]
    procedure CopyDUoMSetup_NoSourceSetup_CreatesNothingInTarget()
    var
        SourceItem: Record Item;
        TargetItem: Record Item;
        TargetSetup: Record "DUoM Item Setup";
        DUoMCopyItemMgt: Codeunit "DUoM Copy Item Mgt.";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo origen sin configuración DUoM
        LibraryInventory.CreateItem(SourceItem);

        // [GIVEN] Un artículo destino sin configuración DUoM
        LibraryInventory.CreateItem(TargetItem);

        // [WHEN] Se copia la configuración DUoM
        DUoMCopyItemMgt.CopyDUoMSetup(SourceItem."No.", TargetItem."No.");

        // [THEN] El artículo destino no tiene ningún registro DUoM Item Setup
        LibraryAssert.IsFalse(TargetSetup.Get(TargetItem."No."), 'No debe crearse DUoM Item Setup cuando el origen no tiene configuración DUoM.');
    end;

    // =========================================================================
    // Tests de integración — flujo estándar Codeunit::"Copy Item"
    //
    // Estos tests invocan el proceso de copia de artículo de BC mediante
    // SetCopyItemBuffer + DoCopyItem (sin UI, sin page handler) para probar que
    // el suscriptor OnAfterCopyItemHandler (50128) se dispara correctamente.
    //
    // Patrón de invocación validado en BC standard tests (ERMCopyItem, codeunit 134462):
    //   CopyItemCU.SetCopyItemBuffer(CopyItemBuffer);
    //   CopyItemCU.DoCopyItem();
    // =========================================================================

    // -------------------------------------------------------------------------
    // T-COPYITEM-INT-01 — Flujo estándar dispara OnAfterCopyItem y copia DUoM Item Setup
    // -------------------------------------------------------------------------

    [Test]
    procedure StdCopyItem_FiresSubscriber_CopiesDUoMSetup()
    var
        SourceItem: Record Item;
        TargetSetup: Record "DUoM Item Setup";
        CopyItemBuffer: Record "Copy Item Buffer";
        CopyItemCU: Codeunit "Copy Item";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryUtility: Codeunit "Library - Utility";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo origen con DUoM habilitado, modo Fixed y ratio 2.5
        LibraryInventory.CreateItem(SourceItem);
        DUoMTestHelpers.CreateItemSetup(SourceItem."No.", true, 'KG', "DUoM Conversion Mode"::Fixed, 2.5);

        // [GIVEN] Parámetros estándar de copia apuntando a un artículo destino nuevo
        CopyItemBuffer."Source Item No." := SourceItem."No.";
        CopyItemBuffer."Target Item No." :=
            CopyStr(LibraryUtility.GenerateGUID(), 1, MaxStrLen(CopyItemBuffer."Target Item No."));
        CopyItemBuffer."Number of Copies" := 1;

        // [WHEN] Se ejecuta el flujo estándar de copia de artículo (sin UI)
        CopyItemCU.SetCopyItemBuffer(CopyItemBuffer);
        CopyItemCU.DoCopyItem();

        // [THEN] El suscriptor OnAfterCopyItemHandler propagó DUoM Item Setup al artículo destino
        LibraryAssert.IsTrue(
            TargetSetup.Get(CopyItemBuffer."Target Item No."),
            'DUoM Item Setup debe existir en el artículo destino tras el flujo estándar Copy Item.');
        LibraryAssert.IsTrue(TargetSetup."Dual UoM Enabled", 'Dual UoM Enabled debe ser true en destino.');
        LibraryAssert.AreEqual('KG', TargetSetup."Second UoM Code", 'Second UoM Code debe copiarse al destino.');
        LibraryAssert.AreEqual(
            "DUoM Conversion Mode"::Fixed, TargetSetup."Conversion Mode",
            'Conversion Mode Fixed debe copiarse al destino.');
        LibraryAssert.AreEqual(2.5, TargetSetup."Fixed Ratio", 'Fixed Ratio debe copiarse al destino.');
    end;

    // -------------------------------------------------------------------------
    // T-COPYITEM-INT-02 — Flujo estándar con variantes copia DUoM Item Variant Setup
    // -------------------------------------------------------------------------

    [Test]
    procedure StdCopyItem_WithVariants_CopiesDUoMVariantSetup()
    var
        SourceItem: Record Item;
        SourceVariant: Record "Item Variant";
        TargetSetup: Record "DUoM Item Setup";
        TargetVariantSetup: Record "DUoM Item Variant Setup";
        CopyItemBuffer: Record "Copy Item Buffer";
        CopyItemCU: Codeunit "Copy Item";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryUtility: Codeunit "Library - Utility";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo origen con DUoM Fixed habilitado y variante ROMANA con anulación DUoM
        LibraryInventory.CreateItem(SourceItem);
        DUoMTestHelpers.CreateItemSetup(SourceItem."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 1.0);
        DUoMTestHelpers.CreateItemVariantWithCode(SourceItem."No.", 'ROMANA', SourceVariant);
        DUoMTestHelpers.CreateVariantSetup(SourceItem."No.", 'ROMANA', 'KG', "DUoM Conversion Mode"::Variable, 1.8);

        // [GIVEN] Parámetros estándar de copia con Item Variants = true
        CopyItemBuffer."Source Item No." := SourceItem."No.";
        CopyItemBuffer."Target Item No." :=
            CopyStr(LibraryUtility.GenerateGUID(), 1, MaxStrLen(CopyItemBuffer."Target Item No."));
        CopyItemBuffer."Number of Copies" := 1;
        CopyItemBuffer."Item Variants" := true;

        // [WHEN] Se ejecuta el flujo estándar de copia de artículo con variantes
        // El estándar copia las variantes ANTES de disparar OnAfterCopyItem,
        // por lo que el suscriptor puede encontrar las variantes del destino ya existentes.
        CopyItemCU.SetCopyItemBuffer(CopyItemBuffer);
        CopyItemCU.DoCopyItem();

        // [THEN] El artículo destino tiene DUoM Item Setup copiado
        LibraryAssert.IsTrue(
            TargetSetup.Get(CopyItemBuffer."Target Item No."),
            'DUoM Item Setup debe existir en el artículo destino.');

        // [THEN] La variante ROMANA del artículo destino tiene DUoM Item Variant Setup copiado
        LibraryAssert.IsTrue(
            TargetVariantSetup.Get(CopyItemBuffer."Target Item No.", 'ROMANA'),
            'DUoM Item Variant Setup debe existir en variante ROMANA del artículo destino.');
        LibraryAssert.AreEqual(
            'KG', TargetVariantSetup."Second UoM Code",
            'Second UoM Code de variante debe copiarse al destino.');
        LibraryAssert.AreEqual(
            "DUoM Conversion Mode"::Variable, TargetVariantSetup."Conversion Mode",
            'Conversion Mode de variante debe copiarse al destino.');
        LibraryAssert.AreEqual(
            1.8, TargetVariantSetup."Fixed Ratio",
            'Fixed Ratio de variante debe copiarse al destino.');
    end;

    // -------------------------------------------------------------------------
    // T-COPYITEM-INT-03 — Flujo estándar NO copia DUoM Lot Ratios
    // -------------------------------------------------------------------------

    [Test]
    procedure StdCopyItem_DoesNotCopyDUoMLotRatios()
    var
        SourceItem: Record Item;
        TargetLotRatios: Record "DUoM Lot Ratio";
        CopyItemBuffer: Record "Copy Item Buffer";
        CopyItemCU: Codeunit "Copy Item";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryUtility: Codeunit "Library - Utility";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo origen con DUoM Variable y un ratio de lote real (dato transaccional)
        LibraryInventory.CreateItem(SourceItem);
        DUoMTestHelpers.CreateItemSetup(SourceItem."No.", true, 'KG', "DUoM Conversion Mode"::Variable, 0.9);
        DUoMTestHelpers.CreateLotRatio(SourceItem."No.", 'LOT-INT-01', 0.87);

        // [GIVEN] Parámetros estándar de copia
        CopyItemBuffer."Source Item No." := SourceItem."No.";
        CopyItemBuffer."Target Item No." :=
            CopyStr(LibraryUtility.GenerateGUID(), 1, MaxStrLen(CopyItemBuffer."Target Item No."));
        CopyItemBuffer."Number of Copies" := 1;

        // [WHEN] Se ejecuta el flujo estándar de copia de artículo
        CopyItemCU.SetCopyItemBuffer(CopyItemBuffer);
        CopyItemCU.DoCopyItem();

        // [THEN] No se han copiado DUoM Lot Ratios al artículo destino
        // (son datos transaccionales del stock real recibido, no configuración maestra)
        TargetLotRatios.SetRange("Item No.", CopyItemBuffer."Target Item No.");
        LibraryAssert.IsTrue(
            TargetLotRatios.IsEmpty(),
            'DUoM Lot Ratio no debe copiarse al artículo destino por el flujo estándar Copy Item.');
    end;
}
