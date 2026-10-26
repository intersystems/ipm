Class Test.PM.Unit.ResourceProcessor.ArtifactoryTarball Extends %UnitTest.TestCase
{

Method TestParseAnonymousFilter()
{
    set filter = {"repo": "generic-local", "name": {"$match": "my-ui-1.2.*"}, "path": "my-ui/-", "type": "file", "@commit.branch": {"$eq": "main"}}
    set criteria = ##class(%IPM.ResourceProcessor.ArtifactoryTarball).ParseAnonymousFilter(filter.%ToJSON())
    do $$$AssertEquals(criteria.repo, "generic-local")
    do $$$AssertEquals(criteria.name.value, "my-ui-1.2.*")
    do $$$AssertEquals(criteria.name.isPattern, 1)
    do $$$AssertEquals(criteria.path.value, "my-ui/-")
    do $$$AssertEquals(criteria.path.isPattern, 0)
    do $$$AssertEquals(criteria.properties.%Get("commit.branch"), "main")
}

Method TestParseAnonymousFilterUnsupported()
{
    for filter = "{""$or"": [{""name"": ""a""}, {""name"": ""b""}]}",
                 "{""name"": {""$gt"": ""a""}}",
                 "{""name"": {""$eq"": ""a"", ""$ne"": ""b""}}",
                 "{""repo"": {""$match"": ""generic-*""}, ""name"": ""a""}",
                 "{""@commit.branch"": {""$match"": ""feature/*""}}",
                 "{""type"": ""folder"", ""name"": ""a""}",
                 "{""size"": 10, ""name"": ""a""}",
                 "{""repo"": ""generic-local""}",
                 "" {
        try {
            do ##class(%IPM.ResourceProcessor.ArtifactoryTarball).ParseAnonymousFilter(filter)
            do $$$AssertFailure("No error for filter: "_filter)
        } catch ex {
            do $$$AssertTrue(ex.DisplayString() [ "ERROR #5001", "Error for filter: "_filter)
        }
    }
}

Method TestWildcardMatch()
{
    set class = "%IPM.ResourceProcessor.ArtifactoryTarball"
    do $$$AssertTrue($classmethod(class, "WildcardMatch", "my-ui-1.2.3-456.tgz", "my-ui-1.2.3-*.tgz"))
    do $$$AssertTrue($classmethod(class, "WildcardMatch", "my-ui-1.2.3.tgz", "my-ui-1.2.?.tgz"))
    do $$$AssertNotTrue($classmethod(class, "WildcardMatch", "my-ui-1.2.3.tgz", "my-ui-1.2.?"))
    do $$$AssertNotTrue($classmethod(class, "WildcardMatch", "my-ui-1x2x3.tgz", "my-ui-1.2.3.tgz"))
    do $$$AssertNotTrue($classmethod(class, "WildcardMatch", "other-my-ui-1.tgz", "my-ui-*"))
}

Method TestSelectNewestArtifact()
{
    set results = [
        {"repo": "generic-local", "path": "/my-ui/-/my-ui-1.2.3-100.tgz", "lastUpdated": "2026-01-01T10:00:00.000Z", "properties": {"commit.branch": ["main"]}},
        {"repo": "generic-local", "path": "/my-ui/-/my-ui-1.2.3-102.tgz", "lastUpdated": "2026-01-03T10:00:00.000Z", "properties": {"commit.branch": ["main"]}},
        {"repo": "generic-local", "path": "/my-ui/-/my-ui-1.2.3-101.tgz", "lastUpdated": "2026-01-02T10:00:00.000Z", "properties": {"commit.branch": ["main"]}},
        {"repo": "generic-local", "path": "/my-ui/-/my-ui-1.2.3-103.tgz", "lastUpdated": "2026-01-04T10:00:00.000Z", "properties": {"commit.branch": ["feature"]}},
        {"repo": "generic-local", "path": "/my-ui/-/my-ui-1.2.3-104.tgz", "lastUpdated": "2026-01-05T10:00:00.000Z"},
        {"repo": "other-local", "path": "/my-ui/-/my-ui-1.2.3-105.tgz", "lastUpdated": "2026-01-06T10:00:00.000Z", "properties": {"commit.branch": ["main"]}},
        {"repo": "generic-local", "path": "/my-ui/-/my-ui-1.3.0-106.tgz", "lastUpdated": "2026-01-07T10:00:00.000Z", "properties": {"commit.branch": ["main"]}}
    ]
    set class = "%IPM.ResourceProcessor.ArtifactoryTarball"
    set filter = {"repo": "generic-local", "name": {"$match": "my-ui-1.2.3-*"}, "@commit.branch": "main"}
    set criteria = $classmethod(class, "ParseAnonymousFilter", filter.%ToJSON())
    do $$$AssertEquals($classmethod(class, "SelectNewestArtifact", results, criteria), "artifactory/generic-local/my-ui/-/my-ui-1.2.3-102.tgz")

    set filter = {"name": "my-ui-1.2.3-100.tgz", "path": "my-ui/-"}
    set criteria = $classmethod(class, "ParseAnonymousFilter", filter.%ToJSON())
    do $$$AssertEquals($classmethod(class, "SelectNewestArtifact", results, criteria), "artifactory/generic-local/my-ui/-/my-ui-1.2.3-100.tgz")

    set filter = {"name": {"$match": "my-ui-*"}, "@commit.branch": "release"}
    set criteria = $classmethod(class, "ParseAnonymousFilter", filter.%ToJSON())
    do $$$AssertEquals($classmethod(class, "SelectNewestArtifact", results, criteria), "")

    set rootResults = [{"repo": "generic-local", "path": "/my-ui.tgz", "lastUpdated": "2026-01-01T10:00:00.000Z"}]
    set filter = {"name": "my-ui.tgz", "path": "."}
    set criteria = $classmethod(class, "ParseAnonymousFilter", filter.%ToJSON())
    do $$$AssertEquals($classmethod(class, "SelectNewestArtifact", rootResults, criteria), "artifactory/generic-local/my-ui.tgz")
}

}
