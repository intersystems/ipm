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
	If (indexlist [ "SemVer") || (indexlist = "") {
		// Force recomputation of SemVer property if index needs to be rebuilt (i.e., because structure has changed)
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,"update %IPM_Repo_Filesystem.Cache set SemVer = ''")
		If tRes.%SQLCODE < 0 {
			Quit $$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message)
		}
	}
	Quit $$$OK
}

Query OrderedMatches(pRoot As %String = "", pName As %String = "", pVersionExpression As %String = "*", pParameters As %String = "") As %Query(ROWSPEC = "Name:%String,VersionString:%String") [ SqlProc ]
{
}

ClassMethod OrderedMatchesExecute(ByRef qHandle As %Binary, pRoot As %String = "", pName As %String = "", pVersionExpression As %String = "*", pParameters As %String = "") As %Status
{
	Set tSC = ##class(%IPM.General.SemanticVersion.Find).MatchesExecute(.qHandle,$classname(),"SemVer",..SemVerIndexLocation(),pName,pVersionExpression,pParameters)
	Set qHandle("root") = pRoot
	Quit tSC
}

ClassMethod OrderedMatchesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = OrderedMatchesExecute ]
{
	Quit ##class(%IPM.General.SemanticVersion.Find).MatchesClose(.qHandle)
}

ClassMethod OrderedMatchesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = OrderedMatchesExecute ]
{
	For {
		Set tSC = ##class(%IPM.General.SemanticVersion.Find).MatchesFetch(.qHandle,.tRow,.AtEnd)
		If AtEnd {
			Quit
		}
		Set tRoot = ..RootGetStored($ListGet(tRow))
		If (tRoot = qHandle("root")) {
			Set Row = $ListBuild(..NameGetStored($ListGet(tRow)),..VersionStringGetStored($ListGet(tRow)))
			Quit
		}
	}
	Quit tSC
}

Method HandleSaveError(pSC As %Status) As %Status
{
	Set tSC = pSC
	Try {
		If $System.Status.Equals(pSC,$$$ERRORCODE($$$KeyNotUnique)) {
			$$$ThrowOnError($System.Status.DecomposeStatus(pSC,.tStatusInfo))
			
			// Which key?
			Set tErrorParam = tStatusInfo(1,"param",1)
			Set tClass = $Piece(tErrorParam,":",1)
			Set tKey = $Piece(tErrorParam,":",2)
			If (tClass = $classname()) && (tKey = "RootNameVersion") {
				// Find the existing instance with matching RootNameVersion
				Set tOtherInstance = ..RootNameVersionOpen(..Root,..Name,..VersionString,,.tSC)
				$$$ThrowOnError(tSC)
				
				// Log a descriptive error message
				Set tDupeDir = ..Root_..SubDirectory
				Set tUseDir = tOtherInstance.Root_tOtherInstance.SubDirectory
				Set tMessage = ..Name_" "_..VersionString_" previously found in "_tUseDir_"; also found in "_tDupeDir_". The version in "_tUseDir_" will be used."
				Do ##class(%IPM.General.LogManager).Warning(tMessage,1)
				
				// Treat this as a non-error
				Set tSC = $$$OK
			}
		}
	} Catch e {
		Set tSC = $$$ADDSC(pSC,e.AsStatus())
	}
	Quit tSC
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
