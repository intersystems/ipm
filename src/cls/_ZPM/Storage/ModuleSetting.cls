/// Abstract class representing a setting applied at the the module level.
Class %ZPM.Storage.ModuleSetting Extends (%SerialObject, %XML.Adaptor, %ZPM.Utils.ComparisonAdaptor) [ Abstract ]
{

Parameter DEFAULTGLOBAL = "^ZPM.Storage.ModuleSetting";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Storage Default
{
<StreamLocation>^ZPM.Storage.ModuleSettingS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
