Class Test.PM.Integration.ExportPythonWheel Extends Test.PM.Integration.Base
{

/// A reference to Python's sys.path
Property PythonPath As %SYS.Python;

/// A copy of the original sys.path
Property PythonPathCopy As %SYS.Python;

/// Run by <B>RunTest</B> once after all test methods in the test class are run. Can be used to tear down a test environment that was set up by <B>OnBeforeAllTests</B> See example in <b>OnBeforeAllTests</b>. 
Method OnAfterAllTests() As %Status
{
    Set copy = ##class(%SYS.Python).Import("copy")
    Set PythonPath = copy.deepcopy(..PythonPathCopy)
    Quit $$$OK
}

/// Run by <B>RunTest</B> once <a href="#OnBeforeAll">before any test methods</a> in the test class are run. Can be used to set up a 
/// test environment that will be later cleaned up by <B>OnAfterAllTests</B>. 
/// <br>NOTE: OnBeforeAllTests does not currently support skipping tests.  Calls to $$$AssertSkipped in
/// OnBeforeAllTests may result in tests appearing to pass rather than being skipped.
/// <br><br>Example: Setup and Cleanup of an environment: 
/// <pre>
/// Method OnBeforeAllTests() As %Status
/// {
/// 	//do setup stuff here
///  	set ^inputMessage = "input message"
/// 	quit $$$OK
/// }
/// Method OnAfterAllTests() As %Status
/// {
/// 	//do clean up stuff here
/// 	kill ^inputMessage
/// 	quit $$$OK
/// }</pre>
/// 
Method OnBeforeAllTests() As %Status
{
    Set sys = ##class(%SYS.Python).Import("sys")
    Set ..PythonPath = sys.path

    Set copy = ##class(%SYS.Python).Import("copy")
    Set ..PythonPathCopy = copy.deepcopy(sys.path)

    Quit $$$OK
}

Method TestExportPythonWheel()
{
    Set package = "oras"
    Set outputDirectory = $$$FileTempDir
    Set bundleName = "my-oras-bundle"
    Set bundleVersion = "0.1.0"

    // Export all dependencies of ORAS along with ORAS itself
    Set deps = ##class(%IPM.Utils.EmbeddedPython).ListDependencies(package, 1, 1)
    Do ##class(%IPM.Utils.EmbeddedPython).BundleWheel(deps, outputDirectory, bundleName, bundleVersion)

    // There should be one and only one file - the wheel
    set rs = ##class(%File).FileSetFunc(outputDirectory)
    Do $$$AssertTrue(rs.%Next())
    Do $$$AssertEquals(rs.Type, "F")
    Set wheelPath = rs.Name
    Do $$$AssertNotTrue(rs.%Next())

    // Try install the wheel to another directory
    Set pipCaller = ##class(%IPM.Lifecycle.Base).ResolvePipCaller()
    // Create a temporary directory for installing the wheel to
    Set targetInstallDir = $$$FileTempDir
    Set command = pipCaller _ $ListBuild("install", wheelPath, "-t", targetInstallDir)
    Set tSC = ##class(%IPM.Utils.Module).RunCommand(, command, .stdout)
    Do $$$AssertStatusOK(tSC, "Successfully installed the wheel")

    // Exclude mgr/python from sys.path and include targetInstallDir to check if the installed wheel works
    Set mgrPython = ##class(%File).NormalizeDirectory("python", ##class(%File).ManagerDirectory())
    Set mgrPython = $Extract(mgrPython, 1, *-1) // Remove trailing slash
    Do ..PythonPath.remove(mgrPython)
    Do ..PythonPath.append(targetInstallDir)
    Try {
        // At this point, oras might be already in sys.modules cache because it was used by something else in this process
        // but if it's not, we import it here so that we can use importlib.reload() with updated sys.path
        Set oras = ##class(%SYS.Python).Import("oras")
        Set importlib = ##class(%SYS.Python).Import("importlib")
        Set oras = importlib.reload(oras)

        Do $$$AssertTrue(oras."__file__" [ targetInstallDir, "oras is imported from the installed wheel")

        // revert oras back to the original one
        Do ..PythonPath.remove(targetInstallDir)
        Do ..PythonPath.append(mgrPython)
        Set oras = importlib.reload(oras)
    } Catch ex {
        Do $$$AssertFailure("Failed to import oras: "_ex.AsStatus())
    }

    // Clean up temporary directories
    Do ##class(%File).RemoveDirectoryTree(outputDirectory)
    Do ##class(%File).RemoveDirectoryTree(targetInstallDir)
}

}
