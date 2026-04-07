codeunit 50200 "DualUoM Pipeline Check Tests"
{
    Subtype = Test;
    [Test]
    procedure TestPipelineIsAlive()
    var
        LibraryAssert: Codeunit "Library Assert";
    begin
        // [GIVEN/WHEN/THEN] Pipeline validation — always passes
        LibraryAssert.IsTrue(true, 'Pipeline check passed');
    end;
}
