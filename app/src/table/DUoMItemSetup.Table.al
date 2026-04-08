/// <summary>
/// Stores the Dual Unit of Measure configuration for a single item.
/// Design choice: dedicated setup table (Option B) rather than extending the Item table
/// directly. This keeps the base Item table clean, supports future extensibility for
/// lot-specific and warehouse scenarios, and follows SaaS-safe extension patterns.
/// One record per item; the record is absent when DUoM is not used for that item.
/// </summary>
table 50100 "DUoM Item Setup"
{
    Caption = 'DUoM Item Setup';
    DataClassification = CustomerContent;
    DrillDownPageId = "DUoM Item Setup";
    LookupPageId = "DUoM Item Setup";

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
        /// Master switch: when false all other DUoM fields are irrelevant.
        /// Setting this to false via Validate() clears all DUoM-specific fields.
        /// </summary>
        field(2; "Dual UoM Enabled"; Boolean)
        {
            Caption = 'Dual UoM Enabled';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if not "Dual UoM Enabled" then
                    ClearDUoMFields();
            end;
        }
        /// <summary>
        /// The secondary unit of measure code (e.g. PCS when the base UoM is KG).
        /// Must differ from the item's base unit of measure.
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
        /// Determines how the conversion ratio is sourced at transaction time:
        ///   Fixed         – constant ratio stored in Fixed Ratio field
        ///   Variable      – default ratio from Fixed Ratio, overridable per document line
        ///   Always Variable – no default; user must enter manually on every line
        /// </summary>
        field(4; "Conversion Mode"; Enum "DUoM Conversion Mode")
        {
            Caption = 'Conversion Mode';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                // Always Variable has no concept of a default ratio; clear it.
                // Variable retains Fixed Ratio as an optional default per-line override.
                if "Conversion Mode" = "Conversion Mode"::AlwaysVariable then
                    "Fixed Ratio" := 0;
            end;
        }
        /// <summary>
        /// The nominal conversion ratio when Conversion Mode is Fixed or Variable.
        /// Represents: 1 base UoM unit = Fixed Ratio second UoM units.
        /// Must be greater than zero when Conversion Mode is Fixed.
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
        key(PK; "Item No.")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Clears all DUoM-specific fields when DUoM is disabled.
    /// Called from the Dual UoM Enabled OnValidate trigger.
    /// </summary>
    local procedure ClearDUoMFields()
    begin
        "Second UoM Code" := '';
        "Conversion Mode" := "Conversion Mode"::Fixed;
        "Fixed Ratio" := 0;
    end;

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

    /// <summary>
    /// Validates the overall DUoM setup for consistency.
    /// Call this before persisting or using the setup in a document flow.
    /// </summary>
    procedure ValidateSetup()
    var
        Item: Record Item;
    begin
        if not "Dual UoM Enabled" then
            exit;

        if "Second UoM Code" = '' then
            Error(SecondUoMRequiredErr);

        if Item.Get("Item No.") then
            if Item."Base Unit of Measure" = "Second UoM Code" then
                Error(SameUoMErr, "Second UoM Code");

        if "Conversion Mode" = "Conversion Mode"::Fixed then
            if "Fixed Ratio" <= 0 then
                Error(FixedRatioRequiredErr);
    end;

    var
        SameUoMErr: Label 'Second UoM Code cannot be the same as the base unit of measure (%1).', Comment = '%1 = UoM Code';
        SecondUoMRequiredErr: Label 'Second UoM Code must be specified when Dual UoM is enabled.';
        FixedRatioRequiredErr: Label 'Fixed Ratio must be greater than zero when Conversion Mode is Fixed.';
}
