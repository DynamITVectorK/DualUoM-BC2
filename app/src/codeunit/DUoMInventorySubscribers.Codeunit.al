/// <summary>
/// Event subscribers for the Inventory flow (Item Journal and Item Ledger Entry)
/// in Dual Unit of Measure.
///
/// Propagation strategy for posted document lines (BC 27 / runtime 15):
///   - Purchase Line → Purch. Rcpt. Line:
///     Subscriber to OnAfterInitFromPurchLine on Table "Purch. Rcpt. Line".
///     Signature verified against microsoft/bc-w1 PurchRcptLine.Table.al.
///   - Purchase Line → Purch. Inv. Line:
///     Subscriber to OnAfterInitFromPurchLine on Table "Purch. Inv. Line".
///     Signature verified against microsoft/bc-w1 PurchInvLine.Table.al.
///   - Purchase Line → Purch. Cr. Memo Line:
///     Subscriber to OnAfterInitFromPurchLine on Table "Purch. Cr. Memo Line".
///     Signature verified against microsoft/bc-w1 PurchCrMemoLine.Table.al.
///   - Sales Line → Sales Shipment Line:
///     Subscriber to OnAfterInitFromSalesLine on Table "Sales Shipment Line".
///     Signature verified against microsoft/bc-w1 SalesShipmentLine.Table.al.
///   - Sales Line → Sales Invoice Line:
///     Subscriber to OnAfterInitFromSalesLine on Table "Sales Invoice Line".
///     Signature verified against microsoft/bc-w1 SalesInvoiceLine.Table.al.
///     NOTE: var SalesInvLine is the FIRST parameter (unlike Purchase pattern).
///   - Sales Line → Sales Cr.Memo Line:
///     Subscriber to OnAfterInitFromSalesLine on Table "Sales Cr.Memo Line".
///     Signature verified against microsoft/bc-w1 SalesCrMemoLine.Table.al.
///     NOTE: var SalesCrMemoLine is the FIRST parameter (unlike Purchase pattern).
///   The actual field-copy logic is centralized in DUoM Doc Transfer Helper (50105).
///
/// Propagation strategy for ILE:
///   DUoM fields are populated on the Item Journal Line upstream:
///   - For Purchase posting: OnPostItemJnlLineOnAfterCopyDocumentFields (Purch.-Post)
///     copies DUoM fields from Purchase Line to Item Journal Line.
///   - For Sales posting: OnPostItemJnlLineOnAfterCopyDocumentFields (Sales-Post)
///     copies DUoM fields from Sales Line to Item Journal Line.
///   - For manual Item Journal postings: OnAfterValidateItemJnlLineQty auto-computes
///     DUoM fields when Quantity is validated through the UI.
///   OnAfterInitItemLedgEntry then copies the DUoM fields from the Item Journal Line
///   to the new ILE before Insert() — no Modify() call is needed.
/// </summary>
codeunit 50104 "DUoM Inventory Subscribers"
{
    Access = Internal;

    /// <summary>
    /// Reacts to Quantity changes on Item Journal Lines for items with DUoM enabled.
    /// Auto-computes DUoM Second Qty from the effective ratio (line ratio or item default).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidateItemJnlLineQty(var Rec: Record "Item Journal Line"; var xRec: Record "Item Journal Line")
    var
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
        DUoMItemSetup: Record "DUoM Item Setup";
        EffectiveRatio: Decimal;
    begin
        if Rec."Item No." = '' then
            exit;
        if not DUoMItemSetup.Get(Rec."Item No.") then
            exit;
        if not DUoMItemSetup."Dual UoM Enabled" then
            exit;
        if DUoMItemSetup."Conversion Mode" = DUoMItemSetup."Conversion Mode"::AlwaysVariable then
            exit;

        EffectiveRatio := Rec."DUoM Ratio";
        if EffectiveRatio = 0 then begin
            EffectiveRatio := DUoMItemSetup."Fixed Ratio";
            if EffectiveRatio <> 0 then
                Rec."DUoM Ratio" := EffectiveRatio;
        end;

        Rec."DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQty(Rec.Quantity, EffectiveRatio, DUoMItemSetup."Conversion Mode");
    end;

    /// <summary>
    /// During Purchase posting, copies DUoM fields from the Purchase Line to the
    /// Item Journal Line before it is posted, so that OnAfterInitItemLedgEntry
    /// can transfer them to the ILE without needing a Modify() call.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnPostItemJnlLineOnAfterCopyDocumentFields', '', false, false)]
    local procedure OnPurchPostCopyDocFieldsToItemJnlLine(var ItemJournalLine: Record "Item Journal Line"; PurchaseLine: Record "Purchase Line")
    begin
        ItemJournalLine."DUoM Second Qty" := PurchaseLine."DUoM Second Qty";
        ItemJournalLine."DUoM Ratio" := PurchaseLine."DUoM Ratio";
    end;

    /// <summary>
    /// During Sales posting, copies DUoM fields from the Sales Line to the
    /// Item Journal Line before it is posted, so that OnAfterInitItemLedgEntry
    /// can transfer them to the ILE without needing a Modify() call.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnPostItemJnlLineOnAfterCopyDocumentFields', '', false, false)]
    local procedure OnSalesPostCopyDocFieldsToItemJnlLine(var ItemJournalLine: Record "Item Journal Line"; SalesLine: Record "Sales Line")
    begin
        ItemJournalLine."DUoM Second Qty" := SalesLine."DUoM Second Qty";
        ItemJournalLine."DUoM Ratio" := SalesLine."DUoM Ratio";
    end;

    /// <summary>
    /// Durante la contabilización de compra, copia los campos DUoM desde la Purchase Line
    /// a la Purch. Rcpt. Line en el momento de la inicialización del registro de destino.
    /// Evento: OnAfterInitFromPurchLine en la tabla "Purch. Rcpt. Line" (BC 27 / runtime 15).
    /// Firma verificada en microsoft/bc-w1: PurchRcptLine.Table.al, procedure InitFromPurchLine.
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Purch. Rcpt. Line", 'OnAfterInitFromPurchLine', '', false, false)]
    local procedure OnAfterInitFromPurchLine(PurchRcptHeader: Record "Purch. Rcpt. Header"; PurchLine: Record "Purchase Line"; var PurchRcptLine: Record "Purch. Rcpt. Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromPurchLineToPurchRcptLine(PurchLine, PurchRcptLine);
    end;

    /// <summary>
    /// Durante la contabilización de venta, copia los campos DUoM desde la Sales Line
    /// a la Sales Shipment Line en el momento de la inicialización del registro de destino.
    /// Evento: OnAfterInitFromSalesLine en la tabla "Sales Shipment Line" (BC 27 / runtime 15).
    /// Firma verificada en microsoft/bc-w1: SalesShipmentLine.Table.al, procedure InitFromSalesLine.
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Sales Shipment Line", 'OnAfterInitFromSalesLine', '', false, false)]
    local procedure OnAfterInitFromSalesLine(SalesShptHeader: Record "Sales Shipment Header"; SalesLine: Record "Sales Line"; var SalesShptLine: Record "Sales Shipment Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromSalesLineToShipLine(SalesLine, SalesShptLine);
    end;

    /// <summary>
    /// Durante la contabilización de compra como factura, copia los campos DUoM desde la
    /// Purchase Line a la Purch. Inv. Line en el momento de la inicialización del registro.
    /// Evento: OnAfterInitFromPurchLine en la tabla "Purch. Inv. Line" (BC 27 / runtime 15).
    /// Publisher: Table "Purch. Inv. Line", evento elegido porque es la inicialización
    /// estándar de la línea de factura registrada desde la línea de compra origen.
    /// Firma verificada en FBakkensen/bc-w1: PurchInvLine.Table.al, procedure InitFromPurchLine
    /// → OnAfterInitFromPurchLine(PurchInvHeader, PurchLine, Rec).
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Purch. Inv. Line", 'OnAfterInitFromPurchLine', '', false, false)]
    local procedure OnAfterInitFromPurchInvLine(PurchInvHeader: Record "Purch. Inv. Header"; PurchLine: Record "Purchase Line"; var PurchInvLine: Record "Purch. Inv. Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromPurchLineToPurchInvLine(PurchLine, PurchInvLine);
    end;

    /// <summary>
    /// Durante la contabilización de un abono de compra, copia los campos DUoM desde la
    /// Purchase Line a la Purch. Cr. Memo Line en el momento de la inicialización del registro.
    /// Evento: OnAfterInitFromPurchLine en la tabla "Purch. Cr. Memo Line" (BC 27 / runtime 15).
    /// Publisher: Table "Purch. Cr. Memo Line", evento elegido porque es la inicialización
    /// estándar de la línea de abono registrado desde la línea de compra origen.
    /// Firma verificada en FBakkensen/bc-w1: PurchCrMemoLine.Table.al, procedure InitFromPurchLine
    /// → OnAfterInitFromPurchLine(PurchCrMemoHdr, PurchLine, Rec).
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Purch. Cr. Memo Line", 'OnAfterInitFromPurchLine', '', false, false)]
    local procedure OnAfterInitFromPurchCrMemoLine(PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr."; PurchLine: Record "Purchase Line"; var PurchCrMemoLine: Record "Purch. Cr. Memo Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromPurchLineToPurchCrMemoLine(PurchLine, PurchCrMemoLine);
    end;

    /// <summary>
    /// Durante la contabilización de venta como factura, copia los campos DUoM desde la
    /// Sales Line a la Sales Invoice Line en el momento de la inicialización del registro.
    /// Evento: OnAfterInitFromSalesLine en la tabla "Sales Invoice Line" (BC 27 / runtime 15).
    /// Publisher: Table "Sales Invoice Line", evento elegido porque es la inicialización
    /// estándar de la línea de factura registrada desde la línea de venta origen.
    /// Firma verificada en FBakkensen/bc-w1: SalesInvoiceLine.Table.al, procedure InitFromSalesLine
    /// → OnAfterInitFromSalesLine(var SalesInvLine, SalesInvHeader, SalesLine).
    /// IMPORTANTE: el parámetro var es el PRIMERO en Sales (distinto del patrón Purchase).
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Sales Invoice Line", 'OnAfterInitFromSalesLine', '', false, false)]
    local procedure OnAfterInitFromSalesInvLine(var SalesInvLine: Record "Sales Invoice Line"; SalesInvHeader: Record "Sales Invoice Header"; SalesLine: Record "Sales Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromSalesLineToSalesInvLine(SalesLine, SalesInvLine);
    end;

    /// <summary>
    /// Durante la contabilización de un abono de venta, copia los campos DUoM desde la
    /// Sales Line a la Sales Cr.Memo Line en el momento de la inicialización del registro.
    /// Evento: OnAfterInitFromSalesLine en la tabla "Sales Cr.Memo Line" (BC 27 / runtime 15).
    /// Publisher: Table "Sales Cr.Memo Line", evento elegido porque es la inicialización
    /// estándar de la línea de abono registrado desde la línea de venta origen.
    /// Firma verificada en FBakkensen/bc-w1: SalesCrMemoLine.Table.al, procedure InitFromSalesLine
    /// → OnAfterInitFromSalesLine(var SalesCrMemoLine, SalesCrMemoHeader, SalesLine).
    /// IMPORTANTE: el parámetro var es el PRIMERO en Sales (distinto del patrón Purchase).
    /// La lógica de copia está centralizada en DUoM Doc Transfer Helper (50105).
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Sales Cr.Memo Line", 'OnAfterInitFromSalesLine', '', false, false)]
    local procedure OnAfterInitFromSalesCrMemoLine(var SalesCrMemoLine: Record "Sales Cr.Memo Line"; SalesCrMemoHeader: Record "Sales Cr.Memo Header"; SalesLine: Record "Sales Line")
    var
        DUoMDocTransferHelper: Codeunit "DUoM Doc Transfer Helper";
    begin
        DUoMDocTransferHelper.CopyFromSalesLineToSalesCrMemoLine(SalesLine, SalesCrMemoLine);
    end;

    /// <summary>
    /// Initialises DUoM fields on the new Item Ledger Entry from the Item Journal Line
    /// before the ILE is inserted — no Modify() call is needed.
    /// Covers both Purchase/Sales posting paths (fields propagated via
    /// OnPostItemJnlLineOnAfterCopyDocumentFields) and manual Item Journal postings
    /// (fields populated by OnAfterValidateItemJnlLineQty).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', false, false)]
    local procedure OnAfterInitItemLedgEntry(var NewItemLedgEntry: Record "Item Ledger Entry"; var ItemJournalLine: Record "Item Journal Line"; var ItemLedgEntryNo: Integer)
    begin
        // Exit only when BOTH fields are zero — cases where one field is zero
        // (e.g., AlwaysVariable with no ratio, or Fixed mode with zero posted quantity
        // but a valid ratio) are correctly propagated.
        if (ItemJournalLine."DUoM Second Qty" = 0) and (ItemJournalLine."DUoM Ratio" = 0) then
            exit;
        NewItemLedgEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";
        NewItemLedgEntry."DUoM Ratio" := ItemJournalLine."DUoM Ratio";
    end;
}
