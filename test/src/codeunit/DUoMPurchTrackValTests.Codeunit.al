/// <summary>
/// Tests TDD para la validación de campos DUoM en Item Tracking Lines (6510)
/// a nivel de campo individual (OnValidate → ValidateTrackingSpecLine).
///
/// Escenarios cubiertos:
///   T-FVAL-01: Modo Fixed — usuario sobreescribe DUoM Ratio incorrecto → error inmediato
///              Verifica que el trigger OnValidate del campo DUoM Ratio en la pageextension
///              bloquea el valor antes de que el usuario pueda cerrar con OK.
///
///   T-FVAL-02: Modo AlwaysVariable — usuario introduce DUoM Second Qty sin DUoM Ratio → error
///              Verifica que introducir DUoM Second Qty cuando DUoM Ratio = 0 en modo
///              AlwaysVariable produce AlwaysVariableMissingRatioErr al validar el campo.
///
///   T-FVAL-03: Modo Variable — usuario sobreescribe DUoM Second Qty incoherente → error
///              Verifica que un DUoM Second Qty que no coincide con Qty (Base) × DUoM Ratio
///              produce RatioIncoherenceErr al validar el campo DUoM Second Qty.
///
///   T-FVAL-04: PurchLine.DUoM Second Qty = 0 → validación agregada omitida → OK sin error
///              Verifica la rama `if PurchLine."DUoM Second Qty" <= 0 then exit` en
///              ValidateTrackingSpecBufferForPurchLine: cuando la Purchase Line no tiene
///              DUoM Second Qty objetivo, el cierre con OK siempre se permite.
///
/// Diseño de la validación de campo:
///   DUoM Ratio.OnValidate (pageextension 50112)
///     → ValidateTrackingSpecLine (DUoM Tracking Coherence Mgt, 50111)
///       → Fixed: ratio ≠ ratio fijo → FixedRatioMismatchErr
///   DUoM Second Qty.OnValidate (pageextension 50112)
///     → ValidateTrackingSpecLine (DUoM Tracking Coherence Mgt, 50111)
///       → AlwaysVariable + Ratio = 0 + Qty > 0 → AlwaysVariableMissingRatioErr
///       → Variable + |Qty × Ratio − SecondQty| > tolerancia → RatioIncoherenceErr
///
/// Complementa los tests de validación agregada en DUoM Purch Track Close Tests (50222)
/// y los tests unitarios directos de ValidateTrackingSpecLine en
/// DUoM Tracking Coherence Tests (50220, T05 y T07).
/// </summary>
codeunit 50223 "DUoM Purch Track Val Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T-FVAL-01 — Modo Fixed: DUoM Ratio incorrecto bloqueado a nivel de campo
    //
    // El subscriber OnAfterValidateTrackingSpecLotNo auto-asigna DUoM Ratio = 0.8
    // (ratio fijo del artículo) al validar el Lot No. Cuando el usuario sobreescribe
    // ese valor con 0.9, el trigger OnValidate del campo DUoM Ratio en la pageextension
    // llama a ValidateTrackingSpecLine → FixedRatioMismatchErr.
    //
    // Artículo: DUoM Fixed, ratio fijo = 0.8, seguimiento por lote.
    // Purchase Line: Qty = 5.
    // Tracking: Lot No. = 'LOT-FIX01', Qty (Base) = 5.
    // Acción: SetValue("DUoM Ratio", 0.9) → error (0.9 ≠ 0.8).
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_FieldVal_MPH')]
    procedure ValidateDUoMRatio_Fixed_WrongRatio_Blocked()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Fixed (ratio fijo = 0.8) y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Fixed, 0.8);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 5 (sin DUoM Second Qty explícito)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Modify(true);

        // [WHEN] El usuario abre Item Tracking Lines y sobreescribe DUoM Ratio con valor
        //        incorrecto (HandlerStep = 1: Lot No. → auto-ratio 0.8 → sobreescribe a 0.9)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 1;
        PurchaseOrder.PurchLines.First();

        // [THEN] Error inmediato al validar DUoM Ratio = 0.9 (≠ ratio fijo 0.8)
        asserterror PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        LibraryAssert.ExpectedError('differs from the fixed ratio');
        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-FVAL-02 — Modo AlwaysVariable: DUoM Second Qty sin DUoM Ratio bloqueado
    //
    // En modo AlwaysVariable, el ratio no se auto-asigna cuando no hay ratio de lote
    // registrado ni DUoM Ratio en la Purchase Line. Al intentar introducir DUoM Second Qty
    // con DUoM Ratio = 0, el trigger OnValidate de DUoM Second Qty llama a
    // ValidateTrackingSpecLine → AlwaysVariableMissingRatioErr.
    //
    // Artículo: DUoM AlwaysVariable, seguimiento por lote.
    // Purchase Line: Qty = 10, sin DUoM Ratio (= 0).
    // Tracking: Lot No. = 'LOT-AV01', Qty (Base) = 10, DUoM Ratio = 0 (default).
    // Acción: SetValue("DUoM Second Qty", 8) → error (ratio = 0, qty = 10).
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_FieldVal_MPH')]
    procedure ValidateDUoMSecondQty_AlwaysVar_ZeroRatio_Blocked()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM AlwaysVariable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::AlwaysVariable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 10, sin DUoM Ratio (= 0) → sin fallback disponible
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 10);
        PurchLine.Modify(true);

        // [WHEN] El usuario abre Item Tracking Lines, asigna lote y cantidad,
        //        pero introduce DUoM Second Qty sin haber definido DUoM Ratio
        //        (HandlerStep = 2: Lot No. → Qty = 10 → DUoM Second Qty = 8 con Ratio = 0)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 2;
        PurchaseOrder.PurchLines.First();

        // [THEN] Error al validar DUoM Second Qty: AlwaysVariable exige ratio válido
        asserterror PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        LibraryAssert.ExpectedError('requires a variable DUoM ratio per lot');
        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-FVAL-03 — Modo Variable: DUoM Second Qty incoherente con DUoM Ratio bloqueado
    //
    // En modo Variable, al asignar el lote el fallback de Purchase Line establece
    // DUoM Ratio = 2. DUoM Second Qty se auto-calcula = 5 × 2 = 10. Cuando el usuario
    // sobreescribe manualmente DUoM Second Qty = 3 (incoherente), el trigger OnValidate
    // llama a ValidateTrackingSpecLine → AssertRatioCoherence → RatioIncoherenceErr.
    //
    // Artículo: DUoM Variable, seguimiento por lote.
    // Purchase Line: Qty = 5, DUoM Ratio = 2 → DUoM Second Qty = 10.
    // Tracking: Lot No. = 'LOT-VAR01', Qty (Base) = 5, DUoM Ratio = 2 (fallback).
    // Acción: SetValue("DUoM Second Qty", 3) → error (|5×2 − 3| = 7 >> tolerancia).
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_FieldVal_MPH')]
    procedure ValidateDUoMSecondQty_Variable_Incoherent_Blocked()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 5, DUoM Ratio = 2 → DUoM Second Qty = 10
        //         (el subscriber usará este ratio como fallback para el lote sin ratio registrado)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Validate("DUoM Ratio", 2);   // DUoM Second Qty = 5 × 2 = 10
        PurchLine.Modify(true);

        // [WHEN] El usuario abre Item Tracking Lines, asigna lote con ratio 2 (fallback),
        //        DUoM Second Qty se auto-calcula a 10, y luego sobreescribe manualmente
        //        DUoM Second Qty = 3 (incoherente con Qty=5 × Ratio=2 = 10)
        //        (HandlerStep = 3)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 3;
        PurchaseOrder.PurchLines.First();

        // [THEN] Error al validar DUoM Second Qty: incoherencia matemática detectada
        asserterror PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        LibraryAssert.ExpectedError('has an inconsistent DUoM ratio');
        PurchaseOrder.Close();
    end;

    // -------------------------------------------------------------------------
    // T-FVAL-04 — PurchLine.DUoM Second Qty = 0: validación agregada omitida en cierre
    //
    // Verifica la rama `if PurchLine."DUoM Second Qty" <= 0 then exit` en
    // ValidateTrackingSpecBufferForPurchLine (50111).
    // Cuando la Purchase Line no tiene DUoM Second Qty objetivo (= 0), el cierre
    // con OK se permite independientemente de los valores DUoM en las líneas de tracking.
    //
    // Artículo: DUoM Variable, seguimiento por lote.
    // Purchase Line: Qty = 5, sin DUoM Ratio → DUoM Second Qty = 0.
    // Tracking: Lot No. = 'LOT-NOCHK01', Qty (Base) = 5, DUoM Ratio = 1.5 (manual).
    //           DUoM Second Qty = 7.5 (auto-calculado).
    // Resultado: OK sin error (agregado omitido porque PurchLine.DUoM Second Qty = 0).
    // -------------------------------------------------------------------------
    [Test]
    [HandlerFunctions('ItemTrackingLines_FieldVal_MPH')]
    procedure CloseOK_PurchLineSecondQtyZero_AggregateCheckSkipped()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        PurchaseOrder: TestPage "Purchase Order";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 5, sin DUoM Ratio → DUoM Second Qty = 0
        //         (no hay objetivo DUoM en la Purchase Line)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 5);
        PurchLine.Modify(true);

        // [WHEN] El usuario abre Item Tracking Lines, asigna lote con DUoM Ratio manual
        //        y cierra con OK (HandlerStep = 4)
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchHeader);
        HandlerStep := 4;
        PurchaseOrder.PurchLines.First();
        PurchaseOrder.PurchLines."Item Tracking Lines".Invoke();
        PurchaseOrder.Close();

        // [THEN] La página se cierra sin error (validación agregada omitida)
        // [THEN] La Reservation Entry tiene DUoM Ratio = 1.5 (valor introducido manualmente)
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source ID", PurchHeader."No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetRange(Positive, true);
        LibraryAssert.IsTrue(ReservEntry.FindFirst(),
            'T-FVAL-04: Debe existir una Reservation Entry tras cerrar Item Tracking Lines.');
        LibraryAssert.AreNearlyEqual(
            1.5, ReservEntry."DUoM Ratio", 0.001,
            'T-FVAL-04: DUoM Ratio debe ser 1.5 (introducido manualmente en tracking).');
        LibraryAssert.AreNearlyEqual(
            7.5, ReservEntry."DUoM Second Qty", 0.001,
            'T-FVAL-04: DUoM Second Qty debe ser 5 × 1.5 = 7.5 (auto-calculado en Variable mode).');
    end;

    /// <summary>
    /// ModalPageHandler para Item Tracking Lines — utilizado por los tests T-FVAL-01..04.
    ///
    ///   HandlerStep = 1 (T-FVAL-01):
    ///     Artículo Fixed (ratio = 0.8). Introduce lote LOT-FIX01 y Qty = 5.
    ///     El subscriber auto-asigna DUoM Ratio = 0.8 al validar el lote.
    ///     Sobreescribe DUoM Ratio = 0.9 (incorrecto) → FixedRatioMismatchErr.
    ///
    ///   HandlerStep = 2 (T-FVAL-02):
    ///     Artículo AlwaysVariable. Introduce lote LOT-AV01 y Qty = 10.
    ///     DUoM Ratio permanece en 0 (sin ratio de lote, PurchLine sin DUoM Ratio).
    ///     Introduce DUoM Second Qty = 8 con Ratio = 0 → AlwaysVariableMissingRatioErr.
    ///
    ///   HandlerStep = 3 (T-FVAL-03):
    ///     Artículo Variable. Introduce lote LOT-VAR01 y Qty = 5.
    ///     El fallback de PurchLine establece DUoM Ratio = 2.
    ///     OnValidate de Quantity (Base) auto-calcula DUoM Second Qty = 10.
    ///     Sobreescribe DUoM Second Qty = 3 (incoherente) → RatioIncoherenceErr.
    ///
    ///   HandlerStep = 4 (T-FVAL-04):
    ///     Artículo Variable. PurchLine sin DUoM Ratio (= 0).
    ///     Introduce lote LOT-NOCHK01 y Qty = 5.
    ///     Introduce DUoM Ratio = 1.5 manualmente → DUoM Second Qty = 7.5 (auto-calculado).
    ///     OK sin error: PurchLine.DUoM Second Qty = 0 → validación agregada omitida.
    ///
    /// Nota: en los steps 1, 2 y 3, la excepción se propaga desde SetValue antes
    /// de llegar a OK().Invoke(), de modo que el handler termina con error.
    /// </summary>
    [ModalPageHandler]
    procedure ItemTrackingLines_FieldVal_MPH(
        var ItemTrackingLines: TestPage "Item Tracking Lines")
    begin
        case HandlerStep of
            1:
                begin
                    // T-FVAL-01: Fixed mode — ratio incorrecto → error en SetValue("DUoM Ratio", 0.9)
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-FIX01');
                    // El subscriber auto-asigna DUoM Ratio = 0.8 (ratio fijo del artículo)
                    ItemTrackingLines."Quantity (Base)".SetValue(5);
                    // Sobreescribir con valor incorrecto → FixedRatioMismatchErr
                    ItemTrackingLines."DUoM Ratio".SetValue(0.9);
                end;
            2:
                begin
                    // T-FVAL-02: AlwaysVariable — DUoM Second Qty sin ratio → error en SetValue
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-AV01');
                    // Sin ratio de lote y PurchLine.DUoM Ratio = 0 → DUoM Ratio queda en 0
                    ItemTrackingLines."Quantity (Base)".SetValue(10);
                    // Intentar introducir DUoM Second Qty con Ratio = 0 → AlwaysVariableMissingRatioErr
                    ItemTrackingLines."DUoM Second Qty".SetValue(8);
                end;
            3:
                begin
                    // T-FVAL-03: Variable — DUoM Second Qty incoherente → error en SetValue
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-VAR01');
                    // Fallback desde PurchLine: DUoM Ratio = 2
                    ItemTrackingLines."Quantity (Base)".SetValue(5);
                    // DUoM Second Qty auto-calculada = 5 × 2 = 10
                    // Sobreescribir con valor incoherente → RatioIncoherenceErr (|5×2-3|=7)
                    ItemTrackingLines."DUoM Second Qty".SetValue(3);
                end;
            4:
                begin
                    // T-FVAL-04: PurchLine.DUoM Second Qty = 0 → cierre OK sin validación agregada
                    ItemTrackingLines.New();
                    ItemTrackingLines."Lot No.".SetValue('LOT-NOCHK01');
                    // Sin ratio de lote y PurchLine.DUoM Ratio = 0 → DUoM Ratio = 0
                    ItemTrackingLines."Quantity (Base)".SetValue(5);
                    // Introducir DUoM Ratio manual = 1.5 → DUoM Second Qty = 5 × 1.5 = 7.5
                    ItemTrackingLines."DUoM Ratio".SetValue(1.5);
                    // ValidateTrackingSpecLine: Ratio=1.5, Qty=5, SecondQty=7.5 → coherente ✓
                    // OnQueryClosePage: PurchLine.DUoM Second Qty = 0 → exit → sin error
                    ItemTrackingLines.OK().Invoke();
                end;
        end;
    end;

    var
        HandlerStep: Integer;
}
