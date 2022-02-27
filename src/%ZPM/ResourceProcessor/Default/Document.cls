Class %ZPM.ResourceProcessor.Default.Document Extends %ZPM.ResourceProcessor.AbstractCompilable
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Default resource processor class for %Studio.AbstractDocument subclasses";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Compile,CompileAfter,Flags,ExportFlags,Directory,LoadAsDirectory,FilenameExtension,FilenameTranslateIdentifier,FilenameTranslateAssociator,Format";

/// May be set to determine the value of <property>Extension</property> based on a static value rather than based on the resource name.
/// The only expected use case at this point is class packages (.PKG, but Extension will be .CLS)
Parameter EXTENSION;

/// When a module is loaded in developer mode, this is appended to the resource name in ^Sources - e.g., ^Sources(..Extension, <resource name>_..#NAMEPOSTFIX)
/// The only expected use case at this point is class packages (.PKG, but Extension will be .CLS)
Parameter NAMEPOSTFIX;

/// If true, the resource will be compiled during the compilation phase in the module lifecycle.
Property Compile As %Boolean [ InitialExpression = 1 ];

/// Directory relative to module root containing the exported resource.
/// Defaults to the resource's extension (lower-case) if unspecified.
Property Directory As %String(MAXLEN = "") [ InitialExpression = {$ZConvert(..#EXTENSION,"L")} ];

/// If true (default is false), the resource is loaded as a directory.
Property LoadAsDirectory As %Boolean [ InitialExpression = 0 ];

/// Characters in the filename to use as the identifier in $translate when determining the resource's filename on disk
/// The default behavior is to replace "." with "/" and ignore "%"
Property FilenameTranslateIdentifier As %String [ InitialExpression = ".%" ];

/// Characters in the filename to use as the associator in $translate when determining the resource's filename on disk
/// The default behavior is to replace "." with "/" and ignore "%"
Property FilenameTranslateAssociator As %String [ InitialExpression = "/" ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "xml" ];

/// Export format - list of acceptable values may differ by subclass.
Property Format As %String;

/// Name of the server document (without extension)
Property Name As %String(MAXLEN = 255) [ Private ];

/// Extension of the server document(s) represented by this resource
Property Extension As %String [ Private ];

Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set pResourceHandled = 0
	Try {
		Set tVerbose = $Get(pParams("Verbose"),0)
		Set tDeveloperMode = $Get(pParams("DeveloperMode"),0)
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
    Set tRoot = ##class(%File).NormalizeDirectory(..ResourceReference.Module.SourcesRoot, ..ResourceReference.Module.Root)
		Set tInScope = ..ResourceReference.IsInScope(pPhase,.tInCurrentPhase)
		If ((pPhase = "Reload") && tInScope) || tInCurrentPhase {
			for tName=tName,$TRANSLATE(tName, "%", "_") {
				// Runs in Reload normally, and also in Test for test scope / Verify for verify scope
				Set tSourcesPrefix = $c($parameter("%ZPM.PackageManager.Developer.Extension.SourceControl.ISC","NOPREFIXCHARCODE"))
				
				If '$Get(pParams("NoMapping"),0) {
				// Disabled mapping of resources. It creates more problems than solves. 
				// Moreover, the removal of mapping during uninstallation is not implemented.
				// $$$ThrowOnError(..OnConfigureMappings(.pParams))
				}
				
				If '..ResourceReference.Generated {
					Set tSubDirectory = $Select(..ResourceReference.Preload:"preload/",1:"")
					Set tResourceDirectory = ##class(%File).NormalizeDirectory(tRoot_"/"_tSubDirectory)
					If ('##class(%File).DirectoryExists(tResourceDirectory)) {
						Quit 
					}

					Set tResourceCatDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory_..Directory_"/")
					if (##class(%File).DirectoryExists(tResourceCatDirectory)) {
						Set tResourceDirectory = tResourceCatDirectory
					} 
					ElseIf (..Directory="mac") {
						Set tResourceCatDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory_"rtn/")
						if (##class(%File).DirectoryExists(tResourceCatDirectory)) {
							Set tResourceDirectory = tResourceCatDirectory
						}
					}
			
					If tDeveloperMode && (..Extension '= "") && (tName '= "") {
						Set ^Sources(..Extension,tName_..#NAMEPOSTFIX) = tSourcesPrefix_tResourceDirectory
					}
					
					If '..ResourceReference.Preload {
						Set tFileExtension = $Select(..LoadAsDirectory:"",1:"."_..FilenameExtension)
						Set tResourcePath = ##class(%File).NormalizeFilename(tResourceDirectory _ tSubDirectory _ $tr(tName,..FilenameTranslateIdentifier,..FilenameTranslateAssociator))_tFileExtension
						If ($$$lcase(tFileExtension)=".xml")&&('##class(%File).Exists(tResourcePath)) {
							Set $PIECE(tResourcePath, ".", *) = "cls"
							Set ..Format = "UDL"
						} 
						ElseIf ($$$lcase(tFileExtension)=".cls")&&('##class(%File).Exists(tResourcePath)) {
							Set $PIECE(tResourcePath, ".", *) = "xml"
							Set ..Format = "XML"
						}

						If ($$$lcase(tFileExtension)=".mac")&&('##class(%File).Exists(tResourcePath)) {
							Set $PIECE(tResourcePath, ".", *) = "rtn"
						}

						if '##class(%File).Exists(tResourcePath) {
							continue
						}

						$$$ThrowOnError(..OnLoad(tResourcePath,tVerbose,tInCurrentPhase,.tLoadedList))
						
						Set tSC = ##class(%ZPM.Storage.LoadedResource).TrackResourceNames(..ResourceReference.Module.Name,..ResourceReference.UniqueName,tLoadedList)
						$$$ThrowOnError(tSC)
					}
				}
				Set pResourceHandled = 1
				Quit
			}
		} ElseIf (pPhase = "Compile") {
			If tInScope {
				// If Compile is false, indicate that the resource's compilation phase has already been handled and nothing special should happen.
				Set pResourceHandled = '..Compile
			} Else {
				// If out of scope, nothing should happen.
				Set pResourceHandled = 1
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
  Set tExportFlags = "-d /diffexport"_..ExportFlags
  Set tVerbose = $Get(pParams("Verbose"),0)
	Try {
		If ..Format = "UDL" {
			// This is tailored toward support of "Other" documents exported in UDL format.
			If ##class(%Atelier.v1.Utils.General).ValidateDocName(pItemName,.tSC,.tCategory) {
				// Ensure directory containing file exists, and attempt to create it if not.
				If $Extract(pFullExportPath) = """" {
					// Avoid issues with the path being quoted. (These mess up GetDirectory().)
					Set pFullExportPath = $Extract(pFullExportPath,2,*-1)
				}
				
				Set tTargetDirectory = ##class(%Library.File).GetDirectory(pFullExportPath)
				If '##class(%Library.File).DirectoryExists(tTargetDirectory) {
					$$$ThrowOnError(##class(%ZPM.Utils.File).CreateDirectoryChain(tTargetDirectory))
				}
				
				$$$ThrowOnError($System.OBJ.ExportUDL(pItemName,pFullExportPath,tExportFlags))
			}
			Set pItemHandled = 1
		} ElseIf (..Format = "XML") {
			$$$ThrowOnError($System.OBJ.Export(pItemName,pFullExportPath,tExportFlags))
			Set pItemHandled = 1
		} ElseIf (..Format = "%RO") {
			Set tSC = $$Export^%apiRTN(pItemName,pFullExportPath,"Save for Source Control","WNSK\UTF8\",tExportFlags)
			Set pItemHandled = 1
		}
    Write:tVerbose !,"Exporting '",pItemName,"' to '",pFullExportPath,"'"
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
	Quit $$$OK
}

/// Subclasses may override to customize resource load behavior during the Reload phase. <br />
/// @Argument	pFullResourcePath			The absolute path to the resource present on the file system
/// @Argument	pVerbose					1: display output from loading files, 0: do not display output
/// @Argument	pCompile					1: compile files upon load, 0: do not compile files
/// @Argument	pLoadedList					Output: comma delimited list of files that have been loaded
Method OnLoad(pFullResourcePath As %String, pVerbose As %Boolean, pCompile As %Boolean = 0, Output pLoadedList As %String) As %Status
{
	Set pLoadedList = ""
	Set tSC = $$$OK
	Try {
		// Workaround: need to clean up after other UDL import/export operations
		Kill ^||%oddDEF
    Set tFlags = $Select(pVerbose:"/display",1:"/nodisplay")_
      $Select(pCompile:"/compile",1:"/nocompile")_
      $Select($TLevel:"/multicompile=0",1:"")

    If ..LoadAsDirectory {
      Set tSC = $System.OBJ.ImportDir(pFullResourcePath, "*", tFlags, , 1, .pLoadedList)
      $$$ThrowOnError(tSC)
      If $Data(pLoadedList)>1 {
        Merge tResult = pLoadedList
        Set pLoadedList = ""
      }
    } ElseIf (..Format = "%RO") {
      // This tolerates some unusual %RO header formats that $System.OBJ.Load does not respect.
      Set pLoadedList = ""
      Set tSC = $$Import^%apiRTN(pFullResourcePath,"replace,compile="_pCompile,,,.tResult,$Select(pVerbose:"d",1:"-d"))
    } Else {
      Set tSC = $System.OBJ.Load(pFullResourcePath,tFlags,,.pLoadedList)
      $$$ThrowOnError(tSC)
    }
    If $Data(tResourceKey)>1 {
      Set tResourceKey = ""
      For {
        Set tResourceKey = $Order(tResult(tResourceKey))
        If (tResourceKey = "") {
          Quit
        }
        Set pLoadedList = pLoadedList_$ListBuild(tResourceKey)
      }
      Set pLoadedList = $ListToString(pLoadedList)
    }

		If $Data(pLoadedList)#2 {
			Do ..ResourceReference.UpdateChildrenFromString(pLoadedList)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %OnNew(pResourceReference As %ZPM.Storage.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
	Set tResourceRefName = pResourceReference.Name
	// Set LoadAsDirectory to 1 if resource reference name is a path. 
	// Else, get name and extension from resource reference name
	If $Extract(tResourceRefName) = "/" {
		Set ..LoadAsDirectory = 1
		Set ..Directory = tResourceRefName
		Set tSC = ##super(pResourceReference)
		If (..Extension = "") {
			Set ..Extension = $$$lcase(..#EXTENSION)
		}
	} Else {
		Set ..Name = $Piece(tResourceRefName,".",1,*-1)
		Set ..Extension = $$$lcase($Case(..#EXTENSION,"":$Piece(tResourceRefName,".",*),:..#EXTENSION))
		Set tSC = ##super(pResourceReference)
		If (..Directory = "") {
			Set ..Directory = $ZConvert(..Extension,"L")
      if $lf($lb("dtl","bpl"),..Directory) {
        set ..Directory = "cls"
      }
		}
	}
	Quit tSC
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		If (pPhase = "Validate") {
			If (..Extension = "") {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid resource name '%1' - must have a file extension to identify the Studio document type.",..Name))
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Enumerate all documents contained in the resource being processed. <br />
/// @Argument	pResourceArray			ByRef: array of the following format: pResourceArray(<Studio document name>) = <module that contains document>
/// pResourceArray(<Studio document name>, <resource referenty property>) = value of resource reference property for given document
Method OnResolveChildren(ByRef pResourceArray) As %Status
{
	If ..LoadAsDirectory {
		Kill pResourceArray(..ResourceReference.Name)
		Set tKey = ""
		While 1 {
			Do ..ResourceReference.Children.GetNext(.tKey)
			Quit:(tKey = "")
			Set pResourceArray(tKey) = ..ResourceReference.Module.Name
			Set pResourceArray(tKey,"Processor") = ..ResourceReference.Processor
			Set pResourceArray(tKey,"Generated") = ..ResourceReference.Generated
			Set pResourceArray(tKey,"Preload") = ..ResourceReference.Preload
			Set pResourceArray(tKey,"Scope") = ..ResourceReference.Scope
			Set pResourceArray(tKey,"Deploy") = ..ResourceReference.Deploy
			Set pResourceArray(tKey,"RelativePath") = ..OnItemRelativePath(tKey)
		}
	} Else {
		// Add the relative path for purposes of lifecycle %Export method
		Set pResourceArray(..ResourceReference.Name,"RelativePath") = ..OnItemRelativePath(..ResourceReference.Name)
	}
	Quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
	Set tFileExtension = $Select(..LoadAsDirectory:"",1:"."_..FilenameExtension)
  Set tSourceRoot = ..ResourceReference.Module.SourcesRoot
	If tSourceRoot'="","\/"'[$EXTRACT(tSourceRoot, *) {
		Set tSourceRoot = tSourceRoot _ "/"
	}  
	Quit $Select(..ResourceReference.Preload:"preload/",1:"")_tSourceRoot_..Directory_"/"_$tr($Piece(pItemName,".",1,*-1),..FilenameTranslateIdentifier,..FilenameTranslateAssociator)_tFileExtension
}

Method GetSourceControlInfo(Output pInfo As %ZPM.PackageManager.Developer.Extension.SourceControl.ResourceInfo) As %Status
{
	Set pInfo = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ResourceInfo).%New()
	Set pInfo.SourceControlAware = 1
	Set pInfo.RelativePath = ..Directory
	Set pInfo.ResourceType = ..Extension
	Set pInfo.Prefix = ..Name_..#NAMEPOSTFIX
	If (..ResourceReference.Preload) {
		Set pInfo.RelativePath = "/preload/"_pInfo.RelativePath
	}
	Quit $$$OK
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
	If ($Extract(..ResourceReference.Name) = "/") {
		Set pUniqueName = ..ResourceReference.Module.Name_"@"_..ResourceReference.Name
	}
}

}
