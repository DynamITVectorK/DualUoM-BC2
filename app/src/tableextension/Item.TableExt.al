/// <summary>
/// Extends the Item table to cascade-delete the DUoM Item Setup record
/// when an item is deleted, preventing orphaned setup data.
/// </summary>
tableextension 50100 "DUoM Item TableExt" extends Item
{
    trigger OnDelete()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        if DUoMItemSetup.Get(Rec."No.") then
            DUoMItemSetup.Delete(true);
    end;
}
