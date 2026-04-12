/// <summary>
/// Stores optional Dual Unit of Measure overrides for a specific Item Variant.
/// Design: variant record is absent when DUoM should fall back to the base item
/// setup (DUoM Item Setup, table 50100). When a record exists for a given
/// (Item No., Variant Code) pair, its fields take precedence over the item-level
/// setup for the effective Second UoM Code, Conversion Mode and Fixed Ratio.
///
/// The master switch ("Dual UoM Enabled") always lives on the Item setup, not here.
/// A variant override is only applied when the item itself has DUoM enabled.
/// </summary>
table 50101 "DUoM Item Variant Setup"
{
    Caption = 'DUoM Item Variant Setup';
    DataClassification = CustomerContent;
    DrillDownPageId = "DUoM Variant Setup List";
    LookupPageId = "DUoM Variant Setup List";

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        /// <summary>
        /// The item variant whose DUoM configuration overrides the item-level setup.
        /// </summary>
        field(2; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            TableRelation = "Item Variant".Code WHERE("Item No." = FIELD("Item No."));
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        /// <summary>
        /// Override for the secondary unit of measure code.
        /// When blank the effective value is inherited from the item setup.
        /// Must differ from the item's base unit of measure when specified.
        /// </summary>
        field(3; "Second UoM Code"; Code[10])
        {
            Caption = 'Second UoM Code';
            TableRelation = "Unit of Measure";
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if "Second UoM Code" <> '' then
                    CheckSecondUoMDiffersFromBase();
            end;
        }
        /// <summary>
        /// Override for the conversion mode.
        /// Setting to AlwaysVariable clears the Fixed Ratio.
        /// </summary>
        field(4; "Conversion Mode"; Enum "DUoM Conversion Mode")
        {
            Caption = 'Conversion Mode';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if "Conversion Mode" = "Conversion Mode"::AlwaysVariable then
                    "Fixed Ratio" := 0;
            end;
        }
        /// <summary>
        /// Override for the nominal conversion ratio.
        /// 1 base UoM unit = Fixed Ratio secondary UoM units.
        /// Cleared automatically when Conversion Mode is set to AlwaysVariable.
        /// </summary>
        field(5; "Fixed Ratio"; Decimal)
        {
            Caption = 'Fixed Ratio';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Item No.", "Variant Code")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Raises an error if the specified Second UoM Code matches the item's base UoM.
    /// A no-op when the item record cannot be found (e.g. during initialisation).
    /// </summary>
    local procedure CheckSecondUoMDiffersFromBase()
    var
        Item: Record Item;
    begin
        if not Item.Get("Item No.") then
            exit;
        if Item."Base Unit of Measure" = "Second UoM Code" then
            Error(SameUoMErr, "Second UoM Code");
    end;

    var
        SameUoMErr: Label 'Second UoM Code cannot be the same as the base unit of measure (%1).', Comment = '%1 = UoM Code';
}
