# InterSystems Package Manager

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased - 0.9.0+snapshot]

### Added
-

### Changed
- HSIEO-9484: Add additional argument to buildDepsGraph to allow putting in an additional list element of dependency's DisplayName
- HSIEO-9484: Add additional property DisplayName to %IPM.Storage.ModuleReference
- HSIEO-10274: Separate DependencyAnalyzer out from IPM
- #261: IPM now truly supports using multiple registries for installation / discovery of packages (without needing to prefix the package with the registry name on "install", although it is still possible and now effective to use the prefix).

### Fixed
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
- #440: IPM works with delimited identifiers disabled
- #451: (CI) Run on fewer versions to minimize overhead and Community Edition expiration issues
- #451: Avoid compliation errors due to storage location conflict on IRIS for Health prior to 2024.1
- #455: Upgrade from %ZPM classes updates language extensions correctly to use %IPM
- #373: Cleaner cross-version approach used in language extension routine generation

### Security
-

### Removed
- 

### Deprecated
-