/// <summary>
/// Extends the Item Card with an action to open the DUoM Item Setup page for the current item.
/// </summary>
pageextension 50100 "DUoM Item Card Ext" extends "Item Card"
{
    actions
    {
        addlast(Navigation)
        {
            action(DUoMSetup)
            {
                ApplicationArea = All;
                Caption = 'DUoM Setup';
                Image = Setup;
                RunObject = Page "DUoM Item Setup";
                RunPageLink = "Item No." = field("No.");
                RunPageMode = Edit;
                ToolTip = 'Opens the Dual Unit of Measure setup for this item.';
            }
        }
    }
}
