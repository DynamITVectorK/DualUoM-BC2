/// <summary>
/// Extends the Reservation Entry table (337) with Dual Unit of Measure fields.
/// When the user confirms Item Tracking Lines (page 6510), BC calls
/// ReservationEntry.CopyTrackingFromSpec(TrackingSpecification), which publishes
/// OnAfterCopyTrackingFromTrackingSpec. DUoM Tracking Subscribers (50109) subscribes
/// to that event and copies DUoM Second Qty and DUoM Ratio from the buffer entry
/// (Tracking Specification 6500) to the persisted Reservation Entry (337).
///
/// This is the standard BC extension mechanism for propagating custom fields
/// from Tracking Specification to Reservation Entry — same pattern used by
/// Package No. Information, CD Tracking (RU), and other BC localizations.
///
/// Signatures verificadas BC 27 / runtime 15:
///   - Reservation Entry (table 337): OnAfterCopyTrackingFromTrackingSpec event
///     published in procedure CopyTrackingFromSpec(TrackingSpecification).
///   - Event fires whenever BC code creates/updates a Reservation Entry from
///     a Tracking Specification buffer, including Item Tracking Lines confirmation.
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
