/// Custom defaults for module
/// Each <Default Name="" Value="" /> element defines one parameter, that can be specified
/// during module installation
Class %IPM.Storage.ModuleSetting.Default Extends %IPM.Storage.ModuleSetting
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModSet.Default";

Property Name As %String(MAXLEN = 255, XMLPROJECTION = "ATTRIBUTE");

Property Value As %String(MAXLEN = 1000, XMLPROJECTION = "ATTRIBUTE");

ClassMethod GetCustomParameters(
	Output customParams,
	module As %IPM.Storage.Module,
	ByRef pParams) As %Status
{
    kill customParams
    set customParams = ""
    set key = ""
    for {
        set default = module.Defaults.GetNext(.key)
        quit:(key="")
        if (default.%ClassName(1)="%IPM.Storage.ModuleSetting.Default") {
            set customParams(default.Name) = default.Value
            if ($data(pParams(default.Name))) {
                set customParams(default.Name) = $get(pParams(default.Name))
            }
        }
    }
    return $$$OK
}

ClassMethod EvaluateArgs(
	ByRef args,
	ByRef customParams) As %Status
{
    set key = ""
    for {
        set key = $order(args(key))
        quit:(key="")
        set args(key) = ..EvaluateAttribute(args(key),.customParams)
    }
    return $$$OK
}

ClassMethod EvaluateAttribute(
	attribute As %String,
	ByRef customParams) As %String
{
    set name=""
    for {
        set name = $order(customParams(name), 1, value)
        quit:(name="")
        set attribute = ##class(%IPM.Utils.Module).%RegExReplace(attribute, name, value)
    }
    return attribute
}

Storage Default
{
<Data name="DefaultState">
<Subscript>"Default"</Subscript>
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>Value</Value>
</Value>
</Data>
<State>DefaultState</State>
<Type>%Storage.Serial</Type>
}

}
