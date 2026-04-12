/// <summary>
/// List page for managing DUoM variant-level overrides.
/// Opened from the Item Card via the "DUoM Variant Overrides" action,
/// pre-filtered to show only overrides for the current item.
/// Each row represents an optional override of the item-level DUoM setup
/// for a specific Item Variant.
/// </summary>
page 50101 "DUoM Variant Setup List"
{
    Caption = 'DUoM Variant Setup List';
    PageType = List;
    SourceTable = "DUoM Item Variant Setup";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Overrides)
            {
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the item number this variant DUoM override belongs to.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the variant code for this DUoM override.';
                }
                field("Second UoM Code"; Rec."Second UoM Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the secondary unit of measure override for this variant. Leave blank to inherit from the item DUoM setup.';
                }
                field("Conversion Mode"; Rec."Conversion Mode")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the conversion mode override for this variant.';
                }
                field("Fixed Ratio"; Rec."Fixed Ratio")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the fixed conversion ratio override for this variant.';
                }
            }
        }
    }
}
