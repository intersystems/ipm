/// Temporary version of history log that lives in IRISTEMP to avoid being affected by TROLLBACK
/// Persisted fully by being converted to %IPM.General.History
Class %IPM.General.HistoryTemp Extends %IPM.General.AbstractHistory
{

Property PersistedTwin As %IPM.General.History;

/// Initalize both this temporary version and the persistent version
ClassMethod Init(
	Action As %String,
	Package As %IPM.DataType.ModuleName) As %IPM.General.HistoryTemp [ Private ]
{
    set log = ##super(Action, Package)
    set twin = ##class(%IPM.General.History).%New()
    set twin.TimeStart = log.TimeStart
    set twin.Action = log.Action
    set twin.Package = log.Package
    set twin.CommandString = log.CommandString
    set twin.UserName = log.UserName
    set twin.Version = log.Version
    $$$ThrowOnError(twin.%Save())

    set log.PersistedTwin = twin
    $$$ThrowOnError(log.%Save())
    quit log
}

/// Persist this more permanently by saving to the PersistedTwin
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
    if ..PersistedTwin '= "" {
        // copy all values to the Persisted Twin
        set ..PersistedTwin.TimeStart = ..TimeStart
        set ..PersistedTwin.TimeEnd = ..TimeEnd
        set ..PersistedTwin.Action = ..Action
        set ..PersistedTwin.Package = ..Package
        set ..PersistedTwin.CommandString = ..CommandString
        set ..PersistedTwin.UserName = ..UserName
        set ..PersistedTwin.Version = ..Version
        set ..PersistedTwin.SourceName = ..SourceName
        set ..PersistedTwin.SourceMoniker = ..SourceMoniker
        set ..PersistedTwin.SourceDetails = ..SourceDetails
        set ..PersistedTwin.Success = ..Success
        set ..PersistedTwin.Committed = ..Committed
        set ..PersistedTwin.Phases = ..Phases
    }
    quit ..%Save()
}

Storage Default
{
<Data name="HistoryTempDefaultData">
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
<Value>PersistedTwin</Value>
</Value>
</Data>
<DataLocation>^IRIS.Temp.HistoryTempD</DataLocation>
<DefaultData>HistoryTempDefaultData</DefaultData>
<IdLocation>^IRIS.Temp.HistoryTempD</IdLocation>
<IndexLocation>^IRIS.Temp.HistoryTempI</IndexLocation>
<StreamLocation>^IRIS.Temp.HistoryTempS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
