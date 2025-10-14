Class Test.PM.Integration.InstallApplication Extends Test.PM.Integration.Base
{

Method TestSimpleApp()
{
  set tSC = $$$OK
  try {
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))

    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/simple-app/")
    set tSC = ##class(%IPM.Main).Shell("load " _ tModuleDir)
    do $$$AssertStatusOK(tSC,"Loaded SimpleApp module successfully. " _ tModuleDir)

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
    quit:'$$$AssertStatusOK(tSC,"Successfully installed SimpleApp application.")
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

Method TestWSGIApp()
{
  set tSC = $$$OK
  try {
    set tVersion = $piece($zversion," ",9)
    if $piece(tVersion, ".", 1) < 2024 {
      do $$$AssertSkipped("WSGI applications are only supported in 2024+. Current version: "_tVersion)
      return
    }
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
    set tModuleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/wsgi-app/")
    set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir)
    do $$$AssertStatusOK(tSC,"Loaded WSGI Application successfully. " _ tModuleDir)
    do $$$AssertStatusOK(..HttpGet("my/flask/demo/"))
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

Method TestRestApp()
{
  set tSC = $$$OK
  try {
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))

    set tModuleDir1 = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/rest-app/")
    set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir1)
    do $$$AssertStatusOK(tSC,"Loaded REST Application ""restdemo/"" successfully. " _ tModuleDir1)
    do $$$AssertStatusOK(..HttpGet("restdemo/"))

    // Delete the 1st REST application
    set tSC = ##class(%IPM.Main).Shell("uninstall -verbose rest-demo")
    do $$$AssertStatusOK(tSC,"Deleted REST Application ""restdemo/"" successfully. " _ tModuleDir1)
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

Method TestRestAppNamespace()
{
  set tSC = $$$OK
  try {
    set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))

    set tModuleDir1 = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(tTestRoot)_"/_data/rest-app-ns/")
    set tSC = ##class(%IPM.Main).Shell("load -verbose " _ tModuleDir1)
    do $$$AssertStatusOK(tSC,"Loaded REST Application ""restdemons/"" successfully. " _ tModuleDir1)
    do $$$AssertStatusOK(..HttpGet("restdemons/"))

    // verify the web application was created in the correct namespace
    set expectedNS = $namespace
    new $namespace
    set $namespace = "%SYS"

    $$$ThrowOnError(##class(Security.Applications).Get("/restdemons", .properties))
    set actualNS = $get(properties("NameSpace"))
    do $$$AssertEquals(expectedNS, actualNS, "Web application was created in the wrong namespace. Expected: "_expectedNS_" Actual: "_actualNS)
    set $namespace = expectedNS

    // Delete the 1st REST application
    set tSC = ##class(%IPM.Main).Shell("uninstall -verbose rest-demo-ns")
    do $$$AssertStatusOK(tSC,"Deleted REST Application ""restdemons/"" successfully. " _ tModuleDir1)
  } catch e {
    do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
  }
}

}
