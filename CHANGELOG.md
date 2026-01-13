# InterSystems Package Manager

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.10.5] - Unreleased

### Added
- #938: Added flag -export-python-deps to package command
- #462: The `repo` command for repository configuration now supports secret input terminal mode for passwords with the `-password-stdin` flag
- #935: Adding a generic JFrog Artifactory tarball resource processor for bundling artifact with a package and deploying it to a final location on install.
- #950: Added support for listing installed Python packages using `list -python`, `list -py` and `list-installed -python`
- #822: The CPF resource processor now supports system expressions and macros in CPF merge files
- #578: Added functionality to record and display IPM history of install, uninstall, load, and update
- #961: Adding creation of a lock file for a module by using the `-create-lockfile` flag on install.
- #959: In ORAS repos, external name can now be used interchangeably with (default) name for `install` and `update`, i.e. a module published with its (default) name can be installed using its external name.
- #951: The `unpublish` command will skip user confirmation prompt if the `-force` flag is provided.
- #1018: Require module name for uninstall when not using the -all flag

### Changed
- #316: All parameters, except developer mode, included with a `load`, `install` or `update` command will be propagated to dependencies
- #885: Always synchronously load dependencies and let each module do multi-threading as needed
to load using multicompile instead of trying to do own multi-threading of item load which causes
lock contention by bypassing IRIS compiler.
- #481: Improve BuildDependencyGraph performance by doing the following:
 - Eliminate recursion and use iteration.
 - Remove depth first search and do pure breadth first search.
 - Have better caching of results for module searches by collapsing search expressions (reducing expressions that are intersections).

### Removed
- #938: Removed secret flag NewVersion handling in %Publish()

### Fixed
- #943: The `load` command when used with a GitHub repository URL accepts a `branch` argument again
- #701: Fix misleading help comments about `search` command
- #958: Update command should not fail early if external name is used
- #970: fix: Resolve <UNDEFINED> error in 'generate' command WebApp processing
- #965: FileCopy on a directory with a Name without the leading slash now works
- #937: Publishing a module with a `<WebApplication>` containing a `Path` no longer errors out
- #957: Improved error messages for OS command execution. Now, when a command fails, the error message includes the full command and its return code. Also fixed argument separation for the Windows `attrib` command and removed misleading error handling for missing commands.
- #789: Fix error when listing modules for an ORAS repo with a specified namespace.
- #999, #1000: Installing IPM cleans up stale mappings used in old versions of IPM
- #1007: The `${ipmDir}` expression now works in the `<Arg>` of an `<Invoke>`
- #1015: Fix dependency resolution bugs where `*` as the version requirement and intersecting ranges wouldn't work properly.
- #1036: The `update` command no longer propagates developer mode to dependencies

### Deprecated
- #828: The `CheckStatus` flag for `<Invoke>` action has been deprecated. Default behavior is now to always check the status of the method if and only if the method signature returns %Library.Status
- #885: `-synchronous` flag since loading dependencies synchronously is now the default behavior.

## [0.10.4] - 2025-10-21

### Added
- #874: Modules can now specify required Python version in `<SystemRequirements>` in `module.xml`
- #909: IPM now warns when Python 3.13 or higher is installed (IRIS incompatibility)
- #850: Re-added `<SystemSetting>` Resource Processor for backwards compatibility
- #550: Add a new "update" command and framework to support in-place module updates. install/load of a module to newer version than currently installed will be blocked by default if module has UpdatePackage defined.

### Fixed
- #899: Fixed CLI parser parses modifiers incorrectly
- #299: Prevent Japanese (and other UNICODE) characters from being garbled when outputting unit test results
- #819: Drastically increase `zpm "info"` speed when many dependent packages have been installed
- #888: Fixed `zpm "list -tree"` showing packages as `[missing]` because of case mismatch
- #058: Prevent uninstallation of dependent module without `-force` flag
- #908: Fix case where `uninstall -all` would fail because of incomplete dependency information
- #892: Fixed load behavior (no longer sets Developer Mode unless -dev flag is set)
- #903: Fixed install behavior which succeeded even when trying to reinstall a module without -dev or -force modifiers (breaking change)
- #363: `help load` and `help install` will now mention that setting the `dev` flag will not roll back transactions on failure
- #884: Fix missing module version in error message when dependency resolution fails to find suitable version
- #838: Improve error messages when installation fails
- #924: Make "module" parameter not required for "uninstall" command so -all modifier works
- #928: `zpm "info"` now recognizes existence of configured ORAS registries
- #930: Fix issue where `load` didn't work on GitHub URLs
- #1011: Hidden flags IgnoreInstalled and UpdateSnapshots cause redundant calling of BuildDependencyGraph()
- #1014: After FileCopy respects scope change #864, compileable resources with specified Scope cause Compile phase to fail on install

### Changed
- #639: All modules installed in developer mode can now be edited, even if they do not contain "snapshot" in the version string
- #706: `load` now only accepts absolute paths
- #278: Modules will now be installed at a well-defined default location: `$System.Util.DataDirectory()/ipm/<packagename>/<version>/`
- #374: A new System Expression `${ipmdir}` points to the module's default installation location: `$System.Util.DataDirectory()/ipm/<packagename>/<version>/`
- #563: The `verify` phase will uninstall all modules after every integration test
- #611, #686: If a path is supplied for `package`, it will now create a temporary subdirectory in that path to export the module into to avoid clashes with any existing files. This subdirectory will be deleted afterwards, leaving just the .tgz file.
- #844: If the "NameSpace" attribute isn't specified for a Web Application, it will be created in the current namespace instead of %SYS
- #815: The PrepareDeploy phase has been removed and packaging+publishing of modules with deployed code will happen in the current namespace even in developer mode

## [0.10.3] - 2025-09-17

### Fixed
- #829: Fixed export of resources with null Directory attribute
- #832: Fixed places that export to possibly-nonexistent directories by adding /createdirs (needed in 2025.2+)
- #823: Fixed selectively undeploying classes within a package
- #820: Fixed `${packagename}` not working for FileCopy
- #837: Fixed poorly formatted and unclear error message when Python wheel fails to install
- #810: Fixed `<SystemRequirements Interoperability="enabled"/>` in module.xml not enabling interoperability for deployed code namespaces
- #836: Fixed FileCopy (and other resource processors) not checking scope
- #688: `uninstall -f -all` will no longer attempt to uninstall IPM
- #839: SemVer expression "And" (as used in dependency resolution) fixed for complex ranges

### Changed
- Format all files and add consistent formatting settings, format on save etc.
- #848: Resource processing should be done in order of granularity
- #779: Module parameters specified in `<Defaults>` in the module.xml are used when loading/installing the module and not just when the module itself runs its lifecycle phases

## [0.10.2] - 2025-06-04

### Fixed
- #809: Fixed installation of rpds.py in containers using durable %SYS
- #811: Issues when upgrading from earlier IPM versions with cross-namespace differences
- #796: Installation on environments without Flexible Python Runtime
- #778: CI - avoid deadlock on 2025.2 preview due to cached query regeneration bug
- #816: Fixed zpm "install" command not pulling specified versions of artifacts

## [0.10.1] - 2025-04-24

### Fixed
- #797 Windows: IPM now uses the Python Runtime Library path from iris.cpf if defined

## [0.10.0] - 2025-04-16

*Important*: The minimum supported InterSystems IRIS version is now *2022.1*. For earlier IRIS versions, use IPM 0.9.x.

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
- #769: Allow `publish <module> -only` to publish a module without running `reload`
- #533: External name changed to IPM (which carries greater meaning in 0.10.0)
- #793: Add support for -synchronous flag to install command (added to load in #746)

### Changed
- The minimum supported IRIS version for this release is 2022.1.
- #702 Preload now happens as part of the new `Initialize` lifecycle phase. `zpm "<module> reload -only"` will no longer auto compile resources in `/preload` directory.
- #726 When running `zpm "load ..."` on a nonexistent path, it now returns an error instead of silently failing with a $$$OK status.
- #754 Deployed items are now exported together into a single `studio-project/Deployed.xml` instead of individual `.deploy` files.
- #756 External name of packages are now unqiue and can no longer conflict with the real name of another packages.
- #751: Blue terminal output replaced with default (white)
- #769: Lifecycle phase `Package` is now run as part of `Publish`.

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
- #775: Fixed a bug where incorrect name/version of ORAS packages is returned
- HSIEO-12012: Publishing modules with deployed code only run PrepareDeploy phase if module is in dev mode.
- #782: Installer no longer includes unit tests
- #781: Addressing an issue where file paths exceed 256 characters
- #786: Resources with scope should not be exported
- #788: Further reducing likelihood of file paths exceeding 256 characters
- Issue installing with ORAS registries with specific builds listed; consistencies in repo -list-modules and -search with ORAS registries
- #787: Publishing/unpublishing to remote registry broken
- #649: Clear existing credentials when changing URL on remote HTTP registry
- Reduced timeout when checking HTTP registry availability (fails faster rather than hanging for a long time and then failing)

## [0.9.2] - 2025-02-24

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
- #757: Fixed a bug where mappings are not getting created when they should.

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
- #776: Loading packages fails on 8-bit IRIS installations in certain locales

### Deprecated
- #593 CSPApplication is deprecated in favor of WebApplication. User will be warned when installing a package containing CSPApplication.
