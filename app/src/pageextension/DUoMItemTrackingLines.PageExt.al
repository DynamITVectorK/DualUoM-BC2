/// <summary>
/// Extends the Item Tracking Lines page (6510) to display Dual Unit of Measure fields
/// (DUoM Ratio and DUoM Second Qty) on each tracking line (Tracking Specification buffer).
/// DUoM Ratio is auto-filled when a Lot No. is validated:
///   - Variable/AlwaysVariable: uses the DUoM Lot Ratio registered for the lot if available.
///   - Fixed: always uses the item/variant Fixed Ratio.
/// DUoM Second Qty is recalculated automatically when DUoM Ratio or Quantity (Base) changes.
/// Both fields are editable so the user can review and override values per lot assignment.
/// For items without DUoM enabled the columns are shown empty (no conditional hide).
///
/// DUoM Second Qty.OnValidate (Variable/AlwaysVariable modes):
///   Calls NormalizeTrackingDUoMSecondQty BEFORE ValidateTrackingSpecLine so that when
///   the user enters real pieces during reception, DUoM Ratio is recalculated from the
///   actual measurement rather than blocking with a coherence error. Fixed mode keeps
///   strict validation (ratio unchanged, coherence error if secondary qty is inconsistent).
///
/// OnValidate handlers on both DUoM fields delegate to DUoM Tracking Coherence Mgt (50111)
/// for immediate UI feedback on ratio coherence and mode-specific rules. The server-side
/// validation guard (pre-posting) is in DUoM Purchase Subscribers (50102).
///
/// OnQueryClosePage (OK/LookupOK):
///   1. Calls ValidateTrackingSpecBufferEachLine to validate per-lot DUoM ratio coherence
///      for every functional tracking line BEFORE any data is persisted. Empty/insertion
///      lines are skipped. This is the first (early) barrier against inconsistent ratios.
///   2. Calls SyncPurchLineFromTrackingBuffer to update the source Purchase Line with the
///      aggregate DUoM totals from tracking. The Purchase Line is the aggregate summary;
///      each tracking line (lot) retains its own per-lot ratio.
///   3. Calls ValidateTrackingSpecBufferForPurchLine as sanity check after sync.
///   The pre-posting validation in DUoM Purchase Subscribers (50102) remains as a second
///   safety barrier for data that may arrive by other means (e.g., direct code insertion).
/// </summary>
pageextension 50112 "DUoM Item Tracking Lines" extends "Item Tracking Lines"
{
    layout
    {
        modify("Quantity (Base)")
        {
            trigger OnAfterValidate()
            var
                DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
            begin
                DUoMCoherenceMgt.NormalizeTrackingQuantityBase(Rec);
                DUoMCoherenceMgt.ValidateTrackingSpecLine(Rec);
                CurrPage.Update(false);
            end;
        }
        addafter("Quantity (Base)")
        {
            field("DUoM Ratio"; Rec."DUoM Ratio")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the conversion ratio for this lot tracking line. Filled automatically from the registered DUoM Lot Ratio (Variable mode) or the item Fixed Ratio (Fixed mode). Can be overridden manually.', Comment = 'ToolTip for DUoM Ratio field on Item Tracking Lines; no placeholders.';

                trigger OnValidate()
                var
                    DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
                begin
                    DUoMCoherenceMgt.ValidateTrackingSpecLine(Rec);
                end;
            }
            field("DUoM Second Qty"; Rec."DUoM Second Qty")
            {
                ApplicationArea = All;
                CaptionClass = DUoMSecondQtyCaption;
                ToolTip = 'Specifies the secondary quantity for this lot tracking line in the second unit of measure. In Variable and AlwaysVariable modes, editing this field recalculates DUoM Ratio automatically.', Comment = 'ToolTip for DUoM Second Qty field on Item Tracking Lines; no placeholders.';

                trigger OnValidate()
                var
                    DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
                begin
                    // In Variable/AlwaysVariable modes: recalculate DUoM Ratio from the entered
                    // secondary qty before validating coherence. This allows users to inform real
                    // pieces during reception without knowing the ratio in advance.
                    DUoMCoherenceMgt.NormalizeTrackingDUoMSecondQty(Rec);
                    DUoMCoherenceMgt.ValidateTrackingSpecLine(Rec);
                end;
            }
        }
    }



    actions
    {
        addlast(processing)
        {
            action(Cancel)
            {
                ApplicationArea = All;
                Caption = 'Cancel';
                Image = Cancel;

                trigger OnAction()
                begin
                    CurrPage.Close();
                end;
            }
        }
    }
    trigger OnAfterGetRecord()
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        DUoMSecondQtyCaption := '3,' + DUoMSecondQtyDefaultLbl;
        if Rec."Item No." <> '' then
            if DUoMItemSetup.Get(Rec."Item No.") then
                if DUoMItemSetup."Dual UoM Enabled" then
                    if DUoMItemSetup."Second UoM Code" <> '' then
                        DUoMSecondQtyCaption := '3,' + DUoMItemSetup."Second UoM Code";
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        DUoMTrackingPropMgt: Codeunit "DUoM Tracking Prop. Mgt";
    begin
        // Only validate on acceptance (OK / LookupOK). Cancel and other close
        // actions must never be blocked by DUoM aggregate validation.
        if not (CloseAction in [Action::OK, Action::LookupOK]) then
            exit(true);
        DUoMTrackingPropMgt.ValidateTrackingBeforeClose(Rec);
        exit(true);
    end;

    var
        DUoMSecondQtyCaption: Text[30];
        DUoMSecondQtyDefaultLbl: Label 'DUoM Second Qty', Comment = 'Default column caption for DUoM Second Qty when no second unit of measure code is available; no placeholders.';
}
