Include (%IPM.Common, %IPM.Formatting)

/// Persistent class for history of all installations, uninstalls, and loads in the system. This class is scoped by namespace.
Class %IPM.General.History Extends %IPM.General.AbstractHistory
{

Index ActionIndex On Action;

Index PackageIndex On Package;

Index VersionIndex On Version;

Property Finalized As %Boolean [ InitialExpression = 0 ];

Trigger PreventSQLUpdates [ Event = UPDATE, Foreach = row/object ]
{
    // Prevent updates to finalized history records
    if {Finalized*O} = 1 {
        set %msg = "Cannot edit finalized history log records"
        set %ok = 0
    }
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

ClassMethod DeleteHistoryGlobally(
	ByRef filter,
	verbose As %Boolean = 0) As %Integer
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
        if ##class(%Dictionary.ClassDefinition).%Exists($listbuild("%IPM.General.History")) {
            set subcount = ..DeleteHistory(.filter)
            set count = count + subcount
            if verbose {
                write !, "Deleted " _ subcount _ " record(s) from " _ ns, !
            }
        }
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

ClassMethod DisplayOneRecord(
	id As %Integer,
	showPhases As %Boolean = 0)
{
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 * FROM %IPM_General.History WHERE ID = ?", id)
    if rs.%Next() {
        do ..ShowColumns(rs, 1, showPhases)
    } else {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "No record found with ID "_id_". Use `history find` command to show all entries. "))
    }
}

/// If detail is 1, will display full details each property on a separate line
/// If detail is "header", will display the column names using the same style as the data
/// Otherwise, will display on a single line, with some details omitted
ClassMethod ShowColumns(
	rs As %SQL.StatementResult,
	detail As %Boolean = 0,
	showPhases As %Boolean = 0) As %Status [ Internal, Private ]
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

    if showPhases {
        do ..ShowPhases(rs)
    }
    return $$$OK
}

ClassMethod ShowPhases(rs As %SQL.StatementResult) As %Status [ Internal, Private ]
{
    write !,$$$FormattedLine($$$Dim, "Phases"), ": ", !
    set phases = rs.%Get("Phases")
    if $listlength(phases) > 0 {
        // Display a header row first
        set phaseColumnStyles = $listbuild(
            $listbuild("Name", $$$Red),
            $listbuild("Time", $$$Yellow),
            $listbuild("Success", $$$Default)
        )
        set ptr = 0
        while $listnext(phaseColumnStyles, ptr, pair) {
            set $listbuild(column, style) = pair
            write $$$FormattedLine(style, column), " "
        }
        write !!

        set ptr = 0
        while $listnext(phases, ptr, phase) {
            // display phase name
            set name = $listget($listget(phase,1),1)
            write $$$FormattedLine($$$Red, name), " "

            // display phase timing
            set start = $listget($listget(phase,1),2)
            set end = $listget($listget(phase,1),3)
            if end = "" {
                write $$$FormattedLine($$$Yellow, start), " "
            } else {
                set diff = $system.SQL.Functions.DATEDIFF("ss", start, end)
                write $$$FormattedLine($$$Yellow, $$$FormatText("%1 (%2 sec)", start, diff)), " "
            }

            // display phase success
            set success = $listget($listget(phase,1),4)
            write $select($$$ISOK(success): "Success", 1:$system.Status.GetErrorText(success)), !
        }
    }
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
    set diff = $system.SQL.Functions.DATEDIFF("ss", start, end)

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
<Value name="14">
<Value>Phases</Value>
</Value>
<Value name="15">
<Value>Finalized</Value>
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
