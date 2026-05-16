/// <summary>
/// Propaga la configuración maestra DUoM al artículo destino cuando el usuario
/// copia un artículo usando la funcionalidad estándar de Business Central.
///
/// Tablas copiadas (datos maestros / configuración):
///   - DUoM Item Setup (50100): configuración DUoM a nivel de artículo.
///   - DUoM Item Variant Setup (50101): anulaciones DUoM por variante.
///
/// Tablas excluidas (datos transaccionales / históricos):
///   - DUoM Lot Ratio (50102): ratios reales por lote. Pertenecen al stock
///     recibido/producido del artículo origen y no deben heredarse.
///
/// Evento verificado: OnAfterCopyItem en Codeunit::"Copy Item" (BC 27 / runtime 15).
/// Firma confirmada en Apps/CZ/AdvancedLocalizationPack (microsoft/ALAppExtensions).
/// Publisher: ObjectType::Codeunit, Codeunit::"Copy Item", evento 'OnAfterCopyItem'.
/// Parámetros: (var CopyItemBuffer: Record "Copy Item Buffer";
///              SourceItem: Record Item; var TargetItem: Record Item)
/// Se eligió este evento porque se dispara tras completar la copia del artículo
/// y todas las tablas relacionadas seleccionadas por el usuario, garantizando
/// que las variantes del artículo destino ya existen cuando se ejecuta el suscriptor.
/// </summary>
codeunit 50128 "DUoM Copy Item Mgt."
{
    // -------------------------------------------------------------------------
    // Suscriptor del evento estándar de copia de artículo
    // -------------------------------------------------------------------------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Copy Item", 'OnAfterCopyItem', '', false, false)]
    local procedure OnAfterCopyItemHandler(var CopyItemBuffer: Record "Copy Item Buffer"; SourceItem: Record Item; var TargetItem: Record Item)
    begin
        CopyDUoMSetup(SourceItem."No.", TargetItem."No.");
    end;

    // -------------------------------------------------------------------------
    // Procedimiento público — usado también directamente en tests unitarios
    // -------------------------------------------------------------------------

    /// <summary>
    /// Copia la configuración DUoM maestra del artículo origen al artículo destino.
    /// Idempotente: si el destino ya tiene configuración DUoM, se actualiza; no se duplica.
    /// </summary>
    procedure CopyDUoMSetup(SourceItemNo: Code[20]; TargetItemNo: Code[20])
    begin
        CopyItemSetup(SourceItemNo, TargetItemNo);
        CopyVariantSetups(SourceItemNo, TargetItemNo);
    end;

    // -------------------------------------------------------------------------
    // Procedimientos locales
    // -------------------------------------------------------------------------

    local procedure CopyItemSetup(SourceItemNo: Code[20]; TargetItemNo: Code[20])
    var
        SourceSetup: Record "DUoM Item Setup";
        TargetSetup: Record "DUoM Item Setup";
    begin
        if not SourceSetup.Get(SourceItemNo) then
            exit;

        if TargetSetup.Get(TargetItemNo) then begin
            TargetSetup."Dual UoM Enabled" := SourceSetup."Dual UoM Enabled";
            TargetSetup."Second UoM Code" := SourceSetup."Second UoM Code";
            TargetSetup."Conversion Mode" := SourceSetup."Conversion Mode";
            TargetSetup."Fixed Ratio" := SourceSetup."Fixed Ratio";
            TargetSetup.Modify(false);
        end else begin
            TargetSetup.TransferFields(SourceSetup);
            TargetSetup."Item No." := TargetItemNo;
            TargetSetup.Insert(false);
        end;
    end;

    local procedure CopyVariantSetups(SourceItemNo: Code[20]; TargetItemNo: Code[20])
    var
        SourceVariantSetup: Record "DUoM Item Variant Setup";
    begin
        SourceVariantSetup.SetRange("Item No.", SourceItemNo);
        if not SourceVariantSetup.FindSet() then
            exit;

        repeat
            CopyVariantSetupIfTargetExists(SourceVariantSetup, TargetItemNo);
        until SourceVariantSetup.Next() = 0;
    end;

    local procedure CopyVariantSetupIfTargetExists(SourceVariantSetup: Record "DUoM Item Variant Setup"; TargetItemNo: Code[20])
    var
        TargetVariantSetup: Record "DUoM Item Variant Setup";
        ItemVariant: Record "Item Variant";
    begin
        // Omitir si la variante no existe en el artículo destino
        // (ocurre cuando el usuario no eligió copiar variantes en el flujo estándar).
        if not ItemVariant.Get(TargetItemNo, SourceVariantSetup."Variant Code") then
            exit;

        if TargetVariantSetup.Get(TargetItemNo, SourceVariantSetup."Variant Code") then begin
            TargetVariantSetup."Second UoM Code" := SourceVariantSetup."Second UoM Code";
            TargetVariantSetup."Conversion Mode" := SourceVariantSetup."Conversion Mode";
            TargetVariantSetup."Fixed Ratio" := SourceVariantSetup."Fixed Ratio";
            TargetVariantSetup.Modify(false);
        end else begin
            TargetVariantSetup.TransferFields(SourceVariantSetup);
            TargetVariantSetup."Item No." := TargetItemNo;
            TargetVariantSetup.Insert(false);
        end;
    end;
}
