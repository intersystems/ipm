/// Abstract class representing a setting applied at the the module level.
Class %IPM.Storage.ModuleSetting Extends (%SerialObject, %XML.Adaptor, %IPM.Utils.ComparisonAdaptor) [ Abstract ]
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModuleSetting";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Storage Default
{
<StreamLocation>^IPM.Storage.ModuleSettingS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
