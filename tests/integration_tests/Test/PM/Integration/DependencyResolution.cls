Class Test.PM.Integration.DependencyResolution Extends Test.PM.Integration.Base
{

Method TestEverything()
{
	#dim tModule As %ZPM.PackageManager.Developer.Module
	New $Namespace
	Set tOrigNS = $Namespace
	Try {
		If '$$$AssertStatusOK(..Setup()) {
			Quit
    }
    
    Do ..PublishModules()
  
		// Get annotations for local module XDATA blocks; put into array by module (XDATA) name.
		If '$$$AssertStatusOK(##class(%ZPM.PackageManager.Developer.Annotation.Utils).ExtractAnnotations($classname(),.tAnnotationList)) {
			Quit
    }
    
		Kill tAssertArray
		
		For i=1:1:tAnnotationList.Count() {
			#dim tAnnotation As %ZPM.PackageManager.Developer.Annotation
			Set tAnnotation = tAnnotationList.GetAt(i)
			If (tAnnotation.MemberType = "XData") {
				Set tAssertArray(tAnnotation.MemberName,$i(tAssertArray(tAnnotation.MemberName))) = $ListBuild(tAnnotation.Tag,$$$lcase(tAnnotation.Value))
			}
    }
    
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
          
					Set tQualRef = ##class(%ZPM.PackageManager.Core.QualifiedModuleReference).%New()
					Set tQualRef.ServerName = ..#REGISTRYNAME
					Set tQualRef.Name = $Piece(tAssertValue," ",1)
					Set tQualRef.VersionString = $Piece(tAssertValue," ",2)
					Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).LoadQualifiedReference(tQualRef)
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
					
					Set tQualRef = ##class(%ZPM.PackageManager.Core.QualifiedModuleReference).%New()
					Set tQualRef.ServerName = ..#REGISTRYNAME
					Set tQualRef.Name = $Piece(tAssertValue," ",1)
					Set tQualRef.VersionString = $Piece(tAssertValue," ",2)
					Set tSC = ##class(%ZPM.PackageManager.Developer.Utils).LoadQualifiedReference(tQualRef)
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
	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"An exception occurred.")
	}
	
	// Cleanup
	Set $Namespace = tOrigNS
	Do $$$AssertStatusOK(..TearDown())
}

Method PublishModules()
{
  Set tOrigNS = $Namespace
  do ##class(%ZPM.PackageManager.Server.Module).%DeleteExtent()
  // Publish modules
  For i=1:1:11,100:1:103 {
    // If we're loading a module with dependencies, clear out things that might have conflicting dependencies first.
    Do ..UtilUninstallAll()
    
    Quit:'$$$AssertStatusOK(..ReadXDataToModule(tOrigNS,"ServerModule"_i,.tModule),"Loaded module from XData block ServerModule"_i)
    
    // Publish module
    Do $$$AssertStatusOK(tModule.Lifecycle.Publish(),"Published "_tModule.Name_" "_tModule.VersionString)
  }
}

Method UtilUninstallAll()
{
	For tModName = "Demo","HS.REST","HS.MDM","HS.JSON" {
		If ##class(%ZPM.PackageManager.Developer.Module).NameExists($$$lcase(tModName)) {
			Do $$$AssertStatusOK(##class(%ZPM.PackageManager.Developer.Module).Uninstall(tModName))
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
