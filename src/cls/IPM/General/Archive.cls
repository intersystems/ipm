Class %IPM.General.Archive Extends %IPM.General.IConfigurable
{

/// Creates an archive with the contents of <var>pSourceDirectory</var> in <var>pArchiveFileName</var>
ClassMethod Create(pSourceDirectory As %String, pArchiveFileName As %String, Output pOutput) As %Status
{
	Set tSC = $$$OK
	Try {
		Kill pOutput
		Set pOutput = 0
		
		If ($Get(pSourceDirectory) = "") {
			Set tSC = $$$ERROR($$$GeneralError,"Source directory not specified.")
			Quit
		}
		If ($Get(pArchiveFileName) = "") {
			Set tSC = $$$ERROR($$$GeneralError,"Archive filename not specified.")
			Quit
		}
		If '##class(%File).DirectoryExists(pSourceDirectory) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Directory %1 does not exist",pArchiveFileName))
			Quit
		}
		Set pSourceDirectory = ##class(%File).NormalizeFilenameWithSpaces(##class(%File).NormalizeDirectory(pSourceDirectory))
		Set pArchiveFileName = ##class(%File).NormalizeFilenameWithSpaces(pArchiveFileName)

		set archive = ##class(%IPM.Utils.FileBinaryTar).Compact(pSourceDirectory, 1, pArchiveFileName, pSourceDirectory)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Extracts the contents of <var>pArchiveFileName</var> into <var>pTargetDirectory</var>
ClassMethod Extract(pArchiveFileName As %String, pTargetDirectory As %String, Output pOutput) As %Status
{
	Set tSC = $$$OK
	Try {
		Kill pOutput
		Set pOutput = 0
		If ($Get(pArchiveFileName) = "") {
			Set tSC = $$$ERROR($$$GeneralError,"Archive filename not specified.")
			Quit
		}
		If ($Get(pTargetDirectory) = "") {
			Set tSC = $$$ERROR($$$GeneralError,"Target directory not specified.")
			Quit
		}
		If '##class(%File).DirectoryExists(pTargetDirectory) {
			Set tResult = ##class(%File).CreateDirectoryChain(pTargetDirectory,.tReturn)
			If 'tResult {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",pTargetDirectory,tReturn))
				Quit
			}
		}
		If $ISOBJECT(pArchiveFileName),pArchiveFileName.%IsA("%Stream.Object") {
			Set tStream = ##class(%Stream.FileBinary).%New()
			Set tStream.Filename = ##class(%File).TempFilename("tgz")
			Do tStream.CopyFromAndSave(pArchiveFileName)
			Set tStream2 = ##class(%Stream.FileBinaryGzip).%New()
			Set tStream2.Filename = tStream.Filename
			Set extracted = ##class(%IPM.Utils.FileBinaryTar).ExtractStream(tStream2, pTargetDirectory)
		} Else {
			Set extracted = ##class(%IPM.Utils.FileBinaryTar).ExtractFile(pArchiveFileName, 1, pTargetDirectory)			
		}
		
		//set tSC = extracted.ExtractTo(pTargetDirectory)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
