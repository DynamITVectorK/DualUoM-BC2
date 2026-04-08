/// <summary>
/// Extends the Item Card with an action to open the DUoM Item Setup page for the current item.
/// The action always retrieves or creates the setup record before opening the page,
/// preventing blank or contextless setup pages.
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
                ToolTip = 'Opens the Dual Unit of Measure setup for this item.';

                trigger OnAction()
                var
                    DUoMItemSetup: Record "DUoM Item Setup";
                begin
                    DUoMItemSetup.GetOrCreate(Rec."No.");
                    Page.Run(Page::"DUoM Item Setup", DUoMItemSetup);
                end;
            }
        }
    }
}
