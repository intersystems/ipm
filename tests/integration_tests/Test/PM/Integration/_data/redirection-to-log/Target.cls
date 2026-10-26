/// Trivial class loaded by <class>Test.PM.Integration.Data.RedirectionToLog.LoadRunner</class>;
/// compiling it names this class on the device, which the test looks for in the log.
Class Test.PM.Integration.Data.RedirectionToLog.Target Extends %RegisteredObject
{

ClassMethod Ping() As %String
{
    return "pong"
}

}
