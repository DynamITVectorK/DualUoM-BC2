/// <summary>
/// Extiende la tabla Purch. Rcpt. Line con campos de Unidad de Medida Dual.
/// Estos campos capturan DUoM Second Qty y DUoM Ratio desde la
/// Purchase Line de origen en el momento del registro. Los valores son inmutables tras el registro.
/// La propagación la realiza DUoM Inventory Subscribers (OnBeforeInsertReceiptLine),
/// suscrito a OnBeforePurchRcptLineInsert — patrón seguro en SaaS que no requiere Modify().
/// </summary>
tableextension 50114 "DUoM Purch. Rcpt. Line Ext" extends "Purch. Rcpt. Line"
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
