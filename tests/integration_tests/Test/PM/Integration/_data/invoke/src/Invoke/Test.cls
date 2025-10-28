Class Invoke.Test
{

ClassMethod NoStatus()
{
    write !, "Hello from Invoke.Test"
}

ClassMethod ReturnStatus() As %Status
{
    quit $$$OK
}

ClassMethod ReturnError() As %Status
{
    quit $$$ERROR($$$GeneralError, "Error from Invoke.Test")
}

ClassMethod ReturnNonStatus() As %Boolean
{
    quit 0
}

ClassMethod NonStatusReturn() As %Status
{
    quit "True"
}

ClassMethod StatusNotReturned() As %Status
{
    write !, "This method does not return status"
}

}
