Class UpdateTest.V2 Extends %IPM.Utils.Update.VersionBase
{

ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray
{
    return ["Method1", "Method3"]
}

ClassMethod GetOrderedMethodsAnyMirrorMember() As %Library.DynamicArray
{
    return ["Method2", "Will"]
}

ClassMethod Method1() As %Status
{
    write !, "This is Method1()"
    return $$$OK
}

ClassMethod Method2() As %Status
{
    write !, "This is Method2()"
    return $$$OK
}

ClassMethod Method3() As %Status
{
    write !, "This is Method3()"
    return $$$OK
}

ClassMethod Will() As %Status
{
    write !, "THIS IS METHOD WILL()"
    return $$$OK
}

ClassMethod MethodNew() As %Status
{
    write !, "THIS IS METHOD METHODNEW()"
    return $$$OK
}

}
