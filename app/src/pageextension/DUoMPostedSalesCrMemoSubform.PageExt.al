/// <summary>
/// Extiende la página Posted Sales Cr. Memo Subform para mostrar los campos de
/// Dual Unit of Measure (DUoM Second Qty y DUoM Ratio) en cada línea de abono
/// de venta registrado.
/// Ambos campos son de solo lectura; los documentos registrados son inmutables.
/// DUoM Second Qty muestra el código de la segunda unidad de medida como caption
/// de la columna cuando está disponible.
/// </summary>
pageextension 50109 "DUoM Pstd Sales CrM Subform" extends "Posted Sales Cr. Memo Subform"
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
                ToolTip = 'Specifies the secondary quantity for this posted sales credit memo line in the second unit of measure.', Comment = 'ToolTip for DUoM Second Qty field on Posted Sales Credit Memo Subform; no placeholders.';
            }
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the conversion ratio used for this posted sales credit memo line.', Comment = 'ToolTip for DUoM Ratio field on Posted Sales Credit Memo Subform; no placeholders.';
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
