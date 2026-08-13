Class Test.PM.Unit.LifecycleDatabase Extends %UnitTest.TestCase
{

/// Modules created outside of this test save modules to storage under fixed names; delete them
/// unconditionally so a failed assert cannot leave rows behind for the next run.
Method OnAfterOneTest(testName As %String) As %Status
{
    for name = "aa-root", "mm-mid", "zz-base" {
        if ##class(%IPM.Storage.Module).NameExists(name) {
            do ##class(%IPM.Storage.Module).NameDelete(name)
        }
    }
    quit $$$OK
}

/// A module declaring Packaging="database" must resolve to %IPM.Lifecycle.Database, not the generic
/// %IPM.Lifecycle.Module. Covers both derivation branches in %OnValidateObject: the default
/// LifecycleClass being switched out, and an empty LifecycleClass being filled in.
Method TestPackagingDerivesLifecycleClass()
{
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = "derive-lifecycle-check"
    set module.VersionString = "1.0.0"
    set module.Packaging = "database"

    // LifecycleClass has an InitialExpression of %IPM.Lifecycle.Module, so this leaves the default
    // in place and validation must notice it disagrees with Packaging.
    do $$$AssertStatusOK(module.%ValidateObject(), "Module with default LifecycleClass and Packaging=database validates")
    do $$$AssertEquals(module.LifecycleClass, "%IPM.Lifecycle.Database", "Default LifecycleClass replaced from database packaging")

    // The other branch: nothing declared at all, so the class is derived rather than replaced.
    set module.LifecycleClass = ""
    do $$$AssertStatusOK(module.%ValidateObject(), "Module with empty LifecycleClass and Packaging=database validates")
    do $$$AssertEquals(module.LifecycleClass, "%IPM.Lifecycle.Database", "Empty LifecycleClass derived from database packaging")
}

/// IsPackagedManifest decides whether a directory is the remains of an already-swapped install,
/// which %Reload refuses to load as source. Detection is the <Checksum> element, so a source
/// manifest and a packaged one must be told apart on that alone.
Method TestIsPackagedManifestDetection()
{
    // TempFilename creates the file it names, so derive a sibling directory from it and delete it.
    set tempFile = ##class(%Library.File).TempFilename()
    set dir = ##class(%Library.File).NormalizeDirectory(tempFile _ ".d")
    do ##class(%Library.File).Delete(tempFile)
    do $$$AssertTrue(##class(%Library.File).CreateDirectoryChain(dir), "Created temp directory")

    do $$$AssertNotTrue(##class(%IPM.Lifecycle.Database).IsPackagedManifest(dir), "Directory with no module.xml is not a packaged manifest")
    do $$$AssertNotTrue(##class(%IPM.Lifecycle.Database).IsPackagedManifest(""), "Empty directory path is not a packaged manifest")

    set header = "<?xml version=""1.0""?>" _ $char(13, 10) _ "<Export generator=""IRIS"">" _ $char(13, 10) _
        "<Document name=""pkg-check.ZPM""><Module><Name>pkg-check</Name><Version>1.0.0</Version>"

    // A source manifest: same shape, no Checksum.
    do ..WriteModuleXML(dir, header _ "</Module></Document></Export>")
    do $$$AssertNotTrue(##class(%IPM.Lifecycle.Database).IsPackagedManifest(dir), "Source manifest is not a packaged manifest")

    // Not valid XML at all: reported by the source load path, not here.
    do ..WriteModuleXML(dir, "<Export><Document")
    do $$$AssertNotTrue(##class(%IPM.Lifecycle.Database).IsPackagedManifest(dir), "Unparseable module.xml is not a packaged manifest")

    do ..WriteModuleXML(dir, header _ "<Packaging>database</Packaging>" _
        "<Checksum Algorithm=""SHA-256"">ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad</Checksum>" _
        "</Module></Document></Export>")
    do $$$AssertTrue(##class(%IPM.Lifecycle.Database).IsPackagedManifest(dir), "Manifest with Checksum is a packaged manifest")

    do ##class(%Library.File).RemoveDirectoryTree(dir)
}

/// Writes content to dir/module.xml, replacing any previous file.
Method WriteModuleXML(
	dir As %String,
	content As %String)
{
    set path = ##class(%Library.File).NormalizeFilename("module.xml", dir)
    // Delete rather than Clear: this is called repeatedly against the same path, and a fresh file
    // is unambiguous about what the stream ends up containing.
    do ##class(%Library.File).Delete(path)
    set stream = ##class(%Stream.FileCharacter).%New()
    do $$$AssertStatusOK(stream.LinkToFile(path), "Linked module.xml")
    do $$$AssertStatusOK(stream.Write(content), "Wrote module.xml content")
    do $$$AssertStatusOK(stream.%Save(), "Saved module.xml")
}

/// Guards the ComputeSHA256Hex output contract (64-char lowercase hex): the hash is produced
/// via the %xsd.hexBinary encoder, so this pins the length and lowercasing.
Method TestSHA256HexFormat()
{
    // Write a small known file and hash it.
    set tmp = ##class(%Library.File).TempFilename("bin")
    set stream = ##class(%Stream.FileBinary).%New()
    do $$$AssertStatusOK(stream.LinkToFile(tmp), "Linked stream to temp file")
    do $$$AssertStatusOK(stream.Write("abc"), "Wrote test content")
    do $$$AssertStatusOK(stream.%Save(), "Saved temp file")
    set hex = ##class(%IPM.Lifecycle.Database).ComputeSHA256Hex(tmp)
    do ##class(%Library.File).Delete(tmp)

    do $$$AssertEquals($length(hex), 64, "SHA-256 hex is 64 characters")
    do $$$AssertEquals($zconvert(hex, "L"), hex, "SHA-256 hex is lowercase")
    // SHA-256 of "abc" is a well-known constant.
    do $$$AssertEquals(hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256('abc') matches known value")
}

/// GetTopologicalDependencyNames must place a dependency before its dependent, unlike
/// GetDependencyNames which returns name order. Uses in-memory module objects saved to storage
/// under names that sort against the required order, so name order and topological order differ.
Method TestTopologicalDependencyOrder()
{
    // "zz-base" <- "mm-mid" <- root. Name order would give mm-mid, zz-base; topological order
    // must give zz-base, mm-mid.
    set base = ##class(%IPM.Storage.Module).%New()
    set base.Name = "zz-base"
    set base.VersionString = "1.0.0"
    do $$$AssertStatusOK(base.%Save(), "Saved zz-base")

    set mid = ##class(%IPM.Storage.Module).%New()
    set mid.Name = "mm-mid"
    set mid.VersionString = "1.0.0"
    set midDep = ##class(%IPM.Storage.ModuleReference).%New()
    set midDep.Name = "zz-base"
    set midDep.VersionString = "1.0.0"
    do mid.Dependencies.Insert(midDep)
    do $$$AssertStatusOK(mid.%Save(), "Saved mm-mid")

    set root = ##class(%IPM.Storage.Module).%New()
    set root.Name = "aa-root"
    set root.VersionString = "1.0.0"
    set rootDep = ##class(%IPM.Storage.ModuleReference).%New()
    set rootDep.Name = "mm-mid"
    set rootDep.VersionString = "1.0.0"
    do root.Dependencies.Insert(rootDep)
    do $$$AssertStatusOK(root.%Save(), "Saved aa-root")

    set ordered = ##class(%IPM.Lifecycle.Database).GetTopologicalDependencyNames(root)
    do $$$AssertEquals($listtostring(ordered, ","), "zz-base,mm-mid", "Dependency precedes dependent")
}

/// Every phase in the canonical install chain must be either run for dependencies or explicitly
/// excluded. Fails when a phase is added to Base.GetCompletePhasesForOne without that decision
/// being made — the exclusion list in Database.GetDependencyExcludedPhases is where to record it.
Method TestDependencyPhasesCoverCanonicalChain()
{
    for entryPhase = "Activate", "ApplyUpdateSteps" {
        set isUpdate = (entryPhase = "ApplyUpdateSteps")
        set canonical = ##class(%IPM.Lifecycle.Base).GetCompletePhasesForOne(entryPhase)
        set run = ##class(%IPM.Lifecycle.Database).GetDependencyInstallPhases(isUpdate)
        set excluded = ##class(%IPM.Lifecycle.Database).GetDependencyExcludedPhases()

        set ptr = 0
        while $listnext(canonical, ptr, onePhase) {
            continue:onePhase=""
            set accountedFor = ($listfind(run, onePhase) > 0) || ($listfind(excluded, onePhase) > 0)
            do $$$AssertTrue(accountedFor, "Canonical phase '" _ onePhase _ "' (" _ entryPhase _ " chain) is either run for dependencies or explicitly excluded")
        }

        // A phase cannot be both, and nothing may be run that the canonical chain does not contain.
        set runPtr = 0
        while $listnext(run, runPtr, runPhase) {
            do $$$AssertNotTrue($listfind(excluded, runPhase), "Phase '" _ runPhase _ "' is not both run and excluded")
            do $$$AssertTrue($listfind(canonical, runPhase) > 0, "Phase '" _ runPhase _ "' comes from the canonical chain")
        }
    }
}

/// Pins the exclusions actually taking effect, so removing one is a visible test change rather
/// than a silent behavior change.
Method TestDependencyPhasesExcludeReloadAndCompile()
{
    set phases = ##class(%IPM.Lifecycle.Database).GetDependencyInstallPhases(0)
    do $$$AssertEquals($listtostring(phases, ","), "Initialize,Validate,Activate", "Dependency install phases")

    // An update runs each dependency's own update steps, matching a source update: params("Update")
    // propagates to dependency loads, which then enter at ApplyUpdateSteps.
    set updatePhases = ##class(%IPM.Lifecycle.Database).GetDependencyInstallPhases(1)
    do $$$AssertEquals($listtostring(updatePhases, ","), "Initialize,Validate,Activate,ApplyUpdateSteps", "Dependency update phases")
}

}
