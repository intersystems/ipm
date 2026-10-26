/// Fails to compile because its superclass does not exist; importing it emits compile errors
/// naming this class on the device, which the test looks for in the log and terminal capture.
Class Test.PM.Integration.Data.RedirectionToLog.ErrorTarget Extends Test.PM.Integration.Data.RedirectionToLog.Missing
{

}
