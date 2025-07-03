/// Some processors may need to do something custom when a custom phase is executed.
/// Such as the CPF processor, which optionally merges a CPF file during a custom phase.
/// This  mixin provides the CustomPhase property and the OnCustomPhase method.
Class %IPM.ResourceProcessor.CustomPhaseMixin
{

Property CustomPhase As %IPM.DataType.CustomPhaseName;

Method OnCustomPhase(
	pCustomPhase As %String,
	ByRef pParams) As %Status
{
    quit $$$OK
}

}
