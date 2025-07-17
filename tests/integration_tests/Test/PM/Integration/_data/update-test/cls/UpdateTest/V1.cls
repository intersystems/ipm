Class UpdateTest.V1 Extends %IPM.Utils.Update.VersionBase
{

ClassMethod MethodA() As %Status
{
    w !, "This is MethodA()"
    return $$$OK
}

ClassMethod MethodB() As %Status
{
    w !, "This is MethodB()"
    return $$$OK
}

ClassMethod MethodC() As %Status
{
    w !, "This is MethodC()"
    return $$$OK
}

ClassMethod Jest()
{
    w !, "THIS IS METHOD JEST()"
}

ClassMethod GetMethodNameList() As %Library.DynamicArray
{
    return [["MethodA", 1], ["MethodB", 0], ["MethodC", 0]]
}

}
