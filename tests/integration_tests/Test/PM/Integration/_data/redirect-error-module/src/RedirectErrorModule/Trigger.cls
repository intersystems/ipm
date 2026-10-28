Class RedirectErrorModule.Trigger
{

/// Opens the chained capture tee, then imports a non-existent file so the IRIS system call errors
/// and is rethrown before <method>EndChainedCaptureToLog</method> runs, leaving the redirection
/// open for the shell to close.
ClassMethod RaiseWrappedError()
{
    do ##class(%IPM.General.LogManager).BeginChainedCaptureToLog()
    $$$ThrowOnError($system.OBJ.Import("/non-existent/redirect-error-target.xml", "ck"))
    do ##class(%IPM.General.LogManager).EndChainedCaptureToLog()
}

}
