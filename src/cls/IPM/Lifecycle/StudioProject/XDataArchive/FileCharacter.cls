Class %IPM.Lifecycle.StudioProject.XDataArchive.FileCharacter Extends %IPM.Lifecycle.StudioProject.XDataArchive.IFile
{

Parameter STREAMCLASS As STRING = "%Stream.FileCharacter";

Property File As %Stream.GlobalCharacter(XMLPROJECTION = "CONTENT");

ClassMethod WriteToStream(
	pFile As %String,
	pStream As %Stream.Object) As %Status [ Private ]
{
    set tSC = $$$OK
    try {
        set tSrcFileStream = ##class(%Stream.FileCharacter).%New()
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
