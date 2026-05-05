Class Test.PM.Unit.Oras Extends %UnitTest.TestCase
{

/// Bare hostname (no scheme) should produce a Location with https:// scheme
/// and no path leaking into Location or PathPrefix.
Method TestGetPackageServiceUrlNormalizationBareHostname()
{
    set def = ##class(%IPM.Repo.Oras.Definition).%New()
    set def.URL = "ghcr.io"
    set svc = def.GetPackageService()
    do $$$AssertEquals(svc.Location, "https://ghcr.io", "Bare hostname gets https:// prepended")
    do $$$AssertEquals(svc.PathPrefix, "", "No path prefix for bare hostname")
}

/// Explicit https:// scheme should produce the same result as a bare hostname.
Method TestGetPackageServiceUrlNormalizationWithScheme()
{
    set def = ##class(%IPM.Repo.Oras.Definition).%New()
    set def.URL = "https://ghcr.io"
    set svc = def.GetPackageService()
    do $$$AssertEquals(svc.Location, "https://ghcr.io", "Explicit https:// scheme preserved")
    do $$$AssertEquals(svc.PathPrefix, "", "No path prefix when URL has no path")
}

/// URL with a path component should set PathPrefix and strip the path from Location.
Method TestGetPackageServiceWithPathPrefix()
{
    set def = ##class(%IPM.Repo.Oras.Definition).%New()
    set def.URL = "ghcr.io/myorg"
    set svc = def.GetPackageService()
    do $$$AssertEquals(svc.Location, "https://ghcr.io", "Path stripped from Location")
    do $$$AssertEquals(svc.PathPrefix, "myorg/", "Path component becomes PathPrefix")
}

/// Bare hostname with port should preserve port in Location.
Method TestGetPackageServiceUrlNormalizationWithPort()
{
    set def = ##class(%IPM.Repo.Oras.Definition).%New()
    set def.URL = "registry.example.com:5000"
    set svc = def.GetPackageService()
    do $$$AssertEquals(svc.Location, "https://registry.example.com:5000", "Port preserved in Location")
    do $$$AssertEquals(svc.PathPrefix, "", "No path prefix when no path in URL")
}

}
