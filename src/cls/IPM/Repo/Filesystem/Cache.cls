Include %occErrors

Class %IPM.Repo.Filesystem.Cache Extends (%Persistent, %IPM.General.ModuleInfo)
{

Parameter DEFAULTGLOBAL = "^IPM.Repo.Filesystem.Cache";

Index CacheItemIndex On (Root, SubDirectory) [ Data = LastModified, Unique ];

Property Root As %String(MAXLEN = 260) [ Required ];

ForeignKey RootFK(Root) References %IPM.Repo.Filesystem.Definition(RootIndex) [ OnDelete = cascade ];

Property SubDirectory As %String(MAXLEN = 260);

Property LastModified As %TimeStamp [ Required ];

/// Full module manifest
Property Manifest As %Stream.GlobalCharacter;

Index SemVer On (Name, Version) As %IPM.General.SemanticVersion.Index;

/// Property associated with the index to allow quick $Query'ing over SemVer order based on ID
Property SemVer As %String(MAXLEN = 512) [ SqlComputeCode = {set {*} = ##class(%IPM.Repo.Filesystem.Cache).SemVerNode({Name},{Version})}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

Index RootNameVersion On (Root, Name, VersionString) [ Unique ];

ClassMethod %OnBeforeBuildIndices(ByRef indexlist As %String(MAXLEN="") = "") As %Status [ Private, ServerOnly = 1 ]
{
    if (indexlist [ "SemVer") || (indexlist = "") {
        // Force recomputation of SemVer property if index needs to be rebuilt (i.e., because structure has changed)
        set tRes = ##class(%SQL.Statement).%ExecDirect(,"update %IPM_Repo_Filesystem.Cache set SemVer = ''")
        if tRes.%SQLCODE < 0 {
            quit $$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message)
        }
    }
    quit $$$OK
}

Query OrderedMatches(
	pRoot As %String = "",
	pName As %String = "",
	pVersionExpression As %String = "*",
	pParameters As %String = "") As %Query(ROWSPEC = "Name:%String,VersionString:%String,Version_Major:%String,Version_Minor:%String,Version_Patch:%String,Version_Prerelease:%String,Version_Build:%String") [ SqlProc ]
{
}

ClassMethod OrderedMatchesExecute(
	ByRef qHandle As %Binary,
	pRoot As %String = "",
	pName As %String = "",
	pVersionExpression As %String = "*",
	pParameters As %String = "") As %Status
{
    set tSC = ##class(%IPM.General.SemanticVersion.Find).MatchesExecute(.qHandle,$classname(),"SemVer",..SemVerIndexLocation(),pName,pVersionExpression,pParameters)
    set qHandle("root") = pRoot
    quit tSC
}

ClassMethod OrderedMatchesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = OrderedMatchesExecute ]
{
    quit ##class(%IPM.General.SemanticVersion.Find).MatchesClose(.qHandle)
}

ClassMethod OrderedMatchesFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = OrderedMatchesExecute ]
{
    for {
        set tSC = ##class(%IPM.General.SemanticVersion.Find).MatchesFetch(.qHandle,.tRow,.AtEnd)
        if AtEnd {
            quit
        }
        set tRoot = ..RootGetStored($listget(tRow))
        if (tRoot = qHandle("root")) {
            set Row = $listbuild(..NameGetStored($listget(tRow)),..VersionStringGetStored($listget(tRow)))_..VersionGetStored($listget(tRow))
            quit
        }
    }
    quit tSC
}

Method HandleSaveError(pSC As %Status) As %Status
{
    set tSC = pSC
    try {
        if $system.Status.Equals(pSC,$$$ERRORCODE($$$KeyNotUnique)) {
            $$$ThrowOnError($system.Status.DecomposeStatus(pSC,.tStatusInfo))

            // Which key?
            set tErrorParam = tStatusInfo(1,"param",1)
            set tClass = $piece(tErrorParam,":",1)
            set tKey = $piece(tErrorParam,":",2)
            if (tClass = $classname()) && (tKey = "RootNameVersion") {
                // Find the existing instance with matching RootNameVersion
                set tOtherInstance = ..RootNameVersionOpen(..Root,..Name,..VersionString,,.tSC)
                $$$ThrowOnError(tSC)

                // Log a descriptive error message
                set tDupeDir = ..Root_..SubDirectory
                set tUseDir = tOtherInstance.Root_tOtherInstance.SubDirectory
                set tMessage = ..Name_" "_..VersionString_" previously found in "_tUseDir_"; also found in "_tDupeDir_". The version in "_tUseDir_" will be used."
                do ##class(%IPM.General.LogManager).Warning(tMessage,1)

                // Treat this as a non-error
                set tSC = $$$OK
            }
        }
    } catch e {
        set tSC = $$$ADDSC(pSC,e.AsStatus())
    }
    quit tSC
}

Storage Default
{
<Data name="CacheDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Root</Value>
</Value>
<Value name="3">
<Value>SubDirectory</Value>
</Value>
<Value name="4">
<Value>Name</Value>
</Value>
<Value name="5">
<Value>Version</Value>
</Value>
<Value name="6">
<Value>VersionString</Value>
</Value>
<Value name="7">
<Value>LastModified</Value>
</Value>
<Value name="8">
<Value>Manifest</Value>
</Value>
<Value name="9">
<Value>SemVer</Value>
</Value>
<Value name="10">
<Value>Description</Value>
</Value>
<Value name="11">
<Value>Repository</Value>
</Value>
<Value name="12">
<Value>AllVersions</Value>
</Value>
<Value name="13">
<Value>Origin</Value>
</Value>
<Value name="14">
<Value>Deployed</Value>
</Value>
<Value name="15">
<Value>PlatformVersion</Value>
</Value>
<Value name="16">
<Value>DisplayName</Value>
</Value>
</Data>
<DataLocation>^IPM.Repo.Filesystem.CacheD</DataLocation>
<DefaultData>CacheDefaultData</DefaultData>
<IdLocation>^IPM.Repo.Filesystem.CacheD</IdLocation>
<IndexLocation>^IPM.Repo.Filesystem.CacheI</IndexLocation>
<StreamLocation>^IPM.Repo.Filesystem.CacheS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
