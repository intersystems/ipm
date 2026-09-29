Class MainModule.App
{

ClassMethod UseDependency() As %String
{
    return "Using dependency version: " _ ##class(DepModule.Core).GetVersion()
}

}
