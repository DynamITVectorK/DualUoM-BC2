/// <summary>
/// Codeunit centralizada para la gestión del signo de DUoM Second Qty.
///
/// Principio rector: patrón Piezas manda y gana.
///
/// Reglas funcionales:
///   - DUoM Second Qty sigue el signo del movimiento (positivo en entradas, negativo en salidas).
///   - DUoM Ratio se mantiene positivo como relación entre unidades.
///   - El signo no se aplica dos veces.
///   - Nadie fuera de esta codeunit debe decidir si DUoM Second Qty va positivo o negativo.
///
/// Esta codeunit es el único lugar donde se toman decisiones de signo DUoM:
///   1. NormalizeILESign: normalizar el signo de DUoM Second Qty al insertar un ILE o VE,
///      tomando el signo de ILE.Quantity como fuente de verdad final del movimiento.
///   2. ApplyMovementSign: aplicar el signo técnico del movimiento a una cantidad DUoM
///      positiva cuando se proyecta hacia un Item Journal Line (desde fuente documental
///      o desde Tracking Specification). El signo se determina desde IJL."Quantity (Base)"
///      o IJL.Quantity.
///   3. ApplyUndoPurchReceiptSign: fijar el signo negativo para el IJL de una anulación
///      de albarán de compra (la corrección invierte la recepción original).
///   4. ApplyUndoSalesShptSign: fijar el signo positivo para el IJL de una anulación
///      de albarán de venta (la corrección invierte el envío original).
///   5. ApplyCorrectionILESign: calcular DUoM Second Qty de un ILE de corrección
///      como la negación del ILE original.
///
/// Subscribers del resto del código DUoM deben permanecer "thin" y delegar aquí.
/// No debe haber lógica de signo DUoM dispersa en otros codeunits.
/// </summary>
codeunit 50126 "DUoM Sign Mgt"
{
    Access = Public;

    /// <summary>
    /// Normaliza el signo de DUoM Second Qty siguiendo el signo de ILE.Quantity.
    ///
    /// Regla:
    ///   - ILE.Quantity > 0 (entrada, compra): DUoM Second Qty > 0.
    ///   - ILE.Quantity < 0 (salida, venta):   DUoM Second Qty < 0.
    ///   - ILE.Quantity = 0:                   DUoM Second Qty = SecondQty sin cambio.
    ///   - SecondQty = 0:                      devuelve 0.
    ///
    /// DUoM Ratio no se altera aquí; debe mantenerse positivo en todos los flujos.
    ///
    /// Usar en: OnAfterInitItemLedgEntry, ILECopyTrackingFromItemJnlLine,
    ///          OnAfterInitValueEntry, ILECopyTrackingFromNewItemJnlLine.
    /// </summary>
    procedure NormalizeILESign(ItemLedgerEntry: Record "Item Ledger Entry"; SecondQty: Decimal): Decimal
    begin
        if SecondQty = 0 then
            exit(0);
        if ItemLedgerEntry.Quantity < 0 then
            exit(-Abs(SecondQty));
        if ItemLedgerEntry.Quantity > 0 then
            exit(Abs(SecondQty));
        exit(SecondQty);
    end;

    /// <summary>
    /// Aplica el signo técnico del movimiento a una cantidad DUoM (SecondQty),
    /// tomando la dirección del movimiento desde el Item Journal Line.
    ///
    /// Regla:
    ///   - IJL."Quantity (Base)" < 0 (salida): devuelve -Abs(SecondQty).
    ///   - IJL.Quantity < 0 (salida sin base): devuelve -Abs(SecondQty).
    ///   - En caso contrario (entrada):         devuelve Abs(SecondQty).
    ///   - SecondQty = 0:                       devuelve 0.
    ///
    /// Los datos de usuario (TrackingSpec, ReservEntry, fuentes documentales) se almacenan
    /// siempre positivos. Este método aplica el signo al convertirlos a la dirección real
    /// del movimiento. No debe aplicarse dos veces sobre el mismo valor.
    ///
    /// Usar en: splits TrackingSpec → IJL, proyección Purchase/Sales Line → IJL.
    /// </summary>
    procedure ApplyMovementSign(ItemJournalLine: Record "Item Journal Line"; SecondQty: Decimal): Decimal
    begin
        if SecondQty = 0 then
            exit(0);
        if ItemJournalLine."Quantity (Base)" < 0 then
            exit(-Abs(SecondQty));
        if ItemJournalLine.Quantity < 0 then
            exit(-Abs(SecondQty));
        exit(Abs(SecondQty));
    end;

    /// <summary>
    /// Calcula DUoM Second Qty para el IJL de una anulación de albarán de compra.
    ///
    /// Regla funcional:
    ///   La anulación invierte la recepción original (Qty > 0) → ILE corrección con Qty < 0.
    ///   Por tanto, DUoM Second Qty debe ser negativa para esta corrección.
    ///
    /// Usar en: OnAfterCopyItemJnlLineFromPurchRcpt (DUoM Inventory Subscribers, 50104).
    /// </summary>
    procedure ApplyUndoPurchReceiptSign(OriginalSecondQty: Decimal): Decimal
    begin
        if OriginalSecondQty = 0 then
            exit(0);
        exit(-Abs(OriginalSecondQty));
    end;

    /// <summary>
    /// Calcula DUoM Second Qty para el IJL de una anulación de albarán de venta.
    ///
    /// Regla funcional:
    ///   La anulación invierte el envío original (Qty < 0) → ILE corrección con Qty > 0.
    ///   Por tanto, DUoM Second Qty debe ser positiva para esta corrección.
    ///
    /// Usar en: OnAfterCopyItemJnlLineFromSalesShpt (DUoM Inventory Subscribers, 50104).
    /// </summary>
    procedure ApplyUndoSalesShptSign(OriginalSecondQty: Decimal): Decimal
    begin
        if OriginalSecondQty = 0 then
            exit(0);
        exit(Abs(OriginalSecondQty));
    end;

    /// <summary>
    /// Calcula DUoM Second Qty para un ILE de corrección a partir del ILE original.
    ///
    /// Regla funcional:
    ///   Un ILE de corrección invierte el movimiento original.
    ///   DUoM Second Qty del nuevo ILE = negación del DUoM Second Qty del ILE original.
    ///
    /// Usar en: OnBeforeInsertCorrItemLedgEntry (DUoM Inventory Subscribers, 50104).
    /// Este evento es el único punto donde OldItemLedgEntry está disponible y el signo
    /// definitivo del ILE de corrección todavía no se ha asignado a NewItemLedgEntry.
    /// </summary>
    procedure ApplyCorrectionILESign(OldILESecondQty: Decimal): Decimal
    begin
        exit(-OldILESecondQty);
    end;
}
