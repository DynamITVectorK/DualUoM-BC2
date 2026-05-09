/// <summary>
/// Extends Item List to show the DUoM registered inventory calculated from Item Ledger Entries.
/// </summary>
pageextension 50127 "DUoM Item List Ext" extends "Item List"
{
    layout
    {
        addafter(InventoryField)
        {
            field("DUoM Inventory"; Rec."DUoM Inventory")
            {
                ApplicationArea = All;
                Editable = false;
            }
        }
    }
}
