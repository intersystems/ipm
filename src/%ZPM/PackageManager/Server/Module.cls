Class %ZPM.PackageManager.Server.Module Extends (%Persistent, %ZPM.PackageManager.Core.Module) [ SqlTableName = _MODULE ]
{

Parameter XMLTYPE = "ServerModule";

Index NameVersion On (Name, VersionString) [ Unique ];

Index NameBitmap On Name [ Type = bitmap ];

Index SemVer On (Name, Version) As %ZPM.PackageManager.Server.SemVerIndex;

Index ManifestSearchIndex On Manifest(KEYS) [ Data = Manifest(ELEMENTS) ];

/// Property associated with the index to allow quick $Query'ing over SemVer order based on ID
Property SemVer As %String(MAXLEN = 512) [ SqlComputeCode = {set {*} = ##class(%ZPM.PackageManager.Server.Module).SemVerNode({Name},{Version})}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

ClassMethod %OnBeforeBuildIndices(ByRef indexlist As %String(MAXLEN="") = "") As %Status [ Private, ServerOnly = 1 ]
{
	If (indexlist [ "SemVer") || (indexlist = "") {
		// Force recomputation of SemVer property if index needs to be rebuilt (i.e., because structure has changed)
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,"update %ZPM_PackageManager_Server._MODULE set SemVer = ''")
		If tRes.%SQLCODE < 0 {
			Quit $$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message)
		}
	}
	Quit $$$OK
}

Query OrderedMatches(pName As %String = "", pVersionExpression As %String = "*", pParameters As %String = "") As %Query(ROWSPEC = "Name:%String,VersionString:%String") [ SqlProc ]
{
}

ClassMethod OrderedMatchesExecute(ByRef qHandle As %Binary, pName As %String = "", pVersionExpression As %String = "*", pParameters As %String = "") As %Status
{
	Quit ##class(%ZPM.PackageManager.Server.SemVerFind).MatchesExecute(.qHandle,$classname(),"SemVer",..SemVerIndexLocation(),pName,pVersionExpression,pParameters)
}

ClassMethod OrderedMatchesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = OrderedMatchesExecute ]
{
	Quit ##class(%ZPM.PackageManager.Server.SemVerFind).MatchesClose(.qHandle)
}

ClassMethod OrderedMatchesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = OrderedMatchesExecute ]
{
	Set tSC = ##class(%ZPM.PackageManager.Server.SemVerFind).MatchesFetch(.qHandle,.tRow,.AtEnd)
	If $$$ISERR(tSC) {
		Quit tSC
	}
	If 'AtEnd {
		Set Row = $ListBuild(..NameGetStored($ListGet(tRow)),..VersionStringGetStored($ListGet(tRow)))
	}
	Quit $$$OK
}

Storage Default
{
<Data name="PackageDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Version</Value>
</Value>
<Value name="4">
<Value>IsLatest</Value>
</Value>
<Value name="5">
<Value>Payload</Value>
</Value>
<Value name="6">
<Value>VersionString</Value>
</Value>
<Value name="7">
<Value>Manifest</Value>
</Value>
<Value name="8">
<Value>SemVer</Value>
</Value>
<Value name="9">
<Value>Installer</Value>
</Value>
<Value name="10">
<Value>Description</Value>
</Value>
<Value name="11">
<Value>Repository</Value>
</Value>
</Data>
<DataLocation>^ZPM.Server.ModuleD</DataLocation>
<DefaultData>PackageDefaultData</DefaultData>
<IdLocation>^ZPM.Server.ModuleD</IdLocation>
<IndexLocation>^ZPM.Server.ModuleI</IndexLocation>
<StreamLocation>^ZPM.Server.ModuleS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
