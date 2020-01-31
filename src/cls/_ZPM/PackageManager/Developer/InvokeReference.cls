Class %ZPM.PackageManager.Developer.InvokeReference Extends (%Persistent,%ZPM.PackageManager.Core.InvokeReference)
{
	Property Class As %String(XMLPROJECTION = "ATTRIBUTE", MAXLEN=255);
    Property Method As %String(XMLPROJECTION = "ATTRIBUTE", MAXLEN=255);
    Property Arg As list of %String(XMLNAME = "Arg",  XMLPROJECTION = "ELEMENT"); 
    
    Relationship Module As %ZPM.PackageManager.Developer.Module(XMLPROJECTION = "NONE")  [ Cardinality = parent, Inverse = Invokes ];

	Method GetArgsArray(args) as %Status {
		Set args = ..Arg.Count()
		For i=1:1:..Arg.Count() {
			Set args(i) = ..Arg.GetAt(i)
			If (args(i)=$c(0)) { Set args(i) = "" }
		}
	}

Storage Default
{
<Data name="InvokeReferenceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Class</Value>
</Value>
<Value name="3">
<Value>Method</Value>
</Value>
<Value name="4">
<Value>Arg</Value>
</Value>
</Data>
<DataLocation>{%%PARENT}("Invokes")</DataLocation>
<DefaultData>InvokeReferenceDefaultData</DefaultData>
<IdLocation>^%ZPM.PackageManager360D.ModuleC("Invokes")</IdLocation>
<IndexLocation>^%ZPM.Packa360D.InvokeRefer378FI</IndexLocation>
<StreamLocation>^%ZPM.Packa360D.InvokeRefer378FS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}