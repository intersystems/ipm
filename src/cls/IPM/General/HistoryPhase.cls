/// History of a single lifecycle phase in the course of a module action
/// Embedded in the relevant %IPM.General.History object
Class %IPM.General.HistoryPhase Extends %SerialObject
{

/// Name of the phase
/// Standard phases are in %IPM.DataType.PhaseName but this also supports Custom Phases
Property Name As %String [ Required ];

/// Time when the phase started
Property TimeStart As %TimeStamp [ InitialExpression = {$zdatetime($now(), 3)}, Required ];

/// Time when the phase ended. This will be empty if the phase is still in progress or ended abnormally.
Property TimeEnd As %TimeStamp;

/// Status of the phase. If the phase is still in progress, this will be 0. Otherwise, it will be the status code of the phase.
Property Success As %Status [ InitialExpression = 0, Required ];

Storage Default
{
<Data name="HistoryPhaseState">
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>TimeStart</Value>
</Value>
<Value name="3">
<Value>TimeEnd</Value>
</Value>
<Value name="4">
<Value>Success</Value>
</Value>
</Data>
<State>HistoryPhaseState</State>
<StreamLocation>^%IPM.General.HistoryPhaseS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
