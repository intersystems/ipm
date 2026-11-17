Class Test.PM.Unit.QuiesceRetry Extends %UnitTest.TestCase
{

Method OnBeforeOneTest(testname As %String) As %Status
{
    kill ^||QuiesceRetryCalls
    return $$$OK
}

/// Fails with the given error on the first call and succeeds after that.
ClassMethod FailFirstCall(errorText As %String) As %Status
{
    if $increment(^||QuiesceRetryCalls) = 1 {
        return $$$ERROR($$$GeneralError, errorText)
    }
    return $$$OK
}

Method TestRetriesQuiesceFailure()
{
    set errorText = "Error merging CPF file 'a.cpf'. ERROR #453: Cannot quiesce the system for namespace reactivation"
    set sc = ##class(%IPM.Test.Utils).CallWithQuiesceRetry($classname(), "FailFirstCall", errorText)
    do $$$AssertStatusOK(sc)
    do $$$AssertEquals(^||QuiesceRetryCalls, 2)
}

Method TestDoesNotRetryOtherErrors()
{
    set sc = ##class(%IPM.Test.Utils).CallWithQuiesceRetry($classname(), "FailFirstCall", "Some other error")
    do $$$AssertStatusNotOK(sc)
    do $$$AssertEquals(^||QuiesceRetryCalls, 1)
}

}
