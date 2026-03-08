Class Verify.Scope.VerifyScopedDependee Extends Test.Scope.VerifyScopedClass
{

ClassMethod VerifyHello()
{
    set obj = ##class(Verify.Scope.VerifyScopedDependee).%New()
    do obj.TestVerify()
}

Method TestVerify()
{
    write "Hello from VerifyScopedDependee!"
    do ##super()
}

}
