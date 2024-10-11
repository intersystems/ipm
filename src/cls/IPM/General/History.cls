Include (%IPM.Common, %IPM.Formatting)

Class %IPM.General.History Extends %Persistent
{

Property Action As %String(VALUELIST = ",load,install,uninstall") [ Required ];

/// Package is not necessarily requried. E.g., when loading a nonexistent directory.
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
    Set log.CommandString = $Get($$$ZPMCommandToLog, "<unset>")
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

Method Finalize(status As %Status, dev As %Boolean = 0) As %Status
{
    $$$ThrowOnError(..%Reload())
    Set ..Success = status
    Set ..Committed = (dev = 1) || $$$ISOK(status)
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
/// Where value can optionally start with >, >=, <, <=, =, <> or contain * to indicate a wildcard
ClassMethod GetHistory(ByRef filter, ascend As %Boolean = 0, limit As %Integer = 0, namespace As %String) As %SQL.StatementResult
{
    New $namespace
    If $Data(namespace) # 2 {
        Set $namespace = $ZStrip(namespace, "<>WC")
    }
    If '$$$comClassDefined("%IPM.General.History") {
        Quit $$$NULLOREF
    }
    Kill varargs
    Set limit = +limit // Coerce to number to prevent SQL injection
    Set query = "SELECT " _ $SELECT(limit>0: "TOP " _limit, 1: "") _  " * FROM %IPM_General.History WHERE 1 = 1 "
    Set col = ""
    For {
        Set col = $Order(filter(col), 1, value)
        If (col = "") || ($Data(value) # 2 = 0) || (col '? 1A.AN){
            Quit
        }
        // col is safe from SQL injection because we ensured it's alphanumeric above
        If $ListFind($ListBuild(">=", "<=", "<>"), $Extract(value, 1, 2)) {
            Set query = query _ " AND " _ col _ $Extract(value, 1, 2) _ "?"
            Set varargs($Increment(varargs)) = $Extract(value, 3, *)
        } ElseIf $ListFind($ListBuild(">", "<", "="), $Extract(value, 1, 1)) {
            Set query = query _ " AND " _ col _ $Extract(value, 1) _ "?"
            Set varargs($Increment(varargs)) = $Extract(value, 2, *)
        } ElseIf value [ "*" {
            Set query = query _ " AND " _ col _ " LIKE ?"
            Set varargs($Increment(varargs)) = $Replace(value, "*", "%")
        } Else {
            Set query = query _ " AND " _ col _ " = ?"
            Set varargs($Increment(varargs)) = value
        }
    }
    Set query = query _ " ORDER BY ID "  _ $Select(ascend: "ASC", 1: "DESC")
    Quit ##class(%SQL.Statement).%ExecDirect(, query, varargs...)
}

/// @API.Method
/// Get the history of all installations, uninstalls, and loads in all namespaces
/// See GetHistory() for the `filter` argument
ClassMethod GetHistoryGlobally(ByRef filter, ascend As %Boolean = 0, limit As %Integer = 0) As %Library.ArrayOfObjects
{
    New $namespace
    Set $namespace = "%SYS"
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT DISTINCT Nsp FROM %SYS.Namespace_List()")
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    Set array = ##class(%Library.ArrayOfObjects).%New()
    While rs.%Next() {
        Set ns = rs.%Get("Nsp")
        Set historyRS = ..GetHistory(.filter, ascend, limit, ns)
        If historyRS = $$$NULLOREF {
            Continue
        }
        Do array.SetAt(historyRS, ns)
    }
    Return array
}

ClassMethod DisplayOneRecord(id As %Integer)
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 * FROM %IPM_General.History WHERE ID = ?", id)
    If rs.%Next() {
        Do ..ShowColumns(rs, 1)
    } Else {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "No record found with ID "_id_". Use `history find` command to show all entries. "))
    }
}

/// If detail is 1, will display full details each property on a separate line
/// If detail is "header", will display the column names using the same style as the data
/// Otherwise, will display on a single line, with some details omitted
ClassMethod ShowColumns(rs As %SQL.StatementResult, detail As %Boolean = 0) As %Status [ Internal, Private ]
{
    Set columnStyles = $ListBuild(
        $ListBuild("ID", $$$Bright),
        $ListBuild("Action", $$$Red),
        $ListBuild("Package", $$$Green),
        $ListBuild("Version", $$$Green),
        $ListBuild("UserName", $$$Blue),
        $ListBuild("Namespace", $$$Magenta),
        $ListBuild("Time", $$$Yellow),
        $ListBuild("Success", $$$Default),
        $ListBuild("Committed", $$$Cyan),
        $ListBuild("CommandString", $$$Red),
        $ListBuild("Source", $$$Default)
    )

    Set ptr = 0
    Write !
    While $ListNext(columnStyles, ptr, pair) {
        Set $ListBuild(column, style) = pair
        If detail = "header" {
            Write $$$FormattedLine(style, column), " "
            Continue
        }
        Set cls = $classname()
        Set mthd = column_"ToString"
        If $System.CLS.IsMthd(cls, mthd) {
            Set value = $classmethod(cls, mthd, rs, detail)
        } Else {
            Set value = rs.%Get(column)
        }
        Set value = $Replace(value, $Char(13), $$$FormattedLine($$$Dim, "<CR>"))
        Set value = $Replace(value, $Char(10), $$$FormattedLine($$$Dim, "<LF>"))
        Set value = $Replace(value, $Char(9), $$$FormattedLine($$$Dim, "<TAB>"))
        Set value = $$$FormattedLine(style, value)
        If detail {
            Write $$$FormattedLine($$$Dim, column), ": ", value, !
        } Else { 
            Write value, " " 
        }
    }
    Return $$$OK
}

ClassMethod VersionToString(rs As %SQL.StatementResult, detail As %Boolean = 0) As %String [ Internal, Private ]
{
    Set obj = ##class(%IPM.General.History).%OpenId(rs.%Get("ID"))
    If $IsObject(obj) {
        Set str = obj.Version.ToString()
        If str '= "0.0.0-0" {
            Quit "v"_str
        }
    }
    Quit "<unset>"
}

ClassMethod TimeToString(rs As %SQL.StatementResult, detail As %Boolean = 0) As %String [ Internal, Private ]
{
    If detail {
        Quit "Started At " _ rs.%Get("TimeStart") _ "; Ended At " _ rs.%Get("TimeEnd")
    } 

    Set start = rs.%Get("TimeStart")
    Set end = rs.%Get("TimeEnd")
    If end = "" {
        Quit rs.%Get("TimeStart")
    } 
    Set diff = $System.SQL.DATEDIFF("ss", start, end)

    Quit $$$FormatText("%1 (%2 sec)", start, diff)
}

ClassMethod SourceToString(rs As %SQL.StatementResult, detail As %Boolean = 0) As %String [ Internal, Private ]
{
    If rs.%Get("Action") '= "install" {
        Quit "n/a"
    }
    If rs.%Get("SourceName") = "" {
        Quit "<no source set>"
    }
    If detail {
        Quit rs.%Get("SourceName") _ " (" _ rs.%Get("SourceMoniker") _ "): " _ rs.%Get("SourceDetails")
    } Else {
        Quit rs.%Get("SourceName")
    }
}

ClassMethod SuccessToString(rs As %SQL.StatementResult, detail As %Boolean = 0) As %String [ Internal, Private ]
{
    Set success = rs.%Get("Success")
    If detail {
        Quit success
    }
    Quit $Select($$$ISOK(success): "Success", 1:$System.Status.GetErrorText(success))
}

ClassMethod CommittedToString(rs As %SQL.StatementResult, detail As %Boolean = 0) As %String [ Internal, Private ]
{
    Quit $Select(rs.%Get("Committed"): "Committed", 1: "Uncommitted")
}

ClassMethod DisplayQueryResult(rs As %SQL.StatementResult)
{
    // TODO improve the display output
    If (rs = $$$NULLOREF) {
        Write !, "IPM is not enabled for this namespace"
        Quit
    }

    set found = 0
    While rs.%Next() {
        If 'found {
            Set found = 1
            Do ..ShowColumns(rs, "header")
            Write !
        }
        Do ..ShowColumns(rs, 0)
    }
    Write !
}

ClassMethod DisplayArray(array As %Library.ArrayOfObjects)
{
    Set ns = ""
    For {
        Set rs = array.GetNext(.ns)
        If rs = "" {
            Quit
        }
        Write !, "Namespace: ", ns
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
