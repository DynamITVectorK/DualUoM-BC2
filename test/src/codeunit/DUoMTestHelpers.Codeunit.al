/// <summary>
/// Procedimientos auxiliares compartidos para los codeunits de test DUoM.
/// Proporciona configuración de permisos para tests que insertan en la tabla DUoM Item Setup (50100).
/// En BC 27.5+, TestPermissions = Disabled no desactiva los checks de permisos para tablas
/// de extensiones PTE, por lo que es necesario asignar el permission set explícitamente.
/// </summary>
codeunit 50208 "DUoM Test Helpers"
{
    /// <summary>
    /// Asigna el permission set 'DUoM - Test All' al usuario de test actual
    /// para garantizar que las operaciones Insert/Modify/Delete sobre la tabla
    /// DUoM Item Setup (50100) puedan ejecutarse durante los tests.
    /// Llamar desde el procedimiento [SetUp] de cada codeunit de test que inserte
    /// en DUoM Item Setup.
    /// </summary>
    procedure SetUpTestPermissions()
    var
        AccessControl: Record "Access Control";
        ModuleInfo: ModuleInfo;
        CompanyNameText: Text[30];
    begin
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        CompanyNameText := CopyStr(CompanyName(), 1, MaxStrLen(AccessControl."Company Name"));

        if AccessControl.Get(
            UserSecurityId(),
            'DUoM - Test All',
            CompanyNameText,
            AccessControl."Scope"::Tenant,
            ModuleInfo.Id)
        then
            exit;

        AccessControl.Init();
        AccessControl."User Security ID" := UserSecurityId();
        AccessControl."Role ID" := 'DUoM - Test All';
        AccessControl."Company Name" := CompanyNameText;
        AccessControl."Scope" := AccessControl."Scope"::Tenant;
        AccessControl."App ID" := ModuleInfo.Id;
        AccessControl.Insert();
    end;
}
