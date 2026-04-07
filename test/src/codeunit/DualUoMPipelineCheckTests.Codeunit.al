codeunit 50200 "DualUoM Pipeline Check Tests"
{
    Subtype = Test;
    [Test]
    procedure TestPipelineIsAlive()
    var
        Assert: Codeunit "Assert";  // ✅ corregido
    begin
        // [GIVEN/WHEN/THEN] Pipeline validation — always passes
        Assert.IsTrue(true, 'Pipeline check passed');
    end;
}
