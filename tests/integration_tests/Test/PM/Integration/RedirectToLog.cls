Include %IPM.Common

/// Tests functionality of ##class(%IPM.General.LogManager).BeginChainedCaptureToLog() and ##class(%IPM.General.LogManager).EndChainedCaptureToLog() methods
Class Test.PM.Integration.RedirectToLog Extends Test.PM.Integration.Base
{

Parameter NEEDSREGISTRY As BOOLEAN = 0;

Parameter LoadingClass = "Test.PM.Integration.Data.RedirectionToLog.LoadClasses";

/// Fully-qualified name of the class the runner loads; its compile output names it on the device.
Parameter TargetClass = "Test.PM.Integration.Data.RedirectionToLog.Target";

/// Fully-qualified name of a class whose compile fails; its error output names it on the device.
Parameter ErrorTargetClass = "Test.PM.Integration.Data.RedirectionToLog.ErrorTarget";

Property LoadedClasses [Multidimensional];

Method OnBeforeOneTest(testname As %String) As %Status
{
    // Reset any log state leaked from an earlier suite before this test initializes its own.
    $$$ThrowOnError(##class(%IPM.General.LogManager).EndChainedCaptureToLog())
    do ##class(%IPM.General.LogManager).%Get().Finalize()
    return $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
    // Guard against a leaked capture or open log carrying into later tests.
    $$$ThrowOnError(##class(%IPM.General.LogManager).EndChainedCaptureToLog())
    do ##class(%IPM.General.LogManager).%Get().Finalize()
    set name = ""
    for {
        set name = $order(..LoadedClasses(name))
        quit:name=""
        $$$ThrowOnError($system.OBJ.Delete(name, "-d"))
    }
    kill ..LoadedClasses
    return $$$OK
}

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
    do $$$AssertNotTrue($data($$$IPMLogCapture), "Chained capture state WAS cleared after the failed command")

    // Clean up
    do ##class(%IPM.Main).Shell("uninstall redirect-error-module -r")
    do $system.OBJ.Delete("RedirectErrorModule.Trigger", "-d")
}

ClassMethod InitLog(
	log As %IPM.General.LogManager) [ Private ]
{
    kill cmd
    set cmd = "install"
    set cmd("data","Verbose") = 0
    $$$ThrowOnError(log.InitializeLog("install test", .cmd))
}

}
