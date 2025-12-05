Class Test.PM.Integration.WebApplicationExport Extends Test.PM.Integration.Base
{

/// Test that a module with a WebApplication resource containing a Path attribute
/// can be packaged/published without encountering error 6080
/// (Can not export '<path>' type in %RO format)
Method TestWebApplicationWithPathExport()
{
	new $namespace
	set oldNamespace = $namespace

	set status = $$$OK
	try {
		set testRoot = $get(^UnitTestRoot)

		// Load the test module using Shell command
		set moduleDirectory = ..GetModuleDir("webapp-export-test")
		set status = ##class(%IPM.Main).Shell("load -v " _ moduleDirectory)
		do $$$AssertStatusOK(status, "Loaded webapp-export-test module successfully.")

		// Verify the WebApplication was created with the correct Path
		set $namespace = "%SYS"
		do $$$AssertTrue(##class(Security.Applications).Exists("/webapp-export-test"), "WebApplication /webapp-export-test was created")

		set status = ##class(Security.Applications).Get("/webapp-export-test", .props)
		do $$$AssertStatusOK(status, "Retrieved WebApplication properties")

		// Verify Path property was evaluated correctly
		// {$cspdir} evaluates to $system.Util.InstallDirectory()_"csp"
		set expectedPath = ##class(%File).NormalizeDirectory($system.Util.InstallDirectory()_"csp/webapp-export-test")
		do $$$AssertEquals(props("Path"), expectedPath, "WebApplication Path was set correctly")

		set $namespace = oldNamespace
		// Set up ORAS/Zot repository for publishing
		set status = ##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000")
		do $$$AssertStatusOK(status, "Successfully configured ORAS repository")

		// Publish the module - this is where error 6080 would have occurred before the fix
		set status = ##class(%IPM.Main).Shell("publish webapp-export-test -r zot -v")
		do $$$AssertStatusOK(status, "Successfully published module with WebApplication containing Path attribute")

		// Uninstall the local module to test installation from the published package
		set status = ##class(%IPM.Main).Shell("uninstall webapp-export-test")
		do $$$AssertStatusOK(status, "Successfully uninstalled local webapp-export-test module")

		// Verify WebApplication was removed
		set $namespace = "%SYS"
		do $$$AssertNotTrue(##class(Security.Applications).Exists("/webapp-export-test"), "WebApplication /webapp-export-test was removed after uninstall")

		set $namespace = oldNamespace

		// Install the module from the zot repository
		set status = ##class(%IPM.Main).Shell("install -v zot/webapp-export-test")
		do $$$AssertStatusOK(status, "Successfully installed webapp-export-test from zot repository")

		// Verify the WebApplication was recreated with the correct Path
		set $namespace = "%SYS"
		do $$$AssertTrue(##class(Security.Applications).Exists("/webapp-export-test"), "WebApplication /webapp-export-test was recreated from published package")

		set status = ##class(Security.Applications).Get("/webapp-export-test", .propsAfterInstall)
		do $$$AssertStatusOK(status, "Retrieved WebApplication properties after installation from zot")

		// Verify Path is still set correctly after round-trip through publish/install
		do $$$AssertEquals(propsAfterInstall("Path"), expectedPath, "WebApplication Path is still correct after publish/install round-trip")

		set $namespace = oldNamespace

		// Clean up: delete the repository
		set status = ##class(%IPM.Main).Shell("repo -delete -n zot")
		do $$$AssertStatusOK(status, "Successfully deleted ORAS repository")

		// Clean up: uninstall the module
		set status = ##class(%IPM.Main).Shell("uninstall webapp-export-test")
		do $$$AssertStatusOK(status, "Successfully uninstalled webapp-export-test")

		// Verify WebApplication was cleaned up
		set $namespace = "%SYS"
		do $$$AssertNotTrue(##class(Security.Applications).Exists("/webapp-export-test"), "WebApplication /webapp-export-test was cleaned up")

	} catch e {
		do $$$AssertStatusOK(e.AsStatus(), "An exception occurred.")
	}

	set $namespace = oldNamespace
}

}
