Include %IPM.Common

Class Test.PM.Unit.Oras Extends %UnitTest.TestCase
{

// ===== Package service construction =====

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

// ===== HTTP failure classification =====

Method NewFailure(
	status As %Integer,
	reason As %String,
	message As %String,
	url As %String = "http://reg/v2/auth-test/demo/tags/list") As %IPM.Repo.Oras.HttpException
{
    set failure = ##class(%IPM.Repo.Oras.HttpException).%New()
    set failure.StatusCode = status
    set failure.Reason = reason
    set failure.RegistryMessage = message
    set failure.URL = url
    return failure
}

Method AssertClassified(
	failure As %IPM.Repo.Oras.HttpException,
	hasCredentials As %Boolean,
	probe As %String,
	line1 As %String,
	line2 As %String,
	rejected As %Boolean)
{
    do failure.Classify("myrepo", "https://registry.example.com", "demo", hasCredentials, probe)
    do $$$AssertEquals(failure.Text, line1 _ $char(13,10) _ line2)
    do $$$AssertEquals(failure.CredentialsRejected, rejected)
}

Method TestCredentialsRejected()
{
    set failure = ..NewFailure(401, "Unauthorized", "Bad Credentials.")
    set line1 = "Repo 'myrepo' (https://registry.example.com) rejected the credentials: 401 Unauthorized - Bad Credentials."
    do ..AssertClassified(failure, 1, $$$OrasCredentialsRejected, line1, "Update the credentials configured for repo 'myrepo'.", 1)
}

Method TestDeniedProbeAccepted()
{
    set failure = ..NewFailure(403, "Forbidden", "denied")
    set line1 = "Repo 'myrepo' (https://registry.example.com) denied access to 'demo': 403 Forbidden - denied."
    do ..AssertClassified(failure, 1, $$$OrasCredentialsAccepted, line1, "The credentials were accepted but lack permission for this module.", 0)
}

Method TestDeniedProbeUnknown()
{
    set failure = ..NewFailure(403, "Forbidden", "denied")
    set line1 = "Repo 'myrepo' (https://registry.example.com) denied access to 'demo': 403 Forbidden - denied."
    do ..AssertClassified(failure, 1, $$$OrasCredentialsUnknown, line1, "The credentials could not be checked.", 0)
}

Method TestRequiresAuthentication()
{
    set failure = ..NewFailure(401, "Unauthorized", "")
    set line1 = "Repo 'myrepo' (https://registry.example.com) requires authentication: 401 Unauthorized."
    do ..AssertClassified(failure, 0, "", line1, "Configure credentials for repo 'myrepo'.", 0)
}

Method TestNotFound()
{
    set failure = ..NewFailure(404, "Not Found", "x", "http://reg/v2/demo/blobs/uploads/?a=1")
    set line1 = "Repo 'myrepo' (https://registry.example.com) returned 404 Not Found for /v2/demo/blobs/uploads/."
    do ..AssertClassified(failure, 1, "", line1, "Check the repo URL and namespace.", 0)
}

Method TestServerError()
{
    set failure = ..NewFailure(500, "Internal Server Error", "boom")
    set line1 = "Repo 'myrepo' (https://registry.example.com) returned 500 Internal Server Error for /v2/auth-test/demo/tags/list - boom."
    set line2 = "The registry failed to handle the request. Try again later, or contact the registry's administrator if it persists."
    do ..AssertClassified(failure, 1, "", line1, line2, 0)
}

Method TestOtherClientError()
{
    set failure = ..NewFailure(400, "Bad Request", "")
    set line1 = "Repo 'myrepo' (https://registry.example.com) returned 400 Bad Request for /v2/auth-test/demo/tags/list."
    set line2 = "The registry rejected the request. Check the repo URL and namespace, and that the registry supports the OCI distribution API."
    do ..AssertClassified(failure, 1, "", line1, line2, 0)
}

/// The message names the repo URL with its path, from both the package and the publish service.
Method TestRegistryFailureShowsPath()
{
    set def = ##class(%IPM.Repo.Oras.Definition).%New()
    set def.Name = "myrepo"
    set def.URL = "registry.example.com/artifactory/api/oci/x"
    set expected = "Repo 'myrepo' (https://registry.example.com/artifactory/api/oci/x) returned 404 Not Found"
    set failure = def.GetPackageService().RegistryFailure(..NewFailure(404, "Not Found", ""), "demo")
    do $$$AssertTrue(failure.Text [ expected, "Package service: " _ failure.Text)
    set failure = def.GetPublishService().RegistryFailure(..NewFailure(404, "Not Found", ""), "demo")
    do $$$AssertTrue(failure.Text [ expected, "Publish service: " _ failure.Text)
}

Method TestFromPythonException()
{
    try {
        do ..RaiseRegistryHttpError()
        do $$$AssertFailure("RegistryHttpError was not raised")
    } catch e {
        set failure = ##class(%IPM.Repo.Oras.HttpException).FromException(e)
        if $$$AssertTrue($isobject(failure), "FromException returned an HttpException") {
            do $$$AssertEquals(failure.StatusCode, 403)
            do $$$AssertEquals(failure.Reason, "Forbidden")
            do $$$AssertEquals(failure.RegistryMessage, "denied")
        }
    }
    do $$$AssertEquals(##class(%IPM.Repo.Oras.HttpException).FromException(##class(%Exception.General).%New("x")), "")
}

/// Signed blob URLs carry credentials in the query
Method TestFromPythonExceptionDropsQuery()
{
    try {
        do ..RaiseRegistryHttpError("https://blobs.example.com/sha256/abc?X-Amz-Signature=secret")
        do $$$AssertFailure("RegistryHttpError was not raised")
    } catch e {
        do $$$AssertNotTrue(e.Data [ "secret", "Python exception omits the query")
        set failure = ##class(%IPM.Repo.Oras.HttpException).FromException(e)
        if $$$AssertTrue($isobject(failure), "FromException returned an HttpException") {
            do $$$AssertEquals(failure.URL, "https://blobs.example.com/sha256/abc")
        }
    }
}

ClassMethod RaiseRegistryHttpError(url As %String = "http://reg/v2/auth-test/demo/tags/list") [ Language = python ]
{
    import iris
    import requests

    response = requests.Response()
    response.status_code = 403
    response.reason = "Forbidden"
    response.url = url
    response._content = b'{"errors":[{"message":"denied"}]}'
    response.request = requests.Request("GET", url).prepare()
    raise iris.cls("%IPM.Repo.Oras.PackageService").OrasHelper().RegistryHttpError(response)
}

// ===== Registry message extraction =====

Method TestRegistryMessageOciShape()
{
    set helper = ##class(%IPM.Repo.Oras.PackageService).OrasHelper()
    do $$$AssertEquals(helper."registry_message"("{""errors"":[{""code"":""DENIED"",""message"":""denied""}]}"), "denied")
}

Method TestRegistryMessageTopLevelShape()
{
    set helper = ##class(%IPM.Repo.Oras.PackageService).OrasHelper()
    do $$$AssertEquals(helper."registry_message"("{""code"":""UNAUTHORIZED"",""message"":""bad creds"",""detail"":{}}"), "bad creds")
}

Method TestRegistryMessageNone()
{
    set helper = ##class(%IPM.Repo.Oras.PackageService).OrasHelper()
    do $$$AssertEquals(helper."registry_message"("{""other"":1}"), "")
    do $$$AssertEquals(helper."registry_message"("not json"), "")
}

Method TestRegistryMessageSanitized()
{
    set helper = ##class(%IPM.Repo.Oras.PackageService).OrasHelper()
    do $$$AssertEquals(helper."registry_message"("{""message"":""\u001b[2Jbad\r\n\tline ""}"), "[2Jbad line")
}

}
