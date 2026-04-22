/// <summary>
/// Stores the actual measured conversion ratio for a specific lot number.
/// When an item is received in variable-weight batches (e.g. lettuce by lot),
/// the real ratio (KG/PCS) measured at weigh-in is recorded here and
/// automatically proposed when the lot is assigned on a document line.
/// </summary>
table 50102 "DUoM Lot Ratio"
{
    Caption = 'DUoM Lot Ratio';
    DataClassification = CustomerContent;
    LookupPageId = "DUoM Lot Ratio List";
    DrillDownPageId = "DUoM Lot Ratio List";

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            NotBlank = true;
            TableRelation = Item;
        }
        field(2; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(3; "Actual Ratio"; Decimal)
        {
            Caption = 'Actual Ratio';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;

            trigger OnValidate()
            begin
                if "Actual Ratio" <= 0 then
                    Error(ErrActualRatioMustBePositiveLbl);
            end;
        }
        field(4; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Item No.", "Lot No.")
        {
            Clustered = true;
        }
    }

    var
        ErrActualRatioMustBePositiveLbl: Label 'Actual Ratio must be greater than zero.', Comment = 'Validation error; no placeholders.';
}
