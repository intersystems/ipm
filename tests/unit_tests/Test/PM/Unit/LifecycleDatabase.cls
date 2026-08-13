Class Test.PM.Unit.LifecycleDatabase Extends %UnitTest.TestCase
{

/// A module declaring Packaging="database" with no explicit LifecycleClass must resolve to
/// %IPM.Lifecycle.Database, not the generic %IPM.Lifecycle.Module.
Method TestPackagingDerivesLifecycleClass()
{
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = "derive-lifecycle-check"
    set module.VersionString = "1.0.0"
    set module.Packaging = "database"
    // Leave LifecycleClass empty so the derivation path runs.

    set sc = module.%ValidateObject()
    do $$$AssertStatusOK(sc, "Module with Packaging=database validates")
    do $$$AssertEquals(module.LifecycleClass, "%IPM.Lifecycle.Database", "LifecycleClass derived from database packaging")
}

/// Guards the ComputeSHA256Hex output contract (64-char lowercase hex): the hash is produced
/// via the %xsd.hexBinary encoder, so this pins the length and lowercasing.
Method TestSHA256HexFormat()
{
    // Write a small known file and hash it.
    set tmp = ##class(%Library.File).TempFilename("bin")
    set stream = ##class(%Stream.FileBinary).%New()
    do stream.LinkToFile(tmp)
    do stream.Write("abc")
    do stream.%Save()
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

    do $$$AssertStatusOK(##class(%IPM.Storage.Module).NameDelete("aa-root"), "Deleted aa-root")
    do $$$AssertStatusOK(##class(%IPM.Storage.Module).NameDelete("mm-mid"), "Deleted mm-mid")
    do $$$AssertStatusOK(##class(%IPM.Storage.Module).NameDelete("zz-base"), "Deleted zz-base")
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
