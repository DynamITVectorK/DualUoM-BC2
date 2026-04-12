/// <summary>
/// Extends the Item Card with actions to open DUoM setup for the current item
/// and to manage DUoM variant-level overrides.
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
            action(DUoMVariantSetup)
            {
                ApplicationArea = All;
                Caption = 'DUoM Variant Overrides';
                Image = Variants;
                ToolTip = 'Opens the DUoM variant-level overrides for this item. Each row overrides the item DUoM setup for a specific variant.';

                trigger OnAction()
                var
                    DUoMVariantSetup: Record "DUoM Item Variant Setup";
                begin
                    DUoMVariantSetup.SetRange("Item No.", Rec."No.");
                    Page.Run(Page::"DUoM Variant Setup List", DUoMVariantSetup);
                end;
            }
        }
    }
}
