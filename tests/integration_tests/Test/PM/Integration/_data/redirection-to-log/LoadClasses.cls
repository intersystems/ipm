Class Test.PM.Integration.Data.RedirectionToLog.LoadClasses
{

Parameter TargetClass = "Test.PM.Integration.Data.RedirectionToLog.Target";

/// Loads a file with the chained capture tee active, so its compile output is routed to the log.
/// Pass <var>writeToTerminal</var> = 1 to also echo the output down the redirect chain.
ClassMethod LoadWithCapture(
	file As %String,
	writeToTerminal As %Boolean = 0)
{
    do ##class(%IPM.General.LogManager).BeginChainedCaptureToLog(writeToTerminal)
    do $system.OBJ.Import(file, "ck")
    do ##class(%IPM.General.LogManager).EndChainedCaptureToLog()
}

/// Loads a file with no capture active, so its compile output reaches the terminal only.
ClassMethod LoadWithoutCapture(file As %String)
{
    do $system.OBJ.Import(file, "ck")
}

}
