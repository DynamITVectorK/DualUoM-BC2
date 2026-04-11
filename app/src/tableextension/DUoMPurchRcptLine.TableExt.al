/// <summary>
/// Extiende la tabla Purch. Rcpt. Line con campos de Unidad de Medida Dual.
/// Estos campos capturan DUoM Second Qty y DUoM Ratio desde la
/// Purchase Line de origen en el momento del registro. Los valores son inmutables tras el registro.
/// La propagación la realiza DUoM Inventory Subscribers mediante el evento estándar
/// OnAfterInitFromPurchLine de la tabla "Purch. Rcpt. Line" (BC 27 / runtime 15),
/// que proporciona acceso a la línea de compra origen en el momento de la inicialización
/// de la línea de recepción — sin necesidad de Modify().
/// La lógica de copia está centralizada en DUoM Doc Transfer Helper (codeunit 50105).
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
