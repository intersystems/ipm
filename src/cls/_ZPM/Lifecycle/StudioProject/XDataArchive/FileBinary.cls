Class %ZPM.Lifecycle.StudioProject.XDataArchive.FileBinary Extends %ZPM.Lifecycle.StudioProject.XDataArchive.IFile
{

Parameter STREAMCLASS As STRING = "%Stream.FileBinary";

Property File As %Stream.GlobalBinary(XMLPROJECTION = "CONTENT");

ClassMethod WriteToStream(pFile As %String, pStream As %Stream.Object) As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		Set tSrcFileStream = ##class(%Stream.FileBinary).%New()
		$$$ThrowOnError(tSrcFileStream.LinkToFile(pFile))
		Set tInstance = ..%New()
		Do tInstance.File.CopyFrom(tSrcFileStream)
		$$$ThrowOnError(tInstance.XMLExportToStream(pStream))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
