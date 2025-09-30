Class Test.PM.Integration.Uninstall Extends Test.PM.Integration.Base
{

Method TestSimpleUninstallAll()
{
  // install a few modules
  set testRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))

  set moduleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/simple-app/")
  set status = ##class(%IPM.Main).Shell("load " _ moduleDir)
  do $$$AssertStatusOK(status,"Loaded SimpleApp module successfully. " _ moduleDir)

  set moduleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/simple-module/")
  set status = ##class(%IPM.Main).Shell("load " _ moduleDir)
  do $$$AssertStatusOK(status,"Loaded SimpleModule module successfully. " _ moduleDir)

  // call "uninstall -f -all"
  set status = ##class(%IPM.Main).Shell("uninstall -f -all")
  do $$$AssertStatusOK(status,"Uninstalled everything successfully.")

  // verify everything except IPM is uninstalled
  do ##class(%IPM.Main).GetListModules(,,.list)
  do $$$AssertTrue(list=1, "Only one module left")
  do $$$AssertTrue($list(list(1))="zpm", "IPM has not been uninstalled")
}

Method TestUninstallAllNoForce()
{
  set testRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
  set moduleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/uninstall/")
  set status = ##class(%IPM.Main).Shell("load " _ moduleDir)
  do $$$AssertStatusOK(status,"Loaded uninstall module successfully. " _ moduleDir)

  // call "uninstall -all"
  set status = ##class(%IPM.Main).Shell("uninstall -all")
  do $$$AssertStatusOK(status,"Uninstalled everything successfully.")

  // verify everything except IPM is uninstalled
  do ##class(%IPM.Main).GetListModules(,,.list)
  do $$$AssertTrue(list=1, "Only one module left")
  do $$$AssertTrue($list(list(1))="zpm", "IPM has not been uninstalled")
}

Method TestUninstallAllForce()
{
  set testRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
  set moduleDir = ##class(%File).NormalizeDirectory(##class(%File).GetDirectory(testRoot)_"/_data/uninstall/")
  set status = ##class(%IPM.Main).Shell("load " _ moduleDir)
  do $$$AssertStatusOK(status,"Loaded uninstall module successfully. " _ moduleDir)

  // force uninstall dependent module
  set status = ##class(%IPM.Main).Shell("uninstall uninstall-a -force")
  do $$$AssertStatusOK(status,"uninstall-a forcefully uninstalled successfully. " _ moduleDir)

  // call "uninstall -f -all"
  set status = ##class(%IPM.Main).Shell("uninstall -f -all")
  do $$$AssertStatusOK(status,"Uninstalled everything successfully.")

  // verify everything except IPM is uninstalled
  do ##class(%IPM.Main).GetListModules(,,.list)
  do $$$AssertTrue(list=1, "Only one module left")
  do $$$AssertTrue($list(list(1))="zpm", "IPM has not been uninstalled")
}

}
