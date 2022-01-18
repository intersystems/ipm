/// Represents a resource within a <class>%ZPM.Storage.ResourceReference</class> - 
/// typically, a class or subpackage within a .PKG resource - that should be scanned for API annotations.
Class %ZPM.PackageManager.Developer.APIReference Extends (%SerialObject, %XML.Adaptor, %ZPM.Utils.ComparisonAdaptor)
{

/// The name of the resource that should be scanned for API annotations, with extension; e.g., MyModule.API.PKG
Property Resource As %ZPM.DataType.ResourceName(XMLPROJECTION = "attribute");

Storage Default
{
<Data name="APIReferenceState">
<Value name="1">
<Value>Resource</Value>
</Value>
</Data>
<State>APIReferenceState</State>
<StreamLocation>^%ZPM.Dev.APIReferenceS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
