Include %IPM.Common

Class %IPM.General.History Extends %Persistent
{

Property Action As %String(VALUELIST = ",load,install,uninstall") [ Required ];

Property Package As %IPM.DataType.ModuleName;

Property Version As %IPM.General.SemanticVersion [ Required ];

Property SourceName As %String(MAXLEN = 100);

Property SourceMoniker As %String(MAXLEN = 100);

Property SourceDetails As %String(MAXLEN = "");

Property TimeStart As %TimeStamp [ Required ];

Property TimeEnd As %TimeStamp;

Property NameSpace As %String [ InitialExpression = {$NAMESPACE}, Required ];

Property UserName As %String [ InitialExpression = {$USERNAME}, Required ];

Property Success As %Status [ InitialExpression = 0, Required ];

Property Committed As %Boolean [ InitialExpression = 0, Required ];

Property CommandString As %String(MAXLEN = 8192) [ Required ];

ClassMethod Init(Action As %String, Package As %IPM.DataType.ModuleName) As %IPM.General.History [ Private ]
{
    Set log = ..%New()
    Set log.TimeStart = $ZDateTime($Now(), 3)
    Set log.Action = Action
    Set log.Package = Package
    Set log.CommandString = $Get($$$ZPMCommandToLog)
    Set log.NameSpace = $Namespace
    Set log.UserName = $Username
    $$$ThrowOnError(log.SetVersion()) // Set the version to placeholder 0.0.0-0, Will be updated before finalizing
    $$$ThrowOnError(log.%Save()) // Save it now in case Finalize isn't called
    Quit log
}

ClassMethod InstallInit(Package As %IPM.DataType.ModuleName) As %IPM.General.History
{
    Quit ..Init("install", Package)
}

ClassMethod LoadInit() As %IPM.General.History
{
    // Package name is not known at this point, so use a placeholder
    Quit ..Init("load", "")
}

ClassMethod UninstallInit(Package As %IPM.DataType.ModuleName) As %IPM.General.History
{
    Quit ..Init("uninstall", Package)
}

Method SetSource(ServerName As %String) As %Status
{
    $$$ThrowOnError(..%Reload())
    Set server = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(ServerName)
    If '$IsObject(server) {
        Quit $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is not defined.", ServerName))
    }
    Set ..SourceName = ServerName
    Set ..SourceMoniker = server.#MONIKER
    Set ..SourceDetails = server.Details
    Quit ..%Save()
}

Method SetVersion(pVersion As %IPM.General.SemanticVersion) As %Status
{
    If ..%Id() '= "" {
        $$$ThrowOnError(..%Reload())
    }
    If $Get(pVersion) = "" {
        Set pVersion = "0.0.0-0"
    }
    Set ..Version = $Select($IsObject(pVersion): pVersion, 1: ##class(%IPM.General.SemanticVersion).FromString(pVersion))
    Quit ..%Save()
}

Method SetName(pName As %String) As %Status
{
    $$$ThrowOnError(..%Reload())
    Set ..Package = pName
    Quit ..%Save()
}

Method Finalize(status As %Status) As %Status
{
    $$$ThrowOnError(..%Reload())
    Set ..Success = status
    // TODO what does committed mean?
    Set ..Committed = 1
    Set ..TimeEnd = $ZDateTime($Now(), 3)
    If ..Package = "" {
        Return $$$ERROR($$$GeneralError, "Package name not set")
    }
    Return ..%Save()
}

/// @API.Method
/// Get the history of all installations, uninstalls, and loads in given namespace
/// The filter argument is a multidimensional array with structure 
/// filter(columnName) = value
ClassMethod GetHistory(ByRef filter, namespace As %String) As %SQL.StatementResult
{
    New $namespace
    If $Data(namespace) # 2 {
        Set $namespace = $ZStrip(namespace, "<>WC")
    }
    If $$$comClassDefined("IPM.General.History") {
        Quit $$$NULLOREF
    }
    Kill varargs
    Set query = "SELECT * FROM %IPM_General.History WHERE 1 = 1 "
    Set col = ""
    For {
        // TODO: consider the case where value starts with > or <. For now we assume it's an exact match
        Set col = $Order(filter(col), 1, value)
        If (col = "") || ($Data(value) # 2 = 0) || (col '? 1A.AN){
            Quit
        }
        // col is safe from SQL injection because we ensured it's alphanumeric above
        Set query = query _ " AND " _ col _ " = ?"
        Set varargs($Increment(varargs)) = value
    }
    Quit ##class(%SQL.Statement).%ExecDirect(, query, varargs...)
}

/// @API.Method
/// Get the history of all installations, uninstalls, and loads in all namespaces
/// See GetHistory() for the `filter` argument
ClassMethod GetHistoryGlobally(ByRef filter) As %Library.ArrayOfObjects
{
    New $namespace
    Set $namespace = "%SYS"
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT DISTINCT Nsp FROM %SYS.Namespace_List()")
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    Set array = ##class(%Library.ArrayOfObjects).%New()
    While rs.%Next() {
        Set ns = rs.%Get("Nsp")
        Do array.SetAt(..GetHistory(.filter, ns), ns)
    }
    Return array
}

ClassMethod DisplayQueryResult(rs As %SQL.StatementResult)
{
    // TODO improve the display output
    Do rs.%Display()
}

ClassMethod DisplayArray(array As %Library.ArrayOfObjects)
{
    Set ns = ""
    For {
        Set rs = array.GetNext(.ns)
        If rs = "" {
            Quit
        }
        Write !, "Namespace: ", ns, !
        Do ..DisplayQueryResult(rs)
    }
}

Storage Default
{
<Data name="HistoryDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Action</Value>
</Value>
<Value name="3">
<Value>Package</Value>
</Value>
<Value name="4">
<Value>Version</Value>
</Value>
<Value name="5">
<Value>SourceName</Value>
</Value>
<Value name="6">
<Value>SourceMoniker</Value>
</Value>
<Value name="7">
<Value>SourceDetails</Value>
</Value>
<Value name="8">
<Value>TimeStart</Value>
</Value>
<Value name="9">
<Value>TimeEnd</Value>
</Value>
<Value name="10">
<Value>NameSpace</Value>
</Value>
<Value name="11">
<Value>UserName</Value>
</Value>
<Value name="12">
<Value>Success</Value>
</Value>
<Value name="13">
<Value>Committed</Value>
</Value>
<Value name="14">
<Value>CommandString</Value>
</Value>
</Data>
<DataLocation>^%IPM.General.HistoryD</DataLocation>
<DefaultData>HistoryDefaultData</DefaultData>
<IdLocation>^%IPM.General.HistoryD</IdLocation>
<IndexLocation>^%IPM.General.HistoryI</IndexLocation>
<StreamLocation>^%IPM.General.HistoryS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
