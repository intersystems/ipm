Class %IPM.DataType.RepoLocation Extends %IPM.DataType.RegExString [ ClassType = datatype ]
{

Parameter MAXLEN = 2048;

// Scheme is optional: OCI/ORAS convention uses bare hostnames (e.g. ghcr.io, not https://ghcr.io).
// https:// is assumed when no scheme is present.
Parameter REGEX = "(https?:\/\/)?(?:[a-zA-Z0-9-]+\.)*[a-zA-Z0-9-]+(?::\d+)?(?:\/[^\s]*)?\/?";

/// Decomposes url with %Net.URLParser, defaulting the scheme to https and leaving no leading slash on the path.
/// e.g. "ghcr.io/myorg" gives scheme "https", host "ghcr.io" and path "myorg"
ClassMethod Parse(
	url As %String,
	Output components)
{
    // %Net.URLParser reads a bare hostname as a path
    if (url '[ "://") {
        set url = "https://" _ url
    }
    do ##class(%Net.URLParser).Decompose(url, .components)
    set components("path") = $zstrip($get(components("path")), "<", "/")
}

/// Returns url with the scheme and host lowercased, https assumed when the scheme is omitted,
/// the scheme's default port dropped, and slashes trimmed from the path.
/// e.g. "GHCR.io:443/" gives "https://ghcr.io"
ClassMethod Canonicalize(url As %String) As %String
{
    do ..Parse(url, .components)
    set scheme = $zconvert(components("scheme"), "L")
    set normalized = scheme _ "://" _ $zconvert($get(components("host")), "L")
    set port = $get(components("port"))
    if (port '= "") && (port '= $case(scheme, "http": 80, "https": 443, : "")) {
        set normalized = normalized _ ":" _ port
    }
    set path = $zstrip(components("path"), ">", "/")
    if (path '= "") {
        set normalized = normalized _ "/" _ path
    }
    return normalized
}

}
