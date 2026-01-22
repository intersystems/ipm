# Implementation Plan: `-force-dependencies` Flag for `update` Command

## Abstract

This plan introduces a `-force-dependencies` (alias `-force-deps`) flag for IPM's `update` command to solve **diamond dependency** and **shared dependency** conflicts that block standard module updates.

**The Problem:** When a module has dependencies shared with other installed modules (diamond pattern), upgrading the parent module fails because the shared dependency must satisfy multiple conflicting version constraints simultaneously. The only current workaround is to uninstall and reinstall everything.

**The Solution:** The `-force-dependencies` flag treats the update like a fresh install—resolving all dependencies from scratch (`IgnoreInstalled=1`) rather than trying to preserve old versions. This guarantees reproducible resolution and correct module ordering. All modules update together to compatible versions in the existing bottom-up order with update steps running as modules load—no additional code changes needed.

**Scope:**
- **Phase 1 (MVP)**: Add flag, clean install resolution, orphan detection, transactional semantics
- **Phase 2 (Future)**: Dry-run diagnostics, Level 2 namespace resolution, lock file sync

**Known Limitation:** Sibling modules incompatible with new dependencies still cause conflicts. Three paths forward documented: manual uninstall, explicit scope selection, or future Level 2 aggressive resolution.

## Problem Statement

Updating a module in a diamond or shared dependency pattern fails with a dependency resolution error, forcing users to uninstall and reinstall entire dependency trees.

**Example Scenario: Diamond Dependency Pattern**

Currently installed (v1.0.0 versions):
```
      parent-module v1.0.0
         /            \
       /                \
    dep-a v1.0.0      dep-b v1.0.0
       \                /
         \            /
       dep-base v1.0.0
```

Available upgrade (v1.1.0 versions):
```
      parent-module v1.1.0
         /            \
       /                \
    dep-a v1.1.0      dep-b v1.1.0
       \                /
         \            /
       dep-base v1.1.0
```

**Current behavior when running `update parent-module 1.1.0`:**
```
ERROR! Requested version (dep-base 1.1.0) does not satisfy the requirements
of other modules installed in the current namespace (dep-a, dep-b: 1.0.0).
```

**Root cause:** Resolution sees v1.0.0 versions of dep-a and dep-b still installed. When it tries to upgrade parent-module to v1.1.0, the new version requires dep-a v1.1.0 and dep-b v1.1.0, which both depend on dep-base v1.1.0. But the old dep-a v1.0.0 and dep-b v1.0.0 (still installed) depend on dep-base v1.0.0. Resolution cannot satisfy both: dep-base cannot be both v1.0.0 and v1.1.0 simultaneously.

**Current workaround:** Uninstall all four modules, then `install parent-module 1.1.0` to resolve everything fresh. Painful and error-prone for large dependency trees.

**Desired behavior:** `update parent-module -force-dependencies 1.1.0` resolves all dependencies as if from a clean install, pulling parent v1.1.0, dep-a v1.1.0, dep-b v1.1.0, and dep-base v1.1.0, then loads/compiles in bottom-up order ensuring no conflicts.

## Solution Overview

Add a `-force-dependencies` flag (alias `-force-deps`) to the `update` command that enables **cascading dependency resolution and updates**. When enabled:

1. Resolve target module to specified version (or latest if unspecified)
2. Treat as a clean install scenario: resolve all dependencies as if starting from scratch (`IgnoreInstalled=1`)
3. Update modules in installation order (bottom-up: dependencies before dependents)
4. Load and compile all code, running update steps as modules load (existing behavior)
5. All updates respect semantic versioning constraints and existing compatibility rules
6. Wrap the entire operation in a transaction for all-or-nothing semantics

## How It Works

**Core Mechanism:** When `-force-dependencies` is specified, the update command:
1. Resolves dependencies as if performing a fresh install (`IgnoreInstalled=1`)
2. Determines all modules that must be updated to compatible versions
3. Updates them in correct order (dependencies before dependents)
4. Loads and compiles all code, running update steps as each module loads (existing behavior)
5. Wraps the entire operation in a transaction for all-or-nothing semantics

**Key Design Decision:**

- **Clean install resolution**: Treats the update like `install parent-module v1.1.0` would—resolving from scratch rather than trying to preserve old versions. This guarantees reproducibility and correctness.


## Implementation Details

### 1. Command Definition (Main.cls - XData Commands)

**Current update command definition (lines 145-169):**
```xml
<command name="update" dataPrefix="D">
    <summary>Updates a module to a newer version.</summary>
    <!-- ... existing parameters ... -->
</command>
```

**Add modifier:**
```xml
<modifier name="force-dependencies" aliases="force-deps" dataAlias="ForceDependenciesUpdate" dataValue="1"
  description="Updates the target module and forces recursive resolution/updates of all dependencies to compatible versions, as if performing a fresh install of the target version." />
```

### 2. Update Method Enhancement (Main.cls - lines 4014-4049)

**Current implementation flow:**
```
Update() method
  ├─ Validates module exists
  ├─ Sets up pCommandInfo("data","Update") = 1
  └─ Calls Install() or Load()
```

**Enhanced implementation:**
```
Update() method
  ├─ Validate module exists
  ├─ Check for -force-dependencies flag: pCommandInfo("data","ForceDependenciesUpdate")
  ├─ If -force-dependencies:
  │   ├─ Set pCommandInfo("data","IgnoreInstalled") = 1
  │   │   [Forces clean-slate dependency resolution]
  │   ├─ Call Install() (leverages existing resolution and update step logic)
  │   ├─ After Install() completes:
  │   │   ├─ Detect orphaned modules
  │   │   └─ Display list of orphans to user
  │   └─ Wrap entire operation in transaction (all-or-nothing)
    └─ Else (normal update):
      └─ Current behavior unchanged
```

### 3. Dependency Resolution (Leverage Existing)

The existing `Install()` method → `LoadDependencies()` → `BuildDependencyGraph()` chain already handles:
- Fuzzy version matching via semantic versioning
- Bottom-up installation order (least dependent → most dependent)
- Conflict detection

**What we change:**
- Set `IgnoreInstalled=1` in pParams to force re-resolution of all dependencies
- This treats the update as a fresh install scenario
- Dependencies resolve to most recent compatible versions, not reusing installed versions

### 4. Update Steps (Leverage Existing Behavior)

Update steps run as modules load in dependency order (existing behavior). Since `-force-dependencies` updates in bottom-up order (dependencies before dependents), update steps naturally execute with the correct dependencies already at new versions:

**Execution order:**
```
For each module in resolved set (bottom-up):
  1. Load
  2. Compile
  3. Activate
  4. ApplyUpdateSteps ← runs with dependencies already at new versions
```

This works correctly because:
- Dependencies load and update steps run before dependents
- When Module A's update step runs, Module B (its dependency) is already at new version
- No special code changes needed; leverages existing ordering

### 5. Safety & Transparency

**Transactional semantics:**
- Entire operation wrapped in database transaction
- Any failure rolls back all changes
- All-or-nothing guarantee ensures namespace consistency

**Conflict detection:**
- Validates resolution against all installed modules
- Fails gracefully if incompatible versions are required
- Informs user exactly which modules conflict

**User communication:**
- Verbose mode displays:
  - Target module and desired version
  - Complete list of modules being updated and their versions
  - Installation order (dependencies first)
  - After completion: orphaned modules detected

**Orphan detection:**
- After successful update, identifies modules no longer needed
- Displays list for user review
- No automatic deletion (user decides)

## Implementation Phases

### Phase 1: Core Flag Support (MVP)
1. Add `-force-dependencies` modifier (alias `-force-deps`) to update command XData
2. Enhance `Update()` method to detect flag and set `IgnoreInstalled=1`
3. Leverage existing `Install()` with modified params
4. Add orphan detection and display
5. Wrap in transaction for all-or-nothing semantics
6. **Result:** Target module and dependencies update to compatible versions in correct order
7. **Timeline:** Single focused change

### Phase 2: Diagnostics & Future Enhancements (Not in scope)
- **Dry-run capability**: Preview what would be updated without executing
- **Level 2 namespace resolution**: Auto-upgrade sibling modules when necessary
- **Lock file regeneration**: Update manifests to stay in sync
- **Enhanced logging**: Detailed audit trail and plan persistence

## Dry-Run Support (Design-ready, not in scope for initial change)

**Goal:** Preview which modules would be updated (and to which versions) from multiple resolution perspectives, helping users understand the impact and choose the best approach for their situation.

**Proposed behavior:**
- New modifier (future): `-dry-run` (alias `-dr`), usable with any update flags.
- Perform full dependency resolution **without executing any lifecycle operations** (no load/compile/activate/applyupdatesteps).
- Support multiple resolution perspectives:
  - **Regular update** (`update -dry-run parent-module 1.1.0`): Show what a standard update would do
  - **Force-deps update** (`update -force-deps -dry-run parent-module 1.1.0`): Show what clean install resolution would do
  - **With sibling handling** (future, e.g., `update -force-level-2 -dry-run parent-module 1.1.0`): Show what namespace-aware resolution would do
- Produce a plan object containing: target module/version, resolved modules with from→to versions, install order, any conflicts detected, and orphan projections.
- Output the plan to the user (stdout) in human-readable form, highlighting differences between perspectives if multiple are requested.
- Persist the plan (e.g., in history log or named plan store) for later reference or execution.

**Key benefit:** Users can run dry-run with different flags to compare outcomes and choose the best approach for their situation. For example:
  - Run `update -dry-run parent 1.1.0` (regular) → see it fails due to sibling conflict
  - Run `update -force-deps -dry-run parent 1.1.0` (clean install) → see the full cascade
  - Decide which path forward makes sense for their environment

**Data considerations:**
- Include a checksum of repository metadata used for resolution so stale plans can be detected.
- Include timestamp, namespace, and user so plan provenance is clear.
- Store enough to rerun: resolved module list with explicit versions and sources.
- Record which resolution perspective was used (regular vs. force-deps vs. sibling-handling).

**Execution considerations (future follow-up):**
- Provide a way to execute a saved plan (e.g., `update -force-deps -plan <id>`), revalidating checksum/freshness before running.
- If repos have changed, prompt or fail with a clear message.

## History Logging Considerations

- Reuse the existing history log mechanism to record:
  - Invocation (command string), target module/version, and flags (`-force-deps`, future `-dry-run`).
  - Resolved plan: modules and versions to be updated (from→to), and the planned order.
  - For dry-run: mark as non-executed; store the plan for later reference.
  - For execution: log each lifecycle phase outcome; on failure, log the status before rollback.
- Ensure history logging occurs even in dry-run (as a “plan recorded” entry) but without side effects.
- Verify that wrapping in a transaction does not suppress history entries; if history writes must be outside the transaction, record plan metadata before starting mutating work.

## Limitations of Current Design

### Sibling Module Conflicts

**Problem:** Phase 1 resolves only the target module's dependency tree. If sibling/peer modules are incompatible with the new dependency versions, resolution fails.

**Example: Shared Dependency with Incompatible Sibling**

Currently installed (v1.0.0 versions):
```
parent-module v1.0.0    unrelated-module v1.0.0
       /    \                    |
      /      \                   |
   dep-a    dep-b                |
     v1.0.0  v1.0.0              |
       \      /                  |
        \    /                   |
       dep-base v1.0.0 <---------+
```

Target upgrade (`update parent-module -force-deps 1.1.0`):
```
parent-module v1.1.0    unrelated-module v1.0.0
       /    \                    |
      /      \                   |
   dep-a    dep-b                |
     v1.1.0  v1.1.0              |
       \      /                  |
        \    /                   |
       dep-base v1.1.0 <---------+
          (conflict!)
  (unrelated-module requires v1.0.0)

  ❌ RESOLUTION FAILS
     ERROR: dep-base v1.1.0 does not satisfy
             unrelated-module (requires v1.0.0)
```

**Ideal End State** (what Level 2 could achieve):
```
parent-module v1.1.0    unrelated-module v1.1.0
       /    \                    |
      /      \                   |
   dep-a    dep-b                |
     v1.1.0  v1.1.0              |
       \      /                  |
        \    /                   |
       dep-base v1.1.0 <---------+

  ✅ RESOLVED
     All modules at v1.1.0, all constraints satisfied
```

**Three Paths Forward:**

1. **Level 2: Namespace Resolution** (future enhancement, `-force-level-2` or `-force-all`): Re-resolve entire namespace, automatically updating all affected siblings to compatible versions. Higher risk, solves the problem completely, but could trigger cascading updates across many modules.

2. **Explicit Scope Selection** (future enhancement, `-force-deps parent,dep-a,dep-b,unrelated-module`): User explicitly specifies which modules to include in the update. User-controlled and safer (only named modules update), but more verbose invocation.

3. **Manual Resolution** (current best practice): User uninstalls the conflicting sibling module first, then runs `update -force-deps parent-module 1.1.0` to resolve the target and its dependencies. After completion, the user can re-install the sibling module if needed. Safest but most manual.

**Diagnostic Tool: Dry-Run**

Phase 2 will introduce a `--dry-run` modifier (usable with `-force-deps`) to preview what would be updated without executing. This helps users understand dependency propagation and conflicts before committing, informing their choice of which path forward to take.

**Current Recommendation:** Proceed with Phase 1. Document the limitation clearly. When users encounter sibling conflicts, guide them to use manual resolution (uninstall sibling, update target, optionally reinstall sibling). Phase 2 dry-run will help users preview and understand the propagation impact.

## Future Considerations (Not in current scope)

- **Orphan cleanup command**: A dedicated `clean`-like command to remove orphaned modules after updates; for now, only list orphans.
- **Dry-run execution flow**: Command to execute a previously saved plan (`-plan <id>`), with freshness checks and user confirmation.
- **Plan freshness validation**: Repo metadata checksum/tag revalidation before executing a saved plan.
- **Lock file regeneration**: Rebuild lock files after `-force-deps` updates to keep manifests consistent.
- **Scoped dependencies coverage**: Explicit tests/handling for test/dev/runtime scopes in resolution and execution.
- **Global/namespace-mapped modules**: Validation and safeguards when globals are shared across namespaces.
- **Cross-namespace updates**: Explicitly disallow or clearly signal; out of scope for now.
- **Dry-run output UX**: Rich, human-readable plan with reasons for each upgrade, and machine-readable plan blob.
- **Telemetry/logging depth**: More detailed audit trail or opt-in telemetry for large upgrades.

## Files to Modify

| File | Changes | Priority |
|------|---------|----------|
| `/src/cls/IPM/Main.cls` | Add `-force-dependencies` modifier to update XData; enhance `Update()` method | P0 |
| `/src/cls/IPM/Utils/Module.cls` | Add `GetDependentModules()`, `FindCompatibleVersion()` methods | P1 |
| `/tests/integration_tests/Test/PM/Integration/Update.cls` | Add test cases for cascading updates | P0 |
| `/src/cls/IPM/General/LockFile.cls` | Update dependent module manifests (via existing APIs) | P1 |

## Testing Strategy

### Unit Tests
```objectscript
Method TestUpdateForceDepsBasic()
  // Update single module with -force-deps, verify dependencies resolve

Method TestUpdateForceDepsCascade()
  // Update parent module, verify child modules also update

Method TestUpdateForceDepsIncompatible()
  // Attempt update that would break compatibility, verify error

Method TestUpdateForceDepsNoFlag()
  // Update without -force-deps should fail in same scenario
```

### Integration Tests (in Update.cls)
```objectscript
// Setup: Install parent v1.0.0, child-a v1.0.0, child-b v1.0.0
set sc = ##class(%IPM.Main).Shell("install parent-module 1.0.0")
set sc = ##class(%IPM.Main).Shell("install module-a 1.0.0")
set sc = ##class(%IPM.Main).Shell("install module-b 1.0.0")

// Test: Update with -force-deps
set sc = ##class(%IPM.Main).Shell("update -force-dependencies parent-module 1.1.0")

// Verify: All three should be at 1.1.0
do $$$AssertEquals(installedVersion("parent-module"), "1.1.0")
do $$$AssertEquals(installedVersion("module-a"), "1.1.0")
do $$$AssertEquals(installedVersion("module-b"), "1.1.0")
```

## Backward Compatibility

✅ **Fully backward compatible:**
- `-force-dependencies` flag is optional; omitting it preserves existing behavior
- No breaking changes to existing APIs
- Existing `update` command works unchanged
- Existing test cases continue to pass

## Success Criteria

1. ✅ `-force-dependencies` flag (alias `-force-deps`) is recognized by the parser
2. ✅ `update -force-dependencies module-name` updates both module and compatible dependencies
3. ✅ Dependent modules are updated to maintain compatibility
4. ✅ All operations are logged in verbose mode
5. ✅ Rollback occurs on any error
6. ✅ No breaking changes to existing behavior
7. ✅ New integration tests pass

## Risks & Mitigation

| Risk | Mitigation |
|------|-----------|
| Infinite loop in dependent updates | Maintain visited set; limit recursion depth |
| Unintended version downgrades | Verify all versions satisfy constraints before updating |
| Cascading breaks dependencies | Rollback entire transaction on failure |
| User confusion about what gets updated | Verbose output + dry-run capability |
| Performance degradation | Cache dependency graph results; minimize re-builds |

## Command Usage Examples

```bash
# Update parent-module and all dependencies to v1.1.0 (clean resolution)
zpm "update -force-dependencies parent-module 1.1.0"

# Using the short alias
zpm "update -force-deps parent-module 1.1.0"

# Update parent-module to latest, resolving dependencies as fresh
zpm "update -force-deps -v parent-module"

# Same but with lock file creation
zpm "update -force-deps parent-module 1.1.0 -create-lockfile"

# Verbose output showing resolution plan and orphans
zpm "update -force-deps -v parent-module 1.1.0"

# Normal update (without -force-dependencies) - maintains existing behavior
zpm "update parent-module 1.1.0"
```

**Example Output (verbose mode):**
```
Updating parent-module from 1.0.0 to 1.1.0 (-force-deps mode)...

Building dependency graph (clean install scenario)...
Done.

Resolved modules to update (in installation order):
  1. logger 1.0.0 → 1.1.0
  2. config-system 1.0.0 → 1.1.0
  3. module-a 1.0.0 → 1.1.0
  4. module-b 1.0.0 → 1.1.0
  5. parent-module 1.0.0 → 1.1.0

Loading and compiling...
  logger 1.1.0 ... compiled
  config-system 1.1.0 ... compiled
  module-a 1.1.0 ... compiled
  module-b 1.1.0 ... compiled
  parent-module 1.1.0 ... compiled

Running update steps...
  logger (v1.0.0 → v1.1.0) ... completed
  config-system (v1.0.0 → v1.1.0) ... completed
  module-a (v1.0.0 → v1.1.0) ... completed
  module-b (v1.0.0 → v1.1.0) ... completed
  parent-module (v1.0.0 → v1.1.0) ... completed

Update complete.

Note: The following modules are no longer depended on:
  - old-logger 1.0.0
  - legacy-config 1.0.0

```

## Documentation Updates

1. Update help text for `update` command to describe `-force-dependencies`/`-force-deps` behavior
2. Add examples to README.md showing cascading updates
3. Document the cascading algorithm in CONTRIBUTING.md
4. Add troubleshooting section for common issues

---

## Appendix: Design Decision Rationale

### Resolution Approach: Why Clean Install?

When updating with `-force-dependencies`, there are two main approaches to dependency resolution:

**Option A: Clean Install** (`IgnoreInstalled=1`)
- Resolve target module's entire dependency tree from scratch, ignoring what's currently installed
- Pulls latest compatible versions for all dependencies within the tree
- More aggressive: if parent v1.5.0 needs dep >=1.2.0 and dep v1.5.0 is available, it pulls v1.5.0 even if dep v1.2.0 is already installed
- Deterministic and reproducible: always produces the same result across systems

**Option B: Preserve Installed** (`IgnoreInstalled=0`)
- Keep currently installed versions whenever they satisfy constraints
- Only pull newer versions when absolutely required by new constraints
- More conservative: keeps dep v1.2.0 if it already satisfies the >=1.2.0 requirement, avoiding unnecessary upgrades
- Trade-off: less deterministic and reproducible as behavior depends on the state of the current system

**Both approaches solve the diamond dependency problem**, because the diamond dependencies themselves are part of the required constraints and must be updated to compatible versions. The difference is scope: Clean Install upgrades to latest compatible; Preserve Installed upgrades only when currently installed versions are incompatible.

**Decision: Clean Install** because:
- It's simpler to reason about and test (no dependency on current system state)
- Provides reproducibility across systems and over time
- Consistent with semantic versioning intent: minor/patch versions are safe and should be adopted
- Alignment with `install` command behavior: users expect consistent resolution

**Trade-off Accepted:** Unnecessary upgrades within the dependency tree (dep v1.2.0 → v1.5.0 even if v1.2.0 works). This is acceptable because clean install semantics are simpler and the upgrades are within semantic versioning bounds, so they should be compatible.

### Update Steps Timing: Why As Modules Load?

Update steps can run at two different times:

**Option A: As Modules Load** (per-module, in dependency order)
- Runs immediately after each module is loaded and compiled, in bottom-up dependency order
- This is the current behavior for all updates
- If Module A depends on Module B, Module B's update step runs before Module A's
- Pros:
  - No code changes required; leverages existing behavior
  - Early feedback; work proceeds incrementally as modules load
  - Natural lifecycle position within module loading
  - If Module A's update step needs Module B's new code, it's guaranteed to be present
- Cons:
  - None identified for `-force-deps` scenario

**Option B: After All Modules Loaded** (deferred, after all code present)
- Runs only after all target modules are loaded and compiled
- Requires code changes to defer update steps
- Pros:
  - Clear phase separation: all loading, then all migrations
  - Handles incompletely labeled module dependency trees where modules depend on siblings or unrelated modules without a dependency declaration
- Cons:
  - Additional complexity and code changes
  - Longer wait before update steps start

**Decision: As Modules Load (No deferred execution needed)** because:
- The current approach already works correctly for `-force-deps`
- Dependency ordering guarantees that dependencies update before dependents
- No code changes required; minimal risk
- Update steps in dependency order ensure all dependencies are at new versions before dependent modules' steps run
- Principle: keep changes minimal and leverage existing infrastructure

**Rationale:** The diamond pattern doesn't require deferring update steps. The clean install resolution ensures correct ordering (bottom-up), and update steps run in the same order, so all dependencies are present when a dependent module's update step runs.

