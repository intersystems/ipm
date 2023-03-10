Class %IPM.Lifecycle.StudioProject.XDataArchive.FileCharacter Extends %IPM.Lifecycle.StudioProject.XDataArchive.IFile
{

Parameter STREAMCLASS As STRING = "%Stream.FileCharacter";

Property File As %Stream.GlobalCharacter(XMLPROJECTION = "CONTENT");

ClassMethod WriteToStream(pFile As %String, pStream As %Stream.Object) As %Status [ Private ]
{
	Set tSC = $$$OK
	Try {
		Set tSrcFileStream = ##class(%Stream.FileCharacter).%New()
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
