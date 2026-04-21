/// <summary>
/// Extiende la tabla Value Entry con el campo DUoM Second Qty para trazabilidad
/// contable completa de la cantidad en la segunda unidad de medida.
/// El campo se propaga desde el Item Journal Line en el evento OnAfterInitValueEntry
/// de Codeunit "Item Jnl.-Post Line" (BC 27 / runtime 15) — sin Modify().
/// La lógica de propagación está centralizada en DUoM Inventory Subscribers (50104).
/// </summary>
tableextension 50121 "DUoM Value Entry Ext" extends "Value Entry"
{
    fields
    {
        field(50100; "DUoM Second Qty"; Decimal)
        {
            Caption = 'DUoM Second Qty', Comment = 'Caption for DUoM Second Qty field; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
    }
}
