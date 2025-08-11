Class Update.Update.V2 Extends %IPM.General.VersionBase
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
    w !, "This is Update.Update.V2::MethodA()"
    return $$$OK
}

ClassMethod MethodB() As %Status
{
    w !, "This is Update.Update.V2::MethodB()"
    return $$$OK
}

ClassMethod MethodC() As %Status
{
    w !, "This is Update.Update.V2::MethodC()"
    return $$$OK
}

}
