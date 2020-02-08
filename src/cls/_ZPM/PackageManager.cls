Include (%syGluedef, %sySecurity, %syPrompt, %ZPM.PackageManager.Common)

Class %ZPM.PackageManager Extends %ZPM.PackageManager.Developer.CLI
{

Parameter DOMAIN = "ZPM";

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
* validate: ensures that module API section is up to date, that module resource processor attributes are valid, and that the resources exported to the filesystem (and possible to source control) are consistent with what is in the database.
* compile: compiles all resources within the module.
* activate: performs post-compilation installation/configuration steps.
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

<command name="search" aliases="find">
<description>Shows all modules in current registry</description>
<example description="Shows all modules in current registry">search</example>
</command>

<command name="repo" aliases="repository" dataPrefix="D">
<description>Configures the current namespace to search for modules on a remote server or on the local filesystem.</description>
<example description="List all repositories">
repo -list
</example>
<example description="Delete all repositories">
repo -delete-all
</example>
<example description="Create a repository pointing to the filesystem with name LocalFiles, accepting snapshots, looking for files named module.xml up to 2 directories deep in C:\MyWorkspace\RootModuleDir\">
repo -name LocalFiles -snapshots 1 -fs -depth 2 -path C:\MyWorkspace\RootModuleDir\
</example>
<example description="Delete the repository named &quot;LocalFiles&quot;">
repo -n LocalFiles -delete
</example>
<example description="Lists all modules (and versions) available from the repository named &quot;AppModules&quot;">
repo -n AppModules -list-modules
</example>

<!-- Universal Actions -->
<modifier name="delete-all" description="Deletes all repositories (possibly subject to a type filter: -f, -r, -l)" />
<modifier name="list" description="Lists all repositories (possibly subject to a type filter: -f, -r, -l)" />
<modifier name="list-modules" description="List modules available in the specified repository (-n\[ame]), or in all configured repositories if no repository was specified." />

<!-- General/shared modifiers -->
<modifier name="name" aliases="n" value="true" description="Namespace-unique name for the module" />
<modifier name="delete" description="Deletes the current namespace's reference to the named repository" />
<modifier name="publish" value="true" valueList="0,1" description="When configuring a remote repository, specifies that publishing of packages to the repository is allowed. When configuring the current namespace with -enable, specifies that publishing is also enabled. "/>

<!-- General properties -->
<modifier name="snapshots" aliases="s" value="true" valueList="0,1" description="For any repository, specifies that it should be used to look for snapshot builds (i.e., those with a semantic version ending in '+snapshot', indicating a 'latest' build of a particular version)." />
<modifier name="prereleases" aliases="pre" value="true" valueList="0,1" description="For any repository, specifies that it should be used to look for prerelease software" />

<!-- Repository types  -->
<modifier name="filesystem" aliases="f,fs" description="Create/update a filesystem repository" />
<modifier name="remote" aliases="r" description="Create/update a remote server repository" />
<modifier name="local" aliases="l" description="Create/update the local namespace cache" />
<modifier name="type" value="true" aliases="t" description="Subclass of %ZPM.PackageManager.Client.ServerDefinition to create/modify/delete or implementation of %ZPM.PackageManager.Core.IPackageService or %ZPM.PackageManager.Core.IPublishService to enable/disable" />

<!-- File repository modifiers -->
<modifier name="depth" aliases="d" value="true" description="For filesystem repositories, specifies the depth (number of folders underneath the root) to search for files named module.xml" />
<modifier name="path" aliases="p" value="true" description="For filesystem repositories, specifies the path to the root directory" />

<!-- Remote repository modifiers -->
<modifier name="url" value="true" description="For remote repositories, specifies the URL for package retrieval web services." />
<modifier name="username" aliases="user" value="true" description="For remote repositories, specifies the username to use when connecting." />
<modifier name="password" aliases="pass" value="true" description="For remote repositories, specifies the password to use when connecting." />

<!-- Modifiers specific to -enable -->
<modifier name="app" value="true" description="When enabling a namespace to serve as a remote repository, specifies the web application to allow web service access." />
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
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<parameter name="path" required="true" description="Directory on the local filesystem, containing a file named module.xml" />
</command>

<command name="install" dataPrefix="D">
<description>Installs a module available in a configured repository</description>
<example description="Installs the most recent 1.x version of HS.JSON available in any configured repository in the current namespace.">install HS.JSON 1.x</example>
<parameter name="module" description="Name of module to install" />
<parameter name="version" description="Version (or version expression) of module to install; defaults to the latest available if unspecified." />
<modifier name="dev" dataAlias="DeveloperMode" dataValue="1" description="Sets the DeveloperMode flag for the module's lifecycle. Key consequences of this are that ^Sources will be configured for resources in the module, and installer methods will be called with the dev mode flag set." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="keywords" aliases="k" value="true" description="Searches for modules matching some set of keywords." />
</command>

<command name="uninstall" dataPrefix="D">
<description>Uninstalls a module currently installed locally. This will be prevented if other modules depend on the named module, unless the -force flag is specified.</description>
<example description="Uninstalls HS.JSON from the current namespace.">uninstall HS.JSON</example>
<modifier name="force" aliases="f" description="If specified, the module will be uninstalled even if other modules depend on it." />
<modifier name="recurse" aliases="r" description="Also recursively uninstall dependencies. By default, will not uninstall dependencies that are also required by other installed modules; the -force flag overrides this." />
<modifier name="quiet" aliases="q" dataAlias="Verbose" dataValue="0" description="Produces minimal output from the command." />
<modifier name="verbose" aliases="v" dataAlias="Verbose" dataValue="1" description="Produces verbose output from the command." />
<modifier name="purge" dataAlias="Purge" dataValue="1" description="Purge data from tables during uninstall." />
<parameter name="module" required="true" description="Name of module to uninstall" />
</command>

<command name="orphans">
<description>Lists resources in the current namespace's default code database that are not part of any module.</description>
<example>orphans -type CLS</example>
<modifier name="type" aliases="t" value="true" description="Type (e.g., extension) of resource to show; if unspecified, all types are included." />
</command>

<command name="manage" aliases="manager">
<description>Manages applications installed on this instance (interactive)</description>
<example>manage -ns MYAPPNS</example>
<modifier name="namespace" aliases="ns" value="true" description="Namespace to start the manager in" />
</command>

<command name="list-installed" aliases="list">
<description>Lists modules installed in the current namespace</description>
<example description="Shows all installed modules in tree format.">list-installed -tree</example>
<modifier name="tree" aliases="t" description="If specified, show dependency tree for installed modules" />
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
</commands>
}

/// @PublicAPI
ClassMethod Shell(pCommand As %String) As %Status
{
	Set tSC = $$$OK
	Do ..ShellInternal(.pCommand,.tException)
	If $IsObject(tException) {
		Set tSC = tException.AsStatus()
	}
	Quit tSC
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
	For {
		Try {
			If (tCommand = "") {
				Write "zpm: ",$Namespace,">"
				Read tCommand
				Write !
			}
			
			If (tCommand = "") {
				#; Do ..%Help()
				Quit
			}
			
			Kill tCommandInfo
      $$$ThrowOnError(..%ParseCommandInput(tCommand,.tCommandInfo))
			
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
			} ElseIf (tCommandInfo = "install") {
				Do ..Install(.tCommandInfo)
			} ElseIf (tCommandInfo = "uninstall") {
				Do ..Uninstall(.tCommandInfo)
			} ElseIf (tCommandInfo = "manage") {
				Do ..Manage(.tCommandInfo)
			} ElseIf (tCommandInfo = "list-installed") {
				Do ..ListInstalled(.tCommandInfo)
			} ElseIf (tCommandInfo = "list-dependents") {
				Do ..ListDependents(.tCommandInfo)
			} ElseIf (tCommandInfo = "orphans") {
				Do ..ListOrphans(.tCommandInfo)
			} ElseIf (tCommandInfo = "module-action") {
				Do ..ModuleAction(.tCommandInfo)
			}
		} Catch pException {
			#dim e As %Exception.AbstractException
			If (pException.Code = $$$ERCTRLC) {
				Set pException = $$$NULLOREF
				Return
			}
			Write !,pException.DisplayString()
		}
		
		Set tCommand = ""
		Quit:tOneCommand
		Write !
	}
}

ClassMethod Init(ByRef pCommandInfo) [ Internal ]
{
	// In quiet mode, no prompts should be shown.
	Set tQuiet = $$$HasModifier(pCommandInfo,"noprompt")
	
	// Local artifact cache
	$$$ThrowOnError(##class(%ZPM.PackageManager.Client.Utils).InitializeLocalCache(.tCreated))
	If (tCreated) {
		Write !,"Initialized local cache."
	} Else {
		Write !,"Local cache already exists."
	}
	
	// Reindex tables with semantic version indices
	For tClass = "%ZPM.PackageManager.Server.Module","%ZPM.PackageManager.Server.Application","%ZPM.PackageManager.Client.Filesystem.Cache" {
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
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,"call %ZPM_PackageManager_Developer.IConfigurable_ListSettings()")
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
}

ClassMethod Search(ByRef pCommandInfo) [ Internal ]
{
	Set tName = $$$GetModifier(pCommandInfo,"name")
	If (tName '= "") {
		Do ..ShowModulesForRepository(tName)
	} Else {
		Write !
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select Name, Details from %ZPM_PackageManager_Client.ServerDefinition")
		If (tRes.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
		}
		While tRes.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			If ($I(tCount) > 1) {
				Write !!
			}
			Write tRes.%Get("Name")," ", tRes.%Get("Details"),":"
			Do ..ShowModulesForRepository(tRes.%Get("Name"))
		}
		$$$ThrowOnError(tSC)
	}
}

ClassMethod Repository(ByRef pCommandInfo) [ Internal ]
{
	Set tFileSystem = $$$HasModifier(pCommandInfo,"filesystem")
	Set tRemote = $$$HasModifier(pCommandInfo,"remote")
	Set tLocal = $$$HasModifier(pCommandInfo,"local")
	
	If $$$HasModifier(pCommandInfo,"list") {
		Write !
		If (tFileSystem + tRemote + tLocal '= 1) {
			Set tRes = ##class(%SQL.Statement).%ExecDirect(,
				"select Name "_
				"from %ZPM_PackageManager_Client.ServerDefinition "_
				"order by %ZPM_PackageManager_Client.ServerDefinition_SortOrder(ID) desc")
			If (tRes.%SQLCODE < 0) {
				Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
			}
			While tRes.%Next(.tSC) {
				$$$ThrowOnError(tSC)
				
				#dim tDefn As %ZPM.PackageManager.Client.ServerDefinition
				Set tRepository = ##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyOpen(tRes.%Get("Name"),,.tSC)
				$$$ThrowOnError(tSC)
				Do tRepository.Display()
				Write !
			}
			$$$ThrowOnError(tSC)
		}
		Quit
	} ElseIf $$$HasModifier(pCommandInfo,"enable") {
	} ElseIf $$$HasModifier(pCommandInfo,"disable") {
	} ElseIf $$$HasModifier(pCommandInfo,"info") {
	} ElseIf $$$HasModifier(pCommandInfo,"list-modules") {
		Do ..Search(.pCommandInfo)
		Quit
	} ElseIf $$$HasModifier(pCommandInfo,"delete-all") {
		Set tDeleteFS = tFileSystem || 'tRemote
		Set tDeleteRemote = tRemote || 'tFileSystem
		If tDeleteFS {
			$$$ThrowOnError(##class(%ZPM.PackageManager.Client.FilesystemServerDefinition).%DeleteExtent())
		}
		If tDeleteRemote {
			$$$ThrowOnError(##class(%ZPM.PackageManager.Client.RemoteServerDefinition).%DeleteExtent())
		}
	} ElseIf $$$HasModifier(pCommandInfo,"delete") {
		$$$ThrowOnError(##class(%ZPM.PackageManager.Client.ServerDefinition).ServerDefinitionKeyDelete($$$GetModifier(pCommandInfo,"name")))
		Quit
	} Else {
		Set tName = $$$GetModifier(pCommandInfo,"name")
		Set tType = $$$GetModifier(pCommandInfo,"type")
		
		#dim tRepoTypeResult As %SQL.StatementResult
		Set tStatement = ##class(%SQL.Statement).%New()
		Set tSC = tStatement.%PrepareClassQuery("%ZPM.PackageManager.Client.ServerDefinition","Catalog")
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
			Set tType = $Select(
				tFileSystem:"%ZPM.PackageManager.Client.FilesystemServerDefinition",
				tRemote:"%ZPM.PackageManager.Client.RemoteServerDefinition",
				tLocal:"%ZPM.PackageManager.Client.LocalServerDefinition",
				1:"")
			
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
		} ElseIf $Data(tMonikers($ZConvert(tType,"L")),tClassName) {
			Set tType = tClassName
		}
		
		Set tBaseClass = "%ZPM.PackageManager.Client.ServerDefinition"
		If '$ClassMethod(tType,"%Extends",tBaseClass) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid type '%1' - must extend %2",tType,tBaseClass))
		}
		
		Merge tModifiers = pCommandInfo("modifiers")
		Merge tData = pCommandInfo("data")
		$$$ThrowOnError($ClassMethod(tType,"Configure",1,.tModifiers,.tData))
	}
}

ClassMethod ShowModulesForRepository(pRepoName As %String) [ Private ]
{
	Set tQuery = "select Name,Version from %ZPM_PackageManager_Developer.Utils_GetModuleList(?)"
	Set tRes = ##class(%SQL.Statement).%ExecDirect(,tQuery,pRepoName)
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Write !,tRes.%Get("Name")," ",tRes.%Get("Version")
	}
}

ClassMethod Load(ByRef pCommandInfo) [ Internal ]
{
	Set tDirectoryName = $Get(pCommandInfo("parameters","path"))
	Merge tParams = pCommandInfo("data")
	If ##class(%File).DirectoryExists(tDirectoryName) {
		$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Utils).LoadNewModule(tDirectoryName,.tParams))
	} ElseIf ##class(%File).Exists(tDirectoryName),$$$lcase($PIECE(tDirectoryName, ".", *)) = "tgz" {
		Set tTargetDirectory = $$$FileTempDir
		Set tSC = ##class(%ZPM.PackageManager.Developer.Archive).Extract(tDirectoryName, tTargetDirectory)
		$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Utils).LoadNewModule(tTargetDirectory, .tParams))
	}
}

ClassMethod Install(ByRef pCommandInfo) [ Internal ]
{
	Set tRegistry = ""
	Set tModuleName = $Get(pCommandInfo("parameters","module"))
	If (tModuleName["/") {
		set $lb(tRegistry, tModuleName) = $lfs(tModuleName, "/")
	}
	If tRegistry = "" {
		Set tServer = ##class(%ZPM.PackageManager.Client.RemoteServerDefinition).DeploymentServerOpen(1,,.tSC)
		If $isobject(tServer) {
			Set tRegistry = tServer.Name
		}
	}

	Set tVersion = $Get(pCommandInfo("parameters","version"))
	Set tKeywords = $$$GetModifier(pCommandInfo,"keywords")
	
	Set tSearchCriteria = ##class(%ZPM.PackageManager.Core.SearchCriteria).%New()
	Set tSearchCriteria.Registry = tRegistry
	Set tSearchCriteria.Name = tModuleName
	Set tSearchCriteria.VersionExpression = tVersion
	Set tSearchCriteria.Keywords = tKeywords
	$$$ThrowOnError(##class(%ZPM.PackageManager.Client.Utils).SearchRepositoriesForModule(tSearchCriteria,.tResults))
	
	If (tResults.Count() > 0) {
		Set tResult = ""
		#dim tResult As %ZPM.PackageManager.Core.QualifiedModuleReference
		If (tKeywords = "") {
			#; Install latest version by default
			Set tResult = tResults.GetAt(tResults.Size)
		} ElseIf (tResults.Count() > 0) {
			For i=1:1:tResults.Count() {
				Set tResultInfo = tResults.GetAt(i)
				Set tOptArray(i) = tResultInfo.Name_" "_tResultInfo.VersionString_" @ "_tResultInfo.ServerName
			}
			
			Set tValue = ""
			Do ##class(%Library.Prompt).GetMenu("Which version?",.tValue,.tOptArray,,$$$InitialDisplayMask)
			
			If (tValue '= "") {
				Set tResult = tResults.GetAt(tValue)
			}
		}
		
		If (tResult '= "") {
			Do ##class(%ZPM.PackageManager.Developer.Lifecycle.Abstract).GetDefaultParameters(.tParams)
			Merge tParams = pCommandInfo("data")
			Set tParams("Install") = 1
			$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Utils).LoadModuleReference(tResult.ServerName,tResult.Name,tResult.VersionString,.tParams))
		}
	} Else {
		Set tPrefix = ""
		If (tModuleName '= "") {
			If (tVersion '= "") {
				Write !,tModuleName_" "_tVersion_" not found in any repository."
			} Else {
				Write !,"'",tModuleName_"' not found in any repository."
			}
		} ElseIf (tKeywords '= "") {
			Write !,"No modules found matching keywords: '",tKeywords,"'"
		} Else {
			
		}
	}
}

ClassMethod Uninstall(ByRef pCommandInfo) [ Internal ]
{
	Set tModuleName = pCommandInfo("parameters","module")
	Set tForce = $$$HasModifier(pCommandInfo,"force") // Force uninstallation even if things depend on this module
	Set tRecurse = $$$HasModifier(pCommandInfo,"recurse") // Recursively uninstall unneeded dependencies
	Merge tParams = pCommandInfo("data")
	$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Module).Uninstall(tModuleName,tForce,tRecurse,.tParams))
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
		$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.Module).ExecutePhases(tModName,tActualPhases,tIsComplete,.tParams))
	} Else {
		If (tModName '= "") && ##class(%ZPM.PackageManager.Developer.Module).NameExists(tModName) {
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

ClassMethod Manage(ByRef pCommandInfo) [ Internal ]
{
	New $Namespace
	Set tNSArg = $Get(pCommandInfo("modifiers","namespace"))
	Set tNamespace = ""
	If (tNSArg '= "") {
		// See if this is the name of a particular namespace.
		If ##class(%SYS.Namespace).Exists(tNSArg) {
			Set tNamespace = tNSArg
		}
	} Else {
		// TODO: see if there is anything installed in this namespace.
	}
	
	Set tNSMenu($i(tNSMenu)) = "Install an application"
	Set tNSMenu($i(tNSMenu)) = "Upgrade/repair an application"
	Set tNSMenu($i(tNSMenu)) = "Uninstall an application"
	Set tNSMenu($i(tNSMenu)) = "Switch namespace"
	Set tNSMenu($i(tNSMenu)) = "Quit"
	
	For {
		Set tValue = ""
		Write !,"Namespace: ",$Namespace
		Set tResponse = ##class(%Library.Prompt).GetMenu("Select an option:",.tValue,.tNSMenu,,$$$InitialDisplayMask)
		If (tResponse '= $$$SuccessResponse) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
		}
		
		If (tValue '= 1) && (tValue '= 5) {
			While (tNamespace = "") {
				Set tNSValue = ""
				Set tResponse = ##class(%Library.Prompt).GetArray("Select a namespace:",.tNSValue,$ListBuild($classname()_":ActiveNamespaces"),,,,$$$InitialDisplayMask)
				If (tResponse '= $$$SuccessResponse) {
					$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
				}
				Set tNamespace = tNSValue
			}
			
			Set $Namespace = tNamespace
		}
		
		If (tValue = 1) {
			// Construct an instance of %ZPM.PackageManager.Core.InstallationInfo
			Set tInfo = ##class(%ZPM.PackageManager.Core.InstallationInfo).%New()
			
			Set tNamespace = ""
			While (tNamespace = "") {
				Set tResponse = ##class(%Library.Prompt).GetString("Namespace:",.tNamespace)
				If (tResponse '= $$$SuccessResponse) {
					$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
				}
				If ##class(%SYS.Namespace).Exists(tNamespace) {
					Write !,"Namespace '",tNamespace,"' already selects. Please enter a new namespace name."
					Set tNamespace = ""
				}
			}
			Set tInfo.Namespace = tNamespace
			
			Set tModName = ""
			Set tResponse = ##class(%Library.Prompt).GetString("Application name:",.tModName)
			If (tResponse '= $$$SuccessResponse) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
			}
			
			Set tModVersion = ""
			Set tResponse = ##class(%Library.Prompt).GetString("Application version/range:",.tModVersion)
			If (tResponse '= $$$SuccessResponse) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
			}
			
			Set tSearchCriteria = ##class(%ZPM.PackageManager.Core.SearchCriteria).%New()
			Set tSearchCriteria.Name = tModName
			Set tSearchCriteria.VersionExpression = tModVersion
			Set tSearchCriteria.IncludeSnapshots = 1
			Set tSearchCriteria.IncludePrerelease = 1
			$$$ThrowOnError(##class(%ZPM.PackageManager.Client.Utils).SearchRepositoriesForApplication(tSearchCriteria,.tResults))
			
			If (tResults.Count() > 0) {
				#dim tResult As %ZPM.PackageManager.Core.QualifiedModuleReference
				If (tResults.Count() = 1) {
					Set tInfo.ModuleReference = tResults.GetAt(1)
				} ElseIf (tResults.Count() > 1) {
					For i=1:1:tResults.Count() {
						Set tResult = tResults.GetAt(i)
						Set tOptArray(i) = tResult.Name_" "_tResult.VersionString_" @ "_tResult.ServerName
					}
					
					Set tResponse = ##class(%Library.Prompt).GetMenu("Which version?",.tValue,.tOptArray,,$$$InitialDisplayMask)
					If (tResponse '= $$$SuccessResponse) {
						$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
					}
					
					Set tInfo.ModuleReference = tResults.GetAt(tValue)
				}
			} Else {
				Write !,tModName_" "_tModVersion_" not found in any repository."
				Continue
			}
			
			// TODO: Parameters
			
			$$$ThrowOnError(##class(%ZPM.PackageManager.Client.Utils).InstallApplication(tInfo))
			
			Set $Namespace = tNamespace
		} ElseIf (tValue = 2) {
			// TODO: Implement, based on things installed in the current namespace.
			Write !,"This feature is not yet implemented."
		} ElseIf (tValue = 3) {
			// List installed modules with application packaging.
			
			Kill tModuleList
			Set tModuleList = 0
			
			#dim tRes As %SQL.StatementResult
			Set tRes = ##class(%SQL.Statement).%ExecDirect(,"select Name,LifecycleClass from %ZPM_PackageManager_Developer.""Module""")
			If (tRes.%SQLCODE < 0) {
				$$$ThrowStatus($$$ERROR($$$SQLCode,tRes.%SQLCODE,tRes.%Message))
			}
			While (tRes.%Next(.tSC)) {
				$$$ThrowOnError(tSC)
				set tLifecycleClass = tRes.LifecycleClass
				if (tLifecycleClass '= "") && ($Length(tLifecycleClass,".") = 1) {
					set tLifecycleClass = $$$DefaultLifecyclePackageDot_tLifecycleClass
				}
				If $ClassMethod(tLifecycleClass,"%Extends","%ZPM.PackageManager.Developer.Lifecycle.Application") {
					Set tModuleList($i(tModuleList)) = tRes.%Get("Name")
				}
			}
			$$$ThrowOnError(tSC)
			
			Set tUninstallAppIdx = ""
			While (tUninstallAppIdx = "") {
				Set tResponse = ##class(%Library.Prompt).GetMenu("Which application?",.tUninstallAppIdx,.tModuleList,,$$$InitialDisplayMask)
				If (tResponse '= $$$SuccessResponse) {
					$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
				}
			}
			
			// Construct an instance of %ZPM.PackageManager.Core.InstallationInfo
			Set tInfo = ##class(%ZPM.PackageManager.Core.InstallationInfo).%New()
			Set tInfo.Namespace = $Namespace
			Set tInfo.ModuleReference.Name = tModuleList(tUninstallAppIdx)
			$$$ThrowOnError(##class(%ZPM.PackageManager.Client.Utils).UninstallApplication(tInfo))
		} ElseIf (tValue = 4) {
			Set tNamespace = ""
		} ElseIf (tValue = 5) {
			Return
		}
	}
}

ClassMethod ListInstalled(ByRef pCommandInfo) [ Private ]
{
	Set tRes = ##class(%SQL.Statement).%ExecDirect(,
		"select Name,VersionString from %ZPM_PackageManager_Developer.""MODULE""")
	If (tRes.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
	}
	While tRes.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Set tModMap(tRes.%Get("Name")) = tRes.%Get("VersionString")
	}
	$$$ThrowOnError(tSC)
	
	Set tTree = ''$Data(pCommandInfo("modifiers","tree"))
	
	If (tTree) {
		// Show tree of dependencies as well.
		// Modules that are dependencies for no other are shown at the top level.
		// TODO: deal with cyclic dependencies?
		
		Set tDepRes = ##class(%SQL.Statement).%ExecDirect(,
			"select ""Module""->Name ModName,Dependencies_Name DepName,Dependencies_VersionString DepVer "_
			"from %ZPM_PackageManager_Developer.Module_Dependencies")
		If (tDepRes.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
		}
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
		Set tMod = ""
		For {
			Set tMod = $Order(tModMap(tMod),1,tVersion)
			Quit:(tMod="")
			Write tMod," ",tVersion,!
		}
	}
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
		Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).GetDependentsAsTree(.%tree,.tErrorList,tModName,tVersion,tRepos)
		$$$ThrowOnError(tSC)
	} Else {
		Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).GetDependentsList(.tList,.tErrorList,tModName,tVersion,tRepos)
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
			#dim tItem As %ZPM.PackageManager.Core.QualifiedModuleReference
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
		
		Write tFrontPadding,tValue,!
		
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
	Set tResult = ##class(%ZPM.PackageManager.Developer.Utils).OrphanedResourcesFunc($Namespace,tType)
	While tResult.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Write tResult.%Get("Name"),!
	}
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
		
		Set tRtn = ##class(%Routine).%New("%ZLANGC00.MAC")
		If ##class(%Routine).Exists("%ZLANGC00.MAC") {
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
		$$$ThrowOnError(tRtn.Compile())
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
ZPM(pArgs...) Do ##class(%ZPM.PackageManager).Shell(pArgs...) Quit
$$$ENDTAG
#; Need an extra line down here to avoid the end bracket being on the same line as $$$ENDTAG - a comment is just fine.
}

}
