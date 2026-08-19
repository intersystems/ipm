Class MainRes.App
{

/// Proves the dependency's compiled code is in the same IRIS.DAT.
ClassMethod UseDependency() As %String
{
    return "main uses " _ ##class(DepRes.Core).GetVersion()
}

}
