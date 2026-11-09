Include %IPM.Common

/// Tests functionality of ##class(%IPM.General.LogManager).BeginChainedCaptureToLog() and ##class(%IPM.General.LogManager).EndChainedCaptureToLog() methods
Class Test.PM.Integration.RedirectToLog Extends Test.PM.Integration.Base
{

Parameter NEEDSREGISTRY As BOOLEAN = 0;

/// Class which uses $System methods to load another class
Parameter LoadingClass = "Test.PM.Integration.Data.RedirectionToLog.LoadClasses";

/// Fully-qualified name of the class the runner loads; its compile output names it on the device.
Parameter TargetClass = "Test.PM.Integration.Data.RedirectionToLog.Target";

/// Fully-qualified name of a class whose compile fails; its error output names it on the device.
Parameter ErrorTargetClass = "Test.PM.Integration.Data.RedirectionToLog.ErrorTarget";

Property LoadedClasses [Multidimensional];

Method OnBeforeOneTest(testname As %String) As %Status
{
    // Reset any log state leaked from an earlier suite before this test initializes its own.
    do ##class(%IPM.General.LogManager).EndChainedCaptureToLog()
    do ##class(%IPM.General.LogManager).%Get().Finalize()
    kill ^||%capture
    return $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
    // Guard against a leaked capture or open log carrying into later tests.
    do ##class(%IPM.General.LogManager).EndChainedCaptureToLog()
    do ##class(%IPM.General.LogManager).%Get().Finalize()
    set name = ""
    for {
        set name = $order(..LoadedClasses(name))
        quit:name=""
        $$$ThrowOnError($system.OBJ.Delete(name, "-d"))
    }
    kill ..LoadedClasses
    kill ^||%capture
    return $$$OK
}

/// Tests that an IRIS system call's output reaches the log only when it is wrapped in the chained capture.
Method TestLoadLoggedOnlyWhenWrapped()
{
    set dataDir = ..GetModuleDir("redirection-to-log")
    set loadingClassFile = dataDir _ "LoadClasses.cls"
    set classToLoadFile = dataDir _ "Target.cls"
    set ..LoadedClasses(..#LoadingClass) = ""
    set ..LoadedClasses(..#TargetClass) = ""

    // Compile test class
    $$$ThrowOnError($system.OBJ.Import(loadingClassFile, "ck"))

    set log = ##class(%IPM.General.LogManager).%Get(.sc)
    $$$ThrowOnError(sc)
    do ..InitLog(log)
    // Captured before Finalize, which clears TxtFilePath.
    set txtPath = log.TxtFilePath

    // Un-redirected IRIS system call: output goes to the terminal only, so the target is not yet in the log.
    do $classmethod(..#LoadingClass, "LoadWithoutCapture", classToLoadFile)
    do $$$AssertNotTrue(..FileContains(txtPath, ..#TargetClass), "unwrapped load output was NOT logged")

    // Redirected IRIS system call: the tee routes the same compile output into the log.
    do $classmethod(..#LoadingClass, "LoadWithCapture", classToLoadFile)
    do log.Finalize()
    do $$$AssertTrue(..FileContains(txtPath, ..#TargetClass), "wrapped load output WAS logged")
}

/// With verbosity off, a wrapped IRIS system call's output reaches the log but is withheld from the terminal.
Method TestNonVerboseLoggedButNotTerminal()
{
    set dataDir = ..GetModuleDir("redirection-to-log")
    set loadingClassFile = dataDir _ "LoadClasses.cls"
    set classToLoadFile = dataDir _ "Target.cls"
    set ..LoadedClasses(..#LoadingClass) = ""
    set ..LoadedClasses(..#TargetClass) = ""

    $$$ThrowOnError($system.OBJ.Import(loadingClassFile, "ck"))

    set log = ##class(%IPM.General.LogManager).%Get(.sc)
    $$$ThrowOnError(sc)
    do ..InitLog(log)
    set txtPath = log.TxtFilePath

    // Stand in for the terminal so we can prove the output was not echoed to it.
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    do $classmethod(..#LoadingClass, "LoadWithCapture", classToLoadFile)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .terminal)

    do log.Finalize()
    do $$$AssertTrue(..FileContains(txtPath, ..#TargetClass), "Wrapped load output in non-verbose mode WAS logged")
    do $$$AssertNotTrue(..FindStringInMultiDimArray(..#TargetClass, .terminal), "Wrapped load output in non-verbose mode was NOT echoed to the terminal")
}

/// A wrapped IRIS system call that fails routes its error into the log and echoes it to the terminal.
Method TestErrorLoggedAndEchoed()
{
    set dataDir = ..GetModuleDir("redirection-to-log")
    set loadingClassFile = dataDir _ "LoadClasses.cls"
    set erroringClassFile = dataDir _ "ErrorTarget.cls"
    set ..LoadedClasses(..#LoadingClass) = ""
    set ..LoadedClasses(..#ErrorTargetClass) = ""

    $$$ThrowOnError($system.OBJ.Import(loadingClassFile, "ck"))

    set log = ##class(%IPM.General.LogManager).%Get(.sc)
    $$$ThrowOnError(sc)
    do ..InitLog(log)
    set txtPath = log.TxtFilePath

    // Wrap the load in Begin/EndCaptureOutput so we can inspect what would be outputted to the terminal
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    do $classmethod(..#LoadingClass, "LoadWithCapture", erroringClassFile, 1)
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .terminal)

    do log.Finalize()
    do $$$AssertTrue(..FileContains(txtPath, "ERROR"), "Redirected compilation error WAS logged")
    do $$$AssertTrue(..FindStringInMultiDimArray("ERROR", .terminal), "Redirected compilation error WAS echoed to the terminal")
}

/// When an IPM command throws from an erroring IRIS system call wrapped in the chained capture tee,
/// the shell must still close the redirection: the command reports failure, interception is switched
/// off, the original I/O handler is restored, and the chained capture state is cleared.
Method TestCommandErrorRestoresRedirection()
{
    set moduleDir = ..GetModuleDir("redirect-error-module")

    // Record the redirection baseline so we can prove the shell handed control back after the failure.
    set originalRedirect = ##class(%Device).ReDirectIO()
    set originalHandler = $select(originalRedirect : $zutil(96, 12), 1 : "")

    // The module Invoke opens the tee and rethrows an erroring import; the shell catches it and reports failure.
    set sc = ##class(%IPM.Main).Shell("load -v " _ moduleDir)
    do $$$AssertStatusNotOK(sc, "Loading a module that throws from a wrapped IRIS system call WAS reported as an error")

    // The failed command must leave redirection exactly as it found it.
    set finalRedirect = ##class(%Device).ReDirectIO()
    do $$$AssertEquals(finalRedirect, originalRedirect, "Redirection state WAS restored after the failed command")
    set finalHandler = $select(finalRedirect : $zutil(96, 12), 1 : "")
    do $$$AssertEquals(finalHandler, originalHandler, "Original I/O handler WAS restored after the failed command")
    do $$$AssertNotTrue($data($$$IPMLogCapture("active")), "Chained capture state WAS cleared after the failed command")

    // Clean up
    do ##class(%IPM.Main).Shell("uninstall redirect-error-module -r")
    do $system.OBJ.Delete("RedirectErrorModule.Trigger", "-d")
}

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

    do $$$AssertTrue(..FindStringInMultiDimArray("Hello from within the tee", .outer), "Line WAS forwarded to the predecessor sink")

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

    do $$$AssertTrue(..FindStringInMultiDimArray("Inner only line", .inner), "Inner capture received only its own line")
    do $$$AssertTrue(..FileContains(txtPath, "Outer tee line one"), "Line written before the inner scope WAS routed to the log")
    do $$$AssertTrue(..FileContains(txtPath, "Outer tee line two"), "Line written after the inner scope WAS routed to the log")
    do $$$AssertNotTrue(..FileContains(txtPath, "Inner only line"), "Inner-captured line was NOT double-routed into the log")
}

/// A string with an embedded CRLF character (carriage return and newline) captured by the
/// redirection handler is correctly logged as two separate lines with control characters stripped
Method TestLineWithNewLineLoggedCleanly()
{
    set log = ##class(%IPM.General.LogManager).%Get(.sc)
    $$$ThrowOnError(sc)
    do ..InitLog(log)
    set txtPath = log.TxtFilePath

    do ##class(%IPM.General.LogManager).BeginChainedCaptureToLog(0)
    write "First line"_$char(13,10)_"Second line"
    do ##class(%IPM.General.LogManager).EndChainedCaptureToLog()
    do log.Finalize()

    set firstLine = ..GetLineInFile(txtPath, "First line")
    set secondLine = ..GetLineInFile(txtPath, "Second line")
    do $$$AssertNotEquals(firstLine, secondLine, "Redirected output with CRLF embedded in it IS split into separate log lines")
    do $$$AssertNotTrue(firstLine [ $char(13), "First logged line does NOT contain a carriage return")
    do $$$AssertNotTrue(secondLine [ $char(13), "Second logged line does NOT contain a carriage return")
}

/// A second, nested BeginChainedCaptureToLog should not have any effect on redirection.
Method TestNonReentrant()
{
    do ##class(%IPM.General.LogManager).BeginChainedCaptureToLog(1)
    do ##class(%IPM.General.LogManager).BeginChainedCaptureToLog(0)
    set writeToTerminal = $get($$$IPMLogCapture("writeToTerminal"))
    do ##class(%IPM.General.LogManager).EndChainedCaptureToLog()
    do $$$AssertEquals(writeToTerminal, 1, "Nested chained capture did NOT overwrite writeToTerminal")
}

/// Ending the chained log capture while a non-chained capture sits on top of it must not drop that capture, and once
/// the chained log capture's state is gone its reinstalled labels must not log any more lines.
Method TestEndWithHandlerOnTop()
{
    set log = ##class(%IPM.General.LogManager).%Get(.sc)
    $$$ThrowOnError(sc)
    do ..InitLog(log)
    set txtPath = log.TxtFilePath

    if ##class(%Device).ReDirectIO() {
        set originalIOHandler = $zutil(96,12)
    } else {
        set originalIOHandler = ""
    }

    do ##class(%IPM.General.LogManager).BeginChainedCaptureToLog()
    write "Tee line",!
    // Module capture layers on top of the active tee.
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    // Tee ends while the Module capture is still the top handler.
    do ##class(%IPM.General.LogManager).EndChainedCaptureToLog()
    write "After tee end",!
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .inner)
    do log.Finalize()

    if ##class(%Device).ReDirectIO() {
        set finalIOHandler = $zutil(96,12)
    } else {
        set finalIOHandler = ""
    }

    do $$$AssertEquals(finalIOHandler, originalIOHandler, "Original I/O handler WAS restored after the tee ended")

    do $$$AssertTrue(..FindStringInMultiDimArray("After tee end", .inner), "Module capture survived the tee teardown")
    do $$$AssertTrue(..FileContains(txtPath, "Tee line"), "Line written before teardown WAS logged")
    do $$$AssertNotTrue(..FileContains(txtPath, "After tee end"), "Stray line was NOT logged after the tee ended")
}

ClassMethod InitLog(
	log As %IPM.General.LogManager) [ Private ]
{
    kill cmd
    set cmd = "install"
    set cmd("data","Verbose") = 0
    set cmd("parameters","module") = "test"
    $$$ThrowOnError(log.InitializeLog("install test", .cmd))
}

}
