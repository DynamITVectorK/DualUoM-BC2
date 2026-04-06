/// <summary>
/// Temporary pipeline validation codeunit.
/// Will be deleted when Issue DynamITVectorK/DualUoM-BC2#2 (Calc Engine) is merged.
/// </summary>
codeunit 50100 "DualUoM Pipeline Check"
{
    Access = Internal;

    procedure PipelineCheck()
    begin
        // Intentionally empty — compile validation only
    end;
}
