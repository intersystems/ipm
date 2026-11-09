Class TestModule.Test Extends %UnitTest.TestCase
{

Method TestDoWork()
{
    set result = ##class(TestModule.Main).DoWork()
    do $$$AssertEquals(result, "Production code")
}

}
