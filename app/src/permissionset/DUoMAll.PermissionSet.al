/// <summary>
/// Grants full read/write access to all DualUoM extension objects.
/// Assign this permission set to users or roles that need to configure
/// or use Dual Unit of Measure functionality.
///
/// Incluye acceso RIMD a las tablas base de BC que el subscriber DUoM escribe
/// durante la contabilización (Purch. Rcpt. Line, Sales Shipment Line), evitando
/// el error "Su licencia no le concede Modify en TableData 121/111".
/// </summary>
permissionset 50100 "DUoM - All"
{
    Assignable = true;
    Caption = 'DualUoM - All';

    Permissions =
        tabledata "DUoM Item Setup" = RIMD,
        tabledata "Purch. Rcpt. Line" = RIMD,
        tabledata "Sales Shipment Line" = RIMD;
}
