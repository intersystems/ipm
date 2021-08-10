/// Utility to make managing the per-process journal flag easier in more complex settings.
/// Usage pattern:
/// <ol>
/// <li>Create an instance of this class at the beginning of a method. This captures the initial state of the flag.</li>
/// <li>Call the Enable() and/or Disable() methods. (These are no-ops if the flag is disabled.)</li>
/// <li>When the object goes out of scope, the flag is returned to its original value.</li>
/// </ol>
/// Under the hood, this does some messy stuff with View/$View that it's best to abstract.
Class %ZPM.PackageManager.Core.JournalManager Extends %RegisteredObject [ Final, Hidden ]
{

Parameter FLAG = 1024;

Property InitialValue As %Boolean [ InitialExpression = {..Enabled()}, Private ];

/// Called when a new instance is created
Method %OnNew(pEnableJournaling As %Boolean = 1) As %Status [ CodeMode = expression, Private, ServerOnly = 1 ]
{
$Select(pEnableJournaling:..Enable(),1:..Disable())
}

Method %OnClose() As %Status [ CodeMode = expression, Private, ServerOnly = 1 ]
{
$Select(..InitialValue:..Enable(),1:..Disable())
}

Method Enabled() As %Boolean [ CodeMode = expression ]
{
'($ZBoolean($ZJob,..#FLAG,1) = ..#FLAG)
}

Method Enable() As %Status
{
	Set tSC = $$$OK
	Try {
		If '..Enabled() {
			// The following command is a staple in our ^build routines,
			// but is not adequately described in our online documentation.
			
			// Just to document what this magical View command does:
			// The first (offset 0) 4 bytes of the process partition (identified by -1 in view/$view)
			// contain a set of flags related to the process. (See partitio.h for process partition
			// struct, and jobstat.h for a full list of these flags and their meanings.)
			
			// Bit 10 can be set to 1, meaning "Journaling is disabled regardless of other conditions."
			// The default, 0, means "Journaling is enabled for this job if other conditions indicate journaling."
			// (from $zjob documentation)
			
			// These are visible in $ZJob, but that doesn't let you modify them - for that you need VIEW.
			// Set these wrong, and your system will freeze!
			// If that happens run the following to recover:
			//    iris force [instance]
			//    iris start [instance]
			View 0:-1:4:($View(0,-1,4)-..#FLAG)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method Disable() As %Status
{
	Set tSC = $$$OK
	Try {
		If ..Enabled() {
			View 0:-1:4:($View(0,-1,4)+..#FLAG)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
