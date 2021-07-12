/// Useful metadata of Artifact saved for further lookup.
Class %ZPM.PackageManager.Developer.AngularArtifact Extends %Persistent
{

Parameter DEFAULTGLOBAL As STRING = "^%ZPM.AngularArtifact";

/// Identifier for the resource, used to build unique identifier.
Property ResourceName As %String(MAXLEN = 128);

/// Indicates the most recent time it is published to their server.
/// Noted as "updated" in Artifactory API in W3C time format.
Property MostRecentUpdated As %String(MAXLEN = "");

/// Name of the UI artifact to be kitted, found as the name of the UI application repo, need to distinguish from ArtifactoryRepo.
Property SourceControlRepo As %String(MAXLEN = 128);

/// Semantic version expression of the artifact to obtain.
Property Version As %String(MAXLEN = 100);

/// Source branch where the artifact was built from, noted as commit.branch in Artifactory API.
Property BranchName As %String(MAXLEN = 128);

/// Unique identifier for a source control repo commit, noted as commit.hash in Artifactory API.
Property CommitHash As %String(MAXLEN = "");

Index UniqueIdentifierIdx On (ResourceName, SourceControlRepo, Version) [ Unique ];

Index BranchNameIdx On BranchName;

Storage Default
{
<Data name="AngularArtifactDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ResourceName</Value>
</Value>
<Value name="3">
<Value>MostRecentUpdated</Value>
</Value>
<Value name="4">
<Value>SourceControlRepo</Value>
</Value>
<Value name="5">
<Value>Version</Value>
</Value>
<Value name="6">
<Value>BranchName</Value>
</Value>
<Value name="7">
<Value>CommitHash</Value>
</Value>
</Data>
<DataLocation>^%ZPM.AngularArtifactD</DataLocation>
<DefaultData>AngularArtifactDefaultData</DefaultData>
<IdLocation>^%ZPM.AngularArtifactD</IdLocation>
<IndexLocation>^%ZPM.AngularArtifactI</IndexLocation>
<StreamLocation>^%ZPM.AngularArtifactS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
