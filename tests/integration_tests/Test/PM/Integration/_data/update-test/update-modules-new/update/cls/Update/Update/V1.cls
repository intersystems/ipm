Class Update.Update.V1 Extends %IPM.General.VersionBase
{

ClassMethod GetOrderedMirrorMethodNames() As %Library.DynamicArray
{
    return ["MethodA", "MethodC"]
}

ClassMethod GetOrderedNonMirroredMethodNames() As %Library.DynamicArray
{
    return ["MethodB"]
}

ClassMethod MethodA() As %Status
{
    write !, "This is Update.Update.V1::MethodA()"
    return $$$OK
}

ClassMethod MethodB() As %Status
{
    write !, "This is Update.Update.V1::MethodB()"
    return $$$OK
}

ClassMethod MethodC() As %Status
{
    write !, "This is Update.Update.V1::MethodC()"
    return $$$OK
}

}
