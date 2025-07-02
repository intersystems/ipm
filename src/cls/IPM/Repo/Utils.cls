Include (%occErrors, %IPM.Common)

Class %IPM.Repo.Utils
{

/// Returns a list of all resolved module references matching the search criteria from configured repositories.
ClassMethod SearchRepositoriesForModule(
	pSearchCriteria As %IPM.Repo.SearchCriteria,
	Output pResults As %Library.ListOfObjects(ELEMENTTYPE="%IPM.Storage.QualifiedModuleInfo"),
	pForceRemoteRepo As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set pResults = $$$NULLOREF
    try {
        set tManager = ##class(%IPM.Repo.Manager).%Get(.tSC)
        $$$ThrowOnError(tSC)
        set tSC = tManager.SearchRepositoriesForModule(pSearchCriteria,.pResults)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Loads the module reference
ClassMethod RetrieveModuleManifest(
	pQualifiedReference As %IPM.Storage.QualifiedModuleInfo,
	Output pManifestStream As %Stream.Object) As %Status
{
    set tSC = $$$OK
    set pManifestStream = $$$NULLOREF
    try {
        set tManager = ##class(%IPM.Repo.Manager).%Get(.tSC)
        $$$ThrowOnError(tSC)
        set tSC = tManager.RetrieveModuleManifest(pQualifiedReference,.pManifestStream)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Loads the module reference
ClassMethod RetrieveModulePackage(
	pQualifiedReference As %IPM.Storage.QualifiedModuleInfo,
	Output pPackageStream As %Stream.Object) As %Status
{
    set tSC = $$$OK
    set pPackageStream = $$$NULLOREF
    try {
        set tManager = ##class(%IPM.Repo.Manager).%Get(.tSC)
        $$$ThrowOnError(tSC)
        set tSC = tManager.RetrieveModulePackage(pQualifiedReference,.pPackageStream)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod GetZPMVersion()
{
    set module = ##class(%IPM.Storage.Module).NameOpen($$$IPMModuleName)
    if ($isobject(module)) {
        return module.VersionString
    }
    return ""
}

ClassMethod moduleSqlToList(
	pQuery As %String,
	pSearchCriteria As %IPM.Repo.SearchCriteria,
	ByRef pArgs) As %Library.ListOfObjects
{
    if '$isobject($get(pSearchCriteria)) {
         set pSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
    }
    merge tArgs = pArgs
    set tKeywordList = ""
    set tWhereParts = ""
    set tOrderByParts = ""
    if (pSearchCriteria.Name '= "") {
        set tArgs($increment(tArgs)) = pSearchCriteria.Name
        if (pSearchCriteria.VersionExpression '= "") {
            set tArgs($increment(tArgs)) = pSearchCriteria.VersionExpression
        } else {
            set tArgs($increment(tArgs)) = "*"
        }
    } else {
        set tArgs($increment(tArgs)) = ""
        set tArgs($increment(tArgs)) = "*"
    }

    set tSearchParams = ""
    if (pSearchCriteria.IncludeSnapshots) {
        set tSearchParams = tSearchParams_$listbuild("snapshot")
    }
    if (pSearchCriteria.IncludePrerelease) {
        set tSearchParams = tSearchParams_$listbuild("prerelease")
    }
    set tArgs($increment(tArgs)) = $listtostring(tSearchParams," ")

    if (pSearchCriteria.Keywords.Count() > 0) {
        set tWhereParts = tWhereParts_$listbuild("%SIMILARITY(Manifest,?) > 0")
        for i=1:1:pSearchCriteria.Keywords.Count() {
            set tKeywordList = tKeywordList_$listbuild(pSearchCriteria.Keywords.GetAt(i))
        }
        set tKeywordList = $listfromstring(tKeywordList," ")
        set tArgs($increment(tArgs)) = tKeywordList
    }

    if (tWhereParts '= "") {
        set pQuery = pQuery_" where "_$listtostring(tWhereParts," and ")
    }

    // List exact version matches first.
    if (pSearchCriteria.VersionExpression '= "") {
        set tOrderByParts = tOrderByParts_$listbuild("case m.VersionString when ? then 0 else 1 end")
        set tArgs($increment(tArgs)) = pSearchCriteria.VersionExpression
    }
    set tOrderByParts = tOrderByParts_$listbuild("m.Name")
    set tOrderByParts = tOrderByParts_$listbuild("m.Version_Major desc", "m.Version_Minor desc", "m.Version_Patch desc", "m.Version_Prerelease desc", "m.Version_Build desc")
    if (tKeywordList '= "") {
        // TODO: Find some way to order by max similarity (or just similarity of latest version of the module) instead?
        set tOrderByParts = tOrderByParts_$listbuild("%SIMILARITY(Manifest,?) desc")
        set tOrderByArgs($increment(tOrderByArgs)) = tKeywordList
    }

    // TVF returns items in correct order - so order by that.
    set tOrderByParts = tOrderByParts_$listbuild("m.%id asc")

    if (tOrderByParts '= "") {
        set pQuery = pQuery_" order by "_$listtostring(tOrderByParts,",")
        for i=1:1:$get(tOrderByArgs) {
            set tArgs($increment(tArgs)) = tOrderByArgs(i)
        }
    }

    set tArray = ##class(%Library.ArrayOfObjects).%New()
    set tRes = ##class(%SQL.Statement).%ExecDirect(,pQuery,tArgs...)
    if (tRes.%SQLCODE < 0) {
        $$$ThrowStatus($$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message))
    }
    while (tRes.%Next(.tStatus)) {
        if $$$ISERR(tStatus) {
            quit
        }
        set Name = tRes.%Get("Name")
        set VersionString = tRes.%Get("VersionString")

        set tModRef = tArray.GetAt(tRes.%Get("Name"))
        if tModRef = "" {
            set tModRef = ##class(%IPM.Storage.ModuleInfo).%New()
            set tModRef.Name = tRes.%Get("Name")
            set tModRef.VersionString = tRes.%Get("VersionString")
            if pSearchCriteria.AllVersions {
                set tModRef.AllVersions = VersionString
            }
            do tArray.SetAt(tModRef, Name)
        } elseif pSearchCriteria.AllVersions {
            set tModRef.AllVersions = tModRef.AllVersions_", "_VersionString
        }
    }
    if $$$ISERR(tStatus) {
        $$$ThrowStatus(tStatus)
    }
    set tList = ##class(%Library.ListOfObjects).%New()
    set key = ""
    for {
        set mod = tArray.GetNext(.key)
        if (key = "") {
            quit
        }
        do tList.Insert(mod)
    }
    quit tList
}

}
