Class Test.PM.Integration.DependencyResolution Extends Test.PM.Integration.Base
{

Method TestEverything()
{
	#dim tModule As %IPM.Storage.Module
	New $Namespace
	Set tOrigNS = $Namespace
	Try {
		If '$$$AssertStatusOK(..Setup()) || ..SkipTest {
			Quit
    }
    
    Do ..PublishModules()
  
		#; // Get annotations for local module XDATA blocks; put into array by module (XDATA) name.
		#; If '$$$AssertStatusOK(##class(%IPM.PackageManager.Developer.Annotation.Utils).ExtractAnnotations($classname(),.tAnnotationList)) {
		#; 	Quit
    #; }
    
		Kill tAssertArray
		
		#; For i=1:1:tAnnotationList.Count() {
		#; 	#dim tAnnotation As %IPM.PackageManager.Developer.Annotation
		#; 	Set tAnnotation = tAnnotationList.GetAt(i)
		#; 	If (tAnnotation.MemberType = "XData") {
		#; 		Set tAssertArray(tAnnotation.MemberName,$i(tAssertArray(tAnnotation.MemberName))) = $ListBuild(tAnnotation.Tag,$$$lcase(tAnnotation.Value))
		#; 	}
    #; }
    
		// In client namespace:
		Write !,!,!
		Set $Namespace = ..#CLIENTNS
		
		// Create a module referring to the module in the remote repository
		Set tKey = ""
		For {
			Set tKey = $Order(tAssertArray(tKey),1,tAssertCount)
			Quit:tKey=""
			
			// Have modules fail independently.
			Try {
				// If we're loading a module with dependencies, clear out things that might have conflicting dependencies first.
				Do ..UtilUninstallAll()
				
				Continue:'$$$AssertStatusOK(..ReadXDataToModule(tOrigNS,tKey,.tModule),"Loaded module in "_tKey_" XData block.")
				
				Continue:'$$$AssertStatusOK(tModule.Lifecycle.Clean(),"Removed existing dependency versions for module.")
				
				For i=1:1:tAssertCount {
					Set $ListBuild(tAssertType,tAssertValue) = tAssertArray(tKey,i)
					If (tAssertType '= "AssertInstalledBefore") {
						Continue
					}
          
					Set tQualRef = ##class(%IPM.Storage.QualifiedModuleInfo).%New()
					Set tQualRef.ServerName = ..#REGISTRYNAME
					Set tQualRef.Name = $Piece(tAssertValue," ",1)
					Set tQualRef.VersionString = $Piece(tAssertValue," ",2)
					Set tSC = ##class(%IPM.Utils.Module).LoadQualifiedReference(tQualRef)
					Do $$$AssertStatusOK(tSC,"Installed "_tAssertValue)
				}
				
				Kill tDependencyGraph
				Set tGraphStatus = tModule.BuildDependencyGraph(.tDependencyGraph)
				
				For i=1:1:tAssertCount {
					Set $ListBuild(tAssertType,tAssertValue) = tAssertArray(tKey,i)
					If (tAssertType = "AssertUnresolvable") {
						If '$$$AssertStatusNotOK(tGraphStatus,"Could not build dependency graph.") {
							Set tDepKey = ""
							For {
								Set tDepKey = $Order(tDependencyGraph(tDepKey),1,tData)
								Quit:tDepKey=""
								Do $$$LogMessage("Resolved as depending on "_tDepKey_" "_$ListGet(tData,3))
							}
						}
						Continue
					} ElseIf (i = 1) {
						Do $$$AssertStatusOK(tGraphStatus,"Could build dependency graph.")
					}
					
					If (tAssertType = "AssertDependsOn") {
						Set tModuleName = $Piece(tAssertValue," ")
						Set tVersion = $Piece(tAssertValue," ",2)
						If '$$$AssertEquals($ListGet(tDependencyGraph(tModuleName),3),tVersion,"Depends on "_tModuleName_" "_tVersion) {
              Do $$$LogMessage("Actually depended on "_tModuleName_" "_$ListGet(tDependencyGraph(tModuleName),3))
						}
					} ElseIf (tAssertType = "AssertCompileOK") {
						Do $$$AssertStatusOK(tModule.%Compile("-d"),"Module compiled successfully.")
					} ElseIf (tAssertType = "AssertCompileNotOK") {
						Set tSC = tModule.%Compile("-d")
						Do $$$AssertStatusNotOK(tSC,"Module compiled with error: "_$System.Status.GetErrorText(tSC))
					}
				}
				
				For i=1:1:tAssertCount {
					Set $ListBuild(tAssertType,tAssertValue) = tAssertArray(tKey,i)
					If (tAssertType '= "AssertInstalledAfter") && (tAssertType '= "AssertInstallFailedAfter") {
						Continue
					}
					
					Set tQualRef = ##class(%IPM.Storage.QualifiedModuleInfo).%New()
					Set tQualRef.ServerName = ..#REGISTRYNAME
					Set tQualRef.Name = $Piece(tAssertValue," ",1)
					Set tQualRef.VersionString = $Piece(tAssertValue," ",2)
					Set tSC = ##class(%IPM.Utils.Module).LoadQualifiedReference(tQualRef)
					If (tAssertType = "AssertInstalledAfter") {
						Do $$$AssertStatusOK(tSC,"Installed "_tAssertValue)
					} Else {
						Do $$$AssertStatusNotOK(tSC,"Refused (correctly) to install "_tAssertValue)
          }
				}
			} Catch e {
				Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
      }
		}

    Do ..SubTestInstallAndUpgrade()
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}
	
	// Cleanup
	Set $Namespace = tOrigNS
	Do $$$AssertStatusOK(..TearDown())
}

Method SubTestInstallAndUpgrade()
{

	#dim tModule As %IPM.Storage.Module
	New $Namespace
	Set tOrigNS = $Namespace
	Try {
		Set $Namespace = ..#CLIENTNS
    Do ..UtilUninstallAll()

    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("install hs.everything 1.0.0 -quiet"))
    zpm "list"
    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("install hs.everything 1.0.1 -quiet"))
    zpm "list"
    Do $$$AssertStatusNotOK(##class(%IPM.Main).Shell("install hs.everything 1.0.0 -quiet"))
    zpm "list"
    Do $$$AssertStatusOK(##class(%IPM.Main).Shell("install hs.everything 1.0.0 -DPermitDowngrade=1 -quiet"))
    zpm "list"
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}
}

Method PublishModules()
{
  Set tOrigNS = $Namespace
  // Publish modules
  For i=1:1:13,100:1:104,200:1:202 {
    // If we're loading a module with dependencies, clear out things that might have conflicting dependencies first.
    Do ..UtilUninstallAll()
    
    Quit:'$$$AssertStatusOK(..ReadXDataToModule(tOrigNS,"ServerModule"_i,.tModule),"Loaded module from XData block ServerModule"_i)
    
    // Publish module
    Do $$$AssertStatusOK(tModule.Lifecycle.Publish(),"Published "_tModule.Name_" "_tModule.VersionString)
  }
}

Method UtilUninstallAll()
{
	For tModName = "Demo","hs.rest","hs.mdm","hs.json","hs.everything","hs.bar","hs.foo" {
		If ##class(%IPM.Storage.Module).NameExists($$$lcase(tModName)) {
			Do $$$AssertStatusOK(##class(%IPM.Storage.Module).Uninstall(tModName))
		}
	}
}

XData ServerModule1 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>0.0.1</Version>
</Module>
}

XData ServerModule2 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>0.1.0</Version>
</Module>
}

XData ServerModule3 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>1.0.0</Version>
</Module>
}

XData ServerModule4 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>1.1.0</Version>
</Module>
}

XData ServerModule5 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>1.1.1</Version>
</Module>
}

XData ServerModule6 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>1.1.2</Version>
</Module>
}

XData ServerModule7 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>1.1.3</Version>
</Module>
}

XData ServerModule8 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>1.1.4</Version>
</Module>
}

XData ServerModule9 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>1.0.1</Version>
</Module>
}

XData ServerModule10 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>1.0.2</Version>
</Module>
}

XData ServerModule11 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.json</Name>
  <Version>2.0.0</Version>
</Module>
}

XData ServerModule12 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.foo</Name>
  <Version>1.0.0</Version>
  <Dependencies>
    <ModuleReference>
      <Name>hs.mdm</Name>
      <Version>1.0.0</Version>
    </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule13 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.bar</Name>
  <Version>1.0.0</Version>
  <Dependencies>
    <ModuleReference>
      <Name>hs.foo</Name>
      <Version>1.0.0</Version>
    </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule100 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.mdm</Name>
  <Version>1.0.0</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.json</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule101 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.mdm</Name>
  <Version>1.0.1</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.json</Name>
  <Version>1.1.x</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule102 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.rest</Name>
  <Version>1.0.0</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.json</Name>
  <Version>1.0.x</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule103 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.rest</Name>
  <Version>1.0.1</Version>
  <Dependencies>
    <ModuleReference>
      <Name>hs.json</Name>
      <Version>1.1.3</Version>
    </ModuleReference>
  </Dependencies>
  <Invoke Class="%IPM.Utils.Build" Method="Hang" />
</Module>
}

XData ServerModule104 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.everything</Name>
  <Version>1.0.0</Version>
  <Dependencies>
    <ModuleReference>
      <Name>hs.rest</Name>
      <Version>1.0.0</Version>
    </ModuleReference>
    <ModuleReference>
      <Name>hs.json</Name>
      <Version>1.0.0</Version>
    </ModuleReference>
    <ModuleReference>
      <Name>hs.mdm</Name>
      <Version>1.0.0</Version>
    </ModuleReference>
    <ModuleReference>
      <Name>hs.foo</Name>
      <Version>1.0.0</Version>
    </ModuleReference>
    <ModuleReference>
      <Name>hs.bar</Name>
      <Version>1.0.0</Version>
    </ModuleReference>
  </Dependencies>
</Module>
}

XData ServerModule200 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.bar</Name>
  <Version>2.0.0</Version>
  <Dependencies>
    <ModuleReference>
      <Name>hs.foo</Name>
      <Version>2.0.0</Version>
    </ModuleReference>
  </Dependencies>
  <Invoke Class="%IPM.Utils.Build" Method="Hang" />
</Module>
}

XData ServerModule201 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.foo</Name>
  <Version>2.0.0</Version>
  <Dependencies>
    <ModuleReference>
      <Name>hs.mdm</Name>
      <Version>1.0.1</Version>
    </ModuleReference>
  </Dependencies>
  <Invoke Class="%IPM.Utils.Build" Method="Hang" />
</Module>
}

XData ServerModule202 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>hs.everything</Name>
  <Version>1.0.1</Version>
  <Dependencies>
    <ModuleReference>
      <Name>hs.rest</Name>
      <Version>1.0.1</Version>
    </ModuleReference>
    <ModuleReference>
      <Name>hs.json</Name>
      <Version>1.1.3</Version>
    </ModuleReference>
    <ModuleReference>
      <Name>hs.mdm</Name>
      <Version>1.0.1</Version>
    </ModuleReference>
    <ModuleReference>
      <Name>hs.foo</Name>
      <Version>2.0.0</Version>
    </ModuleReference>
    <ModuleReference>
      <Name>hs.bar</Name>
      <Version>2.0.0</Version>
    </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("hs.mdm 1.0.1")
/// @AssertDependsOn("hs.json 1.1.4")
/// @AssertCompileOK
XData LocalModule1 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>*</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("hs.mdm 1.0.0")
/// @AssertDependsOn("hs.json 1.0.0")
/// @AssertCompileOK
XData LocalModule2 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("hs.mdm 1.0.1")
/// @AssertDependsOn("hs.json 1.1.4")
/// @AssertCompileOK
XData LocalModule3 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("hs.mdm 1.0.1")
/// @AssertDependsOn("hs.json 1.1.1")
/// @AssertCompileOK
XData LocalModule4 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.json</Name>
  <Version>1.1.1</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>hs.mdm</Name>
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
  <Name>hs.json</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("hs.rest 1.0.1")
/// @AssertDependsOn("hs.mdm 1.0.1")
/// @AssertDependsOn("hs.json 1.1.3")
/// @AssertCompileOK
XData LocalModule6 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.rest</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("hs.rest 1.0.1")
/// @AssertDependsOn("hs.mdm 1.0.1")
/// @AssertDependsOn("hs.json 1.1.3")
/// @AssertCompileOK
XData LocalModule7 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.rest</Name>
  <Version>1.*</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>1.*</Version>
  </ModuleReference>
  
  <!-- The below ModuleReference is required in order for the hs.rest/hs.mdm combination above to be resolved. Ideally it would not be, but with the same result. -->
  <ModuleReference>
  <Name>hs.json</Name>
  <Version>1.1.3</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("hs.rest 1.0.0")
/// @AssertDependsOn("hs.mdm 1.0.0")
/// @AssertDependsOn("hs.json 1.0.0")
/// @AssertCompileOK
XData LocalModule8 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>hs.rest</Name>
  <Version>1.*</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("hs.rest 1.0.0")
/// @AssertDependsOn("hs.mdm 1.0.0")
/// @AssertDependsOn("hs.json 1.0.0")
/// @AssertCompileOK
XData LocalModule9 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>1.*</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>hs.rest</Name>
  <Version>1.0.0</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertDependsOn("hs.rest 1.0.0")
/// @AssertDependsOn("hs.mdm 1.0.0")
/// @AssertDependsOn("hs.json 1.0.0")
/// @AssertCompileOK
XData LocalModule10 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>1.*</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>hs.rest</Name>
  <Version>1.0.x</Version>
  </ModuleReference>
  <ModuleReference>
  <Name>hs.json</Name>
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

/// @AssertInstalledBefore("hs.json 1.1.1")
/// @AssertDependsOn("hs.json 1.1.1")
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
  <Name>hs.mdm</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertInstalledBefore("hs.json 1.0.0")
/// @AssertDependsOn("hs.json 1.1.4")
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
  <Name>hs.mdm</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertUnresolvable
/// @AssertCompileNotOK
/// @AssertInstalledBefore("hs.rest 1.0.0")
XData LocalModule14 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<!-- Test case: Resolving dependencies will fail rather than upgrading an installed version to a version incompatible with other installed software -->
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

/// @AssertCompileNotOK
/// @AssertInstalledBefore("hs.json 2.0.0")
/// @AssertDependsOn("hs.json 1.1.4")
/// @AssertDependsOn("hs.mdm 1.0.1")
XData LocalModule15 [ XMLNamespace = "http://www.intersystems.com/PackageManager" ]
{
<?xml version="1.0"?>
<!-- Test case: Resolving dependencies to downgrade an installed version does not work -->
<Module>
  <Name>Demo</Name>
  <Version>0.0.1+snapshot</Version>
  <Dependencies>
  <ModuleReference>
  <Name>hs.mdm</Name>
  <Version>1.0.1</Version>
  </ModuleReference>
  </Dependencies>
</Module>
}

}
