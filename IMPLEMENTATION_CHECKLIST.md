# Implementation Checklist: `-force-dependencies` Flag

## Phase 1: Core Flag Support

### 1.1 Command Definition
- [ ] Add `-force-dependencies` modifier (alias `-force-deps`) to `update` command in Main.cls XData (line ~157)
  - Modifier: `force-dependencies` with alias `force-deps`
  - Data alias: `ForceDependenciesUpdate` with value `1`
  - Description: "Updates the target module and forces recursive resolution/updates of all dependencies..."

### 1.2 Update() Method Enhancement (Main.cls ~line 4014)
- [ ] Check for `ForceDependenciesUpdate` flag in `pCommandInfo("data","ForceDependenciesUpdate")`
- [ ] If flag is set:
  - [ ] Set `pCommandInfo("data","IgnoreInstalled") = 1`
  - [ ] Wrap `Install()` call in transaction (tstart/tcommit/trollback)
- [ ] Keep existing behavior unchanged when flag is not set

### 1.3 Orphan Detection (New)
- [ ] After successful Install(), call orphan detection
- [ ] Display list of orphaned modules to user

### 1.4 Testing Phase 1
- [ ] Create test case: `TestUpdateForceDepsBasic`
  - Install parent v1.0.0, dep-a v1.0.0, dep-b v1.0.0
  - Update parent -force-deps to v1.1.0
  - Verify all three are at v1.1.0

- [ ] Create test case: `TestUpdateForceDepsDiamond`
  - Recreate exact diamond pattern from problem statement:
    - parent v1.0.0 → dep-a v1.0.0 → dep-base v1.0.0
    - parent v1.0.0 → dep-b v1.0.0 → dep-base v1.0.0 (shared)
  - Standard update parent to v1.1.0 fails with error about dep-base constraint
  - Update parent -force-deps to v1.1.0 succeeds, pulling all v1.1.0 versions

- [ ] ⊘ **SKIPPED** Create test case: `TestUpdateForceDepsWithSibling`
  - Install parent v1.0.0, sibling v1.0.0 (both depend on child v1.0.0)
  - Parent v1.1.0 needs child v1.1.0, but sibling v1.0.0 still requires child v1.0.0
  - Demonstrates known limitation: sibling constraint blocks resolution
  - This will fail until Phase 2 Level 2 namespace resolution implemented

- [ ] ⊘ **SKIPPED** Create test case: `TestUpdateForceDepsDiamondWithSibling`
  - Combines diamond and sibling patterns:
    - parent v1.0.0 → dep-a v1.0.0 → dep-base v1.0.0
    - parent v1.0.0 → dep-b v1.0.0 → dep-base v1.0.0 (shared)
    - unrelated-sibling v1.0.0 → dep-base v1.0.0 (independent)
  - Update parent -force-deps to v1.1.0 pulls dep-base v1.1.0
  - Sibling v1.0.0 still requires dep-base v1.0.0, causing conflict
  - Demonstrates why sibling conflicts require manual intervention
  - This will fail until Phase 2 Level 2 implementation

- [ ] Create test case: `TestUpdateNormalUnaffected`
  - Verify `update` (without -force-deps) still works as before
  - Standard update should not use IgnoreInstalled=1 behavior

---

## Implementation Notes

### Update Step Execution
Update steps run as each module loads (existing behavior). Since modules load in dependency order, update steps automatically execute in the correct order - dependencies are already at their new versions when a dependent module's update step runs. This approach:
- Leverages existing dependency resolution
- Requires no code changes
- Works for both normal updates and `-force-deps` scenarios
- Assumes dependencies are correctly declared (best practice anyway)

No deferred update step mechanism is needed.

---

## Implementation Details

### Files to Modify

1. **src/cls/IPM/Main.cls**
   - Update XData Commands: Add `-force-dependencies` modifier (~line 157)
   - Update() method: Detect flag, set params, wrap in transaction (~line 4014)
   - Add orphan detection and reporting after successful update

2. **tests/integration_tests/Test/PM/Integration/Update.cls**
   - Add test cases (see Testing sections above)

### Key Parameters Flow

```
User: zpm "update -force-deps parent 1.1.0"
        ↓
Parser: pCommandInfo("data","ForceDependenciesUpdate") = 1
        ↓
Update(): Check flag
        ├─ Set pCommandInfo("data","IgnoreInstalled") = 1
        └─ Call Install() with params
        ↓
Install(): Uses modified params
        └─ Calls LoadDependencies() with IgnoreInstalled=1
        ↓
LoadDependencies(): Does clean resolution
        ├─ BuildDependencyGraph() with IgnoreInstalled
        ├─ Constructs ordered dependency list
        └─ Loads modules bottom-up
        ↓
Module loading: Update steps run as modules load (dependency order)
        ↓
Orphan detection: Display orphaned modules
        ↓
Commit transaction
```

### Transaction Boundaries

```objectscript
tstart

try {
    // Set up params
    set pCommandInfo("data","IgnoreInstalled") = 1

    // Resolve and load dependencies (update steps run as modules load)
    do ..Install(.pCommandInfo, log)

    // Detect orphans
    do ..DetectOrphans(.orphanList)

    // Commit on success
    tcommit

} catch e {
    trollback
    throw e
}
```

### Verbose Output Structure

When `-v` flag is used:
1. Show target module and desired version
2. Show dependency resolution plan (modules to update)
3. Show loading/compilation progress
4. Show update step execution progress
5. Show final list of orphaned modules

---

## Success Criteria

- [ ] `-force-dependencies` flag is recognized by parser
- [ ] `update -force-deps module v1.1.0` updates target + dependencies
- [ ] Updates happen in correct order (bottom-up)
- [ ] All code loaded and compiled before update steps run
- [ ] Transactional semantics: all-or-nothing
- [ ] Orphan detection works and is displayed
- [ ] No breaking changes to existing `update` command
- [ ] Integration tests pass
- [ ] Verbose output is clear and helpful

---

## Known Limitations / Future Work

1. **Lock files** - Currently ignored; should be regenerated in future enhancement
2. **Dry-run** - Not implemented; would be nice for preview mode
3. **Scoped dependencies** - Should work but not explicitly tested yet
4. **Global modules** - Assumed to work via existing resolution; needs validation
5. **Cross-namespace updates** - Not in scope; resolution should prevent these

