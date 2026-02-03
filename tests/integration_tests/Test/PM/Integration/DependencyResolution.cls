Class Test.PM.Integration.DependencyResolution Extends Test.PM.Integration.Base
{

Method TestEverything()
{
	#dim tModule As %IPM.Storage.Module
	new $namespace
	set tOrigNS = $namespace
	try {
		if '$$$AssertStatusOK(..Setup()) || ..SkipTest {
			quit
    }

    do ..PublishModules()

		#; // Get annotations for local module XDATA blocks; put into array by module (XDATA) name.
		#; If '$$$AssertStatusOK(##class(%IPM.PackageManager.Developer.Annotation.Utils).ExtractAnnotations($classname(),.tAnnotationList)) {
		#; 	Quit
    #; }

		kill tAssertArray

		#; For i=1:1:tAnnotationList.Count() {
		#; 	#dim tAnnotation As %IPM.PackageManager.Developer.Annotation
		#; 	Set tAnnotation = tAnnotationList.GetAt(i)
		#; 	If (tAnnotation.MemberType = "XData") {
		#; 		Set tAssertArray(tAnnotation.MemberName,$i(tAssertArray(tAnnotation.MemberName))) = $ListBuild(tAnnotation.Tag,$$$lcase(tAnnotation.Value))
		#; 	}
    #; }

		// In client namespace:
		write !,!,!
		set $namespace = ..#CLIENTNS

		// Create a module referring to the module in the remote repository
		set tKey = ""
		for {
			set tKey = $order(tAssertArray(tKey),1,tAssertCount)
			quit:tKey=""

			// Have modules fail independently.
			try {
				// If we're loading a module with dependencies, clear out things that might have conflicting dependencies first.
				do ..UtilUninstallAll()

				continue:'$$$AssertStatusOK(..ReadXDataToModule(tOrigNS,tKey,.tModule),"Loaded module in "_tKey_" XData block.")

				continue:'$$$AssertStatusOK(tModule.Lifecycle.Clean(),"Removed existing dependency versions for module.")

				for i=1:1:tAssertCount {
					set $listbuild(tAssertType,tAssertValue) = tAssertArray(tKey,i)
					if (tAssertType '= "AssertInstalledBefore") {
						continue
					}

					set tQualRef = ##class(%IPM.Storage.QualifiedModuleInfo).%New()
					set tQualRef.ServerName = ..#REGISTRYNAME
					set tQualRef.Name = $piece(tAssertValue," ",1)
					set tQualRef.VersionString = $piece(tAssertValue," ",2)
					set tSC = ##class(%IPM.Utils.Module).LoadQualifiedReference(tQualRef)
					do $$$AssertStatusOK(tSC,"Installed "_tAssertValue)
				}

				kill tDependencyGraph
				set tGraphStatus = tModule.BuildDependencyGraph(.tDependencyGraph)

				for i=1:1:tAssertCount {
					set $listbuild(tAssertType,tAssertValue) = tAssertArray(tKey,i)
					if (tAssertType = "AssertUnresolvable") {
						if '$$$AssertStatusNotOK(tGraphStatus,"Could not build dependency graph.") {
							set tDepKey = ""
							for {
								set tDepKey = $order(tDependencyGraph(tDepKey),1,tData)
								quit:tDepKey=""
								do $$$LogMessage("Resolved as depending on "_tDepKey_" "_$listget(tData,3))
							}
						}
						continue
					} elseif (i = 1) {
						do $$$AssertStatusOK(tGraphStatus,"Could build dependency graph.")
					}

					if (tAssertType = "AssertDependsOn") {
						set tModuleName = $piece(tAssertValue," ")
						set tVersion = $piece(tAssertValue," ",2)
						if '$$$AssertEquals($listget(tDependencyGraph(tModuleName),3),tVersion,"Depends on "_tModuleName_" "_tVersion) {
                            do $$$LogMessage("Actually depended on "_tModuleName_" "_$listget(tDependencyGraph(tModuleName),3))
						}
					} elseif (tAssertType = "AssertCompileOK") {
						do $$$AssertStatusOK(tModule.%Compile("-d"),"Module compiled successfully.")
					} elseif (tAssertType = "AssertCompileNotOK") {
						set tSC = tModule.%Compile("-d")
						do $$$AssertStatusNotOK(tSC,"Module compiled with error: "_$system.Status.GetErrorText(tSC))
					}
				}

				for i=1:1:tAssertCount {
					set $listbuild(tAssertType,tAssertValue) = tAssertArray(tKey,i)
					if (tAssertType '= "AssertInstalledAfter") && (tAssertType '= "AssertInstallFailedAfter") {
						continue
					}

					set tQualRef = ##class(%IPM.Storage.QualifiedModuleInfo).%New()
					set tQualRef.ServerName = ..#REGISTRYNAME
					set tQualRef.Name = $piece(tAssertValue," ",1)
					set tQualRef.VersionString = $piece(tAssertValue," ",2)
					set tSC = ##class(%IPM.Utils.Module).LoadQualifiedReference(tQualRef)
					if (tAssertType = "AssertInstalledAfter") {
						do $$$AssertStatusOK(tSC,"Installed "_tAssertValue)
					} else {
						do $$$AssertStatusNotOK(tSC,"Refused (correctly) to install "_tAssertValue)
          }
				}
			} catch e {
				do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
      }
		}
	} catch e {
		do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}

	// Cleanup
	set $namespace = tOrigNS
	do $$$AssertStatusOK(..TearDown())
}

Method PublishModules()
{
  set tOrigNS = $namespace
  // Publish modules
  for i=1:1:11,100:1:104 {
    // If we're loading a module with dependencies, clear out things that might have conflicting dependencies first.
    do ..UtilUninstallAll()

    quit:'$$$AssertStatusOK(..ReadXDataToModule(tOrigNS,"ServerModule"_i,.tModule),"Loaded module from XData block ServerModule"_i)

    // Publish module
    do $$$AssertStatusOK(tModule.Lifecycle.Publish(),"Published "_tModule.Name_" "_tModule.VersionString)
  }
}

Method UtilUninstallAll()
{
	for tModName = "Demo","HS.REST","HS.MDM","HS.JSON" {
		if ##class(%IPM.Storage.Module).NameExists($$$lcase(tModName)) {
			do $$$AssertStatusOK(##class(%IPM.Storage.Module).Uninstall(tModName))
		}
	}
}

XData ServerModule1 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>0.0.1</Version>
</Module>
}

XData ServerModule2 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>0.1.0</Version>
</Module>
}

XData ServerModule3 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>1.0.0</Version>
</Module>
}

XData ServerModule4 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>1.1.0</Version>
</Module>
}

XData ServerModule5 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>1.1.1</Version>
</Module>
}

XData ServerModule6 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>1.1.2</Version>
</Module>
}

XData ServerModule7 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>1.1.3</Version>
</Module>
}

XData ServerModule8 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>1.1.4</Version>
</Module>
}

XData ServerModule9 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>1.0.1</Version>
</Module>
}

XData ServerModule10 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>1.0.2</Version>
</Module>
}

XData ServerModule11 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.JSON</Name>
  <Version>2.0.0</Version>
</Module>
}

XData ServerModule100 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.MDM</Name>
  <Version>1.0.0</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.JSON</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule101 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.MDM</Name>
  <Version>1.0.1</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.JSON</Name>
  <Version>1.1.x</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule102 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.REST</Name>
  <Version>1.0.0</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.JSON</Name>
  <Version>1.0.x</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule103 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.REST</Name>
  <Version>1.0.1</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.JSON</Name>
  <Version>1.1.3</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule104 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>HS.REST</Name>
  <Version>1.0.4</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.JSON</Name>
  <Version>*</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("HS.MDM 1.0.1")
/// @AssertDependsOn("HS.JSON 1.1.4")
/// @AssertCompileOK
XData LocalModule1 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>*</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("HS.MDM 1.0.0")
/// @AssertDependsOn("HS.JSON 1.0.0")
/// @AssertCompileOK
XData LocalModule2 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("HS.MDM 1.0.1")
/// @AssertDependsOn("HS.JSON 1.1.4")
/// @AssertCompileOK
XData LocalModule3 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("HS.MDM 1.0.1")
/// @AssertDependsOn("HS.JSON 1.1.1")
/// @AssertCompileOK
XData LocalModule4 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.JSON</Name>
  <Version>1.1.1</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertUnresolvable
/// @AssertCompileNotOK
XData LocalModule5 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.JSON</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("HS.REST 1.0.1")
/// @AssertDependsOn("HS.MDM 1.0.1")
/// @AssertDependsOn("HS.JSON 1.1.3")
/// @AssertCompileOK
XData LocalModule6 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.REST</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("HS.REST 1.0.1")
/// @AssertDependsOn("HS.MDM 1.0.1")
/// @AssertDependsOn("HS.JSON 1.1.3")
/// @AssertCompileOK
XData LocalModule7 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.REST</Name>
  <Version>1.*</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.*</Version>
  </ModuleReference>

  <!-- The below ModuleReference is required in order for the HS.REST/HS.MDM combination above to be resolved. Ideally it would not be, but with the same result. -->
  <ModuleReference>
  <Name>HS.JSON</Name>
  <Version>1.1.3</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("HS.REST 1.0.0")
/// @AssertDependsOn("HS.MDM 1.0.0")
/// @AssertDependsOn("HS.JSON 1.0.0")
/// @AssertCompileOK
XData LocalModule8 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>HS.REST</Name>
  <Version>1.*</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("HS.REST 1.0.0")
/// @AssertDependsOn("HS.MDM 1.0.0")
/// @AssertDependsOn("HS.JSON 1.0.0")
/// @AssertCompileOK
XData LocalModule9 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.*</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>HS.REST</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("HS.REST 1.0.0")
/// @AssertDependsOn("HS.MDM 1.0.0")
/// @AssertDependsOn("HS.JSON 1.0.0")
/// @AssertCompileOK
XData LocalModule10 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.*</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>HS.REST</Name>
  <Version>1.0.x</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>HS.JSON</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertUnresolvable
/// @AssertCompileNotOK
XData LocalModule11 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertInstalledBefore("HS.JSON 1.1.1")
/// @AssertDependsOn("HS.JSON 1.1.1")
/// @AssertCompileOK
XData LocalModule12 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<!-- Test case: Resolving dependencies to use an installed version (rather than getting a later version) -->
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertInstalledBefore("HS.JSON 1.0.0")
/// @AssertDependsOn("HS.JSON 1.1.4")
/// @AssertCompileOK
XData LocalModule13 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<!-- Test case: Resolving dependencies to upgrade an installed version (rather than failing) works -->
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertUnresolvable
/// @AssertCompileNotOK
/// @AssertInstalledBefore("HS.REST 1.0.0")
XData LocalModule14 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<!-- Test case: Resolving dependencies will fail rather than upgrading an installed version to a version incompatible with other installed software -->
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertCompileNotOK
/// @AssertInstalledBefore("HS.JSON 2.0.0")
/// @AssertDependsOn("HS.JSON 1.1.4")
/// @AssertDependsOn("HS.MDM 1.0.1")
XData LocalModule15 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<!-- Test case: Resolving dependencies to downgrade an installed version does not work -->
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>HS.MDM</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

}
