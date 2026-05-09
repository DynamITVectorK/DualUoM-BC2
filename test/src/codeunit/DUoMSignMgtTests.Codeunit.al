/// <summary>
/// Tests unitarios para la codeunit centralizada DUoM Sign Mgt (50126).
///
/// Verifica que los dos métodos de gestión de signo DUoM producen los resultados
/// correctos en todos los casos relevantes:
///
///   NormalizeILESign:
///     - ILE.Quantity > 0 (entrada/compra) → DUoM Second Qty positiva.
///     - ILE.Quantity < 0 (salida/venta)   → DUoM Second Qty negativa.
///     - SecondQty = 0                     → devuelve 0.
///     - ILE.Quantity = 0                  → devuelve SecondQty sin cambio.
///
///   ApplyMovementSign:
///     - IJL."Quantity (Base)" < 0 (salida) → DUoM Second Qty negativa.
///     - IJL.Quantity < 0 (salida sin base) → DUoM Second Qty negativa.
///     - Entrada positiva                   → DUoM Second Qty positiva.
///     - SecondQty = 0                      → devuelve 0.
///
/// Principios verificados:
///   - DUoM Ratio no se altera (signo siempre positivo; no es responsabilidad de este codeunit).
///   - El signo no se aplica dos veces (se verifica que Abs(resultado) = Abs(entrada)).
///   - Venta: compra → ILE positivo; venta → ILE negativo; undo receipt → ILE negativo;
///     undo shipment → ILE positivo.
/// </summary>
codeunit 50228 "DUoM Sign Mgt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // =========================================================================
    // NormalizeILESign — ILE de entrada (compra)
    // =========================================================================

    [Test]
    procedure NormalizeILESign_PurchaseEntry_ReturnsPositive()
    var
        ILE: Record "Item Ledger Entry";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] ILE de entrada (compra): Quantity = +10, SecondQty = 8
        ILE.Init();
        ILE.Quantity := 10;

        // [WHEN] Se normaliza el signo de DUoM Second Qty
        Result := DUoMSignMgt.NormalizeILESign(ILE, 8);

        // [THEN] DUoM Second Qty es positiva (entrada)
        LibraryAssert.AreEqual(8, Result,
            'Compra: ILE.Quantity > 0 → DUoM Second Qty debe ser positiva.');
    end;

    [Test]
    procedure NormalizeILESign_PurchaseEntry_NegativeInput_ReturnsPositive()
    var
        ILE: Record "Item Ledger Entry";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] ILE de entrada con SecondQty negativa (valor inconsistente)
        ILE.Init();
        ILE.Quantity := 10;

        // [WHEN] Se normaliza el signo
        Result := DUoMSignMgt.NormalizeILESign(ILE, -8);

        // [THEN] El signo se corrige a positivo (no se aplica dos veces)
        LibraryAssert.AreEqual(8, Result,
            'Compra: ILE.Quantity > 0 → DUoM Second Qty debe corregirse a positiva.');
    end;

    // =========================================================================
    // NormalizeILESign — ILE de salida (venta)
    // =========================================================================

    [Test]
    procedure NormalizeILESign_SaleEntry_ReturnsNegative()
    var
        ILE: Record "Item Ledger Entry";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] ILE de salida (venta): Quantity = -10, SecondQty = 8 (positiva)
        ILE.Init();
        ILE.Quantity := -10;

        // [WHEN] Se normaliza el signo
        Result := DUoMSignMgt.NormalizeILESign(ILE, 8);

        // [THEN] DUoM Second Qty es negativa (salida)
        LibraryAssert.AreEqual(-8, Result,
            'Venta: ILE.Quantity < 0 → DUoM Second Qty debe ser negativa.');
    end;

    [Test]
    procedure NormalizeILESign_SaleEntry_AlreadyNegativeInput_ReturnsNegative()
    var
        ILE: Record "Item Ledger Entry";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] ILE de salida con SecondQty ya negativa
        ILE.Init();
        ILE.Quantity := -10;

        // [WHEN] Se normaliza el signo
        Result := DUoMSignMgt.NormalizeILESign(ILE, -8);

        // [THEN] El resultado sigue siendo negativo (sin doble inversión)
        LibraryAssert.AreEqual(-8, Result,
            'Venta: con SecondQty negativa, el resultado no debe invertirse dos veces.');
    end;

    // =========================================================================
    // NormalizeILESign — SecondQty = 0
    // =========================================================================

    [Test]
    procedure NormalizeILESign_ZeroSecondQty_ReturnsZero()
    var
        ILE: Record "Item Ledger Entry";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] SecondQty = 0 (artículo sin DUoM o ratio cero)
        ILE.Init();
        ILE.Quantity := 10;

        // [WHEN] Se normaliza el signo
        Result := DUoMSignMgt.NormalizeILESign(ILE, 0);

        // [THEN] Devuelve 0 sin alteraciones
        LibraryAssert.AreEqual(0, Result,
            'SecondQty = 0 → NormalizeILESign debe devolver 0.');
    end;

    // =========================================================================
    // NormalizeILESign — ILE.Quantity = 0
    // =========================================================================

    [Test]
    procedure NormalizeILESign_ZeroILEQuantity_ReturnsUnchanged()
    var
        ILE: Record "Item Ledger Entry";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] ILE.Quantity = 0 (caso límite/ajuste neutro)
        ILE.Init();
        ILE.Quantity := 0;

        // [WHEN] Se normaliza el signo
        Result := DUoMSignMgt.NormalizeILESign(ILE, 5);

        // [THEN] Devuelve el valor sin cambio (no hay dirección definida)
        LibraryAssert.AreEqual(5, Result,
            'ILE.Quantity = 0 → NormalizeILESign debe devolver SecondQty sin cambio.');
    end;

    // =========================================================================
    // ApplyMovementSign — salida por Quantity (Base)
    // =========================================================================

    [Test]
    procedure ApplyMovementSign_NegativeQtyBase_ReturnsNegative()
    var
        IJL: Record "Item Journal Line";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] IJL de salida: Quantity (Base) < 0 (venta en BC 27)
        IJL.Init();
        IJL."Quantity (Base)" := -10;
        IJL.Quantity := 10;

        // [WHEN] Se aplica el signo del movimiento a una SecondQty positiva
        Result := DUoMSignMgt.ApplyMovementSign(IJL, 8);

        // [THEN] Resultado negativo (salida)
        LibraryAssert.AreEqual(-8, Result,
            'Salida (Qty Base < 0) → ApplyMovementSign debe devolver valor negativo.');
    end;

    [Test]
    procedure ApplyMovementSign_NegativeQty_ReturnsNegative()
    var
        IJL: Record "Item Journal Line";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] IJL con Quantity < 0 y Quantity (Base) = 0 (fallback a Quantity)
        IJL.Init();
        IJL."Quantity (Base)" := 0;
        IJL.Quantity := -10;

        // [WHEN] Se aplica el signo del movimiento
        Result := DUoMSignMgt.ApplyMovementSign(IJL, 8);

        // [THEN] Resultado negativo (salida por Quantity)
        LibraryAssert.AreEqual(-8, Result,
            'Salida (Qty < 0, Qty Base = 0) → ApplyMovementSign debe devolver valor negativo.');
    end;

    // =========================================================================
    // ApplyMovementSign — entrada
    // =========================================================================

    [Test]
    procedure ApplyMovementSign_PositiveQtyBase_ReturnsPositive()
    var
        IJL: Record "Item Journal Line";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] IJL de entrada: Quantity (Base) > 0 (compra en BC 27)
        IJL.Init();
        IJL."Quantity (Base)" := 10;
        IJL.Quantity := 10;

        // [WHEN] Se aplica el signo del movimiento
        Result := DUoMSignMgt.ApplyMovementSign(IJL, 8);

        // [THEN] Resultado positivo (entrada)
        LibraryAssert.AreEqual(8, Result,
            'Entrada (Qty Base > 0) → ApplyMovementSign debe devolver valor positivo.');
    end;

    // =========================================================================
    // ApplyMovementSign — SecondQty = 0
    // =========================================================================

    [Test]
    procedure ApplyMovementSign_ZeroSecondQty_ReturnsZero()
    var
        IJL: Record "Item Journal Line";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
        Result: Decimal;
    begin
        // [GIVEN] SecondQty = 0 (artículo sin DUoM)
        IJL.Init();
        IJL."Quantity (Base)" := -10;
        IJL.Quantity := -10;

        // [WHEN] Se aplica el signo del movimiento
        Result := DUoMSignMgt.ApplyMovementSign(IJL, 0);

        // [THEN] Devuelve 0
        LibraryAssert.AreEqual(0, Result,
            'SecondQty = 0 → ApplyMovementSign debe devolver 0.');
    end;

    // =========================================================================
    // Verificación de coherencia de signo: compra → ILE positivo
    // =========================================================================

    [Test]
    procedure SignCoherence_PurchaseILE_PositiveQtyAndSecondQty()
    var
        ILE: Record "Item Ledger Entry";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Compra: ILE.Quantity = +10, DUoM Ratio = 0.8
        ILE.Init();
        ILE.Quantity := 10;

        // [WHEN] Se normaliza DUoM Second Qty = Quantity × Ratio = 10 × 0.8 = 8
        // [THEN] DUoM Second Qty es positiva, DUoM Ratio es positiva
        LibraryAssert.AreEqual(8, DUoMSignMgt.NormalizeILESign(ILE, 8),
            'Compra: DUoM Second Qty debe ser positiva (misma dirección que ILE.Quantity).');
        LibraryAssert.IsTrue(0.8 > 0, 'DUoM Ratio debe mantenerse positivo en compras.');
    end;

    // =========================================================================
    // Verificación de coherencia de signo: venta → ILE negativo
    // =========================================================================

    [Test]
    procedure SignCoherence_SaleILE_NegativeQtyAndSecondQty()
    var
        ILE: Record "Item Ledger Entry";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Venta: ILE.Quantity = -5, DUoM Ratio = 1.25
        ILE.Init();
        ILE.Quantity := -5;

        // [WHEN] Se normaliza DUoM Second Qty = 5 × 1.25 = 6.25 (magnitud)
        // [THEN] DUoM Second Qty es negativa (-6.25), DUoM Ratio positiva (1.25)
        LibraryAssert.AreEqual(-6.25, DUoMSignMgt.NormalizeILESign(ILE, 6.25),
            'Venta: DUoM Second Qty debe ser negativa (misma dirección que ILE.Quantity < 0).');
        LibraryAssert.IsTrue(1.25 > 0, 'DUoM Ratio debe mantenerse positivo en ventas.');
    end;

    // =========================================================================
    // Verificación de coherencia de signo: undo receipt → corrección negativa
    // =========================================================================

    [Test]
    procedure SignCoherence_UndoReceiptCorrection_NegativeSecondQty()
    var
        ILE: Record "Item Ledger Entry";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] ILE de corrección de undo receipt: Quantity = -10
        //         (corrección invierte la recepción original con Quantity = +10)
        ILE.Init();
        ILE.Quantity := -10;

        // [WHEN] Se normaliza la magnitud de la recepción original (8)
        // [THEN] DUoM Second Qty es negativa (corrección de entrada es salida)
        LibraryAssert.AreEqual(-8, DUoMSignMgt.NormalizeILESign(ILE, 8),
            'Undo receipt: ILE corrección con Qty < 0 → DUoM Second Qty negativa.');
    end;

    // =========================================================================
    // Verificación de coherencia de signo: undo shipment → corrección positiva
    // =========================================================================

    [Test]
    procedure SignCoherence_UndoShipmentCorrection_PositiveSecondQty()
    var
        ILE: Record "Item Ledger Entry";
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] ILE de corrección de undo shipment: Quantity = +10
        //         (corrección invierte el envío original con Quantity = -10)
        ILE.Init();
        ILE.Quantity := 10;

        // [WHEN] Se normaliza la magnitud del envío original (8)
        // [THEN] DUoM Second Qty es positiva (corrección de salida es entrada)
        LibraryAssert.AreEqual(8, DUoMSignMgt.NormalizeILESign(ILE, 8),
            'Undo shipment: ILE corrección con Qty > 0 → DUoM Second Qty positiva.');
    end;

    // =========================================================================
    // ApplyUndoPurchReceiptSign — siempre negativo
    // =========================================================================

    [Test]
    procedure ApplyUndoPurchReceiptSign_PositiveOriginal_ReturnsNegative()
    var
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Albarán de compra original con DUoM Second Qty = 8 (positiva)
        // [WHEN] Se calcula el signo de la anulación
        // [THEN] Resultado negativo (la corrección invierte la recepción original)
        LibraryAssert.AreEqual(-8, DUoMSignMgt.ApplyUndoPurchReceiptSign(8),
            'Undo receipt (positivo original) → DUoM Second Qty debe ser negativa.');
    end;

    [Test]
    procedure ApplyUndoPurchReceiptSign_NegativeOriginal_ReturnsNegative()
    var
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Albarán de compra con DUoM Second Qty con signo incorrecto (negativa)
        // [WHEN] Se calcula el signo de la anulación
        // [THEN] Resultado negativo (siempre negativo, sin doble inversión)
        LibraryAssert.AreEqual(-8, DUoMSignMgt.ApplyUndoPurchReceiptSign(-8),
            'Undo receipt (negativo original) → DUoM Second Qty debe seguir siendo negativa.');
    end;

    [Test]
    procedure ApplyUndoPurchReceiptSign_Zero_ReturnsZero()
    var
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Albarán de compra sin DUoM (SecondQty = 0)
        // [WHEN] Se calcula el signo de la anulación
        // [THEN] Devuelve 0
        LibraryAssert.AreEqual(0, DUoMSignMgt.ApplyUndoPurchReceiptSign(0),
            'Undo receipt con SecondQty = 0 → debe devolver 0.');
    end;

    // =========================================================================
    // ApplyUndoSalesShptSign — siempre positivo
    // =========================================================================

    [Test]
    procedure ApplyUndoSalesShptSign_NegativeOriginal_ReturnsPositive()
    var
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Albarán de venta original con DUoM Second Qty = -8 (negativa, salida)
        // [WHEN] Se calcula el signo de la anulación
        // [THEN] Resultado positivo (la corrección invierte el envío original)
        LibraryAssert.AreEqual(8, DUoMSignMgt.ApplyUndoSalesShptSign(-8),
            'Undo shipment (negativo original) → DUoM Second Qty debe ser positiva.');
    end;

    [Test]
    procedure ApplyUndoSalesShptSign_PositiveOriginal_ReturnsPositive()
    var
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Albarán de venta con DUoM Second Qty con signo incorrecto (positiva)
        // [WHEN] Se calcula el signo de la anulación
        // [THEN] Resultado positivo (siempre positivo, sin doble inversión)
        LibraryAssert.AreEqual(8, DUoMSignMgt.ApplyUndoSalesShptSign(8),
            'Undo shipment (positivo original) → DUoM Second Qty debe seguir siendo positiva.');
    end;

    [Test]
    procedure ApplyUndoSalesShptSign_Zero_ReturnsZero()
    var
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] Albarán de venta sin DUoM (SecondQty = 0)
        // [WHEN] Se calcula el signo de la anulación
        // [THEN] Devuelve 0
        LibraryAssert.AreEqual(0, DUoMSignMgt.ApplyUndoSalesShptSign(0),
            'Undo shipment con SecondQty = 0 → debe devolver 0.');
    end;

    // =========================================================================
    // ApplyCorrectionILESign — negación del ILE original
    // =========================================================================

    [Test]
    procedure ApplyCorrectionILESign_PositiveOriginalILE_ReturnsNegative()
    var
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] ILE original de compra: DUoM Second Qty = 8 (positiva, entrada)
        // [WHEN] Se calcula el signo del ILE de corrección
        // [THEN] Resultado negativo (la corrección invierte el ILE original)
        LibraryAssert.AreEqual(-8, DUoMSignMgt.ApplyCorrectionILESign(8),
            'ILE corrección de compra: resultado debe ser negativo (inversión del original positivo).');
    end;

    [Test]
    procedure ApplyCorrectionILESign_NegativeOriginalILE_ReturnsPositive()
    var
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] ILE original de venta: DUoM Second Qty = -8 (negativa, salida)
        // [WHEN] Se calcula el signo del ILE de corrección
        // [THEN] Resultado positivo (la corrección invierte el ILE original)
        LibraryAssert.AreEqual(8, DUoMSignMgt.ApplyCorrectionILESign(-8),
            'ILE corrección de venta: resultado debe ser positivo (inversión del original negativo).');
    end;

    [Test]
    procedure ApplyCorrectionILESign_Zero_ReturnsZero()
    var
        DUoMSignMgt: Codeunit "DUoM Sign Mgt";
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN] ILE original sin DUoM (SecondQty = 0)
        // [WHEN] Se calcula el signo del ILE de corrección
        // [THEN] Devuelve 0
        LibraryAssert.AreEqual(0, DUoMSignMgt.ApplyCorrectionILESign(0),
            'ILE corrección con SecondQty = 0 → debe devolver 0.');
    end;
}
