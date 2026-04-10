/// <summary>
/// Grants the test app full access (direct and indirect) to DualUoM extension tables.
/// Assign this permission set to the test execution context so that test codeunits
/// can both directly insert into Table 50100 and trigger indirect inserts via
/// production codeunits (e.g. GetOrCreate), without relying on the deprecated
/// Permissions property on codeunit objects (AL0246).
/// </summary>
permissionset 50200 "DUoM - Test"
{
    Assignable = true;
    Caption = 'DualUoM - Test';

    Permissions =
        tabledata "DUoM Item Setup" = RIMD;
}
