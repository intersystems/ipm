Class Test.PM.Integration.FilesystemRepo Extends Test.PM.Integration.Base
{

Parameter REPONAME = "fs-cache-test";

Property RepoPath As %String;

XData ModuleB300
{
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
  <Document name="module-b.ZPM">
    <Module>
      <Name>module-b</Name>
      <Version>3.0.0</Version>
      <Packaging>module</Packaging>
    </Module>
  </Document>
</Export>
}

Method OnBeforeAllTests() As %Status
{
    // Set up the repo path - use GetModuleDir utility
    set ..RepoPath = ..GetModuleDir("fs-cache-test")

    // Create filesystem repo pointing to test data
    set sc = ##class(%IPM.Main).Shell("repo -n "_..#REPONAME_" -fs -path "_..RepoPath)
    do $$$AssertStatusOK(sc,"Created fs-cache-test repo successfully.")
    quit sc
}

Method OnAfterAllTests() As %Status
{
    // Remove test repository
    set sc = ##class(%IPM.Main).Shell("repo -delete -name "_..#REPONAME)
    do $$$AssertStatusOK(sc,"Deleted fs-cache-test repo successfully.")
    quit sc
}

Method OnAfterOneTest() As %Status
{
    // Uninstall all modules after each test for clean state
    set sc = ##class(%IPM.Main).Shell("uninstall -all")
    do $$$AssertStatusOK(sc,"Uninstalled all modules after test.")
    quit sc
}

/// Test that cache is built correctly when repo is created
Method TestCacheBuiltCorrectly()
{
    // Get the repo definition
    set repoDef = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen(..#REPONAME,,.sc)
    do $$$AssertStatusOK(sc,"Opened repo definition")
    do $$$AssertTrue($isobject(repoDef),"Repo definition exists")

    // Verify cache entries exist for both modules
    set cacheA = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Cache entry for module-a 1.0.0 exists")
    do $$$AssertTrue($isobject(cacheA),"module-a 1.0.0 found in cache")

    // Verify initial cache state - manifest not loaded, but validation passed during cache build
    // ManifestLoaded=0 means only metadata (name/version) was extracted, not full manifest (lazy loading)
    do $$$AssertEquals(cacheA.ManifestLoaded,0,"ManifestLoaded is initially 0 (lazy loading)")

    set cacheB1 = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Cache entry for module-b 1.0.0 exists")
    do $$$AssertTrue($isobject(cacheB1),"module-b 1.0.0 found in cache")

    set cacheB2 = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","2.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Cache entry for module-b 2.0.0 exists")
    do $$$AssertTrue($isobject(cacheB2),"module-b 2.0.0 found in cache")

    // Verify CacheLastRebuilt is set
    do $$$AssertNotEquals(repoDef.CacheLastRebuilt,"","CacheLastRebuilt timestamp is set")

    // Test installing a module to verify cache works
    set sc = ##class(%IPM.Main).Shell("install module-a 1.0.0")
    do $$$AssertStatusOK(sc,"Successfully installed module-a from cache")
}

/// Test lazy loading - manifests are not fully loaded until accessed
Method TestLazyLoadingVerification()
{
    // Rebuild cache to ensure clean state with ManifestLoaded=0
    set sc = ##class(%IPM.Main).Shell("repo -n "_..#REPONAME_" -rebuild-cache")
    do $$$AssertStatusOK(sc,"Rebuilt cache for clean state")

    // Get cache entry
    set cacheA = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Opened cache entry for module-a")

    // Verify ManifestLoaded flag is initially false (lazy loading optimization)
    do $$$AssertEquals(cacheA.ManifestLoaded,0,"ManifestLoaded flag is initially false")

    // Accessing basic metadata should work without loading full manifest
    do $$$AssertEquals(cacheA.Name,"module-a","Can access Name without full manifest load")
    do $$$AssertEquals(cacheA.VersionString,"1.0.0","Can access Version without full manifest load")

    // Now trigger full manifest load by accessing the manifest
    set repoDef = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen(..#REPONAME,,.sc)
    do $$$AssertStatusOK(sc,"Opened repo definition")

    set packageService = repoDef.GetPackageService()

    // Create ModuleInfo object for GetModuleManifest call
    set moduleInfo = ##class(%IPM.Storage.ModuleInfo).%New()
    set moduleInfo.Name = "module-a"
    set moduleInfo.VersionString = "1.0.0"

    set manifest = packageService.GetModuleManifest(moduleInfo)
    do $$$AssertTrue($isobject(manifest),"Got module manifest")

    // After accessing manifest, the ManifestLoaded flag should be set
    set cacheAReloaded = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertEquals(cacheAReloaded.ManifestLoaded,1,"ManifestLoaded flag is now true after accessing manifest")
}

/// Test manual cache rebuild with -rebuild-cache command
Method TestManualCacheRebuild()
{
    // Set a known stale timestamp so we can verify the rebuild updates it without sleeping
    set repoDef = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen(..#REPONAME,,.sc)
    do $$$AssertStatusOK(sc,"Opened repo definition")
    set repoDef.CacheLastRebuilt = "1970-01-01 00:00:00"
    $$$ThrowOnError(repoDef.%Save())

    // Rebuild cache using command
    set sc = ##class(%IPM.Main).Shell("repo -n "_..#REPONAME_" -rebuild-cache")
    do $$$AssertStatusOK(sc,"Cache rebuild command executed successfully")

    // Verify timestamp was updated from the stale value
    set repoDefAfter = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen(..#REPONAME,,.sc)
    do $$$AssertStatusOK(sc,"Opened repo definition after rebuild")
    do $$$AssertNotEquals(repoDefAfter.CacheLastRebuilt,"1970-01-01 00:00:00","CacheLastRebuilt timestamp was updated")

    // Verify cache entries still exist
    set cacheA = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Cache entry for module-a still exists after rebuild")

    // Test installing a module to verify cache still works
    set sc = ##class(%IPM.Main).Shell("install module-b 2.0.0")
    do $$$AssertStatusOK(sc,"Successfully installed module-b after cache rebuild")
}

/// Read a file's raw bytes. Throws if the file can't be opened.
/// Binary rather than character: these tests hash the file, so a read/write round trip has to
/// reproduce the original bytes exactly. A character stream rewrites CRLF as LF, and the fixtures
/// check out with CRLF wherever git's autocrlf applies.
Method ReadFile(path As %String) As %String [ Private ]
{
    set file = ##class(%Stream.FileBinary).%New()
    $$$ThrowOnError(file.LinkToFile(path))
    set content = ""
    while 'file.AtEnd {
        set content = content_file.Read()
    }
    quit content
}

/// Replace a file's contents with the given bytes. See ReadFile for why this is binary.
Method WriteFile(
	path As %String,
	content As %String) As %Status [ Private ]
{
    set sc = $$$OK
    try {
        set file = ##class(%Stream.FileBinary).%New()
        $$$ThrowOnError(file.LinkToFile(path))
        do file.Clear()
        do file.Write(content)
        $$$ThrowOnError(file.%Save())
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

/// Test cache freshness detection via ContentHash tracking: an edited module.xml gets a different
/// hash, so the next validated open re-parses the entry.
Method TestCacheFreshnessDetection()
{
    // Get the original cache entry
    set cacheA = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Opened original cache entry")
    set originalHash = cacheA.ContentHash
    do $$$AssertNotEquals(originalHash,"","Original ContentHash is set")

    set moduleFile = ##class(%File).NormalizeFilename("module.xml",##class(%File).NormalizeFilename("module-a/1.0.0",..RepoPath))
    set originalContent = ..ReadFile(moduleFile)
    do $$$AssertNotEquals(originalContent,"","Read the original module.xml content")

    // Later tests share this git-tracked fixture, so the assertions run inside a try and the restore
    // below happens whether they pass, fail, or throw.
    try {
        // Change the content, not just the timestamp: content hashing only reacts to real edits.
        set modifiedContent = $replace(originalContent,"<Packaging>module</Packaging>","<Packaging>module</Packaging>"_$char(10)_"      <Description>freshness probe</Description>")
        do $$$AssertNotEquals(modifiedContent,originalContent,"Prepared modified module.xml content")
        do $$$AssertStatusOK(..WriteFile(moduleFile,modifiedContent),"Rewrote module.xml with changed content")

        // Access the cache entry via validated open (this checks ContentHash)
        set cacheARefreshed = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpenValidated(..RepoPath,"module-a","1.0.0",,.sc)
        do $$$AssertStatusOK(sc,"Cache entry was refreshed based on ContentHash")
        do $$$AssertNotEquals(cacheARefreshed.ContentHash,originalHash,"ContentHash was updated after the content changed")
        do $$$AssertEquals(cacheARefreshed.ManifestLoaded,0,"Changed manifest is flagged for reparse")

        // Verify we can still install the module
        do $$$AssertStatusOK(##class(%IPM.Main).Shell("install module-a 1.0.0"),"Successfully installed module after cache refresh")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"No error while testing cache freshness")
    }

    do $$$AssertStatusOK(..WriteFile(moduleFile,originalContent),"Restored the original module.xml")
    set cacheARestored = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpenValidated(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Reopened the cache entry after restoring the fixture")
    do $$$AssertTrue($isobject(cacheARestored),"Got a cache entry back after restoring the fixture")
    if $isobject(cacheARestored) {
        do $$$AssertEquals(cacheARestored.ContentHash,originalHash,"ContentHash returned to its original value")
    }
}

/// A module.xml that cannot be parsed must not cost the module its cache entry. The file is still
/// present, so nothing has been deleted and the stale-entry cleanup has no business evicting it.
Method TestUnparseableFileKeepsCacheEntry()
{
    set repoDef = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen(..#REPONAME,,.sc)
    do $$$AssertStatusOK(sc,"Opened repo definition")

    set moduleFile = ##class(%File).NormalizeFilename("module.xml",##class(%File).NormalizeFilename("module-a/1.0.0",..RepoPath))
    set originalContent = ..ReadFile(moduleFile)

    try {
        do $$$AssertStatusOK(..WriteFile(moduleFile,"<Export><Document name=""module-a.ZPM""><Module>"),"Wrote a truncated module.xml")

        // purge=0 is the path an install takes, and the only one that runs stale-entry cleanup.
        do $$$AssertStatusOK(repoDef.BuildCache(0,0),"Rebuilt cache over the unparseable file")

        set cacheA = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-a","1.0.0",,.sc)
        do $$$AssertTrue($isobject(cacheA),"module-a 1.0.0 survived a rebuild over an unparseable module.xml")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"No error while testing an unparseable module.xml")
    }

    do $$$AssertStatusOK(..WriteFile(moduleFile,originalContent),"Restored the original module.xml")
    do $$$AssertStatusOK(repoDef.BuildCache(1,0),"Purged and rebuilt the cache after restoring the fixture")
}

/// Editing <Version> in place changes which module the cache entry describes. Resolving the old
/// version has to fail rather than quietly hand back the new one.
Method TestVersionBumpInPlaceDoesNotReturnWrongModule()
{
    set repoDef = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen(..#REPONAME,,.sc)
    do $$$AssertStatusOK(sc,"Opened repo definition")

    set moduleFile = ##class(%File).NormalizeFilename("module.xml",##class(%File).NormalizeFilename("module-a/1.0.0",..RepoPath))
    set originalContent = ..ReadFile(moduleFile)

    try {
        set bumpedContent = $replace(originalContent,"<Version>1.0.0</Version>","<Version>1.1.0</Version>")
        do $$$AssertNotEquals(bumpedContent,originalContent,"Prepared a version-bumped module.xml")
        do $$$AssertStatusOK(..WriteFile(moduleFile,bumpedContent),"Wrote the version-bumped module.xml")

        set stale = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpenValidated(..RepoPath,"module-a","1.0.0",,.sc)
        do $$$AssertStatusNotOK(sc,"Resolving 1.0.0 fails once the file on disk describes 1.1.0")
        do $$$AssertTrue('$isobject(stale),"No cache entry is handed back for the version that is gone")

        set bumped = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-a","1.1.0",,.sc)
        do $$$AssertTrue($isobject(bumped),"The refreshed entry describes module-a 1.1.0")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"No error while testing an in-place version bump")
    }

    do $$$AssertStatusOK(..WriteFile(moduleFile,originalContent),"Restored the original module.xml")
    do $$$AssertStatusOK(repoDef.BuildCache(1,0),"Purged and rebuilt the cache after restoring the fixture")
}

/// A root that has gone missing must fail the rebuild rather than empty the cache. An unmounted share
/// should not look like a repository whose modules were all deleted.
Method TestMissingRootDoesNotEmptyCache()
{
    set tempRoot = ##class(%IPM.Utils.File).CreateTempDirectory()

    try {
        set moduleDir = ##class(%File).NormalizeFilename("module-b/3.0.0",tempRoot)
        do $$$AssertStatusOK(##class(%IPM.Utils.File).CreateDirectoryChain(moduleDir),"Created a module directory under a temporary root")

        set xdata = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||ModuleB300",,.sc)
        do $$$AssertStatusOK(sc,"Opened XData block")
        set file = ##class(%Stream.FileCharacter).%New()
        $$$ThrowOnError(file.LinkToFile(##class(%File).NormalizeFilename("module.xml",moduleDir)))
        $$$ThrowOnError(file.CopyFrom(xdata.Data))
        $$$ThrowOnError(file.%Save())

        do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -n fs-missing-root -fs -path "_tempRoot),"Created a repo over the temporary root")

        set repoDef = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen("fs-missing-root",,.sc)
        do $$$AssertStatusOK(sc,"Opened the temporary repo definition")
        do $$$AssertTrue(##class(%IPM.Repo.Filesystem.Cache).RootNameVersionExists(repoDef.Root,"module-b","3.0.0"),"module-b 3.0.0 is cached while the root exists")

        do $$$AssertTrue(##class(%File).RemoveDirectoryTree(tempRoot),"Removed the temporary root")

        do $$$AssertStatusNotOK(repoDef.BuildCache(0,0),"Rebuilding against a missing root reports an error")
        do $$$AssertTrue(##class(%IPM.Repo.Filesystem.Cache).RootNameVersionExists(repoDef.Root,"module-b","3.0.0"),"The cache entry survived a rebuild against a missing root")
    } catch e {
        do $$$AssertStatusOK(e.AsStatus(),"No error while testing a missing root")
    }

    do $$$AssertStatusOK(##class(%IPM.Main).Shell("repo -delete -name fs-missing-root"),"Cleaned up the temporary repo")
    // Already removed by the test body on the happy path; this covers an early failure.
    do ##class(%IPM.Utils.File).RemoveDirectoryTree(tempRoot)
}

/// Test adding a new version to the filesystem and auto-discovery on install
Method TestAutoDiscoverNewVersion()
{
    // Create new directory for module-b 3.0.0
    set newVersionDir = ##class(%File).NormalizeFilename("module-b/3.0.0",..RepoPath)
    set created = ##class(%File).CreateDirectory(newVersionDir)
    do $$$AssertTrue(created,"Created directory for module-b 3.0.0")

    // Create module.xml file from XData block
    set moduleFile = ##class(%File).NormalizeFilename("module.xml",newVersionDir)

    // Read XData content
    set xdata = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||ModuleB300",,.sc)
    do $$$AssertStatusOK(sc,"Opened XData block")

    set file = ##class(%Stream.FileCharacter).%New()
    set sc = file.LinkToFile(moduleFile)
    do $$$AssertStatusOK(sc,"Linked to new module file")
    do file.CopyFrom(xdata.Data)
    set sc = file.%Save()
    do $$$AssertStatusOK(sc,"Saved new module.xml file")

    // NOTE: No manual cache rebuild here - install should auto-discover the new version
    // This tests the auto-rebuild feature (cache rebuilt before dependency resolution)

    // Verify new version is NOT yet in cache
    set cacheB3 = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","3.0.0",,.sc)
    do $$$AssertTrue('$isobject(cacheB3),"module-b 3.0.0 not yet in cache before install")

    // Install should auto-rebuild cache and find the new version
    set sc = ##class(%IPM.Main).Shell("install module-b 3.0.0")
    do $$$AssertStatusOK(sc,"Successfully installed module-b 3.0.0 with auto-rebuild")

    // Verify new version is NOW in cache (after install auto-rebuilt)
    set cacheB3After = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","3.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Cache entry for module-b 3.0.0 exists after install")
    do $$$AssertTrue($isobject(cacheB3After),"module-b 3.0.0 found in cache after auto-rebuild")

    // Clean up created directory so it doesn't affect other tests
    do ##class(%File).RemoveDirectoryTree(newVersionDir)
}

/// Test that a stale cache entry is removed when its directory is deleted and cache is rebuilt.
Method TestStaleEntryCleanup()
{
    // Create a temporary module-b 3.0.0 directory with a valid module.xml
    set newVersionDir = ##class(%File).NormalizeFilename("module-b/3.0.0",..RepoPath)
    set created = ##class(%File).CreateDirectory(newVersionDir)
    do $$$AssertTrue(created,"Created directory for module-b 3.0.0")

    set xdata = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||ModuleB300",,.sc)
    do $$$AssertStatusOK(sc,"Opened XData block")
    set moduleFile = ##class(%File).NormalizeFilename("module.xml",newVersionDir)
    set file = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(file.LinkToFile(moduleFile))
    do file.CopyFrom(xdata.Data)
    $$$ThrowOnError(file.%Save())

    // Rebuild cache to pick up the new directory
    set sc = ##class(%IPM.Main).Shell("repo -n "_..#REPONAME_" -rebuild-cache")
    do $$$AssertStatusOK(sc,"Rebuilt cache to populate module-b 3.0.0 entry")

    set cacheB3 = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","3.0.0",,.sc)
    do $$$AssertTrue($isobject(cacheB3),"module-b 3.0.0 exists in cache before deletion")

    // Delete the directory to create a stale cache entry
    set deleted = ##class(%File).RemoveDirectoryTree(newVersionDir)
    do $$$AssertTrue(deleted,"Deleted module-b 3.0.0 directory")

    // Rebuild cache to trigger stale entry cleanup
    set sc = ##class(%IPM.Main).Shell("repo -n "_..#REPONAME_" -rebuild-cache")
    do $$$AssertStatusOK(sc,"Rebuilt cache after deletion")

    // Verify stale entry was removed
    set cacheB3After = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","3.0.0",,.sc)
    do $$$AssertTrue('$isobject(cacheB3After),"module-b 3.0.0 removed from cache after deletion")

    // Verify other versions still exist
    set cacheB2 = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","2.0.0",,.sc)
    do $$$AssertTrue($isobject(cacheB2),"module-b 2.0.0 still exists in cache")
}

/// Test depth specification - create repo with depth and verify it only scans to that depth
Method TestDepthSpecification()
{
    // Test structure:
    // fs-cache-test-depth/module-shallow/1.0.0/module.xml (2 levels deep)
    // fs-cache-test-depth/nested/module-deep/1.0.0/module.xml (3 levels deep)

    // Create a new repo with depth=2 (should only find modules up to 2 levels deep)
    set depthRepoPath = ..GetModuleDir("fs-cache-test-depth")
    set sc = ##class(%IPM.Main).Shell("repo -n fs-cache-depth -fs -path "_depthRepoPath_" -depth 2")
    do $$$AssertStatusOK(sc,"Created repo with depth=2")

    // Get repo definition and verify depth is set
    set repoDef = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen("fs-cache-depth",,.sc)
    do $$$AssertStatusOK(sc,"Opened depth repo definition")
    do $$$AssertEquals(repoDef.Depth,2,"Depth is set to 2")

    // Verify that only modules at depth 2 are cached (not nested deeper)
    // module-shallow at depth 2 should be found
    set cacheShallow = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(depthRepoPath,"module-shallow","1.0.0",,.sc)
    do $$$AssertTrue($isobject(cacheShallow),"module-shallow at depth 2 found in cache")

    // module-deep at depth 3 should NOT be found (exceeds depth limit)
    set cacheDeep = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(depthRepoPath,"module-deep","1.0.0",,.sc)
    do $$$AssertTrue('$isobject(cacheDeep),"module-deep at depth 3 not found in cache (exceeds depth)")

    // Clean up depth repo
    set sc = ##class(%IPM.Main).Shell("repo -delete -name fs-cache-depth")
    do $$$AssertStatusOK(sc,"Cleaned up depth test repo")

    // Test repo without depth specification (depth=0, unlimited)
    set sc = ##class(%IPM.Main).Shell("repo -n fs-cache-unlimited -fs -path "_depthRepoPath)
    do $$$AssertStatusOK(sc,"Created repo with unlimited depth")

    set repoDefUnlimited = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen("fs-cache-unlimited",,.sc)
    do $$$AssertStatusOK(sc,"Opened unlimited depth repo definition")
    do $$$AssertEquals(repoDefUnlimited.Depth,0,"Depth is 0 (unlimited)")

    // Both shallow and deep modules should be found with unlimited depth
    set cacheShallow2 = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(depthRepoPath,"module-shallow","1.0.0",,.sc)
    do $$$AssertTrue($isobject(cacheShallow2),"module-shallow found with unlimited depth")

    set cacheDeep2 = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(depthRepoPath,"module-deep","1.0.0",,.sc)
    do $$$AssertTrue($isobject(cacheDeep2),"module-deep found with unlimited depth")

    // Clean up
    set sc = ##class(%IPM.Main).Shell("repo -delete -name fs-cache-unlimited")
    do $$$AssertStatusOK(sc,"Cleaned up unlimited depth test repo")
}

/// A touch that leaves the content identical must not invalidate the cache entry: this is the
/// difference between content hashing and the mtime tracking it replaced.
Method TestTouchDoesNotReparse()
{
    set moduleFile = ##class(%File).NormalizeFilename("module.xml",##class(%File).NormalizeFilename("module-a/1.0.0",..RepoPath))

    // Load the manifest first, so there is a set ManifestLoaded flag to watch survive the touch.
    set repoDef = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen(..#REPONAME,,.sc)
    do $$$AssertStatusOK(sc,"Opened repo definition")
    set packageService = repoDef.GetPackageService()
    set moduleInfo = ##class(%IPM.Storage.ModuleInfo).%New()
    set moduleInfo.Name = "module-a"
    set moduleInfo.VersionString = "1.0.0"
    do $$$AssertTrue($isobject(packageService.GetModuleManifest(moduleInfo)),"Got module manifest")

    set cacheBefore = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Opened cache entry before the touch")
    do $$$AssertEquals(cacheBefore.ManifestLoaded,1,"Manifest is loaded before the touch")
    set hashBefore = cacheBefore.ContentHash

    // Rewrite byte-identical content: this bumps the file's mtime but not its content hash.
    set content = ..ReadFile(moduleFile)
    do $$$AssertStatusOK(..WriteFile(moduleFile,content),"Rewrote module.xml with identical content")

    set cacheAfter = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpenValidated(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Validated open succeeded after the touch")
    do $$$AssertEquals(cacheAfter.ContentHash,hashBefore,"ContentHash is unchanged by a touch")
    do $$$AssertEquals(cacheAfter.ManifestLoaded,1,"Touch did not discard the loaded manifest")
}

}
