/// <summary>
/// Extends the Sales Shipment Line table with Dual Unit of Measure fields.
/// These fields capture the DUoM Second Qty and Ratio from the originating
/// Sales Line at the time of posting. Values are immutable after posting.
/// Propagation is performed by DUoM Inventory Subscribers (OnAfterInsertShipmentLine).
/// </summary>
tableextension 50115 "DUoM Sales Shipment Line Ext" extends "Sales Shipment Line"
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
