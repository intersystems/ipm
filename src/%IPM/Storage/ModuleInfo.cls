/// Just a Serial Object of ModuleInfo so that it can be persisted in other objects.
Class %IPM.Storage.ModuleInfo Extends (%SerialObject, %IPM.General.ModuleInfo) [ StorageStrategy = "" ]
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModuleInfo";

Storage Default
{
<Data name="ModuleInfoState">
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>Description</Value>
</Value>
<Value name="3">
<Value>Version</Value>
</Value>
<Value name="4">
<Value>VersionString</Value>
</Value>
<Value name="5">
<Value>Repository</Value>
</Value>
</Data>
<State>ModuleInfoState</State>
<StreamLocation>^IPM.Storage.ModuleInfoS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
