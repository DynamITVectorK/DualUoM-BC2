/// <summary>
/// Extends the Item table to cascade-delete the DUoM Item Setup record
/// when an item is deleted, preventing orphaned setup data.
/// </summary>
tableextension 50100 "DUoM Item TableExt" extends Item
{
    fields
    {
        field(50124; "DUoM Inventory"; Decimal)
        {
            Caption = 'DUoM Inventory';
            ToolTip = 'Specifies the registered inventory in the second unit of measure, calculated from Item Ledger Entries.', Comment = 'ToolTip for DUoM Inventory field on Item; no placeholders.';
            FieldClass = FlowField;
            Editable = false;
            CalcFormula = Sum("Item Ledger Entry"."DUoM Second Qty" WHERE("Item No." = FIELD("No."),
                                                                           "Global Dimension 1 Code" = FIELD("Global Dimension 1 Filter"),
                                                                           "Global Dimension 2 Code" = FIELD("Global Dimension 2 Filter"),
                                                                           "Location Code" = FIELD("Location Filter"),
                                                                           "Drop Shipment" = FIELD("Drop Shipment Filter"),
                                                                           "Variant Code" = FIELD("Variant Filter"),
                                                                           "Posting Date" = FIELD("Date Filter"),
                                                                           "Lot No." = FIELD("Lot No. Filter"),
                                                                           "Serial No." = FIELD("Serial No. Filter"),
                                                                           "Package No." = FIELD("Package No. Filter")));
        }
    }

    trigger OnDelete()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        if DUoMItemSetup.Get(Rec."No.") then
            DUoMItemSetup.Delete(true);
    end;
}
