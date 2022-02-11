Class Test.PM.Integration.StandaloneFormBuilder Extends Test.PM.Integration.Base
{

Method TestNewNamespaceInstall()
{
	#; #dim tModule As %IPM.Storage.Module
	
	#; New $Namespace
	#; Set tOrigNS = $Namespace
	#; Try {
	#; 	If '$$$AssertStatusOK(..Setup()) {
	#; 		Quit
	#; 	}
		
	#; 	// Do everything in server/repository namespace.
	#; 	Set $Namespace = ..#SERVERNS
		
	#; 	// Configure Perforce-based repositories
	#; 	Set tAppCmd = "repo -p4 -n AppModules -path //healthshare/appmodules/"
	#; 	Set tUsrCmd = "repo -p4 -n Users -path //Users/tleavitt/PackageManager/modules/HS.StandaloneFormBuilder/"
	#; 	For tCmd = tAppCmd,tUsrCmd {
	#; 		Do $$$LogMessage(tCmd)
	#; 		Do ##class(%IPM.Main).ShellInternal(tCmd,.tException)
	#; 		If $IsObject(tException) {
	#; 			Throw tException
	#; 		}
	#; 	}
		
	#; 	Set tRef = ##class(%IPM.Storage.QualifiedModuleInfo).%New()
	#; 	Set tRef.ServerName = "Users"
	#; 	Set tRef.Name = "HS.StandaloneFormBuilder"
	#; 	Set tRef.VersionString = "0.0.1+snapshot"
	#; 	Set tParams("Verbose")=1
	#; 	Set tSC = ##class(%IPM.Utils.Module).LoadQualifiedReference(tRef,.tParams)
	#; 	Do $$$AssertStatusOK(tSC,"Loaded Standalone Form Builder module successfully.")
	#; } Catch e {
	#; 	Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	#; }
	
	#; // Cleanup
	#; Set $Namespace = tOrigNS
	#; Do $$$AssertStatusOK(..TearDown())
}

}
