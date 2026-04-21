/// <summary>
/// Extiende la página Posted Purch. Cr. Memo Subform para mostrar los campos de
/// Dual Unit of Measure (DUoM Second Qty, DUoM Ratio y DUoM Unit Cost) en cada línea de abono
/// de compra registrado.
/// Todos los campos son de solo lectura; los documentos registrados son inmutables.
/// DUoM Second Qty muestra el código de la segunda unidad de medida como caption
/// de la columna cuando está disponible.
/// </summary>
pageextension 50107 "DUoM Pstd Purch CrM Subform" extends "Posted Purch. Cr. Memo Subform"
{
    layout
    {
        addafter(Quantity)
        {
            field("DUoM Second Qty"; Rec."DUoM Second Qty")
            {
                ApplicationArea = All;
                CaptionClass = DUoMSecondQtyCaption;
                Editable = false;
                ToolTip = 'Specifies the secondary quantity for this posted purchase credit memo line in the second unit of measure.', Comment = 'ToolTip for DUoM Second Qty field on Posted Purchase Credit Memo Subform; no placeholders.';
            }
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the conversion ratio used for this posted purchase credit memo line.', Comment = 'ToolTip for DUoM Ratio field on Posted Purchase Credit Memo Subform; no placeholders.';
            }
            field("DUoM Unit Cost"; Rec."DUoM Unit Cost")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the unit cost in the second unit of measure for this posted purchase credit memo line.', Comment = 'ToolTip for DUoM Unit Cost field on Posted Purchase Credit Memo Subform; no placeholders.';
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        DUoMSecondQtyCaption := '3,' + DUoMSecondQtyDefaultLbl;
        if Rec.Type = Rec.Type::Item then
            if DUoMItemSetup.Get(Rec."No.") then
                if DUoMItemSetup."Dual UoM Enabled" then
                    if DUoMItemSetup."Second UoM Code" <> '' then
                        DUoMSecondQtyCaption := '3,' + DUoMItemSetup."Second UoM Code";
    end;

    var
        DUoMSecondQtyCaption: Text[30];
        DUoMSecondQtyDefaultLbl: Label 'DUoM Second Qty', Comment = 'Default column caption for DUoM Second Qty when no second unit of measure code is available; no placeholders.';
}
