Class %IPM.StudioDocument.ModuleStream Extends %IPM.StudioDocument.AbstractStream
{

Parameter DEFAULTGLOBAL = "^IPM.StudioDoc.ModuleStream";

Method UpdateVersion(semver As %IPM.General.SemanticVersion)
{
	Set regex = "<Version>(.*?)</Version>"
	Set content = ""
	Do ..Contents.Rewind()
	While '..Contents.AtEnd {
		Set content = content _ ..Contents.Read()
	}
	Set start = $LOCATE(content, regex, 0, end, val)
	If start {
		Set content = $EXTRACT(content, 1, start - 1) 
			_ "<Version>" _ semver.ToString() _ "</Version>" 
			_ $EXTRACT(content, end, *)
	} Else {
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Version tag not found in: "_content))
	}

	Do ..Contents.Clear()
	Do ..Contents.Rewind()
	Do ..Contents.Write(content)

	$$$ThrowOnError(..%Save())
}

Storage Default
{
<Data name="ModuleStreamDefaultData">
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
<Value>Hash</Value>
</Value>
<Value name="5">
<Value>LastModifiedTimestamp</Value>
</Value>
</Data>
<DataLocation>^IPM.StudioDoc.ModuleStreamD</DataLocation>
<DefaultData>ModuleStreamDefaultData</DefaultData>
<IdLocation>^IPM.StudioDoc.ModuleStreamD</IdLocation>
<IndexLocation>^IPM.StudioDoc.ModuleStreamI</IndexLocation>
<StreamLocation>^IPM.StudioDoc.ModuleStreamS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
