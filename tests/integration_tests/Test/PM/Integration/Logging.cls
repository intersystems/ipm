Class Test.PM.Integration.Logging Extends Test.PM.Integration.Base
{

/// Base Module for these tests
Parameter BaseModule As String = "base-mod";

/// Dependency module for these tests
Parameter DepModule As String = "dep-mod";

/// Module with a non-existent dependency (to throw install errors)
Parameter BadModule As String = "bad-mod";

/// Module with an <Invoke> with an <UNDEFINED> error to interrupt execution of a command
Parameter InterruptModule As String = "execution-interrupt-mod";

/// Custom directory to use to store log files using the -output-file flag
Parameter CustomOutputDir As String = "/home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/logging/custom-dir/";

/// Default log file directory
Property DefaultLogFileDir As %String;

Method OnBeforeAllTests() As %Status
{
    // Set default property values
    set ..DefaultLogFileDir = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ "ipm-logs/" _ $namespace)

    // Setup repos for LockFile tests
    set sc = ##class(%IPM.Main).Shell("repo -delete-all")
    do $$$AssertStatusOK(sc,"Deleted all leftover repos from other tests successfully.")
    set sc = ##class(%IPM.Main).Shell("repo -n logging-test -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/logging/")
    do $$$AssertStatusOK(sc,"Created logging-test repo successfully.")
    return sc
}

Method OnAfterAllTests() As %Status
{
    // Delete repos for LockFile tests
    set sc = ##class(%IPM.Main).Shell("repo -delete -name logging-test")
    do $$$AssertStatusOK(sc,"Removed logging-test repo successfully.")
    return sc
}

Method OnAfterOneTest() As %Status
{
    // Make test environment clean by uninstalling all modules at the end of each test
    set sc = ##class(%IPM.Main).Shell("uninstall -all")
    do $$$AssertStatusOK(sc, "Successfully uninstalled all modules after test")

    // Delete any log files created under either the default path or custom path
    set sc = ..CleanLogFileDir(..#CustomOutputDir)
    do $$$AssertStatusOK(sc, "Successfully deleted log files in the custom output directory")
    set sc = ..CleanLogFileDir(..DefaultLogFileDir)
    do $$$AssertStatusOK(sc, "Successfully deleted log files in the default output directory")
    return sc
}

/// Test install command and creation of log files at the default location
Method TestInstall()
{
    set commands = $listbuild("install -v " _ ..#BaseModule)
    do ..GenericLoggingTest(commands, ..DefaultLogFileDir)
}

/// Tests creation of a log file on the 'load' command
Method TestLoad()
{
    set commands = $listbuild("load /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/logging/v1/base-mod")
    do ..GenericLoggingTest(commands, ..DefaultLogFileDir)
}

/// Tests creation of a log file on the 'update' command
Method TestUpdate()
{
    set commands = $listbuild("install -no-log " _ ..#BaseModule _ " 1.0.0",
                       "update " _ ..#BaseModule _ " 2.0.0")
    do ..GenericLoggingTest(commands, ..DefaultLogFileDir)
}

/// Tests creation of a log file on the 'uninstall' command
Method TestUninstall()
{
    set commands = $listbuild("install -no-log " _ ..#BaseModule,
                       "uninstall -r " _ ..#BaseModule)
    do ..GenericLoggingTest(commands, ..DefaultLogFileDir)
}

/// Test that the -output-file command creates log files in a specified location
Method TestOutputPath()
{
    set commands = $listbuild("install -v -output-file " _ ..#CustomOutputDir _ " " _ ..#BaseModule)
    do ..GenericLoggingTest(commands, ..#CustomOutputDir)
}

/// Test that the -no-log flag does not create log files
Method TestNoLog()
{
    set command = "install -no-log " _ ..#BaseModule
    set sc = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusOK(sc, "Successfully installed " _ ..#BaseModule)

    set files = ..GetLogFilesInDir(..DefaultLogFileDir)
    do $$$AssertTrue($listlength(files.%Get("txt")) = 0, "No .txt log file created when -no-log flag provided")
    do $$$AssertTrue($listlength(files.%Get("json")) = 0, "No .json log file created when -no-log flag provided")
}

/// Tests log output in the case of an erroring IPM
/// Error cause: Install failure due to module referencing a dependency that it can't find in any repository
Method TestInstallFailure()
{
    set command = "install " _ ..#BadModule
    set sc = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusNotOK(sc, "Install failure on " _ ..#BadModule)

    // TODO: Add a check for erroring log file contents
}

/// Test log output in the case of the execution being interrupted
/// Error cause: <UNDEFINED> in method called via an <Invoke> on the module
Method TestExecutionInterrupted()
{
    set command = "install " _ ..#InterruptModule
    set sc = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusNotOK(sc, "Install interurpted on " _ ..#InterruptModule)

    // TODO: Add a check for erroring log file contents
}

/// Performs a generic logging test
/// Accepts a list of IPM command strings and runs each sequentially, checking their status
/// Then verifies the log files created using the logFileDir argument
/// Assumes that the last command (and that command only) is the one that creates the log files to be checked
Method GenericLoggingTest(
	commands As %List,
	logFileDir As %String)
{
    set lastCommand = ""
    set ptr = 0
    while $listnext(commands, ptr, cmd) {
        set sc = ##class(%IPM.Main).Shell(cmd)
        do $$$AssertStatusOK(sc, "Successfully ran command """ _ cmd _ """")
        set lastCommand = cmd
    }

    set files = ..GetLogFilesInDir(logFileDir)
    if ($listlength(files.%Get("txt")) '= 1) || ($listlength(files.%Get("json")) '= 1) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Expected exactly 1 .txt and 1 .json file in VerifyLogFilesInDirectory() but that was not the case"))
    }
    set txtLogFile = $listget(files.%Get("txt"), 1)
    set jsonLogFile = $listget(files.%Get("json"), 1)

    do ..VerifyTxtFileContents(txtLogFile, lastCommand)
    do ..VerifyJsonFileContents(jsonLogFile, lastCommand)
}

/// Retreives a list of names for files/directories under the directory provided
ClassMethod GetLogFilesInDir(directory As %String) As %DynamicObject [ Internal ]
{
    set files = {}

    // Compile all .txt files
    set txtFiles = ""
    set file = $zsearch(directory _ "*.txt")
    while file '="" {
        set txtFiles = txtFiles _ $listbuild(file)
        set file = $zsearch("")
    }

    // Compile all .json files
    set jsonFiles = ""
    set file = $zsearch(directory _ "*.json")
    while file '="" {
        set jsonFiles = jsonFiles _ $listbuild(file)
        set file = $zsearch("")
    }

    do files.%Set("txt", txtFiles)
    do files.%Set("json", jsonFiles)
    return files
}

/// Verifies the contents of a .txt log file at a given path and command that created the file
/// Log files that are expected to have special output should not be checked using this method
Method VerifyTxtFileContents(
	fileName As %String,
	command As %String = "") [ Internal ]
{
    // Verify top-level info
    set expectedIPMVersion = "IPM Version: " _ ##class(%IPM.Storage.Module).NameOpen("zpm").VersionString
    set expectedSchemaVersion = "Schema Version: 1.0.0"
    set expectedCommand = "Command: """ _ command _ """"
    set stream = ##class(%Stream.FileCharacter).%New()
    set sc = stream.LinkToFile(fileName)
    set txtVersion = $zstrip(stream.ReadLine(), "*C")
    set txtSchema = $zstrip(stream.ReadLine(), "*C")
    set txtCommand = $zstrip(stream.ReadLine(), "*C")
    do $$$AssertEquals(txtVersion, expectedIPMVersion, "IPM version in txt file matches expected value")
    do $$$AssertEquals(txtSchema, expectedSchemaVersion, "Schema version in txt file matches expected value")
    do $$$AssertEquals(txtCommand, expectedCommand, "Command in txt file matches expected value")

    // Verify end message
    set expectedEndMessage = "[INFO] Logging COMPLETE"
    while 'stream.AtEnd {
        set lastLine = stream.ReadLine()
    }
    do $$$AssertEquals(lastLine, expectedEndMessage, "End message is present in the txt log file")
}

/// Verifies the contents of a .json log file at a given path and command that created the file
/// Log files that are expected to have special output should not be checked using this method
Method VerifyJsonFileContents(
	fileName As %String,
	command As %String = "") [ Internal ]
{
    // Verify top-level info
    set expectedIPMVersion = ##class(%IPM.Storage.Module).NameOpen("zpm").VersionString
    set expectedSchemaVersion = "1.0.0"
    set expectedCommand = command
    set json = ##class(%DynamicAbstractObject).%FromJSONFile(fileName)
    do $$$AssertEquals(json.%Get("ipm"), expectedIPMVersion, "IPM version in json file matches expected value")
    do $$$AssertEquals(json.%Get("schema"), expectedSchemaVersion, "Schema version in json file matches expected value")
    do $$$AssertEquals(json.%Get("command"), expectedCommand, "Command in json file matches expected value")

    // Verify end message
    set endMessage = json.%Get("log").%Pop()
    set endMessageIsAsExpected = (endMessage.%Get("level") = "INFO") && (endMessage.%Get("message") = "Logging COMPLETE")
    do $$$AssertTrue(endMessageIsAsExpected, "End message is present in the json log file")
}

/// For a given directory, deletes the log files in that location (.txt and .json files)
ClassMethod CleanLogFileDir(directory As %String) As %Status [ Internal ]
{
    set sc = $$$OK
    try {
        // Delete all .txt files
        set file = $zsearch(directory _ "*.txt")
        while file '="" {
            do ##class(%File).Delete(file)
            set file = $zsearch("")
        }

        // Delete all .json files
        set file = $zsearch(directory _ "*.json")
        while file '="" {
            do ##class(%File).Delete(file)
            set file = $zsearch("")
        }
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    return sc
}

}
