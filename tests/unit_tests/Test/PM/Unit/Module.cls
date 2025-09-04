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
  do $$$AssertStatusOK(##class(%IPM.Utils.Module).GetModuleDefaultsFromXML("/home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/module-defaults/", .defaults))
  do $$$AssertEquals(defaults,3)
  do $$$AssertEquals(defaults("ArbitraryDefault"), 1234)
  do $$$AssertEquals(defaults("NoLock"), 1)
  do $$$AssertEquals(defaults("Verbose"), 1)
}

}
