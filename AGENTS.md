# Repository Guidelines

## Project Structure & Module Organization
- `/src/cls/IPM/`: InterSystems Package Manager ObjectScript source (`%IPM.*`).
- `/tests/unit_tests/Test/PM/Unit/`: Unit tests (`%UnitTest.TestCase`), run by `test`.
- `/tests/integration_tests/Test/PM/Integration/`: Integration tests, run by `verify`.
- `/tests/registry/`, `/tests/oras/`: Registry services that `/docker-compose.yml` starts for integration tests.
- `/tests/sandbox/`: Clean IRIS container for trying IPM release installers.
- `/preload/cls/`: The IPM installer, loaded before IPM itself.
- `/wheels/`: Python wheels IPM depends on.
- `/modules/python/`: Non-embedded Python source.

## Source Control
- main is the protected mainline branch.
- Branching paradigm uses mainline, staging, and release branches (using .x).
- The source is on GitHub: https://github.com/intersystems/ipm.

## Build, Test, and Development Commands
- `docker compose up -d --build` starts the dev environment (see `/CONTRIBUTING.md`). The `ipm-iris-1` container has IPM installed in USER and the repo bind-mounted at `/home/irisowner/zpm/`.
- Run ObjectScript non-interactively by piping to a session:
  ```sh
  docker exec -i ipm-iris-1 iris session IRIS -U USER <<'EOF'
  write $zversion,!
  halt
  EOF
  ```
  On a Windows host with Git Bash, prefix `docker exec` with `MSYS_NO_PATHCONV=1` when an argument is a container-side absolute path.
- Compile one changed class with `do $system.OBJ.Load("/home/irisowner/zpm/src/cls/IPM/<path>.cls", "ck-d")`. Saving a `.cls` in VS Code also compiles it.
- Re-install all of IPM from source:
  - `do $system.OBJ.Load("/home/irisowner/zpm/preload/cls/IPM/Installer.cls", "ck")`
  - `do ##class(IPM.Installer).setup("/home/irisowner/zpm/", 3)`
- A change to `/src/cls/IPM/Main.cls` needs the `iris` container rebuilt. A change to `/docker-compose.yml` or a file it mounts needs that service recreated.
- Test commands. `-only` skips rerunning the earlier lifecycle phases and `-quiet` shows only the summary and failures:
  - All unit tests: `zpm "zpm test -only -quiet"`
  - One case: `zpm "zpm test -only -quiet -DUnitTest.Case=Test.PM.Unit.CLI"`
  - One method: `zpm "zpm test -only -quiet -DUnitTest.Case=Test.PM.Unit.CLI -DUnitTest.Method=TestParser"`
  - Integration tests: replace `test` with `verify` and always pass a `-DUnitTest.Case`, e.g. `-DUnitTest.Case=Test.PM.Integration.Update`. The full integration suite takes too long to run as a check.
- To compile a test class directly, load its base first (`/tests/integration_tests/Test/PM/Integration/Base.cls` for integration tests). Test classes are not compiled in the image.
- All IPM shell commands are defined in `/src/cls/IPM/Main.cls` in the `Commands` XDATA block.

## Coding Style & Naming Conventions
- Follow the Style Guide in `/CONTRIBUTING.md`.
- One class per `.cls` file; keep class path aligned with package.
- Methods (including tests): PascalCase; avoid underscores.
- Indentation: 4 spaces. `/.vscode/settings.json` enforces this and formats on save.
- Methods should throw errors instead of returning %Status unless overriding a method that requires returning %Status.

## Comments & Documentation
- Use `///` for class/method docs; prefer code examples over prose.
- Comments describe what the code does now and why. History, rejected alternatives, and what would break without the change belong in the commit message or PR description.
- Omit issue and PR numbers in in-code documentation. They are clutter once merged, especially for fixes within an unreleased feature.
- Omit backward-compatibility notes for unreleased features (e.g. how rows written before a new property was added would read).
- Write the shortest comment that still carries the non-obvious reason. If the code already says it, do not repeat it.
- An imperative stands as its own sentence: "...could not read. Hash it here rather than X.", not "...could not read; hash it here rather than X."
- Re-read and cut every comment you added before opening a PR.
- Docs, comments, and PR descriptions stand alone. Instead of a label from a plan or chat ("decision 4", "Task 2"), state the reason itself or link its source.
- Write IPM CLI examples as `<command> <target> [<flags>]`, e.g. `load /path/to/module -dev`.
- Use ASCII diagrams in docs and PR descriptions for anything spatio-temporal: workflows, phase order, directory layouts, dependency trees. Update a stale diagram rather than removing it.
- `/CHANGELOG.md` entries must be included for all PRs except those fixing/modifying an unreleased feature and must reference the issue number being fixed, if one exists.

## Prose Style
Applies to comments, `write` output, docs, and PR descriptions.
- Emphasis comes from sentence structure, headings, and lists. Write words in normal case and leave mid-sentence phrases unbolded.
- Join clauses with a comma, "so", "because", or a period. Use an em-dash only where none of those reads better, and rewrite the sentence rather than swapping in another dash.
- Join two independent clauses with "and" without a comma before it, or split them into two sentences.

## Testing Guidelines
- Name test classes with PascalCase and use a short, descriptive word or phrase of what is being tested, e.g. `FileCopy.cls`.
- Name test methods `Test...`, use PascalCase, and keep assertions focused and readable.
- Keep unit tests hermetic, using `%DynamicObject`/`%DynamicArray` fixtures. Integration tests may use the docker-compose services and the filesystem.
- Place integration test data (including test modules) under `/tests/integration_tests/Test/PM/Integration/_data/` and resolve it with `GetModuleDir(...)`.
- Root a `repo -fs` at the smallest directory holding the modules the test resolves. The repo scans every `module.xml` under its root across the slow bind mount.
- When a test departs from full per-test setup and teardown (shared namespaces, reused fixtures), comment why the standard approach was too costly, why sharing is safe, and what constraint it puts on future tests.
- Start hand-written XML fixtures with `<Export generator="IRIS" version="26">`.
- Leave `NEEDSREGISTRY` out of new test classes. It is legacy.
- Before pushing, confirm new tests pass and the cases they touch still pass.
