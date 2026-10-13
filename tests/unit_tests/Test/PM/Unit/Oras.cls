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

/// The namespace is lowercased and leading and trailing slashes are stripped.
Method TestNamespaceNormalization()
{
    set def = ##class(%IPM.Repo.Oras.Definition).%New()
    set def.Namespace = "/packages/ipm/"
    do $$$AssertEquals(def.Namespace, "packages/ipm", "Slashes stripped from both ends")
    do $$$AssertEquals(def.GetPackageService().Namespace, "packages/ipm", "Package service gets normalized namespace")
    set def.Namespace = "Packages/IPM"
    do $$$AssertEquals(def.Namespace, "packages/ipm", "Namespace lowercased")
    set def.Namespace = "/"
    do $$$AssertEquals(def.Namespace, "", "Lone slash is no namespace")
}

/// Module names are registry repository paths without the configured namespace.
Method TestModuleNameFromRepository()
{
    set svc = ##class(%IPM.Repo.Oras.PackageService).%New()
    do $$$AssertEquals(svc.ModuleNameFromRepository("packages/module-a"), "packages/module-a", "Path unchanged without namespace")

    set svc.Namespace = "packages/ipm"
    do $$$AssertEquals(svc.ModuleNameFromRepository("packages/ipm/module-a"), "module-a", "Namespace stripped")
    do $$$AssertEquals(svc.ModuleNameFromRepository("module-a"), "module-a", "Bare name unchanged")
    do $$$AssertEquals(svc.ModuleNameFromRepository("packages/ipmx/module-a"), "packages/ipmx/module-a", "Namespace matched only as a whole path segment")
}

}
