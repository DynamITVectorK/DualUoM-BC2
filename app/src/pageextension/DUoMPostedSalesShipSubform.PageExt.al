/// <summary>
/// Extiende la página de subformulario de envíos de venta registrados para mostrar los campos
/// de Dual Unit of Measure (DUoM Second Qty y DUoM Ratio) en cada línea de envío registrada.
/// Ambos campos son de solo lectura, ya que los documentos registrados son inmutables.
/// DUoM Second Qty muestra el código de la segunda unidad de medida como caption de la columna cuando está disponible.
/// </summary>
pageextension 50105 "DUoM Posted Ship. Subform" extends "Posted Sales Shpt. Subform"
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
                ToolTip = 'Specifies the secondary quantity for this posted shipment line in the second unit of measure.', Comment = 'ToolTip for DUoM Second Qty field on Posted Sales Shipment Subform; no placeholders.';
            }
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the conversion ratio used for this posted shipment line.', Comment = 'ToolTip for DUoM Ratio field on Posted Sales Shipment Subform; no placeholders.';
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
