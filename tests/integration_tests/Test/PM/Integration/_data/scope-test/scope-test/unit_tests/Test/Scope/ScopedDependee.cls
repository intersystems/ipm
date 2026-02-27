Class Test.Scope.ScopedDependee Extends Test.Scope.ScopedClass
{

ClassMethod Hello()
{
    set obj = ##class(Test.Scope.ScopedDependee).%New()
    do obj.TestHello()
}

Method TestHello()
{
    write "Hello from ScopedDependee!"
    do ##super()
}

}
