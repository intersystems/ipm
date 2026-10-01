Class Test.PM.Integration.Logging Extends Test.PM.Integration.Base
{

/// Base Module for these tests
Parameter BaseModule As String = "base-mod";

/// Dependency module for these tests
Parameter DepModule As String = "dep-mod";

/// Module with a non-existent dependency (to throw install errors)
Parameter NonExistentDepMod As String = "non-existent-dep-mod";

/// Module with an <Invoke> with an <UNDEFINED> error to interrupt execution of a command
Parameter InterruptModule As String = "execution-interrupt-mod";

/// Custom directory to use to store log files using the -output-file flag
Parameter CustomOutputDir As String = "/home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/logging/custom-dir/";

/// Default log file directory
Property DefaultLogFileDir As %String;

Method OnBeforeAllTests() As %Status
{
    set sc = $$$OK
    try {
        // Set default property values
        set ..DefaultLogFileDir = ##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory() _ $zconvert($namespace, "l") _ "/" _ "ipm-logs/")

        // Setup repos for LockFile tests
        $$$ThrowOnError(##class(%IPM.Main).Shell("repo -delete-all"))
        $$$ThrowOnError(##class(%IPM.Main).Shell("repo -n logging-test -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/logging/"))

        // Delete any log files that may already exist
        $$$ThrowOnError(..CleanLogFileDir(..#CustomOutputDir))
        $$$ThrowOnError(..CleanLogFileDir(..DefaultLogFileDir))
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

Method OnAfterAllTests() As %Status
{
    set sc = $$$OK
    try {
        // Delete repos for LockFile tests
        $$$ThrowOnError(##class(%IPM.Main).Shell("repo -delete -name logging-test"))
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

Method OnAfterOneTest() As %Status
{
    set sc = $$$OK
    try {
        // Make test environment clean by uninstalling all modules at the end of each test
        $$$ThrowOnError(##class(%IPM.Main).Shell("uninstall -all"))

        // Delete any log files created under either the default path or custom path
        $$$ThrowOnError(..CleanLogFileDir(..#CustomOutputDir))
        $$$ThrowOnError(..CleanLogFileDir(..DefaultLogFileDir))
    } catch ex {
        set sc = ex.AsStatus()
    }
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
    set commands = $listbuild("install -v -output-log " _ ..#CustomOutputDir _ " " _ ..#BaseModule)
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
    do $$$AssertTrue($listlength(files.%Get("jsonl")) = 0, "No .jsonl log file created when -no-log flag provided")
}

/// Tests log output in the case of an erroring IPM
/// Error cause: Install failure due to module referencing a dependency that it can't find in any repository
Method TestInstallFailure()
{
    set command = "install " _ ..#NonExistentDepMod
    set sc = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusNotOK(sc, "Install failure on " _ ..#NonExistentDepMod)

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
/// 
/// Argument   commands    List of IPM command strings to be executed sequentially, with the last one expected to create the log files.
/// Argument   logFileDir  Directory where log files are expected to be created.
Method GenericLoggingTest(
	commands As %List,
	logFileDir As %String)
{
    set lastCommand = ""
    set ptr = 0
    while $listnext(commands, ptr, cmd) {
        $$$ThrowOnError(##class(%IPM.Main).Shell(cmd))
        set lastCommand = cmd
    }

    set files = ..GetLogFilesInDir(logFileDir)
    if ($listlength(files.%Get("txt")) '= 1) || ($listlength(files.%Get("jsonl")) '= 1) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Expected exactly 1 .txt and 1 .jsonl file in VerifyLogFilesInDirectory() but that was not the case"))
    }
    set txtLogFile = $listget(files.%Get("txt"), 1)
    set jsonlLogFile = $listget(files.%Get("jsonl"), 1)

    do ..VerifyTxtFileContents(txtLogFile, lastCommand)
    do ..VerifyJsonlFileContents(jsonlLogFile, lastCommand)
}

/// Retrieves a %DynamicObject containing the names of .txt and .jsonl log files in the specified directory.
/// 
/// Return object:
/// {
///     "txt": <List of .txt log file names>,
///     "jsonl": <List of .jsonl log file names>
/// }
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

    // Compile all .jsonl files
    set jsonlFiles = ""
    set file = $zsearch(directory _ "*.jsonl")
    while file '="" {
        set jsonlFiles = jsonlFiles _ $listbuild(file)
        set file = $zsearch("")
    }

    do files.%Set("txt", txtFiles)
    do files.%Set("jsonl", jsonlFiles)
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
    set expectedCommand = "Command: '" _ command _ "'"
    set stream = ##class(%Stream.FileCharacter).%New()
    set sc = stream.LinkToFile(fileName)
    set txtVersion = $zstrip(stream.ReadLine(), "*C")
    set txtCommand = $zstrip(stream.ReadLine(), "*C")
    do $$$AssertTrue(txtVersion [ expectedIPMVersion, "IPM version in txt file matches expected value")
    do $$$AssertTrue(txtCommand [ expectedCommand, "Command in txt file matches expected value")

    // Verify end message
    set expectedEndMessage = "[INFO] Logging COMPLETE"
    while 'stream.AtEnd {
        set lastLine = stream.ReadLine()
    }
    do $$$AssertTrue(lastLine [ expectedEndMessage, "End message is present in the txt log file")
}

/// Verifies the contents of a .jsonl log file at a given path and command that created the file
/// Log files that are expected to have special output should not be checked using this method
Method VerifyJsonlFileContents(
	fileName As %String,
	command As %String = "") [ Internal ]
{
    // Verify top-level info
    set expectedIPMVersion = ##class(%IPM.Storage.Module).NameOpen("zpm").VersionString
    set expectedSchemaVersion = "https://raw.githubusercontent.com/intersystems/ipm/main/schemas/ipm-log/1.0.0"
    set expectedCommand = command

    set stream = ##class(%Stream.FileCharacter).%New()
    set sc = stream.LinkToFile(fileName)
    set header = $zstrip(stream.ReadLine(), "*C")
    while 'stream.AtEnd {
        set lastLine = stream.ReadLine()
    }

    set header = {}.%FromJSON(header)
    do $$$AssertEquals(header.%Get("ipm"), expectedIPMVersion, "IPM version in jsonl file matches expected value")
    do $$$AssertEquals(header.%Get("$schema"), expectedSchemaVersion, "Schema version in jsonl file matches expected value")
    do $$$AssertEquals(header.%Get("command"), expectedCommand, "Command in jsonl file matches expected value")

    // Verify end message
    set lastLine = {}.%FromJSON(lastLine)
    set endMessageIsAsExpected = (lastLine.%Get("level") = "INFO") && (lastLine.%Get("message") = "Logging COMPLETE")
    do $$$AssertTrue(endMessageIsAsExpected, "End message is present in the jsonl log file")
}

/// For a given directory, deletes the log files in that location (.txt and .jsonl files)
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

        // Delete all .jsonl files
        set file = $zsearch(directory _ "*.jsonl")
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
