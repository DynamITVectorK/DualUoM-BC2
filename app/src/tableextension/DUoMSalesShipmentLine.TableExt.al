/// <summary>
/// Amplía la tabla Sales Shipment Line con campos de Dual Unit of Measure.
/// Estos campos capturan DUoM Second Qty, DUoM Ratio y DUoM Unit Price desde la
/// Sales Line de origen en el momento del registro. Los valores son inmutables tras el registro.
/// La propagación la realiza DUoM Inventory Subscribers mediante el evento estándar
/// OnAfterInitFromSalesLine de la tabla "Sales Shipment Line" (BC 27 / runtime 15),
/// que proporciona acceso a la línea de venta origen en el momento de la inicialización
/// de la línea de envío — sin necesidad de Modify().
/// La lógica de copia está centralizada en DUoM Doc Transfer Helper (codeunit 50105).
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
        field(50102; "DUoM Unit Price"; Decimal)
        {
            Caption = 'DUoM Unit Price', Comment = 'Caption for DUoM Unit Price field; no placeholders.';
            DecimalPlaces = 2 : 5;
            DataClassification = CustomerContent;
        }
    }
}
