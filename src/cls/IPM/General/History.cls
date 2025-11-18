Include (%IPM.Common, %IPM.Formatting)

/// Persistent class for history of all installations, uninstalls, and loads in the system. This class is scoped by namespace.
Class %IPM.General.History Extends %Persistent
{

/// Action of this history record. Can be load, install, uninstall or update
Property Action As %String(VALUELIST = ",load,install,uninstall,update") [ Required ];

Index ActionIndex On Action;

/// Name of the package being logged. This is not necessarily required, e.g. when loading a nonexistent directory.
Property Package As %IPM.DataType.ModuleName;

Index PackageIndex On Package;

/// Version of the package being logged. This is not necessarily required, e.g. when loading a nonexistent directory.
Property Version As %IPM.General.SemanticVersion [ Required ];

Index VersionIndex On Version;

/// Name of the repository where the package is being installed. For load and uninstall this will be empty.
Property SourceName As %IPM.DataType.RepoName(MAXLEN = 100);

/// Moniker of the repository where the package is being installed. For load and uninstall this will be empty.
Property SourceMoniker As %IPM.DataType.RepoMoniker(MAXLEN = 100);

/// Details of the repository where the package is being installed. For load and uninstall this will be empty.
Property SourceDetails As %String(MAXLEN = "");

/// Time when the action started
Property TimeStart As %TimeStamp [ Required ];

/// Time when the action ended. This will be empty if the action is still in progress or ended abnormally.
Property TimeEnd As %TimeStamp;

/// User who initiated the action
Property UserName As %Library.Username [ InitialExpression = {$username}, Required ];

/// Status of the action. If the action is still in progress, this will be 0. Otherwise, it will be the status code of the action.
Property Success As %Status [ InitialExpression = 0, Required ];

/// Whether the action has been commited "to disk" so to speak. A non-commited action has been rolled back.
/// In non developer mode, this indicates whether the action was successful. In developer mode, this is always true.
Property Committed As %Boolean [ InitialExpression = 0, Required ];

/// The command string that triggered the action
Property CommandString As %String(MAXLEN = "") [ Required ];

ClassMethod Init(
	Action As %String,
	Package As %IPM.DataType.ModuleName) As %IPM.General.History [ Private ]
{
    set log = ..%New()
    set log.TimeStart = $zdatetime($now(), 3)
    set log.Action = Action
    set log.Package = Package
    set log.CommandString = $get($$$ZPMCommandToLog, "<unset>")
    set log.UserName = $username
    $$$ThrowOnError(log.SetVersion()) // Set the version to placeholder 0.0.0-0; will be updated before finalizing
    $$$ThrowOnError(log.%Save()) // Save it now in case Finalize isn't called
    quit log
}

ClassMethod InstallInit(Package As %IPM.DataType.ModuleName) As %IPM.General.History
{
    quit ..Init("install", Package)
}

ClassMethod LoadInit(Package As %IPM.DataType.ModuleName = "") As %IPM.General.History
{
    // Package name may not known at this point, so use a placeholder
    quit ..Init("load", Package)
}

ClassMethod UninstallInit(Package As %IPM.DataType.ModuleName) As %IPM.General.History
{
    quit ..Init("uninstall", Package)
}

ClassMethod UpdateInit(Package As %IPM.DataType.ModuleName) As %IPM.General.History
{
    quit ..Init("update", Package)
}

Method SetSource(ServerName As %String) As %Status
{
    $$$ThrowOnError(..%Reload())
    set server = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(ServerName)
    if '$isobject(server) {
        quit $$$ERROR($$$GeneralError,$$$FormatText("Repository '%1' is not defined.", ServerName))
    }
    set ..SourceName = ServerName
    set ..SourceMoniker = server.#MONIKER
    set ..SourceDetails = server.Details
    quit ..%Save()
}

Method SetVersion(pVersion As %IPM.General.SemanticVersion) As %Status
{
    // If object is being initalized, this will fail, so set placeholder instead
    if ..%Id() '= "" {
        $$$ThrowOnError(..%Reload())
    }
    if $get(pVersion) = "" {
        set pVersion = "0.0.0-0"
    }
    set ..Version = $select($isobject(pVersion): pVersion, 1: ##class(%IPM.General.SemanticVersion).FromString(pVersion))
    quit ..%Save()
}

Method SetName(pName As %String) As %Status
{
    $$$ThrowOnError(..%Reload())
    set ..Package = pName
    quit ..%Save()
}

Method Finalize(
	status As %Status,
	dev As %Boolean = 0) As %Status
{
    $$$ThrowOnError(..%Reload())
    set ..Success = status
    set ..Committed = (dev = 1) || $$$ISOK(status)
    set ..TimeEnd = $zdatetime($now(), 3)
    return ..%Save()
}

/// @API.Query
/// Get history records in the current namespace
Query Records(
	ascend As %Boolean,
	limit As %Integer) As %Query(CONTAINID = 1, ROWSPEC = "Action:%String,Package:%String,Version_Major:%Integer,Version_Minor:%Integer,Version_Patch:%Integer,Version_Prerelease:%String,Version_Build:%String,SourceName:%String,SourceMoniker:%String,SourceDetails:%String,TimeStart:%String,TimeEnd:%String,UserName:%String,Success:%String,Committed:%String,CommandString:%String") [ SqlProc ]
{
}

ClassMethod RecordsExecute(
	ByRef qHandle As %Binary,
	ascend As %Boolean,
	limit As %Integer) As %Status [ Internal ]
{
    try {
        kill filter
        set qHandle = ..GetHistory(.filter, .ascend, .limit)
    } catch e {
        return e.AsStatus()
    }
    return $$$OK
}

ClassMethod RecordsFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ Internal, PlaceAfter = RecordsExecute ]
{
    try {
        if qHandle.%Next() {
            set Row = $listbuild(
                qHandle.%Get("Action"),
                qHandle.%Get("Package"),
                qHandle.%Get("Version_Major"),
                qHandle.%Get("Version_Minor"),
                qHandle.%Get("Version_Patch"),
                qHandle.%Get("Version_Prerelease"),
                qHandle.%Get("Version_Build"),
                qHandle.%Get("SourceName"),
                qHandle.%Get("SourceMoniker"),
                qHandle.%Get("SourceDetails"),
                qHandle.%Get("TimeStart"),
                qHandle.%Get("TimeEnd"),
                qHandle.%Get("UserName"),
                qHandle.%Get("Success"),
                qHandle.%Get("Committed"),
                qHandle.%Get("CommandString")
            )
            set AtEnd = 0
        } else {
            set Row = ""
            set AtEnd = 1
        }
    } catch ex {
        return ex.AsStatus()
    }
    return $$$OK
}

ClassMethod RecordsClose(ByRef qHandle As %Binary) As %Status [ Internal, PlaceAfter = RecordsFetch ]
{
    set qHandle = ""
    quit $$$OK
}

/// Get an SQL "where" clause based on the filter argument
/// See GetHistory() for the `filter` argument
/// Output "clause" is the SQL WHERE clause as a string, container zero or more ? placeholders
/// The "varargs" is an array of values to be substituted in the ? placeholders.
/// The "varargs" may already be populated with values, and new values will be appended to it.
ClassMethod ConstructSQLWhere(
	ByRef filter As %String,
	Output clause As %String,
	ByRef varargs As %String) As %Status [ Internal ]
{
    try {
        set clause = " WHERE 1 = 1 "
        set col = ""
        for {
            set col = $order(filter(col), 1, value)
            if (col = "") || ($data(value) # 2 = 0) || ('$match(col, "^[a-zA-Z][a-zA-Z0-9]*$")) {
                quit
            }
            // col is safe from SQL injection because we ensured it's alphanumeric above
            if $listfind($listbuild(">=", "<=", "<>"), $extract(value, 1, 2)) {
                set clause = clause _ " AND " _ col _ $extract(value, 1, 2) _ "?"
                set varargs($increment(varargs)) = $extract(value, 3, *)
            } elseif $listfind($listbuild(">", "<", "="), $extract(value, 1, 1)) {
                set clause = clause _ " AND " _ col _ $extract(value, 1) _ "?"
                set varargs($increment(varargs)) = $extract(value, 2, *)
            } elseif value [ "*" {
                set clause = clause _ " AND " _ col _ " LIKE ?"
                set varargs($increment(varargs)) = $replace(value, "*", "%")
            } else {
                set clause = clause _ " AND " _ col _ "=?"
                set varargs($increment(varargs)) = value
            }
        }
        set clause = clause _ " " // Ensure there's a space at the end
    } catch ex {
        return ex.AsStatus()
    }
    return $$$OK
}

/// Get the history of all installations, uninstalls, and loads in current namespace
/// The filter argument is a multidimensional array with structure
/// filter(columnName) = value
/// Where value can optionally start with >, >=, <, <=, =, <> or contain * to indicate a wildcard
ClassMethod GetHistory(
	ByRef filter,
	ascend As %Boolean = 0,
	limit As %Integer = 0)
{
    if limit > 0 {
        set query = "SELECT TOP ? * FROM %IPM_General.History "
        set varargs($increment(varargs)) = limit
    } else {
        set query = "SELECT * FROM %IPM_General.History "
    }
    $$$ThrowOnError(..ConstructSQLWhere(.filter, .where, .varargs))
    set query = query _ where
    set query = query _ " ORDER BY ID "  _ $select(ascend: "ASC", 1: "DESC")
    set rs = ##class(%SQL.Statement).%ExecDirect(, query, varargs...)
    return rs
}

/// Delete the history of installations, uninstalls, and loads in current namespace
ClassMethod DeleteHistory(ByRef filter) As %Integer
{
    set query = "DELETE FROM %IPM_General.History "
    $$$ThrowOnError(..ConstructSQLWhere(.filter, .where, .varargs))
    set query = query _ where
    set rs = ##class(%SQL.Statement).%ExecDirect(, query, varargs...)
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    quit rs.%ROWCOUNT
}

ClassMethod DeleteHistoryGlobally(ByRef filter) As %Integer
{
    set originalNS = $namespace
    new $namespace
    set $namespace = "%SYS"
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT DISTINCT Nsp FROM %SYS.Namespace_List()")
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    set count = 0
    while rs.%Next() {
        set ns = rs.%Get("Nsp")
        set $namespace = ns
        set count = count + ..DeleteHistory(.filter)
    }
    set $namespace = originalNS
    quit count
}

/// @API.Query
Query GlobalRecords(
	ascend As %Boolean,
	limit As %Integer) As %Query(ROWSPEC = "Action:%String,Package:%String,Version_Major:%Integer,Version_Minor:%Integer,Version_Patch:%Integer,Version_Prerelease:%String,Version_Build:%String,SourceName:%String,SourceMoniker:%String,SourceDetails:%String,TimeStart:%String,TimeEnd:%String,UserName:%String,Success:%String,Committed:%String,CommandString:%String") [ SqlProc ]
{
}

ClassMethod GlobalRecordsExecute(
	ByRef qHandle As %Binary,
	ascend As %Boolean,
	limit As %Integer) As %Status [ Internal ]
{
    try {
        kill filter
        set qHandle = ..GetHistoryGlobally(.filter, .ascend, .limit)
    } catch e {
        return e.AsStatus()
    }
    return $$$OK
}

ClassMethod GlobalRecordsFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ Internal, PlaceAfter = GlobalRecordsExecute ]
{
    try {
        while qHandle.Count() > 0 {
            // Always get the first namespace. Remove it from list once corresponding result set is exhausted.
            set ns = ""
            set rs = qHandle.GetNext(.ns)
            $$$ThrowOnError(..RecordsFetch(rs, .Row, .AtEnd))
            if AtEnd {
                // If rs is empty, there could still be more namespaces to process
                do qHandle.RemoveAt(ns, .success)
                if 'success {
                    $$$ThrowStatus($$$ERROR($$$GeneralError, "Failed to remove namespace "_ns_" from list"))
                }
            } else {
                return $$$OK
            }
        }
        // Only when the list is empty should we return AtEnd = 1 and Row = ""
        set Row = "", AtEnd = 1
        return $$$OK
    } catch ex {
        return ex.AsStatus()
    }
    return $$$OK
}

ClassMethod GlobalRecordsClose(ByRef qHandle As %Binary) As %Status [ Internal, PlaceAfter = GlobalRecordsFetch ]
{
    // Should not happen, but just in case
    if qHandle.Count() '= 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Namespace list not empty in GlobalRecordsFetch()!"))
    }
    set qHandle = ""
    quit $$$OK
}

/// Get the history of all installations, uninstalls, and loads in all namespaces
/// See GetHistory() for the `filter` argument
ClassMethod GetHistoryGlobally(
	ByRef filter,
	ascend As %Boolean = 0,
	limit As %Integer = 0) As %Library.ArrayOfObjects
{
    set originalNS = $namespace
    new $namespace
    set $namespace = "%SYS"
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT DISTINCT Nsp FROM %SYS.Namespace_List()")
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    set array = ##class(%Library.ArrayOfObjects).%New()
    while rs.%Next() {
        set ns = rs.%Get("Nsp")
        set $namespace = ns
        set historyRS = ..GetHistory(.filter, ascend, limit)
        if historyRS = $$$NULLOREF {
            continue
        }
        do array.SetAt(historyRS, ns)
    }
    set $namespace = originalNS
    return array
}

ClassMethod DisplayOneRecord(id As %Integer)
{
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 * FROM %IPM_General.History WHERE ID = ?", id)
    if rs.%Next() {
        do ..ShowColumns(rs, 1)
    } else {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "No record found with ID "_id_". Use `history find` command to show all entries. "))
    }
}

/// If detail is 1, will display full details each property on a separate line
/// If detail is "header", will display the column names using the same style as the data
/// Otherwise, will display on a single line, with some details omitted
ClassMethod ShowColumns(
	rs As %SQL.StatementResult,
	detail As %Boolean = 0) As %Status [ Internal, Private ]
{
    set columnStyles = $listbuild(
        $listbuild("ID", $$$Bright),
        $listbuild("Action", $$$Red),
        $listbuild("Package", $$$Green),
        $listbuild("Version", $$$Magenta),
        $listbuild("UserName", $$$Blue),
        $listbuild("Time", $$$Yellow),
        $listbuild("Success", $$$Default),
        $listbuild("Committed", $$$Cyan),
        $listbuild("CommandString", $$$Red),
        $listbuild("Source", $$$Default)
    )

    set ptr = 0
    write !
    while $listnext(columnStyles, ptr, pair) {
        set $listbuild(column, style) = pair
        if detail = "header" {
            write $$$FormattedLine(style, column), " "
            continue
        }
        set cls = $classname()
        set mthd = column_"ToString"
        if $system.CLS.IsMthd(cls, mthd) {
            set value = $classmethod(cls, mthd, rs, detail)
        } else {
            set value = rs.%Get(column)
        }
        set value = $replace(value, $char(13), $$$FormattedLine($$$Dim, "<CR>"))
        set value = $replace(value, $char(10), $$$FormattedLine($$$Dim, "<LF>"))
        set value = $replace(value, $char(9), $$$FormattedLine($$$Dim, "<TAB>"))
        set value = $$$FormattedLine(style, value)
        if detail {
            write $$$FormattedLine($$$Dim, column), ": ", value, !
        } else {
            write value, " "
        }
    }
    return $$$OK
}

ClassMethod VersionToString(
	rs As %SQL.StatementResult,
	detail As %Boolean = 0) As %String [ Internal, Private ]
{
    set obj = ##class(%IPM.General.History).%OpenId(rs.%Get("ID"))
    if $isobject(obj) {
        set str = obj.Version.ToString()
        if str '= "0.0.0-0" {
            quit "v"_str
        }
    }
    quit "<unset>"
}

ClassMethod TimeToString(
	rs As %SQL.StatementResult,
	detail As %Boolean = 0) As %String [ Internal, Private ]
{
    if detail {
        quit "Started At " _ rs.%Get("TimeStart") _ "; Ended At " _ rs.%Get("TimeEnd")
    }

    set start = rs.%Get("TimeStart")
    set end = rs.%Get("TimeEnd")
    if end = "" {
        quit rs.%Get("TimeStart")
    }
    set diff = $system.SQL.DATEDIFF("ss", start, end)

    quit $$$FormatText("%1 (%2 sec)", start, diff)
}

ClassMethod SourceToString(
	rs As %SQL.StatementResult,
	detail As %Boolean = 0) As %String [ Internal, Private ]
{
    if rs.%Get("Action") '= "install" {
        quit "n/a"
    }
    if rs.%Get("SourceName") = "" {
        quit "<no source set>"
    }
    if detail {
        quit rs.%Get("SourceName") _ " (" _ rs.%Get("SourceMoniker") _ "): " _ rs.%Get("SourceDetails")
    } else {
        quit rs.%Get("SourceName")
    }
}

ClassMethod SuccessToString(
	rs As %SQL.StatementResult,
	detail As %Boolean = 0) As %String [ Internal, Private ]
{
    set success = rs.%Get("Success")
    if detail {
        quit success
    }
    quit $select($$$ISOK(success): "Success", 1:$system.Status.GetErrorText(success))
}

ClassMethod CommittedToString(
	rs As %SQL.StatementResult,
	detail As %Boolean = 0) As %String [ Internal, Private ]
{
    quit $select(rs.%Get("Committed"): "Committed", 1: "Uncommitted")
}

ClassMethod DisplayQueryResult(
	rs As %SQL.StatementResult,
	namespace As %String)
{
    // TODO improve the display output
    if (rs = $$$NULLOREF) {
        write !, "IPM is not enabled for this namespace"
        quit
    }

    set found = 0
    while rs.%Next() {
        if 'found {
            set found = 1
            if $data(namespace) {
                write !, "Namespace: ", namespace
            }
            do ..ShowColumns(rs, "header")
            write !
        }
        do ..ShowColumns(rs, 0)
    }
    if found {
        write !
    }
}

ClassMethod DisplayArray(array As %Library.ArrayOfObjects)
{
    set originalNS = $namespace
    new $namespace
    set ns = ""
    for {
        set rs = array.GetNext(.ns)
        if rs = "" {
            quit
        }
        set $namespace = ns
        do ..DisplayQueryResult(rs, ns)
    }
    set $namespace = originalNS
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
<Value>UserName</Value>
</Value>
<Value name="11">
<Value>Success</Value>
</Value>
<Value name="12">
<Value>Committed</Value>
</Value>
<Value name="13">
<Value>CommandString</Value>
</Value>
</Data>
<DataLocation>^IPM.General.HistoryD</DataLocation>
<DefaultData>HistoryDefaultData</DefaultData>
<IdLocation>^IPM.General.HistoryD</IdLocation>
<IndexLocation>^IPM.General.HistoryI</IndexLocation>
<StreamLocation>^IPM.General.HistoryS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
