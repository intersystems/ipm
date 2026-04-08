Class InvokeModule.Setup
{

/// Called after Compile phase. Sets a global marker to prove it ran.
/// During database install this should be skipped (pre-Activate).
ClassMethod OnCompile() As %Status
{
    set ^InvokeTest("compile") = 1
    quit $$$OK
}

/// Called after Activate phase. Sets a global marker to prove it ran.
/// During database install this should run (post-swap).
ClassMethod OnActivate() As %Status
{
    set ^InvokeTest("activate") = 1
    quit $$$OK
}

}
