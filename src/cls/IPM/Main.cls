Include (%syGluedef, %sySecurity, %syPrompt, %IPM.Common, %IPM.Formatting)

IncludeGenerator %IPM.Common

Class %IPM.Main Extends %IPM.CLI
{

Parameter DOMAIN = "ZPM";

Parameter STANDARDPHASES = {$ListBuild("reload","compile","test","package","verify","publish","makedeployed")};

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
</description>

<!-- Examples -->
<example description="Compiles the module named &quot;MyModuleName&quot;">module-action MyModuleName compile</example>
<example description="Performs multiple actions on the module named &quot;MyModuleName&quot;; &quot;clean&quot; deletes all of its dependenices, and &quot;install&quot; will then re-download them, package the module, and register it in the current namespace's module cache.">MyModuleName clean register</example>
<example description="Compiles the module named MyUIModule with verbose output and pParams(&quot;UIFW&quot;,&quot;force&quot;) (passed to all lifecycle phases) set to 42.">MyUIModule compile -v -DUIFW.force=42</example>

<!-- Parameters -->
<parameter name="module" required="true" description="Name of module on which to perform lifecycle actions" />
<parameter name="actions" required="true" description="Space-delimited list of module lifecycle phases to run" trailing="true" />

<!-- Modifiers -->
<modifier name="only" aliases="o" description="Only runs the specified phase(s), rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />

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
<modifier name="only" aliases="o" description="Only runs the specified phase (reload), rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
</command>

<command name="compile">
<description>
This command is an alias for `module-action module-name compile`
</description>
<parameter name="module" required="true" description="Name of module on which to perform compile action" />
<modifier name="only" aliases="o" description="Only runs the specified phase (compile), rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
</command>

<command name="test" dataPrefix="D">
<description>
This command is an alias for `module-action module-name test`
</description>
<parameter name="module" required="true" description="Name of module on which to perform test action" />
<modifier name="only" aliases="o" description="Only runs the specified phase (test),rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
</command>

<command name="package" dataPrefix="D">
<description>
This command is an alias for `module-action module-name package`
</description>
<parameter name="module" required="true" description="Name of module on which to perform package actions" />
<modifier name="only" aliases="o" description="Only runs the specified phase (package), rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="path" aliases="p" dataAlias="Path" value="true" description="Use specified path to export package." />
</command>

<command name="verify" dataPrefix="D">
<description>
This command is an alias for `module-action module-name verify`
</description>
<parameter name="module" required="true" description="Name of module on which to perform verify action" />
<modifier name="only" aliases="o" description="Only runs the specified phase (verify), rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
</command>

<command name="publish" dataPrefix="D">
<description>
This command is an alias for `module-action module-name publish`
</description>
<parameter name="module" required="true" description="Name of module on which to perform publish actions" />
<modifier name="only" aliases="o" description="Only runs the specified phase (publish), rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
</command>

<command name="makedeployed">
<description>
This command is an alias for `module-action module-name makedeployed`
</description>
<parameter name="module" required="true" description="Name of module on which to perform reload action" />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="only" aliases="o" description="Only runs the specified phase (makedeployed), rather than also running predecessors." />
<modifier name="recurse" aliases="r" description="Runs the specified phase (makedeployed) on the module and all of its dependencies." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
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


<!-- Modifiers -->
<modifier name="branch" aliases="b" dataAlias="Branch" value="true" description="The name of the branch in the repository" />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="nodev" dataAlias="DeveloperMode" dataValue="0" description="Disables the DeveloperMode flag for the module's lifecycle." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="bypass-py-deps" dataAlias="BypassPyDeps" dataValue="1" description="Skip installing python dependencies" />
<modifier name="extra-pip-flags" dataAlias="ExtraPipFlags" value="true" description="Extra flags to pass to pip when installing python dependencies. Surround the flags (and values) with quotes if spaces are present. Default flags are &quot;--target &lt;target&gt; --python-version &lt;pyversion&gt; --only-binary=:all:&quot;." />

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

<!-- Parameters -->
<parameter name="module" required="true" description="Name of module to install" />
<parameter name="version" description="Version (or version expression) of module to install; defaults to the latest available if unspecified." />

<!-- Modifiers -->
<modifier name="latest" aliases="l" description="Installs the latest available version of this module without prompting the user." />
<modifier name="prompt" aliases="p" description="Prompts user which version to install, if more then one found." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="keywords" aliases="k" value="true" description="Searches for modules matching some set of keywords." />
<modifier name="bypass-py-deps" dataAlias="BypassPyDeps" dataValue="1" description="Skip installing python dependencies" />
<modifier name="extra-pip-flags" dataAlias="ExtraPipFlags" value="true" description="Extra flags to pass to pip when installing python dependencies. Surround the flags (and values) with quotes if spaces are present. Default flags are &quot;--target &lt;target&gt; --python-version &lt;pyversion&gt; --only-binary=:all:&quot;."/>

</command>

<command name="reinstall" dataPrefix="D">
<summary>Reinstalls the already installed version of the provided module.</summary>
<description>
	Reinstalls an already-installed module from the latest version available in a configured
	repository. By default, updates dependencies of that module as well.
</description>

<!-- Examples -->
<example description="Reinstalls the currently-installed version of the ZHSLIB module, in development mode">
	reinstall -dev ZHSLIB
</example>
<example description="Reinstalls the currently-installed vresion of the ZHSLIB module without reinstalling python dependencies">
	reinstall -bypass-py-deps ZHSLIB
</example>
<example description="Reinstalls ZHSLIB but set pip timeout to 30 seconds">
	reinstall -extra-pip-flags "--timeout 30" ZHSLIB
</example>

<!-- Parameters -->
<parameter name="module" required="true" description="Name of module to reinstall" />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />

<!-- Modifiers -->
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
<parameter name="module" required="true" description="Name of module to uninstall" />

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

</commands>
}

ClassMethod %GetCommandStructure(Output pCommandStructure)
{
  Do ..%GetOneCommandStructure(.pCommandStructure)

  Do ##class(%IPM.Repo.Definition).%GetCommandStructure(.tCommandStructure)
  Merge pCommandStructure("repo") = tCommandStructure("repo")
}

/// @API.Method
ClassMethod Shell(pCommand As %String = "", pTerminateOnError As %Boolean = 0, pHaltOnComplete As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Do ..ShellInternal(pCommand,.tException)
	If $IsObject(tException) {
		If pTerminateOnError {
			Do $System.Process.Terminate($Job,1)
		}
		Set tSC = tException.AsStatus()
	}
	If pHaltOnComplete {
		Halt
	}
	Quit tSC
}

ClassMethod TerminalPrompt() As %String
{
	Set tp=##class(%SYSTEM.Process).TerminalPrompt()
	Set prompt="zpm:"
	Set del=$$$FormattedLine(..TerminalPromptColor(),">")
	If ..TerminalPromptColor()=$$$Default { Set tp=2 }
	For i=1:1:$Length(tp,",") {
		If $Piece(tp,",",i)=1 {	Set prompt=prompt_$Piece($System,":")_del Continue}
		ElseIf $Piece(tp,",",i)=2 {	Set prompt=prompt_$Namespace_del Continue}
		ElseIf $Piece(tp,",",i)=3 {	Set prompt=prompt_$Piece($System,":",2)_del Continue}
		ElseIf $Piece(tp,",",i)=4 {	Set prompt=prompt_$ZTime(+$Piece($Horolog,",",2),1)_del Continue}
		ElseIf $Piece(tp,",",i)=5 {	Set prompt=prompt_$Job_del Continue}
    Elseif $Piece(tp,",",i)=8,$Tlevel { Set prompt=prompt_"TL"_$Tlevel_del Continue}
        // for zpm shell 7 do not need to be implemented	
    }
	Quit prompt
}

/// @API.Method
/// Get Version modules and current registry
/// example do ##class(%IPM.Main).GetVersion("zpm,zpm-registry",.out,.list)
ClassMethod GetVersion(ModuleName, ByRef out, list)
{
	Do ..GetListModules("*", ModuleName, .list)
	for i=1:1 { quit:'$d(list(i),ns)
	 	set ns=$lg(ns,1)
	 	for ii=1:1 { quit:'$d(list(i,"modules",ii),module)
	 		set out($lg(module,1))=$lb(ns,$lg(module,2))
	 	}
	}
	set sc=$$$OK
	set sql="select URL from %IPM_Repo_Remote.Definition where Enabled = 1"
		,rs=##class(%ResultSet).%New()
		,sc=rs.Prepare(sql)
	Set:sc sc=rs.Execute("")
	If sc {
		Quit:'rs.%Next()  
		set out=rs.Get("URL")
	}
	Quit sc
}

/// For use in unit tests that need to test if a command threw any exceptions.
ClassMethod ShellInternal(pCommand As %String, Output pException As %Exception.AbstractException) [ Internal ]
{
	New $$$DeprecationWarned
	Set pException = $$$NULLOREF
	Set tOneCommand = 0
	Set tCommand = $Get(pCommand)
	If (tCommand '= "") {
		Set tOneCommand = 1
	}
	do ##class(%IPM.Main).GetVersion("zpm",.out)	
	If $Get(out) = "" {
		Set registryInfo = $$$FormattedLine($$$Cyan, "No registry configured")
	} Else {
		Set registryInfo = "Current registry "_$$$FormattedLine($$$Cyan, out)
	}
	Set introMessageList = $ListBuild(
		"Welcome to the Package Manager Shell (ZPM). Version: "_$$$FormattedLine($$$Green, ..GetVersionModule("zpm")),
		"Enter q/quit to exit the shell. Enter ?/help to view available commands",
		registryInfo
	)
	Set tInShell = 0
	For {
		Kill $$$DeprecationWarned
		Try {
			
			// Have intro message just for first entrance to shell
			// Ensure not displayed if its just one command
			If 'tInShell && 'tOneCommand {
				Do ..DrawBorder(introMessageList, ..TerminalPromptColor())
				Set tInShell = 1
			}
			
			If (tCommand = "") {
				Write ..TerminalPrompt()
				Read tCommand
				Write !
			}
			
			If (tCommand = "") {
				#; Do ..%Help()
				Quit
			}
			
			Kill tCommandInfo
			// Parse command
			$$$ThrowOnError(..%ParseCommandInput(tCommand,.tParsedCommandInfo))
			
			// Merge defaults first so they can be overwritten by commands
			Do ..GetNamespaceDefaultModifiers(.tDefaultArray)
			Merge tCommandInfo("data") = tDefaultArray
			Merge tCommandInfo = tParsedCommandInfo
			
			If (tCommandInfo = "quit") {
				Return
			} ElseIf (tCommandInfo = "help") {
				Do ..%Help(.tCommandInfo)
			} ElseIf (tCommandInfo = "init") {
				Do ..Init(.tCommandInfo)
			} ElseIf (tCommandInfo = "search") {
				Do ..Search(.tCommandInfo)
			} ElseIf (tCommandInfo = "repo") {
				Do ..Repository(.tCommandInfo)
			} ElseIf (tCommandInfo = "load") {
				Do ..Load(.tCommandInfo)
			} ElseIf (tCommandInfo = "exec") {
				Write !
				Xecute tCommandInfo("parameters","expression")
			} ElseIf (tCommandInfo = "install") {
				Do ..Install(.tCommandInfo)
			} ElseIf (tCommandInfo = "reinstall") {
				Do ..Reinstall(.tCommandInfo)
			} ElseIf (tCommandInfo = "uninstall") {
				Do ..Uninstall(.tCommandInfo)
			} ElseIf (tCommandInfo = "list-installed") {
				Do ..ListInstalled(.tCommandInfo)
			} ElseIf (tCommandInfo = "list-dependents") {
				Do ..ListDependents(.tCommandInfo)
			} ElseIf (tCommandInfo = "orphans") {
				Do ..ListOrphans(.tCommandInfo)
			} ElseIf (tCommandInfo = "default-modifiers") {
				Do ..ProcessDefaultModifiers(.tCommandInfo)
			} ElseIf (tCommandInfo = "arrange") {
				Do ..Arrange(.tCommandInfo)
			} ElseIf (tCommandInfo = "import") {
				Do ..Import(.tCommandInfo)
			} ElseIf (tCommandInfo = "run-from-file") {
				Do ..ProcessRunFromFile(.tCommandInfo)
			} ElseIf (tCommandInfo = "dependency-analyzer") {
				Do ..RunDependencyAnalyzer(.tCommandInfo)
			} ElseIf (tCommandInfo = "config") {
				Do ..Config(.tCommandInfo)
			} ElseIf (tCommandInfo = "unpublish") {
				Do ..Unpublish(.tCommandInfo)
			} ElseIf ($Listfind(..#STANDARDPHASES,tCommandInfo)) {
				Do ..RunOnePhase(.tCommandInfo)
			} ElseIf (tCommandInfo = "generate") {
				Do ..GenerateModuleXML(.tCommandInfo)
			} ElseIf (tCommandInfo = "module-action") {
				Do ..ModuleAction(.tCommandInfo)
			} ElseIf (tCommandInfo = "version") {
				Do ..Version(.tCommandInfo)
			} ElseIf (tCommandInfo = "namespace") {
				Do ..Namespace(.tCommandInfo)			
			} ElseIf (tCommandInfo = "enable") {
				Do ..EnableIPM(.tCommandInfo)
			} ElseIf (tCommandInfo = "unmap") {
				Do ..UnmapIPM(.tCommandInfo)
			}
		} Catch pException {
			If (pException.Code = $$$ERCTRLC) {
				Set pException = $$$NULLOREF
				Return
			}
			Do ..DisplayError(pException.AsStatus())
		}
		Set tCommand = ""
		If tOneCommand {
			Quit	
		}
		Write !
	}
}

ClassMethod DisplayError(pStatus As %Status)
{
  If $$$ISERR(pStatus) {
    Write !,$$$FormattedLine($$$Red, "ERROR!")
    Write " ",$System.Status.GetOneStatusText(pStatus)
  }
}

/// Show modules in Namespace and to go namespace
ClassMethod Namespace(ByRef pCommandInfo) [ Internal ]
{
  Set name = $Translate($Get(pCommandInfo("parameters","name"),"*"),$Char(34))
	If name'["*" {
    Try {
      Set $Namespace = name
    } Catch ex {
      $$$ThrowStatus($$$ERROR($$$GeneralError,"Failed to switch to namespace: " _ name))
    }
    Quit
  }

	Set currentns = $Namespace
  Set showFields = ""
  If $Get(pCommandInfo("data","Description")) {
    Set showFields = $ListBuild("Description")
  }

  Do ..GetListModules(name, , .list, showFields)
  Do ..DisplayModules(.list, 1, 1)

  Write !
  Set prompt = "Enter number or name where to go:"
  Do {
    Set value = ""
    Do ##class(%Library.Prompt).GetString(prompt, .value)
    Quit:value=""
    Try { 
      Set $Namespace = $Select($Data(list(value), ns): $ListGet(ns), 1: value)
    } Catch e {
      Write $Char(13),*27,"[K",*27,"[A"
      Continue
    }
    Quit
  } While 1
  Write $Char(13),*27,"[K",prompt, " ", $Namespace,!
}

/// Get list Namespace, example do ##class(%IPM.Main).GetListNamespace(.ns)
ClassMethod GetListNamespace(Output list, pSearch As %String = "")
{
  Kill list
  Set list = 0

  // Build regex for matching outside of SQL. 
  // Directly using `where Nsp LIKE ?` causes a bug described in https://github.com/intersystems/ipm/issues/579 
  Set pSearch = $Zstrip(pSearch, "<>WC")
  If pSearch = "" {
    Set pSearch = "*"
  }
  Set regex = ##class(%IPM.DataType.RegExString).FromWildCard(pSearch)

  Set width = 0
  Set tQuery = "SELECT Nsp FROM %SYS.Namespace_List()"
  Set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery) 
  $$$ThrowSQLIfError(tRes.%SQLCODE, tRes.%Message)
  While tRes.%Next(.tSC) {
    $$$ThrowOnError(tSC)
    Set nsp = tRes.Nsp
    If $Match(nsp, regex) {
      Set list(nsp) = ""
    }
  }
}

/// draw description
ClassMethod DrawColumn(desc) As %String
{
	Set dx=$X
	For d=1:1:$Length(desc," ") {
 		Set wd=$Piece(desc," ",d) 
		If $X+$Length(wd)>80 Write !,?dx
		Write wd," " 
	}
 	Quit ""
}

ClassMethod SwitchToNamespace(pNamespace As %String = {$Namespace}) As %Status
{
	Set tSC = $$$OK
	Try {
    If pNamespace'=$Namespace {
		  Set $Namespace = pNamespace
    }
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Get List Modules
/// example d ##class(%IPM.Main).GetListModules("%SYS","zpm",.list)
ClassMethod GetListModules(pNamespace As %String = {$Namespace}, pSearch As %String = "", ByRef list, pExtraFields As %String = "", pRepository As %String = "") [ Internal ]
{
  Set list = 0
  If (pNamespace="") || (pNamespace["*") {
    Do ..GetListNamespace(.listNS, pNamespace)
    Set list("ns") = pNamespace
    Set width = 0
    Set ns = ""
    For { 
      Set ns = $Order(listNS(ns)) 
      Quit:ns=""
      Kill listModules
      Do ..GetListModules(ns, pSearch, .listModules, pExtraFields, pRepository)
      Continue:(pSearch'="")&&('$Get(listModules))
      If width < $Length(ns) {
        Set width = $Length(ns)
      }
      Set list = list + 1 
      Set list(list) = $ListBuild(ns)

      Merge list(list, "modules") = listModules
    }
    Merge list("width") = width

    Quit
  }
  If pNamespace'=$Namespace {
    New $Namespace
    If $$$ISERR(..SwitchToNamespace(pNamespace)) {
      Quit
    }
  }
  If '$$$comClassDefined("%IPM.Storage.Module") {
    // Don't error in namespaces without IPM enabled
    Quit
  }
  Set tArgs = 0
	Set tQuery = "SELECT Name,VersionString,Description,ExternalName,DeveloperMode,Root FROM %IPM_Storage.ModuleItem WHERE 1=1 "
  Set pSearch = $ZStrip(pSearch, "<>WC")
  If pSearch'="" {
    If pSearch["," {
      Set tList = $ListFromString(pSearch, ",")
      Set tParams = ""
      Set ptr = 0
      While $ListNext(tList, ptr, tItem) {
        Set tItem = $ZStrip(tItem, "<>WC")
        Continue:tItem=""
        Set tParams = tParams _ $ListBuild("?")
        Set tArgs($Increment(tArgs)) = tItem
      }
      Set tQuery = tQuery _ " AND name IN (" _ $ListToString(tParams, ", ") _ ")"
    } ElseIf pSearch'="*" {
      Set tQuery = tQuery _ " AND name " _ $Select(pSearch["*": "like ?", 1: "= ?")
      Set tArgs($Increment(tArgs)) = $Translate(pSearch, "*", "%")
    }
  }
  If pRepository'="" {
    Set tQuery = tQuery _ " AND Repository = ?"
    Set tArgs($Increment(tArgs)) = pRepository
  }
  Set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery, tArgs...)
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
  Set maxWidth = 0
  Set list = 0
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
    Set name = tRes.Name
    Set list = list + 1
		Set list(list) = $ListBuild(name, tRes.VersionString, tRes.ExternalName, tRes.DeveloperMode, tRes.Root)
		If maxWidth<$Length(name) {
      Set maxWidth = $Length(name)
    }
    Continue:pExtraFields=""
    Set obj = ##class(%IPM.Storage.Module).NameOpen(name, .tSC)
    Continue:$$$ISERR(tSC)
    Set ptr = 0 
    While $ListNext(pExtraFields, ptr, field) {
      Continue:field=""
      Set tObj = obj
      Set tValue = ""
      For j=1:1:$Length(field, ".") {
        Set tField = $Piece(field, ".", j)
        Set tValue = $Property(tObj, tField)
        Quit:'$IsObject(tValue)
        Set tObj = tValue
      }
      Continue:tValue=""
      Set list(list, field) = tValue
    }
	}
  Set list("width") = maxWidth
}

/// generates module.xml
ClassMethod GenerateModuleXML(ByRef pCommandInfo) As %Status [ Internal ]
{
	Set tPath = $Get(pCommandInfo("parameters","path"))
	If (tPath="") {
		Set tHelp(1) = "Enter path to the module folder (where module.xml will be generated)"
		Set tHelp(2) = "Enter "" null string to quit"
		Do ##class(%Library.Prompt).GetString("Enter module folder:", .tPath, , ,.tHelp)
		Return:(tPath="") $$$OK
	}
	Set tPath = ##class(%File).NormalizeDirectory(tPath)

	If ($$$HasModifier(pCommandInfo,"template")) {
		Return ##class(%IPM.Storage.ModuleTemplate).GenerateTemplate(tPath)
	} 
	While (1) {
		Set tHelp(1) = "Enter module name"
		Set tHelp(2) = "Enter "" null string to quit"
		Do ##class(%Library.Prompt).GetString("Enter module name:", .tName, , ,.tHelp)
		Return:(tName="") $$$OK
		If ('##class(%IPM.Storage.ModuleTemplate).NameIsValid(tName)) {
			Write !,"Module name """_tName_""" is invalid" 
			Set tName=""
			Continue 
		}
		Quit 
	}

	While (1) {
		Set tVersion = "1.0.0"
		Do ##class(%Library.Prompt).GetString("Enter module version:", .tVersion)
		Return:(tVersion="") $$$OK
		If ('##class(%IPM.General.SemanticVersion).IsValid(tVersion)) {
			Write !,"Module version """_tVersion_""" is invalid" 
			Set tVersion=""
			Continue 
		}
		Quit
	}

	Do ##class(%Library.Prompt).GetString("Enter module description:", .tDescription)

	Do ##class(%Library.Prompt).GetString("Enter module keywords:", .tKeywords)	

	Set tTemplate = ##class(%IPM.Storage.ModuleTemplate).NewTemplate(tPath, tName, tVersion, tDescription, tKeywords)
	Return:'$IsObject(tTemplate) 

	If ($$$HasModifier(pCommandInfo,"author")) {
		Write !,"Author:"
		Do ##class(%Library.Prompt).GetString("    Enter Author name:", .tAuthorPerson)	
		Do ##class(%Library.Prompt).GetString("    Enter Organization name:", .tAuthorOrg)
		Do ##class(%Library.Prompt).GetString("    Enter License:", .tAuthorLicense)
		Do ##class(%Library.Prompt).GetString("    Enter Copyright Date:", .tAuthorCopy)
		Do ##class(%Library.Prompt).GetString("    Enter Notes:", .tAuthorNotes)
		Do tTemplate.SetAuthorProps(tAuthorPerson, tAuthorOrg, tAuthorLicense, tAuthorCopy, tAuthorNotes)
		Write !
	}
	
	Set tSrc = "src"
	Do ##class(%Library.Prompt).GetString("Enter module source folder:", .tSrc)	
	Set tExp = $$$GetModifier(pCommandInfo,"export")
	If tExp'="" {
		set tPathSrc=##class(%File).NormalizeDirectory(tPath_"\"_tSrc)
		Do ##class(%IPM.Storage.ModuleTemplate).ExportResources(tPathSrc,tExp)
	}
	Do tTemplate.ReadResources(tSrc)

	// web applications
	Do ##class(%IPM.Storage.ModuleTemplate).GetCSPApplications(.apps)
	If ($ListLength(apps)>0 ) {
		Write !!,"Existing Web Applications:"
		For i=1:1:$ListLength(apps) {
			Write !,"    "_$ListGet(apps,i)
		}
		Do ##class(%Library.Prompt).GetString("    Enter a comma separated list of web applications or * for all:", .tWebAppList)

		Do tTemplate.AddWebApps(tWebAppList,.tCSPapps) // tCSP - list of CSP (not REST apps) 
		For i=1:1:$ListLength(tCSPapps) {
			Set tCSPPath = ""
			Do ##class(%Library.Prompt).GetString("    Enter path to csp files for "_$ListGet(tCSPapps,i)_": ", .tCSPPath)
			If (tCSPPath'="") {
				Do tTemplate.SetSourcePathForCSPApp($ListGet(tCSPapps,i),tCSPPath)
			}
		}
	}

	// dependencies
	Write !,"Dependencies:"
	While 1 {
		Set tDependant = ""
		Set tResponse = ##class(%Library.Prompt).GetString("    Enter module:version or empty string to continue:", .tDependant)
		Set tDependant = $ZStrip(tDependant,"<>W")
		Quit:(tDependant="")
		Do tTemplate.AddDependant(tDependant)
	}

	Do tTemplate.ProcessResources()
	Return tTemplate.SaveFile(tPath)
}

/// Get Default Command of Registry
/// example d ##class(%IPM.Main).GetDefaultCommandRegistry()
ClassMethod GetDefaultCommandRegistry()
{
	New $Namespace
	Set $Namespace="%SYS"
	Set Status=##Class(Config.Startup).Get(.Properties)
	If Status {
		Set ServerPort="http://"_$ZUtil(110)_":"_$Get(Properties("WebServerPort"),52773)
		Write !,"Default commands for the registry"
		Write !,"View all packets in the browser:",!,"  ",ServerPort_"/registry/packages/-/all"
		Write !,"Switch to the current registry:",!,"   repo -r -n registry -url "_ServerPort_"/registry/ -user ""_system"" -pass ""SYS""",!
		
	}
}

/// Get Version Module
ClassMethod GetVersionModule(name, namespace = {$namespace})
{
	New $Namespace
	Set $Namespace=namespace
	Try {
		Do ..GetListModules(,name,.list)
		Return $ListGet(list(1), 2)
	} Catch ex {
		Return ""
	}
}

/// @API.Method
/// Version client and registry
ClassMethod Version(ByRef pCommandInfo) [ Internal ]
{
	Do ..GetListModules("*", $$$IPMModuleName_","_$$$IPMServerRegistryModuleName, .list)
	Do ..AddIPMMappedNamespaces(.list)
	Do ..DisplayModules(.list)

	// Get URL current registry
	Set tRes = ##class(%IPM.Repo.Remote.Definition).ExtentFunc()
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)

		#dim tRepository As %IPM.Repo.Remote.Definition
		Set tRepository = ##class(%IPM.Repo.Remote.Definition).%OpenId(tRes.ID,,.tSC)
		$$$ThrowOnError(tSC)
		Set tService = tRepository.GetPackageService()
		Set tInfo = tService.GetInfo()
		Write !,$$$FormattedLine($$$Blue,tRepository.URL)," - ",tInfo.ToString()
	}
	Quit $$$OK
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
	Do ..GetListNamespace(.allNS,"*")
	For i=1:1:+$Get(list) {
		Set namespace = $ListGet(list(i))
		If (namespace '= "") {
			Kill allNS(namespace)
		}
		Set sourceDB = ##class(%SYS.Namespace).GetPackageDest(namespace,"%IPM")
		Set mappedFrom(sourceDB) = namespace
		Merge mappedFrom(sourceDB,"info") = list(i)
	}

	Set namespace = ""
	For {
		Set namespace = $Order(allNS(namespace))
		If namespace = "" {
			Quit
		}

		Set sourceDB = ##class(%SYS.Namespace).GetPackageDest(namespace,"%IPM")
		If $Data(mappedFrom(sourceDB),sourceNamespace) {
			Kill info
			Merge info = mappedFrom(sourceDB,"info")
			Set info = $lb(namespace)
			Set info("modules",1,"Installed In") = sourceNamespace
			Merge list($i(list)) = info
			If $Length(namespace) > +$Get(list("width")) {
				Set list("width") = $Length(namespace)
			}
		}
	}
}

/// @API.Method
ClassMethod IsAvailable(pModuleName As %String, pNamespace As %String = "", pArgs...) As %Boolean
{
	New $NAMESPACE
	If pNamespace'="" {
		Set $namespace = pNamespace
	}
	If '##class(%IPM.Storage.Module).NameExists(pModuleName,.id) {
		Return 0
	}
	Set availabilityClass = ##class(%IPM.Storage.Module).AvailabilityClassGetStored(id)
	If availabilityClass = "" {
		Return 1
	}
	Quit $ClassMethod(availabilityClass,"IsAvailable",pNamespace,pArgs...)
}

ClassMethod GetNamespaceDefaultModifiers(Output pDefaultArray) [ Internal ]
{
	Kill pDefaultArray
	Merge pDefaultArray = $$$ZPMDefaultModifiers
}

ClassMethod SetNamespaceDefaultModifiers(ByRef pDefaultArray) [ Internal ]
{
	Merge $$$ZPMDefaultModifiers = pDefaultArray
}

ClassMethod DeleteNamespaceDefaultModifiers() [ Internal ]
{
	Kill $$$ZPMDefaultModifiers
}

ClassMethod AccumulateDefaultModifierList(ByRef pDefaultArray, pNameParts As %Library.List = "") As %Library.List [ Internal ]
{
	Set returnList = ""
	Set key = ""
	While 1 {
		Set key = $Order(pDefaultArray(key))
		If (key = "") {
			Quit
		}
		Set nameParts = pNameParts _ $ListBuild(key)
		If $Data(pDefaultArray(key),value)#2 {
			// Only add to return list if top level node contains value
			Set returnList = returnList _ $ListBuild("-D"_$ListToString(nameParts,".")_"="_value)
		}
		If ($Data(pDefaultArray(key)) >= 10) {
			// Contains subscripts so call recursively
			Kill childArray
			Merge childArray = pDefaultArray(key)
			Set childList = ..AccumulateDefaultModifierList(.childArray, nameParts)
			Set returnList = returnList _ childList
		}
	}
	Return returnList
}

ClassMethod ProcessDefaultModifiers(ByRef pCommandInfo) [ Internal ]
{
	Set shouldSet = $$$HasModifier(pCommandInfo,"set")
	Set shouldGet = $$$HasModifier(pCommandInfo,"get")
	Set shouldDelete = $$$HasModifier(pCommandInfo,"delete")
	If ((shouldSet + shouldGet + shouldDelete) '= 1) {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"MUST use EXACTLY one of the available modifiers. View available modifiers by running the following command: help default-modifiers"))
	}
	If shouldGet {
		Do ..GetNamespaceDefaultModifiers(.defaultArray)
		Set modList = ..AccumulateDefaultModifierList(.defaultArray)
		If ($ListLength(modList) = 0) {
			Write !, "No default modifiers currently set for this namespace", !
			Return
		}
		Write !!, $$$FormattedLine($$$Underlined,"Available default modifiers:"), !
		Set ptr = 0
		While $ListNext(modList, ptr, modName) {
			Write !, modName
		}
		Write !
	} ElseIf shouldSet {
		Merge dataArray = pCommandInfo("data")
		Do ..SetNamespaceDefaultModifiers(.dataArray)
		Write !, "Successfully updated default modifiers!", !
	} ElseIf shouldDelete {
		Do ..DeleteNamespaceDefaultModifiers()
		Write !, "Successfully deleted default modifiers!", !
	}
}

ClassMethod Init(ByRef pCommandInfo) [ Internal ]
{
	// In quiet mode, no prompts should be shown.
	Set tQuiet = $$$HasModifier(pCommandInfo,"noprompt")
	
	// Reindex tables with semantic version indices
	For tClass = "%IPM.Repo.Filesystem.Cache" {
		Write !,"Reindexing ",tClass,"... "
		$$$ThrowOnError($ClassMethod(tClass,"%BuildIndices",,1,1))
		Write "done."
	}
	
	// Package Manager Settings
	If tQuiet {
		Set tResult = 0
	} Else {
		Write !
		Set tResult = 0
		Set tHelp = "Enter ""Yes"" to configure settings for third-party tools that the package manager needs. These are all optional, "_
			"with the possible exception of JAVA_HOME, which must be configured to enable packaging of modules or extraction of packages."
		Set tResponse = ##class(%Library.Prompt).GetYesNo("Do you want to configure general package manager settings?",.tResult,.tHelp)
		If (tResponse '= $$$SuccessResponse) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
		}
	}
	If (tResult) {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,"call %IPM_General.IConfigurable_ListSettings()")
		If (tRes.%SQLCODE < 0) {
			$$$ThrowStatus($$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message))
		}
		Set tLastSource = ""
		While tRes.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			
			Set tSource = tRes.%Get("Source")
			If (tSource '= tLastSource) {
				Set tLastSource = tSource
				Set tSourceDesc = tRes.%Get("SourceDescription")
				Write !!,tSourceDesc
			}
			Set tSetting = tRes.%Get("Name")
			Set tSettingDesc = tRes.%Get("Description")
			Set tSettingValue = tRes.%Get("Value")
			
			Write !,tSetting,": ",tSettingDesc
			Set tResponse = ##class(%Library.Prompt).GetString("Value:",.tSettingValue,,,tSettingDesc)
			If (tResponse '= $$$SuccessResponse) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
			}
			
			If (tSettingValue '= tRes.%Get("Value")) {
				$$$ThrowOnError($ClassMethod(tSource,"SetSettingValue",tSetting,tSettingValue))
				Write !,tSetting," updated."
			}
		}
		$$$ThrowOnError(tSC)
	}
	
	
	If tQuiet {
		Set tConfigureZPM = $$$HasModifier(pCommandInfo,"zpm")
	} Else {
		// Update of language extension - see if one is already configured.
		$$$ThrowOnError(..UpdateLanguageExtensions(0,1,.tHasZPM))
		Set tConfigureZPM = 'tHasZPM // Default to "yes" if command is missing.
		
		Write !
		Set tHelp = "The 'ZPM' command allows quick command line access to many features of the package manager. Extensive documentation is available via:"_$Char(13,10,9)_" zpm ""help""."
		Set tResponse = ##class(%Library.Prompt).GetYesNo("Do you want to enable/update the 'ZPM' command?",.tConfigureZPM,.tHelp)
		If (tResponse '= $$$SuccessResponse) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
		}
	}
	If tConfigureZPM {
		$$$ThrowOnError(..UpdateLanguageExtensions())
	}
	
	// Source Control settings
	Write !
	Set tSCClassChanged = 0
	
	Set tPrimaryClass = ""
	Set tCompositeSCClass = "%IPM.ExtensionBase.Composite"
	Set tServerMenuExtClass = ""

	// set server menu extension class (tServerMenuExtClass)
	If tQuiet {
		If $$$HasModifier(pCommandInfo,"menuextension") {
			Set tServerMenuExtClass = $$$GetModifier(pCommandInfo,"menuextension")
		}
	} Else {
		Set tValue = ""
		Set tStatement = ##class(%SQL.Statement).%New()
		$$$ThrowOnError(tStatement.%PrepareClassQuery($classname(), "ServerMenuExtensionClasses"))
		Set tResultSet=tStatement.%Execute()
		$$$ThrowSQLIfError(tResultSet.%SQLCODE, tResultSet.%Message)
		While tResultSet.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			// if there's only one satisfied subclass, directly set it
			// if not, tServerMenuExtClass will be overwritten by user input to the prompt below
			Set tServerMenuExtClass = tResultSet.%Get("Name")
		}
		$$$ThrowOnError(tSC)
		If (tResultSet.%ROWCOUNT > 1) {
			// if has more than one satisfied subclass, let user choose which server menu extension class to set
			Set tHelp = "Note: only subclasses of %IPM.ExtensionBase.ServerMenu.Interface are listed."
			Set tResponse = ##class(%Library.Prompt).GetArray("Which class to set as the server menu extension class?",.tValue, $ListBuild($ClassName()_":ServerMenuExtensionClasses"),,,.tHelp,$$$InitialDisplayMask)
			If (tResponse '= $$$SuccessResponse) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
			}
			If (tValue '= "") {
				Set tServerMenuExtClass = tValue
			}
		}
		If (tServerMenuExtClass '= "") {
			Write !, "Setting "_tServerMenuExtClass_" as the server menu extension class."
		}
	}

	Set tSCInterface = "%IPM.ExtensionBase.SourceControl.Interface"
	Set tOldSourceControlClass = ##class(%Studio.SourceControl.Interface).SourceControlClassGet()
	
	If (tOldSourceControlClass '= "") && '$$$comClassDefined(tOldSourceControlClass) {
		Write !,"Source control class ",tOldSourceControlClass," does not exist - disabling it."
		$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet())
		Set tOldSourceControlClass = ""
	}
	
	If (tOldSourceControlClass '= "") && (tOldSourceControlClass '= tCompositeSCClass) && (tOldSourceControlClass '= tServerMenuExtClass) {
		Write !,"Enabling package manager extension if present... "
		$$$ThrowOnError(##class(%IPM.ExtensionBase.Composite).SetExtensionClasses(tOldSourceControlClass,$ListBuild(tServerMenuExtClass)))
		Write "done."
		Set tOldSourceControlClass = tCompositeSCClass
	}
	
	If (tOldSourceControlClass = "") {
		Write !,"No Studio extension is currently configured for this namespace."
	} ElseIf (tOldSourceControlClass = tCompositeSCClass) {
		Set tPrimaryClass = ##class(%IPM.ExtensionBase.Composite).GetPrimaryExtensionClass()
		Set tExtensionClasses = ##class(%IPM.ExtensionBase.Composite).GetSubExtensionClasses()
		Write !,"Currently configured to use the following extension classes: "
		Set tPtr = 0
		While $ListNext(tExtensionClasses,tPtr,tClass) {
			Write !,$Char(9),tClass,$Case(tClass,tPrimaryClass:" (primary)",:"")
		}
	} Else {
		Write !,"Currently configured with the package manager extension, but no source control class."
	}
	
	If tQuiet {
		Set tResult = $$$HasModifier(pCommandInfo,"extension")
	} Else {
		Write !
		Set tHelp = "The source control class is a namespace-specific setting, controlling export of files to the filesystem / source control on the server."
		Set tResult = (tPrimaryClass = "") || '$$$comClassDefined(tPrimaryClass) || '$ClassMethod(tPrimaryClass,"%Extends",tSCInterface)
		Set tResponse = ##class(%Library.Prompt).GetYesNo("Do you want to change the source control class for this namespace?",.tResult,.tHelp)
		If (tResponse '= $$$SuccessResponse) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
		}
	}
	
	If (tResult) {
		// Provide list of options for source control classes to overlay.
		If tQuiet {
			Set tValue = $$$GetModifier(pCommandInfo,"extension")
		} Else {
			Set tValue = ""
			Set tHelp = "Note: only subclasses of %IPM.ExtensionBase.SourceControl.Interface are listed."
			Set tResponse = ##class(%Library.Prompt).GetArray("Which class?",.tValue,$ListBuild($ClassName()_":SourceControlClasses"),,,.tHelp,$$$InitialDisplayMask)
			If (tResponse '= $$$SuccessResponse) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
			}
		}
		
		If (tValue = "") {
			$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(tServerMenuExtClass))
			Write !,!,"Removed source control class. Package manager extension still enabled if present."
		} Else {
			Write !,!,"Setting ",tValue," as the source control class for this namespace..."
			// Just configure the package manager source control class. (Gaining the "Package Manager" menu.)
			$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(tCompositeSCClass))
			Set tSecondaryExtension = $ListBuild(tServerMenuExtClass)
			$$$ThrowOnError(##class(%IPM.ExtensionBase.Composite).SetExtensionClasses(tValue,tSecondaryExtension))
			Write " done."
			
			// To see if it changed, compare to primary class (if found earlier) or old source control class (if we weren't combining extensions before)
			If (tValue '= tPrimaryClass) {
				Set tSCClassChanged = 1
			}
		}
	} ElseIf (tOldSourceControlClass = "") {
		// Just configure the package manager source control class. (Gaining the "Package Manager" menu.)
		$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(tServerMenuExtClass))
		Write !,!,"Enabled package manager extension if present."
	}
	
	// If we're not just using the package manager, check for configuration method on primary source control class
	// (by seeing if it implements the additional package manager source control interface)
	If (##class(%Studio.SourceControl.Interface).SourceControlClassGet() = tCompositeSCClass) {
		// Default to having the user configure the extension after changing it.
		Set tResult = tSCClassChanged
		Set tPrimaryClass = ##class(%IPM.ExtensionBase.Composite).GetPrimaryExtensionClass()
		If $ClassMethod(tPrimaryClass,"%Extends",tSCInterface) && 'tQuiet {
			Set tHelp = "Enter 'Yes' to configure settings for the selected source control class. Some of these may be namespace-specific, and some may be instance-wide."
			Set tResponse = ##class(%Library.Prompt).GetYesNo("Do you want to configure source control options?",.tResult,.tHelp)
			If (tResponse '= $$$SuccessResponse) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
			}
			If (tResult) {
				$$$ThrowOnError($ClassMethod(tPrimaryClass,"Configure"))
				Write !,"Configuration complete."
			}
		}
	}
}

ClassMethod ProcessRunFromFile(ByRef pCommandInfo) [ Internal ]
{
	Set filename = $Get(pCommandInfo("parameters","file"))
	Set dryRun = $$$HasModifier(pCommandInfo,"dry-run")
	
	If '##class(%Library.File).Exists(filename) {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Provided file does not exist"))
	}
	Set fileStream = ##class(%Stream.FileCharacter).%New()
	$$$ThrowOnError(fileStream.LinkToFile(filename))
	
	// Accumulate list of commands to execute
	Set commandList = ""
	
	Set extension = $Piece(filename, ".", *)
	If (extension = "txt") {
		// Read line by line, adding each line to command list
		While 'fileStream.AtEnd {
			Set line = fileStream.ReadLine(, .sc)
			$$$ThrowOnError(sc)
			// Strip leading and trailing white space + control characters
			Set line = $ZStrip(line,"<>CW")
			If (line '= "") {
				Set commandList = commandList _ $ListBuild(line)
			}
		}
	} ElseIf (extension = "json") {
		// Will be an array so read file into it
		#dim jsonInput As %Library.DynamicObject
		#dim commandsArray As %Library.DynamicArray
		Set jsonInput = ##class(%Library.DynamicAbstractObject).%FromJSON(fileStream)
		If 'jsonInput.%IsA("%Library.DynamicObject") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Unexpected format of file. Expected JSON object at root level but not found."))
		}
		Set commandsArray = jsonInput.%Get("commands")
		If '$IsObject(commandsArray) || 'commandsArray.%IsA("%Library.DynamicArray") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"'commands' property MUST be a JSON array"))
		}
		#dim arrayIter As %Iterator.Array
		Set arrayIter = commandsArray.%GetIterator()
		While arrayIter.%GetNext(, .commandJson) {
			Set command = ..ParseJsonToCommand(commandJson)
			Set commandList = commandList _ $ListBuild(command)
		}
	} Else {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Unsupported file extension: "_extension))
	}
	
	Set message = $Case(dryRun,
		1: "The following commands will be run in the shell if the -dry-run flag is not used:",
		: "Running commands found in file:"
	)
	Write !, message, !	
	Set ptr = 0
	While $ListNext(commandList,ptr,command) {
    Write !,..TerminalPrompt()
		Write command
		If 'dryRun {
			$$$ThrowOnError(..Shell(command))
		}
		Write !
	}
	Write !
}

ClassMethod Search(ByRef pCommandInfo) [ Internal ]
{
	Set tRepo = $Get(pCommandInfo("data","Repo"),0)
	Set tDesc = $Get(pCommandInfo("data","Description"),0)
	Set tAllVersions = $Get(pCommandInfo("data","AllVersions"),0)
	Set tSearchString = $Get(pCommandInfo("parameters","searchString"),"")
	Set tName = $$$GetModifier(pCommandInfo,"name")
	If (tName '= "") {
		Do ..ShowModulesForRepository(tName, tRepo, tDesc, tSearchString, tAllVersions)
	} Else {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select Name, Details from %IPM_Repo.Definition")
		If (tRes.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
		}
		While tRes.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			If ($Increment(tCount) > 1) {
				Write !!
			}
			Write tRes.%Get("Name")," ", tRes.%Get("Details"),":"
			Do ..ShowModulesForRepository(tRes.%Get("Name"), tRepo, tDesc, tSearchString, tAllVersions)
		}
		$$$ThrowOnError(tSC)
	}
}

ClassMethod Config(ByRef pCommandInfo) [ Internal ]
{
	Set action = $Get(pCommandInfo("parameters","action"))
	Set key = $Get(pCommandInfo("parameters","key"))
	Set value = $Get(pCommandInfo("parameters","value"))

	If (action="") { 
		Set action = "list"	
	}
	If (action="list") {
		Do ##class(%IPM.Repo.UniversalSettings).PrintList()
	} ElseIf (action="set") {
		If ( (key = "") || (value="") ) {
			Write "Key and Value required. Use config set <key> <value>",!
			Quit
		} 
		Do ##class(%IPM.Repo.UniversalSettings).UpdateOne(key,value)
	} ElseIf (action="get") {
		If (key = "") {
			Do ##class(%IPM.Repo.UniversalSettings).PrintList()
		} Else {
			Do ##class(%IPM.Repo.UniversalSettings).PrintOne(key)
		}
	} ElseIf (action="delete") {
		If (key = "") {
			Write "Key required. Use config delete <key>",!
			Quit
		}
		Do ##class(%IPM.Repo.UniversalSettings).ResetToDefault(key)
	}
}

ClassMethod Repository(ByRef pCommandInfo) [ Internal ]
{
  Do ##class(%IPM.Repo.Definition).CollectServerTypes(.types)

  Set tType = $$$GetModifier(pCommandInfo, "type")

  Set serverClassList = ""
  Set t = ""
  For {
    Set t = $Order(types(t), 1, className)
    Quit:(t = "")
    If ('($$$HasModifier(pCommandInfo, t)) && (t '= tType)) {
      Kill types(t)
    } 
    ElseIf '$ListFind(serverClassList, className) {
      Set serverClassList = serverClassList _ $ListBuild(className)
    }
  }

	If $$$HasModifier(pCommandInfo,"list") && '$$$HasModifier(pCommandInfo,"list-modules") {
		Set tUseFilter = $Data(types)\10
    Set tRes = ##class(%IPM.Repo.Definition).ListFunc()
    $$$ThrowSQLIfError(tRes.%SQLCODE,tRes.%Message)
		Set tDisplayCount = 0
		Write !
    While tRes.%Next(.tSC) {
			$$$ThrowOnError(tSC)

			Set tRepository = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tRes.%Get("Name"),,.tSC)
			$$$ThrowOnError(tSC)
			If serverClassList = "" || ($ListFind(serverClassList, $ClassName(tRepository))) {
				Do tRepository.Display()
				Write !
				Set tDisplayCount = tDisplayCount + 1 
			}
    }
		$$$ThrowOnError(tSC)
		If (tDisplayCount = 0) {
			Write "No repositories found.", !
		}
    Quit
	} ElseIf $$$HasModifier(pCommandInfo,"copy-from") {
		Set tSourceNamespace = $$$GetModifier(pCommandInfo,"copy-from")
		Set tOldNamespace = $Namespace
		New $Namespace
		Try {
			Set $Namespace = tSourceNamespace
		} Catch e {
			If (e.Name = "<NAMESPACE>") {
				Write !,"Invalid namespace: ",tSourceNamespace
				Return
			}
			Throw e
		}
		
		Set tName = $$$GetModifier(pCommandInfo,"name")
		If (tName '= "") {
			Set tRepository = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tName,,.tSC)
			If $$$ISERR(tSC) && $System.Status.Equals(tSC,$$$ERRORCODE($$$KeyValueNotFoundOpen)) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("No repository with name '%1' exists in namespace '%2'",tName,tSourceNamespace))
			}
			$$$ThrowOnError(tSC)
			Set tRepositories($Increment(tRepositories)) = tRepository
		} Else {
			// Find all the repositories in the source namespace
			Set tRes = ##class(%SQL.Statement).%ExecDirect(,
				"select Name "_
				"from %IPM_Repo.Definition "_
				"order by %IPM_Repo.Definition_SortOrder(ID) desc")
			If (tRes.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
			}
			While tRes.%Next(.tSC) {
				$$$ThrowOnError(tSC)
				Set tRepository = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tRes.%Get("Name"),,.tSC)
				$$$ThrowOnError(tSC)
				Set tRepositories($Increment(tRepositories)) = tRepository
			}
			$$$ThrowOnError(tSC)
		}
		
		Set $Namespace = tOldNamespace
		For tIndex=1:1:$Get(tRepositories) {
			// Deep clone in case there are ever other referenced objects that need to be carried across.
			// This is not relevant for any current repository types, but is most likely to be correct in
			// hypothetical cases where it may matter. (A Git or GitHub-based repository, for example, would
			// probably need to store more information that would be carried across this way.)
			Set tNewRepository = tRepositories(tIndex).%ConstructClone(1)
			If ##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(tNewRepository.Name) {
				Write !,"Repository already defined: ",tNewRepository.Name,"; skipping."
				Continue
			}
			Set tOneSC = tNewRepository.%Save()
			If $$$ISOK(tOneSC) {
				Write !,"Copied:"
				Do tNewRepository.Display()
			}
			Set tSC = $System.Status.AppendStatus(tSC,tOneSC)
		}
		$$$ThrowOnError(tSC)
	} ElseIf $$$HasModifier(pCommandInfo,"list-modules") {
    Do ..Search(.pCommandInfo)
		Quit
	} ElseIf $$$HasModifier(pCommandInfo,"delete-all") {
    If (serverClassList = "") {
			$$$ThrowOnError(##class(%IPM.Repo.Definition).%DeleteExtent())
    }
    Else {
      Set ptr = 0
      While $ListNext(serverClassList, ptr, className) {
        $$$ThrowOnError($ClassMethod(className, "%DeleteExtent"))
      }
    }
	} ElseIf $$$HasModifier(pCommandInfo,"delete") {
		Set repoName = $$$GetModifier(pCommandInfo,"name")
		If (repoName = "") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Missing -name modifier"))
		}
		If '##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(repoName) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Repository "_$$$QUOTE(repoName)_" does not exist so cannot be deleted."))
		}
		$$$ThrowOnError(##class(%IPM.Repo.Definition).ServerDefinitionKeyDelete(repoName))
  } ElseIf $$$HasModifier(pCommandInfo,"reset-defaults") {
    Merge tModifiers = pCommandInfo("modifiers")
    Set tName = $$$GetModifier(pCommandInfo,"name")
    If (tName = "") {
      Set tName = "registry"
      Set tModifiers("name") = tName
    }
    Set tModifiers("remote") = ""

    Set tModifiers("url") = ##class(%IPM.Repo.UniversalSettings).GetDefaultRegistry()
    If (tModifiers("url")="") {
        Write "Error retrieving default registry URL"
        Quit
    }
    Set tModifiers("username") = "", tModifiers("password") = ""
    Set tType = "%IPM.Repo.Remote.Definition"
    $$$ThrowOnError($ClassMethod(tType,"Configure",1,.tModifiers,.tData))
    Do ..Shell("repo -list")
	} Else {
		Set tName = $$$GetModifier(pCommandInfo,"name")
		Set tType = $ListGet(serverClassList)
		
		#dim tRepoTypeResult As %SQL.StatementResult
		Set tStatement = ##class(%SQL.Statement).%New()
		Set tSC = tStatement.%PrepareClassQuery("%IPM.Repo.Definition","Catalog")
		$$$ThrowOnError(tSC)
		Set tRepoTypeResult = tStatement.%Execute()
		If tRepoTypeResult.%SQLCODE < 0 {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRepoTypeResult.%SQLCODE, tRepoTypeResult.%Message)
		}
		While tRepoTypeResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tMonikers($ZConvert(tRepoTypeResult.%Get("Moniker"),"L")) = tRepoTypeResult.%Get("Classname")
			Set tClassList($Increment(tClassList)) = tRepoTypeResult.%Get("Classname")
			Set tDescList($Increment(tDescList)) = tRepoTypeResult.%Get("Description")
		}
		$$$ThrowOnError(tSC)


		If (tType = ""),(tName '= ""),##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(tName) {
			Set tInstance = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tName)
			If $IsObject(tInstance) {
				Set tType = tInstance.%ClassName(1)
			}
		}
	
    If (tType = "") {
      Set tResponse = ##class(%Library.Prompt).GetMenu("Which sort of repository do you wish to configure?",.tDescIndex,.tDescList,,$$$InitialDisplayMask)
      If (tResponse '= $$$SuccessResponse) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
      }
    
      If (tDescIndex = "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"A repository type must be specified."))
      }
      
      Set tType = tClassList(tDescIndex)
    }
		
		Set tBaseClass = "%IPM.Repo.Definition"
		If '$ClassMethod(tType,"%Extends",tBaseClass) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid type '%1' - must extend %2",tType,tBaseClass))
		}
		
		Merge tModifiers = pCommandInfo("modifiers")
		Merge tData = pCommandInfo("data")
		$$$ThrowOnError($ClassMethod(tType,"Configure",1,.tModifiers,.tData,tType))
    Do ..Shell("repo -list")
	}
}

ClassMethod ShowModulesForRepository(pRepoName As %String, pShowRepo As %Boolean = 0, pShowDesc As %Boolean = 0, pSearchString As %String = "", pShowAllVersions As %Boolean = 0) [ Private ]
{
  #define gn "^||tmpDesc"
	Kill @$$$gn
	Set (maxlenname,maxlenver) = 0, where = ""
	If pSearchString["*" {
		Set where=" WHERE name like ?"
	} ElseIf pSearchString'="" { 
		Set where=" WHERE name = ?"
	}
	Set tQuery = "SELECT Name,Version,Repository,Description,Origin,AllVersions FROM %IPM_Utils.Module_GetModuleList(?,?) "_where
	If (pSearchString = "") {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(, tQuery, pRepoName, pShowAllVersions)
	} Else {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(, tQuery, pRepoName, pShowAllVersions, $Replace(pSearchString,"*","%"))
	}
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
  Set list = 0
  Set width = 0
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Set name = tRes.%Get("Name")
    If width < $Length(name) {
      Set width = $Length(name)
    }

    Set list = list + 1
    Set list(list) = $ListBuild(name, tRes.Version)
    Set list(list, "Origin") = tRes.Origin
    If pShowDesc {
      Set list(list, "Description") = tRes.Description
    }
    If pShowRepo {
      Set list(list, "Repository") = tRes.Repository
    }
    If pShowAllVersions {
      Set list(list, "AllVersions") = tRes.AllVersions
    }
	}
  Set list("width") = width
  Write !
  Do ..DisplayModules(.list)
}

Query SourceControlClasses() As %SQLQuery(ROWSPEC = "ID:%String,Name:%String") [ SqlProc ]
{
	select Name as ID,Name from %Dictionary.ClassDefinition_SubclassOf('%IPM.ExtensionBase.SourceControl.Interface')
}

Query ServerMenuExtensionClasses() As %SQLQuery(ROWSPEC = "ID:%String,Name:%String") [ SqlProc ]
{
	select Name as ID,Name from %Dictionary.ClassDefinition_SubclassOf('%IPM.ExtensionBase.ServerMenu.Interface')
}

ClassMethod LoadFromRepo(tDirectoryName, ByRef tParams) [ Internal ]
{
	Set slash=$Select($ZVersion(1)=3:"/",1:"\")
	Set TempDir = ##class(%File).GetDirectory(##class(%File).GetDirectory($ZUtil(86))_"mgr"_slash_"Temp"_slash_$Translate($ZTimestamp,".,")_slash)
	$$$ThrowOnError(##class(%File).CreateDirectoryChain(TempDir))
	Set:$Extract(tDirectoryName,*)="/" tDirectoryName=$Extract(tDirectoryName,1,*-1)
	Set RepoName=$Piece($Piece($Piece(tDirectoryName,"/",*),".git")," ")
	Set tCmd="cd "_TempDir_" && git clone "_tDirectoryName
	If $Get(tParams("zpm","Branch"))'="" Set tCmd=tCmd_" -b "_tParams("zpm","Branch")
	$$$ThrowOnError(##class(%IPM.Utils.Module).RunCommandViaZF(tCmd,.tLog,.tErr))
  Set tDirectoryName = TempDir_slash_RepoName
  If ($Get(tParams("Verbose"))) {
		Write !,"Create tempory directory "_TempDir
		Write !,tCmd
    For i=1:1:$Get(tLog) {
      Write tLog(i),!
    }
    Write !,tDirectoryName
  }
  For i=1:1:$Get(tErr) {
    Write tErr(i),!
  }
	Hang 2
	Quit tDirectoryName
}

ClassMethod Load(ByRef pCommandInfo) [ Internal ]
{
	Set tDirectoryName = $Get(pCommandInfo("parameters","path"))
	Merge tParams = pCommandInfo("data")
	Set tParams("cmd") = "load"
	Do ##class(%Net.URLParser).Decompose(tDirectoryName, .tComponents)
	If $G(tComponents("scheme")) [ "http" {
		set tDirectoryName=..LoadFromRepo(tDirectoryName,.tParams)
	}
	If ##class(%File).DirectoryExists(tDirectoryName) {
		Set tParams("DeveloperMode") = $Get(tParams("DeveloperMode"), 1)
		$$$ThrowOnError(##class(%IPM.Utils.Module).LoadNewModule(tDirectoryName,.tParams))
	} ElseIf ##class(%File).Exists(tDirectoryName),$$$lcase($Piece(tDirectoryName, ".", *)) = "tgz" {
		Set tTargetDirectory = $$$FileTempDirSys
		Set tSC = ##class(%IPM.General.Archive).Extract(tDirectoryName, tTargetDirectory)
		$$$ThrowOnError(##class(%IPM.Utils.Module).LoadNewModule(tTargetDirectory, .tParams))
	}
}

ClassMethod CheckModuleNamespace() As %Status
{
	Do ..GetMapInfo(.tIsMappedFrom, .tIsMappedTo)
	If $Data(tIsMappedFrom($Namespace), sourceNS) # 2 {
		Quit $$$ERROR($$$GeneralError, $$$FormatText("Cannot install '%1' in namespace '%2' because it is mapped from namespace '%3'.", $$$IPMModuleName, $Namespace, sourceNS))
	}
	If $Data(tIsMappedTo($Namespace)) / 2 {
		Write !, "Will affect the following namespaces:", $NAMESPACE
		Set ns = ""
		For {
			Set ns = $Order(tIsMappedTo($Namespace, ns))
			If ns = "" {
				Quit
			}
			Write ", ", ns
		}
	}
	Quit $$$OK
}

ClassMethod Install(ByRef pCommandInfo) [ Internal ]
{
	Set tRegistry = ""
	Set tModuleName = $Get(pCommandInfo("parameters","module"))
	If (tModuleName["/") {
		Set $ListBuild(tRegistry, tModuleName) = $ListFromString(tModuleName, "/")
	}
	If (tModuleName = "") {
		Quit $$$OK
	}

	If tModuleName = $$$IPMModuleName {
		$$$ThrowOnError(..CheckModuleNamespace())
	}

	Set tVersion = $Get(pCommandInfo("parameters","version"))
	Set tKeywords = $$$GetModifier(pCommandInfo,"keywords")
	
	Set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
	Set tSearchCriteria.Registry = tRegistry
	Set tSearchCriteria.Name = $$$lcase(tModuleName)
	Set tSearchCriteria.VersionExpression = tVersion
	Set tSearchCriteria.Keywords = tKeywords
	$$$ThrowOnError(##class(%IPM.Repo.Utils).SearchRepositoriesForModule(tSearchCriteria,.tResults))
	
	If (tResults.Count() > 0) {
		Set tResult = ""
		#dim tResult As %IPM.Storage.QualifiedModuleInfo
		// Results are ordered by semantic version, descending. (So the "latest" version will always be first.)
		If ('$$$HasModifier(pCommandInfo,"prompt") || (tResults.Count() = 1)) && (tKeywords = "") {
			Set tResult = tResults.GetAt(1)
		} ElseIf (tResults.Count() > 0) {
			For i=1:1:tResults.Count() {
				Set tResultInfo = tResults.GetAt(i)
				Set tOptArray(i) = tResultInfo.DisplayName_" "_tResultInfo.VersionString_" @ "_tResultInfo.ServerName
			}
			
			Set tValue = ""
      		Set tResponse = ##class(%Library.Prompt).GetMenu("Which version?",.tValue,.tOptArray,,$$$InitialDisplayMask+$$$EnableQuitCharMask)
      		If (tResponse '= $$$SuccessResponse) {
        		$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
      		}
			
			If (tValue '= "") {
				Set tResult = tResults.GetAt(tValue)
			}
		}
		
		If (tResult '= "") {
			Do ##class(%IPM.Lifecycle.Base).GetDefaultParameters(.tParams)
			Merge tParams = pCommandInfo("data")
			Set tParams("DeveloperMode") = $Get(tParams("DeveloperMode"), 0)
			Set tParams("cmd") = "install"
			Set tParams("Install") = 1
      If tResult.Deployed {
        Set platformVersion = $System.Version.GetMajor() _ "." _$System.Version.GetMinor()
        Set tResult.PlatformVersion = platformVersion
        If ('tResult.PlatformVersions.Find(platformVersion)) {
          $$$ThrowStatus($$$ERROR($$$GeneralError, "Deployed package '" _ tModuleName _ "' " _ tResult.VersionString _ " not supported on this platform " _ platformVersion _ "."))
        }
      }
			$$$ThrowOnError(##class(%IPM.Utils.Module).LoadQualifiedReference(tResult, .tParams))
    
    }
	} Else {
		Set tPrefix = ""
		If (tModuleName '= "") {
			If (tVersion '= "") {
				$$$ThrowStatus($$$ERROR($$$GeneralError, tModuleName_" "_tVersion_" not found in any repository."))
			} Else {
				$$$ThrowStatus($$$ERROR($$$GeneralError, "'"_tModuleName_"' not found in any repository."))
			}
		} ElseIf (tKeywords '= "") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No modules found matching keywords: '"_tKeywords_"'"))
		} Else {
			Write !,"No modules found. Are there any repositories configured in the current namespace?"
		}
	}
}

ClassMethod Reinstall(ByRef pCommandInfo) [ Internal ]
{
	// Overriding defaults in the "data" array:
	// For now this is just the "UpdateSnapshots" flag but it could be more eventually.
	Set tData("UpdateSnapshots") = 1
	
	// Note that pCommandInfo("data") may override the default of UpdateSnapshots=1.
	Merge tData = pCommandInfo("data")
	Merge pCommandInfo("data") = tData
	
	// Find  the currently-installed version of the module
	Set tModuleName = $Get(pCommandInfo("parameters","module"))
	Set tModule = ##class(%IPM.Storage.Module).NameOpen(tModuleName,,.tSC)
	If $System.Status.Equals(tSC,$$$ERRORCODE($$$KeyValueNotFoundOpen)) {
		$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Module '%1' is not currently installed.",tModuleName)))
	}
	$$$ThrowOnError(tSC)

	If tModuleName = $$$IPMModuleName {
		$$$ThrowOnError(..CheckModuleNamespace())
	}
	
	Set tVersionString = tModule.Version.ToString()
	Write !,"Reinstalling ",tModuleName," ",tVersionString
	Set pCommandInfo("parameters","version") = tVersionString
	Do ..Install(.pCommandInfo)
}

ClassMethod Uninstall(ByRef pCommandInfo) [ Internal ]
{
	Merge tParams = pCommandInfo("data")
	Set tForce = $$$HasModifier(pCommandInfo,"force") // Force uninstallation even if things depend on this module
	If $$$HasModifier(pCommandInfo,"all") {
		$$$ThrowOnError(##class(%IPM.Utils.Module).UninstallAll(tForce,.tParams))
    Return
	} Else {
		Set tModuleName = pCommandInfo("parameters","module")
		If tModuleName = $$$IPMModuleName {
			$$$ThrowOnError(..CheckModuleNamespace())
		}	
		Set tRecurse = $$$HasModifier(pCommandInfo,"recurse") // Recursively uninstall unneeded dependencies
		$$$ThrowOnError(##class(%IPM.Storage.Module).Uninstall(tModuleName,tForce,tRecurse,.tParams))
	}
}

ClassMethod RunOnePhase(ByRef pCommandInfo) [ Internal ]
{
	Set tModName = $Get(pCommandInfo("parameters","module"))
	Set tPhases = $ListBuild($ZConvert(pCommandInfo, "w"))
	Set tIsComplete = '$$$HasModifier(pCommandInfo,"only")
  	Set tParams("Recurse") = $$$HasModifier(pCommandInfo,"recurse")
	Set tParams("cmd") = pCommandInfo
	Merge tParams = pCommandInfo("data")
	$$$ThrowOnError(##class(%IPM.Storage.Module).ExecutePhases(tModName,tPhases,tIsComplete,.tParams))
}

ClassMethod Unpublish(ByRef pCommandInfo) [ Internal ]
{
  	If ( ($Get(pCommandInfo("parameters","module"))="") || ($Get(pCommandInfo("parameters","version"))="") ) {
    	Set tCommandInfo("parameters","command") = "unpublish"
    	Do ..%Help(.tCommandInfo)
    	Quit
  	}

	Set tRegistry = ""
	Set tModuleName = $ZConvert($Get(pCommandInfo("parameters","module")), "L")
	If ( tModuleName["/" ) {
		Set $ListBuild(tRegistry, tModuleName) = $ListFromString(tModuleName, "/")
	}
	If ( tRegistry = "" ) {
		Set tRS = ##class(%IPM.Repo.Remote.Definition).PublishingServerFunc()
		If (tRS.%SQLCODE = 0) && tRS.%Next() {
			Set tServer = ##class(%IPM.Repo.Remote.Definition).%OpenId(tRS.ID)
		}
	} Else {
		Set tServer = ##class(%IPM.Repo.Definition).ServerDefinitionKeyOpen(tRegistry,,.tSC)
	}
	If ('$Isobject(tServer)) {
		Write "Registry not found: "_tRegistry,!
		Return $$$ERROR(5001, "Registry not found: "_tRegistry)
	}
	Set tVersion = $Get(pCommandInfo("parameters","version"))

	Try {
		Set tManager = ##class(%IPM.Repo.Remote.PublishManager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		$$$ThrowOnError(tManager.CheckUnpublishEnabled(.isEnabled, tServer.Name, tModuleName, tVersion))
		If (isEnabled) {
            Set tResult = 0
			If ($$$lcase(tVersion)="all") {
				Write $$$FormattedLine($$$Red, "Deleting a package and all its versions is an irreversible action")
                Set tHelp = "Enter ""Yes"" if you want to delete all package versions."
                Set tMsg = "Are you sure you want to delete all versions of the package """_tModuleName_""" from registry """_tServer.Name_""" ("_tServer.URL_")?"
			} Else {
				Write $$$FormattedLine($$$Red, "Deleting a package version is an irreversible action")
                Set tHelp = "Enter ""Yes"" if you want to delete selected package version."
				Set tMsg = "Are you sure you want to delete the package """_tModuleName_" "_tVersion_""" from registry """_tServer.Name_""" ("_tServer.URL_")?"
			}

		    Set tResponse = ##class(%Library.Prompt).GetYesNo(tMsg,.tResult,.tHelp)

            If (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
            }

			If (tResult) {
				$$$ThrowOnError(tManager.Unpublish(tServer.Name, tModuleName, tVersion))
				Write !!,"Package deleted"
			}
		} Else {
			Write !,"The package could not be deleted (the registry denied the request)",!
		}
	} Catch ex {
		Write !!,$$$FormattedLine($$$Red, "ERROR! "), ex.DisplayString()
	}
}

ClassMethod ModuleAction(ByRef pCommandInfo) [ Internal ]
{
	Set tModName = $Get(pCommandInfo("parameters","module"))
	Set tPhases = $ListFromString($Get(pCommandInfo("parameters","actions"))," ")
	Set tIsComplete = '$$$HasModifier(pCommandInfo,"only")
	If $ListLength(tPhases) {
		// Accept lower-case phase names in the command.
		Set tPtr = 0
		Set tActualPhases = ""
		While $ListNext(tPhases,tPtr,tPhase) {
			Set tActualPhases = tActualPhases_$ListBuild($ZConvert(tPhase, "w"))
		}
		Merge tParams = pCommandInfo("data")
		$$$ThrowOnError(##class(%IPM.Storage.Module).ExecutePhases(tModName,tActualPhases,tIsComplete,.tParams))
	} Else {
		If (tModName '= "") && ##class(%IPM.Storage.Module).NameExists(tModName) {
			// TODO: list phases if a valid module name was specified.
		} Else {
			Do ..%Help()
		}
	}
}

/// Run Dependency Analyzer for the given module
ClassMethod RunDependencyAnalyzer(ByRef pCommandInfo)
{
	If '$$$comClassDefined("%pkg.isc.dependencyAnalyzer.Utils") {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Dependency Analyzer package must be installed before running the dependency analyzer."))
	}
	Set ignoredStringRef = $$$GetModifier(pCommandInfo,"ignore-str")
	Set ignoreAll = $$$HasModifier(pCommandInfo,"ignore-str-all")
	Set invalidOnly = $$$GetModifier(pCommandInfo,"invalid-only")
  Set directDepsOnly = $$$HasModifier(pCommandInfo,"direct-deps-only")
	If (ignoreAll) {
		Set ignoredStringRef = $char(0)
	}
	Set moduleOrItemName = $Get(pCommandInfo("parameters", "moduleOrItem"))
	If (moduleOrItemName = "") {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Module/item name must be provided. Run help command to see syntax"))
	}
	Write !, "Running dependency analyzer...", !, !
	// Status can be ignored as it is written to the current device
	If (invalidOnly = 0)  {
		Do ##class(%IPM.DependencyAnalyzer).RunForAllReferences(moduleOrItemName, .allReferences, 1,,,,ignoredStringRef, directDepsOnly)
		If '$Data(allReferences) {
			Write !, "No references found!"
		}
	} Else {
		Do ##class(%IPM.DependencyAnalyzer).RunForInvalidReferences(moduleOrItemName, .invalidReferences, 1,,,,ignoredStringRef, directDepsOnly)
		If '$Data(invalidReferences) {
			Write !, "No invalid references found!"
		}
	}
	Write !
}

/// Implemented as custom query instead of `select Nsp, Nsp from %SYS.Namespace_List(0,0) WHERE status = 1` because of a DP issue, see https://github.com/intersystems/ipm/issues/579
Query ActiveNamespaces() As %Query(ROWSPEC = "ID:%String,Name:%String") [ SqlProc ]
{
}

ClassMethod ActiveNamespacesExecute(qHandle As %Binary) As %Status
{
  Try {
    Set tQuery = "SELECT NSP, Status FROM %SYS.Namespace_List(0,0)"
    Set rs = ##class(%SQL.Statement).%ExecDirect(, tQuery)
    Kill qHandle
    While rs.%Next() {
      If rs.%Get("Status") {
        Set qHandle($INCREMENT(qHandle)) = rs.%Get("NSP")
      }
    }
    Set qHandle = 0
  } catch ex {
    Return ex.AsStatus()
  }
  Return $$$OK
}

ClassMethod ActiveNamespacesFetch(qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ActiveNamespacesExecute ]
{
  Try {
    If $Data(qHandle($Increment(qHandle)), nsp) # 2 {
      Set Row = $ListBuild(nsp, nsp)
      Set AtEnd = 0
    } Else {
      Set Row = ""
      Set AtEnd = 1
    }
  } catch ex {
    Return ex.AsStatus()
  }
  Return $$$OK
}

ClassMethod ActiveNamespacesClose(qHandle As %Binary) As %Status [ PlaceAfter = ActiveNamespacesFetch ]
{
  Kill qHandle
  Return $$$OK
}

ClassMethod ListInstalled(ByRef pCommandInfo) [ Private ]
{
  Set tSearchString = $Get(pCommandInfo("parameters","searchString"),"")
	If (''$Data(pCommandInfo("modifiers","tree"))) {
		// Show tree of dependencies as well.
		// Modules that are dependencies for no other are shown at the top level.
		// TODO: deal with cyclic dependencies?
		Quit:'..GetListModule(,.tModMap)	
		Set tDepRes = ##class(%SQL.Statement).%ExecDirect(,
			"select ModuleItem->Name ModName,Dependencies_Name DepName,Dependencies_VersionString DepVer "_
			"from %IPM_Storage.ModuleItem_Dependencies")
    $$$ThrowSQLIfError(tDepRes.%SQLCODE, tDepRes.%Message)
		While tDepRes.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tModMap(tDepRes.%Get("ModName"),tDepRes.%Get("DepName")) = tDepRes.%Get("DepVer")
			Set tVisitedMap(tDepRes.%Get("DepName")) = 1
		}
		$$$ThrowOnError(tSC)
		
		Set tMod = ""
		For {
			Set tMod = $Order(tModMap(tMod),1,tVersion)
			Quit:(tMod="")
			Do:'$Data(tVisitedMap(tMod)) ..AccumulateTreeRecursive(tMod,.tModMap,.tOrderedTree)
		}
		Do ..PrintTree(.tOrderedTree)
	} Else {
    Set showFields = ""
    If +$Get(pCommandInfo("data","Desc")) {
      Set showFields = $ListBuild(
        "Description",
        "Author.CopyrightDate", 
        "Author.License", 
        "Author.Notes", 
        "Author.Organization", 
        "Author.Person",
        "Root"
      )
    }
		Set tDesc=+$Get(pCommandInfo("data","Desc"))
    Do ..GetListModules(,tSearchString, .list, showFields, $Get(pCommandInfo("modifiers", "repository")))
	}
  Merge tModifiers = pCommandInfo("modifiers")
  Do ..DisplayModules(.list,,,, .tModifiers)
}

/// Get module list in currently namespace
ClassMethod GetListModule(ns = {$Namespace}, ByRef Mod, OnlyName = 1) As %Status [ Deprecated ]
{
	new $Namespace
	set $Namespace=ns
	Set tRes = ##class(%SQL.Statement).%ExecDirect(,
		"select * from %IPM_Storage.ModuleItem")
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
	Set in=""
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Set name=tRes.%Get("DisplayName")
		Set in=in_"'"_name_"',"
		Set list=$ListBuild(tRes.%Get("VersionString"),tRes.%Get("Description"),tRes.%Get("Root"))
		For a="Author_CopyrightDate", "Author_License", "Author_Notes", "Author_Organization", "Author_Person" {
			Set list=list_$ListBuild(tRes.%Get(a))
		}
		Set Mod(name) = tRes.%Get("VersionString")
		Set:'OnlyName Mod(name,"L") = list
		
	}
	$$$ThrowOnError(tSC)
	Quit:in=""||(OnlyName) $$$OK
	Set in=$Extract(in,1,*-1)

	Set tQuery = "select Name, Version, Repository, Description, AllVersions from %IPM_Utils.Module_GetModuleList('registry') WHERE name in ("_in_")"
	Set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery)
	
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Set name = tRes.%Get("DisplayName")
		Set Mod(name,"R")=$ListBuild(tRes.%Get("Version"),tRes.%Get("Description"),tRes.%Get("Repository"),tRes.%Get("AllVersions"))
	}
	Quit $$$OK
}

ClassMethod AccumulateTreeRecursive(pModName As %String, ByRef pModMap, ByRef pTree, pLevel As %Integer = 0) [ Private ]
{
	If (pLevel = 0) && $Data(pVisitedMap(pModName)) {
		Quit
	}
	
	Set tParentIndex = $Increment(pTree)
	Set pTree(tParentIndex) = $ListBuild(pModName_" "_$Get(pModMap(pModName),"[missing]"))
	Set tDep = ""
	Set tPrevSibling = ""
	For {
		Set tDep = $Order(pModMap(pModName,tDep),1,tDepVerExpr)
		Quit:(tDep="")
		
		// Set first child for parent node to this index (if there is no first child yet)
		Set tSiblingIndex = pTree + 1
		If ($ListGet(pTree(tParentIndex),2) = "") {
			Set $List(pTree(tParentIndex),2) = tSiblingIndex
		}
		
		// Set next sibling for previous node to this index.
		If (tPrevSibling '= "") {
			Set $List(pTree(tPrevSibling),3) = tSiblingIndex
		}
		Set tPrevSibling = tSiblingIndex
		
		Do ..AccumulateTreeRecursive(tDep,.pModMap,.pTree,pLevel+1)
	}
}

ClassMethod ListDependents(ByRef pCommandInfo) [ Private ]
{
	Set tTree = ''$Data(pCommandInfo("modifiers","tree"))
	Set tRepos = $ListFromString($Get(pCommandInfo("modifiers","repos")))
	Set tModName = $Get(pCommandInfo("parameters","module"))
	Set tVersion = $Get(pCommandInfo("parameters","version"))
  If tModName="" {
    $$$ThrowStatus($$$ERROR($$$GeneralError,"A module name is required"))
  }
	
	If tTree {
		New %tree
		Set tSC = ##class(%IPM.Utils.Module).GetDependentsAsTree(.%tree,.tErrorList,tModName,tVersion,tRepos)
		$$$ThrowOnError(tSC)
	} Else {
		Set tSC = ##class(%IPM.Utils.Module).GetDependentsList(.tList,.tErrorList,tModName,tVersion,tRepos)
		$$$ThrowOnError(tSC)
	}
	
	If $Data(tErrorList) {
		Write !,"Warning: some errors occurred."
		For i=1:1:tErrorList {
			Set $ListBuild(tServer,tModName,tVersion,tErrorSC) = tErrorList(i)
			Set tServer = $Case(tServer,"":" (installed)",:" @ "_tServer)
			Write !,tModName," ",tVersion,tServer,": ",$System.Status.GetErrorText(tErrorSC)
		}
		Write !
	}
	
	If tTree {
		Set tRef = "%tree"
		Set tState = 0
		
		For {
			Set tRef = $Query(@tRef)
			Quit:tRef=""
			
			For i=1:1:$QLength(tRef) {
				Set tSub = $QSubscript(tRef,i)
				If ($Get(tState(i)) = tSub) {
					Continue
				} Else {
					Set tNodeIndex = $Increment(tDependentTree)
			
					Set tState(i) = tSub
					For j=i+1:1:tState {
						Kill tState(j)
						Kill tPreviousNode
					}
					If $Data(tState(i,"node"),tPreviousNode)
					
					Set tState = i
					Set tState(i,"node") = tNodeIndex
					
					Set $ListBuild(tModName,tVersion,tServer) = tSub
					Set tServer = $Case(tServer,"":" (installed)",:" @ "_tServer)
					
					Set tValue = tModName_" "_tVersion_tServer
					
					Set tDependentTree(tNodeIndex) = $ListBuild(tValue)
					
					// Set first child
					If $Data(tState(i-1,"node"),tParent) && ($ListGet(tDependentTree(tParent),2) = "") {
						Set $List(tDependentTree(tParent),2) = tNodeIndex
					}
					
					// Set next sibling of previous node
					If $Data(tPreviousNode,tPreviousNode) && (tPreviousNode '= $Get(tParent)) {
						Set $List(tDependentTree(tPreviousNode),3) = tNodeIndex
					}
					
					Set tPreviousNode = tNodeIndex
				}
			}
		}
		
		Do ..PrintTree(.tDependentTree)
	} Else {
		For i=1:1:tList.Count() {
			#dim tItem As %IPM.Storage.QualifiedModuleInfo
			Set tItem = tList.GetAt(i)
			Set tServer = $Case(tItem.ServerName,"":" (installed)",:" @ "_tItem.ServerName)
			Write !,tItem.Name," ",tItem.VersionString,tServer
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
	Set tFrontPadding = ""
	Set tChildDepth = 0
	For i=1:1:$Order(pTree(""),-1) {
		Set tFirstChild = ""
		Set tNextSibling = ""
		Set $ListBuild(tValue, tFirstChild, tNextSibling) = pTree(i)
		
		Set tFrontPadding = $Get(tPadding(i))
		
		If (tNextSibling = "") {
			Set $Extract(tFrontPadding,*-2) = $Char($ZHex("2514H"))
		}
		If (tFirstChild '= "") {
			Set $Extract(tFrontPadding,*) = $Char($ZHex("252CH"))
		}
		
		Write tFrontPadding,$$$FormattedLine($$$Green,$Piece(tValue," ",1))," ",$Piece(tValue," ",2),!
		
		If (tNextSibling '= "") {
			Set tPadding(tNextSibling) = $Get(tPadding(i))
		}
		If (tFirstChild '= "") {
			Set tModPadding = ""
			If $Get(tPadding(i)) '= "" {
				Set tModPadding = $Extract(tPadding(i),1,*-3)_$Case(tNextSibling,"":" ",:$Char($ZHex("2502H")))_"  "
			}
			Set tPadding(tFirstChild) = $Extract(tModPadding,1,*-1)_$Char($ZHex("251CH"),$ZHex("2500H"),$ZHex("2500H"))
		}
	}
}

ClassMethod ListOrphans(ByRef pCommandInfo) [ Private ]
{
	Set tType = $$$GetModifier(pCommandInfo,"type")
	Set tResult = ##class(%IPM.Utils.Module).OrphanedResourcesFunc($Namespace,tType)
	While tResult.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Write tResult.%Get("Name"),!
	}
}

ClassMethod Arrange(ByRef pCommandInfo) [ Private ]
{
	Set tSC = $$$OK
	Set tAll = $$$HasModifier(pCommandInfo,"all")
	Set tModuleName = $Get(pCommandInfo("parameters","module"))
	If (tAll && (tModuleName '= "")) {
		Set tSC = $$$ERROR($$$GeneralError,"Invalid command - cannot specify '-all' flag and a module name.")
	} ElseIf ('tAll && (tModuleName = "")) {
		Set tSC = $$$ERROR($$$GeneralError,"Invalid command - must specify '-all' or a module name.")
	}
	$$$ThrowOnError(tSC)
	
	Try {
		If (tAll) {
			Set tResult = ##class(%SQL.Statement).%ExecDirect(,
				"select Name from %IPM_Storage.ModuleItem where DeveloperMode = 1")
			If (tResult.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResult.%SQLCODE,tResult.%Message)
			}
		}
		For {
			If (tAll) {
				Set tHasData = tResult.%Next(.tSC)
				$$$ThrowOnError(tSC)
				If 'tHasData {
					Quit
				}
				Set tModuleName = tResult.%Get("Name")
			}
			
			Set tModule = ##class(%IPM.Storage.Module).NameOpen(tModuleName,,.tSC)
			$$$ThrowOnError(tSC)
			Set tSC = ##class(%IPM.Utils.Module).ExportDocumentForObject(tModule,.tSourceControlOutput)
			$$$ThrowOnError(tSC)
			For tLine=1:1:$Get(tSourceControlOutput) {
				Write tSourceControlOutput(tLine),!
			}
			
			If 'tAll {
				Quit
			}
		}
	} Catch e {
		Set tSC = $$$EMBEDSC($$$ERROR($$$GeneralError,"Error arranging module(s)"),e.AsStatus())
		$$$ThrowStatus(tSC)
	}
}

ClassMethod Import(ByRef pCommandInfo)
{
	Set tSC = $$$OK
	Set tSource = $Get(pCommandInfo("parameters","source"))
	If (tSource = "") {
    	$$$ThrowStatus($$$ERROR($$$GeneralError,"A source for import must be specified"))
  	}
	Try {
		Set tRecurse = '$$$HasModifier(pCommandInfo,"norecurse")
		Set tCompile = '$$$HasModifier(pCommandInfo,"nocompile")
		Set tVerbose = $$$HasModifier(pCommandInfo,"verbose")
		Set tQuiet = $$$HasModifier(pCommandInfo,"quiet")
		
		#dim %SourceControl As %Studio.SourceControl.ISC
		New %SourceControl
		Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		$$$ThrowOnError(tSC)
		
		Set tSourceDir = ##class(%Library.File).NormalizeDirectory(tSource)
		Set tSourceFile = ##class(%Library.File).NormalizeFilename(tSource)
		Set tLoadFlags = $Select(tCompile:"c",1:"")_$Select(tQuiet:"-d",tVerbose:"d",1:"")_"k"
		For tListOnly = 1,0 {
			Continue:tListOnly&&'$IsObject(%SourceControl)
			Set tLoadedList = ""
			// First pass, this lists the things that will be loaded.
			// Second pass, it loads them.
			If ##class(%Library.File).Exists(tSourceFile) {
				If ##class(%Library.File).DirectoryExists(tSourceFile) {
					If 'tQuiet {
						Write !,"Loading "_tSourceDir
					}
					Set tSC = $System.OBJ.ImportDir(tSourceDir,,tLoadFlags,,tRecurse,.tImportedArray,tListOnly)
					
					// Build $ListBuild list of loaded items
					Set tLoadedKey = ""
					For {
						Set tLoadedKey = $Order(tImportedArray(tLoadedKey))
						If (tLoadedKey = "") {
							Quit
						}
						
						Set tLoadedList = tLoadedList_$ListBuild(tLoadedKey)
					}
				} Else {
					If 'tQuiet {
						Write !,"Loading "_tSourceFile
					}
					Set tSC = $System.OBJ.Load(tSourceFile,tLoadFlags,,.tLoadedList,tListOnly)
					Set tLoadedList = $ListFromString(tLoadedList)
				}
			} Else {
				Set tSC = $$$ERROR($$$FileDoesNotExist,tSource)
			}
			$$$ThrowOnError(tSC)

			Continue:'$IsObject(%SourceControl)
			
			If tListOnly {
				// Trigger source control class's user action 6 (simulating a load into Studio)
				// This happens first to avoid warnings about the file being modified outside of Studio.
				Set tSC = ##class(%Studio.SourceControl.Interface).UserAction(1,6,$ListToString(tLoadedList),"")
				$$$ThrowOnError(tSC)
			} Else {
				If 'tQuiet {
					Write !,$ListLength(tLoadedList)," item(s) loaded."
					Write !,"Exporting modified files."
				}
				
				Set tPointer = 0
				Set tSC = $$$OK
				While $ListNext(tLoadedList,tPointer,tLoadedItem) {
					Set tLoadedItem = ##class(%Studio.SourceControl.Interface).normalizeName(tLoadedItem)
					
					// Avoid comparison with file timestamp in Perforce workspace, since that's irrelevant; we have loaded a new version, likely from elsewhere.
					// If a file has previously been exported to the Perforce workspace but not actually marked for add, GetStatus will report that the file is
					// in source control. This case is handled later after revert is attempted and fails because the file is not known to Perforce.
					Kill ^Sources(0,"FileTimeStamp",tLoadedItem)
					If $$$ISOK(##class(%Studio.SourceControl.Interface).GetStatus(tLoadedItem,.tIsInSourceControl)) {
            			If tIsInSourceControl {
              				Set tSC = $$$ADDSC(tSC,%SourceControl.OnAfterSave(tLoadedItem))
            			} Else {
            				Set tSC = $$$ADDSC(tSC,%SourceControl.AddToSourceControl(tLoadedItem))
            			}
          			}
				}
			}
		}
	} Catch e {
		// Append string rather than using $System.Status.EmbedStatus, for clearer display in caller.
		Set tSC = $$$ERROR($$$GeneralError,"Error in import: "_$System.Status.GetErrorText(e.AsStatus()))
		$$$ThrowStatus(tSC)
	}
}

ClassMethod UpdateLanguageExtensionsOne(RoutineName As %String, pTestOnly As %Boolean = 0, Output pFound As %Boolean = 0, ByRef tGenLines) As %Status
{
	Set tRtn = ##class(%Routine).%New(RoutineName)
	If ##class(%Routine).Exists(RoutineName) {
    While 'tRtn.AtEnd {
      Set tLine = tRtn.ReadLine()
      If $Match(tLine,$$$STARTTAGREGEX) {
        // Read through the ending tag.
        While ('tRtn.AtEnd) && ('$Match(tRtn.ReadLine(),$$$ENDTAGREGEX)) {}
        
        // Generate the lines.
        Set pFound = 1
        For i=1:1:tGenLines {
          Set tRtnLines($Increment(tRtnLines)) = tGenLines(i)
        }
      } Else { 
        // outside of the tags, just copy the lines to preserve users' custom code
        Set tRtnLines($Increment(tRtnLines)) = tLine
	  }
    }
    If 'pFound {
      For i=1:1:tGenLines {
        Set tRtnLines($Increment(tRtnLines)) = tGenLines(i)
      }
    }
  } Else {
    Merge tRtnLines = tGenLines
  }
  If (pTestOnly) {
    Quit
  }
  Do tRtn.Clear()
  For i=1:1:tRtnLines {
    Do tRtn.WriteLine(tRtnLines(i))
  }
  $$$ThrowOnError(tRtn.Save())
  $$$ThrowOnError(tRtn.Compile("/keepsource"))
	Quit $$$OK
}

ClassMethod UpdateLanguageExtensions(pVerbose As %Boolean = 0, pTestOnly As %Boolean = 0, Output pFound As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		TSTART
		// Get routine lines to generate
		Set tOffset = 0
		Set tStarted = 0
		Set labelPrefix = $Select($System.Version.GetMajor() >= 2023: "",1: "z")
		Set method = ##class(%Dictionary.MethodDefinition).IDKEYOpen($classname(),"LanguageExtensions",,.sc)
		$$$ThrowOnError(sc)
		Set tGenLines($i(tGenLines)) = $$$STARTTAGQ
		While 'method.Implementation.AtEnd {
			Set tGenLines($i(tGenLines)) = method.Implementation.ReadLine()
		}
		Set tGenLines($i(tGenLines)) = $$$ENDTAGQ

		If '$Data(tGenLines) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Could not find %ZLANGC00 routine contents in "_$Classname()))
		}
		Do ..UpdateLanguageExtensionsOne("%ZLANGC00.MAC", pTestOnly,.pFound,.tGenLines)
		Quit:pTestOnly
		Set i="" 
		For { Set i=$Order(tGenLines(i),1,tStr) Quit:i=""
			If tStr["Do ##class" Set tGenLines(i)=$Replace($Replace(tStr,"Quit",""),"Do ","Quit ") Quit
		}
		Do ..UpdateLanguageExtensionsOne("%ZLANGF00.MAC", pTestOnly,.pFound,.tGenLines)
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}
	Quit tSC
}

ClassMethod LanguageExtensions() [ Private ]
{
ZPM(pArgs...)
 If $System.CLS.IsMthd("%IPM.Main", "Shell") { 
 	Do ##class(%IPM.Main).Shell(pArgs...) Quit
 } Else {
	// TODO: Needs to support enabling IPM from here, also need to decide what level of customization to provide
	Set quitOnError = $Get(pArgs(2))
	Set haltOnComplete = $Get(pArgs(3))
	Write !, "IPM is not enabled in this namespace."
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Nsp FROM %SYS.Namespace_List()")
	If rs.%SQLCODE '= 0 {
		Write !, "Error getting namespace name. SQLCODE =", rs.%SQLCODE
	} Else {
		New $Namespace
		Set found = 0	
		While rs.%Next() {
			Set $Namespace = $Zstrip(rs.%Get("Nsp"), "<>WC")
			// Some I4H containers come with %IPM.Main but the "version" command doesn't work ?!
			If $System.CLS.IsMthd("%IPM.Main", "Shell") && ($Namespace '= "HSLIB") && ($Namespace '= "HSSYS") {
				Write !, "Change namepace to one of the following to run the ""zpm"" command"
				Do ##class(%IPM.Main).Shell("version")
				Write !, "If you want to map IPM globally, switch to one of the namespaces above and run: zpm ""enable -map -globally""."
				Write !, "If you want to reset repository and map IPM globally along with repository settings, switch to one of the namespaces above and run: zpm ""enable -community""."
				Set found = 1
				Quit
			}
		}
		// Shouldn't happen since %ZLANGC00.mac and %ZLANGF00.mac are present
		If 'found {
			Write !, "No namespace found with IPM enabled."
		}
	}

	If quitOnError {
		Write ! // Add a newline before quitting, otherwise the shell prompt will be on the same line as the error message
		Do $System.Process.Terminate($Job, 1)
	}
	If haltOnComplete {
		Write ! // Add a newline before halting
		Halt
	}
	// The $$$ERROR macro is not available for use in language extension
	Return $System.Status.Error(5001, "IPM is not enabled in this namespace.")
 }
}

ClassMethod EnableIPM(ByRef pCommandInfo)
{
	New $Namespace
	Set initNamespace = $Namespace
	If ..IPMInstalled(.ipmModuleId){
		Set modDef = ##class(%IPM.Storage.Module).%OpenId(ipmModuleId,,.sc)
		$$$ThrowOnError(sc)
		Write !, "Version of IPM in current namespace: "
		Write !,($namespace)_"> "_$$$FormattedLine($$$Green,$$$IPMModuleName_" ")_modDef.VersionString
	}

	If $$$HasModifier(pCommandInfo,"community") {
		For cmd = "repo -delete-all", "repo -reset-defaults", "enable -map -repos -globally" {
			Write !!, "RUNNING command: """, cmd, """"
			Do ..ShellInternal(cmd, .exc)
			If exc '= $$$NULLOREF {
				Write !, $$$FormattedLine($$$Red, $$$FormatText("Error running command ""%1"" - %2", cmd, exc.DisplayString()))
			} Else {
				Write !, $$$FormattedLine($$$Green, $$$FormatText("Command ""%1"" finished successfull", cmd))
			}
		}
		Return
	}

	Set quiet = $$$HasModifier(pCommandInfo,"quiet")
	Set preview = $$$HasModifier(pCommandInfo,"preview")
	Set map = $$$HasModifier(pCommandInfo,"map")
	Set globally = $$$HasModifier(pCommandInfo, "globally")
	Set localOnly = $$$HasModifier(pCommandInfo, "local-only")
	Set version = $$$GetModifier(pCommandInfo, "version")
	Set namespaces = $$$GetModifier(pCommandInfo, "namespaces")
	Set namespaces = $$$ucase(namespaces)
	Set allowUpgrade = $$$HasModifier(pCommandInfo,"allow-upgrade")
	Set mapRepos = $$$HasModifier(pCommandInfo,"repos")
	Set remoteName = $$$GetModifier(pCommandInfo,"remote")
	Set useLocal = 1			// var to store the final decision of whether to use local manifest or get from server
	Set targetVersion = "" 		// var to store the final version of IPM to be installed
	Kill targetNamespaces 		// multi-dim array to store the final namespaces that need to install IPM
	Set loadFlag = "ck/displayerror=1/displaylog=0" // flags + modifiers to use when loading module manifest file / stream - ensure compilation and only display error instead of entire log

	// basic sanity checks
	If (quiet && (namespaces = "") && 'globally) {
		$$$ThrowOnError($$$ERROR($$$GeneralError,"Cannot install IPM in quiet mode without specifying namespaces to install."))
	}
	If ((namespaces '= "") && globally) {
		$$$ThrowOnError($$$ERROR($$$GeneralError,"Cannot specify namespaces and global installation flag at the same time."))
	}
	If (version '= "") && (globally && map) {
		$$$ThrowOnError($$$ERROR($$$GeneralError,"Cannot specify version when mapping the currently-installed version globally."))
	}
	If map && 'globally && (namespaces = "") {
		$$$ThrowOnError($$$ERROR($$$GeneralError,"If mapping from the current namespace's routine database with -map, must specify either -globally or a list of namespaces with -ns"))
	}
	If ('map) && (mapRepos) {
		$$$ThrowOnError($$$ERROR($$$GeneralError,"Cannot specify -repos without -map"))
	}

	If map {
		If globally {
			Set namespaces = ""
			Do ..GetListNamespace(.list)
			// Namespace-specific mappings aren't allowed to override %ALL mappings. See https://github.com/intersystems/ipm/pull/485
			Kill list("%ALL")
			Set key = ""
			For {
				Set key = $Order(list(key))
				If key = "" {
					Quit
				}
				Set namespaces = namespaces _ $ListBuild(key)
			}
		} Else {
			Set namespaces = $ListFromString(namespaces)
		}

		// First try to map IPM itself
		Set pointer = 0
		While $ListNext(namespaces,pointer,namespace) {
			Set namespace = $Zstrip(namespace, "<>WC")
			Set $Namespace = namespace
			If ..IPMInstalled() {
				If 'quiet || preview {
					Write !,"Skipping IPM mapping of "_namespace_" - IPM already installed."
				}
				Continue
			}
			Set $Namespace = initNamespace
			If preview {
				Write !,"Would add IPM mappings to "_namespace
				Continue
			}
			If 'quiet {
				Write !,"Mapping %IPM package in "_initNamespace_" equivalently to "_namespace
			}
			$$$ThrowOnError(##class(%IPM.Utils.Build).MapPackageEquivalently("%IPM",initNamespace,namespace))
			If 'quiet {
				Write !,"Mapping %IPM.* routines in "_initNamespace_" equivalently to "_namespace
			}
			$$$ThrowOnError(##class(%IPM.Utils.Build).MapRoutineEquivalently("%IPM.*",initNamespace,,namespace))
		}

		// Then try to map repositories if -repos is specified
		If mapRepos {
			Do ..GetMapInfo(.isMappedFrom)
			Set pointer = 0
			While $ListNext(namespaces,pointer,namespace) {
				Set namespace = $ZStrip(namespace, "<>WC")
				// If IPM is not mapped from source namespace, skip repo mapping 
				If $Get(isMappedFrom(namespace)) '= initNamespace {
					If 'quiet || preview {
						Write !,"Skipping repository mapping of "_namespace_" - IPM not mapped from source namespace."
					}
					Continue
				}
				// If repository are already present, also skip repo mapping avoid override
				Set $Namespace = namespace
				If $Data(^IPM.Repo.DefinitionD) \ 2 {
					If 'quiet || preview {
						Write !,"Skipping repository mapping of "_namespace_" - IPM repositories found."
					}
					Continue
				}
				Set $Namespace = initNamespace
				If preview {
					Write !,"Would add IPM repository mappings to "_namespace
					Continue
				}
				If 'quiet {
					Write !,"Mapping IPM repository in "_initNamespace_" equivalently to "_namespace
				}
				For suffix = "D", "S", "I" {
					$$$ThrowOnError(##class(%IPM.Utils.Build).MapGlobalEquivalently("IPM.Repo.Definition"_suffix, initNamespace, namespace))
				}
			}
		}

		Set $Namespace = initNamespace
		If preview {
			Write !,"Preview mode; no configuration changes were made."
		} ElseIf 'quiet {
			Write !,"Done.",!
			Do ..Version()
		}
		Return
	}

	New $Namespace
	// 1. Get list of local IPM artifacts under /<instance install dir>/lib/ipm/
	Set XMLDir = $system.Util.InstallDirectory()
	For subDirName = "lib", "ipm" {
		Set XMLDir = ##class(%File).SubDirectoryName(XMLDir, subDirName)
	}
  	Set statement = ##class(%SQL.Statement).%New()
  	Set sc = statement.%PrepareClassQuery("%File", "FileSet")
  	$$$ThrowOnError(sc)
	// Valid IPM installation manifest should be of format: ipm-0.0.1.xml
	If ##class(%File).DirectoryExists(XMLDir) {
		Set resultSet = statement.%Execute(XMLDir, "ipm-*.xml")
		If (resultSet.%SQLCODE < 0)  {
			$$$ThrowSQLIfError(resultSet.%SQLCODE,resultSet.%Message)
		}
		Kill ipmLocalArray			// multi-dim array to store local ipm manifests; ipmLocalArray(<version>)=<fileName>
		Kill menuList				// menu to let user choose which version of local ipm to install (if not in quiet mode and no version is specified)
		While resultSet.%Next(.sc) {
			$$$ThrowOnError(sc)
			Set fileName = resultSet.%Get("Name")
			If (resultSet.%Get("Type") = "F") {
				// get the exact version string from filename
				Set exactIPMVer = $Piece($Piece(fileName, "ipm-", 2, *), ".xml", 1, *-1)
				Set ipmLocalArray(exactIPMVer) = fileName
				Set menuList($Increment(menuList)) = exactIPMVer_" (local version)"
			}
		}
		$$$ThrowOnError(sc)
	}

	If ('$DATA(menuList) && localOnly) {
		$$$ThrowOnError($$$ERROR($$$GeneralError,"No ipm-<version>.xml installer file is found locally in directory: "__XMLDir))
	}

	// 2. Choose / propmpt user to choose which local/remote version of IPM to install
	If (version '= "") {
		Set targetVersion = version
		If '$DATA(ipmLocalArray(version)) {
			If localOnly {
				$$$ThrowOnError($$$ERROR($$$GeneralError,"No ipm-"_version_".xml installer file is found locally in directory: "_XMLDir))
			}
			Write !, "No ipm-"_version_".xml installer file is found in "_XMLDir_" locally. Trying to download from the registry."
			// need to get from remote registry server
			Set useLocal = 0
		}
	} Else {
		If quiet {
			// quiet mode + no version specified - either error out or install latest version from registry / locally
			If localOnly {
				//using semantic version utility, find the latest local version and install
				Set key = ""
				While 1 {
					Set key = $Order(ipmLocalArray(key))
					Set currentVer = ipmLocalArray(key)
					If (targetVersion = "") {
						Set targetVersion = currentVer
						Continue
					}
					Set semVerTarget = ##class(%IPM.General.SemanticVersion).FromString(targetVersion)
					Set semVerCurrent = ##class(%IPM.General.SemanticVersion).FromString(currentVer)
					If semVerCurrent.Follows(semVerTarget) {
						Set targetVersion = currentVer
					}
				}
			} Else {
				Write !, "No IPM version is specified and is in quiet mode. Install the latest version of IPM from the registry."
				Set useLocal = 0
				Set targetVersion = "latest"
			}
		} Else {
			// prompt user with option to download the latest version from registry
			Set localIPMCount = $Get(menuList, 0)
			If 'localOnly {
				// Add remote version options to menuList
				Set server = ##class(%IPM.Repo.Remote.Definition).GetOne(remoteName, .sc)
				$$$ThrowOnError(sc)
				If $IsObject(server) {
					Set latestVersion = server.GetPackageService().GetLatestModuleVersion($$$IPMModuleName)
					Set menuList($Increment(menuList)) = "latest"_" (remote version - "_latestVersion_")"
				}
				kill server
				kill packageService
			}
			Set menuValue = 1
			Set menuResponse = ##class(%Library.Prompt).GetMenu("Which version of IPM to use?", .menuValue, .menuList,,128)
			If (menuResponse '= 1) {
				$$$ThrowOnError($$$ERROR($$$GeneralError,"Unsupported response. Operation cancelled."))
			}
			Set targetVersion = $Piece(menuList(menuValue), " ") // get rid of (local version) or (remote version) suffix
			If (menuValue > localIPMCount) {
				Set useLocal = 0
			}
		}
	}

	// Now we know which exact version to install and we know whether we should install it with local artifact or get from registry,
	// 3. Figure out which namespaces to install

	// TODO: Let user interactively choose which namespaces to install IPM
	Set baseNS = $Namespace
	Set sc = ##class(%SYS.Namespace).ListAll(.allNS)
	$$$ThrowOnError(sc)
	// multi-dim array to store all non-%SYS explicit namepaces that 
	// either have no IPM installed (if allow-upgrade is not set)
	// or all of them (if allow-upgrade is set)
	Kill namespacesForIPM
	Set currentNS = ""
	If allowUpgrade {
		Merge namespacesForIPM = allNS
	} Else {
		While 1 {
			Set currentNS = $ORDER(allNS(currentNS))
			If currentNS = "" {
				Quit
			}
			// avoid %SYS and implied namespaces
			If (currentNS '= "%SYS") && ($ZCONVERT(currentNS, "U") = currentNS) {
				Set $Namespace = currentNS
				If '$System.CLS.IsMthd("%IPM.Main", "Shell") {
					Set namespacesForIPM(currentNS) = 1
				}
			}
		}
	}
	Set $Namespace = baseNS
	If globally {
		Merge targetNamespaces = namespacesForIPM
	} ElseIf (namespaces '= "") {
		Set specifiedNSs = $ListFromString(namespaces, ",")
		Set ptr = 0
   		While $ListNext(specifiedNSs, ptr, value) {
			If '$DATA(namespacesForIPM(value)) {
				Write !, value_" is not a valid namespace to install IPM"_$Select(allowUpgrade: ". ", 1: ", or it already has IPM installed. ")_"Skipped."
			} Else {
				Set targetNamespaces(value) = 1
			}
		}
	} Else {
		// TODO: Implement this part
		Write !, "Currently do not support interactively choose namespaces to install IPM. Use -namespaces or -globally modifier."
		Return
	}

	// 4. Now that we got all the namespaces that need to install IPM, do the actual installation
	If 'useLocal {
		Set server = ##class(%IPM.Repo.Remote.Definition).GetOne(remoteName, .sc)
		$$$ThrowOnError(sc)
		If $IsObject(server) {
			Set packageService = server.GetPackageService()
			Set ipmRef = ##class(%IPM.Storage.ModuleInfo).%New()
			// TODO: Make this ipm eventually once the package name is changed
			Set ipmRef.Name = $$$IPMModuleName
			If (targetVersion = "latest") {
				// convert latest to semantic version so that it can be undestood by ModuleInfo class
				Set server = ##class(%IPM.Repo.Remote.Definition).GetOne(remoteName, .sc)
				$$$ThrowOnError(sc)
				If $IsObject(server) {
					Set targetVersion = server.GetPackageService().GetLatestModuleVersion($$$IPMModuleName)
				}
			}
			If (targetVersion = "") {
				$$$ThrowOnError($$$ERROR($$$GeneralError,"Failed to find a satisfying target version of IPM to install."))
			}
			Set ipmRef.VersionString = targetVersion
			
			// Retrieve module installer manifest
			Set manifest = packageService.GetModuleInstallerManifest(ipmRef)
			Set currentNS = ""
			While 1 {
				Set currentNS = $ORDER(targetNamespaces(currentNS))
				If currentNS = "" {
					Quit
				}
				Set $Namespace = currentNS
				If preview {
					Write !, $$$FormatText("Would install IPM version %1 from registry in namespace %2", targetVersion, currentNS)
					Continue
				}
				Do $SYSTEM.OBJ.LoadStream(manifest, loadFlag)
				Write !, "IPM enabled for namespace "_currentNS
			}
		} Else {
			$$$ThrowOnError($$$ERROR($$$GeneralError,"Failed to get a valid registry server in order to download the IPM manifest."))
		}
	} Else {
		Set targetIPMFileName = ipmLocalArray(targetVersion)
		Set currentNS=$ORDER(targetNamespaces(""))
		Set enabledNSList = ""
		Set problematicList = ""
		Set tOverallSC = $$$OK
		While (currentNS '="") {
			Set $Namespace = currentNS
			If preview {
				Set filePath = ##class(%File).NormalizeFilename(targetIPMFileName, XMLDir)
				Write !, $$$FormatText("Would install IPM using file at %1 in namespace %2", filePath, currentNS)
				Continue
			}
			Set tSC = $SYSTEM.OBJ.Load(##class(%File).NormalizeFilename(targetIPMFileName, XMLDir), loadFlag)
			If $$$ISOK(tSC) {
				Set enabledNSList = enabledNSList_$ListBuild(currentNS)
			} else {
				Set problematicList = problematicList_$ListBuild(currentNS)
			}
			Set currentNS = $ORDER(targetNamespaces(currentNS))
			Set tOverallSC = $$$ADDSC(tOverallSC,tSC)
		}
		If 'preview {
			Write !, "IPM enabled for namespace(s) "_$ListToString(enabledNSList)
			If $$$ISERR(tOverallSC) {
				Write !, "IPM failed to enable for namespace "_$ListToString(problematicList)
				$$$ThrowOnError(tOverallSC)
			}
		}
	}

	If preview {
		Write !,"Preview mode; no configuration changes were made."
	}
}

ClassMethod UnmapIPM(ByRef pCommandInfo)
{
	Set globally = $$$HasModifier(pCommandInfo,"globally")
	Set namespaces = $ListFromString($$$GetModifier(pCommandInfo,"namespaces"), ",")
	Set namespaces = $$$ucase(namespaces)
	Set verbose = '$$$HasModifier(pCommandInfo,"quiet")
	set reposOnly = $$$HasModifier(pCommandInfo,"repos-only")
	// Sanity check
	If (globally && (namespaces '= "")) {
		$$$ThrowOnError($$$ERROR($$$GeneralError,"Cannot specify namespaces and global unmap flag at the same time."))
	}
	If ('globally && (namespaces = "")) {
		$$$ThrowOnError($$$ERROR($$$GeneralError,"Must specify either -globally or a list of namespaces with -ns"))
	}
	// populate namespaces if globally is set
	If globally {
		Do ..GetListNamespace(.nsTree)
		Set ns = ""
		For {
			Set ns = $Order(nsTree(ns))
			If ns = "" {
				Quit
			}
			Set namespaces = namespaces_$ListBuild(ns)
		}
	}
	If verbose {
		If reposOnly {
			Write !,"Will attempt to unmap IPM repository settings from: "_ $ListToString(namespaces, ", ")
		} Else {
			Write !,"Will attempt to unmap IPM package, routines, and repository settings from: "_ $ListToString(namespaces, ", ")
		}
	}

	// Gather namespaces where %IPM is mapped into
	Do ..GetMapInfo(.tIsMappedFrom)
	
	Set ptr = 0
	While $ListNext(namespaces, ptr, ns) {
		Set src = $Get(tIsMappedFrom(ns))
		If (src = "") {
			If verbose {
				Write !,"No mapping found for "_ns_". Skipping."
			}
			Continue
		} 

		If verbose {
			Write !,"Unmapping repository settings from "_ns_" (mapped from "_src_")"
		}
		For suffix = "D", "S", "I" {
			$$$ThrowOnError(##class(%IPM.Utils.Module).RemoveGlobalMapping(ns, "IPM.Repo.Definition"_suffix))
		}

		If 'reposOnly {
			If verbose {
				Write !,"Unmapping IPM package and routines from "_ns_" (mapped from "_src_")"
			}
			$$$ThrowOnError(##class(%IPM.Utils.Module).RemovePackageMapping(ns, "%IPM"))
			$$$ThrowOnError(##class(%IPM.Utils.Module).RemoveRoutineMapping(ns, "%IPM.*"))
		}
	}
}

/// Get the mapping relationship for %IPM package. Format: 
/// <ul>
/// <li>pIsMappedFrom(destinationNamespace) = sourceNamespace</li>
/// <li>pIsMappedTo(sourceNamespace, destinationNamespace) = ""</li>
/// </ul>
ClassMethod GetMapInfo(Output pIsMappedFrom, Output pIsMappedTo)
{
	Kill pIsMappedFrom, pIsMappedTo 
	Do ..GetListModules("*", $$$IPMModuleName, .list)	
	Do ..AddIPMMappedNamespaces(.list)
	For i = 1:1:list {
		Set destNS = $ListGet(list(i))
		If $Data(list(i,  "modules", 1, "Installed In"), srcNS) # 2 {
			Set pIsMappedFrom(destNS) = srcNS
			Set pIsMappedTo(srcNS, destNS) = ""
		}
	}
}

ClassMethod IPMInstalled(ByRef ipmModuleId) As %Boolean [ CodeMode = expression ]
{
$$$comClassDefined("%IPM.Storage.Module") && ##class(%IPM.Storage.Module).NameExists($$$IPMModuleName, .ipmModuleId)
}

/// Runs package manager commands in a way that is friendly to the OS-level shell.
/// Creates <var>pOutputLogFile</var> if it does not exist.
/// If it does, and <var>pAppendToLog</var> is true, appends to it; otherwise, deletes the file before outputting to it.
ClassMethod ShellScript(pCommand As %String, pOutputLogFile As %String = "", pAppendToLog As %Boolean = 0)
{
	Set tSC = $$$OK
	Set tFileOpen = 0
	Try {
		If (pOutputLogFile '= "") {
			// Append to pOutputLogFile if it exists and pAppendToLog is true.
			Set tParams = "WS"_$Select(
				'##class(%Library.File).Exists(pOutputLogFile):"N",
				pAppendToLog:"A",
				1:"N")
			Open pOutputLogFile:tParams:1
			If '$Test {
				Set tSC = $$$ERROR($$$FileNotOpen,pOutputLogFile)
				$$$ThrowStatus(tSC)
			}
			Set tFileOpen = 1
			Use pOutputLogFile
		}
		Write !!,">>",pCommand,!
		Set tSC = ..Shell(pCommand)
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
		Do e.Log()
	}
	
	Write !
	If tFileOpen {
		Close pOutputLogFile
	}
	
	If $$$ISERR(tSC) {
		// Set ERRORLEVEL to 1
		Do $System.Process.Terminate(,1)
	}
}

ClassMethod DisplayModules(ByRef pList, pNumbered As %Boolean = 0, pWithNamespace As %Boolean = 0, pIndent As %Integer = 0, ByRef pModifiers)
{
  If '$Data(pList) {
    Quit
  }
  Set pWithNamespace = pWithNamespace || $Data(pList("ns"))
  If pWithNamespace {
    Set nsWidth = $Get(pList("width")) + 2
    Set numbersWidth = $Select(pNumbered: $Length(pList) + 3, 1: 0)
    Set modulesWidth = 0
    For i=1:1:pList {
      If $Data(pList(i, "modules", "width"), width), width > modulesWidth {
        Set modulesWidth = width
      }
    }

    For i=1:1:pList {
      Set $ListBuild(tNS) = pList(i)
      Write !
      If pNumbered {
        Write $Justify(i, numbersWidth - 2), ". "
      }
      Write $$$FormattedLinePadRight($$$Magenta, tNS _ "> ", nsWidth)
      Set tPrefix = $Justify("", numbersWidth) _ tNS 
      Kill tModulesList 
      Merge tModulesList = pList(i, "modules")
      Set tModulesList("width") = modulesWidth
      Do ..DisplayModules(.tModulesList, 0, 0, $X)
    }
    Quit
  }

  Set extraColumns = $ListBuild(
    $ListBuild("Description", $$$Yellow),
    $ListBuild("Root", $$$Magenta),
    $ListBuild("Author.CopyrightDate", $$$Yellow, "CopyrightDate"),
    $ListBuild("Author.License", $$$Yellow, "License"),
    $ListBuild("Author.Notes", $$$Yellow, "Notes"),
    $ListBuild("Author.Organization", $$$Yellow, "Organization"),
    $ListBuild("Author.Person", $$$Yellow, "Author"),
    $ListBuild("Origin", $$$Blue),
    $ListBuild("AllVersions", $$$Blue, "Versions"),
    $ListBuild("Repository", $$$Blue),
    $ListBuild("Installed In", $$$Blue)
  )

  Set width = $Get(pList("width")) + 1
  Set tIndent = pIndent
  Set tIndent = $Select(pIndent > 0: pIndent, 1: width)
  For i=1:1:pList {
    Set info = pList(i)
    Set developerMode = 0
    Set root = ""
    Set $ListBuild(name, version, externalName, developerMode, root) = info
    Write:i>1 !,?pIndent
    Write $$$FormattedLinePadRight($$$Green, name, width), $$$FormattedLine($$$Blue, version)
    If $Get(developerMode) {
      Write " ", $$$FormattedLine($$$Red, "(DeveloperMode)")
    }
    If $Data(pModifiers("showsource")) {
      Write " ", $$$FormattedLine($$$Magenta, root)
    }

    Set ptr = 0 
    While $ListNext(extraColumns, ptr, column) {
      Continue:$Get(column)=""
      Set colName = ""
      Set $ListBuild(colValue, color, colName) = column
      Set colName = $Select($Get(colName)'="": colName, 1: colValue)
      If $Data(pList(i, colValue), value), value'="" {
        Write !,?tIndent
        Do ..DrawColumn($$$FormattedLine(color, colName _ ": ") _ value)
      }
    }
  }
}

}
