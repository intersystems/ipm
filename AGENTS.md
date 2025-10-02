# Repository Guidelines

## Project Structure & Module Organization
- `/src/`: InterSystems Package Manager ObjectScript source code classes.
- `/tests/unit_tests/Test/PM/Unit/`: Unit tests using InterSystems IRIS `%UnitTest.TestCase`.
- `/tests/integration_tests/Test/PM/Integration/`: Integration tests using InterSystems IRIS `%UnitTest.TestCase`.
- `/wheels/`: Python wheel files that are dependencies of IPM.
- `/CHANGELOG.md`: Changelog for IPM changes by semantic version.
- `/CONTRIBUTING.md`: Instructions for setting up a development environment, testing, and  for IPM.
- `/README.md`: Basic user docs.
- `/module.xml`: IPM module manifest for packaging/testing.
- `/Dockerfile` and `/docker-compose.yml` and `/iris.script`: Files for setting up an IPM development environment in Docker containers.
- `/.vscode/`: Settings for VSCode suitable for development on IPM.
- `/preload/cls/`: Files to be loaded before IPM is loaded in an IRIS instance (IPM installer).
- `/scripts/`: Shell scripts.
- `/modules/python/`: Non-embedded python source code.

## Source Control
- Git-based.
- main is the protected mainline branch.
- Branching paradigm uses mainline, staging, and release branches (using .x).
- The InterSystems Package Manager source code is located in a remote, open source Github repository: https://github.com/intersystems/ipm.

## Build, Test, and Development Commands
- To re-compile sources (from IRIS terminal in the correct namespace):
  - `d $system.OBJ.Load("/home/irisowner/zpm/preload/cls/IPM/Installer.cls", "ck")`
  - `do ##class(IPM.Installer).setup("/home/irisowner/zpm/", 3)`
- Run tests via ZPM (prompt for instance and namespace):
  - Prefer this interactive shell snippet so you can choose the IRIS instance and namespace at run time:
    ```sh
    read -r -p "IRIS instance name: " IRISINST
    read -r -p "Namespace to run tests: " NS
    iris session "$IRISINST" -U "$NS" <<'EOF'
_system
SYS
zpm "zpm test"
halt
EOF
    ```
  - To run a single unit test case, replace the `zpm` line with, for example:
    ```sh
    zpm "zpm test -only -DUnitTest.Case=Test.PM.Integration.Update"
    ```
  - To run a single unit test method within a test case, replace the `zpm` line with, for example:
    ```sh
    zpm "zpm test -only -DUnitTest.Case=Test.PM.Integration.Update -DUnitTest.Method=TestUpdateToNewVersionTwice"
    ```
  - To run integration tests, replace `test` in the commands above with `verify`.
  - All IPM shell commands are defined in `/src/cls/IPM/Main.cls` in the `Commands` XDATA block.
  - If already inside an IRIS terminal in your target namespace, you can simply run:
    - `zpm "zpm test"`

## Coding Style & Naming Conventions
- One class per `.cls` file; keep class path aligned with package.
- Methods (including tests): PascalCase; avoid underscores.
- Indentation: 4 spaces or tabs consistently; align `Try/Catch`/`While` blocks.
- Use `///` for concise class/method docs; prefer code examples over prose.
- Methods should throw errors instead of returning %Status unless overriding a method that requires returning %Status.

## Testing Guidelines
- Place unit tests under `/tests/unit_tests/Test/PM/Unit/`.
- Place integration tests under `/tests/unit_tests/Test/PM/Integration/`.
- Place any test data (including test modules) under `/tests/_data/`.
- Name test classes with PascalCase and use a short, descriptive word or phrase of what is being tested, e.g. `FileCopy.cls`
- Name test methods `Test...`, use PascalCase, and keep assertions focused and readable.
- Keep tests hermetic: no external I/O or network; use `%DynamicObject`/`%DynamicArray` fixtures.
- Run tests locally before pushing; ensure new tests pass and do not break existing ones.

## Security & Configuration Tips
- None so far.