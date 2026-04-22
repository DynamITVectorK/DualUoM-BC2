/// <summary>
/// Card page for viewing and editing the Dual Unit of Measure setup for a single item.
/// Opened from the Item Card via the DUoM Setup action.
/// </summary>
page 50100 "DUoM Item Setup"
{
    Caption = 'DUoM Item Setup';
    InsertAllowed = false;
    PageType = Card;
    SourceTable = "DUoM Item Setup";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the item number this DUoM setup belongs to.';
                }
                field("Dual UoM Enabled"; Rec."Dual UoM Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this item uses Dual Unit of Measure.';
                }
            }
            group(Configuration)
            {
                Caption = 'Configuration';
                Enabled = Rec."Dual UoM Enabled";

                field("Second UoM Code"; Rec."Second UoM Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the secondary unit of measure for this item (e.g. PCS when the base UoM is KG).';
                }
                field("Conversion Mode"; Rec."Conversion Mode")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how the conversion ratio is determined. Fixed: constant ratio. Variable: default ratio overridable per line. Always Variable: user enters ratio manually on every line.';
                }
                field("Fixed Ratio"; Rec."Fixed Ratio")
                {
                    ApplicationArea = All;
                    Enabled = (Rec."Conversion Mode" = Rec."Conversion Mode"::Fixed) or (Rec."Conversion Mode" = Rec."Conversion Mode"::Variable);
                    ToolTip = 'Specifies the fixed or default conversion ratio (1 base UoM unit = Fixed Ratio second UoM units). Required when Conversion Mode is Fixed; used as the default in Variable mode.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ValidateSetup)
            {
                ApplicationArea = All;
                Caption = 'Validate Setup';
                Image = Approve;
                ToolTip = 'Checks that the current DUoM configuration is consistent and complete.';

                trigger OnAction()
                begin
                    Rec.ValidateSetup();
                    Message(SetupValidMsg);
                end;
            }
            action(DUoMLotRatios)
            {
                ApplicationArea = All;
                Caption = 'DUoM Lot Ratios';
                Image = Lot;
                RunObject = page "DUoM Lot Ratio List";
                RunPageLink = "Item No." = field("Item No.");
                RunPageMode = View;
                ToolTip = 'Opens the list of actual conversion ratios registered per lot for this item.';
            }
        }
    }

    var
        SetupValidMsg: Label 'DUoM setup is valid.', Comment = 'Confirmation message; no placeholders.';
}
