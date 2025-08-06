Class %IPM.Storage.UpdateStep.Base Extends %RegisteredObject
{

Property ClassName As %Dictionary.Classname [ Required ];

Property MethodName As %Dictionary.Identifier [ Required ];

Property HostName As %String(MAXLEN = 255) [ Required ];

Property InstanceName As %String(MAXLEN = 255) [ Required ];

Property TimeStampStart As %Library.DateTime;

Property TimeStampEnd As %Library.DateTime;

Property Status As %Status;

Method %OnNew(
	className As %String = "",
	methodName As %String = "",
	hostName As %String = "",
	instanceName As %String = "") As %Status
{
    set ..ClassName = className
    set ..MethodName = methodName
    if hostName = "" {
        set ..HostName = ##class(%SYS.System).GetNodeName()
    }
    if instanceName = "" {
        set ..InstanceName = ##class(%SYS.System).GetInstanceName()
    }
    set ..Status = $$$OK

    return $$$OK
}

}
