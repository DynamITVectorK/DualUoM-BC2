/// <summary>
/// Extends the Reservation Entry table (337) with Dual Unit of Measure fields.
///
/// Note: The automatic propagation from Tracking Specification (6500) to Reservation Entry
/// (337) is NOT implemented because the BC 27 event OnAfterCopyTrackingFromTrackingSpec
/// does not expose a modifiable "var Rec: Record Reservation Entry" parameter for extension
/// fields (AL0282). The fields are defined here for future use when a safe propagation
/// mechanism is available (tarea futura N-lotes).
///
/// The DUoM ratio per lot is applied to the Item Ledger Entry during posting via
/// TryApplyLotRatioToILE (DUoM Lot Subscribers, 50108).
/// </summary>
tableextension 50123 "DUoM Reservation Entry Ext" extends "Reservation Entry"
{
    fields
    {
        field(50100; "DUoM Second Qty"; Decimal)
        {
            Caption = 'DUoM Second Qty', Comment = 'Caption for DUoM Second Qty field; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
        field(50101; "DUoM Ratio"; Decimal)
        {
            Caption = 'DUoM Ratio', Comment = 'Caption for DUoM Ratio field; no placeholders.';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
    }
}
