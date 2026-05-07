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
    /// Prepara los campos DUoM del Item Journal Line para el posting de compra.
    /// La cantidad DUoM final usa la cantidad real a registrar del IJL y mantiene signo positivo.
    /// </summary>
    procedure PrepareFromPurchaseLine(var ItemJnlLine: Record "Item Journal Line"; PurchaseLine: Record "Purchase Line")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        RatioToUse: Decimal;
        PostingAbsQty: Decimal;
        SourceAbsQty: Decimal;
        RoundingPrecision: Decimal;
        SecondQtyAbs: Decimal;
    begin
        if PurchaseLine.Type <> PurchaseLine.Type::Item then
            exit;
        if PurchaseLine."No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(PurchaseLine."No.", PurchaseLine."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        PostingAbsQty := Abs(ItemJnlLine.Quantity);
        SourceAbsQty := Abs(PurchaseLine.Quantity);
        RoundingPrecision := DUoMUoMHelper.GetRoundingPrecisionByUoMCode(PurchaseLine."No.", SecondUoMCode);
        RatioToUse := ResolveRatioFromPurchaseLine(PurchaseLine, ConversionMode, FixedRatio);
        if RatioToUse <> 0 then
            ItemJnlLine."DUoM Ratio" := RatioToUse;

        SecondQtyAbs := CalcSecondQtyForPosting(
            PostingAbsQty,
            SourceAbsQty,
            Abs(PurchaseLine."DUoM Second Qty"),
            RatioToUse,
            ConversionMode,
            RoundingPrecision);
        ItemJnlLine."DUoM Second Qty" := SecondQtyAbs;
    end;

    /// <summary>
    /// Prepara los campos DUoM del Item Journal Line para el posting de venta.
    /// La cantidad DUoM final usa la cantidad real a registrar del IJL y mantiene signo negativo.
    /// </summary>
    procedure PrepareFromSalesLine(var ItemJnlLine: Record "Item Journal Line"; SalesLine: Record "Sales Line")
    var
        DUoMSetupResolver: Codeunit "DUoM Setup Resolver";
        DUoMUoMHelper: Codeunit "DUoM UoM Helper";
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal;
        RatioToUse: Decimal;
        PostingAbsQty: Decimal;
        SourceAbsQty: Decimal;
        RoundingPrecision: Decimal;
        SecondQtyAbs: Decimal;
    begin
        if SalesLine.Type <> SalesLine.Type::Item then
            exit;
        if SalesLine."No." = '' then
            exit;
        if not DUoMSetupResolver.GetEffectiveSetup(SalesLine."No.", SalesLine."Variant Code", SecondUoMCode, ConversionMode, FixedRatio) then
            exit;

        PostingAbsQty := Abs(ItemJnlLine.Quantity);
        SourceAbsQty := Abs(SalesLine.Quantity);
        RoundingPrecision := DUoMUoMHelper.GetRoundingPrecisionByUoMCode(SalesLine."No.", SecondUoMCode);
        RatioToUse := ResolveRatioFromSalesLine(SalesLine, ConversionMode, FixedRatio);
        if RatioToUse <> 0 then
            ItemJnlLine."DUoM Ratio" := RatioToUse;

        SecondQtyAbs := CalcSecondQtyForPosting(
            PostingAbsQty,
            SourceAbsQty,
            Abs(SalesLine."DUoM Second Qty"),
            RatioToUse,
            ConversionMode,
            RoundingPrecision);
        ItemJnlLine."DUoM Second Qty" := -SecondQtyAbs;
    end;

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

    local procedure ResolveRatioFromPurchaseLine(PurchaseLine: Record "Purchase Line"; ConversionMode: Enum "DUoM Conversion Mode"; FixedRatio: Decimal): Decimal
    begin
        if ConversionMode = ConversionMode::Fixed then
            exit(FixedRatio);
        if PurchaseLine."DUoM Ratio" <> 0 then
            exit(PurchaseLine."DUoM Ratio");
        exit(FixedRatio);
    end;

    local procedure ResolveRatioFromSalesLine(SalesLine: Record "Sales Line"; ConversionMode: Enum "DUoM Conversion Mode"; FixedRatio: Decimal): Decimal
    begin
        if ConversionMode = ConversionMode::Fixed then
            exit(FixedRatio);
        if SalesLine."DUoM Ratio" <> 0 then
            exit(SalesLine."DUoM Ratio");
        exit(FixedRatio);
    end;

    local procedure CalcSecondQtyForPosting(
        PostingQty: Decimal;
        SourceQty: Decimal;
        SourceSecondQty: Decimal;
        RatioToUse: Decimal;
        ConversionMode: Enum "DUoM Conversion Mode";
        RoundingPrecision: Decimal): Decimal
    var
        DUoMCalcEngine: Codeunit "DUoM Calc Engine";
    begin
        if PostingQty = 0 then
            exit(0);
        if SourceSecondQty <> 0 then
            exit(CalcProportionalSecondQty(SourceQty, SourceSecondQty, PostingQty));
        if ConversionMode = ConversionMode::AlwaysVariable then
            exit(0);
        if RatioToUse = 0 then
            exit(0);
        exit(DUoMCalcEngine.ComputeSecondQtyRounded(PostingQty, RatioToUse, ConversionMode, RoundingPrecision));
    end;

    local procedure CalcProportionalSecondQty(SourceQty: Decimal; SourceSecondQty: Decimal; PostingQty: Decimal): Decimal
    begin
        if SourceSecondQty = 0 then
            exit(0);
        if SourceQty = 0 then
            exit(0);
        exit(Abs(SourceSecondQty) * Abs(PostingQty) / Abs(SourceQty));
    end;
}
