/// <summary>
/// Extiende Entry Summary con campos DUoM para mostrar ratio y cantidad secundaria
/// en la página de selección de movimientos de seguimiento.
/// </summary>
tableextension 50129 "DUoM Entry Summary Ext" extends "Entry Summary"
{
    fields
    {
        field(50124; "DUoM Ratio"; Decimal)
        {
            Caption = 'DUoM Ratio', Comment = 'Caption for DUoM Ratio field in Entry Summary; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
        field(50125; "DUoM Second Qty"; Decimal)
        {
            Caption = 'DUoM Second Qty', Comment = 'Caption for DUoM Second Qty field in Entry Summary; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
    }
}
