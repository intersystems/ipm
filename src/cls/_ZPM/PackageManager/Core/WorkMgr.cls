/// Effectively makes MAK4715 for pre-2017.2 platform versions. <br />
/// This makes the %workqueue variable available in callbacks.
Class %ZPM.PackageManager.Core.WorkMgr Extends %SYSTEM.WorkMgr
{

/// After work has been queued this will wait for a signal from a callback to exit back to the caller.
/// This is done by in the callback queued with <method>QueueCallback</method> setting the public
/// variable '%exit' to 1. This method returns <var>AtEnd</var> to show whether all the work is complete or
/// there are still items outstanding.
Method Wait(qspec As %String, ByRef AtEnd As %Boolean) As %Status
{
	New %workqueue
	Set %workqueue=$This
	Quit ##super(.qspec,.AtEnd)
}

/// After work has been queued this will wait for all the workers to complete. It will display any output the work
/// writes to the current device and it will also combine all the %Status codes that the units of work report and
/// return this combined %Status. If there are no workers then this will execute all the work in this main job
/// during this phase. When this returns all the work queued up to this point has been completed. Also this is the
/// phase that will run the <method>QueueCallback</method> callbacks as the workers jobs report that various
/// units are complete.
Method WaitForComplete(qspec As %String, errorlog As %String) As %Status
{
	New %workqueue
	Set %workqueue=$This
	Quit ##super(.qspec,.errorlog)
}

}
