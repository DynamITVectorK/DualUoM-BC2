/// <summary>
/// List page for maintaining lot-specific actual conversion ratios.
/// Accessible standalone or filtered by Item No. from the DUoM Item Setup card.
/// </summary>
page 50102 "DUoM Lot Ratio List"
{
    ApplicationArea = All;
    Caption = 'DUoM Lot Ratio List';
    PageType = List;
    SourceTable = "DUoM Lot Ratio";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number this lot ratio belongs to.';
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lot number for which the actual ratio has been recorded.';
                }
                field("Actual Ratio"; Rec."Actual Ratio")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the actual measured conversion ratio for this lot (e.g. KG per PCS).';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies an optional description or comment for this lot ratio record.';
                }
            }
        }
    }
}
