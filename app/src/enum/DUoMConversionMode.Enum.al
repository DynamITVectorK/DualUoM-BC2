/// <summary>
/// Defines how the conversion ratio between the base unit and the second unit of measure
/// is determined for an item. Used by the DUoM Item Setup.
/// </summary>
enum 50100 "DUoM Conversion Mode"
{
    Extensible = true;
    Caption = 'DUoM Conversion Mode';

    value(0; Fixed)
    {
        Caption = 'Fixed';
    }
    value(1; Variable)
    {
        Caption = 'Variable';
    }
    value(2; AlwaysVariable)
    {
        Caption = 'Always Variable';
    }
}
