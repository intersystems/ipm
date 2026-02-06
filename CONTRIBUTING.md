# Contributing to IPM

## Process - Contributions, Review, and Prioritization

IPM's primary maintainers are a highly invested cross-departmental team within InterSystems. We welcome community contributions, but at times may have limited bandwidth for thorough reviews alongside our own IPM- and non-IPM-related work.

In general:
* Regressions - InterSystems will review and merge PRs urgently (target: <1 week)
* Other bug fixes - InterSystems will review and merge without a milestone associated with the issue (target: within 1 month)
* Features are more complicated. We need to ensure alignment with the overall IPM roadmap and existing design.
    * To avoid wasting contributors' time, InterSystems signoff on the spec is required before PR review and strongly advised before implementation work begins.
    * If a feature issue is assigned to an InterSystems employee, that means that work may be in progress. Contributors should verify with the assignee before beginning work.
    * For community-requested features, it is appropriate to report a GitHub issue and then create a Discussion to hone the spec. The final spec will go into the issue. While pending spec, the issue will be given the "needs spec" label and should not be actioned.
    * Features we would like to see or implement in a certain timeframe will have an associated milestone.
    * Features where we would particularly welcome community contribution will have the "help wanted" label.

Pull request reviews will cover code style and quality, architectural consistency, and correctness to spec.

---

## Style Guide
As a general principle, try to copy the style of the existing code. If you are working in VS Code, use the formatting in `.vscode/settings.json`.

### Syntax and Structure
* Use full, unabbreviated command names: `set`, `quit`, `write`, instead of `s`, `q`, `w`.
* Write one command per line—avoid combining operations with semicolons or unnecessary chaining.
* Use blank lines generously to separate logical sections within methods.
* Place opening braces on the same line as control structures (`if`, `for`, `while`, `try`, `catch`).
* Avoid postconditionals except in simple, idiomatic cases
    * Acceptable: early loop exits (`quit:key=""`) or conditional output (`write:verbose !,"message"`)
### Variable Naming
* For variable naming, use descripive names that convey purpose
* Avoid `p-` and `t-` prefixes
### Error Handling
* Use try-catch blocks for error handling
* Throw errors with `$$$ThrowOnError()` for methods that return a status or `$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("<Descriptive message> %1",<details from a variable>)))` to construct a custom error status
* Check status with `$$$ISERR()` or `$$$ISOK()`
* All return statuses should be handled either by throwing errors or special handling if not fatal
### Comments
* Use `//` for inline comments
* Use `///` for method and class-level documentation

---

## Technical Guide

### Developing IPM in Docker Containers

To implement new features, enhance existing capabilities, or fix known bugs, we strongly recommend setting up a local dev environment with Docker containers.

#### Commands
To develop IPM inside Docker containers, run the following command directly:
```bash
git clone https://github.com/intersystems/ipm
cd /path/to/cloned/ipm
git checkout <target-branch> # consult with other IPM developers on which branch your PR should be targeted
git checkout -b <new-branch-name>
docker compose up -d --build
```
This will spin up 3 (or 4, if you're working on v0.10.x) containers, which are:
- `ipm-iris-1`, a container that has the repo-version IPM built in the USER namespace, where the management portal (52773) is published to the host OS at 52774. On the Docker network, this container has the hostname `iris`.
- `ipm-registry-1`, a container with a zpm-registry pre-configured, where the username is `admin`, the password is `SYS`, and the management portal (52773) is published to the host OS at 52775. On the Docker network, this container has the hostname `registry`.
- `ipm-sandbox-1`, a container with a vanilla IRIS instance, where the management portal (52773) is published to the host OS at 52776. On the Docker network, this container has the hostname `sandbox`.
- `ipm-oras-1`, a container WITHOUT any IRIS instance. This container is based on [zot](https://github.com/project-zot/zot) and provides an OCI image registry, with port 5000 published to the host OS at 5001. On the Docker network, this container has the hostname `oras`.

#### Important notes
- In both `ipm-iris-1` and `ipm-sandbox-1`, the IPM repo itself is mounted at `/home/irisowner/zpm/`.
- Sometimes `ipm-registry-1` doesn't install zpm-registry properly; you may need to perform the following steps to manually make it work:
  - Run `docker exec -it ipm-registry-1 /bin/bash` to access the container.
  - Inside the container, run `iris session iris` to access the IRIS instance.
  - Inside the IRIS instance, run `zn "REGISTRY"` and `zpm "install zpm-registry"` to install and configure the registry. When this finishes successfully, the registry will be up and running, accessible to other containers at `http://registry:52773/registry`.
- If any of the ports 52774, 52775, 52776, or 5001 are in use, you may need to modify the port forwarding configuration in `docker-compose.yml`.
- If you are on an ARM chip (e.g., M-series Macs), you may need to change the `oras` section in `docker-compose.yml` to use `ghcr.io/project-zot/zot-linux-arm64:latest` instead of `ghcr.io/project-zot/zot-linux-amd64:latest`.
- The VS Code workspace settings in `.vscode/settings.json` automatically connect to the IRIS instance on 52774. If you didn't change the port mapping in `docker-compose.yml`, when you save and compile changes in VS Code, it should automatically update the `%IPM.*` code in the `USER` namespace of the `ipm-iris-1` container.

#### Development
Make any necessary changes, compile them (which should be handled by VS Code on save), and test in the `ipm-iris-1` container by running:
```bash
docker exec -it ipm-iris-1 /bin/bash
$ iris session iris
```
OR as a single line:
```bash
docker exec -it ipm-iris-1 /bin/bash -c "iris session iris"
```
If you need to shut down all the containers (either to switch to another branch or to revert back to a clean state) involved in the `docker-compose.yml`, run the following command in the project folder:
```bash
docker compose down --remove-orphans --volumes
```
From time to time, you may also want to remove unused Docker data to save disk space, as insufficient disk space may cause `docker compose up` to fail.
```bash
docker system prune -a
```


### Developing IPM in an existing IRIS instance
If you already have an IRIS instance running and you want to test IPM in this instance, run the following command:
```bash
git clone https://github.com/intersystems/ipm
cd /path/to/cloned/ipm
git checkout <target-branch> # consult with other IPM developers on which branch your PR should be targeted
git checkout -b <new-branch-name>

iris session <YOUR-INSTANCE-NAME>
```
Then, inside the instance terminal, run:
```objectscript
do $System.OBJ.Load("</path/to/ipm/repo>/preload/cls/IPM/Installer.cls", "ck")
do ##class(IPM.Installer).setup("</path/to/ipm/repo>/", 3)
```

#### Caveats
- This approach is NOT recommended for any instance with HSLIB as the existing versions of IPM and its extensions may interfere
- If your current instance doesn't run on 52774 with an empty prefix, you need to manually edit VS Code settings (either via GUI or `.vscode/settings.json`) in order to automate VS Code compilation on your instance.
- When you switch to another Git branch, previous changes may carry over. For example, if you created and compiled a new class `%IPM.MyClass.cls` on branch A and switched to branch B, that class may still be visible in your instance. Consider manually deleting the IPM package using `$System.OBJ.DeletePackage("%IPM")` before switching branches if needed.

---

### Testing
There are 2 kinds of tests in IPM: unit tests and integration tests. You can find all the test cases in the `tests/` folder.

-  To run all the unit tests, use `zpm "zpm test -only -v"`;
-  To run all the integration tests, use `zpm "zpm verify -only -v"`;

where the `-v` is an optional verbosity flag.

Some tests involve publishing to test registries, such as the ones in `ipm-registry-1` and `ipm-oras-1`. If those tests fail, check if those 2 containers are running on the correct ports and endpoints. Tests can also fail for other reasons. Typically, you can run both tests on an unchanged codebase to establish a baseline first. After development, if it doesn't incur new failures beyond the baseline, then your changes should be fine. We also have CI to double-check all unit/integration tests when you open a pull request.

#### Creating Tests

It may often be necessary to create small, specific modules to test functionality. To do so, there are two main approaches.
##### 1. File System Based (module.xml + Source Directory)
Test modules are stored as complete directory structures in `tests/integration_tests/Test/PM/Integration/_data/` with:
- A `module.xml` file
- Source code files in subdirectories (typically `src/`)
- Dependencies in a `.modules` directory
- Any other required resources

###### Implementation Example
```
_data/simple-module/
├── module.xml
└── src/
    └── Test.pkg
```

The `module.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Export generator="Cache" version="25">
  <Document name="simplemodule.ZPM">
    <Module>
      <Name>simplemodule</Name>
      <Version>0.0.1+snapshot</Version>
      <SourcesRoot>src</SourcesRoot>
      <Resource Name="Test.pkg"/>
    </Module>
  </Document>
</Export>
```


Note: Individual modules may be placed in subdirectories, so multiple modules can exist in a given directory in `_data`, e.g.

```
_data/simplest-module/
├── 1.0.0
├──── module.xml
├── 2.0.0
├──── module.xml
```

###### How to Use in Tests
Using inherited `GetModuleDir()` helper
```objectscript
Method TestSimpleModule()
{
    set moduleDir = ..GetModuleDir("simple-module")
    set sc = ##class(%IPM.Main).Shell("load " _ moduleDir)
    do $$$AssertStatusOK(sc,"Loaded module successfully")
}
```

##### 2. XData Blocks (In-Class XML Definition)
Test modules are defined as XML blocks within the test class using ObjectScript's `XData` blocks. These contain the module manifest XML that matches the module.xml format.

###### Implementation Example
```objectscript
Class Test.PM.Integration.Scopes Extends Test.PM.Integration.Base
{
    XData ServerModule1 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
    {
    <?xml version="1.0"?>
    <Module>
      <Name>HS.UNITTEST1</Name>
      <Version>0.0.1</Version>
    </Module>
    }
}
```

###### How to Use in Tests
Call the inherited helper method `ReadXDataToModule()` from the Base test class:
```objectscript
Method TestEverything()
{
    do ..ReadXDataToModule(tOrigNS,"ServerModule1",.tModule)
    // Do some testing...
}
```

### Installer Testing
It may be handy to test creation of an IPM installer as part of your workflow. Here's how to do that locally:

```
docker-compose exec iris bash

iris session iris
zpm "repo -r -name registry -url ""http://registry:52773/registry/"" -username admin -password SYS"
zpm "publish zpm -verbose"
halt

cd /home/irisowner/zpm && wget http://registry:52773/registry/packages/zpm/latest/installer -O zpm.xml
```

Now you have zpm.xml at the top level of your git repo and can test installation from e.g. a full IRIS instance on your host environment. (Don't worry, it's in .gitignore!)

---
### Pull Request (PR)
Before creating a Github PR, make sure you document the changes involved in `CHANGELOG.md` and add unit/integration tests in the `tests/` folder.

