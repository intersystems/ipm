Include (%syGluedef, %sySecurity, %syPrompt, %ZPM.PackageManager.Common, %ZPM.Formatting)

IncludeGenerator %ZPM.PackageManager.Common

Class %ZPM.Main Extends %ZPM.CLI
{

Parameter DOMAIN = "ZPM";

Parameter STANDARDPHASES = {$Listbuild("reload","compile","test","package","verify","publish")};

/// Description of commands to use for this CLI
XData Commands [ XMLNamespace = "http://www.intersystems.com/PackageManager/CLI" ]
{
<?xml version="1.0"?>
<commands>
<command name="help" aliases="?">
<description>Displays help information for the shell or a particular command</description>
<modifier name="verbose" aliases="v" description="Show full detail" />
<modifier name="markdown" aliases="m" description="Print detail in markdown format (for easy transfer to external documentation)" />
<parameter name="command" description="Command for which help information should be displayed" />
</command>

<command name="quit" aliases="q,exit">
<description>Exits the package manager shell</description>
</command>

<command name="module-action" default="true" dataPrefix="D" trailingModifiers="true">
<description>
Performs operations on modules - compiling, running tests, packaging/registering, etc.
You can use this by starting a command with the module name.
Note that flags appear *after* all actions.

The standard lifecycle phases are:
* clean: removes all dependencies that are not required by other installed modules and their resources. Dependencies required by other modules will also be removed if the -DClean.Force=1 flag is specified.
* reload: pulls module source code into the namespace from disk. Does not compile.
* validate: ensures that module resource processor attributes are valid, and that the resources exported to the filesystem (and possible to source control) are consistent with what is in the database.
* compile: compiles all resources within the module.
* activate: performs post-compilation installation/configuration steps.
* document: regenerates the API documentation for the module
* test: runs any unit tests associated with the module, in the current namespace.
* package: exports the module's resources and bundles them into a module artifact (.tgz file).
* verify: installs that artifact in a separate namespace, then runs integration tests (if any).
* register: saves that artifact into the current namespace's module cache. This is accessible to other instances configured to look at the current namespace as a module repository.
* publish: saves that artifact to the repository for which deployment is enabled. Currently, there may only be one of these per namespace.
</description>
<example description="Compiles the module named &quot;MyModuleName&quot;">module-action MyModuleName compile</example>
<example description="Performs multiple actions on the module named &quot;MyModuleName&quot;; &quot;clean&quot; deletes all of its dependenices, and &quot;install&quot; will then re-download them, package the module, and register it in the current namespace's module cache.">MyModuleName clean register</example>
<example description="Compiles the module named MyUIModule with verbose output and pParams(&quot;UIFW&quot;,&quot;force&quot;) (passed to all lifecycle phases) set to 42.">MyUIModule compile -v -DUIFW.force=42</example>
<parameter name="module" required="true" description="Name of module on which to perform lifecycle actions" />
<parameter name="actions" required="true" description="Space-delimited list of module lifecycle phases to run" trailing="true" />
<modifier name="only" aliases="o" description="Only runs the specified phase(s), rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
</command>

<command name="init" aliases="initialize">
<description>Configures new namespace for use of package manager (interactive). This sets up the local cache and allows for configuration of studio extensions for source control and the package manager itself. In the case of Perforce-based source control, prompts are included for username, password, Perforce workspace, and a few other settings.</description>
<modifier name="noprompt" aliases="quiet,q" description="If specified, no prompts will be shown." />
<modifier name="zpm" aliases="cli" description="If specified, the zpm command will be configured." />
<modifier name="extension" aliases="ext" value="true" description="Studio extension to configure for the current namespace (in addition to the Package Manager extension - e.g., for source control)" />
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

<command name="test">
<description>
This command is an alias for `module-action module-name test`
</description>
<parameter name="module" required="true" description="Name of module on which to perform test action" />
<modifier name="only" aliases="o" description="Only runs the specified phase (test),rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
</command>

<command name="package">
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

<command name="verify">
<description>
This command is an alias for `module-action module-name verify`
</description>
<parameter name="module" required="true" description="Name of module on which to perform verify action" />
<modifier name="only" aliases="o" description="Only runs the specified phase (verify), rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
</command>

<command name="publish">
<description>
This command is an alias for `module-action module-name publish`
</description>
<parameter name="module" required="true" description="Name of module on which to perform publish actions" />
<modifier name="only" aliases="o" description="Only runs the specified phase (publish), rather than also running predecessors." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
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
<description>Configures the current namespace to search for modules on a remote server or on the local filesystem.</description>
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

<!-- Universal Actions -->
<modifier name="delete-all" description="Deletes all repositories (possibly subject to a type filter: -f, -r, ...)" />
<modifier name="list" description="Lists all repositories (possibly subject to a type filter: -f, -r, ...)" />
<modifier name="list-modules" aliases="modules,listmodules" description="List modules available in the specified repository (-n\[ame]), or in all configured repositories if no repository was specified." />

<!-- General/shared modifiers -->
<modifier name="name" aliases="n" value="true" description="Namespace-unique name for the module" />
<modifier name="delete" description="Deletes the current namespace's reference to the named repository" />
<modifier name="publish" value="true" valueList="0,1" description="When configuring a remote repository, specifies that publishing of packages to the repository is allowed. When configuring the current namespace with -enable, specifies that publishing is also enabled. "/>

<!-- General properties -->
<modifier name="snapshots" aliases="s" value="true" valueList="0,1" description="For any repository, specifies that it should be used to look for snapshot builds (i.e., those with a semantic version ending in '+snapshot', indicating a 'latest' build of a particular version)." />
<modifier name="prereleases" aliases="pre" value="true" valueList="0,1" description="For any repository, specifies that it should be used to look for prerelease software" />
<modifier name="read-only" aliases="ro" value="true" valueList="0,1" description="For any repository, specifies that modules installed from it are ALWAYS installed in non-developer mode, effectively making them read only" />

<modifier name="type" value="true" aliases="t" description="Subclass of %ZPM.Repo.Definition to create/modify/delete or implementation of %ZPM.Repo.IPackageService or %ZPM.Repo.IPublishService to enable/disable" />

</command>

<command name="load" dataPrefix="D">
<description>Loads a module from the specified directory or archive into the current namespace. Dependencies are also loaded automatically, provided that they can be found in repositories configured with the 'repo' command.</description>
<example description="Loads the module described in C:\module\root\path\module.xml">
load C:\module\root\path\
load C:\module\root\path\module-0.0.1.tgz
</example>
<example description="Loads the module described in C:\module\root\path\module.xml in developer mode and with verbose output.">
load -dev -verbose C:\module\root\path\
load -dev -verbose C:\module\root\path\module-0.0.1.tgz
</example>
<modifier name="branch" aliases="b" dataAlias="Branch" value="true" description="The name of the branch in the repository" />
<example description="Loads the module described in C:\module\root\path\module.xml in developer mode and with verbose output.">
load https://github.com/user/repository.git
load https://github.com/user/repository.git -b branch-name
</example>
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<parameter name="path" required="true" description="Directory on the local filesystem, containing a file named module.xml" />
</command>

<command name="import">
<description>Imports classes from a file or file(s), reexporting to source control if needed.</description>
<example>import C:\Temp\MyExport.xml</example>
<example>import C:\Temp\MyFlatExportDir\ -norecurse -nocompile</example>
<parameter name="source" description="File or directory to import" required="true" />
<modifier name="quiet" aliases="q" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" description="Produces verbose output from the command." />
<modifier name="norecurse" description="If importing a directory, do not recurse (default is to load directories recursively)" />
<modifier name="nocompile" description="Skip compiling imported classes (default is to compile them)" />
</command>

<command name="run-from-file" aliases="run">
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
<parameter name="file" description="File to import" required="true" />
<modifier name="dry-run" aliases="d" description="Does not actually run the commands. Simply displays what would be run." />
</command>

<command name="install" dataPrefix="D">
<description>Installs a module available in a configured repository</description>
<example description="Installs the most recent 1.x version of HS.JSON available in any configured repository in the current namespace.">install HS.JSON 1.x</example>
<parameter name="module" required="true" description="Name of module to install" />
<parameter name="version" description="Version (or version expression) of module to install; defaults to the latest available if unspecified." />
<modifier name="prompt" aliases="p" description="Prompts user which version to install, if more then one found." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="keywords" aliases="k" value="true" description="Searches for modules matching some set of keywords." />
</command>

<command name="reinstall" dataPrefix="D">
<description>Reinstalls an already-installed module from the latest version available in a configured repository. By default, updates dependencies of that module as well.</description>
<example description="Reinstalls the currently-installed version of the ZHSLIB module, in development mode">reinstall -dev ZHSLIB</example>
<parameter name="module" required="true" description="Name of module to reinstall" />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="shallow" aliases="s" dataAlias="UpdateSnapshots" dataValue="0" description="Suppresses updating of dependencies with '+snapshot' versions." />
</command>

<command name="uninstall" dataPrefix="D">
<description>Uninstalls a module currently installed locally. This will be prevented if other modules depend on the named module, unless the -force flag is specified.</description>
<example description="Uninstalls HS.JSON from the current namespace.">uninstall HS.JSON</example>
<modifier name="all" aliases="a" description="Uninstalls all modules installed in the current namespace." />
<modifier name="global" aliases="g" dataAlias="Clean.GlobalScope" dataValue="1" description="Also uninstalls modules with 'global scope' (available in all namespaces); by default, these are skipped." />
<modifier name="force" aliases="f" description="If specified, the module will be uninstalled even if other modules depend on it." />
<modifier name="recurse" aliases="r" description="Also recursively uninstall dependencies. By default, will not uninstall dependencies that are also required by other installed modules; the -force flag overrides this." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="purge" dataAlias="Purge" dataValue="1" description="Purge data from tables during uninstall." />
<parameter name="module" required="true" description="Name of module to uninstall" />
</command>

<command name="clear-cache">
<description>Clears the cache of artifacts downloaded for installation in the current namespace. (As an optimization, downloaded module/application artifacts are stored in the database for local retrieval later.)</description>
</command>

<command name="cos">
<description>Executes ObjectScript</description>
<example>cos set $Namespace = "MYAPP"</example>
<parameter name="cos" required="true" trailing="true" description="ObjectScript command(s) to execute" />
</command>

<command name="orphans">
<description>Lists resources in the current namespace's default code database that are not part of any module.</description>
<example>orphans -type CLS</example>
<modifier name="type" aliases="t" value="true" description="Type (e.g., extension) of resource to show; if unspecified, all types are included." />
</command>

<command name="list-installed" aliases="list">
<description>Lists modules installed in the current namespace</description>
<example description="Shows all installed modules in tree format.">list-installed -tree</example>
<modifier name="tree" aliases="t" description="If specified, show dependency tree for installed modules." />
<modifier name="description" aliases="d" dataAlias="Desc" dataValue="1" description="Additional information is displayed for each module." />
</command>

<command name="list-dependents" aliases="dependents">
<description>Lists modules dependent on the specified module</description>
<example description="Lists all currently-installed modules dependent on the currently-installed 'HS.JSON' version">list-dependents HS.JSON</example>
<example description="Lists all modules in the 'AppModules' repository dependent on all 'HS.JSON' versions.">list-dependents -repos AppModules HS.JSON</example>
<example description="Lists all modules in the 'AppModules' repository dependent on 'HS.JSON' version '0.0.1+snapshot', as a tree.">dependents -t -r AppModules HS.JSON 0.0.1+snapshot</example>
<modifier name="tree" aliases="t" description="If specified, show as a tree (rather than a flattened list)" />
<modifier name="repos" aliases="r" value="true" description="Comma-separated list of repository names to search in. If unspecified, the version of the module in the current namespace will be used instead." />
<parameter name="module" required="true" description="Name of module for which dependent modules will be found" />
<parameter name="version" description="Version of the module for which dependent modules will be found (in all configured repositories)" />
</command>

<command name="default-modifiers" dataPrefix="D">
<description>Sets default modifiers to use for all package manager commands in the current namespace.</description>
<modifier name="set" description="Set the default modifiers to the provided modifiers. Note: this just appends to existing modifiers. DOES NOT delete any defaults." />
<modifier name="get" description="Prints the default modifiers to the current device." />
<modifier name="delete" description="Deletes all registered default modifiers." />
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
<description>Rearranges the resources in a module manifest to follow the standard format</description>
<modifier name="all" description="If specified, rearrange all modules loaded in development mode (rather than just the current one)." />
<parameter name="module" description="Name of module to rearrange" />
</command>

<command name="version" aliases="ver">
<description>Prints the currently-installed package manager and registry version (excluding +snapshot or other build information)</description>
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
<parameter name="searchString" description="Search string, * can be used" />
<example description="Shows a description of all modules in the name of which there is a context">find -d *tools*</example>
</command>

<command name="namespace" aliases="zn"> 
<description>See list modules in namespace and go to the namespace</description>
<example description="Show all modules in all namespaces">zn *</example>
<example description="Show all modules in namespaces by context">zn sql*</example>
<parameter name="name" description="Name namespace, * or context name*" />
</command>
</commands>
}

ClassMethod %GetCommandStructure(Output pCommandStructure)
{
  Do ..%GetOneCommandStructure(.pCommandStructure)

  Do ##class(%ZPM.Repo.Definition).%GetCommandStructure(.tCommandStructure)
  Merge pCommandStructure("repo") = tCommandStructure("repo")
}

/// @API.Method
ClassMethod Shell(pCommand As %String, pTerminateOnError As %Boolean = 0, pHaltOnComplete As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Do ..ShellInternal(.pCommand,.tException)
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
	set tp=##class(%SYSTEM.Process).TerminalPrompt()
	set prompt="zpm:"
	set del=$$$FormattedLine(..TerminalPromptColor(),">")
	if ..TerminalPromptColor()=$$$Default set tp=2
	for i=1:1:$l(tp,",") {
		if $p(tp,",",i)=1 {	set prompt=prompt_$p($system,":")_del continue}
		elseif $p(tp,",",i)=2 {	set prompt=prompt_$namespace_del continue}
		elseif $p(tp,",",i)=3 {	set prompt=prompt_$p($system,":",2)_del continue}
		elseif $p(tp,",",i)=4 {	set prompt=prompt_$zt(+$p($h,",",2),1)_del continue}
		elseif $p(tp,",",i)=5 {	set prompt=prompt_$job_del continue}
        elseif $p(tp,",",i)=8,$tl { set prompt=prompt_"TL"_$tl_del continue}
        ;for zpm shell 7 do not need to be implemented	
    }
	quit prompt
}

/// For use in unit tests that need to test if a command threw any exceptions.
ClassMethod ShellInternal(pCommand As %String, Output pException As %Exception.AbstractException) [ Internal ]
{
	Set pException = $$$NULLOREF
	Set tOneCommand = 0
	Set tCommand = $Get(pCommand)
	If (tCommand '= "") {
		Set tOneCommand = 1
	}
	Set introMessageList = $ListBuild(
		"Welcome to the Package Manager Shell (ZPM).",
		"Enter q/quit to exit the shell. Enter ?/help to view available commands"
	)
	Set tInShell = 0
	For {
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
				#; Do ..InTranStart(.tCommandInfo,.tTLev)
				Do ..Load(.tCommandInfo)
			} ElseIf (tCommandInfo = "cos") {
				Write !
				Xecute tCommandInfo("parameters","cos")
			} ElseIf (tCommandInfo = "install") {
				#; Do ..InTranStart(.tCommandInfo,.tTLev)
				Do ..Install(.tCommandInfo)
			} ElseIf (tCommandInfo = "reinstall") {
        #; Do ..InTranStart(.tCommandInfo,.tTLev)
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
			} ElseIf (tCommandInfo = "config") {
				Do ..Config(.tCommandInfo)
			} ElseIf ($Listfind(..#STANDARDPHASES,tCommandInfo)) {
				#; if (tCommandInfo="publish") Do ..InTranStart(.tCommandInfo,.tTLev)
				Do ..RunOnePhase(.tCommandInfo)
			} ElseIf (tCommandInfo = "generate") {
				Do ..GenerateModuleXML(.tCommandInfo)
			} ElseIf (tCommandInfo = "module-action") {
				Do ..ModuleAction(.tCommandInfo)
			} ElseIf (tCommandInfo = "version") {
				Do ..Version(.tCommandInfo)
			} ElseIf (tCommandInfo = "namespace") {
				Do ..Namespace(.tCommandInfo)			}
			} Catch pException {
				#; if $TLevel>$GET(tTLev) TROLLBACK 1  write:$GET(tCommandInfo("data","Verbose")) !,"Rollback a transaction",!
				#dim e As %Exception.AbstractException
				If (pException.Code = $$$ERCTRLC) {
					Set pException = $$$NULLOREF
					Return
				}
        Do ..DisplayError(pException.AsStatus())
			}
		#; if $TLevel>$GET(tTLev) TCOMMIT  write:$GET(tCommandInfo("data","Verbose")) !,"Completing a transaction",!
		Set tCommand = ""
		Quit:tOneCommand
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

/// In Transaction 
ClassMethod InTranStart(ByRef pCommandInfo, ByRef tTLev) [ Internal ]
{
	Set name = $Get(pCommandInfo("parameters","module"))
	Set tVerbose = $GET(pCommandInfo("data","Verbose"))
	if name'="",name'="zpm" set tTLev=$TLevel  TSTART  write:tVerbose !,"Opening a transaction",!
	quit $$$OK
}

/// Show modules in Namespace and to go namespace
ClassMethod Namespace(ByRef pCommandInfo) [ Internal ]
{
	Set currentns=$Namespace
	Set name = $Translate($Get(pCommandInfo("parameters","name")),$c(34))
	Set tDesc=$Get(pCommandInfo("data","Desc"))
	If name["*" {
		Do ..GetListNamespace(.namespace)
		Set ns="",num=0
		For { set ns=$Order(namespace(ns)) Quit:ns=""
			Set $Namespace=ns
			Kill list
			If ("@"_ns)[("@"_$Zconvert($tr(name,"*"),"U")) {
				Set num=num+1
					,num(num)=ns
				Do ..GetListModules("",.list)
				If $D(list) {
					Set module="",write=0
					For { set module=$Order(list(module)) Quit:module=""
						Write !
						,$Select('write:num_".",1:$j("",$L(num)+1))
						,(ns)_">"_$j("",namespace-$l(ns_">"))
						," "_$$$FormattedLine($$$Green,module)_$j("",list-$l(module))
						," "_$LG(list(module),1)
						If tDesc {
							Write !?(4+$L(ns_">"_$Justify("",namespace-$Length(ns_">"))))
							Do ..DrawColumn($$$FormattedLine($$$Yellow,"Description: ")_" "_$Listget(list(module),2))
						}
						Set write=1
					}
				} Else {
					Write !
					,num_"."
					,$$$FormattedLine($$$Magenta,ns)_">"_$Justify("",namespace-$Length(ns_">"))
					
				}
			}
		}
		Set $Namespace=currentns
		Do ##class(%Library.Prompt).GetString("Enter number or name where to go: ", .goto)	
		If goto'="" try { Set $Namespace=$Select($D(num(goto)):num(goto),1:goto) } catch e {}
	} Else {
		Set $Namespace=name
	}
}

/// Get list Namespace, example do ##(%ZPM.Main).GetListNamespace(.ns)
ClassMethod GetListNamespace(ByRef namespace)
{
	New $Namespace
	Set $Namespace="%SYS"
	
	Set tQuery = "select Nsp from %SYS.Namespace_List(0,0) where Status = 1"
	Set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery)
	
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Set namespace(tRes.%Get("Nsp"))=""
		Set:$Get(maxlen)<$Length(tRes.%Get("Nsp")) maxlen=$Length(tRes.%Get("Nsp"))
	}
	Set:$Data(namespace) namespace=$G(maxlen)
}

/// draw description
ClassMethod DrawColumn(desc) As %String
{
	Set dx=$x
	For d=1:1:$Length(desc," ") {
 		Set wd=$Piece(desc," ",d) 
		If $x+$l(wd)>80 Write !,?dx
		Write wd," " 
	}
 	Quit ""
}

/// Get List Modules
/// example d ##class(%ZPM.Main).GetListModules("zpm",.list)
ClassMethod GetListModules(StartsWith As %String = "", ByRef pList) [ Internal ]
{
	Set tQuery = "select Name,VersionString,Description,ExternalName from %ZPM_Storage.""MODULE"""
	If StartsWith'="" { Set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery_ " where name %StartsWith ?",StartsWith) }
	Else { Set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery)}
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Set pList(tRes.%Get("Name"))=$lb(tRes.%Get("VersionString"),tRes.%Get("Description"),tRes.%Get("ExternalName"))
		Set:$G(maxlen)<$L(tRes.%Get("Name")) maxlen=$L(tRes.%Get("Name"))
	}
	Set:$D(pList) pList=$G(maxlen)
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

	Set tExp = $$$GetModifier(pCommandInfo,"export")
	If tExp'="" {
		Do ##class(%ZPM.Storage.ModuleTemplate).ExportResources(tPath,tExp)
	}	
	If ($$$HasModifier(pCommandInfo,"template")) {
		Return ##class(%ZPM.Storage.ModuleTemplate).GenerateTemplate(tPath)
	} 
	While (1) {
		Set tHelp(1) = "Enter module name"
		Set tHelp(2) = "Enter "" null string to quit"
		Do ##class(%Library.Prompt).GetString("Enter module name:", .tName, , ,.tHelp)
		Return:(tName="") $$$OK
		If ('##class(%ZPM.Storage.ModuleTemplate).NameIsValid(tName)) {
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
		If ('##class(%ZPM.General.SemanticVersion).IsValid(tVersion)) {
			Write !,"Module version """_tVersion_""" is invalid" 
			Set tVersion=""
			Continue 
		}
		Quit
	}

	Do ##class(%Library.Prompt).GetString("Enter module description:", .tDescription)

	Do ##class(%Library.Prompt).GetString("Enter module keywords:", .tKeywords)	

	Set tTemplate = ##class(%ZPM.Storage.ModuleTemplate).NewTemplate(tPath, tName, tVersion, tDescription, tKeywords)
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
	Do tTemplate.ReadResorces(tSrc)

	// web applications
	Do ##class(%ZPM.Storage.ModuleTemplate).GetCSPApplications(.apps)
	If ($Listlength(apps)>0 ) {
		Write !!,"Existing Web Applications:"
		For i=1:1:$Listlength(apps) {
			Write !,"    "_$Listget(apps,i)
		}
		Do ##class(%Library.Prompt).GetString("    Enter a comma separated list of web applications or * for all:", .tWebAppList)

		Do tTemplate.AddWebApps(tWebAppList,.tCSPapps) // tCSP - list of CSP (not REST apps) 
		For i=1:1:$Listlength(tCSPapps) {
			Set tCSPPath = ""
			Do ##class(%Library.Prompt).GetString("    Enter path to csp files for "_$Listget(tCSPapps,i)_": ", .tCSPPath)
			If (tCSPPath'="") {
				Do tTemplate.SetSourcePathForCSPApp($Listget(tCSPapps,i),tCSPPath)
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
/// example d ##class(%ZPM.Main).GetDefaultCommandRegistry()
ClassMethod GetDefaultCommandRegistry()
{
	New $Namespace
	Set $Namespace="%SYS"
	Set Status=##Class(Config.Startup).Get(.Properties)
	If Status {
		Set ServerPort="http://"_$zu(110)_":"_$Get(Properties("WebServerPort"),52773)
		Write !,"Default commands for the registry"
		Write !,"View all packets in the browser:",!,"  ",ServerPort_"/registry/packages/-/all"
		Write !,"Switch to the current registry:",!,"   repo -r -n registry -url "_ServerPort_"/registry/ -user ""_system"" -pass ""SYS""",!
		
	}
}

/// @API.Method
/// Version client and registry
ClassMethod Version(ByRef pCommandInfo) [ Internal ]
{
	New $Namespace
  	Do ..GetListNamespace(.namespace)
  
	Set $Namespace="%SYS"

	Do ..GetListModules("zpm",.list)
	If $Data(list("zpm")) {
			Write !,($namespace)_"> "_$$$FormattedLine($$$Green,"zpm ")_$ListGet(list("zpm"),1)
	}
	Set ns=""
	For { Set ns=$Order(namespace(ns)) Quit:ns=""
		Kill list
		try {
			Set $namespace=ns
			Do ..GetListModules("zpm",.list)
			If $Data(list("zpm-registry")) {
				Write !,(ns)_"> "_$$$FormattedLine($$$Green,"zpm-registry ")_$ListGet(list("zpm-registry"),1)
				Set Found=ns
				Do ..GetDefaultCommandRegistry()
			}
		} catch {
			// just ignore inaccessible namespaces
		}
	}
	Set $namespace="%SYS"
	If '$Data(Found) Write !," Locally installed zpm-registry not found" 
	
	// Get URL current registry
	Set tRes = ##class(%ZPM.Repo.Remote.Definition).ExtentFunc()
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)

		#dim tRepository As %ZPM.Repo.Remote.Definition
		Set tRepository = ##class(%ZPM.Repo.Remote.Definition).%OpenId(tRes.ID,,.tSC)
		$$$ThrowOnError(tSC)
		Set tService = tRepository.GetPackageService()
		Set tInfo = tService.GetInfo()
		Write !,$$$FormattedLine($$$Blue,tRepository.URL)," - ",tInfo.version
	}
	q $$$OK
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
	
	// Local artifact cache
	$$$ThrowOnError(##class(%ZPM.Repo.Utils).InitializeLocalCache(.tCreated))
	If (tCreated) {
		Write !,"Initialized local cache."
	} Else {
		Write !,"Local cache already exists."
	}
	
	// Reindex tables with semantic version indices
	For tClass = "%ZPM.Repo.Filesystem.Cache" {
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
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,"call %ZPM_General.IConfigurable_ListSettings()")
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
		Set tHelp = "The 'ZPM' command allows quick command line access to many features of the package manager. Extensive documentation is available via:"_$c(13,10,9)_" zpm ""help""."
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
	Set tCompositeSCClass = "%ZPM.PackageManager.Developer.Extension.Composite"
	Set tPackageMgrSCClass = "%ZPM.PackageManager.Developer.Extension.PackageManager"
	Set tSCInterface = "%ZPM.PackageManager.Developer.Extension.SourceControl.Interface"
	Set tOldSourceControlClass = ##class(%Studio.SourceControl.Interface).SourceControlClassGet()
	
	If (tOldSourceControlClass '= "") && '$$$comClassDefined(tOldSourceControlClass) {
		Write !,"Source control class ",tOldSourceControlClass," does not exist - disabling it."
		$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet())
		Set tOldSourceControlClass = ""
	}
	
	If (tOldSourceControlClass '= "") && (tOldSourceControlClass '= tCompositeSCClass) && (tOldSourceControlClass '= tPackageMgrSCClass) {
		Write !,"Enabling package manager extension... "
		$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Extension.Composite).SetExtensionClasses(tOldSourceControlClass,$ListBuild(tPackageMgrSCClass)))
		Write "done."
		Set tOldSourceControlClass = tCompositeSCClass
	}
	
	If (tOldSourceControlClass = "") {
		Write !,"No Studio extension is currently configured for this namespace."
	} ElseIf (tOldSourceControlClass = tCompositeSCClass) {
		Set tPrimaryClass = ##class(%ZPM.PackageManager.Developer.Extension.Composite).GetPrimaryExtensionClass()
		Set tExtensionClasses = ##class(%ZPM.PackageManager.Developer.Extension.Composite).GetSubExtensionClasses()
		Write !,"Currently configured to use the following extension classes: "
		Set tPtr = 0
		While $ListNext(tExtensionClasses,tPtr,tClass) {
			Write !,$c(9),tClass,$Case(tClass,tPrimaryClass:" (primary)",:"")
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
			Set tHelp = "Note: only subclasses of %ZPM.PackageManager.Developer.Extension.SourceControl.Interface are listed."
			Set tResponse = ##class(%Library.Prompt).GetArray("Which class?",.tValue,$ListBuild($classname()_":SourceControlClasses"),,,.tHelp,$$$InitialDisplayMask)
			If (tResponse '= $$$SuccessResponse) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
			}
		}
		
		If (tValue = "") {
			$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(tPackageMgrSCClass))
			Write !,!,"Removed source control class. Package manager extension still enabled."
		} Else {
			Write !,!,"Setting ",tValue," as the source control class for this namespace..."
			// Just configure the package manager source control class. (Gaining the "Package Manager" menu.)
			$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(tCompositeSCClass))
			Set tSecondaryExtension = $ListBuild("%ZPM.PackageManager.Developer.Extension.PackageManager")
			$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Extension.Composite).SetExtensionClasses(tValue,tSecondaryExtension))
			Write " done."
			
			// To see if it changed, compare to primary class (if found earlier) or old source control class (if we weren't combining extensions before)
			If (tValue '= tPrimaryClass) {
				Set tSCClassChanged = 1
			}
		}
	} ElseIf (tOldSourceControlClass = "") {
		// Just configure the package manager source control class. (Gaining the "Package Manager" menu.)
		$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(tPackageMgrSCClass))
		Write !,!,"Enabled package manager extension."
	}
	
	// If we're not just using the package manager, check for configuration method on primary source control class
	// (by seeing if it implements the additional package manager source control interface)
	If (##class(%Studio.SourceControl.Interface).SourceControlClassGet() = tCompositeSCClass) {
		// Default to having the user configure the extension after changing it.
		Set tResult = tSCClassChanged
		Set tPrimaryClass = ##class(%ZPM.PackageManager.Developer.Extension.Composite).GetPrimaryExtensionClass()
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
	Set tDesc= $Get(pCommandInfo("data","Description"),0)
	Set tSearchString = $Get(pCommandInfo("parameters","searchString"),"")
	Set tName = $$$GetModifier(pCommandInfo,"name")
	If (tName '= "") {
		Do ..ShowModulesForRepository(tName, tRepo, tDesc, tSearchString)
	} Else {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select Name, Details from %ZPM_Repo.Definition")
		If (tRes.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
		}
		While tRes.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			If ($I(tCount) > 1) {
				Write !!
			}
			Write tRes.%Get("Name")," ", tRes.%Get("Details"),":"
			Do ..ShowModulesForRepository(tRes.%Get("Name"), tRepo, tDesc, tSearchString)
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
		Do ##class(%ZPM.Repo.UniversalSettings).PrintList()
	} ElseIf (action="set") {
		If ( (key = "") || (value="") ) {
			Write "Key and Value required. Use config set <key> <value>",!
			Quit
		} 
		Do ##class(%ZPM.Repo.UniversalSettings).UpdateOne(key,value)
	} ElseIf (action="get") {
		If (key = "") {
			Do ##class(%ZPM.Repo.UniversalSettings).PrintList()
		} Else {
			Do ##class(%ZPM.Repo.UniversalSettings).PrintOne(key)
		}
	} ElseIf (action="delete") {
		If (key = "") {
			Write "Key required. Use config delete <key>",!
			Quit
		}
		Do ##class(%ZPM.Repo.UniversalSettings).ResetToDefault(key)
	}
}

ClassMethod Repository(ByRef pCommandInfo) [ Internal ]
{
  Do ##class(%ZPM.Repo.Definition).CollectServerTypes(.types)

  Set tType = $$$GetModifier(pCommandInfo, "type")

  Set serverClassList = ""
  Set t = ""
  For {
    Set t = $order(types(t), 1, className)
    Quit:(t = "")
    If ('($$$HasModifier(pCommandInfo, t)) && (t '= tType)) {
      Kill types(t)
    } 
    ElseIf '$Listfind(serverClassList, className) {
      Set serverClassList = serverClassList _ $ListBuild(className)
    }
  }

	If $$$HasModifier(pCommandInfo,"list") && '$$$HasModifier(pCommandInfo,"list-modules") {
		Set tUseFilter = $Data(types)\10
    Set tRes = ##class(%ZPM.Repo.Definition).ListFunc()
    $$$ThrowSQLIfError(tRes.%SQLCODE,tRes.%Message)
		Set tDisplayCount = 0
		Write !
    While tRes.%Next(.tSC) {
			$$$ThrowOnError(tSC)

			Set tRepository = ##class(%ZPM.Repo.Definition).ServerDefinitionKeyOpen(tRes.%Get("Name"),,.tSC)
			$$$ThrowOnError(tSC)
			If serverClassList = "" || ($ListFind(serverClassList, $Classname(tRepository))) {
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
	} ElseIf $$$HasModifier(pCommandInfo,"list-modules") {
    Do ..Search(.pCommandInfo)
		Quit
	} ElseIf $$$HasModifier(pCommandInfo,"delete-all") {
    If (serverClassList = "") {
			$$$ThrowOnError(##class(%ZPM.Repo.Definition).%DeleteExtent())
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
		If '##class(%ZPM.Repo.Definition).ServerDefinitionKeyExists(repoName) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Repository "_$$$QUOTE(repoName)_" does not exist so cannot be deleted."))
		}
		$$$ThrowOnError(##class(%ZPM.Repo.Definition).ServerDefinitionKeyDelete(repoName))
  } Elseif $$$HasModifier(pCommandInfo,"reset-defaults") {
    Merge tModifiers = pCommandInfo("modifiers")
    Set tName = $$$GetModifier(pCommandInfo,"name")
    If (tName = "") {
      Set tName = "registry"
      Set tModifiers("name") = tName
    }
    Set tModifiers("remote") = ""

    Set tModifiers("url") = ##class(%ZPM.Repo.UniversalSettings).GetDefaultRegistry()
    If (tModifiers("url")="") {
        Write "Error retrieving default registry URL"
        Quit
    }
    Set tModifiers("username") = "", tModifiers("password") = ""
    Set tType = "%ZPM.Repo.Remote.Definition"
    $$$ThrowOnError($ClassMethod(tType,"Configure",1,.tModifiers,.tData))
	} Else {
		Set tName = $$$GetModifier(pCommandInfo,"name")
		Set tType = $ListGet(serverClassList)
		
		#dim tRepoTypeResult As %SQL.StatementResult
		Set tStatement = ##class(%SQL.Statement).%New()
		Set tSC = tStatement.%PrepareClassQuery("%ZPM.Repo.Definition","Catalog")
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
		
		Set tBaseClass = "%ZPM.Repo.Definition"
		If '$ClassMethod(tType,"%Extends",tBaseClass) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid type '%1' - must extend %2",tType,tBaseClass))
		}
		
		Merge tModifiers = pCommandInfo("modifiers")
		Merge tData = pCommandInfo("data")
		$$$ThrowOnError($ClassMethod(tType,"Configure",1,.tModifiers,.tData,tType))
	}
}

ClassMethod ShowModulesForRepository(pRepoName As %String, pShowRepo As %Boolean = 0, pShowDesc As %Boolean = 0, pSearchString As %String = "") [ Private ]
{
	#define gn "^||tmpDesc"
	Kill @$$$gn
	Set maxlenname = 0, where = ""
	If pSearchString["*" {
		Set where=" WHERE name like ?"
	} Elseif pSearchString'="" { 
		Set where=" WHERE name = ?"
	}
	Set tQuery = "SELECT Name,Version,Repository,Description FROM %ZPM_Utils.Module_GetModuleList(?) "_where
	If (pSearchString = "") {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery,pRepoName)
	} Else {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery,pRepoName, $Replace(pSearchString,"*","%"))
	}
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Set name = tRes.%Get("Name")
		Set:($Length(name)>maxlenname) maxlenname = $Length(name)
		Set @$$$gn@(name)=$Listbuild(tRes.%Get("Version"),tRes.%Get("Repository"),tRes.%Get("Description"))
	}
	Set name=""
	For { 
		Set name = $Order(@$$$gn@(name)) 
		Quit:name=""
		Write !,$$$FormattedLine($$$Green,name)
		Write ?(maxlenname+1), $Listget(@$$$gn@(name),1)
		If ( ($Listget(@$$$gn@(name),3)'="") && (pShowDesc=1) ) {
			Write ?(maxlenname+7),..DrawColumn($$$FormattedLine($$$Yellow,"Description: ")_$Listget(@$$$gn@(name),3))
		}
		If ( ($Listget(@$$$gn@(name),3)'="") && ($Listget(@$$$gn@(name),2)'="") && (pShowDesc=1) && (pShowRepo=1) ) {
			Write !
		}
		If ( ($Listget(@$$$gn@(name),2)'="") && (pShowRepo=1) ) {
			Write ?(maxlenname+7),$$$FormattedLine($$$Blue,"Repository: "_$Listget(@$$$gn@(name),2))
		}	
	}
}

Query SourceControlClasses() As %SQLQuery(ROWSPEC = "ID:%String,Name:%String") [ SqlProc ]
{
	select Name as "ID",Name from %Dictionary.ClassDefinition_SubclassOf('%ZPM.PackageManager.Developer.Extension.SourceControl.Interface')
}

ClassMethod LoadFromRepo(tDirectoryName, ByRef tParams) [ Internal ]
{
	set slash=$s($zversion(1)=3:"/",1:"\")
	set TempDir = ##class(%File).GetDirectory(##class(%File).GetDirectory($zu(86))_"mgr"_slash_"Temp"_slash_$tr($zts,".,")_slash)
	$$$ThrowOnError(##class(%File).CreateDirectoryChain(TempDir))
	set:$Extract(tDirectoryName,*)="/" tDirectoryName=$Extract(tDirectoryName,1,*-1)
	set RepoName=$p($p($p(tDirectoryName,"/",*),".git")," ")
	set tCmd="cd "_TempDir_" && git clone "_tDirectoryName
	if $Get(tParams("zpm","Branch"))'="" set tCmd=tCmd_" -b "_tParams("zpm","Branch")
	$$$ThrowOnError(##class(%ZPM.Utils.Module).RunCommandViaZF(tCmd,.tLog,.tErr))
      	set tDirectoryName = TempDir_slash_RepoName
      	If ($Get(tParams("Verbose"))) {
			write !,"Create tempory directory "_TempDir
			write !,tCmd
        	For i=1:1:$Get(tLog) {
          		Write tLog(i),!
        	}
        	write !,tDirectoryName
      	}
       	For i=1:1:$Get(tErr) {
       		Write tErr(i),!
       	}
		hang 2
		quit tDirectoryName
}

ClassMethod Load(ByRef pCommandInfo) [ Internal ]
{
	Set tDirectoryName = $Get(pCommandInfo("parameters","path"))
	Merge tParams = pCommandInfo("data")
  if $Extract(tDirectoryName,1,4)="http" {
		set tDirectoryName=..LoadFromRepo(tDirectoryName,.tParams)
	}
	If ##class(%File).DirectoryExists(tDirectoryName) {
		$$$ThrowOnError(##class(%ZPM.Utils.Module).LoadNewModule(tDirectoryName,.tParams))
	} ElseIf ##class(%File).Exists(tDirectoryName),$$$lcase($PIECE(tDirectoryName, ".", *)) = "tgz" {
		Set tTargetDirectory = $$$FileTempDirSys
		Set tSC = ##class(%ZPM.General.Archive).Extract(tDirectoryName, tTargetDirectory)
		$$$ThrowOnError(##class(%ZPM.Utils.Module).LoadNewModule(tTargetDirectory, .tParams))
	}
}

ClassMethod Install(ByRef pCommandInfo) [ Internal ]
{
	Set tRegistry = ""
	Set tModuleName = $ZConvert($Get(pCommandInfo("parameters","module")), "L")
	If (tModuleName["/") {
		set $lb(tRegistry, tModuleName) = $lfs(tModuleName, "/")
	}
  if (tModuleName = "") {
    Quit $$$OK
  }
	If tRegistry = "" {
		Set tServer = ##class(%ZPM.Repo.Remote.Definition).DeploymentServerOpen(1,,.tSC)
		If $isobject(tServer) {
			Set tRegistry = tServer.Name
		}
	}

	Set tVersion = $Get(pCommandInfo("parameters","version"))
	Set tKeywords = $$$GetModifier(pCommandInfo,"keywords")
	
	Set tSearchCriteria = ##class(%ZPM.Repo.SearchCriteria).%New()
	Set tSearchCriteria.Registry = tRegistry
	Set tSearchCriteria.Name = tModuleName
	Set tSearchCriteria.VersionExpression = tVersion
	Set tSearchCriteria.Keywords = tKeywords
	$$$ThrowOnError(##class(%ZPM.Repo.Utils).SearchRepositoriesForModule(tSearchCriteria,.tResults))
	
	If (tResults.Count() > 0) {
		Set tResult = ""
		#dim tResult As %ZPM.Storage.QualifiedModuleInfo
		// Results are ordered by semantic version, descending. (So the "latest" version will always be first.)
		If ('$$$HasModifier(pCommandInfo,"prompt") || (tResults.Count() = 1)) && (tKeywords = "") {
			Set tResult = tResults.GetAt(1)
		} ElseIf (tResults.Count() > 0) {
			For i=1:1:tResults.Count() {
				Set tResultInfo = tResults.GetAt(i)
				Set tOptArray(i) = tResultInfo.Name_" "_tResultInfo.VersionString_" @ "_tResultInfo.ServerName
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
			Do ##class(%ZPM.Lifecycle.Base).GetDefaultParameters(.tParams)
			Merge tParams = pCommandInfo("data")
			Set tParams("Install") = 1
			$$$ThrowOnError(##class(%ZPM.Utils.Module).LoadModuleReference(tResult.ServerName,tResult.Name,tResult.VersionString,.tParams))
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
	Set tModule = ##class(%ZPM.Storage.Module).NameOpen(tModuleName,,.tSC)
	If $System.Status.Equals(tSC,$$$ERRORCODE($$$KeyValueNotFoundOpen)) {
		$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Module '%1' is not currently installed.",tModuleName)))
	}
	$$$ThrowOnError(tSC)
	
	Set tVersionString = tModule.Version.ToString()
	Write !,"Reinstalling ",tModuleName," ",tVersionString
	Set pCommandInfo("parameters","version") = tVersionString
	Do ..Install(.pCommandInfo)
}

ClassMethod Uninstall(ByRef pCommandInfo) [ Internal ]
{
  If ($Get(pCommandInfo("parameters","module"))="") {
    Set tCommandInfo("parameters","command") = "uninstall"
    Do ..%Help(.tCommandInfo)
    Quit 
  }
	Merge tParams = pCommandInfo("data")
	Set tForce = $$$HasModifier(pCommandInfo,"force") // Force uninstallation even if things depend on this module
	If $$$HasModifier(pCommandInfo,"all") {
		$$$ThrowOnError(##class(%ZPM.Utils.Module).UninstallAll(tForce,.tParams))
    Return
	} Else {
		Set tModuleName = pCommandInfo("parameters","module")
		Set tRecurse = $$$HasModifier(pCommandInfo,"recurse") // Recursively uninstall unneeded dependencies
		$$$ThrowOnError(##class(%ZPM.Storage.Module).Uninstall(tModuleName,tForce,tRecurse,.tParams))
	}
}

ClassMethod RunOnePhase(ByRef pCommandInfo) [ Internal ]
{
	Set tModName = $Get(pCommandInfo("parameters","module"))
	Set tPhases = $Listbuild($zcvt(pCommandInfo, "w"))
	Set tIsComplete = '$$$HasModifier(pCommandInfo,"only")
	Merge tParams = pCommandInfo("data")
	$$$ThrowOnError(##class(%ZPM.Storage.Module).ExecutePhases(tModName,tPhases,tIsComplete,.tParams))
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
			Set tActualPhases = tActualPhases_$ListBuild($zcvt(tPhase, "w"))
		}
		Merge tParams = pCommandInfo("data")
		$$$ThrowOnError(##class(%ZPM.Storage.Module).ExecutePhases(tModName,tActualPhases,tIsComplete,.tParams))
	} Else {
		If (tModName '= "") && ##class(%ZPM.Storage.Module).NameExists(tModName) {
			// TODO: list phases if a valid module name was specified.
		} Else {
			Do ..%Help()
		}
	}
}

Query ActiveNamespaces() As %SQLQuery(ROWSPEC = "ID:%String,Name:%String") [ SqlProc ]
{
	select Nsp,Nsp from %SYS.Namespace_List(0,0) where Status = 1
}

ClassMethod ListInstalled(ByRef pCommandInfo) [ Private ]
{
	If (''$Data(pCommandInfo("modifiers","tree"))) {
		// Show tree of dependencies as well.
		// Modules that are dependencies for no other are shown at the top level.
		// TODO: deal with cyclic dependencies?
		quit:'..GetListModule(,.tModMap)	
		Set tDepRes = ##class(%SQL.Statement).%ExecDirect(,
			"select ""Module""->Name ModName,Dependencies_Name DepName,Dependencies_VersionString DepVer "_
			"from %ZPM_Storage.Module_Dependencies")
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
		set tDesc=+$g(pCommandInfo("data","Desc"))
		quit:'..GetListModule(,.tModMap,'tDesc)
		Set tMod = ""
		For { Set tMod = $Order(tModMap(tMod),1,tVersion)
			Quit:(tMod="")
			Write !,$$$FormattedLine($$$Green,tMod)," ",tVersion_" "
			If tDesc,$Data(tModMap(tMod,"L"),Lock) {
				Set maxlenname=$L(tMod_" "_tVersion_" ")
				Do ..DrawColumn($$$FormattedLine($$$Yellow,"Description: ")_$ListGet(Lock,2))
				Set au=3 
				For a="Author_CopyrightDate", "Author_License", "Author_Notes", "Author_Organization", "Author_Person" { 
					Set au=au+1
					set audata=$ListGet(Lock,au)
					Write:audata'="" !
					,?(maxlenname)
					,..DrawColumn($$$FormattedLine($$$Magenta,a_": ")_audata)
				}
				Write !
					,?(maxlenname)
					,..DrawColumn($$$FormattedLine($$$Magenta,"Root: ")_$ListGet(Lock,3))
				if $Data(tModMap(tMod,"R"),Rem) {
					write !,$ListGet(Rem,3)
				}
			}
		}
	}
}

/// Get module list in currently namespace
ClassMethod GetListModule(ns = {$namespace}, ByRef Mod, OnlyName = 1) As %Status
{
	new $namespace
	set $namespace=ns
	Set tRes = ##class(%SQL.Statement).%ExecDirect(,
		"select * from %ZPM_Storage.""MODULE""")
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
	set in=""
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Set name=tRes.%Get("Name")
		set in=in_"'"_name_"',"
		set list=$lb(tRes.%Get("VersionString"),tRes.%Get("Description"),tRes.%Get("Root"))
		For a="Author_CopyrightDate", "Author_License", "Author_Notes", "Author_Organization", "Author_Person" {
			Set list=list_$lb(tRes.%Get(a))
		}
		Set Mod(name) = tRes.%Get("VersionString")
		Set:'OnlyName Mod(name,"L") = list
		
	}
	$$$ThrowOnError(tSC)
	quit:in=""||(OnlyName) $$$OK
	set in=$Extract(in,1,*-1)

	Set tQuery = "select Name, Version, Repository, Description from %ZPM_PackageManager_Developer.Utils_GetModuleList('registry') WHERE name in ("_in_")"
	Set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery)
	
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Set Mod(tRes.%Get("Name"),"R")=$Listbuild(tRes.%Get("Version"),tRes.%Get("Description"),tRes.%Get("Repository"))
	}
	quit $$$OK
}

ClassMethod AccumulateTreeRecursive(pModName As %String, ByRef pModMap, ByRef pTree, pLevel As %Integer = 0) [ Private ]
{
	If (pLevel = 0) && $Data(pVisitedMap(pModName)) {
		Quit
	}
	
	Set tParentIndex = $i(pTree)
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
	
	If tTree {
		New %tree
		Set tSC = ##class(%ZPM.Utils.Module).GetDependentsAsTree(.%tree,.tErrorList,tModName,tVersion,tRepos)
		$$$ThrowOnError(tSC)
	} Else {
		Set tSC = ##class(%ZPM.Utils.Module).GetDependentsList(.tList,.tErrorList,tModName,tVersion,tRepos)
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
					Set tNodeIndex = $i(tDependentTree)
			
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
			#dim tItem As %ZPM.Storage.QualifiedModuleInfo
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
			Set $Extract(tFrontPadding,*-2) = $c($zh("2514H"))
		}
		If (tFirstChild '= "") {
			Set $Extract(tFrontPadding,*) = $c($zh("252CH"))
		}
		
		Write tFrontPadding,$$$FormattedLine($$$Green,$p(tValue," ",1))," ",$p(tValue," ",2),!
		
		If (tNextSibling '= "") {
			Set tPadding(tNextSibling) = $Get(tPadding(i))
		}
		If (tFirstChild '= "") {
			Set tModPadding = ""
			If $Get(tPadding(i)) '= "" {
				Set tModPadding = $Extract(tPadding(i),1,*-3)_$Case(tNextSibling,"":" ",:$c($zh("2502H")))_"  "
			}
			Set tPadding(tFirstChild) = $Extract(tModPadding,1,*-1)_$c($zh("251CH"),$zh("2500H"),$zh("2500H"))
		}
	}
}

ClassMethod ListOrphans(ByRef pCommandInfo) [ Private ]
{
	Set tType = $$$GetModifier(pCommandInfo,"type")
	Set tResult = ##class(%ZPM.Utils.Module).OrphanedResourcesFunc($Namespace,tType)
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
				"select Name from %ZPM_Storage.""Module"" where DeveloperMode = 1")
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
			
			Set tModule = ##class(%ZPM.Storage.Module).NameOpen(tModuleName,,.tSC)
			$$$ThrowOnError(tSC)
			Set tSC = ##class(%ZPM.Utils.Module).ExportDocumentForObject(tModule,.tSourceControlOutput)
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
	#def1arg STARTTAGQ " ;Generated by %ZPM.PackageManager: Start"
	#def1arg ENDTAGQ " ;Generated by %ZPM.PackageManager: End"
	#def1arg STARTTAG ##Expression($$$STARTTAGQ)
	#def1arg ENDTAG ##Expression($$$ENDTAGQ)
	Set tRtn = ##class(%Routine).%New(RoutineName)
	If ##class(%Routine).Exists(RoutineName) {
    Set tEnded = 1
    While 'tRtn.AtEnd {
      Set tLine = tRtn.ReadLine()
      If (tLine = $$$STARTTAGQ) {
        // Read through the ending tag.
        While ('tRtn.AtEnd) && (tRtn.ReadLine() '= $$$ENDTAGQ) {}
        
        // Generate the lines.
        Set pFound = 1
        For i=1:1:tGenLines {
          Set tRtnLines($i(tRtnLines)) = tGenLines(i)
        }
      } Else {
        // Before %ZLANGC00 was generated: there's an old version with ZPM defined.
        Set tIsZPM = ($ZConvert($Extract(tLine,1,4),"U") = "ZPM(")
        If tIsZPM {
          Set pFound = 1
          Set tEnded = 0
          Set tRtnLines($i(tRtnLines)) = $$$STARTTAGQ
        }
        If '(tIsZPM || tEnded) {
          If ($ZStrip($Extract(tLine),"*W") '= "") {
            Set tRtnLines($i(tRtnLines)) = $$$ENDTAGQ
            Set tEnded = 1
          }
        }
        Set tRtnLines($i(tRtnLines)) = tLine
      }
    }
    If 'tEnded {
      Set tRtnLines($i(tRtnLines)) = $$$ENDTAGQ
    } ElseIf 'pFound {
      For i=1:1:tGenLines {
        Set tRtnLines($i(tRtnLines)) = tGenLines(i)
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
	#def1arg STARTTAGQ " ;Generated by %ZPM.PackageManager: Start"
	#def1arg ENDTAGQ " ;Generated by %ZPM.PackageManager: End"
	#def1arg STARTTAG ##Expression($$$STARTTAGQ)
	#def1arg ENDTAG ##Expression($$$ENDTAGQ)

	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		TSTART
		// Get routine lines to generate
		Set tOffset = 0
		Set tStarted = 0
		For {
			Set tLineName = "zUpdateLanguageExtensions"_"+"_$i(tOffset)_"^"_$ZName
			Set tExtLine = $Text(@(tLineName))
			If (tExtLine=$$$STARTTAGQ) {
				Set tStarted = 1
			}
			If (tStarted) {
				Set tGenLines($i(tGenLines)) = tExtLine
			}
			Quit:(tExtLine=$$$ENDTAGQ)
			Quit:(tExtLine="")
		}

		If '$Data(tGenLines) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Could not find %ZLANGC00 routine contents in "_$classname()))
		}
		Do ..UpdateLanguageExtensionsOne("%ZLANGC00.MAC", pTestOnly,.pFound,.tGenLines)
		Quit:pTestOnly
		Set i="" 
		For { set i=$Order(tGenLines(i),1,tStr) Quit:i=""
			If tStr[" Do ##class" Set tGenLines(i)=$Replace($Replace(tStr," Quit","")," Do "," Quit ") Quit
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
#; These are the actual contents of %ZLANGC00 (to be added/updated)
$$$STARTTAG
ZPM(pArgs...) Do ##class(%ZPM.Main).Shell(pArgs...) Quit
$$$ENDTAG
#; Need an extra line down here to avoid the end bracket being on the same line as $$$ENDTAG - a comment is just fine.
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

}
