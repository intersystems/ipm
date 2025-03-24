# InterSystems Package Manager

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased - 0.10.0+snapshot]

### Added
- #474 Added compatibility to load ".tar.gz" archives in addition to ".tgz"
- #469 Added ability to include an `IPMVersion` in `SystemRequirement` of module.xml
- #530 Added a `CustomPhase` attribute to `<Invoke>` that doesn't require a corresponding %method in lifecycle class.
- #582 Added functionality to optionally see time of last update and server version of each package
- #609,#729 Added support for `-export-deps` when running the "Package" phase (and, consequently, the "Publish" phase) of lifecycle
- #541 Added support for ORAS repository
- #702 Added a new lifecycle phase `Initialize` which is used for preload
- #702 Added a `<CPF/>` resource, which can be used for CPF merge before/after a specified lifecycle phase or in a custom lifecycle phase.
- #704,743 Added support for passing in env files via `-env /path/to/env1.json;/path/to/env2.json` syntax. Environment variables are also supported via ${var} syntax.
- #710 Added support for `module-version` command which updates the version of a module
- #716,#733 Added support to publish under external name by passing `-use-external-name` or `-use-ext`. Fail early if external name is illegal / empty.
- #720 Added support to export package with Python dependencies exported as a wheel file.
- #720 Support offline installation of oras using fixed version of pure python wheels and an adaptor for rpds.
- #746: Added support for loading modules synchronously without multiprocessing
- #749: Added more debugging information in the welcome banner
- #754: Support publishing and installing deployed items for ORAS repository
- #755: Added an `info` command which prints external name (optionally including the real name) of top-level packages without the `build` part of semver. 
- #756: Support running commands using external names of packages.
- #767: Allow skipping the reload phase when packaging and publishing, useful for packaging/publishing after running `module-version`

### Changed
- #702 Preload now happens as part of the new `Initialize` lifecycle phase. `zpm "<module> reload -only"` will no longer auto compile resources in `/preload` directory.
- #726 When running `zpm "load ..."` on a nonexistent path, it now returns an error instead of silently failing with a $$$OK status.
- #754 Deployed items are now exported together into a single `studio-project/Deployed.xml` instead of individual `.deploy` files.
- #756 External name of packages are now unqiue and can no longer conflict with the real name of another packages.
- #751: Blue terminal output replaced with default (white)

### Fixed
- #474: When loading a .tgz/.tar.gz package, automatically locate the top-most module.xml in case there is nested directory structure (e.g., GitHub releases)
- #635: When calling the "package" command, the directory is now normalized to include trailing slash (or backslash).
- #696: Fix a bug that caused error status to be ignored when publishing a module.
- #700: Fix a bug due to incompatible conventions between SemVer and OCI tags
- #726,#729: Fixed a bug where install/loading a tarball doesn't install dependencies from `.modules` subfolder even when it's available
- #731: Issue upgrading from v0.9.x due to refactor of repo classes
- #718: Upload zpm.xml (without the version) as an artifact to provide a more stable URL to latest release artifact on GitHub
- #754: Fix a bug where `MakeDeployed` doesn't mark a module as deployed if there are only class (but not routine) resources with `Deploy=true`
- #757: Fixed a bug where mappings are not getting created when they should.
- #722: Unified modifiers between ModuleAction and RunOnePhase
- #735: Prerelease now properly allows alphanumeric tags with zeros
- #736: Fixed a bug with FileCopy not handling a dependency's resource correctly

### Security
-

### Removed
- 

### Deprecated
-

## [Unreleased - 0.9.2+snapshot]

### Added
- #682 When downloading IPM via the `enable` command from a remote registry, allow user to pass in the registry name (or get the only existent one), instead of the deployment enabled registry.

### Fixed
- #684 Fixed banner display issues in interactive `zpm` shell.
- #682 When enabling IPM in a namespace using local IPM caches, check for existence of `<iris-root>/lib/ipm/` beforing querying it.
- #682 Use more standard wording of mapping when enabling IPM
- #681 Convert specified namespaces to upper case for `enable` and `unmap` commands.
- #680 Always export static files (README.md, LICENSE, requirements.txt) if existent
- #678 Only update comment-flagged part of the language extension, allowing users to keep their custom code when upgrading
- #680, #683 Always export static files (README.md, LICENSE, requirements.txt, CHANGELOG.md) if existent
- #745 Allow publishing of deployments without developer mode

### Security
- #697 When publishing modules, will get an status with error message (instead of just a boolean) in case of failures.

## [0.9.1] - 2024-12-18

### Added
- #663 Added support for mapping of repository settings along with, or in addition to, IPM package and routines
- #663 Added functionality to always unmap repository settings when IPM package and routines are unmapped
- #663 Added support for unmapping of repository settings alone
- #663 Added support for `enable -community`, which resets repository settings to default and maps IPM along with repo settings globally

### Fixed
- #663 Improved error output and instructions in the language extension when "zpm" is run from a namespace without IPM

## [0.9.0] - 2024-12-16

### Added
- #364 Added ability to restrict the installation to IRIS or IRIS for Health platform to the SystemRequirements attribute
- #518 Added ability to show source file location when running `list-installed`. E.g., `zpm "list-installed -showsource"`.
- #538 Added ability to customize caller to PipCaller and UseStandalonePip through `config set`, which are empty by default and can be used to override the auto-detection of pip.
- #562 Added a generic resource processpor `WebApplication`, which handles creating and removal of all Security.Applications resources
- #575 Added ability to expand `$$$macro` in module.xml. The macro cannot take any arguments yet.
- #595 Added ability to bypass installation of python dependencies with -bypass-py-deps or -DBypassPyDeps=1.
- #647 Added ability to add extra flags when installing python dependencies using pip

### Changed
- IPM is now namespace-specific rather than being installed in %SYS and being available instance-wide.
- HSIEO-9484: Add additional argument to buildDepsGraph to allow putting in an additional list element of dependency's DisplayName
- HSIEO-9484: Add additional property DisplayName to %IPM.Storage.ModuleReference
- HSIEO-10274: Separate DependencyAnalyzer out from IPM
- #261: IPM now truly supports using multiple registries for installation / discovery of packages (without needing to prefix the package with the registry name on "install", although it is still possible and now effective to use the prefix).
- #454: IPM 0.9.x+ uses different globals for storage vs. 0.7.0 and previous. Installation will automatically migrate data from the old globals to the new ones. The old globals are left around in case the user decides to revert to an earlier version.
- #527: IPM 0.9.x+ ignores the casing of resources when matching files on disk even on case-sensitive filesystems

### Fixed
- HSIEO-11006: Fix conditions for marking code as deployed
- HSIEO-10884: Bug Fix - FileCopy to check for $ variables in path
- HSIEO-11006: Fix conditions for marking code as deployed
- HSIEO-9269, HSIEO-9402: % percent perforce directories are no longer necessary
- HSIEO-9269, HSIEO-9404: Repo check should happen in the order to repo creation, not by repo name
- HSIEO-9269, HSIEO-9411: Make sure can load and export xml Package-type resource
- HSIEO-9269, HSIEO-9403: Ensure studio project uses display name.
- HSIEO-9269, HSIEO-9404: Repo check should happen in the order to repo creation, not by repo name
- HSIEO-9269, HSIEO-9366: Make sure VersionInfo uses exact database namespace instead
- HSIEO-9269, HSIEO-9384: %IPM.Utils.Build:CreateNamespace should not call %IPM class from %SYS namespace
- HSIEO-9269, HSIEO-9333: OnDetermineResourceDeployability should make sure to check uppercase of item suffix
- HSIEO-9269, HSIEO-9315: HSCC needs to re-create %IPM mapping for application namespace because of its mapping deletion
- HSIEO-9269, HSIEO-9276: Fix dependency analyzer issue
- HSIEO-9269, HSIEO-9275: IsAvailable() method need to work robustly
- HSIEO-9269, HSIEO-9277, HSIEO-9235: Remove exportDeployedItem temporarily until HSIEO-9235
- HSIEO-9269, HSIEO-9278: Mark based module as non deployed if install in dev mode
- HSIEO-9269, HSIEO-9279: Enable resource mapping creation during build
- HSIEO-9269, HSIEO-9280: Load unittest code during module install
- HSIEO-9430: Module definition should not expose DisplayName + deprecate DisplayNameInternal as it will not be used anymore
- HSIEO-9924: RunDev needs to do complete installation of component and dependencies via ignoreInstalled, so adding ignoreInstalledModules checker in syncLoadDependencies
- HSIEO-10267: Bug Fix - Resource name should be the fifth argument of CreateDatabase
- HSIEO-10520: Pre-Release module versions does not get exact version match
- #440: IPM works with delimited identifiers disabled
- #451: CI runs on fewer versions to minimize overhead and Community Edition expiration issues
- #451, #428: Fixes "Verify" phase to work properly after %IPM rename
- #451: Avoid compliation errors due to storage location conflict on IRIS for Health prior to 2024.1
- #455: Upgrade from %ZPM classes updates language extensions correctly to use %IPM
- #373: Cleaner cross-version approach used in language extension routine generation
- #459: zpm "version" behaves better without internet access
- #224: When updating zpm, existing configuration won't be reset
- #482: Reenabled deployed code support without impact on embedded source control (reworks HSIEO-9277)
- #487: When loading a package, relative paths staring with prefix "http" won't be mistaken for git repo
- #544: When installing a package from remote repo, IPM specifies `includePrerelease` and `includeSnapshots` in HTTP request. Correctly-behaving zpm registry should respect that.
- #557: When comparing semver against semver expressions, exclude prereleases and snapshots from the range maximum.
- #559: Allow treating the "w" in SemVer x.y.z-w as a post-release rather than pre-release.
- #607: Uninstall reports deletion of non-classes
- #606: Don't put garbage folders in tar archive
- #652: Don't create extra needless mappings (could cause deadlock with parallel installation of dependencies)

### Deprecated
- #593 CSPApplication is deprecated in favor of WebApplication. User will be warned when installing a package containing CSPApplication.

