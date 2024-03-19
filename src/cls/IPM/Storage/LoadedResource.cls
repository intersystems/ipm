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

Index LoadedResource On LoadedResource As Exact;

ClassMethod TrackResourceNames(pModuleName As %String, pResourceName As %String, pResourceList As %String, pNamespace As %String = {$Namespace}) As %Status
{
	Set tSC = $$$OK
	Set tRecordsCreated = 0
	Try {
		Set tResult = ##class(%SQL.Statement).%ExecDirect(,"delete from %IPM_Storage.LoadedResource "_
			"where Namespace = ? and ModuleName = ? and ResourceUniqueName = ?",
			pNamespace,pModuleName,pResourceName)
		If (tResult.%SQLCODE < 0) {
			// Purge cached query and retry
			Do $SYSTEM.SQL.PurgeCQClass("%sqlcq."_pNamespace_".cls1")
			Set tNewResult = ##class(%SQL.Statement).%ExecDirect(,"delete from %IPM_Storage.LoadedResource "_
			"where Namespace = ? and ModuleName = ? and ResourceUniqueName = ?",
			pNamespace,pModuleName,pResourceName)
			If (tNewResult.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tNewResult.%SQLCODE,tNewResult.%Message)
			}
		}
		
		Set tResourceList = $ListFromString(pResourceList)
		Set tPointer = 0
		While $ListNext(tResourceList,tPointer,tName) {
			Set tInstance = ..%New()
			Set tInstance.Namespace = pNamespace
			Set tInstance.ModuleName = pModuleName
			Set tInstance.ResourceUniqueName = pResourceName
			Set tInstance.LoadedResource = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(tName)
			$$$ThrowOnError(tInstance.%Save())
			Set tRecordsCreated = 1
		}
	} Catch e {
		Set tSC = e.AsStatus()
		
		If tRecordsCreated {
			// Since using IRISTEMP, need an alternative approach to remove any rows that have been created:
			Set tResult = ##class(%SQL.Statement).%ExecDirect(,"delete from %IPM_Storage.LoadedResource "_
				"where Namespace = ? and ModuleName = ? and ResourceUniqueName = ?",
				pNamespace,pModuleName,pResourceName)
			If (tResult.%SQLCODE < 0) {
				Set tSC = $$$ADDSC(tSC,$$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message))
			}
		}
	}
	Quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod Validate(pNamespace As %String = {$Namespace}, Output pErrorList) As %Status
{
	Set tSC = $$$OK
	Try {
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
		Set tQuery = "select LoadedResource,ModuleName,ActualModule from ( "_
			"	select LoadedResource,ModuleName,%IPM_ExtensionBase.Utils_GetHomeModuleName(LoadedResource) ActualModule "_
			"	from %IPM_Storage.LoadedResource "_
			"	where Namespace = ?)"_
			"	where ModuleName != ActualModule"
		Set tResult = ##class(%SQL.Statement).%ExecDirect(,tQuery,pNamespace)
		
		While tResult.%Next(.tSC) {
			Set tMsg = "Resource '%1' was loaded for module '%2', but is part of module '%3'"
			Set pErrorList($i(pErrorList)) = $$$FormatText(tMsg,tResult.%Get("LoadedResource"),tResult.%Get("ModuleName"),tResult.%Get("ActualModule"))
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod Clear(pNamespace As %String = {$Namespace}) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tResult = ##class(%SQL.Statement).%ExecDirect(,"delete from %IPM_Storage.LoadedResource "_
			"where Namespace = ?",
			pNamespace)
		If (tResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod ReportConflicts()
{
	Try {
		$$$ThrowOnError(..Validate(,.tErrorList))
		For tIndex=1:1:$Get(tErrorList) {
			Write !,"WARNING: ",tErrorList(tIndex)
		}
	} Catch e {
		Set tSC = e.AsStatus()
		Do $System.OBJ.DisplayError(tSC)
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
