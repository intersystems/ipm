Class Update.Update.V1 Extends %IPM.Utils.Update.VersionBase
{

ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray
{
    return ["MethodA"]
}

ClassMethod GetOrderedMethodsAnyMirrorMember() As %Library.DynamicArray
{
    return []
}

ClassMethod MethodA() As %Status
{
    write !, "This is Update.Update.V1::MethodA()"
    return $$$OK
}

}
