/// <summary>
/// Extends the Item Tracking Lines page (6510) to display Dual Unit of Measure fields
/// (DUoM Ratio and DUoM Second Qty) on each tracking line (Tracking Specification buffer).
/// DUoM Ratio is auto-filled when a Lot No. is validated:
///   - Variable/AlwaysVariable: uses the DUoM Lot Ratio registered for the lot if available.
///   - Fixed: always uses the item/variant Fixed Ratio.
/// DUoM Second Qty is recalculated automatically when DUoM Ratio or Quantity (Base) changes.
/// Both fields are editable so the user can review and override values per lot assignment.
/// For items without DUoM enabled the columns are shown empty (no conditional hide).
/// </summary>
pageextension 50112 "DUoM Item Tracking Lines" extends "Item Tracking Lines"
{
    layout
    {
        addafter("Quantity (Base)")
        {
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the conversion ratio for this lot tracking line. Filled automatically from the registered DUoM Lot Ratio (Variable mode) or the item Fixed Ratio (Fixed mode). Can be overridden manually.', Comment = 'ToolTip for DUoM Ratio field on Item Tracking Lines; no placeholders.';
            }
            field("DUoM Second Qty"; Rec."DUoM Second Qty")
            {
                ApplicationArea = All;
                CaptionClass = DUoMSecondQtyCaption;
                ToolTip = 'Specifies the secondary quantity for this lot tracking line in the second unit of measure. Computed automatically from Quantity (Base) and DUoM Ratio.', Comment = 'ToolTip for DUoM Second Qty field on Item Tracking Lines; no placeholders.';
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        DUoMSecondQtyCaption := '3,' + DUoMSecondQtyDefaultLbl;
        if Rec."Item No." <> '' then
            if DUoMItemSetup.Get(Rec."Item No.") then
                if DUoMItemSetup."Dual UoM Enabled" then
                    if DUoMItemSetup."Second UoM Code" <> '' then
                        DUoMSecondQtyCaption := '3,' + DUoMItemSetup."Second UoM Code";
    end;

    var
        DUoMSecondQtyCaption: Text[30];
        DUoMSecondQtyDefaultLbl: Label 'DUoM Second Qty', Comment = 'Default column caption for DUoM Second Qty when no second unit of measure code is available; no placeholders.';
}
