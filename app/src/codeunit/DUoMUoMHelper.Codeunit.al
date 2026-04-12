/// <summary>
/// Helper codeunit for Unit of Measure operations in the Dual UoM context.
/// Provides shared utilities for retrieving UoM properties needed across
/// tableextensions and event subscribers without duplicating lookup logic.
/// </summary>
codeunit 50106 "DUoM UoM Helper"
{
    Access = Internal;

    /// <summary>
    /// Returns the Qty. Rounding Precision of the secondary Unit of Measure
    /// configured for the given item in DUoM Item Setup.
    /// Reads the "Qty. Rounding Precision" field from the Item Unit of Measure
    /// table for the combination of ItemNo and the configured second UoM code.
    /// Returns 0 when the item has no DUoM setup, no secondary UoM code is set,
    /// or the Item Unit of Measure record does not exist in the database.
    /// </summary>
    /// <param name="ItemNo">The item number to look up in DUoM Item Setup.</param>
    /// <returns>The Qty. Rounding Precision of the secondary UoM, or 0 as fallback.</returns>
    procedure GetSecondUoMRoundingPrecision(ItemNo: Code[20]): Decimal
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        if not DUoMItemSetup.Get(ItemNo) then
            exit(0);
        if DUoMItemSetup."Second UoM Code" = '' then
            exit(0);
        if ItemUnitOfMeasure.Get(ItemNo, DUoMItemSetup."Second UoM Code") then
            exit(ItemUnitOfMeasure."Qty. Rounding Precision");
        exit(0);
    end;

    /// <summary>
    /// Returns the Qty. Rounding Precision for a specific UoM code on an item.
    /// Use this overload when the effective Second UoM Code is already known
    /// (e.g. obtained from DUoM Setup Resolver after applying variant hierarchy).
    /// Returns 0 when SecondUoMCode is blank or the Item Unit of Measure record
    /// does not exist.
    /// </summary>
    /// <param name="ItemNo">The item number.</param>
    /// <param name="SecondUoMCode">The secondary UoM code to look up.</param>
    /// <returns>The Qty. Rounding Precision of the given UoM, or 0 as fallback.</returns>
    procedure GetRoundingPrecisionByUoMCode(ItemNo: Code[20]; SecondUoMCode: Code[10]): Decimal
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        if SecondUoMCode = '' then
            exit(0);
        if ItemUnitOfMeasure.Get(ItemNo, SecondUoMCode) then
            exit(ItemUnitOfMeasure."Qty. Rounding Precision");
        exit(0);
    end;
}
