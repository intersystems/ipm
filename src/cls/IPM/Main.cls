Include (%syGluedef, %sySecurity, %syPrompt, %IPM.Common, %IPM.Formatting)

IncludeGenerator %IPM.Common

Class %IPM.Main Extends %IPM.CLI
{

Parameter DOMAIN = "ZPM";

Parameter STANDARDPHASES = {$listbuild("reload","compile","test","package","verify","publish","makedeployed","applyupdatesteps")};

/// Description of commands to use for this CLI
XData Commands [ XMLNamespace = "http://www.intersystems.com/PackageManager/CLI" ]
{
<?xml version="1.0"?>
<commands>
<command name="help" aliases="?">
<description>Displays help information for the shell or a particular command.</description>

<!-- Parameters -->
<parameter name="command" description="Command for which help information should be displayed" />

<!-- Modifiers -->
<modifier name="verbose" aliases="v" description="Show full detail" />
<modifier name="markdown" aliases="m" description="Print detail in markdown format (for easy transfer to external documentation)" />
</command>

<command name="quit" aliases="q,exit">
<description>Exits the package manager shell.</description>
</command>

<command name="module-action" default="true" dataPrefix="D" trailingModifiers="true">
<summary>Performs operations on modules - compiling, running tests, packaging/registering, etc.</summary>
<description>
Performs operations on modules - compiling, running tests, packaging/registering, etc.
You can use this by starting a command with the module name.
Note that flags appear *after* all actions.

The standard lifecycle phases are:
* clean: removes all dependencies that are not required by other installed modules and
their resources. Dependencies required by other modules will also be removed if the -DClean.Force=1 flag is specified.
* reload: pulls module source code into the namespace from disk. Does not compile.
* validate: ensures that module resource processor attributes are valid, and that the
resources exported to the filesystem (and possible to source control) are consistent
with what is in the database.
* compile: compiles all resources within the module.
* activate: performs post-compilation installation/configuration steps.
* makedeployed: deploys resources within the module for which deployment is enabled.
* document: regenerates the API documentation for the module
* test: runs any unit tests associated with the module, in the current namespace.
* package: exports the module's resources and bundles them into a module artifact (.tgz file).
* verify: installs that artifact in a separate namespace, then runs integration tests (if any).
* register: saves that artifact into the current namespace's module cache.
This is accessible to other instances configured to look at the current namespace as a
module repository.
* publish: saves that artifact to the repository for which deployment is enabled.
Currently, there may only be one of these per namespace.
* applyupdatesteps: run any update steps for the module to become updated to the latest available version.
Can also specify desired version to update to.
</description>

<!-- Examples -->
<example description="Compiles the module named &quot;MyModuleName&quot;">module-action MyModuleName compile</example>
<example description="Performs multiple actions on the module named &quot;MyModuleName&quot;; &quot;clean&quot; deletes all of its dependenices, and &quot;install&quot; will then re-download them, package the module, and register it in the current namespace's module cache.">MyModuleName clean register</example>
<example description="Compiles the module named MyUIModule with verbose output and pParams(&quot;UIFW&quot;,&quot;force&quot;) (passed to all lifecycle phases) set to 42.">MyUIModule compile -v -DUIFW.force=42</example>
<example description="Verify the module MyModule with the env file /path/to/env.json. The module is responsible for accessing the data using %IPM.General.EnvironmentConfig:GetArg()">MyModule verify -env /path/to/env.json</example>

<!-- Parameters -->
<parameter name="module" required="true" description="Name of module on which to perform lifecycle actions" />
<parameter name="actions" required="true" description="Space-delimited list of module lifecycle phases to run" trailing="true" />

<!-- Modifiers -->
<modifier name="env" aliases="e" dataAlias="EnvFiles" value="true" description="Semicolon separated paths to the environment files in json format. See wiki for details." />
<modifier name="only" aliases="o" description="Only runs the specified phase(s), rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="export-deps" value="true" valueList="0,1" dataAlias="ExportDependencies" description="If specified, controls whether dependencies are exported. If omitted, defaults to the value of the #EXPORTDEPENDENCIES in lifecycle class. This modifier is only used in &quot;Package&quot; and &quot;Publish&quot; lifecycles." />

</command>

<command name="init" aliases="initialize">
<summary>Configures the current namespace for package manager use.</summary>
<description>
Configures new namespace for use of package manager (interactive). This sets up the
local cache and allows for configuration of studio extensions for source control and
the package manager itself. In the case of Perforce-based source control, prompts are
included for username, password, Perforce workspace, and a few other settings.
</description>

<!-- Modifiers -->
<modifier name="noprompt" aliases="quiet,q" description="If specified, no prompts will be shown." />
<modifier name="zpm" aliases="cli" description="If specified, the zpm command will be configured." />
<modifier name="extension" aliases="ext" value="true" description="Generic extension (e.g., extension class for source control) to configure for the current namespace " />
<modifier name="menuextension" aliases="menuext" value="true" description="Server menu extension (Package Manager extension for server menus such as Studio, vscode menu, etc.) to configure for the current namespace" />
</command>

<command name="reload">
<description>
This command is an alias for `module-action module-name reload`
</description>
<parameter name="module" required="true" description="Name of module on which to perform reload action" />
</command>

<command name="compile">
<description>
This command is an alias for `module-action module-name compile`
</description>
<parameter name="module" required="true" description="Name of module on which to perform compile action" />
</command>

<command name="test" dataPrefix="D">
<description>
This command is an alias for `module-action module-name test`
</description>
<parameter name="module" required="true" description="Name of module on which to perform test action" />
</command>

<command name="package" dataPrefix="D">
<description>
This command is an alias for `module-action module-name package`
</description>
<parameter name="module" required="true" description="Name of module on which to perform package actions" />
<modifier name="path" aliases="p" dataAlias="Path" value="true" description="the specified path to export package." />
<modifier name="export-deps" value="true" valueList="0,1" dataAlias="ExportDependencies" description="If specified, controls whether dependencies are exported. If omitted, defaults to the value of the #EXPORTDEPENDENCIES in lifecycle class. This modifier is only used in &quot;Package&quot; and &quot;Publish&quot; lifecycles." />
<modifier name="export-python-deps" dataAlias="ExportPythonDependencies" dataValue="1" description="If specified, exports Python dependencies. If omitted, defaults to false." />
</command>

<command name="verify" dataPrefix="D">
<description>
This command is an alias for `module-action module-name verify`
</description>
<parameter name="module" required="true" description="Name of module on which to perform verify action" />
</command>

<command name="publish" dataPrefix="D">
<description>
This command is an alias for `module-action module-name publish`
</description>
<parameter name="module" required="true" description="Name of module on which to perform publish actions" />
<modifier name="repo" aliases="r" dataAlias="PublishTo" description="Namespace-unique name for the module to publish to (if deployment is enabled)" />
<modifier name="use-external-name" aliases="use-ext" dataAlias="UseExternalName" dataValue="1" description="Publish the package under the &lt;ExternalName&gt; of the package. If ExternalName is unspecified or illegal, an error will be thrown."/>
</command>

<command name="update" dataPrefix="D">
<summary>Updates a module to a newer version.</summary>
<description>
	Updates a module to a newer version. By default, updates to the latest available version. Also runs all of the update steps from the current version to the newer version.
    This command is an alias for module-action module-name applyupdatesteps.
</description>

<!-- Examples -->
<example description="Updates the HS.JSON module from the current version to version 3.0.0.">
	update HS.JSON 3.0.0
</example>

<!-- Parameters -->
<parameter name="module" required="true" description="Name of module on which to perform update actions" />
<parameter name="version" description="Version (or version expression) of module to update; defaults to the latest available if unspecified. Is ignored if -path is provided." />

<!-- Modifiers -->
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="env" aliases="e" dataAlias="EnvFiles" value="true" description="Semicolon separated paths to the environment files in json format." />
<modifier name="path" aliases="p" value="true" description="Location of local tarball containing the updated version of the module. Overrides 'version' parameter if present." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
</command>

<command name="makedeployed">
<description>
This command is an alias for `module-action module-name makedeployed`
</description>
<parameter name="module" required="true" description="Name of module on which to perform reload action" />
<modifier name="recurse" aliases="r" description="Runs the specified phase (makedeployed) on the module and all of its dependencies." />
</command>

<command name="unpublish">
<description>
Delete package from registry
</description>
<example description="Delete all versions of the package &quot;MyModuleName&quot; from the registry">unpublish MyModuleName all</example>
<example description="Delete version &quot;1.0.0&quot; of the package &quot;MyModuleName&quot; from the registry">unpublish MyModuleName 1.0.0</example>
<parameter name="module" required="true" description="Name of module on which to perform unpublish actions" />
<parameter name="version" required="true" description="Version of module on which to perform unpublish actions. Use &quot;all&quot; to delete all versions of the package" />

<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
</command>

<command name="config">
<description>Update ZPM settings. Setting is a key-value pair.</description>
<example description="Disable collecting analytics data">config set analytics 0</example>
<example description="Enable collecting analytics data">config set analytics 1</example>
<example description="list all settings">config list</example>
<example description="get value for analytics key">config get analytics</example>
<example description="reset to default value for analytics key">config delete analytics</example>
<parameter name="action" required="true" description="One of settings actions: list, get, set, delete" />
<parameter name="key" required="false" description="Setting key" />
<parameter name="value" required="false" description="Setting value" />
</command>

<command name="repo" aliases="repository" dataPrefix="D">
<summary>Configures the current namespace to search for modules in a repository.</summary>
<description>
Configures the current namespace to search for modules on a remote server or on the
local filesystem.
</description>

<!-- Examples -->
<example description="List all repositories">
repo -list
</example>
<example description="Delete all repositories">
repo -delete-all
</example>
<example description="Delete the repository named &quot;LocalFiles&quot;">
repo -n LocalFiles -delete
</example>
<example description="Lists all modules (and versions) available from the repository named &quot;AppModules&quot;">
repo -n AppModules -list-modules
</example>
<example description="Enables package manager web services in this namespace via the /csp/mynamespace/ web application, including web services for publishing. Note that security (e.g., authentication settings, required role) should be configured separately as part of this web application.">
repo -enable -app /csp/mynamespace -publish 1
</example>

<!-- Modifiers -->
<!-- Universal Actions -->
<modifier name="delete-all" description="Deletes all repositories (possibly subject to a type filter: e.g -filesystem, -remote, -local)" />
<modifier name="list" description="Lists all repositories (possibly subject to a type filter: e.g. -filesystem, -remote, -local)" />
<modifier name="list-modules" aliases="modules,listmodules" description="List modules available in the specified repository (-n\[ame]), or in all configured repositories if no repository was specified." />
<modifier name="info" description="Shows configuration details for the current namespace as a remote repository." />
<modifier name="copy-from" value="true" description="Copies repository configuration from a different (specified) namespace" />
<!-- General/shared modifiers -->
<modifier name="name" aliases="n" value="true" description="Namespace-unique name for the module" />
<modifier name="delete" description="Deletes the current namespace's reference to the named repository" />
<modifier name="publish" value="true" valueList="0,1" description="When configuring a remote repository, specifies that publishing of packages to the repository is allowed. When configuring the current namespace with -enable, specifies that publishing is also enabled. "/>
<!-- General properties -->
<modifier name="enable" value="false" description="For any repository, specifies that it can be used." />
<modifier name="disable" value="false" description="For any repository, specifies that it can not be used." />
<modifier name="snapshots" aliases="s" value="true" valueList="0,1" description="For any repository, specifies that it should be used to look for snapshot builds (i.e., those with a semantic version ending in '+snapshot', indicating a 'latest' build of a particular version)." />
<modifier name="prereleases" aliases="pre" value="true" valueList="0,1" description="For any repository, specifies that it should be used to look for prerelease software" />
<modifier name="read-only" aliases="ro" value="true" valueList="0,1" description="For any repository, specifies that modules installed from it are ALWAYS installed in non-developer mode, effectively making them read only" />
<!-- Repository types  -->
<modifier name="type" value="true" aliases="t" description="Subclass of %IPM.Repo.Definition to create/modify/delete or implementation of %IPM.Repo.IPackageService or %IPM.Repo.IPublishService to enable/disable" />

</command>

<command name="load" dataPrefix="D">
<summary>
Loads a module from the specified directory into the current namespace.
</summary>
<description>
Loads a module from the specified directory into the current namespace.
Dependencies are also loaded automatically, provided that they can be found in
repositories configured with the 'repo' command.
</description>

<!-- Examples -->
<example description="Loads the module described in C:\module\root\path\module.xml">
load C:\module\root\path\
load C:\module\root\path\module-0.0.1.tgz
load C:\module\root\path\module-0.0.1.tar.gz
</example>
<example description="Loads the module described in C:\module\root\path\module.xml in developer mode and with verbose output.">
load -dev -verbose C:\module\root\path\
load -dev -verbose C:\module\root\path\module-0.0.1.tgz
</example>
<example description="Loads the module in branch feature-1 from remote repository https://github.com/user/repository.git.">
load https://github.com/user/repository.git
load https://github.com/user/repository.git -branch feature-1
</example>
<example description="Loads the module described in C:\module\root\path\module.xml without installing python dependencies">
    load -bypass-py-deps C:\module\root\path\
</example>
<example description="Loads the module described in C:\module\root\path\module.xml but set pip timeout to 30 seconds">
    load -extra-pip-flags "--timeout 30" C:\module\root\path\
</example>
<example description="Loads the module described in C:\module\root\path\module.xml using the C:\path\to\env.json1 and C:\path\to\env.json2 as the install time configuration">
load C:\module\root\path -env C:\path\to\env1.json;C:\path\to\env2.json
</example>


<!-- Modifiers -->
<modifier name="env" aliases="e" dataAlias="EnvFiles" value="true" description="Semicolon separated paths to the environment files in json format. See wiki for details." />
<modifier name="branch" aliases="b" dataAlias="Branch" value="true" description="The name of the branch in the repository" />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set. In addition, transactions will not be rolled back if installation fails." />
<modifier name="nodev" dataAlias="DeveloperMode" dataValue="0" description="Disables the DeveloperMode flag for the module's lifecycle." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="bypass-py-deps" dataAlias="BypassPyDeps" dataValue="1" description="Skip installing python dependencies" />
<modifier name="extra-pip-flags" dataAlias="ExtraPipFlags" value="true" description="Extra flags to pass to pip when installing python dependencies. Surround the flags (and values) with quotes if spaces are present. Default flags are &quot;--target &lt;target&gt; --python-version &lt;pyversion&gt; --only-binary=:all:&quot;." />
<modifier name="synchronous" value="false" description="Load the module in a single process, rather than using the default multi-process loading." />
<modifier name="force" aliases="f" value="false" description="Allows the user to load a newer version of an existing module without running update steps." />

<!-- Parameters -->
<parameter name="path" required="true" description="Directory on the local filesystem, containing a file named module.xml" />

</command>

<command name="import">
<description>Imports classes from a file or file(s), reexporting to source control if needed.</description>

<!-- Examples -->
<example description="Import and compile the class or classes from the given file">
    import C:\Temp\MyExport.xml
</example>
<example description="Import the classes from the given directory, located at its root level only. Classes are loaded but not compiled.">
    import C:\Temp\MyFlatExportDir\ -norecurse -nocompile
</example>

<!-- Parameters -->
<parameter name="source" description="File or directory to import" required="true" />

<!-- Modifiers -->
<modifier name="quiet" aliases="q" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" description="Produces verbose output from the command." />
<modifier name="norecurse" description="If importing a directory, do not recurse (default is to load directories recursively)" />
<modifier name="nocompile" description="Skip compiling imported classes (default is to compile them)" />

</command>

  <command name="run-from-file" aliases="run">
<summary>Runs Package Manager Shell commands provided in a file.</summary>
<description>
        Imports either a text file or a JSON file that contains Package Manager Shell commands and runs them sequentially
        in the current namespace.
        Expected format if the file is a text file (with a .txt extension):
        Each line of the file should contain a single command to be run
        Expected format if the file is a JSON file (with a .json extension):
        The file must contain a single array whose items are JSON objects matching the following format -
        {
            "command": "command name",
            "parameters": { ... },
            "modifiers": { ... },
            "custom_modifiers": { ... }
        }
        where each nested object contains key-value pairs. Note that for modifiers that have no value associated with them
        (such as -verbose), the value of the key-value pair for the modifier is ignored.
</description>

<!-- Examples -->
<example description="Run the commands present in the text file.">
run-from-file C:\Temp\MyCommands.text, where contents of the file are as follows:
    repo -name Test -p4 -path //Users/test/
    install -dev TestModule -latest -DNoMapping=1 -DDeploy.Parameter="TESTDEPLOY"
</example>
<example description="Run the commands present in the JSON file.">
run C:\Temp\MyCommands.json, where contents of the file are as follows:
    {
        "commands": [
            {
                "command": "repo",
                "modifiers": {
                    "name": "Test",
                    "p4": "",
                    "path": "//Users/test/"
                }
            },
            {
                "command": "install",
                "parameters": {
                    "module": "TestModule"
                },
                "modifiers": {
                    "dev": "",
                    "latest": ""
                },
                "custom_modifiers": {
                    "NoMapping": 1,
                    "Deploy.Parameter": "TESTDEPLOY"
                }
            }
        ]
    }
</example>

<!-- Parameters -->
<parameter name="file" description="File to import" required="true" />

<!-- Modifiers -->
<modifier name="dry-run" aliases="d" description="Does not actually run the commands. Simply displays what would be run." />

</command>

<command name="install" dataPrefix="D">
<description>Installs a module available in a configured repository.</description>

<!-- Examples -->
<example description="Installs the most recent 1.x version of HS.JSON available in any configured repository in the current namespace.">
    install HS.JSON 1.x
</example>
<example description="Installs HS.JSON without installing python dependencies">
    install -bypass-py-deps HS.JSON
</example>
<example description="Installs HS.JSON but set pip timeout to 30 seconds">
    install -extra-pip-flags "--timeout 30" HS.JSON
</example>
<example description="Installs example-package using the /path/to/env1.json and /path/to/env2.json as the install time configuration">
install -env /path/to/env1.json;/path/to/env2.json example-package
</example>

<!-- Parameters -->
<parameter name="module" required="true" description="Name of module to install" />
<parameter name="version" description="Version (or version expression) of module to install; defaults to the latest available if unspecified." />

<!-- Modifiers -->
<modifier name="env" aliases="e" dataAlias="EnvFiles" value="true" description="Semicolon separated paths to the environment files in json format. See wiki for details." />
<modifier name="latest" aliases="l" description="Installs the latest available version of this module without prompting the user." />
<modifier name="prompt" aliases="p" description="Prompts user which version to install, if more then one found." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set. In addition, transactions will not be rolled back if installation fails." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="keywords" aliases="k" value="true" description="Searches for modules matching some set of keywords." />
<modifier name="bypass-py-deps" dataAlias="BypassPyDeps" dataValue="1" description="Skip installing python dependencies" />
<modifier name="extra-pip-flags" dataAlias="ExtraPipFlags" value="true" description="Extra flags to pass to pip when installing python dependencies. Surround the flags (and values) with quotes if spaces are present. Default flags are &quot;--target &lt;target&gt; --python-version &lt;pyversion&gt; --only-binary=:all:&quot;."/>
<modifier name="synchronous" value="false" description="Load the module in a single process, rather than using the default multi-process loading." />
<modifier name="force" aliases="f" value="false" description="Allows the user to install a newer version of an existing module without running update steps." />

</command>

<command name="reinstall" dataPrefix="D">
<summary>Reinstalls the already installed version of the provided module.</summary>
<description>
    Reinstalls an already-installed module from the latest version available in a configured
    repository. By default, updates dependencies of that module as well.
</description>

<!-- Examples -->
<example description="Reinstalls the currently-installed version of the MyTestModule module, in development mode">
    reinstall -dev MyTestModule
</example>
<example description="Reinstalls the currently-installed vresion of the MyTestModule module without reinstalling python dependencies">
    reinstall -bypass-py-deps MyTestModule
</example>
<example description="Reinstalls MyTestModule but set pip timeout to 30 seconds">
    reinstall -extra-pip-flags "--timeout 30" MyTestModule
</example>
<example description="Reinstalls example-package using the /path/to/env1.json and /path/to/env2.json as the install time configuration">
reinstall -env /path/to/env1.json;/path/to/env2.json example-package
</example>

<!-- Parameters -->
<parameter name="module" required="true" description="Name of module to reinstall" />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />

<!-- Modifiers -->
<modifier name="env" aliases="e" dataAlias="EnvFiles" value="true" description="Semicolon separated paths to the environment files in json format. See wiki for details." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="shallow" aliases="s" dataAlias="UpdateSnapshots" dataValue="0" description="Suppresses updating of dependencies with '+snapshot' versions." />
<modifier name="bypass-py-deps" dataAlias="BypassPyDeps" dataValue="1" description="Skip installing python dependencies" />
<modifier name="extra-pip-flags" dataAlias="ExtraPipFlags" value="true" description="Extra flags to pass to pip when installing python dependencies. Surround the flags (and values) with quotes if spaces are present. Default flags are &quot;--target &lt;target&gt; --python-version &lt;pyversion&gt; --only-binary=:all:&quot;."/>

</command>

<command name="uninstall" dataPrefix="D">
<summary>Uninstalls a module currently installed in this namespace.</summary>
<description>
    Uninstalls a module currently installed locally. This will be prevented if other modules
    depend on the named module, unless the -force flag is specified.
</description>

<!-- Examples -->
<example description="Uninstalls HS.JSON from the current namespace.">
    uninstall HS.JSON
</example>

<!-- Parameters -->
<parameter name="module" description="Name of module to uninstall" />

<!-- Modifiers -->
<modifier name="all" aliases="a" description="Uninstalls all modules installed in the current namespace." />
<modifier name="global" aliases="g" dataAlias="Clean.GlobalScope" dataValue="1" description="Also uninstalls modules with 'global scope' (available in all namespaces); by default, these are skipped." />
<modifier name="force" aliases="f" description="If specified, the module will be uninstalled even if other modules depend on it." />
<modifier name="recurse" aliases="r" description="Also recursively uninstall dependencies. By default, will not uninstall dependencies that are also required by other installed modules; the -force flag overrides this." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="purge" dataAlias="Purge" dataValue="1" description="Purge data from tables during uninstall." />

</command>

<command name="exec" aliases="cos">
<description>
    Executes the provided ObjectScript expression.
</description>

<!-- Examples -->
<example description="Run the Objectscript expression to set the namespace to MYAPP">
    cos set $Namespace = "MYAPP"
</example>

<!-- Parameters -->
<parameter name="expression" required="true" trailing="true" description="ObjectScript expression(s) to execute" />

</command>

<command name="orphans">
<description>
    Lists resources in the current namespace's default code database that are not part of any module.
</description>

<!-- Examples -->
<example description="List resources that are classes that are not part of any module in the current namespace">
    orphans -type CLS
</example>

<!-- Modifiers -->
<modifier name="type" aliases="t" value="true" description="Type (e.g., extension) of resource to show; if unspecified, all types are included." />

</command>

<command name="list-installed" aliases="list">
<description>
    Lists modules installed in the current namespace.
</description>

<!-- Examples -->
<example description="Shows all installed modules in tree format.">
    list-installed -tree
</example>

<!-- Parameters -->
<parameter name="searchString" description="Search string, * can be used." />

<!-- Modifiers -->
<modifier name="tree" aliases="t" description="If specified, show dependency tree for installed modules." />
<modifier name="description" aliases="d" dataAlias="Desc" dataValue="1" description="Additional information is displayed for each module." />
<modifier name="showsource" aliases="ss" description="If specified, show dependency list with local source for installed modules." />
<modifier name="showtime" aliases="st" description="If specified, show the time of last update for each module" />
<modifier name="showupstream" aliases="su" description="If specified, show the latest version for each module in configured repos if it's different than the local version." />
<modifier name="repository" aliases="repo" value="true" description="If specified, only show modules installed that belong to the provided repository." />

</command>

<command name="list-dependents" aliases="dependents">
<description>
    Lists modules dependent on the specified module.
</description>

<!-- Examples -->
<example description="Lists all currently-installed modules dependent on all 'HS.JSON' versions">
    list-dependents HS.JSON
</example>
<example description="Lists all currently-installed modules in the 'AppModules' repository dependent on all 'HS.JSON' versions">
    list-dependents -repos AppModules HS.JSON
</example>
<example description="Lists all currently-installed modules in the 'AppModules' repository dependent on 'HS.JSON' version '0.0.1+snapshot', as a tree">
    dependents -t -r AppModules HS.JSON 0.0.1+snapshot
</example>

<!-- Parameters -->
<parameter name="module" required="true" description="Name of module for which dependent modules will be found" />
<parameter name="version" description="Version of the module for which dependent modules will be found (in all configured repositories)" />

<!-- Modifiers -->
<modifier name="tree" aliases="t" description="If specified, show as a tree (rather than a flattened list)" />
<modifier name="repos" aliases="r" value="true" description="Comma-separated list of repository names to search in. If unspecified, the version of the module in the current namespace will be used instead." />

</command>

<command name="default-modifiers" dataPrefix="D">
<description>
    Manages default modifiers to use for all package manager commands in the current namespace.
</description>

<!-- Modifiers -->
<modifier name="set" description="Set the default modifiers to the provided modifiers. Note: this just appends to existing modifiers. DOES NOT delete any defaults." />
<modifier name="get" description="Prints the default modifiers to the current device." />
<modifier name="delete" description="Deletes all registered default modifiers." />

<!-- Examples -->
<example description="Set custom modifiers -DNoTransaction=1 and -DUpdateSnapshots=1 with every package manager command">
    default-modifiers -set -DNoTransaction=1 -DUpdateSnapshots=1
</example>
<example description="Get currently set custom modifiers.">
    default-modifiers -get
</example>
<example description="Delete currently set custom modifiers.">
    default-modifiers -delete
</example>
</command>

<command name="arrange">
<description>
    Rearranges the resources in a module manifest to follow the standard format.
</description>

<!-- Parameters -->
<parameter name="module" description="Name of module to rearrange" />

<!-- Modifiers -->
<modifier name="all" description="If specified, rearrange all modules loaded in development mode (rather than just the current one)." />
</command>

  <command name="dependency-analyzer" aliases="deps">
      <summary>
        Computes references to other items/modules for a given module/item.
    </summary>
    <description>
        For a module, inspects all items in the provided module and checks for invalid references to items
        that are not in the module and not in any of the module's dependencies.
        For an item, finds all its references to other items, or optionally list
        just the invalid references of the item as well.
        Dependency analyzer supports .cls and .inc items. Other item types are not yet supported.
        The references are written to the current device.
    </description>
    <!-- Parameters -->
    <parameter name="moduleOrItem" required="true" description="Name of module / item to inspect" />
    <!-- Modifiers -->
    <modifier name="invalid-only" value="true" description="Will only be applied when the input is an item name. Default to 1, i.e default to show invalid references only. If specified to 0, will show all references to the item." />
  <modifier name="ignore-str" value="true" description="If specified, ignore specific string references provided as a comma-separated string, including class names" />
    <modifier name="ignore-str-all" description="If specified, ignore all string references, including class names" />
  <modifier name="direct-deps-only" description="If specified, flag references based on direct dependencies only instead of allowing for transitive dependencies" />
    <!-- Examples -->
    <example description="Runs the dependency analyzer on the module MyModuleName to find invalid references, and ignore string references MyClassName1 and MyClassName2.">
        deps MyModuleName -ignore-str MyClassName1,MyClassName2
    </example>
    <example description="Runs the dependency analyzer on item MyClassName3.cls to find all its references, and ignore all string references.">
        deps MyClassName3.cls -invalid-only 0 -ignore-str-all
    </example>
    <example description="Runs the dependency analyzer on item MyIncludeName.inc to find all invalid references in it.">
        deps MyIncludeName.inc
    </example>
  </command>


<command name="version" aliases="ver">
<description>
    Prints the currently-installed package manager and registry version (excluding +snapshot or other build information)
</description>
</command>

<command name="generate" aliases="gen">
<description>Generates module.xml</description>
<example description="Generates module.xml for your module in interactive mode ">generate</example>
<example description="Generates template in the specified folder /my/path">generate -t /my/path</example>
<example description="Export CLS,MAC,INC,DFI in the specified folder /my/path/src">
generate /my/path -export 00000,PacketName2,IgnorePacket2^00000,PacketName3,IgnorePacket3
 byte=1 isGenerated
 byte=2 isSystem
 byte=3 isPercented
 byte=4 isMapped
 byte=5 isDFI
</example>
<modifier name="template" aliases="t" description="Generates module.xml template in the specified folder" />
<modifier name="author" aliases="a" description="Request information about the author" />
<parameter name="path" description="Directory on the local filesystem, containing a file named module.xml" />
<modifier name="export" aliases="e" value="true" description="Export resource in path" />
</command>

<command name="search" aliases="find">
<description>Shows all modules in current registry or namespaces</description>
<example description="Shows all modules in current registry">search -r</example>
<modifier name="show-repo" aliases="r" dataAlias="Repo" dataValue="1" description="Shows github repository only for each module." />
<modifier name="description" aliases="d" dataAlias="Description" dataValue="1" description="Shows description for each module." />
<modifier name="versions" dataAlias="AllVersions" dataValue="1" description="Shows all versions for each module." />

<parameter name="searchString" description="Search string, * can be used" />
<example description="Shows a description of all modules in the name of which there is a context">find -d *tools*</example>
</command>

<command name="namespace" aliases="zn">
<description>See list modules in namespace and go to the namespace</description>
<example description="Show all modules in all namespaces">zn *</example>
<example description="Show all modules in namespaces by context">zn sql*</example>
<parameter name="name" description="Name namespace, * or context name*" />
<modifier name="description" aliases="d" dataAlias="Description" dataValue="1" description="Shows description for each module." />
</command>

    <command name="enable">
        <summary>
            Enable IPM in other namespaces.
        </summary>
        <!-- Modifiers -->
        <modifier name="version" aliases="v" value="true" description="A special version of IPM can be provided. If not specified, the latest version from the registry will be installed (hence is not required if quiet flag is set)."/>
        <modifier name="namespaces" aliases="ns" value="true" description="Comma-separated namespaces in which IPM needs to be enabled."/>
        <modifier name="globally" aliases="g" description="Will install IPM in all explicit namespaces that currently do not have IPM installed. Unless using it together with the -map option, will not include %SYS. By default, this modifier is not set and will not install globally."/>
        <modifier name="local-only" description="If specified, only local artifacts will be used for installation. By default, this modifier is not set and will not limit to local artifacts." />
        <modifier name="allow-upgrade" description="If specified, will also check for IPM version in specified namespaces and upgrade if version is lower than the target version. By default, this modifier is not ste and will not allow upgrade." />
        <modifier name="map" aliases="m" description="If specified, will map IPM code from the current namespace-default code database rather than installing a separate copy." />
        <modifier name="repos" aliases="r" description="If specified, will map repository settings across namespaces. Must be used together with -map." />
        <modifier name="remote" value="true" description="If specified, will use fetch IPM versions from this remote repository. If this is omitted and multiple remote repositories are present, an error will occur." />
        <modifier name="quiet" aliases="q" description="Quiet mode. By default, this modifier is not set and will display the contents onto the terminal/caller command line." />
        <modifier name="preview" aliases="p" description="Preview what will be changed without actually making the changes." />
        <modifier name="community" description="If specified, will reset repository to the community repository and map IPM to all namespaces along with the repository settings. This is functionaly equivalent to &quot;repo -delete-all&quot;, &quot;repo -reset-defaults&quot;, and &quot;enable -map -repos -globally&quot;. With this modifier, all other modifiers will be ignored."/>
        <!-- Examples -->
        <example description="Make IPM available in all namespaces (including %SYS) by mapping the version in the current namespace default routine database. Namespace-specific installation will override this.">
            enable -map -globally
        </example>
        <example description="Install IPM version 0.3.4 from the remote registry namd &quot;registry&quot; in quiet mode in namespaces: NS1, NS2, NS3.">
            enable -v 0.3.4 -q -ns NS1,NS2,NS3 -remote registry
        </example>
        <example description="Install IPM in all non-%SYS explicit namespaces, and select version later in terminal prompt menu. This works if there is only 1 remote repository configured.">
            enable -globally
        </example>
        <example description="User wants to get the latest version of IPM from the registry server, and install it in all non-%SYS explicit namespaces. This works if there is only 1 remote repository configured.">
            enable -v latest -globally
        </example>
        <example description="Install or upgrade IPM to latest IPM version in namespaces: NS1, NS2, NS3. This works if there is only 1 remote repository configured.">
            enable -v latest -allow-upgrade NS1,NS2,NS3
        </example>
        <example description="Reset repository to the community repository and map IPM to all namespaces along with the repository settings.">
            enable -community
        </example>
    </command>

<command name="unmap">
    <summary>Unmap %IPM package and routines in specified namespaces.</summary>
    <description>
        Unmap %IPM package and routines in specified namespaces. Will Skip non-mapped namespaces.
        If repository settings are mapped, will also unmap repository settings.
    </description>
    <modifier name="namespaces" aliases="ns" value="true" description="Comma-separated namespaces in which IPM mapping needs to be deleted."/>
    <modifier name="globally" aliases="g" description="Will unmap IPM in all explicit namespaces that currently do not have IPM installed."/>
    <modifier name="quiet" aliases="q" description="Quiet mode. By default, this modifier is not set and will display the contents onto the terminal/caller command line." />
    <modifier name="repos-only" description="If specified, will only unmap repository settings across namespaces. This doesn't affect mapping of IPM packages and routines." />
    <example description="Unmap IPM from namespaces NS1, NS2, NS3.">
        unmap -ns NS1,NS2,NS3
    </example>
    <example description="Unmap IPM from all namespaces">
        unmap -g
    </example>
</command>

<command name="module-version" aliases="modver">
    <description>
        Updates the version of the module in the current namespace.
    </description>
    <parameter name="module" required="true" description="Name of the module to update the version for." />
    <parameter name="version" description="Either a valid SemVer string, or 'major', 'minor', 'patch'. If it's 'major', 'minor', or 'patch', will bump the cooresponding part of SemVer." />

    <modifier name="prerelease" value="true" aliases="p" description="Set the prerelease to a specific value" />
    <modifier name="build" value="true" aliases="b" description="Set the build to a specific value" />
    <modifier name="force" description="Permit the version to be downgraded. By default, trying to downgrade the version will fail" />
    <modifier name="quiet" aliases="q" description="Suppress output (except for errors)" />

    <example description="Sets the version of the module HS.JSON to 1.2.3">
        module-version HS.JSON 1.2.3
    </example>
    <example description="Bump the major version the module HS.JSON. If current version is 1.2.3, the new version will be 2.0.0">
        module-version HS.JSON major
    </example>
    <example description="Bump the minor version and set prerelease to 'alpha' and build to 'xyz'. If current version is 1.2.3, the new version will be 1.3.0-alpha+xyz">
        module-version HS.JSON minor -prerelease alpha -build xyz
    </example>
    <example description="Downgrade the version to 1.2.3. If the current version is 1.3.0, this will still work because the force flag is set.">
        module-version HS.JSON 1.2.3 -force
    </example>
</command>

<command name="information" aliases="info">
    <description>Output information about the current ZPM environment.</description>
    <modifier name="verbose" aliases="v" description="Show more detailed information"/>
    <example description="Show basic information about the current ZPM environment">
        info
    </example>
    <example description="Show detailed information about the current ZPM environment">
        info -verbose
    </example>
</command>

<command name="history" aliases="log" dataPrefix="D">
	<summary>Manage history of package installation/uninstallation.</summary>
	<description>Manage history of package installation/uninstallation. Commands logged are install, load, and uninstall. By default, all entries will be affected. To specify filters, use the -Dcol=val syntax. See examples for more.</description>
	<modifier name="globally" aliases="g" description="If specified, will affect all namespaces instead of the current one. Defaults to false."/>
	<modifier name="sort" aliases="asc" value="true" description="List the history logs in a specific order. Allowed values are asc and desc. Default behaviour is to list logs in descending order of %ID."/>
	<modifier name="limit" value="true" description="If specified, will only list the specified number of logs. If set to 0, all logs will be displayed. If omitted, will use the value returned by `zpm &quot;config get DefaultLogEntryLimit&quot;`."/>
	<modifier name="confirm" value="false" description="If present, will delete all records in the current namespace. Ignored if -globally is passed too."/>
	<parameter name="action" required="true" description="One of history actions: find (default), details, delete, schema" />
	<parameter name="argument" required="false" description="Argument for `details` command" />
	<example description="Show history of all packages in the current namespace in descending order">history find </example>
	<example description="Show history of all packages in the current namespace where command starts with &quot;load&quot;">history find -DCommandString="load*"</example>
	<example description="Show history of all packages in the current namespace where start time is later than 2000-01-01 00:00:00">history find -DTimeStart=">2000-01-01 00:00:00"</example>
	<example description="Show 5 history records in the current namespace in ascending order">history find -sort asc -limit 5</example>
	<example description="Show column names that the table can be filtered by">history schema</example>
	<example description="Show only installation history of package &quot;zpip&quot; in the current namespace ">history find -Daction=install -Dpackage=zpip</example>
	<example description="Show only installation history of package &quot;zpip&quot; in all namespaces ">history find -globally -Daction=install -Dpackage=zpip</example>
	<example description="Delete all histories in the namespace">history delete -confirm</example>
	<example description="Show details of history item with ID 3">history details 3</example>
</command>

</commands>
}

ClassMethod %GetCommandStructure(Output pCommandStructure)
{
  do ..%GetOneCommandStructure(.pCommandStructure)

  do ##class(%IPM.Repo.Definition).%GetCommandStructure(.tCommandStructure)
  merge pCommandStructure("repo") = tCommandStructure("repo")
}

/// @API.Method
ClassMethod Shell(
	pCommand As %String = "",
	pTerminateOnError As %Boolean = 0,
	pHaltOnComplete As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    do ..ShellInternal(pCommand,.tException)
    if $isobject(tException) {
        if pTerminateOnError {
            do $system.Process.Terminate($job,1)
        }
        set tSC = tException.AsStatus()
    }
    if pHaltOnComplete {
        halt
    }
    quit tSC
}

ClassMethod TerminalPrompt() As %String
{
    set tp=##class(%SYSTEM.Process).TerminalPrompt()
    set prompt="zpm:"
    set del=$$$FormattedLine(..TerminalPromptColor(),">")
    if ..TerminalPromptColor()=$$$Default { set tp=2 }
    for i=1:1:$length(tp,",") {
        if $piece(tp,",",i)=1 {	set prompt=prompt_$piece($system,":")_del continue}
        elseif $piece(tp,",",i)=2 {	set prompt=prompt_$namespace_del continue}
        elseif $piece(tp,",",i)=3 {	set prompt=prompt_$piece($system,":",2)_del continue}
        elseif $piece(tp,",",i)=4 {	set prompt=prompt_$ztime(+$piece($horolog,",",2),1)_del continue}
        elseif $piece(tp,",",i)=5 {	set prompt=prompt_$job_del continue}
        elseif $piece(tp,",",i)=8,$tlevel { set prompt=prompt_"TL"_$tlevel_del continue}
        // for zpm shell 7 do not need to be implemented
    }
    quit prompt
}

/// @API.Method
/// Get Version modules and current registry
/// example do ##class(%IPM.Main).GetVersion("zpm,zpm-registry",.out,.list)
ClassMethod GetVersion(
	ModuleName,
	ByRef out,
	list)
{
    do ..GetListModules("*", ModuleName, .list)
    for i=1:1 {
        quit:'$data(list(i),ns)
        set ns=$listget(ns,1)
        for ii=1:1 {
            quit:'$data(list(i,"modules",ii),module)
            set out($listget(module,1))=$listbuild(ns,$listget(module,2))
        }
    }
    set sc=$$$OK
    set sql="select URL from %IPM_Repo_Remote.Definition where Enabled = 1" _
        " union " _
        "select URL from %IPM_Repo_Oras.Definition where Enabled = 1"
        ,rs=##class(%ResultSet).%New()
        ,sc=rs.Prepare(sql)
    set:sc sc=rs.Execute("")
    if sc {
        quit:'rs.%Next()
        set out=$zconvert(rs.Get("URL"),"l")
    }
    quit sc
}

ClassMethod GetSystemMode()
{
    new $namespace
    set $namespace = "%SYS"
    if $$$ISOK(##class(Config.Startup).Get(.tProperties)) {
        quit $get(tProperties("SystemMode"))
    }
    quit ""
}

/// Return a list of messages to display when the shell is first started
/// For messages that are too long to fit in a box, they should be returned in the outOfBoxMessage parameter
ClassMethod BuildIntroMessages(Output outOfBoxMessage As %String) As %List
{
    set cls = "%ZHSLIB.HealthShareMgr", mthd = "VersionInfo"
    if $system.CLS.IsMthd(cls, mthd) {
        set outOfBoxMessage = $classmethod(cls, mthd)
    } else {
        set outOfBoxMessage = $zversion
    }

    do ##class(%IPM.Main).GetVersion($$$IPMModuleName,.out)
    if $get(out) = "" {
        set registryInfo = $$$FormattedLine($$$Cyan, "No registry configured")
    } else {
        set registryInfo = "Current registry "_$$$FormattedLine($$$Cyan, out)
    }

    set systemMode = ..GetSystemMode()
    if systemMode = "" {
        set systemMode = "System Mode: <unset>"
    } else {
        set systemMode = "System Mode: " _ systemMode
    }

    set mirrorStatus = $system.Mirror.GetStatus()
    set mirrorStatus = "Mirror Status: " _ mirrorStatus

    set list = $listbuild(
        "Welcome to the Package Manager Shell (ZPM). Version: "_$$$FormattedLine($$$Green, ..GetVersionModule($$$IPMModuleName)),
        "Enter q/quit to exit the shell. Enter ?/help to view available commands",
        registryInfo,
        systemMode,
        mirrorStatus
    )
    quit list
}

/// For use in unit tests that need to test if a command threw any exceptions.
ClassMethod ShellInternal(
	pCommand As %String,
	Output pException As %Exception.AbstractException) [ Internal ]
{
    new $$$DeprecationWarned
    // Keep a reference of the singleton, so subsequent .%Get() calls return the same instance
    set configReference = ##class(%IPM.General.EnvironmentConfig).%Get()

    set pException = $$$NULLOREF
    set tOneCommand = 0
    set tCommand = $get(pCommand)
    if (tCommand '= "") {
        set tOneCommand = 1
    }
    set introMessageList = ..BuildIntroMessages(.outOfBoxMessage)
    set tInShell = 0
    for {
        kill $$$DeprecationWarned
        try {
            // Have intro message just for first entrance to shell
            // Ensure not displayed if its just one command
            if 'tInShell && 'tOneCommand {
                do ..DrawBorder(introMessageList, ..TerminalPromptColor())
                write $get(outOfBoxMessage),! // Display long messages outside of the box
                set tInShell = 1
            }
            if (tCommand = "") {
                write ..TerminalPrompt()
                read tCommand
                write !
            }
            if (tCommand = "") {
                #; Do ..%Help()
                quit
            }
            kill tCommandInfo
            // Parse command
            $$$ThrowOnError(..%ParseCommandInput(tCommand,.tParsedCommandInfo))

            // Merge defaults first so they can be overwritten by commands
            do ..GetNamespaceDefaultModifiers(.tDefaultArray)
            merge tCommandInfo("data") = tDefaultArray
            merge tCommandInfo = tParsedCommandInfo

			// Stashed for use in %IPM.General.History:Init
			new $$$ZPMCommandToLog
			set $$$ZPMCommandToLog = tCommand

            if (tCommandInfo = "quit") {
                return
            } elseif (tCommandInfo = "help") {
                do ..%Help(.tCommandInfo)
            } elseif (tCommandInfo = "init") {
                do ..Init(.tCommandInfo)
            } elseif (tCommandInfo = "search") {
                do ..Search(.tCommandInfo)
            } elseif (tCommandInfo = "repo") {
                do ..Repository(.tCommandInfo)
            } elseif (tCommandInfo = "load") {
                do ..Load(.tCommandInfo)
            } elseif (tCommandInfo = "exec") {
                write !
                xecute tCommandInfo("parameters","expression")
            } elseif (tCommandInfo = "install") {
                do ..Install(.tCommandInfo)
            } elseif (tCommandInfo = "reinstall") {
                do ..Reinstall(.tCommandInfo)
            } elseif (tCommandInfo = "uninstall") {
                do ..Uninstall(.tCommandInfo)
            } elseif (tCommandInfo = "list-installed") {
                do ..ListInstalled(.tCommandInfo)
            } elseif (tCommandInfo = "list-dependents") {
                do ..ListDependents(.tCommandInfo)
            } elseif (tCommandInfo = "orphans") {
                do ..ListOrphans(.tCommandInfo)
            } elseif (tCommandInfo = "default-modifiers") {
                do ..ProcessDefaultModifiers(.tCommandInfo)
            } elseif (tCommandInfo = "arrange") {
                do ..Arrange(.tCommandInfo)
            } elseif (tCommandInfo = "import") {
                do ..Import(.tCommandInfo)
            } elseif (tCommandInfo = "run-from-file") {
                do ..ProcessRunFromFile(.tCommandInfo)
            } elseif (tCommandInfo = "dependency-analyzer") {
                do ..RunDependencyAnalyzer(.tCommandInfo)
            } elseif (tCommandInfo = "config") {
                do ..Config(.tCommandInfo)
            } elseif (tCommandInfo = "unpublish") {
                do ..Unpublish(.tCommandInfo)
            }  elseif (tCommandInfo = "update") {
                do ..Update(.tCommandInfo)
            } elseif ($listfind(..#STANDARDPHASES,tCommandInfo)) {
                do ..RunOnePhase(.tCommandInfo)
            } elseif (tCommandInfo = "generate") {
                do ..GenerateModuleXML(.tCommandInfo)
            } elseif (tCommandInfo = "module-action") {
                do ..ModuleAction(.tCommandInfo)
            } elseif (tCommandInfo = "version") {
                do ..Version(.tCommandInfo)
            } elseif (tCommandInfo = "namespace") {
                do ..Namespace(.tCommandInfo)
            } elseif (tCommandInfo = "enable") {
                do ..EnableIPM(.tCommandInfo)
            } elseif (tCommandInfo = "unmap") {
                do ..UnmapIPM(.tCommandInfo)
            } elseif (tCommandInfo = "module-version") {
                do ..ModuleVersion(.tCommandInfo)
            } elseif (tCommandInfo = "information") {
                do ..Information(.tCommandInfo)
			} elseif (tCommandInfo = "history") {
				do ..History(.tCommandInfo)
            }
        } catch pException {
            if (pException.Code = $$$ERCTRLC) {
                set pException = $$$NULLOREF
                return
            }
            do ..DisplayError(pException.AsStatus())
        }
        set tCommand = ""
        if tOneCommand {
            quit
        }
        write !
    }
}

ClassMethod DisplayError(pStatus As %Status)
{
    if $$$ISERR(pStatus) {
        write !,$$$FormattedLine($$$Red, "ERROR!")
        write " ",$system.Status.GetOneStatusText(pStatus)
    }
}

/// Show modules in Namespace and to go namespace
ClassMethod Namespace(ByRef pCommandInfo) [ Internal ]
{
    set name = $translate($get(pCommandInfo("parameters","name"),"*"),$char(34))
    if (name'["*") {
        try {
            set $namespace = name
        } catch ex {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to switch to namespace: " _ name))
        }
        quit
    }

    set currentns = $namespace
    set showFields = ""
    if $get(pCommandInfo("data","Description")) {
        set showFields = $listbuild("Description")
    }

    do ..GetListModules(name, , .list, showFields)
    do ..DisplayModules(.list, 1, 1)

    write !
    set prompt = "Enter number or name where to go:"
    do {
        set value = ""
        do ##class(%Library.Prompt).GetString(prompt, .value)
        quit:value=""
        try {
            set $namespace = $select($data(list(value), ns): $listget(ns), 1: value)
        } catch e {
            write $char(13),*27,"[K",*27,"[A"
            continue
        }
        quit
    } while 1
    write $char(13),*27,"[K",prompt, " ", $namespace,!
}

/// Get list Namespace, example do ##class(%IPM.Main).GetListNamespace(.ns)
ClassMethod GetListNamespace(
	Output list,
	pSearch As %String = "")
{
    kill list
    set list = 0

    // Build regex for matching outside of SQL.
    // Directly using `where Nsp LIKE ?` causes a bug described in https://github.com/intersystems/ipm/issues/579
    set pSearch = $zstrip(pSearch, "<>WC")
    if pSearch = "" {
        set pSearch = "*"
    }
    set regex = ##class(%IPM.DataType.RegExString).FromWildCard(pSearch)

    set width = 0
    set tQuery = "SELECT Nsp FROM %SYS.Namespace_List()"
    set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery)
    $$$ThrowSQLIfError(tRes.%SQLCODE, tRes.%Message)
    while tRes.%Next(.tSC) {
        $$$ThrowOnError(tSC)
        set nsp = tRes.Nsp
        if $match(nsp, regex) {
            set list(nsp) = ""
        }
    }
}

/// draw description
ClassMethod DrawColumn(desc) As %String
{
    set dx=$x
    for d=1:1:$length(desc," ") {
        set wd=$piece(desc," ",d)
        if ($x+$length(wd)>80) {
            write !,?dx
        }
        write wd," "
    }
    quit ""
}

ClassMethod SwitchToNamespace(pNamespace As %String = {$namespace}) As %Status
{
    set tSC = $$$OK
    try {
        if (pNamespace'=$namespace) {
            set $namespace = pNamespace
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Get List Modules
/// example d ##class(%IPM.Main).GetListModules("%SYS","zpm",.list)
ClassMethod GetListModules(
	pNamespace As %String = {$namespace},
	pSearch As %String = "",
	ByRef list,
	pExtraFields As %String = "",
	pRepository As %String = "") [ Internal ]
{
    set list = 0
    if (pNamespace="") || (pNamespace["*") {
        do ..GetListNamespace(.listNS, pNamespace)
        set list("ns") = pNamespace
        set width = 0
        set ns = ""
        for {
            set ns = $order(listNS(ns))
            quit:ns=""
            kill listModules
            try {
                // It is possible that GetListModules will fail in some namespaces. Allow it to do without failing the whole operation.
                // Most likely cases: incorrect mappings, corrupt installation of IPM in IRISSYS after upgrade.
                do ##class(%IPM.Main).GetListModules(ns, pSearch, .listModules, pExtraFields, pRepository)
            } catch e {
                write !,"WARNING: Failed to list packages in namespace "_ns_": "_e.DisplayString(),!
                kill listModules
            }
            continue:(pSearch'="")&&('$get(listModules))
            if (width < $length(ns)) {
                set width = $length(ns)
            }
            set list = list + 1
            set list(list) = $listbuild(ns)
            merge list(list, "modules") = listModules
        }
        merge list("width") = width
        quit
    }
    if (pNamespace'=$namespace) {
        new $namespace
        if $$$ISERR(..SwitchToNamespace(pNamespace)) {
            quit
        }
    }
    if '$$$comClassDefined("%IPM.Storage.Module") {
        // Don't error in namespaces without IPM enabled
        quit
    }
    set tArgs = 0
    // HACK: Certain IRIS kit, e.g., irishealth-community 2024.1 comes with %IPM in HSLIB and HSSYS namespaces
    // The caveat is that the %IPM.Storage.Module doesn't have a "LastUpdated" property
    // So, we need to check if the property exists before querying it
    $$$ThrowOnError(##class(%SYSTEM.SQL.Schema).GetAllColumns("%IPM_Storage.ModuleItem", .columns))
    set hasLastUpdated = $data(columns("LastUpdated"))
    set tQuery = "SELECT Name,VersionString,Description,ExternalName,DeveloperMode,Root"
    if hasLastUpdated {
        set tQuery = tQuery _ ",LastUpdated"
    }
    set tQuery = tQuery _ " FROM %IPM_Storage.ModuleItem WHERE 1=1 "
    set pSearch = $zstrip(pSearch, "<>WC")
    if (pSearch'="") {
        if pSearch["," {
            set tList = $listfromstring(pSearch, ",")
            set tParams = ""
            set ptr = 0
            while $listnext(tList, ptr, tItem) {
                set tItem = $zstrip(tItem, "<>WC")
                continue:tItem=""
                set tParams = tParams _ $listbuild("?")
                set tArgs($increment(tArgs)) = tItem
            }
            set tQuery = tQuery _ " AND name IN (" _ $listtostring(tParams, ", ") _ ")"
        } elseif pSearch'="*" {
            set tQuery = tQuery _ " AND name " _ $select(pSearch["*": "like ?", 1: "= ?")
            set tArgs($increment(tArgs)) = $translate(pSearch, "*", "%")
        }
    }
    if pRepository'="" {
        set tQuery = tQuery _ " AND Repository = ?"
        set tArgs($increment(tArgs)) = pRepository
    }
    set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery, tArgs...)
    $$$ThrowSQLIfError(tRes.%SQLCODE,tRes.%Message)
    set maxWidth = 0
    set list = 0
    while tRes.%Next(.tSC) {
        $$$ThrowOnError(tSC)
        set name = tRes.Name
        set list = list + 1
        set list(list) = $listbuild(name, tRes.VersionString, tRes.ExternalName, tRes.DeveloperMode, tRes.Root)
        if hasLastUpdated {
            set list(list) = list(list) _ $listbuild(tRes.LastUpdated)
        }
        if (maxWidth<$length(name)) {
            set maxWidth = $length(name)
        }
        continue:pExtraFields=""
        set obj = ##class(%IPM.Storage.Module).NameOpen(name, .tSC)
        continue:$$$ISERR(tSC)
        set ptr = 0
        while $listnext(pExtraFields, ptr, field) {
            continue:field=""
            set tObj = obj
            set tValue = ""
            for j=1:1:$length(field, ".") {
                set tField = $piece(field, ".", j)
                set tValue = $property(tObj, tField)
                quit:'$isobject(tValue)
                set tObj = tValue
            }
            continue:tValue=""
            set list(list, field) = tValue
        }
    }
    set list("width") = maxWidth
}

/// generates module.xml
ClassMethod GenerateModuleXML(ByRef pCommandInfo) As %Status [ Internal ]
{
    set tPath = $get(pCommandInfo("parameters","path"))
    if (tPath="") {
        set tHelp(1) = "Enter path to the module folder (where module.xml will be generated)"
        set tHelp(2) = "Enter "" null string to quit"
        do ##class(%Library.Prompt).GetString("Enter module folder:", .tPath, , ,.tHelp)
        return:(tPath="") $$$OK
    }
    set tPath = ##class(%File).NormalizeDirectory(tPath)

    if ($$$HasModifier(pCommandInfo,"template")) {
        return ##class(%IPM.Storage.ModuleTemplate).GenerateTemplate(tPath)
    }
    while (1) {
        set tHelp(1) = "Enter module name"
        set tHelp(2) = "Enter "" null string to quit"
        do ##class(%Library.Prompt).GetString("Enter module name:", .tName, , ,.tHelp)
        return:(tName="") $$$OK
        if ('##class(%IPM.Storage.ModuleTemplate).NameIsValid(tName)) {
            write !,"Module name """_tName_""" is invalid"
            set tName=""
            continue
        }
        quit
    }

    while (1) {
        set tVersion = "1.0.0"
        do ##class(%Library.Prompt).GetString("Enter module version:", .tVersion)
        return:(tVersion="") $$$OK
        if ('##class(%IPM.General.SemanticVersion).IsValid(tVersion)) {
            write !,"Module version """_tVersion_""" is invalid"
            set tVersion=""
            continue
        }
        quit
    }

    do ##class(%Library.Prompt).GetString("Enter module description:", .tDescription)

    do ##class(%Library.Prompt).GetString("Enter module keywords:", .tKeywords)

    set tTemplate = ##class(%IPM.Storage.ModuleTemplate).NewTemplate(tPath, tName, tVersion, tDescription, tKeywords)
    return:'$isobject(tTemplate)

    if ($$$HasModifier(pCommandInfo,"author")) {
        write !,"Author:"
        do ##class(%Library.Prompt).GetString("    Enter Author name:", .tAuthorPerson)
        do ##class(%Library.Prompt).GetString("    Enter Organization name:", .tAuthorOrg)
        do ##class(%Library.Prompt).GetString("    Enter License:", .tAuthorLicense)
        do ##class(%Library.Prompt).GetString("    Enter Copyright Date:", .tAuthorCopy)
        do ##class(%Library.Prompt).GetString("    Enter Notes:", .tAuthorNotes)
        do tTemplate.SetAuthorProps(tAuthorPerson, tAuthorOrg, tAuthorLicense, tAuthorCopy, tAuthorNotes)
        write !
    }

    set tSrc = "src"
    do ##class(%Library.Prompt).GetString("Enter module source folder:", .tSrc)
    set tExp = $$$GetModifier(pCommandInfo,"export")
    if tExp'="" {
        set tPathSrc=##class(%File).NormalizeDirectory(tPath_"\"_tSrc)
        do ##class(%IPM.Storage.ModuleTemplate).ExportResources(tPathSrc,tExp)
    }
    do tTemplate.ReadResources(tSrc)

    // web applications
    do ##class(%IPM.Storage.ModuleTemplate).GetCSPApplications(.apps)
    if ($listlength(apps)>0 ) {
        write !!,"Existing Web Applications:"
        for i=1:1:$listlength(apps) {
            write !,"    "_$listget(apps,i)
        }
        do ##class(%Library.Prompt).GetString("    Enter a comma separated list of web applications or * for all:", .tWebAppList)

        do tTemplate.AddWebApps(tWebAppList,.tCSPapps) // tCSP - list of CSP (not REST apps)
        for i=1:1:$listlength(tCSPapps) {
            set tCSPPath = ""
            do ##class(%Library.Prompt).GetString("    Enter path to csp files for "_$listget(tCSPapps,i)_": ", .tCSPPath)
            if (tCSPPath'="") {
                do tTemplate.SetSourcePathForCSPApp($listget(tCSPapps,i),tCSPPath)
            }
        }
    }

    // dependencies
    write !,"Dependencies:"
    while 1 {
        set tDependant = ""
        set tResponse = ##class(%Library.Prompt).GetString("    Enter module:version or empty string to continue:", .tDependant)
        set tDependant = $zstrip(tDependant,"<>W")
        quit:(tDependant="")
        do tTemplate.AddDependant(tDependant)
    }

    do tTemplate.ProcessResources()
    return tTemplate.SaveFile(tPath)
}

/// Get Default Command of Registry
/// example d ##class(%IPM.Main).GetDefaultCommandRegistry()
ClassMethod GetDefaultCommandRegistry()
{
    new $namespace
    set $namespace="%SYS"
    set Status=##Class(Config.Startup).Get(.Properties)
    if Status {
        set ServerPort="http://"_$zutil(110)_":"_$get(Properties("WebServerPort"),52773)
        write !,"Default commands for the registry"
        write !,"View all packets in the browser:",!,"  ",ServerPort_"/registry/packages/-/all"
        write !,"Switch to the current registry:",!,"   repo -r -n registry -url "_ServerPort_"/registry/ -user ""_system"" -pass ""SYS""",!

    }
}

/// Get Version Module
ClassMethod GetVersionModule(
	name,
	namespace = {$namespace})
{
    new $namespace
    set $namespace=namespace
    try {
        do ..GetListModules(,name,.list)
        return $listget(list(1), 2)
    } catch ex {
        return ""
    }
}

/// @API.Method
/// Version client and registry
ClassMethod Version(ByRef pCommandInfo) [ Internal ]
{
    do ..GetListModules("*", $$$IPMModuleName_","_$$$IPMServerRegistryModuleName, .list)
    do ..AddIPMMappedNamespaces(.list)
    do ..DisplayModules(.list)

    // Get URL current registry
    set tRes = ##class(%IPM.Repo.Remote.Definition).ExtentFunc()
    while tRes.%Next(.tSC) {
        $$$ThrowOnError(tSC)

        #dim tRepository As %IPM.Repo.Remote.Definition
        set tRepository = ##class(%IPM.Repo.Remote.Definition).%OpenId(tRes.ID,,.tSC)
        $$$ThrowOnError(tSC)
        set tService = tRepository.GetPackageService()
        set tInfo = tService.GetInfo()
        write !,$$$FormattedLine($$$Default,tRepository.URL)," - ",tInfo.ToString()
    }
    quit $$$OK
}

/// Argument `list` is a multidimensional array where `list` contains the a numeric value `n`, indicating the length of the list
/// Each subnode `list(i)` where 1 <= i <= n contains a $ListBuild of a single namespace
/// Each subnote `list(i,"modules")` contains the number of modules in the namespace
/// For 1 <= j <= `list(i,"modules")`, each subnode `list(i,"modules",j)` contains a $ListBuild of the module name, version, external name, and whether the module is installed in developer mode
/// Additional nodes are also accepted, although they are not used in this method
/// For example:
/// list=1
/// list(1)=$lb("USER")
/// list(1,"modules")=2
/// list(1,"modules",1)=$lb("zpm","0.9.0-SNAPSHOT","Package Management System",1)
/// list(1,"modules",2)=$lb("zpm-registry","1.3.2","ZPM Registry",0)
/// list(1,"modules","width")=12
/// list("ns")="*"
/// list("width")=4
ClassMethod AddIPMMappedNamespaces(ByRef list) [ Private ]
{
    do ..GetListNamespace(.allNS,"*")
    for i=1:1:+$get(list) {
        set namespace = $listget(list(i))
        if (namespace '= "") {
            kill allNS(namespace)
        }
        set sourceDB = ##class(%SYS.Namespace).GetPackageDest(namespace,"%IPM")
        set mappedFrom(sourceDB) = namespace
        merge mappedFrom(sourceDB,"info") = list(i)
    }

    set namespace = ""
    for {
        set namespace = $order(allNS(namespace))
        if namespace = "" {
            quit
        }

        set sourceDB = ##class(%SYS.Namespace).GetPackageDest(namespace,"%IPM")
        if $data(mappedFrom(sourceDB),sourceNamespace) {
            kill info
            merge info = mappedFrom(sourceDB,"info")
            set info = $listbuild(namespace)
            set info("modules",1,"Installed In") = sourceNamespace
            merge list($increment(list)) = info
            if $length(namespace) > +$get(list("width")) {
                set list("width") = $length(namespace)
            }
        }
    }
}

/// @API.Method
ClassMethod IsAvailable(
	pModuleName As %String,
	pNamespace As %String = "",
	pArgs...) As %Boolean
{
    new $namespace
    if pNamespace'="" {
        set $namespace = pNamespace
    }
    if '##class(%IPM.Storage.Module).NameExists(pModuleName,.id) {
        return 0
    }
    set availabilityClass = ##class(%IPM.Storage.Module).AvailabilityClassGetStored(id)
    if availabilityClass = "" {
        return 1
    }
    quit $classmethod(availabilityClass,"IsAvailable",pNamespace,pArgs...)
}

ClassMethod GetNamespaceDefaultModifiers(Output pDefaultArray) [ Internal ]
{
    kill pDefaultArray
    merge pDefaultArray = $$$ZPMDefaultModifiers
}

ClassMethod SetNamespaceDefaultModifiers(ByRef pDefaultArray) [ Internal ]
{
    merge $$$ZPMDefaultModifiers = pDefaultArray
}

ClassMethod DeleteNamespaceDefaultModifiers() [ Internal ]
{
    kill $$$ZPMDefaultModifiers
}

ClassMethod AccumulateDefaultModifierList(
	ByRef pDefaultArray,
	pNameParts As %Library.List = "") As %Library.List [ Internal ]
{
    set returnList = ""
    set key = ""
    while 1 {
        set key = $order(pDefaultArray(key))
        if (key = "") {
            quit
        }
        set nameParts = pNameParts _ $listbuild(key)
        if $data(pDefaultArray(key),value)#2 {
            // Only add to return list if top level node contains value
            set returnList = returnList _ $listbuild("-D"_$listtostring(nameParts,".")_"="_value)
        }
        if ($data(pDefaultArray(key)) >= 10) {
            // Contains subscripts so call recursively
            kill childArray
            merge childArray = pDefaultArray(key)
            set childList = ..AccumulateDefaultModifierList(.childArray, nameParts)
            set returnList = returnList _ childList
        }
    }
    return returnList
}

ClassMethod ProcessDefaultModifiers(ByRef pCommandInfo) [ Internal ]
{
    set shouldSet = $$$HasModifier(pCommandInfo,"set")
    set shouldGet = $$$HasModifier(pCommandInfo,"get")
    set shouldDelete = $$$HasModifier(pCommandInfo,"delete")
    if ((shouldSet + shouldGet + shouldDelete) '= 1) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"MUST use EXACTLY one of the available modifiers. View available modifiers by running the following command: help default-modifiers"))
    }
    if shouldGet {
        do ..GetNamespaceDefaultModifiers(.defaultArray)
        set modList = ..AccumulateDefaultModifierList(.defaultArray)
        if ($listlength(modList) = 0) {
            write !, "No default modifiers currently set for this namespace", !
            return
        }
        write !!, $$$FormattedLine($$$Underlined,"Available default modifiers:"), !
        set ptr = 0
        while $listnext(modList, ptr, modName) {
            write !, modName
        }
        write !
    } elseif shouldSet {
        merge dataArray = pCommandInfo("data")
        do ..SetNamespaceDefaultModifiers(.dataArray)
        write !, "Successfully updated default modifiers!", !
    } elseif shouldDelete {
        do ..DeleteNamespaceDefaultModifiers()
        write !, "Successfully deleted default modifiers!", !
    }
}

ClassMethod Init(ByRef pCommandInfo) [ Internal ]
{
    // In quiet mode, no prompts should be shown.
    set tQuiet = $$$HasModifier(pCommandInfo,"noprompt")

    // Reindex tables with semantic version indices
    for tClass = "%IPM.Repo.Filesystem.Cache" {
        write !,"Reindexing ",tClass,"... "
        $$$ThrowOnError($classmethod(tClass,"%BuildIndices",,1,1))
        write "done."
    }

    // Package Manager Settings
    if tQuiet {
        set tResult = 0
    } else {
        write !
        set tResult = 0
        set tHelp = "Enter ""Yes"" to configure settings for third-party tools that the package manager needs. These are all optional, "_
            "with the possible exception of JAVA_HOME, which must be configured to enable packaging of modules or extraction of packages."
        set tResponse = ##class(%Library.Prompt).GetYesNo("Do you want to configure general package manager settings?",.tResult,.tHelp)
        if (tResponse '= $$$SuccessResponse) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
        }
    }
    if (tResult) {
        set tRes = ##class(%SQL.Statement).%ExecDirect(,"call %IPM_General.IConfigurable_ListSettings()")
        if (tRes.%SQLCODE < 0) {
            $$$ThrowStatus($$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message))
        }
        set tLastSource = ""
        while tRes.%Next(.tSC) {
            $$$ThrowOnError(tSC)

            set tSource = tRes.%Get("Source")
            if (tSource '= tLastSource) {
                set tLastSource = tSource
                set tSourceDesc = tRes.%Get("SourceDescription")
                write !!,tSourceDesc
            }
            set tSetting = tRes.%Get("Name")
            set tSettingDesc = tRes.%Get("Description")
            set tSettingValue = tRes.%Get("Value")

            write !,tSetting,": ",tSettingDesc
            set tResponse = ##class(%Library.Prompt).GetString("Value:",.tSettingValue,,,tSettingDesc)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
            }

            if (tSettingValue '= tRes.%Get("Value")) {
                $$$ThrowOnError($classmethod(tSource,"SetSettingValue",tSetting,tSettingValue))
                write !,tSetting," updated."
            }
        }
        $$$ThrowOnError(tSC)
    }


    if tQuiet {
        set tConfigureZPM = $$$HasModifier(pCommandInfo,"zpm")
    } else {
        // Update of language extension - see if one is already configured.
        $$$ThrowOnError(..UpdateLanguageExtensions(0,1,.tHasZPM))
        set tConfigureZPM = 'tHasZPM // Default to "yes" if command is missing.

        write !
        set tHelp = "The 'ZPM' command allows quick command line access to many features of the package manager. Extensive documentation is available via:"_$char(13,10,9)_" zpm ""help""."
        set tResponse = ##class(%Library.Prompt).GetYesNo("Do you want to enable/update the 'ZPM' command?",.tConfigureZPM,.tHelp)
        if (tResponse '= $$$SuccessResponse) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
        }
    }
    if tConfigureZPM {
        $$$ThrowOnError(..UpdateLanguageExtensions())
    }

    // Source Control settings
    write !
    set tSCClassChanged = 0

    set tPrimaryClass = ""
    set tCompositeSCClass = "%IPM.ExtensionBase.Composite"
    set tServerMenuExtClass = ""

    // set server menu extension class (tServerMenuExtClass)
    if tQuiet {
        if $$$HasModifier(pCommandInfo,"menuextension") {
            set tServerMenuExtClass = $$$GetModifier(pCommandInfo,"menuextension")
        }
    } else {
        set tValue = ""
        set tStatement = ##class(%SQL.Statement).%New()
        $$$ThrowOnError(tStatement.%PrepareClassQuery($classname(), "ServerMenuExtensionClasses"))
        set tResultSet=tStatement.%Execute()
        $$$ThrowSQLIfError(tResultSet.%SQLCODE, tResultSet.%Message)
        while tResultSet.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            // if there's only one satisfied subclass, directly set it
            // if not, tServerMenuExtClass will be overwritten by user input to the prompt below
            set tServerMenuExtClass = tResultSet.%Get("Name")
        }
        $$$ThrowOnError(tSC)
        if (tResultSet.%ROWCOUNT > 1) {
            // if has more than one satisfied subclass, let user choose which server menu extension class to set
            set tHelp = "Note: only subclasses of %IPM.ExtensionBase.ServerMenu.Interface are listed."
            set tResponse = ##class(%Library.Prompt).GetArray("Which class to set as the server menu extension class?",.tValue, $listbuild($classname()_":ServerMenuExtensionClasses"),,,.tHelp,$$$InitialDisplayMask)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
            }
            if (tValue '= "") {
                set tServerMenuExtClass = tValue
            }
        }
        if (tServerMenuExtClass '= "") {
            write !, "Setting "_tServerMenuExtClass_" as the server menu extension class."
        }
    }

    set tSCInterface = "%IPM.ExtensionBase.SourceControl.Interface"
    set tOldSourceControlClass = ##class(%Studio.SourceControl.Interface).SourceControlClassGet()

    if (tOldSourceControlClass '= "") && '$$$comClassDefined(tOldSourceControlClass) {
        write !,"Source control class ",tOldSourceControlClass," does not exist - disabling it."
        $$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet())
        set tOldSourceControlClass = ""
    }

    if (tOldSourceControlClass '= "") && (tOldSourceControlClass '= tCompositeSCClass) && (tOldSourceControlClass '= tServerMenuExtClass) {
        write !,"Enabling package manager extension if present... "
        $$$ThrowOnError(##class(%IPM.ExtensionBase.Composite).SetExtensionClasses(tOldSourceControlClass,$listbuild(tServerMenuExtClass)))
        write "done."
        set tOldSourceControlClass = tCompositeSCClass
    }

    if (tOldSourceControlClass = "") {
        write !,"No Studio extension is currently configured for this namespace."
    } elseif (tOldSourceControlClass = tCompositeSCClass) {
        set tPrimaryClass = ##class(%IPM.ExtensionBase.Composite).GetPrimaryExtensionClass()
        set tExtensionClasses = ##class(%IPM.ExtensionBase.Composite).GetSubExtensionClasses()
        write !,"Currently configured to use the following extension classes: "
        set tPtr = 0
        while $listnext(tExtensionClasses,tPtr,tClass) {
            write !,$char(9),tClass,$case(tClass,tPrimaryClass:" (primary)",:"")
        }
    } else {
        write !,"Currently configured with the package manager extension, but no source control class."
    }

    if tQuiet {
        set tResult = $$$HasModifier(pCommandInfo,"extension")
    } else {
        write !
        set tHelp = "The source control class is a namespace-specific setting, controlling export of files to the filesystem / source control on the server."
        set tResult = (tPrimaryClass = "") || '$$$comClassDefined(tPrimaryClass) || '$classmethod(tPrimaryClass,"%Extends",tSCInterface)
        set tResponse = ##class(%Library.Prompt).GetYesNo("Do you want to change the source control class for this namespace?",.tResult,.tHelp)
        if (tResponse '= $$$SuccessResponse) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
        }
    }

    if (tResult) {
        // Provide list of options for source control classes to overlay.
        if tQuiet {
            set tValue = $$$GetModifier(pCommandInfo,"extension")
        } else {
            set tValue = ""
            set tHelp = "Note: only subclasses of %IPM.ExtensionBase.SourceControl.Interface are listed."
            set tResponse = ##class(%Library.Prompt).GetArray("Which class?",.tValue,$listbuild($classname()_":SourceControlClasses"),,,.tHelp,$$$InitialDisplayMask)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
            }
        }

        if (tValue = "") {
            $$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(tServerMenuExtClass))
            write !,!,"Removed source control class. Package manager extension still enabled if present."
        } else {
            write !,!,"Setting ",tValue," as the source control class for this namespace..."
            // Just configure the package manager source control class. (Gaining the "Package Manager" menu.)
            $$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(tCompositeSCClass))
            set tSecondaryExtension = $listbuild(tServerMenuExtClass)
            $$$ThrowOnError(##class(%IPM.ExtensionBase.Composite).SetExtensionClasses(tValue,tSecondaryExtension))
            write " done."

            // To see if it changed, compare to primary class (if found earlier) or old source control class (if we weren't combining extensions before)
            if (tValue '= tPrimaryClass) {
                set tSCClassChanged = 1
            }
        }
    } elseif (tOldSourceControlClass = "") {
        // Just configure the package manager source control class. (Gaining the "Package Manager" menu.)
        $$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(tServerMenuExtClass))
        write !,!,"Enabled package manager extension if present."
    }

    // If we're not just using the package manager, check for configuration method on primary source control class
    // (by seeing if it implements the additional package manager source control interface)
    if (##class(%Studio.SourceControl.Interface).SourceControlClassGet() = tCompositeSCClass) {
        // Default to having the user configure the extension after changing it.
        set tResult = tSCClassChanged
        set tPrimaryClass = ##class(%IPM.ExtensionBase.Composite).GetPrimaryExtensionClass()
        if $classmethod(tPrimaryClass,"%Extends",tSCInterface) && 'tQuiet {
            set tHelp = "Enter 'Yes' to configure settings for the selected source control class. Some of these may be namespace-specific, and some may be instance-wide."
            set tResponse = ##class(%Library.Prompt).GetYesNo("Do you want to configure source control options?",.tResult,.tHelp)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
            }
            if (tResult) {
                $$$ThrowOnError($classmethod(tPrimaryClass,"Configure"))
                write !,"Configuration complete."
            }
        }
    }
}

ClassMethod ProcessRunFromFile(ByRef pCommandInfo) [ Internal ]
{
    set filename = $get(pCommandInfo("parameters","file"))
    set dryRun = $$$HasModifier(pCommandInfo,"dry-run")

    if '##class(%Library.File).Exists(filename) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Provided file does not exist"))
    }
    set fileStream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(fileStream.LinkToFile(filename))

    // Accumulate list of commands to execute
    set commandList = ""

    set extension = $piece(filename, ".", *)
    if (extension = "txt") {
        // Read line by line, adding each line to command list
        while 'fileStream.AtEnd {
            set line = fileStream.ReadLine(, .sc)
            $$$ThrowOnError(sc)
            // Strip leading and trailing white space + control characters
            set line = $zstrip(line,"<>CW")
            if (line '= "") {
                set commandList = commandList _ $listbuild(line)
            }
        }
    } elseif (extension = "json") {
        // Will be an array so read file into it
        #dim jsonInput As %Library.DynamicObject
        #dim commandsArray As %Library.DynamicArray
        set jsonInput = ##class(%Library.DynamicAbstractObject).%FromJSON(fileStream)
        if 'jsonInput.%IsA("%Library.DynamicObject") {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Unexpected format of file. Expected JSON object at root level but not found."))
        }
        set commandsArray = jsonInput.%Get("commands")
        if '$isobject(commandsArray) || 'commandsArray.%IsA("%Library.DynamicArray") {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"'commands' property MUST be a JSON array"))
        }
        #dim arrayIter As %Iterator.Array
        set arrayIter = commandsArray.%GetIterator()
        while arrayIter.%GetNext(, .commandJson) {
            set command = ..ParseJsonToCommand(commandJson)
            set commandList = commandList _ $listbuild(command)
        }
    } else {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Unsupported file extension: "_extension))
    }

    set message = $case(dryRun,
        1: "The following commands will be run in the shell if the -dry-run flag is not used:",
        : "Running commands found in file:"
    )
    write !, message, !
    set ptr = 0
    while $listnext(commandList,ptr,command) {
        write !,..TerminalPrompt()
        write command
        if 'dryRun {
            $$$ThrowOnError(..Shell(command))
        }
        write !
    }
    write !
}

ClassMethod Search(ByRef pCommandInfo) [ Internal ]
{
    set tRepo = $get(pCommandInfo("data","Repo"),0)
    set tDesc = $get(pCommandInfo("data","Description"),0)
    set tAllVersions = $get(pCommandInfo("data","AllVersions"),0)
    set tSearchString = $get(pCommandInfo("parameters","searchString"),"")
    set tName = $$$GetModifier(pCommandInfo,"name")
    if (tName '= "") {
        do ..ShowModulesForRepository(tName, tRepo, tDesc, tSearchString, tAllVersions)
    } else {
        set tRes = ##class(%SQL.Statement).%ExecDirect(,"select Name, Details from %IPM_Repo.Definition")
        if (tRes.%SQLCODE < 0) {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
        }
        while tRes.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            if ($increment(tCount) > 1) {
                write !!
            }
            write tRes.%Get("Name")," ", tRes.%Get("Details"),":"
            do ..ShowModulesForRepository(tRes.%Get("Name"), tRepo, tDesc, tSearchString, tAllVersions)
        }
        $$$ThrowOnError(tSC)
    }
}

ClassMethod Config(ByRef pCommandInfo) [ Internal ]
{
    set action = $get(pCommandInfo("parameters","action"))
    set key = $get(pCommandInfo("parameters","key"))
    set value = $get(pCommandInfo("parameters","value"))

    if (action="") {
        set action = "list"
    }
    if (action="list") {
        do ##class(%IPM.Repo.UniversalSettings).PrintList()
    } elseif (action="set") {
        if ( (key = "") || (value="") ) {
            write "Key and Value required. Use config set <key> <value>",!
            quit
        }
        do ##class(%IPM.Repo.UniversalSettings).UpdateOne(key,value)
    } elseif (action="get") {
        if (key = "") {
            do ##class(%IPM.Repo.UniversalSettings).PrintList()
        } else {
            do ##class(%IPM.Repo.UniversalSettings).PrintOne(key)
        }
    } elseif (action="delete") {
        if (key = "") {
            write "Key required. Use config delete <key>",!
            quit
        }
        do ##class(%IPM.Repo.UniversalSettings).ResetToDefault(key)
    }
}

ClassMethod Repository(ByRef pCommandInfo) [ Internal ]
{
    do ##class(%IPM.Repo.Definition).CollectServerTypes(.types)

    set tType = $$$GetModifier(pCommandInfo, "type")

    set serverClassList = ""
    set t = ""
    for {
        set t = $order(types(t), 1, className)
        quit:(t = "")
        if ('($$$HasModifier(pCommandInfo, t)) && (t '= tType)) {
            kill types(t)
        }
        elseif '$listfind(serverClassList, className) {
            set serverClassList = serverClassList _ $listbuild(className)
        }
    }

    if $$$HasModifier(pCommandInfo,"list") && '$$$HasModifier(pCommandInfo,"list-modules") {
        set tUseFilter = $data(types)\10
        set tRes = ##class(%IPM.Repo.Definition).ListFunc()
        $$$ThrowSQLIfError(tRes.%SQLCODE,tRes.%Message)
        set tDisplayCount = 0
        write !
        while tRes.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            set tRepository = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tRes.%Get("Name"),,.tSC)
            $$$ThrowOnError(tSC)
            if serverClassList = "" || ($listfind(serverClassList, $classname(tRepository))) {
                do tRepository.Display()
                write !
                set tDisplayCount = tDisplayCount + 1
            }
        }
        $$$ThrowOnError(tSC)
        if (tDisplayCount = 0) {
            write "No repositories found.", !
        }
        quit
    } elseif $$$HasModifier(pCommandInfo,"copy-from") {
        set tSourceNamespace = $$$GetModifier(pCommandInfo,"copy-from")
        set tOldNamespace = $namespace
        new $namespace
        try {
            set $namespace = tSourceNamespace
        } catch e {
            if (e.Name = "<NAMESPACE>") {
                write !,"Invalid namespace: ",tSourceNamespace
                return
            }
            throw e
        }

        set tName = $$$GetModifier(pCommandInfo,"name")
        if (tName '= "") {
            set tRepository = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tName,,.tSC)
            if $$$ISERR(tSC) && $system.Status.Equals(tSC,$$$ERRORCODE($$$KeyValueNotFoundOpen)) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("No repository with name '%1' exists in namespace '%2'",tName,tSourceNamespace))
            }
            $$$ThrowOnError(tSC)
            set tRepositories($increment(tRepositories)) = tRepository
        } else {
            // Find all the repositories in the source namespace
            set tRes = ##class(%SQL.Statement).%ExecDirect(,
                "select Name "_
                "from %IPM_Repo.Definition "_
                "order by %IPM_Repo.Definition_SortOrder(ID) desc")
            if (tRes.%SQLCODE < 0) {
                throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
            }
            while tRes.%Next(.tSC) {
                $$$ThrowOnError(tSC)
                set tRepository = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tRes.%Get("Name"),,.tSC)
                $$$ThrowOnError(tSC)
                set tRepositories($increment(tRepositories)) = tRepository
            }
            $$$ThrowOnError(tSC)
        }

        set $namespace = tOldNamespace
        for tIndex=1:1:$get(tRepositories) {
            // Deep clone in case there are ever other referenced objects that need to be carried across.
            // This is not relevant for any current repository types, but is most likely to be correct in
            // hypothetical cases where it may matter. (A Git or GitHub-based repository, for example, would
            // probably need to store more information that would be carried across this way.)
            set tNewRepository = tRepositories(tIndex).%ConstructClone(1)
            if ##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(tNewRepository.Name) {
                write !,"Repository already defined: ",tNewRepository.Name,"; skipping."
                continue
            }
            set tOneSC = tNewRepository.%Save()
            if $$$ISOK(tOneSC) {
                write !,"Copied:"
                do tNewRepository.Display()
            }
            set tSC = $system.Status.AppendStatus(tSC,tOneSC)
        }
        $$$ThrowOnError(tSC)
    } elseif $$$HasModifier(pCommandInfo,"list-modules") {
        do ..Search(.pCommandInfo)
        quit
    } elseif $$$HasModifier(pCommandInfo,"delete-all") {
        if (serverClassList = "") {
            $$$ThrowOnError(##class(%IPM.Repo.Definition).%DeleteExtent())
        } else {
            set ptr = 0
            while $listnext(serverClassList, ptr, className) {
                $$$ThrowOnError($classmethod(className, "%DeleteExtent"))
            }
        }
    } elseif $$$HasModifier(pCommandInfo,"delete") {
        set repoName = $$$GetModifier(pCommandInfo,"name")
        if (repoName = "") {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Missing -name modifier"))
        }
        if '##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(repoName) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Repository "_$$$QUOTE(repoName)_" does not exist so cannot be deleted."))
        }
        $$$ThrowOnError(##class(%IPM.Repo.Definition).ServerDefinitionKeyDelete(repoName))
    } elseif $$$HasModifier(pCommandInfo,"reset-defaults") {
        merge tModifiers = pCommandInfo("modifiers")
        set tName = $$$GetModifier(pCommandInfo,"name")
        if (tName = "") {
            set tName = "registry"
            set tModifiers("name") = tName
        }
        set tModifiers("remote") = ""

        set tModifiers("url") = ##class(%IPM.Repo.UniversalSettings).GetDefaultRegistry()
        if (tModifiers("url")="") {
            write "Error retrieving default registry URL"
            quit
        }
        set tModifiers("username") = "", tModifiers("password") = ""
        set tType = "%IPM.Repo.Remote.Definition"
        $$$ThrowOnError($classmethod(tType,"Configure",1,.tModifiers,.tData))
        do ..Shell("repo -list")
    } else {
        set tName = $$$GetModifier(pCommandInfo,"name")
        set tType = $listget(serverClassList)

        #dim tRepoTypeResult As %SQL.StatementResult
        set tStatement = ##class(%SQL.Statement).%New()
        set tSC = tStatement.%PrepareClassQuery("%IPM.Repo.Definition","Catalog")
        $$$ThrowOnError(tSC)
        set tRepoTypeResult = tStatement.%Execute()
        if tRepoTypeResult.%SQLCODE < 0 {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(tRepoTypeResult.%SQLCODE, tRepoTypeResult.%Message)
        }
        while tRepoTypeResult.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            if tRepoTypeResult.%Get("Moniker") = "http" {
                continue
            }
            set tMonikers($zconvert(tRepoTypeResult.%Get("Moniker"),"L")) = tRepoTypeResult.%Get("Classname")
            set tClassList($increment(tClassList)) = tRepoTypeResult.%Get("Classname")
            set tDescList($increment(tDescList)) = tRepoTypeResult.%Get("Description")
        }
        $$$ThrowOnError(tSC)

        if (tType = "") && (tName '= "") && ##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(tName) {
            set tInstance = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tName)
            if $isobject(tInstance) {
                set tType = tInstance.%ClassName(1)
            }
        }

        if (tType = "") {
            set tResponse = ##class(%Library.Prompt).GetMenu("Which sort of repository do you wish to configure?",.tDescIndex,.tDescList,,$$$InitialDisplayMask)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
            }
            if (tDescIndex = "") {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"A repository type must be specified."))
            }
            set tType = tClassList(tDescIndex)
        }

        set tBaseClass = "%IPM.Repo.Definition"
        if '$classmethod(tType,"%Extends",tBaseClass) {
            set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid type '%1' - must extend %2",tType,tBaseClass))
        }

        merge tModifiers = pCommandInfo("modifiers")
        merge tData = pCommandInfo("data")
        $$$ThrowOnError($classmethod(tType,"Configure",1,.tModifiers,.tData,tType))
        do ..Shell("repo -list")
    }
}

ClassMethod ShowModulesForRepository(
	pRepoName As %String,
	pShowRepo As %Boolean = 0,
	pShowDesc As %Boolean = 0,
	pSearchString As %String = "",
	pShowAllVersions As %Boolean = 0) [ Private ]
{
    #define gn "^||tmpDesc"
    kill @$$$gn
    set (maxlenname,maxlenver) = 0, where = ""
    if pSearchString["*" {
        set where=" WHERE name like ?"
    } elseif pSearchString'="" {
        set where=" WHERE name = ?"
    }
    set tQuery = "SELECT Name,Version,Repository,Description,Origin,AllVersions FROM %IPM_Utils.Module_GetModuleList(?,?) "_where
    if (pSearchString = "") {
        set tRes = ##class(%SQL.Statement).%ExecDirect(, tQuery, pRepoName, pShowAllVersions)
    } else {
        set tRes = ##class(%SQL.Statement).%ExecDirect(, tQuery, pRepoName, pShowAllVersions, $replace(pSearchString,"*","%"))
    }
    $$$ThrowSQLIfError(tRes.%SQLCODE,tRes.%Message)
    set list = 0
    set width = 0
    while tRes.%Next(.tSC) {
        $$$ThrowOnError(tSC)
        set name = tRes.%Get("Name")
        if width < $length(name) {
            set width = $length(name)
        }
        set list = list + 1
        set list(list) = $listbuild(name, tRes.Version)
        set list(list, "Origin") = tRes.Origin
        if pShowDesc {
            set list(list, "Description") = tRes.Description
        }
        if pShowRepo {
            set list(list, "Repository") = tRes.Repository
        }
        if pShowAllVersions {
            set list(list, "AllVersions") = tRes.AllVersions
        }
    }
    set list("width") = width
    write !
    do ..DisplayModules(.list)
}

Query SourceControlClasses() As %SQLQuery(ROWSPEC = "ID:%String,Name:%String") [ SqlProc ]
{
    select Name as ID,Name from %Dictionary.ClassDefinition_SubclassOf('%IPM.ExtensionBase.SourceControl.Interface')
}

Query ServerMenuExtensionClasses() As %SQLQuery(ROWSPEC = "ID:%String,Name:%String") [ SqlProc ]
{
    select Name as ID,Name from %Dictionary.ClassDefinition_SubclassOf('%IPM.ExtensionBase.ServerMenu.Interface')
}

ClassMethod LoadFromRepo(
	tDirectoryName,
	ByRef tParams) [ Internal ]
{
    set slash=$select($zversion(1)=3:"/",1:"\")
    set TempDir = ##class(%File).GetDirectory(##class(%File).GetDirectory($zutil(86))_"mgr"_slash_"Temp"_slash_$translate($ztimestamp,".,")_slash)
    $$$ThrowOnError(##class(%File).CreateDirectoryChain(TempDir))
    set:$extract(tDirectoryName,*)="/" tDirectoryName=$extract(tDirectoryName,1,*-1)
    set RepoName=$piece($piece($piece(tDirectoryName,"/",*),".git")," ")
    set tCmd="cd "_TempDir_" && git clone "_tDirectoryName
    if $get(tParams("Branch"))'="" set tCmd=tCmd_" -b "_tParams("Branch")
    $$$ThrowOnError(##class(%IPM.Utils.Module).RunCommandViaZF(tCmd,.tLog,.tErr))
    set tDirectoryName = TempDir_slash_RepoName
    if ($get(tParams("Verbose"))) {
        write !,"Create tempory directory "_TempDir
        write !,tCmd
        for i=1:1:$get(tLog) {
            write tLog(i),!
        }
        write !,tDirectoryName
    }
    for i=1:1:$get(tErr) {
        write tErr(i),!
    }
    hang 2
    quit tDirectoryName
}

ClassMethod Load(ByRef pCommandInfo) [ Internal ]
{
	set devMode = $get(pCommandInfo("data", "DeveloperMode"), 0)
	set log = ##class(%IPM.General.History).LoadInit("")
	try {
		do ..LoadInternal(.pCommandInfo, log)
	} catch Ex {
		$$$ThrowOnError(log.Finalize(Ex.AsStatus(), devMode))
		throw Ex
	}
	$$$ThrowOnError(log.Finalize($$$OK, devMode))
}

ClassMethod LoadInternal(
	ByRef pCommandInfo,
	pLog As %IPM.General.History) [ Internal ]
{
    set tDirectoryName = $get(pCommandInfo("parameters","path"))
    set isAbsolutePath = ($extract(##class(%File).NormalizeDirectory(tDirectoryName), 1, $length(tDirectoryName)) = tDirectoryName)
    set isURL = $extract(tDirectoryName,1,4)="http"
    if tDirectoryName = "" {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"No path has been specified."))
    } elseif '##class(%File).Exists(tDirectoryName) && 'isAbsolutePath && 'isURL {
        // if the path is to a directory (not a file) and it is not a URL, it must be absolute
        $$$ThrowStatus($$$ERROR($$$GeneralError,"The specified path must be absolute."))
    }
    set tSynchronous = $$$HasModifier(pCommandInfo,"synchronous")
    set tForce = $$$HasModifier(pCommandInfo,"force")
    merge tParams = pCommandInfo("data")
    // In the case of an update command, pCommandInfo has already been populated in ..Update(). The relevant information was then moved to tParams via the merge command above.
    // In the case of a load command, tParams still needs to be populated here.
    if '$get(tParams("Update"),0) {
        set tParams("cmd") = "load"
        set tParams("Load") = 1
    }
    set tParams("Force") = tForce
    do ##class(%Net.URLParser).Decompose(tDirectoryName, .tComponents)
    if $get(tComponents("scheme")) [ "http" {
        set tDirectoryName=..LoadFromRepo(tDirectoryName,.tParams)
    }
    set extension = $$$lcase($piece(tDirectoryName,".",*))
    if ##class(%File).Exists(tDirectoryName) && ((extension="tgz") || (extension="tar.gz")) {
        set tTargetDirectory = $$$FileTempDirSys
        if $get(pCommandInfo("data", "Verbose")) {
            write !,"Extracting archive to ",tTargetDirectory
        }
        $$$ThrowOnError(##class(%IPM.General.Archive).Extract(tDirectoryName, tTargetDirectory))
        // Try to locate the top-level module.xml file
        if $get(pCommandInfo("data", "Verbose")) {
            write !,"Trying to locate module.xml file in ", tTargetDirectory
        }
        set tCount = ##class(%IPM.Utils.File).FindFiles(tTargetDirectory, "module.xml", .tList)
        if (tCount = 0) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"No module.xml file found in archive."))
        }

        // The top-level module.xml is the last one in tList, assuming ##class(%File).FileSetFunc returns directory first
        set tModuleFilePath = $listget(tList(tCount), *)
        set tTargetDirectory = ##class(%File).GetDirectory(tModuleFilePath, 1)
        if $get(pCommandInfo("data", "Verbose")) {
            write !,"Found "_tCount_" results. They are: "
            set idx = ""
            for {
                set idx = $order(tList(idx))
                quit:(idx="")
                write !, $char(9), $list(tList(idx), *)
            }
            write !, "Using module.xml file at ", tModuleFilePath
        }
    }

    // When loading a module from a local folder, there might be a <mod root>/.modules/ folder containining dependencies.
    // It's easier to configure a temporary repository than to handle this case in the dependency resolution code.
    set tTargetDirectory = $get(tTargetDirectory, tDirectoryName)
    set dotModules = ##class(%File).NormalizeDirectory(".modules", tTargetDirectory)
    set tmpRepoMgr = ##class(%IPM.General.TempLocalRepoManager).%New(dotModules, 1)
    set tSC = ##class(%IPM.Utils.Module).LoadNewModule(tTargetDirectory, .tParams, , tSynchronous, pLog)
    set tSC = $$$ADDSC(tSC, tmpRepoMgr.CleanUp())
    $$$ThrowOnError(tSC)
}

ClassMethod CheckModuleNamespace() As %Status
{
    do ..GetMapInfo(.tIsMappedFrom, .tIsMappedTo)
    if $data(tIsMappedFrom($namespace), sourceNS) # 2 {
        quit $$$ERROR($$$GeneralError, $$$FormatText("Cannot install '%1' in namespace '%2' because it is mapped from namespace '%3'.", $$$IPMModuleName, $namespace, sourceNS))
    }
    if $data(tIsMappedTo($namespace)) / 2 {
        write !, "Will affect the following namespaces:", $namespace
        set ns = ""
        for {
            set ns = $order(tIsMappedTo($namespace, ns))
            if ns = "" {
                quit
            }
            write ", ", ns
        }
    }
    quit $$$OK
}

ClassMethod Install(ByRef pCommandInfo) [ Internal ]
{
    set tRegistry = ""
    set tModuleName = $get(pCommandInfo("parameters","module"))
    if (tModuleName["/") {
        set $listbuild(tRegistry, tModuleName) = $listfromstring(tModuleName, "/")
    }
    if (tModuleName = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "No module name specified."))
    }

    if tModuleName = $$$IPMModuleName {
        $$$ThrowOnError(..CheckModuleNamespace())
    }
    // check if any registries are configured and enabled
    new SQLCODE, count
    &sql(SELECT COUNT(*) into :count FROM %IPM_Repo.Definition WHERE Enabled = 1)
    $$$ThrowSQLIfError(SQLCODE,%message)
    if (SQLCODE = 0) && (count = 0) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "No repositories are configured and enabled in this namespace."))
    }

    set tVersion = $get(pCommandInfo("parameters","version"))
    set tKeywords = $$$GetModifier(pCommandInfo,"keywords")
    set tSynchronous = $$$HasModifier(pCommandInfo,"synchronous")
    set tForce = $$$HasModifier(pCommandInfo,"force")

    #dim log As %IPM.General.History
	set log = ##class(%IPM.General.History).InstallInit(tModuleName)
	set devMode = $get(pCommandInfo("data","DeveloperMode"), 0)

	try {
        set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
        set tSearchCriteria.Registry = tRegistry
        set tSearchCriteria.Name = $$$lcase(tModuleName)
        set tSearchCriteria.VersionExpression = tVersion
        set tSearchCriteria.Keywords = tKeywords
        $$$ThrowOnError(##class(%IPM.Repo.Utils).SearchRepositoriesForModule(tSearchCriteria,.tResults))

        if (tResults.Count() > 0) {
            set tResult = ""
            #dim tResult As %IPM.Storage.QualifiedModuleInfo
            // Results are ordered by semantic version, descending. (So the "latest" version will always be first.)
            if ('$$$HasModifier(pCommandInfo,"prompt") || (tResults.Count() = 1)) && (tKeywords = "") {
                set tResult = tResults.GetAt(1)
            } elseif (tResults.Count() > 0) {
                for i=1:1:tResults.Count() {
                    set tResultInfo = tResults.GetAt(i)
                    set tOptArray(i) = tResultInfo.DisplayName_" "_tResultInfo.VersionString_" @ "_tResultInfo.ServerName
                }

                set tValue = ""
                set tResponse = ##class(%Library.Prompt).GetMenu("Which version?",.tValue,.tOptArray,,$$$InitialDisplayMask+$$$EnableQuitCharMask)
                if (tResponse '= $$$SuccessResponse) {
                    $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
                }
                if (tValue '= "") {
                    set tResult = tResults.GetAt(tValue)
                }
            }

            if (tResult '= "") {
                do ##class(%IPM.Lifecycle.Base).GetDefaultParameters(.tParams)
                merge tParams = pCommandInfo("data")
                set tParams("DeveloperMode") = devMode
                set tParams("Force") = tForce
                // In the case of an update command, pCommandInfo has already been populated in ..Update(). The relevant information was then moved to tParams via the merge command above.
                // In the case of a install command, tParams still needs to be populated here.
                if '$get(tParams("Update"),0) {
                    set tParams("cmd") = "install"
                    set tParams("Install") = 1
                }
                if tResult.Deployed {
                    set platformVersion = $system.Version.GetMajor() _ "." _$system.Version.GetMinor()
                    set tResult.PlatformVersion = platformVersion
                    if ('tResult.PlatformVersions.Find(platformVersion)) {
                        $$$ThrowStatus($$$ERROR($$$GeneralError, "Deployed package '" _ tModuleName _ "' " _ tResult.VersionString _ " not supported on this platform " _ platformVersion _ "."))
                    }
                }
				$$$ThrowOnError(log.SetSource(tResult.ServerName))
				$$$ThrowOnError(log.SetVersion(tResult.Version))
                $$$ThrowOnError(##class(%IPM.Utils.Module).LoadQualifiedReference(tResult, .tParams, , tSynchronous, 1))
            }
        } else {
            set tPrefix = ""
            if (tModuleName '= "") {
                if (tVersion '= "") {
                    $$$ThrowStatus($$$ERROR($$$GeneralError, tModuleName_" "_tVersion_" not found in any repository."))
                } else {
                    $$$ThrowStatus($$$ERROR($$$GeneralError, "'"_tModuleName_"' not found in any repository."))
                }
            } elseif (tKeywords '= "") {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"No modules found matching keywords: '"_tKeywords_"'"))
            } else {
                write !,"No modules found. Are there any repositories configured in the current namespace?"
            }
        }
    } catch ex {
		$$$ThrowOnError(log.Finalize(ex.AsStatus(), devMode))
		throw ex
	}
	$$$ThrowOnError(log.Finalize($$$OK, devMode))
}

ClassMethod Reinstall(ByRef pCommandInfo) [ Internal ]
{
    // Overriding defaults in the "data" array:
    // For now this is just the "UpdateSnapshots" flag but it could be more eventually.
    set tData("UpdateSnapshots") = 1

    // Note that pCommandInfo("data") may override the default of UpdateSnapshots=1.
    merge tData = pCommandInfo("data")
    merge pCommandInfo("data") = tData

    // Find  the currently-installed version of the module
    set tModuleName = $get(pCommandInfo("parameters","module"))
    set tModule = ##class(%IPM.Storage.Module).NameOpen(tModuleName,,.tSC)
    if $system.Status.Equals(tSC,$$$ERRORCODE($$$KeyValueNotFoundOpen)) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Module '%1' is not currently installed.",tModuleName)))
    }
    $$$ThrowOnError(tSC)

    if tModuleName = $$$IPMModuleName {
        $$$ThrowOnError(..CheckModuleNamespace())
    }

    set tVersionString = tModule.Version.ToString()
    write !,"Reinstalling ",tModuleName," ",tVersionString
    set pCommandInfo("parameters","version") = tVersionString
    do ..Install(.pCommandInfo)
}

ClassMethod Uninstall(ByRef pCommandInfo) [ Internal ]
{
    merge tParams = pCommandInfo("data")
    set tForce = $$$HasModifier(pCommandInfo,"force") // Force uninstallation even if things depend on this module
    if $$$HasModifier(pCommandInfo,"all") {
        $$$ThrowOnError(##class(%IPM.Utils.Module).UninstallAll(tForce,.tParams))
        return
    } else {
        set tModuleName = pCommandInfo("parameters","module")
        if (tModuleName = $$$IPMModuleName) {
            $$$ThrowOnError(..CheckModuleNamespace())
        }
        set tRecurse = $$$HasModifier(pCommandInfo,"recurse") // Recursively uninstall unneeded dependencies
        $$$ThrowOnError(##class(%IPM.Storage.Module).Uninstall(tModuleName,tForce,tRecurse,.tParams))
    }
}

ClassMethod RunOnePhase(ByRef pCommandInfo) [ Internal ]
{
    do ##class(%IPM.Lifecycle.Base).LoadEnvironmentConfig($get(pCommandInfo("data", "EnvFiles")))
    set tModName = $get(pCommandInfo("parameters","module"))
    set tPhases = $listbuild($zconvert(pCommandInfo, "w"))
    set tIsComplete = '$$$HasModifier(pCommandInfo,"only")
    set tParams("Recurse") = $$$HasModifier(pCommandInfo,"recurse")
    set tParams("cmd") = pCommandInfo
    merge tParams = pCommandInfo("data")
    if $data(tParams("Path"), path) # 2 {
        set tParams("Path") = ##class(%File).NormalizeDirectory(path)
    }
    $$$ThrowOnError(##class(%IPM.Storage.Module).ExecutePhases(tModName,tPhases,tIsComplete,.tParams))
}

ClassMethod Unpublish(ByRef pCommandInfo) [ Internal ]
{
    if ( ($get(pCommandInfo("parameters","module"))="") || ($get(pCommandInfo("parameters","version"))="") ) {
        set tCommandInfo("parameters","command") = "unpublish"
        do ..%Help(.tCommandInfo)
        quit
    }

    set tRegistry = ""
    set tModuleName = $zconvert($get(pCommandInfo("parameters","module")), "L")
    if ( tModuleName["/" ) {
        set $listbuild(tRegistry, tModuleName) = $listfromstring(tModuleName, "/")
    }
    if ( tRegistry = "" ) {
        set tRS = ##class(%IPM.Repo.Http.Definition).PublishingServerFunc()
        if (tRS.%SQLCODE = 0) && tRS.%Next() {
            set tServer = $classmethod(tRS.Class, "%OpenId", tRS.ID)
        }
    } else {
        set tServer = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tRegistry,,.tSC)
    }
    if ('$isobject(tServer)) {
        write "Registry not found: "_tRegistry,!
        return $$$ERROR(5001, "Registry not found: "_tRegistry)
    }
    set tVersion = $get(pCommandInfo("parameters","version"))

    try {
        set tManager = tServer.GetPublishingManager(.tSC)
        $$$ThrowOnError(tSC)
        $$$ThrowOnError(tManager.CheckUnpublishEnabled(.isEnabled, tServer.Name, tModuleName, tVersion))

        if (isEnabled) {
            set tResult = 0
            if ($$$lcase(tVersion)="all") {
                write $$$FormattedLine($$$Red, "Deleting a package and all its versions is an irreversible action")
                set tHelp = "Enter ""Yes"" if you want to delete all package versions."
                set tMsg = "Are you sure you want to delete all versions of the package """_tModuleName_""" from registry """_tServer.Name_""" ("_tServer.URL_")?"
            } else {
                write $$$FormattedLine($$$Red, "Deleting a package version is an irreversible action")
                set tHelp = "Enter ""Yes"" if you want to delete selected package version."
                set tMsg = "Are you sure you want to delete the package """_tModuleName_" "_tVersion_""" from registry """_tServer.Name_""" ("_tServer.URL_")?"
            }

            set tResponse = ##class(%Library.Prompt).GetYesNo(tMsg,.tResult,.tHelp)

            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
            }

            if (tResult) {
                $$$ThrowOnError(tManager.Unpublish(tServer.Name, tModuleName, tVersion))
                write !!,"Package deleted"
            }
        } else {
            write !,"The package could not be deleted (the registry denied the request)",!
        }
    } catch ex {
        write !!,$$$FormattedLine($$$Red, "ERROR! "), ex.DisplayString()
    }
}

ClassMethod ModuleAction(ByRef pCommandInfo) [ Internal ]
{
    do ##class(%IPM.Lifecycle.Base).LoadEnvironmentConfig($get(pCommandInfo("data", "EnvFiles")))
    set tModName = $get(pCommandInfo("parameters","module"))
    set tPhases = $listfromstring($get(pCommandInfo("parameters","actions"))," ")
    set tIsComplete = '$$$HasModifier(pCommandInfo,"only")
    set tParams("Recurse") = $$$HasModifier(pCommandInfo,"recurse")
    if $listlength(tPhases) {
        // Accept lower-case phase names in the command.
        set tPtr = 0
        set tActualPhases = ""
        while $listnext(tPhases,tPtr,tPhase) {
            set tActualPhases = tActualPhases_$listbuild($zconvert(tPhase, "w"))
        }
        merge tParams = pCommandInfo("data")
        if $data(tParams("Path"), path) # 2 {
            set tParams("Path") = ##class(%File).NormalizeDirectory(path)
        }
        $$$ThrowOnError(##class(%IPM.Storage.Module).ExecutePhases(tModName,tActualPhases,tIsComplete,.tParams))
    } else {
        if (tModName '= "") && ##class(%IPM.Storage.Module).NameExists(tModName) {
            // TODO: list phases if a valid module name was specified.
        } else {
            do ..%Help()
        }
    }
}

/// Run Dependency Analyzer for the given module
ClassMethod RunDependencyAnalyzer(ByRef pCommandInfo)
{
    if '$$$comClassDefined("%pkg.isc.dependencyAnalyzer.Utils") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Dependency Analyzer package must be installed before running the dependency analyzer."))
    }
    set ignoredStringRef = $$$GetModifier(pCommandInfo,"ignore-str")
    set ignoreAll = $$$HasModifier(pCommandInfo,"ignore-str-all")
    set invalidOnly = $$$GetModifier(pCommandInfo,"invalid-only")
    set directDepsOnly = $$$HasModifier(pCommandInfo,"direct-deps-only")
    if (ignoreAll) {
        set ignoredStringRef = $char(0)
    }
    set moduleOrItemName = $get(pCommandInfo("parameters", "moduleOrItem"))
    if (moduleOrItemName = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Module/item name must be provided. Run help command to see syntax"))
    }
    write !, "Running dependency analyzer...", !, !
    // Status can be ignored as it is written to the current device
    if (invalidOnly = 0)  {
        do ##class(%IPM.DependencyAnalyzer).RunForAllReferences(moduleOrItemName, .allReferences, 1,,,,ignoredStringRef, directDepsOnly)
        if '$data(allReferences) {
            write !, "No references found!"
        }
    } else {
        do ##class(%IPM.DependencyAnalyzer).RunForInvalidReferences(moduleOrItemName, .invalidReferences, 1,,,,ignoredStringRef, directDepsOnly)
        if '$data(invalidReferences) {
            write !, "No invalid references found!"
        }
    }
    write !
}

/// Implemented as custom query instead of `select Nsp, Nsp from %SYS.Namespace_List(0,0) WHERE status = 1` because of a DP issue, see https://github.com/intersystems/ipm/issues/579
Query ActiveNamespaces() As %Query(ROWSPEC = "ID:%String,Name:%String") [ SqlProc ]
{
}

ClassMethod ActiveNamespacesExecute(qHandle As %Binary) As %Status
{
    try {
        set tQuery = "SELECT NSP, Status FROM %SYS.Namespace_List(0,0)"
        set rs = ##class(%SQL.Statement).%ExecDirect(, tQuery)
        kill qHandle
        while rs.%Next() {
            if rs.%Get("Status") {
                set qHandle($increment(qHandle)) = rs.%Get("NSP")
            }
        }
        set qHandle = 0
    } catch ex {
        return ex.AsStatus()
    }
    return $$$OK
}

ClassMethod ActiveNamespacesFetch(
	qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ActiveNamespacesExecute ]
{
    try {
        if $data(qHandle($increment(qHandle)), nsp) # 2 {
            set Row = $listbuild(nsp, nsp)
            set AtEnd = 0
        } else {
            set Row = ""
            set AtEnd = 1
        }
    } catch ex {
        return ex.AsStatus()
    }
    return $$$OK
}

ClassMethod ActiveNamespacesClose(qHandle As %Binary) As %Status [ PlaceAfter = ActiveNamespacesFetch ]
{
    kill qHandle
    return $$$OK
}

ClassMethod ListInstalled(ByRef pCommandInfo) [ Private ]
{
    set tSearchString = $get(pCommandInfo("parameters","searchString"),"")
    if (''$data(pCommandInfo("modifiers","tree"))) {
        // Show tree of dependencies as well.
        // Modules that are dependencies for no other are shown at the top level.
        // TODO: deal with cyclic dependencies?
        quit:'..GetListModule(,.tModMap)
        set tDepRes = ##class(%SQL.Statement).%ExecDirect(,
            "select ModuleItem->Name ModName,Dependencies_Name DepName,Dependencies_VersionString DepVer "_
            "from %IPM_Storage.ModuleItem_Dependencies")
        $$$ThrowSQLIfError(tDepRes.%SQLCODE, tDepRes.%Message)
        while tDepRes.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            set tModMap($zconvert(tDepRes.%Get("ModName"),"l"),$zconvert(tDepRes.%Get("DepName"),"l")) = tDepRes.%Get("DepVer")
            set tVisitedMap($zconvert(tDepRes.%Get("DepName"),"l")) = 1
        }
        $$$ThrowOnError(tSC)

        set tMod = ""
        for {
            set tMod = $order(tModMap(tMod),1,tVersion)
            quit:(tMod="")
            do:'$data(tVisitedMap(tMod)) ..AccumulateTreeRecursive(tMod,.tModMap,.tOrderedTree)
        }
        do ..PrintTree(.tOrderedTree)
    } else {
        set showFields = ""
        if +$get(pCommandInfo("data","Desc")) {
            set showFields = showFields_$listbuild(
                "Description",
                "Author.CopyrightDate",
                "Author.License",
                "Author.Notes",
                "Author.Organization",
                "Author.Person",
                "Root"
            )
        }
        set tDesc=+$get(pCommandInfo("data","Desc"))
        do ..GetListModules(,tSearchString, .list, showFields, $get(pCommandInfo("modifiers", "repository")))
        for i = 1:1:list {
            set entry = list(i)
            set name = $listget(entry,1)
            set externalName = $listget(entry,3)
            set displayName = $select(externalName'= "":externalName, 1:name)
            if (displayName '= name) {
                set displayName = displayName_" ("_name_")"
            }
            set $list(list(i), 1) = displayName
            if (list("width") < $length(displayName)) {
                set list("width") = $length(displayName)
            }
        }
        merge tModifiers = pCommandInfo("modifiers")
        do ..DisplayModules(.list,,,, .tModifiers)
    }
}

/// Get module list in currently namespace
ClassMethod GetListModule(
	ns = {$namespace},
	ByRef Mod,
	OnlyName = 1) As %Status [ Deprecated ]
{
    new $namespace
    set $namespace=ns
    set tRes = ##class(%SQL.Statement).%ExecDirect(,
        "select * from %IPM_Storage.ModuleItem")
    $$$ThrowSQLIfError(tRes.%SQLCODE,tRes.%Message)
    set in=""
    while tRes.%Next(.tSC) {
        $$$ThrowOnError(tSC)
        set name=$zconvert(tRes.%Get("DisplayName"),"l")
        set in=in_"'"_name_"',"
        set list=$listbuild(tRes.%Get("VersionString"),tRes.%Get("Description"),tRes.%Get("Root"))
        for a="Author_CopyrightDate", "Author_License", "Author_Notes", "Author_Organization", "Author_Person" {
            set list=list_$listbuild(tRes.%Get(a))
        }
        set Mod(name) = tRes.%Get("VersionString")
        set:'OnlyName Mod(name,"L") = list
    }
    $$$ThrowOnError(tSC)
    quit:in=""||(OnlyName) $$$OK
    set in=$extract(in,1,*-1)

    set tQuery = "select Name, Version, Repository, Description, AllVersions from %IPM_Utils.Module_GetModuleList('registry') WHERE name in ("_in_")"
    set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery)
    $$$ThrowSQLIfError(tRes.%SQLCODE,tRes.%Message)
    while tRes.%Next(.tSC) {
        $$$ThrowOnError(tSC)
        set name = tRes.%Get("DisplayName")
        set Mod(name,"R")=$listbuild(tRes.%Get("Version"),tRes.%Get("Description"),tRes.%Get("Repository"),tRes.%Get("AllVersions"))
    }
    quit $$$OK
}

ClassMethod AccumulateTreeRecursive(
	pModName As %String,
	ByRef pModMap,
	ByRef pTree,
	pLevel As %Integer = 0) [ Private ]
{
    if (pLevel = 0) && $data(pVisitedMap(pModName)) {
        quit
    }

    set tParentIndex = $increment(pTree)
    set pTree(tParentIndex) = $listbuild(pModName_" "_$get(pModMap(pModName),"[missing]"))
    set tDep = ""
    set tPrevSibling = ""
    for {
        set tDep = $order(pModMap(pModName,tDep),1,tDepVerExpr)
        quit:(tDep="")

        // Set first child for parent node to this index (if there is no first child yet)
        set tSiblingIndex = pTree + 1
        if ($listget(pTree(tParentIndex),2) = "") {
            set $list(pTree(tParentIndex),2) = tSiblingIndex
        }

        // Set next sibling for previous node to this index.
        if (tPrevSibling '= "") {
            set $list(pTree(tPrevSibling),3) = tSiblingIndex
        }
        set tPrevSibling = tSiblingIndex

        do ..AccumulateTreeRecursive(tDep,.pModMap,.pTree,pLevel+1)
    }
}

ClassMethod ListDependents(ByRef pCommandInfo) [ Private ]
{
    set tTree = ''$data(pCommandInfo("modifiers","tree"))
    set tRepos = $listfromstring($get(pCommandInfo("modifiers","repos")))
    set tModName = $get(pCommandInfo("parameters","module"))
    set tVersion = $get(pCommandInfo("parameters","version"))
    if tModName="" {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"A module name is required"))
    }
    if tTree {
        new %tree
        set tSC = ##class(%IPM.Utils.Module).GetDependentsAsTree(.%tree,.tErrorList,tModName,tVersion,tRepos)
        $$$ThrowOnError(tSC)
    } else {
        set tSC = ##class(%IPM.Utils.Module).GetDependentsList(.tList,.tErrorList,tModName,tVersion,tRepos)
        $$$ThrowOnError(tSC)
    }
    if $data(tErrorList) {
        write !,"Warning: some errors occurred."
        for i=1:1:tErrorList {
            set $listbuild(tServer,tModName,tVersion,tErrorSC) = tErrorList(i)
            set tServer = $case(tServer,"":" (installed)",:" @ "_tServer)
            write !,tModName," ",tVersion,tServer,": ",$system.Status.GetErrorText(tErrorSC)
        }
        write !
    }

    if tTree {
        set tRef = "%tree"
        set tState = 0
        for {
            set tRef = $query(@tRef)
            quit:tRef=""
            for i=1:1:$qlength(tRef) {
                set tSub = $qsubscript(tRef,i)
                if ($get(tState(i)) = tSub) {
                    continue
                }
                set tNodeIndex = $increment(tDependentTree)
                set tState(i) = tSub
                for j=i+1:1:tState {
                    kill tState(j)
                    kill tPreviousNode
                }
                if $data(tState(i,"node"),tPreviousNode)

                set tState = i
                set tState(i,"node") = tNodeIndex

                set $listbuild(tModName,tVersion,tServer) = tSub
                set tServer = $case(tServer,"":" (installed)",:" @ "_tServer)

                set tValue = tModName_" "_tVersion_tServer

                set tDependentTree(tNodeIndex) = $listbuild(tValue)

                // Set first child
                if $data(tState(i-1,"node"),tParent) && ($listget(tDependentTree(tParent),2) = "") {
                    set $list(tDependentTree(tParent),2) = tNodeIndex
                }

                // Set next sibling of previous node
                if $data(tPreviousNode,tPreviousNode) && (tPreviousNode '= $get(tParent)) {
                    set $list(tDependentTree(tPreviousNode),3) = tNodeIndex
                }

                set tPreviousNode = tNodeIndex
            }
        }
        do ..PrintTree(.tDependentTree)
    } else {
        for i=1:1:tList.Count() {
            #dim tItem As %IPM.Storage.QualifiedModuleInfo
            set tItem = tList.GetAt(i)
            set tServer = $case(tItem.ServerName,"":" (installed)",:" @ "_tItem.ServerName)
            write !,tItem.Name," ",tItem.VersionString,tServer
        }
    }
}

/// Prints a tree with unicode box art
/// Tree representation should be:
/// pTree(<node no.>) = $listbuild(<value>, <first child node no.>, <next sibling node no.>)
/// With the first node in node #1 (no root - it can have siblings), and the subscripts are sequential
/// according to pre-order (which is how the tree will be displayed, one node per line).
ClassMethod PrintTree(ByRef pTree)
{
    set tFrontPadding = ""
    set tChildDepth = 0
    for i=1:1:$order(pTree(""),-1) {
        set tFirstChild = ""
        set tNextSibling = ""
        set $listbuild(tValue, tFirstChild, tNextSibling) = pTree(i)

        set tFrontPadding = $get(tPadding(i))

        if (tNextSibling = "") {
            set $extract(tFrontPadding,*-2) = $char($zhex("2514H"))
        }
        if (tFirstChild '= "") {
            set $extract(tFrontPadding,*) = $char($zhex("252CH"))
        }

        write tFrontPadding,$$$FormattedLine($$$Green,$piece(tValue," ",1))," ",$piece(tValue," ",2),!

        if (tNextSibling '= "") {
            set tPadding(tNextSibling) = $get(tPadding(i))
        }
        if (tFirstChild '= "") {
            set tModPadding = ""
            if ($get(tPadding(i)) '= "") {
                set tModPadding = $extract(tPadding(i),1,*-3)_$case(tNextSibling,"":" ",:$char($zhex("2502H")))_"  "
            }
            set tPadding(tFirstChild) = $extract(tModPadding,1,*-1)_$char($zhex("251CH"),$zhex("2500H"),$zhex("2500H"))
        }
    }
}

ClassMethod ListOrphans(ByRef pCommandInfo) [ Private ]
{
    set tType = $$$GetModifier(pCommandInfo,"type")
    set tResult = ##class(%IPM.Utils.Module).OrphanedResourcesFunc($namespace,tType)
    while tResult.%Next(.tSC) {
        $$$ThrowOnError(tSC)
        write tResult.%Get("Name"),!
    }
}

ClassMethod Arrange(ByRef pCommandInfo) [ Private ]
{
    set tSC = $$$OK
    set tAll = $$$HasModifier(pCommandInfo,"all")
    set tModuleName = $get(pCommandInfo("parameters","module"))
    if (tAll && (tModuleName '= "")) {
        set tSC = $$$ERROR($$$GeneralError,"Invalid command - cannot specify '-all' flag and a module name.")
    } elseif ('tAll && (tModuleName = "")) {
        set tSC = $$$ERROR($$$GeneralError,"Invalid command - must specify '-all' or a module name.")
    }
    $$$ThrowOnError(tSC)

    try {
        if (tAll) {
            set tResult = ##class(%SQL.Statement).%ExecDirect(,
                "select Name from %IPM_Storage.ModuleItem where DeveloperMode = 1")
            if (tResult.%SQLCODE < 0) {
                throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
            }
        }
        for {
            if (tAll) {
                set tHasData = tResult.%Next(.tSC)
                $$$ThrowOnError(tSC)
                if 'tHasData {
                    quit
                }
                set tModuleName = tResult.%Get("Name")
            }

            set tModule = ##class(%IPM.Storage.Module).NameOpen(tModuleName,,.tSC)
            $$$ThrowOnError(tSC)
            set tSC = ##class(%IPM.Utils.Module).ExportDocumentForObject(tModule,.tSourceControlOutput)
            $$$ThrowOnError(tSC)
            for tLine=1:1:$get(tSourceControlOutput) {
                write tSourceControlOutput(tLine),!
            }

            if 'tAll {
                quit
            }
        }
    } catch e {
        set tSC = $$$EMBEDSC($$$ERROR($$$GeneralError,"Error arranging module(s)"),e.AsStatus())
        $$$ThrowStatus(tSC)
    }
}

ClassMethod Import(ByRef pCommandInfo)
{
    set tSC = $$$OK
    set tSource = $get(pCommandInfo("parameters","source"))
    if (tSource = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"A source for import must be specified"))
    }
    try {
        set tRecurse = '$$$HasModifier(pCommandInfo,"norecurse")
        set tCompile = '$$$HasModifier(pCommandInfo,"nocompile")
        set tVerbose = $$$HasModifier(pCommandInfo,"verbose")
        set tQuiet = $$$HasModifier(pCommandInfo,"quiet")

        #dim %SourceControl As %Studio.SourceControl.ISC
        new %SourceControl
        set tSC = ##class(%Studio.SourceControl.Interface).SourceControlCreate()
        $$$ThrowOnError(tSC)

        set tSourceDir = ##class(%Library.File).NormalizeDirectory(tSource)
        set tSourceFile = ##class(%Library.File).NormalizeFilename(tSource)
        set tLoadFlags = $select(tCompile:"c",1:"")_$select(tQuiet:"-d",tVerbose:"d",1:"")_"k"
        for tListOnly = 1,0 {
            continue:tListOnly&&'$isobject(%SourceControl)
            set tLoadedList = ""
            // First pass, this lists the things that will be loaded.
            // Second pass, it loads them.
            if ##class(%Library.File).Exists(tSourceFile) {
                if ##class(%Library.File).DirectoryExists(tSourceFile) {
                    if 'tQuiet {
                        write !,"Loading "_tSourceDir
                    }
                    set tSC = $system.OBJ.ImportDir(tSourceDir,,tLoadFlags,,tRecurse,.tImportedArray,tListOnly)

                    // Build $ListBuild list of loaded items
                    set tLoadedKey = ""
                    for {
                        set tLoadedKey = $order(tImportedArray(tLoadedKey))
                        if (tLoadedKey = "") {
                            quit
                        }

                        set tLoadedList = tLoadedList_$listbuild(tLoadedKey)
                    }
                } else {
                    if 'tQuiet {
                        write !,"Loading "_tSourceFile
                    }
                    set tSC = $system.OBJ.Load(tSourceFile,tLoadFlags,,.tLoadedList,tListOnly)
                    set tLoadedList = $listfromstring(tLoadedList)
                }
            } else {
                set tSC = $$$ERROR($$$FileDoesNotExist,tSource)
            }
            $$$ThrowOnError(tSC)

            continue:'$isobject(%SourceControl)

            if tListOnly {
                // Trigger source control class's user action 6 (simulating a load into Studio)
                // This happens first to avoid warnings about the file being modified outside of Studio.
                set tSC = ##class(%Studio.SourceControl.Interface).UserAction(1,6,$listtostring(tLoadedList),"")
                $$$ThrowOnError(tSC)
            } else {
                if 'tQuiet {
                    write !,$listlength(tLoadedList)," item(s) loaded."
                    write !,"Exporting modified files."
                }

                set tPointer = 0
                set tSC = $$$OK
                while $listnext(tLoadedList,tPointer,tLoadedItem) {
                    set tLoadedItem = ##class(%Studio.SourceControl.Interface).normalizeName(tLoadedItem)

                    // Avoid comparison with file timestamp in Perforce workspace, since that's irrelevant; we have loaded a new version, likely from elsewhere.
                    // If a file has previously been exported to the Perforce workspace but not actually marked for add, GetStatus will report that the file is
                    // in source control. This case is handled later after revert is attempted and fails because the file is not known to Perforce.
                    kill ^Sources(0,"FileTimeStamp",tLoadedItem)
                    if $$$ISOK(##class(%Studio.SourceControl.Interface).GetStatus(tLoadedItem,.tIsInSourceControl)) {
                        if tIsInSourceControl {
                            set tSC = $$$ADDSC(tSC,%SourceControl.OnAfterSave(tLoadedItem))
                        } else {
                            set tSC = $$$ADDSC(tSC,%SourceControl.AddToSourceControl(tLoadedItem))
                        }
                    }
                }
            }
        }
    } catch e {
        // Append string rather than using $System.Status.EmbedStatus, for clearer display in caller.
        set tSC = $$$ERROR($$$GeneralError,"Error in import: "_$system.Status.GetErrorText(e.AsStatus()))
        $$$ThrowStatus(tSC)
    }
}

ClassMethod UpdateLanguageExtensionsOne(
	RoutineName As %String,
	pTestOnly As %Boolean = 0,
	Output pFound As %Boolean = 0,
	ByRef tGenLines) As %Status
{
    set tRtn = ##class(%Routine).%New(RoutineName)
    if ##class(%Routine).Exists(RoutineName) {
        while 'tRtn.AtEnd {
            set tLine = tRtn.ReadLine()
            if $match(tLine,$$$STARTTAGREGEX) {
                // Read through the ending tag.
                while ('tRtn.AtEnd) && ('$match(tRtn.ReadLine(),$$$ENDTAGREGEX)) {}

                // Generate the lines.
                set pFound = 1
                for i=1:1:tGenLines {
                    set tRtnLines($increment(tRtnLines)) = tGenLines(i)
                }
            } else {
                // outside of the tags, just copy the lines to preserve users' custom code
                set tRtnLines($increment(tRtnLines)) = tLine
            }
        }
        if 'pFound {
            for i=1:1:tGenLines {
                set tRtnLines($increment(tRtnLines)) = tGenLines(i)
            }
        }
    } else {
        merge tRtnLines = tGenLines
    }
    if (pTestOnly) {
        quit
    }
    do tRtn.Clear()
    for i=1:1:tRtnLines {
        do tRtn.WriteLine(tRtnLines(i))
    }
    $$$ThrowOnError(tRtn.Save())
    $$$ThrowOnError(tRtn.Compile("/keepsource"))
    quit $$$OK
}

ClassMethod UpdateLanguageExtensions(
	pVerbose As %Boolean = 0,
	pTestOnly As %Boolean = 0,
	Output pFound As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        tstart
        // Get routine lines to generate
        set tOffset = 0
        set tStarted = 0
        set labelPrefix = $select($system.Version.GetMajor() >= 2023: "",1: "z")
        set method = ##class(%Dictionary.MethodDefinition).IDKEYOpen($classname(),"LanguageExtensions",,.sc)
        $$$ThrowOnError(sc)
        set tGenLines($increment(tGenLines)) = $$$STARTTAGQ
        while 'method.Implementation.AtEnd {
            set tGenLines($increment(tGenLines)) = method.Implementation.ReadLine()
        }
        set tGenLines($increment(tGenLines)) = $$$ENDTAGQ

        if '$data(tGenLines) {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"Could not find %ZLANGC00 routine contents in "_$classname()))
        }
        do ..UpdateLanguageExtensionsOne("%ZLANGC00.MAC", pTestOnly,.pFound,.tGenLines)
        quit:pTestOnly
        set i=""
        for { set i=$order(tGenLines(i),1,tStr) quit:i=""
            if tStr["Do ##class" set tGenLines(i)=$replace($replace(tStr,"Quit",""),"Do ","Quit ") quit
        }
        do ..UpdateLanguageExtensionsOne("%ZLANGF00.MAC", pTestOnly,.pFound,.tGenLines)
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) {
        trollback 1
    }
    quit tSC
}

ClassMethod LanguageExtensions() [ Private ]
{
ZPM(pArgs...)
 if $system.CLS.IsMthd("%IPM.Main", "Shell") {
     do ##class(%IPM.Main).Shell(pArgs...) quit
 } else {
    // TODO: Needs to support enabling IPM from here, also need to decide what level of customization to provide
    set quitOnError = $get(pArgs(2))
    set haltOnComplete = $get(pArgs(3))
    write !, "IPM is not enabled in this namespace."
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Nsp FROM %SYS.Namespace_List()")
    if rs.%SQLCODE '= 0 {
        write !, "Error getting namespace name. SQLCODE =", rs.%SQLCODE
    } else {
        new $namespace
        set found = 0
        while rs.%Next() {
            set $namespace = $zstrip(rs.%Get("Nsp"), "<>WC")
            // Some I4H containers come with %IPM.Main but the "version" command doesn't work ?!
            if $system.CLS.IsMthd("%IPM.Main", "Shell") && ($namespace '= "HSLIB") && ($namespace '= "HSSYS") {
                write !, "Change namespace to one of the following to run the ""zpm"" command"
                do ##class(%IPM.Main).Shell("version")
                write !, "If you want to map IPM globally, switch to one of the namespaces above and run: zpm ""enable -map -globally""."
                write !, "If you want to reset repository and map IPM globally along with repository settings, switch to one of the namespaces above and run: zpm ""enable -community""."
                set found = 1
                quit
            }
        }
        // Shouldn't happen since %ZLANGC00.mac and %ZLANGF00.mac are present
        if 'found {
            write !, "No namespace found with IPM enabled."
        }
    }

    if quitOnError {
        write ! // Add a newline before quitting, otherwise the shell prompt will be on the same line as the error message
        do $system.Process.Terminate($job, 1)
    }
    if haltOnComplete {
        write ! // Add a newline before halting
        halt
    }
    // The $$$ERROR macro is not available for use in language extension
    return $system.Status.Error(5001, "IPM is not enabled in this namespace.")
 }
}

ClassMethod EnableIPM(ByRef pCommandInfo)
{
    new $namespace
    set initNamespace = $namespace
    if ..IPMInstalled(.ipmModuleId){
        set modDef = ##class(%IPM.Storage.Module).%OpenId(ipmModuleId,,.sc)
        $$$ThrowOnError(sc)
        write !, "Version of IPM in current namespace: "
        write !,($namespace)_"> "_$$$FormattedLine($$$Green,$$$IPMModuleName_" ")_modDef.VersionString
    }

    if $$$HasModifier(pCommandInfo,"community") {
        for cmd = "repo -delete-all", "repo -reset-defaults", "enable -map -repos -globally" {
            write !!, "RUNNING command: """, cmd, """"
            do ..ShellInternal(cmd, .exc)
            if exc '= $$$NULLOREF {
                write !, $$$FormattedLine($$$Red, $$$FormatText("Error running command ""%1"" - %2", cmd, exc.DisplayString()))
            } else {
                write !, $$$FormattedLine($$$Green, $$$FormatText("Command ""%1"" finished successfull", cmd))
            }
        }
        return
    }

    set quiet = $$$HasModifier(pCommandInfo,"quiet")
    set preview = $$$HasModifier(pCommandInfo,"preview")
    set map = $$$HasModifier(pCommandInfo,"map")
    set globally = $$$HasModifier(pCommandInfo, "globally")
    set localOnly = $$$HasModifier(pCommandInfo, "local-only")
    set version = $$$GetModifier(pCommandInfo, "version")
    set namespaces = $$$GetModifier(pCommandInfo, "namespaces")
    set namespaces = $$$ucase(namespaces)
    set allowUpgrade = $$$HasModifier(pCommandInfo,"allow-upgrade")
    set mapRepos = $$$HasModifier(pCommandInfo,"repos")
    set remoteName = $$$GetModifier(pCommandInfo,"remote")
    set useLocal = 1			// var to store the final decision of whether to use local manifest or get from server
    set targetVersion = "" 		// var to store the final version of IPM to be installed
    kill targetNamespaces 		// multi-dim array to store the final namespaces that need to install IPM
    set loadFlag = "ck/displayerror=1/displaylog=0" // flags + modifiers to use when loading module manifest file / stream - ensure compilation and only display error instead of entire log

    // basic sanity checks
    if (quiet && (namespaces = "") && 'globally) {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"Cannot install IPM in quiet mode without specifying namespaces to install."))
    }
    if ((namespaces '= "") && globally) {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"Cannot specify namespaces and global installation flag at the same time."))
    }
    if (version '= "") && (globally && map) {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"Cannot specify version when mapping the currently-installed version globally."))
    }
    if map && 'globally && (namespaces = "") {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"If mapping from the current namespace's routine database with -map, must specify either -globally or a list of namespaces with -ns"))
    }
    if ('map) && (mapRepos) {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"Cannot specify -repos without -map"))
    }

    if map {
        if globally {
            set namespaces = ""
            do ..GetListNamespace(.list)
            // Namespace-specific mappings aren't allowed to override %ALL mappings. See https://github.com/intersystems/ipm/pull/485
            kill list("%ALL")
            set key = ""
            for {
                set key = $order(list(key))
                if key = "" {
                    quit
                }
                set namespaces = namespaces _ $listbuild(key)
            }
        } else {
            set namespaces = $listfromstring(namespaces)
        }

        // First try to map IPM itself
        set pointer = 0
        while $listnext(namespaces,pointer,namespace) {
            set namespace = $zstrip(namespace, "<>WC")
            set $namespace = namespace
            if ..IPMInstalled() {
                if 'quiet || preview {
                    write !,"Skipping IPM mapping of "_namespace_" - IPM already installed."
                }
                continue
            }
            set $namespace = initNamespace
            if preview {
                write !,"Would add IPM mappings to "_namespace
                continue
            }
            if 'quiet {
                write !,"Mapping %IPM package in "_initNamespace_" equivalently to "_namespace
            }
            $$$ThrowOnError(##class(%IPM.Utils.Build).MapPackageEquivalently("%IPM",initNamespace,namespace))
            if 'quiet {
                write !,"Mapping %IPM.* routines in "_initNamespace_" equivalently to "_namespace
            }
            $$$ThrowOnError(##class(%IPM.Utils.Build).MapRoutineEquivalently("%IPM.*",initNamespace,,namespace))
        }

        // Then try to map repositories if -repos is specified
        if mapRepos {
            do ..GetMapInfo(.isMappedFrom)
            set pointer = 0
            while $listnext(namespaces,pointer,namespace) {
                set namespace = $zstrip(namespace, "<>WC")
                // If IPM is not mapped from source namespace, skip repo mapping
                if $get(isMappedFrom(namespace)) '= initNamespace {
                    if 'quiet || preview {
                        write !,"Skipping repository mapping of "_namespace_" - IPM not mapped from source namespace."
                    }
                    continue
                }
                // If repository are already present, also skip repo mapping avoid override
                set $namespace = namespace
                if $data(^IPM.Repo.DefinitionD) \ 2 {
                    if 'quiet || preview {
                        write !,"Skipping repository mapping of "_namespace_" - IPM repositories found."
                    }
                    continue
                }
                set $namespace = initNamespace
                if preview {
                    write !,"Would add IPM repository mappings to "_namespace
                    continue
                }
                if 'quiet {
                    write !,"Mapping IPM repository in "_initNamespace_" equivalently to "_namespace
                }
                for suffix = "D", "S", "I" {
                    $$$ThrowOnError(##class(%IPM.Utils.Build).MapGlobalEquivalently("IPM.Repo.Definition"_suffix, initNamespace, namespace))
                }
            }
        }

        set $namespace = initNamespace
        if preview {
            write !,"Preview mode; no configuration changes were made."
        } elseif 'quiet {
            write !,"Done.",!
            do ..Version()
        }
        return
    }

    new $namespace
    // 1. Get list of local IPM artifacts under /<instance install dir>/lib/ipm/
    set XMLDir = $system.Util.InstallDirectory()
    for subDirName = "lib", "ipm" {
        set XMLDir = ##class(%File).SubDirectoryName(XMLDir, subDirName)
    }
    set statement = ##class(%SQL.Statement).%New()
    set sc = statement.%PrepareClassQuery("%File", "FileSet")
    $$$ThrowOnError(sc)
    // Valid IPM installation manifest should be of format: ipm-0.0.1.xml
    if ##class(%File).DirectoryExists(XMLDir) {
        set resultSet = statement.%Execute(XMLDir, "ipm-*.xml")
        $$$ThrowSQLIfError(resultSet.%SQLCODE,resultSet.%Message)
        kill ipmLocalArray			// multi-dim array to store local ipm manifests; ipmLocalArray(<version>)=<fileName>
        kill menuList				// menu to let user choose which version of local ipm to install (if not in quiet mode and no version is specified)
        while resultSet.%Next(.sc) {
            $$$ThrowOnError(sc)
            set fileName = resultSet.%Get("Name")
            if (resultSet.%Get("Type") = "F") {
                // get the exact version string from filename
                set exactIPMVer = $piece($piece(fileName, "ipm-", 2, *), ".xml", 1, *-1)
                set ipmLocalArray(exactIPMVer) = fileName
                set menuList($increment(menuList)) = exactIPMVer_" (local version)"
            }
        }
        $$$ThrowOnError(sc)
    }

    if ('$data(menuList) && localOnly) {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"No ipm-<version>.xml installer file is found locally in directory: "__XMLDir))
    }

    // 2. Choose / propmpt user to choose which local/remote version of IPM to install
    if (version '= "") {
        set targetVersion = version
        if '$data(ipmLocalArray(version)) {
            if localOnly {
                $$$ThrowOnError($$$ERROR($$$GeneralError,"No ipm-"_version_".xml installer file is found locally in directory: "_XMLDir))
            }
            write !, "No ipm-"_version_".xml installer file is found in "_XMLDir_" locally. Trying to download from the registry."
            // need to get from remote registry server
            set useLocal = 0
        }
    } else {
        if quiet {
            // quiet mode + no version specified - either error out or install latest version from registry / locally
            if localOnly {
                //using semantic version utility, find the latest local version and install
                set key = ""
                while 1 {
                    set key = $order(ipmLocalArray(key))
                    set currentVer = ipmLocalArray(key)
                    if (targetVersion = "") {
                        set targetVersion = currentVer
                        continue
                    }
                    set semVerTarget = ##class(%IPM.General.SemanticVersion).FromString(targetVersion)
                    set semVerCurrent = ##class(%IPM.General.SemanticVersion).FromString(currentVer)
                    if semVerCurrent.Follows(semVerTarget) {
                        set targetVersion = currentVer
                    }
                }
            } else {
                write !, "No IPM version is specified and is in quiet mode. Install the latest version of IPM from the registry."
                set useLocal = 0
                set targetVersion = "latest"
            }
        } else {
            // prompt user with option to download the latest version from registry
            set localIPMCount = $get(menuList, 0)
            if 'localOnly {
                // Add remote version options to menuList
                set server = ##class(%IPM.Repo.Remote.Definition).GetOne(remoteName, .sc)
                $$$ThrowOnError(sc)
                if $isobject(server) {
                    set latestVersion = server.GetPackageService().GetLatestModuleVersion($$$IPMModuleName)
                    set menuList($increment(menuList)) = "latest"_" (remote version - "_latestVersion_")"
                }
                kill server
                kill packageService
            }
            set menuValue = 1
            set menuResponse = ##class(%Library.Prompt).GetMenu("Which version of IPM to use?", .menuValue, .menuList,,128)
            if (menuResponse '= 1) {
                $$$ThrowOnError($$$ERROR($$$GeneralError,"Unsupported response. Operation cancelled."))
            }
            set targetVersion = $piece(menuList(menuValue), " ") // get rid of (local version) or (remote version) suffix
            if (menuValue > localIPMCount) {
                set useLocal = 0
            }
        }
    }

    // Now we know which exact version to install and we know whether we should install it with local artifact or get from registry,
    // 3. Figure out which namespaces to install

    // TODO: Let user interactively choose which namespaces to install IPM
    set baseNS = $namespace
    set sc = ##class(%SYS.Namespace).ListAll(.allNS)
    $$$ThrowOnError(sc)
    // multi-dim array to store all non-%SYS explicit namepaces that
    // either have no IPM installed (if allow-upgrade is not set)
    // or all of them (if allow-upgrade is set)
    kill namespacesForIPM
    set currentNS = ""
    if allowUpgrade {
        merge namespacesForIPM = allNS
    } else {
        while 1 {
            set currentNS = $order(allNS(currentNS))
            if currentNS = "" {
                quit
            }
            // avoid %SYS and implied namespaces
            if (currentNS '= "%SYS") && ($zconvert(currentNS, "U") = currentNS) {
                set $namespace = currentNS
                if '$system.CLS.IsMthd("%IPM.Main", "Shell") {
                    set namespacesForIPM(currentNS) = 1
                }
            }
        }
    }
    set $namespace = baseNS
    if globally {
        merge targetNamespaces = namespacesForIPM
    } elseif (namespaces '= "") {
        set specifiedNSs = $listfromstring(namespaces, ",")
        set ptr = 0
        while $listnext(specifiedNSs, ptr, value) {
            if '$data(namespacesForIPM(value)) {
                write !, value_" is not a valid namespace to install IPM"_$select(allowUpgrade: ". ", 1: ", or it already has IPM installed. ")_"Skipped."
            } else {
                set targetNamespaces(value) = 1
            }
        }
    } else {
        // TODO: Implement this part
        write !, "Currently do not support interactively choose namespaces to install IPM. Use -namespaces or -globally modifier."
        return
    }

    // 4. Now that we got all the namespaces that need to install IPM, do the actual installation
    if 'useLocal {
        set server = ##class(%IPM.Repo.Remote.Definition).GetOne(remoteName, .sc)
        $$$ThrowOnError(sc)
        if $isobject(server) {
            set packageService = server.GetPackageService()
            set ipmRef = ##class(%IPM.Storage.ModuleInfo).%New()
            set ipmRef.Name = $$$IPMModuleName
            if (targetVersion = "latest") {
                // convert latest to semantic version so that it can be undestood by ModuleInfo class
                set server = ##class(%IPM.Repo.Remote.Definition).GetOne(remoteName, .sc)
                $$$ThrowOnError(sc)
                if $isobject(server) {
                    set targetVersion = server.GetPackageService().GetLatestModuleVersion($$$IPMModuleName)
                }
            }
            if (targetVersion = "") {
                $$$ThrowOnError($$$ERROR($$$GeneralError,"Failed to find a satisfying target version of IPM to install."))
            }
            set ipmRef.VersionString = targetVersion

            // Retrieve module installer manifest
            set manifest = packageService.GetModuleInstallerManifest(ipmRef)
            set currentNS = ""
            while 1 {
                set currentNS = $order(targetNamespaces(currentNS))
                if currentNS = "" {
                    quit
                }
                set $namespace = currentNS
                if preview {
                    write !, $$$FormatText("Would install IPM version %1 from registry in namespace %2", targetVersion, currentNS)
                    continue
                }
                do $system.OBJ.LoadStream(manifest, loadFlag)
                write !, "IPM enabled for namespace "_currentNS
            }
        } else {
            $$$ThrowOnError($$$ERROR($$$GeneralError,"Failed to get a valid registry server in order to download the IPM manifest."))
        }
    } else {
        set targetIPMFileName = ipmLocalArray(targetVersion)
        set currentNS=$order(targetNamespaces(""))
        set enabledNSList = ""
        set problematicList = ""
        set tOverallSC = $$$OK
        while (currentNS '="") {
            set $namespace = currentNS
            if preview {
                set filePath = ##class(%File).NormalizeFilename(targetIPMFileName, XMLDir)
                write !, $$$FormatText("Would install IPM using file at %1 in namespace %2", filePath, currentNS)
                continue
            }
            set tSC = $system.OBJ.Load(##class(%File).NormalizeFilename(targetIPMFileName, XMLDir), loadFlag)
            if $$$ISOK(tSC) {
                set enabledNSList = enabledNSList_$listbuild(currentNS)
            } else {
                set problematicList = problematicList_$listbuild(currentNS)
            }
            set currentNS = $order(targetNamespaces(currentNS))
            set tOverallSC = $$$ADDSC(tOverallSC,tSC)
        }
        if 'preview {
            write !, "IPM enabled for namespace(s) "_$listtostring(enabledNSList)
            if $$$ISERR(tOverallSC) {
                write !, "IPM failed to enable for namespace "_$listtostring(problematicList)
                $$$ThrowOnError(tOverallSC)
            }
        }
    }

    if preview {
        write !,"Preview mode; no configuration changes were made."
    }
}

ClassMethod UnmapIPM(ByRef pCommandInfo)
{
    set globally = $$$HasModifier(pCommandInfo,"globally")
    set namespaces = $listfromstring($$$GetModifier(pCommandInfo,"namespaces"), ",")
    set namespaces = $$$ucase(namespaces)
    set verbose = '$$$HasModifier(pCommandInfo,"quiet")
    set reposOnly = $$$HasModifier(pCommandInfo,"repos-only")
    // Sanity check
    if (globally && (namespaces '= "")) {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"Cannot specify namespaces and global unmap flag at the same time."))
    }
    if ('globally && (namespaces = "")) {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"Must specify either -globally or a list of namespaces with -ns"))
    }
    // populate namespaces if globally is set
    if globally {
        do ..GetListNamespace(.nsTree)
        set ns = ""
        for {
            set ns = $order(nsTree(ns))
            if ns = "" {
                quit
            }
            set namespaces = namespaces_$listbuild(ns)
        }
    }
    if verbose {
        if reposOnly {
            write !,"Will attempt to unmap IPM repository settings from: "_ $listtostring(namespaces, ", ")
        } else {
            write !,"Will attempt to unmap IPM package, routines, and repository settings from: "_ $listtostring(namespaces, ", ")
        }
    }

    // Gather namespaces where %IPM is mapped into
    do ..GetMapInfo(.tIsMappedFrom)

    set ptr = 0
    while $listnext(namespaces, ptr, ns) {
        set src = $get(tIsMappedFrom(ns))
        if (src = "") {
            if verbose {
                write !,"No mapping found for "_ns_". Skipping."
            }
            continue
        }

        if verbose {
            write !,"Unmapping repository settings from "_ns_" (mapped from "_src_")"
        }
        for suffix = "D", "S", "I" {
            $$$ThrowOnError(##class(%IPM.Utils.Module).RemoveGlobalMapping(ns, "IPM.Repo.Definition"_suffix))
        }

        if 'reposOnly {
            if verbose {
                write !,"Unmapping IPM package and routines from "_ns_" (mapped from "_src_")"
            }
            $$$ThrowOnError(##class(%IPM.Utils.Module).RemovePackageMapping(ns, "%IPM"))
            $$$ThrowOnError(##class(%IPM.Utils.Module).RemoveRoutineMapping(ns, "%IPM.*"))
        }
    }
}

ClassMethod ModuleVersion(ByRef pCommandInfo)
{
    set modName = $get(pCommandInfo("parameters","module"))
    set quiet = $$$HasModifier(pCommandInfo,"quiet")
    set force = $$$HasModifier(pCommandInfo,"force")
    if (modName = "") {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"No module name specified."))
    }
    set mod = ##class(%IPM.Storage.Module).NameOpen(modName,.sc)
    if (mod = "") {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"Module "_modName_" not found."))
    }
    set stream = ##class(%IPM.StudioDocument.ModuleStream).NameOpen(modName)
    if (stream = "") {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"Module stream "_modName_" not found."))
    }
    if 'quiet {
        write !,$$$FormatText("Current version of module %1 is: %2", modName, mod.VersionString)
    }

    // Compute the new semver
    set versionString = $get(pCommandInfo("parameters","version"))
    if versionString = "major" {
        set semver = mod.Version.WithBumpMajor()
    } elseif versionString = "minor" {
        set semver = mod.Version.WithBumpMinor()
    } elseif versionString = "patch" {
        set semver = mod.Version.WithBumpPatch()
    } elseif versionString = "" {
        set semver = ##class(%IPM.General.SemanticVersion).FromString(mod.Version.ToString())
    } else {
        set semver = ##class(%IPM.General.SemanticVersion).FromString(versionString)
    }

    // Validate the semver
    if 'semver.%ValidateObject() {
        $$$ThrowOnError($$$ERROR($$$GeneralError,"Invalid version string: "_versionString))
    }

    if $$$HasModifier(pCommandInfo,"prerelease") {
        set semver = semver.WithPrerelease($$$GetModifier(pCommandInfo,"prerelease"))
    }
    if $$$HasModifier(pCommandInfo,"build") {
        set semver = semver.WithBuild($$$GetModifier(pCommandInfo,"build"))
    }

    // Ensure semver is not lower than the current version, unless force is set
    if ('force) && ('semver.Follows(mod.Version)) {
        set msg = $$$FormatText("Cannot set version to %1 as it is not strictly higher than the current version %2 (Use -force to override)", semver.ToString(), mod.VersionString)
        set msg = msg _ $char(10, 13) _ "Note: when either version has a nonempty prerelease value, and differ from the other by major.minor.patch, neither version is considered strictly higher than the other."
        set msg = msg _ $char(10, 13) _ "      See https://github.com/npm/node-semver?tab=readme-ov-file#prerelease-tags for more information."
        $$$ThrowOnError($$$ERROR($$$GeneralError, msg))
    }
    if (semver.ToString() = mod.Version.ToString()) {
        if 'quiet {
            write !,"Version is unchanged - Skipping."
        }
        return
    }

    if 'quiet {
        write !,$$$FormatText("Setting version of module %1 to: %2", modName, semver.ToString())
    }

    set initTLevel = $tlevel
    set ex = $$$NULLOREF
    tstart
    try {
        new %SourceControl
        set docName = modName_".ZPM"
        do ##class(%Studio.SourceControl.Interface).SourceControlCreate()
        if $isobject($get(%SourceControl)) {
            write !,"Checking out "_docName
            $$$ThrowOnError(%SourceControl.CheckOut(docName))
        }
        set mod.Version = semver
        set mod.VersionString = semver.ToString()
        $$$ThrowOnError(mod.%Save())
        do ##class(%IPM.StudioDocument.Module).UpdateVersion(modName,semver)
        tcommit
    } catch ex {
    }
    while ($tlevel > initTLevel) {
        trollback 1
    }
    if $isobject(ex) {
        throw ex
    }
}

/// Get the mapping relationship for %IPM package. Format:
/// <ul>
/// <li>pIsMappedFrom(destinationNamespace) = sourceNamespace</li>
/// <li>pIsMappedTo(sourceNamespace, destinationNamespace) = ""</li>
/// </ul>
ClassMethod GetMapInfo(
	Output pIsMappedFrom,
	Output pIsMappedTo)
{
    kill pIsMappedFrom, pIsMappedTo
    do ..GetListModules("*", $$$IPMModuleName, .list)
    do ..AddIPMMappedNamespaces(.list)
    for i = 1:1:list {
        set destNS = $listget(list(i))
        if $data(list(i,  "modules", 1, "Installed In"), srcNS) # 2 {
            set pIsMappedFrom(destNS) = srcNS
            set pIsMappedTo(srcNS, destNS) = ""
        }
    }
}

ClassMethod IPMInstalled(ByRef ipmModuleId) As %Boolean [ CodeMode = expression ]
{
$$$comClassDefined("%IPM.Storage.Module") && ##class(%IPM.Storage.Module).NameExists($$$IPMModuleName, .ipmModuleId)
}

ClassMethod History(ByRef pCommandInfo)
{
	set action = $get(pCommandInfo("parameters", "action"))

	set globally = $$$HasModifier(pCommandInfo, "globally")
	set ascend = ($$$GetModifier(pCommandInfo, "sort") = "asc")
	set confirm = $$$HasModifier(pCommandInfo, "confirm")
	set limit = $$$GetModifier(pCommandInfo, "limit")
	set limit = $select(limit="": ##class(%IPM.Repo.UniversalSettings).GetValue("DefaultLogEntryLimit"), limit=0: "", 1: +limit)
	merge filter = pCommandInfo("data", "zpm")

	if (action = "find") || (action = "") {
        if globally {
            do ##class(%IPM.General.History).GetHistoryGlobally(.filter, ascend, limit, 1)
        } else {
            do ##class(%IPM.General.History).GetHistory(.filter, ascend, limit, 1)
        }
	} elseif action = "details" {
		set id = $get(pCommandInfo("parameters", "argument"))
		do ##class(%IPM.General.History).DisplayOneRecord(id)
	} elseif action = "schema" {
		$$$ThrowOnError($system.SQL.Schema.GetAllColumns("%IPM_General.History", , .columns))
		write "Columns available for filtering are: "
		set idx = ""
		for {
			set idx = $order(columns(idx), 1, col)
			if idx = "" {
				quit
			}
			if $extract(col, 1, 3) = "x__" {
				continue
			}
			write !, "- ", col
		}
	} elseif action = "delete" {
		if ($data(filter) \ 2 = 0) && ('globally) && ('confirm) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No filter specified. Should specify at least one column to filter on or pass -confirm to delete all records in the current namespace."))
		}
        if globally {
		    set count = ##class(%IPM.General.History).DeleteHistoryGlobally(.filter)
        } else {
		    set count = ##class(%IPM.General.History).DeleteHistory(.filter)
        }
		write !, "Deleted ", count, " record(s)."
	} else {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Invalid action specified. Use `help history` to see available actions."))
	}
}

/// Runs package manager commands in a way that is friendly to the OS-level shell.
/// Creates <var>pOutputLogFile</var> if it does not exist.
/// If it does, and <var>pAppendToLog</var> is true, appends to it; otherwise, deletes the file before outputting to it.
ClassMethod ShellScript(
	pCommand As %String,
	pOutputLogFile As %String = "",
	pAppendToLog As %Boolean = 0)
{
    set tSC = $$$OK
    set tFileOpen = 0
    try {
        if (pOutputLogFile '= "") {
            // Append to pOutputLogFile if it exists and pAppendToLog is true.
            set tParams = "WS"_$select(
                '##class(%Library.File).Exists(pOutputLogFile):"N",
                pAppendToLog:"A",
                1:"N")
            open pOutputLogFile:tParams:1
            if '$test {
                set tSC = $$$ERROR($$$FileNotOpen,pOutputLogFile)
                $$$ThrowStatus(tSC)
            }
            set tFileOpen = 1
            use pOutputLogFile
        }
        write !!,">>",pCommand,!
        set tSC = ..Shell(pCommand)
        $$$ThrowOnError(tSC)
    } catch e {
        set tSC = e.AsStatus()
        do e.Log()
    }

    write !
    if tFileOpen {
        close pOutputLogFile
    }

    if $$$ISERR(tSC) {
        // Set ERRORLEVEL to 1
        do $system.Process.Terminate(,1)
    }
}

ClassMethod DisplayModules(
	ByRef pList,
	pNumbered As %Boolean = 0,
	pWithNamespace As %Boolean = 0,
	pIndent As %Integer = 0,
	ByRef pModifiers)
{
    if '$data(pList) {
        quit
    }
    set pWithNamespace = pWithNamespace || $data(pList("ns"))
    if pWithNamespace {
        set nsWidth = $get(pList("width")) + 2
        set numbersWidth = $select(pNumbered: $length(pList) + 3, 1: 0)
        set modulesWidth = 0
        for i=1:1:pList {
            if $data(pList(i, "modules", "width"), width), width > modulesWidth {
                set modulesWidth = width
            }
        }
        for i=1:1:pList {
            set $listbuild(tNS) = pList(i)
            write !
            if pNumbered {
                write $justify(i, numbersWidth - 2), ". "
            }
            write $$$FormattedLinePadRight($$$Magenta, tNS _ "> ", nsWidth)
            set tPrefix = $justify("", numbersWidth) _ tNS
            kill tModulesList
            merge tModulesList = pList(i, "modules")
            set tModulesList("width") = modulesWidth
            do ..DisplayModules(.tModulesList, 0, 0, $x)
        }
        quit
    }

    set extraColumns = $listbuild(
        $listbuild("Description", $$$Yellow),
        $listbuild("Root", $$$Magenta),
        $listbuild("Author.CopyrightDate", $$$Yellow, "CopyrightDate"),
        $listbuild("Author.License", $$$Yellow, "License"),
        $listbuild("Author.Notes", $$$Yellow, "Notes"),
        $listbuild("Author.Organization", $$$Yellow, "Organization"),
        $listbuild("Author.Person", $$$Yellow, "Author"),
        $listbuild("Origin", $$$Default),
        $listbuild("AllVersions", $$$Default, "Versions"),
        $listbuild("Repository", $$$Default),
        $listbuild("Installed In", $$$Default)
    )

    kill serverVersions
    if $data(pModifiers("showupstream")) {
       do ..GetUpstreamPackageVersions(.serverVersions)
    }

    set width = $get(pList("width")) + 1
    set tIndent = pIndent
    set tIndent = $select(pIndent > 0: pIndent, 1: width)
    for i=1:1:pList {
        set info = pList(i)
        set developerMode = 0
        set root = ""
        set $listbuild(name, version, externalName, developerMode, root, lastUpdated) = info
        write:i>1 !,?pIndent
        write $$$FormattedLinePadRight($$$Green, name, width), $$$FormattedLine($$$Default, version)
        if $data(pModifiers("showupstream")) && ($data(serverVersions(name)) / 10) {
            set r = ""
            set diffs = ""
            for {
                set r = $order(serverVersions(name, r), 1, sVer)
                if (r = "") {
                    quit
                }
                if (sVer '= version) {
                    set diffs = diffs_$listbuild($$$FormatText("%1: %2", r, sVer))
                }
            }
            if (diffs '= "") {
                write " ", $$$FormattedLine($$$Default, "(" _ $listtostring(diffs, ", ") _ ")")
            }
        }
        if $get(developerMode) {
            write " ", $$$FormattedLine($$$Red, "(DeveloperMode)")
        }
        if $data(pModifiers("showsource")) {
            write " ", $$$FormattedLine($$$Magenta, root)
        }
        if $data(pModifiers("showtime")) && ($data(lastUpdated) # 2) {
            write " ", $$$FormattedLine($$$Yellow, lastUpdated)
        }

        set ptr = 0
        while $listnext(extraColumns, ptr, column) {
            continue:$get(column)=""
            set colName = ""
            set $listbuild(colValue, color, colName) = column
            set colName = $select($get(colName)'="": colName, 1: colValue)
            if $data(pList(i, colValue), value) && (value'="") {
                write !,?tIndent
                do ..DrawColumn($$$FormattedLine(color, colName _ ": ") _ value)
            }
        }
    }
}

ClassMethod GetUpstreamPackageVersions(Output list)
{
    set query = "SELECT %DLIST(Name) AS Repos FROM %IPM_Repo.Definition"
    set rs = ##class(%SQL.Statement).%ExecDirect(, query)
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    if rs.%Next() {
        set repos = rs.%Get("Repos")
    }

    set ptr = 0
    while $listnext(repos, ptr, r) {
        set query = "SELECT Name,Version FROM %IPM_Utils.Module_GetModuleList(?,?) "
        set rs = ##class(%SQL.Statement).%ExecDirect(, query, r, 0)
        while rs.%Next() {
        set list(rs.%Get("Name"), r) = rs.%Get("Version")
        }
    }
}

/// Provides information on all installed top level modules (i.e. modules that are not depended on)
ClassMethod Information(ByRef pCommandInfo)
{
  set verbose = $$$HasModifier(pCommandInfo,"verbose")
  // Figure out which installed modules are not dependencies by
  // 1) getting list of all installed modules
  // 2) getting list of all dependencies
  // and 3) cross checking the two lists
  do ..GetListModules(,,.modList)
  set depRes = ##class(%SQL.Statement).%ExecDirect(,
    "select ModuleItem->Name ModName,Dependencies_Name DepName,Dependencies_VersionString DepVer "_
    "from %IPM_Storage.ModuleItem_Dependencies")
  $$$ThrowSQLIfError(depRes.%SQLCODE, depRes.%Message)
  while depRes.%Next(.sc) {
    $$$ThrowOnError(sc)
    set visited($zconvert(depRes.%Get("DepName"),"l")) = 1
  }
  $$$ThrowOnError(sc)

  set topLevelList("width") = 0
  for i = 1:1:modList {
    set entry = modList(i)
    set name = $listget(entry, 1)
    // only list non-dependencies
    if '$data(visited(name)) {
      // compile information
      set externalName = $list(entry, 3)
      if (externalName '= "") && (externalName '= name) {
        if verbose {
          set $list(entry, 1) = externalName_" (" _ name _ ")"
        } else {
          set $list(entry, 1) = externalName
        }
      }
      if topLevelList("width") < $length($listget(entry)) {
        set topLevelList("width") = $length($listget(entry))
      }
      set version = ##class(%IPM.General.SemanticVersion).FromString($list(entry, 2))
      set $list(entry, 2) = version.ToStringWithoutBuild()
      set topLevelList($increment(topLevelList)) = entry
    }
  }

  set messages = ..BuildIntroMessages(.outOfBoxMessage)
  set messages = messages _ $listbuild(outOfBoxMessage)
  set ptr = 0
  while $listnext(messages, ptr, line) {
    write !, line
  }
  write !!, "Currently installed top-level modules are listed below:", !
  do ..DisplayModules(.topLevelList)
}

ClassMethod Update(ByRef pCommandInfo)
{
    if $get(pCommandInfo("data","PermitDowngrade"),0) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"The 'PermitDowngrade' flag is not allowed for the update command."))
    }
    set verbose = $get(pCommandInfo("data","Verbose"))
    set version = $get(pCommandInfo("parameters","version"))
    set path = $$$GetModifier(pCommandInfo,"path")
    set moduleName = $get(pCommandInfo("parameters","module"))
    if '##class(%IPM.Storage.Module).NameExists(moduleName) && '##class(%IPM.Storage.Module).ExternalNameExists(moduleName) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Module "_moduleName_" has not been installed. Please use the install or load commands to install the module before calling update."))
    }
    if verbose {
        if path '= "" {
            write !,"Resolving version of module specified by -path flag: ",path," to update",!
        } elseif version = "" {
            write !,"Resolving latest available version of module ",moduleName," to install",!
        } else {
            write !,"Preparing to update module ",moduleName," to version ",version,!
        }
    }
    // Indicating to pCommandInfo that this is an update command, not an install or load command. pCommandInfo will be passed to either Install() or Load() to continue performing the update.
    set pCommandInfo("data","cmd") = "update"
    set pCommandInfo("data","Update") = 1
    set pCommandInfo("data","ModuleName") = moduleName
    if path '= "" {
        // A path to a tarball is specified. Call ..Load() in order to load the newer version of the module.
        set pCommandInfo("parameters","path") = path
        do ..Load(.pCommandInfo)
    } else {
        // Call ..Install() in order to install the newer version of the module.
        do ..Install(.pCommandInfo)
    }
}

}
