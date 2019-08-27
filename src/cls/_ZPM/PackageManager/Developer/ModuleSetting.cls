/// Abstract class representing a setting applied at the the module level.
Class %ZPM.PackageManager.Developer.ModuleSetting Extends (%SerialObject, %XML.Adaptor) [ Abstract ]
{

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

Storage Default
{
<StreamLocation>^ZPM.Dev.ModuleSettingS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
