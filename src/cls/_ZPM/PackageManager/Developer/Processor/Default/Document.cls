Class %ZPM.PackageManager.Developer.Processor.Default.Document Extends %ZPM.PackageManager.Developer.Processor.AbstractCompilable
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Default resource processor class for %Studio.AbstractDocument subclasses";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Compile,CompileAfter,Flags,Directory,LoadAsDirectory,FilenameExtension,FilenameTranslateIdentifier,FilenameTranslateAssociator,Format";

/// May be set to determine the value of <property>Extension</property> based on a static value rather than based on the resource name.
/// The only expected use case at this point is class packages (.PKG, but Extension will be .CLS)
Parameter EXTENSION;

/// If true, the resource will be compiled during the compilation phase in the module lifecycle.
Property Compile As %Boolean [ InitialExpression = 1 ];

/// Directory relative to module root containing the exported resource.
/// Defaults to the resource's extension (lower-case) if unspecified.
Property Directory As %String(MAXLEN = "");

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
		Set tName = $TRANSLATE(tName, "%", "_")
		Set tRoot = ##class(%File).NormalizeDirectory(..ResourceReference.Module.SourcesRoot, ..ResourceReference.Module.Root)
		If (pPhase = "Reload") {
			Set tGlobalScope = ..ResourceReference.Module.GlobalScope && '$Get(pParams("Reload","ForceLocalScope"),0)
			
			$$$ThrowOnError(..OnConfigureMappings(.pParams))
			
			If '..ResourceReference.Generated {
				Set tSubDirectory = $Select(..ResourceReference.Preload:"preload/",1:"")
				Set tResourceDirectory = ##class(%File).NormalizeDirectory(tRoot_"/"_tSubDirectory_..Directory_"/")
				
				If '..ResourceReference.Preload {
					Set tFileExtension = $Select(..LoadAsDirectory:"",1:"."_..FilenameExtension)
					Set tResourcePath = ##class(%File).NormalizeFilename(tResourceDirectory_$tr(tName,..FilenameTranslateIdentifier,..FilenameTranslateAssociator))_tFileExtension
					If ($$$lcase(tFileExtension)=".xml")&&('##class(%File).Exists(tResourcePath)) {
						Set $PIECE(tResourcePath, ".", *) = "cls"
						Set ..Format = "UDL"
					}

					Set tResourceParentPath = ##class(%File).ParentDirectoryName(tResourcePath)

					$$$ThrowOnError(..OnLoad(tResourcePath,tVerbose,.tHandled))
					If 'tHandled {
						If (..Format = "UDL") {
							// This is tailored toward support of "Other" documents exported in UDL format.
							// NOTE: Does not support LoadAsDirectory in the general implementation, although subclasses (e.g., Package) may.
							Set tDocName = ..ResourceReference.Name
							Set tList = ""
							If (tDocName [ "*") {
								set tWildcards = tDocName
								if $$$isUNIX set tWildcards = $$$ucase(tWildcards)_";"_$$$lcase(tWildcards)
								do ##class(%ZPM.PackageManager.Developer.File).FindFiles(tResourceParentPath, tWildcards, .tList)
							} Else {
								set tList($i(tList)) = $LISTBUILD(tDocName, tResourcePath) 
							}

							For i=1:1:tList {
								set $LISTBUILD(tDocName, tResourcePath) = tList(i)
								If ($$$ucase($Piece(tDocName, ".", *)) = "DFI") {
									Set tDocName = $Translate($Piece(tResourcePath, tResourceParentPath, 2), "-\", "_/")
									If (tDocName [ "/") {
										Set tDocName = $Piece(tDocName, "/", 1, *-1) _ "-" _ $Piece(tDocName, "/", *)
									}
								}

								// Slimmed down version of %Api.Atelier.v1:PutDoc
								If ##class(%Atelier.v1.Utils.General).ValidateDocName(tDocName,.tSC,.tCategory) {
									Set tFileStream = ##class(%Stream.FileCharacter).%New()
									$$$ThrowOnError(tFileStream.LinkToFile(tResourcePath))
									Kill tDocArray
									While 'tFileStream.AtEnd {
										Set tDocArray($i(tDocArray(0))) = tFileStream.ReadLine($$$MaxLocalLength,.tSC)
										$$$ThrowOnError(tSC)
									}
									Set tSC = ##class(%Atelier.v1.Utils.TextServices).SetTextFromArray(.tDocArray,,tDocName,tCategory)
									$$$ThrowOnError(tSC)
									If tVerbose {
										Write !,"Loaded "_tDocName
									}
								}
							}
						} Else {
							Set tFlags = $Select(tVerbose:"/display",1:"/nodisplay")_"/nocompile"
							If ..LoadAsDirectory {
								Set tSC = $System.OBJ.LoadDir(tResourcePath,tFlags,.tErrors,1)
							} Else {
								Set tSC = $System.OBJ.Load(tResourcePath,tFlags,.tErrors)
							}
							For i=1:1:$Get(tErrors) {
								Write !,tErrors(i)
							}
							$$$ThrowOnError(tSC)
						}
					}
				}
			}
			Set pResourceHandled = 1
		} ElseIf (pPhase = "Compile") {
			// If Compile is false, indicate that the resource's compilation phase has already been handled and nothing special should happen.
			Set pResourceHandled = '..Compile
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		#; if $$$lcase($p(pItemName,".",*))="dfi" write !,pItemName," -> ",pFullExportPath
		If ..Format = "UDL" {
			// This is tailored toward support of "Other" documents exported in UDL format.
			// Slimmed down version of %Api.Atelier.v1:GetDoc
			If ##class(%Atelier.v1.Utils.General).ValidateDocName(pItemName,.tSC,.tCategory) {
				// Ensure directory containing file exists, and attempt to create it if not.
				If $Extract(pFullExportPath) = """" {
					// Avoid issues with the path being quoted. (These mess up GetDirectory().)
					Set pFullExportPath = $Extract(pFullExportPath,2,*-1)
				}
				Set tTargetDirectory = ##class(%Library.File).GetDirectory(pFullExportPath)
				If '##class(%Library.File).DirectoryExists(tTargetDirectory) {
					// TODO: Use cleaner/more robust method for this?
					Set tGood = ##class(%Library.File).CreateDirectoryChain(tTargetDirectory,.tReturn)
					If 'tGood {
						Set tMsg = $$$FormatText("Could not create directory '%1': %2",tTargetDirectory,$zu(209,tReturn))
						$$$ThrowStatus($$$ERROR($$$GeneralError,tMsg))
					}
				}
				
				If ($SYSTEM.Version.GetMajor()<2017) {
					Set tFileStream = ##class(%Stream.FileCharacter).%New()
					$$$ThrowOnError(tFileStream.LinkToFile(pFullExportPath))
					Set tSC = ##class(%Atelier.v1.Utils.TextServices).GetTextAsArray(pItemName,,.tDocArray)
					$$$ThrowOnError(tSC)
					
					For tLine=1:1:tDocArray(0) {
						Do tFileStream.WriteLine(tDocArray(tLine))
					}
					$$$ThrowOnError(tFileStream.%Save())					
				} Else {
					$$$ThrowOnError($SYSTEM.OBJ.ExportUDL(pItemName, pFullExportPath, "-d"))
				}
				If tVerbose {
					WRITE !,"Exported '",pItemName,"' to ",pFullExportPath
				}
				Set pItemHandled = 1
			}
		}
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

/// Subclasses may override to customize resource load behavior during the Reload phase.
Method OnLoad(pFullResourcePath As %String, pVerbose As %Boolean, Output pHandled As %Boolean = 0) As %Status
{
	Quit $$$OK
}

Method %OnNew(pResourceReference As %ZPM.PackageManager.Developer.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
	Set ..Name = $Piece(pResourceReference.Name,".",1,*-1)
	Set ..Extension = $Case(..#EXTENSION,"":$Piece(pResourceReference.Name,".",*),:..#EXTENSION)
	Set tSC = ##super(pResourceReference)
	If (..Directory = "") {
		Set ..Directory = $ZConvert(..Extension,"L")
	}
	Quit tSC
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		If (pPhase = "Validate") {
			If ($Extract(..Name) = "/") {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid resource name '%1' - must be a Studio document type.",..Name))
				Quit
			}
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

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
	If ('$Data(pResourceArray(..ResourceReference.Name))) {
		Quit $$$OK
	}
	// Add the relative path for purposes of lifecycle %Export method
	Set tFileExtension = $Select(..LoadAsDirectory:"",1:"."_..FilenameExtension)
	Set tSourceRoot = ..ResourceReference.Module.SourcesRoot
	If tSourceRoot'="","\/"'[$EXTRACT(tSourceRoot, *) {
		Set tSourceRoot = tSourceRoot _ "/"
	}
	set tClassName = ..Name
	Set tClassName = $TRANSLATE(tClassName, "%", "_")
	Set pResourceArray(..ResourceReference.Name,"RelativePath") = tSourceRoot_..Directory_"/"_$tr(tClassName,..FilenameTranslateIdentifier,..FilenameTranslateAssociator)_tFileExtension
	Quit $$$OK
}

}
