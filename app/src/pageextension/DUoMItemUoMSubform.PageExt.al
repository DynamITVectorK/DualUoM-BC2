/// <summary>
/// Extends the Item Units of Measure page to make the Qty. Rounding Precision field
/// visible in the repeater by default and editable when no item ledger entries exist
/// for the item.
///
/// Root cause of the reported issue: the standard BC 27 "Item Units of Measure" page
/// (page 5404) only exposes Qty. Rounding Precision for the base UoM through a page
/// variable in the "Current Base Unit of Measure" group. For alternate UoMs the field
/// is completely absent from the repeater, so the DualUoM rounding configuration
/// cannot be reached through the standard UI.
///
/// When added via Personalization the field is read-only because no explicit Editable
/// expression is set; the standard BC table validation (CheckNoEntriesWithUoM) will
/// also reject changes once the item has been used in any warehouse or document flow.
/// This extension adds the field explicitly with a conditional Editable expression
/// so users can configure it before any transactions are posted.
/// </summary>
pageextension 50110 "DUoM Item UoM Subform" extends "Item Units of Measure"
{
    layout
    {
        addafter("Qty. per Unit of Measure")
        {
            field("Qty. Rounding Precision"; Rec."Qty. Rounding Precision")
            {
                ApplicationArea = All;
                Editable = IsQtyRndPrecisionEditable;
                ToolTip = 'Specifies the rounding precision for quantities in this unit of measure. Can only be changed when no item ledger entries exist for this item.', Comment = 'ToolTip for Qty. Rounding Precision field on Item Units of Measure page extension; no placeholders.';
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", Rec."Item No.");
        IsQtyRndPrecisionEditable := ItemLedgerEntry.IsEmpty();
    end;

    var
        IsQtyRndPrecisionEditable: Boolean;
}
