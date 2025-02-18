# Contributing to IPM

To implement new features, enhance existing capabilities, or fix known bugs, you can set up a local environment using one of the following methods:

## Develop IPM inside Docker containers

### Commands
To develop IPM inside Docker containers, we recommend running the following command directly:
```bash
git clone https://github.com/intersystems/ipm
cd /path/to/cloned/ipm
git checkout <target-branch> # consult with other IPM developers on which branch your PR should be targeted
git checkout -b <new-branch-name>
docker compose up -d --build
```
This will spin up 3 (or 4, if you're working on v0.10.x) containers, which are:
-  `ipm-iris-1`, a container that has the repo-version IPM built in the USER namespace, where the management portal (52773) is published to the host OS at 52774. On the Docker network, this container has the hostname `iris`.
-  `ipm-registry-1`, a container with a zpm-registry pre-configured, where the username is `admin`, the password is `SYS`, and the management portal (52773) is published to the host OS at 52775. On the Docker network, this container has the hostname `registry`.
-  `ipm-sandbox-1`, a container with a vanilla IRIS instance, where the management portal (52773) is published to the host OS at 52776. On the Docker network, this container has the hostname `sandbox`.
-  `ipm-oras-1`, a container WITHOUT any IRIS instance. This container is based on [zot](https://github.com/project-zot/zot) and provides an OCI image registry, with port 5000 published to the host OS at 5000. On the Docker network, this container has the hostname `oras`.

### Important notes
-  In both `ipm-iris-1` and `ipm-sandbox-1`, the IPM repo itself is mounted at `/home/iris`.
-  Sometimes `ipm-registry-1` doesn't install zpm-registry properly; you may need to perform the following steps to manually make it work:
  - Run `docker exec -it ipm-registry-1 /bin/bash` to access the container.
  - Inside the container, run `iris session iris` to access the IRIS instance.
  - Inside the IRIS instance, run `zn "REGISTRY"` and `zpm "install zpm-registry"` to install and configure the registry. When this finishes successfully, the registry will be up and running, accessible to other containers at `http://registry:52773/registry`.
-  If any of the ports 52774, 52775, 52776, or 5000 are in use, you may need to modify the port forwarding configuration in `docker-compose.yml`. For example, the macOS `Control Center` app uses this port.
-  If you are on an ARM chip (e.g., M-series Macs), you may need to change the `oras` section in `docker-compose.yml` to use `ghcr.io/project-zot/zot-linux-arm64:latest` instead of `ghcr.io/project-zot/zot-linux-amd64:latest`.
-  The VS Code workspace settings in `.vscode/settings.json` automatically connect to the IRIS instance on 52774. If you didn't change the port mapping in `docker-compose.yml`, when you save and compile changes in VS Code, it should automatically update the `%IPM.*` code in the `USER` namespace of the `ipm-iris-1` container.

### Development
Make any necessary changes, compile them (which should be handled by VS Code on save), and test in the `ipm-iris-1` container by running:
```bash
docker exec -it ipm-iris-1 /bin/bash
$ iris session iris
```
If you need to shut down all the containers (either to switch to another branch or to revert back to a clean state) involved in the `docker-compose.yml`, run the following command in the project folder:
```bash
docker compose down --remove-orphans --volumes
```
From time to time, you may also want to remove unused Docker data to save disk space, as insufficient disk space may cause `docker compose up` to fail.
```bash
docker system prune -a
```

### Testing
There are 2 kinds of tests in IPM -- unit tests and integration tests. You can find all the test cases in the `tests/` folder. 

- To run all the unit tests, use `zpm "zpm test -only -v"`;
- To run all the integrationt tests, use `zpm "zpm verify -only -v"`;

where the `-v` is an optional verbosity flag.

Some tests involve publishing to test registries, such as the ones in `ipm-registry-1` and `ipm-oras-1`. If those tests fail, check if those 2 containers are running on the correct ports and endpoints. Tests also fail for other reasons. Typically, you can run both tests on unchanged codebase to establish a baseline first. After development, if it doesn't incur new failures beyond the baseline, then your changes should be fine. We also have CI to double check all unit/integration tests when you open a pull request.

### Pull Request
Before creating a PR, make sure you document the changes involved in `CHANGELOG.md` and add unit/integration tests in the `tests/` folder.

## Develop IPM in an existing IRIS instance
If you already have an IRIS instance running and you want to test IPM in this instance, run the following command:
```bash
git clone https://github.com/intersystems/ipm
cd /path/to/cloned/ipm
git checkout <target-branch> # consult with other IPM developers on which branch your PR should be targeted
git checkout -b <new-branch-name>

iris session <YOUR-INSTANCE-NAME>
```
Then, inside the container, run:
```objectscript
do $System.OBJ.Load("</path/to/ipm/repo>/preload/cls/IPM/Installer.cls", "ck")
do ##class(IPM.Installer).setup("</path/to/ipm/repo>/", 3)
```

### Caveats
-  If your current instance doesn't run on 52774 with an empty prefix, you need to manually edit VS Code settings (either via GUI or `.vscode/settings.json`) in order to automate VS Code compilation on your instance.
-  When you switch to another Git branch, previous changes may carry over. For example, if you created and compiled a new class `%IPM.MyClass.cls` on branch A and switched to branch B, that class may still be visible in your instance. Consider manually deleting every IPM package using `$System.OBJ.DeletePackage("%IPM")`.

### Testing & Pull Request
Refer to the [Testing](#testing) and [Pull Request](#pull-request) sections for developing IPM inside Docker containers.