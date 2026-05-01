/// <summary>
/// Extends the Reservation Entry table (337) with Dual Unit of Measure fields.
///
/// La propagación desde Tracking Specification (6500) hacia Reservation Entry (337)
/// se implementa en DUoM Tracking Copy Subscribers (50110) vía el evento
/// OnAfterCopyTrackingFromTrackingSpec en esta tabla, siguiendo el patrón de
/// codeunit 6516 "Package Management". Este evento sí expone var ReservationEntry
/// como parámetro modificable — la limitación AL0282 documentada anteriormente
/// era incorrecta (se confundió con el evento homónimo en tabla Tracking Specification).
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
