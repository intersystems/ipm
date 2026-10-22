Include %IPM.Common

/// A failed response from an ORAS registry, built from the helper's RegistryHttpError.
/// Classify sets the message a user sees.
Class %IPM.Repo.Oras.HttpException Extends %Exception.AbstractException
{

Property StatusCode As %Integer;

Property Reason As %String(MAXLEN = "");

Property URL As %String(MAXLEN = "");

/// The registry's own message from the response body, if any.
Property RegistryMessage As %String(MAXLEN = "");

/// Set by Classify.
Property Text As %String(MAXLEN = "");

/// Set by Classify when the registry rejected the configured credentials.
Property CredentialsRejected As %Boolean [ InitialExpression = 0 ];

/// Returns ex as an HttpException if it is one or is a RegistryHttpError raised by the oras helper, otherwise "".
ClassMethod FromException(ex As %Exception.AbstractException) As %IPM.Repo.Oras.HttpException
{
    if ex.%IsA($classname()) {
        return ex
    }
    set marker = "RegistryHttpError'>: "
    if 'ex.%IsA("%Exception.PythonException") || (ex.Data '[ marker) {
        return ""
    }
    try {
        set payload = {}.%FromJSON($piece(ex.Data, marker, 2, *))
    } catch {
        return ""
    }
    set failure = ..%New("RegistryHttpError", payload.status, , payload.url)
    set failure.StatusCode = payload.status
    set failure.Reason = payload.reason
    set failure.URL = payload.url
    set failure.RegistryMessage = payload.message
    return failure
}

/// Returns whether ex is a failed registry response.
ClassMethod IsRegistryFailure(ex As %Exception.AbstractException) As %Boolean
{
    return $isobject(..FromException(ex))
}

/// Sets Text and CredentialsRejected for this failure on repository in repo repoName at repoURL.
/// probe is the result of %IPM.Repo.Oras.PackageService:ProbeCredentials, used for a 401 or 403 when hasCredentials is set.
Method Classify(
	repoName As %String,
	repoURL As %String,
	repository As %String,
	hasCredentials As %Boolean,
	probe As %String)
{
    set repo = "Repo '" _ repoName _ "' (" _ repoURL _ ")"
    set status = ..StatusCode _ " " _ ..Reason
    set ..CredentialsRejected = 0
    if (..StatusCode = 401) || (..StatusCode = 403) {
        if 'hasCredentials {
            set first = repo _ " requires authentication: " _ status
            set second = "Configure credentials for repo '" _ repoName _ "'."
        } elseif probe = $$$OrasCredentialsRejected {
            set first = repo _ " rejected the credentials: " _ status
            set second = "Update the credentials configured for repo '" _ repoName _ "'."
            set ..CredentialsRejected = 1
        } else {
            set first = repo _ " denied access to '" _ repository _ "': " _ status
            if probe = $$$OrasCredentialsAccepted {
                set second = "The credentials were accepted but lack permission for this repository."
            } else {
                set second = "The credentials could not be checked."
            }
        }
        set first = first _ ..MessageSuffix()
    } elseif ..StatusCode = 404 {
        set first = repo _ " returned " _ status _ " for " _ ..Path()
        set second = "Check the repo URL and namespace."
    } else {
        set first = repo _ " returned " _ status _ " for " _ ..Path() _ ..MessageSuffix()
        if ..StatusCode >= 500 {
            set second = "The registry failed to handle the request. Try again later, or contact the registry's administrator if it persists."
        } else {
            set second = "The registry rejected the request. Check the repo URL and namespace, and that the registry supports the OCI distribution API."
        }
    }
    set ..Text = ..EndSentence(first) _ $char(13,10) _ second
}

Method MessageSuffix() As %String [ Private ]
{
    return $select(..RegistryMessage = "": "", 1: " - " _ ..RegistryMessage)
}

/// The URL's path, without query.
Method Path() As %String [ Private ]
{
    do ##class(%Net.URLParser).Decompose(..URL, .components)
    return $get(components("path"))
}

ClassMethod EndSentence(text As %String) As %String [ Private ]
{
    return text _ $select($extract(text, *) = ".": "", 1: ".")
}

Method OnAsStatus() As %Status [ Private ]
{
    set text = ..Text
    if text = "" {
        set text = ..EndSentence("Registry returned " _ ..StatusCode _ " " _ ..Reason _ " for " _ ..URL _ ..MessageSuffix())
    }
    return $$$ERROR($$$GeneralError, text)
}

}
