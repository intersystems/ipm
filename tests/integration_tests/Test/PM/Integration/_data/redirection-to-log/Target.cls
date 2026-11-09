/// Target class to be loaded and compiled; trivial
Class Test.PM.Integration.Data.RedirectionToLog.Target Extends %RegisteredObject
{

ClassMethod Ping() As %String
{
    return "pong"
}

}
