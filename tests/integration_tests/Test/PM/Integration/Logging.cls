Class Test.PM.Integration.Logging Extends Test.PM.Integration.Base
{

/// Base Module for these tests
Parameter BaseModule As String = "base-mod";

/// Dependency module for these tests
Parameter DepModule As String = "dep-mod";

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
Method TestDefaultInstall()
{
    // Execute a generic install test using default paths
    do ..GenericInstallTest(0)
}

/// Test that the -output-file command creates log files in a specified location
Method TestOutputPath()
{
    // Execute a generic install test using custom paths
    do ..GenericInstallTest(1)
}

/// Test that the -no-log flag does not create log files
Method TestNoLog()
{
    set command = "install -v -no-log " _ ..#BaseModule
    set sc = ##class(%IPM.Main).Shell("install -v " _ ..#BaseModule)
    do $$$AssertStatusOK(sc, "Successfully installed " _ ..#BaseModule)

    set ..DefaultLogFileDir = "/home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/logging/custom-dir/"
    set files = ..GetLogFilesInDir(..DefaultLogFileDir)
    set txtLogFile = files.%Get("txt")
    set jsonLogFile = files.%Get("json")

    do $$$AssertTrue(txtLogFile = "", "No .txt log file created when -no-log flag provided")
    do $$$AssertTrue(jsonLogFile = "", "No .json log file created when -no-log flag provided")
}

/// Performs a generic install test
/// Checks that the install creates the .txt and .json log files and verifies their contents
Method GenericInstallTest(useCustomPathing As %Boolean = 0)
{
    if (useCustomPathing) {
        set command = "install -v -output-file " _ ..#CustomOutputDir _ " " _ ..#BaseModule
        set command = "install -v " _ ..#BaseModule
        set logFileDir = ..#CustomOutputDir
    } else {
        set command = "install -v " _ ..#BaseModule
        set logFileDir = ..DefaultLogFileDir
    }

    set sc = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusOK(sc, "Successfully installed " _ ..#BaseModule)

    set files = ..GetLogFilesInDir(logFileDir)
    set txtLogFile = files.%Get("txt")
    set jsonLogFile = files.%Get("json")

    do ..VerifyTxtFileContents(txtLogFile, command)
    do ..VerifyJsonFileContents(jsonLogFile, command)
}

Method VerifyTxtFileContents(
	fileName As %String,
	command As %String = "")
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
    do $$$AssertEquals(txtVersion, expectedIPMVersion, "IPM version in json file matches expected value")
    do $$$AssertEquals(txtSchema, expectedSchemaVersion, "Schema version in json file matches expected value")
    do $$$AssertEquals(txtCommand, expectedCommand, "Command in json file matches expected value")

    // Verify end message
    set expectedEndMessage = "[INFO] Logging COMPLETE"
    while 'stream.AtEnd {
        set lastLine = stream.ReadLine()
    }
    do $$$AssertEquals(lastLine, expectedEndMessage, "End message is present in the txt log file")
}

Method VerifyJsonFileContents(
	fileName As %String,
	command As %String = "")
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

/// Retreives a list of names for files/directories under the directory provided
/// Providing a prefix or suffix allows further filtering of the results inside the given directory
ClassMethod GetLogFilesInDir(directory As %String) As %DynamicObject
{
    set files = {}
    do files.%Set("txt", $zsearch(directory _ "*.txt"))
    do files.%Set("json", $zsearch(directory _ "*.json"))
    return files
}

/// For a given directory, deletes the log files in that location (.txt and .json files)
ClassMethod CleanLogFileDir(directory As %String) As %Status
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
