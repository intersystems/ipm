Class Update.Update.V2 Extends %IPM.Utils.Update.VersionBase
{

ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray
{
    return ["MethodA", "MethodC"]
}

ClassMethod GetOrderedMethodsAnyMirrorMember() As %Library.DynamicArray
{
    return ["MethodB"]
}

ClassMethod MethodA() As %Status
{
    write !, "This is Update.Update.V2::MethodA()"
    return $$$OK
}

ClassMethod MethodB() As %Status
{
    write !, "This is Update.Update.V2::MethodB()"
    return $$$OK
}

ClassMethod MethodC() As %Status
{
    write !, "This is Update.Update.V2::MethodC()"
    return $$$OK
}

}
