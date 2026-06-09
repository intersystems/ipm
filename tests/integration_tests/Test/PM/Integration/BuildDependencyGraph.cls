/// zpm "zpm verify -DUnitTest.Case=Test.PM.Integration.BuildDependencyGraph"
Class Test.PM.Integration.BuildDependencyGraph Extends Test.PM.Integration.Base
{

Parameter REPONAME = "build-dependency-graph";

Method OnBeforeAllTests() As %Status
{
    // Set up repo once
    set sc = ##class(%IPM.Main).Shell("repo -n "_..#REPONAME_" -fs -path "_..GetModuleDir(..#REPONAME))
    do $$$AssertStatusOK(sc, "Created "_..#REPONAME_" repo successfully.")
    return sc
}

Method OnAfterAllTests() As %Status
{
    // Clean up repo after all tests complete
    set sc = ##class(%IPM.Main).Shell("repo -delete -name "_..#REPONAME)
    do $$$AssertStatusOK(sc, "Deleted "_..#REPONAME_" repo successfully.")
    return sc
}

Method OnAfterOneTest() As %Status
{
    // Uninstall all installed modules after each test to ensure a clean slate for the next test and
    // prevent cross-test interference from installed modules
    set sc = ##class(%IPM.Main).Shell("uninstall -all")
    do $$$AssertStatusOK(sc, "Uninstalled all modules successfully.")
    return sc
}

// ===== Installed module interactions =====

/// When a dependency is already installed at a version that satisfies the required expression,
/// BuildDependencyGraph should record that installed version in the graph and skip the
/// repository search entirely (pIgnoreInstalledModules=0, default).
/// Test data: build-dependency-graph/complex-c 2.0.0 installed; build graph for complex-a 1.0.0
/// which requires complex-c ^2.0.0 — installed version should be used.
Method TestInstalledVersionUsedWhenCompatible()
{
    // Install complex-c 2.0.0 — a dependency of complex-a compatible with its ^2.0.0 requirement
    set sc = ##class(%IPM.Main).Shell("load " _ ..GetModuleDir(..#REPONAME, "complex-c", "2.0.0"))
    do $$$AssertStatusOK(sc, "Loaded complex-c 2.0.0.")

    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-a", "1.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-a 1.0.0 module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeded with complex-c 2.0.0 installed.")

    do $$$AssertTrue($data(graph("complex-c")), "complex-c in graph.")
    set $listbuild(, server, version) = graph("complex-c")
    do $$$AssertEquals(version, "2.0.0", "complex-c resolved at installed version 2.0.0.")
    do $$$AssertEquals(server, "", "complex-c served from installed module (empty server name).")
}

/// When the directly installed version of a dependency is a higher major than the required
/// range, the downgrade prevention lower bound (>=installed) combined with the required range
/// produces an unsatisfiable expression. With pIgnoreInstalledModules=1 the installed version
/// is not consulted and resolution falls back to the repository.
/// Test data: complex-c 3.0.0 installed; build graph for complex-a 1.0.0 (requires complex-c ^2.0.0).
Method TestInstalledDirectVersionConflictWithAndWithoutIgnoreFlag()
{
    // Install complex-c 3.0.0 — a higher major version than complex-a requires (^2.0.0)
    set sc = ##class(%IPM.Main).Shell("load " _ ..GetModuleDir(..#REPONAME, "complex-c", "3.0.0"))
    do $$$AssertStatusOK(sc, "Loaded complex-c 3.0.0.")

    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-a", "1.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-a 1.0.0 module object.")

    // pPermitDowngrade=0 (default): >=3.0.0 (downgrade prevention) AND ^2.0.0 = >=2.0.0 <3.0.0-0 → conflict
    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusNotOK(sc, "BuildDependencyGraph() fails when installed version is a higher major.")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "complex-c", "Error message names complex-c as the conflict.")

    // pIgnoreInstalledModules=1: installed version not consulted → resolves complex-c 2.0.0 from repo
    kill graph
    set sc = mod.BuildDependencyGraph(.graph, , , , , , , , 1)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeds with pIgnoreInstalledModules=1.")
    set $listbuild(, , version) = graph("complex-c")
    do $$$AssertEquals(version, "2.0.0", "complex-c resolved at 2.0.0 from repo (installed 3.0.0 ignored).")
}

/// When an installed module has its own dependency on module-dep, GetRequiredVersionExpression
/// surfaces that installed module's constraint, which may conflict with the requirement being
/// resolved. With pIgnoreInstalledModules=1 the installed module's constraint is not applied
/// and resolution succeeds.
/// Test data: complex-b 2.0.0 installed (requires complex-c ^3.0.0); build graph for complex-a
/// 1.0.0 (requires complex-c ^2.0.0) — conflict without pIgnoreInstalledModules=1.
Method TestInstalledModuleConstraintConflictWithAndWithoutIgnoreFlag()
{
    // Install complex-b 2.0.0 which requires complex-c ^3.0.0; this also installs complex-c 3.0.0
    set sc = ##class(%IPM.Main).Shell("load " _ ..GetModuleDir(..#REPONAME, "complex-b", "2.0.0"))
    do $$$AssertStatusOK(sc, "Loaded complex-b 2.0.0.")

    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-a", "1.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-a 1.0.0 module object.")

    // Without pIgnoreInstalledModules: complex-b's installed ^3.0.0 constraint + complex-a's ^2.0.0 → conflict
    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusNotOK(sc, "BuildDependencyGraph() fails due to installed module constraint conflict.")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "complex-c", "Error message names complex-c as the conflict.")

    // With pIgnoreInstalledModules=1: installed constraints excluded → resolves complex-c 2.0.0 from repo
    kill graph
    set sc = mod.BuildDependencyGraph(.graph, , , , , , , , 1)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeds with pIgnoreInstalledModules=1.")
    set $listbuild(, , version) = graph("complex-c")
    do $$$AssertEquals(version, "2.0.0", "complex-c resolved at 2.0.0 when installed constraints ignored.")
}

/// With pPermitDowngrade=0 (default), if the installed version of a dependency is higher than
/// what the expression would otherwise allow, a >=installed lower bound is added and the error
/// message includes it as a named constraint source.
/// Test data: complex-b 2.0.0 installed; build graph for complex-root 1.0.0 (requires complex-b ^1.0.0).
Method TestDowngradePreventedByDefault()
{
    // Install complex-b 2.0.0 — a higher major version than complex-root 1.0.0 requires (^1.0.0)
    set sc = ##class(%IPM.Main).Shell("load " _ ..GetModuleDir(..#REPONAME, "complex-b", "2.0.0"))
    do $$$AssertStatusOK(sc, "Loaded complex-b 2.0.0.")

    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-root", "1.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-root 1.0.0 module object.")

    // pPermitDowngrade=0 (default): >=2.0.0 (downgrade prevention) AND ^1.0.0 = >=1.0.0 <2.0.0-0 → conflict
    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusNotOK(sc, "BuildDependencyGraph() fails when downgrade would be required.")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "complex-b", "Error message names complex-b as the conflict.")
}

/// Modules listed in pCoUpdatingModules are excluded from GetRequiredVersionExpression so
/// their installed constraints are not applied when resolving shared dependencies.
/// Test data: complex-a 1.0.0 installed (requires complex-c ^2.0.0); build graph for complex-b
/// 2.0.0 (requires complex-c ^3.0.0) — conflict without co-updating, succeeds with it.
Method TestCoUpdatingModulesExcludedFromInstalledCheck()
{
    // Install complex-a 1.0.0 which requires complex-c ^2.0.0
    set sc = ##class(%IPM.Main).Shell("load " _ ..GetModuleDir(..#REPONAME, "complex-a", "1.0.0"))
    do $$$AssertStatusOK(sc, "Loaded complex-a 1.0.0.")

    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-b", "2.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-b 2.0.0 module object.")

    // Without pCoUpdatingModules: complex-a's ^2.0.0 constraint conflicts with complex-b's ^3.0.0
    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusNotOK(sc, "BuildDependencyGraph() fails when installed complex-a constraint conflicts.")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "complex-c", "Error message names complex-c as the conflict.")

    // With pCoUpdatingModules=["complex-a"]: complex-a's constraint excluded → complex-c 3.0.0 from repo
    kill graph
    set sc = mod.BuildDependencyGraph(.graph, , , , , , , , , , , , , , $listbuild("complex-a"))
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeds when complex-a is co-updating.")
    set $listbuild(, , version) = graph("complex-c")
    do $$$AssertEquals(version, "3.0.0", "complex-c resolved at 3.0.0 (complex-a's constraint excluded.")
}

// ===== Scoped dependency handling =====

/// A transitive dependency declared with Scope="test" on an intermediate module should NOT
/// appear in the graph when BuildDependencyGraph is called without the test phase active.
/// Test data: build-dependency-graph/scoped-root; build without pPhases including "test".
Method TestScopedDepExcludedWhenPhaseInactive()
{
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "scoped-root"), .found)
    do $$$AssertTrue(found, "Loaded scoped-root 1.0.0 module object.")

    // Build graph with no phases active — scoped test/verify deps should be excluded
    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeded with no phases.")

    do $$$AssertTrue($data(graph("scoped-b")), "scoped-b (non-scoped) in graph.")
    do $$$AssertTrue('$data(graph("scoped-c")), "scoped-c (test-scoped) absent from graph when test phase inactive.")
    do $$$AssertTrue('$data(graph("scoped-d")), "scoped-d (verify-scoped) absent from graph when verify phase inactive.")
}

/// The same test-scoped transitive dependency DOES appear in the graph when BuildDependencyGraph
/// is called with the test phase active, and its scope field in the graph entry equals "test".
/// Test data: build-dependency-graph/scoped-root; build with pPhases=$listbuild("test","verify").
Method TestScopedDepIncludedWhenPhaseActive()
{
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "scoped-root"), .found)
    do $$$AssertTrue(found, "Loaded scoped-root 1.0.0 module object.")

    set phases = $listbuild("test", "verify")
    set sc = mod.BuildDependencyGraph(.graph, , , , phases)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeded with test+verify phases.")

    do $$$AssertTrue($data(graph("scoped-b")), "scoped-b in graph.")
    set $listbuild(,,,,scopeB) = graph("scoped-b")
    do $$$AssertEquals(scopeB, "", "scoped-b scope is empty (non-scoped).")

    do $$$AssertTrue($data(graph("scoped-c")), "scoped-c in graph when test phase active.")
    set $listbuild(,,,,scopeC) = graph("scoped-c")
    do $$$AssertEquals(scopeC, "test", "scoped-c scope is 'test'.")

    do $$$AssertTrue($data(graph("scoped-d")), "scoped-d in graph when verify phase active.")
    set $listbuild(,,,,scopeD) = graph("scoped-d")
    do $$$AssertEquals(scopeD, "verify", "scoped-d scope is 'verify'.")
}

/// When two dependencies share a common sub-dependency but one requires it with Scope="test"
/// at an incompatible version, no conflict error is raised when building without the test phase
/// because the scoped requirement is skipped entirely.
/// Test data: scoped-root 2.0.0 (requires loop-a ^1.0.0 prod and scoped-b ^3.0.0 prod);
/// scoped-b 3.0.0 test-requires loop-c ^2.0.0; loop-a requires loop-c ^1.0.0.
Method TestScopedDepIncompatibleVersionNoConflictOutsidePhase()
{
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "scoped-root", "2.0.0"), .found)
    do $$$AssertTrue(found, "Loaded scoped-root 2.0.0 module object.")

    // Without test phase: scoped-b's test-scoped dep on loop-c ^2.0.0 is skipped → no conflict
    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeds without test phase.")

    do $$$AssertTrue($data(graph("loop-a")), "loop-a in graph.")
    do $$$AssertTrue($data(graph("scoped-b")), "scoped-b in graph.")
    do $$$AssertTrue($data(graph("loop-c")), "loop-c in graph (from loop-a prod dep).")
    set $listbuild(, , version) = graph("loop-c")
    do $$$AssertEquals(version, "1.0.0", "loop-c resolved at 1.0.0 via loop-a; scoped-b's test dep excluded.")
}

/// The same scenario where one module has a test-scoped dependency at an incompatible version
/// DOES produce a conflict error when the test phase is active, because both constraints
/// are included in the cumulative version expression.
/// Test data: scoped-root 2.0.0 requires loop-a ^1.0.0 (prod) and scoped-b ^3.0.0 (prod);
/// loop-a requires loop-c ^1.0.0; scoped-b 3.0.0 test-requires loop-c ^2.0.0.
/// With test phase: ^1.0.0 AND ^2.0.0 is an empty range → conflict.
/// NOTE: loop-a uses a RANGE dep (^1.0.0) rather than exact (1.0.0) so that the range
/// intersection detects incompatibility — exact-vs-range has a known Intersect edge case.
Method TestScopedDepIncompatibleVersionConflictsWhenPhaseActive()
{
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "scoped-root", "2.0.0"), .found)
    do $$$AssertTrue(found, "Loaded scoped-root 2.0.0 module object.")

    // With test phase: scoped-b's loop-c ^2.0.0 and loop-b's loop-c 1.0.0 both active → conflict
    set sc = mod.BuildDependencyGraph(.graph, , , , $listbuild("test"))
    do $$$AssertStatusNotOK(sc, "BuildDependencyGraph() fails when test phase activates conflicting scoped dep.")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "loop-c", "Error message names loop-c as the conflict.")
}

/// When a scoped dependency is included, its own production sub-dependencies are transitively
/// included in the graph. When the scope phase is inactive, neither the scoped dep nor its
/// sub-dependencies appear in the graph.
/// Test data: scoped-root 3.0.0 test-depends on loop-b ^1.0.0; loop-b prod-depends on loop-c 1.0.0.
Method TestNestedScopedDepTransitivelyIncluded()
{
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "scoped-root", "3.0.0"), .found)
    do $$$AssertTrue(found, "Loaded scoped-root 3.0.0 module object.")

    // Without test phase: loop-b (test-scoped) and loop-c (its transitive prod dep) both absent
    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeds without test phase.")
    do $$$AssertTrue('$data(graph("loop-b")), "loop-b absent when test phase inactive.")
    do $$$AssertTrue('$data(graph("loop-c")), "loop-c absent transitively when test phase inactive.")

    // With test phase: loop-b included (test scope), loop-c included as its transitive prod dep
    kill graph
    set sc = mod.BuildDependencyGraph(.graph, , , , $listbuild("test"))
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeds with test phase.")
    do $$$AssertTrue($data(graph("loop-b")), "loop-b in graph when test phase active.")
    do $$$AssertTrue($data(graph("loop-c")), "loop-c included transitively via test-scoped loop-b.")
}

/// The root module's active phase list filters sub-dependencies of scoped modules: a verify-scoped
/// sub-dependency of a test-scoped module is excluded when only the test phase is active, but
/// included when both test and verify are active.
/// Test data: scoped-root 4.0.0 test-depends on scoped-b ^2.0.0; scoped-b 2.0.0 has scoped-c
/// (test scope) and scoped-d (verify scope).
Method TestCheckNestedScopedFiltersSubDependencyPhases()
{
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "scoped-root", "4.0.0"), .found)
    do $$$AssertTrue(found, "Loaded scoped-root 4.0.0 module object.")

    // With test phase only, pCheckNestedScoped=1: scoped-b and scoped-c included; scoped-d (verify) excluded
    set sc = mod.BuildDependencyGraph(.graph, , , , $listbuild("test"), , , , , , , 1)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeds with test phase only.")
    do $$$AssertTrue($data(graph("scoped-b")), "scoped-b in graph (test scope active).")
    do $$$AssertTrue($data(graph("scoped-c")), "scoped-c in graph (scoped-b's test dep, test active).")
    do $$$AssertTrue('$data(graph("scoped-d")), "scoped-d absent (scoped-b's verify dep, verify inactive).")

    // With test+verify phases: scoped-d now also included
    kill graph
    set sc = mod.BuildDependencyGraph(.graph, , , , $listbuild("test", "verify"), , , , , , , 1)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeds with test+verify phases.")
    do $$$AssertTrue($data(graph("scoped-d")), "scoped-d in graph when verify phase active.")
}

// ===== Core resolution correctness =====

/// When a shared dependency is reached via multiple paths — whether sibling modules at the
/// same depth (same-level diamond) or the root module and a transitive chain at different
/// depths (multi-level diamond) — the shared module appears exactly once in the graph with
/// all constraint sources recorded and no version conflict when the ranges are compatible.
/// Test data:
///   Same-level: complex-root 1.0.0; complex-a and complex-b both require complex-c ^2.0.0
///   Multi-level: complex-root 4.0.0 directly requires complex-e ^3.0.0, and complex-a 1.0.0
///     also requires complex-e ^3.0.0 transitively via complex-c 2.0.0
Method TestSharedDependencyResolvedOnce()
{
    // Same-level diamond: complex-a (depth 1) and complex-b (depth 1) both require complex-c
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-root", "1.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-root 1.0.0 module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeded for complex-root 1.0.0.")

    do $$$AssertTrue($data(graph("complex-c")), "complex-c in graph.")
    set $listbuild(depth) = graph("complex-c")
    do $$$AssertEquals(depth, 2, "complex-c resolved at depth 2.")
    do $$$AssertTrue($data(graph("complex-c", "complex-a 1.0.0")), "complex-a 1.0.0 recorded as source for complex-c.")
    do $$$AssertTrue($data(graph("complex-c", "complex-b 1.0.0")), "complex-b 1.0.0 recorded as source for complex-c.")

    // Multi-level diamond: complex-root 4.0.0 directly requires complex-e ^3.0.0 (depth 1),
    // and complex-c 2.0.0 (reached via complex-a) also requires complex-e ^3.0.0 transitively.
    // Compatible constraints — graph build succeeds with both sources recorded for complex-e.
    kill graph
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-root", "4.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-root 4.0.0 module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeded for compatible multi-level diamond.")

    do $$$AssertTrue($data(graph("complex-e")), "complex-e in graph (required at root depth and transitively).")
    set $listbuild(, , version) = graph("complex-e")
    do $$$AssertEquals(version, "3.0.0", "complex-e resolved at version 3.0.0.")
    // BuildDependencyGraph removes the root module's own source entries from sub-arrays during
    // cleanup, so only the transitive source (complex-c 2.0.0) is present as a recorded source.
    do $$$AssertTrue($data(graph("complex-e", "complex-c 2.0.0")), "complex-c 2.0.0 recorded as transitive source for complex-e.")
}

/// Incompatible version constraints on a shared dependency — whether from sibling modules at
/// the same depth or from the root module conflicting with a transitive constraint at a deeper
/// depth — cause BuildDependencyGraph to throw a descriptive error naming the shared module
/// and at least one conflicting source.
/// Test data:
///   Same-level: complex-root 2.0.0; complex-a (^2.0.0) and complex-b 2.0.0 (^3.0.0) conflict on complex-c
///   Multi-level: complex-root 5.0.0 directly requires complex-e ^2.0.0; complex-c 2.0.0
///     transitively requires complex-e ^3.0.0 — constraints at different depths are incompatible
Method TestIncompatibleTransitiveConstraintsThrowDescriptiveError()
{
    // Same-level conflict: complex-a and complex-b are sibling deps both requiring complex-c
    // at incompatible ranges (^2.0.0 vs ^3.0.0)
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-root", "2.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-root 2.0.0 module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusNotOK(sc, "BuildDependencyGraph() fails for incompatible transitive constraints.")
    set errMsg = $system.Status.GetErrorText(sc)
    do $$$AssertTrue(errMsg [ "complex-c", "Error message names complex-c as the conflicting dependency.")
    do $$$AssertTrue((errMsg [ "complex-a") || (errMsg [ "complex-b"), "Error message names a constraint source.")

    // Multi-level conflict: complex-root 5.0.0 directly requires complex-e ^2.0.0 (depth 1),
    // while complex-a 1.0.0 → complex-c 2.0.0 transitively requires complex-e ^3.0.0 (depth 3).
    // The root-level constraint and the deep transitive constraint are incompatible.
    kill graph
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-root", "5.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-root 5.0.0 module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusNotOK(sc, "BuildDependencyGraph() fails for incompatible multi-level constraints.")
    set errMsg = $system.Status.GetErrorText(sc)
    do $$$AssertTrue(errMsg [ "complex-e", "Error message names complex-e as the conflicting dependency.")
    do $$$AssertTrue((errMsg [ "complex-root") || (errMsg [ "complex-c"), "Error message names a constraint source.")
}

/// A direct cyclic dependency (A→B→A) and an indirect 3-hop cycle (A→B→C→A) both cause
/// BuildDependencyGraph to throw an error that includes the cycle path in the message.
/// The indirect cycle verifies that detection works regardless of how many hops separate
/// the dependent from the module it cycles back to.
/// Test data:
///   2-hop: loop-root 2.0.0 → loop-b 2.0.0 → loop-root
///   3-hop: loop-root 3.0.0 → loop-b 3.0.0 → loop-c 3.0.0 → loop-root
Method TestCyclicDependencyThrows()
{
    // 2-hop cycle: loop-root 2.0.0 → loop-b 2.0.0 → loop-root
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "loop-root", "2.0.0"), .found)
    do $$$AssertTrue(found, "Loaded loop-root 2.0.0 module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusNotOK(sc, "BuildDependencyGraph() fails for 2-hop cyclic dependencies.")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "loop-root", "Error message mentions the cyclic module.")

    // 3-hop indirect cycle: loop-root 3.0.0 → loop-b 3.0.0 → loop-c 3.0.0 → loop-root.
    // The cycle is not detected until loop-c's sub-dependency on loop-root is classified,
    // at which point loop-root is already three levels up the traversal path.
    kill graph
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "loop-root", "3.0.0"), .found)
    do $$$AssertTrue(found, "Loaded loop-root 3.0.0 module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusNotOK(sc, "BuildDependencyGraph() fails for 3-hop indirect cyclic dependencies.")
    set err = $system.Status.GetErrorText(sc)
    do $$$AssertTrue(err [ "loop-root", "Error message includes the cycle-origin module (loop-root).")
    do $$$AssertTrue(err [ "loop-c", "Error message includes the module where the indirect cycle is detected (loop-c).")
}

/// When multiple versions of a fuzzy dependency satisfy the accumulated constraints,
/// BuildDependencyGraph selects the highest satisfying version available in the repository.
/// Test data: loop-root 1.0.0 requires loop-b ^1.0.0; repo has loop-b 1.0.0+snapshot (flat)
/// and loop-b 1.0.1 (versioned) — 1.0.1 should be selected as the highest.
Method TestFuzzyVersionSelectsHighestCompatibleMatch()
{
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "loop-root"), .found)
    do $$$AssertTrue(found, "Loaded loop-root 1.0.0 module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeded.")

    do $$$AssertTrue($data(graph("loop-b")), "loop-b in graph.")
    set $listbuild(, , version) = graph("loop-b")
    do $$$AssertEquals(version, "1.0.1", "loop-b resolved at highest compatible version 1.0.1.")
}

/// When a dependency is pinned to an exact version string (e.g., "1.0.0" not "^1.0.0"),
/// that exact version is recorded in the graph regardless of other available versions.
/// Test data: build-dependency-graph/loop-root; loop-root pins loop-c at exactly 1.0.0.
Method TestExactVersionPinnedInGraph()
{
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "loop-root"), .found)
    do $$$AssertTrue(found, "Loaded loop-root module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeded.")

    do $$$AssertTrue($data(graph("loop-c")), "loop-c in graph.")
    set $listbuild(, , version) = graph("loop-c")
    do $$$AssertEquals(version, "1.0.0", "loop-c resolved at exact version 1.0.0.")
}

// ===== Complex multi-level dependency tree =====
// All three cases below use the same module set under build-dependency-graph/:
//   complex-root, complex-a, complex-b, complex-c, complex-d, complex-e
// Topology (root 1.0.0 compatible case):
//   complex-root
//   ├── complex-a 1.0.0  (requires complex-c ^2.0.0, complex-d ^1.0.0)
//   │   ├── complex-c 2.0.0  (requires complex-e ^3.0.0)
//   │   │   └── complex-e 3.0.0  (leaf)          ← depth 3
//   │   └── complex-d 1.0.0  (leaf)               ← depth 2
//   └── complex-b 1.0.0  (requires complex-c ^2.0.0)
//       └── complex-c 2.0.0  (diamond, same range) ← deduped at depth 2

/// Builds the graph for complex-root 1.0.0, whose two direct dependencies both require
/// complex-c ^2.0.0 (compatible diamond). Verifies:
///   - complex-a, complex-b appear at depth 1
///   - complex-c, complex-d appear at depth 2; complex-c appears exactly once despite two paths
///   - complex-e appears at depth 3 as a deep transitive dependency
/// Test data: build-dependency-graph/ (complex-root 1.0.0).
Method TestComplexCompatibleDiamondBuildsCorrectly()
{
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-root", "1.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-root 1.0.0 module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusOK(sc, "BuildDependencyGraph() succeeded for compatible diamond.")

    set $listbuild(depth) = graph("complex-a")
    do $$$AssertEquals(depth, 1, "complex-a at depth 1.")
    set $listbuild(depth) = graph("complex-b")
    do $$$AssertEquals(depth, 1, "complex-b at depth 1.")
    set $listbuild(depth) = graph("complex-c")
    do $$$AssertEquals(depth, 2, "complex-c at depth 2.")
    set $listbuild(depth) = graph("complex-d")
    do $$$AssertEquals(depth, 2, "complex-d at depth 2.")
    set $listbuild(depth) = graph("complex-e")
    do $$$AssertEquals(depth, 3, "complex-e at depth 3.")
}

/// Builds the graph for complex-root 3.0.0, which directly requires complex-c ^3.0.0 in
/// addition to complex-a (which transitively requires complex-c ^2.0.0). The direct root
/// constraint ^3.0.0 and the transitive constraint ^2.0.0 are incompatible; verifies that the
/// conflict is detected and the error names both the root and complex-a as constraint sources.
/// Test data: build-dependency-graph/ (complex-root 3.0.0).
Method TestComplexRootDirectConflictsWithTransitiveDep()
{
    set mod = ##class(%IPM.Utils.Module).GetModuleObjectFromPath(..GetModuleDir(..#REPONAME, "complex-root", "3.0.0"), .found)
    do $$$AssertTrue(found, "Loaded complex-root 3.0.0 module object.")

    set sc = mod.BuildDependencyGraph(.graph)
    do $$$AssertStatusNotOK(sc, "BuildDependencyGraph() correctly fails when root directly conflicts with transitive constraint.")
    do $$$AssertTrue($system.Status.GetErrorText(sc) [ "complex-c", "Error message names complex-c as the conflicting dependency.")
}

/// Counts the number of times that BuildDependencyGraph() gets invoked on test modules' installation to catch regressions
Method TestBuildDependencyGraphCount()
{
    // Reset counter to track BuildDependencyGraph() number of calls
    kill ^CacheTemp.BuildDependencyGraph($job)

    // Open method definition
    set methodDef = ##class(%Dictionary.MethodDefinition).%OpenId("%IPM.Storage.Module||BuildDependencyGraph")

    // Save original implementation so we can restore it
    set ^CacheTemp.BuildDependencyGraph("orig", $job) = methodDef.Implementation.Read()

    // Build wrapped implementation
    set newImp = ##class(%Stream.TmpCharacter).%New()

    set sc = newImp.WriteLine(
        "    set ^CacheTemp.BuildDependencyGraph($job)=$increment(^CacheTemp.BuildDependencyGraph($job))"
    )
    do $$$AssertStatusOK(sc, "Wrote new line into BuildDependencyGraph() successfully.")

    // Rewind original and copy it
    do methodDef.Implementation.Rewind()
    while 'methodDef.Implementation.AtEnd {
        set sc = newImp.WriteLine(methodDef.Implementation.ReadLine())
        do $$$AssertStatusOK(sc, "Copied original line into new definition of BuildDependencyGraph() successfully.")
    }

    // Replace implementation
    set methodDef.Implementation = newImp
    set sc = methodDef.%Save()
    do $$$AssertStatusOK(sc, "Saved new method definition for BuildDependencyGraph() successfully.")

    // Recompile the class
    set sc = $system.OBJ.Compile("%IPM.Storage.Module", "cuk")
    do $$$AssertStatusOK(sc, "Compiled test definition of %IPM.Storage.Module successfully.")

    set sc = ##class(%IPM.Main).Shell("load " _ ..GetModuleDir(..#REPONAME, "loop-root") _ " -DIgnoreInstalled=1 -DUpdateSnapshots=1")
    do $$$AssertStatusOK(sc, "Loaded loop-root module via Shell.")

    do $$$AssertTrue($get(^CacheTemp.BuildDependencyGraph($job), 0) > 0)
    do $$$AssertTrue($get(^CacheTemp.BuildDependencyGraph($job), 0) < 4)

    set methodDef = ##class(%Dictionary.MethodDefinition).%OpenId("%IPM.Storage.Module||BuildDependencyGraph")

    if $data(^CacheTemp.BuildDependencyGraph("orig", $job)) {
        set imp = ##class(%Stream.TmpCharacter).%New()
        set sc = imp.Write(^CacheTemp.BuildDependencyGraph("orig", $job))
        do $$$AssertStatusOK(sc, "Wrote back original method definition of BuildDependencyGraph() successfully.")
        set methodDef.Implementation = imp
        set sc = methodDef.%Save()
        do $$$AssertStatusOK(sc, "Saved original method definition of BuildDependencyGraph() successfully.")
        set sc = $system.OBJ.Compile("%IPM.Storage.Module", "cuk")
        do $$$AssertStatusOK(sc, "Compiled original definition of %IPM.Storage.Module successfully.")
    }

    kill ^CacheTemp.BuildDependencyGraph($job)
}

}
