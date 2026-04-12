/// <summary>
/// Extends the Item Units of Measure page to make the Qty. Rounding Precision field
/// visible in the repeater by default and editable when no entries exist for the
/// specific combination of item and unit of measure.
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
///
/// Editability logic: the field is editable for a given UoM line only when there are
/// no Item Ledger Entries and no Warehouse Entries for that exact (Item No., UoM Code)
/// combination. A transaction in a different UoM of the same item does not affect
/// the editability of this line.
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
                ToolTip = 'Specifies the rounding precision for quantities in this unit of measure. Can only be changed when no item ledger entries or warehouse entries exist for this unit of measure.', Comment = 'ToolTip for Qty. Rounding Precision field on Item Units of Measure page extension; no placeholders.';
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        WarehouseEntry: Record "Warehouse Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", Rec."Item No.");
        ItemLedgerEntry.SetRange("Unit of Measure Code", Rec.Code);
        WarehouseEntry.SetRange("Item No.", Rec."Item No.");
        WarehouseEntry.SetRange("Unit of Measure Code", Rec.Code);
        IsQtyRndPrecisionEditable := ItemLedgerEntry.IsEmpty() and WarehouseEntry.IsEmpty();
    end;

    var
        IsQtyRndPrecisionEditable: Boolean;
}
