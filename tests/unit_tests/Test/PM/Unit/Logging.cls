Include (%IPM.Common, %IPM.Formatting)

Class Test.PM.Unit.Logging Extends %UnitTest.TestCase
{

Method OnAfterOneTest() As %Status
{
    do ..KillLogManagerSingleton()
    return $$$OK
}

/// Tests that InitializeLog() creates the .txt and .jsonl log files
Method TestInstantiation()
{
    set logMgr = ##class(%IPM.General.LogManager).%Get()

    // Replicating a commandInfo object for this test
    set command = "install logging-test"
    set commandInfo = "install"
    set commandInfo("logMgr") = logMgr
    set commandInfo("parameters","module") = "logging-test"

    set sc = logMgr.InitializeLog(command, .commandInfo)
    do $$$AssertStatusOK(sc, "Log manager initializes successfully.")
    do $$$AssertTrue(logMgr.Initialized, "Log manager is marked as initialized.")
}

/// Tests that InitializeLog() does not create the .txt and jsonl log files when no commandInfo is provided
Method TestInstantiationWithoutCommandInfo()
{
    set logMgr = ##class(%IPM.General.LogManager).%Get()

    // Setting a command for this test but no commandInfo
    set command = "install logging-test"

    set sc = logMgr.InitializeLog(command, .commandInfo)
    do $$$AssertStatusOK(sc, "Log manager initializes without command info.")
    do $$$AssertNotTrue(logMgr.Initialized, "Log manager is marked as not initialized when no commandInfo given.")
}

/// Tests writing to the log files with various log levels and scenarios
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
    set message = "test log message"
    set sc = logMgr.WriteLogLine(message, $$$Info)
    do $$$AssertStatusOK(sc, "Writing a valid log line succeeds.")
    set stream=##class(%Stream.FileCharacter).%New()
    do stream.LinkToFile(logMgr.TxtFilePath)
    set contents = stream.Read(5000)
    do $$$AssertTrue(contents[message, "Log file contains the written message.")

    // Writing a log line with an invalid level should fail
    set sc = logMgr.WriteLogLine("Invalid Log Level", "INVALID")
    do $$$AssertStatusNotOK(sc, "Writing a log line with an invalid level fails.")

    // Writing a log line with an un-initialized log manager should succeed and not care about log level
    do ..KillLogManagerSingleton()
    set sc = logMgr.WriteLogLine("Un-initialized log manager test", "INVALID")
    do $$$AssertStatusOK(sc, "Writing a log line with an un-initialized log manager succeeds.")
}

/// Tests writing formatted text to the log files
Method TestFormattedText()
{
    // Instantiate log manager before writing to logs
    set logMgr = ##class(%IPM.General.LogManager).%Get()
    set command = "install logging-test"
    set commandInfo = "install"
    set commandInfo("logMgr") = logMgr
    set commandInfo("parameters","module") = "logging-test"
    set commandInfo("data", "LogFileDir") = "/home/irisowner/zpm/output-logs/"
    $$$ThrowOnError(logMgr.InitializeLog(command, .commandInfo))

    set line = $$$FormattedLine($$$Yellow, "WARNING: Command  does not exist so showing all available commands.")
    set sc = logMgr.WriteLogLine(line, "WARNING")
}

/// Kills the log manager singleton to ensure that subsequent tests start with a fresh instance
ClassMethod KillLogManagerSingleton()
{
    kill ^||%IPM.Singleton("%IPM.General.LogManager",$namespace)
}

}
