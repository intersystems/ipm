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

	set tCommands($increment(tCommands)) = "repo -r -n registry -url http://x/ -password-env MY_PW -token-env MY_TOK"
	set tResults(tCommands)="repo"
	set tResults(tCommands,"modifiers","name")="registry"
	set tResults(tCommands,"modifiers","remote")=""
	set tResults(tCommands,"modifiers","url")="http://x/"
	set tResults(tCommands,"modifiers","password-env")="MY_PW"
	set tResults(tCommands,"modifiers","token-env")="MY_TOK"

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

    // sort modifier parses correctly — long and short forms, ascending and descending
    set tCommands($increment(tCommands)) = "list -s name"
    set tResults(tCommands)="list-installed"
    set tResults(tCommands,"modifiers","sort")="name"

    set tCommands($increment(tCommands)) = "list -s n"
    set tResults(tCommands)="list-installed"
    set tResults(tCommands,"modifiers","sort")="n"

    set tCommands($increment(tCommands)) = "list -s n-d"
    set tResults(tCommands)="list-installed"
    set tResults(tCommands,"modifiers","sort")="n-d"

    set tCommands($increment(tCommands)) = "list -s date"
    set tResults(tCommands)="list-installed"
    set tResults(tCommands,"modifiers","sort")="date"

    set tCommands($increment(tCommands)) = "list -s d-d"
    set tResults(tCommands)="list-installed"
    set tResults(tCommands,"modifiers","sort")="d-d"

    set tCommands($increment(tCommands)) = "list -s v"
    set tResults(tCommands)="list-installed"
    set tResults(tCommands,"modifiers","sort")="v"

    set tCommands($increment(tCommands)) = "list -s version-desc"
    set tResults(tCommands)="list-installed"
    set tResults(tCommands,"modifiers","sort")="version-desc"

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

Method TestRepositoryEnvVars()
{
	set os = ##class(%SYS.Python).Import("os")

	// Test positive path: password-env with valid env var
	do os.putenv("IPM_TEST_PW", "secret")
	do ..AssertNoException("repo -r -n registry-pw-test -url http://127.0.0.1:9999/ -username u -password-env IPM_TEST_PW")

	set repoDef = ##class(%IPM.Repo.Remote.Definition).ServerDefinitionKeyOpen("registry-pw-test")
	do $$$AssertTrue($isobject(repoDef), "Repository registry-pw-test should exist")
	do $$$AssertEquals(repoDef.Password, "secret", "Password should be set from env var")

	// Cleanup
	do ..RunCommand("repo -n registry-pw-test -delete")
	do os.putenv("IPM_TEST_PW", "")

	// Test negative path: password-env with unset env var
	set sc = ..RunCommand("repo -r -n registry-pw-fail -url http://127.0.0.1:9999/ -username u -password-env IPM_TEST_PW")
	do $$$AssertStatusNotOK(sc, "Command should fail when env var is not set")

	// Defensive cleanup in case the repo was somehow created before the failure
	do ..RunCommand("repo -n registry-pw-fail -delete")

	// Test negative path: password-env conflict with password
	// Note: -password-stdin conflict is not tested here because it requires interactive terminal input
	set sc = ..RunCommand("repo -r -n registry-pw-conflict -url http://127.0.0.1:9999/ -username u -password-env IPM_TEST_PW -password plaintext")
	do $$$AssertStatusNotOK(sc, "Command should fail when both -password-env and -password are specified")
	do ..RunCommand("repo -n registry-pw-conflict -delete")

	// Test token-env with valid env var
	do os.putenv("IPM_TEST_TOK", "mytoken123")
	do ..AssertNoException("repo -r -n registry-tok-test -url http://127.0.0.1:9999/ -token-env IPM_TEST_TOK")

	set repoDef = ##class(%IPM.Repo.Remote.Definition).ServerDefinitionKeyOpen("registry-tok-test")
	do $$$AssertTrue($isobject(repoDef), "Repository registry-tok-test should exist")
	do $$$AssertEquals(repoDef.Token, "mytoken123", "Token should be set from env var")

	// Cleanup
	do ..RunCommand("repo -n registry-tok-test -delete")
	do os.putenv("IPM_TEST_TOK", "")

	// Test negative path: token-env with unset env var
	set sc = ..RunCommand("repo -r -n registry-tok-fail -url http://127.0.0.1:9999/ -token-env IPM_TEST_TOK")
	do $$$AssertStatusNotOK(sc, "Command should fail when token env var is not set")
	do ..RunCommand("repo -n registry-tok-fail -delete")

	// Test negative path: token-env conflict with token
	set sc = ..RunCommand("repo -r -n registry-tok-conflict -url http://127.0.0.1:9999/ -token-env IPM_TEST_TOK -token hardcoded")
	do $$$AssertStatusNotOK(sc, "Command should fail when both -token-env and -token are specified")
	do ..RunCommand("repo -n registry-tok-conflict -delete")
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

Method TestAutoPurgeOldHistory() As %Status
{
    set status = ..RunCommand("config set HistoryRetain 30")
    do $$$AssertStatusOK(status, "Config set executed successfully")

    set status = ..RunCommand("config get HistoryRetain")
    do $$$AssertStatusOK(status, "Config get executed successfully")

    do $$$LogMessage("Update HistoryRetain from 30 days to 1 day")
    set status = ..RunCommand("config set HistoryRetain 1")
    do $$$AssertStatusOK(status, "HistoryRetain is changed from 30 days to 1 day successfully")

    do $$$LogMessage("Purging old history entries older than 1 day")
    set status = ##class(%IPM.General.History).AutoPurgeOldHistory()
    do $$$AssertStatusOK(status, "AutoPurgeOldHistory executed successfully")

    set afterPurge = ##class(%IPM.General.History).GetHistoryLastPurge()
    do $$$LogMessage("After purge timestamp: "_afterPurge)
    do $$$LogMessage("reset set the HistoryRetain to default value by deleting the config")
    set status = ..RunCommand("config delete HistoryRetain")
    do $$$AssertStatusOK(status, "Config delete executed successfully")
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

/// Specifies the serialization format (json, toon, yaml) for unit and integration test results in the shell.
Method TestReportFormatConfiguration()
{
    set originalFormat = ##class(%IPM.Repo.UniversalSettings).GetTestReportFormat()

    do ..RunCommand("config set TestReportFormat json")
    set format = ##class(%IPM.Repo.UniversalSettings).GetTestReportFormat()
    do $$$AssertEquals(format, "json", "Verify TestReportFormat is set to JSON")

    do ..RunCommand("config set TestReportFormat yaml")
    set format = ##class(%IPM.Repo.UniversalSettings).GetTestReportFormat()
    do $$$AssertEquals(format, "yaml", "Verify TestReportFormat is set to YAML")

    // Restore original value so this test doesn't pollute subsequent tests
    if originalFormat'="" {
        do ..RunCommand("config set TestReportFormat "_originalFormat)
    } else {
        do ..RunCommand("config delete TestReportFormat")
    }
}

Method TestSortList()
{
    // Build a synthetic list matching the format SortList receives (post label substitution by ListInstalled):
    // $listbuild(label, versionString, externalName, developerMode, root, lastUpdated)
    // Deliberately different orderings per field so each sort is independently verified:
    //   name asc:    apple, mango, zebra
    //   date asc:    mango (jan01), zebra (jan02), apple (jan03)
    //   version asc: zebra (1.0.0), apple (2.0.0), mango (3.0.0)
    set list = 3
    set list(1) = $listbuild("zebra", "1.0.0", "", 0, "", "2026-01-02 10:00:00")
    set list(2) = $listbuild("apple", "2.0.0", "", 0, "", "2026-01-03 10:00:00")
    set list(3) = $listbuild("mango", "3.0.0", "", 0, "", "2026-01-01 10:00:00")

    // Sort by name ascending: apple, mango, zebra
    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "n")
    do $$$AssertEquals($listget(sorted(1),1), "apple", "name asc: first is apple")
    do $$$AssertEquals($listget(sorted(2),1), "mango", "name asc: second is mango")
    do $$$AssertEquals($listget(sorted(3),1), "zebra", "name asc: third is zebra")

    // Sort by name descending: zebra, mango, apple
    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "n-d")
    do $$$AssertEquals($listget(sorted(1),1), "zebra", "name desc: first is zebra")
    do $$$AssertEquals($listget(sorted(2),1), "mango", "name desc: second is mango")
    do $$$AssertEquals($listget(sorted(3),1), "apple", "name desc: third is apple")

    // Sort by date ascending: mango (jan01), zebra (jan02), apple (jan03)
    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "d")
    do $$$AssertEquals($listget(sorted(1),1), "mango", "date asc: first is mango")
    do $$$AssertEquals($listget(sorted(2),1), "zebra", "date asc: second is zebra")
    do $$$AssertEquals($listget(sorted(3),1), "apple", "date asc: third is apple")

    // Sort by date descending: apple (jan03), zebra (jan02), mango (jan01)
    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "d-d")
    do $$$AssertEquals($listget(sorted(1),1), "apple", "date desc: first is apple")
    do $$$AssertEquals($listget(sorted(2),1), "zebra", "date desc: second is zebra")
    do $$$AssertEquals($listget(sorted(3),1), "mango", "date desc: third is mango")

    // Sort by version ascending: zebra (1.0.0), apple (2.0.0), mango (3.0.0)
    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "v")
    do $$$AssertEquals($listget(sorted(1),1), "zebra", "version asc: first is zebra")
    do $$$AssertEquals($listget(sorted(2),1), "apple", "version asc: second is apple")
    do $$$AssertEquals($listget(sorted(3),1), "mango", "version asc: third is mango")

    // Sort by version descending: mango (3.0.0), apple (2.0.0), zebra (1.0.0)
    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "v-d")
    do $$$AssertEquals($listget(sorted(1),1), "mango", "version desc: first is mango")
    do $$$AssertEquals($listget(sorted(2),1), "apple", "version desc: second is apple")
    do $$$AssertEquals($listget(sorted(3),1), "zebra", "version desc: third is zebra")

    // Edge case: empty list — should not crash
    kill sorted
    set sorted = 0
    do ##class(%IPM.Main).SortList(.sorted, "n")
    do $$$AssertEquals(sorted, 0, "empty list: count is 0")

    // Edge case: single-item list — should not crash or lose the item
    kill sorted
    set sorted = 1
    set sorted(1) = $listbuild("only", "1.0.0", "", 0, "", "2026-01-01 10:00:00")
    do ##class(%IPM.Main).SortList(.sorted, "n")
    do $$$AssertEquals(sorted, 1, "single item: count is 1")
    do $$$AssertEquals($listget(sorted(1),1), "only", "single item: item preserved")

}

Method TestSortListIPMFirst()
{
    // IPM always appears first regardless of sort direction.
    // Entries use the label format produced by ListInstalled before SortList is called:
    // plain internal name ("zpm") or formatted "ExternalName (internalName)" ("IPM (zpm)")
    set list = 3
    set list(1) = $listbuild("zebra", "1.0.0", "", 0, "", "2026-01-02 10:00:00")
    set list(2) = $listbuild("IPM (zpm)", "0.10.0", "", 0, "", "2026-01-03 10:00:00")
    set list(3) = $listbuild("apple", "2.0.0", "", 0, "", "2026-01-01 10:00:00")

    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "n")
    do $$$AssertEquals($listget(sorted(1),1), "IPM (zpm)", "IPM first (name asc)")

    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "n-d")
    do $$$AssertEquals($listget(sorted(1),1), "IPM (zpm)", "IPM first (name desc)")

    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "d")
    do $$$AssertEquals($listget(sorted(1),1), "IPM (zpm)", "IPM first (date asc)")

    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "v-d")
    do $$$AssertEquals($listget(sorted(1),1), "IPM (zpm)", "IPM first (version desc)")
}

Method TestSortListSemanticVersions()
{
    // Verify numeric component ordering: "1.10.0" must sort after "1.9.0".
    // Pre-release and build metadata cases are covered in TestSortListVersionPrerelease.
    set list = 4
    set list(1) = $listbuild("alpha", "1.10.2", "", 0, "", "2026-01-01 10:00:00")
    set list(2) = $listbuild("beta",  "1.9.10", "", 0, "", "2026-01-02 10:00:00")
    set list(3) = $listbuild("gamma", "1.10.1", "", 0, "", "2026-01-03 10:00:00")
    set list(4) = $listbuild("delta", "2.0.0",  "", 0, "", "2026-01-04 10:00:00")

    // Double-check ordering with Follows before relying on it in sort assertions
    do $$$AssertTrue(##class(%IPM.General.SemanticVersion).FromString("1.10.1").Follows(##class(%IPM.General.SemanticVersion).FromString("1.9.10")), "1.10.1 follows 1.9.10")
    do $$$AssertTrue(##class(%IPM.General.SemanticVersion).FromString("1.10.2").Follows(##class(%IPM.General.SemanticVersion).FromString("1.10.1")), "1.10.2 follows 1.10.1")
    do $$$AssertTrue(##class(%IPM.General.SemanticVersion).FromString("2.0.0").Follows(##class(%IPM.General.SemanticVersion).FromString("1.10.2")), "2.0.0 follows 1.10.2")

    // Version ascending: beta (1.9.10) < gamma (1.10.1) < alpha (1.10.2) < delta (2.0.0)
    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "v")
    do $$$AssertEquals($listget(sorted(1),1), "beta",  "version asc: first is beta (1.9.10)")
    do $$$AssertEquals($listget(sorted(2),1), "gamma", "version asc: second is gamma (1.10.1)")
    do $$$AssertEquals($listget(sorted(3),1), "alpha", "version asc: third is alpha (1.10.2)")
    do $$$AssertEquals($listget(sorted(4),1), "delta", "version asc: fourth is delta (2.0.0)")

    // Version descending: reverse of above
    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "v-d")
    do $$$AssertEquals($listget(sorted(1),1), "delta", "version desc: first is delta (2.0.0)")
    do $$$AssertEquals($listget(sorted(2),1), "alpha", "version desc: second is alpha (1.10.2)")
    do $$$AssertEquals($listget(sorted(3),1), "gamma", "version desc: third is gamma (1.10.1)")
    do $$$AssertEquals($listget(sorted(4),1), "beta",  "version desc: fourth is beta (1.9.10)")
}

Method TestSortListVersionPrerelease()
{
    // Verify pre-release and build metadata sort correctly per semver spec:
    //   pre-release < release with same major.minor.patch
    //   build metadata is ignored (treated as release)
    //   pre-release ordering is case-sensitive (consistent with SemanticVersion.Follows):
    //     uppercase letters (A-Z, 65-90) sort before lowercase (a-z, 97-122)
    //     so "SNAPSHOT" (S=83) < "alpha" (a=97) < "beta.1" < "rc.1"
    //   "~" (126) is used as the key suffix for release/build-only versions so they sort last
    // Expected ascending order:
    //   snap  (1.0.0-SNAPSHOT)   — pre-release, S=83 sorts before lowercase labels
    //   a     (1.0.0-alpha)      — pre-release
    //   b     (1.0.0-beta.1)     — pre-release
    //   c     (1.0.0-rc.1)       — pre-release
    //   bld   (1.0.0+build.42)   — build metadata only: treated same as release (key suffix "~")
    //   rel   (1.0.0)            — release (key suffix "~"), "rel" > "bld" as secondary key
    set list = 6
    set list(1) = $listbuild("rel",  "1.0.0",           "", 0, "", "2026-01-01 10:00:00")
    set list(2) = $listbuild("snap", "1.0.0-SNAPSHOT",  "", 0, "", "2026-01-02 10:00:00")
    set list(3) = $listbuild("a",    "1.0.0-alpha",     "", 0, "", "2026-01-03 10:00:00")
    set list(4) = $listbuild("bld",  "1.0.0+build.42",  "", 0, "", "2026-01-04 10:00:00")
    set list(5) = $listbuild("b",    "1.0.0-beta.1",    "", 0, "", "2026-01-05 10:00:00")
    set list(6) = $listbuild("c",    "1.0.0-rc.1",      "", 0, "", "2026-01-06 10:00:00")

    // Follows is a partial order — pairs with different MMP where both have pre-release are incomparable.
    // Our sort imposes a total order (every entry gets a string key), so these Follows checks only
    // validate the pairs that semver itself defines an answer for.
    do $$$AssertTrue(##class(%IPM.General.SemanticVersion).FromString("1.0.0").Follows(##class(%IPM.General.SemanticVersion).FromString("1.0.0-SNAPSHOT")), "release follows pre-release (SNAPSHOT)")
    do $$$AssertTrue(##class(%IPM.General.SemanticVersion).FromString("1.0.0").Follows(##class(%IPM.General.SemanticVersion).FromString("1.0.0-alpha")), "release follows pre-release (alpha)")
    do $$$AssertTrue(##class(%IPM.General.SemanticVersion).FromString("1.0.0-beta.1").Follows(##class(%IPM.General.SemanticVersion).FromString("1.0.0-alpha")), "beta.1 follows alpha")
    do $$$AssertTrue(##class(%IPM.General.SemanticVersion).FromString("1.0.0-rc.1").Follows(##class(%IPM.General.SemanticVersion).FromString("1.0.0-beta.1")), "rc.1 follows beta.1")

    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "v")
    do $$$AssertEquals($listget(sorted(1),1), "snap", "version asc: snap (1.0.0-SNAPSHOT)")
    do $$$AssertEquals($listget(sorted(2),1), "a",    "version asc: a (1.0.0-alpha)")
    do $$$AssertEquals($listget(sorted(3),1), "b",    "version asc: b (1.0.0-beta.1)")
    do $$$AssertEquals($listget(sorted(4),1), "c",    "version asc: c (1.0.0-rc.1)")
    // rel and bld both have key suffix "~"; their relative order is by label (name)
    do $$$AssertEquals($listget(sorted(5),1), "bld",  "version asc: bld (1.0.0+build.42)")
    do $$$AssertEquals($listget(sorted(6),1), "rel",  "version asc: rel (1.0.0)")

    kill sorted
    merge sorted = list
    do ##class(%IPM.Main).SortList(.sorted, "v-d")
    do $$$AssertEquals($listget(sorted(1),1), "rel",  "version desc: rel (1.0.0)")
    do $$$AssertEquals($listget(sorted(2),1), "bld",  "version desc: bld (1.0.0+build.42)")
    do $$$AssertEquals($listget(sorted(3),1), "c",    "version desc: c (1.0.0-rc.1)")
    do $$$AssertEquals($listget(sorted(4),1), "b",    "version desc: b (1.0.0-beta.1)")
    do $$$AssertEquals($listget(sorted(5),1), "a",    "version desc: a (1.0.0-alpha)")
    do $$$AssertEquals($listget(sorted(6),1), "snap", "version desc: snap (1.0.0-SNAPSHOT)")
}

Method TestLocateCommand()
{
    set ipmModule = ##class(%IPM.Storage.Module).NameOpen("zpm",,.sc)
    do $$$AssertStatusOK(sc, "Opened zpm module to get version")
    set ipmVersion = ipmModule.VersionString

    do $$$LogMessage("Testing locate-resource with .inc resource")
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set status = ##class(%IPM.Main).Shell("locate-resource %IPM.Common.inc")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
    do $$$AssertStatusOK(status, "locate-resource %IPM.Common.inc executed successfully")
    set content = ""
    set i = ""
    for {
        set i = $order(output(i))
        quit:i=""
        set content = content _ output(i) _ $char(10)
    }
    do $$$AssertTrue(content [ "zpm", "output contains module name 'zpm'")
    do $$$AssertTrue(content [ ipmVersion, "output contains IPM version "_ipmVersion)

    do $$$LogMessage("Testing locate-resource with .cls resource")
    do ##class(%IPM.Utils.Module).BeginCaptureOutput(.cookie)
    set status = ##class(%IPM.Main).Shell("locate-resource %IPM.Main.cls")
    do ##class(%IPM.Utils.Module).EndCaptureOutput(cookie, .output)
    do $$$AssertStatusOK(status, "locate-resource %IPM.Main.cls executed successfully")
    set content = ""
    set i = ""
    for {
        set i = $order(output(i))
        quit:i=""
        set content = content _ output(i) _ $char(10)
    }
    do $$$AssertTrue(content [ "zpm", "output contains module name 'zpm'")
    do $$$AssertTrue(content [ ipmVersion, "output contains IPM version "_ipmVersion)

    do $$$LogMessage("Testing locate-resource with non-existing resource")
    set status = ..RunCommand("locate-resource Test.Sample.inc")
    do $$$AssertStatusOK(status, "Gracefully handled non-existing resource")

    do $$$LogMessage("Testing locate-resource without required argument")
    set status = ..RunCommand("locate-resource")
    do $$$AssertStatusNotOK(status, "Handled missing argument")
}

}
