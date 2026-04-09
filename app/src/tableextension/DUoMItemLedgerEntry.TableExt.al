/// <summary>
/// Extends the Item Ledger Entry table with Dual Unit of Measure fields.
/// These fields are immutable after posting; they capture the actual second quantity
/// and conversion ratio at the moment of the inventory transaction.
/// Values are propagated by DUoM Inventory Subscribers at posting time.
/// </summary>
tableextension 50113 "DUoM Item Ledger Entry Ext" extends "Item Ledger Entry"
{
    fields
    {
        field(50100; "DUoM Second Qty"; Decimal)
        {
            Caption = 'DUoM Second Qty';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the secondary quantity posted with this entry, expressed in the second unit of measure.';
        }
        field(50101; "DUoM Ratio"; Decimal)
        {
            Caption = 'DUoM Ratio';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the conversion ratio used when this entry was posted (1 base UoM unit = DUoM Ratio second UoM units).';
        }
    }
}
