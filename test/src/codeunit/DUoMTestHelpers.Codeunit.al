/// <summary>
/// Procedimientos auxiliares compartidos para los codeunits de test DUoM.
/// Proporciona factorías de datos para crear y limpiar registros DUoM Item Setup (50100)
/// durante los tests, sin dependencia de tablas del sistema como Access Control.
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
}
