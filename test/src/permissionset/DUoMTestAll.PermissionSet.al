/// <summary>
/// Grants the test app full access (direct and indirect) to DualUoM extension tables.
/// Assign this permission set to the test execution context so that test codeunits
/// can both directly insert into Table 50100 and trigger indirect inserts via
/// production codeunits (e.g. GetOrCreate), without relying on the deprecated
/// Permissions property on codeunit objects (AL0246).
///
/// Incluye también RIMD sobre las tablas base escritas por los subscribers DUoM
/// durante la contabilización (Purch. Rcpt. Line, Sales Shipment Line,
/// Purch. Inv. Line, Purch. Cr. Memo Line, Sales Invoice Line, Sales Cr.Memo Line),
/// necesario para que los tests E2E con TestPermissions = Restrictive no fallen
/// por falta de permiso Modify en las tablas base de BC.
/// </summary>
permissionset 50200 "DUoM - Test All"
{
    Assignable = true;
    Caption = 'DualUoM - Test All';

    Permissions =
        tabledata "DUoM Item Setup" = RIMD,
        tabledata "Purch. Rcpt. Line" = RIMD,
        tabledata "Sales Shipment Line" = RIMD,
        tabledata "Purch. Inv. Line" = RIMD,
        tabledata "Purch. Cr. Memo Line" = RIMD,
        tabledata "Sales Invoice Line" = RIMD,
        tabledata "Sales Cr.Memo Line" = RIMD;
}
