/// <p>Functional index on semantic versions. This serves two purposes:
/// <ol>
/// <li>Enable searching based on module name and semantic version expression without scanning the whole extent</li>
/// <li>Simplify ordering based on latest semantic version, properly handling major/minor/patch version numbers and prerelease designations.</li>
/// </ol>
/// </p>
/// <p>To use this index in a class, define an index on a string property (the module name) and a property of type <class>%ZPM.PackageManager.Core.SemanticVersion</class>.
/// <code>
/// Index SemVer On (Name, Version) As %ZPM.PackageManager.Server.SemVerIndex;
/// </code>
/// You must also define a property with the same name as that index, as follows:
/// <code>
/// Property SemVer As %String(MAXLEN = 512) [ SqlComputeCode = {set {*} = ##class(%ZPM.PackageManager.Server.Module).SemVerNode({Name},{Version})}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];
/// </code>
/// </p>
/// <p>For an example, see <class>%ZPM.PackageManager.Server.Module</class>.</p>
/// <p>To use the generated Find method and the %ZPM.PackageManager.Server.SemVerFind (as in the example of %ZPM_PackageManager_Server._Module):
/// <code>
/// SELECT Name,VersionString FROM %ZPM_PackageManager_Server._Module WHERE ID %INSET %ZPM_PackageManager_Server.Module_SemVerFind('HS.JSON','0.x','snapshot')
/// </code>
/// To facilitate ordering by semantic version, classes that define such indices may also implement class queries to wrap %ZPM.PackageManager.Server.SemVerFind:Matches.
/// </p>
Class %ZPM.PackageManager.Server.SemVerIndex Extends %Library.FunctionalIndex [ ClassType = index, System = 3 ]
{

ClassMethod Find(pName As %Binary, pVersionExpression As %String = "", pParameters As %String = "") As %Library.Binary [ CodeMode = generator, ServerOnly = 1, SqlProc ]
{
	// Above, pName needs to be %Binary due to inheritance.
	// Don't generate if %mode is "method" - this prevents generation for %ZPM.PackageManager.Server.SemVerIndex itself.
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
        $$$GENERATE(" Quit ##class(%ZPM.PackageManager.Server.SemVerFind).%New("_$$$QUOTE(%class)_","_$$$QUOTE(%property)_",$Name("_tIdxGlobal_"),pName,pVersionExpression,pParameters)")
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
	Set tGlobal = ##class(%ZPM.PackageManager.Server.SemVerIndex).GetIndexGlobalNode(pGlobal, pName, pVersion)
	Set @tGlobal@(pID) = pVersion
}

ClassMethod Delete(pGlobal, pID, pName, pVersion)
{
	Set tGlobal = ##class(%ZPM.PackageManager.Server.SemVerIndex).GetIndexGlobalNode(pGlobal, pName, pVersion)
	Kill @tGlobal@(pID)
}

ClassMethod GetIndexGlobalNode(pGlobal, pName, pVersion) As %String
{
	Set $ListBuild(tMajor,tMinor,tPatch,tPreRelease,tBuild) = pVersion
	If (tBuild = "") && (tPreRelease = "") {
		// No build or prerelease - this is simple.
		Set tGlobal = $Name(@pGlobal@(pName,tMajor,tMinor,tPatch,2))
	} ElseIf (tPreRelease = "") {
		// No prerelease, but has a build - also simple.
		Set tGlobal = $Name(@pGlobal@(pName,tMajor,tMinor,tPatch,1+($ZConvert(tBuild,"L")'="snapshot"),tBuild))
	} Else {
		// Less simple...
		Set tPreRelease = $Get(tPreRelease),tBuild = $Get(tBuild)
		Set tPreReleaseParts = $ListFromString(tPreRelease,".")
		Set tPtr = 0
		Set tGlobal = $Name(@pGlobal@(pName,tMajor,tMinor,tPatch,0))
		While $ListNext(tPreReleaseParts,tPtr,tPart) {
			Set tGlobal = $Name(@tGlobal@(tPart))
		}
		If (tBuild '= "") {
			Set tGlobal = $Name(@tGlobal@(-1,tBuild))
		}
	}
	Quit tGlobal
}

ClassMethod Node(pName, pVersion) As %String [ CodeMode = generator, ServerOnly = 1 ]
{
    If (%mode '= "method") {
        Set tIdxGlobal = ..IndexLocationForCompile(%class,%property)
        $$$GENERATE(" Quit ##class(%ZPM.PackageManager.Server.SemVerIndex).GetIndexGlobalNode($Name("_tIdxGlobal_"),pName,pVersion)")
    }
}

}
