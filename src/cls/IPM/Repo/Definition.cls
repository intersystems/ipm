Include (%syPrompt, %IPM.Common)

Class %IPM.Repo.Definition Extends (%Persistent, %ZEN.DataModel.Adaptor, %IPM.CLI.Commands) [ Abstract ]
{

Parameter DEFAULTGLOBAL = "^IPM.Repo.Definition";

Parameter DOMAIN = "ZPM";

/// Display name for this type of repository, shown in the UI and package manager shell.
Parameter DISPLAYNAME As STRING [ Abstract ];

/// Short/logical name for this type of repository, used in the package manager shell as an alternative to the full class name.
Parameter MONIKER As STRING [ Abstract ];

Parameter MONIKERALIAS As STRING [ Abstract ];

/// The maximum number of tabs to display for padding purposes.
/// Override this in subclasses to provide more padding.
Parameter MaxDisplayTabCount As INTEGER = 3;

Index ServerDefinitionKey On Name [ Unique ];

Property Name As %String(MAXLEN = 100) [ Required ];

Property Enabled As %Boolean [ InitialExpression = 1 ];

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {set {*} = ""}, SqlComputed ];

Property Snapshots As %Boolean [ InitialExpression = 0 ];

Property Prereleases As %Boolean [ InitialExpression = 0 ];

/// If set to a non-empty value, this will be used as the sort order for this repository, bypassing the GetSortOrder() method.
/// This should be only configured by IPM during certain processes (e.g., installing depdenencies from .modules directory).
/// There is no current plan to support configuring this from the package manager shell.
Property OverriddenSortOrder As %Integer [ Internal ];

ClassMethod %GetCommandStructure(Output pCommandStructure)
{
    kill pCommandStructure
    set tRes = ##class(%Dictionary.ClassDefinitionQuery).SubclassOfFunc(..%ClassName(1))
    while tRes.%Next(.tSC) {
        do $classmethod(tRes.Name, "%GetOneCommandStructure", .tCommandStructure)
        merge pCommandStructure("repo") = tCommandStructure("repo")
    }
}

ClassMethod CollectServerTypes(Output types) As %Status
{
    set rs = ##class(%Dictionary.ClassDefinitionQuery).SubclassOfFunc(..%ClassName(1))

    while rs.%Next() {
        set name = rs.Name
        set moniker = $parameter(name, "MONIKER")
        continue:moniker=""
        set types(moniker) = name
        set aliasList = $listfromstring($parameter(name, "MONIKERALIAS"))
        set ptr = 0
        while $listnext(aliasList, ptr, alias) {
            merge types(alias) = types(moniker)
        }
    }

    return $$$OK
}

/// Boolean flag indicating that modules installed from this repository
/// are ALWAYS installed in non-developer mode.
Property ReadOnly As %Boolean [ InitialExpression = 0 ];

/// Returns a client to interact with this server.
Method GetPackageService() As %IPM.Repo.IPackageService [ Abstract ]
{
}

/// Returns a client to publish modules/applications to this server.
/// If publishing modules/applications is not supported, returns $$$NULLOREF.
/// Errors are thrown as exceptions.
Method GetPublishService() As %IPM.Repo.IPublishService [ Abstract ]
{
}

ClassMethod SortOrder(pID As %String) As %Integer [ SqlProc ]
{
    set tServer = ..%OpenId(pID)
    if tServer.OverriddenSortOrder '= "" {
        quit tServer.OverriddenSortOrder
    }
    quit tServer.GetSortOrder()
}

/// Get a number of TABs (ascii 9) for display padding purposes.
/// A total of (..#MaxDisplayTabCount - pDecrement) tabs are returned
/// This is used to align output in the package manager shell.
/// If a new option is added to the display, only the parameter `#MaxDisplayTabCount` needs to be changed.
ClassMethod Padding(pDecrement As %Integer = 0) As %String [ Internal ]
{
    set pDecrement = ..#MaxDisplayTabCount - pDecrement
    set tTabs = ""
    for i = 1:1:pDecrement {
        set tTabs = tTabs_$char(9)
    }
    return tTabs
}

/// Outputs information about this server to the current device.
/// Subclasses may override to show additional information, but should typically call ##super() at the beginning.
Method Display()
{
    write !,..Name
    write !,$char(9),"Source: ",..Padding(1),..Details
    write !,$char(9),"Enabled?",..Padding(1),$$$YesNo(..Enabled)
    write !,$char(9),"Available?",..Padding(1),$$$YesNo(..GetPackageService().IsAvailable())
    write !,$char(9),"Use for Snapshots?",..Padding(2),$$$YesNo(..Snapshots)
    write !,$char(9),"Use for Prereleases?",..Padding(2),$$$YesNo(..Prereleases)
    write !,$char(9),"Is Read-Only?",..Padding(1),$$$YesNo(..ReadOnly)
}

/// Called from package manager shell to create or update an instance of this class.
/// Acceptable values in <var>pModifiers</var> and <var>pData</var> may vary between classes, but
/// some (such as "name", "enabled", "snapshots", and "prereleases") are common to all.
/// For a full list of modifiers, see the Commands XDATA block in <class>%IPM.Main</class>.
/// If specified, <var>pExpectedType</var> will be compared against the full classname of the existing
/// instance matched by <var>pModifiers("name")</var>; an error will be returned if they do not match.
ClassMethod Configure(
	pInteractive As %Boolean = 1,
	ByRef pModifiers,
	ByRef pData,
	pExpectedType As %Dictionary.Classname = "") As %Status [ Final ]
{
    set tSC = $$$OK
    try {
        set tName = $get(pModifiers("name"))

        if (pInteractive && (tName = "")) {
            set tResponse = ##class(%Library.Prompt).GetString("Name: ",.tName)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
            }
        }

        set tIsNew = 0
        set tInstance = $$$NULLOREF
        if ..ServerDefinitionKeyExists(tName) {
            set tInstance = ..ServerDefinitionKeyOpen(tName,,.tSC)
            $$$ThrowOnError(tSC)

            if (pExpectedType '= "") && (pExpectedType '= $classname(tInstance)) {
                set tMessage = "Repository '%1' is configured as a different type. Use a different name, or delete it (repo -n %1 -delete) and run the previous command again."
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText(tMessage,tName))
                $$$ThrowStatus(tSC)
            }
        }

        if '$isobject(tInstance) {
            set tInstance = ..%New()
            set tIsNew = 1
            set tInstance.Name = tName
        }

        if $data(pModifiers("disable")) {
            set tInstance.Enabled = 0
        } elseif (tIsNew || $data(pModifiers("enable"))) {
            set tInstance.Enabled = 1
        }

        if $data(pModifiers("snapshots"),tSnapshots) {
            set tInstance.Snapshots = tSnapshots
        } elseif (tIsNew) {
            set tInstance.Snapshots = 1
        }
        if $data(pModifiers("prereleases"),tPrereleases) {
            set tInstance.Prereleases = tPrereleases
        } elseif (tIsNew) {
            set tInstance.Prereleases = 1
        }
        if $data(pModifiers("read-only"),tReadOnly) {
            set tInstance.ReadOnly = tReadOnly
        } elseif (tIsNew) {
            set tInstance.ReadOnly = 0
        }

        if $data(pModifiers("password-stdin")) {
            // prompt for password using secret input terminal mode
            open $io:(:"S")
            read "Password: ", pwd
            close $io
            set pModifiers("password") = pwd
        }

        $$$ThrowOnError(..OnConfigure(tInstance,pInteractive,.pModifiers,.pData))

        $$$ThrowOnError(tInstance.%Save())
        do tInstance.Display()
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Subclasses must override. Allows handling of any custom modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(
	pInstance As %IPM.Repo.Definition,
	pInteractive As %Boolean = 1,
	ByRef pModifiers,
	ByRef pData) As %Status [ Abstract ]
{
}

/// Subclasses must override. Orders repositories by type and possibly other factors.
Method GetSortOrder() As %Integer [ Abstract, Private ]
{
}

Query Catalog() As %Query(ROWSPEC = "Classname:%String,Moniker:%String,Description:%String") [ SqlProc ]
{
}

ClassMethod CatalogExecute(ByRef qHandle As %Binary) As %Status
{
    set tSC = $$$OK
    try {
        set tRes = ##class(%SQL.Statement).%New()
        set tSC = tRes.%PrepareClassQuery("%Dictionary.ClassDefinition","SubclassOf")
        $$$ThrowOnError(tSC)
        set qHandle = tRes.%Execute($classname())
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod CatalogFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = CatalogExecute ]
{
    set AtEnd = 'qHandle.%Next(.tSC)
    if 'AtEnd {
        set tClass = qHandle.%Get("Name")
        set Row = $listbuild(tClass,$parameter(tClass,"MONIKER"),$parameter(tClass,"DISPLAYNAME"))
    }
    quit tSC
}

ClassMethod CatalogClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = CatalogExecute ]
{
    quit $$$OK
}

Query List() As %SQLQuery
{
SELECT Name FROM %IPM_Repo.Definition
ORDER BY %IPM_Repo.Definition_SortOrder(ID) DESC
}

/// If a name is provided, return the repo of this type with the name
/// Otherwise, return the only repo of this type in the system
/// If there are multiple repos (or no repos) of this type, return an error
ClassMethod GetOne(
	name As %String = "",
	Output sc As %Status) As %IPM.Repo.Definition
{
    if $get(name) '= "" {
        quit ..ServerDefinitionKeyOpen(name, , .sc)
    }
    set tablename = $$$comClassKeyGet($classname(), $$$cCLASSsqlqualifiednameQ)
    set query = "SELECT id FROM " _ tablename  // should be safe from SQL injection, since $classname() is safe
    set rs = ##class(%SQL.Statement).%ExecDirect(, query)
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    set list = ""
    while rs.%Next() {
        set list = list _ $listbuild(rs.%Get("id"))
    }
    if $listlength(list) = 1 {
        quit ..%OpenId($listget(list, 1), , .sc)
    }
    set sc = $$$ERROR($$$GeneralError, "Unable to find a unique repo of type " _ $classname())
    quit ""
}

Storage Default
{
<Data name="RepoDefinitionDefaultData">
<Subscript>"RepoDefinition"</Subscript>
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="5">
<Value>Credentials</Value>
</Value>
<Value name="7">
<Value>Enabled</Value>
</Value>
<Value name="8">
<Value>IsLocalCache</Value>
</Value>
<Value name="9">
<Value>Details</Value>
</Value>
<Value name="10">
<Value>Snapshots</Value>
</Value>
<Value name="11">
<Value>Prereleases</Value>
</Value>
<Value name="12">
<Value>ReadOnly</Value>
</Value>
<Value name="13">
<Value>OverriddenSortOrder</Value>
</Value>
</Data>
<DataLocation>^IPM.Repo.DefinitionD</DataLocation>
<DefaultData>RepoDefinitionDefaultData</DefaultData>
<IdLocation>^IPM.Repo.DefinitionD</IdLocation>
<IndexLocation>^IPM.Repo.DefinitionI</IndexLocation>
<StreamLocation>^IPM.Repo.DefinitionS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
