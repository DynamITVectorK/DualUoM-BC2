/// <summary>
/// Grants full read/write access to all DualUoM extension objects.
/// Assign this permission set to users or roles that need to configure
/// or use Dual Unit of Measure functionality.
///
/// Incluye acceso RIMD a las tablas base de BC que el subscriber DUoM escribe
/// durante la contabilización (Purch. Rcpt. Line, Sales Shipment Line,
/// Purch. Inv. Line, Purch. Cr. Memo Line, Sales Invoice Line, Sales Cr.Memo Line),
/// evitando el error "Su licencia no le concede Modify en TableData NNN".
/// Incluye lectura sobre Value Entry para que las páginas e informes DUoM
/// puedan mostrar el campo DUoM Second Qty. El suscriptor OnAfterInitValueEntry
/// asigna el campo antes del Insert() estándar de BC, sin llamar a Modify().
/// </summary>
permissionset 50100 "DUoM - All"
{
    Assignable = true;
    Caption = 'DualUoM - All';

    Permissions =
        tabledata "DUoM Item Setup" = RIMD,
        tabledata "DUoM Item Variant Setup" = RIMD,
        tabledata "DUoM Lot Ratio" = RIMD,
        tabledata "Purch. Rcpt. Line" = RIMD,
        tabledata "Sales Shipment Line" = RIMD,
        tabledata "Purch. Inv. Line" = RIMD,
        tabledata "Purch. Cr. Memo Line" = RIMD,
        tabledata "Sales Invoice Line" = RIMD,
        tabledata "Sales Cr.Memo Line" = RIMD,
        tabledata "Value Entry" = R,
        tabledata "Reservation Entry" = RIMD;
}
