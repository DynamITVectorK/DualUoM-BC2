/// <summary>
/// Tests para el borrado en cascada de DUoM Item Variant Setup (tabla 50101)
/// cuando se elimina una Item Variant.
/// Verifica la integridad referencial: no deben quedar registros de setup de variante
/// huérfanos tras la eliminación de la Item Variant asociada.
///
/// Cierra el gap P1-01 identificado en docs/TestCoverageAudit.md.
/// El trigger OnDelete de tableextension 50120 "DUoM Item Variant Ext" implementa
/// esta lógica; estos tests garantizan su correcto funcionamiento.
/// </summary>
codeunit 50215 "DUoM Variant Del Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // OnDelete — se elimina el setup cuando se elimina la Item Variant
    // -------------------------------------------------------------------------

    [Test]
    procedure DeleteItemVariant_WithSetup_DeletesVariantSetup()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo existe en la base de datos
        LibraryInventory.CreateItem(Item);

        // [GIVEN] Existe una Item Variant para ese artículo
        ItemVariant.Init();
        ItemVariant."Item No." := Item."No.";
        ItemVariant.Code := 'VDT-01';
        ItemVariant.Insert(false);

        // [GIVEN] Existe un registro DUoM Item Variant Setup para esa variante
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'VDT-01', 'PCS', "DUoM Conversion Mode"::Fixed, 1.5);

        // [WHEN] Se elimina la Item Variant
        ItemVariant.Delete(true);

        // [THEN] El registro DUoM Item Variant Setup también se ha eliminado (sin huérfanos)
        LibraryAssert.IsFalse(
            DUoMVariantSetup.Get(Item."No.", 'VDT-01'),
            'DUoM Item Variant Setup debe eliminarse en cascada cuando se elimina la Item Variant');

        // Cleanup
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // OnDelete — sin error cuando la Item Variant no tiene setup DUoM
    // -------------------------------------------------------------------------

    [Test]
    procedure DeleteItemVariant_WithoutSetup_NoError()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo y una Item Variant sin setup DUoM correspondiente
        LibraryInventory.CreateItem(Item);
        ItemVariant.Init();
        ItemVariant."Item No." := Item."No.";
        ItemVariant.Code := 'VDT-02';
        ItemVariant.Insert(false);

        // [WHEN] Se elimina la Item Variant
        ItemVariant.Delete(true);

        // [THEN] No se produce error y la variante ya no existe
        LibraryAssert.IsFalse(
            ItemVariant.Get(Item."No.", 'VDT-02'),
            'La Item Variant no debe existir tras la eliminación cuando no había setup DUoM');

        // Cleanup
        Item.Delete(false);
    end;

    // -------------------------------------------------------------------------
    // OnDelete — eliminar una variante no afecta al setup de otra variante
    // -------------------------------------------------------------------------

    [Test]
    procedure DeleteItemVariant_OtherVariantSetupUnaffected()
    var
        Item: Record Item;
        ItemVariant1: Record "Item Variant";
        ItemVariant2: Record "Item Variant";
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Un artículo con dos variantes, cada una con su propio DUoM setup
        LibraryInventory.CreateItem(Item);

        ItemVariant1.Init();
        ItemVariant1."Item No." := Item."No.";
        ItemVariant1.Code := 'VDT-03A';
        ItemVariant1.Insert(false);

        ItemVariant2.Init();
        ItemVariant2."Item No." := Item."No.";
        ItemVariant2.Code := 'VDT-03B';
        ItemVariant2.Insert(false);

        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'VDT-03A', 'PCS', "DUoM Conversion Mode"::Fixed, 1.5);
        DUoMTestHelpers.CreateVariantSetup(Item."No.", 'VDT-03B', 'KG', "DUoM Conversion Mode"::Variable, 1.0);

        // [WHEN] Solo se elimina la primera variante
        ItemVariant1.Delete(true);

        // [THEN] El DUoM setup de la segunda variante permanece intacto
        LibraryAssert.IsTrue(
            DUoMVariantSetup.Get(Item."No.", 'VDT-03B'),
            'Eliminar una variante no debe afectar al DUoM setup de otras variantes del mismo artículo');

        // Cleanup
        DUoMTestHelpers.DeleteVariantSetupIfExists(Item."No.", 'VDT-03B');
        ItemVariant2.Delete(false);
        Item.Delete(false);
    end;
}
