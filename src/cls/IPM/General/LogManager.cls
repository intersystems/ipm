Include %IPM.Common

Class %IPM.General.LogManager Extends %IPM.General.Singleton
{

/// Has hashes of unique messages (with data equal to the index in ..Messages of that message)
Property UniqueMessageHashes [ MultiDimensional, Private ];

Property Messages As list Of %IPM.General.LogManager.Message;

Property Threshold As %Integer [ InitialExpression = {$$$ZPMLogWARNING} ];

Method Flush(pThreshold As %Integer = {..Threshold})
{
    set tLastMessage = $$$NULLOREF
    for tMessageIndex=1:1:..Messages.Count() {
        set tMessage = ..Messages.GetAt(tMessageIndex)
        if (tMessage.Severity >= pThreshold) {
            if $isobject(tLastMessage) && (tMessage.GetHash() = tLastMessage.GetHash()) {
                // Don't repeat the same message, just track the count.
                set tMessage.Count = tLastMessage.Count + tMessage.Count
            } elseif $isobject(tLastMessage) && (tLastMessage.Severity >= pThreshold) {
                do tLastMessage.Display()
            }
            set tLastMessage = tMessage
        }
    }
    if $isobject(tLastMessage) {
        do tLastMessage.Display()
    }

    do ..Messages.Clear()
    kill ..UniqueMessageHashes
}

/// Flushes out the log of messages before doing the standard singleton cleanup.
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
    set tSC = ##super()
    do ..Flush()
    quit tSC
}

/// @API.Method
ClassMethod Trace(
	pMessage As %String,
	pUnique As %Boolean = 0)
{
    do ..CreateMessage(pMessage, pUnique, $$$ZPMLogTRACE)
}

/// @API.Method
ClassMethod Info(
	pMessage As %String,
	pUnique As %Boolean = 0)
{
    do ..CreateMessage(pMessage, pUnique, $$$ZPMLogINFO)
}

/// @API.Method
ClassMethod Warning(
	pMessage As %String,
	pUnique As %Boolean = 0)
{
    do ..CreateMessage(pMessage, pUnique, $$$ZPMLogWARNING)
}

/// @API.Method
ClassMethod Error(
	pMessage As %String,
	pUnique As %Boolean = 0)
{
    do ..CreateMessage(pMessage, pUnique, $$$ZPMLogERROR)
}

ClassMethod CreateMessage(
	pMessage As %String,
	pUnique As %Boolean = 0,
	pSeverity As %Integer) [ Private ]
{
    set tMessage = ##class(%IPM.General.LogManager.Message).%New(pMessage,pSeverity)
    set tInstance = ..%Get(.tSC)
    if $$$ISOK(tSC) {
        do tInstance.AddMessage(tMessage,pUnique)
    } else {
        do tMessage.Display()
    }
}

Method AddMessage(
	pMessage As %IPM.General.LogManager.Message,
	pUnique As %Boolean = 0) [ Private ]
{
    set tHash = pMessage.GetHash()
    if $data(..UniqueMessageHashes(tHash),tIndex) {
        set ..Messages.GetAt(tIndex).Count = ..Messages.GetAt(tIndex).Count + 1
    } else {
        do ..Messages.Insert(pMessage)
        if pUnique {
            set ..UniqueMessageHashes(tHash) = ..Messages.Count()
        }
    }
}

}
