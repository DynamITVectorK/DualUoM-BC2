/// <summary>
/// Extends the Item Variant table to cascade-delete the DUoM Item Variant Setup
/// record when a variant is deleted, preventing orphaned override data.
/// </summary>
tableextension 50120 "DUoM Item Variant Ext" extends "Item Variant"
{
    trigger OnDelete()
    var
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
    begin
        if DUoMVariantSetup.Get(Rec."Item No.", Rec.Code) then
            DUoMVariantSetup.Delete(true);
    end;
}
