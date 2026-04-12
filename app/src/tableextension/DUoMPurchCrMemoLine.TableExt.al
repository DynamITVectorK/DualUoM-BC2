/// <summary>
/// Extiende la tabla Purch. Cr. Memo Line con campos de Unidad de Medida Dual.
/// Estos campos capturan DUoM Second Qty y DUoM Ratio desde la Purchase Line
/// de origen en el momento del registro del abono de compra. Los valores son
/// inmutables tras el registro.
/// La propagación la realiza DUoM Inventory Subscribers mediante el evento estándar
/// OnAfterInitFromPurchLine de la tabla "Purch. Cr. Memo Line" (BC 27 / runtime 15),
/// que proporciona acceso a la línea de compra origen en el momento de la inicialización
/// de la línea de abono registrado — sin necesidad de Modify().
/// La lógica de copia está centralizada en DUoM Doc Transfer Helper (codeunit 50105).
/// </summary>
tableextension 50117 "DUoM Purch. Cr. Memo Line Ext" extends "Purch. Cr. Memo Line"
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
