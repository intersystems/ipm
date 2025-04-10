Class CustomPhaseWithoutLifecycle.Manager
{

ClassMethod SayHello()
{
    Write !, "Hello from CustomPhaseWithoutLifecycle.Manager"
}

ClassMethod ReturnError() As %Status
{
    Quit $$$ERROR($$$GeneralError, "Error from CustomPhaseWithoutLifecycle.Manager")
}

}
