/// Non-deployed resource, so the module has both a deployed and a non-deployed
/// Studio project during packaging. Version() reports the module version, so tests
/// can tell which of the two published versions is actually installed.
Class PlatformFilterTest.Public
{

ClassMethod Version() As %String
{
    return "1.0.0"
}

}
