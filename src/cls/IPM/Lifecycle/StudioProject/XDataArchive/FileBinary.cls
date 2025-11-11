Class %IPM.Lifecycle.StudioProject.XDataArchive.FileBinary Extends %IPM.Lifecycle.StudioProject.XDataArchive.IFile
{

Parameter STREAMCLASS As STRING = "%Stream.FileBinary";

Property File As %Stream.GlobalBinary(XMLPROJECTION = "CONTENT");

ClassMethod WriteToStream(
	pFile As %String,
	pStream As %Stream.Object) As %Status [ Private ]
{
    set tSC = $$$OK
    try {
        set tSrcFileStream = ##class(%Stream.FileBinary).%New()
        $$$ThrowOnError(tSrcFileStream.LinkToFile(pFile))
        set tInstance = ..%New()
        do tInstance.File.CopyFrom(tSrcFileStream)
        $$$ThrowOnError(tInstance.XMLExportToStream(pStream))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
