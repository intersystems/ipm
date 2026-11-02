Class Test.PM.Unit.Robocopy Extends %UnitTest.TestCase
{

Method TestCommandNotRun()
{
    try {
        do ##class(%IPM.Utils.File).RunRobocopy($listbuild("ipm-nonexistent-command"), "")
        do $$$AssertFailure("No error thrown for a command that could not run")
    } catch e {
        do $$$AssertStatusNotOK(e.AsStatus())
    }
}

Method TestSuccessExitCode()
{
    do ##class(%IPM.Utils.File).RunRobocopy(..ExitCommand(7), "")
    do $$$AssertSuccess("Exit code 7 accepted")
}

Method TestFailureExitCode()
{
    try {
        do ##class(%IPM.Utils.File).RunRobocopy(..ExitCommand(8), "")
        do $$$AssertFailure("No error thrown for exit code 8")
    } catch e {
        do $$$AssertStatusNotOK(e.AsStatus())
    }
}

/// Returns a command $list that exits with <var>code</var>, standing in for ROBOCOPY.
ClassMethod ExitCommand(code As %Integer) As %List
{
    if $$$isWINDOWS {
        return $listbuild("cmd", "/c", "exit " _ code)
    }
    return $listbuild("sh", "-c", "exit " _ code)
}

}
