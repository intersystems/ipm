Class TrustParent.Hello
{

ClassMethod Hello() As %String
{
    return ##class(TrustChild.Hello).Hello() _ " via parent"
}

}
