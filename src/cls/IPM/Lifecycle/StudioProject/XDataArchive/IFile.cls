/// Abstract representation of a file included in an XData archive.
/// Subclasses may customize the stream type.
Class %IPM.Lifecycle.StudioProject.XDataArchive.IFile Extends (%RegisteredObject, %XML.Adaptor) [ Abstract ]
{

Parameter STREAMCLASS As STRING [ Abstract ];

ClassMethod IngestToStream(
	pFile As %String,
	pStream As %Stream.Object) As %Status [ Final ]
{
    for tTextType = "xml","htm","html","js","css","json","csv","cls","mac","inc","csp" {
        set tTextTypes(tTextType) = ""
    }
    set tExtension = $piece(pFile,".",*)
    if (tExtension '= "") && $data(tTextTypes(tExtension)) {
        quit ##class(%IPM.Lifecycle.StudioProject.XDataArchive.FileCharacter).WriteToStream(pFile,pStream)
    }
    quit ##class(%IPM.Lifecycle.StudioProject.XDataArchive.FileBinary).WriteToStream(pFile,pStream)
}

ClassMethod Extract(
	pDirectory As %String,
	pXData As %Dictionary.XDataDefinition) As %Status [ Final ]
{
    set tSC = $$$OK
    try {
        set tReader = ##class(%XML.Reader).%New()
        do tReader.Correlate("FileCharacter","%IPM.Lifecycle.StudioProject.XDataArchive.FileCharacter")
        do tReader.Correlate("FileBinary","%IPM.Lifecycle.StudioProject.XDataArchive.FileBinary")
        $$$ThrowOnError(tReader.OpenStream(pXData.Data))
        while tReader.Next(.tObject,.tSC) {
            $$$ThrowOnError(tSC)
            set tFileName = ##class(%Library.File).NormalizeFilename(##class(%Library.File).NormalizeDirectory(pDirectory)_pXData.Description)
            $$$ThrowOnError(tObject.WriteToFile(tFileName))
        }
        $$$ThrowOnError(tSC)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod WriteToStream(
	pFile As %String,
	pStream As %Stream.Object) As %Status [ Abstract, Private ]
{
}

Method WriteToFile(pFile As %String) As %Status [ Private ]
{
    set tSC = $$$OK
    try {
        set tDirectory = ##class(%Library.File).GetDirectory(pFile)
        if '##class(%Library.File).DirectoryExists(tDirectory) {
            $$$ThrowOnError(##class(%IPM.Lifecycle.StudioProject.XDataArchive).CreateDirectoryChain(tDirectory))
        }
        set tDestFileStream = $classmethod(..#STREAMCLASS,"%New")
        $$$ThrowOnError(tDestFileStream.LinkToFile(pFile))
        $$$ThrowOnError(tDestFileStream.CopyFromAndSave(..File))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
