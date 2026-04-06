codeunit 50100 "DualUoM Pipeline Check Tests"
{
    Subtype = Test;

    [Test]
    procedure TestPipelineIsAlive()
    var
        Assert: Codeunit "Library - Assert";
    begin
        // [GIVEN/WHEN/THEN] Pipeline validation — always passes
        Assert.IsTrue(true, 'Pipeline check passed');
    end;
}
