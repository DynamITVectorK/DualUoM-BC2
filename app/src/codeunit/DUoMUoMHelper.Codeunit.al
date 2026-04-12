/// <summary>
/// Helper codeunit for Unit of Measure operations in the Dual UoM context.
/// Provides shared utilities for retrieving UoM properties needed across
/// tableextensions and event subscribers without duplicating lookup logic.
/// </summary>
codeunit 50106 "DUoM UoM Helper"
{
    Access = Internal;

    /// <summary>
    /// Returns the Rounding Precision of the secondary Unit of Measure
    /// configured for the given item in DUoM Item Setup.
    /// Returns 0 when the item has no DUoM setup, no secondary UoM code is set,
    /// or the Unit of Measure record does not exist in the database.
    /// </summary>
    /// <param name="ItemNo">The item number to look up in DUoM Item Setup.</param>
    /// <returns>The Rounding Precision of the secondary UoM, or 0 as fallback.</returns>
    procedure GetSecondUoMRoundingPrecision(ItemNo: Code[20]): Decimal
    var
        DUoMItemSetup: Record "DUoM Item Setup";
        UnitOfMeasure: Record "Unit of Measure";
    begin
        if not DUoMItemSetup.Get(ItemNo) then
            exit(0);
        if DUoMItemSetup."Second UoM Code" = '' then
            exit(0);
        if UnitOfMeasure.Get(DUoMItemSetup."Second UoM Code") then
            exit(UnitOfMeasure."Rounding Precision");
        exit(0);
    end;
}
