/// <summary>
/// Gestión centralizada del contexto de artículo/variante en Entry Summary.
/// Resuelve Item No. y Variant Code desde la tabla origen real del buffer,
/// usando Table ID + Entry No. como referencia hacia Item Ledger Entry
/// o Reservation Entry.
///
/// Motivo: Entry Summary (tabla 338) no contiene campos "Item No." ni "Variant Code"
/// en BC 27. La información de artículo debe obtenerse desde el origen real:
///   - Table ID = 32 (Item Ledger Entry): Entry No. = ILE Entry No. → Get directo.
///   - Table ID = 337 (Reservation Entry): Entry No. filtra por RE → FindFirst.
/// </summary>
codeunit 50132 "DUoM Entry Summary Mgt."
{
    Access = Internal;

    /// <summary>
    /// Intenta resolver el contexto de artículo/variante desde un Entry Summary.
    /// Devuelve true si puede determinar un Item No. fiable; false en caso contrario.
    /// No provoca errores si el origen no es compatible o no es DUoM.
    ///
    /// Implementación:
    ///   - Table ID 32 (Item Ledger Entry): Get por Entry No. (Entry No. = ILE Entry No.).
    ///   - Table ID 337 (Reservation Entry): FindFirst filtrado por Entry No.
    ///   - Otros Table ID o Entry No. = 0: devuelve false.
    /// </summary>
    procedure TryResolveItemContext(
        EntrySummary: Record "Entry Summary";
        var ItemNo: Code[20];
        var VariantCode: Code[10]
    ): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
    begin
        ItemNo := '';
        VariantCode := '';

        if EntrySummary."Entry No." = 0 then
            exit(false);

        case EntrySummary."Table ID" of
            Database::"Item Ledger Entry":
                begin
                    if not ItemLedgerEntry.Get(EntrySummary."Entry No.") then
                        exit(false);
                    ItemNo := ItemLedgerEntry."Item No.";
                    VariantCode := ItemLedgerEntry."Variant Code";
                    exit(true);
                end;
            Database::"Reservation Entry":
                begin
                    ReservationEntry.SetRange("Entry No.", EntrySummary."Entry No.");
                    if not ReservationEntry.FindFirst() then
                        exit(false);
                    ItemNo := ReservationEntry."Item No.";
                    VariantCode := ReservationEntry."Variant Code";
                    exit(true);
                end;
        end;

        exit(false);
    end;
}
