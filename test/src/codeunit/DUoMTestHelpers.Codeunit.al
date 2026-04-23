/// <summary>
/// Procedimientos auxiliares compartidos para los codeunits de test DUoM.
/// Proporciona factorías de datos para crear y limpiar registros DUoM Item Setup (50100)
/// y DUoM Item Variant Setup (50101) durante los tests, sin dependencia de tablas
/// del sistema como Access Control.
/// </summary>
codeunit 50208 "DUoM Test Helpers"
{
    /// <summary>
    /// Crea e inserta un registro DUoM Item Setup con los valores indicados.
    /// Devuelve el registro insertado para su uso inmediato en el test.
    /// </summary>
    procedure CreateItemSetup(
        ItemNo: Code[20];
        Enabled: Boolean;
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal): Record "DUoM Item Setup"
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        DUoMItemSetup.Init();
        DUoMItemSetup."Item No." := ItemNo;
        DUoMItemSetup."Dual UoM Enabled" := Enabled;
        DUoMItemSetup."Second UoM Code" := SecondUoMCode;
        DUoMItemSetup."Conversion Mode" := ConversionMode;
        DUoMItemSetup."Fixed Ratio" := FixedRatio;
        DUoMItemSetup.Insert(false);
        exit(DUoMItemSetup);
    end;

    /// <summary>
    /// Elimina el registro DUoM Item Setup del ítem indicado si existe.
    /// No produce error si el registro no existe.
    /// </summary>
    procedure DeleteItemSetupIfExists(ItemNo: Code[20])
    var
        DUoMItemSetup: Record "DUoM Item Setup";
    begin
        if DUoMItemSetup.Get(ItemNo) then
            DUoMItemSetup.Delete(false);
    end;

    /// <summary>
    /// Crea e inserta un registro DUoM Item Variant Setup para la variante indicada.
    /// Devuelve el registro insertado para su uso inmediato en el test.
    /// </summary>
    procedure CreateVariantSetup(
        ItemNo: Code[20];
        VariantCode: Code[10];
        SecondUoMCode: Code[10];
        ConversionMode: Enum "DUoM Conversion Mode";
        FixedRatio: Decimal): Record "DUoM Item Variant Setup"
    var
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
    begin
        DUoMVariantSetup.Init();
        DUoMVariantSetup."Item No." := ItemNo;
        DUoMVariantSetup."Variant Code" := VariantCode;
        DUoMVariantSetup."Second UoM Code" := SecondUoMCode;
        DUoMVariantSetup."Conversion Mode" := ConversionMode;
        DUoMVariantSetup."Fixed Ratio" := FixedRatio;
        DUoMVariantSetup.Insert(false);
        exit(DUoMVariantSetup);
    end;

    /// <summary>
    /// Elimina el registro DUoM Item Variant Setup para la variante indicada si existe.
    /// No produce error si el registro no existe.
    /// </summary>
    procedure DeleteVariantSetupIfExists(ItemNo: Code[20]; VariantCode: Code[10])
    var
        DUoMVariantSetup: Record "DUoM Item Variant Setup";
    begin
        if DUoMVariantSetup.Get(ItemNo, VariantCode) then
            DUoMVariantSetup.Delete(false);
    end;

    /// <summary>
    /// Crea e inserta un registro DUoM Lot Ratio para el par (ItemNo, LotNo).
    /// Devuelve el registro insertado para su uso inmediato en el test.
    /// </summary>
    procedure CreateLotRatio(
        ItemNo: Code[20];
        LotNo: Code[50];
        ActualRatio: Decimal): Record "DUoM Lot Ratio"
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        DUoMLotRatio.Init();
        DUoMLotRatio."Item No." := ItemNo;
        DUoMLotRatio."Lot No." := LotNo;
        DUoMLotRatio."Actual Ratio" := ActualRatio;
        DUoMLotRatio.Insert(false);
        exit(DUoMLotRatio);
    end;

    /// <summary>
    /// Elimina el registro DUoM Lot Ratio para el par (ItemNo, LotNo) si existe.
    /// No produce error si el registro no existe.
    /// </summary>
    procedure DeleteLotRatioIfExists(ItemNo: Code[20]; LotNo: Code[50])
    var
        DUoMLotRatio: Record "DUoM Lot Ratio";
    begin
        if DUoMLotRatio.Get(ItemNo, LotNo) then
            DUoMLotRatio.Delete(false);
    end;

    /// <summary>
    /// Asigna un Item Tracking Code con seguimiento de lotes al artículo indicado.
    /// Crea el código 'DUoM-LOT' si no existe ya en la base de datos de prueba.
    /// Necesario para que BC 27 acepte y mantenga Lot No. en Item Journal Line
    /// durante la validación del campo (Validate("Lot No.", ...)), lo que permite
    /// al subscriber de lotes (50108) aplicar el ratio de lote sobre DUoM Ratio y
    /// DUoM Second Qty. Sin este código de seguimiento, BC puede limpiar el campo
    /// Lot No. durante la validación, dejando el subscriber sin efecto.
    ///
    /// Excepción justificada (Init + Insert sin helper estándar):
    ///   Library - Inventory no ofrece ningún método de creación de Item Tracking Code.
    ///   En BC 27 existe Library - Item Tracking en Tests-TestLibraries, pero no está
    ///   verificada su disponibilidad exacta ni su nombre de método en este entorno
    ///   (no tiene ningún uso previo en el proyecto). Para evitar una dependencia no
    ///   verificada, se crea el registro directamente con Init() + Insert(false), que
    ///   es el patrón admitido en el proyecto cuando no existe helper estándar aplicable.
    ///   Ver regla "AL Test Data Creation" en docs/05-testing-strategy.md.
    /// </summary>
    procedure EnableLotTrackingOnItem(var Item: Record Item)
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if not ItemTrackingCode.Get('DUoM-LOT') then begin
            ItemTrackingCode.Init();
            ItemTrackingCode.Code := 'DUoM-LOT';
            ItemTrackingCode.Description := 'DUoM Lot Tracking';
            ItemTrackingCode."Lot Specific Tracking" := true;
            ItemTrackingCode.Insert(false);
        end;
        Item.Validate("Item Tracking Code", ItemTrackingCode.Code);
        Item.Modify(true);
    end;

    /// <summary>
    /// Asigna seguimiento de lote a una Item Journal Line creando la Reservation Entry
    /// (Estado: Surplus) que BC 27 requiere para contabilizar un diario con trazabilidad
    /// de lote activada ("Lot Specific Tracking" = true en Item Tracking Code).
    ///
    /// Sin esta Reservation Entry, BC lanza "You must assign a lot number..." al intentar
    /// contabilizar la línea, incluso si "Lot No." está indicado directamente en el IJL.
    ///
    /// Excepción justificada (Init + Insert sin helper estándar):
    ///   Se verificó que "Library - Item Tracking" (Tests-TestLibraries BC 27) expone
    ///   CreateItemJournalLineItemTracking, pero la firma exacta del parámetro
    ///   ItemJournalLine (var Record vs. Record por valor) difiere entre versiones de
    ///   runtime y no puede confirmarse sin compilación. Una discordancia provocaría
    ///   error de compilación AL0036 en CI. Se opta por la creación directa de la
    ///   Reservation Entry con los campos mínimos exigidos por el motor de BC,
    ///   patrón que coincide con la implementación interna del propio helper estándar.
    ///   Ver regla "AL Test Data Creation" en docs/05-testing-strategy.md.
    ///
    /// Nota sobre el cálculo del Entry No.:
    ///   La tabla "Reservation Entry" no expone GetLastEntryNo(). El patrón estándar
    ///   en BC (incluido en "Library - Item Tracking") es FindLast() + "Entry No." + 1.
    ///
    /// Parámetros:
    ///   ItemJnlLine — La línea de diario a la que asignar la trazabilidad de lote.
    ///   LotNo       — El número de lote a asignar.
    ///   Qty         — Cantidad: positiva para entradas (Purchase), negativa para salidas (Sale).
    /// </summary>
    procedure AssignLotToItemJnlLine(var ItemJnlLine: Record "Item Journal Line"; LotNo: Code[50]; Qty: Decimal)
    var
        ReservationEntry: Record "Reservation Entry";
        NextEntryNo: Integer;
    begin
        if ReservationEntry.FindLast() then
            NextEntryNo := ReservationEntry."Entry No." + 1
        else
            NextEntryNo := 1;
        ReservationEntry.Init();
        ReservationEntry."Entry No." := NextEntryNo;
        ReservationEntry."Item No." := ItemJnlLine."Item No.";
        ReservationEntry."Variant Code" := ItemJnlLine."Variant Code";
        ReservationEntry."Location Code" := ItemJnlLine."Location Code";
        ReservationEntry."Lot No." := LotNo;
        ReservationEntry."Reservation Status" := ReservationEntry."Reservation Status"::Surplus;
        ReservationEntry."Source Type" := Database::"Item Journal Line";
        ReservationEntry."Source Subtype" := ItemJnlLine."Entry Type".AsInteger();
        ReservationEntry."Source ID" := ItemJnlLine."Journal Template Name";
        ReservationEntry."Source Batch Name" := ItemJnlLine."Journal Batch Name";
        ReservationEntry."Source Ref. No." := ItemJnlLine."Line No.";
        ReservationEntry."Quantity (Base)" := Qty;
        ReservationEntry."Qty. to Handle (Base)" := Qty;
        ReservationEntry."Qty. to Invoice (Base)" := Qty;
        ReservationEntry.Positive := Qty > 0;
        ReservationEntry."Creation Date" := Today;
        ReservationEntry.Insert(false);
    end;

    /// <summary>
    /// Crea una variante de artículo con el código específico indicado.
    /// Usa Library - Inventory.CreateItemVariant internamente (norma del proyecto)
    /// y después renombra al código deseado para mantener semántica de negocio
    /// determinista en los tests DUoM (p.ej. 'ROMANA', 'ICEBERG', 'GRANEL').
    /// Se justifica un helper propio porque LibraryInventory.CreateItemVariant genera
    /// un código aleatorio, pero los tests de variantes DUoM requieren códigos
    /// específicos con semántica funcional.
    /// </summary>
    procedure CreateItemVariantWithCode(ItemNo: Code[20]; VariantCode: Code[10]; var ItemVariant: Record "Item Variant")
    var
        LibraryInventory: Codeunit "Library - Inventory";
    begin
        LibraryInventory.CreateItemVariant(ItemVariant, ItemNo);
        ItemVariant.Rename(ItemNo, VariantCode);
    end;
}
