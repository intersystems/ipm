Class %IPM.Storage.LoadedResource Extends %Persistent
{

Parameter DEFAULTGLOBAL = "^IRIS.Temp.IPM.LoadedResource";

Property Namespace As %String(MAXLEN = 64) [ Required ];

Property ModuleName As %String(MAXLEN = 255) [ Required ];

Property ResourceUniqueName As %String(MAXLEN = 255) [ Required ];

Property LoadedResource As %String(MAXLEN = 255) [ Required ];

ForeignKey ModuleNameFK(ModuleName) References %IPM.Storage.Module(Name) [ OnDelete = cascade ];

ForeignKey ResourceUniqueNameFK(ResourceUniqueName) References %IPM.Storage.ResourceReference(ResourceName) [ OnDelete = cascade ];

Index NamespaceIndex On Namespace [ Type = bitmap ];

Index ModuleNameIndex On ModuleName [ Type = bitmap ];

Index ResourceUniqueNameIndex On ResourceUniqueName [ Type = bitmap ];

Index LoadedResourceIndex On LoadedResource As Exact;

ClassMethod TrackResourceNames(
	pModuleName As %String,
	pResourceName As %String,
	pResourceList As %String,
	pNamespace As %String = {$namespace}) As %Status
{
    set tSC = $$$OK
    set tRecordsCreated = 0
    try {
        set query = "delete from %IPM_Storage.LoadedResource "_
            "where Namespace = ? and ModuleName = ? and ResourceUniqueName = ?"
        set tResult = ##class(%SQL.Statement).%ExecDirect(,query,
            pNamespace,pModuleName,pResourceName)
        if (tResult.%SQLCODE < 0) {
            // Purge cached query and retry
            do $system.SQL.PurgeCQClass("%sqlcq."_pNamespace_".cls1")
            set tNewResult = ##class(%SQL.Statement).%ExecDirect(,query,
            pNamespace,pModuleName,pResourceName)
            if (tNewResult.%SQLCODE < 0) {
                throw ##class(%Exception.SQL).CreateFromSQLCODE(tNewResult.%SQLCODE,tNewResult.%Message)
            }
        }

        set tResourceList = $listfromstring(pResourceList)
        set tPointer = 0
        while $listnext(tResourceList,tPointer,tName) {
            set tInstance = ..%New()
            set tInstance.Namespace = pNamespace
            set tInstance.ModuleName = pModuleName
            set tInstance.ResourceUniqueName = pResourceName
            set tInstance.LoadedResource = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(tName)
            $$$ThrowOnError(tInstance.%Save())
            set tRecordsCreated = 1
        }
    } catch e {
        set tSC = e.AsStatus()
        if tRecordsCreated {
            // Since using IRISTEMP, need an alternative approach to remove any rows that have been created:
            set tResult = ##class(%SQL.Statement).%ExecDirect(,query,
                pNamespace,pModuleName,pResourceName)
            if (tResult.%SQLCODE < 0) {
                set tSC = $$$ADDSC(tSC,$$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message))
            }
        }
    }
    quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod Validate(
	pNamespace As %String = {$namespace},
	Output pErrorList) As %Status
{
    set tSC = $$$OK
    try {
        // This is an interesting query, but not necessarily as useful as the one actually used below, which
        // specifies which module *should not* contain the specified resources.
        /*
        // Find any resources that were loaded twice.
        Set tQuery = "select LoadedResource,Sources from ("_
            "	select LoadedResource,count(distinct ModuleName) as Matches,LIST(ModuleName||':'||ResourceUniqueName) As Sources "_
            "	from %IPM_Storage.LoadedResource "_
            "	where Namespace = ? "_
            "	group by LoadedResource) duplicates "_
            "where duplicates.Matches > 1"
        Set tDuplicateResult = ##class(%SQL.Statement).%ExecDirect(,tQuery,pNamespace)
        Do tDuplicateResult.%Display()
        */

        // Find any resources that were loaded as part of a different module than the one that says it contains them.
        set tQuery = "select LoadedResource,ModuleName,ActualModule from ( "_
            "	select LoadedResource,ModuleName,%IPM_ExtensionBase.Utils_GetHomeModuleName(LoadedResource) ActualModule "_
            "	from %IPM_Storage.LoadedResource "_
            "	where Namespace = ?)"_
            "	where ModuleName != ActualModule"
        set tResult = ##class(%SQL.Statement).%ExecDirect(,tQuery,pNamespace)

        while tResult.%Next(.tSC) {
            set tMsg = "Resource '%1' was loaded for module '%2', but is part of module '%3'"
            set pErrorList($increment(pErrorList)) = $$$FormatText(tMsg,tResult.%Get("LoadedResource"),tResult.%Get("ModuleName"),tResult.%Get("ActualModule"))
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod Clear(pNamespace As %String = {$namespace}) As %Status
{
    set tSC = $$$OK
    try {
        set tResult = ##class(%SQL.Statement).%ExecDirect(,
            "delete from %IPM_Storage.LoadedResource where Namespace = ?",
            pNamespace
        )
        if (tResult.%SQLCODE < 0) {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod ReportConflicts()
{
    try {
        $$$ThrowOnError(..Validate(,.tErrorList))
        for tIndex=1:1:$get(tErrorList) {
            write !,"WARNING: ",tErrorList(tIndex)
        }
    } catch e {
        set tSC = e.AsStatus()
        do $system.OBJ.DisplayError(tSC)
    }
}

Storage Default
{
<Data name="LoadedResourceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Namespace</Value>
</Value>
<Value name="3">
<Value>ModuleName</Value>
</Value>
<Value name="4">
<Value>ResourceUniqueName</Value>
</Value>
<Value name="5">
<Value>LoadedResource</Value>
</Value>
</Data>
<DataLocation>^IRIS.Temp.IPM.LoadedResourceD</DataLocation>
<DefaultData>LoadedResourceDefaultData</DefaultData>
<IdLocation>^IRIS.Temp.IPM.LoadedResourceD</IdLocation>
<IndexLocation>^IRIS.Temp.IPM.LoadedResourceI</IndexLocation>
<StreamLocation>^IRIS.Temp.IPM.LoadedResourceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
