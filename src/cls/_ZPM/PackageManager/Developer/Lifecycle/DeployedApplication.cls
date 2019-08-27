/// Application lifecycle that deploys resources in all dependencies by default (unless Deploy="false" is expcitly stated in the dependency)
Class %ZPM.PackageManager.Developer.Lifecycle.DeployedApplication Extends %ZPM.PackageManager.Developer.Lifecycle.Application
{

Method OnBeforeCaptureResource(ByRef pResourceInfo, Output pDeploy As %Boolean) As %Status
{
	Set tSC = $$$OK
	Try {
		// Override: deploy unless explicitly told not to.
		Set pDeploy = $Case($Get(pResourceInfo("Deploy")),0:0,:1)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
