Class UpdateTest.V1 Extends %IPM.Utils.Update.VersionBase
{

ClassMethod GetOrderedMirrorMethodNames() As %Library.DynamicArray
{
    return ["MethodA"]
}

ClassMethod GetOrderedNonMirroredMethodNames() As %Library.DynamicArray
{
    return []
}

ClassMethod MethodA() As %Status
{
    w !, "This is MethodA()"
    return $$$OK
}

}
