Class %IPM.DataType.RepoLocation Extends %IPM.DataType.RegExString [ ClassType = datatype ]
{

Parameter MAXLEN = 2048;

// Scheme is optional: OCI/ORAS convention uses bare hostnames (e.g. ghcr.io, not https://ghcr.io).
// https:// is assumed when no scheme is present.
Parameter REGEX = "(https?:\/\/)?(?:[a-zA-Z0-9-]+\.)*[a-zA-Z0-9-]+(?::\d+)?(?:\/[^\s]*)?\/?";

}
