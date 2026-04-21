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
///   - Purchase Line → Purch. Inv. Line   (InitFromPurchLine)
///   - Purchase Line → Purch. Cr. Memo Line (InitFromPurchLine)
///   - Sales Line → Sales Invoice Line    (InitFromSalesLine)
///   - Sales Line → Sales Cr.Memo Line    (InitFromSalesLine)
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
        SalesShptLine."DUoM Unit Price" := SalesLine."DUoM Unit Price";
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
        PurchRcptLine."DUoM Unit Cost" := PurchaseLine."DUoM Unit Cost";
    end;

    /// <summary>
    /// Copia los campos DUoM desde una Purchase Line hacia una Purch. Inv. Line.
    /// Se invoca desde el suscriptor de OnAfterInitFromPurchLine en la tabla
    /// "Purch. Inv. Line" (BC 27 / runtime 15).
    /// </summary>
    procedure CopyFromPurchLineToPurchInvLine(PurchaseLine: Record "Purchase Line"; var PurchInvLine: Record "Purch. Inv. Line")
    begin
        if (PurchaseLine."DUoM Second Qty" = 0) and (PurchaseLine."DUoM Ratio" = 0) then
            exit;
        PurchInvLine."DUoM Second Qty" := PurchaseLine."DUoM Second Qty";
        PurchInvLine."DUoM Ratio" := PurchaseLine."DUoM Ratio";
        PurchInvLine."DUoM Unit Cost" := PurchaseLine."DUoM Unit Cost";
    end;

    /// <summary>
    /// Copia los campos DUoM desde una Purchase Line hacia una Purch. Cr. Memo Line.
    /// Se invoca desde el suscriptor de OnAfterInitFromPurchLine en la tabla
    /// "Purch. Cr. Memo Line" (BC 27 / runtime 15).
    /// </summary>
    procedure CopyFromPurchLineToPurchCrMemoLine(PurchaseLine: Record "Purchase Line"; var PurchCrMemoLine: Record "Purch. Cr. Memo Line")
    begin
        if (PurchaseLine."DUoM Second Qty" = 0) and (PurchaseLine."DUoM Ratio" = 0) then
            exit;
        PurchCrMemoLine."DUoM Second Qty" := PurchaseLine."DUoM Second Qty";
        PurchCrMemoLine."DUoM Ratio" := PurchaseLine."DUoM Ratio";
        PurchCrMemoLine."DUoM Unit Cost" := PurchaseLine."DUoM Unit Cost";
    end;

    /// <summary>
    /// Copia los campos DUoM desde una Sales Line hacia una Sales Invoice Line.
    /// Se invoca desde el suscriptor de OnAfterInitFromSalesLine en la tabla
    /// "Sales Invoice Line" (BC 27 / runtime 15).
    /// </summary>
    procedure CopyFromSalesLineToSalesInvLine(SalesLine: Record "Sales Line"; var SalesInvLine: Record "Sales Invoice Line")
    begin
        if (SalesLine."DUoM Second Qty" = 0) and (SalesLine."DUoM Ratio" = 0) then
            exit;
        SalesInvLine."DUoM Second Qty" := SalesLine."DUoM Second Qty";
        SalesInvLine."DUoM Ratio" := SalesLine."DUoM Ratio";
        SalesInvLine."DUoM Unit Price" := SalesLine."DUoM Unit Price";
    end;

    /// <summary>
    /// Copia los campos DUoM desde una Sales Line hacia una Sales Cr.Memo Line.
    /// Se invoca desde el suscriptor de OnAfterInitFromSalesLine en la tabla
    /// "Sales Cr.Memo Line" (BC 27 / runtime 15).
    /// </summary>
    procedure CopyFromSalesLineToSalesCrMemoLine(SalesLine: Record "Sales Line"; var SalesCrMemoLine: Record "Sales Cr.Memo Line")
    begin
        if (SalesLine."DUoM Second Qty" = 0) and (SalesLine."DUoM Ratio" = 0) then
            exit;
        SalesCrMemoLine."DUoM Second Qty" := SalesLine."DUoM Second Qty";
        SalesCrMemoLine."DUoM Ratio" := SalesLine."DUoM Ratio";
        SalesCrMemoLine."DUoM Unit Price" := SalesLine."DUoM Unit Price";
    end;
}
