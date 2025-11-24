Class Test.PM.Integration.History Extends Test.PM.Integration.Base
{

Parameter SimpleModuleName As STRING = "simplest-module";

Parameter HistoryNSName As STRING = "HISTORY";

Method OnAfterOneTest(testname As %String) As %Status
{
    set tSC = ##class(%IPM.Main).Shell("uninstall -all")
    do $$$AssertStatusOK(tSC,"All modules uninstalled")

    if ##class(%IPM.Repo.Definition).ServerDefinitionKeyExists("zot") {
        set tSC = ##class(%IPM.Main).Shell("repo -n zot -delete")
        do $$$AssertStatusOK(tSC,"Zot repo unconfigured succesfully")
    }

    // delete entries
    set tSC = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(tSC,"History deleted successfully")

    return tSC
}

/// Tests basic load, uninstall, and install
Method TestSimpleHistory()
{
    // delete previous entries
    set tSC = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(tSC,"History deleted successfully")

    set tModuleDir = ..GetModuleDir(..#SimpleModuleName _ "/1.0.0")

    // Load module
    set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
    do $$$AssertStatusOK(tSC,"Loaded module successfully")

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
        do $$$AssertEquals(rs.%Get("CommandString"),"load -verbose " _ tModuleDir)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")
    }

    // Publish module to test install
    set tSC = ##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000")
    do $$$AssertStatusOK(tSC,"Zot repo configured succesfully")
    set tSC = ##class(%IPM.Main).Shell("publish simplest-module -verbose -r zot")
    do $$$AssertStatusOK(tSC,"Published module successfully")

    // Uninstall module
    set tSC = ##class(%IPM.Main).Shell("uninstall -verbose " _ ..#SimpleModuleName)
    do $$$AssertStatusOK(tSC,"Uninstalled module successfully")

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
    set tSC = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusOK(tSC,"Installed module successfully")

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

/// Creates a history log entry for each of load, install, and uninstall in the current namespace
Method DoLoadUninstallInstall(
	moduleName As %String,
	moduleVersion As %String)
{
    // set up load, install, uninstall entries
    set tModuleDir = ..GetModuleDir(moduleName _  "/" _ moduleVersion)
    set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
    do $$$AssertStatusOK(tSC,"Loaded module successfully")
    set tSC = ##class(%IPM.Main).Shell("repo -o -name zot -url http://oras:5000")
    do $$$AssertStatusOK(tSC,"Zot repo configured succesfully")
    set tSC = ##class(%IPM.Main).Shell("publish " _ moduleName _ " -verbose -r zot -export-deps 1")
    do $$$AssertStatusOK(tSC,"Published module successfully")
    set tSC = ##class(%IPM.Main).Shell("uninstall -r -verbose " _ moduleName)
    do $$$AssertStatusOK(tSC,"Uninstalled module successfully")
    set tSC = ##class(%IPM.Main).Shell("install -verbose " _ moduleName _ " " _ moduleVersion)
    do $$$AssertStatusOK(tSC,"Installed module successfully")
}

Method TestHistoryModifiers()
{
    // delete previous entries
    set tSC = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(tSC,"History deleted successfully")

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
    set tSC = ##class(%IPM.Main).Shell("load -verbose " _ ..GetModuleDir("module-version"))
    do $$$AssertStatusOK(tSC,"Loaded module successfully")

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

Method TestInvalidHistoryCommands()
{
    set command = "history blah"
    set tSC = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusNotOK(tSC,"Invalid command: "_command)

    set command = "history details 0"
    set tSC = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusNotOK(tSC,"Invalid command: "_command)

    set command = "history details blah"
    set tSC = ##class(%IPM.Main).Shell(command)
    do $$$AssertStatusNotOK(tSC,"Invalid command: "_command)
}

Method TestDevMode()
{
    set tModuleDir = ..GetModuleDir("malformed-module")
    set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
    do $$$AssertStatusNotOK(tSC,"Malformed module not loaded")

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
        do $$$AssertEquals(rs.%Get("CommandString"),"load -verbose " _ tModuleDir)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")
    }

    set tSC = ##class(%IPM.Main).Shell("load -verbose -dev " _ tModuleDir)
    do $$$AssertStatusNotOK(tSC,"Malformed module not loaded")

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
        do $$$AssertEquals(rs.%Get("CommandString"),"load -verbose -dev " _ tModuleDir)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")
    }
}

/// Creates entries in the history log in two namespaces
/// Checks that local and global find and delete work
Method TestMultipleNamespaces()
{
    new $namespace
    set originalNS = $namespace

    // (pre-cleanup) delete previous entries
    set tSC = ##class(%IPM.Main).Shell("history delete -g -confirm")
    do $$$AssertStatusOK(tSC,"History deleted successfully")

    // perform actions in this current namespace
    do ..DoLoadUninstallInstall(..#SimpleModuleName, "1.0.0")

    // create new namespace and perform actions in it
    set newNamespace = ..CreateNewNamespace()
    write !, "Switching to ", newNamespace
    set $namespace = newNamespace
    // keep list of namespaces to iterate through
    set namespaces = $listbuild(originalNS, newNamespace)

    // delete previous entries
    set tSC = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(tSC,"History deleted successfully")

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
    // The new namespace is mapped to the orginal one, so they share the %IPM.General.History table
    // todo figure out why delete doesn't work; something about the mappings is throwing it off

    write !, "Testing history deletion in ", $namespace
    set tSC = ##class(%IPM.Main).Shell("history delete -confirm")
    do $$$AssertStatusOK(tSC,"History deleted successfully")

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

/// Creates a new namespace and switches into it
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

Method TestUpdate()
{
    // Load 1.0.0
    set tModuleDir = ..GetModuleDir(..#SimpleModuleName _ "/1.0.0")

    // Load module
    set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
    do $$$AssertStatusOK(tSC,"Loaded module successfully")

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
        set expectedCommandString = "load -verbose " _ tModuleDir
        do $$$AssertEquals(rs.%Get("CommandString"),expectedCommandString)
        do $$$AssertEquals(rs.%Get("SourceDetails"),"")
        do $$$AssertEquals(rs.%Get("SourceMoniker"),"")
        do $$$AssertEquals(rs.%Get("SourceName"),"")
    }

    // Update to 2.0.0
    set tModuleDir = ..GetModuleDir(..#SimpleModuleName _ "/2.0.0")
    set commandString = "update " _ ..#SimpleModuleName _ " -verbose -path " _ tModuleDir
    set tSC = ##class(%IPM.Main).Shell(commandString)
    do $$$AssertStatusOK(tSC,"Update module successfully")

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

/// An action that fails should properly document the failing phase
Method TestFailingPhases()
{
    set tModuleDir = ..GetModuleDir("invoke/failure/NonStatusReturnCheckStatus")
    set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)

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
        do $$$AssertEquals(rs.%Get("CommandString"),"load -verbose " _ tModuleDir)
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

}
