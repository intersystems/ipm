/// Abstract representation of a file included in an XData archive.
/// Subclasses may customize the stream type.
Class %IPM.Lifecycle.StudioProject.XDataArchive.IFile Extends (%RegisteredObject, %XML.Adaptor) [ Abstract ]
{

Parameter STREAMCLASS As STRING [ Abstract ];

ClassMethod IngestToStream(pFile As %String, pStream As %Stream.Object) As %Status [ Final ]
{
	For tTextType = "xml","htm","html","js","css","json","csv","cls","mac","inc","csp" {
		Set tTextTypes(tTextType) = ""
	}
	Set tExtension = $Piece(pFile,".",*)
	If (tExtension '= "") && $Data(tTextTypes(tExtension)) {
		Quit ##class(%IPM.Lifecycle.StudioProject.XDataArchive.FileCharacter).WriteToStream(pFile,pStream)
	}
	Quit ##class(%IPM.Lifecycle.StudioProject.XDataArchive.FileBinary).WriteToStream(pFile,pStream)
}

ClassMethod Extract(pDirectory As %String, pXData As %Dictionary.XDataDefinition) As %Status [ Final ]
{
	Set tSC = $$$OK
	Try {
		Set tReader = ##class(%XML.Reader).%New()
		Do tReader.Correlate("FileCharacter","%IPM.Lifecycle.StudioProject.XDataArchive.FileCharacter")
		Do tReader.Correlate("FileBinary","%IPM.Lifecycle.StudioProject.XDataArchive.FileBinary")
		$$$ThrowOnError(tReader.OpenStream(pXData.Data))
		While tReader.Next(.tObject,.tSC) {
			$$$ThrowOnError(tSC)
			Set tFileName = ##class(%Library.File).NormalizeFilename(##class(%Library.File).NormalizeDirectory(pDirectory)_pXData.Description)
			$$$ThrowOnError(tObject.WriteToFile(tFileName))
		}
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod WriteToStream(pFile As %String, pStream As %Stream.Object) As %Status [ Abstract, Private ]
{
}

Method WriteToFile(pFile As %String) As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		Set tDirectory = ##class(%Library.File).GetDirectory(pFile)
		If '##class(%Library.File).DirectoryExists(tDirectory) {
			$$$ThrowOnError(##class(%IPM.Lifecycle.StudioProject.XDataArchive).CreateDirectoryChain(tDirectory))
		}
		Set tDestFileStream = $classmethod(..#STREAMCLASS,"%New")
		$$$ThrowOnError(tDestFileStream.LinkToFile(pFile))
		$$$ThrowOnError(tDestFileStream.CopyFromAndSave(..File))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
