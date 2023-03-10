/// Class to enable use of <class>%IPM.General.SemanticVersion.Index</class> with %FIND.
/// For detailed documentation, see <class>%IPM.General.SemanticVersion.Index</class>.
/// TODO: emulate bitmap index by overriding GetChunk/NextChunk/PreviousChunk?
Class %IPM.General.SemanticVersion.Find Extends %SQL.AbstractFind
{

Property BaseIndexGlobal As %String [ Private, ReadOnly ];

Property Class As %String [ Private, ReadOnly ];

Property IndexName As %String [ Private, ReadOnly ];

Property Offset As %String [ Private, ReadOnly ];

Property Name As %String [ Private, ReadOnly ];

Property Parameters As %String [ Private, ReadOnly ];

Property VersionExpression As %IPM.General.SemanticVersionExpression [ Private ];

Property IncludePrerelease As %Boolean [ InitialExpression = 0, Private ];

Property IncludeSnapshot As %Boolean [ InitialExpression = 0, Private ];

/// <p>
/// This callback method is invoked by the <METHOD>%New</METHOD> method to 
/// provide notification that a new instance of an object is being created. 
/// </p>
/// <p>
/// If this method returns an error then the object will not be created. 
/// </p>
/// <p>
/// It is passed the arguments provided in the %New call. 
/// When customizing this method, override the arguments with whatever variables and types you expect to receive from %New(). 
/// For example, if you're going to call %New, passing 2 arguments, %OnNew's signature could be: 
/// <pre>
/// Method %OnNew(dob as %Date = "", name as %Name = "") as %Status 
/// </pre>
/// If instead of returning a %Status code this method returns an oref and this oref is a subclass of the current 
/// class, then this oref will be the one returned to the caller of the %New method. 
/// </p>
Method %OnNew(pClass As %String, pIndexName As %String, pBaseIndexGlobal As %String, pName As %String, pVersionExpression As %String = "", pParameters As %String = "", Output pSC) As %Status [ Internal, Private, ServerOnly = 1 ]
{
	Set pSC = $$$OK
	Try {
		Set i%Class = pClass
		Set i%IndexName = pIndexName
		Set i%BaseIndexGlobal = pBaseIndexGlobal
		Set i%Offset = $QLENGTH(pBaseIndexGlobal) // Number of index subscripts before the interesting stuff.
		Set i%Name = pName
		Set i%Parameters = $ZConvert(pParameters,"L")
		Set ..IncludePrerelease = (..Parameters [ "prerelease")
		Set ..IncludeSnapshot = (..Parameters [ "snapshot")
		If (pVersionExpression = "") {
			Set pVersionExpression = "*"
		}
		Set pSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pVersionExpression,.tExpression)
		Set ..VersionExpression = tExpression
		If $$$ISERR(pSC) {
			Quit
		}
		Set pSC = ##super()
	} Catch e {
		Set pSC = e.AsStatus()
	}
	Quit pSC
}

/// At minimum, <METHOD>ContainsItem()</METHOD> must always be supported.
/// It returns 1 iff the given pItem is in the set S.
Method ContainsItem(pItem As %String) As %Boolean
{
	// Sample value of tRef:
	// ^IPM.Client.FSCacheI("SemVer","HSMOD.VirusScanner.Common",0,1,0,1,"snapshot")
	// NOTE: pItem is a row ID.
	Set tRef = $ClassMethod(i%Class,i%IndexName_"GetStored",pItem)
	If (tRef = "") { Quit 0 }
	
	Set tLength = $QLength(tRef)
	Set tName = $QSubscript(tRef,i%Offset+1)
	If (tName '= ..Name) && (..Name '= "") {
		Quit 0
	}
	
	Set tIsPrerelease = '$QSubscript(tRef,i%Offset+5)
	
	If ..IncludePrerelease < tIsPrerelease {
		Quit 0
	}
	
	Set tIsSnapshot = ($ZConvert($QSubscript(tRef,tLength),"L") = "snapshot") &&
		('tIsPrerelease || ($QSubscript(tRef,tLength-1) = -2))
	
	If ..IncludeSnapshot < tIsSnapshot {
		Quit 0
	}
	
	// The data of the index will be the semantic version.
	Set tVersion = ##class(%IPM.General.SemanticVersion).FromListBuild($Get(@tRef@(pItem)))
	Quit tVersion.Satisfies(..VersionExpression)
}

/// Supports %INSUB (eventually?) - for now called from class query.
Method NextItem(pItem As %String = "") As %String
{
	Set tNextItem = ""
	If (pItem '= "") {
		// NOTE: pItem is a row ID.
		Set tRef = $ClassMethod(i%Class,i%IndexName_"GetStored",pItem)
		Set tNextRef = $Query(@tRef@(pItem))
	} Else {
		Set tNextRef = $Query(@i%BaseIndexGlobal@(i%Name))
	}
	For {
		// Sample value of tNextRef:
		// ^IPM.Client.FSCacheI("SemVer","HSMOD.VirusScanner.Common",0,1,0,1,"snapshot")
		If (tNextRef = "") {
			Quit
		}
		
		// Ensure we're still looking at the correct base global.
		If ($QSubscript(tNextRef,i%Offset) '= $QSubscript(i%BaseIndexGlobal,i%Offset)) {
			Quit
		}
		
		// Ensure we're still looking at a version for the correct name.
		Set tName = $QSubscript(tNextRef,i%Offset+1)
		If (tName '= i%Name) && (i%Name '= "") {
			Quit
		}
		
		// TODO: Clever skipping of chunks based on expression/ranges and prerelease/snapshot flags.
		Set tID = $QSubscript(tNextRef,$QLENGTH(tNextRef))
		If ..ContainsItem(tID) {
			Set tNextItem = tID
			Quit
		}
		Set tNextRef = $Query(@tNextRef)
	}
	Quit tNextItem
}

/// Supports %INSUB (eventually?) - for now called from class query.
Method PreviousItem(pItem As %String = "") As %String
{
	Set tPreviousItem = ""
	If (pItem '= "") {
		// NOTE: pItem is a row ID.
		Set tRef = $ClassMethod(i%Class,i%IndexName_"GetStored",pItem)
		Set tPreviousRef = $Query(@tRef@(pItem),-1)
	} Else {
		Set tNextName = $Case(i%Name,"":"",:$Order(@i%BaseIndexGlobal@(i%Name)))
		Set tPreviousRef = $Query(@i%BaseIndexGlobal@(tNextName),-1)
	}
	For {
		// Sample value of tPreviousRef:
		// ^%IPM.Client.FSCacheI("SemVer","HSMOD.VirusScanner.Common",0,1,0,1,"snapshot")
		If (tPreviousRef = "") {
			Quit
		}
		
		// Ensure we're still looking at the correct base global.
		If ($QSubscript(tPreviousRef,i%Offset) '= $QSubscript(i%BaseIndexGlobal,i%Offset)) {
			Quit
		}
		
		// Ensure we're still looking at a version for the correct name.
		Set tName = $QSubscript(tPreviousRef,i%Offset+1)
		If (tName '= i%Name) && (i%Name '= "") {
			Quit
		}
		
		// TODO: Clever skipping of chunks based on expression/ranges and prerelease/snapshot flags.
		Set tID = $QSubscript(tPreviousRef,$QLENGTH(tPreviousRef))
		If ..ContainsItem(tID) {
			Set tPreviousItem = tID
			Quit
		}
		Set tPreviousRef = $Query(@tPreviousRef,-1)
	}
	Quit tPreviousItem
}

/// This is not inherited by classes defining an index of this type.
Query Matches(pClass As %String, pIndexName As %String, pBaseIndexGlobal As %String, pName As %String = "", pVersionExpression As %String = "*", pParameters As %String = "") As %Query(CONTAINID = 1, ROWSPEC = "ID:%String") [ SqlProc ]
{
}

ClassMethod MatchesExecute(ByRef qHandle As %Binary, pClass As %String, pIndexName As %String, pBaseIndexGlobal As %String, pName As %String = "", pVersionExpression As %String = "*", pParameters As %String = "") As %Status
{
	Set tSC = $$$OK
	Try {
		Kill qHandle
		Set qHandle("searcher") = ..%New(pClass,pIndexName,pBaseIndexGlobal,pName,pVersionExpression,pParameters,.tSC)
		$$$ThrowOnError(tSC)
		Set qHandle("item") = qHandle("searcher").PreviousItem("")
	} Catch e {
		Kill qHandle
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod MatchesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = MatchesExecute ]
{
	If (qHandle("item") = "") {
		Set AtEnd = 1
	} Else {
		Set Row = $ListBuild(qHandle("item"))
		Set qHandle("item") = qHandle("searcher").PreviousItem(qHandle("item"))
	}
	Quit $$$OK
}

ClassMethod MatchesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = MatchesExecute ]
{
	Quit $$$OK
}

}
