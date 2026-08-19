Class InvokeModule.Setup
{

/// Called after Compile phase. Sets a global marker to prove it ran.
/// During database install this should run — the DB is mounted after %Reload completes.
ClassMethod OnCompile() As %Status
{
    set ^InvokeTest("compile") = 1
    quit $$$OK
}

/// Called after Activate phase. Sets a global marker to prove it ran.
/// During database install this should run.
ClassMethod OnActivate() As %Status
{
    set ^InvokeTest("activate") = 1
    quit $$$OK
}

}
