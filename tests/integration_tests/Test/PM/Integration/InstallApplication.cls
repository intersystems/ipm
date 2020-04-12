Class Test.PM.Integration.InstallApplication Extends Test.PM.Integration.Base
{

Method TestSimpleApp()
{
  Set tSC = $$$OK
  Try {
    Set tTestRoot = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot))
    
    $$$ThrowOnError(##class(%ZPM.PackageManager.Client.Utils).InitializeLocalCache(.tCreated))
    If (tCreated) {
      Do $$$LogMessage("Initialized local cache.")
    } Else {
      Do $$$LogMessage("Local cache already exists.")
    }
    
    Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).LoadModuleFromDirectory(##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-app/"))
    Do $$$AssertStatusOK(tSC,"Loaded SimpleApp module successfully.")
    Set tSC = ##class(%ZPM.PackageManager.Developer.Module).ExecutePhases("SimpleApp",$ListBuild("Register"),1)
    Do $$$AssertStatusOK(tSC,"Registered SimpleApp module in local namespace cache.")
    
    Set tQualRef = ##class(%ZPM.PackageManager.Core.QualifiedModuleReference).%New()
    Set tQualRef.Name = "SimpleApp"
    Set tQualRef.ServerName = "(Local Cache)"
    Set tQualRef.VersionString = "0.0.1+snapshot"
    
    Set tInstallInfo = ##class(%ZPM.PackageManager.Core.InstallationInfo).%New()
    Set tInstallInfo.Namespace = "INTTEST"
    Set tInstallInfo.ModuleReference = tQualRef //tResults.GetAt(1)
    Set tSC = ##class(%ZPM.PackageManager.Client.Utils).UninstallApplication(tInstallInfo)
    If $$$ISERR(tSC) {
      Do $$$LogMessage("Encountered an error trying to clean up INTTEST namespace (which may not actually be an issue): "_$System.Status.GetErrorText(tSC))
    } Else {
      Do $$$LogMessage("Successfully cleaned up existing namespace with application installed.")
    }
    
    // Finally: Given a qualified module reference, install it.
    Set tSC = ##class(%ZPM.PackageManager.Client.Utils).InstallApplication(tInstallInfo)
    Quit:'$$$AssertStatusOK(tSC,"Successfully installed SimpleApp application.")
  } Catch e {
    Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

}
