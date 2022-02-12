/// This class helps with packaging a directory (containing files) in a format that is easy to import on a different instance.
Class %IPM.Lifecycle.StudioProject.XDataArchive Extends %RegisteredObject
{

Property SourceDirectory As %String(MAXLEN = "") [ Private ];

Property Package As %String [ Private ];

/// <var>pDirectory</var> is the directory to be packaged.
Method %OnNew(pDirectory As %String) As %Status [ Private, ServerOnly = 1 ]
{
	Set ..SourceDirectory = pDirectory
	Quit $$$OK
}

/// Populates classes with the context of <property>SourceDirectory</property>, then adds the generated classes to <var>pStudioProject</var>.
Method AddToProject(pStudioProject As %Studio.Project, pVerbose As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		$$$ThrowOnError(..Populate(pVerbose))
		$$$ThrowOnError($System.OBJ.GetPackageList(.tItems,..Package))
		Set tKey = ""
		For {
			Set tKey = $Order(tItems(tKey))
			If (tKey = "") {
				Quit
			}
			$$$ThrowOnError(pStudioProject.AddItem(tKey,"CLS"))
		}
		$$$ThrowOnError(pStudioProject.%Save())
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Creates XData blocks with the contents of files in <property>SourceDirectory</property>
Method Populate(pVerbose As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		If (..SourceDirectory = "") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"A directory must be specified in %IPM.Lifecycle.StudioProject.XDataArchive:%OnNew."))
		}
		Set ..SourceDirectory = ##class(%Library.File).NormalizeDirectory(..SourceDirectory)
		If '##class(%Library.File).DirectoryExists(..SourceDirectory) {
			$$$ThrowStatus($$$ERROR($$$DirectoryNotExist,..SourceDirectory))
		}
		$$$ThrowOnError(..GetDirectoryContentsRecursive(..SourceDirectory,.tFiles))
		
		For {
			Set ..Package = "zTemp.PackageManager.StaticBundle"_$Increment(tCount)
			If ($Extract($Order(^oddDEF(..Package_".")),1,$Length(..Package)) '= ..Package) {
				Quit
			}
		}
		
		If pVerbose {
			Write !,"Converting "_..SourceDirectory_" to package: "_..Package,!
		}
		
		// Copy the requisite classes to the temp package name to support use in non-Package Manager contexts
		For tPostfix = "",".IFile",".FileBinary",".FileCharacter" {
			Set tSource = ##class(%Dictionary.ClassDefinition).%OpenId($classname()_tPostfix,,.tSC)
			$$$ThrowOnError(tSC)
			
			Set tTarget = tSource.%ConstructClone(1)
			Set tTarget.Name = ..Package_".XDataArchive"_tPostfix
			Set tTarget.Super = $Replace(tTarget.Super,$classname(),..Package_".XDataArchive")
			$$$ThrowOnError(tTarget.%Save())
			
			// Fix method lines individually
			Set tMethod = ""
			For {
				Set tMethod = $$$defMemberNext(tTarget.Name,$$$cCLASSmethod,tMethod)
				If (tMethod = "") {
					Quit
				}
				For tLine=1:1:$$$defMemberKeyGet(tTarget.Name,$$$cCLASSmethod,tMethod,$$$cMETHimplementation) {
					Set tLineCode = $Replace($$$defMemberArrayGet(tTarget.Name,$$$cCLASSmethod,tMethod,$$$cMETHimplementation,tLine),$classname(),..Package_".XDataArchive")
					$$$defMemberArraySet(tTarget.Name,$$$cCLASSmethod,tMethod,$$$cMETHimplementation,tLine,tLineCode)
				}
			}
		}
		
		// Load files
		Set tMaxBlocks = 255
		Set tBlockCount = 0
		Set tClassCount = 1
		Set tFileKey = ""
		For {
			Set tFileKey = $Order(tFiles(tFileKey),1,tFile)
			If (tFileKey = "") {
				Quit
			}
			If $Increment(tBlockCount) > tMaxBlocks {
				Set tBlockCount = 1
				Set tClassCount = tClassCount + 1
			}
			If (tBlockCount = 1) {
				Set tClass = ##class(%Dictionary.ClassDefinition).%New()
				Set tClass.Name = ..Package_".c"_tClassCount
			}
			Set tXData = ##class(%Dictionary.XDataDefinition).%New()
			Set tXData.Name = "b"_tBlockCount
			Set tXData.Description = tFile
			If pVerbose {
				Write !,"Converting file: ",tFile
			}
			$$$ThrowOnError(##class(%IPM.Lifecycle.StudioProject.XDataArchive.IFile).IngestToStream(..SourceDirectory_tFile,tXData.Data))
			Do tClass.XDatas.Insert(tXData)
			$$$ThrowOnError(tClass.%Save())
		}
		
		$$$ThrowOnError($System.OBJ.CompilePackage(..Package,"c-k-d"))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method GetDirectoryContentsRecursive(pDirectory As %String, Output pItems) As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		Kill pItems
		Set tFileResult = ##class(%Library.File).FileSetFunc(pDirectory,,1)
		If (tFileResult.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tFileResult.%SQLCODE,tFileResult.%Message)
		}
		While tFileResult.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			If (tFileResult.%Get("Type") = "D") {
				$$$ThrowOnError(..GetDirectoryContentsRecursive(tFileResult.%Get("Name"),.tItems))
				For tItem=1:1:$Get(tItems) {
					Set pItems($Increment(pItems)) = tFileResult.%Get("ItemName")_"/"_tItems(tItem)
				}
			} Else {
				Set pItems($Increment(pItems)) = tFileResult.%Get("ItemName")
			}
		}
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Copied from %IPM.Utils.File to support use in classes cloned from this one
ClassMethod CreateDirectoryChain(pName As %String) As %Status
{
	Set tSC = $$$OK
	If '##class(%Library.File).CreateDirectoryChain(pName,.tReturn) {
		Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",pName,$zu(209,tReturn)))
	}
	Quit tSC
}

Method GenerateInstallerCode(pDirectoryVariableName As %String, ByRef pRoutine) As %Status
{
	Set pRoutine($Increment(pRoutine)) = " $$$ThrowOnError(##class("_..Package_".XDataArchive).Extract("_pDirectoryVariableName_"))"
	Set pRoutine($Increment(pRoutine)) = " $$$ThrowOnError($System.OBJ.DeletePackage("_$$$QUOTE(..Package)_",""-d""))"
	Quit $$$OK
}

ClassMethod Extract(pTargetDirectory As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tPackage = $Piece($classname(),".",1,*-1)
		$$$ThrowOnError($System.OBJ.GetPackageList(.tClasses,tPackage))
		
		// Extract all files.
		Set tClassKey = ""
		For {
			Set tClassKey = $Order(tClasses(tClassKey))
			If (tClassKey = "") {
				Quit
			}
			Set tClassDef = ##class(%Dictionary.ClassDefinition).%OpenId(tClassKey,,.tSC)
			$$$ThrowOnError(tSC)
			
			Set tXDataKey = ""
			For {
				Set tXData = tClassDef.XDatas.GetNext(.tXDataKey)
				If (tXDataKey = "") {
					Quit
				}
				$$$ThrowOnError(##class(%IPM.Lifecycle.StudioProject.XDataArchive.IFile).Extract(pTargetDirectory,tXData))
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// This callback method is invoked by the <METHOD>%Close</METHOD> method to 
/// provide notification that the current object is being closed.
/// 
/// <P>The return value of this method is ignored.
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = $$$OK
	Try {
		If (..Package '= "") {
			Set tSC = $System.OBJ.DeletePackage(..Package,"-d")
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
