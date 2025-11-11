Include %IPM.Formatting

Class %IPM.General.TempLocalRepoManager Extends %RegisteredObject
{

Property Root As %String;

Property Repo As %IPM.Repo.Definition;

/// Creates the repository. If anything goes wrong, it will throw an error after cleaning up the repo.
/// Purposedly private and not a classmethod, so that we can only call it through %OnNew.
/// This encourages user to perform clean-up using the return instance from %OnNew.
Method Create(useFirst As %Boolean) [ Internal, Private ]
{
    set count = 0
    for {
        set repoName = "ipm-temp-modules-" _ $increment(count)
        if '##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(repoName) {
            quit
        }
    }
    set ..Repo = ##class(%IPM.Repo.Filesystem.Definition).%New()
    set ..Repo.Name = repoName
    set ..Repo.Root = ..Root
    set ..Repo.Snapshots = 1
    set ..Repo.Prereleases = 1
    // Make sure this is the first/last repo to be found by SQL query in %IPM.Repo.Manager:SearchRepositoriesForModule
    set ..Repo.OverriddenSortOrder = $select(useFirst:-1000 ,1:1000)

    $$$ThrowOnError(..Repo.BuildCache(1,1,1))
}

ClassMethod SkipCreate(location As %String) As %Boolean [ Internal ]
{
    if (location = "") || ('##class(%File).DirectoryExists(location)) {
        return 1
    }

    /// There is a unique index on the "Root" column, so skip creating the repo if it already exists (e.g., setup by another thread)
    set query = "SELECT COUNT(*) As Total FROM %IPM_Repo_Filesystem.Definition WHERE Root = ?"
    set rs = ##class(%SQL.Statement).%ExecDirect(, query, location)
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    if rs.%Next() && (rs.%Get("Total") > 0) {
        return 1
    }
    return 0
}

Method %OnNew(
	location As %String,
	useFirst As %Boolean = 0) As %Status
{
    /// If the location is empty or already covered by another repo, skip creating the repo
    /// This will still create an intance of this class, but the cleanup will be a no-op
    try {
        if ..SkipCreate($get(location)) {
            return $$$OK
        }
    } catch ex {
        return ex.AsStatus()
    }

    set ..Root = $get(location)
    try {
        do ..Create(useFirst)
    } catch ex {
        return $$$ADDSC(ex.AsStatus(), ..CleanUp())
    }

    return $$$OK
}

Method CleanUp() As %Status
{
    if ('$isobject(..Repo)) || (..Repo.%Id() = "") {
        quit $$$OK
    }

    set sc = ..Repo.%DeleteId(..Repo.%Id())
    if $$$ISERR(sc) {
        set msg = $$$FormatText("Failed to clean up repository '%1'. You may need to manually delete it using 'repo -delete -n %1'", ..Repo.Name)
        set msg = $$$FormattedLine($$$Red, msg)
        write !, msg
    }
    quit sc
}

}
