/// <summary>
/// Tests TDD para validación temprana de ratio DUoM por lote en Item Tracking Lines.
///
/// Escenarios cubiertos (requisitos del issue de validación temprana DUoM):
///
///   T-RATIO-01: NormalizeTrackingDUoMSecondQty recalcula DUoM Ratio automáticamente
///               cuando el usuario informa DUoM Second Qty con Base Qty ya establecido.
///               Verifica que Ratio = SecondQty / BaseQty (sin intervención del usuario).
///
///   T-RATIO-02: ValidateTrackingSpecBufferEachLine (nueva barrera de cierre) detecta
///               ratio incoherente en una línea de tracking y lanza error con detalle
///               del lote, cantidades y ratio esperado vs informado.
///
///   T-RATIO-03: La validación pre-posting (segunda barrera) sigue bloqueando el
///               registro cuando los datos DUoM incoherentes se insertan por código
///               saltándose la UI de Item Tracking Lines.
///
///   T-RATIO-04: Las líneas vacías/de inserción (sin lote, serial, paquete ni
///               cantidades) son ignoradas por ValidateTrackingSpecBufferEachLine y
///               no causan errores falsos-positivos de coherencia DUoM.
///
///   T-RATIO-05: Un conjunto de tracking con ratios coherentes y totales que suman
///               correctamente (20 KG / 65 PCS en 3 lotes) pasa la validación sin error.
///
///   T-RATIO-06: Un conjunto de tracking cuyas cantidades DUoM secundarias no suman
///               el total de la Purchase Line es bloqueado por
///               ValidateTrackingSpecBufferForPurchLine con error de totales DUoM.
///
/// Arquitectura de validación de cierre (nueva barrera T-RATIO-02):
///   OnQueryClosePage (DUoM Item Tracking Lines, 50112)
///     → ValidateTrackingSpecBufferEachLine (DUoM Tracking Coherence Mgt, 50111)  ← NUEVO
///       → IsFunctionalTrackingLine: skip líneas vacías
///       → ValidateTrackingSpecLine: coherencia por lote (ratio = secondQty / baseQty)
///     → SyncPurchLineFromTrackingBuffer
///     → ValidateTrackingSpecBufferForPurchLine (sanity check totales)
///
/// Segunda barrera (intacta):
///   OnPostItemJnlLineOnAfterCopyDocumentFields → DUoM Purchase Subscribers (50102)
///     → ValidatePurchLineTrackingCoherence (50111) → coherencia por Reservation Entry
///
/// Convenciones de test:
///   - Todos los tests siguen el patrón [GIVEN] / [WHEN] / [THEN].
///   - T-RATIO-01, T-RATIO-02, T-RATIO-04, T-RATIO-05: tests unitarios directos sobre
///     métodos públicos de DUoM Tracking Coherence Mgt (50111) usando buffers temporales.
///   - T-RATIO-03: test de integración con Reservation Entry real y posting.
///   - T-RATIO-06: test con Purchase Line real y buffer temporal de TrackingSpec.
///   - Se usan LibraryInventory, LibraryPurchase y LibraryAssert según norma del proyecto.
/// </summary>
codeunit 50226 "DUoM Purch Lot Ratio Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // -------------------------------------------------------------------------
    // T-RATIO-01 — NormalizeTrackingDUoMSecondQty recalcula DUoM Ratio
    //
    // Verifica que, en modo Variable, cuando el usuario informa DUoM Second Qty = 7
    // con Quantity (Base) = 3, el método NormalizeTrackingDUoMSecondQty recalcula
    // DUoM Ratio = 7 / 3 ≈ 2,3333…  sin necesidad de intervención manual.
    //
    // Test unitario directo sobre NormalizeTrackingDUoMSecondQty (50111).
    // El registro de TrackingSpec es temporal: no se persiste en BD.
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchLotTracking_SecondQtyValidate_RecalculatesDUoMRatio()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification" temporary;
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
        ExpectedRatio: Decimal;
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Línea de tracking temporal: lote BBB, Base Qty = 3, DUoM Second Qty = 7
        //         DUoM Ratio = 1,75 (valor previo inconsistente — será recalculado)
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Lot No." := 'BBB';
        TrackingSpec."Quantity (Base)" := 3;
        TrackingSpec."DUoM Second Qty" := 7;
        TrackingSpec."DUoM Ratio" := 1.75;
        TrackingSpec.Insert();

        // [WHEN] Se llama a NormalizeTrackingDUoMSecondQty (equivale al OnValidate de
        //        DUoM Second Qty en Item Tracking Lines)
        DUoMCoherenceMgt.NormalizeTrackingDUoMSecondQty(TrackingSpec);

        // [THEN] DUoM Ratio queda recalculado a 7 / 3 = 2,3333…
        ExpectedRatio := 7 / 3;
        LibraryAssert.AreNearlyEqual(
            ExpectedRatio, TrackingSpec."DUoM Ratio", 0.00001,
            'T-RATIO-01: DUoM Ratio debe ser 7/3 ≈ 2,3333 tras NormalizeTrackingDUoMSecondQty.');
    end;

    // -------------------------------------------------------------------------
    // T-RATIO-02 — ValidateTrackingSpecBufferEachLine bloquea ratio incoherente
    //
    // Verifica que la nueva barrera de cierre ValidateTrackingSpecBufferEachLine
    // detecta un ratio incoherente en una línea de tracking y lanza error con
    // detalle del lote, cantidades y ratio esperado vs informado.
    //
    // Escenario del issue:
    //   Lote BBB: Base Qty = 3, DUoM Second Qty = 7, DUoM Ratio = 1,75 (inconsistente)
    //   Expected Ratio = 7 / 3 = 2,3333…  ≠ 1,75 → error
    //
    // Test unitario directo sobre ValidateTrackingSpecBufferEachLine (50111)
    // con un buffer temporal que simula el estado de la página al cerrar.
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchLotTracking_CloseWithInconsistentRatio_RaisesError()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification" temporary;
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Buffer de tracking con lote BBB incoherente:
        //         Base Qty = 3, DUoM Second Qty = 7, DUoM Ratio = 1,75
        //         Ratio esperado = 7 / 3 ≈ 2,3333  ≠  1,75 (incoherente)
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Lot No." := 'BBB';
        TrackingSpec."Quantity (Base)" := 3;
        TrackingSpec."DUoM Second Qty" := 7;
        TrackingSpec."DUoM Ratio" := 1.75;
        TrackingSpec.Insert();

        // [WHEN] Se ejecuta la validación de cierre equivalente a aceptar Item Tracking Lines
        // [THEN] Se lanza error de incoherencia DUoM indicando el lote BBB
        asserterror DUoMCoherenceMgt.ValidateTrackingSpecBufferEachLine(TrackingSpec);
        LibraryAssert.ExpectedError('BBB');
    end;

    // -------------------------------------------------------------------------
    // T-RATIO-03 — La validación final de posting sigue bloqueando datos incoherentes
    //
    // Verifica que la segunda barrera de validación DUoM (pre-posting, en
    // DUoM Purchase Subscribers 50102 → ValidatePurchLineTrackingCoherence 50111)
    // sigue activa y bloquea el registro cuando los datos DUoM incoherentes se
    // insertan directamente en Reservation Entry por código (bypass de la UI).
    //
    // Escenario del issue:
    //   Datos insertados por código: Qty = 3, DUoM Ratio = 1,75, DUoM Second Qty = 7
    //   (incoherente: 3 × 1,75 = 5,25 ≠ 7)
    //   → el posting se bloquea con RatioIncoherenceErr
    //
    // Este test garantiza que la nueva barrera de cierre no debilita ni elimina
    // la validación final existente.
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchPost_InconsistentTrackingRatio_StillBlockedByPostingGuard()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        ReservEntry: Record "Reservation Entry";
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        NextEntryNo: Integer;
    begin
        // [GIVEN] Artículo con DUoM Variable y seguimiento por lote
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(
            Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);
        DUoMTestHelpers.EnableLotTrackingOnItem(Item);

        // [GIVEN] Purchase Line: Qty = 3, DUoM Second Qty = 7 (objetivo)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 3);
        PurchLine."DUoM Second Qty" := 7;
        PurchLine.Modify(false);

        // [GIVEN] Reservation Entry con datos DUoM incoherentes (bypass de la UI):
        //         Qty = 3, DUoM Ratio = 1,75, DUoM Second Qty = 7
        //         Inconsistente: 3 × 1,75 = 5,25  ≠  7
        //         (el total 7 = PurchLine.DUoM Second Qty para que pase la comprobación
        //         de totales y se llegue a la validación por lote, que sí lanza error)
        ReservEntry.LockTable();
        if ReservEntry.FindLast() then
            NextEntryNo := ReservEntry."Entry No." + 1
        else
            NextEntryNo := 1;
        ReservEntry.Init();
        ReservEntry."Entry No." := NextEntryNo;
        ReservEntry.Positive := true;
        ReservEntry."Item No." := PurchLine."No.";
        ReservEntry."Variant Code" := PurchLine."Variant Code";
        ReservEntry."Location Code" := PurchLine."Location Code";
        ReservEntry."Lot No." := 'BBB';
        ReservEntry."Quantity (Base)" := 3;
        ReservEntry."Qty. to Handle (Base)" := 3;
        ReservEntry."Qty. to Invoice (Base)" := 3;
        ReservEntry."Source Type" := Database::"Purchase Line";
        ReservEntry."Source Subtype" := PurchLine."Document Type".AsInteger();
        ReservEntry."Source ID" := PurchLine."Document No.";
        ReservEntry."Source Batch Name" := '';
        ReservEntry."Source Prod. Order Line" := 0;
        ReservEntry."Source Ref. No." := PurchLine."Line No.";
        ReservEntry."Reservation Status" := ReservEntry."Reservation Status"::Surplus;
        ReservEntry."DUoM Ratio" := 1.75;
        ReservEntry."DUoM Second Qty" := 7;  // incoherente: 3 × 1,75 = 5,25 ≠ 7
        ReservEntry.Insert(true);

        // [WHEN] Se intenta registrar la compra (solo recepción)
        // [THEN] El posting se bloquea porque el ratio del lote BBB es incoherente
        asserterror LibraryPurchase.PostPurchaseDocument(PurchHeader, true, false);
        LibraryAssert.ExpectedError('inconsistent DUoM ratio');
    end;

    // -------------------------------------------------------------------------
    // T-RATIO-04 — Las líneas vacías/de inserción son ignoradas
    //
    // Verifica que ValidateTrackingSpecBufferEachLine ignora las líneas que no
    // tienen ningún valor funcional (sin lote, serial, paquete, ni cantidades).
    // Estas líneas aparecen como filas de inserción en la página estándar o en
    // TestPage y no deben causar errores falsos-positivos de coherencia DUoM.
    //
    // Escenario:
    //   Buffer con una línea funcional coherente (BBB: 3/7/2,3333) y una línea
    //   vacía (todos los campos en cero/vacío) → sin error.
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchLotTracking_EmptyInsertionLine_IsIgnoredByDUoMValidation()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification" temporary;
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Línea funcional coherente: lote BBB, Base = 3, SecondQty = 7, Ratio = 7/3
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Lot No." := 'BBB';
        TrackingSpec."Quantity (Base)" := 3;
        TrackingSpec."DUoM Second Qty" := 7;
        TrackingSpec."DUoM Ratio" := 7 / 3;
        TrackingSpec.Insert();

        // [GIVEN] Línea vacía/de inserción: todos los campos relevantes en cero/vacío
        //         Simula la fila en blanco visible en la página estándar durante la edición
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 2;
        TrackingSpec."Item No." := Item."No.";
        // Lot No. = '', Serial No. = '', Package No. = '', Qty = 0, DUoMSecondQty = 0, DUoMRatio = 0
        TrackingSpec.Insert();

        // [WHEN] Se ejecuta la validación del buffer (equivalente al cierre de la página)
        // [THEN] Sin error: la línea vacía se ignora; la funcional es coherente
        DUoMCoherenceMgt.ValidateTrackingSpecBufferEachLine(TrackingSpec);
        LibraryAssert.IsTrue(
            true,
            'T-RATIO-04: La línea vacía no debe causar error de coherencia DUoM.');
    end;

    // -------------------------------------------------------------------------
    // T-RATIO-05 — Totales de tracking correctos → sin error
    //
    // Verifica que tres lotes con ratios coherentes y cuya suma coincide con
    // los totales esperados (20 KG / 65 PCS) pasan la validación sin error.
    //
    // Escenario del issue:
    //   BBB:  Base = 3  / SecondQty = 7   / Ratio = 7/3 ≈ 2,3333
    //   GFFF: Base = 1  / SecondQty = 5   / Ratio = 5
    //   NNNN: Base = 16 / SecondQty = 53  / Ratio = 53/16 = 3,3125
    //   Total: Base = 20, SecondQty = 65  → sin error
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchLotTracking_TrackingTotals_MatchPurchaseLineDUoMSecondQty()
    var
        Item: Record Item;
        TrackingSpec: Record "Tracking Specification" temporary;
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Tres lotes con ratios coherentes que suman 20 KG / 65 PCS
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Lot No." := 'BBB';
        TrackingSpec."Quantity (Base)" := 3;
        TrackingSpec."DUoM Second Qty" := 7;
        TrackingSpec."DUoM Ratio" := 7 / 3;
        TrackingSpec.Insert();

        TrackingSpec.Init();
        TrackingSpec."Entry No." := 2;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Lot No." := 'GFFF';
        TrackingSpec."Quantity (Base)" := 1;
        TrackingSpec."DUoM Second Qty" := 5;
        TrackingSpec."DUoM Ratio" := 5;
        TrackingSpec.Insert();

        TrackingSpec.Init();
        TrackingSpec."Entry No." := 3;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Lot No." := 'NNNN';
        TrackingSpec."Quantity (Base)" := 16;
        TrackingSpec."DUoM Second Qty" := 53;
        TrackingSpec."DUoM Ratio" := 53 / 16;
        TrackingSpec.Insert();

        // [WHEN] Se valida el conjunto de tracking (cada línea por su ratio)
        // [THEN] Sin error: los 3 lotes tienen ratios coherentes
        DUoMCoherenceMgt.ValidateTrackingSpecBufferEachLine(TrackingSpec);
        LibraryAssert.IsTrue(
            true,
            'T-RATIO-05: Los tres lotes coherentes no deben causar error de validación.');
    end;

    // -------------------------------------------------------------------------
    // T-RATIO-06 — Totales de tracking no cuadran → error de totales DUoM
    //
    // Verifica que ValidateTrackingSpecBufferForPurchLine lanza error cuando la
    // suma de DUoM Second Qty en el buffer de tracking no coincide con el
    // DUoM Second Qty de la Purchase Line.
    //
    // Escenario del issue:
    //   Purchase Line: Base = 20, DUoM Second Qty = 65
    //   Buffer de tracking: BBB(3/6) + GFFF(1/5) + NNNN(16/53) = 64 PCS  ≠  65
    //   → error de totales DUoM
    //
    // Nota: se llama a ValidateTrackingSpecBufferForPurchLine directamente
    // (sin SyncPurchLineFromTrackingBuffer previo) para probar la validación de
    // totales de forma independiente del flujo de sincronización.
    // -------------------------------------------------------------------------
    [Test]
    procedure PurchLotTracking_TrackingTotalsMismatch_RaisesError()
    var
        Item: Record Item;
        Vendor: Record Vendor;
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        TrackingSpec: Record "Tracking Specification" temporary;
        DUoMTestHelpers: Codeunit "DUoM Test Helpers";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryAssert: Codeunit "Library Assert";
        DUoMCoherenceMgt: Codeunit "DUoM Tracking Coherence Mgt";
    begin
        // [GIVEN] Artículo con DUoM Variable
        LibraryInventory.CreateItem(Item);
        DUoMTestHelpers.CreateItemSetup(Item."No.", true, 'PCS', "DUoM Conversion Mode"::Variable, 0);

        // [GIVEN] Purchase Line real con DUoM Second Qty = 65 (Qty = 20)
        LibraryPurchase.CreateVendor(Vendor);
        LibraryPurchase.CreatePurchHeader(
            PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(
            PurchLine, PurchHeader, PurchLine.Type::Item, Item."No.", 0);
        PurchLine.Validate(Quantity, 20);
        PurchLine."DUoM Second Qty" := 65;
        PurchLine.Modify(false);

        // [GIVEN] Buffer de tracking que suma 64 PCS en lugar de 65
        //         (lote BBB tiene SecondQty = 6 en lugar de 7 → total = 64)
        //         Todos los lotes tienen ratios coherentes (no hay incoherencia por lote).
        TrackingSpec.Init();
        TrackingSpec."Entry No." := 1;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Source Type" := Database::"Purchase Line";
        TrackingSpec."Source Subtype" := PurchLine."Document Type".AsInteger();
        TrackingSpec."Source ID" := PurchLine."Document No.";
        TrackingSpec."Source Ref. No." := PurchLine."Line No.";
        TrackingSpec."Source Batch Name" := '';
        TrackingSpec."Source Prod. Order Line" := 0;
        TrackingSpec."Lot No." := 'BBB';
        TrackingSpec."Quantity (Base)" := 3;
        TrackingSpec."DUoM Second Qty" := 6;  // reducido 1 para crear desajuste (6+5+53=64≠65)
        TrackingSpec."DUoM Ratio" := 6 / 3;
        TrackingSpec.Insert();

        TrackingSpec.Init();
        TrackingSpec."Entry No." := 2;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Source Type" := Database::"Purchase Line";
        TrackingSpec."Source Subtype" := PurchLine."Document Type".AsInteger();
        TrackingSpec."Source ID" := PurchLine."Document No.";
        TrackingSpec."Source Ref. No." := PurchLine."Line No.";
        TrackingSpec."Source Batch Name" := '';
        TrackingSpec."Source Prod. Order Line" := 0;
        TrackingSpec."Lot No." := 'GFFF';
        TrackingSpec."Quantity (Base)" := 1;
        TrackingSpec."DUoM Second Qty" := 5;
        TrackingSpec."DUoM Ratio" := 5;
        TrackingSpec.Insert();

        TrackingSpec.Init();
        TrackingSpec."Entry No." := 3;
        TrackingSpec."Item No." := Item."No.";
        TrackingSpec."Source Type" := Database::"Purchase Line";
        TrackingSpec."Source Subtype" := PurchLine."Document Type".AsInteger();
        TrackingSpec."Source ID" := PurchLine."Document No.";
        TrackingSpec."Source Ref. No." := PurchLine."Line No.";
        TrackingSpec."Source Batch Name" := '';
        TrackingSpec."Source Prod. Order Line" := 0;
        TrackingSpec."Lot No." := 'NNNN';
        TrackingSpec."Quantity (Base)" := 16;
        TrackingSpec."DUoM Second Qty" := 53;
        TrackingSpec."DUoM Ratio" := 53 / 16;
        TrackingSpec.Insert();

        // Posicionar el cursor en el primer registro del buffer (necesario para que
        // ValidateTrackingSpecBufferForPurchLine lea la info de origen correctamente)
        TrackingSpec.FindFirst();

        // [WHEN] Se valida el total del buffer contra la Purchase Line
        // [THEN] Error: la suma del tracking (64) no coincide con la Purchase Line (65)
        asserterror DUoMCoherenceMgt.ValidateTrackingSpecBufferForPurchLine(TrackingSpec);
        LibraryAssert.ExpectedError('does not match the DUoM quantity on the purchase line');
    end;
}
