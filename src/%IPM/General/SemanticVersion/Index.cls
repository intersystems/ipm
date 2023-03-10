/// <p>Functional index on semantic versions. This serves two purposes:
/// <ol>
/// <li>Enable searching based on module name and semantic version expression without scanning the whole extent</li>
/// <li>Simplify ordering based on latest semantic version, properly handling major/minor/patch version numbers and prerelease designations.</li>
/// </ol>
/// </p>
/// <p>To use this index in a class, define an index on a string property (the module name) and a property of type <class>%IPM.General.SemanticVersion</class>.
/// <code>
/// Index SemVer On (Name, Version) As %IPM.General.SemanticVersion.Index;
/// </code>
/// You must also define a property with the same name as that index, as follows:
/// <code>
/// Property SemVer As %String(MAXLEN = 512) [ SqlComputeCode = {set {*} = ##class(%IPM.Repo.Filesystem.Cache).SemVerNode({Name},{Version})}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];
/// </code>
/// </p>
/// <p>For an example, see <class>%IPM.Repo.Filesystem.Cache</class>.</p>
/// <p>To use the generated Find method and the %IPM.General.SemanticVersion.Find (as in the example of %IPM_PackageManager_Server._Module):
/// <code>
/// SELECT Name,VersionString FROM %IPM_PackageManager_Server._Module WHERE ID %INSET %IPM_PackageManager_Server.Module_SemVerFind('HS.JSON','0.x','snapshot')
/// </code>
/// To facilitate ordering by semantic version, classes that define such indices may also implement class queries to wrap %IPM.General.SemanticVersion.Find:Matches.
/// </p>
Class %IPM.General.SemanticVersion.Index Extends %Library.FunctionalIndex [ ClassType = index, System = 3 ]
{

ClassMethod Find(pName As %Binary, pVersionExpression As %String = "", pParameters As %String = "") As %Library.Binary [ CodeMode = generator, ServerOnly = 1, SqlProc ]
{
	// Above, pName needs to be %Binary due to inheritance.
	// Don't generate if %mode is "method" - this prevents generation for %IPM.General.SemanticVersion.Index itself.
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
        $$$GENERATE(" Quit ##class(%IPM.General.SemanticVersion.Find).%New("_$$$QUOTE(%class)_","_$$$QUOTE(%property)_",$Name("_tIdxGlobal_"),pName,pVersionExpression,pParameters)")
    }
}

/// This method is invoked when a new instance of a class is inserted into the database.
ClassMethod InsertIndex(pID As %CacheString, pArg... As %Binary) [ CodeMode = generator, ServerOnly = 1 ]
{
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
        $$$GENERATE(" Do .."_%property_"Insert($Name("_tIdxGlobal_"),pID,pArg(1),pArg(2))")
    }
}

/// This method is invoked when an existing instance of a class is updated.
ClassMethod UpdateIndex(pID As %CacheString, pArg... As %Binary) [ CodeMode = generator, ServerOnly = 1 ]
{
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
        $$$GENERATE(" Do .."_%property_"Delete($Name("_tIdxGlobal_"),pID,pArg(3),pArg(4))")
        $$$GENERATE(" Do .."_%property_"Insert($Name("_tIdxGlobal_"),pID,pArg(1),pArg(2))")
    }
}

/// This method is invoked when an existing instance of a class is deleted.
ClassMethod DeleteIndex(pID As %CacheString, pArg... As %Binary) [ CodeMode = generator, ServerOnly = 1 ]
{
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
        $$$GENERATE(" Do .."_%property_"Delete($Name("_tIdxGlobal_"),pID,pArg(1),pArg(2))")
    }
}

ClassMethod IndexLocationForCompile(pClassName As %String, pIndexName As %String) As %String
{
    Set tStorage = ##class(%Dictionary.ClassDefinition).%OpenId(pClassName).Storages.GetAt(1).IndexLocation
    Quit $Name(@tStorage@(pIndexName))
}

ClassMethod IndexLocation() [ CodeMode = generator, ServerOnly = 1 ]
{
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
        $$$GENERATE(" Quit "_$$$QUOTE(tIdxGlobal))
    }
}

ClassMethod PurgeIndex() [ CodeMode = generator, ServerOnly = 1 ]
{
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
        $$$GENERATE(" Kill " _ tIdxGlobal)
    }
}

ClassMethod SortBeginIndex() [ CodeMode = generator, ServerOnly = 1 ]
{
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
		// No-op?
        $$$GENERATE(" Quit")
    }
}

ClassMethod SortEndIndex() [ CodeMode = generator, ServerOnly = 1 ]
{
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
		// No-op?
        $$$GENERATE(" Quit")
    }
}

ClassMethod Insert(pGlobal, pID, pName, pVersion)
{
	Set tGlobal = ##class(%IPM.General.SemanticVersion.Index).GetIndexGlobalNode(pGlobal, pName, pVersion)
	Set @tGlobal@(pID) = pVersion
}

ClassMethod Delete(pGlobal, pID, pName, pVersion)
{
	Set tGlobal = ##class(%IPM.General.SemanticVersion.Index).GetIndexGlobalNode(pGlobal, pName, pVersion)
	Kill @tGlobal@(pID)
}

ClassMethod GetIndexGlobalNode(pGlobal, pName, pVersion) As %String
{
	// The purpose of this method is to translate a semantic version into a global name that has
	// a proper semantic version sorting order (most notably, for snapshot and prerelease versions)
	// when traversed with $Query. (Forward is ascending order from earliest to latest; reverse, which is
	// more likely useful, is descending order from latest to earliest version.)
	Set $ListBuild(tMajor,tMinor,tPatch,tPreRelease,tBuild) = pVersion
	If (tBuild = "") && (tPreRelease = "") {
		// No build or prerelease - this is simple.
		Set tGlobal = $Name(@pGlobal@(pName,tMajor,tMinor,tPatch,2))
	} ElseIf (tPreRelease = "") {
		// No prerelease, but has a build - also simple.
		Set tGlobal = $Name(@pGlobal@(pName,tMajor,tMinor,tPatch,1+($ZConvert(tBuild,"L")'="snapshot"),tBuild))
	} Else {
		// Less simple. Split dot-separated pieces of the prerelease into individual subscripts.
		Set tPreRelease = $Get(tPreRelease)
		Set tBuild = $Get(tBuild)
		Set tPreReleaseParts = $ListFromString(tPreRelease,".")
		Set tPtr = 0
		Set tGlobal = $Name(@pGlobal@(pName,tMajor,tMinor,tPatch,0))
		While $ListNext(tPreReleaseParts,tPtr,tPart) {
			Set tGlobal = $Name(@tGlobal@(tPart))
		}
		
		// Mark the end of a prerelease version with something that will force collation earlier than 
		// e.g., ^global(-2,build) (for a snapshot version) collates before ^global(-1) (no build metadata), which collates
		// before ^global(-1,build) (for other build metadata), which collates before ^global("beta",3,-2,"snapshot")
		// (for a "later" prerelease version with more dot-separated parts).
		// A reverse $query should go from later to earlier versions.
		If ($ZConvert(tBuild,"L") = "snapshot") {
			Set tGlobal = $Name(@tGlobal@(-2,tBuild))
		} ElseIf (tBuild '= "") {
			Set tGlobal = $Name(@tGlobal@(-1,tBuild))
		} Else {
			Set tGlobal = $Name(@tGlobal@(-1))
		}
	}
	Quit tGlobal
}

ClassMethod Node(pName, pVersion) As %String [ CodeMode = generator, ServerOnly = 1 ]
{
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
        $$$GENERATE(" Quit ##class(%IPM.General.SemanticVersion.Index).GetIndexGlobalNode($Name("_tIdxGlobal_"),pName,pVersion)")
    }
}

}
