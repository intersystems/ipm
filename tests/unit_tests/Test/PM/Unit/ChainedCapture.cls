/// Unit tests for the chained redirected output capture methods in <class>%IPM.General.LogManager</class>:
/// it must route each captured line into the log while forwarding it live down the redirect
/// chain, and it must coexist with an already-active <class>%IPM.Utils.Module</class> capture.
Class Test.PM.Unit.ChainedCapture Extends %UnitTest.TestCase
{

/// Begin the tee under an outer capture with terminal forwarding on, write a line, and assert it
/// reached both the log (routing) and the outer capture buffer (forwarding intact).
Method TestVerboseChainedCapture()
{
    set log = ##class(%IPM.General.LogManager).%Get(.sc)
    $$$ThrowOnError(sc)
    do ..InitLog(log)
    set txtPath = log.TxtFilePath

    // BeginCaptureOutput stands in for the terminal / predecessor sink.
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    do ##class(%IPM.General.LogManager).BeginChainedCaptureToLog(1)
    write "Hello from within the tee",!
    do ##class(%IPM.General.LogManager).EndChainedCaptureToLog()
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .outer)

    do $$$AssertTrue(..ArrayContains(.outer, "Hello from within the tee"), "Line WAS forwarded to the predecessor sink")

    do log.Finalize()
    do $$$AssertTrue(..FileContains(txtPath, "Hello from within the tee"), "Line WAS routed to the .txt log")
}

/// Start a Module capture inside an active tee: the inner capture receives its own output,
/// the tee keeps routing the lines written outside the inner scope, and neither clobbers the other.
Method TestNonVerboseChainedCapture()
{
    set log = ##class(%IPM.General.LogManager).%Get(.sc)
    $$$ThrowOnError(sc)
    do ..InitLog(log)
    set txtPath = log.TxtFilePath

    do ##class(%IPM.General.LogManager).BeginChainedCaptureToLog(0)
    write "Outer tee line one",!
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    write "Inner only line",!
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .inner)
    write "Outer tee line two",!
    do ##class(%IPM.General.LogManager).EndChainedCaptureToLog()
    do log.Finalize()

    do $$$AssertTrue(..ArrayContains(.inner, "Inner only line"), "Inner capture received only its own line")
    do $$$AssertTrue(..FileContains(txtPath, "Outer tee line one"), "Line written before the inner scope WAS routed to the log")
    do $$$AssertTrue(..FileContains(txtPath, "Outer tee line two"), "Line written after the inner scope WAS routed to the log")
    do $$$AssertNotTrue(..FileContains(txtPath, "Inner only line"), "Inner-captured line was NOT double-routed into the log")
}

/// A second BeginChainedCaptureToLog while one is active must be rejected, not silently clobber state.
Method TestNonReentrant()
{
    $$$ThrowOnError(##class(%IPM.General.LogManager).BeginChainedCaptureToLog())
    set sc = ##class(%IPM.General.LogManager).BeginChainedCaptureToLog()
    $$$ThrowOnError(##class(%IPM.General.LogManager).EndChainedCaptureToLog())
    do $$$AssertStatusNotOK(sc, "Second chained capture WAS rejected while one is active")
}

/// Ending the tee while a Module capture sits on top of it must not drop that capture, and once
/// the tee's state is gone its reinstalled labels must not log stray lines.
Method TestEndWithHandlerOnTop()
{
    set log = ##class(%IPM.General.LogManager).%Get(.sc)
    $$$ThrowOnError(sc)
    do ..InitLog(log)
    set txtPath = log.TxtFilePath

    do ##class(%IPM.General.LogManager).BeginChainedCaptureToLog()
    write "Tee line",!
    // Module capture layers on top of the active tee.
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    // Tee ends while the Module capture is still the top handler.
    do ##class(%IPM.General.LogManager).EndChainedCaptureToLog()
    write "After tee end",!
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .inner)
    do log.Finalize()

    do $$$AssertTrue(..ArrayContains(.inner, "After tee end"), "Module capture survived the tee teardown")
    do $$$AssertTrue(..FileContains(txtPath, "Tee line"), "Line written before teardown WAS logged")
    do $$$AssertNotTrue(..FileContains(txtPath, "After tee end"), "Stray line was NOT logged after the tee ended")
}

/// Initialize the LogManager log files for a synthetic supported command.
ClassMethod InitLog(log As %IPM.General.LogManager) [ Private ]
{
    kill cmd
    set cmd = "install"
    set cmd("data","Verbose") = 0
    $$$ThrowOnError(log.InitializeLog("install test", .cmd))
}

ClassMethod ArrayContains(
	ByRef array,
	needle As %String) As %Boolean [ Private ]
{
    set key = ""
    for {
        set key = $order(array(key), 1, line)
        quit:key=""
        if ($get(line) [ needle) {
            return 1
        }
    }
    return 0
}

ClassMethod FileContains(
	path As %String,
	needle As %String) As %Boolean [ Private ]
{
    set stream = ##class(%Stream.FileCharacter).%New()
    set stream.Filename = path
    while 'stream.AtEnd {
        if (stream.ReadLine() [ needle) {
            return 1
        }
    }
    return 0
}

}
