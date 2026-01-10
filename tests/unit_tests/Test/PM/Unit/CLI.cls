/// Unit tests for the "zpm" command line (although not using the "zpm" command itself)
Class Test.PM.Unit.CLI Extends %UnitTest.TestCase
{

Method TestParser()
{

	// Test cases
	set tCommands($increment(tCommands)) = "help -v repo"
	set tResults(tCommands)="help"
	set tResults(tCommands,"modifiers","verbose")=""
	set tResults(tCommands,"parameters","command")="repo"

	set tCommands($increment(tCommands)) = "repo -name UTFILE -fs -path ""C:\\Program Files\\stuff\\"" -depth 42"
	set tResults(tCommands)="repo"
	set tResults(tCommands,"modifiers","depth")=42
	set tResults(tCommands,"modifiers","filesystem")=""
	set tResults(tCommands,"modifiers","name")="UTFILE"
	set tResults(tCommands,"modifiers","path")="C:\Program Files\stuff\"

	set tCommands($increment(tCommands)) = "ZPM activate -dev -DUIFW.force=1"
	// Old behavior:
	/*
	Set tResults(tCommands)="module-action"
	Set tResults(tCommands,"parameters","actions")="activate -dev -DUIFW.force=1"
	Set tResults(tCommands,"parameters","module")="ZPM"
	*/
	set tResults(tCommands)="module-action"
	set tResults(tCommands,"parameters","actions")="activate"
	set tResults(tCommands,"parameters","module")="ZPM"
	set tResults(tCommands,"data","DeveloperMode")=1
	set tResults(tCommands,"data","UIFW","force")=1

	set tCommands($increment(tCommands)) = "ZPM clean install -dev -DUIFW.force=1 -DSomething=""quoted\"" value"""
	// Old behavior:
	/*
	Set tResults(tCommands)="module-action"
	Set tResults(tCommands,"parameters","actions")="clean install -dev -DUIFW.force=1 -DSomething=""quoted"" value"""
	Set tResults(tCommands,"parameters","module")="ZPM"
	*/
	set tResults(tCommands)="module-action"
	set tResults(tCommands,"parameters","actions")="clean install"
	set tResults(tCommands,"parameters","module")="ZPM"
	set tResults(tCommands,"data","DeveloperMode")=1
	set tResults(tCommands,"data","UIFW","force")=1
	set tResults(tCommands,"data","zpm","Something")="quoted"" value"
	set tResults(tCommands,"data","Something")="quoted"" value"

	set tCommands($increment(tCommands)) = "module-action isc-dev publish"
	set tResults(tCommands)="module-action"
	set tResults(tCommands,"parameters","actions")="publish"
	set tResults(tCommands,"parameters","module")="isc-dev"

	set tCommands($increment(tCommands)) = "list-installed -t"
	set tResults(tCommands)="list-installed"
	set tResults(tCommands,"modifiers","tree")=""

	set tCommands($increment(tCommands)) = "install SomeModule -synchronous"
	set tResults(tCommands)="install"
	set tResults(tCommands,"parameters","module")="SomeModule"
	set tResults(tCommands,"modifiers","synchronous")=""
	set tResults(tCommands,"modifiers","synchronous","deprecated")=1

	set tCommands($increment(tCommands)) = "install SomeModule 0.0.1-prerelease.42+snapshot"
	set tResults(tCommands)="install"
	set tResults(tCommands,"parameters","module")="SomeModule"
	set tResults(tCommands,"parameters","version")="0.0.1-prerelease.42+snapshot"

	set tCommands($increment(tCommands)) = "repo -r -n registry -url http://iris-test:52774/registry/ -user ""user"" -pass ""pass"""
	set tResults(tCommands)="repo"
	set tResults(tCommands,"modifiers","name")="registry"
	set tResults(tCommands,"modifiers","remote")=""
	set tResults(tCommands,"modifiers","url")="http://iris-test:52774/registry/"
	set tResults(tCommands,"modifiers","username")="user"
	set tResults(tCommands,"modifiers","password")="pass"

	/*
	Set tCommands($i(tCommands)) =
	Set tResults(tCommands)=
	Set tResults(tCommands,
	*/

    // defaulted dataValue (-v) followed by a valued modifier
    // Expect: -v -> data("Verbose")=1, and -env value goes to data("EnvFiles") (NOT into "Verbose")
    set tCommands($increment(tCommands)) = "install SomeModule -v -env C:\env1.json;C:\env2.json"
    set tResults(tCommands)="install"
    set tResults(tCommands,"parameters","module")="SomeModule"
    set tResults(tCommands,"data","Verbose")=1
    set tResults(tCommands,"data","EnvFiles")="C:\env1.json;C:\env2.json"

    // defaulted dataValue (-q) followed by a valued modifier
    // Expect: -q -> data("Verbose")=0, and -env captured correctly
    set tCommands($increment(tCommands)) = "install SomeModule -q -env /etc/env1.json;/etc/env2.json"
    set tResults(tCommands)="install"
    set tResults(tCommands,"parameters","module")="SomeModule"
    set tResults(tCommands,"data","Verbose")=0
    set tResults(tCommands,"data","EnvFiles")="/etc/env1.json;/etc/env2.json"

    // module-action + phase modifiers
    // Expect: -v sets data("Verbose")=1, -path goes to data("Path"), and -export-deps maps to data("ExportDependencies")
    set tCommands($increment(tCommands)) = "module-action MyModule package -v -path /tmp/pkg -export-deps 1"
    set tResults(tCommands)="module-action"
    set tResults(tCommands,"parameters","module")="MyModule"
    set tResults(tCommands,"parameters","actions")="package"
    set tResults(tCommands,"data","Verbose")=1
    set tResults(tCommands,"data","Path")="/tmp/pkg"
    set tResults(tCommands,"data","ExportDependencies")=1

    // defaulted dataValue (-dev) followed by a valued modifier
    // Expect: -dev -> data("DeveloperMode")=1, and -extra-pip-flags captured correctly
    set tCommands($increment(tCommands)) = "load -dev -extra-pip-flags ""--timeout 30"" C:\code\my-module\"
    set tResults(tCommands)="load"
    set tResults(tCommands,"parameters","path")="C:\code\my-module\"
    set tResults(tCommands,"data","DeveloperMode")=1
    set tResults(tCommands,"data","ExtraPipFlags")="--timeout 30"

    // Recognized alias should NOT mirror under data("zpm",...)
	// Expects no data("zpm","EnvFiles")
    set tCommands($increment(tCommands)) = "install SomeModule -env C:\a.json;C:\b.json"
    set tResults(tCommands)="install"
    set tResults(tCommands,"parameters","module")="SomeModule"
    set tResults(tCommands,"data","EnvFiles")="C:\a.json;C:\b.json"

    // Recognized alias with a preceding defaulted dataValue (-v) should NOT mirror under data("zpm",...)
    set tCommands($increment(tCommands)) = "install SomeModule -v -env /etc/a.json;/etc/b.json"
    set tResults(tCommands)="install"
    set tResults(tCommands,"parameters","module")="SomeModule"
    set tResults(tCommands,"data","Verbose")=1
    set tResults(tCommands,"data","EnvFiles")="/etc/a.json;/etc/b.json"

    // module-action with valued aliases; no zpm copies for aliases
    set tCommands($increment(tCommands)) = "module-action MyModule package -v -path /tmp/pkg -export-deps 1"
    set tResults(tCommands)="module-action"
    set tResults(tCommands,"parameters","module")="MyModule"
    set tResults(tCommands,"parameters","actions")="package"
    set tResults(tCommands,"data","Verbose")=1
    set tResults(tCommands,"data","Path")="/tmp/pkg"
    set tResults(tCommands,"data","ExportDependencies")=1

    // load with defaulted alias then valued alias; no zpm copy for alias
    set tCommands($increment(tCommands)) = "load -dev -extra-pip-flags ""--timeout 30"" C:\code\my-module\"
    set tResults(tCommands)="load"
    set tResults(tCommands,"parameters","path")="C:\code\my-module\"
    set tResults(tCommands,"data","DeveloperMode")=1
    set tResults(tCommands,"data","ExtraPipFlags")="--timeout 30"

    // Mix of -D and recognized alias
    set tCommands($increment(tCommands)) = "install SomeModule -DEnvFiles=/etc/one;/etc/two -env /etc/three;/etc/four"
    set tResults(tCommands)="install"
    set tResults(tCommands,"parameters","module")="SomeModule"
    set tResults(tCommands,"data","EnvFiles")="/etc/three;/etc/four"
    set tResults(tCommands,"data","zpm","EnvFiles")="/etc/one;/etc/two"

	// Verify output matches
	for i=1:1:tCommands {
		kill tParsedCommandInfo,tExpectedCommandInfo
		do $$$AssertStatusOK(##class(%IPM.Main).%ParseCommandInput(tCommands(i),.tParsedCommandInfo))
		merge tExpectedCommandInfo = tResults(i)
		if '$$$AssertTrue(..CompareArrays(.tParsedCommandInfo,.tExpectedCommandInfo,.tMessage),"Parsed correctly: "_tCommands(i)) {
			do $$$LogMessage(tMessage)
			write !,"Expected:",! zwrite tExpectedCommandInfo
			write !,"Actual:",! zwrite tParsedCommandInfo
		}
	}
}

Method TestRepository()
{
	// Cleanup
	do ..RunCommand("repo -delete-all")
	do ..RunCommand("repo -list")

	// Create repositories
	set tDir = ##class(%File).ManagerDirectory()
	do ##class(%Studio.General).GetWebServerPort(.tPort)
	set tUrl = "https://pm.community.intersystems.com/"
	do ..AssertNoException("repo -name UTFILE -fs -path "_tDir_" -depth 1")
	do ..AssertNoException("repo -n UTSERVER -r -url "_tUrl)
	do ..RunCommand("repo -list")

	// Update repositories
	do ..AssertNoException("repo -n UTFILE -fs -snapshots 0")
	do ..AssertNoException("repo -name UTSERVER -r -prereleases 0 -url http://registry/")
	do ..AssertNoException("repo -name TEST -r -prereleases 0 -url http://newregistry/ -publish 1")
	do ..RunCommand("repo -list")

	// Cleanup (again)
	do ..RunCommand("repo -n UTFILE -delete")
	do ..RunCommand("repo -name UTSERVER -delete")
	do ..RunCommand("repo -name TEST -delete")

	do ..RunCommand("repo -r -name registry -reset-defaults")
}

Method TestModifiers()
{
	do ..CompareModifiers("-export-deps 1", "reload","test-module")
	do ..CompareModifiers("-export-deps 1", "compile","test-module")
	do ..CompareModifiers("-export-deps 1", "test","test-module")
	do ..CompareModifiers("-path /my/path -env envPath", "package","test-module")
	do ..CompareModifiers("-env envPath -export-deps 1", "verify","test-module")
	do ..CompareModifiers("-path /my/path -env envPath -repo Repo -use-external-name 1", "publish","test-module")
	do ..CompareModifiers("-path /my/path -env envPath -recurse 1", "makedeployed","test-module")
}

Method CompareModifiers(
	commandModifiers As %String,
	phase As %String,
	module As %String)
{
	/// Test modifier support for lifecycle phases. Make sure ModuleAction and RunOnePhase have the same support
	do ##class(%IPM.Main).%ParseCommandInput(module_" "_phase_" "+commandModifiers,.info1)
	do ##class(%IPM.Main).%ParseCommandInput(phase_" "_module_" "+commandModifiers,.info2)

	if '$$$AssertTrue(..CompareArrays(.info1,.info2,.tMessage),"module-action and lifecycle phase allow for same modifiers") {
		do $$$LogMessage(tMessage)
		write !,"module-action accepted modifiers:",! zwrite info1
		write !,phase_" accepted modifiers:",! zwrite info2
	}
}

/// This method returns the %Status for checking the success or failure of executed commands.
Method RunCommand(pCommand As %String) As %Status
{
	set status = ##class(%IPM.Main).Shell(pCommand)
	do $$$LogMessage("Run command: "_pCommand)
    return status
}

Method AssertNoException(pCommand As %String)
{
	do ##class(%IPM.Main).ShellInternal(pCommand,.tException)
	if '$$$AssertEquals(tException,"","No exceptions occurred running command: "_pCommand) {
		do $$$LogMessage(tException.DisplayString())
	}
}

/// Returns true if arrays <var>first</var> and <var>second</var> have all the same subscripts and all
/// the same values at those subscripts. <br />
/// If <var>first</var> and <var>second</var> both happen to be either undefined or unsubscripted variables,
/// returns true if they're both undefined or have the same value.<br />
/// <var>pMessage</var> has details of the first difference found, if any.
/// See https://community.intersystems.com/post/best-way-compare-two-arrays-equality-same-subscripts-and-values
Method CompareArrays(
	ByRef first,
	ByRef second,
	Output pMessage) As %Boolean [ PublicList = (tRef1, tRef2, first, second) ]
{
    new tRef1,tRef2
    set pMessage = ""
    set tEqual = 1
    set tRef1 = "first"
    set tRef2 = "second"
    while (tRef1 '= "") || (tRef2 '= "") {
        #; See if the subscript is the same for both arrays.
        #; If not, one of them has a subscript the other doesn't, and they're not equal.
        if ($piece(tRef1,"first",2) '= $piece(tRef2,"second",2)) {
            set tEqual = 0
            set pMessage = "Different subscripts encountered by $Query: "_
                $case(tRef1,"":"<end>",:tRef1)_"; "_$case(tRef2,"":"<end>",:tRef2)
            quit
        }

        kill tRef1Value,tRef2Value
        set tRef1Data = $data(@tRef1,tRef1Value)
        set tRef2Data = $data(@tRef2,tRef2Value)
        #; See if the $Data values are the same for the two.
        #; This is really only useful to detect if one of the arrays is undefined on the first pass;
        #; $Query only returns subscripts with data.
        #; This will catch only one being defined, or one being an array and
        #; ​the other being a regular variable.
        if (tRef1Data '= tRef2Data) {
            set tEqual = 0
            set pMessage = "$Data("_tRef1_")="_tRef1Data_"; $Data("_tRef2_")="_tRef2Data
            quit
        } elseif (tRef1Data#2) && (tRef2Data#2) {
            #; See if the value at the subscript is the same for both arrays.
            #; If not, they're not equal.
            if (tRef1Value '= tRef2Value) {
                set tEqual = 0
                set pMessage = tRef1_"="_@tRef1_"; "_tRef2_"="_@tRef2
                quit
            }
        }

        set tRef1 = $query(@tRef1)
        set tRef2 = $query(@tRef2)
    }
    quit tEqual
}

/// Test that the 'list -python' command correctly retrieves and formats Python packages.
Method TestListPython() As %Status
{
    set sc = $$$OK
    set commandsList = $listbuild("list -python", "list -py", "list-installed -python", "list-installed -py")
    set ptr=0
    while $listnext(commandsList,ptr,command) {
        do ..RunCommand(command)
    }
    ;
    set i = $increment(commands)
    set commands(i) = "list-installed -python"
	set results(commands)="list-installed"
	set results(commands,"modifiers","python")=""
	// Verify output matches
    kill parsedCommandInfo,expectedCommandInfo
    do $$$AssertStatusOK(##class(%IPM.Main).%ParseCommandInput(commands(i),.parsedCommandInfo))
    merge expectedCommandInfo = results(i)
    if $$$AssertTrue(..CompareArrays(.parsedCommandInfo,.expectedCommandInfo,.tMessage),"Parsed correctly: "_commands(i)) {
        do $$$LogMessage(tMessage)
        write !,"Expected:",! zwrite expectedCommandInfo
        write !,"Actual:",! zwrite parsedCommandInfo
    }
    quit sc
}

Method TestUninstallWithoutModuleName()
{
    do $$$LogMessage("Run Uninstall command without module name")
    set status = ..RunCommand("uninstall")
    do $$$AssertStatusNotOK(status, $system.Status.GetErrorText(status))
    set status = ..RunCommand("install objectscript-math")
    do $$$AssertStatusOK(status, "objectscript-math module installed successfully.")
    set exists = ##class(%IPM.Storage.Module).NameExists("objectscript-math")
    do $$$AssertTrue(exists, "objectscript-math Module exists in storage after installation.")
    do ..RunCommand("uninstall objectscript-math")
    set exists = ##class(%IPM.Storage.Module).NameExists("objectscript-math")
    do $$$AssertNotTrue(exists, "Module removed successfully.")
}

}
