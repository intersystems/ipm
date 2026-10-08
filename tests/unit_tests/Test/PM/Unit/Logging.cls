Class Test.PM.Unit.Logging Extends %UnitTest.TestCase
{

Method OnAfterOneTest() As %Status
{
    do ..KillLogManagerSingleton()
    return $$$OK
}

Method TestInstantiation()
{
    set logMgr = ##class(%IPM.General.LogManager).%Get()

    // Replicating a commandInfo object for this test
    set command = "install logging-test"
    set commandInfo = "install"
    //set commandInfo("logMgr") = logMgr
    set commandInfo("parameters","module") = "logging-test"

    set sc = logMgr.InitializeLog(command, .commandInfo)
    do $$$AssertStatusOK(sc, "Log manager initializes successfully.")
    do $$$AssertTrue(logMgr.Initialized, "Log manager is marked as initialized.")
}

Method TestInstantiationWithoutCommandInfo()
{
    set logMgr = ##class(%IPM.General.LogManager).%Get()

    // Setting a command for this test but no commandInfo
    set command = "install logging-test"

    set sc = logMgr.InitializeLog(command, .commandInfo)
    do $$$AssertStatusOK(sc, "Log manager initializes without command info.")
    do $$$AssertNotTrue(logMgr.Initialized, "Log manager is marked as not initialized when no commandInfo given.")
}

Method TestWritingToLogs()
{
    // Instantiate log manager before writing to logs
    set logMgr = ##class(%IPM.General.LogManager).%Get()
    set command = "install logging-test"
    set commandInfo = "install"
    set commandInfo("logMgr") = logMgr
    set commandInfo("parameters","module") = "logging-test"
    $$$ThrowOnError(logMgr.InitializeLog(command, .commandInfo))

    // Writing a normal message should succeed
    set sc = ##class(%IPM.General.LogManager).WriteLogLine("test log message", "INFO")
    do $$$AssertStatusOK(sc, "Writing a valid log line succeeds.")

    // Writing a log line with an invalid level should fail
    set sc = ##class(%IPM.General.LogManager).WriteLogLine("Invalid Log Level", "INVALID")
    do $$$AssertStatusNotOK(sc, "Writing a log line with an invalid level fails.")

    // Writing a log line with an un-initialized log manager should succeed and not care about log level
    do ..KillLogManagerSingleton()
    set sc = ##class(%IPM.General.LogManager).WriteLogLine("Un-initialized log manager test", "INVALID")
    do $$$AssertStatusOK(sc, "Writing a log line with an un-initialized log manager succeeds.")
}

ClassMethod KillLogManagerSingleton()
{
    kill ^||%IPM.Singleton("%IPM.General.LogManager",$namespace)
}

}
