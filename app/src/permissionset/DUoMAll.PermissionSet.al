/// <summary>
/// Grants full read/write access to all DualUoM extension objects.
/// Assign this permission set to users or roles that need to configure
/// or use Dual Unit of Measure functionality.
/// </summary>
permissionset 50100 "DUoM - All"
{
    Assignable = true;
    Caption = 'DualUoM - All';

    Permissions =
        tabledata "DUoM Item Setup" = RIMD;
}
