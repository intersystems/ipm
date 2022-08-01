Class %ZPM.PackageManager.Developer.ErrorMessages.MessageFileStream Extends %ZPM.PackageManager.Developer.Document.AbstractStream
{

ClassMethod Convert(pFilePath As %String, pSave As %Boolean = 1, Output pObject As %ZPM.PackageManager.Developer.ErrorMessages.MessageFileStream) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tFileName = $Piece(##class(%File).GetFilename(pFilePath),".xml")
		Set tSourceStream = ##class(%Stream.FileCharacter).%New()
		Set tSC = tSourceStream.LinkToFile(pFilePath)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If ..NameExists(tFileName) {
			Set pObject = ..NameOpen(tFileName,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			Set pObject = ..%New()
			Set pObject.Name = $Piece(##class(%File).GetFilename(pFilePath),"xml")
		}
		Set tSC = pObject.Contents.CopyFrom(tSourceStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pSave) {
			Set tSC = pObject.%Save()
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If $$$ISERR(tSC) {
		Set pObject = $$$NULLOREF
	}
	Quit tSC
}

Storage Default
{
<Data name="MessageFileStreamDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Contents</Value>
</Value>
<Value name="4">
<Value>LastModifiedTimestamp</Value>
</Value>
<Value name="5">
<Value>Hash</Value>
</Value>
</Data>
<DataLocation>^ZPM.Dev.MsgFileD</DataLocation>
<DefaultData>MessageFileStreamDefaultData</DefaultData>
<IdLocation>^ZPM.Dev.MsgFileD</IdLocation>
<IndexLocation>^ZPM.Dev.MsgFileI</IndexLocation>
<StreamLocation>^ZPM.Dev.MsgFileS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
