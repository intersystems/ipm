/// Integration test suite for IPM history log.
/// Tests various aspects of the history log including:
/// - Basic history entry creation for load, install, and uninstall operations
/// - History filtering by action type, package name, and other criteria
/// - Multi-namespace history tracking and management
/// - Phase tracking during module operations
/// - Error handling and failed operation tracking
/// - History deletion (local and global)
/// - Dev mode behavior with uncommitted operations
Class Test.PM.Integration.History Extends Test.PM.Integration.Base
{

Parameter SimpleModuleName As STRING = "simplest-module";

Parameter HistoryNSName As STRING = "HISTORY";

/// Cleanup method executed after each test to ensure a clean state.
/// Uninstalls all modules, removes the test repository configuration, and clears all history entries.
Method OnAfterOneTest(testname As %String) As %Status
{
    set sc = ##class(%IPM.Main).Shell("uninstall -all")
    do $$$AssertStatusOK(sc,"All modules uninstalled")

    if ##class(%IPM.Repo.Definition).ServerDefinitionKeyExists("zot") {
        set sc = ##class(%IPM.Main).Shell("repo -n zot -delete")
        do $$$AssertStatusOK(sc,"Zot repo unconfigured succesfully")
    }

    // delete entries
    set sc = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(sc,"History deleted successfully")

    return sc
}

/// Tests basic history logging for load, uninstall, and install operations.
/// Verifies that history entries are created with all expected fields populated correctly including:
/// - Action type (load, uninstall, install)
/// - Module version information
/// - Timestamps
/// - Success and committed status
/// - Command strings
/// - Source information (for install operations)
Method TestSimpleHistory()
{
    // delete previous entries
    set sc = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(sc,"History deleted successfully")

    set moduleDir = ..GetModuleDir(..#SimpleModuleName _ "/1.0.0")

    // Load module
    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc,"Loaded module successfully")

    // get history
    set rs = ##class(%IPM.General.History).GetHistory(,,1)
    while rs.%Next() {
        do $$$AssertTrue(rs.%Get("ID") '= "")
        do $$$AssertEquals(rs.%Get("Action"),"load")
        do $$$AssertEquals(rs.%Get("Package"),..#SimpleModuleName)
        do $$$AssertEquals(rs.%Get("Version_Major"),"1")
        do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
        do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
        do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
        do $$$AssertTrue(rs.%Get("TimeStart") '= "")
        do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
        do $$$AssertEquals(rs.%Get("Success"),1)
        do $$$AssertEquals(rs.%Get("Committed"),1)
        do $$$AssertEquals(rs.%Get("CommandString"),"load -verbose " _ moduleDir)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")
    }

    // Publish module to test install
    set sc = ##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000")
    do $$$AssertStatusOK(sc,"Zot repo configured succesfully")
    set sc = ##class(%IPM.Main).Shell("publish simplest-module -verbose -r zot")
    do $$$AssertStatusOK(sc,"Published module successfully")

    // Uninstall module
    set sc = ##class(%IPM.Main).Shell("uninstall -verbose " _ ..#SimpleModuleName)
    do $$$AssertStatusOK(sc,"Uninstalled module successfully")

    // get history
    set rs = ##class(%IPM.General.History).GetHistory(,,1)
    while rs.%Next() {
        do $$$AssertTrue(rs.%Get("ID") '= "")
        do $$$AssertEquals(rs.%Get("Action"),"uninstall")
        do $$$AssertEquals(rs.%Get("Package"),..#SimpleModuleName)
        do $$$AssertEquals(rs.%Get("Version_Major"),"1")
        do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
        do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
        do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
        do $$$AssertTrue(rs.%Get("TimeStart") '= "")
        do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
        do $$$AssertEquals(rs.%Get("Success"),1)
        do $$$AssertEquals(rs.%Get("Committed"),1)
        do $$$AssertEquals(rs.%Get("CommandString"),"uninstall -verbose " _ ..#SimpleModuleName)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")
    }

    // Install module
    set command = "install -verbose zot/" _ ..#SimpleModuleName _ " 1.0.0"
    set sc = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusOK(sc,"Installed module successfully")

    // get history
    set rs = ##class(%IPM.General.History).GetHistory(,,1)
    while rs.%Next() {
        do $$$AssertTrue(rs.%Get("ID") '= "")
        do $$$AssertEquals(rs.%Get("Action"),"install")
        do $$$AssertEquals(rs.%Get("Package"),..#SimpleModuleName)
        do $$$AssertEquals(rs.%Get("Version_Major"),"1")
        do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
        do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
        do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
        do $$$AssertTrue(rs.%Get("TimeStart") '= "")
        do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
        do $$$AssertEquals(rs.%Get("Success"),1)
        do $$$AssertEquals(rs.%Get("Committed"),1)
        do $$$AssertEquals(rs.%Get("CommandString"),command)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"http://oras:5000")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"oras")
        do $$$AssertEquals(rs.%Get("SourceName"),"zot")
    }
}

/// Helper method that creates history log entries for load, install, and uninstall operations.
/// Used by multiple tests to set up a consistent test state with representative history entries.
/// <p>Parameters:
/// <ul>
/// <li>moduleName - The name of the module to operate on</li>
/// <li>moduleVersion - The semantic version of the module</li>
/// </ul>
Method DoLoadUninstallInstall(
	moduleName As %String,
	moduleVersion As %String)
{
    // set up load, install, uninstall entries
    set moduleDir = ..GetModuleDir(moduleName _  "/" _ moduleVersion)
    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc,"Loaded module successfully")
    set sc = ##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000")
    do $$$AssertStatusOK(sc,"Zot repo configured succesfully")
    set sc = ##class(%IPM.Main).Shell("publish " _ moduleName _ " -verbose -r zot -export-deps 1")
    do $$$AssertStatusOK(sc,"Published module successfully")
    set sc = ##class(%IPM.Main).Shell("uninstall -r -verbose " _ moduleName)
    do $$$AssertStatusOK(sc,"Uninstalled module successfully")
    set sc = ##class(%IPM.Main).Shell("install -verbose " _ moduleName _ " " _ moduleVersion)
    do $$$AssertStatusOK(sc,"Installed module successfully")
}

/// Tests history filtering and query modifiers.
/// Verifies that the GetHistory API correctly supports:
/// - Filtering by action type (load, install, uninstall)
/// - Filtering by package name
/// - Limiting the number of results returned
/// Ensures that filters work in combination and return accurate results.
Method TestHistoryModifiers()
{
    // delete previous entries
    set sc = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(sc,"History deleted successfully")

    // Populate history log entries
    do ..DoLoadUninstallInstall(..#SimpleModuleName, "1.0.0")

    // test filter by action
    set actions = $listbuild("load", "install", "uninstall")
    set pointer = 0
    while $listnext(actions,pointer,action) {
        set filter("action") = action
        set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
        set count = 0
        while rs.%Next() {
            do $$$AssertEquals(rs.%Get("Action"),action)
            set count = count + 1
        }
        do $$$AssertEquals(count, 1, "Only one " _ action _ " action")
    }

    // test limit
    set rs = ##class(%IPM.General.History).GetHistory(,,2)
    set count = 0
    while rs.%Next() {
        set count = count + 1
    }
    do $$$AssertEquals(count, 2, "Only two actions shown")

    // install different module
    set sc = ##class(%IPM.Main).Shell("load -verbose " _ ..GetModuleDir("module-version"))
    do $$$AssertStatusOK(sc,"Loaded module successfully")

    // test filter by module
    kill filter
    set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
    set count = 0
    while rs.%Next() {
        set count = count + 1
    }
    do $$$AssertEquals(count, 4, "Four entries in total expected, but "_count_" found")

    set filter("package") = ..#SimpleModuleName
    set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
    set count = 0
    while rs.%Next() {
        do $$$AssertEquals(rs.%Get("Package"),..#SimpleModuleName)
        set count = count + 1
    }
    do $$$AssertEquals(count, 3, "Three entries for " _ ..#SimpleModuleName _ " expected, but "_count_" found")

    set filter("package") = "mv"
    set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
    set count = 0
    while rs.%Next() {
        do $$$AssertEquals(rs.%Get("Package"),"mv")
        set count = count + 1
    }
    do $$$AssertEquals(count, 1, "One entries for mv expected, but "_count_" found")
}

/// Tests that invalid history commands return appropriate error status.
/// Verifies error handling for:
/// - Invalid history subcommands
/// - Invalid history detail IDs (0, non-numeric)
Method TestInvalidHistoryCommands()
{
    set command = "history blah"
    set sc = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusNotOK(sc,"Invalid command: "_command)

    set command = "history details 0"
    set sc = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusNotOK(sc,"Invalid command: "_command)

    set command = "history details blah"
    set sc = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusNotOK(sc,"Invalid command: "_command)
}

/// Tests history logging behavior in dev mode vs non-dev mode.
/// Verifies that:
/// - Failed operations without -dev flag create uncommitted history entries (Committed=0)
/// - Failed operations with -dev flag create committed history entries (Committed=1)
Method TestDevMode()
{
    set moduleDir = ..GetModuleDir("malformed-module")
    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusNotOK(sc,"Malformed module not loaded")

    // no dev mode means it shouldn't be committed
    set rs = ##class(%IPM.General.History).GetHistory(.filter,,1)
    set count = 0
    while rs.%Next() {
        do $$$AssertTrue(rs.%Get("ID") '= "")
        do $$$AssertEquals(rs.%Get("Action"),"load")
        do $$$AssertEquals(rs.%Get("Package"),"")
        do $$$AssertEquals(rs.%Get("Version_Major"),"0")
        do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
        do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
        do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
        do $$$AssertTrue(rs.%Get("TimeStart") '= "")
        do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
        do $$$AssertNotEquals(rs.%Get("Success"),1)
        do $$$AssertEquals(rs.%Get("Committed"),0)
        do $$$AssertEquals(rs.%Get("CommandString"),"load -verbose " _ moduleDir)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")
    }

    set sc = ##class(%IPM.Main).Shell("load -verbose -dev " _ moduleDir)
    do $$$AssertStatusNotOK(sc,"Malformed module not loaded")

    // dev mode means it should be committed
    set rs = ##class(%IPM.General.History).GetHistory(.filter,,1)
    set count = 0
    while rs.%Next() {
        do $$$AssertTrue(rs.%Get("ID") '= "")
        do $$$AssertEquals(rs.%Get("Action"),"load")
        do $$$AssertEquals(rs.%Get("Package"),"")
        do $$$AssertEquals(rs.%Get("Version_Major"),"0")
        do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
        do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
        do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
        do $$$AssertTrue(rs.%Get("TimeStart") '= "")
        do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
        do $$$AssertNotEquals(rs.%Get("Success"),1)
        do $$$AssertEquals(rs.%Get("Committed"),1)
        do $$$AssertEquals(rs.%Get("CommandString"),"load -verbose -dev " _ moduleDir)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")
    }
}

/// Tests multi-namespace history tracking and management.
/// Creates history entries in two different namespaces and verifies:
/// - Namespace-specific history queries return only entries for that namespace
/// - Global history queries return entries from all namespaces
/// - Namespace-specific deletion only affects the current namespace
/// - Global deletion removes entries from all namespaces
Method TestMultipleNamespaces()
{
    new $namespace
    set originalNS = $namespace

    // (pre-cleanup) delete previous entries
    set sc = ##class(%IPM.Main).Shell("history delete -g -confirm")
    do $$$AssertStatusOK(sc,"History deleted successfully")

    // perform actions in this current namespace
    do ..DoLoadUninstallInstall(..#SimpleModuleName, "1.0.0")

    // create new namespace and perform actions in it
    set newNamespace = ..CreateNewNamespace()
    write !, "Switching to ", newNamespace
    set $namespace = newNamespace
    // keep list of namespaces to iterate through
    set namespaces = $listbuild(originalNS, newNamespace)

    // delete previous entries
    set sc = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(sc,"History deleted successfully")

    // populate history log
    write !, "Populating history log in ", $namespace
    do ..DoLoadUninstallInstall(..#SimpleModuleName, "1.0.0")

    // test namespace specific and global history starting with original NS
    set $namespace = originalNS
    write !, "Testing namespace specific and global history in ", $namespace
    set rs = ##class(%IPM.General.History).GetHistory()
    set count = 0
    while rs.%Next() {
        set count = count + 1
    }
    do $$$AssertEquals(count, 3, "3 entries in " _ $namespace _ " expected, but "_count_" found")

    set count = ..GetGlobalHistoryCount(namespaces)
    do $$$AssertEquals(count, 6, "6 entries expected globally, but "_count_" found")

    // test namespace specific and global history for new NS
    set $namespace = newNamespace
    write !, "Testing namespace specific and global history in ", $namespace
    set rs = ##class(%IPM.General.History).GetHistory()
    set count = 0
    while rs.%Next() {
        set count = count + 1
    }
    do $$$AssertEquals(count, 3, "3 entries in " _ $namespace _ " expected, but "_count_" found")

    set count = ..GetGlobalHistoryCount(namespaces)
    do $$$AssertEquals(count, 6, "6 entries expected globally, but "_count_" found")

    // Test history deletion
    // start with local namespace-specific deletion
    write !, "Testing history deletion in ", $namespace
    set sc = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(sc,"History deleted successfully")

    set $namespace = originalNS
    set rs = ##class(%IPM.General.History).GetHistory()
    set count = 0
    while rs.%Next() {
        set count = count + 1
    }
    do $$$AssertEquals(count, 3, "3 entries in " _ $namespace _ " expected, but "_count_" found")
    set count = ..GetGlobalHistoryCount(namespaces)
    do $$$AssertEquals(count, 3, "3 entries expected globally, but "_count_" found")

    // delete history globally so no entries are left
    write !, "Testing global history deletion"
    set count = ##class(%IPM.General.History).DeleteHistoryGlobally()
    do $$$AssertEquals(count, 3, "3 deletions in " _ $namespace _ " expected, but " _ count _" performed")

    set rs = ##class(%IPM.General.History).GetHistory()
    set count = 0
    while rs.%Next() {
        set count = count + 1
    }
    do $$$AssertEquals(count, 0, "0 entries in " _ $namespace _ " expected, but " _ count _ " found")

    set count = ..GetGlobalHistoryCount(namespaces)
    do $$$AssertEquals(count, 0, "0 entries expected globally, but "_count_" found")

    // check in the other namespace
    set $namespace = originalNS
    write !, "Checking in ", $namespace
    set rs = ##class(%IPM.General.History).GetHistory()
    set count = 0
    while rs.%Next() {
        set count = count + 1
    }
    do $$$AssertEquals(count, 0, "0 entries in " _ $namespace _ " expected, but "_count_" found")

    set count = ..GetGlobalHistoryCount(namespaces)
    do $$$AssertEquals(count, 0, "0 entries expected globally, but "_count_" found")

    // Cleanup
    set $namespace = originalNS
}

/// Helper method that creates and configures a new test namespace.
/// The new namespace is configured with proper mappings for:
/// - Unit test globals
/// - IPM package manager routines and classes
/// - IPM repository configuration
/// Returns the name of the newly created namespace.
Method CreateNewNamespace() As %String
{
    set currentNS = $namespace
    set nsConfig = ##class(%IPM.Storage.ModuleSetting.NamespaceConfig).%New()

    $$$ThrowOnError(##class(%IPM.Utils.Build).InitializeNamespace(..#HistoryNSName,,.newNamespace,nsConfig))

    // Map ^UnitTest* from its home in the original namespace to the VERIFY namespace.
    $$$ThrowOnError(##class(%IPM.Utils.Build).MapGlobalEquivalently("UnitTest*",currentNS,newNamespace))

    // Map the package manager itself equivalently in the new namespace.
    $$$ThrowOnError(##class(%IPM.Utils.Build).MapRoutineEquivalently("%IPM.*",currentNS,,newNamespace))
    $$$ThrowOnError(##class(%IPM.Utils.Build).MapPackageEquivalently("%IPM",currentNS,newNamespace))

    // Map globals for %IPM.Repo.Definition and %IPM.Repo.Filesystem.Cache
    // from the original namespace to the new namespace
    for tClass = "%IPM.Repo.Definition","%IPM.Repo.Filesystem.Cache" {
        $$$ThrowOnError(##class(%IPM.Utils.Build).MapClassDataEquivalently(tClass,currentNS,newNamespace))
    }
    return newNamespace
}

/// Helper method that counts history entries across multiple namespaces.
/// Iterates through the provided list of namespaces and counts all history entries.
/// <p>Parameters:
/// <ul>
/// <li>namespaces - List of namespace names to query</li>
/// <li>limit - Optional limit on number of entries to retrieve per namespace (0 = unlimited)</li>
/// </ul>
/// Returns the total count of history entries across all specified namespaces.
ClassMethod GetGlobalHistoryCount(
	namespaces As %List,
	limit As %Integer = 0) As %Integer
{
    new $namespace
    set originalNS = $namespace

    set array = ##class(%IPM.General.History).GetHistoryGlobally(,,limit)
    set count = 0
    set pointer = 0
    while $listnext(namespaces, pointer, ns) {
        set rs = array.GetAt(ns)
        if rs = "" {
            continue
        }
        set $namespace = ns
        set subcount = 0
        while rs.%Next() {
            set subcount = subcount + 1
        }
        write !, subcount _ " entries found in " _ ns, !
        set count = count + subcount
    }
    set $namespace = originalNS
    return count
}

/// Tests history logging for module update operations.
/// Verifies that:
/// - Initial load creates a history entry with version 1.0.0
/// - Update to 2.0.0 creates a history entry with action "update" and the new version
/// - All expected fields are populated correctly including command string and version information
Method TestUpdate()
{
    // Load 1.0.0
    set moduleDir = ..GetModuleDir(..#SimpleModuleName _ "/1.0.0")

    // Load module
    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc,"Loaded module successfully")

    // get history
    set rs = ##class(%IPM.General.History).GetHistory(,,1)
    while rs.%Next() {
        do $$$AssertTrue(rs.%Get("ID") '= "")
        do $$$AssertEquals(rs.%Get("Action"),"load")
        do $$$AssertEquals(rs.%Get("Package"),..#SimpleModuleName)
        do $$$AssertEquals(rs.%Get("Version_Major"),"1")
        do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
        do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
        do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
        do $$$AssertTrue(rs.%Get("TimeStart") '= "")
        do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
        do $$$AssertEquals(rs.%Get("Success"),1)
        do $$$AssertEquals(rs.%Get("Committed"),1)
        set expectedCommandString = "load -verbose " _ moduleDir
        do $$$AssertEquals(rs.%Get("CommandString"),expectedCommandString)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")
    }

    // Update to 2.0.0
    set moduleDir = ..GetModuleDir(..#SimpleModuleName _ "/2.0.0")
    set commandString = "update " _ ..#SimpleModuleName _ " -verbose -path " _ moduleDir
    set sc = ##class(%IPM.Main).Shell(commandString)
    do $$$AssertStatusOK(sc,"Update module successfully")

    // get history
    set rs = ##class(%IPM.General.History).GetHistory(,,1)
    while rs.%Next() {
        do $$$AssertTrue(rs.%Get("ID") '= "")
        do $$$AssertEquals(rs.%Get("Action"),"update")
        do $$$AssertEquals(rs.%Get("Package"),..#SimpleModuleName)
        do $$$AssertEquals(rs.%Get("Version_Major"),"2")
        do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
        do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
        do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
        do $$$AssertTrue(rs.%Get("TimeStart") '= "")
        do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
        do $$$AssertEquals(rs.%Get("Success"),1)
        do $$$AssertEquals(rs.%Get("Committed"),1)
        do $$$AssertEquals(rs.%Get("CommandString"),commandString)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")
    }
}

/// Tests that history entries correctly record all phases of module operations.
/// Verifies that:
/// - Load and install operations record 5 phases: Initialize, Reload, Validate, Compile, Activate
/// - Uninstall operations record only the Clean phase
/// - Each phase includes start time, end time, and status
/// - All phases complete successfully ($$$OK status)
Method TestPhases()
{
    // Populate history log entries
    do ..DoLoadUninstallInstall(..#SimpleModuleName, "1.0.0")

    // verify the phases have been populated appropriately
    set actions = $listbuild("load", "install")
    set pointer = 0
    while $listnext(actions,pointer,action) {
        set filter("action") = action
        set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
        while rs.%Next() {
            set phases = rs.%Get("Phases")
            // 5 phases expected: Initialize, Reload, Validate, Compile, Activate
            do $$$AssertEquals($listlength(phases), 5)

            set initialize = $listget($listget(phases, 1), 1)
            do $$$AssertEquals($listget(initialize, 1),"Initialize")
            do $$$AssertTrue($listget(initialize, 2)'="")
            do $$$AssertTrue($listget(initialize, 3)'="")
            do $$$AssertEquals($listget(initialize, 4), $$$OK)

            set reload = $listget($listget(phases, 2), 1)
            do $$$AssertEquals($listget(reload, 1),"Reload")
            do $$$AssertTrue($listget(reload, 2)'="")
            do $$$AssertTrue($listget(reload, 3)'="")
            do $$$AssertEquals($listget(reload, 4), $$$OK)

            set validate = $listget($listget(phases, 3), 1)
            do $$$AssertEquals($listget(validate, 1),"Validate")
            do $$$AssertTrue($listget(validate, 2)'="")
            do $$$AssertTrue($listget(validate, 3)'="")
            do $$$AssertEquals($listget(validate, 4), $$$OK)

            set compile = $listget($listget(phases, 4), 1)
            do $$$AssertEquals($listget(compile, 1),"Compile")
            do $$$AssertTrue($listget(compile, 2)'="")
            do $$$AssertTrue($listget(compile, 3)'="")
            do $$$AssertEquals($listget(compile, 4), $$$OK)

            set activate = $listget($listget(phases, 5), 1)
            do $$$AssertEquals($listget(activate, 1),"Activate")
            do $$$AssertTrue($listget(activate, 2)'="")
            do $$$AssertTrue($listget(activate, 3)'="")
            do $$$AssertEquals($listget(activate, 4), $$$OK)
        }
    }
    // Uninstall only has the clean phase
    set filter("action") = "uninstall"
    set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
    while rs.%Next() {
        set phases = rs.%Get("Phases")
        do $$$AssertEquals($listlength(phases), 1)

        set initialize = $listget($listget(phases, 1), 1)
        do $$$AssertEquals($listget(initialize, 1),"Clean")
        do $$$AssertTrue($listget(initialize, 2)'="")
        do $$$AssertTrue($listget(initialize, 3)'="")
        do $$$AssertEquals($listget(initialize, 4), $$$OK)
    }
}

/// Tests that failed operations properly record which phase failed.
/// Loads a malformed module that fails during the Activate phase and verifies:
/// - History entry shows the operation as unsuccessful
/// - History entry is not committed as it is not in dev mode (Committed=0)
/// - All phases up to and including the failing phase are recorded
/// - The failing phase has a non-OK status while earlier phases have OK status
Method TestFailingPhases()
{
    set moduleDir = ..GetModuleDir("invoke/failure/NonStatusReturnCheckStatus")
    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)

    set rs = ##class(%IPM.General.History).GetHistory(.filter,,1)
    while rs.%Next() {
        // Check history log entry is good
        do $$$AssertTrue(rs.%Get("ID") '= "")
        do $$$AssertEquals(rs.%Get("Action"),"load")
        do $$$AssertEquals(rs.%Get("Package"),"invoke")
        do $$$AssertEquals(rs.%Get("Version_Major"),"0")
        do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
        do $$$AssertEquals(rs.%Get("Version_Patch"),"1")
        do $$$AssertEquals(rs.%Get("Version_Prerelease"),"snapshot")
        do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
        do $$$AssertTrue(rs.%Get("TimeStart") '= "")
        do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
        do $$$AssertNotEquals(rs.%Get("Success"),$$$OK)
        do $$$AssertEquals(rs.%Get("Committed"),0)
        do $$$AssertEquals(rs.%Get("CommandString"),"load -verbose " _ moduleDir)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")

        set phases = rs.%Get("Phases")
        // 5 phases expected: Initialize, Reload, Validate, Compile, Activate
        do $$$AssertEquals($listlength(phases), 5)

        set initialize = $listget($listget(phases, 1), 1)
        do $$$AssertEquals($listget(initialize, 1),"Initialize")
        do $$$AssertTrue($listget(initialize, 2)'="")
        do $$$AssertTrue($listget(initialize, 3)'="")
        do $$$AssertEquals($listget(initialize, 4), $$$OK)

        set reload = $listget($listget(phases, 2), 1)
        do $$$AssertEquals($listget(reload, 1),"Reload")
        do $$$AssertTrue($listget(reload, 2)'="")
        do $$$AssertTrue($listget(reload, 3)'="")
        do $$$AssertEquals($listget(reload, 4), $$$OK)

        set validate = $listget($listget(phases, 3), 1)
        do $$$AssertEquals($listget(validate, 1),"Validate")
        do $$$AssertTrue($listget(validate, 2)'="")
        do $$$AssertTrue($listget(validate, 3)'="")
        do $$$AssertEquals($listget(validate, 4), $$$OK)

        set compile = $listget($listget(phases, 4), 1)
        do $$$AssertEquals($listget(compile, 1),"Compile")
        do $$$AssertTrue($listget(compile, 2)'="")
        do $$$AssertTrue($listget(compile, 3)'="")
        do $$$AssertEquals($listget(compile, 4), $$$OK)

        set activate = $listget($listget(phases, 5), 1)
        do $$$AssertEquals($listget(activate, 1),"Activate")
        do $$$AssertTrue($listget(activate, 2)'="")
        do $$$AssertTrue($listget(activate, 3)'="")
        do $$$AssertNotEquals($listget(activate, 4), $$$OK)
    }
}

/// Tests history logging for modules with dependencies.
/// Loads a module that has a dependency and verifies that:
/// - Both parent and child modules have separate history entries
/// - Load, install, and uninstall operations are tracked for both modules
/// - Phase information is correctly recorded for both parent and child
/// - Dependency module (simplest-module-dep) has correct version information
Method TestWithDependencies()
{
    // Populate history log entries
    do ..DoLoadUninstallInstall(..#SimpleModuleName, "3.0.0")
    set moduleName = ..#SimpleModuleName
    set depName = ..#SimpleModuleName _ "-dep"

    // check both parent and child module have all 3 load, install, and uninstall entries with proper phases

    // parent module: simplest-module
    set filter("package")=moduleName
    set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
    set actions = $listbuild("load", "install", "uninstall")
    set pointer = 0
    while $listnext(actions,pointer,action) {
        set filter("action") = action
        set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
        set count = 0
        while rs.%Next() {
            do $$$AssertTrue(rs.%Get("ID") '= "")
            do $$$AssertEquals(rs.%Get("Action"),action)
            do $$$AssertEquals(rs.%Get("Package"),moduleName)
            do $$$AssertEquals(rs.%Get("Version_Major"),"3")
            do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
            do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
            do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
            do $$$AssertTrue(rs.%Get("TimeStart") '= "")
            do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
            do $$$AssertEquals(rs.%Get("Success"),1)
            do $$$AssertEquals(rs.%Get("Committed"),1)
            set count = count + 1
        }
        do $$$AssertEquals(count, 1, "Only one " _ action _ " action")
    }

    // child module: simplest-module-dep
    set filter("package")=depName
    set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
    set actions = $listbuild("load", "install", "uninstall")
    set pointer = 0
    while $listnext(actions,pointer,action) {
        set filter("action") = action
        set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
        set count = 0
        while rs.%Next() {
            do $$$AssertTrue(rs.%Get("ID") '= "")
            do $$$AssertEquals(rs.%Get("Action"),action)
            do $$$AssertEquals(rs.%Get("Package"),depName)
            do $$$AssertEquals(rs.%Get("Version_Major"),"1")
            do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
            do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
            do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
            do $$$AssertTrue(rs.%Get("TimeStart") '= "")
            do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
            do $$$AssertEquals(rs.%Get("Success"),1)
            do $$$AssertEquals(rs.%Get("Committed"),1)
            set count = count + 1
        }
        do $$$AssertEquals(count, 1, "Only one " _ action _ " action")

        // check phases
        set phases = rs.%Get("Phases")
        if (action = "load") || (action = "install") {
            // 5 phases expected: Initialize, Reload, Validate, Compile, Activate
            do $$$AssertEquals($listlength(phases), 5)

            set initialize = $listget($listget(phases, 1), 1)
            do $$$AssertEquals($listget(initialize, 1),"Initialize")
            do $$$AssertTrue($listget(initialize, 2)'="")
            do $$$AssertTrue($listget(initialize, 3)'="")
            do $$$AssertEquals($listget(initialize, 4), $$$OK)

            set reload = $listget($listget(phases, 2), 1)
            do $$$AssertEquals($listget(reload, 1),"Reload")
            do $$$AssertTrue($listget(reload, 2)'="")
            do $$$AssertTrue($listget(reload, 3)'="")
            do $$$AssertEquals($listget(reload, 4), $$$OK)

            set validate = $listget($listget(phases, 3), 1)
            do $$$AssertEquals($listget(validate, 1),"Validate")
            do $$$AssertTrue($listget(validate, 2)'="")
            do $$$AssertTrue($listget(validate, 3)'="")
            do $$$AssertEquals($listget(validate, 4), $$$OK)

            set compile = $listget($listget(phases, 4), 1)
            do $$$AssertEquals($listget(compile, 1),"Compile")
            do $$$AssertTrue($listget(compile, 2)'="")
            do $$$AssertTrue($listget(compile, 3)'="")
            do $$$AssertEquals($listget(compile, 4), $$$OK)

            set activate = $listget($listget(phases, 5), 1)
            do $$$AssertEquals($listget(activate, 1),"Activate")
            do $$$AssertTrue($listget(activate, 2)'="")
            do $$$AssertTrue($listget(activate, 3)'="")
            do $$$AssertEquals($listget(activate, 4), $$$OK)
        } else {
            // uninstall only has one phase
            do $$$AssertEquals($listlength(phases), 1)
            set initialize = $listget($listget(phases, 1), 1)
            do $$$AssertEquals($listget(initialize, 1),"Clean")
            do $$$AssertTrue($listget(initialize, 2)'="")
            do $$$AssertTrue($listget(initialize, 3)'="")
            do $$$AssertEquals($listget(initialize, 4), $$$OK)
        }
    }
}

/// Tests history retrieval after the temporary history global has been deleted.
/// Verifies that:
/// - History can be populated normally
/// - Deleting the ^IRIS.Temp.HistoryTempD global doesn't break history retrieval
/// - Phase information is still accessible after the temp global is removed
/// This ensures resilience against data loss or cleanup operations.
Method TestTempGlobalWhacking()
{
    // Populate history log entries
    do ..DoLoadUninstallInstall(..#SimpleModuleName, "1.0.0")

    // Whack the HistoryTemp global and make sure everything still works
    kill ^IRIS.Temp.HistoryTempD

    // verify the phases have been populated appropriately
    set actions = $listbuild("load", "install")
    set pointer = 0
    while $listnext(actions,pointer,action) {
        set filter("action") = action
        set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
        while rs.%Next() {
            do $$$AssertTrue(rs.%Get("ID") '= "")
            do $$$AssertEquals(rs.%Get("Action"),action)
            do $$$AssertEquals(rs.%Get("Package"),..#SimpleModuleName)
            do $$$AssertEquals(rs.%Get("Version_Major"),"1")
            do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
            do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
            do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
            do $$$AssertTrue(rs.%Get("TimeStart") '= "")
            do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
            do $$$AssertEquals(rs.%Get("Success"),1)
            do $$$AssertEquals(rs.%Get("Committed"),1)
            do $$$AssertNotEquals(rs.%Get("CommandString"), "")

            // check phases
            set phases = rs.%Get("Phases")
            // 5 phases expected: Initialize, Reload, Validate, Compile, Activate
            do $$$AssertEquals($listlength(phases), 5)

            set initialize = $listget($listget(phases, 1), 1)
            do $$$AssertEquals($listget(initialize, 1),"Initialize")
            do $$$AssertTrue($listget(initialize, 2)'="")
            do $$$AssertTrue($listget(initialize, 3)'="")
            do $$$AssertEquals($listget(initialize, 4), $$$OK)

            set reload = $listget($listget(phases, 2), 1)
            do $$$AssertEquals($listget(reload, 1),"Reload")
            do $$$AssertTrue($listget(reload, 2)'="")
            do $$$AssertTrue($listget(reload, 3)'="")
            do $$$AssertEquals($listget(reload, 4), $$$OK)

            set validate = $listget($listget(phases, 3), 1)
            do $$$AssertEquals($listget(validate, 1),"Validate")
            do $$$AssertTrue($listget(validate, 2)'="")
            do $$$AssertTrue($listget(validate, 3)'="")
            do $$$AssertEquals($listget(validate, 4), $$$OK)

            set compile = $listget($listget(phases, 4), 1)
            do $$$AssertEquals($listget(compile, 1),"Compile")
            do $$$AssertTrue($listget(compile, 2)'="")
            do $$$AssertTrue($listget(compile, 3)'="")
            do $$$AssertEquals($listget(compile, 4), $$$OK)

            set activate = $listget($listget(phases, 5), 1)
            do $$$AssertEquals($listget(activate, 1),"Activate")
            do $$$AssertTrue($listget(activate, 2)'="")
            do $$$AssertTrue($listget(activate, 3)'="")
            do $$$AssertEquals($listget(activate, 4), $$$OK)
        }
    }
    // Uninstall only has the clean phase
    set filter("action") = "uninstall"
    set rs = ##class(%IPM.General.History).GetHistory(.filter,,10)
    while rs.%Next() {
        do $$$AssertTrue(rs.%Get("ID") '= "")
        do $$$AssertEquals(rs.%Get("Action"),"uninstall")
        do $$$AssertEquals(rs.%Get("Package"),..#SimpleModuleName)
        do $$$AssertEquals(rs.%Get("Version_Major"),"1")
        do $$$AssertEquals(rs.%Get("Version_Minor"),"0")
        do $$$AssertEquals(rs.%Get("Version_Patch"),"0")
        do $$$AssertEquals(rs.%Get("UserName"),"irisowner")
        do $$$AssertTrue(rs.%Get("TimeStart") '= "")
        do $$$AssertTrue(rs.%Get("TimeEnd") '= "")
        do $$$AssertEquals(rs.%Get("Success"),1)
        do $$$AssertEquals(rs.%Get("Committed"),1)
        do $$$AssertNotEquals(rs.%Get("CommandString"), "")
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")

        // check phases
        set phases = rs.%Get("Phases")
        do $$$AssertEquals($listlength(phases), 1)

        set initialize = $listget($listget(phases, 1), 1)
        do $$$AssertEquals($listget(initialize, 1),"Clean")
        do $$$AssertTrue($listget(initialize, 2)'="")
        do $$$AssertTrue($listget(initialize, 3)'="")
        do $$$AssertEquals($listget(initialize, 4), $$$OK)
    }
}

/// Tests that finalized history records are locked and cannot be edited.
/// Verifies that:
/// - History records are created successfully
/// - History records are marked as finalized after HistoryTemp closes
/// - Attempts to directly edit finalized History records are blocked
/// - Subsequent operations can still create new records normally
/// - Attempts to modify finalized History records with SQL are blocked
Method TestFinalizedRecordsLocked()
{
    // delete previous entries
    set sc = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(sc,"History deleted successfully")

    set moduleDir = ..GetModuleDir(..#SimpleModuleName _ "/1.0.0")

    // Load a module - creates and finalizes a history entry
    set sc = ##class(%IPM.Main).Shell("load -verbose " _ moduleDir)
    do $$$AssertStatusOK(sc,"Loaded module successfully")

    // Get the history record
    set rs = ##class(%IPM.General.History).GetHistory(,,1)
    do $$$AssertTrue(rs.%Next(), "Should have at least one history record")
    set historyId = rs.%Get("ID")

    // Verify it's finalized
    set historyObj = ##class(%IPM.General.History).%OpenId(historyId)
    do $$$AssertTrue($isobject(historyObj), "Should be able to open history record")
    do $$$AssertEquals(historyObj.Finalized, 1, "History record should be finalized")

    // Try to edit it - should fail
    set historyObj.Package = "modified-name"
    set sc = historyObj.%Save()
    do $$$AssertStatusNotOK(sc, "Should not be able to edit finalized record")
    set errorText = $system.Status.GetErrorText(sc)
    do $$$AssertTrue(errorText [ "Cannot edit finalized history log records", "Error message should mention finalized records")

    // Verify the record was not modified (reload from database)
    $$$ThrowOnError(historyObj.%Reload())
    do $$$AssertEquals(historyObj.Package, ..#SimpleModuleName,"Package name should not have been changed")

    // Verify a subsequent operation still works
    set sc = ##class(%IPM.Main).Shell("uninstall " _ ..#SimpleModuleName)
    do $$$AssertStatusOK(sc, "Subsequent operations should still work")

    // Verify we now have two history records
    set rs = ##class(%IPM.General.History).GetHistory()
    set count = 0
    while rs.%Next() {
        set count = count + 1
    }
    do $$$AssertEquals(count, 2, "Should have two history records after uninstall")

    // Test SQL update protection
    set sqlStatement = ##class(%SQL.Statement).%New()
    set sc = sqlStatement.%Prepare("UPDATE %IPM_General.History SET Package = ? WHERE ID = ?")
    do $$$AssertStatusOK(sc, "SQL prepare should succeed")
    set sqlResult = sqlStatement.%Execute("sql-modified-name", historyId)
    do $$$AssertEquals(sqlResult.%SQLCODE, -132, "SQL update should fail with SQLCODE -132")
    do $$$AssertTrue(sqlResult.%Message [ "Cannot edit finalized history log records", "SQL error message should mention history records cannot be edited")

    // Verify the record was not modified via SQL
    $$$ThrowOnError(historyObj.%Reload())
    do $$$AssertEquals(historyObj.Package, ..#SimpleModuleName, "Package name should still not be changed after SQL attempt")
}

}
