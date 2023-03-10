Include %IPM.Common

Class %IPM.General.InstallContext Extends %IPM.General.Singleton
{

/// If set to 1, calls to %Get must return an instance of this class created in the current namespace; a new instance will be created if none exists.
Parameter NAMESPACESCOPE As BOOLEAN = 1;

Property DependencyGraph [ MultiDimensional, Private ];

Property CacheTempIndex As %Integer [ Private ];

Method SetGraph(ByRef pDependencyGraph)
{
	Kill ..DependencyGraph
	Merge ..DependencyGraph = pDependencyGraph
}

Method SetCacheTempIndex(pIndex As %Integer = "")
{
	Set ..CacheTempIndex = pIndex
}

Method GetModuleList() As %List
{
	Set tList = ""
	Set tModuleName = ""
	For {
		Set tModuleName = $Order(..DependencyGraph(tModuleName))
		If (tModuleName = "") {
			Quit
		}
		Set tList = tList_$ListBuild(tModuleName)
	}
	Quit tList
}

Method ModuleIsDependency(pModuleName As %String) As %Boolean
{
	Quit ($Data(..DependencyGraph(pModuleName)) > 0)
}

Method GetPendingModuleList() As %List
{
	If (..CacheTempIndex = "") {
		Quit ""
	}
	
	// The caller should have the temp global locked, but just in case...
	Merge tGraph = $$$ZPMTempLoadGraph(..CacheTempIndex)
	
	Set tList = ""
	Set tModuleName = ""
	For {
		Set tModuleName = $Order(tGraph(tModuleName))
		If (tModuleName = "") {
			Quit
		}
		Set tList = tList_$ListBuild(tModuleName)
	}
	Quit tList
}

Method ModuleIsPending(pModuleName As %String) As %Boolean
{
	If (..CacheTempIndex = "") {
		Quit 0
	}
	Quit ($Data($$$ZPMTempLoadGraph(..CacheTempIndex,pModuleName)) > 0)
}

}
