Include %IPM.Common

Class %IPM.General.LogManager Extends %IPM.General.Singleton
{

/// Has hashes of unique messages (with data equal to the index in ..Messages of that message)
Property UniqueMessageHashes [ MultiDimensional, Private ];

Property Messages As list Of %IPM.General.LogManager.Message;

Property Threshold As %Integer [ InitialExpression = {$$$ZPMLogWARNING} ];

Method Flush(pThreshold As %Integer = {..Threshold})
{
	Set tLastMessage = $$$NULLOREF
	For tMessageIndex=1:1:..Messages.Count() {
		Set tMessage = ..Messages.GetAt(tMessageIndex)
		If (tMessage.Severity >= pThreshold) {
			If $IsObject(tLastMessage) && (tMessage.GetHash() = tLastMessage.GetHash()) {
				// Don't repeat the same message, just track the count.
				Set tMessage.Count = tLastMessage.Count + tMessage.Count
			} ElseIf $IsObject(tLastMessage) && (tLastMessage.Severity >= pThreshold) {
				Do tLastMessage.Display()
			}
			Set tLastMessage = tMessage
		}
	}
	If $IsObject(tLastMessage) {
		Do tLastMessage.Display()
	}
	
	Do ..Messages.Clear()
	Kill ..UniqueMessageHashes
}

/// Flushes out the log of messages before doing the standard singleton cleanup.
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = ##super()
	Do ..Flush()
	Quit tSC
}

/// @API.Method
ClassMethod Trace(pMessage As %String, pUnique As %Boolean = 0)
{
	Do ..CreateMessage(pMessage, pUnique, $$$ZPMLogTRACE)
}

/// @API.Method
ClassMethod Info(pMessage As %String, pUnique As %Boolean = 0)
{
	Do ..CreateMessage(pMessage, pUnique, $$$ZPMLogINFO)
}

/// @API.Method
ClassMethod Warning(pMessage As %String, pUnique As %Boolean = 0)
{
	Do ..CreateMessage(pMessage, pUnique, $$$ZPMLogWARNING)
}

/// @API.Method
ClassMethod Error(pMessage As %String, pUnique As %Boolean = 0)
{
	Do ..CreateMessage(pMessage, pUnique, $$$ZPMLogERROR)
}

ClassMethod CreateMessage(pMessage As %String, pUnique As %Boolean = 0, pSeverity As %Integer) [ Private ]
{
	Set tMessage = ##class(%IPM.General.LogManager.Message).%New(pMessage,pSeverity)
	Set tInstance = ..%Get(.tSC)
	If $$$ISOK(tSC) {
		Do tInstance.AddMessage(tMessage,pUnique)
	} Else {
		Do tMessage.Display()
	}
}

Method AddMessage(pMessage As %IPM.General.LogManager.Message, pUnique As %Boolean = 0) [ Private ]
{
	Set tHash = pMessage.GetHash()
	If $Data(..UniqueMessageHashes(tHash),tIndex) {
		Set ..Messages.GetAt(tIndex).Count = ..Messages.GetAt(tIndex).Count + 1
	} Else {
		Do ..Messages.Insert(pMessage)
		If pUnique {
			Set ..UniqueMessageHashes(tHash) = ..Messages.Count()
		}
	}
}

}
