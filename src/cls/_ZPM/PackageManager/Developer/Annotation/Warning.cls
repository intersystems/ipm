/// warnings generated during annotation processing, by module
Class %ZPM.PackageManager.Developer.Annotation.Warning Extends %Persistent
{

Property ModuleName As %String;

Property WarningText As %String(MAXLEN = "");

Property OriginatingEntityIdentifierText As %String(MAXLEN = 500);

Index ModuleIndex On ModuleName;

Storage Default
{
<Data name="WarningDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ModuleName</Value>
</Value>
<Value name="3">
<Value>WarningText</Value>
</Value>
<Value name="4">
<Value>OriginatingEntityIdentifierText</Value>
</Value>
</Data>
<DataLocation>^%ZPM.Dev.Annotation.WarningD</DataLocation>
<DefaultData>WarningDefaultData</DefaultData>
<IdLocation>^%ZPM.Dev.Annotation.WarningD</IdLocation>
<IndexLocation>^%ZPM.Dev.Annotation.WarningI</IndexLocation>
<StreamLocation>^%ZPM.Dev.Annotation.WarningS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
