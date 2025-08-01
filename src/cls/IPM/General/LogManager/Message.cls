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

Method %OnNew(
	pMessage As %String,
	pSeverity As %Integer) As %Status [ Private, ServerOnly = 1 ]
{
    set ..Message = pMessage
    set ..Severity = pSeverity
    quit $$$OK
}

/// Outputs the message to the current device.
Method Display()
{
    write !,..SeverityLogicalToDisplay(..Severity),": ",..Message
    if (..Count > 1) {
        write " (repeated "_..Count_" times)"
    }
}

Method GetHash() As %String
{
    quit $zcrc(..Severity_..Message,7)
}

}
