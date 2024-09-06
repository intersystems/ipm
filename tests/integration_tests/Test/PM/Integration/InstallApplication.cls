Class Test.PM.Integration.InstallApplication Extends Test.PM.Integration.Base
{

Method TestSimpleApp()
{
  Set tSC = $$$OK
  Try {
    Set tTestRoot = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot))
    
    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-app/")
    Set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)
    Do $$$AssertStatusOK(tSC,"Loaded SimpleApp module successfully. " _ tModuleDir)
    
    #; Set tInstallInfo = ##class(%IPM.PackageManager.Core.InstallationInfo).%New()
    #; Set tInstallInfo.Namespace = "INTTEST"
    #; #; Set tInstallInfo.ModuleReference = tQualRef //tResults.GetAt(1)
    #; Set tSC = ##class(%IPM.Repo.Utils).UninstallApplication(tInstallInfo)
    #; If $$$ISERR(tSC) {
    #;   Do $$$LogMessage("Encountered an error trying to clean up INTTEST namespace (which may not actually be an issue): "_$System.Status.GetErrorText(tSC))
    #; } Else {
    #;   Do $$$LogMessage("Successfully cleaned up existing namespace with application installed.")
    #; }
    
    #; // Finally: Given a qualified module reference, install it.
    #; Set tSC = ##class(%IPM.Repo.Utils).InstallApplication(tInstallInfo)
    Quit:'$$$AssertStatusOK(tSC,"Successfully installed SimpleApp application.")
  } Catch e {
    Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

Method TestWSGIApp()
{
  Set tSC = $$$OK
  Try {
    Set tVersion = $Piece($ZVersion," ",9)
    If $Piece(tVersion, ".", 1) < 2024 {
      Do $$$AssertSkipped("WSGI applications are only supported in 2024+. Current version: "_tVersion)
      Return
    }
    Set tTestRoot = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot))
    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/wsgi-app/")
    Set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)
    Do $$$AssertStatusOK(tSC,"Loaded WSGI Application successfully. " _ tModuleDir)
  } Catch e {
    Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

Method TestRestApp()
{
  Set tSC = $$$OK
  Try {
    Set tTestRoot = ##class(%File).NormalizeDirectory($Get(^UnitTestRoot))
    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/rest-app/")
    Set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)
    Do $$$AssertStatusOK(tSC,"Loaded REST Application successfully. " _ tModuleDir)
  } Catch e {
    Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

}
