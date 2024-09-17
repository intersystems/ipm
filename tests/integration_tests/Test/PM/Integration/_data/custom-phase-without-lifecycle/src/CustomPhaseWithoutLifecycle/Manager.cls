Class CustomPhaseWithoutLifecycle.Manager
{

ClassMethod SayHello() As %Status
{
    Write !, "Hello from CustomPhaseWithoutLifecycle.Manager"
    Quit $$$OK
}

ClassMethod ReturnError() As %Status
{
    Quit $$$ERROR($$$GeneralError, "Error from CustomPhaseWithoutLifecycle.Manager")
}

}
