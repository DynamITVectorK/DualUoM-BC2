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
///   Two parallel mechanisms cover both paths:
///
///   SIN Item Tracking (artículos sin lotes / sin trazabilidad activa):
///     OnPostItemJnlLineOnAfterCopyDocumentFields → Purchase/Sales Line → IJL  (ya existe)
///     OnAfterInitItemLedgEntry → IJL → ILE  (copia campos DUoM del IJL antes del Insert)
///     Este subscriber siempre se dispara, con o sin tracking activo.
///
///   CON Item Tracking (por lote, BC llama CopyTrackingFromItemJnlLine solo cuando hay Lot/Serial):
///     OnAfterCopyTrackingFromSpec → TrackingSpec → IJL  (refinamiento por lote)
///     OnAfterCopyTrackingFromItemJnlLine → IJL → ILE  (codeunit 50110)
///     Estos subscribers solo se disparan cuando hay tracking activo (Lot No. / Serial No.).
///     ILECopyTrackingFromItemJnlLine sobrescribe lo que OnAfterInitItemLedgEntry copió,
///     aplicando Abs(ILE.Quantity) × Ratio específico del lote.
///
///   IMPORTANTE: OnAfterInitItemLedgEntry no llama a TryApplyLotRatioToILE.
///   La lógica de lote específico la gestiona codeunit 50110 exclusivamente.
///
/// Estrategia de propagación para Value Entry:
///   OnAfterInitValueEntry en Codeunit "Item Jnl.-Post Line" (BC 27 / runtime 15)
///   copia DUoM Second Qty desde la Item Journal Line al nuevo Value Entry
///   antes de Insert() — no se necesita ninguna llamada a Modify().
///   Firma verificada: (var ValueEntry; var ItemJournalLine; var ValueEntryNo; var ItemLedgEntry).
/// </summary>
codeunit 50104 "DUoM Inventory Subscribers"
{
    Access = Internal;

    /// <summary>
    /// Reacts to Quantity changes on Item Journal Lines for items with DUoM enabled.
    /// Auto-computes DUoM Second Qty from the effective ratio, applying the
    /// Item → Variant hierarchy via DUoM Setup Resolver.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidateItemJnlLineQty(var Rec: Record "Item Journal Line"; var xRec: Record "Item Journal Line")
    var
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        EffectiveRatio: Decimal;
    begin
        if Rec."Item No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(Rec."Item No.", Rec."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;
        if ConversionMode = ConversionMode::AlwaysVariable then
            exit;

        EffectiveRatio := Rec."DUoM Ratio";
        if EffectiveRatio = 0 then begin
            EffectiveRatio := FixedRatio;
            if EffectiveRatio <> 0 then
                Rec."DUoM Ratio" := EffectiveRatio;
        end;

        Rec."DUoM Second Qty" := DUoMCalcEngine.ComputeSecondQty(Rec.Quantity, EffectiveRatio, ConversionMode);
    end;

    /// <summary>
    /// During Purchase posting, copies DUoM fields from the Purchase Line to the
    /// Item Journal Line before it is posted, so that DUoM Tracking Copy Subscribers
    /// (50110) can transfer them to the ILE via OnAfterCopyTrackingFromItemJnlLine.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnPostItemJnlLineOnAfterCopyDocumentFields', '', false, false)]
    local procedure OnPurchPostCopyDocFieldsToItemJnlLine(var ItemJournalLine: Record "Item Journal Line"; PurchaseLine: Record "Purchase Line")
    begin
        ItemJournalLine."DUoM Second Qty" := PurchaseLine."DUoM Second Qty";
        ItemJournalLine."DUoM Ratio" := PurchaseLine."DUoM Ratio";
    end;

    /// <summary>
    /// During Sales posting, copies DUoM fields from the Sales Line to the
    /// Item Journal Line before it is posted, so that DUoM Tracking Copy Subscribers
    /// (50110) can transfer them to the ILE via OnAfterCopyTrackingFromItemJnlLine.
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
    /// Inicializa campos DUoM en el nuevo Item Ledger Entry desde el Item Journal Line
    /// antes del Insert() — sin llamada a Modify().
    ///
    /// Este subscriber cubre el flujo SIN Item Tracking (artículos sin lotes):
    ///   OnAfterCopyTrackingFromItemJnlLine (codeunit 50110) no se dispara cuando
    ///   BC no llama CopyTrackingFromItemJnlLine() porque no hay tracking activo.
    ///   Este subscriber garantiza que DUoM Ratio y DUoM Second Qty lleguen al ILE
    ///   para artículos sin trazabilidad de lote o serie.
    ///
    /// Para artículos CON Item Tracking (Lot No. / Serial No.):
    ///   ILECopyTrackingFromItemJnlLine (codeunit 50110) se dispara después de este
    ///   subscriber y sobrescribe con Abs(ILE.Quantity) × Ratio específico del lote.
    ///   La coexistencia es correcta — la sobreescritura posterior es siempre más precisa.
    ///
    /// Lógica simplificada (sin llamada a TryApplyLotRatioToILE):
    ///   La lógica de ratio de lote específico la gestiona codeunit 50110 exclusivamente.
    ///
    /// Publisher: Codeunit "Item Jnl.-Post Line", evento OnAfterInitItemLedgEntry.
    /// Firma verificada en BC 27 / runtime 15 (ItemJnlPostLine.Codeunit.al).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', false, false)]
    local procedure OnAfterInitItemLedgEntry(var NewItemLedgEntry: Record "Item Ledger Entry"; var ItemJournalLine: Record "Item Journal Line"; var ItemLedgEntryNo: Integer)
    begin
        if (ItemJournalLine."DUoM Ratio" = 0) and (ItemJournalLine."DUoM Second Qty" = 0) then
            exit;
        NewItemLedgEntry."DUoM Ratio" := ItemJournalLine."DUoM Ratio";
        if ItemJournalLine."DUoM Ratio" <> 0 then
            // Recalcular con la cantidad exacta del ILE para que el valor sea siempre
            // proporcional a la cantidad contabilizada (correcto también en multi-lote
            // antes de que 50110 sobrescriba con el ratio específico del lote).
            NewItemLedgEntry."DUoM Second Qty" :=
                Abs(NewItemLedgEntry.Quantity) * ItemJournalLine."DUoM Ratio"
        else
            // AlwaysVariable sin ratio: copiar DUoM Second Qty directamente desde IJL.
            // Solo alcanzable en flujo sin Item Tracking (ratio = 0, sin lote).
            NewItemLedgEntry."DUoM Second Qty" := ItemJournalLine."DUoM Second Qty";
    end;

    /// <summary>
    /// Propaga DUoM Second Qty desde el Item Journal Line al nuevo Value Entry
    /// antes de que se inserte — sin llamada a Modify().
    /// Publisher: Codeunit "Item Jnl.-Post Line", evento OnAfterInitValueEntry.
    /// Evento elegido porque inicializa el Value Entry desde el Item Journal Line
    /// en el mismo flujo de contabilización que OnAfterInitItemLedgEntry.
    /// Firma verificada en BC 27 / runtime 15 (ItemJnlPostLine.Codeunit.al):
    ///   OnAfterInitValueEntry(var ValueEntry; var ItemJnlLine; var ValueEntryNo; var ItemLedgEntry).
    /// Patrón SaaS: OnAfterInit* + asignación directa (sin Modify sobre tabla base).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitValueEntry', '', false, false)]
    local procedure OnAfterInitValueEntry(var ValueEntry: Record "Value Entry"; var ItemJournalLine: Record "Item Journal Line"; var ValueEntryNo: Integer; var ItemLedgEntry: Record "Item Ledger Entry")
    var
        SecondQty: Decimal;
    begin
        if ItemJournalLine."DUoM Second Qty" = 0 then
            exit;
        // Apply the same sign as the ILE Quantity: negative for outbound transactions (e.g. sales).
        SecondQty := Abs(ItemJournalLine."DUoM Second Qty");
        if ItemLedgEntry.Quantity < 0 then
            SecondQty := -SecondQty;
        ValueEntry."DUoM Second Qty" := SecondQty;
    end;
}
