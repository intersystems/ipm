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
Method %OnNew(
	pClass As %String,
	pIndexName As %String,
	pBaseIndexGlobal As %String,
	pName As %String,
	pVersionExpression As %String = "",
	pParameters As %String = "",
	Output pSC) As %Status [ Internal, Private, ServerOnly = 1 ]
{
    set pSC = $$$OK
    try {
        set i%Class = pClass
        set i%IndexName = pIndexName
        set i%BaseIndexGlobal = pBaseIndexGlobal
        set i%Offset = $qlength(pBaseIndexGlobal) // Number of index subscripts before the interesting stuff.
        set i%Name = pName
        set i%Parameters = $zconvert(pParameters,"L")
        set ..IncludePrerelease = (..Parameters [ "prerelease")
        set ..IncludeSnapshot = (..Parameters [ "snapshot")
        if (pVersionExpression = "") {
            set pVersionExpression = "*"
        }
        set pSC = ##class(%IPM.General.SemanticVersionExpression).FromString(pVersionExpression,.tExpression)
        set ..VersionExpression = tExpression
        if $$$ISERR(pSC) {
            quit
        }
        set pSC = ##super()
    } catch e {
        set pSC = e.AsStatus()
    }
    quit pSC
}

/// At minimum, <METHOD>ContainsItem()</METHOD> must always be supported.
/// It returns 1 iff the given pItem is in the set S.
Method ContainsItem(pItem As %String) As %Boolean
{
    // Sample value of tRef:
    // ^IPM.Client.FSCacheI("SemVer","HSMOD.VirusScanner.Common",0,1,0,1,"snapshot")
    // NOTE: pItem is a row ID.
    set tRef = $classmethod(i%Class,i%IndexName_"GetStored",pItem)
    if (tRef = "") { quit 0 }

    set tLength = $qlength(tRef)
    set tName = $qsubscript(tRef,i%Offset+1)
    if (tName '= ..Name) && (..Name '= "") {
        quit 0
    }

    set tIsPrerelease = '$qsubscript(tRef,i%Offset+5)

    if ..IncludePrerelease < tIsPrerelease {
        quit 0
    }

    set tIsSnapshot = ($zconvert($qsubscript(tRef,tLength),"L") = "snapshot") &&
        ('tIsPrerelease || ($qsubscript(tRef,tLength-1) = -2))

    if ..IncludeSnapshot < tIsSnapshot {
        quit 0
    }

    // The data of the index will be the semantic version.
    set tVersion = ##class(%IPM.General.SemanticVersion).FromListBuild($get(@tRef@(pItem)))
    quit tVersion.Satisfies(..VersionExpression)
}

/// Supports %INSUB (eventually?) - for now called from class query.
Method NextItem(pItem As %String = "") As %String
{
    set tNextItem = ""
    if (pItem '= "") {
        // NOTE: pItem is a row ID.
        set tRef = $classmethod(i%Class,i%IndexName_"GetStored",pItem)
        set tNextRef = $query(@tRef@(pItem))
    } else {
        set tNextRef = $query(@i%BaseIndexGlobal@(i%Name))
    }
    for {
        // Sample value of tNextRef:
        // ^IPM.Client.FSCacheI("SemVer","HSMOD.VirusScanner.Common",0,1,0,1,"snapshot")
        if (tNextRef = "") {
            quit
        }

        // Ensure we're still looking at the correct base global.
        if ($qsubscript(tNextRef,i%Offset) '= $qsubscript(i%BaseIndexGlobal,i%Offset)) {
            quit
        }

        // Ensure we're still looking at a version for the correct name.
        set tName = $qsubscript(tNextRef,i%Offset+1)
        if (tName '= i%Name) && (i%Name '= "") {
            quit
        }

        // TODO: Clever skipping of chunks based on expression/ranges and prerelease/snapshot flags.
        set tID = $qsubscript(tNextRef,$qlength(tNextRef))
        if ..ContainsItem(tID) {
            set tNextItem = tID
            quit
        }
        set tNextRef = $query(@tNextRef)
    }
    quit tNextItem
}

/// Supports %INSUB (eventually?) - for now called from class query.
Method PreviousItem(pItem As %String = "") As %String
{
    set tPreviousItem = ""
    if (pItem '= "") {
        // NOTE: pItem is a row ID.
        set tRef = $classmethod(i%Class,i%IndexName_"GetStored",pItem)
        set tPreviousRef = $query(@tRef@(pItem),-1)
    } else {
        set tNextName = $case(i%Name,"":"",:$order(@i%BaseIndexGlobal@(i%Name)))
        set tPreviousRef = $query(@i%BaseIndexGlobal@(tNextName),-1)
    }
    for {
        // Sample value of tPreviousRef:
        // ^%IPM.Client.FSCacheI("SemVer","HSMOD.VirusScanner.Common",0,1,0,1,"snapshot")
        if (tPreviousRef = "") {
            quit
        }

        // Ensure we're still looking at the correct base global.
        if ($qsubscript(tPreviousRef,i%Offset) '= $qsubscript(i%BaseIndexGlobal,i%Offset)) {
            quit
        }

        // Ensure we're still looking at a version for the correct name.
        set tName = $qsubscript(tPreviousRef,i%Offset+1)
        if (tName '= i%Name) && (i%Name '= "") {
            quit
        }

        // TODO: Clever skipping of chunks based on expression/ranges and prerelease/snapshot flags.
        set tID = $qsubscript(tPreviousRef,$qlength(tPreviousRef))
        if ..ContainsItem(tID) {
            set tPreviousItem = tID
            quit
        }
        set tPreviousRef = $query(@tPreviousRef,-1)
    }
    quit tPreviousItem
}

/// This is not inherited by classes defining an index of this type.
Query Matches(
	pClass As %String,
	pIndexName As %String,
	pBaseIndexGlobal As %String,
	pName As %String = "",
	pVersionExpression As %String = "*",
	pParameters As %String = "") As %Query(CONTAINID = 1, ROWSPEC = "ID:%String") [ SqlProc ]
{
}

ClassMethod MatchesExecute(
	ByRef qHandle As %Binary,
	pClass As %String,
	pIndexName As %String,
	pBaseIndexGlobal As %String,
	pName As %String = "",
	pVersionExpression As %String = "*",
	pParameters As %String = "") As %Status
{
    set tSC = $$$OK
    try {
        kill qHandle
        set qHandle("searcher") = ..%New(pClass,pIndexName,pBaseIndexGlobal,pName,pVersionExpression,pParameters,.tSC)
        $$$ThrowOnError(tSC)
        set qHandle("item") = qHandle("searcher").PreviousItem("")
    } catch e {
        kill qHandle
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod MatchesFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = MatchesExecute ]
{
    if (qHandle("item") = "") {
        set AtEnd = 1
    } else {
        set Row = $listbuild(qHandle("item"))
        set qHandle("item") = qHandle("searcher").PreviousItem(qHandle("item"))
    }
    quit $$$OK
}

ClassMethod MatchesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = MatchesExecute ]
{
    quit $$$OK
}

}
