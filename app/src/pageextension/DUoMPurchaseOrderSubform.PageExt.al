/// <summary>
/// Extends the Purchase Order Subform page to display the Dual Unit of Measure fields
/// (DUoM Second Qty, DUoM Ratio and DUoM Unit Cost) on each purchase line.
/// DUoM Second Qty is read-only in Fixed and Variable modes (computed automatically by the
/// subscriber on Quantity validation); it becomes editable only in AlwaysVariable mode,
/// where the user must enter the secondary quantity manually.
/// DUoM Ratio is always editable to allow per-line override in Variable mode.
/// DUoM Unit Cost is always editable; entering it derives Direct Unit Cost automatically.
/// </summary>
pageextension 50101 "DUoM Purchase Order Subform" extends "Purchase Order Subform"
{
    layout
    {
        addafter(Quantity)
        {
            field("DUoM Second Qty"; Rec."DUoM Second Qty")
            {
                ApplicationArea = All;
                CaptionClass = DUoMSecondQtyCaption;
                Editable = IsDUoMSecondQtyEditable;
                ToolTip = 'Specifies the expected document-level secondary quantity for this purchase line in the second unit of measure. Computed automatically in Fixed and Variable modes; enter manually in Always Variable mode. The real per-lot operational total is shown in DUoM Tracking Total.', Comment = 'ToolTip for DUoM Second Qty field on Purchase Order Subform; no placeholders.';
            }
            field("DUoM Tracking Total"; DUoMTrackingSecondQtyTotal)
            {
                ApplicationArea = All;
                Caption = 'DUoM Tracking Total';
                Editable = false;
                ToolTip = 'Specifies the real operational DUoM total aggregated from Reservation Entry for this purchase line. This value is calculated on demand from lot tracking data and is not persisted on the purchase line.', Comment = 'ToolTip for DUoM Tracking Total field on Purchase Order Subform; no placeholders.';
            }
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the conversion ratio for this purchase line. Overrides the item default when the item uses Variable conversion mode.', Comment = 'ToolTip for DUoM Ratio field on Purchase Order Subform; no placeholders.';
            }
            field("DUoM Unit Cost"; Rec."DUoM Unit Cost")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the unit cost in the second unit of measure. Derives Direct Unit Cost automatically when the ratio is available.', Comment = 'ToolTip for DUoM Unit Cost field on Purchase Order Subform; no placeholders.';
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        UpdateDUoMLinePresentation();
        CalcDUoMTrackingTotal();
    end;

    local procedure UpdateDUoMLinePresentation()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        IsDUoMSecondQtyEditable := false;
        DUoMSecondQtyCaption := '3,' + DUoMSecondQtyDefaultLbl;
        if Rec.Type <> Rec.Type::Item then
            exit;
        if Rec."No." = '' then
            exit;
        if not DUoMItemSetup.Get(Rec."No.") then
            exit;
        if not DUoMItemSetup."Dual UoM Enabled" then
            exit;

        IsDUoMSecondQtyEditable :=
            DUoMItemSetup."Conversion Mode" = DUoMItemSetup."Conversion Mode"::AlwaysVariable;
        if DUoMItemSetup."Second UoM Code" = '' then
            exit;
        DUoMSecondQtyCaption := '3,' + DUoMItemSetup."Second UoM Code";
    end;

    local procedure CalcDUoMTrackingTotal()
    var
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
        TotalBaseQty: Decimal;
    begin
        DUoMTrackingSecondQtyTotal := 0;
        if Rec.Type <> Rec.Type::Item then
            exit;
        if Rec."No." = '' then
            exit;

        // TotalBaseQty se ignora en UI: este campo solo muestra el total DUoM agregado.
        DUoMCoherenceMgt.CalcTrackingDUoMTotalsForPurchLine(
            Rec, DUoMTrackingSecondQtyTotal, TotalBaseQty);
    end;

    var
        IsDUoMSecondQtyEditable: Boolean;
        DUoMTrackingSecondQtyTotal: Decimal;
        DUoMSecondQtyCaption: Text[30];
        DUoMSecondQtyDefaultLbl: Label 'DUoM Second Qty', Comment = 'Default column caption for DUoM Second Qty when no second unit of measure code is available; no placeholders.';
}
