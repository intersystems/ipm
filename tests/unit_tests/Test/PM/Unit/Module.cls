Class Test.PM.Unit.Module Extends %UnitTest.TestCase
{

Method TestEvaluateAttribute()
{
  Set tModule = ##class(%IPM.Storage.Module).%New()
  Set tModule.Root = "/tmp/foo/bar"

  Set tests = $ListBuild(
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
  For i=1:1:$ListLength(tests) {
    Set test = $ListGet(tests, i)
    Do $$$AssertNotTrue(tModule.%Evaluate(test)=test, test)
  }
  Do $$$AssertEquals(tModule.%Evaluate("#{..Root}"),tModule.Root)
}

}
