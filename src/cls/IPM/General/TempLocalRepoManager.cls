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
	Set count = 0
	For {
		Set repoName = "ipm-temp-modules-" _ $Increment(count)
		If '##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(repoName) {
			Quit
		}
	}
	Set ..Repo = ##class(%IPM.Repo.Filesystem.Definition).%New()
	Set ..Repo.Name = repoName
	Set ..Repo.Root = ..Root
	Set ..Repo.Snapshots = 1
	Set ..Repo.Prereleases = 1
	// Make sure this is the first/last repo to be found by SQL query in %IPM.Repo.Manager:SearchRepositoriesForModule
	Set ..Repo.OverriddenSortOrder = $SELECT(useFirst:-1000 ,1:1000)

	$$$ThrowOnError(..Repo.BuildCache(1,1,1))
}

ClassMethod SkipCreate(location As %String) As %Boolean [ Internal ]
{
	If (location = "") || ('##class(%File).DirectoryExists(location)) {
		Return 1
	}

	/// There is a unique index on the "Root" column, so skip creating the repo if it already exists (e.g., setup by another thread)
	Set query = "SELECT COUNT(*) As Total FROM %IPM_Repo_Filesystem.Definition WHERE Root = ?"
	Set rs = ##class(%SQL.Statement).%ExecDirect(, query, location)
	$$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
	If rs.%Next() && rs.%Get("Total") > 0 {
		Return 1
	}
	Return 0
}

Method %OnNew(location As %String, useFirst As %Boolean = 0) As %Status
{
	/// If the location is empty or already covered by another repo, skip creating the repo
	/// This will still create an intance of this class, but the cleanup will be a no-op
	Try {
		If ..SkipCreate($Get(location)) {
			Return $$$OK
		}
	} Catch ex {
		Return ex.AsStatus()
	}

	Set ..Root = $Get(location)
	Try {
		Do ..Create(useFirst)
	} Catch ex {
		Do ..CleanUp()
		Return ex.AsStatus()
	}

	Return $$$OK
}

Method CleanUp() As %Status
{
	If ('$IsObject(..Repo)) || (..Repo.%Id() = "") {
		Quit $$$OK
	}

	Set sc = ..Repo.%DeleteId(..Repo.%Id())
	If $$$ISERR(sc) {
		Set msg = $$$FormatText("Failed to clean up repository '%1'. You may need to manually delete it using 'repo -delete -n %1'", ..Repo.Name)
		Set msg = $$$FormattedLine($$$Red, msg)
		Write !, msg
	}
	Quit sc
}

}
