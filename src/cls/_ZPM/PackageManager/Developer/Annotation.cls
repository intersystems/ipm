Class %ZPM.PackageManager.Developer.Annotation Extends %SerialObject
{

Property Classname As %Dictionary.CacheClassname [ Required ];

Property MemberType As %String(VALUELIST = ",ForeignKey,Index,Method,Parameter,Projection,Property,Query,Storage,Trigger,XData");

Property MemberName As %Dictionary.CacheIdentifier;

Property Tag As %String(MAXLEN = 50) [ Required ];

Property Value As %String(MAXLEN = "");

Storage Default
{
<Data name="AnnotationState">
<Value name="1">
<Value>Classname</Value>
</Value>
<Value name="2">
<Value>MemberType</Value>
</Value>
<Value name="3">
<Value>MemberName</Value>
</Value>
<Value name="4">
<Value>Tag</Value>
</Value>
<Value name="5">
<Value>Value</Value>
</Value>
</Data>
<State>AnnotationState</State>
<StreamLocation>^ZPM.PackageManager.Deve78FE.AnnotationS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
