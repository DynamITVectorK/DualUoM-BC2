/// <summary>
/// Helper codeunit that centralizes the logic for copying DUoM fields
/// from source document lines to posted document lines.
///
/// Patrón de uso:
///   Los suscriptores de eventos deben permanecer delgados ("thin subscribers").
///   Toda la lógica de copia de campos DUoM entre líneas debe delegarse aquí,
///   para facilitar el mantenimiento, las pruebas y la extensibilidad futura.
///
/// Flujos cubiertos:
///   - Sales Line → Sales Shipment Line   (InitFromSalesLine)
///   - Purchase Line → Purch. Rcpt. Line  (InitFromPurchLine)
/// </summary>
codeunit 50105 "DUoM Doc Transfer Helper"
{
    Access = Internal;

    /// <summary>
    /// Copia los campos DUoM desde una Sales Line hacia una Sales Shipment Line.
    /// Se invoca desde el suscriptor de OnAfterInitFromSalesLine en la tabla
    /// "Sales Shipment Line". Prefiere la copia directa de los valores ya
    /// establecidos en la línea de origen; no recalcula salvo que sea necesario.
    /// </summary>
    procedure CopyFromSalesLineToShipLine(SalesLine: Record "Sales Line"; var SalesShptLine: Record "Sales Shipment Line")
    begin
        if (SalesLine."DUoM Second Qty" = 0) and (SalesLine."DUoM Ratio" = 0) then
            exit;
        SalesShptLine."DUoM Second Qty" := SalesLine."DUoM Second Qty";
        SalesShptLine."DUoM Ratio" := SalesLine."DUoM Ratio";
    end;

    /// <summary>
    /// Copia los campos DUoM desde una Purchase Line hacia una Purch. Rcpt. Line.
    /// Se invoca desde el suscriptor de OnAfterInitFromPurchLine en la tabla
    /// "Purch. Rcpt. Line". Prefiere la copia directa de los valores ya
    /// establecidos en la línea de origen; no recalcula salvo que sea necesario.
    /// </summary>
    procedure CopyFromPurchLineToPurchRcptLine(PurchaseLine: Record "Purchase Line"; var PurchRcptLine: Record "Purch. Rcpt. Line")
    begin
        if (PurchaseLine."DUoM Second Qty" = 0) and (PurchaseLine."DUoM Ratio" = 0) then
            exit;
        PurchRcptLine."DUoM Second Qty" := PurchaseLine."DUoM Second Qty";
        PurchRcptLine."DUoM Ratio" := PurchaseLine."DUoM Ratio";
    end;
}
