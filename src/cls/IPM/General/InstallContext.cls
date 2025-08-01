Include %IPM.Common

Class %IPM.General.InstallContext Extends %IPM.General.Singleton
{

/// If set to 1, calls to %Get must return an instance of this class created in the current namespace; a new instance will be created if none exists.
Parameter NAMESPACESCOPE As BOOLEAN = 1;

Property DependencyGraph [ MultiDimensional, Private ];

Property CacheTempIndex As %Integer [ Private ];

Method SetGraph(ByRef pDependencyGraph)
{
    kill ..DependencyGraph
    merge ..DependencyGraph = pDependencyGraph
}

Method SetCacheTempIndex(pIndex As %Integer = "")
{
    set ..CacheTempIndex = pIndex
}

Method GetModuleList() As %List
{
    set tList = ""
    set tModuleName = ""
    for {
        set tModuleName = $order(..DependencyGraph(tModuleName))
        if (tModuleName = "") {
            quit
        }
        set tList = tList_$listbuild(tModuleName)
    }
    quit tList
}

Method ModuleIsDependency(pModuleName As %String) As %Boolean
{
    quit ($data(..DependencyGraph(pModuleName)) > 0)
}

Method GetPendingModuleList() As %List
{
    if (..CacheTempIndex = "") {
        quit ""
    }

    // The caller should have the temp global locked, but just in case...
    merge tGraph = $$$ZPMTempLoadGraph(..CacheTempIndex)

    set tList = ""
    set tModuleName = ""
    for {
        set tModuleName = $order(tGraph(tModuleName))
        if (tModuleName = "") {
            quit
        }
        set tList = tList_$listbuild(tModuleName)
    }
    quit tList
}

Method ModuleIsPending(pModuleName As %String) As %Boolean
{
    if (..CacheTempIndex = "") {
        quit 0
    }
    quit ($data($$$ZPMTempLoadGraph(..CacheTempIndex,pModuleName)) > 0)
}

}
