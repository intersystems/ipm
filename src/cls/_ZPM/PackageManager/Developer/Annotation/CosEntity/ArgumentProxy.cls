Class %ZPM.PackageManager.Developer.Annotation.CosEntity.ArgumentProxy Extends %ZPM.PackageManager.Developer.Annotation.CosEntity
{

Parameter XMLNAME = "Argument";

Parameter AcceptableAnchorTags = "Argument";

Property Name As %String(XMLPROJECTION = "attribute");

Property DataType As %Dictionary.Classname(XMLPROJECTION = "attribute");

Property DefaultValue As %String(XMLPROJECTION = "attribute");

/// either "Output" or "ByRef". The default case (input/ByRef) is represented by a blank so that it will be omitted from the XML output
Property PassedAs As %String(VALUELIST = ",Output,ByRef", XMLPROJECTION = "attribute");

Relationship ParentMember As %ZPM.PackageManager.Developer.Annotation.CosEntity.MemberWithArguments [ Cardinality = one, Inverse = Arguments, OnDelete = cascade ];

Index ParentMemberIndex On ParentMember;

Index ArgumentExtentIndex [ Extent ];

ClassMethod GetOwnerClassProxyID(pID As %Integer) As %Integer
{
	set tParentMemberID = ..ParentMemberGetStored(pID)
	quit ##class(%ZPM.PackageManager.Developer.Annotation.CosEntity.ClassMemberProxy).GetOwnerClassProxyID(tParentMemberID)
}

Method GetFriendlyIdentifier() As %String
{
	quit ..ParentMember.GetFriendlyIdentifier() _ ", argument " _ ..Name
}

Storage Default
{
<Data name="ArgumentProxyDefaultData">
<Subscript>"ArgumentProxy"</Subscript>
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>DataType</Value>
</Value>
<Value name="3">
<Value>DefaultValue</Value>
</Value>
<Value name="4">
<Value>PassedAs</Value>
</Value>
<Value name="5">
<Value>ParentMember</Value>
</Value>
</Data>
<DefaultData>ArgumentProxyDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
