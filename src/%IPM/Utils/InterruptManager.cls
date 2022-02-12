/// Handles setting of "break" to avoid Ctr-C breaking the instance when called during critical sections.
Class %IPM.Utils.InterruptManager Extends %RegisteredObject
{

/// Stores the value associated with the "break" command.
Property BreakValue As %Boolean [ InitialExpression = {$ZJob\4#2}, Private ];

/// Disables interrupts
Method DisableInterrupts()
{
	Break 0
}

/// This callback method is invoked by the <METHOD>%Close</METHOD> method to 
/// provide notification that the current object is being closed.
/// 
/// <P>The return value of this method is ignored.
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
	Break ..BreakValue
}

}
