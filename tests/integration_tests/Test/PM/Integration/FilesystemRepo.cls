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
Method Test01CacheBuiltCorrectly()
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
    // ValidationPassed=1 means the module.xml was validated as a valid ZPM document during cache build
    do $$$AssertEquals(cacheA.ManifestLoaded,0,"ManifestLoaded is initially 0 (lazy loading)")
    do $$$AssertEquals(cacheA.ValidationPassed,1,"ValidationPassed is 1 after cache build")

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
Method Test02LazyLoadingVerification()
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
Method Test03RebuildCache()
{
    // Get initial cache rebuild timestamp
    set repoDef = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen(..#REPONAME,,.sc)
    do $$$AssertStatusOK(sc,"Opened repo definition")
    set initialTimestamp = repoDef.CacheLastRebuilt

    // Rebuild cache using command
    set sc = ##class(%IPM.Main).Shell("repo -n "_..#REPONAME_" -rebuild-cache")
    do $$$AssertStatusOK(sc,"Cache rebuild command executed successfully")

    // Verify timestamp was updated
    set repoDefAfter = ##class(%IPM.Repo.Filesystem.Definition).ServerDefinitionKeyOpen(..#REPONAME,,.sc)
    do $$$AssertStatusOK(sc,"Opened repo definition after rebuild")
    do $$$AssertNotEquals(repoDefAfter.CacheLastRebuilt,initialTimestamp,"CacheLastRebuilt timestamp was updated")

    // Verify cache entries still exist
    set cacheA = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Cache entry for module-a still exists after rebuild")

    // Test installing a module to verify cache still works
    set sc = ##class(%IPM.Main).Shell("install module-b 2.0.0")
    do $$$AssertStatusOK(sc,"Successfully installed module-b after cache rebuild")
}

/// Test cache freshness detection via FileMTime tracking
Method Test04CacheFreshnessDetection()
{
    // Get the original cache entry
    set cacheA = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Opened original cache entry")
    set originalMTime = cacheA.FileMTime
    do $$$AssertNotEquals(originalMTime,"","Original FileMTime is set")

    // Modify the module.xml file by rewriting it (updating mtime)
    set moduleFile = ##class(%File).NormalizeFilename("module.xml",##class(%File).NormalizeFilename("module-a/1.0.0",..RepoPath))

    // Read and rewrite the file to update its modification time
    set file = ##class(%Stream.FileCharacter).%New()
    set sc = file.LinkToFile(moduleFile)
    do $$$AssertStatusOK(sc,"Linked to module file")
    set content = ""
    while 'file.AtEnd {
        set content = content_file.Read()
    }
    do file.Clear()
    set sc = file.LinkToFile(moduleFile)
    do file.Write(content)
    set sc = file.%Save()
    do $$$AssertStatusOK(sc,"Updated module file mtime")

    // Access the cache entry via validated open (this checks FileMTime)
    set cacheARefreshed = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpenValidated(..RepoPath,"module-a","1.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Cache entry was refreshed based on FileMTime")

    // Verify FileMTime was updated
    do $$$AssertNotEquals(cacheARefreshed.FileMTime,originalMTime,"FileMTime was updated after file modification")

    // Verify we can still install the module
    set sc = ##class(%IPM.Main).Shell("install module-a 1.0.0")
    do $$$AssertStatusOK(sc,"Successfully installed module after cache refresh")
}

/// Test adding a new version to the filesystem
Method Test05AddNewVersion()
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

    // Rebuild cache to pick up new version
    set sc = ##class(%IPM.Main).Shell("repo -n "_..#REPONAME_" -rebuild-cache")
    do $$$AssertStatusOK(sc,"Rebuilt cache")

    // Verify new version is in cache
    set cacheB3 = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","3.0.0",,.sc)
    do $$$AssertStatusOK(sc,"Cache entry for module-b 3.0.0 exists")
    do $$$AssertTrue($isobject(cacheB3),"module-b 3.0.0 found in cache")

    // Test installing the new version
    set sc = ##class(%IPM.Main).Shell("install module-b 3.0.0")
    do $$$AssertStatusOK(sc,"Successfully installed module-b 3.0.0")
}

/// Test deleting a version and verifying stale entry cleanup
Method Test06DeleteVersionStaleCleanup()
{
    // Verify module-b 3.0.0 exists in cache (from previous test)
    set cacheB3 = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","3.0.0",,.sc)
    do $$$AssertTrue($isobject(cacheB3),"module-b 3.0.0 exists before deletion")

    // Delete the directory
    set versionDir = ##class(%File).NormalizeFilename("module-b/3.0.0",..RepoPath)
    set deleted = ##class(%File).RemoveDirectoryTree(versionDir)
    do $$$AssertTrue(deleted,"Deleted module-b 3.0.0 directory")

    // Rebuild cache to trigger cleanup
    set sc = ##class(%IPM.Main).Shell("repo -n "_..#REPONAME_" -rebuild-cache")
    do $$$AssertStatusOK(sc,"Rebuilt cache after deletion")

    // Verify cache entry was removed
    set cacheB3After = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","3.0.0",,.sc)
    do $$$AssertTrue('$isobject(cacheB3After),"module-b 3.0.0 removed from cache after deletion")

    // Verify other versions still exist
    set cacheB2 = ##class(%IPM.Repo.Filesystem.Cache).RootNameVersionOpen(..RepoPath,"module-b","2.0.0",,.sc)
    do $$$AssertTrue($isobject(cacheB2),"module-b 2.0.0 still exists in cache")
}

/// Test depth specification - create repo with depth and verify it only scans to that depth
Method Test07DepthSpecification()
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

}
