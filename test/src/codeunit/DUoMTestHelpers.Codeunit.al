/// <summary>
/// Procedimientos auxiliares compartidos para los codeunits de test DUoM.
/// Proporciona factorías de datos para crear y limpiar registros DUoM Item Setup (50100)
/// y DUoM Item Variant Setup (50101) durante los tests, sin dependencia de tablas
/// del sistema como Access Control.
/// </summary>
codeunit 50208 "DUoM Test Helpers"
{
    /// <summary>
    /// Crea e inserta un registro DUoM Item Setup con los valores indicados.
    /// Devuelve el registro insertado para su uso inmediato en el test.
    /// </summary>
    procedure CreateItemSetup(
        ItemNo: Code[20];
        Enabled: Boolean;
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal): Record "DUoM Item Setup"
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := ItemNo;
        DUoMItemSetup."Dual UoM Enabled" := Enabled;
        DUoMItemSetup."Second UoM Code" := SecondUoMCode;
        DUoMItemSetup."Conversion Mode" := ConversionMode;
        DUoMItemSetup."Fixed Ratio" := FixedRatio;
        DUoMItemSetup.Insert(false);
        exit(DUoMItemSetup);
    end;

    /// <summary>
    /// Elimina el registro DUoM Item Setup del ítem indicado si existe.
    /// No produce error si el registro no existe.
    /// </summary>
    procedure DeleteItemSetupIfExists(ItemNo: Code[20])
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        if DUoMItemSetup.Get(ItemNo) then
            DUoMItemSetup.Delete(false);
    end;

    /// <summary>
    /// Crea e inserta un registro DUoM Item Variant Setup para la variante indicada.
    /// Devuelve el registro insertado para su uso inmediato en el test.
    /// </summary>
    procedure CreateVariantSetup(
        ItemNo: Code[20];
        VariantCode: Code[10];
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal): Record "DUoM Item Variant Setup"
    var
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
    begin
        DUoMVariantSetup.Init();
        DUoMVariantSetup."Item No." := ItemNo;
        DUoMVariantSetup."Variant Code" := VariantCode;
        DUoMVariantSetup."Second UoM Code" := SecondUoMCode;
        DUoMVariantSetup."Conversion Mode" := ConversionMode;
        DUoMVariantSetup."Fixed Ratio" := FixedRatio;
        DUoMVariantSetup.Insert(false);
        exit(DUoMVariantSetup);
    end;

    /// <summary>
    /// Elimina el registro DUoM Item Variant Setup para la variante indicada si existe.
    /// No produce error si el registro no existe.
    /// </summary>
    procedure DeleteVariantSetupIfExists(ItemNo: Code[20]; VariantCode: Code[10])
    var
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
    begin
        if DUoMVariantSetup.Get(ItemNo, VariantCode) then
            DUoMVariantSetup.Delete(false);
    end;

    /// <summary>
    /// Crea e inserta un registro DUoM Lot Ratio para el par (ItemNo, LotNo).
    /// Devuelve el registro insertado para su uso inmediato en el test.
    /// </summary>
    procedure CreateLotRatio(
        ItemNo: Code[20];
        LotNo: Code[50];
        ActualRatio: Decimal): Record "DUoM Lot Ratio"
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        DUoMLotRatio.Init();
        DUoMLotRatio."Item No." := ItemNo;
        DUoMLotRatio."Lot No." := LotNo;
        DUoMLotRatio."Actual Ratio" := ActualRatio;
        DUoMLotRatio.Insert(false);
        exit(DUoMLotRatio);
    end;

    /// <summary>
    /// Elimina el registro DUoM Lot Ratio para el par (ItemNo, LotNo) si existe.
    /// No produce error si el registro no existe.
    /// </summary>
    procedure DeleteLotRatioIfExists(ItemNo: Code[20]; LotNo: Code[50])
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        if DUoMLotRatio.Get(ItemNo, LotNo) then
            DUoMLotRatio.Delete(false);
    end;

    /// <summary>
    /// Crea una variante de artículo con el código específico indicado.
    /// Usa Library - Inventory.CreateItemVariant internamente (norma del proyecto)
    /// y después renombra al código deseado para mantener semántica de negocio
    /// determinista en los tests DUoM (p.ej. 'ROMANA', 'ICEBERG', 'GRANEL').
    /// Se justifica un helper propio porque LibraryInventory.CreateItemVariant genera
    /// un código aleatorio, pero los tests de variantes DUoM requieren códigos
    /// específicos con semántica funcional.
    /// </summary>
    procedure CreateItemVariantWithCode(ItemNo: Code[20]; VariantCode: Code[10]; var ItemVariant: Record "Item Variant")
    var
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        LibraryInventory.CreateItemVariant(ItemVariant, ItemNo);
        ItemVariant.Rename(ItemNo, VariantCode);
    end;
}
