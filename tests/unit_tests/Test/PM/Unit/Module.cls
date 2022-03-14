Class Test.PM.Unit.Module Extends %UnitTest.TestCase
{

Method TestEvaluateAttribute()
{
  Set tModule = ##class(%IPM.Storage.Module).%New()

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
    "${verbose}","{$verbose}"
  )
  For i=1:1:$ListLength(tests) {
    Set test = $ListGet(tests, i)
    Do $$$AssertNotTrue(tModule.%Evaluate(test)=test, test)
  }
}

}
