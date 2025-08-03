Class UpdateTest.V1 Extends %IPM.Utils.Update.VersionBase
{

ClassMethod GetOrderedMirroredMethodNames() As %Library.DynamicArray
{
    return ["MethodA", "MethodC"]
}

ClassMethod GetOrderedNonMirroredMethodNames() As %Library.DynamicArray
{
    return ["MethodB", "Jest"]
}

ClassMethod MethodA() As %Status
{
    write !, "This is MethodA()"
    return $$$OK
}

ClassMethod MethodB() As %Status
{
    write !, "This is MethodB()"
    return $$$OK
}

ClassMethod MethodC() As %Status
{
    write !, "This is MethodC()"
    return $$$OK
}

ClassMethod Jest() As %Status
{
    write !, "THIS IS METHOD JEST()"
    return $$$OK
}

}
