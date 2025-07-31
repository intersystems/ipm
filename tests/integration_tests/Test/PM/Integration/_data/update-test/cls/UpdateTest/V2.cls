Class UpdateTest.V2 Extends %IPM.Utils.Update.VersionBase
{

ClassMethod GetOrderedMirroredMethodNames() As %Library.DynamicArray
{
    return ["Method1", "Method3"]
    //return ["Method1", "MethodNew", "Method3"]
}

ClassMethod GetOrderedNonMirroredMethodNames() As %Library.DynamicArray
{
    return ["Method2", "Will"]
}

ClassMethod Method1() As %Status
{
    w !, "This is Method1()"
    return $$$OK
}

ClassMethod Method2() As %Status
{
    w !, "This is Method2()"
    return $$$OK
}

ClassMethod Method3() As %Status
{
    w !, "This is Method3()"
    return $$$OK
}

ClassMethod Will() As %Status
{
    w !, "THIS IS METHOD WILL()"
    return $$$OK
}

ClassMethod MethodNew() As %Status
{
    w !, "THIS IS METHOD METHODNEW()"
    return $$$OK
}

}
