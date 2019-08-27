Class %ZPM.PackageManager.Core.ModuleInfo.QueryUtils
{

ClassMethod moduleSqlToList(pQuery As %String, pSearchCriteria As %ZPM.PackageManager.Core.SearchCriteria, ByRef pArgs) As %Library.ListOfObjects
{
	If '$IsObject($Get(pSearchCriteria)) {
		 Set pSearchCriteria = ##class(%ZPM.PackageManager.Core.SearchCriteria).%New()
	}
	Merge tArgs = pArgs
	Set tKeywordList = ""
	Set tWhereParts = ""
	Set tOrderByParts = ""
	If (pSearchCriteria.Name '= "") {
		Set tArgs($i(tArgs)) = pSearchCriteria.Name
		If (pSearchCriteria.VersionExpression '= "") {
			Set tArgs($i(tArgs)) = pSearchCriteria.VersionExpression
		} Else {
			Set tArgs($i(tArgs)) = "*"
		}
	} Else {
		Set tArgs($i(tArgs)) = ""
		Set tArgs($i(tArgs)) = "*"
	}
	
	Set tSearchParams = ""
	If (pSearchCriteria.IncludeSnapshots) {
		Set tSearchParams = tSearchParams_$ListBuild("snapshot")
	}
	If (pSearchCriteria.IncludePrerelease) {
		Set tSearchParams = tSearchParams_$ListBuild("prerelease")
	}
	Set tArgs($i(tArgs)) = $ListToString(tSearchParams," ")
	
	If (pSearchCriteria.Keywords.Count() > 0) {
		Set tWhereParts = tWhereParts_$ListBuild("%SIMILARITY(Manifest,?) > 0")
		For i=1:1:pSearchCriteria.Keywords.Count() {
			Set tKeywordList = tKeywordList_$ListBuild(pSearchCriteria.Keywords.GetAt(i))
		}
		Set tKeywordList = $ListFromString(tKeywordList," ")
		Set tArgs($i(tArgs)) = tKeywordList
	}
	
	If (tWhereParts '= "") {
		Set pQuery = pQuery_" where "_$ListToString(tWhereParts," and ")
	}
	
	// List exact version matches first.
	If (pSearchCriteria.VersionExpression '= "") {
		Set tOrderByParts = tOrderByParts_$ListBuild("case m.VersionString when ? then 0 else 1 end")
		Set tArgs($i(tArgs)) = pSearchCriteria.VersionExpression
	}
	
	If (tKeywordList '= "") {
		// TODO: Find some way to order by max similarity (or just similarity of latest version of the module) instead?
		Set tOrderByParts = tOrderByParts_$ListBuild("%SIMILARITY(Manifest,?) desc")
		Set tOrderByArgs($i(tOrderByArgs)) = tKeywordList
	}
	
	// TVF returns items in correct order - so order by that.
	Set tOrderByParts = tOrderByParts_$ListBuild("m.%id asc")
	
	If (tOrderByParts '= "") {
		Set pQuery = pQuery_" order by "_$ListToString(tOrderByParts,",")
		For i=1:1:$Get(tOrderByArgs) {
			Set tArgs($i(tArgs)) = tOrderByArgs(i)
		}
	}
	
	Set tList = ##class(%Library.ListOfObjects).%New()
	Set tRes = ##class(%SQL.Statement).%ExecDirect(,pQuery,tArgs...)
	If (tRes.%SQLCODE < 0) {
		$$$ThrowStatus($$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message))
	}
	While (tRes.%Next(.tStatus)) {
		If $$$ISERR(tStatus) {
			Quit
		}
		
		Set tModRef = ##class(%ZPM.PackageManager.Core.ResolvedModuleReference).%New()
		Set tModRef.Name = tRes.%Get("Name")
		Set tModRef.VersionString = tRes.%Get("VersionString")
		Do tList.Insert(tModRef)
	}
	If $$$ISERR(tStatus) {
		$$$ThrowStatus(tStatus)
	}
	Quit tList
}

}
