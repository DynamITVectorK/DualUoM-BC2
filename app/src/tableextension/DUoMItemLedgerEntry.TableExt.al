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
            Caption = 'DUoM Second Qty', Comment = 'Caption for DUoM Second Qty field; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
        field(50101; "DUoM Ratio"; Decimal)
        {
            Caption = 'DUoM Ratio', Comment = 'Caption for DUoM Ratio field; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
    }
}
