Class %IPM.General.LogManager.Message Extends %RegisteredObject
{

/// Severity display name -> logical value also available via macros in %IPM.Common.inc: <br />
/// <example>
/// $$$ZPMLogTRACE
/// $$$ZPMLogINFO
/// $$$ZPMLogWARNING
/// $$$ZPMLogERROR
/// </example>
Property Severity As %Integer(DISPLAYLIST = ",TRACE,INFO,WARNING,ERROR", VALUELIST = ",0,1,2,3");

Property Message As %String(MAXLEN = "");

Property Count As %Integer [ InitialExpression = 1 ];

Method %OnNew(pMessage As %String, pSeverity As %Integer) As %Status [ Private, ServerOnly = 1 ]
{
	Set ..Message = pMessage
	Set ..Severity = pSeverity
	Quit $$$OK
}

/// Outputs the message to the current device.
Method Display()
{
	Write !,..SeverityLogicalToDisplay(..Severity),": ",..Message
	If (..Count > 1) {
		Write " (repeated "_..Count_" times)"
	}
}

Method GetHash() As %String
{
	Quit $ZCRC(..Severity_..Message,7)
}

}
