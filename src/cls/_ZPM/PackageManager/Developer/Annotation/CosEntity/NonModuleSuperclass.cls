/// data holder for names of non-module superclasses extended by a given module class. Note that although this 
/// class is in the CosEntity package, it does NOT extend <class>%ZPM.PackageManager.Developer.Annotation.CosEntity</class>. 
Class %ZPM.PackageManager.Developer.Annotation.CosEntity.NonModuleSuperclass Extends (%Persistent, %XML.Adaptor)
{

Parameter XMLNAME = "NonModuleSuperclass";

Relationship AppliesTo As %ZPM.PackageManager.Developer.Annotation.CosEntity.ClassProxy [ Cardinality = parent, Inverse = NonModuleSuperclasses ];

Property ClassName As %Dictionary.Classname(XMLPROJECTION = "attribute");

Property InPrimaryAncestry As %Boolean(XMLPROJECTION = "attribute") [ InitialExpression = 0 ];

Storage Default
{
<Data name="NonModuleSuperclassDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ClassName</Value>
</Value>
<Value name="3">
<Value>InPrimaryAncestry</Value>
</Value>
</Data>
<DataLocation>{%%PARENT}("NonModuleSuperclasses")</DataLocation>
<DefaultData>NonModuleSuperclassDefaultData</DefaultData>
<IdLocation>^%ZPM.Dev.Annot.ClassProxyC("NonModuleSuperclasses")</IdLocation>
<IndexLocation>^%ZPM.Dev.Annotation.NonModSupI</IndexLocation>
<StreamLocation>^%ZPM.Dev.Annotation.NonModSupS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
