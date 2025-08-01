Class %IPM.StudioDocument.LocalizedMessageStream Extends %IPM.StudioDocument.AbstractStream
{

Parameter DEFAULTGLOBAL = "^IPM.StudioDoc.LocalMsgStream";

ClassMethod Convert(
	pFilePath As %String,
	pSave As %Boolean = 1,
	Output pObject As %IPM.StudioDocument.LocalizedMessageStream) As %Status
{
    set tSC = $$$OK
    try {
        set tFileName = $piece(##class(%File).GetFilename(pFilePath),".xml")
        set tSourceStream = ##class(%Stream.FileCharacter).%New()
        set tSC = tSourceStream.LinkToFile(pFilePath)
        if $$$ISERR(tSC) {
            quit
        }

        if ..NameExists(tFileName) {
            set pObject = ..NameOpen(tFileName,.tSC)
            if $$$ISERR(tSC) {
                quit
            }
        } else {
            set pObject = ..%New()
            set pObject.Name = $piece(##class(%File).GetFilename(pFilePath),"xml")
        }
        set tSC = pObject.Contents.CopyFrom(tSourceStream)
        if $$$ISERR(tSC) {
            quit
        }

        if (pSave) {
            set tSC = pObject.%Save()
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    if $$$ISERR(tSC) {
        set pObject = $$$NULLOREF
    }
    quit tSC
}

Storage Default
{
<Data name="LocalizedMessageStreamDefaultData">
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
<DataLocation>^IPM.StudioDoc.LocalMsgStreamD</DataLocation>
<DefaultData>LocalizedMessageStreamDefaultData</DefaultData>
<IdLocation>^IPM.StudioDoc.LocalMsgStreamD</IdLocation>
<IndexLocation>^IPM.StudioDoc.LocalMsgStreamI</IndexLocation>
<StreamLocation>^IPM.StudioDoc.LocalMsgStreamS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
