## Description

Closes #536.

A filesystem repository's cache of available modules was built once, when the repository was configured, and never again. Adding, editing, or deleting a `module.xml` under the root had no effect until the operator re-ran `repo -fs -path ...` to reconfigure it, so `install` and `repo -list-modules` served stale results indefinitely.

This PR makes the cache self-maintaining. It is rebuilt automatically before dependency resolution on `install`, on demand via a new `repo -rebuild-cache` flag, and still on configure. To make a rebuild cheap enough to run that often, the cache tracks a content hash per `module.xml` so unchanged files are skipped, and defers extracting the manifest until something needs it.

### Architecture

`%IPM.Repo.Filesystem.Cache` holds one row per `module.xml` found under the root. Three changes to that row:

- `ContentHash`: SHA-1 of the `module.xml` the row was built from. A rebuild compares hashes and re-parses only what changed. Content rather than mtime, which is unreliable across container bind mounts.
- `ManifestLoaded` / `Manifest`: a rebuild parses only the module's name and version. The manifest is extracted on first request.
- `SubDirectoryHash`: SHA-1 of `SubDirectory`, used as the unique index key in place of the path itself.

### When the cache is built

| Trigger | Scope | Purge |
|---|---|---|
| `repo -fs -path ...` (configure) | the configured repository | yes |
| `repo -n <repo> -rebuild-cache` | that repository | yes |
| `install <module>`, before dependency resolution | every enabled filesystem repository | no |
| `install <repo>/<module>` | just `<repo>`, if it is a filesystem repository | no |
| `%IPM.General.TempLocalRepoManager` | its temporary repository | yes |

`reinstall` and `update` route through the same `Install` entry point, so they get the rebuild too.

A purge blanks every row's `ContentHash`, forcing a re-parse of every manifest. A non-purge rebuild costs one hash per file plus a parse of whatever changed, which is what makes it viable on the `install` path. A root that is not currently reachable is skipped rather than failing the install.

### Cache rebuild pipeline (`BuildCache`)

1. Refuse to scan a root that does not exist, so an unmounted share does not look like a repository whose modules were all deleted.
2. Lock the repository row, so two concurrent rebuilds cannot each compute a visited set and delete the other's new entries.
3. On purge, blank every row's `ContentHash`.
4. Preload the existing rows into an array keyed by `SubDirectoryHash`, so an unchanged file costs a hash comparison instead of an object open.
5. Walk the tree via `%IPM.Utils.File.WalkDirectories`, hashing each `module.xml` as it goes.
6. Per file: reuse the row outright if the hash matches, otherwise parse name and version and update the row.
7. Delete rows whose files were not seen by the walk.
8. Stamp `CacheLastRebuilt` and save.

### Resolving a module (`GetModuleManifest`)

1. `RootNameVersionOpenValidated` opens the row and re-hashes the file on disk. A mismatch re-parses name and version in place and drops the cached manifest.
2. Because a re-parse can change name or version, the entry is re-checked through the index. If it no longer describes the module that was asked for, the lookup fails rather than installing something else.
3. If `ManifestLoaded` is 0, `LoadManifestForCacheEntry` runs the full XSLT extraction and saves it.

### Notable implementation details

**`SubDirectoryHash` as the index key.** The unique index keyed on `SubDirectory` directly, which caps out on long paths and, under `%String`'s SQLUPPER collation, treats `mods/Foo` and `mods/foo` as one entry when they are two directories. The SHA-1 gives a fixed 40-character subscript with exact-case semantics. Rows written before the property existed store an empty hash and would all collide on one slot, so `%OnBeforeBuildIndices` deletes them; a cache row is derived data and the next build re-creates it.

**Purge blanks hashes instead of deleting rows.** A reader that opens the repository mid-rebuild sees the existing entries rather than an empty repository.

**Metadata-only parse.** `GetModuleStreamFromFile` takes a `pMetadataOnly` flag that runs only `MetadataExtractionTransform` and skips `ModuleDocumentTransform`, so a rebuild does one XSLT pass per changed file instead of two. The full path buffers the file into a stream so both transforms share one read.

**Directory walking is shared with `sync`.** `%IPM.Utils.File.WalkDirectories` (embedded Python `os.walk`, with a SQL breadth-first fallback that warns when it is used) now serves both the cache scan and sync's change detection, replacing `Definition.ScanDirectory`. `%IPM.Storage.FileHash.NormalizePath` moved to `%IPM.Utils.File` alongside it.

**Auto-depth detection removed.** Pinning the search depth for a repository with a uniform layout is still supported, by passing `-depth` and having it kept. What is gone is inferring that depth during the initial scan, which never did the job:

- It could not fire for the case it was for. The scan's guard was `if (pDepth > pMaxDepth)`, where `pDepth` is the repository's `Depth`. Without `-depth` that is 0, so the guard is `0 > 0`, the detected depth stays 0, and `OnConfigure` skips the assignment. A repository left at the unlimited default never had a depth inferred for it.
- Where it did fire, `-depth` had already been given, so all it could do is rewrite the operator's own value downward. It was not even a maximum: the guard compares the requested depth to the accumulator rather than to the depth of the file just found, so what got saved was the depth of whichever file happened to be visited while the accumulator was still below the requested depth. A repository configured `-depth 3` could be saved as `Depth = 1`, after which nothing at level 2 or 3 was discovered.

**`repo -n <repo> -list-modules` reports cache age.** Filesystem repositories append `CacheLastRebuilt` and a pointer to `-rebuild-cache`.

**`%Clean` kills `CacheI` and `CacheS`.** It killed only `CacheD`, leaving index entries pointing at deleted rows and orphaning the manifest streams.

## Testing

Integration tests in `Test.PM.Integration.FilesystemRepo`, running against a working copy of `tests/_data/fs-cache-test` since several tests edit `module.xml` in place:

- Cache contents after a build; manifests unloaded until accessed.
- Edited `module.xml` is detected by hash and re-parsed; a byte-identical touch is not.
- An in-place `<Version>` bump does not let a lookup of the old version return the new module.
- Two directories claiming the same name and version fail the validated open rather than returning an unsaved row.
- An unparseable `module.xml` keeps its existing cache entry.
- A deleted module directory has its entry cleaned up.
- A missing root fails the rebuild instead of emptying the cache.
- The SQL fallback walk agrees with the Python walk.
- `-depth` is respected; a new version is auto-discovered on `install`; `-rebuild-cache` works end to end.

Unit tests in `Test.PM.Unit.FileHash` cover `WalkDirectories` and the relocated `NormalizePath`.

## Checklist

- [ ] This branch has the latest changes from the `main` branch rebased or merged.
- [x] Changelog entry added.
- [ ] Unit (`zpm test -only`) and integration tests (`zpm verify -only`) pass.
- [ ] Style matches the style guide in the [contributing guide](https://github.com/intersystems/ipm/blob/main/CONTRIBUTING.md#style-guide).
- [ ] Documentation has been/will be updated
  - Source controlled docs, e.g. README.md, should be included in this PR and Wiki changes should be made after this PR is merged (add an extra issue for this if needed)
- [ ] Pull request correctly renders in the "Preview" tab.
