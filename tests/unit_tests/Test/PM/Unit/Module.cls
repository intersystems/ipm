Class Test.PM.Unit.Module Extends %UnitTest.TestCase
{

Method TestEvaluateAttribute()
{
  set tModule = ##class(%IPM.Storage.Module).%New()
  set tModule.Root = "/tmp/foo/bar"

  set tests = $listbuild(
    "${cspdir}","{$cspdir}",
    "${cspdir}","{$cspdir}",
    "${namespace}","{$namespace}",
    "${ns}","{$ns}",
    "${mgrdir}","{$mgrdir}",
    "${cspdir}","{$cspdir}",
    "${root}","{$root}",
    "${bindir}","{$bindir}",
    "${libdir}","{$libdir}",
    "${verbose}","{$verbose}",
    "${packagename}","{$packagename}",
    "${version}","{$version}"
  )
  for i=1:1:$listlength(tests) {
    set test = $listget(tests, i)
    do $$$AssertNotTrue(tModule.%Evaluate(test)=test, test)
  }
  do $$$AssertEquals(tModule.%Evaluate("#{..Root}"),tModule.Root)
}

Method TestEvaluateMacro()
{
  do $$$AssertEquals(##class(%IPM.Utils.Module).%EvaluateMacro("$$$ "), "$$$ ")
  do $$$AssertEquals(##class(%IPM.Utils.Module).%EvaluateMacro("Hello $$$OK $$$RandomJibberish123 World"), "Hello 1  World")
  do $$$AssertEquals(##class(%IPM.Utils.Module).%EvaluateMacro("Hello $$$OK$$$RandomJibberish123 World"), "Hello 1 World")
  do $$$AssertEquals(##class(%IPM.Utils.Module).%EvaluateMacro("$$$AutheUnauthenticated + $$$AutheCache + MAGIC"), $$$AutheUnauthenticated _ " + " _ $$$AutheCache _ " + MAGIC")
}

Method TestGetModuleDefaultsFromXML()
{
  do ##class(%IPM.Utils.Module).GetModuleDefaultsFromXML("/home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/module-defaults/", .defaults)
  do $$$AssertEquals(defaults("ArbitraryDefault"), 1234)
  do $$$AssertEquals(defaults("NoLock"), 1)
  do $$$AssertEquals(defaults("Verbose"), 1)

  set count = 0
  set key = $order(defaults(""))
  while (key'="") {
    set count = count + 1
    set key = $order(defaults(key))
  }
  do $$$AssertEquals(count, 3)
}

Method TestFixUndefinedCLIGenCommand()
{
	set tWebAppList = "/test/test"
	set tPath = ##class(%File).NormalizeDirectory("test-path")
    set tTemplate = ##class(%IPM.Storage.ModuleTemplate).NewTemplate(tPath, "testmodule", "1.0.0", "test module verification", "testmod")
    set sc = tTemplate.AddWebApps(tWebAppList, .tCSPapps)
    do $$$AssertStatusOK(sc, "AddWebApps method must now process web app list without error.")
}

}
